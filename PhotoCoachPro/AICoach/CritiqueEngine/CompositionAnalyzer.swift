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
        var score: Double = 0.5  // Start neutral
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

        // Ideal: one or two salient regions covering 10-40% of image
        let concentrationScore: Double
        if totalArea > 0.1 && totalArea < 0.4 {
            concentrationScore = 1.0
        } else if totalArea < 0.1 {
            concentrationScore = 0.5  // Too small
        } else {
            concentrationScore = 0.6  // Too large/scattered
        }

        return concentrationScore
    }

    // MARK: - Balance Analysis

    private func analyzeBalance(_ image: CIImage) -> Double {
        let extent = image.extent

        // Simplified: analyze left vs right weight
        // In production, would use Vision to detect objects and calculate visual weight

        // For now, use a heuristic based on image brightness distribution
        let leftHalf = image.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: extent.width / 2, height: extent.height))
        let rightHalf = image.cropped(to: CGRect(x: extent.midX, y: extent.minY, width: extent.width / 2, height: extent.height))

        let leftBrightness = calculateAverageBrightness(leftHalf)
        let rightBrightness = calculateAverageBrightness(rightHalf)

        // Calculate balance (closer to 1.0 = better balance)
        let ratio = min(leftBrightness, rightBrightness) / max(leftBrightness, rightBrightness)

        // Perfect balance = 1.0, but slight asymmetry (0.7-0.9) is often good
        if ratio > 0.7 {
            return 0.8 + (ratio - 0.7) * 0.67  // 0.8 to 1.0
        } else {
            return ratio  // 0.0 to 0.7
        }
    }

    private func calculateAverageBrightness(_ image: CIImage) -> Double {
        // Simplified: use area statistics filter
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // Average of RGB
        let brightness = (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / (3.0 * 255.0)
        return brightness
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

        // Score based on distance (closer = better)
        // Distance of 0.15 or less = excellent
        // Distance of 0.3 or more = poor
        if minDistance < 0.15 {
            return 1.0
        } else if minDistance > 0.3 {
            return 0.3
        } else {
            // Linear scale between 0.15 and 0.3
            return 1.0 - ((minDistance - 0.15) / 0.15) * 0.7
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
