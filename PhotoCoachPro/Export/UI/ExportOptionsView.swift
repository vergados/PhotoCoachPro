//
//  ExportOptionsView.swift
//  PhotoCoachPro
//
//  Export settings configuration UI
//

import SwiftUI

/// Configure export settings
struct ExportOptionsView: View {
    @Binding var settings: ExportSettings
    @State private var selectedPreset: ExportSettings?
    @State private var showPresetPicker = false
    @Environment(\.dismiss) private var dismiss

    var onExport: (ExportSettings) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Presets
                presetsSection

                // Format
                formatSection

                // Quality (only for lossy formats)
                if settings.format.supportsCompression {
                    qualitySection
                }

                // Resolution
                resolutionSection

                // Color Space
                colorSpaceSection

                // Metadata
                metadataSection

                // Estimated file size
                estimatedSizeSection
            }
            .navigationTitle("Export Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        onExport(settings)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPresetPicker) {
                PresetPickerView(selectedPreset: $selectedPreset)
            }
            .onChange(of: selectedPreset) { _, newPreset in
                if let preset = newPreset {
                    applyPreset(preset)
                }
            }
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ExportSettings.allPresets, id: \.name) { preset in
                        PresetCard(preset: preset) {
                            applyPreset(preset)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Quick Presets")
        }
    }

    // MARK: - Format

    private var formatSection: some View {
        Section {
            Picker("Format", selection: $settings.format) {
                ForEach(ExportSettings.ExportFormat.allCases, id: \.self) { format in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(format.rawValue)
                            .font(.body)
                        Text(format.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Format")
        } footer: {
            Text(settings.format.description)
        }
    }

    // MARK: - Quality

    private var qualitySection: some View {
        Section {
            Picker("Quality", selection: $settings.quality) {
                ForEach(ExportSettings.ExportQuality.allCases, id: \.self) { quality in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quality.rawValue)
                            .font(.body)
                        Text(quality.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(quality)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Quality")
        } footer: {
            Text(settings.quality.description)
        }
    }

    // MARK: - Resolution

    private var resolutionSection: some View {
        Section {
            Picker("Resolution", selection: $settings.resolution) {
                ForEach(ExportSettings.ResolutionOption.allCases, id: \.self) { resolution in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolution.rawValue)
                            .font(.body)
                        Text(resolution.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(resolution)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Resolution")
        } footer: {
            Text(settings.resolution.description)
        }
    }

    // MARK: - Color Space

    private var colorSpaceSection: some View {
        Section {
            Picker("Color Space", selection: $settings.colorSpace) {
                ForEach(ExportSettings.ColorSpaceOption.allCases, id: \.self) { colorSpace in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(colorSpace.rawValue)
                            .font(.body)
                        Text(colorSpace.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(colorSpace)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Color Space")
        } footer: {
            Text(settings.colorSpace.description)
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        Section {
            Picker("Metadata", selection: $settings.metadata) {
                ForEach(ExportSettings.MetadataOption.allCases, id: \.self) { metadata in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metadata.rawValue)
                            .font(.body)
                        Text(metadata.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(metadata)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Metadata")
        } footer: {
            Text(settings.metadata.description)
        }
    }

    // MARK: - Estimated Size

    private var estimatedSizeSection: some View {
        Section {
            HStack {
                Text("Estimated File Size")
                    .foregroundColor(.secondary)

                Spacer()

                Text(settings.estimatedFileSize)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: ExportSettings) {
        settings = preset
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: ExportSettings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: iconForPreset(preset))
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name ?? "Custom")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(preset.format.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 100)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func iconForPreset(_ preset: ExportSettings) -> String {
        guard let name = preset.name else { return "photo" }

        switch name {
        case "Web Optimized": return "globe"
        case "Social Media": return "heart.circle"
        case "Print": return "printer"
        case "Archival": return "archivebox"
        default: return "photo"
        }
    }
}

// MARK: - Preset Picker

private struct PresetPickerView: View {
    @Binding var selectedPreset: ExportSettings?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ExportSettings.allPresets, id: \.name) { preset in
                Button(action: {
                    selectedPreset = preset
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name ?? "Custom")
                                .font(.body)
                                .fontWeight(.semibold)

                            Text("\(preset.format.rawValue) · \(preset.quality.rawValue) · \(preset.resolution.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Export Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExportOptionsView(
        settings: .constant(ExportSettings()),
        onExport: { _ in }
    )
}
