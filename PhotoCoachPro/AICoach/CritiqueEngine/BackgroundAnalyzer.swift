//
//  BackgroundAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes background clutter and subject separation
//

import Foundation
import CoreImage
import Vision

/// Analyzes background quality and separation
actor BackgroundAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze subject separation
        let separationScore = try await analyzeSubjectSeparation(image)
        score += separationScore * 0.5

        if separationScore > 0.7 {
            strengths.append("Clear subject separation")
        } else if separationScore < 0.4 {
            issues.append("Poor subject-background separation")
        }

        // Analyze background complexity
        let complexityScore = analyzeBackgroundComplexity(image)
        score += complexityScore * 0.5

        if complexityScore < 0.4 {
            issues.append("Busy or distracting background")
        } else if complexityScore > 0.7 {
            strengths.append("Clean, simple background")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(score: score, separationScore: separationScore, complexityScore: complexityScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Subject Separation

    private func analyzeSubjectSeparation(_ image: CIImage) async throws -> Double {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return 0.5
        }

        // Try to detect subject
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let result = request.results?.first else {
                // No person detected - try foreground
                return try await analyzeForegroundSeparation(cgImage: cgImage)
            }

            // Analyze mask quality (confidence)
            // Higher confidence = better separation
            let confidence = result.confidence

            return Double(confidence)

        } catch {
            // Fallback to foreground detection
            return try await analyzeForegroundSeparation(cgImage: cgImage)
        }
    }

    private func analyzeForegroundSeparation(cgImage: CGImage) async throws -> Double {
        if #available(iOS 17.0, macOS 14.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let result = request.results?.first else {
                return 0.5  // No foreground detected
            }

            // Check if foreground is well-defined
            let instanceCount = result.allInstances.count

            if instanceCount == 1 {
                return 0.9  // Single clear subject
            } else if instanceCount > 1 && instanceCount <= 3 {
                return 0.7  // Multiple subjects but manageable
            } else {
                return 0.4  // Too many instances (cluttered)
            }
        } else {
            return 0.6  // Neutral score on older platforms
        }
    }

    // MARK: - Background Complexity

    private func analyzeBackgroundComplexity(_ image: CIImage) -> Double {
        // Analyze edge density in background (assuming center is subject)
        let extent = image.extent

        // Sample background areas (corners)
        let sampleSize = min(extent.width, extent.height) * 0.2
        let samples = [
            // Top-left
            image.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: sampleSize, height: sampleSize)),
            // Top-right
            image.cropped(to: CGRect(x: extent.maxX - sampleSize, y: extent.minY, width: sampleSize, height: sampleSize)),
            // Bottom-left
            image.cropped(to: CGRect(x: extent.minX, y: extent.maxY - sampleSize, width: sampleSize, height: sampleSize)),
            // Bottom-right
            image.cropped(to: CGRect(x: extent.maxX - sampleSize, y: extent.maxY - sampleSize, width: sampleSize, height: sampleSize))
        ]

        var totalComplexity = 0.0

        for sample in samples {
            let edges = sample.applyingFilter("CIEdges", parameters: [
                kCIInputIntensityKey: 1.0
            ])

            guard let areaAverage = CIFilter(name: "CIAreaAverage") else { continue }
            areaAverage.setValue(edges, forKey: kCIInputImageKey)
            areaAverage.setValue(CIVector(cgRect: sample.extent), forKey: kCIInputExtentKey)

            guard let outputImage = areaAverage.outputImage else { continue }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

            let edgeDensity = Double(bitmap[0]) / 255.0
            totalComplexity += edgeDensity
        }

        let avgComplexity = totalComplexity / Double(samples.count)

        // Lower complexity = cleaner background = higher score
        // Ideal: < 0.15
        if avgComplexity < 0.10 {
            return 1.0  // Very clean
        } else if avgComplexity < 0.20 {
            return 0.8  // Clean
        } else if avgComplexity < 0.30 {
            return 0.6  // Moderate
        } else {
            return 0.3  // Busy/cluttered
        }
    }

    private func generateNotes(score: Double, separationScore: Double, complexityScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent background with good subject separation. "
        } else if score > 0.6 {
            notes = "Good background management. "
        } else {
            notes = "Background could be improved. "
        }

        if separationScore < 0.5 {
            notes += "Subject doesn't stand out from background. "
        } else if separationScore > 0.8 {
            notes += "Subject well-separated from background. "
        }

        if complexityScore < 0.5 {
            notes += "Background is busy or distracting. "
        } else if complexityScore > 0.8 {
            notes += "Clean, uncluttered background. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
