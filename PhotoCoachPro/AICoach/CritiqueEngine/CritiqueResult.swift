//
//  CritiqueResult.swift
//  PhotoCoachPro
//
//  Structured critique data model
//

import Foundation

/// Complete photo critique with actionable feedback
struct CritiqueResult: Codable, Identifiable, Equatable {
    var id: UUID
    var photoID: UUID
    var timestamp: Date
    var overallScore: Double            // 0.0 to 1.0
    var overallSummary: String
    var topImprovements: [String]       // Max 3 prioritized suggestions
    var categories: CategoryBreakdown
    var editGuidance: [EditSuggestion]
    var practiceRecommendation: String?

    init(
        id: UUID = UUID(),
        photoID: UUID,
        timestamp: Date = Date(),
        overallScore: Double,
        overallSummary: String,
        topImprovements: [String],
        categories: CategoryBreakdown,
        editGuidance: [EditSuggestion],
        practiceRecommendation: String? = nil
    ) {
        self.id = id
        self.photoID = photoID
        self.timestamp = timestamp
        self.overallScore = overallScore
        self.overallSummary = overallSummary
        self.topImprovements = topImprovements
        self.categories = categories
        self.editGuidance = editGuidance
        self.practiceRecommendation = practiceRecommendation
    }

    // MARK: - Category Breakdown

    struct CategoryBreakdown: Codable, Equatable {
        var composition: CategoryScore
        var light: CategoryScore
        var focus: CategoryScore
        var color: CategoryScore
        var background: CategoryScore
        var story: CategoryScore

        var averageScore: Double {
            let scores = [
                composition.score,
                light.score,
                focus.score,
                color.score,
                background.score,
                story.score
            ]
            return scores.reduce(0, +) / Double(scores.count)
        }

        var weakestCategory: (name: String, score: CategoryScore) {
            let categories = [
                ("Composition", composition),
                ("Light", light),
                ("Focus", focus),
                ("Color", color),
                ("Background", background),
                ("Story", story)
            ]
            return categories.min { $0.1.score < $1.1.score } ?? ("Unknown", composition)
        }

        var strongestCategory: (name: String, score: CategoryScore) {
            let categories = [
                ("Composition", composition),
                ("Light", light),
                ("Focus", focus),
                ("Color", color),
                ("Background", background),
                ("Story", story)
            ]
            return categories.max { $0.1.score < $1.1.score } ?? ("Unknown", composition)
        }
    }

    struct CategoryScore: Codable, Equatable {
        var score: Double               // 0.0 to 1.0
        var rating: Rating
        var notes: String
        var detectedIssues: [String]
        var strengths: [String]

        enum Rating: String, Codable {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case needsWork = "Needs Work"
            case poor = "Poor"

            init(score: Double) {
                switch score {
                case 0.9...1.0: self = .excellent
                case 0.75..<0.9: self = .good
                case 0.6..<0.75: self = .fair
                case 0.4..<0.6: self = .needsWork
                default: self = .poor
                }
            }

            var color: String {
                switch self {
                case .excellent: return "green"
                case .good: return "blue"
                case .fair: return "yellow"
                case .needsWork: return "orange"
                case .poor: return "red"
                }
            }
        }

        init(score: Double, notes: String, detectedIssues: [String] = [], strengths: [String] = []) {
            self.score = score
            self.rating = Rating(score: score)
            self.notes = notes
            self.detectedIssues = detectedIssues
            self.strengths = strengths
        }
    }

    // MARK: - Edit Suggestions

    struct EditSuggestion: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var category: String
        var suggestion: String
        var priority: Priority
        var instruction: EditInstruction?  // Optional pre-configured edit

        enum Priority: String, Codable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }

        init(category: String, suggestion: String, priority: Priority, instruction: EditInstruction? = nil) {
            self.category = category
            self.suggestion = suggestion
            self.priority = priority
            self.instruction = instruction
        }
    }

    // MARK: - Helpers

    var overallRating: CategoryScore.Rating {
        CategoryScore.Rating(score: overallScore)
    }

    var hasStrongAreas: Bool {
        categories.strongestCategory.score.score > 0.8
    }

    var needsSignificantImprovement: Bool {
        overallScore < 0.5
    }
}

// MARK: - Preset Critiques (for testing/demo)
extension CritiqueResult {
    static func placeholder(photoID: UUID) -> CritiqueResult {
        CritiqueResult(
            photoID: photoID,
            overallScore: 0.72,
            overallSummary: "Good photo with strong composition. Consider improving exposure balance and background separation.",
            topImprovements: [
                "Brighten shadows to reveal more detail",
                "Simplify background for better subject focus",
                "Boost colors slightly for more impact"
            ],
            categories: CategoryBreakdown(
                composition: CategoryScore(
                    score: 0.85,
                    notes: "Well-balanced composition with good use of negative space. Subject placement follows rule of thirds.",
                    detectedIssues: [],
                    strengths: ["Rule of thirds alignment", "Good negative space", "Clear focal point"]
                ),
                light: CategoryScore(
                    score: 0.65,
                    notes: "Adequate lighting but shadows are too dark. Highlights are well-controlled.",
                    detectedIssues: ["Blocked shadows", "Low contrast in midtones"],
                    strengths: ["No blown highlights", "Good highlight detail"]
                ),
                focus: CategoryScore(
                    score: 0.78,
                    notes: "Sharp focus on subject with pleasing bokeh. Slight softness in extremes.",
                    detectedIssues: ["Edge softness"],
                    strengths: ["Sharp subject", "Good depth of field"]
                ),
                color: CategoryScore(
                    score: 0.70,
                    notes: "Colors are accurate but could be more vibrant. White balance is neutral.",
                    detectedIssues: ["Muted saturation"],
                    strengths: ["Accurate white balance", "Good color harmony"]
                ),
                background: CategoryScore(
                    score: 0.60,
                    notes: "Background is slightly distracting. Could benefit from more separation.",
                    detectedIssues: ["Busy background", "Low separation"],
                    strengths: ["No mergers with subject"]
                ),
                story: CategoryScore(
                    score: 0.75,
                    notes: "Clear subject with good emotional connection. Narrative could be stronger.",
                    detectedIssues: [],
                    strengths: ["Clear subject", "Good moment capture"]
                )
            ),
            editGuidance: [
                EditSuggestion(
                    category: "Light",
                    suggestion: "Lift shadows by +30 to reveal detail without making image flat",
                    priority: .high,
                    instruction: EditInstruction(type: .shadows, value: 30)
                ),
                EditSuggestion(
                    category: "Color",
                    suggestion: "Increase vibrance by +20 for more impact while keeping skin tones natural",
                    priority: .medium,
                    instruction: EditInstruction(type: .vibrance, value: 20)
                ),
                EditSuggestion(
                    category: "Background",
                    suggestion: "Apply subtle vignette to draw attention to subject",
                    priority: .low,
                    instruction: EditInstruction(type: .vignetteAmount, value: -15)
                )
            ],
            practiceRecommendation: "Focus on background awareness: practice identifying distracting elements before shooting. Next week, shoot 10 images with deliberate background management."
        )
    }
}
