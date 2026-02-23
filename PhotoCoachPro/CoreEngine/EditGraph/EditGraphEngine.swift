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

    /// Render image with all active instructions applied.
    /// Instructions with a maskID are applied after all globals, skipped when no masks are loaded.
    func render(source: CIImage, instructions: [EditInstruction]) async -> CIImage {
        await render(source: source, instructions: instructions, masks: [:])
    }

    /// Full render pipeline supporting both global and mask-scoped adjustments.
    /// - Global instructions (maskID == nil) are applied first with crop/curve ordering.
    /// - Masked instructions are applied after globals, blended via their mask image.
    func render(source: CIImage, instructions: [EditInstruction], masks: [UUID: CIImage]) async -> CIImage {
        var result = source
        let globalInstructions = instructions.filter { $0.maskID == nil }
        let maskedInstructions = instructions.filter { $0.maskID != nil }

        // 1. Apply crop first (coordinates are relative to original source extent)
        let cropTypes: Set<EditInstruction.EditType> = [.cropX, .cropY, .cropWidth, .cropHeight]
        if globalInstructions.contains(where: { cropTypes.contains($0.type) }) {
            result = applyCrop(result, instructions: globalInstructions)
        }

        // 2. Apply global adjustments in order (crop geometry and tone curve are pass-throughs)
        for instruction in globalInstructions {
            result = applyGlobal(result, instruction: instruction)
        }

        // 3. Apply tone curve last for global pass
        if let curveInstruction = globalInstructions.last(where: { $0.type == .toneCurveControlPoint }) {
            result = applyToneCurve(result, instruction: curveInstruction)
        }

        // 4. Apply masked adjustments (blended into the composited result using each mask)
        for instruction in maskedInstructions {
            guard let maskID = instruction.maskID, let mask = masks[maskID] else { continue }
            result = applyMasked(result, instruction: instruction, mask: mask)
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

        // MARK: Extended Sharpening
        case .sharpRadius:
            return applySharpRadius(image, radius: instruction.value)
        case .sharpMasking:
            return applySharpMasking(image, threshold: instruction.value)

        // MARK: Extended Noise Reduction
        case .noiseDetail:
            return applyNoiseDetail(image, amount: instruction.value)
        case .colorNoiseReduction:
            return applyColorNoiseReduction(image, amount: instruction.value)

        // MARK: Lens Corrections
        case .lensCorrection:
            return applyLensCorrection(image, amount: instruction.value)
        case .perspectiveVertical:
            return applyPerspectiveVertical(image, amount: instruction.value)
        case .perspectiveHorizontal:
            return applyPerspectiveHorizontal(image, amount: instruction.value)
        case .distortion:
            return applyDistortion(image, amount: instruction.value)

        // MARK: Geometry
        case .straighten, .cropRotation:
            return applyRotation(image, degrees: instruction.value)

        // MARK: Extended Vignette
        case .vignetteMidpoint:
            return applyVignetteMidpoint(image, midpoint: instruction.value)
        case .vignetteRoundness:
            return image // CIVignette has no roundness param; pass-through

        // MARK: Extended Grain
        case .grainSize:
            return applyGrainSize(image, size: instruction.value)
        case .grainRoughness:
            return applyGrainRoughness(image, roughness: instruction.value)

        // MARK: HSL
        case .hslHue:
            return applyHSLHue(image, degrees: instruction.value)
        case .hslSaturation:
            return applyHSLSaturation(image, amount: instruction.value)
        case .hslLuminance:
            return applyHSLLuminance(image, amount: instruction.value)

        // MARK: Tone Curve / Crop (managed in view state)
        case .toneCurveControlPoint:
            return image // Tone curve points stored in view; pass-through
        case .cropX, .cropY, .cropWidth, .cropHeight:
            return image // Crop geometry managed by CropView; pass-through
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
        // Map -100...100 to recoverable highlights.
        // inputHighlightAmount: 1.0 = no compression (default), 0.0 = full highlight recovery.
        // Negative amount = recover highlights → subtract from 1.0 toward 0.0.
        let highlightAmount = amount / 100.0
        return image.applyingFilter("CIHighlightShadowAdjust", parameters: [
            "inputHighlightAmount": max(0.0, min(1.0, 1.0 + highlightAmount))
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
        guard amount != 0 else { return image }
        let t = amount / 100.0  // -1 to +1
        // Only the highlights zone moves; midtones and below are pinned to identity.
        // Positive: pull shoulder up toward white (brighter highlights).
        // Negative: lower white point for a matte/crushed-highlight look.
        let p3y = max(0, min(1, 0.75 + 0.17 * t))           // shoulder: 0.75 → 0.92 at +100
        let p4y = max(0, min(1, 1.0 + 0.20 * min(0, t)))    // white pt: stays 1.0 above zero, drops to 0.80 at -100
        return image.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0,    y: 0),
            "inputPoint1": CIVector(x: 0.25, y: 0.25),
            "inputPoint2": CIVector(x: 0.5,  y: 0.5),
            "inputPoint3": CIVector(x: 0.75, y: p3y),
            "inputPoint4": CIVector(x: 1.0,  y: p4y)
        ])
    }

    private func applyBlacks(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let t = amount / 100.0  // -1 to +1
        // Only the shadows zone moves; midtones and above are pinned to identity.
        // Positive: lift black point (open shadows, hazy look).
        // Negative: crush shadow shoulder deeper toward black.
        let p0y = max(0, min(1, 0.10 * max(0, t)))           // black pt: 0 → 0.10 at +100, stays 0 when negative
        let p1y = max(0, min(1, 0.25 + 0.10 * t))            // shadow shoulder: 0.35 at +100, 0.15 at -100
        return image.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0,    y: p0y),
            "inputPoint1": CIVector(x: 0.25, y: p1y),
            "inputPoint2": CIVector(x: 0.5,  y: 0.5),
            "inputPoint3": CIVector(x: 0.75, y: 0.75),
            "inputPoint4": CIVector(x: 1.0,  y: 1.0)
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
            kCIInputIntensityKey: intensity,
            kCIInputRadiusKey: 1.0
        ])
    }

    private func applyGrain(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let intensity = amount / 100.0

        // Generate random noise
        guard let noiseGenerator = CIFilter(name: "CIRandomGenerator"),
              let noise = noiseGenerator.outputImage else { return image }

        // Composite noise over image — use intensity 1.0 so grain is fully monochromatic
        // gray, not colorful random speckles
        return image.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputImageKey: noise.cropped(to: image.extent)
                .applyingFilter("CIColorMonochrome", parameters: [
                    kCIInputIntensityKey: 1.0,
                    kCIInputColorKey: CIColor(red: intensity * 0.2, green: intensity * 0.2, blue: intensity * 0.2)
                ])
        ])
    }

    // MARK: - Extended Sharpening

    private func applySharpRadius(_ image: CIImage, radius: Double) -> CIImage {
        guard radius > 0.5 else { return image }
        return image.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: radius,
            kCIInputIntensityKey: 0.5
        ])
    }

    private func applySharpMasking(_ image: CIImage, threshold: Double) -> CIImage {
        guard threshold > 0 else { return image }
        let t = threshold / 100.0
        let sharpened = image.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 1.5
        ])
        let edges = image.applyingFilter("CIEdges", parameters: [
            kCIInputIntensityKey: t * 8.0
        ])
        return sharpened.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: edges
        ])
    }

    // MARK: - Extended Noise Reduction

    private func applyNoiseDetail(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let level = amount / 100.0
        return image.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": level * 0.05,
            kCIInputSharpnessKey: 0.8
        ])
    }

    private func applyColorNoiseReduction(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let level = amount / 100.0
        return image.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": level * 0.08,
            kCIInputSharpnessKey: 0.5
        ])
    }

    // MARK: - Lens Corrections

    private func applyLensCorrection(_ image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else { return image }
        let intensity = amount / 100.0
        return image.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: intensity * 0.4
        ])
    }

    private func applyPerspectiveVertical(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let shear = amount / 100.0 * 0.3
        let transform = CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0)
        return image.transformed(by: transform)
    }

    private func applyPerspectiveHorizontal(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let shear = amount / 100.0 * 0.3
        let transform = CGAffineTransform(a: 1, b: shear, c: 0, d: 1, tx: 0, ty: 0)
        return image.transformed(by: transform)
    }

    private func applyDistortion(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let center = CIVector(x: image.extent.midX, y: image.extent.midY)
        let radius = min(image.extent.width, image.extent.height) * 0.5
        let scale = (amount / 100.0) * 0.5
        return image.applyingFilter("CIBumpDistortion", parameters: [
            kCIInputCenterKey: center,
            kCIInputRadiusKey: radius,
            kCIInputScaleKey: scale
        ])
    }

    // MARK: - Geometry

    private func applyRotation(_ image: CIImage, degrees: Double) -> CIImage {
        guard degrees != 0 else { return image }
        let radians = degrees * .pi / 180.0
        let transform = CGAffineTransform(rotationAngle: radians)
        return image.transformed(by: transform)
    }

    // MARK: - Extended Vignette

    private func applyVignetteMidpoint(_ image: CIImage, midpoint: Double) -> CIImage {
        guard midpoint > 0 else { return image }
        let radius = (midpoint / 100.0) * 2.0
        return image.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: 0.5,
            kCIInputRadiusKey: radius
        ])
    }

    // MARK: - Extended Grain

    private func applyGrainSize(_ image: CIImage, size: Double) -> CIImage {
        guard size > 0 else { return image }
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let noise = noiseFilter.outputImage else { return image }
        let blurred = noise.cropped(to: image.extent).applyingGaussianBlur(sigma: size / 100.0 * 3.0)
        return image.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputImageKey: blurred.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputIntensityKey: 0.08
            ])
        ])
    }

    private func applyGrainRoughness(_ image: CIImage, roughness: Double) -> CIImage {
        guard roughness > 0 else { return image }
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let noise = noiseFilter.outputImage else { return image }
        let intensity = roughness / 100.0 * 0.15
        return image.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputImageKey: noise.cropped(to: image.extent).applyingFilter("CIColorMonochrome", parameters: [
                kCIInputIntensityKey: intensity
            ])
        ])
    }

    // MARK: - HSL Adjustments

    private func applyHSLHue(_ image: CIImage, degrees: Double) -> CIImage {
        guard degrees != 0 else { return image }
        let angle = degrees * .pi / 180.0
        return image.applyingFilter("CIHueAdjust", parameters: [
            kCIInputAngleKey: angle
        ])
    }

    private func applyHSLSaturation(_ image: CIImage, amount: Double) -> CIImage {
        let saturation = 1.0 + (amount / 100.0)
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: max(0.0, min(2.0, saturation))
        ])
    }

    private func applyHSLLuminance(_ image: CIImage, amount: Double) -> CIImage {
        let brightness = (amount / 100.0) * 0.2
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: brightness
        ])
    }

    // MARK: - Tone Curve

    private func applyToneCurve(_ image: CIImage, instruction: EditInstruction) -> CIImage {
        guard let pointsStr = instruction.metadata["points"] else { return image }

        // Parse "x1,y1;x2,y2;..." into sorted (x, y) pairs
        let rawPoints: [(Double, Double)] = pointsStr
            .split(separator: ";")
            .compactMap { pair -> (Double, Double)? in
                let coords = pair.split(separator: ",")
                guard coords.count == 2,
                      let x = Double(coords[0]),
                      let y = Double(coords[1]) else { return nil }
                return (x, y)
            }
            .sorted { $0.0 < $1.0 }

        guard !rawPoints.isEmpty else { return image }

        // CIToneCurve requires exactly 5 CIVector points
        let targetX: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
        let vectors = targetX.map { x -> CIVector in
            CIVector(x: x, y: interpolateY(at: x, from: rawPoints))
        }

        return image.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": vectors[0],
            "inputPoint1": vectors[1],
            "inputPoint2": vectors[2],
            "inputPoint3": vectors[3],
            "inputPoint4": vectors[4]
        ])
    }

    private func interpolateY(at x: Double, from points: [(Double, Double)]) -> Double {
        guard !points.isEmpty else { return x }
        if let exact = points.first(where: { abs($0.0 - x) < 0.0001 }) { return exact.1 }
        let lower = points.last(where: { $0.0 < x })
        let upper = points.first(where: { $0.0 > x })
        switch (lower, upper) {
        case (nil, let u?): return u.1
        case (let l?, nil): return l.1
        case (let l?, let u?):
            let t = (x - l.0) / (u.0 - l.0)
            return l.1 + t * (u.1 - l.1)
        default: return x
        }
    }

    // MARK: - Crop Geometry

    private func applyCrop(_ image: CIImage, instructions: [EditInstruction]) -> CIImage {
        let cropX = instructions.last(where: { $0.type == .cropX })?.value ?? 0.0
        let cropY = instructions.last(where: { $0.type == .cropY })?.value ?? 0.0
        let cropWidth = instructions.last(where: { $0.type == .cropWidth })?.value ?? 1.0
        let cropHeight = instructions.last(where: { $0.type == .cropHeight })?.value ?? 1.0

        guard cropWidth > 0, cropHeight > 0 else { return image }
        guard !(cropX == 0 && cropY == 0 && cropWidth >= 1 && cropHeight >= 1) else { return image }

        let extent = image.extent
        let rect = CGRect(
            x: extent.minX + cropX * extent.width,
            y: extent.minY + cropY * extent.height,
            width: cropWidth * extent.width,
            height: cropHeight * extent.height
        )

        // Crop and translate to origin so downstream filters work correctly
        return image
            .cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }

    // MARK: - Masked Adjustments (Phase 2)

    private func applyMasked(_ image: CIImage, instruction: EditInstruction, mask: CIImage) -> CIImage {
        let adjusted = applyGlobal(image, instruction: instruction)

        // Soften mask edges with Gaussian blur for natural local-adjustment transitions.
        // clampedToExtent() prevents the blur from reading transparent pixels at the boundary;
        // cropping back afterward restores the original extent.
        let softMask = mask.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 20.0])
            .cropped(to: mask.extent)

        return adjusted.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: softMask
        ])
    }
}
