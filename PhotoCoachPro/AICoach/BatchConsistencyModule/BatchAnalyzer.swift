//
//  BatchAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes consistency across a batch of photos
//

import Foundation
import CoreImage

/// Analyzes batch consistency
actor BatchAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    // MARK: - Batch Analysis

    /// Analyze consistency across batch of photos
    func analyze(images: [(image: CIImage, photoID: UUID)], batchID: UUID) async throws -> ConsistencyReport {
        guard images.count >= 2 else {
            throw BatchAnalysisError.insufficientPhotos
        }

        // Analyze individual metrics
        let exposureMetric = analyzeExposureConsistency(images: images)
        let whiteBalanceMetric = analyzeWhiteBalanceConsistency(images: images)
        let colorMetric = analyzeColorConsistency(images: images)
        let sharpnessMetric = analyzeSharpnessConsistency(images: images)
        let compositionMetric = analyzeCompositionConsistency(images: images)

        let metrics = ConsistencyReport.ConsistencyMetrics(
            exposureConsistency: exposureMetric,
            whiteBalanceConsistency: whiteBalanceMetric,
            colorConsistency: colorMetric,
            sharpnessConsistency: sharpnessMetric,
            compositionConsistency: compositionMetric
        )

        // Calculate overall consistency
        let overallConsistency = calculateOverallConsistency(metrics: metrics)

        // Identify outliers
        let outliers = identifyOutliers(images: images, metrics: metrics)

        // Generate recommendations
        let recommendations = generateRecommendations(metrics: metrics, outliers: outliers, images: images)

        return ConsistencyReport(
            batchID: batchID,
            photoIDs: images.map { $0.photoID },
            overallConsistency: overallConsistency,
            metrics: metrics,
            recommendations: recommendations,
            outliers: outliers
        )
    }

    // MARK: - Exposure Consistency

    private func analyzeExposureConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        var brightnesses: [Double] = []

        for item in images {
            let brightness = calculateAverageBrightness(item.image)
            brightnesses.append(brightness)
        }

        let mean = brightnesses.reduce(0, +) / Double(brightnesses.count)
        let variance = brightnesses.map { pow($0 - mean, 2) }.reduce(0, +) / Double(brightnesses.count)
        let stdDev = sqrt(variance)

        // Smooth decay anchored on variance (stdDev²): 0.0000→1.0, 0.0025→0.90, 0.0100→0.65, 0.0400→0.35, 0.1225+→0.20
        let score = smoothConsistencyScore(variance, anchors: [
            (variance: 0.0000, score: 1.00),
            (variance: 0.0025, score: 0.90),
            (variance: 0.0100, score: 0.65),
            (variance: 0.0400, score: 0.35),
            (variance: 0.1225, score: 0.20)
        ])

        let notes: String
        if score > 0.8 {
            notes = "Exposure is very consistent across the batch."
        } else if score > 0.6 {
            notes = "Exposure is mostly consistent with minor variations."
        } else {
            notes = "Exposure varies significantly across the batch. Consider normalizing."
        }

        return ConsistencyReport.MetricScore(score: score, variance: variance, notes: notes)
    }

    private func calculateAverageBrightness(_ image: CIImage) -> Double {
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

        return Double(0.2126 * bitmap[0] + 0.7152 * bitmap[1] + 0.0722 * bitmap[2])
    }

    // MARK: - White Balance Consistency

    private func analyzeWhiteBalanceConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        var colorCasts: [(r: Double, g: Double, b: Double)] = []

        for item in images {
            let cast = calculateColorCast(item.image)
            colorCasts.append(cast)
        }

        // Calculate variance in color channels
        let rValues = colorCasts.map { $0.r }
        let gValues = colorCasts.map { $0.g }
        let bValues = colorCasts.map { $0.b }

        let rVariance = calculateVariance(rValues)
        let gVariance = calculateVariance(gValues)
        let bVariance = calculateVariance(bValues)

        let avgVariance = (rVariance + gVariance + bVariance) / 3.0

        // Smooth decay: 0.000→1.0, 0.010→0.90, 0.030→0.65, 0.060→0.40, 0.100+→0.20
        let score = smoothConsistencyScore(avgVariance, anchors: [
            (variance: 0.000, score: 1.00),
            (variance: 0.010, score: 0.90),
            (variance: 0.030, score: 0.65),
            (variance: 0.060, score: 0.40),
            (variance: 0.100, score: 0.20)
        ])

        let notes: String
        if score > 0.8 {
            notes = "White balance is consistent across all photos."
        } else {
            notes = "White balance varies across the batch. Consider syncing temperature and tint."
        }

        return ConsistencyReport.MetricScore(score: score, variance: avgVariance, notes: notes)
    }

    private func calculateColorCast(_ image: CIImage) -> (r: Double, g: Double, b: Double) {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return (0, 0, 0) }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return (0, 0, 0) }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return (
            r: Double(bitmap[0]) / 255.0,
            g: Double(bitmap[1]) / 255.0,
            b: Double(bitmap[2]) / 255.0
        )
    }

    // MARK: - Color Consistency

    private func analyzeColorConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        // Simplified: measure saturation variance
        var saturations: [Double] = []

        for item in images {
            let saturation = calculateAverageSaturation(item.image)
            saturations.append(saturation)
        }

        let variance = calculateVariance(saturations)

        // Smooth decay: 0.00→1.0, 0.02→0.90, 0.05→0.70, 0.10→0.45, 0.20+→0.20
        let score = smoothConsistencyScore(variance, anchors: [
            (variance: 0.00, score: 1.00),
            (variance: 0.02, score: 0.90),
            (variance: 0.05, score: 0.70),
            (variance: 0.10, score: 0.45),
            (variance: 0.20, score: 0.20)
        ])

        let notes = score > 0.7 ? "Color saturation is consistent." : "Color saturation varies. Consider normalizing vibrance."

        return ConsistencyReport.MetricScore(score: score, variance: variance, notes: notes)
    }

    /// Computes mean HSV saturation by sampling a 32×32 bitmap and averaging
    /// per-pixel S = (max−min)/max values — not the saturation of the average color.
    private func calculateAverageSaturation(_ image: CIImage) -> Double {
        let sampleSize = 32
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return 0.5 }

        let normalized = image.transformed(
            by: CGAffineTransform(translationX: -ext.minX, y: -ext.minY)
                .concatenating(CGAffineTransform(scaleX: CGFloat(sampleSize) / ext.width,
                                                 y: CGFloat(sampleSize) / ext.height))
        )

        let n = sampleSize * sampleSize
        var pixels = [UInt8](repeating: 0, count: n * 4)
        context.render(normalized,
                       toBitmap: &pixels,
                       rowBytes: sampleSize * 4,
                       bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
                       format: .RGBA8,
                       colorSpace: nil)

        var total: Double = 0
        for i in 0..<n {
            let r = Double(pixels[i * 4])     / 255.0
            let g = Double(pixels[i * 4 + 1]) / 255.0
            let b = Double(pixels[i * 4 + 2]) / 255.0
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            total += maxC > 0 ? (maxC - minC) / maxC : 0
        }
        return total / Double(n)
    }

    // MARK: - Sharpness Consistency

    private func analyzeSharpnessConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        // Simplified sharpness measure
        var sharpnessValues: [Double] = []

        for item in images {
            let edges = item.image.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.0])

            guard let filter = CIFilter(name: "CIAreaAverage") else { continue }
            filter.setValue(edges, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: edges.extent), forKey: kCIInputExtentKey)

            guard let outputImage = filter.outputImage else { continue }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

            let sharpness = Double(bitmap[0]) / 255.0
            sharpnessValues.append(sharpness)
        }

        let variance = calculateVariance(sharpnessValues)

        // Smooth decay: 0.000→1.0, 0.020→0.88, 0.040→0.65, 0.065→0.40, 0.120+→0.20
        let score = smoothConsistencyScore(variance, anchors: [
            (variance: 0.000, score: 1.00),
            (variance: 0.020, score: 0.88),
            (variance: 0.040, score: 0.65),
            (variance: 0.065, score: 0.40),
            (variance: 0.120, score: 0.20)
        ])
        let notes = score > 0.7 ? "Sharpness is consistent." : "Sharpness varies across photos."

        return ConsistencyReport.MetricScore(score: score, variance: variance, notes: notes)
    }

    // MARK: - Composition Consistency

    private func analyzeCompositionConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        guard !images.isEmpty else {
            return ConsistencyReport.MetricScore(score: 1.0, variance: 0, notes: "No images to compare.")
        }

        var centroids: [(x: Double, y: Double)] = []
        var aspectRatios: [Double] = []

        for item in images {
            centroids.append(brightnessWeightedCentroid(item.image))
            let ext = item.image.extent
            if ext.height > 0 {
                aspectRatios.append(Double(ext.width / ext.height))
            }
        }

        // Variance in centroid positions captures subject placement inconsistency
        let xVariance = calculateVariance(centroids.map { $0.x })
        let yVariance = calculateVariance(centroids.map { $0.y })
        let centroidVariance = (xVariance + yVariance) / 2.0

        // Detect portrait/landscape mixing (aspect ratio spread)
        let arVariance = calculateVariance(aspectRatios)
        let hasOrientationMix = arVariance > 0.5

        // Score: low centroid variance = consistent framing
        // Smooth decay: 0.000→1.0, 0.010→0.85, 0.030→0.65, 0.060→0.40, 0.120+→0.20
        let rawScore = smoothConsistencyScore(centroidVariance, anchors: [
            (variance: 0.000, score: 1.00),
            (variance: 0.010, score: 0.85),
            (variance: 0.030, score: 0.65),
            (variance: 0.060, score: 0.40),
            (variance: 0.120, score: 0.20)
        ])
        let score = hasOrientationMix ? max(0.2, rawScore - 0.2) : rawScore

        let notes: String
        if score > 0.8 {
            notes = "Subject placement and framing are consistent across photos."
        } else if hasOrientationMix {
            notes = "Mixed portrait and landscape orientations detected in batch."
        } else if centroidVariance > 0.06 {
            notes = "Subject placement varies significantly — framing differs across photos."
        } else {
            notes = "Some variation in subject placement and framing."
        }

        return ConsistencyReport.MetricScore(score: score, variance: centroidVariance, notes: notes)
    }

    /// Returns the brightness-weighted centroid of an image as normalized (x, y) in [0,1].
    /// Uses CIAreaAverage on each image quadrant; (0,0) = top-left, (1,1) = bottom-right.
    private func brightnessWeightedCentroid(_ image: CIImage) -> (x: Double, y: Double) {
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return (0.5, 0.5) }

        let hw = ext.width / 2
        let hh = ext.height / 2

        // CoreImage Y-axis: bottom = minY, top = maxY
        let tl = CGRect(x: ext.minX,      y: ext.minY + hh, width: hw, height: hh)
        let tr = CGRect(x: ext.minX + hw, y: ext.minY + hh, width: hw, height: hh)
        let bl = CGRect(x: ext.minX,      y: ext.minY,      width: hw, height: hh)
        let br = CGRect(x: ext.minX + hw, y: ext.minY,      width: hw, height: hh)

        let tlB = quadrantBrightness(image, rect: tl)
        let trB = quadrantBrightness(image, rect: tr)
        let blB = quadrantBrightness(image, rect: bl)
        let brB = quadrantBrightness(image, rect: br)

        let total = tlB + trB + blB + brB
        guard total > 0 else { return (0.5, 0.5) }

        // cx > 0.5 means right half is brighter (subject leans right)
        let cx = (trB + brB) / total
        // cy: 0 = top, 1 = bottom — convention (0,0) = top-left, (1,1) = bottom-right.
        // Bottom quadrants bright → cy near 1 (subject low). Top quadrants bright → cy near 0 (subject high).
        let cy = (blB + brB) / total

        return (x: cx, y: cy)
    }

    private func quadrantBrightness(_ image: CIImage, rect: CGRect) -> Double {
        let cropped = image.cropped(to: rect)
        guard let avgOutput = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: cropped,
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])?.outputImage else { return 0 }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(
            avgOutput,
            toBitmap: &bitmap,
            rowBytes: 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )
        return Double(0.2126 * bitmap[0] + 0.7152 * bitmap[1] + 0.0722 * bitmap[2])
    }

    // MARK: - Helpers

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }

    /// Piecewise-linear interpolation through (variance, score) anchors — no cliff edges.
    /// Anchors must be sorted ascending by variance.
    private func smoothConsistencyScore(_ variance: Double,
                                        anchors: [(variance: Double, score: Double)]) -> Double {
        if variance <= anchors.first!.variance { return anchors.first!.score }
        if variance >= anchors.last!.variance  { return anchors.last!.score }
        for i in 0..<anchors.count - 1 {
            let lo = anchors[i], hi = anchors[i + 1]
            if variance < hi.variance {
                let t = (variance - lo.variance) / (hi.variance - lo.variance)
                return lo.score + t * (hi.score - lo.score)
            }
        }
        return anchors.last!.score
    }

    private func calculateOverallConsistency(metrics: ConsistencyReport.ConsistencyMetrics) -> Double {
        let scores = [
            metrics.exposureConsistency.score * 0.3,
            metrics.whiteBalanceConsistency.score * 0.25,
            metrics.colorConsistency.score * 0.2,
            metrics.sharpnessConsistency.score * 0.15,
            metrics.compositionConsistency.score * 0.1
        ]
        return scores.reduce(0, +)
    }

    // MARK: - Outlier Detection

    private func identifyOutliers(
        images: [(image: CIImage, photoID: UUID)],
        metrics: ConsistencyReport.ConsistencyMetrics
    ) -> [ConsistencyReport.OutlierPhoto] {
        var outliers: [ConsistencyReport.OutlierPhoto] = []

        // Check exposure outliers
        let brightnesses = images.map { calculateAverageBrightness($0.image) }
        let meanBrightness = brightnesses.reduce(0, +) / Double(brightnesses.count)
        let stdDev = sqrt(calculateVariance(brightnesses))

        for (index, brightness) in brightnesses.enumerated() {
            let deviation = abs(brightness - meanBrightness) / (stdDev > 0 ? stdDev : 1.0)

            if deviation > 2.0 {  // 2 standard deviations
                outliers.append(ConsistencyReport.OutlierPhoto(
                    photoID: images[index].photoID,
                    metric: "Exposure",
                    deviation: deviation,
                    currentValue: brightness,
                    targetValue: meanBrightness,
                    suggestion: brightness > meanBrightness ? "Reduce exposure" : "Increase exposure"
                ))
            }
        }

        return outliers
    }

    // MARK: - Recommendations

    private func generateRecommendations(
        metrics: ConsistencyReport.ConsistencyMetrics,
        outliers: [ConsistencyReport.OutlierPhoto],
        images: [(image: CIImage, photoID: UUID)]
    ) -> [ConsistencyReport.BatchRecommendation] {
        var recommendations: [ConsistencyReport.BatchRecommendation] = []

        // Exposure consistency
        if metrics.exposureConsistency.score < 0.7 {
            recommendations.append(ConsistencyReport.BatchRecommendation(
                category: "Exposure",
                issue: "Inconsistent exposure across batch",
                suggestion: "Normalize exposure to match brightest or average photo",
                affectedPhotos: images.map { $0.photoID },
                priority: .high,
                batchCorrection: ConsistencyReport.BatchCorrection(
                    type: .exposure,
                    targetValue: 0.0,  // Would calculate actual target
                    applyTo: .outliers
                )
            ))
        }

        // White balance consistency
        if metrics.whiteBalanceConsistency.score < 0.7 {
            recommendations.append(ConsistencyReport.BatchRecommendation(
                category: "White Balance",
                issue: "Inconsistent color temperature",
                suggestion: "Sync white balance across all photos",
                affectedPhotos: images.map { $0.photoID },
                priority: .high,
                batchCorrection: ConsistencyReport.BatchCorrection(
                    type: .temperature,
                    targetValue: 6500,
                    applyTo: .all
                )
            ))
        }

        // Color consistency
        if metrics.colorConsistency.score < 0.7 {
            recommendations.append(ConsistencyReport.BatchRecommendation(
                category: "Color",
                issue: "Inconsistent color saturation across batch",
                suggestion: "Normalize vibrance and saturation to unify the look",
                affectedPhotos: images.map { $0.photoID },
                priority: .medium,
                batchCorrection: ConsistencyReport.BatchCorrection(
                    type: .vibrance,
                    targetValue: 0.0,
                    applyTo: .outliers
                )
            ))
        }

        // Sharpness consistency
        if metrics.sharpnessConsistency.score < 0.7 {
            recommendations.append(ConsistencyReport.BatchRecommendation(
                category: "Sharpness",
                issue: "Inconsistent sharpness across batch",
                suggestion: "Apply uniform sharpening to soft photos to match the set",
                affectedPhotos: images.map { $0.photoID },
                priority: .medium,
                batchCorrection: ConsistencyReport.BatchCorrection(
                    type: .sharpness,
                    targetValue: 0.5,
                    applyTo: .outliers
                )
            ))
        }

        // Composition consistency
        if metrics.compositionConsistency.score < 0.7 {
            recommendations.append(ConsistencyReport.BatchRecommendation(
                category: "Composition",
                issue: "Inconsistent framing and subject placement",
                suggestion: "Review framing and crop photos to a consistent aspect ratio and placement",
                affectedPhotos: images.map { $0.photoID },
                priority: .low,
                batchCorrection: nil
            ))
        }

        return recommendations
    }
}

// MARK: - Errors

enum BatchAnalysisError: Error, LocalizedError {
    case insufficientPhotos
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .insufficientPhotos:
            return "Need at least 2 photos to analyze batch consistency"
        case .analysisFailed:
            return "Batch analysis failed"
        }
    }
}
