//
//  Preset.swift
//  PhotoCoachPro
//
//  Preset data model
//

import Foundation
import CoreImage

/// Represents a saved preset with edit instructions
struct Preset: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var category: PresetCategory
    var instructions: [EditInstruction]
    var thumbnailPath: String?
    var author: String
    var description: String?
    var tags: [String]
    var isFavorite: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var modifiedAt: Date
    var usageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: PresetCategory,
        instructions: [EditInstruction],
        thumbnailPath: String? = nil,
        author: String = "User",
        description: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.instructions = instructions
        self.thumbnailPath = thumbnailPath
        self.author = author
        self.description = description
        self.tags = tags
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.usageCount = usageCount
    }

    // MARK: - Category

    enum PresetCategory: String, Codable, CaseIterable {
        case portrait = "Portrait"
        case landscape = "Landscape"
        case street = "Street"
        case film = "Film"
        case blackAndWhite = "Black & White"
        case vintage = "Vintage"
        case dramatic = "Dramatic"
        case soft = "Soft"
        case vibrant = "Vibrant"
        case muted = "Muted"
        case creative = "Creative"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .portrait: return "person.fill"
            case .landscape: return "mountain.2.fill"
            case .street: return "building.2.fill"
            case .film: return "film.fill"
            case .blackAndWhite: return "circle.lefthalf.filled"
            case .vintage: return "camera.fill"
            case .dramatic: return "bolt.fill"
            case .soft: return "cloud.fill"
            case .vibrant: return "paintpalette.fill"
            case .muted: return "drop.fill"
            case .creative: return "sparkles"
            case .custom: return "folder.fill"
            }
        }

        var color: String {
            switch self {
            case .portrait: return "blue"
            case .landscape: return "green"
            case .street: return "gray"
            case .film: return "orange"
            case .blackAndWhite: return "black"
            case .vintage: return "brown"
            case .dramatic: return "red"
            case .soft: return "pink"
            case .vibrant: return "purple"
            case .muted: return "indigo"
            case .creative: return "cyan"
            case .custom: return "yellow"
            }
        }
    }

    // MARK: - Computed Properties

    var instructionCount: Int {
        instructions.count
    }

    var hasAdjustments: Bool {
        !instructions.isEmpty
    }

    var editTypes: [EditInstruction.EditType] {
        instructions.map { $0.type }
    }

    var affectsExposure: Bool {
        editTypes.contains { $0 == .exposure || $0 == .brightness }
    }

    var affectsColor: Bool {
        editTypes.contains { type in
            [.temperature, .tint, .saturation, .vibrance, .hue].contains(type)
        }
    }

    var affectsContrast: Bool {
        editTypes.contains { type in
            [.contrast, .highlights, .shadows, .blacks, .whites].contains(type)
        }
    }

    // MARK: - Methods

    /// Create preset from edit record
    static func from(editRecord: EditRecord, name: String, category: PresetCategory) -> Preset {
        Preset(
            name: name,
            category: category,
            instructions: editRecord.instructions
        )
    }

    /// Apply preset to edit record (replace all instructions)
    func applyTo(_ editRecord: inout EditRecord) {
        editRecord.instructions = instructions
    }

    /// Apply preset with strength (0.0 to 1.0)
    func applyTo(_ editRecord: inout EditRecord, strength: Double) {
        let scaledInstructions = instructions.map { instruction in
            var scaled = instruction
            scaled.value *= strength
            return scaled
        }
        editRecord.instructions = scaledInstructions
    }

    /// Merge preset with existing edits
    func mergeWith(_ editRecord: inout EditRecord) {
        // Add preset instructions after existing ones
        editRecord.instructions.append(contentsOf: instructions)
    }

    /// Increment usage count
    mutating func recordUsage() {
        usageCount += 1
        modifiedAt = Date()
    }

    /// Toggle favorite status
    mutating func toggleFavorite() {
        isFavorite.toggle()
        modifiedAt = Date()
    }

    /// Update metadata
    mutating func update(name: String? = nil, description: String? = nil, tags: [String]? = nil) {
        if let name = name { self.name = name }
        if let description = description { self.description = description }
        if let tags = tags { self.tags = tags }
        modifiedAt = Date()
    }

    // MARK: - Validation

    func validate() -> ValidationResult {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Preset name cannot be empty")
        }

        if instructions.isEmpty {
            errors.append("Preset must have at least one instruction")
        }

        // Check for duplicate instruction types (warn only)
        let duplicateTypes = Dictionary(grouping: instructions, by: { $0.type })
            .filter { $0.value.count > 1 }
            .map { $0.key }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: duplicateTypes.isEmpty ? [] : ["Preset contains duplicate edit types: \(duplicateTypes.map { $0.rawValue }.joined(separator: ", "))"]
        )
    }

    struct ValidationResult {
        var isValid: Bool
        var errors: [String]
        var warnings: [String]
    }

    // MARK: - Export/Import

    /// Export preset to JSON data
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Import preset from JSON data
    static func importFromJSON(_ data: Data) throws -> Preset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Preset.self, from: data)
    }

    /// Export to dictionary (for sharing)
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "category": category.rawValue,
            "instructions": instructions.map { instruction in
                [
                    "type": instruction.type.rawValue,
                    "value": instruction.value
                ]
            }
        ]

        if let description = description {
            dict["description"] = description
        }

        if !tags.isEmpty {
            dict["tags"] = tags
        }

        dict["author"] = author

        return dict
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Preset, rhs: Preset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preset Collection

struct PresetCollection: Codable {
    var name: String
    var presets: [Preset]
    var createdAt: Date
    var version: String

    init(name: String, presets: [Preset], version: String = "1.0") {
        self.name = name
        self.presets = presets
        self.createdAt = Date()
        self.version = version
    }

    /// Export collection to JSON
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Import collection from JSON
    static func importFromJSON(_ data: Data) throws -> PresetCollection {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PresetCollection.self, from: data)
    }
}
