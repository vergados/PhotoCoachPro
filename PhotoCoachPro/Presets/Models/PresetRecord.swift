//
//  PresetRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for preset persistence
//

import Foundation
import SwiftData

/// SwiftData model for persisting presets
@Model
final class PresetRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var author: String
    var presetDescription: String?
    var tags: [String]
    var isFavorite: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var modifiedAt: Date
    var usageCount: Int

    // Instructions stored as JSON
    @Attribute(.externalStorage) var instructionsData: Data

    // Optional thumbnail
    var thumbnailPath: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        author: String = "User",
        presetDescription: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        usageCount: Int = 0,
        instructionsData: Data,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.author = author
        self.presetDescription = presetDescription
        self.tags = tags
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.usageCount = usageCount
        self.instructionsData = instructionsData
        self.thumbnailPath = thumbnailPath
    }

    // MARK: - Conversion

    /// Create PresetRecord from Preset
    static func from(_ preset: Preset) throws -> PresetRecord {
        let encoder = JSONEncoder()
        let instructionsData = try encoder.encode(preset.instructions)

        return PresetRecord(
            id: preset.id,
            name: preset.name,
            category: preset.category.rawValue,
            author: preset.author,
            presetDescription: preset.description,
            tags: preset.tags,
            isFavorite: preset.isFavorite,
            isBuiltIn: preset.isBuiltIn,
            createdAt: preset.createdAt,
            modifiedAt: preset.modifiedAt,
            usageCount: preset.usageCount,
            instructionsData: instructionsData,
            thumbnailPath: preset.thumbnailPath
        )
    }

    /// Convert to Preset
    func toPreset() throws -> Preset {
        let decoder = JSONDecoder()
        let instructions = try decoder.decode([EditInstruction].self, from: instructionsData)

        guard let category = Preset.PresetCategory(rawValue: self.category) else {
            throw PresetError.invalidCategory
        }

        return Preset(
            id: id,
            name: name,
            category: category,
            instructions: instructions,
            thumbnailPath: thumbnailPath,
            author: author,
            description: presetDescription,
            tags: tags,
            isFavorite: isFavorite,
            isBuiltIn: isBuiltIn,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            usageCount: usageCount
        )
    }

    /// Update from Preset
    func update(from preset: Preset) throws {
        let encoder = JSONEncoder()

        self.name = preset.name
        self.category = preset.category.rawValue
        self.author = preset.author
        self.presetDescription = preset.description
        self.tags = preset.tags
        self.isFavorite = preset.isFavorite
        self.modifiedAt = preset.modifiedAt
        self.usageCount = preset.usageCount
        self.instructionsData = try encoder.encode(preset.instructions)
        self.thumbnailPath = preset.thumbnailPath
    }
}

// MARK: - Errors

enum PresetError: Error, LocalizedError {
    case invalidCategory
    case encodingFailed
    case decodingFailed
    case presetNotFound
    case duplicateName
    case importFailed

    var errorDescription: String? {
        switch self {
        case .invalidCategory:
            return "Invalid preset category"
        case .encodingFailed:
            return "Failed to encode preset data"
        case .decodingFailed:
            return "Failed to decode preset data"
        case .presetNotFound:
            return "Preset not found"
        case .duplicateName:
            return "A preset with this name already exists"
        case .importFailed:
            return "Failed to import preset"
        }
    }
}
