//
//  RAWDecoder.swift
//  PhotoCoachPro
//
//  CIRAWFilter-based RAW decoding with full control
//

import Foundation
import CoreImage
import CoreGraphics

/// Decodes RAW images with full control over processing parameters
actor RAWDecoder {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])) {
        self.context = context
    }

    // MARK: - Decoding

    /// Decode RAW image with settings
    func decode(url: URL, settings: RAWSettings = .default) async throws -> RAWDecodedImage {
        // Create RAW filter
        guard let rawFilter = CIFilter(imageURL: url, options: filterOptions(for: settings)) else {
            throw RAWDecodingError.unsupportedFormat
        }

        // Apply settings
        applySettings(settings, to: rawFilter)

        // Get output image
        guard let outputImage = rawFilter.outputImage else {
            throw RAWDecodingError.decodingFailed
        }

        // Extract native size
        let nativeSize = rawFilter.value(forKey: kCIInputImageOrientationKey) as? CGSize ?? outputImage.extent.size

        // Extract available keys for advanced control
        let availableKeys = rawFilter.inputKeys

        return RAWDecodedImage(
            image: outputImage,
            settings: settings,
            nativeSize: nativeSize,
            availableFilterKeys: availableKeys,
            rawFilter: rawFilter
        )
    }

    /// Quick decode with auto settings (for preview/thumbnail)
    func quickDecode(url: URL) async throws -> CIImage {
        let options: [CIRAWFilterOption: Any] = [
            .allowDraftMode: true,
            .baselineExposure: 0.0
        ]

        guard let rawFilter = CIFilter(imageURL: url, options: options),
              let outputImage = rawFilter.outputImage else {
            throw RAWDecodingError.decodingFailed
        }

        return outputImage
    }

    /// Decode with auto white balance
    func decodeWithAutoWB(url: URL, settings: RAWSettings = .default) async throws -> RAWDecodedImage {
        var adjustedSettings = settings

        // First pass: get neutral values
        guard let rawFilter = CIFilter(imageURL: url, options: filterOptions(for: settings)) else {
            throw RAWDecodingError.unsupportedFormat
        }

        // Extract auto WB values if available
        if let neutralTemp = rawFilter.value(forKey: "inputNeutralTemperature") as? Double,
           let neutralTint = rawFilter.value(forKey: "inputNeutralTint") as? Double {
            adjustedSettings.neutralTemperature = neutralTemp
            adjustedSettings.neutralTint = neutralTint
            adjustedSettings.temperature = neutralTemp
            adjustedSettings.tint = neutralTint
        }

        return try await decode(url: url, settings: adjustedSettings)
    }

    // MARK: - Re-render with Updated Settings

    /// Re-render existing RAW filter with new settings (faster than full decode)
    func rerender(decoded: RAWDecodedImage, newSettings: RAWSettings) async -> CIImage? {
        guard let filter = decoded.rawFilter else { return nil }

        applySettings(newSettings, to: filter)
        return filter.outputImage
    }

    // MARK: - Private Helpers

    private func filterOptions(for settings: RAWSettings) -> [CIRAWFilterOption: Any] {
        var options: [CIRAWFilterOption: Any] = [
            .allowDraftMode: false,
            .baselineExposure: settings.baselineExposure
        ]

        // Color space
        switch settings.colorSpace {
        case .native:
            break // Use native
        case .sRGB:
            options[.colorSpace] = CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            options[.colorSpace] = CGColorSpace(name: CGColorSpace.displayP3)!
        case .adobeRGB:
            options[.colorSpace] = CGColorSpace(name: CGColorSpace.adobeRGB1998)!
        case .proPhotoRGB:
            options[.colorSpace] = CGColorSpace(name: CGColorSpace.rommrgb)!
        }

        return options
    }

    private func applySettings(_ settings: RAWSettings, to filter: CIFilter) {
        let params = settings.ciFilterParameters

        for (key, value) in params {
            // Only set if key is available
            if filter.inputKeys.contains(key) {
                filter.setValue(value, forKey: key)
            }
        }
    }

    // MARK: - Metadata Extraction

    /// Extract RAW-specific metadata
    func extractRAWMetadata(url: URL) async throws -> RAWMetadata {
        guard let rawFilter = CIFilter(imageURL: url, options: [:]) else {
            throw RAWDecodingError.unsupportedFormat
        }

        var metadata = RAWMetadata()

        // Extract available properties
        if let nativeScale = rawFilter.value(forKey: "inputScaleFactor") as? Double {
            metadata.nativeScale = nativeScale
        }

        if let baselineExposure = rawFilter.value(forKey: "inputBaselineExposure") as? Double {
            metadata.baselineExposure = baselineExposure
        }

        if let neutralTemp = rawFilter.value(forKey: "inputNeutralTemperature") as? Double {
            metadata.neutralTemperature = neutralTemp
        }

        if let neutralTint = rawFilter.value(forKey: "inputNeutralTint") as? Double {
            metadata.neutralTint = neutralTint
        }

        metadata.availableKeys = rawFilter.inputKeys

        return metadata
    }
}

// MARK: - Result Types

struct RAWDecodedImage {
    let image: CIImage
    let settings: RAWSettings
    let nativeSize: CGSize
    let availableFilterKeys: [String]
    let rawFilter: CIFilter?  // Keep reference for re-rendering
}

struct RAWMetadata {
    var nativeScale: Double?
    var baselineExposure: Double?
    var neutralTemperature: Double?
    var neutralTint: Double?
    var availableKeys: [String] = []
}

// MARK: - Errors

enum RAWDecodingError: Error, LocalizedError {
    case unsupportedFormat
    case decodingFailed
    case missingMetadata
    case invalidSettings

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "RAW format not supported or file is corrupted"
        case .decodingFailed:
            return "Failed to decode RAW image"
        case .missingMetadata:
            return "RAW metadata could not be read"
        case .invalidSettings:
            return "Invalid RAW processing settings"
        }
    }
}
