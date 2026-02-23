//
//  SkillDashboardView.swift
//  PhotoCoachPro
//
//  Skill tracking dashboard showing insights, achievements, and weekly plan
//

import SwiftUI

struct SkillDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: Section = .overview

    enum Section: String, CaseIterable {
        case overview = "Overview"
        case plan = "Weekly Plan"
    }

    private var dashboard: SkillDashboard {
        let plan = WeeklyFocusPlan.generate(for: appState.skillHistory, startDate: Date())
        return SkillDashboard(history: appState.skillHistory, currentPlan: plan)
    }

    var body: some View {
        if appState.skillHistory.totalPhotosAnalyzed == 0 {
            emptyState
        } else {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSection {
                        case .overview:
                            overviewSection
                        case .plan:
                            planSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Skill Tracking")
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !dashboard.insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Insights")
                        .font(.headline)

                    ForEach(dashboard.insights) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.type.icon)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text(insight.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if !dashboard.achievements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Achievements")
                        .font(.headline)

                    ForEach(dashboard.achievements) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.type.icon)
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text(achievement.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planSection: some View {
        Group {
            if let plan = dashboard.currentPlan {
                WeeklyFocusPlanView(plan: plan)
            } else {
                Text("No plan available yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No skill data yet.")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Analyze some photos first to build your skill profile.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
        .navigationTitle("Skill Tracking")
    }
}
