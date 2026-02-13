//
//  ConflictResolutionView.swift
//  PhotoCoachPro
//
//  Sync conflict resolution UI
//

import SwiftUI

/// Resolve sync conflicts
struct ConflictResolutionView: View {
    let conflicts: [SyncConflict]
    @State private var selectedConflict: SyncConflict?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if conflicts.isEmpty {
                    emptyState
                } else {
                    conflictsList
                }
            }
            .navigationTitle("Sync Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedConflict) { conflict in
                ConflictDetailView(conflict: conflict)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("No Conflicts")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("All your devices are in sync")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conflicts List

    private var conflictsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("\(conflicts.count) conflict(s) need resolution")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))

                // Conflicts
                ForEach(conflicts) { conflict in
                    ConflictCard(conflict: conflict) {
                        selectedConflict = conflict
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Conflict Card

private struct ConflictCard: View {
    let conflict: SyncConflict
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: iconForRecordType(conflict.recordType))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflict.recordType)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Detected \(conflict.detectedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Versions
                HStack(spacing: 12) {
                    // Local version
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone")
                                .font(.caption)
                            Text("Local")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)

                        Text(conflict.localModifiedDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(conflict.localModifiedDate, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.orange)

                    // Remote version
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "icloud")
                                .font(.caption)
                            Text("iCloud")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.green)

                        Text(conflict.remoteModifiedDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(conflict.remoteModifiedDate, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Time difference
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)

                    Text("Time difference: \(formatTimeDifference(conflict.timeDifference))")
                        .font(.caption)

                    Spacer()

                    if conflict.isLocalNewer {
                        Text("Local is newer")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if conflict.isRemoteNewer {
                        Text("iCloud is newer")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func iconForRecordType(_ type: String) -> String {
        switch type {
        case "Photo": return "photo"
        case "EditRecord": return "slider.horizontal.3"
        case "Preset": return "photo.stack"
        default: return "doc"
        }
    }

    private func formatTimeDifference(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Conflict Detail View

private struct ConflictDetailView: View {
    let conflict: SyncConflict
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Conflict info
                    conflictInfo

                    // Resolution options
                    resolutionOptions
                }
                .padding()
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var conflictInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conflict Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Type", value: conflict.recordType)
                InfoRow(label: "Detected", value: formatDate(conflict.detectedAt))
                InfoRow(label: "Local Modified", value: formatDate(conflict.localModifiedDate))
                InfoRow(label: "iCloud Modified", value: formatDate(conflict.remoteModifiedDate))
                InfoRow(label: "Time Difference", value: formatTimeDifference(conflict.timeDifference))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var resolutionOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Resolution")
                .font(.headline)

            VStack(spacing: 12) {
                ResolutionButton(
                    icon: "iphone",
                    title: "Keep Local Version",
                    subtitle: "Use the version from this device",
                    color: .blue,
                    isRecommended: conflict.isLocalNewer
                ) {
                    resolveConflict(.keepLocal)
                }

                ResolutionButton(
                    icon: "icloud",
                    title: "Keep iCloud Version",
                    subtitle: "Use the version from iCloud",
                    color: .green,
                    isRecommended: conflict.isRemoteNewer
                ) {
                    resolveConflict(.keepRemote)
                }

                ResolutionButton(
                    icon: "doc.on.doc",
                    title: "Keep Both Versions",
                    subtitle: "Create a copy for the local version",
                    color: .orange,
                    isRecommended: false
                ) {
                    resolveConflict(.keepBoth)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func resolveConflict(_ resolution: SyncConflict.Resolution) {
        // Resolve conflict
        print("Resolving conflict with: \(resolution)")
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTimeDifference(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours) hour(s) \(minutes) minute(s)"
        } else {
            return "\(minutes) minute(s)"
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

private struct ResolutionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color)
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ConflictResolutionView(conflicts: [
        SyncConflict(
            recordType: "Photo",
            recordID: UUID(),
            localRecord: "Local photo data",
            remoteRecord: "Remote photo data",
            localModifiedDate: Date().addingTimeInterval(-3600),
            remoteModifiedDate: Date()
        ),
        SyncConflict(
            recordType: "Preset",
            recordID: UUID(),
            localRecord: "Local preset",
            remoteRecord: "Remote preset",
            localModifiedDate: Date(),
            remoteModifiedDate: Date().addingTimeInterval(-7200)
        )
    ])
}
