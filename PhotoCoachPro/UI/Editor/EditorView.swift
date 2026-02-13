//
//  EditorView.swift
//  PhotoCoachPro
//
//  Main editing canvas and controls
//

import SwiftUI

struct EditorView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedTool: EditTool = .basic
    @State private var showBeforeAfter = false
    @State private var showHistogram = true

    enum EditTool: String, CaseIterable {
        case basic = "Basic"
        case color = "Color"
        case detail = "Detail"
        case effects = "Effects"

        var icon: String {
            switch self {
            case .basic: return "sun.max"
            case .color: return "paintpalette"
            case .detail: return "sparkles"
            case .effects: return "wand.and.stars"
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // Landscape: Side-by-side
                    HStack(spacing: 0) {
                        imageCanvas
                            .frame(maxWidth: .infinity)

                        toolPanel
                            .frame(width: 320)
                    }
                } else {
                    // Portrait: Stacked
                    VStack(spacing: 0) {
                        imageCanvas
                            .frame(maxHeight: .infinity)

                        toolPanel
                            .frame(height: 300)
                    }
                }
            }
            .navigationTitle(appState.currentPhoto?.fileName ?? "Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarButtons
                }
            }
        }
    }

    // MARK: - Subviews

    private var imageCanvas: some View {
        ZStack {
            Color.black

            if let image = appState.renderedImage {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ProgressView()
            }

            // Histogram overlay
            if showHistogram {
                VStack {
                    HStack {
                        Spacer()
                        HistogramView()
                            .frame(width: 200, height: 100)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .accessibilityLabel("Image canvas")
    }

    private var toolPanel: some View {
        VStack(spacing: 0) {
            // Tool selector
            ToolPicker(selection: $selectedTool)
                .padding(.horizontal)
                .padding(.top, 12)

            Divider()

            // Tool-specific controls
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTool {
                    case .basic:
                        BasicControls()
                    case .color:
                        ColorControls()
                    case .detail:
                        DetailControls()
                    case .effects:
                        EffectsControls()
                    }
                }
                .padding()
            }

            Divider()

            // Bottom actions
            HStack(spacing: 16) {
                Button(action: { Task { await appState.undo() } }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(appState.currentEditHistory?.canUndo != true)

                Button(action: { Task { await appState.redo() } }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(appState.currentEditHistory?.canRedo != true)

                Spacer()

                Button("Reset") {
                    appState.currentEditHistory?.resetToOriginal()
                    Task { await appState.renderCurrentImage() }
                }
                .foregroundStyle(.red)

                Button("Done") {
                    appState.selectedTab = .home
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private var toolbarButtons: some View {
        Group {
            Button {
                showHistogram.toggle()
            } label: {
                Image(systemName: "chart.bar")
            }
            .accessibilityLabel("Toggle histogram")

            Button {
                showBeforeAfter.toggle()
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .accessibilityLabel("Compare before and after")
        }
    }
}

// MARK: - Tool Picker
struct ToolPicker: View {
    @Binding var selection: EditorView.EditTool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(EditorView.EditTool.allCases, id: \.self) { tool in
                Button {
                    selection = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.title3)

                        Text(tool.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selection == tool ? Color.accentColor : Color.clear)
                    .foregroundStyle(selection == tool ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.rawValue)
                .accessibilityAddTraits(selection == tool ? [.isSelected] : [])
            }
        }
    }
}
