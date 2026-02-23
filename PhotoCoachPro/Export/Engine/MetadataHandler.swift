//
//  MetadataHandler.swift
//  PhotoCoachPro
//
//  EXIF metadata handling for export
//

import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Handle image metadata during export
actor MetadataHandler {
    private let exifReader: EXIFReader

    init(exifReader: EXIFReader = EXIFReader()) {
        self.exifReader = exifReader
    }

    /// Apply metadata option to exported image data
    func apply(
        imageData: Data,
        format: ExportSettings.ExportFormat,
        metadataOption: ExportSettings.MetadataOption,
        sourcePhoto: PhotoRecord
    ) async throws -> Data {
        switch metadataOption {
        case .preserve:
            return try await preserveAllMetadata(imageData, format: format, sourcePhoto: sourcePhoto)
        case .basic:
            return try await preserveBasicMetadata(imageData, format: format, sourcePhoto: sourcePhoto)
        case .strip:
            return try await stripAllMetadata(imageData, format: format)
        }
    }

    // MARK: - Preserve All

    private func preserveAllMetadata(
        _ imageData: Data,
        format: ExportSettings.ExportFormat,
        sourcePhoto: PhotoRecord
    ) async throws -> Data {
        let mutableData = NSMutableData(data: imageData)

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(imageSource) else {
            throw ExportError.metadataHandlingFailed
        }

        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            throw ExportError.metadataHandlingFailed
        }

        // Read original metadata directly from source file via CGImageSource
        var originalMetadataProps: CFDictionary? = nil
        if !sourcePhoto.filePath.isEmpty {
            let sourceURL = URL(fileURLWithPath: sourcePhoto.filePath)
            if let srcSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) {
                originalMetadataProps = CGImageSourceCopyPropertiesAtIndex(srcSource, 0, nil)
            }
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ExportError.metadataHandlingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, originalMetadataProps)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.metadataHandlingFailed
        }

        return mutableData as Data
    }

    // MARK: - Preserve Basic

    private func preserveBasicMetadata(
        _ imageData: Data,
        format: ExportSettings.ExportFormat,
        sourcePhoto: PhotoRecord
    ) async throws -> Data {
        let mutableData = NSMutableData(data: imageData)

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(imageSource) else {
            throw ExportError.metadataHandlingFailed
        }

        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            throw ExportError.metadataHandlingFailed
        }

        // Read original metadata from source file and strip GPS / IPTC
        var filteredMetadataProps: CFDictionary? = nil
        if !sourcePhoto.filePath.isEmpty {
            let sourceURL = URL(fileURLWithPath: sourcePhoto.filePath)
            if let srcSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(srcSource, 0, nil) as? [String: Any] {
                let filtered = filterToBasicMetadata(props)
                filteredMetadataProps = filtered as CFDictionary
            }
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ExportError.metadataHandlingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, filteredMetadataProps)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.metadataHandlingFailed
        }

        return mutableData as Data
    }

    // MARK: - Strip All

    private func stripAllMetadata(
        _ imageData: Data,
        format: ExportSettings.ExportFormat
    ) async throws -> Data {
        // Create mutable data
        let mutableData = NSMutableData(data: imageData)

        // Create image source
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(imageSource) else {
            throw ExportError.metadataHandlingFailed
        }

        // Create destination without metadata
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            type,
            1,
            nil
        ) else {
            throw ExportError.metadataHandlingFailed
        }

        // Add image without metadata
        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            CGImageDestinationAddImage(destination, cgImage, nil)
        } else {
            throw ExportError.metadataHandlingFailed
        }

        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.metadataHandlingFailed
        }

        return mutableData as Data
    }

    // MARK: - Helpers

    private func filterToBasicMetadata(_ metadata: [String: Any]) -> [String: Any] {
        var filtered: [String: Any] = [:]

        // Keep camera and lens info
        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            var basicExif: [String: Any] = [:]

            // Camera settings
            let keysToKeep = [
                kCGImagePropertyExifExposureTime,
                kCGImagePropertyExifFNumber,
                kCGImagePropertyExifISOSpeedRatings,
                kCGImagePropertyExifFocalLength,
                kCGImagePropertyExifDateTimeOriginal,
                kCGImagePropertyExifLensMake,
                kCGImagePropertyExifLensModel
            ]

            for key in keysToKeep {
                if let value = exif[key as String] {
                    basicExif[key as String] = value
                }
            }

            if !basicExif.isEmpty {
                filtered[kCGImagePropertyExifDictionary as String] = basicExif
            }
        }

        // Keep TIFF info (camera make/model)
        if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            var basicTiff: [String: Any] = [:]

            let keysToKeep = [
                kCGImagePropertyTIFFMake,
                kCGImagePropertyTIFFModel,
                kCGImagePropertyTIFFOrientation
            ]

            for key in keysToKeep {
                if let value = tiff[key as String] {
                    basicTiff[key as String] = value
                }
            }

            if !basicTiff.isEmpty {
                filtered[kCGImagePropertyTIFFDictionary as String] = basicTiff
            }
        }

        // Explicitly exclude GPS
        // (Don't copy kCGImagePropertyGPSDictionary)

        return filtered
    }

    private func convertMetadataToCF(_ metadata: [String: Any]) -> NSDictionary {
        return metadata as NSDictionary
    }

    // MARK: - Metadata Inspection

    /// Extract metadata from image data
    func extractMetadata(from data: Data) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }

        return properties
    }

    /// Check if image data contains GPS information
    func containsGPSData(_ data: Data) -> Bool {
        guard let metadata = extractMetadata(from: data) else {
            return false
        }

        return metadata[kCGImagePropertyGPSDictionary as String] != nil
    }

    /// Get metadata summary
    func metadataSummary(from data: Data) -> MetadataSummary {
        guard let metadata = extractMetadata(from: data) else {
            return MetadataSummary(hasEXIF: false, hasGPS: false, hasIPTC: false)
        }

        let hasEXIF = metadata[kCGImagePropertyExifDictionary as String] != nil
        let hasGPS = metadata[kCGImagePropertyGPSDictionary as String] != nil
        let hasIPTC = metadata[kCGImagePropertyIPTCDictionary as String] != nil

        return MetadataSummary(hasEXIF: hasEXIF, hasGPS: hasGPS, hasIPTC: hasIPTC)
    }
}

// MARK: - Metadata Summary

struct MetadataSummary {
    let hasEXIF: Bool
    let hasGPS: Bool
    let hasIPTC: Bool

    var isEmpty: Bool {
        return !hasEXIF && !hasGPS && !hasIPTC
    }

    var description: String {
        var parts: [String] = []
        if hasEXIF { parts.append("EXIF") }
        if hasGPS { parts.append("GPS") }
        if hasIPTC { parts.append("IPTC") }

        if parts.isEmpty {
            return "No metadata"
        } else {
            return parts.joined(separator: ", ")
        }
    }
}
