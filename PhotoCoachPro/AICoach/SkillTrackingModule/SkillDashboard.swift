//
//  SkillDashboard.swift
//  PhotoCoachPro
//
//  Aggregated skill tracking dashboard
//

import Foundation

/// Aggregated view of all skill tracking data
struct SkillDashboard: Codable, Identifiable, Equatable {
    var id: UUID
    var history: SkillHistory
    var currentPlan: WeeklyFocusPlan?
    var insights: [Insight]
    var achievements: [Achievement]
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        history: SkillHistory,
        currentPlan: WeeklyFocusPlan? = nil,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.history = history
        self.currentPlan = currentPlan
        self.insights = []
        self.achievements = []
        self.generatedAt = generatedAt

        // Generate insights and achievements
        self.insights = Self.generateInsights(from: history, plan: currentPlan)
        self.achievements = Self.generateAchievements(from: history)
    }

    // MARK: - Insight

    struct Insight: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var type: InsightType
        var category: SkillMetric.SkillCategory?
        var title: String
        var message: String
        var priority: Priority

        enum InsightType: String, Codable {
            case improvement = "Improvement"
            case concern = "Concern"
            case milestone = "Milestone"
            case recommendation = "Recommendation"
            case celebration = "Celebration"

            var icon: String {
                switch self {
                case .improvement: return "arrow.up.circle.fill"
                case .concern: return "exclamationmark.triangle.fill"
                case .milestone: return "star.circle.fill"
                case .recommendation: return "lightbulb.fill"
                case .celebration: return "party.popper.fill"
                }
            }

            var color: String {
                switch self {
                case .improvement: return "green"
                case .concern: return "orange"
                case .milestone: return "blue"
                case .recommendation: return "purple"
                case .celebration: return "yellow"
                }
            }
        }

        enum Priority: String, Codable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }

        init(
            type: InsightType,
            category: SkillMetric.SkillCategory? = nil,
            title: String,
            message: String,
            priority: Priority = .medium
        ) {
            self.type = type
            self.category = category
            self.title = title
            self.message = message
            self.priority = priority
        }
    }

    // MARK: - Achievement

    struct Achievement: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var type: AchievementType
        var title: String
        var description: String
        var earnedAt: Date
        var category: SkillMetric.SkillCategory?
        var metadata: [String: String]

        enum AchievementType: String, Codable {
            case firstCritique = "First Critique"
            case tenCritiques = "10 Critiques"
            case hundredCritiques = "100 Critiques"
            case weekStreak = "Week Streak"
            case monthStreak = "Month Streak"
            case skillMastery = "Skill Mastery"
            case allRounder = "All-Rounder"
            case rapidImprovement = "Rapid Improvement"
            case consistent = "Consistent Practice"

            var icon: String {
                switch self {
                case .firstCritique: return "star.fill"
                case .tenCritiques: return "rosette"
                case .hundredCritiques: return "crown.fill"
                case .weekStreak: return "flame.fill"
                case .monthStreak: return "flame.fill"
                case .skillMastery: return "graduationcap.fill"
                case .allRounder: return "seal.fill"
                case .rapidImprovement: return "bolt.fill"
                case .consistent: return "calendar.badge.checkmark"
                }
            }
        }

        init(
            type: AchievementType,
            title: String,
            description: String,
            earnedAt: Date = Date(),
            category: SkillMetric.SkillCategory? = nil,
            metadata: [String: String] = [:]
        ) {
            self.type = type
            self.title = title
            self.description = description
            self.earnedAt = earnedAt
            self.category = category
            self.metadata = metadata
        }
    }

    // MARK: - Computed Properties

    var overallScore: Double {
        history.overallScore
    }

    var overallRating: String {
        switch overallScore {
        case 0.9...1.0: return "Expert"
        case 0.8..<0.9: return "Proficient"
        case 0.7..<0.8: return "Competent"
        case 0.6..<0.7: return "Improving"
        default: return "Developing"
        }
    }

    var highPriorityInsights: [Insight] {
        insights.filter { $0.priority == .high }
    }

    var recentAchievements: [Achievement] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return achievements.filter { $0.earnedAt >= twoWeeksAgo }
    }

    var weeklyProgress: Double {
        guard let plan = currentPlan else { return 0 }
        return plan.completionRate
    }

    // MARK: - Summary

    func summary() -> Summary {
        Summary(
            overallScore: overallScore,
            overallRating: overallRating,
            totalPhotos: history.totalPhotosAnalyzed,
            totalMilestones: history.milestones.count,
            strongestSkill: history.strongestSkill?.category,
            weakestSkill: history.weakestSkill?.category,
            improvingSkills: history.improvingSkills.count,
            decliningSkills: history.decliningSkills.count,
            currentFocus: currentPlan?.primaryFocus,
            weeklyProgress: weeklyProgress
        )
    }

    struct Summary: Codable, Equatable {
        var overallScore: Double
        var overallRating: String
        var totalPhotos: Int
        var totalMilestones: Int
        var strongestSkill: SkillMetric.SkillCategory?
        var weakestSkill: SkillMetric.SkillCategory?
        var improvingSkills: Int
        var decliningSkills: Int
        var currentFocus: SkillMetric.SkillCategory?
        var weeklyProgress: Double
    }

    // MARK: - Insight Generation

    private static func generateInsights(from history: SkillHistory, plan: WeeklyFocusPlan?) -> [Insight] {
        var insights: [Insight] = []

        // Check for declining skills
        for category in history.decliningSkills {
            insights.append(Insight(
                type: .concern,
                category: category,
                title: "\(category.rawValue) is Declining",
                message: "Your \(category.rawValue) score has decreased recently. Consider focusing practice here.",
                priority: .high
            ))
        }

        // Check for improving skills
        for category in history.improvingSkills {
            if let metric = history.metrics[category], metric.improvementRate > 0.05 {
                insights.append(Insight(
                    type: .improvement,
                    category: category,
                    title: "\(category.rawValue) is Improving",
                    message: "Great progress! You're improving \(category.rawValue) at \(String(format: "%.1f", metric.improvementRate * 100))% per week.",
                    priority: .low
                ))
            }
        }

        // Check for milestones
        if let recentMilestone = history.recentMilestones.first {
            insights.append(Insight(
                type: .milestone,
                category: recentMilestone.category,
                title: "New Milestone!",
                message: "You achieved \(recentMilestone.type.rawValue) in \(recentMilestone.category.rawValue)!",
                priority: .medium
            ))
        }

        // Check weak areas
        if let weakest = history.weakestSkill, weakest.metric.currentScore < 0.6 {
            insights.append(Insight(
                type: .recommendation,
                category: weakest.category,
                title: "Focus Area Suggestion",
                message: "\(weakest.category.rawValue) is your weakest area. Dedicated practice could yield significant improvement.",
                priority: .high
            ))
        }

        // Check overall improvement
        let report = history.progressReport(days: 30)
        if report.totalPhotos > 20 && report.milestonesAchieved > 0 {
            insights.append(Insight(
                type: .celebration,
                title: "Strong Month!",
                message: "You analyzed \(report.totalPhotos) photos and achieved \(report.milestonesAchieved) milestone(s) this month!",
                priority: .low
            ))
        }

        // Check plan progress
        if let plan = plan, plan.isActive && plan.completionRate < 0.3 && plan.daysRemaining < 3 {
            insights.append(Insight(
                type: .recommendation,
                title: "Weekly Plan at Risk",
                message: "Only \(plan.daysRemaining) days left and \(String(format: "%.0f", plan.completionRate * 100))% complete. Try to finish remaining exercises.",
                priority: .medium
            ))
        }

        return insights.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }

    // MARK: - Achievement Generation

    private static func generateAchievements(from history: SkillHistory) -> [Achievement] {
        var achievements: [Achievement] = []

        let totalMeasurements = history.metrics.values.map { $0.measurements.count }.reduce(0, +)

        // First critique
        if totalMeasurements >= 1 {
            achievements.append(Achievement(
                type: .firstCritique,
                title: "First Steps",
                description: "Completed your first photo critique"
            ))
        }

        // 10 critiques
        if totalMeasurements >= 10 {
            achievements.append(Achievement(
                type: .tenCritiques,
                title: "Getting Started",
                description: "Completed 10 photo critiques"
            ))
        }

        // 100 critiques
        if totalMeasurements >= 100 {
            achievements.append(Achievement(
                type: .hundredCritiques,
                title: "Dedicated Learner",
                description: "Completed 100 photo critiques"
            ))
        }

        // Skill mastery (any category over 0.9)
        for (category, metric) in history.metrics where metric.currentScore >= 0.9 {
            achievements.append(Achievement(
                type: .skillMastery,
                title: "\(category.rawValue) Master",
                description: "Achieved mastery in \(category.rawValue)",
                category: category
            ))
        }

        // All-rounder (all categories over 0.75)
        let allCategoriesGood = history.metrics.values.allSatisfy { $0.currentScore >= 0.75 }
        if allCategoriesGood && totalMeasurements >= 30 {
            achievements.append(Achievement(
                type: .allRounder,
                title: "Well-Rounded Photographer",
                description: "All skills above 75%"
            ))
        }

        // Rapid improvement (any category improved >0.2 in 2 weeks)
        for (category, metric) in history.metrics {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let recentMeasurements = metric.measurements(from: twoWeeksAgo, to: Date())

            if recentMeasurements.count >= 3 {
                let sorted = recentMeasurements.sorted { $0.timestamp < $1.timestamp }
                if let first = sorted.first, let last = sorted.last {
                    let improvement = last.score - first.score
                    if improvement >= 0.2 {
                        achievements.append(Achievement(
                            type: .rapidImprovement,
                            title: "Rapid Progress",
                            description: "Improved \(category.rawValue) by 20% in 2 weeks",
                            category: category
                        ))
                    }
                }
            }
        }

        return achievements
    }

    // MARK: - Skill Breakdown

    func skillBreakdown() -> [SkillBreakdownItem] {
        SkillMetric.SkillCategory.allCases.compactMap { category in
            guard let metric = history.metrics[category] else { return nil }

            return SkillBreakdownItem(
                category: category,
                currentScore: metric.currentScore,
                targetScore: metric.targetScore,
                trend: metric.trend,
                measurements: metric.measurements.count,
                lastUpdated: metric.lastUpdated
            )
        }
    }

    struct SkillBreakdownItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: SkillMetric.SkillCategory
        var currentScore: Double
        var targetScore: Double
        var trend: SkillMetric.Trend
        var measurements: Int
        var lastUpdated: Date

        var progress: Double {
            guard targetScore > 0 else { return 0 }
            return min(1.0, currentScore / targetScore)
        }
    }

    // MARK: - Activity Timeline

    func activityTimeline(days: Int = 30) -> [TimelineItem] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        var items: [TimelineItem] = []

        // Add milestones
        for milestone in history.milestones where milestone.achievedAt >= startDate {
            items.append(TimelineItem(
                date: milestone.achievedAt,
                type: .milestone,
                title: "\(milestone.type.rawValue) in \(milestone.category.rawValue)",
                category: milestone.category
            ))
        }

        // Add practice sessions
        for session in history.sessions where session.date >= startDate {
            items.append(TimelineItem(
                date: session.date,
                type: .session,
                title: "Analyzed \(session.photosAnalyzed) photos",
                category: session.focusArea
            ))
        }

        // Add plan completions
        if let plan = currentPlan, plan.isPast {
            items.append(TimelineItem(
                date: plan.weekEndDate,
                type: .planComplete,
                title: "Completed weekly plan (\(String(format: "%.0f", plan.completionRate * 100))%)",
                category: plan.primaryFocus
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    struct TimelineItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var date: Date
        var type: TimelineType
        var title: String
        var category: SkillMetric.SkillCategory?

        enum TimelineType: String, Codable {
            case milestone = "Milestone"
            case session = "Session"
            case planComplete = "Plan Complete"

            var icon: String {
                switch self {
                case .milestone: return "star.fill"
                case .session: return "camera.fill"
                case .planComplete: return "checkmark.circle.fill"
                }
            }
        }
    }
}
