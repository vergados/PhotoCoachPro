//
//  SkillHistoryRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for persisted skill history
//

import Foundation
import SwiftData

/// SwiftData wrapper for SkillHistory — one record per user (id == userID)
@Model
final class SkillHistoryRecord {
    @Attribute(.unique) var id: UUID        // userID — one record per user
    var createdAt: Date
    var lastUpdated: Date
    @Attribute(.externalStorage) var historyData: Data?

    var skillHistory: SkillHistory? {
        get {
            historyData.flatMap { try? JSONDecoder().decode(SkillHistory.self, from: $0) }
        }
        set {
            historyData = try? JSONEncoder().encode(newValue)
            lastUpdated = Date()
        }
    }

    init(id: UUID, createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.lastUpdated = createdAt
    }
}
