//
//  WeeklyFocusPlanView.swift
//  PhotoCoachPro
//
//  Renders a WeeklyFocusPlan with focus, goals, and exercises
//

import SwiftUI

struct WeeklyFocusPlanView: View {
    let plan: WeeklyFocusPlan

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Week of \(Self.weekFormatter.string(from: plan.weekStartDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: plan.primaryFocus.icon)
                    Text(plan.primaryFocus.rawValue)
                        .fontWeight(.semibold)
                }
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
            }

            // Goals
            if !plan.goals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goals")
                        .font(.headline)

                    ForEach(plan.goals) { goal in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: goal.achieved ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(goal.achieved ? .green : .secondary)

                            Text(goal.description)
                                .font(.subheadline)
                                .foregroundStyle(goal.achieved ? .secondary : .primary)
                        }
                    }
                }
            }

            // Exercises
            if !plan.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercises")
                        .font(.headline)

                    ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .leading)

                                Text(exercise.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                Image(systemName: exercise.difficulty.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(exercise.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 28)

                            HStack(spacing: 16) {
                                Label("\(exercise.estimatedMinutes) min", systemImage: "clock")
                                Label("\(exercise.photoCount) photos", systemImage: "camera")
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 28)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("Weekly Plan")
    }
}
