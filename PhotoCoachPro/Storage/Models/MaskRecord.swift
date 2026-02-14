//
//  MaskRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for mask storage
//

import Foundation
import SwiftData

@Model
final class MaskRecord {
    @Attribute(.unique) var id: UUID
    var photoID: UUID
    var createdDate: Date
    var modifiedDate: Date

    // Mask data (stored as Codable)
    @Attribute(.externalStorage) var maskLayerData: Data?

    // Relationship back to photo
    @Relationship(deleteRule: .nullify, inverse: \PhotoRecord.masks)
    var photo: PhotoRecord?

    // Computed property
    var maskLayer: MaskLayer? {
        get {
            guard let data = maskLayerData else { return nil }
            return try? JSONDecoder().decode(MaskLayer.self, from: data)
        }
        set {
            maskLayerData = try? JSONEncoder().encode(newValue)
            modifiedDate = Date()
        }
    }

    init(
        id: UUID = UUID(),
        photoID: UUID,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        maskLayer: MaskLayer? = nil
    ) {
        self.id = id
        self.photoID = photoID
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.maskLayer = maskLayer
    }
}
