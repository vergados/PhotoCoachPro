//
//  StoryAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes subject clarity and emotional impact
//

import Foundation
import CoreImage
import Vision

/// Analyzes storytelling and emotional impact
actor StoryAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze subject clarity
        let subjectScore = try await analyzeSubjectClarity(image)
        score += subjectScore * 0.6

        if subjectScore > 0.7 {
            strengths.append("Clear, compelling subject")
        } else if subjectScore < 0.4 {
            issues.append("Unclear subject or message")
        }

        // Analyze visual interest
        let interestScore = analyzeVisualInterest(image)
        score += interestScore * 0.4

        if interestScore > 0.7 {
            strengths.append("Visually engaging")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(score: score, subjectScore: subjectScore, interestScore: interestScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Subject Clarity

    private func analyzeSubjectClarity(_ image: CIImage) async throws -> Double {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return 0.5
        }

        // Use saliency to detect subject
        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return 0.5
        }

        let salientObjects = result.salientObjects ?? []

        if salientObjects.isEmpty {
            return 0.3  // No clear subject
        }

        // Check if there's one dominant subject
        if salientObjects.count == 1 {
            return 0.9  // Clear single subject
        } else if salientObjects.count <= 3 {
            return 0.7  // Multiple subjects but manageable
        } else {
            return 0.4  // Too many competing elements
        }
    }

    // MARK: - Visual Interest

    private func analyzeVisualInterest(_ image: CIImage) -> Double {
        // Analyze variety in texture and detail
        let entropy = calculateImageEntropy(image)

        // Good entropy: 4.0-6.0 (neither too uniform nor too chaotic)
        if entropy >= 4.0 && entropy <= 6.0 {
            return 1.0
        } else if entropy < 3.0 {
            return 0.5  // Too uniform
        } else if entropy > 7.0 {
            return 0.6  // Too chaotic
        } else {
            return 0.8
        }
    }

    private func calculateImageEntropy(_ image: CIImage) -> Double {
        // Simplified entropy calculation
        // Real implementation would calculate Shannon entropy of histogram

        // Use histogram variance as proxy
        guard let areaHistogram = CIFilter(name: "CIAreaHistogram") else {
            return 5.0
        }

        areaHistogram.setValue(image, forKey: kCIInputImageKey)
        areaHistogram.setValue(64, forKey: "inputCount")
        areaHistogram.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaHistogram.outputImage else {
            return 5.0
        }

        var histogramData = [Float](repeating: 0, count: 64)
        context.render(outputImage, toBitmap: &histogramData, rowBytes: 64 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 64, height: 1), format: .Rf, colorSpace: nil)

        // Calculate variance
        let mean = histogramData.reduce(0, +) / Float(histogramData.count)
        let variance = histogramData.map { pow($0 - mean, 2) }.reduce(0, +) / Float(histogramData.count)

        // Normalize to approximate entropy range
        return Double(sqrt(variance)) * 10.0
    }

    private func generateNotes(score: Double, subjectScore: Double, interestScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Compelling image with clear storytelling. "
        } else if score > 0.6 {
            notes = "Good narrative and visual interest. "
        } else {
            notes = "Story or message could be clearer. "
        }

        if subjectScore > 0.7 {
            notes += "Subject is clear and well-defined. "
        } else if subjectScore < 0.5 {
            notes += "Subject is unclear or competing with other elements. "
        }

        if interestScore > 0.7 {
            notes += "Visually engaging with good variety. "
        } else if interestScore < 0.5 {
            notes += "Image lacks visual interest. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
