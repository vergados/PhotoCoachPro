//
//  DPIUpscaler.swift
//  PhotoCoachPro
//
//  Upscales images using advanced interpolation and AI-based techniques
//

import Foundation
import CoreImage
import CoreGraphics
import Accelerate

/// Upscales images while preserving quality
actor DPIUpscaler {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])) {
        self.context = context
    }

    // MARK: - Public Interface

    /// Upscale an image by a given factor
    /// - Parameters:
    ///   - image: Source image
    ///   - scale: Upscaling factor (2.0 = double resolution, 4.0 = quadruple)
    ///   - method: Upscaling method to use
    /// - Returns: Upscaled image
    func upscale(image: CIImage, scale: CGFloat, method: UpscalingMethod = .lanczos) async throws -> CIImage {
        guard scale > 1.0 else {
            throw UpscalingError.invalidScale
        }

        print("📐 Upscaling image by \(scale)x using \(method)")

        let upscaled = try await applyUpscaling(image: image, scale: scale, method: method)

        print("✅ Upscaling complete")
        return upscaled
    }

    /// Get output dimensions for a given scale
    func outputDimensions(for image: CIImage, scale: CGFloat) -> CGSize {
        let extent = image.extent
        return CGSize(
            width: extent.width * scale,
            height: extent.height * scale
        )
    }

    /// Calculate DPI for output.
    /// Upscaling adds pixels so the image can be printed larger at the same DPI —
    /// the pixel density (DPI) of the output stays constant while print dimensions grow.
    /// - Parameters:
    ///   - originalDPI: Original image DPI
    ///   - scale: Upscaling factor
    /// - Returns: Effective output DPI (unchanged; total resolution increases by scale²)
    func outputDPI(originalDPI: CGFloat, scale: CGFloat) -> CGFloat {
        return originalDPI
    }

    // MARK: - Upscaling Methods

    private func applyUpscaling(image: CIImage, scale: CGFloat, method: UpscalingMethod) async throws -> CIImage {
        switch method {
        case .bicubic:
            return await bicubicUpscale(image: image, scale: scale)
        case .lanczos:
            return await lanczosUpscale(image: image, scale: scale)
        case .edgePreserving:
            return await edgePreservingUpscale(image: image, scale: scale)
        case .aiEnhanced:
            return await aiEnhancedUpscale(image: image, scale: scale)
        }
    }

    // MARK: - Bicubic Upscaling

    /// Upscales using Accelerate's vImageScale_ARGB8888 with kvImageHighQualityResampling,
    /// which applies a Lanczos-5 kernel — significantly sharper than bilinear with fewer
    /// ringing artifacts than naive bicubic.
    private func bicubicUpscale(image: CIImage, scale: CGFloat) async -> CIImage {
        let extent    = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let srcWidth  = Int(extent.width)
        let srcHeight = Int(extent.height)
        let dstWidth  = max(1, Int((extent.width  * scale).rounded()))
        let dstHeight = max(1, Int((extent.height * scale).rounded()))
        let bpp       = 4
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        // Render source pixels into a flat byte buffer
        let normalized    = image.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        let srcBytesPerRow = srcWidth * bpp
        var srcBytes = [UInt8](repeating: 0, count: srcHeight * srcBytesPerRow)
        context.render(
            normalized,
            toBitmap: &srcBytes,
            rowBytes: srcBytesPerRow,
            bounds: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight),
            format: .ARGB8,
            colorSpace: colorSpace)

        // Destination buffer
        let dstBytesPerRow = dstWidth * bpp
        var dstBytes = [UInt8](repeating: 0, count: dstHeight * dstBytesPerRow)

        // vImage high-quality resampling (Lanczos-5 kernel).
        // withUnsafeMutableBytes pins the buffer address for the duration of the call.
        let vErr = srcBytes.withUnsafeMutableBytes { srcRaw -> vImage_Error in
            dstBytes.withUnsafeMutableBytes { dstRaw -> vImage_Error in
                var srcBuffer = vImage_Buffer(
                    data: srcRaw.baseAddress,
                    height: vImagePixelCount(srcHeight),
                    width: vImagePixelCount(srcWidth),
                    rowBytes: srcBytesPerRow)
                var dstBuffer = vImage_Buffer(
                    data: dstRaw.baseAddress,
                    height: vImagePixelCount(dstHeight),
                    width: vImagePixelCount(dstWidth),
                    rowBytes: dstBytesPerRow)
                return vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil,
                                           vImage_Flags(kvImageHighQualityResampling))
            }
        }
        guard vErr == kvImageNoError else {
            return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        // Reconstruct CIImage from scaled buffer
        let data = Data(dstBytes)
        let result = CIImage(
            bitmapData: data,
            bytesPerRow: dstBytesPerRow,
            size: CGSize(width: dstWidth, height: dstHeight),
            format: .ARGB8,
            colorSpace: colorSpace)

        // Restore original extent origin
        return result.transformed(
            by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    // MARK: - Lanczos Upscaling (High Quality)

    private func lanczosUpscale(image: CIImage, scale: CGFloat) async -> CIImage {
        // Use Core Image's Lanczos scale transform for high-quality upscaling
        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
        scaleFilter.setValue(image, forKey: kCIInputImageKey)
        scaleFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        return scaleFilter.outputImage ?? image
    }

    // MARK: - Edge-Preserving Upscaling

    private func edgePreservingUpscale(image: CIImage, scale: CGFloat) async -> CIImage {
        // First, upscale with Lanczos
        var upscaled = await lanczosUpscale(image: image, scale: scale)

        // Apply edge detection and sharpening to preserve details
        let edges = upscaled.applyingFilter("CIEdges", parameters: [
            kCIInputIntensityKey: 2.0
        ])

        // Sharpen the upscaled image
        upscaled = upscaled.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 2.5,
            kCIInputIntensityKey: 0.5
        ])

        // Blend edges back in for enhanced detail using Screen mode:
        // Screen = 1-(1-src)*(1-bg) stays bounded in [0,1], avoiding the highlight
        // blow-out caused by CIAdditionCompositing's raw src+dst addition.
        let blended = edges.applyingFilter("CIScreenBlendMode", parameters: [
            kCIInputBackgroundImageKey: upscaled
        ])

        return blended
    }

    // MARK: - AI-Enhanced Upscaling

    private func aiEnhancedUpscale(image: CIImage, scale: CGFloat) async -> CIImage {
        // Start with Lanczos upscaling
        var upscaled = await lanczosUpscale(image: image, scale: scale)

        // Apply multiple enhancement passes

        // Pass 1: Noise reduction (important after upscaling)
        upscaled = upscaled.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": 0.02,
            kCIInputSharpnessKey: 0.4
        ])

        // Pass 2: Detail enhancement
        upscaled = upscaled.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.7
        ])

        // Pass 3: Color vibrance enhancement
        upscaled = upscaled.applyingFilter("CIVibrance", parameters: [
            "inputAmount": 0.3
        ])

        // Pass 4: Subtle contrast adjustment
        upscaled = upscaled.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.1
        ])

        return upscaled
    }
}

// MARK: - Upscaling Method

enum UpscalingMethod: String, CaseIterable {
    case bicubic = "Bicubic"
    case lanczos = "Lanczos (Recommended)"
    case edgePreserving = "Edge Preserving"
    case aiEnhanced = "AI Enhanced"

    var description: String {
        switch self {
        case .bicubic:
            return "Fast, basic quality upscaling"
        case .lanczos:
            return "High quality interpolation (recommended for photos)"
        case .edgePreserving:
            return "Preserves sharp edges and fine details"
        case .aiEnhanced:
            return "Multi-pass enhancement with noise reduction and sharpening"
        }
    }
}

// MARK: - Errors

enum UpscalingError: LocalizedError {
    case invalidScale
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidScale:
            return "Upscaling factor must be greater than 1.0"
        case .processingFailed:
            return "Failed to process image upscaling"
        }
    }
}
