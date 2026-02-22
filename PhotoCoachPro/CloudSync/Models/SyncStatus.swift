//
//  SyncStatus.swift
//  PhotoCoachPro
//
//  Sync status tracking
//

import Foundation

/// Current sync status
struct SyncStatus: Codable, Equatable {
    var state: SyncState
    var lastSyncDate: Date?
    var pendingUploads: Int
    var pendingDownloads: Int
    var errors: [SyncError]
    var iCloudAvailable: Bool
    var autoSyncEnabled: Bool

    init(
        state: SyncState = .idle,
        lastSyncDate: Date? = nil,
        pendingUploads: Int = 0,
        pendingDownloads: Int = 0,
        errors: [SyncError] = [],
        iCloudAvailable: Bool = false,
        autoSyncEnabled: Bool = false
    ) {
        self.state = state
        self.lastSyncDate = lastSyncDate
        self.pendingUploads = pendingUploads
        self.pendingDownloads = pendingDownloads
        self.errors = errors
        self.iCloudAvailable = iCloudAvailable
        self.autoSyncEnabled = autoSyncEnabled
    }

    // MARK: - Sync State

    enum SyncState: String, Codable {
        case idle = "Idle"
        case syncing = "Syncing"
        case uploading = "Uploading"
        case downloading = "Downloading"
        case error = "Error"
        case paused = "Paused"

        var icon: String {
            switch self {
            case .idle: return "checkmark.icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .uploading: return "icloud.and.arrow.up"
            case .downloading: return "icloud.and.arrow.down"
            case .error: return "exclamationmark.icloud"
            case .paused: return "pause.circle"
            }
        }

        var color: String {
            switch self {
            case .idle: return "green"
            case .syncing, .uploading, .downloading: return "blue"
            case .error: return "red"
            case .paused: return "orange"
            }
        }
    }

    // MARK: - Sync Error

    struct SyncError: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var recordType: String
        var recordID: UUID
        var error: String
        var timestamp: Date
        var isResolved: Bool

        init(
            recordType: String,
            recordID: UUID,
            error: String,
            timestamp: Date = Date(),
            isResolved: Bool = false
        ) {
            self.recordType = recordType
            self.recordID = recordID
            self.error = error
            self.timestamp = timestamp
            self.isResolved = isResolved
        }
    }

    // MARK: - Computed Properties

    var isSyncing: Bool {
        state == .syncing || state == .uploading || state == .downloading
    }

    var hasErrors: Bool {
        !errors.filter { !$0.isResolved }.isEmpty
    }

    var unresolvedErrors: [SyncError] {
        errors.filter { !$0.isResolved }
    }

    var totalPending: Int {
        pendingUploads + pendingDownloads
    }

    var hasPendingChanges: Bool {
        totalPending > 0
    }

    var canSync: Bool {
        iCloudAvailable && !isSyncing && state != .paused
    }

    var statusMessage: String {
        if !iCloudAvailable {
            return "iCloud not available"
        }

        switch state {
        case .idle:
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            } else {
                return "Not synced"
            }

        case .syncing:
            return "Syncing..."

        case .uploading:
            return "Uploading \(pendingUploads) item(s)"

        case .downloading:
            return "Downloading \(pendingDownloads) item(s)"

        case .error:
            return "Sync error: \(unresolvedErrors.count) issue(s)"

        case .paused:
            return "Sync paused"
        }
    }

    // MARK: - Methods

    mutating func addError(_ error: SyncError) {
        errors.append(error)
        state = .error
    }

    mutating func resolveError(id: UUID) {
        if let index = errors.firstIndex(where: { $0.id == id }) {
            errors[index].isResolved = true
        }

        // If all errors resolved, return to idle
        if !hasErrors {
            state = .idle
        }
    }

    mutating func clearErrors() {
        errors.removeAll()
        if state == .error {
            state = .idle
        }
    }

    mutating func updateLastSync() {
        lastSyncDate = Date()
    }

    mutating func reset() {
        state = .idle
        pendingUploads = 0
        pendingDownloads = 0
        errors.removeAll()
    }
}

// MARK: - Sync Conflict

struct SyncConflict: Identifiable {
    var id: UUID = UUID()
    var recordType: String
    var recordID: UUID
    var localRecord: Any
    var remoteRecord: Any
    var localModifiedDate: Date
    var remoteModifiedDate: Date
    var detectedAt: Date

    enum Resolution {
        case keepLocal
        case keepRemote
        case keepBoth
        case manual
    }

    init(
        recordType: String,
        recordID: UUID,
        localRecord: Any,
        remoteRecord: Any,
        localModifiedDate: Date,
        remoteModifiedDate: Date,
        detectedAt: Date = Date()
    ) {
        self.recordType = recordType
        self.recordID = recordID
        self.localRecord = localRecord
        self.remoteRecord = remoteRecord
        self.localModifiedDate = localModifiedDate
        self.remoteModifiedDate = remoteModifiedDate
        self.detectedAt = detectedAt
    }

    var isLocalNewer: Bool {
        localModifiedDate > remoteModifiedDate
    }

    var isRemoteNewer: Bool {
        remoteModifiedDate > localModifiedDate
    }

    var timeDifference: TimeInterval {
        abs(localModifiedDate.timeIntervalSince(remoteModifiedDate))
    }
}

// MARK: - Sync Queue Item

struct SyncQueueItem: Codable, Identifiable {
    var id: UUID = UUID()
    var operation: SyncOperation
    var recordType: String
    var recordID: UUID
    var recordData: Data?
    var priority: Priority
    var createdAt: Date
    var retryCount: Int
    var lastError: String?

    enum SyncOperation: String, Codable {
        case create = "Create"
        case update = "Update"
        case delete = "Delete"
    }

    enum Priority: Int, Codable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
    }

    init(
        operation: SyncOperation,
        recordType: String,
        recordID: UUID,
        recordData: Data? = nil,
        priority: Priority = .normal,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.operation = operation
        self.recordType = recordType
        self.recordID = recordID
        self.recordData = recordData
        self.priority = priority
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
    }

    var canRetry: Bool {
        retryCount < 3
    }

    mutating func incrementRetry(error: String) {
        retryCount += 1
        lastError = error
    }
}
