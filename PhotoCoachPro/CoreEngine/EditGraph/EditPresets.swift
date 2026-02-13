//
//  EditPresets.swift
//  PhotoCoachPro
//
//  Copy/paste/batch-apply edit settings
//

import Foundation

/// Named preset containing edit instructions
struct EditPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var instructions: [EditInstruction]
    var category: PresetCategory
    var createdDate: Date
    var isUserCreated: Bool

    init(
        id: UUID = UUID(),
        name: String,
        instructions: [EditInstruction],
        category: PresetCategory = .custom,
        createdDate: Date = Date(),
        isUserCreated: Bool = true
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.category = category
        self.createdDate = createdDate
        self.isUserCreated = isUserCreated
    }

    enum PresetCategory: String, Codable, CaseIterable {
        case custom = "Custom"
        case portrait = "Portrait"
        case landscape = "Landscape"
        case blackAndWhite = "B&W"
        case cinematic = "Cinematic"
        case vibrant = "Vibrant"
        case muted = "Muted"
        case vintage = "Vintage"

        var displayName: String { rawValue }
    }
}

/// Manages preset library
actor EditPresetManager {
    private var presets: [EditPreset] = []

    init() {
        loadDefaultPresets()
    }

    // MARK: - Access

    func allPresets() -> [EditPreset] {
        presets
    }

    func presets(in category: EditPreset.PresetCategory) -> [EditPreset] {
        presets.filter { $0.category == category }
    }

    func preset(id: UUID) -> EditPreset? {
        presets.first { $0.id == id }
    }

    // MARK: - Mutations

    func save(_ preset: EditPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        // TODO: Persist to disk
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id && $0.isUserCreated }
    }

    // MARK: - Clipboard Operations

    private var clipboard: [EditInstruction]?

    func copy(instructions: [EditInstruction]) {
        clipboard = instructions
    }

    func paste() -> [EditInstruction]? {
        clipboard
    }

    var hasClipboard: Bool {
        clipboard != nil
    }

    // MARK: - Default Presets

    private func loadDefaultPresets() {
        // Portrait preset
        presets.append(EditPreset(
            name: "Natural Portrait",
            instructions: [
                EditInstruction(type: .exposure, value: 0.3),
                EditInstruction(type: .shadows, value: 15),
                EditInstruction(type: .texture, value: -10),
                EditInstruction(type: .clarity, value: -5),
                EditInstruction(type: .saturation, value: -5),
                EditInstruction(type: .sharpAmount, value: 40)
            ],
            category: .portrait,
            isUserCreated: false
        ))

        // Landscape preset
        presets.append(EditPreset(
            name: "Vivid Landscape",
            instructions: [
                EditInstruction(type: .contrast, value: 15),
                EditInstruction(type: .clarity, value: 20),
                EditInstruction(type: .vibrance, value: 30),
                EditInstruction(type: .saturation, value: 10),
                EditInstruction(type: .sharpAmount, value: 60)
            ],
            category: .landscape,
            isUserCreated: false
        ))

        // B&W preset
        presets.append(EditPreset(
            name: "Classic B&W",
            instructions: [
                EditInstruction(type: .saturation, value: -100),
                EditInstruction(type: .contrast, value: 25),
                EditInstruction(type: .clarity, value: 15),
                EditInstruction(type: .blacks, value: -10),
                EditInstruction(type: .vignetteAmount, value: -20)
            ],
            category: .blackAndWhite,
            isUserCreated: false
        ))
    }
}
