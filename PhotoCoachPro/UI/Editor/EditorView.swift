//
//  EditorView.swift
//  PhotoCoachPro
//
//  Main editing canvas and controls
//

import SwiftUI
import CoreImage

struct EditorView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedTool: EditTool = .basic
    @State private var showBeforeAfter = false
    @State private var showHistogram = true
    @State private var curvePoints: [ToneCurvePoint] = [
        ToneCurvePoint(x: 0, y: 0),
        ToneCurvePoint(x: 0.25, y: 0.25),
        ToneCurvePoint(x: 0.75, y: 0.75),
        ToneCurvePoint(x: 1, y: 1)
    ]
    @State private var cropRect: CGRect = .zero
    @State private var cropRotation: Double = 0
    @State private var cropAspectRatio: CropAspectRatio? = nil
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var showPrintPrep = false
    @State private var showSavePreset = false
    @State private var exportSettings = ExportSettings()

    enum EditTool: String, CaseIterable {
        case basic = "Basic"
        case color = "Color"
        case detail = "Detail"
        case effects = "Effects"
        case curves = "Curves"
        case hsl = "HSL"
        case crop = "Crop"
        case mask = "Masks"
        case lens = "Lens"

        var icon: String {
            switch self {
            case .basic: return "sun.max"
            case .color: return "paintpalette"
            case .detail: return "sparkles"
            case .effects: return "wand.and.stars"
            case .curves: return "waveform.path.ecg"
            case .hsl: return "paintpalette.fill"
            case .crop: return "crop"
            case .mask: return "lasso"
            case .lens: return "camera.aperture"
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarButtons
                }
            }
            .sheet(isPresented: $showExportOptions) {
                if let photo = appState.currentPhoto {
                    ExportOptionsView(settings: $exportSettings) { _ in
                        showExportOptions = false
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let photo = appState.currentPhoto {
                    ShareView(photoRecord: photo)
                }
            }
            .sheet(isPresented: $showPrintPrep) {
                if let photo = appState.currentPhoto {
                    PrintPreparationView(photoRecord: photo)
                }
            }
            .sheet(isPresented: $showSavePreset) {
                if let editRecord = appState.currentEditHistory?.editRecord {
                    SavePresetView(editRecord: editRecord)
                }
            }
        }
    }

    // MARK: - Subviews

    private var imageCanvas: some View {
        ZStack {
            Color.black

            if showBeforeAfter {
                // Before/After comparison
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Before (original)
                        if let original = appState.currentImage,
                           let renderer = CIContext().createCGImage(original, from: original.extent) {
                            Image(decorative: renderer, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("Before")
                                        .font(.caption)
                                        .padding(8)
                                        .background(.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                }
                        }

                        // After (edited)
                        if let edited = appState.renderedImage {
                            #if os(iOS)
                            Image(uiImage: edited)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("After")
                                        .font(.caption)
                                        .padding(8)
                                        .background(.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                }
                            #elseif os(macOS)
                            Image(nsImage: edited)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("After")
                                        .font(.caption)
                                        .padding(8)
                                        .background(.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                }
                            #endif
                        }
                    }
                }
            } else {
                // Normal view (edited only)
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
                    case .curves:
                        ToneCurveView(curvePoints: $curvePoints) {
                            let sorted = curvePoints.sorted { $0.x < $1.x }
                            let pointsStr = sorted.map { "\($0.x),\($0.y)" }.joined(separator: ";")
                            let instruction = EditInstruction(
                                type: .toneCurveControlPoint,
                                value: Double(sorted.count),
                                metadata: ["points": pointsStr]
                            )
                            Task { await appState.addEdit(instruction) }
                        }
                    case .hsl:
                        HSLMixerView()
                    case .crop:
                        if let ciImage = appState.currentImage {
                            CropView(
                                cropRect: $cropRect,
                                rotationAngle: $cropRotation,
                                aspectRatio: $cropAspectRatio,
                                imageSize: ciImage.extent.size
                            ) {
                                let extent = ciImage.extent
                                let history = appState.currentEditHistory
                                if cropRect.width > 0, cropRect.height > 0 {
                                    history?.addInstruction(EditInstruction(type: .cropX, value: cropRect.origin.x / extent.width))
                                    history?.addInstruction(EditInstruction(type: .cropY, value: cropRect.origin.y / extent.height))
                                    history?.addInstruction(EditInstruction(type: .cropWidth, value: cropRect.width / extent.width))
                                    history?.addInstruction(EditInstruction(type: .cropHeight, value: cropRect.height / extent.height))
                                }
                                history?.addInstruction(EditInstruction(type: .cropRotation, value: cropRotation))
                                Task { await appState.renderCurrentImage() }
                            }
                        }
                    case .mask:
                        MaskPanelView()
                    case .lens:
                        LensControls()
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
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(NSColor.windowBackgroundColor))
        #endif
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

            Button { showExportOptions = true } label: { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Export photo")
            Button { showShareSheet = true } label: { Image(systemName: "shareplay") }
                .accessibilityLabel("Share photo")
            Button { showPrintPrep = true } label: { Image(systemName: "printer") }
                .accessibilityLabel("Print photo")
            Button { showSavePreset = true } label: { Image(systemName: "star.circle") }
                .accessibilityLabel("Save as preset")
                .disabled(appState.currentPhoto == nil)
        }
    }
}

// MARK: - Tool Picker
struct ToolPicker: View {
    @Binding var selection: EditorView.EditTool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
                        .frame(minWidth: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
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
}
