//
//  CloudRecord.swift
//  PhotoCoachPro
//
//  Base cloud record types
//

import Foundation
import CloudKit

/// Base protocol for CloudKit records
protocol CloudRecordConvertible {
    var recordID: CKRecord.ID { get }
    var recordType: String { get }

    func toCKRecord() throws -> CKRecord
    static func from(_ record: CKRecord) throws -> Self
}

// MARK: - Cloud Photo

struct CloudPhoto: Codable, Identifiable {
    var id: UUID
    var fileName: String
    var width: Int
    var height: Int
    var fileSizeBytes: Int64
    var importedDate: Date
    var modifiedDate: Date
    var deviceID: String
    var fileData: Data?  // Optional - might be in asset
    var thumbnailData: Data?

    // CloudKit metadata
    var recordName: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        fileName: String,
        width: Int,
        height: Int,
        fileSizeBytes: Int64,
        importedDate: Date,
        modifiedDate: Date,
        deviceID: String,
        fileData: Data? = nil,
        thumbnailData: Data? = nil,
        recordName: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.fileSizeBytes = fileSizeBytes
        self.importedDate = importedDate
        self.modifiedDate = modifiedDate
        self.deviceID = deviceID
        self.fileData = fileData
        self.thumbnailData = thumbnailData
        self.recordName = recordName ?? "Photo-\(id.uuidString)"
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    static let recordType = "Photo"
}

extension CloudPhoto: CloudRecordConvertible {
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: recordName)
    }

    var recordType: String {
        Self.recordType
    }

    func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["fileName"] = fileName
        record["width"] = width
        record["height"] = height
        record["fileSizeBytes"] = fileSizeBytes
        record["importedDate"] = importedDate
        record["modifiedDate"] = modifiedDate
        record["deviceID"] = deviceID

        // Store file data as asset
        if let fileData = fileData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try fileData.write(to: tempURL)
            record["fileAsset"] = CKAsset(fileURL: tempURL)
        }

        // Store thumbnail as asset
        if let thumbnailData = thumbnailData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("thumb_\(id.uuidString).jpg")
            try thumbnailData.write(to: tempURL)
            record["thumbnailAsset"] = CKAsset(fileURL: tempURL)
        }

        return record
    }

    static func from(_ record: CKRecord) throws -> CloudPhoto {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let fileName = record["fileName"] as? String,
              let width = record["width"] as? Int,
              let height = record["height"] as? Int,
              let fileSizeBytes = record["fileSizeBytes"] as? Int64,
              let importedDate = record["importedDate"] as? Date,
              let modifiedDate = record["modifiedDate"] as? Date,
              let deviceID = record["deviceID"] as? String else {
            throw CloudSyncError.invalidRecord
        }

        var fileData: Data?
        if let asset = record["fileAsset"] as? CKAsset,
           let url = asset.fileURL {
            fileData = try? Data(contentsOf: url)
        }

        var thumbnailData: Data?
        if let asset = record["thumbnailAsset"] as? CKAsset,
           let url = asset.fileURL {
            thumbnailData = try? Data(contentsOf: url)
        }

        return CloudPhoto(
            id: id,
            fileName: fileName,
            width: width,
            height: height,
            fileSizeBytes: fileSizeBytes,
            importedDate: importedDate,
            modifiedDate: modifiedDate,
            deviceID: deviceID,
            fileData: fileData,
            thumbnailData: thumbnailData,
            recordName: record.recordID.recordName,
            createdAt: record.creationDate ?? Date(),
            modifiedAt: record.modificationDate ?? Date()
        )
    }
}

// MARK: - Cloud Edit Record

struct CloudEditRecord: Codable, Identifiable {
    var id: UUID
    var photoID: UUID
    var instructionsData: Data
    var historyIndex: Int
    var modifiedDate: Date
    var deviceID: String

    // CloudKit metadata
    var recordName: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        photoID: UUID,
        instructionsData: Data,
        historyIndex: Int,
        modifiedDate: Date,
        deviceID: String,
        recordName: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.photoID = photoID
        self.instructionsData = instructionsData
        self.historyIndex = historyIndex
        self.modifiedDate = modifiedDate
        self.deviceID = deviceID
        self.recordName = recordName ?? "EditRecord-\(id.uuidString)"
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    static let recordType = "EditRecord"
}

extension CloudEditRecord: CloudRecordConvertible {
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: recordName)
    }

    var recordType: String {
        Self.recordType
    }

    func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["photoID"] = photoID.uuidString
        record["instructionsData"] = instructionsData
        record["historyIndex"] = historyIndex
        record["modifiedDate"] = modifiedDate
        record["deviceID"] = deviceID

        return record
    }

    static func from(_ record: CKRecord) throws -> CloudEditRecord {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let photoIDString = record["photoID"] as? String,
              let photoID = UUID(uuidString: photoIDString),
              let instructionsData = record["instructionsData"] as? Data,
              let historyIndex = record["historyIndex"] as? Int,
              let modifiedDate = record["modifiedDate"] as? Date,
              let deviceID = record["deviceID"] as? String else {
            throw CloudSyncError.invalidRecord
        }

        return CloudEditRecord(
            id: id,
            photoID: photoID,
            instructionsData: instructionsData,
            historyIndex: historyIndex,
            modifiedDate: modifiedDate,
            deviceID: deviceID,
            recordName: record.recordID.recordName,
            createdAt: record.creationDate ?? Date(),
            modifiedAt: record.modificationDate ?? Date()
        )
    }
}

// MARK: - Cloud Preset

struct CloudPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var category: String
    var instructionsData: Data
    var author: String
    var presetDescription: String?
    var tags: [String]
    var isFavorite: Bool
    var isBuiltIn: Bool
    var createdDate: Date
    var modifiedDate: Date
    var deviceID: String

    // CloudKit metadata
    var recordName: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        name: String,
        category: String,
        instructionsData: Data,
        author: String,
        presetDescription: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        createdDate: Date,
        modifiedDate: Date,
        deviceID: String,
        recordName: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.instructionsData = instructionsData
        self.author = author
        self.presetDescription = presetDescription
        self.tags = tags
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.deviceID = deviceID
        self.recordName = recordName ?? "Preset-\(id.uuidString)"
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    static let recordType = "Preset"
}

extension CloudPreset: CloudRecordConvertible {
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: recordName)
    }

    var recordType: String {
        Self.recordType
    }

    func toCKRecord() throws -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["name"] = name
        record["category"] = category
        record["instructionsData"] = instructionsData
        record["author"] = author
        record["presetDescription"] = presetDescription
        record["tags"] = tags
        record["isFavorite"] = isFavorite ? 1 : 0
        record["isBuiltIn"] = isBuiltIn ? 1 : 0
        record["createdDate"] = createdDate
        record["modifiedDate"] = modifiedDate
        record["deviceID"] = deviceID

        return record
    }

    static func from(_ record: CKRecord) throws -> CloudPreset {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let category = record["category"] as? String,
              let instructionsData = record["instructionsData"] as? Data,
              let author = record["author"] as? String,
              let isFavoriteInt = record["isFavorite"] as? Int,
              let isBuiltInInt = record["isBuiltIn"] as? Int,
              let createdDate = record["createdDate"] as? Date,
              let modifiedDate = record["modifiedDate"] as? Date,
              let deviceID = record["deviceID"] as? String else {
            throw CloudSyncError.invalidRecord
        }

        let presetDescription = record["presetDescription"] as? String
        let tags = record["tags"] as? [String] ?? []

        return CloudPreset(
            id: id,
            name: name,
            category: category,
            instructionsData: instructionsData,
            author: author,
            presetDescription: presetDescription,
            tags: tags,
            isFavorite: isFavoriteInt == 1,
            isBuiltIn: isBuiltInInt == 1,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deviceID: deviceID,
            recordName: record.recordID.recordName,
            createdAt: record.creationDate ?? Date(),
            modifiedAt: record.modificationDate ?? Date()
        )
    }
}

// MARK: - Errors

enum CloudSyncError: Error, LocalizedError {
    case invalidRecord
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case conflictDetected
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Invalid CloudKit record format"
        case .notAuthenticated:
            return "Not signed in to iCloud"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .conflictDetected:
            return "Sync conflict detected"
        case .syncFailed:
            return "Sync operation failed"
        }
    }
}
