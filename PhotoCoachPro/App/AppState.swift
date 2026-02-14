//
//  AppState.swift
//  PhotoCoachPro
//
//  Central app state management
//

import Foundation
import SwiftUI
import CoreImage

/// Central app state
@MainActor
class AppState: ObservableObject {
    // Singletons
    let database: LocalDatabase
    let privacySettings: PrivacySettings

    // Core engines (actors)
    let colorSpaceManager: ColorSpaceManager
    let imageLoader: ImageLoader
    let imageRenderer: ImageRenderer
    let thumbnailCache: ThumbnailCache
    let editGraphEngine: EditGraphEngine
    let exifReader: EXIFReader

    // Phase 1 managers
    let presetManager: EditPresetManager
    let exportManager: ExportManager

    // Phase 4: Preset system
    let customPresetManager: PresetManager
    let presetApplicator: PresetApplicator

    // Phase 5: Cloud sync (optional - initialize later)
    var syncManager: SyncManager?

    // Phase 6: Export engine
    let exportEngine: ExportEngine

    // Current editing session
    @Published var currentPhoto: PhotoRecord?
    @Published var currentEditHistory: EditHistoryManager?
    @Published var currentImage: CIImage?
    @Published var renderedImage: PlatformImage?

    // UI state
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab: AppTab = .home

    enum AppTab {
        case home
        case editor
        case export
    }

    init() {
        // Initialize singletons
        self.database = LocalDatabase.shared
        self.privacySettings = PrivacySettings.shared

        // Initialize actors and managers
        self.colorSpaceManager = ColorSpaceManager()
        self.imageLoader = ImageLoader(colorSpaceManager: colorSpaceManager)
        self.imageRenderer = ImageRenderer(colorSpaceManager: colorSpaceManager)
        self.thumbnailCache = ThumbnailCache()
        self.editGraphEngine = EditGraphEngine()
        self.exifReader = EXIFReader()

        // Phase 1 managers
        self.presetManager = EditPresetManager()
        self.exportManager = ExportManager(
            renderer: imageRenderer,
            colorSpaceManager: colorSpaceManager,
            privacySettings: privacySettings
        )

        // Phase 4: Preset system
        self.customPresetManager = PresetManager(database: database)
        self.presetApplicator = PresetApplicator()

        // Phase 5: Cloud sync (optional - can be initialized later)
        self.syncManager = nil

        // Phase 6: Export engine
        self.exportEngine = ExportEngine()
    }

    // MARK: - Photo Management

    func importPhoto(from url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            // Load image
            let loaded = try await imageLoader.load(from: url)

            // Create file copy in app documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let destURL = documentsURL.appendingPathComponent("Photos").appendingPathComponent(fileName)

            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: documentsURL.appendingPathComponent("Photos"),
                withIntermediateDirectories: true
            )

            // Copy file
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)

            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Create photo record
            let photo = PhotoRecord(
                filePath: destURL.path,
                fileName: fileName,
                createdDate: loaded.metadata?.dateTimeOriginal ?? Date(),
                width: Int(loaded.image.extent.width),
                height: Int(loaded.image.extent.height),
                fileFormat: loaded.fileType,
                fileSizeBytes: fileSize,
                exifSnapshot: loaded.metadata
            )

            try database.savePhoto(photo)

            // Open in editor
            await openPhoto(photo)

        } catch {
            errorMessage = "Failed to import photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func openPhoto(_ photo: PhotoRecord) async {
        isLoading = true
        errorMessage = nil

        do {
            // Load image
            let loaded = try await imageLoader.load(from: photo.fileURL)
            currentImage = loaded.image

            // Get or create edit history
            let editRecord = try database.getOrCreateEditRecord(for: photo)
            let historyManager = EditHistoryManager(editRecord: editRecord, database: database)

            currentPhoto = photo
            currentEditHistory = historyManager

            // Render current state
            await renderCurrentImage()

            selectedTab = .editor

        } catch {
            errorMessage = "Failed to open photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Editing

    func renderCurrentImage() async {
        guard let source = currentImage,
              let history = currentEditHistory else { return }

        let instructions = history.editStack.activeInstructions
        let rendered = await editGraphEngine.render(source: source, instructions: instructions)

        // Render to platform image for display
        renderedImage = await imageRenderer.renderPlatformImage(from: rendered)
    }

    func addEdit(_ instruction: EditInstruction) async {
        currentEditHistory?.addInstruction(instruction)
        await renderCurrentImage()
    }

    func undo() async {
        currentEditHistory?.undo()
        await renderCurrentImage()
    }

    func redo() async {
        currentEditHistory?.redo()
        await renderCurrentImage()
    }

    // MARK: - Export

    func exportCurrent(to url: URL, preset: ExportManager.ExportPreset) async {
        guard let source = currentImage,
              let history = currentEditHistory,
              let photo = currentPhoto else { return }

        isLoading = true
        errorMessage = nil

        do {
            let instructions = history.editStack.activeInstructions
            let rendered = await editGraphEngine.render(source: source, instructions: instructions)

            try await exportManager.export(
                image: rendered,
                to: url,
                preset: preset,
                metadata: PhotoMetadata(exif: photo.exifSnapshot)
            )
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
