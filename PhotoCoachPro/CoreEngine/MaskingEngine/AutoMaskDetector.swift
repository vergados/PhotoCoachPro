//
//  AutoMaskDetector.swift
//  PhotoCoachPro
//
//  Vision framework-based automatic masking
//

import Foundation
import CoreImage
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Automatic mask detection using Vision framework
actor AutoMaskDetector {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    // MARK: - Subject Detection

    /// Detect and mask subject (person or foreground object)
    func detectSubject(in image: CIImage) async throws -> MaskLayer {
        // Convert to CGImage for Vision
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw MaskDetectionError.conversionFailed
        }

        // Try person segmentation first
        if let personMask = try? await detectPerson(cgImage: cgImage) {
            return MaskLayer(
                name: "Subject (Person)",
                type: .subject,
                maskImage: personMask,
                featherRadius: 2.0
            )
        }

        // Fall back to foreground instance mask
        if #available(iOS 17.0, macOS 14.0, *) {
            if let foregroundMask = try? await detectForeground(cgImage: cgImage) {
                return MaskLayer(
                    name: "Subject (Foreground)",
                    type: .subject,
                    maskImage: foregroundMask,
                    featherRadius: 3.0
                )
            }
        }

        throw MaskDetectionError.noSubjectDetected
    }

    /// Detect person using VNGeneratePersonSegmentationRequest
    private func detectPerson(cgImage: CGImage) async throws -> CIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw MaskDetectionError.detectionFailed
        }

        let maskBuffer = result.pixelBuffer
        return CIImage(cvPixelBuffer: maskBuffer)
    }

    /// Detect foreground using VNGenerateForegroundInstanceMaskRequest
    @available(iOS 17.0, macOS 14.0, *)
    private func detectForeground(cgImage: CGImage) async throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw MaskDetectionError.detectionFailed
        }

        // Get the mask for all instances
        let allInstancesMask = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )

        return CIImage(cvPixelBuffer: allInstancesMask)
    }

    // MARK: - Sky Detection

    /// Detect sky region using blue-channel dominance and luminance gating.
    ///
    /// Sky pixels satisfy two conditions simultaneously:
    ///   1. Blue dominance: B > avg(R, G) by a margin.
    ///      Computed via CIColorMatrix: out = B − 0.5·(R+G) + 0.5 bias → threshold at 0.57.
    ///   2. Brightness: Rec.709 luma > 0.40 (excludes night sky and dark shadows).
    /// The two binary masks are multiplied (AND) to produce the final sky mask.
    func detectSky(in image: CIImage) async throws -> MaskLayer {
        // Blue-channel dominance: out_channel = −0.5·R − 0.5·G + 1.0·B + 0.5 bias
        // Pure sky-blue (0.53, 0.81, 0.98) → 0.81  ≥ threshold
        // White clouds   (0.95, 0.95, 0.95) → 0.50  < threshold
        // Pure green/red (0 or 1, 0, 0)     → 0.00  < threshold
        let blueDom = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector":    CIVector(x: -0.5,  y: -0.5,  z: 1.0,   w: 0),
            "inputGVector":    CIVector(x: -0.5,  y: -0.5,  z: 1.0,   w: 0),
            "inputBVector":    CIVector(x: -0.5,  y: -0.5,  z: 1.0,   w: 0),
            "inputAVector":    CIVector(x: 0,     y: 0,     z: 0,     w: 1),
            "inputBiasVector": CIVector(x: 0.5,   y: 0.5,   z: 0.5,   w: 0)
        ])
        let blueMask = blueDom.applyingFilter("CIColorThreshold",
                                               parameters: ["inputThreshold": 0.57])

        // Rec.709 luminance gate — all three output channels carry the same luma value
        let luma = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector":    CIVector(x: 0,      y: 0,      z: 0,      w: 1),
            "inputBiasVector": CIVector(x: 0,      y: 0,      z: 0,      w: 0)
        ])
        let lumaMask = luma.applyingFilter("CIColorThreshold",
                                            parameters: ["inputThreshold": 0.40])

        // Pixel-wise AND: sky = blue-dominant ∧ bright
        let skyMask = blueMask.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: lumaMask
        ])

        return MaskLayer(
            name: "Sky",
            type: .sky,
            maskImage: skyMask,
            featherRadius: 10.0
        )
    }

    // MARK: - Background Detection

    /// Detect background (inverse of subject)
    func detectBackground(in image: CIImage) async throws -> MaskLayer {
        var subjectMask = try await detectSubject(in: image)

        // Invert the subject mask
        subjectMask.inverted = true
        subjectMask.name = "Background"
        subjectMask.type = .background

        return subjectMask
    }

    // MARK: - Saliency Detection

    /// Detect salient regions (areas of interest)
    func detectSaliency(in image: CIImage) async throws -> MaskLayer {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw MaskDetectionError.conversionFailed
        }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw MaskDetectionError.detectionFailed
        }

        let maskBuffer = result.pixelBuffer
        let saliencyMask = CIImage(cvPixelBuffer: maskBuffer)

        return MaskLayer(
            name: "Salient Regions",
            type: .subject,
            maskImage: saliencyMask,
            featherRadius: 5.0
        )
    }

    // MARK: - Color Range Mask

    /// Create mask from color range using CIColorCube
    func maskFromColorRange(
        in image: CIImage,
        targetColor: CIColor,
        tolerance: Double = 0.2
    ) async -> MaskLayer {
        let dimension = 64
        let cubeData = buildColorCubeData(targetColor: targetColor, tolerance: tolerance, dimension: dimension)

        let mask = image.applyingFilter("CIColorCube", parameters: [
            "inputCubeDimension": dimension,
            "inputCubeData": cubeData as NSData
        ])

        return MaskLayer(
            name: "Color Range",
            type: .color,
            maskImage: mask,
            featherRadius: 3.0
        )
    }

    /// Build a 64^3 color cube lookup table.
    /// Each cube entry maps an input RGB to a grayscale output:
    /// - brightness = 1 at the target color, falling to 0 at the tolerance boundary.
    private func buildColorCubeData(targetColor: CIColor, tolerance: Double, dimension: Int) -> Data {
        let dim = dimension
        let tol = max(Float(tolerance), 0.001)
        let tr = Float(targetColor.red)
        let tg = Float(targetColor.green)
        let tb = Float(targetColor.blue)

        var data = [Float](repeating: 0, count: dim * dim * dim * 4)

        for b in 0..<dim {
            for g in 0..<dim {
                for r in 0..<dim {
                    let fr = Float(r) / Float(dim - 1)
                    let fg = Float(g) / Float(dim - 1)
                    let fb = Float(b) / Float(dim - 1)

                    // Euclidean distance in RGB space (each channel in 0...1)
                    let dr = fr - tr
                    let dg = fg - tg
                    let db = fb - tb
                    let dist = sqrt(dr * dr + dg * dg + db * db)

                    // Smooth falloff: 1 at center, 0 at the tolerance boundary
                    let strength = max(0.0, 1.0 - dist / tol)

                    let index = (b * dim * dim + g * dim + r) * 4
                    // Grayscale mask: strength encoded in R, G, B; alpha always opaque
                    data[index + 0] = strength
                    data[index + 1] = strength
                    data[index + 2] = strength
                    data[index + 3] = 1.0
                }
            }
        }

        return data.withUnsafeBytes { Data($0) }
    }

    // MARK: - Luminance Mask

    /// Create mask from luminance range using dual thresholds
    func maskFromLuminanceRange(
        in image: CIImage,
        minLuminance: Double = 0.0,
        maxLuminance: Double = 1.0
    ) async -> MaskLayer {
        // Convert to grayscale
        let grayscale = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // Lower bound: pixels brighter than minLuminance → white
        let lowerMask = grayscale.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": minLuminance
        ])

        // Upper bound: pixels darker than maxLuminance → white (threshold at max, then invert)
        let upperMask = grayscale
            .applyingFilter("CIColorThreshold", parameters: [
                "inputThreshold": maxLuminance
            ])
            .applyingFilter("CIColorInvert")

        // Combine: only pixels that pass both bounds
        let mask = lowerMask.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: upperMask
        ])

        return MaskLayer(
            name: "Luminance Range",
            type: .luminance,
            maskImage: mask,
            featherRadius: 5.0
        )
    }
}

// MARK: - Errors

enum MaskDetectionError: Error, LocalizedError {
    case conversionFailed
    case detectionFailed
    case noSubjectDetected
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image for mask detection"
        case .detectionFailed:
            return "Mask detection failed"
        case .noSubjectDetected:
            return "No subject detected in image"
        case .unsupportedPlatform:
            return "Mask detection not available on this platform version"
        }
    }
}
