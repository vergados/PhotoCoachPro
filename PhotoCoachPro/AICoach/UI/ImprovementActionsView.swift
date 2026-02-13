//
//  ImprovementActionsView.swift
//  PhotoCoachPro
//
//  Displays actionable edit suggestions
//

import SwiftUI

/// Displays actionable edit suggestions from critique
struct ImprovementActionsView: View {
    let suggestions: [CritiqueResult.EditSuggestion]
    @State private var selectedPriority: Priority? = nil

    enum Priority: String, CaseIterable {
        case all = "All"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with filter
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit Suggestions")
                    .font(.headline)

                if !suggestions.isEmpty {
                    // Priority filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Priority.allCases, id: \.self) { priority in
                                FilterChip(
                                    title: priority.rawValue,
                                    isSelected: selectedPriority == priority,
                                    count: countForPriority(priority)
                                ) {
                                    selectedPriority = (selectedPriority == priority) ? nil : priority
                                }
                            }
                        }
                    }
                }
            }

            // Suggestions list
            if filteredSuggestions.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredSuggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
                }
            }
        }
    }

    private var filteredSuggestions: [CritiqueResult.EditSuggestion] {
        guard let priority = selectedPriority, priority != .all else {
            return suggestions
        }

        return suggestions.filter { suggestion in
            suggestion.priority.rawValue.lowercased() == priority.rawValue.lowercased()
        }
    }

    private func countForPriority(_ priority: Priority) -> Int {
        if priority == .all {
            return suggestions.count
        }
        return suggestions.filter { $0.priority.rawValue.lowercased() == priority.rawValue.lowercased() }.count
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: CritiqueResult.EditSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with priority
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(suggestion.priority.rawValue + " Priority")
                        .font(.caption)
                        .foregroundColor(priorityColor)
                }

                Spacer()

                // Priority badge
                PriorityBadge(priority: suggestion.priority)
            }

            // Suggestion text
            Text(suggestion.suggestion)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Expected improvement
            if suggestion.expectedImprovement > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("Expected improvement: +\(String(format: "%.0f", suggestion.expectedImprovement * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Apply button (if instruction available)
            if suggestion.instruction != nil {
                Button(action: {
                    // Apply edit action
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Apply Edit")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(priorityColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var categoryIcon: String {
        switch suggestion.category.lowercased() {
        case "composition": return "viewfinder"
        case "exposure", "light": return "sun.max"
        case "focus", "sharpness": return "camera.aperture"
        case "color": return "paintpalette"
        case "background": return "person.crop.rectangle"
        case "story": return "text.bubble"
        default: return "wand.and.stars"
        }
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Priority Badge

private struct PriorityBadge: View {
    let priority: CritiqueResult.EditSuggestion.Priority

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < priorityLevel ? color : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private var priorityLevel: Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private var color: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("No Suggestions")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("This photo looks great! No improvements needed.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        ImprovementActionsView(suggestions: [
            CritiqueResult.EditSuggestion(
                category: "Exposure",
                suggestion: "Increase exposure by +0.5 EV to brighten shadows and reveal more detail.",
                priority: .high,
                instruction: EditInstruction(type: .exposure, value: 0.5),
                expectedImprovement: 0.15
            ),
            CritiqueResult.EditSuggestion(
                category: "Color",
                suggestion: "Adjust white balance to remove cool color cast. Consider warming the image.",
                priority: .high,
                instruction: EditInstruction(type: .temperature, value: 500),
                expectedImprovement: 0.12
            ),
            CritiqueResult.EditSuggestion(
                category: "Sharpness",
                suggestion: "Apply moderate sharpening to enhance edge detail and improve overall clarity.",
                priority: .medium,
                instruction: EditInstruction(type: .sharpness, value: 0.3),
                expectedImprovement: 0.08
            ),
            CritiqueResult.EditSuggestion(
                category: "Color",
                suggestion: "Reduce saturation slightly to achieve a more natural look.",
                priority: .medium,
                instruction: EditInstruction(type: .saturation, value: -0.1),
                expectedImprovement: 0.05
            ),
            CritiqueResult.EditSuggestion(
                category: "Composition",
                suggestion: "Consider cropping to improve composition and remove distracting elements on the edges.",
                priority: .low,
                instruction: nil,
                expectedImprovement: 0.03
            )
        ])
        .padding()
    }
}
