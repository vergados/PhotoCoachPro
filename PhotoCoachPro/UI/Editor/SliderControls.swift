//
//  SliderControls.swift
//  PhotoCoachPro
//
//  Parametric adjustment sliders
//

import SwiftUI

// MARK: - Basic Controls
struct BasicControls: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            EditSlider(
                label: "Exposure",
                type: .exposure,
                icon: "sun.max"
            )

            EditSlider(
                label: "Contrast",
                type: .contrast,
                icon: "circle.lefthalf.filled"
            )

            EditSlider(
                label: "Highlights",
                type: .highlights,
                icon: "sun.max.fill"
            )

            EditSlider(
                label: "Shadows",
                type: .shadows,
                icon: "moon.fill"
            )

            EditSlider(
                label: "Whites",
                type: .whites,
                icon: "circle.fill"
            )

            EditSlider(
                label: "Blacks",
                type: .blacks,
                icon: "circle"
            )
        }
    }
}

// MARK: - Color Controls
struct ColorControls: View {
    var body: some View {
        VStack(spacing: 16) {
            EditSlider(
                label: "Temperature",
                type: .temperature,
                icon: "thermometer"
            )

            EditSlider(
                label: "Tint",
                type: .tint,
                icon: "eyedropper"
            )

            EditSlider(
                label: "Saturation",
                type: .saturation,
                icon: "paintpalette"
            )

            EditSlider(
                label: "Vibrance",
                type: .vibrance,
                icon: "paintpalette.fill"
            )
        }
    }
}

// MARK: - Detail Controls
struct DetailControls: View {
    var body: some View {
        VStack(spacing: 16) {
            EditSlider(
                label: "Texture",
                type: .texture,
                icon: "square.grid.3x3"
            )

            EditSlider(
                label: "Clarity",
                type: .clarity,
                icon: "sparkles"
            )

            EditSlider(
                label: "Sharpening",
                type: .sharpAmount,
                icon: "camera.filters"
            )

            EditSlider(
                label: "Noise Reduction",
                type: .noiseReduction,
                icon: "waveform"
            )
        }
    }
}

// MARK: - Effects Controls
struct EffectsControls: View {
    var body: some View {
        VStack(spacing: 16) {
            EditSlider(
                label: "Dehaze",
                type: .dehaze,
                icon: "cloud.fill"
            )

            EditSlider(
                label: "Vignette",
                type: .vignetteAmount,
                icon: "circle.dotted"
            )

            EditSlider(
                label: "Grain",
                type: .grainAmount,
                icon: "camera.metering.matrix"
            )
        }
    }
}

// MARK: - Reusable Edit Slider
struct EditSlider: View {
    let label: String
    let type: EditInstruction.EditType
    let icon: String

    @EnvironmentObject var appState: AppState
    @State private var value: Double = 0
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)

                Button {
                    resetValue()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(value == type.defaultValue ? 0 : 1)
                .accessibilityLabel("Reset \(label)")
            }

            Slider(
                value: $value,
                in: type.range,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        commitValue()
                    }
                }
            )
            .tint(isEditing ? .accentColor : .primary.opacity(0.3))
            .accessibilityLabel(label)
            .accessibilityValue(formattedValue)
        }
        .onAppear {
            loadCurrentValue()
        }
    }

    private var formattedValue: String {
        if type == .exposure {
            return String(format: "%+.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }

    private func loadCurrentValue() {
        guard let history = appState.currentEditHistory else { return }
        value = history.currentValue(for: type)
    }

    private func commitValue() {
        Task {
            let instruction = EditInstruction(type: type, value: value)
            await appState.addEdit(instruction)
        }
    }

    private func resetValue() {
        value = type.defaultValue
        commitValue()
    }
}
