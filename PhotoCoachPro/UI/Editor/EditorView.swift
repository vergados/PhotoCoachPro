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
            imageCanvas
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomSection
                }
                .background(DS.bg)
                .navigationTitle(appState.currentPhoto?.fileName ?? "Editor")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                #if os(iOS)
                .toolbarBackground(DS.bgRaised, for: .navigationBar)
                #endif
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarButtons
                    }
                }
                .sheet(isPresented: $showExportOptions) {
                    if let _ = appState.currentPhoto {
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

    // MARK: - Image Canvas

    private var imageCanvas: some View {
        ZStack {
            Color.black

            if showBeforeAfter {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        if let original = appState.currentImage,
                           let renderer = CIContext().createCGImage(original, from: original.extent) {
                            Image(decorative: renderer, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("BEFORE")
                                        .font(.system(size: 9, weight: .medium))
                                        .tracking(1.0)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.6))
                                        .foregroundStyle(DS.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .padding(8)
                                }
                        }

                        if let edited = appState.renderedImage {
                            #if os(iOS)
                            Image(uiImage: edited)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("AFTER")
                                        .font(.system(size: 9, weight: .medium))
                                        .tracking(1.0)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.6))
                                        .foregroundStyle(DS.accent)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .padding(8)
                                }
                            #elseif os(macOS)
                            Image(nsImage: edited)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width / 2)
                                .overlay(alignment: .topLeading) {
                                    Text("AFTER")
                                        .font(.system(size: 9, weight: .medium))
                                        .tracking(1.0)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.6))
                                        .foregroundStyle(DS.accent)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .padding(8)
                                }
                            #endif
                        }
                    }
                }
            } else {
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
                        .tint(DS.accent)
                }
            }

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

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DS.border)
                .frame(height: 1)

            RolodexToolPicker(selection: $selectedTool)
                .frame(height: 72)
                .background(DS.bgRaised)

            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    toolControls
                }
                .padding()
            }
            .frame(height: 200)
            .background(DS.bgRaised)

            Rectangle()
                .fill(DS.border)
                .frame(height: 1)

            HStack(spacing: 16) {
                Button(action: { Task { await appState.undo() } }) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(DS.textSecondary)
                }
                .disabled(appState.currentEditHistory?.canUndo != true)

                Button(action: { Task { await appState.redo() } }) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundStyle(DS.textSecondary)
                }
                .disabled(appState.currentEditHistory?.canRedo != true)

                Spacer()

                Button("Reset") {
                    appState.currentEditHistory?.resetToOriginal()
                    Task { await appState.renderCurrentImage() }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.textSecondary)

                Button("Done") {
                    appState.selectedTab = .home
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(DS.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()
            .background(DS.bgRaised)
        }
    }

    @ViewBuilder
    private var toolControls: some View {
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

    // MARK: - Toolbar Buttons

    private var toolbarButtons: some View {
        Group {
            Button {
                showHistogram.toggle()
            } label: {
                Image(systemName: "chart.bar")
                    .foregroundStyle(showHistogram ? DS.accent : DS.textSecondary)
            }
            .accessibilityLabel("Toggle histogram")

            Button {
                showBeforeAfter.toggle()
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(showBeforeAfter ? DS.accent : DS.textSecondary)
            }
            .accessibilityLabel("Compare before and after")

            Button { showExportOptions = true } label: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(DS.textSecondary)
            }
            .accessibilityLabel("Export photo")

            Button { showShareSheet = true } label: {
                Image(systemName: "shareplay").foregroundStyle(DS.textSecondary)
            }
            .accessibilityLabel("Share photo")

            Button { showPrintPrep = true } label: {
                Image(systemName: "printer").foregroundStyle(DS.textSecondary)
            }
            .accessibilityLabel("Print photo")

            Button { showSavePreset = true } label: {
                Image(systemName: "star.circle").foregroundStyle(DS.textSecondary)
            }
            .accessibilityLabel("Save as preset")
            .disabled(appState.currentPhoto == nil)
        }
    }
}

// MARK: - Rolodex Tool Picker

struct RolodexToolPicker: View {
    @Binding var selection: EditorView.EditTool
    @State private var scrolledTool: EditorView.EditTool? = nil

    var body: some View {
        GeometryReader { geometry in
            let slotWidth = geometry.size.width / 3.0

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(EditorView.EditTool.allCases, id: \.self) { tool in
                            RolodexItem(tool: tool, isSelected: selection == tool)
                                .frame(width: slotWidth)
                                .id(tool)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, slotWidth, for: .scrollContent)
                .scrollPosition(id: $scrolledTool, anchor: .center)
                .onChange(of: scrolledTool) { _, newTool in
                    if let tool = newTool {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection = tool
                        }
                    }
                }
                .onAppear {
                    scrolledTool = selection
                }

                // Thin accent line beneath the center slot indicating selected tool
                Rectangle()
                    .fill(DS.accent)
                    .frame(width: slotWidth, height: 2)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Rolodex Item

private struct RolodexItem: View {
    let tool: EditorView.EditTool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.icon)
                .font(.system(
                    size: isSelected ? 22 : 16,
                    weight: isSelected ? .semibold : .regular
                ))
                .foregroundStyle(isSelected ? DS.accent : DS.textTertiary)
                .animation(.easeInOut(duration: 0.18), value: isSelected)

            Text(tool.rawValue.uppercased())
                .font(.system(
                    size: isSelected ? 11 : 10,
                    weight: isSelected ? .semibold : .regular
                ))
                .tracking(1)
                .foregroundStyle(isSelected ? DS.accent : DS.textTertiary)
                .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
