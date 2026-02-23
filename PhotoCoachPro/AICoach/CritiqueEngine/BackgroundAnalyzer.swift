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
        var score: Double = 0.0
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

            // Check if foreground is well-defined — smooth decay per additional instance
            // 1 → 0.90, 2 → 0.75, 3 → 0.60, 4 → 0.45, 5+ → 0.30 floor
            let n = Double(result.allInstances.count)
            return max(0.30, 0.90 - (n - 1.0) * 0.15)
        } else {
            // Older platform fallback: use attention-based saliency to locate the primary
            // subject, then measure edge contrast in a border ring around its bounding box.
            // High edge density in that ring = subject stands out sharply from background.
            let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()
            let saliencyHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try saliencyHandler.perform([saliencyReq])

            guard let saliency  = saliencyReq.results?.first,
                  let objects   = saliency.salientObjects,
                  let primary   = objects.first else {
                return 0.40  // No salient subject detectable
            }

            // Convert normalized VN bounding box to pixel coordinates.
            // VN and CIImage both use bottom-left origin, so the mapping is direct.
            let w   = CGFloat(cgImage.width)
            let h   = CGFloat(cgImage.height)
            let box = primary.boundingBox
            let bx  = box.minX * w,  by  = box.minY * h
            let bw  = box.width * w, bh  = box.height * h
            let pad = min(bw, bh) * 0.12  // 12% expansion on each side

            let borderRect = CGRect(x: max(0, bx - pad),
                                    y: max(0, by - pad),
                                    width:  min(w, bx + bw + pad) - max(0, bx - pad),
                                    height: min(h, by + bh + pad) - max(0, by - pad))
            guard !borderRect.isEmpty else { return 0.50 }

            // Measure average edge density in the expanded border ring
            let ci    = CIImage(cgImage: cgImage)
            let edges = ci.cropped(to: borderRect)
                .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.5])
            guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0.50 }
            avgFilter.setValue(edges, forKey: kCIInputImageKey)
            avgFilter.setValue(CIVector(cgRect: edges.extent), forKey: kCIInputExtentKey)
            guard let avgOut = avgFilter.outputImage else { return 0.50 }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(avgOut, toBitmap: &bitmap, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: nil)

            let edgeDensity = Double(bitmap[0]) / 255.0
            // Smooth piecewise ramp — edge density in border ring indicates subject-bg contrast
            switch edgeDensity {
            case ..<0.05:
                return 0.40
            case 0.05..<0.08:
                return 0.40 + ((edgeDensity - 0.05) / 0.03) * 0.20              // 0.40 → 0.60
            case 0.08..<0.15:
                return 0.60 + ((edgeDensity - 0.08) / 0.07) * 0.20              // 0.60 → 0.80
            default:
                return min(0.90, 0.80 + (edgeDensity - 0.15) * 0.67)            // → 0.90 cap
            }
        }
    }

    // MARK: - Background Complexity

    private func analyzeBackgroundComplexity(_ image: CIImage) -> Double {
        // Analyze edge density in background (assuming center is subject)
        let extent = image.extent

        // Sample background areas (corners)
        let sampleSize = min(extent.width, extent.height) * 0.2
        // CoreImage uses bottom-left origin: minY = visual bottom, maxY = visual top
        let samples = [
            // Bottom-left (CoreImage origin)
            image.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: sampleSize, height: sampleSize)),
            // Bottom-right
            image.cropped(to: CGRect(x: extent.maxX - sampleSize, y: extent.minY, width: sampleSize, height: sampleSize)),
            // Top-left
            image.cropped(to: CGRect(x: extent.minX, y: extent.maxY - sampleSize, width: sampleSize, height: sampleSize)),
            // Top-right
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

        // Lower complexity = cleaner background = higher score — smooth piecewise decay, no cliff edges
        switch avgComplexity {
        case ..<0.05:
            return 1.00
        case 0.05..<0.15:
            return 1.00 - ((avgComplexity - 0.05) / 0.10) * 0.25             // 1.00 → 0.75
        case 0.15..<0.25:
            return 0.75 - ((avgComplexity - 0.15) / 0.10) * 0.30             // 0.75 → 0.45
        case 0.25..<0.40:
            return 0.45 - ((avgComplexity - 0.25) / 0.15) * 0.20             // 0.45 → 0.25
        default:
            return max(0.20, 0.25 - (avgComplexity - 0.40) * 0.33)           // → 0.20 floor
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
