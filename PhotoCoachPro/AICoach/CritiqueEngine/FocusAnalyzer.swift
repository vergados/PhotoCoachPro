//
//  FocusAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes sharpness and depth of field quality
//

import Foundation
import CoreImage
import Vision

/// Analyzes focus and sharpness quality
actor FocusAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.0
        var issues: [String] = []
        var strengths: [String] = []

        // Crop to the primary salient region so sharpness is measured on the
        // subject, not on a blurred background or empty corners.
        let subjectImage = saliencyBoundedRegion(image)

        // Analyze overall sharpness
        let sharpnessScore = analyzeSharpness(subjectImage)
        score += sharpnessScore * 0.6

        if sharpnessScore > 0.7 {
            strengths.append("Sharp focus on subject")
        } else if sharpnessScore < 0.4 {
            issues.append("Soft or blurry image")
        }

        // Analyze edge detail
        let edgeScore = analyzeEdgeDetail(subjectImage)
        score += edgeScore * 0.4

        if edgeScore < 0.4 {
            issues.append("Lack of fine detail")
        } else if edgeScore > 0.7 {
            strengths.append("Good detail retention")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(score: score, sharpnessScore: sharpnessScore, edgeScore: edgeScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Subject Region

    /// Returns the image cropped to its primary salient region.
    /// Falls back to the full image when saliency detection fails or finds nothing.
    private func saliencyBoundedRegion(_ image: CIImage) -> CIImage {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return image
        }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return image
        }

        guard let result  = request.results?.first,
              let objects = result.salientObjects,
              let primary = objects.first else { return image }

        // VN bounding box uses bottom-left origin — same as CIImage — so the
        // mapping from normalized coordinates to pixel coordinates is direct.
        let ext = image.extent
        let box = primary.boundingBox
        let cropRect = CGRect(
            x: ext.minX + box.minX * ext.width,
            y: ext.minY + box.minY * ext.height,
            width:  box.width  * ext.width,
            height: box.height * ext.height
        )
        let clipped = cropRect.intersection(ext)
        guard !clipped.isEmpty else { return image }
        return image.cropped(to: clipped)
    }

    // MARK: - Sharpness Analysis

    /// Laplacian Variance Method: variance = E[L²] − E[L]²
    /// High variance → crisp edges; low variance → blurry.
    private func analyzeSharpness(_ image: CIImage) -> Double {
        // Apply Laplacian edge-detection kernel
        let laplacian = image.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9)
        ])

        // Render to a 128×128 tile so runtime is bounded regardless of image size
        let tileSize = 128
        let extent   = laplacian.extent
        guard extent.width > 0, extent.height > 0 else { return 0.5 }

        let scaleX = CGFloat(tileSize) / extent.width
        let scaleY = CGFloat(tileSize) / extent.height
        let scaled = laplacian.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
                .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
        )

        let pixelCount = tileSize * tileSize
        var bitmap = [Float](repeating: 0, count: pixelCount * 4)
        context.render(scaled,
                       toBitmap: &bitmap,
                       rowBytes: tileSize * 4 * MemoryLayout<Float>.size,
                       bounds: CGRect(x: 0, y: 0, width: tileSize, height: tileSize),
                       format: .RGBAf,
                       colorSpace: nil)

        // Accumulate sum and sum-of-squares from the R channel
        var sum:   Double = 0
        var sumSq: Double = 0
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let v  = Double(bitmap[i])
            sum   += v
            sumSq += v * v
        }
        let mean     = sum   / Double(pixelCount)
        let variance = sumSq / Double(pixelCount) - mean * mean

        // Smooth piecewise ramp calibrated to Laplacian variance on a float [0,1] image
        switch variance {
        case 0.006...:
            return 1.00
        case 0.002..<0.006:
            return 0.80 + ((variance - 0.002) / 0.004) * 0.20    // 0.80 → 1.00
        case 0.0003..<0.002:
            return 0.50 + ((variance - 0.0003) / 0.0017) * 0.30  // 0.50 → 0.80
        default:
            return max(0.20, (variance / 0.0003) * 0.50)          // 0.20 → 0.50
        }
    }

    private func analyzeEdgeDetail(_ image: CIImage) -> Double {
        // Edge detection
        let edges = image.applyingFilter("CIEdges", parameters: [
            kCIInputIntensityKey: 1.0
        ])

        // Count edge pixels
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        areaAverage.setValue(edges, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: edges.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaAverage.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let edgeDensity = Double(bitmap[0]) / 255.0

        // Smooth piecewise ramp — optimal zone 0.20–0.35, soft floor 0.40, noise floor 0.50
        switch edgeDensity {
        case ..<0.10:
            return 0.40 + (edgeDensity / 0.10) * 0.30              // 0.40 → 0.70
        case 0.10..<0.20:
            return 0.70 + ((edgeDensity - 0.10) / 0.10) * 0.30    // 0.70 → 1.00
        case 0.20..<0.35:
            return 1.00                                              // optimal zone
        case 0.35..<0.50:
            return 1.00 - ((edgeDensity - 0.35) / 0.15) * 0.50    // 1.00 → 0.50
        default:
            return 0.50                                              // over-sharpened floor
        }
    }

    private func generateNotes(score: Double, sharpnessScore: Double, edgeScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent sharpness and detail. "
        } else if score > 0.6 {
            notes = "Good focus with acceptable sharpness. "
        } else {
            notes = "Focus and sharpness need improvement. "
        }

        if sharpnessScore < 0.5 {
            notes += "Image appears soft or out of focus. "
        } else if sharpnessScore > 0.8 {
            notes += "Critically sharp focus. "
        }

        if edgeScore < 0.5 {
            notes += "Lacking fine detail. Consider sharpening. "
        } else if edgeScore > 0.8 {
            notes += "Good detail retention throughout. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
