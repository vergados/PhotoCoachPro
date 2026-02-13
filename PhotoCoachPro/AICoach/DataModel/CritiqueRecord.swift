//
//  CritiqueRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for critique persistence
//

import Foundation
import SwiftData

/// SwiftData model for persisting critique results
@Model
final class CritiqueRecord {
    @Attribute(.unique) var id: UUID
    var photoID: UUID
    var timestamp: Date

    // Overall scoring
    var overallScore: Double
    var overallRating: String
    var overallSummary: String

    // Category scores (stored as JSON)
    @Attribute(.externalStorage) var categoriesData: Data

    // Top improvements
    var topImprovements: [String]

    // Edit suggestions (stored as JSON)
    @Attribute(.externalStorage) var editGuidanceData: Data

    // Practice recommendation
    var practiceRecommendation: String?

    // Metadata
    var userNotes: String?
    var wasApplied: Bool
    var appliedAt: Date?

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \PhotoRecord.critiques)
    var photo: PhotoRecord?

    init(
        id: UUID = UUID(),
        photoID: UUID,
        timestamp: Date = Date(),
        overallScore: Double,
        overallRating: String,
        overallSummary: String,
        categoriesData: Data,
        topImprovements: [String],
        editGuidanceData: Data,
        practiceRecommendation: String? = nil,
        userNotes: String? = nil,
        wasApplied: Bool = false,
        appliedAt: Date? = nil
    ) {
        self.id = id
        self.photoID = photoID
        self.timestamp = timestamp
        self.overallScore = overallScore
        self.overallRating = overallRating
        self.overallSummary = overallSummary
        self.categoriesData = categoriesData
        self.topImprovements = topImprovements
        self.editGuidanceData = editGuidanceData
        self.practiceRecommendation = practiceRecommendation
        self.userNotes = userNotes
        self.wasApplied = wasApplied
        self.appliedAt = appliedAt
    }

    // MARK: - Conversion

    /// Create CritiqueRecord from CritiqueResult
    static func from(_ result: CritiqueResult) throws -> CritiqueRecord {
        let encoder = JSONEncoder()

        let categoriesData = try encoder.encode(result.categories)
        let editGuidanceData = try encoder.encode(result.editGuidance)

        return CritiqueRecord(
            id: result.id,
            photoID: result.photoID,
            timestamp: result.timestamp,
            overallScore: result.overallScore,
            overallRating: result.overallRating.rawValue,
            overallSummary: result.overallSummary,
            categoriesData: categoriesData,
            topImprovements: result.topImprovements,
            editGuidanceData: editGuidanceData,
            practiceRecommendation: result.practiceRecommendation
        )
    }

    /// Convert to CritiqueResult
    func toCritiqueResult() throws -> CritiqueResult {
        let decoder = JSONDecoder()

        let categories = try decoder.decode(CritiqueResult.CategoryBreakdown.self, from: categoriesData)
        let editGuidance = try decoder.decode([CritiqueResult.EditSuggestion].self, from: editGuidanceData)

        guard let rating = CritiqueResult.OverallRating(rawValue: overallRating) else {
            throw CritiqueError.invalidRating
        }

        return CritiqueResult(
            id: id,
            photoID: photoID,
            timestamp: timestamp,
            overallScore: overallScore,
            overallRating: rating,
            overallSummary: overallSummary,
            categories: categories,
            topImprovements: topImprovements,
            editGuidance: editGuidance,
            practiceRecommendation: practiceRecommendation
        )
    }
}

// MARK: - PhotoRecord Extension

extension PhotoRecord {
    @Relationship(deleteRule: .cascade)
    var critiques: [CritiqueRecord]? {
        get { nil }  // Managed by SwiftData
        set { }
    }

    /// Get most recent critique
    var latestCritique: CritiqueRecord? {
        critiques?.sorted { $0.timestamp > $1.timestamp }.first
    }

    /// Get all critiques sorted by date
    var sortedCritiques: [CritiqueRecord] {
        critiques?.sorted { $0.timestamp > $1.timestamp } ?? []
    }
}

// MARK: - Errors

enum CritiqueError: Error, LocalizedError {
    case invalidRating
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidRating:
            return "Invalid critique rating value"
        case .encodingFailed:
            return "Failed to encode critique data"
        case .decodingFailed:
            return "Failed to decode critique data"
        }
    }
}
