//
//  LocalDatabase.swift
//  PhotoCoachPro
//
//  SwiftData container setup and database management
//

import Foundation
import SwiftData

/// Manages SwiftData model container and context
@MainActor
class LocalDatabase: ObservableObject {
    static let shared = LocalDatabase()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([
            PhotoRecord.self,
            EditRecord.self,
            MaskRecord.self,
            RAWSettingsRecord.self,
            CritiqueRecord.self,
            PresetRecord.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Photo Operations

    func fetchAllPhotos() -> [PhotoRecord] {
        let descriptor = FetchDescriptor<PhotoRecord>(
            sortBy: [SortDescriptor(\.importedDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchRecentPhotos(limit: Int = 20) -> [PhotoRecord] {
        var descriptor = FetchDescriptor<PhotoRecord>(
            sortBy: [SortDescriptor(\.importedDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchPhoto(id: UUID) -> PhotoRecord? {
        let descriptor = FetchDescriptor<PhotoRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    func savePhoto(_ photo: PhotoRecord) throws {
        context.insert(photo)
        try context.save()
    }

    func deletePhoto(_ photo: PhotoRecord) throws {
        context.delete(photo)
        try context.save()
    }

    // MARK: - Edit Operations

    func fetchEditRecord(for photoID: UUID) -> EditRecord? {
        let descriptor = FetchDescriptor<EditRecord>(
            predicate: #Predicate { $0.photoID == photoID }
        )
        return try? context.fetch(descriptor).first
    }

    func saveEditRecord(_ record: EditRecord) throws {
        context.insert(record)
        try context.save()
    }

    func getOrCreateEditRecord(for photo: PhotoRecord) throws -> EditRecord {
        if let existing = fetchEditRecord(for: photo.id) {
            return existing
        }

        let newRecord = EditRecord(photoID: photo.id)
        newRecord.photo = photo
        photo.editRecord = newRecord
        try saveEditRecord(newRecord)
        return newRecord
    }

    // MARK: - Batch Operations

    func deleteAllPhotos() throws {
        let photos = fetchAllPhotos()
        for photo in photos {
            context.delete(photo)
        }
        try context.save()
    }

    // MARK: - Search

    func searchPhotos(query: String) -> [PhotoRecord] {
        let lowercased = query.lowercased()
        let descriptor = FetchDescriptor<PhotoRecord>(
            predicate: #Predicate { photo in
                photo.fileName.lowercased().contains(lowercased)
            },
            sortBy: [SortDescriptor(\.importedDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Critique Operations

    func fetchCritique(id: UUID) -> CritiqueRecord? {
        let descriptor = FetchDescriptor<CritiqueRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    func fetchCritiques(for photoID: UUID) -> [CritiqueRecord] {
        let descriptor = FetchDescriptor<CritiqueRecord>(
            predicate: #Predicate { $0.photoID == photoID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchAllCritiques() -> [CritiqueRecord] {
        let descriptor = FetchDescriptor<CritiqueRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveCritique(_ critique: CritiqueRecord) throws {
        context.insert(critique)
        try context.save()
    }

    func deleteCritique(_ critique: CritiqueRecord) throws {
        context.delete(critique)
        try context.save()
    }

    // MARK: - Preset Operations

    func fetchPreset(id: UUID) -> PresetRecord? {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    func fetchPreset(name: String) -> PresetRecord? {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.name == name }
        )
        return try? context.fetch(descriptor).first
    }

    func fetchAllPresets() -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchPresets(category: String) -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.category == category },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchBuiltInPresets() -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.isBuiltIn == true },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchCustomPresets() -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.isBuiltIn == false },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchFavoritePresets() -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchMostUsedPresets(limit: Int) -> [PresetRecord] {
        var descriptor = FetchDescriptor<PresetRecord>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchRecentPresets(limit: Int) -> [PresetRecord] {
        var descriptor = FetchDescriptor<PresetRecord>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func searchPresets(query: String) -> [PresetRecord] {
        let lowercased = query.lowercased()
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { preset in
                preset.name.lowercased().contains(lowercased)
            },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func savePreset(_ preset: PresetRecord) throws {
        context.insert(preset)
        try context.save()
    }

    func deletePreset(_ preset: PresetRecord) throws {
        context.delete(preset)
        try context.save()
    }

    // MARK: - Statistics

    func totalPhotoCount() -> Int {
        let descriptor = FetchDescriptor<PhotoRecord>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func totalStorageSize() -> Int64 {
        let photos = fetchAllPhotos()
        return photos.reduce(0) { $0 + $1.fileSizeBytes }
    }

    func totalCritiqueCount() -> Int {
        let descriptor = FetchDescriptor<CritiqueRecord>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func totalPresetCount() -> Int {
        let descriptor = FetchDescriptor<PresetRecord>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func presetCount(category: String) -> Int {
        let descriptor = FetchDescriptor<PresetRecord>(
            predicate: #Predicate { $0.category == category }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
