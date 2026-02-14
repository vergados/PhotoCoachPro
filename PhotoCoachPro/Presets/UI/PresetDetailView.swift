//
//  PresetDetailView.swift
//  PhotoCoachPro
//
//  Preset detail and preview
//

import SwiftUI

/// Preset detail with preview and apply
struct PresetDetailView: View {
    let preset: Preset
    @State private var strength: Double = 1.0
    @State private var isFavorite: Bool
    @State private var showBeforeAfter = false
    @Environment(\.dismiss) private var dismiss

    init(preset: Preset) {
        self.preset = preset
        self._isFavorite = State(initialValue: preset.isFavorite)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    previewSection

                    // Strength control
                    strengthControl

                    // Preset info
                    presetInfo

                    // Instructions breakdown
                    instructionsBreakdown

                    // Actions
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(preset.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { isFavorite.toggle() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .primary)
                    }
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 12) {
            // Preview image placeholder
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(4/3, contentMode: .fit)

                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Select a photo to preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .cornerRadius(16)

            // Before/After toggle
            if showBeforeAfter {
                HStack {
                    Button(action: { }) {
                        Text("Before")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Spacer()

                    Button(action: { }) {
                        Text("After")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Strength Control

    private var strengthControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Strength")
                    .font(.headline)

                Spacer()

                Text(String(format: "%.0f%%", strength * 100))
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $strength, in: 0...1)

                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Adjust the intensity of the preset effect")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Preset Info

    private var presetInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category and author
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: preset.category.icon)
                            .font(.caption)

                        Text(preset.category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Author")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        if preset.isBuiltIn {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }

                        Text(preset.author)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }

            Divider()

            // Description
            if let description = preset.description {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }

            // Tags
            if !preset.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(preset.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            // Stats
            HStack(spacing: 24) {
                StatItem(
                    icon: "slider.horizontal.3",
                    value: "\(preset.instructionCount)",
                    label: "Edits"
                )

                if preset.usageCount > 0 {
                    StatItem(
                        icon: "chart.bar.fill",
                        value: "\(preset.usageCount)",
                        label: "Uses"
                    )
                }

                StatItem(
                    icon: "calendar",
                    value: formatDate(preset.createdAt),
                    label: "Created"
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Instructions Breakdown

    private var instructionsBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjustments")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(preset.instructions) { instruction in
                    InstructionRow(instruction: instruction, strength: strength)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Apply button
            Button(action: { }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Apply Preset")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            HStack(spacing: 12) {
                // Export button
                Button(action: { }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                // Duplicate button
                if !preset.isBuiltIn {
                    Button(action: { }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Duplicate")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
            }

            // Delete button (custom presets only)
            if !preset.isBuiltIn {
                Button(role: .destructive, action: { }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Preset")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Instruction Row

private struct InstructionRow: View {
    let instruction: EditInstruction
    let strength: Double

    var body: some View {
        HStack {
            Image(systemName: iconForEditType(instruction.type))
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(instruction.type.rawValue)
                .font(.subheadline)

            Spacer()

            Text(formatValue(instruction.value * strength))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor(instruction.value * strength))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor.blended(withFraction: 0.5, of: NSColor.windowBackgroundColor)!))
        .cornerRadius(8)
    }

    private func iconForEditType(_ type: EditInstruction.EditType) -> String {
        switch type {
        case .exposure: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .highlights, .shadows: return "sun.haze"
        case .temperature: return "thermometer"
        case .tint: return "paintbrush"
        case .saturation, .vibrance: return "paintpalette"
        case .sharpAmount, .clarity: return "camera.aperture"
        default: return "slider.horizontal.3"
        }
    }

    private func formatValue(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }

    private func valueColor(_ value: Double) -> Color {
        if value > 0 {
            return .green
        } else if value < 0 {
            return .red
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    PresetDetailView(preset: PresetLibrary.portraitNatural)
}
