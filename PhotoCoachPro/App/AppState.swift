//
//  AppState.swift
//  PhotoCoachPro
//
//  Central app state management
//

import Foundation
import SwiftUI
import CoreImage
import Combine
import Photos

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

    // Phase 5: Cloud sync (optional - gated on privacySettings.cloudSyncEnabled)
    var syncManager: SyncManager?

    // Phase 6: Export engine
    let exportEngine: ExportEngine

    // Phase 5: Panorama and Upscaling
    let panoramaStitcher: PanoramaStitcher
    let dpiUpscaler: DPIUpscaler

    // Quick metrics analyzer (lightweight, no AI/ML)
    let quickMetricsAnalyzer: QuickMetricsAnalyzer

    // Skill history (persisted via SwiftData)
    @Published var skillHistory: SkillHistory
    private let skillUserID: UUID
    private var syncSettingsCancellable: AnyCancellable? = nil

    // Current editing session
    @Published var currentPhoto: PhotoRecord? {
        didSet {
            print("🔄 AppState.currentPhoto changed: \(currentPhoto?.fileName ?? "nil")")
        }
    }
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
        case panorama
        case upscaling
    }

    init() {
        // Initialize singletons
        self.database = LocalDatabase.shared
        self.privacySettings = PrivacySettings.shared

        // Resolve skill user ID and load persisted skill history
        let resolvedUserID = AppState.resolveSkillUserID()
        self.skillUserID = resolvedUserID
        if let record = LocalDatabase.shared.fetchSkillHistoryRecord(userID: resolvedUserID),
           let history = record.skillHistory {
            self.skillHistory = history
        } else {
            self.skillHistory = SkillHistory(userID: resolvedUserID)
        }

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

        // Phase 5: Cloud sync (gated on cloudSyncEnabled preference)
        if PrivacySettings.shared.cloudSyncEnabled {
            let manager = SyncManager()
            self.syncManager = manager
            Task { try? await manager.initialize() }
        } else {
            self.syncManager = nil
        }

        // Phase 6: Export engine
        self.exportEngine = ExportEngine()

        // Phase 5: Panorama and Upscaling
        self.panoramaStitcher = PanoramaStitcher()
        self.dpiUpscaler = DPIUpscaler()

        // Quick metrics analyzer
        self.quickMetricsAnalyzer = QuickMetricsAnalyzer()

        // Subscribe to cloud sync setting changes (dropFirst prevents double-init on launch)
        syncSettingsCancellable = PrivacySettings.shared.$cloudSyncEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                Task { @MainActor in
                    if enabled {
                        let manager = SyncManager()
                        self.syncManager = manager
                        Task { try? await manager.initialize() }
                    } else {
                        self.syncManager = nil
                    }
                }
            }

        // Seed built-in presets on first launch
        Task {
            do {
                try await PresetLibrary.installBuiltInPresets(manager: customPresetManager)
                print("✅ Built-in presets seeded successfully")
            } catch {
                print("❌ Failed to seed built-in presets: \(error)")
            }
        }
    }

    // MARK: - Skill User ID

    private static func resolveSkillUserID() -> UUID {
        let key = "com.photocoachpro.skillUserID"
        if let existing = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let newID = UUID()
        UserDefaults.standard.set(newID.uuidString, forKey: key)
        return newID
    }

    // MARK: - Photo Management

    /// Import a photo from the Photos library using its asset identifier (no file copy)
    func importPhotoFromLibrary(assetIdentifier: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Load image directly from Photos library
            let loaded = try await imageLoader.loadFromAsset(localIdentifier: assetIdentifier)

            // Fetch PHAsset for metadata (dimensions, filename, date)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            let asset = fetchResult.firstObject

            let fileName: String
            if let asset = asset,
               let resource = PHAssetResource.assetResources(for: asset).first {
                fileName = resource.originalFilename
            } else {
                fileName = "\(assetIdentifier).jpeg"
            }

            let photo = PhotoRecord(
                filePath: "",
                assetIdentifier: assetIdentifier,
                fileName: fileName,
                createdDate: asset?.creationDate ?? Date(),
                width: asset.map { Int($0.pixelWidth) } ?? Int(loaded.image.extent.width),
                height: asset.map { Int($0.pixelHeight) } ?? Int(loaded.image.extent.height),
                fileFormat: URL(fileURLWithPath: fileName).pathExtension.lowercased(),
                fileSizeBytes: 0,
                exifSnapshot: loaded.metadata,
                sourceType: "photosLibrary"
            )

            try database.savePhoto(photo)
            await openPhoto(photo, loadedImage: loaded)

        } catch {
            errorMessage = "Failed to import photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Import a photo from the file system using a security-scoped bookmark (no file copy)
    func importPhotoFromFileSystem(url: URL, bookmarkData: Data?) async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded: LoadedImage
            if let bookmark = bookmarkData {
                loaded = try await imageLoader.loadFromBookmark(data: bookmark)
            } else {
                loaded = try await imageLoader.load(from: url)
            }

            // Get file size (best effort)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

            let photo = PhotoRecord(
                filePath: url.path,
                fileName: url.lastPathComponent,
                createdDate: loaded.metadata?.dateTimeOriginal ?? Date(),
                width: Int(loaded.image.extent.width),
                height: Int(loaded.image.extent.height),
                fileFormat: loaded.fileType,
                fileSizeBytes: fileSize,
                exifSnapshot: loaded.metadata,
                sourceType: "fileSystem",
                bookmarkData: bookmarkData
            )

            try database.savePhoto(photo)
            await openPhoto(photo, loadedImage: loaded)

        } catch {
            errorMessage = "Failed to import photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func openPhoto(_ photo: PhotoRecord) async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await imageLoader.loadImage(for: photo)
            await openPhoto(photo, loadedImage: loaded)

        } catch {
            errorMessage = "Failed to open photo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func openPhoto(_ photo: PhotoRecord, loadedImage: LoadedImage) async {
        do {
            currentImage = loadedImage.image

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
    }

    // MARK: - Editing

    func renderCurrentImage() async {
        guard let source = currentImage,
              let history = currentEditHistory else {
            return
        }

        let instructions = history.editStack.activeInstructions
        let rendered = await editGraphEngine.render(source: source, instructions: instructions)

        // Render to platform image for display
        renderedImage = await imageRenderer.renderPlatformImage(from: rendered)
    }

    func addEdit(_ instruction: EditInstruction) async {
        guard let history = currentEditHistory else { return }

        // Check if the most recent active instruction is the same type
        // If so, update it instead of adding a new one
        if let existing = history.editStack.mostRecent(ofType: instruction.type),
           history.editStack.activeInstructions.last?.type == instruction.type {
            // Update the existing instruction with the new value
            var updatedInstruction = existing
            updatedInstruction.value = instruction.value
            updatedInstruction.timestamp = Date()
            history.updateInstruction(updatedInstruction)
        } else {
            // Add as a new instruction
            history.addInstruction(instruction)
        }

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

    // MARK: - Skill History

    /// Record a critique result into the persisted skill history
    func recordCritiqueResult(_ result: CritiqueResult) {
        skillHistory.recordCritique(result)
        saveSkillHistory()
    }

    private func saveSkillHistory() {
        if let existing = database.fetchSkillHistoryRecord(userID: skillUserID) {
            existing.skillHistory = skillHistory
            try? database.updateSkillHistoryRecord(existing)
        } else {
            let record = SkillHistoryRecord(id: skillUserID)
            record.skillHistory = skillHistory
            try? database.saveSkillHistoryRecord(record)
        }
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
