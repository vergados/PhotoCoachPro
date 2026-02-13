//
//  SkillMetric.swift
//  PhotoCoachPro
//
//  Individual skill metric tracking
//

import Foundation

/// Represents a single trackable skill metric
struct SkillMetric: Codable, Identifiable, Equatable {
    var id: UUID
    var category: SkillCategory
    var currentScore: Double  // 0.0 to 1.0
    var targetScore: Double   // 0.0 to 1.0
    var measurements: [Measurement]
    var trend: Trend
    var lastUpdated: Date
    var improvementRate: Double  // Score change per week

    init(
        id: UUID = UUID(),
        category: SkillCategory,
        currentScore: Double = 0.5,
        targetScore: Double = 0.8,
        measurements: [Measurement] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.currentScore = currentScore
        self.targetScore = targetScore
        self.measurements = measurements
        self.trend = .stable
        self.lastUpdated = lastUpdated
        self.improvementRate = 0.0
    }

    // MARK: - Skill Categories

    enum SkillCategory: String, Codable, CaseIterable {
        case composition = "Composition"
        case lighting = "Light"
        case focus = "Focus & Sharpness"
        case color = "Color Theory"
        case background = "Background Management"
        case storytelling = "Visual Storytelling"

        var description: String {
            switch self {
            case .composition:
                return "Framing, balance, rule of thirds, visual flow"
            case .lighting:
                return "Exposure, dynamic range, contrast control"
            case .focus:
                return "Sharpness, depth of field, critical focus"
            case .color:
                return "White balance, saturation, color harmony"
            case .background:
                return "Subject isolation, background simplification"
            case .storytelling:
                return "Subject clarity, emotional impact, message"
            }
        }

        var icon: String {
            switch self {
            case .composition: return "viewfinder"
            case .lighting: return "sun.max"
            case .focus: return "camera.aperture"
            case .color: return "paintpalette"
            case .background: return "person.crop.rectangle"
            case .storytelling: return "text.bubble"
            }
        }
    }

    // MARK: - Measurement

    struct Measurement: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var score: Double
        var timestamp: Date
        var photoID: UUID
        var critiqueID: UUID

        init(score: Double, timestamp: Date = Date(), photoID: UUID, critiqueID: UUID) {
            self.score = score
            self.timestamp = timestamp
            self.photoID = photoID
            self.critiqueID = critiqueID
        }
    }

    // MARK: - Trend

    enum Trend: String, Codable {
        case improving = "Improving"
        case stable = "Stable"
        case declining = "Declining"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            case .unknown: return "questionmark"
            }
        }

        var color: String {
            switch self {
            case .improving: return "green"
            case .stable: return "blue"
            case .declining: return "orange"
            case .unknown: return "gray"
            }
        }
    }

    // MARK: - Computed Properties

    var progressToTarget: Double {
        guard targetScore > 0 else { return 0 }
        return min(1.0, currentScore / targetScore)
    }

    var isOnTrack: Bool {
        progressToTarget >= 0.7 && trend != .declining
    }

    var needsFocus: Bool {
        currentScore < 0.6 || trend == .declining
    }

    var recentMeasurements: [Measurement] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return measurements.filter { $0.timestamp >= twoWeeksAgo }
    }

    var averageRecentScore: Double {
        guard !recentMeasurements.isEmpty else { return currentScore }
        let sum = recentMeasurements.map { $0.score }.reduce(0, +)
        return sum / Double(recentMeasurements.count)
    }

    // MARK: - Methods

    /// Add a new measurement and update metrics
    mutating func addMeasurement(_ measurement: Measurement) {
        measurements.append(measurement)
        lastUpdated = measurement.timestamp
        currentScore = measurement.score

        // Recalculate trend and improvement rate
        updateTrend()
        updateImprovementRate()
    }

    /// Calculate trend based on recent measurements
    private mutating func updateTrend() {
        guard measurements.count >= 3 else {
            trend = .unknown
            return
        }

        let recent = measurements.suffix(10)
        let scores = recent.map { $0.score }

        // Simple linear regression slope
        let n = Double(scores.count)
        let indices = Array(0..<scores.count).map { Double($0) }

        let sumX = indices.reduce(0, +)
        let sumY = scores.reduce(0, +)
        let sumXY = zip(indices, scores).map(*).reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)

        if slope > 0.01 {
            trend = .improving
        } else if slope < -0.01 {
            trend = .declining
        } else {
            trend = .stable
        }
    }

    /// Calculate improvement rate (score change per week)
    private mutating func updateImprovementRate() {
        guard measurements.count >= 2 else {
            improvementRate = 0.0
            return
        }

        let sorted = measurements.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first, let last = sorted.last else {
            improvementRate = 0.0
            return
        }

        let timeInterval = last.timestamp.timeIntervalSince(first.timestamp)
        let weeks = timeInterval / (7 * 24 * 60 * 60)

        guard weeks > 0 else {
            improvementRate = 0.0
            return
        }

        let scoreChange = last.score - first.score
        improvementRate = scoreChange / weeks
    }

    /// Get measurement for specific photo
    func measurement(for photoID: UUID) -> Measurement? {
        measurements.first { $0.photoID == photoID }
    }

    /// Get measurements in date range
    func measurements(from startDate: Date, to endDate: Date) -> [Measurement] {
        measurements.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Reset metric (clear measurements)
    mutating func reset() {
        measurements = []
        currentScore = 0.5
        trend = .unknown
        improvementRate = 0.0
        lastUpdated = Date()
    }

    // MARK: - Practice Recommendations

    func practiceRecommendation() -> String {
        switch category {
        case .composition:
            if currentScore < 0.6 {
                return "Practice: Use grid overlay. Place subjects at thirds intersections. Study professional photographers' framing."
            } else if currentScore < 0.8 {
                return "Practice: Experiment with negative space. Try unconventional angles. Study visual weight and balance."
            } else {
                return "Practice: Master advanced techniques like leading lines, layers, and golden ratio."
            }

        case .lighting:
            if currentScore < 0.6 {
                return "Practice: Study histogram. Avoid clipping. Shoot during golden hour for softer light."
            } else if currentScore < 0.8 {
                return "Practice: Experiment with backlighting. Use reflectors. Master dynamic range."
            } else {
                return "Practice: Advanced techniques like high-key, low-key, and dramatic lighting."
            }

        case .focus:
            if currentScore < 0.6 {
                return "Practice: Use single-point AF. Focus on eyes in portraits. Check sharpness at 100% zoom."
            } else if currentScore < 0.8 {
                return "Practice: Experiment with aperture. Master focus stacking. Use back-button focus."
            } else {
                return "Practice: Advanced techniques like zone focusing and hyperfocal distance."
            }

        case .color:
            if currentScore < 0.6 {
                return "Practice: Set custom white balance. Avoid over-saturation. Study color wheel basics."
            } else if currentScore < 0.8 {
                return "Practice: Master complementary colors. Experiment with color grading. Study color psychology."
            } else {
                return "Practice: Advanced color theory, split complementary schemes, and color storytelling."
            }

        case .background:
            if currentScore < 0.6 {
                return "Practice: Use wider apertures (f/2.8 or lower). Move subjects away from background. Find clean backgrounds."
            } else if currentScore < 0.8 {
                return "Practice: Use longer focal lengths for compression. Master depth of field. Control background elements."
            } else {
                return "Practice: Advanced techniques like bokeh control and environmental context."
            }

        case .storytelling:
            if currentScore < 0.6 {
                return "Practice: Define clear subject. Remove distractions. Ask 'what's the story?' before shooting."
            } else if currentScore < 0.8 {
                return "Practice: Add context and layers. Use visual metaphors. Study photojournalism."
            } else {
                return "Practice: Master visual narratives, series work, and emotional storytelling."
            }
        }
    }
}
