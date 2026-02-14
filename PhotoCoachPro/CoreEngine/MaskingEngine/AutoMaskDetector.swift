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
        if let foregroundMask = try? await detectForeground(cgImage: cgImage) {
            return MaskLayer(
                name: "Subject (Foreground)",
                type: .subject,
                maskImage: foregroundMask,
                featherRadius: 3.0
            )
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

    /// Detect sky region
    func detectSky(in image: CIImage) async throws -> MaskLayer {
        // Simplified sky detection using color and luminance
        // Professional version would use ML model

        let skyMask = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0
            ])
            .applyingFilter("CIColorThreshold", parameters: [
                "inputThreshold": 0.7  // Bright regions
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

    /// Create mask from color range
    func maskFromColorRange(
        in image: CIImage,
        targetColor: CIColor,
        tolerance: Double = 0.2
    ) async -> MaskLayer {
        // Use CIColorCube for color selection
        let mask = image.applyingFilter("CIColorCube", parameters: [
            "inputCubeDimension": 64,
            // Color cube data would be generated based on target color and tolerance
        ])

        return MaskLayer(
            name: "Color Range",
            type: .color,
            maskImage: mask,
            featherRadius: 3.0
        )
    }

    // MARK: - Luminance Mask

    /// Create mask from luminance range
    func maskFromLuminanceRange(
        in image: CIImage,
        minLuminance: Double = 0.0,
        maxLuminance: Double = 1.0
    ) async -> MaskLayer {
        // Convert to grayscale
        let grayscale = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // Apply threshold
        let mask = grayscale.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": (minLuminance + maxLuminance) / 2.0
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
