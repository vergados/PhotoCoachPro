//
//  FocusAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes sharpness and depth of field quality
//

import Foundation
import CoreImage

/// Analyzes focus and sharpness quality
actor FocusAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze overall sharpness
        let sharpnessScore = analyzeSharpness(image)
        score += sharpnessScore * 0.6

        if sharpnessScore > 0.7 {
            strengths.append("Sharp focus on subject")
        } else if sharpnessScore < 0.4 {
            issues.append("Soft or blurry image")
        }

        // Analyze edge detail
        let edgeScore = analyzeEdgeDetail(image)
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

    // MARK: - Sharpness Analysis

    private func analyzeSharpness(_ image: CIImage) -> Double {
        // Use Laplacian variance to measure sharpness
        let laplacian = image.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9)
        ])

        // Calculate variance
        guard let areaMax = CIFilter(name: "CIAreaMaximum") else { return 0.5 }
        areaMax.setValue(laplacian, forKey: kCIInputImageKey)
        areaMax.setValue(CIVector(cgRect: laplacian.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaMax.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)

        let variance = Double(bitmap[0])

        // Normalize (typical sharp images have variance > 0.1)
        if variance > 0.15 {
            return 1.0
        } else if variance > 0.1 {
            return 0.8
        } else if variance > 0.05 {
            return 0.6
        } else {
            return 0.3
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

        // Good detail typically has edge density of 0.15-0.3
        if edgeDensity >= 0.15 && edgeDensity <= 0.35 {
            return 1.0
        } else if edgeDensity < 0.1 {
            return 0.4  // Too soft
        } else if edgeDensity > 0.5 {
            return 0.5  // Too much noise/over-sharpened
        } else {
            return 0.7
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
