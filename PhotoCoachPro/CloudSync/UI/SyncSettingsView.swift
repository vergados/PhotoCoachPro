//
//  SyncSettingsView.swift
//  PhotoCoachPro
//
//  Sync settings and configuration
//

import SwiftUI

/// Sync settings configuration
struct SyncSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var privacySettings = PrivacySettings.shared

    @State private var autoSyncEnabled = false
    @State private var syncPhotos = true
    @State private var syncEdits = true
    @State private var syncPresets = true
    @State private var syncCritiques = false
    @State private var conflictResolution: ConflictResolutionMode = .lastWriteWins
    @State private var showResetConfirmation = false
    @State private var syncStatus: SyncStatus?
    @State private var isSyncing = false
    @Environment(\.dismiss) private var dismiss

    enum ConflictResolutionMode: String, CaseIterable {
        case lastWriteWins = "Last Write Wins"
        case keepLocal = "Always Keep Local"
        case keepRemote = "Always Keep Remote"
        case askEachTime = "Ask Each Time"

        var description: String {
            switch self {
            case .lastWriteWins:
                return "Automatically choose the most recent version"
            case .keepLocal:
                return "Always keep the local version"
            case .keepRemote:
                return "Always keep the iCloud version"
            case .askEachTime:
                return "Manually resolve each conflict"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Master enable toggle
                Section {
                    Toggle(isOn: $privacySettings.cloudSyncEnabled) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text("Enable iCloud Sync")
                        }
                    }
                } footer: {
                    Text("Your data stays on this device. Enable to sync across your Apple devices using iCloud.")
                }

                if privacySettings.cloudSyncEnabled {
                    // General settings
                    Section {
                        Toggle(isOn: $autoSyncEnabled) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Auto-Sync")
                            }
                        }
                        .onChange(of: autoSyncEnabled) { _, newValue in
                            Task {
                                guard let manager = appState.syncManager else { return }
                                if newValue {
                                    try? await manager.resumeSync()
                                } else {
                                    await manager.pauseSync()
                                }
                            }
                        }
                    } header: {
                        Text("General")
                    } footer: {
                        Text("Automatically sync changes with iCloud when connected to WiFi")
                    }

                    // What to sync
                    Section {
                        Toggle(isOn: $syncPhotos) {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.blue)
                                Text("Photos")
                            }
                        }

                        Toggle(isOn: $syncEdits) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.blue)
                                Text("Edits")
                            }
                        }

                        Toggle(isOn: $syncPresets) {
                            HStack {
                                Image(systemName: "photo.stack")
                                    .foregroundColor(.blue)
                                Text("Presets")
                            }
                        }

                        Toggle(isOn: $syncCritiques) {
                            HStack {
                                Image(systemName: "star")
                                    .foregroundColor(.blue)
                                Text("Critiques")
                            }
                        }
                    } header: {
                        Text("Sync Items")
                    } footer: {
                        Text("Choose what to sync with iCloud. Photos may use significant storage.")
                    }

                    // Conflict resolution
                    Section {
                        Picker("Resolution Mode", selection: $conflictResolution) {
                            ForEach(ConflictResolutionMode.allCases, id: \.self) { mode in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.rawValue)
                                        .font(.body)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(mode)
                            }
                        }
                    } header: {
                        Text("Conflict Resolution")
                    } footer: {
                        Text(conflictResolution.description)
                    }

                    // Storage info
                    Section {
                        HStack {
                            Text("iCloud Storage Used")
                            Spacer()
                            Text(syncStatus != nil ? "Calculating..." : "Not available")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Available")
                            Spacer()
                            Text(syncStatus != nil ? "Calculating..." : "Not available")
                                .foregroundColor(.secondary)
                        }

                        NavigationLink(destination: Text("iCloud Storage")) {
                            HStack {
                                Text("Manage Storage")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Storage")
                    } footer: {
                        Text("Storage calculation requires iCloud sync to be enabled")
                    }

                    // Actions
                    Section {
                        Button(action: syncNow) {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(isSyncing ? "Syncing..." : "Sync Now")
                            }
                        }
                        .disabled(isSyncing || syncStatus?.iCloudAvailable == false || appState.syncManager == nil)

                        Button(action: { showResetConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Reset Sync Data")
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text("Actions")
                    }

                    // Advanced
                    Section {
                        HStack {
                            Text("Device ID")
                            Spacer()
                            #if os(iOS)
                            Text(UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            #else
                            Text(getDeviceID().prefix(8))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            #endif
                        }

                        HStack {
                            Text("Last Sync")
                            Spacer()
                            if let lastSync = syncStatus?.lastSyncDate {
                                Text(formatRelativeTime(lastSync))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Advanced")
                    }
                }
            }
            .navigationTitle("Sync Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStatus()
            }
            .alert("Reset Sync Data", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetSyncData()
                }
            } message: {
                Text("This will remove all sync data and queue. Your local data will not be affected.")
            }
        }
    }

    #if os(macOS)
    private func getDeviceID() -> String {
        let defaults = UserDefaults.standard
        let key = "com.photocoachpro.deviceID"
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: key)
        return newID
    }
    #endif

    private func loadStatus() async {
        guard let manager = appState.syncManager else { return }
        syncStatus = await manager.getStatus()
        autoSyncEnabled = syncStatus?.autoSyncEnabled ?? false
    }

    private func syncNow() {
        guard let manager = appState.syncManager else { return }
        Task {
            isSyncing = true
            defer { isSyncing = false }

            do {
                try await manager.sync()
                await loadStatus()
            } catch {
                print("Sync failed: \(error)")
            }
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if days < 7 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    private func resetSyncData() {
        guard let manager = appState.syncManager else { return }
        Task {
            await manager.pauseSync()
            await loadStatus()
        }
    }
}

// MARK: - Preview

#Preview {
    SyncSettingsView()
        .environmentObject(AppState())
}
