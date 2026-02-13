//
//  LightAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes exposure, contrast, highlight/shadow quality
//

import Foundation
import CoreImage

/// Analyzes lighting quality and exposure
actor LightAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze histogram
        let histogram = calculateHistogram(image)

        // Check for clipping
        let clippingScore = analyzeClipping(histogram: histogram)
        score += clippingScore * 0.35

        if histogram.shadowClipping > 0.05 {
            issues.append("Blocked shadows")
        }
        if histogram.highlightClipping > 0.05 {
            issues.append("Blown highlights")
        }
        if clippingScore > 0.8 {
            strengths.append("Good exposure latitude")
        }

        // Analyze contrast
        let contrastScore = analyzeContrast(histogram: histogram)
        score += contrastScore * 0.3

        if contrastScore < 0.4 {
            issues.append("Low contrast")
        } else if contrastScore > 0.7 {
            strengths.append("Good tonal range")
        }

        // Analyze dynamic range
        let dynamicRangeScore = analyzeDynamicRange(histogram: histogram)
        score += dynamicRangeScore * 0.35

        if dynamicRangeScore > 0.7 {
            strengths.append("Well-utilized dynamic range")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(
            score: score,
            histogram: histogram,
            clippingScore: clippingScore,
            contrastScore: contrastScore
        )

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Histogram Analysis

    private struct Histogram {
        let values: [Int]
        let shadowClipping: Double     // % of pixels at pure black
        let highlightClipping: Double  // % of pixels at pure white
        let meanBrightness: Double
        let contrast: Double
    }

    private func calculateHistogram(_ image: CIImage) -> Histogram {
        // Convert to grayscale
        let grayscale = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // Use area histogram
        guard let filter = CIFilter(name: "CIAreaHistogram") else {
            return Histogram(values: Array(repeating: 0, count: 256), shadowClipping: 0, highlightClipping: 0, meanBrightness: 0.5, contrast: 0.5)
        }

        filter.setValue(grayscale, forKey: kCIInputImageKey)
        filter.setValue(256, forKey: "inputCount")
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        filter.setValue(1.0, forKey: "inputScale")

        guard let outputImage = filter.outputImage else {
            return Histogram(values: Array(repeating: 0, count: 256), shadowClipping: 0, highlightClipping: 0, meanBrightness: 0.5, contrast: 0.5)
        }

        // Read histogram data
        var histogramData = [Float](repeating: 0, count: 256)
        context.render(outputImage, toBitmap: &histogramData, rowBytes: 256 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 256, height: 1), format: .Rf, colorSpace: nil)

        let values = histogramData.map { Int($0 * 1000) }

        // Calculate statistics
        let totalPixels = values.reduce(0, +)
        let shadowPixels = values[0..<10].reduce(0, +)
        let highlightPixels = values[246..<256].reduce(0, +)

        let shadowClipping = Double(shadowPixels) / Double(totalPixels)
        let highlightClipping = Double(highlightPixels) / Double(totalPixels)

        // Mean brightness
        var sumWeighted = 0
        for (index, count) in values.enumerated() {
            sumWeighted += index * count
        }
        let meanBrightness = Double(sumWeighted) / Double(totalPixels) / 255.0

        // Contrast (standard deviation)
        var sumSquaredDiff = 0.0
        for (index, count) in values.enumerated() {
            let diff = Double(index) / 255.0 - meanBrightness
            sumSquaredDiff += diff * diff * Double(count)
        }
        let contrast = sqrt(sumSquaredDiff / Double(totalPixels))

        return Histogram(
            values: values,
            shadowClipping: shadowClipping,
            highlightClipping: highlightClipping,
            meanBrightness: meanBrightness,
            contrast: contrast
        )
    }

    private func analyzeClipping(histogram: Histogram) -> Double {
        // Penalize clipping
        let totalClipping = histogram.shadowClipping + histogram.highlightClipping

        if totalClipping < 0.01 {
            return 1.0  // Excellent
        } else if totalClipping < 0.05 {
            return 0.8  // Good
        } else if totalClipping < 0.10 {
            return 0.6  // Fair
        } else {
            return 0.3  // Poor
        }
    }

    private func analyzeContrast(histogram: Histogram) -> Double {
        // Ideal contrast is around 0.25-0.35
        let contrast = histogram.contrast

        if contrast >= 0.25 && contrast <= 0.35 {
            return 1.0
        } else if contrast < 0.15 {
            return 0.4  // Too flat
        } else if contrast > 0.45 {
            return 0.5  // Too contrasty
        } else {
            // Gradual falloff
            return 0.7
        }
    }

    private func analyzeDynamicRange(histogram: Histogram) -> Double {
        // Check how well the histogram spans the full tonal range
        let values = histogram.values

        // Find first and last significant bins
        var firstBin = 0
        var lastBin = 255

        for i in 0..<256 {
            if values[i] > 10 {
                firstBin = i
                break
            }
        }

        for i in (0..<256).reversed() {
            if values[i] > 10 {
                lastBin = i
                break
            }
        }

        let range = Double(lastBin - firstBin) / 255.0

        // Good utilization: 0.7-0.95 of range
        if range >= 0.7 && range <= 0.95 {
            return 1.0
        } else if range < 0.4 {
            return 0.4  // Narrow range
        } else {
            return 0.7
        }
    }

    private func generateNotes(score: Double, histogram: Histogram, clippingScore: Double, contrastScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent exposure with good tonal range. "
        } else if score > 0.6 {
            notes = "Good exposure overall. "
        } else {
            notes = "Exposure needs improvement. "
        }

        if histogram.shadowClipping > 0.05 {
            notes += "Shadows are blocked (pure black). "
        }

        if histogram.highlightClipping > 0.05 {
            notes += "Highlights are blown (pure white). "
        }

        if contrastScore < 0.5 {
            notes += "Image is flat - boost contrast. "
        } else if contrastScore > 0.7 {
            notes += "Good contrast and punch. "
        }

        if histogram.meanBrightness < 0.3 {
            notes += "Image is underexposed. "
        } else if histogram.meanBrightness > 0.7 {
            notes += "Image is overexposed. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
