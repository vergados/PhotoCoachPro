//
//  QuickMetricsAnalyzer.swift
//  PhotoCoachPro
//
//  Quick metrics analysis (lightweight, no AI/ML dependencies)
//  Ported from Python backend algorithms
//

import Foundation
import CoreImage
import CoreGraphics

// MARK: - Result Models

/// Quick color analysis results
struct QuickColorMetrics {
    let meanRGB: [CGFloat]              // Average RGB values (0-255)
    let saturationMean: CGFloat         // Mean saturation (0-1)
    let saturationP95: CGFloat          // 95th percentile saturation (0-1)
    let warmth: CGFloat                 // R-B difference (positive=warm, negative=cool)
    let greenMagenta: CGFloat           // G minus avg(R,B) (positive=green, negative=magenta)
    let score: CGFloat                  // Overall score (0-100)
    let notes: [String]                 // Interpretation notes
}

/// Quick sharpness analysis results
struct QuickSharpnessMetrics {
    let laplacianStdDev: CGFloat        // Edge energy standard deviation
    let laplacianVariance: CGFloat      // Edge energy variance
    let score: CGFloat                  // Overall score (0-100)
    let notes: [String]                 // Interpretation notes
}

/// Quick exposure analysis results
struct QuickExposureMetrics {
    let brightnessMean: CGFloat         // Mean brightness (0-255)
    let brightnessP05: CGFloat          // 5th percentile brightness
    let brightnessP95: CGFloat          // 95th percentile brightness
    let dynamicRange: CGFloat           // P95 - P05
    let clippedShadows: CGFloat         // Percentage of clipped shadows
    let clippedHighlights: CGFloat      // Percentage of clipped highlights
    let score: CGFloat                  // Overall score (0-100)
    let notes: [String]                 // Interpretation notes
}

/// Combined quick metrics result
struct QuickMetricsResult {
    let color: QuickColorMetrics
    let sharpness: QuickSharpnessMetrics
    let exposure: QuickExposureMetrics
    let overallScore: CGFloat           // Weighted average
}

// MARK: - Quick Metrics Analyzer

/// Lightweight image analysis using Core Image (no AI/ML)
/// Provides fast, explainable metrics for color, sharpness, and exposure
actor QuickMetricsAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])) {
        self.context = context
    }

    // MARK: - Public Interface

    /// Analyze an image with all quick metrics
    func analyze(_ image: CIImage) async throws -> QuickMetricsResult {
        // Resize image for consistent analysis speed
        let resized = resizeForAnalysis(image, maxDimension: 1400)

        // Run all analyses in parallel
        async let colorTask = analyzeColor(resized)
        async let sharpnessTask = analyzeSharpness(resized)
        async let exposureTask = analyzeExposure(resized)

        let color = try await colorTask
        let sharpness = try await sharpnessTask
        let exposure = try await exposureTask

        // Calculate weighted overall score
        let overallScore = (color.score * 0.3 + sharpness.score * 0.3 + exposure.score * 0.4)

        return QuickMetricsResult(
            color: color,
            sharpness: sharpness,
            exposure: exposure,
            overallScore: overallScore
        )
    }

    // MARK: - Color Analysis

    func analyzeColor(_ image: CIImage) async throws -> QuickColorMetrics {
        let extent = image.extent

        // Get average RGB using CIAreaAverage
        guard let avgFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]), let avgOutput = avgFilter.outputImage else {
            throw AnalysisError.filterFailed
        }

        // Read the single pixel output — Float render for sub-integer precision, scaled to 0–255 range
        var bitmap = [Float](repeating: 0, count: 4)
        context.render(avgOutput, toBitmap: &bitmap, rowBytes: 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)

        let meanR = CGFloat(bitmap[0]) * 255.0
        let meanG = CGFloat(bitmap[1]) * 255.0
        let meanB = CGFloat(bitmap[2]) * 255.0
        let meanRGB = [meanR, meanG, meanB]

        // Calculate color cast indicators
        let warmth = meanR - meanB  // Positive = warm, negative = cool
        let greenMagenta = meanG - ((meanR + meanB) / 2.0)  // Positive = green, negative = magenta

        // Calculate saturation from RGB (simple approximation)
        let saturationMean = calculateSaturation(r: meanR, g: meanG, b: meanB)

        // Compute saturation P95 from a 64×64 per-pixel HSV saturation histogram
        let saturationP95 = calculateSaturationPercentile(image, percentile: 0.95)

        // Generate notes
        var notes: [String] = []

        if saturationMean < 0.12 {
            notes.append("Colors look very muted (low saturation)")
        } else if saturationMean < 0.22 {
            notes.append("Colors look slightly muted (cinematic/soft palette)")
        } else if saturationMean <= 0.45 {
            notes.append("Saturation looks natural/healthy")
        } else if saturationMean <= 0.60 {
            notes.append("Saturation is strong; watch for oversaturation")
        } else {
            notes.append("Very strong saturation; risk of clipped/unnatural color")
        }

        if warmth > 18 {
            notes.append("Warm color cast detected (reds/yellows dominate)")
        } else if warmth < -18 {
            notes.append("Cool color cast detected (blues dominate)")
        } else {
            notes.append("White balance looks fairly neutral")
        }

        if greenMagenta > 10 {
            notes.append("Slight green cast detected (often from fluorescents/shade)")
        } else if greenMagenta < -10 {
            notes.append("Slight magenta cast detected (often from mixed lighting)")
        }

        // Score calculation
        var score: CGFloat = 100.0

        // Saturation penalty
        if saturationMean < 0.22 {
            score -= (0.22 - saturationMean) * 220.0
        }
        if saturationMean > 0.55 {
            score -= (saturationMean - 0.55) * 180.0
        }

        // Cast penalties
        score -= min(18.0, abs(warmth) * 0.35)
        score -= min(12.0, abs(greenMagenta) * 0.40)

        // Bonus for good saturation in highlights
        if saturationP95 >= 0.35 && saturationP95 <= 0.85 {
            score += 3.0
        }

        score = clamp(score, min: 0.0, max: 100.0)

        return QuickColorMetrics(
            meanRGB: meanRGB,
            saturationMean: saturationMean,
            saturationP95: saturationP95,
            warmth: warmth,
            greenMagenta: greenMagenta,
            score: score,
            notes: notes
        )
    }

    // MARK: - Sharpness Analysis

    func analyzeSharpness(_ image: CIImage) async throws -> QuickSharpnessMetrics {
        // Convert to grayscale using Rec.709 perceptual weights
        let grayscale = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector":    CIVector(x: 0,      y: 0,      z: 0,      w: 1),
            "inputBiasVector": CIVector(x: 0,      y: 0,      z: 0,      w: 0)
        ])

        // Resize for consistent analysis
        let resized = resizeForAnalysis(grayscale, maxDimension: 1600)

        // Use edge detection filter (simpler than custom convolution)
        guard let edges = CIFilter(name: "CIEdges", parameters: [
            kCIInputImageKey: resized,
            kCIInputIntensityKey: 1.0
        ])?.outputImage else {
            throw AnalysisError.filterFailed
        }

        let convolution = edges

        // Calculate variance of the Laplacian
        let variance = try await calculateImageVariance(convolution)
        let stdDev = sqrt(variance)

        // Generate notes
        var notes: [String] = []

        if variance < 60 {
            notes.append("Image likely soft or slightly out of focus")
        } else if variance < 180 {
            notes.append("Sharpness looks decent for typical viewing sizes")
        } else {
            notes.append("Strong fine detail; image appears very sharp")
        }

        // Score calculation using exponential curve.
        // k is calibrated to the CIEdges histogram variance range (0–thousands).
        // The original k=180 was calibrated for Laplacian variance on float [0,1] images
        // and saturated far too early for the larger values produced here.
        let k: CGFloat = 2000.0
        var score = 100.0 * (1.0 - exp(-variance / k))

        // Penalty for very low variance
        if variance < 25 {
            score = max(0.0, score - 20.0)
            notes.append("Very low edge energy detected (possible motion blur or heavy noise reduction)")
        }

        score = clamp(score, min: 0.0, max: 100.0)

        return QuickSharpnessMetrics(
            laplacianStdDev: stdDev,
            laplacianVariance: variance,
            score: score,
            notes: notes
        )
    }

    // MARK: - Exposure Analysis

    func analyzeExposure(_ image: CIImage) async throws -> QuickExposureMetrics {
        // Convert to grayscale for luminance analysis (Rec.709 perceptual weights)
        let grayscale = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector":    CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector":    CIVector(x: 0,      y: 0,      z: 0,      w: 1),
            "inputBiasVector": CIVector(x: 0,      y: 0,      z: 0,      w: 0)
        ])

        // Get histogram
        let histogram = try await calculateHistogram(grayscale)

        // Calculate percentiles
        let p05 = calculatePercentile(histogram: histogram, percentile: 0.05)
        let p95 = calculatePercentile(histogram: histogram, percentile: 0.95)
        let mean = calculateMean(histogram: histogram)

        let dynamicRange = p95 - p05

        // Calculate clipping — single-bin check (pure black = bin 0, pure white = bin 255)
        // Using 3-bin windows over-reports clipping on images with many near-white/near-black pixels.
        let total = histogram.reduce(0, +)
        let shadowSum = histogram[0]
        let highlightSum = histogram[255]
        let clippedShadows = (CGFloat(shadowSum) / CGFloat(total)) * 100.0
        let clippedHighlights = (CGFloat(highlightSum) / CGFloat(total)) * 100.0

        // Generate notes
        var notes: [String] = []

        let idealLo: CGFloat = 110.0
        let idealHi: CGFloat = 145.0

        if mean < idealLo {
            notes.append("Image looks underexposed (overall too dark)")
        } else if mean > idealHi {
            notes.append("Image looks overexposed (overall too bright)")
        } else {
            notes.append("Overall brightness looks reasonable")
        }

        if dynamicRange < 60 {
            notes.append("Low dynamic range (may look flat or muddy)")
        } else if dynamicRange > 170 {
            notes.append("Very high dynamic range (could be harsh or high-contrast)")
        } else {
            notes.append("Dynamic range looks healthy")
        }

        if clippedHighlights > 2.0 {
            notes.append("Noticeable highlight clipping (blown whites)")
        }
        if clippedShadows > 2.0 {
            notes.append("Noticeable shadow clipping (crushed blacks)")
        }

        // Score calculation
        var score: CGFloat = 100.0

        // Mean penalty
        if mean < idealLo {
            score -= min(35.0, (idealLo - mean) * 0.5)
        }
        if mean > idealHi {
            score -= min(35.0, (mean - idealHi) * 0.5)
        }

        // Clipping penalty
        score -= min(30.0, clippedHighlights * 4.0)
        score -= min(30.0, clippedShadows * 4.0)

        // Dynamic range bonus/penalty
        if dynamicRange < 60 {
            score -= (60 - dynamicRange) * 0.25
        } else if dynamicRange >= 80 && dynamicRange <= 160 {
            score += 3.0
        }

        score = clamp(score, min: 0.0, max: 100.0)

        return QuickExposureMetrics(
            brightnessMean: mean,
            brightnessP05: p05,
            brightnessP95: p95,
            dynamicRange: dynamicRange,
            clippedShadows: clippedShadows,
            clippedHighlights: clippedHighlights,
            score: score,
            notes: notes
        )
    }

    // MARK: - Helper Functions

    private func resizeForAnalysis(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let extent = image.extent
        let maxDim = max(extent.width, extent.height)

        guard maxDim > maxDimension else { return image }

        let scale = maxDimension / maxDim
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func calculateSaturation(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)

        guard maxC > 0 else { return 0 }

        return (maxC - minC) / maxC  // Already normalized 0-1; inputs are 0-255 but ratio is scale-independent
    }

    /// Renders the image at 64×64 and computes per-pixel HSV saturation,
    /// then returns the requested percentile from the resulting histogram.
    private func calculateSaturationPercentile(_ image: CIImage, percentile: CGFloat) -> CGFloat {
        let sampleSize = 64
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return 0 }

        // Translate to origin then scale to sampleSize×sampleSize
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

        // Build per-pixel HSV saturation histogram (256 bins, 0–1 range)
        var satHist = [Int](repeating: 0, count: 256)
        for i in 0..<(sampleSize * sampleSize) {
            let r = CGFloat(pixelData[i * 4])
            let g = CGFloat(pixelData[i * 4 + 1])
            let b = CGFloat(pixelData[i * 4 + 2])
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let sat: CGFloat = maxC > 0 ? (maxC - minC) / maxC : 0
            let bin = min(255, Int(sat * 255))
            satHist[bin] += 1
        }

        // Walk the histogram to find the requested percentile.
        // max(1, ...) prevents target=0 at percentile=0.0, which would cause an
        // immediate early return from bin 0 before any counts are accumulated.
        let total = sampleSize * sampleSize
        let target = max(1, Int(percentile * CGFloat(total)))
        var running = 0
        for (i, count) in satHist.enumerated() {
            running += count
            if running >= target {
                return CGFloat(i) / 255.0
            }
        }
        return 1.0
    }

    private func calculateImageVariance(_ image: CIImage) async throws -> CGFloat {
        let extent = image.extent

        // Build a 256-bin histogram of the edge-energy image
        guard let histOutput = CIFilter(name: "CIAreaHistogram", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent),
            "inputCount": 256,
            "inputScale": 1.0
        ])?.outputImage else {
            throw AnalysisError.filterFailed
        }

        var histData = [Float](repeating: 0, count: 256 * 4)
        context.render(
            histOutput,
            toBitmap: &histData,
            rowBytes: 256 * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        // Extract red channel counts (edge image is grayscale, all channels equal)
        var counts = [Double](repeating: 0, count: 256)
        var total: Double = 0
        for i in 0..<256 {
            counts[i] = Double(histData[i * 4])
            total += counts[i]
        }

        guard total > 0 else { return 0 }

        // Compute mean from histogram
        var mean: Double = 0
        for i in 0..<256 {
            mean += Double(i) * counts[i]
        }
        mean /= total

        // Compute variance: Σ count[i] * (i - mean)² / total
        var variance: Double = 0
        for i in 0..<256 {
            let diff = Double(i) - mean
            variance += counts[i] * diff * diff
        }
        variance /= total

        return CGFloat(variance)
    }

    private func calculateHistogram(_ image: CIImage) async throws -> [Int] {
        // Use CIAreaHistogram filter
        let extent = image.extent

        guard let histFilter = CIFilter(name: "CIAreaHistogram", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent),
            "inputCount": 256,
            "inputScale": 1.0
        ])?.outputImage else {
            throw AnalysisError.filterFailed
        }

        // Render histogram to bitmap
        var histData = [Float](repeating: 0, count: 256 * 4)
        context.render(histFilter, toBitmap: &histData, rowBytes: 256 * 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 256, height: 1), format: .RGBAf, colorSpace: nil)

        // Extract red channel (grayscale, so all channels same)
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<256 {
            histogram[i] = Int(histData[i * 4] * 1000000)  // Scale up for integer math
        }

        return histogram
    }

    private func calculatePercentile(histogram: [Int], percentile: CGFloat) -> CGFloat {
        let total = histogram.reduce(0, +)
        // max(1, ...) prevents target=0 at percentile=0.0, which triggers an
        // immediate early return from the very first bin.
        let target = max(1, Int(percentile * CGFloat(total)))

        var running = 0
        for (i, count) in histogram.enumerated() {
            running += count
            if running >= target {
                return CGFloat(i)
            }
        }

        return 255.0
    }

    private func calculateMean(histogram: [Int]) -> CGFloat {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }

        var sum: CGFloat = 0
        for (i, count) in histogram.enumerated() {
            sum += CGFloat(i * count)
        }

        return sum / CGFloat(total)
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        return max(minValue, min(maxValue, value))
    }
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case filterFailed
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .filterFailed:
            return "Image filter operation failed"
        case .invalidImage:
            return "Invalid image for analysis"
        }
    }
}
