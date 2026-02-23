//
//  PanoramaStitcher.swift
//  PhotoCoachPro
//
//  Stitches multiple photos into a panorama using Core Image and Vision
//

import Foundation
import CoreImage
import CoreGraphics
import Vision

/// Projection mode for panorama stitching
enum ProjectionMode {
    case planar      // Standard flat projection
    case cylindrical // Cylindrical projection (better for wide panoramas)
}

/// Stitches multiple images into a panorama
actor PanoramaStitcher {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])) {
        self.context = context
    }

    // MARK: - Public Interface

    /// Stitch multiple images into a panorama
    /// - Parameters:
    ///   - images: Array of images in left-to-right order
    ///   - blendWidth: Width of blending region in pixels (default: 100)
    ///   - projectionMode: Projection mode (planar or cylindrical, default: cylindrical)
    ///   - useExposureBlending: Apply exposure compensation for seamless blending (default: true)
    /// - Returns: Stitched panorama image
    func stitch(images: [CIImage], blendWidth: CGFloat = 100, projectionMode: ProjectionMode = .cylindrical, useExposureBlending: Bool = true) async throws -> CIImage {
        guard images.count >= 2 else {
            throw PanoramaError.notEnoughImages
        }

        print("🧩 Starting panorama stitch with \(images.count) images (projection: \(projectionMode), exposure blending: \(useExposureBlending))")

        // Apply projection warping if needed
        let projectedImages: [CIImage]
        if projectionMode == .cylindrical {
            projectedImages = try await applyCylindricalProjection(images)
        } else {
            projectedImages = images
        }

        // Apply exposure compensation if enabled
        let exposureAdjusted: [CIImage]
        if useExposureBlending {
            exposureAdjusted = await compensateExposure(projectedImages)
        } else {
            exposureAdjusted = projectedImages
        }

        // Align images using feature detection
        let alignedImages = try await alignImages(exposureAdjusted)

        // Blend images together
        let stitched = await blendImages(alignedImages, blendWidth: blendWidth)

        print("✅ Panorama stitched successfully")
        return stitched
    }

    // MARK: - Cylindrical Projection

    private func applyCylindricalProjection(_ images: [CIImage]) async throws -> [CIImage] {
        print("  🌐 Applying cylindrical projection...")

        var projectedImages: [CIImage] = []

        for (index, image) in images.enumerated() {
            let projected = try await projectImageToCylinder(image)
            projectedImages.append(projected)
            print("  ✓ Projected image \(index + 1)/\(images.count)")
        }

        return projectedImages
    }

    /// Projects a flat image onto a cylinder using real per-pixel inverse mapping.
    ///
    /// Forward projection (flat → cylindrical):
    ///   xc = f · atan((x − cx) / f),   yc = (y − cy) · f / √((x−cx)² + f²)
    ///
    /// Inverse (used here, cylindrical → flat):
    ///   x  = f · tan(xc / f) + cx,      y  = yc / cos(xc / f) + cy
    ///
    /// Focal length is estimated assuming ≈ 60° horizontal FOV (typical phone camera):
    ///   f = (w/2) / tan(30°) ≈ w · 0.866
    private func projectImageToCylinder(_ image: CIImage) async throws -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let width    = Int(extent.width)
        let height   = Int(extent.height)
        let bpp      = 4
        let rowBytes = width * bpp

        // Normalize image to origin so render bounds align with pixel indices
        let normalized = image.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))

        var srcBytes = [UInt8](repeating: 0, count: height * rowBytes)
        context.render(
            normalized,
            toBitmap: &srcBytes,
            rowBytes: rowBytes,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB))

        let f  = Double(width)  * 0.866   // focal length in pixels
        let cx = Double(width)  * 0.5
        let cy = Double(height) * 0.5

        var dstBytes = [UInt8](repeating: 0, count: height * rowBytes)

        for row in 0..<height {
            let yc = Double(row) - cy
            for col in 0..<width {
                let xc       = Double(col) - cx
                let theta    = xc / f
                let cosTheta = cos(theta)
                guard abs(cosTheta) > 1e-6 else { continue }

                let srcX = f * tan(theta) + cx
                let srcY = yc / cosTheta  + cy

                guard srcX >= 0, srcY >= 0,
                      srcX < Double(width)  - 1,
                      srcY < Double(height) - 1 else { continue }

                // Bilinear interpolation
                let x0 = Int(srcX); let x1 = x0 + 1
                let y0 = Int(srcY); let y1 = y0 + 1
                let fx = srcX - Double(x0)
                let fy = srcY - Double(y0)

                let dstIdx = row * rowBytes + col * bpp
                let i00    = y0 * rowBytes + x0 * bpp
                let i10    = y0 * rowBytes + x1 * bpp
                let i01    = y1 * rowBytes + x0 * bpp
                let i11    = y1 * rowBytes + x1 * bpp

                for c in 0..<3 {
                    let v = Double(srcBytes[i00+c]) * (1-fx) * (1-fy)
                          + Double(srcBytes[i10+c]) * fx     * (1-fy)
                          + Double(srcBytes[i01+c]) * (1-fx) * fy
                          + Double(srcBytes[i11+c]) * fx     * fy
                    dstBytes[dstIdx + c] = UInt8(max(0, min(255, v.rounded())))
                }
                dstBytes[dstIdx + 3] = 255  // fully opaque
            }
        }

        let data = Data(dstBytes)
        let result = CIImage(
            bitmapData: data,
            bytesPerRow: rowBytes,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB))

        // Restore original extent origin so the downstream pipeline is unaffected
        return result.transformed(
            by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    // MARK: - Image Alignment

    private func alignImages(_ images: [CIImage]) async throws -> [CIImage] {
        guard images.count >= 2 else { return images }

        var aligned: [CIImage] = [images[0]]
        var currentOffset = CGPoint.zero

        for i in 1..<images.count {
            let previous = aligned[i - 1]
            let current = images[i]

            // Find features in both images
            let offset = try await findAlignment(reference: previous, target: current)

            // Accumulate offset
            currentOffset = CGPoint(
                x: currentOffset.x + offset.x,
                y: currentOffset.y + offset.y
            )

            // Apply translation
            let transform = CGAffineTransform(translationX: currentOffset.x, y: currentOffset.y)
            let alignedImage = current.transformed(by: transform)

            aligned.append(alignedImage)

            print("  ✓ Aligned image \(i+1)/\(images.count) with offset: (\(offset.x), \(offset.y))")
        }

        return aligned
    }

    private func findAlignment(reference: CIImage, target: CIImage) async throws -> CGPoint {
        // Use Vision framework for accurate feature-based alignment

        let referenceExtent = reference.extent
        let targetExtent = target.extent

        // Convert CIImage to CGImage for Vision framework
        guard let referenceCG = context.createCGImage(reference, from: referenceExtent),
              let targetCG = context.createCGImage(target, from: targetExtent) else {
            throw PanoramaError.alignmentFailed
        }

        // Create a registration request with the reference image
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: referenceCG)

        // Perform the request on the target image
        let handler = VNImageRequestHandler(cgImage: targetCG, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("⚠️ Vision alignment failed, using fallback: \(error.localizedDescription)")
            return try await findAlignmentFallback(reference: reference, target: target)
        }

        // Get the alignment transform
        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            print("⚠️ No alignment results, using fallback")
            return try await findAlignmentFallback(reference: reference, target: target)
        }

        // The alignment transform gives us the translation needed
        let transform = observation.alignmentTransform

        // Vision returns a normalized alignment transform (tx/ty in [−1, 1]).
        // Convert to pixel offsets: tx is the panorama placement x for the current image
        // (how far right of the reference origin to place it), ty is the vertical correction.
        let xOffset = transform.tx * referenceExtent.width
        let yOffset = transform.ty * referenceExtent.height

        print("  📐 Vision alignment: x=\(xOffset), y=\(yOffset), confidence=\(observation.confidence)")

        return CGPoint(x: xOffset, y: yOffset)
    }

    /// Fallback alignment using overlap-based heuristic
    private func findAlignmentFallback(reference: CIImage, target: CIImage) async throws -> CGPoint {
        let referenceExtent = reference.extent
        // Proportional overlap: 25% of image width, capped at 300px
        let overlapWidth = min(referenceExtent.width * 0.25, 300.0)
        let targetExtent = target.extent

        // Extract overlap regions
        let referenceOverlap = reference.cropped(to: CGRect(
            x: max(0, referenceExtent.maxX - overlapWidth),
            y: 0,
            width: overlapWidth,
            height: referenceExtent.height
        ))

        let targetOverlap = target.cropped(to: CGRect(
            x: 0,
            y: 0,
            width: min(overlapWidth, targetExtent.width),
            height: targetExtent.height
        ))

        // Try to find vertical alignment using a second Vision request on overlap regions
        let yOffset = try await findVerticalAlignment(reference: referenceOverlap, target: targetOverlap)

        // Horizontal offset: reference width minus half overlap (assume 50% overlap)
        let xOffset = referenceExtent.width - (overlapWidth / 2)

        return CGPoint(x: xOffset, y: yOffset)
    }

    private func findVerticalAlignment(reference: CIImage, target: CIImage) async throws -> CGFloat {
        // Use Vision to find vertical alignment within overlap regions
        let refExtent = reference.extent
        let targetExtent = target.extent

        guard let refCG = context.createCGImage(reference, from: refExtent),
              let targetCG = context.createCGImage(target, from: targetExtent) else {
            // Fallback: center align
            return (refExtent.height - targetExtent.height) / 2
        }

        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: refCG)
        let handler = VNImageRequestHandler(cgImage: targetCG, options: [:])

        do {
            try handler.perform([request])

            if let observation = request.results?.first as? VNImageTranslationAlignmentObservation {
                return observation.alignmentTransform.ty
            }
        } catch {
            // Fall through to default alignment
        }

        // Fallback: center align
        return (refExtent.height - targetExtent.height) / 2
    }

    // MARK: - Exposure Compensation

    private func compensateExposure(_ images: [CIImage]) async -> [CIImage] {
        guard images.count >= 2 else { return images }

        print("  ☀️ Analyzing and compensating exposure...")

        var compensated: [CIImage] = [images[0]] // First image is reference

        for i in 1..<images.count {
            let reference = compensated[i - 1]
            let current = images[i]

            // Calculate exposure difference in overlap region
            let exposureDiff = await calculateExposureDifference(reference: reference, target: current)

            if abs(exposureDiff) > 0.05 { // Only compensate if difference is significant
                // Apply exposure adjustment
                let adjusted = current.applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: exposureDiff
                ])
                compensated.append(adjusted)
                print("  ✓ Adjusted image \(i + 1) exposure by \(exposureDiff) EV")
            } else {
                compensated.append(current)
            }
        }

        return compensated
    }

    private func calculateExposureDifference(reference: CIImage, target: CIImage) async -> Float {
        let refExtent = reference.extent
        // Proportional overlap: 25% of image width, capped at 300px
        let overlapWidth = min(refExtent.width * 0.25, 300.0)
        let targetExtent = target.extent

        // Extract overlap regions for comparison
        let refOverlap = reference.cropped(to: CGRect(
            x: max(0, refExtent.maxX - overlapWidth),
            y: 0,
            width: min(overlapWidth, refExtent.width),
            height: refExtent.height
        ))

        let targetOverlap = target.cropped(to: CGRect(
            x: 0,
            y: 0,
            width: min(overlapWidth, targetExtent.width),
            height: targetExtent.height
        ))

        // Calculate trimmed-mean brightness (ignores top/bottom 10% of pixels)
        let refBrightness = getTrimmedMeanBrightness(refOverlap)
        let targetBrightness = getTrimmedMeanBrightness(targetOverlap)

        // Calculate exposure difference in EV (log scale)
        guard targetBrightness > 0 else { return 0 }
        let ratio = refBrightness / targetBrightness
        let evDifference = log2(ratio)

        return Float(evDifference)
    }

    /// Computes brightness as a trimmed mean over the middle 80% of pixels,
    /// discarding the darkest 10% and brightest 10% to reduce flare/clipping influence.
    private func getTrimmedMeanBrightness(_ image: CIImage) -> CGFloat {
        let extent = image.extent

        // Convert to Rec.709 grayscale luminance before histogramming
        let grayscale = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        guard let histOutput = CIFilter(name: "CIAreaHistogram", parameters: [
            kCIInputImageKey: grayscale,
            kCIInputExtentKey: CIVector(cgRect: extent),
            "inputCount": 256,
            "inputScale": 1.0
        ])?.outputImage else { return 0.5 }

        var histData = [Float](repeating: 0, count: 256 * 4)
        context.render(
            histOutput,
            toBitmap: &histData,
            rowBytes: 256 * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        // Accumulate bin counts from the red channel
        var counts = [Double](repeating: 0, count: 256)
        var total: Double = 0
        for i in 0..<256 {
            counts[i] = Double(histData[i * 4])
            total += counts[i]
        }

        guard total > 0 else { return 0.5 }

        // Find lower trim boundary (bottom 10%)
        var running: Double = 0
        var lowerBin = 0
        for i in 0..<256 {
            running += counts[i]
            if running >= total * 0.10 { lowerBin = i; break }
        }

        // Find upper trim boundary (top 10%)
        running = 0
        var upperBin = 255
        for i in stride(from: 255, through: 0, by: -1) {
            running += counts[i]
            if running >= total * 0.10 { upperBin = i; break }
        }

        guard lowerBin <= upperBin else { return 0.5 }

        // Weighted mean over middle 80%
        var weightedSum: Double = 0
        var includedCount: Double = 0
        for i in lowerBin...upperBin {
            weightedSum += Double(i) * counts[i]
            includedCount += counts[i]
        }

        guard includedCount > 0 else { return 0.5 }
        return CGFloat(weightedSum / includedCount) / 255.0
    }

    // MARK: - Image Blending

    private func blendImages(_ images: [CIImage], blendWidth: CGFloat) async -> CIImage {
        guard images.count >= 2 else { return images[0] }

        var result = images[0]

        for i in 1..<images.count {
            let current = images[i]

            // Create blend mask
            let mask = createBlendMask(
                for: result.extent,
                next: current.extent,
                blendWidth: blendWidth
            )

            // Blend using mask
            result = current.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: result,
                kCIInputMaskImageKey: mask
            ])

            print("  ✓ Blended image \(i+1)/\(images.count)")
        }

        return result
    }

    private func createBlendMask(for firstExtent: CGRect, next secondExtent: CGRect, blendWidth: CGFloat) -> CIImage {
        // Create a gradient mask in the overlap region

        // Find overlap region
        let overlapX = max(firstExtent.minX, secondExtent.minX)
        let overlapMaxX = min(firstExtent.maxX, secondExtent.maxX)
        let overlapWidth = overlapMaxX - overlapX

        // Create gradient from transparent to opaque using CILinearGradient filter
        guard let gradient = CIFilter(name: "CILinearGradient") else {
            // Fallback to simple mask
            return CIImage(color: CIColor.white).cropped(to: secondExtent)
        }

        gradient.setValue(CIVector(x: overlapX, y: 0), forKey: "inputPoint0")
        gradient.setValue(CIVector(x: overlapX + min(blendWidth, overlapWidth), y: 0), forKey: "inputPoint1")
        gradient.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor0")
        gradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let gradientImage = gradient.outputImage else {
            // Fallback to simple mask
            return CIImage(color: CIColor.white).cropped(to: secondExtent)
        }

        // Crop to second image extent
        return gradientImage.cropped(to: secondExtent)
    }
}

// MARK: - Errors

enum PanoramaError: LocalizedError {
    case notEnoughImages
    case alignmentFailed
    case stitchingFailed

    var errorDescription: String? {
        switch self {
        case .notEnoughImages:
            return "At least 2 images are required for panorama stitching"
        case .alignmentFailed:
            return "Failed to align images. Make sure they have overlapping content."
        case .stitchingFailed:
            return "Failed to stitch images together"
        }
    }
}
