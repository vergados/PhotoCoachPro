//
//  SkillHistory.swift
//  PhotoCoachPro
//
//  Historical skill performance tracking
//

import Foundation

/// Tracks historical skill performance across all categories
struct SkillHistory: Codable, Identifiable, Equatable {
    var id: UUID
    var userID: UUID
    var metrics: [SkillMetric.SkillCategory: SkillMetric]
    var sessions: [PracticeSession]
    var milestones: [Milestone]
    var createdAt: Date
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.metrics = [:]
        self.sessions = []
        self.milestones = []
        self.createdAt = createdAt
        self.lastUpdated = createdAt

        // Initialize all skill categories
        for category in SkillMetric.SkillCategory.allCases {
            metrics[category] = SkillMetric(category: category)
        }
    }

    // MARK: - Practice Session

    struct PracticeSession: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var date: Date
        var photosAnalyzed: Int
        var focusArea: SkillMetric.SkillCategory?
        var averageScore: Double
        var improvementAreas: [SkillMetric.SkillCategory]
        var notes: String?

        init(
            date: Date = Date(),
            photosAnalyzed: Int,
            focusArea: SkillMetric.SkillCategory? = nil,
            averageScore: Double,
            improvementAreas: [SkillMetric.SkillCategory] = [],
            notes: String? = nil
        ) {
            self.date = date
            self.photosAnalyzed = photosAnalyzed
            self.focusArea = focusArea
            self.averageScore = averageScore
            self.improvementAreas = improvementAreas
            self.notes = notes
        }
    }

    // MARK: - Milestone

    struct Milestone: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: SkillMetric.SkillCategory
        var achievedScore: Double
        var achievedAt: Date
        var type: MilestoneType
        var photoID: UUID?

        enum MilestoneType: String, Codable {
            case beginner = "Beginner"           // 0.5
            case improving = "Improving"         // 0.6
            case competent = "Competent"         // 0.7
            case proficient = "Proficient"       // 0.8
            case expert = "Expert"               // 0.9
            case master = "Master"               // 0.95

            var threshold: Double {
                switch self {
                case .beginner: return 0.5
                case .improving: return 0.6
                case .competent: return 0.7
                case .proficient: return 0.8
                case .expert: return 0.9
                case .master: return 0.95
                }
            }

            var icon: String {
                switch self {
                case .beginner: return "star"
                case .improving: return "star.fill"
                case .competent: return "rosette"
                case .proficient: return "seal"
                case .expert: return "crown"
                case .master: return "crown.fill"
                }
            }

            static func milestone(for score: Double) -> MilestoneType? {
                if score >= 0.95 { return .master }
                if score >= 0.9 { return .expert }
                if score >= 0.8 { return .proficient }
                if score >= 0.7 { return .competent }
                if score >= 0.6 { return .improving }
                if score >= 0.5 { return .beginner }
                return nil
            }
        }

        init(
            category: SkillMetric.SkillCategory,
            achievedScore: Double,
            achievedAt: Date = Date(),
            type: MilestoneType,
            photoID: UUID? = nil
        ) {
            self.category = category
            self.achievedScore = achievedScore
            self.achievedAt = achievedAt
            self.type = type
            self.photoID = photoID
        }
    }

    // MARK: - Computed Properties

    var overallScore: Double {
        guard !metrics.isEmpty else { return 0 }
        let scores = metrics.values.map { $0.currentScore }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var strongestSkill: (category: SkillMetric.SkillCategory, metric: SkillMetric)? {
        metrics.max { $0.value.currentScore < $1.value.currentScore }
            .map { (category: $0.key, metric: $0.value) }
    }

    var weakestSkill: (category: SkillMetric.SkillCategory, metric: SkillMetric)? {
        metrics.min { $0.value.currentScore < $1.value.currentScore }
            .map { (category: $0.key, metric: $0.value) }
    }

    var improvingSkills: [SkillMetric.SkillCategory] {
        metrics.filter { $0.value.trend == .improving }.map { $0.key }
    }

    var decliningSkills: [SkillMetric.SkillCategory] {
        metrics.filter { $0.value.trend == .declining }.map { $0.key }
    }

    var totalPhotosAnalyzed: Int {
        sessions.map { $0.photosAnalyzed }.reduce(0, +)
    }

    var recentSessions: [PracticeSession] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return sessions.filter { $0.date >= twoWeeksAgo }
    }

    var recentMilestones: [Milestone] {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return milestones.filter { $0.achievedAt >= oneMonthAgo }
    }

    // MARK: - Update Methods

    /// Record a new critique result
    mutating func recordCritique(_ critique: CritiqueResult) {
        // Update each category metric
        updateMetric(.composition, score: critique.categories.composition.score, photoID: critique.photoID, critiqueID: critique.id)
        updateMetric(.lighting, score: critique.categories.light.score, photoID: critique.photoID, critiqueID: critique.id)
        updateMetric(.focus, score: critique.categories.focus.score, photoID: critique.photoID, critiqueID: critique.id)
        updateMetric(.color, score: critique.categories.color.score, photoID: critique.photoID, critiqueID: critique.id)
        updateMetric(.background, score: critique.categories.background.score, photoID: critique.photoID, critiqueID: critique.id)
        updateMetric(.storytelling, score: critique.categories.story.score, photoID: critique.photoID, critiqueID: critique.id)

        lastUpdated = Date()
    }

    /// Update a specific metric with new measurement
    private mutating func updateMetric(_ category: SkillMetric.SkillCategory, score: Double, photoID: UUID, critiqueID: UUID) {
        guard var metric = metrics[category] else { return }

        let measurement = SkillMetric.Measurement(
            score: score,
            timestamp: Date(),
            photoID: photoID,
            critiqueID: critiqueID
        )

        let previousScore = metric.currentScore
        metric.addMeasurement(measurement)
        metrics[category] = metric

        // Check for milestone achievement
        if let milestoneType = Milestone.MilestoneType.milestone(for: score),
           score >= milestoneType.threshold && previousScore < milestoneType.threshold {
            addMilestone(category: category, score: score, type: milestoneType, photoID: photoID)
        }
    }

    /// Add a practice session
    mutating func addSession(_ session: PracticeSession) {
        sessions.append(session)
        lastUpdated = Date()
    }

    /// Add a milestone
    private mutating func addMilestone(category: SkillMetric.SkillCategory, score: Double, type: Milestone.MilestoneType, photoID: UUID) {
        // Avoid duplicate milestones
        let exists = milestones.contains { $0.category == category && $0.type == type }
        guard !exists else { return }

        let milestone = Milestone(
            category: category,
            achievedScore: score,
            achievedAt: Date(),
            type: type,
            photoID: photoID
        )

        milestones.append(milestone)
    }

    // MARK: - Query Methods

    /// Get metric for category
    func metric(for category: SkillMetric.SkillCategory) -> SkillMetric? {
        metrics[category]
    }

    /// Get all measurements for category in date range
    func measurements(for category: SkillMetric.SkillCategory, from startDate: Date, to endDate: Date) -> [SkillMetric.Measurement] {
        guard let metric = metrics[category] else { return [] }
        return metric.measurements(from: startDate, to: endDate)
    }

    /// Get sessions in date range
    func sessions(from startDate: Date, to endDate: Date) -> [PracticeSession] {
        sessions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Get milestones for category
    func milestones(for category: SkillMetric.SkillCategory) -> [Milestone] {
        milestones.filter { $0.category == category }.sorted { $0.achievedAt < $1.achievedAt }
    }

    /// Calculate progress over time period
    func progressReport(days: Int) -> ProgressReport {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        var categoryProgress: [SkillMetric.SkillCategory: Double] = [:]

        for (category, metric) in metrics {
            let measurements = metric.measurements(from: startDate, to: Date())
            guard measurements.count >= 2 else {
                categoryProgress[category] = 0
                continue
            }

            let sorted = measurements.sorted { $0.timestamp < $1.timestamp }
            if let first = sorted.first, let last = sorted.last {
                categoryProgress[category] = last.score - first.score
            } else {
                categoryProgress[category] = 0
            }
        }

        let sessionsInPeriod = sessions(from: startDate, to: Date())
        let milestonesInPeriod = milestones.filter { $0.achievedAt >= startDate }

        return ProgressReport(
            period: days,
            categoryProgress: categoryProgress,
            totalSessions: sessionsInPeriod.count,
            totalPhotos: sessionsInPeriod.map { $0.photosAnalyzed }.reduce(0, +),
            milestonesAchieved: milestonesInPeriod.count
        )
    }

    struct ProgressReport: Codable, Equatable {
        var period: Int  // days
        var categoryProgress: [SkillMetric.SkillCategory: Double]
        var totalSessions: Int
        var totalPhotos: Int
        var milestonesAchieved: Int

        var mostImproved: SkillMetric.SkillCategory? {
            categoryProgress.max { $0.value < $1.value }?.key
        }

        var needsWork: [SkillMetric.SkillCategory] {
            categoryProgress.filter { $0.value < 0 }.map { $0.key }
        }
    }

    // MARK: - Statistics

    /// Get statistics summary
    func statistics() -> Statistics {
        Statistics(
            totalMeasurements: metrics.values.map { $0.measurements.count }.reduce(0, +),
            totalSessions: sessions.count,
            totalMilestones: milestones.count,
            averageScore: overallScore,
            daysTracking: daysSinceCreation,
            strongestCategory: strongestSkill?.category,
            weakestCategory: weakestSkill?.category
        )
    }

    struct Statistics: Codable, Equatable {
        var totalMeasurements: Int
        var totalSessions: Int
        var totalMilestones: Int
        var averageScore: Double
        var daysTracking: Int
        var strongestCategory: SkillMetric.SkillCategory?
        var weakestCategory: SkillMetric.SkillCategory?
    }

    private var daysSinceCreation: Int {
        let components = Calendar.current.dateComponents([.day], from: createdAt, to: Date())
        return components.day ?? 0
    }
}
