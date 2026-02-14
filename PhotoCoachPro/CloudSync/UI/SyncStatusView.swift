//
//  SyncStatusView.swift
//  PhotoCoachPro
//
//  Sync status display
//

import SwiftUI

/// Displays current sync status
struct SyncStatusView: View {
    @State private var status: SyncStatus
    @State private var showDetails = false
    private let manager: SyncManager

    init(manager: SyncManager = SyncManager(), status: SyncStatus = SyncStatus()) {
        self.manager = manager
        self._status = State(initialValue: status)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            // Details (expandable)
            if showDetails {
                detailsView
                    .transition(.opacity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadStatus()
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        Button(action: { withAnimation { showDetails.toggle() } }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: status.state.icon)
                    .font(.title3)
                    .foregroundColor(statusColor)

                // Status text
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.state.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(status.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Pending indicator
                if status.hasPendingChanges {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)

                        Text("\(status.totalPending)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                }

                // Expand indicator
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details View

    private var detailsView: some View {
        VStack(spacing: 16) {
            Divider()

            // iCloud status
            HStack {
                Image(systemName: status.iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                    .foregroundColor(status.iCloudAvailable ? .green : .red)

                Text(status.iCloudAvailable ? "iCloud Connected" : "iCloud Unavailable")
                    .font(.subheadline)

                Spacer()
            }
            .padding(.horizontal)

            // Auto-sync toggle
            Toggle(isOn: .constant(status.autoSyncEnabled)) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle")
                    Text("Auto-Sync")
                }
            }
            .padding(.horizontal)

            // Pending uploads
            if status.pendingUploads > 0 {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.blue)

                    Text("\(status.pendingUploads) pending upload(s)")
                        .font(.subheadline)

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Pending downloads
            if status.pendingDownloads > 0 {
                HStack {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundColor(.blue)

                    Text("\(status.pendingDownloads) pending download(s)")
                        .font(.subheadline)

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Errors
            if status.hasErrors {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)

                        Text("\(status.unresolvedErrors.count) Error(s)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    ForEach(status.unresolvedErrors.prefix(3)) { error in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.recordType)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(error.error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if status.unresolvedErrors.count > 3 {
                        Text("+ \(status.unresolvedErrors.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            // Actions
            HStack(spacing: 12) {
                // Sync now button
                Button(action: { Task { try? await syncNow() } }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(status.canSync ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!status.canSync)

                // Settings button
                Button(action: { }) {
                    Image(systemName: "gear")
                        .font(.subheadline)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch status.state {
        case .idle:
            return .green
        case .syncing, .uploading, .downloading:
            return .blue
        case .error:
            return .red
        case .paused:
            return .orange
        }
    }

    // MARK: - Actions

    private func loadStatus() async {
        status = await manager.getStatus()

        // Setup status update handler
        await manager.setStatusUpdateHandler { newStatus in
            Task { @MainActor in
                status = newStatus
            }
        }
    }

    private func syncNow() async throws {
        try await manager.sync()
    }
}

// MARK: - Compact Status Indicator

struct SyncStatusIndicator: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.state.icon)
                .font(.caption)

            if status.hasPendingChanges {
                Text("\(status.totalPending)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch status.state {
        case .idle: return .green
        case .syncing, .uploading, .downloading: return .blue
        case .error: return .red
        case .paused: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SyncStatusView(status: SyncStatus(
            state: .idle,
            lastSyncDate: Date(),
            pendingUploads: 0,
            pendingDownloads: 0,
            iCloudAvailable: true
        ))

        Spacer()

        SyncStatusView(status: SyncStatus(
            state: .syncing,
            pendingUploads: 5,
            pendingDownloads: 3,
            iCloudAvailable: true
        ))

        Spacer()

        SyncStatusView(status: SyncStatus(
            state: .error,
            errors: [
                SyncStatus.SyncError(recordType: "Photo", recordID: UUID(), error: "Network error")
            ],
            iCloudAvailable: true
        ))
    }
}
