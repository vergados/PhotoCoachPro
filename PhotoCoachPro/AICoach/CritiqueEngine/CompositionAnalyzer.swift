//
//  CompositionAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes composition: rule of thirds, balance, leading lines
//

import Foundation
import CoreImage
import Vision

/// Analyzes photo composition quality
actor CompositionAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    // MARK: - Analysis

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.0
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze saliency (where the eye is drawn)
        let saliencyScore = try await analyzeSaliency(image)
        score += saliencyScore * 0.4

        if saliencyScore > 0.7 {
            strengths.append("Clear focal point")
        } else if saliencyScore < 0.4 {
            issues.append("Unclear focal point")
        }

        // Analyze balance
        let balanceScore = analyzeBalance(image)
        score += balanceScore * 0.3

        if balanceScore > 0.7 {
            strengths.append("Well-balanced composition")
        } else if balanceScore < 0.4 {
            issues.append("Unbalanced composition")
        }

        // Analyze rule of thirds alignment
        let thirdsScore = try await analyzeRuleOfThirds(image)
        score += thirdsScore * 0.3

        if thirdsScore > 0.7 {
            strengths.append("Good rule of thirds alignment")
        } else if thirdsScore < 0.4 {
            issues.append("Subject not on power points")
        }

        // Clamp score
        score = max(0, min(1, score))

        let notes = generateNotes(score: score, saliencyScore: saliencyScore, balanceScore: balanceScore, thirdsScore: thirdsScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Saliency Analysis

    private func analyzeSaliency(_ image: CIImage) async throws -> Double {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return 0.5
        }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return 0.5
        }

        // Analyze saliency map
        let salientObjects = result.salientObjects ?? []

        if salientObjects.isEmpty {
            return 0.3  // No clear subject
        }

        // Check if saliency is concentrated (good) or scattered (bad)
        let totalArea = salientObjects.reduce(0.0) { $0 + $1.boundingBox.width * $1.boundingBox.height }

        // Smooth bell: ramps up to peak (10–35% area), then tapers — no cliff edges
        let concentrationScore: Double
        switch totalArea {
        case ..<0.03:
            // Tiny or absent subject: ramp 0.30 → 0.50
            concentrationScore = 0.30 + (totalArea / 0.03) * 0.20
        case 0.03..<0.10:
            // Approaching ideal: ramp 0.50 → 1.00
            concentrationScore = 0.50 + ((totalArea - 0.03) / 0.07) * 0.50
        case 0.10..<0.35:
            concentrationScore = 1.00  // Ideal zone
        case 0.35..<0.65:
            // Gently tapers: 1.00 at 35% → 0.50 at 65%
            concentrationScore = 1.00 - ((totalArea - 0.35) / 0.30) * 0.50
        default:
            // Heavily scattered: continues falling to a floor of 0.30
            concentrationScore = max(0.30, 0.50 - (totalArea - 0.65) * 0.67)
        }

        return concentrationScore
    }

    // MARK: - Balance Analysis

    private func analyzeBalance(_ image: CIImage) -> Double {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return 0.5 }

        let hw = extent.width / 2
        let hh = extent.height / 2

        // --- Brightness-weighted centroid via four quadrants ---
        // CoreImage Y-axis: minY = bottom, maxY = top
        let tlRect = CGRect(x: extent.minX,      y: extent.minY + hh, width: hw, height: hh)
        let trRect = CGRect(x: extent.minX + hw, y: extent.minY + hh, width: hw, height: hh)
        let blRect = CGRect(x: extent.minX,      y: extent.minY,      width: hw, height: hh)
        let brRect = CGRect(x: extent.minX + hw, y: extent.minY,      width: hw, height: hh)

        let tlB = calculateAverageBrightness(image.cropped(to: tlRect))
        let trB = calculateAverageBrightness(image.cropped(to: trRect))
        let blB = calculateAverageBrightness(image.cropped(to: blRect))
        let brB = calculateAverageBrightness(image.cropped(to: brRect))

        let brightTotal = tlB + trB + blB + brB
        let cx = brightTotal > 0 ? (trB + brB) / brightTotal : 0.5   // right-weight fraction
        let cy = brightTotal > 0 ? (tlB + trB) / brightTotal : 0.5   // top-weight fraction

        // Distance from geometric center; rule-of-thirds subjects sit ~0.17 off-center
        let dx = abs(cx - 0.5)
        let dy = abs(cy - 0.5)
        let centroidDistance = sqrt(dx * dx + dy * dy)

        // Smooth linear interpolation between anchor points — no cliff edges
        let centroidScore: Double
        switch centroidDistance {
        case ..<0.15:
            centroidScore = 1.00  // Centred or naturally balanced
        case 0.15..<0.28:
            // 1.00 → 0.85 over 0.13 units
            centroidScore = 1.00 - ((centroidDistance - 0.15) / 0.13) * 0.15
        case 0.28..<0.45:
            // 0.85 → 0.40 over 0.17 units
            centroidScore = 0.85 - ((centroidDistance - 0.28) / 0.17) * 0.45
        default:
            // Continues falling toward 0.20 minimum
            centroidScore = max(0.20, 0.40 - (centroidDistance - 0.45) * 1.20)
        }

        // --- Edge density asymmetry via CIEdges ---
        let edgeImage = image.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.0])

        let leftEdge  = calculateAverageBrightness(edgeImage.cropped(to: CGRect(x: extent.minX,      y: extent.minY, width: hw,            height: extent.height)))
        let rightEdge = calculateAverageBrightness(edgeImage.cropped(to: CGRect(x: extent.minX + hw, y: extent.minY, width: hw,            height: extent.height)))
        let topEdge   = calculateAverageBrightness(edgeImage.cropped(to: CGRect(x: extent.minX,      y: extent.minY + hh, width: extent.width, height: hh)))
        let botEdge   = calculateAverageBrightness(edgeImage.cropped(to: CGRect(x: extent.minX,      y: extent.minY,      width: extent.width, height: hh)))

        let lrAsym = abs(leftEdge - rightEdge) / max(leftEdge + rightEdge, 0.001)
        let tbAsym = abs(topEdge  - botEdge)   / max(topEdge  + botEdge,   0.001)
        let edgeAsymmetry = (lrAsym + tbAsym) / 2.0

        let edgeScore: Double = edgeAsymmetry < 0.20 ? 1.0 : edgeAsymmetry < 0.40 ? 0.80 : 0.60

        // Combine: centroid placement (60%) + edge density balance (40%)
        return centroidScore * 0.6 + edgeScore * 0.4
    }

    private func calculateAverageBrightness(_ image: CIImage) -> Double {
        // Simplified: use area statistics filter
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4 * MemoryLayout<Float>.size,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf,
                       colorSpace: nil)

        // Rec.709 perceptual luminance — matches human sensitivity weighting
        return Double(0.2126 * bitmap[0] + 0.7152 * bitmap[1] + 0.0722 * bitmap[2])
    }

    // MARK: - Rule of Thirds

    private func analyzeRuleOfThirds(_ image: CIImage) async throws -> Double {
        // Detect if subject is on rule of thirds power points
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return 0.5
        }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first,
              let salientObjects = result.salientObjects,
              let mainObject = salientObjects.first else {
            return 0.5
        }

        // Calculate power points (intersections of rule of thirds lines)
        let powerPoints: [CGPoint] = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0),
            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
            CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]

        // Get center of main salient object
        let objectCenter = CGPoint(
            x: mainObject.boundingBox.midX,
            y: mainObject.boundingBox.midY
        )

        // Find distance to nearest power point
        let distances = powerPoints.map { point in
            let dx = objectCenter.x - point.x
            let dy = objectCenter.y - point.y
            return sqrt(dx * dx + dy * dy)
        }

        guard let minDistance = distances.min() else { return 0.5 }

        // Smooth piecewise decay — rewards precision on the power point,
        // tapers continuously outward rather than hitting a hard floor
        switch minDistance {
        case ..<0.10:
            return 1.00
        case 0.10..<0.25:
            return 1.00 - ((minDistance - 0.10) / 0.15) * 0.65    // 1.00 → 0.35
        case 0.25..<0.40:
            return 0.35 - ((minDistance - 0.25) / 0.15) * 0.15    // 0.35 → 0.20
        default:
            return 0.20
        }
    }

    // MARK: - Notes Generation

    private func generateNotes(score: Double, saliencyScore: Double, balanceScore: Double, thirdsScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent composition with strong fundamentals. "
        } else if score > 0.6 {
            notes = "Good composition with solid structure. "
        } else {
            notes = "Composition needs improvement. "
        }

        if saliencyScore > 0.7 {
            notes += "Clear focal point draws the eye effectively. "
        } else {
            notes += "Focal point could be more defined. "
        }

        if thirdsScore > 0.7 {
            notes += "Subject well-placed using rule of thirds. "
        } else {
            notes += "Consider rule of thirds placement. "
        }

        if balanceScore > 0.7 {
            notes += "Well-balanced visual weight."
        } else {
            notes += "Visual balance could be improved."
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
