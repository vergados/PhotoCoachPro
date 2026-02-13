//
//  SyncSettingsView.swift
//  PhotoCoachPro
//
//  Sync settings and configuration
//

import SwiftUI

/// Sync settings configuration
struct SyncSettingsView: View {
    @State private var autoSyncEnabled = true
    @State private var syncPhotos = true
    @State private var syncEdits = true
    @State private var syncPresets = true
    @State private var syncCritiques = false
    @State private var conflictResolution: ConflictResolutionMode = .lastWriteWins
    @State private var showResetConfirmation = false
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
                // General settings
                Section {
                    Toggle(isOn: $autoSyncEnabled) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(.blue)
                            Text("Auto-Sync")
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
                        Text("234 MB")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Available")
                        Spacer()
                        Text("4.7 GB")
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
                }

                // Actions
                Section {
                    Button(action: { }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                    }

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
                        Text(UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text("2 minutes ago")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Advanced")
                }
            }
            .navigationTitle("Sync Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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

    private func resetSyncData() {
        // Reset sync data
        print("Reset sync data")
    }
}

// MARK: - Preview

#Preview {
    SyncSettingsView()
}
