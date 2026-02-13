//
//  WeeklyFocusPlan.swift
//  PhotoCoachPro
//
//  Generated weekly practice plans
//

import Foundation

/// Weekly practice plan with targeted exercises
struct WeeklyFocusPlan: Codable, Identifiable, Equatable {
    var id: UUID
    var weekStartDate: Date
    var weekEndDate: Date
    var primaryFocus: SkillMetric.SkillCategory
    var secondaryFocus: SkillMetric.SkillCategory?
    var exercises: [Exercise]
    var goals: [Goal]
    var createdAt: Date
    var completedExercises: Set<UUID>

    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        primaryFocus: SkillMetric.SkillCategory,
        secondaryFocus: SkillMetric.SkillCategory? = nil,
        exercises: [Exercise] = [],
        goals: [Goal] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekEndDate = Calendar.current.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
        self.primaryFocus = primaryFocus
        self.secondaryFocus = secondaryFocus
        self.exercises = exercises
        self.goals = goals
        self.createdAt = createdAt
        self.completedExercises = []
    }

    // MARK: - Exercise

    struct Exercise: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: SkillMetric.SkillCategory
        var title: String
        var description: String
        var difficulty: Difficulty
        var estimatedMinutes: Int
        var photoCount: Int  // Number of photos to take
        var tips: [String]
        var examplePhotoID: UUID?

        enum Difficulty: String, Codable {
            case beginner = "Beginner"
            case intermediate = "Intermediate"
            case advanced = "Advanced"

            var icon: String {
                switch self {
                case .beginner: return "1.circle"
                case .intermediate: return "2.circle"
                case .advanced: return "3.circle"
                }
            }
        }

        init(
            category: SkillMetric.SkillCategory,
            title: String,
            description: String,
            difficulty: Difficulty,
            estimatedMinutes: Int,
            photoCount: Int,
            tips: [String] = []
        ) {
            self.category = category
            self.title = title
            self.description = description
            self.difficulty = difficulty
            self.estimatedMinutes = estimatedMinutes
            self.photoCount = photoCount
            self.tips = tips
        }
    }

    // MARK: - Goal

    struct Goal: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: SkillMetric.SkillCategory
        var targetScore: Double
        var currentScore: Double
        var description: String
        var achieved: Bool

        init(
            category: SkillMetric.SkillCategory,
            targetScore: Double,
            currentScore: Double,
            description: String
        ) {
            self.category = category
            self.targetScore = targetScore
            self.currentScore = currentScore
            self.description = description
            self.achieved = currentScore >= targetScore
        }

        var progress: Double {
            guard targetScore > 0 else { return 0 }
            return min(1.0, currentScore / targetScore)
        }
    }

    // MARK: - Computed Properties

    var isActive: Bool {
        let now = Date()
        return now >= weekStartDate && now <= weekEndDate
    }

    var isPast: Bool {
        Date() > weekEndDate
    }

    var daysRemaining: Int {
        guard isActive else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: weekEndDate)
        return max(0, components.day ?? 0)
    }

    var completionRate: Double {
        guard !exercises.isEmpty else { return 0 }
        return Double(completedExercises.count) / Double(exercises.count)
    }

    var uncompletedExercises: [Exercise] {
        exercises.filter { !completedExercises.contains($0.id) }
    }

    var goalsAchieved: Int {
        goals.filter { $0.achieved }.count
    }

    var weekDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: weekEndDate))"
    }

    // MARK: - Methods

    /// Mark exercise as completed
    mutating func completeExercise(_ exerciseID: UUID) {
        completedExercises.insert(exerciseID)
    }

    /// Update goal progress
    mutating func updateGoal(category: SkillMetric.SkillCategory, currentScore: Double) {
        if let index = goals.firstIndex(where: { $0.category == category }) {
            goals[index].currentScore = currentScore
            goals[index].achieved = currentScore >= goals[index].targetScore
        }
    }

    // MARK: - Plan Generation

    /// Generate a weekly plan based on skill history
    static func generate(for history: SkillHistory, startDate: Date = Date()) -> WeeklyFocusPlan {
        // Determine primary focus (weakest skill that needs improvement)
        let primaryFocus = determinePrimaryFocus(history: history)

        // Determine secondary focus (second weakest or declining skill)
        let secondaryFocus = determineSecondaryFocus(history: history, excluding: primaryFocus)

        // Generate exercises
        let exercises = generateExercises(
            primary: primaryFocus,
            secondary: secondaryFocus,
            history: history
        )

        // Generate goals
        let goals = generateGoals(
            primary: primaryFocus,
            secondary: secondaryFocus,
            history: history
        )

        return WeeklyFocusPlan(
            weekStartDate: startDate,
            primaryFocus: primaryFocus,
            secondaryFocus: secondaryFocus,
            exercises: exercises,
            goals: goals
        )
    }

    private static func determinePrimaryFocus(history: SkillHistory) -> SkillMetric.SkillCategory {
        // Priority 1: Declining skills
        if let declining = history.decliningSkills.first {
            return declining
        }

        // Priority 2: Lowest scoring skill
        if let weakest = history.weakestSkill {
            return weakest.category
        }

        // Default: Composition (foundation skill)
        return .composition
    }

    private static func determineSecondaryFocus(history: SkillHistory, excluding primary: SkillMetric.SkillCategory) -> SkillMetric.SkillCategory? {
        let candidates = history.metrics
            .filter { $0.key != primary }
            .filter { $0.value.currentScore < 0.8 || $0.value.trend == .declining }
            .sorted { $0.value.currentScore < $1.value.currentScore }

        return candidates.first?.key
    }

    private static func generateExercises(
        primary: SkillMetric.SkillCategory,
        secondary: SkillMetric.SkillCategory?,
        history: SkillHistory
    ) -> [Exercise] {
        var exercises: [Exercise] = []

        // Generate 3-4 exercises for primary focus
        let primaryMetric = history.metrics[primary]
        let primaryDifficulty = determineDifficulty(score: primaryMetric?.currentScore ?? 0.5)

        exercises.append(contentsOf: exercisesForCategory(primary, difficulty: primaryDifficulty, count: 3))

        // Generate 1-2 exercises for secondary focus
        if let secondary = secondary {
            let secondaryMetric = history.metrics[secondary]
            let secondaryDifficulty = determineDifficulty(score: secondaryMetric?.currentScore ?? 0.5)
            exercises.append(contentsOf: exercisesForCategory(secondary, difficulty: secondaryDifficulty, count: 2))
        }

        return exercises
    }

    private static func determineDifficulty(score: Double) -> Exercise.Difficulty {
        if score < 0.6 {
            return .beginner
        } else if score < 0.8 {
            return .intermediate
        } else {
            return .advanced
        }
    }

    private static func exercisesForCategory(_ category: SkillMetric.SkillCategory, difficulty: Exercise.Difficulty, count: Int) -> [Exercise] {
        let allExercises = exerciseLibrary[category] ?? []
        let filtered = allExercises.filter { $0.difficulty == difficulty || difficulty == .intermediate }
        return Array(filtered.prefix(count))
    }

    private static func generateGoals(
        primary: SkillMetric.SkillCategory,
        secondary: SkillMetric.SkillCategory?,
        history: SkillHistory
    ) -> [Goal] {
        var goals: [Goal] = []

        if let primaryMetric = history.metrics[primary] {
            let target = min(1.0, primaryMetric.currentScore + 0.1)
            goals.append(Goal(
                category: primary,
                targetScore: target,
                currentScore: primaryMetric.currentScore,
                description: "Improve \(primary.rawValue) by 10%"
            ))
        }

        if let secondary = secondary, let secondaryMetric = history.metrics[secondary] {
            let target = min(1.0, secondaryMetric.currentScore + 0.05)
            goals.append(Goal(
                category: secondary,
                targetScore: target,
                currentScore: secondaryMetric.currentScore,
                description: "Improve \(secondary.rawValue) by 5%"
            ))
        }

        return goals
    }

    // MARK: - Exercise Library

    private static let exerciseLibrary: [SkillMetric.SkillCategory: [Exercise]] = [
        .composition: [
            Exercise(
                category: .composition,
                title: "Rule of Thirds Practice",
                description: "Take 10 photos placing your subject at thirds intersections. Use grid overlay.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 10,
                tips: ["Enable grid overlay", "Place subject at power points", "Try both horizontal and vertical"]
            ),
            Exercise(
                category: .composition,
                title: "Leading Lines",
                description: "Find and photograph leading lines that guide the eye to your subject.",
                difficulty: .intermediate,
                estimatedMinutes: 45,
                photoCount: 8,
                tips: ["Look for roads, fences, rivers", "Lines should lead to subject", "Try diagonal lines for dynamism"]
            ),
            Exercise(
                category: .composition,
                title: "Negative Space Mastery",
                description: "Practice using negative space to emphasize your subject.",
                difficulty: .advanced,
                estimatedMinutes: 60,
                photoCount: 10,
                tips: ["Less is more", "Balance subject with empty space", "Use negative space to create mood"]
            )
        ],

        .lighting: [
            Exercise(
                category: .lighting,
                title: "Histogram Reading",
                description: "Take photos in different lighting and analyze histograms to avoid clipping.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 15,
                tips: ["Check histogram before shooting", "Avoid clipping on both ends", "Expose to preserve highlights"]
            ),
            Exercise(
                category: .lighting,
                title: "Golden Hour Shooting",
                description: "Shoot during golden hour (sunrise/sunset) for soft, warm light.",
                difficulty: .intermediate,
                estimatedMinutes: 60,
                photoCount: 12,
                tips: ["Shoot 1 hour after sunrise or before sunset", "Use warm white balance", "Try backlit subjects"]
            ),
            Exercise(
                category: .lighting,
                title: "High Contrast Control",
                description: "Master high-contrast scenes without losing shadow or highlight detail.",
                difficulty: .advanced,
                estimatedMinutes: 90,
                photoCount: 10,
                tips: ["Use graduated ND filters", "Bracket exposures", "Consider HDR techniques"]
            )
        ],

        .focus: [
            Exercise(
                category: .focus,
                title: "Single-Point Focus",
                description: "Practice using single-point autofocus for critical sharpness.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 10,
                tips: ["Use single-point AF mode", "Focus on eyes in portraits", "Check focus at 100% zoom"]
            ),
            Exercise(
                category: .focus,
                title: "Aperture and DOF",
                description: "Experiment with different apertures to control depth of field.",
                difficulty: .intermediate,
                estimatedMinutes: 45,
                photoCount: 12,
                tips: ["Try f/2.8, f/5.6, f/11", "Note DOF changes", "Use wider apertures for portraits"]
            )
        ],

        .color: [
            Exercise(
                category: .color,
                title: "Custom White Balance",
                description: "Practice setting custom white balance for accurate colors.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 10,
                tips: ["Use gray card or white paper", "Compare auto vs custom WB", "Match lighting conditions"]
            ),
            Exercise(
                category: .color,
                title: "Color Harmony",
                description: "Photograph complementary and analogous color schemes.",
                difficulty: .intermediate,
                estimatedMinutes: 60,
                photoCount: 15,
                tips: ["Study color wheel", "Look for complementary pairs", "Try analogous color groups"]
            )
        ],

        .background: [
            Exercise(
                category: .background,
                title: "Background Blur",
                description: "Use wide apertures to separate subject from background.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 10,
                tips: ["Use f/2.8 or wider", "Increase distance from background", "Use longer focal lengths"]
            )
        ],

        .storytelling: [
            Exercise(
                category: .storytelling,
                title: "Define Your Subject",
                description: "Take photos with one clear, obvious subject.",
                difficulty: .beginner,
                estimatedMinutes: 30,
                photoCount: 10,
                tips: ["Ask: what's the story?", "Remove distractions", "Make subject unmistakable"]
            ),
            Exercise(
                category: .storytelling,
                title: "Photo Series",
                description: "Create a 5-photo series that tells a story.",
                difficulty: .advanced,
                estimatedMinutes: 120,
                photoCount: 15,
                tips: ["Plan your narrative", "Show progression", "Consider sequencing"]
            )
        ]
    ]
}
