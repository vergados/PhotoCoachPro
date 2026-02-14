//
//  ExportManager.swift
//  PhotoCoachPro
//
//  Coordinates all export types
//

import Foundation
import CoreImage
import CoreGraphics

/// Manages photo export operations
actor ExportManager {
    private let renderer: ImageRenderer
    private let colorSpaceManager: ColorSpaceManager
    private let privacySettings: PrivacySettings

    init(
        renderer: ImageRenderer,
        colorSpaceManager: ColorSpaceManager,
        privacySettings: PrivacySettings
    ) {
        self.renderer = renderer
        self.colorSpaceManager = colorSpaceManager
        self.privacySettings = privacySettings
    }

    // MARK: - Export Configurations

    enum ExportFormat {
        case jpeg(quality: Double)
        case png
        case tiff
        case heic(quality: Double)

        var fileExtension: String {
            switch self {
            case .jpeg: return "jpg"
            case .png: return "png"
            case .tiff: return "tif"
            case .heic: return "heic"
            }
        }
    }

    enum ExportPreset {
        case web           // sRGB, JPEG 85%, max 2048px
        case print         // Working space, TIFF 16-bit
        case original      // Preserve original settings
        case custom(ExportOptions)

        var options: ExportOptions {
            switch self {
            case .web:
                return ExportOptions(
                    format: .jpeg(quality: 0.85),
                    colorSpace: .sRGB,
                    maxDimension: 2048,
                    embedColorProfile: true,
                    stripMetadata: false
                )
            case .print:
                return ExportOptions(
                    format: .tiff,
                    colorSpace: .displayP3,
                    maxDimension: nil,
                    embedColorProfile: true,
                    stripMetadata: false
                )
            case .original:
                return ExportOptions(
                    format: .jpeg(quality: 0.95),
                    colorSpace: .displayP3,
                    maxDimension: nil,
                    embedColorProfile: true,
                    stripMetadata: false
                )
            case .custom(let options):
                return options
            }
        }
    }

    struct ExportOptions {
        var format: ExportFormat
        var colorSpace: ColorSpaceManager.WorkingSpace
        var maxDimension: Int?
        var embedColorProfile: Bool
        var stripMetadata: Bool
        var stripLocation: Bool

        init(
            format: ExportFormat,
            colorSpace: ColorSpaceManager.WorkingSpace,
            maxDimension: Int? = nil,
            embedColorProfile: Bool = true,
            stripMetadata: Bool = false,
            stripLocation: Bool = false
        ) {
            self.format = format
            self.colorSpace = colorSpace
            self.maxDimension = maxDimension
            self.embedColorProfile = embedColorProfile
            self.stripMetadata = stripMetadata
            self.stripLocation = stripLocation
        }
    }

    // MARK: - Export Operations

    func export(
        image: CIImage,
        to url: URL,
        preset: ExportPreset = .original,
        metadata: PhotoMetadata? = nil
    ) async throws {
        let options = preset.options
        var processedImage = image

        // Resize if needed
        if let maxDim = options.maxDimension {
            processedImage = resize(processedImage, maxDimension: maxDim)
        }

        // Convert to target color space
        let targetColorSpace = options.colorSpace.cgColorSpace
        let convertedImage = await colorSpaceManager.convert(processedImage, to: targetColorSpace)

        // Apply privacy settings
        let finalMetadata = await applyPrivacyFilters(metadata)

        // Render and save
        try await save(
            image: convertedImage,
            to: url,
            format: options.format,
            colorSpace: targetColorSpace,
            metadata: finalMetadata,
            embedProfile: options.embedColorProfile
        )
    }

    // MARK: - Batch Export

    func exportBatch(
        images: [(image: CIImage, url: URL, metadata: PhotoMetadata?)],
        preset: ExportPreset = .original,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws {
        for (index, item) in images.enumerated() {
            try await export(
                image: item.image,
                to: item.url,
                preset: preset,
                metadata: item.metadata
            )
            progressHandler(index + 1, images.count)
        }
    }

    // MARK: - Private Helpers

    private func resize(_ image: CIImage, maxDimension: Int) -> CIImage {
        let extent = image.extent
        let maxCurrent = max(extent.width, extent.height)
        let scale = Double(maxDimension) / maxCurrent

        guard scale < 1.0 else { return image }

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }

    private func applyPrivacyFilters(_ metadata: PhotoMetadata?) async -> PhotoMetadata? {
        guard var metadata = metadata else { return nil }

        let stripMetadata = await privacySettings.stripMetadataOnExport
        let stripLocation = await privacySettings.stripLocationOnExport

        if stripMetadata {
            return nil
        }

        if stripLocation {
            metadata.exif?.gpsLatitude = nil
            metadata.exif?.gpsLongitude = nil
            metadata.exif?.gpsAltitude = nil
        }

        return metadata
    }

    private func save(
        image: CIImage,
        to url: URL,
        format: ExportFormat,
        colorSpace: CGColorSpace,
        metadata: PhotoMetadata?,
        embedProfile: Bool
    ) async throws {
        switch format {
        case .jpeg(let quality):
            guard let data = await renderer.renderJPEG(from: image, quality: quality, colorSpace: colorSpace) else {
                throw ExportError.renderFailed
            }
            try data.write(to: url, options: .atomic)

        case .png:
            guard let data = await renderer.renderPNG(from: image, colorSpace: colorSpace) else {
                throw ExportError.renderFailed
            }
            try data.write(to: url, options: .atomic)

        case .tiff, .heic:
            // Phase 1: Basic JPEG/PNG only, TIFF/HEIC in Phase 2
            throw ExportError.unsupportedFormat
        }
    }
}

// MARK: - Errors
// Note: ExportError is defined in Export/Models/ExportSettings.swift
