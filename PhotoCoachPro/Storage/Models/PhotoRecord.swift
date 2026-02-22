//
//  PhotoRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for photo records
//

import Foundation
import SwiftData

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

// MARK: - Convenience Extensions
extension PhotoRecord {
    enum PhotoSourceType {
        case photosLibrary
        case fileSystem
    }

    var resolvedSourceType: PhotoSourceType {
        sourceType == "photosLibrary" ? .photosLibrary : .fileSystem
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
