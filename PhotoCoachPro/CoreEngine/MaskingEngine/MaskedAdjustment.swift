//
//  MaskedAdjustment.swift
//  PhotoCoachPro
//
//  Applies EditInstruction through mask
//

import Foundation
import CoreImage

/// Applies selective adjustments using masks
actor MaskedAdjustmentEngine {
    private let editEngine: EditGraphEngine

    init(editEngine: EditGraphEngine) {
        self.editEngine = editEngine
    }

    // MARK: - Apply Masked Adjustments

    /// Apply single instruction through mask
    func applyMasked(
        _ image: CIImage,
        instruction: EditInstruction,
        mask: MaskLayer
    ) async -> CIImage {
        guard let maskImage = mask.processedMask(sourceSize: image.extent.size) else {
            return image
        }

        // Apply adjustment to entire image
        let adjusted = await editEngine.render(source: image, instructions: [instruction])

        // Blend adjusted over original using mask
        return blendWithMask(
            original: image,
            adjusted: adjusted,
            mask: maskImage
        )
    }

    /// Apply multiple instructions through same mask
    func applyMasked(
        _ image: CIImage,
        instructions: [EditInstruction],
        mask: MaskLayer
    ) async -> CIImage {
        guard let maskImage = mask.processedMask(sourceSize: image.extent.size) else {
            return image
        }

        // Apply all adjustments to entire image
        let adjusted = await editEngine.render(source: image, instructions: instructions)

        // Blend adjusted over original using mask
        return blendWithMask(
            original: image,
            adjusted: adjusted,
            mask: maskImage
        )
    }

    /// Apply instructions grouped by mask
    func applyMaskedAdjustments(
        _ image: CIImage,
        adjustments: [MaskID: [EditInstruction]],
        masks: [MaskID: MaskLayer]
    ) async -> CIImage {
        var result = image

        for (maskID, instructions) in adjustments {
            guard let mask = masks[maskID] else { continue }
            result = await applyMasked(result, instructions: instructions, mask: mask)
        }

        return result
    }

    // MARK: - Mask Blending

    private func blendWithMask(
        original: CIImage,
        adjusted: CIImage,
        mask: CIImage
    ) -> CIImage {
        // Use CIBlendWithMask to composite
        adjusted.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: original,
            kCIInputMaskImageKey: mask
        ])
    }

    // MARK: - Mask Preview

    /// Generate mask overlay for UI visualization
    func createMaskOverlay(
        mask: MaskLayer,
        sourceSize: CGSize,
        color: CIColor = CIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
    ) async -> CIImage? {
        guard let maskImage = mask.processedMask(sourceSize: sourceSize) else {
            return nil
        }

        // Create colored version of mask
        let coloredMask = maskImage.applyingFilter("CIConstantColorGenerator", parameters: [
            kCIInputColorKey: color
        ]).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: maskImage
        ])

        return coloredMask
    }

    /// Generate checkerboard pattern to show transparency
    func createMaskVisualization(
        mask: MaskLayer,
        sourceSize: CGSize
    ) async -> CIImage? {
        guard let maskImage = mask.processedMask(sourceSize: sourceSize) else {
            return nil
        }

        // Create checkerboard
        let checkerboard = CIFilter(
            name: "CICheckerboardGenerator",
            parameters: [
                "inputCenter": CIVector(x: 0, y: 0),
                "inputColor0": CIColor.white,
                "inputColor1": CIColor(red: 0.9, green: 0.9, blue: 0.9),
                "inputWidth": 20.0
            ]
        )?.outputImage?.cropped(to: CGRect(origin: .zero, size: sourceSize))

        guard let background = checkerboard else { return maskImage }

        // Composite mask over checkerboard
        return maskImage.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: background
        ])
    }
}

// MARK: - Type Aliases
typealias MaskID = UUID

// MARK: - Mask Groups
struct MaskGroup {
    var id: UUID
    var name: String
    var masks: [MaskLayer]
    var blendMode: MaskBlendMode

    enum MaskBlendMode: String, Codable {
        case add = "Add"
        case subtract = "Subtract"
        case intersect = "Intersect"
        case difference = "Difference"
    }

    /// Combine all masks in group according to blend mode
    func combinedMask() -> CIImage? {
        guard let first = masks.first?.maskImage else { return nil }

        var result = first

        for mask in masks.dropFirst() {
            guard let maskImage = mask.maskImage else { continue }

            switch blendMode {
            case .add:
                result = result.applyingFilter("CILightenBlendMode", parameters: [
                    kCIInputBackgroundImageKey: result,
                    kCIInputImageKey: maskImage
                ])
            case .subtract:
                let inverted = maskImage.applyingFilter("CIColorInvert")
                result = result.applyingFilter("CIDarkenBlendMode", parameters: [
                    kCIInputBackgroundImageKey: result,
                    kCIInputImageKey: inverted
                ])
            case .intersect:
                result = result.applyingFilter("CIDarkenBlendMode", parameters: [
                    kCIInputBackgroundImageKey: result,
                    kCIInputImageKey: maskImage
                ])
            case .difference:
                result = result.applyingFilter("CIDifferenceBlendMode", parameters: [
                    kCIInputBackgroundImageKey: result,
                    kCIInputImageKey: maskImage
                ])
            }
        }

        return result
    }
}
