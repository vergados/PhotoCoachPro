//
//  ColorAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes color harmony and white balance
//

import Foundation
import CoreImage

/// Analyzes color quality and harmony
actor ColorAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze saturation
        let saturationScore = analyzeSaturation(image)
        score += saturationScore * 0.3

        if saturationScore < 0.4 {
            issues.append("Colors are muted")
        } else if saturationScore > 0.8 {
            strengths.append("Vibrant colors")
        }

        // Analyze white balance
        let wbScore = analyzeWhiteBalance(image)
        score += wbScore * 0.4

        if wbScore < 0.5 {
            issues.append("Color cast detected")
        } else if wbScore > 0.8 {
            strengths.append("Accurate white balance")
        }

        // Analyze color harmony
        let harmonyScore = analyzeColorHarmony(image)
        score += harmonyScore * 0.3

        if harmonyScore > 0.7 {
            strengths.append("Good color harmony")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(score: score, saturationScore: saturationScore, wbScore: wbScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Saturation Analysis

    private func analyzeSaturation(_ image: CIImage) -> Double {
        return smoothSaturationScore(calculateAverageSaturation(image))
    }

    /// Smooth bell curve: ideal zone 0.35–0.55, tapers toward both desaturated and
    /// oversaturated extremes without cliff edges.
    private func smoothSaturationScore(_ s: Double) -> Double {
        switch s {
        case ..<0.10:
            return 0.20 + (s / 0.10) * 0.25                          // 0.20 → 0.45
        case 0.10..<0.30:
            return 0.45 + ((s - 0.10) / 0.20) * 0.45                 // 0.45 → 0.90
        case 0.30..<0.35:
            return 0.90 + ((s - 0.30) / 0.05) * 0.10                 // 0.90 → 1.00
        case 0.35..<0.55:
            return 1.00                                                // Ideal zone
        case 0.55..<0.70:
            return 1.00 - ((s - 0.55) / 0.15) * 0.20                 // 1.00 → 0.80
        case 0.70..<0.85:
            return 0.80 - ((s - 0.70) / 0.15) * 0.30                 // 0.80 → 0.50
        default:
            return max(0.25, 0.50 - (s - 0.85) * 1.67)               // → 0.25 floor
        }
    }

    /// Computes mean HSV saturation across all pixels by rendering to a 64×64 bitmap
    /// and averaging per-pixel S = (max - min) / max values.
    private func calculateAverageSaturation(_ image: CIImage) -> Double {
        let sampleSize = 64
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return 0.5 }

        let toOrigin = CGAffineTransform(translationX: -ext.minX, y: -ext.minY)
        let scale = CGAffineTransform(
            scaleX: CGFloat(sampleSize) / ext.width,
            y: CGFloat(sampleSize) / ext.height
        )
        let sampled = image.transformed(by: toOrigin.concatenating(scale))

        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        context.render(
            sampled,
            toBitmap: &pixelData,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: nil
        )

        var totalSaturation: Double = 0
        let pixelCount = sampleSize * sampleSize
        for i in 0..<pixelCount {
            let r = Double(pixelData[i * 4])     / 255.0
            let g = Double(pixelData[i * 4 + 1]) / 255.0
            let b = Double(pixelData[i * 4 + 2]) / 255.0
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            totalSaturation += maxC > 0 ? (maxC - minC) / maxC : 0
        }

        return totalSaturation / Double(pixelCount)
    }

    // MARK: - White Balance Analysis

    private func analyzeWhiteBalance(_ image: CIImage) -> Double {
        // Analyze color cast by checking RGB balance
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        areaAverage.setValue(image, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaAverage.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4 * MemoryLayout<Float>.size,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf,
                       colorSpace: nil)

        let r = Double(bitmap[0])
        let g = Double(bitmap[1])
        let b = Double(bitmap[2])

        // Measure per-channel deviation from the neutral mean
        let avg = (r + g + b) / 3.0
        guard avg > 0 else { return 0.5 }
        let rDiff = abs(r - avg) / avg
        let gDiff = abs(g - avg) / avg
        let bDiff = abs(b - avg) / avg

        let maxDiff = max(rDiff, gDiff, bDiff)

        // Smooth decay — no cliff: 0.00→1.0, 0.05→1.0, 0.10→0.80, 0.20→0.55, 0.35→0.30, 0.50+→0.20
        switch maxDiff {
        case ..<0.05:
            return 1.00
        case 0.05..<0.10:
            return 1.00 - ((maxDiff - 0.05) / 0.05) * 0.20   // 1.00 → 0.80
        case 0.10..<0.20:
            return 0.80 - ((maxDiff - 0.10) / 0.10) * 0.25   // 0.80 → 0.55
        case 0.20..<0.35:
            return 0.55 - ((maxDiff - 0.20) / 0.15) * 0.25   // 0.55 → 0.30
        default:
            return max(0.20, 0.30 - (maxDiff - 0.35) * 0.67) // → 0.20 floor
        }
    }

    // MARK: - Color Harmony

    /// Analyzes color harmony by building a 36-bin hue histogram from per-pixel HSV conversion,
    /// clustering dominant hues, and scoring the result against known harmonic relationships
    /// (monochromatic, analogous, complementary, triadic).
    private func analyzeColorHarmony(_ image: CIImage) -> Double {
        let sampleSize = 64
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return 0.7 }

        let toOrigin = CGAffineTransform(translationX: -ext.minX, y: -ext.minY)
        let scale = CGAffineTransform(
            scaleX: CGFloat(sampleSize) / ext.width,
            y: CGFloat(sampleSize) / ext.height
        )
        let sampled = image.transformed(by: toOrigin.concatenating(scale))

        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        context.render(
            sampled,
            toBitmap: &pixelData,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: nil
        )

        // 36 bins × 10° = full 360° hue wheel
        var hueBins = [Double](repeating: 0, count: 36)
        var coloredPixels = 0

        for i in 0..<(sampleSize * sampleSize) {
            let r = Double(pixelData[i * 4])     / 255.0
            let g = Double(pixelData[i * 4 + 1]) / 255.0
            let b = Double(pixelData[i * 4 + 2]) / 255.0
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC

            // Skip near-gray pixels — they don't contribute meaningful hue information
            guard delta > 0.15 * maxC, maxC > 0 else { continue }
            coloredPixels += 1

            // HSV hue in degrees [0, 360)
            var hue: Double
            if maxC == r {
                hue = 60.0 * ((g - b) / delta)
                if hue < 0 { hue += 360 }
            } else if maxC == g {
                hue = 60.0 * ((b - r) / delta) + 120
            } else {
                hue = 60.0 * ((r - g) / delta) + 240
            }

            hueBins[Int(hue / 10.0) % 36] += 1
        }

        // Too few colorful pixels to judge harmony (monochrome/B&W image)
        guard coloredPixels > 20 else { return 0.75 }

        // Normalize to probabilities
        let total = hueBins.reduce(0, +)
        let probs = hueBins.map { $0 / total }

        // Collect bins with >5% presence as "dominant" hues
        let dominantBins = (0..<36).filter { probs[$0] > 0.05 }
        let clusters = hueCluster(dominantBins, binCount: 36)

        return hueHarmonyScore(clusters: clusters, probs: probs)
    }

    /// Groups adjacent dominant hue bins (wrapping at 360°) into contiguous clusters.
    private func hueCluster(_ bins: [Int], binCount: Int) -> [[Int]] {
        guard !bins.isEmpty else { return [] }
        let sorted = bins.sorted()
        var clusters: [[Int]] = []
        var current = [sorted[0]]

        for i in 1..<sorted.count {
            if sorted[i] - current.last! <= 2 {
                current.append(sorted[i])
            } else {
                clusters.append(current)
                current = [sorted[i]]
            }
        }
        clusters.append(current)

        // Merge first and last clusters if they wrap around the 0°/360° boundary
        if clusters.count > 1 {
            let gap = binCount - clusters.last!.last! + clusters.first!.first!
            if gap <= 2 {
                var merged = clusters.removeLast()
                merged.append(contentsOf: clusters.removeFirst())
                clusters.insert(merged.sorted(), at: 0)
            }
        }

        return clusters
    }

    /// Circular mean of hue bins (0–35, where 35 and 0 are adjacent).
    /// Arithmetic mean of [0, 1, 34, 35] gives 17 (teal) — the wrong answer.
    /// Circular mean detects the wraparound and returns ~35 (red) instead.
    private func clusterCenter(_ bins: [Int]) -> Int {
        guard !bins.isEmpty else { return 0 }
        let sorted = bins.sorted()
        let internalRange = sorted.last! - sorted.first!
        let wrappedGap    = 36 - sorted.last! + sorted.first!
        guard wrappedGap < internalRange else {
            // No wraparound — plain arithmetic mean
            return bins.reduce(0, +) / bins.count
        }
        // Wraparound: shift bins on the low side of the gap up by 36 before averaging
        let threshold = (sorted.first! + sorted.last!) / 2
        let adjusted  = bins.map { $0 <= threshold ? $0 + 36 : $0 }
        return (adjusted.reduce(0, +) / bins.count) % 36
    }

    /// Scores harmony from cluster count and angular relationships between cluster centers.
    private func hueHarmonyScore(clusters: [[Int]], probs: [Double]) -> Double {
        switch clusters.count {
        case 0:
            return 0.5
        case 1:
            // Monochromatic — maximally harmonious
            return 1.0
        case 2:
            let center1 = clusterCenter(clusters[0])
            let center2 = clusterCenter(clusters[1])
            let angDiff = min(abs(center2 - center1), 36 - abs(center2 - center1))
            if angDiff <= 6 {
                // Analogous (within 60°)
                return 0.92
            } else if angDiff >= 14 && angDiff <= 22 {
                // Complementary (180° ± 40°): bonus for one dominant color
                let w1 = clusters[0].map { probs[$0] }.reduce(0, +)
                let w2 = clusters[1].map { probs[$0] }.reduce(0, +)
                let dominance = max(w1, w2) / (w1 + w2)
                return 0.82 + dominance * 0.10
            } else {
                // Dissonant split
                return 0.58
            }
        case 3:
            let centers = clusters.map { clusterCenter($0) }.sorted()
            let gaps = [centers[1] - centers[0], centers[2] - centers[1], 36 - centers[2] + centers[0]]
            let spread = (gaps.max() ?? 0) - (gaps.min() ?? 0)
            // Evenly spaced → triadic; otherwise split-complementary
            return spread <= 4 ? 0.80 : 0.72
        default:
            // Many hue clusters — increasingly chaotic
            return max(0.30, 0.65 - Double(clusters.count - 4) * 0.08)
        }
    }

    private func generateNotes(score: Double, saturationScore: Double, wbScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent color rendition. "
        } else if score > 0.6 {
            notes = "Good color quality. "
        } else {
            notes = "Colors need adjustment. "
        }

        if saturationScore < 0.5 {
            notes += "Colors appear muted or dull. "
        } else if saturationScore > 0.8 {
            notes += "Vibrant, punchy colors. "
        }

        if wbScore < 0.6 {
            notes += "Color cast detected - adjust white balance. "
        } else if wbScore > 0.8 {
            notes += "Accurate white balance. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
