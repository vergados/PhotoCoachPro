//
//  PhotoRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for photo records
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.photocoachpro", category: "PhotoRecord")

@Model
final class PhotoRecord {
    @Attribute(.unique) var id: UUID
    var filePath: String
    var assetIdentifier: String?
    var sourceType: String?      // "photosLibrary" | "fileSystem" | nil (legacy = fileSystem)
    var bookmarkData: Data?      // security-scoped bookmark for file-system imports
    var fileName: String
    var createdDate: Date
    var importedDate: Date
    var width: Int
    var height: Int
    var fileFormat: String
    var fileSizeBytes: Int64

    // User-managed flags
    var isFavorite: Bool = false

    // Metadata (stored as Codable)
    @Attribute(.externalStorage) var exifSnapshotData: Data?

    // Edit relationships
    @Relationship(deleteRule: .cascade) var editRecord: EditRecord?
    @Relationship(deleteRule: .cascade) var masks: [MaskRecord] = []
    @Relationship(deleteRule: .cascade) var rawSettings: RAWSettingsRecord?
    @Relationship(deleteRule: .cascade) var critiques: [CritiqueRecord] = []

    // Computed properties
    var exifSnapshot: EXIFData? {
        get {
            guard let data = exifSnapshotData else { return nil }
            return try? JSONDecoder().decode(EXIFData.self, from: data)
        }
        set {
            exifSnapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        filePath: String,
        assetIdentifier: String? = nil,
        fileName: String,
        createdDate: Date = Date(),
        importedDate: Date = Date(),
        width: Int,
        height: Int,
        fileFormat: String,
        fileSizeBytes: Int64,
        exifSnapshot: EXIFData? = nil,
        sourceType: String? = nil,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.assetIdentifier = assetIdentifier
        self.sourceType = sourceType
        self.bookmarkData = bookmarkData
        self.fileName = fileName
        self.createdDate = createdDate
        self.importedDate = importedDate
        self.width = width
        self.height = height
        self.fileFormat = fileFormat
        self.fileSizeBytes = fileSizeBytes
        self.exifSnapshot = exifSnapshot
    }
}

// MARK: - Critique Helpers
extension PhotoRecord {
    /// Get most recent critique
    var latestCritique: CritiqueRecord? {
        critiques.sorted { $0.timestamp > $1.timestamp }.first
    }

    /// Get all critiques sorted by date
    var sortedCritiques: [CritiqueRecord] {
        critiques.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Convenience Extensions
extension PhotoRecord {
    enum PhotoSourceType {
        case photosLibrary
        case fileSystem
    }

    var resolvedSourceType: PhotoSourceType {
        switch sourceType {
        case "photosLibrary": return .photosLibrary
        case "fileSystem", nil: return .fileSystem
        default:
            // Unknown sourceType — log and default to fileSystem to avoid a crash.
            // The ternary operator previously mapped ALL non-"photosLibrary" values
            // (including future source types like "cloudStorage") silently to .fileSystem.
            logger.warning("Unknown sourceType '\(self.sourceType ?? "unknown")' for photo \(self.id), defaulting to .fileSystem")
            return .fileSystem
        }
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var fileSizeMB: Double {
        Double(fileSizeBytes) / 1_048_576.0
    }

    var isRAW: Bool {
        RAWFormat.isRAWFormat(fileFormat)
    }

    var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }
}
