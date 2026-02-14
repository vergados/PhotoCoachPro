// //  ImageLoader.swift
//  PhotoCoachPro
//
//  Loads any supported format into CIImage
//

import Foundation
import CoreImage
import CoreGraphics
import UniformTypeIdentifiers

/// Loads images from various sources into CIImage
actor ImageLoader {
    private let colorSpaceManager: ColorSpaceManager
    private let loadTimeout: TimeInterval

    init(colorSpaceManager: ColorSpaceManager, loadTimeout: TimeInterval = 30.0) {
        self.colorSpaceManager = colorSpaceManager
        self.loadTimeout = loadTimeout
    }

    // MARK: - Load from URL

    func load(from url: URL) async throws -> LoadedImage {
        try await withTimeout(loadTimeout) {
            let fileType = try self.detectFileType(url: url)

            switch fileType {
            case .raw:
                return try await self.loadRAW(from: url)
            case .standard:
                return try await self.loadStandard(from: url)
            }
        }
    }

    // MARK: - Timeout Wrapper

    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ImageLoadError.timeout
            }

            guard let result = try await group.next() else {
                throw ImageLoadError.timeout
            }

            group.cancelAll()
            return result
        }
    }

    // MARK: - Standard Formats (JPEG, PNG, HEIC, TIFF)

    private func loadStandard(from url: URL) async throws -> LoadedImage {
        let options: [CIImageOption: Any] = [
            .applyOrientationProperty: true
        ]

        guard let ciImage = CIImage(contentsOf: url, options: options) else {
            throw ImageLoadError.invalidImage
        }

        // Extract metadata
        let properties = ciImage.properties
        let exifData = extractEXIF(from: properties)

        // Convert to working color space
        let workingImage = await colorSpaceManager.convertToWorkingSpace(ciImage)

        return LoadedImage(
            image: workingImage,
            originalColorSpace: ciImage.colorSpace,
            metadata: exifData,
            fileType: url.pathExtension.lowercased()
        )
    }

    // MARK: - RAW Formats

    private func loadRAW(from url: URL) async throws -> LoadedImage {
        // Use CIRAWFilter for RAW decoding
        guard let rawFilter = CIFilter(imageURL: url, options: [:]) else {
            throw ImageLoadError.rawDecodingFailed
        }

        guard let ciImage = rawFilter.outputImage else {
            throw ImageLoadError.rawDecodingFailed
        }

        // Extract RAW properties
        let properties = ciImage.properties
        let exifData = extractEXIF(from: properties)

        // Convert to working color space
        let workingImage = await colorSpaceManager.convertToWorkingSpace(ciImage)

        return LoadedImage(
            image: workingImage,
            originalColorSpace: ciImage.colorSpace,
            metadata: exifData,
            fileType: url.pathExtension.lowercased(),
            isRAW: true
        )
    }

    // MARK: - File Type Detection

    private func detectFileType(url: URL) throws -> FileType {
        let ext = url.pathExtension.lowercased()

        let rawExtensions = ["dng", "nef", "cr2", "cr3", "arw", "orf", "raf", "rw2", "raw"]
        if rawExtensions.contains(ext) {
            return .raw
        }

        let standardExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif"]
        if standardExtensions.contains(ext) {
            return .standard
        }

        throw ImageLoadError.unsupportedFormat
    }

    // MARK: - EXIF Extraction

    private func extractEXIF(from properties: [String: Any]) -> EXIFData? {
        guard let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }

        var exif = EXIFData()

        // Camera info
        let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        exif.cameraMake = tiffDict?[kCGImagePropertyTIFFMake as String] as? String
        exif.cameraModel = tiffDict?[kCGImagePropertyTIFFModel as String] as? String

        // Exposure settings
        exif.exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? String
        exif.fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double
        exif.iso = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? Int
        exif.exposureBias = exifDict[kCGImagePropertyExifExposureBiasValue as String] as? Double

        // Lens info
        exif.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
        exif.focalLength35mmEquiv = exifDict[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double

        // Dates
        if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            exif.dateTimeOriginal = parseEXIFDate(dateString)
        }

        // GPS
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            exif.gpsLatitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double
            exif.gpsLongitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double
            exif.gpsAltitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        }

        // Color space
        let colorSpaceInt = exifDict[kCGImagePropertyExifColorSpace as String] as? Int
        exif.colorSpace = colorSpaceInt == 1 ? "sRGB" : "Uncalibrated"

        return exif
    }

    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    // MARK: - Supporting Types

    enum FileType {
        case raw
        case standard
    }
}

// MARK: - Loaded Image Result
struct LoadedImage {
    let image: CIImage
    let originalColorSpace: CGColorSpace?
    let metadata: EXIFData?
    let fileType: String
    let isRAW: Bool

    init(
        image: CIImage,
        originalColorSpace: CGColorSpace?,
        metadata: EXIFData?,
        fileType: String,
        isRAW: Bool = false
    ) {
        self.image = image
        self.originalColorSpace = originalColorSpace
        self.metadata = metadata
        self.fileType = fileType
        self.isRAW = isRAW
    }
}

// MARK: - Errors
enum ImageLoadError: Error, LocalizedError {
    case invalidImage
    case unsupportedFormat
    case rawDecodingFailed
    case fileNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not load image file"
        case .unsupportedFormat:
            return "Unsupported image format"
        case .rawDecodingFailed:
            return "Failed to decode RAW image"
        case .fileNotFound:
            return "Image file not found"
        case .timeout:
            return "Image loading timed out (file may be corrupted)"
        }
    }
}
