//
//  SyncManager.swift
//  PhotoCoachPro
//
//  Manages cloud synchronization
//

import Foundation
import CloudKit

/// Manages cloud sync operations
actor SyncManager {
    private let cloudKit: CloudKitService
    private let database: LocalDatabase
    private var syncStatus: SyncStatus
    private var syncQueue: [SyncQueueItem] = []
    private var conflicts: [SyncConflict] = []
    private var isInitialized = false

    // Callback for status updates
    private var statusUpdateHandler: ((SyncStatus) -> Void)?

    init(
        cloudKit: CloudKitService = CloudKitService(),
        database: LocalDatabase = .shared
    ) {
        self.cloudKit = cloudKit
        self.database = database
        self.syncStatus = SyncStatus()
    }

    // MARK: - Initialization

    func initialize() async throws {
        guard !isInitialized else { return }

        // Check iCloud availability
        let isAvailable = await cloudKit.isAccountAvailable()
        syncStatus.iCloudAvailable = isAvailable

        if isAvailable {
            // Setup subscriptions
            try await setupSubscriptions()
        }

        isInitialized = true
        notifyStatusUpdate()
    }

    private func setupSubscriptions() async throws {
        // Subscribe to changes for each record type
        let recordTypes = ["Photo", "EditRecord", "Preset"]

        for recordType in recordTypes {
            let subscriptionID = "subscription-\(recordType)"

            do {
                // Check if subscription exists
                let existing = try await cloudKit.fetchAllSubscriptions()
                let hasSubscription = existing.contains { $0.subscriptionID == subscriptionID }

                if !hasSubscription {
                    try await cloudKit.createSubscription(
                        recordType: recordType,
                        subscriptionID: subscriptionID
                    )
                }
            } catch {
                print("Failed to setup subscription for \(recordType): \(error)")
            }
        }
    }

    // MARK: - Status

    func getStatus() -> SyncStatus {
        syncStatus
    }

    func setStatusUpdateHandler(_ handler: @escaping (SyncStatus) -> Void) {
        statusUpdateHandler = handler
    }

    private func notifyStatusUpdate() {
        statusUpdateHandler?(syncStatus)
    }

    func toggleAutoSync() {
        syncStatus.autoSyncEnabled.toggle()
        notifyStatusUpdate()
    }

    func pauseSync() {
        syncStatus.state = .paused
        notifyStatusUpdate()
    }

    func resumeSync() async throws {
        guard syncStatus.state == .paused else { return }
        syncStatus.state = .idle
        notifyStatusUpdate()

        if syncStatus.hasPendingChanges {
            try await sync()
        }
    }

    // MARK: - Sync Operations

    func sync() async throws {
        guard syncStatus.canSync else { return }

        syncStatus.state = .syncing
        notifyStatusUpdate()

        do {
            // Process upload queue
            try await processUploadQueue()

            // Fetch remote changes
            try await fetchRemoteChanges()

            // Update status
            syncStatus.state = .idle
            syncStatus.updateLastSync()
            notifyStatusUpdate()

        } catch {
            syncStatus.state = .error
            syncStatus.addError(SyncStatus.SyncError(
                recordType: "System",
                recordID: UUID(),
                error: error.localizedDescription
            ))
            notifyStatusUpdate()
            throw error
        }
    }

    // MARK: - Upload Queue

    private func processUploadQueue() async throws {
        guard !syncQueue.isEmpty else { return }

        syncStatus.state = .uploading
        syncStatus.pendingUploads = syncQueue.count
        notifyStatusUpdate()

        // Sort by priority
        let sorted = syncQueue.sorted { $0.priority.rawValue > $1.priority.rawValue }

        for item in sorted {
            do {
                try await processQueueItem(item)

                // Remove from queue
                if let index = syncQueue.firstIndex(where: { $0.id == item.id }) {
                    syncQueue.remove(at: index)
                    syncStatus.pendingUploads -= 1
                    notifyStatusUpdate()
                }

            } catch {
                // Handle retry logic
                if var retryItem = syncQueue.first(where: { $0.id == item.id }) {
                    if retryItem.canRetry {
                        retryItem.incrementRetry(error: error.localizedDescription)
                        if let index = syncQueue.firstIndex(where: { $0.id == item.id }) {
                            syncQueue[index] = retryItem
                        }
                    } else {
                        // Max retries reached
                        syncStatus.addError(SyncStatus.SyncError(
                            recordType: item.recordType,
                            recordID: item.recordID,
                            error: error.localizedDescription
                        ))
                    }
                }
            }
        }
    }

    private func processQueueItem(_ item: SyncQueueItem) async throws {
        switch item.operation {
        case .create, .update:
            // Upload record
            try await uploadRecord(recordType: item.recordType, recordID: item.recordID)

        case .delete:
            // Delete record
            let recordName = "\(item.recordType)-\(item.recordID.uuidString)"
            let recordID = CKRecord.ID(recordName: recordName)
            try await cloudKit.delete(recordID: recordID)
        }
    }

    private func uploadRecord(recordType: String, recordID: UUID) async throws {
        switch recordType {
        case "Photo":
            try await uploadPhoto(recordID: recordID)

        case "EditRecord":
            try await uploadEditRecord(recordID: recordID)

        case "Preset":
            try await uploadPreset(recordID: recordID)

        default:
            throw CloudSyncError.invalidRecord
        }
    }

    // MARK: - Upload Specific Records

    private func uploadPhoto(recordID: UUID) async throws {
        guard let photo = await database.fetchPhoto(id: recordID) else {
            throw CloudSyncError.invalidRecord
        }

        // Convert to cloud record
        let cloudPhoto = CloudPhoto(
            id: photo.id,
            fileName: photo.fileName,
            width: photo.width,
            height: photo.height,
            fileSizeBytes: photo.fileSizeBytes,
            importedDate: photo.importedDate,
            modifiedDate: photo.editRecord?.modifiedDate ?? photo.importedDate,
            deviceID: await cloudKit.currentDeviceID
        )

        _ = try await cloudKit.save(cloudPhoto)
    }

    private func uploadEditRecord(recordID: UUID) async throws {
        // Fetch from database
        guard let editRecord = await database.fetchEditRecord(for: recordID) else {
            throw CloudSyncError.invalidRecord
        }

        let encoder = JSONEncoder()
        let instructionsData = try encoder.encode(editRecord.editStack.activeInstructions)

        let cloudEdit = CloudEditRecord(
            id: editRecord.id,
            photoID: editRecord.photoID,
            instructionsData: instructionsData,
            historyIndex: editRecord.editStack.currentIndex,
            modifiedDate: editRecord.modifiedDate,
            deviceID: await cloudKit.currentDeviceID
        )

        _ = try await cloudKit.save(cloudEdit)
    }

    private func uploadPreset(recordID: UUID) async throws {
        guard let preset = await database.fetchPreset(id: recordID),
              let presetModel = try? preset.toPreset() else {
            throw CloudSyncError.invalidRecord
        }

        let encoder = JSONEncoder()
        let instructionsData = try encoder.encode(presetModel.instructions)

        let cloudPreset = CloudPreset(
            id: presetModel.id,
            name: presetModel.name,
            category: presetModel.category.rawValue,
            instructionsData: instructionsData,
            author: presetModel.author,
            presetDescription: presetModel.description,
            tags: presetModel.tags,
            isFavorite: presetModel.isFavorite,
            isBuiltIn: presetModel.isBuiltIn,
            createdDate: presetModel.createdAt,
            modifiedDate: presetModel.modifiedAt,
            deviceID: await cloudKit.currentDeviceID
        )

        _ = try await cloudKit.save(cloudPreset)
    }

    // MARK: - Download Remote Changes

    private func fetchRemoteChanges() async throws {
        syncStatus.state = .downloading
        notifyStatusUpdate()

        // Fetch changes for each record type
        try await fetchRemotePhotos()
        try await fetchRemoteEditRecords()
        try await fetchRemotePresets()
    }

    private func fetchRemotePhotos() async throws {
        let cloudPhotos = try await cloudKit.fetchAll(recordType: CloudPhoto.recordType, type: CloudPhoto.self)

        for cloudPhoto in cloudPhotos {
            // Check if exists locally
            let existing = await database.fetchPhoto(id: cloudPhoto.id)

            if let existing = existing {
                // Check for conflict
                let localModified = existing.editRecord?.modifiedDate ?? existing.importedDate
                if localModified != cloudPhoto.modifiedDate {
                    detectConflict(
                        recordType: "Photo",
                        recordID: cloudPhoto.id,
                        localModified: localModified,
                        remoteModified: cloudPhoto.modifiedDate,
                        localRecord: existing,
                        remoteRecord: cloudPhoto
                    )
                }
            } else {
                // Download new photo
                // Note: In production, download file data separately
                print("New remote photo: \(cloudPhoto.fileName)")
            }
        }
    }

    private func fetchRemoteEditRecords() async throws {
        let cloudEdits = try await cloudKit.fetchAll(recordType: CloudEditRecord.recordType, type: CloudEditRecord.self)

        for cloudEdit in cloudEdits {
            // Decode instructions
            let decoder = JSONDecoder()
            let instructions = try decoder.decode([EditInstruction].self, from: cloudEdit.instructionsData)

            // Check if exists locally
            let existing = await database.fetchEditRecord(for: cloudEdit.photoID)

            if let existing = existing {
                // Check for conflict
                if existing.modifiedDate != cloudEdit.modifiedDate {
                    detectConflict(
                        recordType: "EditRecord",
                        recordID: cloudEdit.id,
                        localModified: existing.modifiedDate,
                        remoteModified: cloudEdit.modifiedDate,
                        localRecord: existing,
                        remoteRecord: cloudEdit
                    )
                }
            } else {
                // Create new edit record
                print("New remote edit record for photo: \(cloudEdit.photoID)")
            }
        }
    }

    private func fetchRemotePresets() async throws {
        let cloudPresets = try await cloudKit.fetchAll(recordType: CloudPreset.recordType, type: CloudPreset.self)

        for cloudPreset in cloudPresets {
            // Check if exists locally
            let existing = await database.fetchPreset(id: cloudPreset.id)

            if let existing = existing {
                // Check for conflict
                if existing.modifiedAt != cloudPreset.modifiedDate {
                    detectConflict(
                        recordType: "Preset",
                        recordID: cloudPreset.id,
                        localModified: existing.modifiedAt,
                        remoteModified: cloudPreset.modifiedDate,
                        localRecord: existing,
                        remoteRecord: cloudPreset
                    )
                }
            } else {
                // Create new preset
                print("New remote preset: \(cloudPreset.name)")
            }
        }
    }

    // MARK: - Conflict Detection

    private func detectConflict(
        recordType: String,
        recordID: UUID,
        localModified: Date,
        remoteModified: Date,
        localRecord: Any,
        remoteRecord: Any
    ) {
        let conflict = SyncConflict(
            recordType: recordType,
            recordID: recordID,
            localRecord: localRecord,
            remoteRecord: remoteRecord,
            localModifiedDate: localModified,
            remoteModifiedDate: remoteModified
        )

        conflicts.append(conflict)

        // Auto-resolve with last-write-wins if enabled
        // Otherwise, wait for manual resolution
        print("Conflict detected for \(recordType): \(recordID)")
    }

    func getConflicts() -> [SyncConflict] {
        conflicts
    }

    func resolveConflict(id: UUID, resolution: SyncConflict.Resolution) async throws {
        guard let conflict = conflicts.first(where: { $0.id == id }) else { return }

        // Apply resolution
        // Implementation depends on record type and resolution strategy

        // Remove from conflicts
        conflicts.removeAll { $0.id == id }
    }

    // MARK: - Queue Management

    func queueUpload(recordType: String, recordID: UUID, priority: SyncQueueItem.Priority = .normal) {
        let item = SyncQueueItem(
            operation: .update,
            recordType: recordType,
            recordID: recordID,
            priority: priority
        )

        syncQueue.append(item)
        syncStatus.pendingUploads += 1
        notifyStatusUpdate()

        // Auto-sync if enabled
        if syncStatus.autoSyncEnabled {
            Task {
                try? await sync()
            }
        }
    }

    func queueDelete(recordType: String, recordID: UUID) {
        let item = SyncQueueItem(
            operation: .delete,
            recordType: recordType,
            recordID: recordID,
            priority: .high
        )

        syncQueue.append(item)
        syncStatus.pendingUploads += 1
        notifyStatusUpdate()
    }

    func clearQueue() {
        syncQueue.removeAll()
        syncStatus.pendingUploads = 0
        notifyStatusUpdate()
    }
}
