//
//  EditGraphEngine.swift
//  PhotoCoachPro
//
//  Applies instruction stack to source image using Core Image
//

import Foundation
import CoreImage
import CoreGraphics

/// Core engine that applies edit instructions to images
actor EditGraphEngine {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])) {
        self.context = context
    }

    // MARK: - Main Render Pipeline

    /// Render image with all active instructions applied
    func render(source: CIImage, instructions: [EditInstruction]) async -> CIImage {
        var result = source

        // Group instructions by whether they're masked or global
        let globalInstructions = instructions.filter { $0.maskID == nil }

        // Apply global adjustments in order
        for instruction in globalInstructions {
            result = applyGlobal(result, instruction: instruction)
        }

        return result
    }

    /// Render with mask support (Phase 2 - stub for now)
    func render(source: CIImage, instructions: [EditInstruction], masks: [UUID: CIImage]) async -> CIImage {
        var result = source

        for instruction in instructions {
            if let maskID = instruction.maskID, let mask = masks[maskID] {
                result = applyMasked(result, instruction: instruction, mask: mask)
            } else {
                result = applyGlobal(result, instruction: instruction)
            }
        }

        return result
    }

    // MARK: - Global Adjustments

    private func applyGlobal(_ image: CIImage, instruction: EditInstruction) -> CIImage {
        switch instruction.type {
        // MARK: Basic Tone
        case .exposure:
            return applyExposure(image, ev: instruction.value)
        case .contrast:
            return applyContrast(image, amount: instruction.value)
        case .highlights:
            return applyHighlights(image, amount: instruction.value)
        case .shadows:
            return applyShadows(image, amount: instruction.value)
        case .whites:
            return applyWhites(image, amount: instruction.value)
        case .blacks:
            return applyBlacks(image, amount: instruction.value)

        // MARK: Color Temperature
        case .temperature:
            return applyTemperature(image, offset: instruction.value)
        case .tint:
            return applyTint(image, offset: instruction.value)

        // MARK: Presence
        case .texture:
            return applyTexture(image, amount: instruction.value)
        case .clarity:
            return applyClarity(image, amount: instruction.value)
        case .dehaze:
            return applyDehaze(image, amount: instruction.value)

        // MARK: Color
        case .saturation:
            return applySaturation(image, amount: instruction.value)
        case .vibrance:
            return applyVibrance(image, amount: instruction.value)

        // MARK: Sharpening
        case .sharpAmount:
            return applySharpening(image, amount: instruction.value)

        // MARK: Noise Reduction
        case .noiseReduction:
            return applyNoiseReduction(image, amount: instruction.value)

        // MARK: Vignette
        case .vignetteAmount:
            return applyVignette(image, amount: instruction.value)

        // MARK: Grain
        case .grainAmount:
            return applyGrain(image, amount: instruction.value)

        default:
            // Unimplemented adjustments return original image
            return image
        }
    }

    // MARK: - Individual Filter Implementations

    private func applyExposure(_ image: CIImage, ev: Double) -> CIImage {
        image.applyingFilter("CIExposureAdjust", parameters: [
            kCIInputEVKey: ev
        ])
    }

    private func applyContrast(_ image: CIImage, amount: Double) -> CIImage {
        // Map -100...100 to 0.5...2.0
        let contrast = 1.0 + (amount / 100.0)
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: max(0.5, min(2.0, contrast))
        ])
    }

    private func applyHighlights(_ image: CIImage, amount: Double) -> CIImage {
        // Map -100...100 to recoverable highlights
        let highlightAmount = amount / 100.0
        return image.applyingFilter("CIHighlightShadowAdjust", parameters: [
            "inputHighlightAmount": 1.0 - highlightAmount
        ])
    }

    private func applyShadows(_ image: CIImage, amount: Double) -> CIImage {
        // Map -100...100 to shadow lift
        let shadowAmount = amount / 100.0
        return image.applyingFilter("CIHighlightShadowAdjust", parameters: [
            "inputShadowAmount": shadowAmount
        ])
    }

    private func applyWhites(_ image: CIImage, amount: Double) -> CIImage {
        // Simplified: adjust via curves (proper implementation would use tone curves)
        let gamma = 1.0 - (amount / 200.0)
        return image.applyingFilter("CIGammaAdjust", parameters: [
            "inputPower": max(0.5, min(1.5, gamma))
        ])
    }

    private func applyBlacks(_ image: CIImage, amount: Double) -> CIImage {
        // Simplified: adjust via black point
        let blackPoint = amount / 100.0
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: blackPoint * 0.1
        ])
    }

    private func applyTemperature(_ image: CIImage, offset: Double) -> CIImage {
        // Map -100...100 to temperature shift
        // Kelvin approximation: neutral = 6500K, range ±1000K
        let neutral: CIVector = CIVector(x: 6500, y: 0)
        let targetTemp = 6500 + (offset * 10)
        return image.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": neutral,
            "inputTargetNeutral": CIVector(x: targetTemp, y: 0)
        ])
    }

    private func applyTint(_ image: CIImage, offset: Double) -> CIImage {
        // Tint as green/magenta shift
        let neutral: CIVector = CIVector(x: 6500, y: 0)
        let tintShift = offset * 10
        return image.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": neutral,
            "inputTargetNeutral": CIVector(x: 6500, y: tintShift)
        ])
    }

    private func applyTexture(_ image: CIImage, amount: Double) -> CIImage {
        // Texture: high-frequency contrast boost
        guard amount != 0 else { return image }
        let intensity = amount / 100.0
        return image.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: intensity * 0.5
        ])
    }

    private func applyClarity(_ image: CIImage, amount: Double) -> CIImage {
        // Clarity: mid-tone contrast
        guard amount != 0 else { return image }
        let intensity = amount / 100.0
        return image.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputIntensityKey: abs(intensity),
            kCIInputRadiusKey: 20.0
        ])
    }

    private func applyDehaze(_ image: CIImage, amount: Double) -> CIImage {
        // Dehaze approximation: contrast + saturation boost
        guard amount != 0 else { return image }
        let intensity = amount / 100.0
        return image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.0 + (intensity * 0.3),
                kCIInputSaturationKey: 1.0 + (intensity * 0.2)
            ])
    }

    private func applySaturation(_ image: CIImage, amount: Double) -> CIImage {
        let saturation = 1.0 + (amount / 100.0)
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: max(0.0, min(2.0, saturation))
        ])
    }

    private func applyVibrance(_ image: CIImage, amount: Double) -> CIImage {
        // Vibrance: smart saturation (affects muted colors more)
        let vibrance = amount / 100.0
        return image.applyingFilter("CIVibrance", parameters: [
            "inputAmount": vibrance
        ])
    }

    private func applySharpening(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let intensity = amount / 100.0
        return image.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: intensity * 2.0
        ])
    }

    private func applyNoiseReduction(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let level = amount / 100.0
        return image.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": level * 0.1,
            kCIInputSharpnessKey: 1.0 - (level * 0.5)
        ])
    }

    private func applyVignette(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let intensity = amount / 100.0
        return image.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: abs(intensity),
            kCIInputRadiusKey: 1.0
        ])
    }

    private func applyGrain(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let intensity = amount / 100.0

        // Generate random noise
        let noiseGenerator = CIFilter.randomGenerator()
        guard let noise = noiseGenerator.outputImage else { return image }

        // Composite noise over image
        return image.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputImageKey: noise.cropped(to: image.extent)
                .applyingFilter("CIColorMonochrome", parameters: [
                    kCIInputIntensityKey: intensity * 0.2
                ])
        ])
    }

    // MARK: - Masked Adjustments (Phase 2)

    private func applyMasked(_ image: CIImage, instruction: EditInstruction, mask: CIImage) -> CIImage {
        let adjusted = applyGlobal(image, instruction: instruction)

        // Blend adjusted over original using mask
        return adjusted.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask
        ])
    }
}
