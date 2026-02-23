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
        let sharedContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!])
        self.compositionAnalyzer = CompositionAnalyzer(context: sharedContext)
        self.lightAnalyzer = LightAnalyzer(context: sharedContext)
        self.focusAnalyzer = FocusAnalyzer(context: sharedContext)
        self.colorAnalyzer = ColorAnalyzer(context: sharedContext)
        self.backgroundAnalyzer = BackgroundAnalyzer(context: sharedContext)
        self.storyAnalyzer = StoryAnalyzer(context: sharedContext)
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

        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else { return 0.5 }
        let weightedSum = zip(scores, weights).map { score, weight in score * weight }.reduce(0, +)
        return weightedSum / weightSum
    }

    // MARK: - Summary Generation

    private func generateSummary(categories: CritiqueResult.CategoryBreakdown, overallScore: Double) -> String {
        let rating = CritiqueResult.CategoryScore.Rating(score: overallScore)
        let strongest = categories.strongestCategory
        let weakest = categories.weakestCategory
        let scorePercent = Int(overallScore * 100)

        var summary = ""

        // Score-specific opening with concrete number
        switch rating {
        case .excellent:
            summary = "Outstanding work — this photo scores \(scorePercent)/100 overall. "
        case .good:
            summary = "Solid photo at \(scorePercent)/100 with good technical control. "
        case .fair:
            summary = "A developing photo at \(scorePercent)/100 with clear areas to grow. "
        case .needsWork:
            summary = "Photo scores \(scorePercent)/100 and needs targeted improvement. "
        case .poor:
            summary = "Photo scores \(scorePercent)/100. Focus on the fundamentals first. "
        }

        // Strongest area with its actual score
        let strongestPercent = Int(strongest.score.score * 100)
        summary += "\(strongest.name) is your strongest element at \(strongestPercent)%. "

        // Weakest area with a specific detected issue if available
        let weakestPercent = Int(weakest.score.score * 100)
        if weakest.score.score < 0.7 {
            if let topIssue = weakest.score.detectedIssues.first {
                summary += "\(weakest.name) (\(weakestPercent)%) needs attention — specifically \(topIssue)."
            } else {
                summary += "\(weakest.name) (\(weakestPercent)%) has the most room for improvement."
            }
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
        let weakestPercent = Int(weakest.score.score * 100)
        let topIssue = weakest.score.detectedIssues.first

        // Build a contextual clause from the detected issue if available
        let issueContext: String = topIssue.map { " Detected issue: \($0)." } ?? ""

        switch weakest.name {
        case "Composition":
            return "Composition is at \(weakestPercent)%.\(issueContext) Practice: Before each shot, actively place your main subject using the rule of thirds or a strong leading line. Shoot 15 frames this week with deliberate placement — review each one before moving on."

        case "Light":
            return "Lighting is at \(weakestPercent)%.\(issueContext) Practice: Photograph the same subject at dawn, midday, and golden hour. Compare how direction and quality of light changes mood and texture. Pay attention to where shadows fall."

        case "Focus":
            return "Focus is at \(weakestPercent)%.\(issueContext) Practice: Shoot the same composition at f/2.8, f/5.6, and f/11. Study how depth of field changes subject separation and background clarity. Use single-point autofocus on your main subject."

        case "Color":
            return "Color is at \(weakestPercent)%.\(issueContext) Practice: Set a manual white balance using a gray card for your next five sessions. Compare the corrected images against auto white balance results. Notice how neutral tones affect the overall palette."

        case "Background":
            return "Background is at \(weakestPercent)%.\(issueContext) Practice: Before pressing the shutter, pause and scan every edge of the frame. Shoot 10 images with the sole goal of a clean, uncluttered background — move your position or change focal length as needed."

        case "Story":
            return "Story/impact is at \(weakestPercent)%.\(issueContext) Practice: Before each shot, write one sentence describing the emotion or message you want to convey. Then ask: does every element in the frame support that sentence? Remove or reframe anything that does not."

        default:
            return "Overall score: \(weakestPercent)%. Review your five strongest images and identify what they have in common. Set one specific intention for your next shoot based on that pattern."
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
