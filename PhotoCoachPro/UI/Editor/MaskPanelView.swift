//
//  MaskPanelView.swift
//  PhotoCoachPro
//
//  Mask management panel for selective adjustments
//

import SwiftUI

struct MaskPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Add Mask section
            addMaskSection

            // Active masks list
            if !appState.activeMasks.isEmpty {
                Divider()
                activeMasksSection
            }

            // Selected mask controls
            if let selectedID = appState.selectedMaskID,
               let selectedMask = appState.activeMasks.first(where: { $0.id == selectedID }) {
                Divider()
                MaskControlsView(mask: selectedMask)
            }

            // Empty state
            if appState.activeMasks.isEmpty && !appState.isMaskDetecting {
                Text("No masks added yet.\nAdd a mask to apply selective adjustments.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Add Mask Section

    private var addMaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Mask")
                .font(.headline)

            if appState.isMaskDetecting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    spacing: 8
                ) {
                    MaskAddButton(title: "Subject", icon: "person.fill") {
                        Task { await appState.addSubjectMask() }
                    }
                    MaskAddButton(title: "Sky", icon: "cloud.sun.fill") {
                        Task { await appState.addSkyMask() }
                    }
                    MaskAddButton(title: "Background", icon: "photo.fill") {
                        Task { await appState.addBackgroundMask() }
                    }
                    MaskAddButton(title: "Gradient", icon: "rectangle.leadinghalf.inset.filled") {
                        Task { await appState.addGradientMask() }
                    }
                    MaskAddButton(title: "Luminance", icon: "circle.lefthalf.filled") {
                        Task { await appState.addLuminanceMask() }
                    }
                }
            }
        }
    }

    // MARK: - Active Masks Section

    private var activeMasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Masks")
                .font(.headline)

            ForEach(appState.activeMasks) { mask in
                MaskRow(mask: mask)
            }
        }
    }
}

// MARK: - Mask Add Button

private struct MaskAddButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(title) mask")
    }
}

// MARK: - Mask Row

private struct MaskRow: View {
    let mask: MaskLayer
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedMaskID == mask.id
    }

    var body: some View {
        HStack(spacing: 10) {
            // Enable toggle
            Button {
                Task { await appState.toggleMask(id: mask.id) }
            } label: {
                Image(systemName: mask.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(mask.enabled ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mask.enabled ? "Disable mask" : "Enable mask")

            // Mask name (tap to select)
            Button {
                appState.selectMask(id: isSelected ? nil : mask.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: maskIcon(for: mask.type))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(mask.name)
                        .font(.subheadline)
                        .foregroundStyle(mask.enabled ? .primary : .secondary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Delete
            Button {
                Task { await appState.removeMask(id: mask.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete mask")
        }
    }

    private func maskIcon(for type: MaskLayer.MaskType) -> String {
        switch type {
        case .subject:    return "person.fill"
        case .sky:        return "cloud.sun.fill"
        case .background: return "photo.fill"
        case .brushed:    return "paintbrush.fill"
        case .gradient:   return "rectangle.leadinghalf.inset.filled"
        case .color:      return "eyedropper.full"
        case .luminance:  return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Mask Controls

private struct MaskControlsView: View {
    let mask: MaskLayer
    @EnvironmentObject var appState: AppState

    @State private var feather: Double
    @State private var opacityPct: Double
    @State private var inverted: Bool

    init(mask: MaskLayer) {
        self.mask = mask
        _feather = State(initialValue: mask.featherRadius)
        _opacityPct = State(initialValue: mask.opacity * 100)
        _inverted = State(initialValue: mask.inverted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mask Controls")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Feather
            VStack(spacing: 4) {
                HStack {
                    Text("Feather")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(feather)) px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $feather, in: 0...50) { editing in
                    if !editing { commitUpdate() }
                }
            }

            // Opacity
            VStack(spacing: 4) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(opacityPct))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $opacityPct, in: 0...100) { editing in
                    if !editing { commitUpdate() }
                }
            }

            // Invert
            Toggle("Invert Mask", isOn: $inverted)
                .font(.caption)
                .onChange(of: inverted) { _, _ in commitUpdate() }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func commitUpdate() {
        var updated = mask
        updated.featherRadius = feather
        updated.opacity = opacityPct / 100.0
        updated.inverted = inverted
        Task { await appState.updateMask(updated) }
    }
}
