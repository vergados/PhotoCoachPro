//
//  CategoryBreakdownView.swift
//  PhotoCoachPro
//
//  Detailed breakdown of category scores
//

import SwiftUI

/// Detailed breakdown of all critique categories
struct CategoryBreakdownView: View {
    let categories: CritiqueResult.CategoryBreakdown

    var body: some View {
        VStack(spacing: 16) {
            CategoryDetailCard(
                title: "Composition",
                icon: "viewfinder",
                score: categories.composition,
                weight: 0.25
            )

            CategoryDetailCard(
                title: "Light",
                icon: "sun.max",
                score: categories.light,
                weight: 0.25
            )

            CategoryDetailCard(
                title: "Focus",
                icon: "camera.aperture",
                score: categories.focus,
                weight: 0.15
            )

            CategoryDetailCard(
                title: "Color",
                icon: "paintpalette",
                score: categories.color,
                weight: 0.15
            )

            CategoryDetailCard(
                title: "Background",
                icon: "person.crop.rectangle",
                score: categories.background,
                weight: 0.10
            )

            CategoryDetailCard(
                title: "Story",
                icon: "text.bubble",
                score: categories.story,
                weight: 0.10
            )
        }
    }
}

// MARK: - Category Detail Card

private struct CategoryDetailCard: View {
    let title: String
    let icon: String
    let score: CritiqueResult.CategoryScore
    let weight: Double

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with score
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(scoreColor)
                    }

                    // Title and weight
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(Int(weight * 100))% of overall score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", score.score * 100))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)

                        Text(score.rating.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            // Score bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(scoreColor)
                        .frame(width: geometry.size.width * score.score, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // Notes
                    if !score.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Analysis")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(score.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Strengths
                    if !score.strengths.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Strengths")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(score.strengths, id: \.self) { strength in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .foregroundColor(.green)
                                        Text(strength)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Issues
                    if !score.detectedIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Issues Detected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(score.detectedIssues, id: \.self) { issue in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .foregroundColor(.orange)
                                        Text(issue)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var scoreColor: Color {
        switch score.score {
        case 0.9...1.0: return .green
        case 0.75..<0.9: return .blue
        case 0.6..<0.75: return .orange
        case 0.4..<0.6: return .red.opacity(0.8)
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        CategoryBreakdownView(categories: CritiqueResult.CategoryBreakdown(
            composition: CritiqueResult.CategoryScore(
                score: 0.85,
                notes: "Strong composition with good use of rule of thirds. Subject placement is effective and creates visual interest.",
                detectedIssues: [],
                strengths: ["Rule of thirds alignment", "Good visual balance", "Effective framing"]
            ),
            light: CritiqueResult.CategoryScore(
                score: 0.72,
                notes: "Generally well exposed but some highlight clipping in the sky. Dynamic range could be better managed.",
                detectedIssues: ["Highlight clipping in sky", "Slightly underexposed shadows"],
                strengths: ["Good overall exposure", "Minimal noise"]
            ),
            focus: CritiqueResult.CategoryScore(
                score: 0.68,
                notes: "Focus is acceptable but sharpness could be improved. Some softness detected in critical areas.",
                detectedIssues: ["Slight softness in main subject", "Depth of field too shallow"],
                strengths: []
            ),
            color: CritiqueResult.CategoryScore(
                score: 0.55,
                notes: "Color balance needs attention. Noticeable color cast affecting overall image quality.",
                detectedIssues: ["Cool color cast", "Over-saturated greens", "Inconsistent white balance"],
                strengths: []
            ),
            background: CritiqueResult.CategoryScore(
                score: 0.78,
                notes: "Good subject-background separation. Background elements don't compete with subject.",
                detectedIssues: ["Some distracting elements in upper right"],
                strengths: ["Clean background", "Good bokeh", "Subject isolation"]
            ),
            story: CritiqueResult.CategoryScore(
                score: 0.82,
                notes: "Clear and compelling narrative. Subject is well-defined and emotionally engaging.",
                detectedIssues: [],
                strengths: ["Strong subject clarity", "Engaging composition", "Clear message"]
            )
        ))
        .padding()
    }
}
