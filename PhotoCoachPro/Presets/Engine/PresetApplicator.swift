//
//  PresetApplicator.swift
//  PhotoCoachPro
//
//  Applies presets to photos
//

import Foundation
import CoreImage

/// Applies presets to photos with various strategies
actor PresetApplicator {
    private let editGraphEngine: EditGraphEngine

    init(editGraphEngine: EditGraphEngine = EditGraphEngine()) {
        self.editGraphEngine = editGraphEngine
    }

    // MARK: - Application Modes

    enum ApplicationMode {
        case replace      // Replace all existing edits
        case append       // Add preset after existing edits
        case merge        // Intelligently merge with existing edits
    }

    // MARK: - Apply Preset

    /// Apply preset to edit record
    func apply(
        _ preset: Preset,
        to editRecord: inout EditRecord,
        mode: ApplicationMode = .replace,
        strength: Double = 1.0
    ) {
        let instructions = adjustedInstructions(preset.instructions, strength: strength)

        switch mode {
        case .replace:
            editRecord.editStack = EditStack(instructions: instructions)

        case .append:
            var combined = editRecord.editStack.activeInstructions
            combined.append(contentsOf: instructions)
            editRecord.editStack = EditStack(instructions: combined)

        case .merge:
            mergeInstructions(instructions, into: &editRecord)
        }
    }

    /// Apply preset and render preview
    func applyAndRender(
        _ preset: Preset,
        to source: CIImage,
        strength: Double = 1.0
    ) async -> CIImage {
        let instructions = adjustedInstructions(preset.instructions, strength: strength)
        return await editGraphEngine.render(source: source, instructions: instructions)
    }

    /// Apply preset with before/after comparison
    func applyWithComparison(
        _ preset: Preset,
        to source: CIImage,
        existingInstructions: [EditInstruction],
        strength: Double = 1.0
    ) async -> (before: CIImage, after: CIImage) {
        let before = await editGraphEngine.render(source: source, instructions: existingInstructions)

        let presetInstructions = adjustedInstructions(preset.instructions, strength: strength)
        let combined = existingInstructions + presetInstructions
        let after = await editGraphEngine.render(source: source, instructions: combined)

        return (before, after)
    }

    // MARK: - Strength Adjustment

    /// Adjust preset instructions by strength (0.0 to 1.0)
    private func adjustedInstructions(_ instructions: [EditInstruction], strength: Double) -> [EditInstruction] {
        let clampedStrength = max(0.0, min(1.0, strength))

        return instructions.map { instruction in
            var adjusted = instruction
            adjusted.value *= clampedStrength
            adjusted.timestamp = Date()
            return adjusted
        }
    }

    // MARK: - Intelligent Merging

    /// Merge preset instructions with existing edits
    private func mergeInstructions(_ presetInstructions: [EditInstruction], into editRecord: inout EditRecord) {
        var merged = editRecord.editStack.activeInstructions

        for presetInstruction in presetInstructions {
            // Check if this edit type already exists
            if let existingIndex = merged.firstIndex(where: { $0.type == presetInstruction.type }) {
                // Replace existing instruction
                merged[existingIndex] = presetInstruction
            } else {
                // Add new instruction
                merged.append(presetInstruction)
            }
        }

        editRecord.editStack = EditStack(instructions: merged)
    }

    // MARK: - Batch Application

    /// Apply preset to multiple photos
    func applyBatch(
        _ preset: Preset,
        to photos: [PhotoRecord],
        mode: ApplicationMode = .replace,
        strength: Double = 1.0,
        database: LocalDatabase
    ) async throws -> [PhotoRecord] {
        var updated: [PhotoRecord] = []

        for photo in photos {
            var editRecord = try await MainActor.run {
                try database.getOrCreateEditRecord(for: photo)
            }

            apply(preset, to: &editRecord, mode: mode, strength: strength)

            try await MainActor.run {
                try database.context.save()
            }

            updated.append(photo)
        }

        return updated
    }

    // MARK: - Preset Blending

    /// Blend two presets together
    func blend(
        _ preset1: Preset,
        _ preset2: Preset,
        ratio: Double  // 0.0 = all preset1, 1.0 = all preset2
    ) -> Preset {
        let clampedRatio = max(0.0, min(1.0, ratio))

        // Combine instructions from both presets
        var blendedInstructions: [EditInstruction] = []

        // Create map of instruction types
        var instructionMap: [EditInstruction.EditType: (first: EditInstruction?, second: EditInstruction?)] = [:]

        for instruction in preset1.instructions {
            instructionMap[instruction.type] = (instruction, nil)
        }

        for instruction in preset2.instructions {
            var current = instructionMap[instruction.type] ?? (nil, nil)
            current.second = instruction
            instructionMap[instruction.type] = current
        }

        // Blend values
        for (type, pair) in instructionMap {
            let value1 = pair.first?.value ?? 0.0
            let value2 = pair.second?.value ?? 0.0

            let blendedValue = value1 * (1.0 - clampedRatio) + value2 * clampedRatio

            blendedInstructions.append(EditInstruction(type: type, value: blendedValue))
        }

        return Preset(
            name: "Blended",
            category: preset1.category,
            instructions: blendedInstructions,
            description: "Blend of \(preset1.name) and \(preset2.name)"
        )
    }

    // MARK: - Auto-Adjust

    /// Auto-adjust preset strength based on image analysis
    func autoAdjustStrength(
        _ preset: Preset,
        for image: CIImage
    ) async -> Double {
        // Analyze image characteristics
        let brightness = await analyzeBrightness(image)
        let contrast = await analyzeContrast(image)

        // Adjust strength based on image
        var strength = 1.0

        // Reduce strength for already high-contrast images
        if preset.affectsContrast && contrast > 0.7 {
            strength *= 0.7
        }

        // Reduce strength for very bright or very dark images
        if preset.affectsExposure {
            if brightness > 0.8 || brightness < 0.2 {
                strength *= 0.8
            }
        }

        return max(0.5, min(1.0, strength))
    }

    // MARK: - Image Analysis

    private func analyzeBrightness(_ image: CIImage) async -> Double {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / (3.0 * 255.0)
    }

    private func analyzeContrast(_ image: CIImage) async -> Double {
        // Simplified contrast estimation using histogram variance
        guard let filter = CIFilter(name: "CIAreaHistogram") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(256, forKey: "inputCount")
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        let context = CIContext()
        var histogram = [Float](repeating: 0, count: 256)
        context.render(outputImage, toBitmap: &histogram, rowBytes: 256 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 256, height: 1), format: .Rf, colorSpace: nil)

        // Calculate variance as proxy for contrast
        let mean = histogram.reduce(0, +) / Float(histogram.count)
        let variance = histogram.map { pow($0 - mean, 2) }.reduce(0, +) / Float(histogram.count)

        // Normalize to 0-1 range
        return Double(min(1.0, sqrt(variance) / 10.0))
    }

    // MARK: - Preset Recommendations

    /// Recommend preset based on image analysis
    func recommendPreset(
        for image: CIImage,
        category: Preset.PresetCategory? = nil
    ) async -> Preset? {
        let brightness = await analyzeBrightness(image)
        let contrast = await analyzeContrast(image)

        // Simple recommendation logic
        var candidates = PresetLibrary.allBuiltIn

        if let category = category {
            candidates = candidates.filter { $0.category == category }
        }

        // Recommend based on image characteristics
        if brightness < 0.3 {
            // Dark image - suggest brightening presets
            return candidates.first { $0.name.contains("Natural") || $0.name.contains("Soft") }
        } else if brightness > 0.8 {
            // Bright image - suggest contrast presets
            return candidates.first { $0.name.contains("Dramatic") || $0.name.contains("Contrast") }
        } else if contrast < 0.3 {
            // Low contrast - suggest vivid presets
            return candidates.first { $0.name.contains("Vivid") || $0.name.contains("Pop") }
        } else {
            // Average image - suggest natural preset
            return candidates.first { $0.name.contains("Classic") || $0.name.contains("Natural") }
        }
    }
}
