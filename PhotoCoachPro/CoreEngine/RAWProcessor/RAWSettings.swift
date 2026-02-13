//
//  RAWSettings.swift
//  PhotoCoachPro
//
//  RAW-specific processing parameters
//

import Foundation
import CoreImage

/// RAW processing settings
struct RAWSettings: Codable, Equatable {
    // Basic RAW adjustments
    var exposure: Double              // EV adjustment (-5.0 to +5.0)
    var baselineExposure: Double      // Camera baseline (-2.0 to +2.0)

    // White balance
    var temperature: Double           // Kelvin (2000 to 25000)
    var tint: Double                  // Green/Magenta (-150 to +150)
    var neutralTemperature: Double?   // Auto WB reference
    var neutralTint: Double?          // Auto WB reference

    // Noise reduction
    var luminanceNoiseReduction: Double     // 0.0 to 1.0
    var colorNoiseReduction: Double         // 0.0 to 1.0
    var noiseReductionSharpness: Double     // 0.0 to 1.0
    var noiseReductionDetail: Double        // 0.0 to 1.0

    // Sharpening
    var sharpness: Double             // 0.0 to 1.0
    var sharpnessRadius: Double       // 0.5 to 3.0
    var sharpnessThreshold: Double    // 0.0 to 0.1

    // Lens corrections
    var enableChromaticAberration: Bool
    var enableVignette: Bool
    var boostAmount: Double           // Shadow boost (0.0 to 1.0)
    var boostShadowAmount: Double     // Fine-tune shadow boost

    // Output
    var colorSpace: ColorSpaceOption
    var outputDepth: BitDepth

    enum ColorSpaceOption: String, Codable {
        case native = "Native"
        case sRGB = "sRGB"
        case displayP3 = "Display P3"
        case adobeRGB = "Adobe RGB"
        case proPhotoRGB = "ProPhoto RGB"
    }

    enum BitDepth: String, Codable {
        case depth8 = "8-bit"
        case depth16 = "16-bit"
    }

    // MARK: - Defaults

    static var `default`: RAWSettings {
        RAWSettings(
            exposure: 0.0,
            baselineExposure: 0.0,
            temperature: 6500,
            tint: 0,
            neutralTemperature: nil,
            neutralTint: nil,
            luminanceNoiseReduction: 0.0,
            colorNoiseReduction: 0.0,
            noiseReductionSharpness: 0.5,
            noiseReductionDetail: 0.5,
            sharpness: 0.0,
            sharpnessRadius: 1.0,
            sharpnessThreshold: 0.03,
            enableChromaticAberration: true,
            enableVignette: true,
            boostAmount: 0.0,
            boostShadowAmount: 0.0,
            colorSpace: .native,
            outputDepth: .depth16
        )
    }

    // MARK: - Presets

    static var cleanRAW: RAWSettings {
        var settings = RAWSettings.default
        settings.colorNoiseReduction = 0.3
        settings.luminanceNoiseReduction = 0.2
        settings.sharpness = 0.4
        settings.enableChromaticAberration = true
        settings.enableVignette = true
        return settings
    }

    static var maximumDetail: RAWSettings {
        var settings = RAWSettings.default
        settings.sharpness = 0.7
        settings.sharpnessRadius = 0.8
        settings.colorNoiseReduction = 0.1
        settings.luminanceNoiseReduction = 0.1
        settings.noiseReductionDetail = 0.8
        return settings
    }

    static var smoothNoise: RAWSettings {
        var settings = RAWSettings.default
        settings.colorNoiseReduction = 0.6
        settings.luminanceNoiseReduction = 0.5
        settings.noiseReductionSharpness = 0.3
        settings.sharpness = 0.2
        return settings
    }
}

// MARK: - CIFilter Parameter Mapping
extension RAWSettings {
    /// Convert settings to CIFilter parameters
    var ciFilterParameters: [String: Any] {
        var params: [String: Any] = [:]

        // Exposure
        params[kCIInputEVKey] = exposure
        params["inputBaselineExposure"] = baselineExposure

        // White balance
        if let neutralTemp = neutralTemperature, let neutralTint = neutralTint {
            params["inputNeutralChromaticityX"] = neutralTemp
            params["inputNeutralChromaticityY"] = neutralTint
        }
        params["inputNeutralTemperature"] = temperature
        params["inputNeutralTint"] = tint

        // Noise reduction
        params["inputLuminanceNoiseReductionAmount"] = luminanceNoiseReduction
        params["inputColorNoiseReductionAmount"] = colorNoiseReduction
        params["inputNoiseReductionSharpnessAmount"] = noiseReductionSharpness
        params["inputNoiseReductionDetailAmount"] = noiseReductionDetail

        // Sharpening
        params["inputSharpnessAmount"] = sharpness
        params["inputSharpnessRadius"] = sharpnessRadius
        params["inputSharpnessThreshold"] = sharpnessThreshold

        // Lens corrections
        params["inputEnableChromaticAberrationCorrection"] = enableChromaticAberration
        params["inputEnableVendorLensCorrection"] = enableVignette
        params["inputBoostAmount"] = boostAmount
        params["inputBoostShadowAmount"] = boostShadowAmount

        return params
    }
}
