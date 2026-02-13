//
//  ImageAnalyzer.swift
//  PhotoCoachPro
//
//  Core photo quality analysis orchestrator
//

import Foundation
import CoreImage
import Vision

/// Orchestrates all analysis modules to generate complete critique
actor ImageAnalyzer {
    private let compositionAnalyzer: CompositionAnalyzer
    private let lightAnalyzer: LightAnalyzer
    private let focusAnalyzer: FocusAnalyzer
    private let colorAnalyzer: ColorAnalyzer
    private let backgroundAnalyzer: BackgroundAnalyzer
    private let storyAnalyzer: StoryAnalyzer

    init() {
        self.compositionAnalyzer = CompositionAnalyzer()
        self.lightAnalyzer = LightAnalyzer()
        self.focusAnalyzer = FocusAnalyzer()
        self.colorAnalyzer = ColorAnalyzer()
        self.backgroundAnalyzer = BackgroundAnalyzer()
        self.storyAnalyzer = StoryAnalyzer()
    }

    // MARK: - Analysis

    /// Analyze photo and generate complete critique
    func analyze(_ image: CIImage, photoID: UUID) async throws -> CritiqueResult {
        // Run all analyzers in parallel
        async let compositionScore = compositionAnalyzer.analyze(image)
        async let lightScore = lightAnalyzer.analyze(image)
        async let focusScore = focusAnalyzer.analyze(image)
        async let colorScore = colorAnalyzer.analyze(image)
        async let backgroundScore = backgroundAnalyzer.analyze(image)
        async let storyScore = storyAnalyzer.analyze(image)

        // Collect results
        let categories = CritiqueResult.CategoryBreakdown(
            composition: try await compositionScore,
            light: try await lightScore,
            focus: try await focusScore,
            color: try await colorScore,
            background: try await backgroundScore,
            story: try await storyScore
        )

        // Calculate overall score (weighted average)
        let overallScore = calculateOverallScore(categories: categories)

        // Generate summary
        let summary = generateSummary(categories: categories, overallScore: overallScore)

        // Identify top improvements
        let topImprovements = identifyTopImprovements(categories: categories)

        // Generate edit guidance
        let editGuidance = generateEditGuidance(categories: categories)

        // Generate practice recommendation
        let practiceRecommendation = generatePracticeRecommendation(categories: categories)

        return CritiqueResult(
            photoID: photoID,
            overallScore: overallScore,
            overallSummary: summary,
            topImprovements: topImprovements,
            categories: categories,
            editGuidance: editGuidance,
            practiceRecommendation: practiceRecommendation
        )
    }

    // MARK: - Scoring

    private func calculateOverallScore(categories: CritiqueResult.CategoryBreakdown) -> Double {
        // Weighted average (composition and light are most important)
        let weights: [Double] = [
            0.25,  // composition
            0.25,  // light
            0.15,  // focus
            0.15,  // color
            0.10,  // background
            0.10   // story
        ]

        let scores = [
            categories.composition.score,
            categories.light.score,
            categories.focus.score,
            categories.color.score,
            categories.background.score,
            categories.story.score
        ]

        return zip(scores, weights).reduce(0) { $0 + ($1.0 * $1.1) }
    }

    // MARK: - Summary Generation

    private func generateSummary(categories: CritiqueResult.CategoryBreakdown, overallScore: Double) -> String {
        let rating = CritiqueResult.CategoryScore.Rating(score: overallScore)
        let strongest = categories.strongestCategory
        let weakest = categories.weakestCategory

        var summary = ""

        // Overall assessment
        switch rating {
        case .excellent:
            summary = "Excellent photo with strong technical execution. "
        case .good:
            summary = "Good photo with solid fundamentals. "
        case .fair:
            summary = "Fair photo with room for improvement. "
        case .needsWork:
            summary = "Photo needs work in several key areas. "
        case .poor:
            summary = "Photo has significant technical issues. "
        }

        // Strongest area
        summary += "Particularly strong in \(strongest.name.lowercased()). "

        // Weakest area
        if weakest.score.score < 0.7 {
            summary += "Consider improving \(weakest.name.lowercased()) for better overall impact."
        }

        return summary
    }

    private func identifyTopImprovements(categories: CritiqueResult.CategoryBreakdown) -> [String] {
        var improvements: [(priority: Double, text: String)] = []

        // Collect all issues with priority scores
        let categoryScores = [
            ("composition", categories.composition),
            ("light", categories.light),
            ("focus", categories.focus),
            ("color", categories.color),
            ("background", categories.background),
            ("story", categories.story)
        ]

        for (name, score) in categoryScores {
            for issue in score.detectedIssues {
                // Priority = (1 - score) * importance
                let importance = name == "composition" || name == "light" ? 1.5 : 1.0
                let priority = (1.0 - score.score) * importance
                improvements.append((priority, issue))
            }
        }

        // Sort by priority and take top 3
        return improvements
            .sorted { $0.priority > $1.priority }
            .prefix(3)
            .map { $0.text }
    }

    // MARK: - Edit Guidance

    private func generateEditGuidance(categories: CritiqueResult.CategoryBreakdown) -> [CritiqueResult.EditSuggestion] {
        var suggestions: [CritiqueResult.EditSuggestion] = []

        // Light adjustments
        if categories.light.score < 0.7 {
            if categories.light.detectedIssues.contains(where: { $0.contains("shadow") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Light",
                    suggestion: "Lift shadows to reveal more detail",
                    priority: .high,
                    instruction: EditInstruction(type: .shadows, value: 30)
                ))
            }

            if categories.light.detectedIssues.contains(where: { $0.contains("highlight") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Light",
                    suggestion: "Recover highlights to prevent blown areas",
                    priority: .high,
                    instruction: EditInstruction(type: .highlights, value: -30)
                ))
            }

            if categories.light.detectedIssues.contains(where: { $0.contains("contrast") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Light",
                    suggestion: "Boost contrast for more punch",
                    priority: .medium,
                    instruction: EditInstruction(type: .contrast, value: 20)
                ))
            }
        }

        // Color adjustments
        if categories.color.score < 0.7 {
            if categories.color.detectedIssues.contains(where: { $0.contains("saturation") || $0.contains("muted") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Color",
                    suggestion: "Increase vibrance for more impact",
                    priority: .medium,
                    instruction: EditInstruction(type: .vibrance, value: 25)
                ))
            }

            if categories.color.detectedIssues.contains(where: { $0.contains("white balance") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Color",
                    suggestion: "Adjust white balance for more natural colors",
                    priority: .high
                ))
            }
        }

        // Focus/sharpness
        if categories.focus.score < 0.7 {
            if categories.focus.detectedIssues.contains(where: { $0.contains("soft") || $0.contains("blur") }) {
                suggestions.append(CritiqueResult.EditSuggestion(
                    category: "Focus",
                    suggestion: "Apply moderate sharpening to enhance detail",
                    priority: .medium,
                    instruction: EditInstruction(type: .sharpAmount, value: 50)
                ))
            }
        }

        // Background
        if categories.background.score < 0.7 {
            suggestions.append(CritiqueResult.EditSuggestion(
                category: "Background",
                suggestion: "Use vignette to draw attention to subject",
                priority: .low,
                instruction: EditInstruction(type: .vignetteAmount, value: -20)
            ))
        }

        return suggestions
    }

    // MARK: - Practice Recommendations

    private func generatePracticeRecommendation(categories: CritiqueResult.CategoryBreakdown) -> String {
        let weakest = categories.weakestCategory

        switch weakest.name {
        case "Composition":
            return "Practice: Shoot 20 images this week focusing on rule of thirds and leading lines. Review each before shooting the next."

        case "Light":
            return "Practice: Study the quality of light at different times of day. Shoot the same subject in morning, noon, and evening light."

        case "Focus":
            return "Practice: Experiment with different apertures (f/2.8, f/5.6, f/11) to understand depth of field. Focus on critical sharpness."

        case "Color":
            return "Practice: Shoot a color wheel of subjects (red, orange, yellow, green, blue, purple). Learn how colors interact."

        case "Background":
            return "Practice: Before each shot, scan the background for distracting elements. Shoot 10 images with deliberate background management."

        case "Story":
            return "Practice: Tell a visual story with 3 images. Think about what emotion or message you want to convey before shooting."

        default:
            return "Practice: Review your best photos. Identify what makes them work. Try to replicate those qualities in new images."
        }
    }
}

// MARK: - Batch Analysis
extension ImageAnalyzer {
    /// Analyze multiple photos and return critiques
    func analyzeBatch(_ images: [(image: CIImage, photoID: UUID)]) async throws -> [CritiqueResult] {
        var results: [CritiqueResult] = []

        for item in images {
            let critique = try await analyze(item.image, photoID: item.photoID)
            results.append(critique)
        }

        return results
    }
}
