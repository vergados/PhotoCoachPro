//
//  HSLMixerView.swift
//  PhotoCoachPro
//
//  Per-channel HSL color adjustment
//

import SwiftUI

struct HSLMixerView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedChannel: ColorChannel = .red
    @State private var selectedMode: AdjustmentMode = .hue

    enum ColorChannel: String, CaseIterable {
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case aqua = "Aqua"
        case blue = "Blue"
        case purple = "Purple"
        case magenta = "Magenta"

        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .aqua: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .magenta: return .pink
            }
        }
    }

    enum AdjustmentMode: String, CaseIterable {
        case hue = "Hue"
        case saturation = "Saturation"
        case luminance = "Luminance"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Mode selector
            Picker("Adjustment", selection: $selectedMode) {
                ForEach(AdjustmentMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Channel selector
            channelSelector

            // Slider
            channelSlider

            // Quick presets
            if selectedMode == .saturation {
                quickPresets
            }
        }
        .padding()
    }

    // MARK: - Subviews

    private var channelSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorChannel.allCases, id: \.self) { channel in
                    channelButton(channel)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func channelButton(_ channel: ColorChannel) -> some View {
        Button {
            selectedChannel = channel
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(channel.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                selectedChannel == channel ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )

                Text(channel.rawValue)
                    .font(.caption2)
                    .foregroundStyle(selectedChannel == channel ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(channel.rawValue) channel")
        .accessibilityAddTraits(selectedChannel == channel ? [.isSelected] : [])
    }

    private var channelSlider: some View {
        HSLChannelSlider(
            channel: selectedChannel,
            mode: selectedMode
        )
    }

    private var quickPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Adjustments")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                presetButton("Vibrant", action: applyVibrant)
                presetButton("Muted", action: applyMuted)
                presetButton("Desaturate", action: applyDesaturate)
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Actions

    private func applyVibrant() {
        for channel in ColorChannel.allCases {
            let instruction = EditInstruction(
                type: .hslSaturation,
                value: 20,
                metadata: ["channel": channel.rawValue.lowercased()]
            )
            Task { await appState.addEdit(instruction) }
        }
    }

    private func applyMuted() {
        for channel in ColorChannel.allCases {
            let instruction = EditInstruction(
                type: .hslSaturation,
                value: -30,
                metadata: ["channel": channel.rawValue.lowercased()]
            )
            Task { await appState.addEdit(instruction) }
        }
    }

    private func applyDesaturate() {
        for channel in ColorChannel.allCases {
            let instruction = EditInstruction(
                type: .hslSaturation,
                value: -100,
                metadata: ["channel": channel.rawValue.lowercased()]
            )
            Task { await appState.addEdit(instruction) }
        }
    }
}

// MARK: - HSL Channel Slider
struct HSLChannelSlider: View {
    let channel: HSLMixerView.ColorChannel
    let mode: HSLMixerView.AdjustmentMode

    @EnvironmentObject var appState: AppState
    @State private var value: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)

                Spacer()

                Text(formattedValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    resetValue()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(value == 0 ? 0 : 1)
            }

            Slider(value: $value, in: valueRange) { editing in
                if !editing {
                    commitValue()
                }
            }
            .accessibilityLabel("\(mode.rawValue) for \(channel.rawValue)")
            .accessibilityValue(formattedValue)
        }
        .onAppear {
            loadCurrentValue()
        }
    }

    private var label: String {
        "\(channel.rawValue) \(mode.rawValue)"
    }

    private var valueRange: ClosedRange<Double> {
        switch mode {
        case .hue:
            return -180...180
        case .saturation, .luminance:
            return -100...100
        }
    }

    private var formattedValue: String {
        String(format: mode == .hue ? "%.0f°" : "%.0f", value)
    }

    private var editType: EditInstruction.EditType {
        switch mode {
        case .hue: return .hslHue
        case .saturation: return .hslSaturation
        case .luminance: return .hslLuminance
        }
    }

    private func loadCurrentValue() {
        guard let history = appState.currentEditHistory else { return }

        // Find most recent instruction for this channel + mode
        let instructions = history.editStack.all(ofType: editType)
        if let instruction = instructions.last(where: { $0.metadata["channel"] == channel.rawValue.lowercased() }) {
            value = instruction.value
        } else {
            value = 0
        }
    }

    private func commitValue() {
        let instruction = EditInstruction(
            type: editType,
            value: value,
            metadata: ["channel": channel.rawValue.lowercased()]
        )
        Task { await appState.addEdit(instruction) }
    }

    private func resetValue() {
        value = 0
        commitValue()
    }
}
