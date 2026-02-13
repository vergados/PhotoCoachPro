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

        // Score based on standard deviation (lower = more consistent)
        let score: Double
        if stdDev < 0.05 {
            score = 1.0
        } else if stdDev < 0.10 {
            score = 0.8
        } else if stdDev < 0.15 {
            score = 0.6
        } else {
            score = 0.3
        }

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

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / (3.0 * 255.0)
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

        let score: Double
        if avgVariance < 0.01 {
            score = 1.0
        } else if avgVariance < 0.03 {
            score = 0.8
        } else if avgVariance < 0.05 {
            score = 0.6
        } else {
            score = 0.3
        }

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

        let score: Double
        if variance < 0.02 {
            score = 1.0
        } else if variance < 0.05 {
            score = 0.8
        } else if variance < 0.10 {
            score = 0.6
        } else {
            score = 0.3
        }

        let notes = score > 0.7 ? "Color saturation is consistent." : "Color saturation varies. Consider normalizing vibrance."

        return ConsistencyReport.MetricScore(score: score, variance: variance, notes: notes)
    }

    private func calculateAverageSaturation(_ image: CIImage) -> Double {
        let cast = calculateColorCast(image)
        let maxC = max(cast.r, cast.g, cast.b)
        let minC = min(cast.r, cast.g, cast.b)
        return maxC > 0 ? (maxC - minC) / maxC : 0
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

        let score = variance < 0.02 ? 1.0 : (variance < 0.05 ? 0.7 : 0.4)
        let notes = score > 0.7 ? "Sharpness is consistent." : "Sharpness varies across photos."

        return ConsistencyReport.MetricScore(score: score, variance: variance, notes: notes)
    }

    // MARK: - Composition Consistency

    private func analyzeCompositionConsistency(images: [(image: CIImage, photoID: UUID)]) -> ConsistencyReport.MetricScore {
        // Simplified: assume moderate consistency for composition
        // Real implementation would analyze framing, subject placement, etc.
        return ConsistencyReport.MetricScore(
            score: 0.7,
            variance: 0.05,
            notes: "Composition consistency analysis requires manual review."
        )
    }

    // MARK: - Helpers

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
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
