//
//  PresetLibrary.swift
//  PhotoCoachPro
//
//  Built-in preset templates
//

import Foundation

/// Library of built-in preset templates
struct PresetLibrary {

    // MARK: - Portrait Presets

    static let portraitNatural = Preset(
        name: "Natural Portrait",
        category: .portrait,
        instructions: [
            EditInstruction(type: .exposure, value: 0.2),
            EditInstruction(type: .shadows, value: 0.3),
            EditInstruction(type: .vibrance, value: 0.1),
            EditInstruction(type: .sharpness, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Soft, natural look perfect for portraits. Slightly brightens shadows and enhances skin tones.",
        tags: ["portrait", "natural", "soft"],
        isBuiltIn: true
    )

    static let portraitDramatic = Preset(
        name: "Dramatic Portrait",
        category: .portrait,
        instructions: [
            EditInstruction(type: .contrast, value: 0.4),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: -0.3),
            EditInstruction(type: .clarity, value: 0.3),
            EditInstruction(type: .saturation, value: -0.2)
        ],
        author: "Photo Coach Pro",
        description: "High contrast, moody look with deep shadows and crisp highlights.",
        tags: ["portrait", "dramatic", "moody", "contrast"],
        isBuiltIn: true
    )

    static let portraitGlow = Preset(
        name: "Portrait Glow",
        category: .portrait,
        instructions: [
            EditInstruction(type: .exposure, value: 0.3),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.4),
            EditInstruction(type: .clarity, value: -0.3),
            EditInstruction(type: .vibrance, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Soft, glowing effect ideal for beauty and lifestyle portraits.",
        tags: ["portrait", "glow", "soft", "beauty"],
        isBuiltIn: true
    )

    // MARK: - Landscape Presets

    static let landscapeVivid = Preset(
        name: "Vivid Landscape",
        category: .landscape,
        instructions: [
            EditInstruction(type: .vibrance, value: 0.5),
            EditInstruction(type: .saturation, value: 0.2),
            EditInstruction(type: .contrast, value: 0.3),
            EditInstruction(type: .clarity, value: 0.4),
            EditInstruction(type: .sharpness, value: 0.3)
        ],
        author: "Photo Coach Pro",
        description: "Punchy, saturated colors perfect for dramatic landscapes.",
        tags: ["landscape", "vivid", "saturated", "punchy"],
        isBuiltIn: true
    )

    static let landscapeMuted = Preset(
        name: "Muted Landscape",
        category: .landscape,
        instructions: [
            EditInstruction(type: .saturation, value: -0.3),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.2),
            EditInstruction(type: .clarity, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Subtle, desaturated look for a calm, serene mood.",
        tags: ["landscape", "muted", "calm", "desaturated"],
        isBuiltIn: true
    )

    static let landscapeGoldenHour = Preset(
        name: "Golden Hour",
        category: .landscape,
        instructions: [
            EditInstruction(type: .temperature, value: 800),
            EditInstruction(type: .exposure, value: 0.2),
            EditInstruction(type: .highlights, value: -0.3),
            EditInstruction(type: .shadows, value: 0.3),
            EditInstruction(type: .vibrance, value: 0.3)
        ],
        author: "Photo Coach Pro",
        description: "Warm, golden tones reminiscent of sunset and sunrise.",
        tags: ["landscape", "golden hour", "warm", "sunset"],
        isBuiltIn: true
    )

    // MARK: - Black & White Presets

    static let blackAndWhiteClassic = Preset(
        name: "Classic B&W",
        category: .blackAndWhite,
        instructions: [
            EditInstruction(type: .saturation, value: -1.0),
            EditInstruction(type: .contrast, value: 0.3),
            EditInstruction(type: .clarity, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Timeless black and white with balanced contrast.",
        tags: ["b&w", "classic", "timeless"],
        isBuiltIn: true
    )

    static let blackAndWhiteHighContrast = Preset(
        name: "High Contrast B&W",
        category: .blackAndWhite,
        instructions: [
            EditInstruction(type: .saturation, value: -1.0),
            EditInstruction(type: .contrast, value: 0.7),
            EditInstruction(type: .highlights, value: 0.2),
            EditInstruction(type: .shadows, value: -0.4),
            EditInstruction(type: .clarity, value: 0.4)
        ],
        author: "Photo Coach Pro",
        description: "Dramatic black and white with deep blacks and bright whites.",
        tags: ["b&w", "high contrast", "dramatic"],
        isBuiltIn: true
    )

    static let blackAndWhiteSoft = Preset(
        name: "Soft B&W",
        category: .blackAndWhite,
        instructions: [
            EditInstruction(type: .saturation, value: -1.0),
            EditInstruction(type: .contrast, value: -0.2),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.3),
            EditInstruction(type: .clarity, value: -0.2)
        ],
        author: "Photo Coach Pro",
        description: "Soft, low-contrast black and white for a gentle mood.",
        tags: ["b&w", "soft", "low contrast"],
        isBuiltIn: true
    )

    // MARK: - Film Presets

    static let filmKodachrome = Preset(
        name: "Kodachrome",
        category: .film,
        instructions: [
            EditInstruction(type: .temperature, value: 300),
            EditInstruction(type: .saturation, value: 0.4),
            EditInstruction(type: .contrast, value: 0.3),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Rich, saturated colors inspired by classic Kodachrome film.",
        tags: ["film", "kodachrome", "vintage", "saturated"],
        isBuiltIn: true
    )

    static let filmPortra = Preset(
        name: "Portra",
        category: .film,
        instructions: [
            EditInstruction(type: .temperature, value: 200),
            EditInstruction(type: .tint, value: 5),
            EditInstruction(type: .saturation, value: -0.1),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.3),
            EditInstruction(type: .clarity, value: -0.1)
        ],
        author: "Photo Coach Pro",
        description: "Soft, creamy tones inspired by Kodak Portra film stock.",
        tags: ["film", "portra", "soft", "creamy"],
        isBuiltIn: true
    )

    static let filmFuji = Preset(
        name: "Fuji Classic",
        category: .film,
        instructions: [
            EditInstruction(type: .temperature, value: -100),
            EditInstruction(type: .saturation, value: 0.2),
            EditInstruction(type: .contrast, value: 0.2),
            EditInstruction(type: .highlights, value: -0.1),
            EditInstruction(type: .shadows, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Cool, vibrant colors reminiscent of Fuji film.",
        tags: ["film", "fuji", "cool", "vibrant"],
        isBuiltIn: true
    )

    // MARK: - Vintage Presets

    static let vintage70s = Preset(
        name: "70s Fade",
        category: .vintage,
        instructions: [
            EditInstruction(type: .temperature, value: 500),
            EditInstruction(type: .saturation, value: -0.2),
            EditInstruction(type: .contrast, value: -0.3),
            EditInstruction(type: .highlights, value: -0.3),
            EditInstruction(type: .shadows, value: 0.4),
            EditInstruction(type: .clarity, value: -0.2)
        ],
        author: "Photo Coach Pro",
        description: "Faded, warm tones inspired by 1970s photography.",
        tags: ["vintage", "70s", "faded", "warm"],
        isBuiltIn: true
    )

    static let vintageSepia = Preset(
        name: "Sepia Tone",
        category: .vintage,
        instructions: [
            EditInstruction(type: .saturation, value: -0.8),
            EditInstruction(type: .temperature, value: 1200),
            EditInstruction(type: .contrast, value: -0.2),
            EditInstruction(type: .clarity, value: -0.1)
        ],
        author: "Photo Coach Pro",
        description: "Classic sepia tone for a nostalgic, antique look.",
        tags: ["vintage", "sepia", "antique", "nostalgic"],
        isBuiltIn: true
    )

    // MARK: - Street Presets

    static let streetGritty = Preset(
        name: "Gritty Street",
        category: .street,
        instructions: [
            EditInstruction(type: .contrast, value: 0.5),
            EditInstruction(type: .saturation, value: -0.3),
            EditInstruction(type: .clarity, value: 0.5),
            EditInstruction(type: .highlights, value: -0.3),
            EditInstruction(type: .shadows, value: -0.2),
            EditInstruction(type: .sharpness, value: 0.4)
        ],
        author: "Photo Coach Pro",
        description: "High contrast, gritty look perfect for urban street photography.",
        tags: ["street", "gritty", "urban", "contrast"],
        isBuiltIn: true
    )

    // MARK: - Dramatic Presets

    static let dramaticMoody = Preset(
        name: "Moody Dark",
        category: .dramatic,
        instructions: [
            EditInstruction(type: .exposure, value: -0.5),
            EditInstruction(type: .contrast, value: 0.6),
            EditInstruction(type: .highlights, value: -0.4),
            EditInstruction(type: .shadows, value: -0.5),
            EditInstruction(type: .saturation, value: -0.3),
            EditInstruction(type: .clarity, value: 0.3)
        ],
        author: "Photo Coach Pro",
        description: "Dark, moody atmosphere with crushed blacks and dramatic shadows.",
        tags: ["dramatic", "moody", "dark", "shadows"],
        isBuiltIn: true
    )

    // MARK: - Soft Presets

    static let softDreamy = Preset(
        name: "Dreamy Soft",
        category: .soft,
        instructions: [
            EditInstruction(type: .exposure, value: 0.3),
            EditInstruction(type: .highlights, value: -0.2),
            EditInstruction(type: .shadows, value: 0.4),
            EditInstruction(type: .clarity, value: -0.4),
            EditInstruction(type: .saturation, value: -0.1),
            EditInstruction(type: .vibrance, value: 0.2)
        ],
        author: "Photo Coach Pro",
        description: "Soft, dreamy look with reduced clarity and lifted shadows.",
        tags: ["soft", "dreamy", "ethereal"],
        isBuiltIn: true
    )

    // MARK: - Vibrant Presets

    static let vibrantPop = Preset(
        name: "Pop Color",
        category: .vibrant,
        instructions: [
            EditInstruction(type: .vibrance, value: 0.7),
            EditInstruction(type: .saturation, value: 0.3),
            EditInstruction(type: .contrast, value: 0.3),
            EditInstruction(type: .clarity, value: 0.3),
            EditInstruction(type: .sharpness, value: 0.3)
        ],
        author: "Photo Coach Pro",
        description: "Bold, punchy colors that really pop off the screen.",
        tags: ["vibrant", "pop", "saturated", "bold"],
        isBuiltIn: true
    )

    // MARK: - All Built-in Presets

    static let allBuiltIn: [Preset] = [
        // Portrait
        portraitNatural,
        portraitDramatic,
        portraitGlow,

        // Landscape
        landscapeVivid,
        landscapeMuted,
        landscapeGoldenHour,

        // Black & White
        blackAndWhiteClassic,
        blackAndWhiteHighContrast,
        blackAndWhiteSoft,

        // Film
        filmKodachrome,
        filmPortra,
        filmFuji,

        // Vintage
        vintage70s,
        vintageSepia,

        // Street
        streetGritty,

        // Dramatic
        dramaticMoody,

        // Soft
        softDreamy,

        // Vibrant
        vibrantPop
    ]

    // MARK: - Initialize Built-in Presets

    /// Install built-in presets to database
    static func installBuiltInPresets(manager: PresetManager) async throws {
        for preset in allBuiltIn {
            // Check if already exists
            if let existing = try await manager.fetch(id: preset.id) {
                // Skip if already installed
                continue
            }

            try await manager.save(preset)
        }
    }

    /// Get presets by category
    static func presets(for category: Preset.PresetCategory) -> [Preset] {
        allBuiltIn.filter { $0.category == category }
    }

    /// Get preset by name
    static func preset(named name: String) -> Preset? {
        allBuiltIn.first { $0.name == name }
    }
}
