//
//  RAWSettingsRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for RAW processing settings
//

import Foundation
import SwiftData

@Model
final class RAWSettingsRecord {
    @Attribute(.unique) var id: UUID
    var photoID: UUID
    var createdDate: Date
    var modifiedDate: Date

    // RAW settings (stored as Codable)
    @Attribute(.externalStorage) var settingsData: Data?

    // Relationship back to photo
    var photo: PhotoRecord?

    // Computed property
    var settings: RAWSettings {
        get {
            guard let data = settingsData,
                  let decoded = try? JSONDecoder().decode(RAWSettings.self, from: data) else {
                return .default
            }
            return decoded
        }
        set {
            settingsData = try? JSONEncoder().encode(newValue)
            modifiedDate = Date()
        }
    }

    init(
        id: UUID = UUID(),
        photoID: UUID,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        settings: RAWSettings = .default
    ) {
        self.id = id
        self.photoID = photoID
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.settings = settings
    }
}
