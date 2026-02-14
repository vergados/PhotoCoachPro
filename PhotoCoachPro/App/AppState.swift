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
        case presets
        case coaching
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
        // Use larger thumbnails for Retina displays (800x800 for crisp 2x/3x rendering)
        self.thumbnailCache = ThumbnailCache(thumbnailSize: CGSize(width: 800, height: 800))
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

    // DIAGNOSTIC TEST - Simple version
    func testImport(from url: URL) async {
        errorMessage = nil

        do {
            // Step 1: Copy file
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("test.jpg")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: url, to: dest)

            // Step 2: Try ImageLoader actor
            let loaded = try await imageLoader.load(from: dest)
            errorMessage = "✅ ImageLoader works! Size: \(Int(loaded.image.extent.width))x\(Int(loaded.image.extent.height))"

        } catch {
            errorMessage = "❌ ImageLoader failed: \(error.localizedDescription)"
        }
    }

    func importPhoto(from url: URL) async {
        print("📸 Starting import from: \(url)")
        isLoading = true
        errorMessage = nil

        do {
            // FIRST: Copy file to a permanent location BEFORE processing
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let destURL = documentsURL.appendingPathComponent("Photos").appendingPathComponent(fileName)
            print("📸 Destination: \(destURL.path)")

            // Ensure directory exists
            print("📸 Creating directory...")
            try FileManager.default.createDirectory(
                at: documentsURL.appendingPathComponent("Photos"),
                withIntermediateDirectories: true
            )

            // Copy file FIRST (while security-scoped access is still valid)
            print("📸 Copying file from temporary location...")
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            print("📸 File copied successfully to permanent location")

            // NOW load image from our permanent copy
            print("📸 Loading image from permanent location...")
            let loaded = try await imageLoader.load(from: destURL)
            print("📸 Image loaded: \(loaded.image.extent.width)x\(loaded.image.extent.height)")

            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Create photo record
            print("📸 Creating photo record...")
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

            print("📸 Saving to database...")
            try database.savePhoto(photo)
            print("📸 Photo saved successfully")

            // Open in editor
            print("📸 Opening photo in editor...")
            await openPhoto(photo)

        } catch {
            print("❌ Import error: \(error)")
            errorMessage = "Failed to import photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func openPhoto(_ photo: PhotoRecord) async {
        print("🟢 Opening photo: \(photo.fileName)")
        isLoading = true
        errorMessage = nil

        do {
            // Load image
            print("🟢 Loading image from: \(photo.fileURL.path)")
            let loaded = try await imageLoader.load(from: photo.fileURL)
            currentImage = loaded.image
            print("🟢 Current image set: \(loaded.image.extent)")

            // Get or create edit history
            print("🟢 Getting edit record...")
            let editRecord = try database.getOrCreateEditRecord(for: photo)
            let historyManager = EditHistoryManager(editRecord: editRecord, database: database)
            print("🟢 Edit history created")

            currentPhoto = photo
            currentEditHistory = historyManager
            print("🟢 State updated: currentPhoto and currentEditHistory set")

            // Render current state
            print("🟢 Rendering image...")
            await renderCurrentImage()
            print("🟢 Render complete, renderedImage = \(renderedImage != nil ? "SET" : "NIL")")

            print("🟢 Switching to editor tab...")
            selectedTab = .editor
            print("🟢 Selected tab is now: \(selectedTab)")

        } catch {
            print("❌ openPhoto error: \(error)")
            errorMessage = "Failed to open photo: \(error.localizedDescription)"
        }

        print("🟢 Setting isLoading = false")
        isLoading = false
    }

    // MARK: - Editing

    func renderCurrentImage() async {
        print("🎨 renderCurrentImage called")
        print("🎨 currentImage = \(currentImage != nil ? "SET" : "NIL")")
        print("🎨 currentEditHistory = \(currentEditHistory != nil ? "SET" : "NIL")")

        guard let source = currentImage,
              let history = currentEditHistory else {
            print("❌ Cannot render: missing currentImage or currentEditHistory")
            return
        }

        print("🎨 Getting active instructions...")
        let instructions = history.editStack.activeInstructions
        print("🎨 Active instructions count: \(instructions.count)")

        print("🎨 Rendering with edit graph engine...")
        let rendered = await editGraphEngine.render(source: source, instructions: instructions)
        print("🎨 Edit graph render complete: \(rendered.extent)")

        // Render to platform image for display
        print("🎨 Converting to platform image...")
        renderedImage = await imageRenderer.renderPlatformImage(from: rendered)
        print("🎨 Platform image rendered: \(renderedImage != nil ? "SUCCESS" : "FAILED")")
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
