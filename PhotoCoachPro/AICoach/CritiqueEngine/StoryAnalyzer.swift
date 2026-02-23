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
        var score: Double = 0.0
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

        // Smooth decay per additional competing element:
        // 1 → 0.90, 2 → 0.78, 3 → 0.66, 4 → 0.54, 5 → 0.42, 6+ → 0.30
        let n = Double(salientObjects.count)
        return max(0.30, 0.90 - (n - 1.0) * 0.12)
    }

    // MARK: - Visual Interest

    private func analyzeVisualInterest(_ image: CIImage) -> Double {
        // Analyze variety in texture and detail
        let entropy = calculateImageEntropy(image)

        // Smooth bell curve peaked at 5.0 bits (typical of well-composed natural scenes)
        return smoothEntropyScore(entropy)
    }

    /// Computes Shannon entropy H = Σ(-p_i × log₂(p_i)) from a 256-bin luminance histogram.
    /// Range: 0 (uniform image) to 8 (maximally complex, all bins equally filled).
    /// Typical natural scenes fall in 5–7 bits.
    private func calculateImageEntropy(_ image: CIImage) -> Double {
        // Convert to Rec.709 grayscale so entropy reflects luminance complexity
        let grayscale = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        guard let histOutput = CIFilter(name: "CIAreaHistogram", parameters: [
            kCIInputImageKey: grayscale,
            kCIInputExtentKey: CIVector(cgRect: grayscale.extent),
            "inputCount": 256,
            "inputScale": 1.0
        ])?.outputImage else { return 5.0 }

        var histData = [Float](repeating: 0, count: 256 * 4)
        context.render(
            histOutput,
            toBitmap: &histData,
            rowBytes: 256 * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        // Sum bin counts from the red channel
        var total: Double = 0
        var counts = [Double](repeating: 0, count: 256)
        for i in 0..<256 {
            counts[i] = Double(histData[i * 4])
            total += counts[i]
        }

        guard total > 0 else { return 0 }

        // Shannon entropy: H = Σ(-p_i × log₂(p_i)) over all occupied bins
        var entropy: Double = 0
        for count in counts where count > 0 {
            let p = count / total
            entropy -= p * log2(p)
        }

        return entropy
    }

    /// Piecewise-linear bell curve through perceptual entropy anchors.
    /// Anchors: 0→0.20, 2→0.40, 4→0.85, 5→1.00, 6→0.85, 7→0.65, 8→0.45
    private func smoothEntropyScore(_ entropy: Double) -> Double {
        let anchors: [(x: Double, y: Double)] = [
            (0.0, 0.20), (2.0, 0.40), (4.0, 0.85),
            (5.0, 1.00), (6.0, 0.85), (7.0, 0.65), (8.0, 0.45)
        ]
        if entropy <= anchors.first!.x { return anchors.first!.y }
        if entropy >= anchors.last!.x  { return anchors.last!.y  }
        for i in 0..<anchors.count - 1 {
            let lo = anchors[i], hi = anchors[i + 1]
            if entropy < hi.x {
                let t = (entropy - lo.x) / (hi.x - lo.x)
                return lo.y + t * (hi.y - lo.y)
            }
        }
        return 0.65
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
