//
//  ExportEngine.swift
//  PhotoCoachPro
//
//  Export processing engine
//

import Foundation
import CoreImage
import UniformTypeIdentifiers

/// Export processing engine
actor ExportEngine {
    private let context: CIContext
    private let colorSpaceManager: ColorSpaceManager
    private let metadataHandler: MetadataHandler
    private let formatConverter: FormatConverter

    init(
        context: CIContext = CIContext(options: [.useSoftwareRenderer: false]),
        colorSpaceManager: ColorSpaceManager = ColorSpaceManager(),
        metadataHandler: MetadataHandler = MetadataHandler(),
        formatConverter: FormatConverter = FormatConverter()
    ) {
        self.context = context
        self.colorSpaceManager = colorSpaceManager
        self.metadataHandler = metadataHandler
        self.formatConverter = formatConverter
    }

    // MARK: - Single Export

    /// Export a single photo with the given settings
    func export(
        image: CIImage,
        settings: ExportSettings,
        photoRecord: PhotoRecord,
        outputURL: URL
    ) async throws {
        // 1. Apply resolution changes
        let resizedImage = try await applyResolution(image, settings: settings)

        // 2. Convert color space
        let colorManagedImage = try await applyColorSpace(resizedImage, settings: settings)

        // 3. Convert format and quality
        let imageData = try await formatConverter.convert(
            colorManagedImage,
            to: settings.format,
            quality: settings.quality,
            context: context
        )

        // 4. Handle metadata
        let finalData = try await metadataHandler.apply(
            imageData: imageData,
            format: settings.format,
            metadataOption: settings.metadata,
            sourcePhoto: photoRecord
        )

        // 5. Write to output URL
        try finalData.write(to: outputURL)
    }

    /// Export with progress callback
    func export(
        image: CIImage,
        settings: ExportSettings,
        photoRecord: PhotoRecord,
        outputURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        progressHandler(0.0)

        // Resolution (25%)
        let resizedImage = try await applyResolution(image, settings: settings)
        progressHandler(0.25)

        // Color space (50%)
        let colorManagedImage = try await applyColorSpace(resizedImage, settings: settings)
        progressHandler(0.5)

        // Format conversion (75%)
        let imageData = try await formatConverter.convert(
            colorManagedImage,
            to: settings.format,
            quality: settings.quality,
            context: context
        )
        progressHandler(0.75)

        // Metadata (90%)
        let finalData = try await metadataHandler.apply(
            imageData: imageData,
            format: settings.format,
            metadataOption: settings.metadata,
            sourcePhoto: photoRecord
        )
        progressHandler(0.9)

        // Write (100%)
        try finalData.write(to: outputURL)
        progressHandler(1.0)
    }

    // MARK: - Batch Export

    /// Export multiple photos with the same settings
    func batchExport(
        jobs: [(image: CIImage, photoRecord: PhotoRecord, outputURL: URL)],
        settings: ExportSettings,
        progressHandler: @escaping (Int, Double) -> Void // (index, overall progress)
    ) async throws {
        let total = jobs.count

        for (index, job) in jobs.enumerated() {
            // Export with per-job progress
            try await export(
                image: job.image,
                settings: settings,
                photoRecord: job.photoRecord,
                outputURL: job.outputURL
            ) { jobProgress in
                let overallProgress = (Double(index) + jobProgress) / Double(total)
                progressHandler(index, overallProgress)
            }
        }
    }

    // MARK: - Resolution

    private func applyResolution(
        _ image: CIImage,
        settings: ExportSettings
    ) async throws -> CIImage {
        guard let maxDimension = settings.resolution.maxDimension else {
            // Original resolution
            return image
        }

        let extent = image.extent
        let width = extent.width
        let height = extent.height

        // Calculate scale factor
        let currentMax = max(width, height)
        guard currentMax > Double(maxDimension) else {
            // Already smaller than target
            return image
        }

        let scale = Double(maxDimension) / currentMax

        // Apply scale transform
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }

    // MARK: - Color Space

    private func applyColorSpace(
        _ image: CIImage,
        settings: ExportSettings
    ) async throws -> CIImage {
        guard let targetColorSpace = settings.colorSpace.colorSpace else {
            throw ExportError.invalidColorSpace
        }

        // Convert from working space to target color space
        guard let converted = image.matchedFromWorkingSpace(to: targetColorSpace) else {
            throw ExportError.colorSpaceConversionFailed
        }

        return converted
    }

    // MARK: - File Size Estimation

    /// Estimate final file size in bytes
    func estimateFileSize(
        image: CIImage,
        settings: ExportSettings
    ) async -> Int64 {
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)

        // Apply resolution
        let finalWidth: Int
        let finalHeight: Int

        if let maxDimension = settings.resolution.maxDimension {
            let currentMax = max(width, height)
            if currentMax > maxDimension {
                let scale = Double(maxDimension) / Double(currentMax)
                finalWidth = Int(Double(width) * scale)
                finalHeight = Int(Double(height) * scale)
            } else {
                finalWidth = width
                finalHeight = height
            }
        } else {
            finalWidth = width
            finalHeight = height
        }

        let pixelCount = finalWidth * finalHeight

        // Sample-encode a 256×256 tile and extrapolate to the full resolution.
        // This captures actual image entropy so a flat-color image correctly estimates
        // a much smaller file than a detailed landscape at the same format/quality.
        let sampleMax = 256
        let srcMax    = max(finalWidth, finalHeight)
        let sampleScale = srcMax > sampleMax
            ? Double(sampleMax) / Double(srcMax)
            : 1.0
        let sampleW = max(1, Int(Double(finalWidth)  * sampleScale))
        let sampleH = max(1, Int(Double(finalHeight) * sampleScale))

        // Normalize image to origin then scale to sample dimensions
        let normalized = image.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
                .concatenating(CGAffineTransform(scaleX: CGFloat(sampleW) / extent.width,
                                                 y: CGFloat(sampleH) / extent.height)))

        let sRGB    = CGColorSpace(name: CGColorSpace.sRGB)!
        let aRGB    = CGColorSpace(name: CGColorSpace.adobeRGB1998)!
        let lossyOpt: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:
                settings.quality.compressionQuality as NSNumber
        ]

        let sampleBytes: Int? = {
            switch settings.format {
            case .jpeg:
                return context.jpegRepresentation(of: normalized, colorSpace: sRGB,
                                                  options: lossyOpt)?.count
            case .heic:
                if #available(iOS 11.0, macOS 10.13, *) {
                    return context.heifRepresentation(of: normalized, format: .RGBA8,
                                                      colorSpace: sRGB,
                                                      options: lossyOpt)?.count
                }
                return nil
            case .png:
                return context.pngRepresentation(of: normalized, format: .RGBA8,
                                                 colorSpace: sRGB, options: [:])?.count
            case .tiff:
                return context.tiffRepresentation(of: normalized, format: .RGBA16,
                                                  colorSpace: aRGB, options: [:])?.count
            }
        }()

        if let bytes = sampleBytes, sampleW * sampleH > 0 {
            let bytesPerSamplePixel = Double(bytes) / Double(sampleW * sampleH)
            return Int64(bytesPerSamplePixel * Double(pixelCount))
        }

        // Fallback when encoding fails
        switch (settings.format, settings.quality) {
        case (.jpeg, .maximum), (.heic, .maximum): return Int64(pixelCount * 3)
        case (.jpeg, .high),    (.heic, .high):    return Int64(pixelCount * 2)
        case (.jpeg, .medium),  (.heic, .medium):  return Int64(pixelCount)
        case (.jpeg, .low),     (.heic, .low):     return Int64(pixelCount / 2)
        case (.png, _):                             return Int64(pixelCount * 4)
        case (.tiff, _):                            return Int64(pixelCount * 12)
        }
    }

    // MARK: - Validation

    /// Validate export settings
    func validateSettings(_ settings: ExportSettings, for image: CIImage) throws {
        // Check format compatibility
        if !settings.format.supportsTransparency && imageHasTransparency(image) {
            throw ExportError.formatDoesNotSupportTransparency
        }

        // Check color space availability
        guard settings.colorSpace.colorSpace != nil else {
            throw ExportError.invalidColorSpace
        }

        // Warn if quality setting doesn't apply
        if !settings.format.supportsCompression && settings.quality != .maximum {
            // Quality setting ignored for PNG/TIFF
        }
    }

    private func imageHasTransparency(_ image: CIImage) -> Bool {
        // Pixel buffer format types alone are NOT a reliable transparency indicator.
        // kCVPixelFormatType_32BGRA is the default format for camera output and most
        // CoreImage operations even when the image is fully opaque, causing false positives
        // that trigger "format does not support transparency" errors on ordinary JPEG exports.
        // Image properties are the authoritative source for meaningful alpha.

        let props = image.properties

        // PNG HasAlpha flag — set explicitly by encoders only when alpha is meaningful
        if let pngProps = props["{PNG}"] as? [String: Any],
           let hasAlpha = pngProps["HasAlpha"] as? Bool {
            return hasAlpha
        }

        // TIFF ExtraSamples: non-empty array indicates an alpha (or other extra) channel
        if let tiffProps = props["{TIFF}"] as? [String: Any],
           let extraSamples = tiffProps["ExtraSamples"] as? [Int],
           !extraSamples.isEmpty {
            return true
        }

        // JPEG / RAW / HEIC do not carry alpha channels
        return false
    }

    // MARK: - Supported Formats

    /// Get list of supported export formats for current platform
    func supportedFormats() -> [ExportSettings.ExportFormat] {
        #if os(iOS)
        return ExportSettings.ExportFormat.allCases
        #elseif os(macOS)
        // HEIC might not be available on older macOS versions
        if #available(macOS 10.13, *) {
            return ExportSettings.ExportFormat.allCases
        } else {
            return [.jpeg, .png, .tiff]
        }
        #endif
    }
}

// Note: ExportError is defined in ExportManager.swift
