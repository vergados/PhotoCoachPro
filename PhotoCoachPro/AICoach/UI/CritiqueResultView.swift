//
//  CritiqueResultView.swift
//  PhotoCoachPro
//
//  Displays critique results with scoring and suggestions
//

import SwiftUI

/// Main critique result display view
struct CritiqueResultView: View {
    let critique: CritiqueResult
    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case categories = "Categories"
        case improvements = "Improvements"
        case practice = "Practice"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab selector
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .categories:
                        CategoryBreakdownView(categories: critique.categories)
                    case .improvements:
                        ImprovementActionsView(suggestions: critique.editGuidance)
                    case .practice:
                        practiceContent
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Photo Critique")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            // Overall score circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: critique.overallScore)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", critique.overallScore * 100))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)

                    Text(critique.overallRating.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            // Summary
            Text(critique.overallSummary)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }

    // MARK: - Overview Content

    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Top improvements
            topImprovementsSection

            // Category summary
            categorySummarySection

            // Quick stats
            quickStatsSection
        }
    }

    private var topImprovementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Improvements")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(critique.topImprovements.prefix(3).enumerated()), id: \.offset) { index, improvement in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }

                        Text(improvement)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var categorySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Scores")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CategoryScoreCard(title: "Composition", score: critique.categories.composition.score, icon: "viewfinder")
                CategoryScoreCard(title: "Light", score: critique.categories.light.score, icon: "sun.max")
                CategoryScoreCard(title: "Focus", score: critique.categories.focus.score, icon: "camera.aperture")
                CategoryScoreCard(title: "Color", score: critique.categories.color.score, icon: "paintpalette")
                CategoryScoreCard(title: "Background", score: critique.categories.background.score, icon: "person.crop.rectangle")
                CategoryScoreCard(title: "Story", score: critique.categories.story.score, icon: "text.bubble")
            }
        }
    }

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)

            HStack(spacing: 12) {
                StatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(critique.categories.strengths.count)",
                    label: "Strengths",
                    color: .green
                )

                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(critique.categories.totalIssues)",
                    label: "Issues",
                    color: .orange
                )

                StatCard(
                    icon: "lightbulb.fill",
                    value: "\(critique.editGuidance.count)",
                    label: "Suggestions",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Practice Content

    private var practiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let practice = critique.practiceRecommendation {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.purple)
                        Text("Practice Recommendation")
                            .font(.headline)
                    }

                    Text(practice)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                }
            }

            // Weakest category
            if let weakest = critique.categories.weakestCategory {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Area")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .foregroundColor(.orange)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(weakest.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Score: \(String(format: "%.0f", weakest.score.score * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        switch critique.overallScore {
        case 0.9...1.0: return .green
        case 0.75..<0.9: return .blue
        case 0.6..<0.75: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

private struct CategoryScoreCard: View {
    let title: String
    let score: Double
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(scoreColor)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: "%.0f%%", score * 100))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var scoreColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CritiqueResultView(critique: CritiqueResult(
            photoID: UUID(),
            overallScore: 0.75,
            overallRating: .good,
            overallSummary: "Good photo with strong composition and lighting. Some improvements possible in color and focus.",
            categories: CritiqueResult.CategoryBreakdown(
                composition: CritiqueResult.CategoryScore(score: 0.85, notes: "Good balance", detectedIssues: [], strengths: ["Good framing"]),
                light: CritiqueResult.CategoryScore(score: 0.80, notes: "Well exposed", detectedIssues: [], strengths: ["Good dynamic range"]),
                focus: CritiqueResult.CategoryScore(score: 0.70, notes: "Acceptable", detectedIssues: ["Slight softness"], strengths: []),
                color: CritiqueResult.CategoryScore(score: 0.65, notes: "Needs work", detectedIssues: ["Color cast"], strengths: []),
                background: CritiqueResult.CategoryScore(score: 0.75, notes: "Good separation", detectedIssues: [], strengths: []),
                story: CritiqueResult.CategoryScore(score: 0.80, notes: "Clear subject", detectedIssues: [], strengths: ["Strong narrative"])
            ),
            topImprovements: [
                "Adjust white balance to remove color cast",
                "Increase sharpness slightly",
                "Consider cropping for better composition"
            ],
            editGuidance: [],
            practiceRecommendation: "Practice using custom white balance for accurate colors."
        ))
    }
}
