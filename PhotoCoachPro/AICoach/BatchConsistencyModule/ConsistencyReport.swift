//
//  ConsistencyReport.swift
//  PhotoCoachPro
//
//  Batch consistency analysis report
//

import Foundation

/// Report analyzing consistency across a batch of photos
struct ConsistencyReport: Codable, Identifiable, Equatable {
    var id: UUID
    var batchID: UUID
    var photoIDs: [UUID]
    var timestamp: Date
    var overallConsistency: Double  // 0.0 to 1.0
    var metrics: ConsistencyMetrics
    var recommendations: [BatchRecommendation]
    var outliers: [OutlierPhoto]

    init(
        id: UUID = UUID(),
        batchID: UUID,
        photoIDs: [UUID],
        timestamp: Date = Date(),
        overallConsistency: Double,
        metrics: ConsistencyMetrics,
        recommendations: [BatchRecommendation],
        outliers: [OutlierPhoto]
    ) {
        self.id = id
        self.batchID = batchID
        self.photoIDs = photoIDs
        self.timestamp = timestamp
        self.overallConsistency = overallConsistency
        self.metrics = metrics
        self.recommendations = recommendations
        self.outliers = outliers
    }

    // MARK: - Consistency Metrics

    struct ConsistencyMetrics: Codable, Equatable {
        var exposureConsistency: MetricScore
        var whiteBalanceConsistency: MetricScore
        var colorConsistency: MetricScore
        var sharpnessConsistency: MetricScore
        var compositionConsistency: MetricScore

        var weakestMetric: (name: String, score: MetricScore) {
            let metrics = [
                ("Exposure", exposureConsistency),
                ("White Balance", whiteBalanceConsistency),
                ("Color", colorConsistency),
                ("Sharpness", sharpnessConsistency),
                ("Composition", compositionConsistency)
            ]
            return metrics.min { $0.1.score < $1.1.score } ?? ("Unknown", exposureConsistency)
        }
    }

    struct MetricScore: Codable, Equatable {
        var score: Double          // 0.0 to 1.0
        var variance: Double       // Measure of spread
        var rating: Rating
        var notes: String

        enum Rating: String, Codable {
            case veryConsistent = "Very Consistent"
            case consistent = "Consistent"
            case moderate = "Moderate Variation"
            case inconsistent = "Inconsistent"
            case veryInconsistent = "Very Inconsistent"

            init(score: Double) {
                switch score {
                case 0.9...1.0: self = .veryConsistent
                case 0.75..<0.9: self = .consistent
                case 0.5..<0.75: self = .moderate
                case 0.25..<0.5: self = .inconsistent
                default: self = .veryInconsistent
                }
            }
        }

        init(score: Double, variance: Double, notes: String) {
            self.score = score
            self.variance = variance
            self.rating = Rating(score: score)
            self.notes = notes
        }
    }

    // MARK: - Recommendations

    struct BatchRecommendation: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: String
        var issue: String
        var suggestion: String
        var affectedPhotos: [UUID]
        var priority: Priority
        var batchCorrection: BatchCorrection?

        enum Priority: String, Codable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }

        init(
            category: String,
            issue: String,
            suggestion: String,
            affectedPhotos: [UUID],
            priority: Priority,
            batchCorrection: BatchCorrection? = nil
        ) {
            self.category = category
            self.issue = issue
            self.suggestion = suggestion
            self.affectedPhotos = affectedPhotos
            self.priority = priority
            self.batchCorrection = batchCorrection
        }
    }

    struct BatchCorrection: Codable, Equatable {
        var type: CorrectionType
        var targetValue: Double
        var applyTo: ApplicationMode

        enum CorrectionType: String, Codable {
            case exposure = "Exposure"
            case temperature = "Temperature"
            case tint = "Tint"
            case saturation = "Saturation"
            case vibrance = "Vibrance"
            case contrast = "Contrast"
            case sharpness = "Sharpness"
        }

        enum ApplicationMode: String, Codable {
            case all = "All Photos"
            case outliers = "Outliers Only"
            case specific = "Specific Photos"
        }

        init(type: CorrectionType, targetValue: Double, applyTo: ApplicationMode) {
            self.type = type
            self.targetValue = targetValue
            self.applyTo = applyTo
        }
    }

    // MARK: - Outliers

    struct OutlierPhoto: Codable, Identifiable, Equatable {
        var id: UUID { photoID }
        var photoID: UUID
        var metric: String
        var deviation: Double      // Standard deviations from mean
        var currentValue: Double
        var targetValue: Double
        var suggestion: String

        init(
            photoID: UUID,
            metric: String,
            deviation: Double,
            currentValue: Double,
            targetValue: Double,
            suggestion: String
        ) {
            self.photoID = photoID
            self.metric = metric
            self.deviation = deviation
            self.currentValue = currentValue
            self.targetValue = targetValue
            self.suggestion = suggestion
        }
    }

    // MARK: - Summary

    var summaryText: String {
        let rating = MetricScore.Rating(score: overallConsistency)

        switch rating {
        case .veryConsistent:
            return "Excellent batch consistency. Photos have uniform look and feel."
        case .consistent:
            return "Good batch consistency with minor variations."
        case .moderate:
            return "Moderate consistency. Some photos deviate from the set."
        case .inconsistent:
            return "Inconsistent batch. Significant variations across photos."
        case .veryInconsistent:
            return "Very inconsistent batch. Photos look disconnected."
        }
    }

    var hasOutliers: Bool {
        !outliers.isEmpty
    }

    var criticalRecommendations: [BatchRecommendation] {
        recommendations.filter { $0.priority == .critical || $0.priority == .high }
    }
}
