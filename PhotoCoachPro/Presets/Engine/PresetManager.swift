//
//  PresetManager.swift
//  PhotoCoachPro
//
//  Manages preset operations
//

import Foundation
import SwiftData

/// Manages preset storage and retrieval
actor PresetManager {
    private let database: LocalDatabase

    init(database: LocalDatabase = .shared) {
        self.database = database
    }

    // MARK: - Fetch Operations

    /// Fetch all presets
    func fetchAll() async throws -> [Preset] {
        let records = await database.fetchAllPresets()
        return try records.map { try $0.toPreset() }
    }

    /// Fetch preset by ID
    func fetch(id: UUID) async throws -> Preset? {
        guard let record = await database.fetchPreset(id: id) else {
            return nil
        }
        return try record.toPreset()
    }

    /// Fetch presets by category
    func fetch(category: Preset.PresetCategory) async throws -> [Preset] {
        let records = await database.fetchPresets(category: category.rawValue)
        return try records.map { try $0.toPreset() }
    }

    /// Fetch built-in presets
    func fetchBuiltIn() async throws -> [Preset] {
        let records = await database.fetchBuiltInPresets()
        return try records.map { try $0.toPreset() }
    }

    /// Fetch custom (user-created) presets
    func fetchCustom() async throws -> [Preset] {
        let records = await database.fetchCustomPresets()
        return try records.map { try $0.toPreset() }
    }

    /// Fetch favorite presets
    func fetchFavorites() async throws -> [Preset] {
        let records = await database.fetchFavoritePresets()
        return try records.map { try $0.toPreset() }
    }

    /// Fetch most used presets
    func fetchMostUsed(limit: Int = 10) async throws -> [Preset] {
        let records = await database.fetchMostUsedPresets(limit: limit)
        return try records.map { try $0.toPreset() }
    }

    /// Fetch recent presets
    func fetchRecent(limit: Int = 10) async throws -> [Preset] {
        let records = await database.fetchRecentPresets(limit: limit)
        return try records.map { try $0.toPreset() }
    }

    /// Search presets by name or tags
    func search(query: String) async throws -> [Preset] {
        let records = await database.searchPresets(query: query)
        return try records.map { try $0.toPreset() }
    }

    // MARK: - Save Operations

    /// Save new preset
    func save(_ preset: Preset) async throws {
        // Check for duplicate name
        let existing = await database.fetchPreset(name: preset.name)
        if existing != nil && existing?.id != preset.id {
            throw PresetError.duplicateName
        }

        let record = try PresetRecord.from(preset)
        try await database.savePreset(record)
    }

    /// Update existing preset
    func update(_ preset: Preset) async throws {
        guard let record = await database.fetchPreset(id: preset.id) else {
            throw PresetError.presetNotFound
        }

        try await MainActor.run {
            try record.update(from: preset)
        }

        try await database.context.save()
    }

    /// Delete preset
    func delete(_ preset: Preset) async throws {
        guard let record = await database.fetchPreset(id: preset.id) else {
            throw PresetError.presetNotFound
        }

        try await database.deletePreset(record)
    }

    /// Delete multiple presets
    func delete(_ presets: [Preset]) async throws {
        for preset in presets {
            try await delete(preset)
        }
    }

    // MARK: - Preset Operations

    /// Create preset from edit record
    func createFromEditRecord(
        _ editRecord: EditRecord,
        name: String,
        category: Preset.PresetCategory,
        description: String? = nil,
        tags: [String] = []
    ) async throws -> Preset {
        var preset = Preset.from(editRecord: editRecord, name: name, category: category)
        preset.description = description
        preset.tags = tags

        try await save(preset)
        return preset
    }

    /// Duplicate preset
    func duplicate(_ preset: Preset, newName: String? = nil) async throws -> Preset {
        var duplicated = preset
        duplicated.id = UUID()
        duplicated.name = newName ?? "\(preset.name) Copy"
        duplicated.isBuiltIn = false
        duplicated.createdAt = Date()
        duplicated.modifiedAt = Date()
        duplicated.usageCount = 0
        duplicated.isFavorite = false

        try await save(duplicated)
        return duplicated
    }

    /// Toggle favorite status
    func toggleFavorite(_ preset: Preset) async throws {
        var updated = preset
        updated.toggleFavorite()
        try await update(updated)
    }

    /// Record preset usage
    func recordUsage(_ preset: Preset) async throws {
        var updated = preset
        updated.recordUsage()
        try await update(updated)
    }

    // MARK: - Import/Export

    /// Export preset to file
    func exportPreset(_ preset: Preset, to url: URL) async throws {
        let data = try preset.exportToJSON()
        try data.write(to: url)
    }

    /// Export multiple presets as collection
    func exportCollection(_ presets: [Preset], name: String, to url: URL) async throws {
        let collection = PresetCollection(name: name, presets: presets)
        let data = try collection.exportToJSON()
        try data.write(to: url)
    }

    /// Import preset from file
    func importPreset(from url: URL) async throws -> Preset {
        let data = try Data(contentsOf: url)

        // Try single preset first
        if let preset = try? Preset.importFromJSON(data) {
            // Generate new ID to avoid conflicts
            var imported = preset
            imported.id = UUID()
            imported.isBuiltIn = false
            imported.createdAt = Date()
            imported.modifiedAt = Date()
            imported.usageCount = 0

            try await save(imported)
            return imported
        }

        // Try collection
        if let collection = try? PresetCollection.importFromJSON(data) {
            guard let first = collection.presets.first else {
                throw PresetError.importFailed
            }

            var imported = first
            imported.id = UUID()
            imported.isBuiltIn = false
            imported.createdAt = Date()
            imported.modifiedAt = Date()
            imported.usageCount = 0

            try await save(imported)
            return imported
        }

        throw PresetError.importFailed
    }

    /// Import collection from file
    func importCollection(from url: URL) async throws -> [Preset] {
        let data = try Data(contentsOf: url)
        let collection = try PresetCollection.importFromJSON(data)

        var imported: [Preset] = []

        for preset in collection.presets {
            var importedPreset = preset
            importedPreset.id = UUID()
            importedPreset.isBuiltIn = false
            importedPreset.createdAt = Date()
            importedPreset.modifiedAt = Date()
            importedPreset.usageCount = 0

            try await save(importedPreset)
            imported.append(importedPreset)
        }

        return imported
    }

    // MARK: - Bulk Operations

    /// Delete all custom presets
    func deleteAllCustom() async throws {
        let custom = try await fetchCustom()
        try await delete(custom)
    }

    /// Reset usage counts
    func resetUsageCounts() async throws {
        let presets = try await fetchAll()
        for preset in presets {
            var updated = preset
            updated.usageCount = 0
            try await update(updated)
        }
    }

    /// Get preset count
    func count() async -> Int {
        await database.totalPresetCount()
    }

    /// Get preset count by category
    func count(category: Preset.PresetCategory) async -> Int {
        await database.presetCount(category: category.rawValue)
    }
}
