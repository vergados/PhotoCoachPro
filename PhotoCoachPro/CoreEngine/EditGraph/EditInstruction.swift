//
//  EditInstruction.swift
//  PhotoCoachPro
//
//  Single parametric edit operation
//

import Foundation

/// Single parametric edit operation (Codable for persistence)
struct EditInstruction: Codable, Identifiable, Equatable {
    var id: UUID
    var type: EditType
    var value: Double
    var maskID: UUID?                  // nil = global, UUID = masked adjustment
    var timestamp: Date
    var metadata: [String: String]     // Additional data for complex edits

    init(
        id: UUID = UUID(),
        type: EditType,
        value: Double,
        maskID: UUID? = nil,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.maskID = maskID
        self.timestamp = timestamp
        self.metadata = metadata
    }

    enum EditType: String, Codable, CaseIterable {
        // Basic tone
        case exposure
        case contrast
        case highlights
        case shadows
        case whites
        case blacks

        // Color temperature
        case temperature
        case tint

        // Presence
        case texture
        case clarity
        case dehaze

        // Color
        case saturation
        case vibrance

        // Sharpening
        case sharpAmount
        case sharpRadius
        case sharpMasking

        // Noise reduction
        case noiseReduction
        case noiseDetail
        case colorNoiseReduction

        // Lens corrections
        case lensCorrection
        case perspectiveVertical
        case perspectiveHorizontal
        case distortion

        // Crop & geometry
        case cropX
        case cropY
        case cropWidth
        case cropHeight
        case cropRotation
        case straighten

        // Effects
        case vignetteAmount
        case vignetteMidpoint
        case vignetteRoundness
        case grainAmount
        case grainSize
        case grainRoughness

        // Advanced (require metadata)
        case toneCurveControlPoint     // metadata: {"index": "2", "x": "0.5", "y": "0.6"}
        case hslHue                    // metadata: {"channel": "red|orange|yellow|green|aqua|blue|purple|magenta"}
        case hslSaturation
        case hslLuminance

        var displayName: String {
            switch self {
            case .exposure: return "Exposure"
            case .contrast: return "Contrast"
            case .highlights: return "Highlights"
            case .shadows: return "Shadows"
            case .whites: return "Whites"
            case .blacks: return "Blacks"
            case .temperature: return "Temperature"
            case .tint: return "Tint"
            case .texture: return "Texture"
            case .clarity: return "Clarity"
            case .dehaze: return "Dehaze"
            case .saturation: return "Saturation"
            case .vibrance: return "Vibrance"
            case .sharpAmount: return "Sharpening"
            case .sharpRadius: return "Sharp Radius"
            case .sharpMasking: return "Sharp Masking"
            case .noiseReduction: return "Noise Reduction"
            case .noiseDetail: return "Noise Detail"
            case .colorNoiseReduction: return "Color NR"
            case .lensCorrection: return "Lens Correction"
            case .perspectiveVertical: return "Vertical"
            case .perspectiveHorizontal: return "Horizontal"
            case .distortion: return "Distortion"
            case .cropX: return "Crop X"
            case .cropY: return "Crop Y"
            case .cropWidth: return "Crop Width"
            case .cropHeight: return "Crop Height"
            case .cropRotation: return "Rotation"
            case .straighten: return "Straighten"
            case .vignetteAmount: return "Vignette"
            case .vignetteMidpoint: return "Vignette Mid"
            case .vignetteRoundness: return "Vignette Round"
            case .grainAmount: return "Grain"
            case .grainSize: return "Grain Size"
            case .grainRoughness: return "Grain Rough"
            case .toneCurveControlPoint: return "Tone Curve"
            case .hslHue: return "HSL Hue"
            case .hslSaturation: return "HSL Saturation"
            case .hslLuminance: return "HSL Luminance"
            }
        }

        var defaultValue: Double {
            switch self {
            case .exposure, .contrast, .highlights, .shadows, .whites, .blacks:
                return 0.0
            case .temperature, .tint:
                return 0.0
            case .texture, .clarity, .dehaze:
                return 0.0
            case .saturation:
                return 0.0
            case .vibrance:
                return 0.0
            case .sharpAmount, .sharpRadius, .sharpMasking:
                return 0.0
            case .noiseReduction, .noiseDetail, .colorNoiseReduction:
                return 0.0
            case .lensCorrection:
                return 0.0
            case .perspectiveVertical, .perspectiveHorizontal, .distortion:
                return 0.0
            case .cropX, .cropY:
                return 0.0
            case .cropWidth, .cropHeight:
                return 1.0
            case .cropRotation, .straighten:
                return 0.0
            case .vignetteAmount, .vignetteMidpoint, .vignetteRoundness:
                return 0.0
            case .grainAmount, .grainSize, .grainRoughness:
                return 0.0
            case .toneCurveControlPoint:
                return 0.5
            case .hslHue, .hslSaturation, .hslLuminance:
                return 0.0
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .exposure:
                return -5.0...5.0
            case .contrast:
                return -100...100
            case .highlights, .shadows:
                return -100...100
            case .whites, .blacks:
                return -100...100
            case .temperature:
                return -100...100  // Kelvin offset
            case .tint:
                return -100...100
            case .texture, .clarity, .dehaze:
                return -100...100
            case .saturation, .vibrance:
                return -100...100
            case .sharpAmount:
                return 0...150
            case .sharpRadius:
                return 0.5...3.0
            case .sharpMasking:
                return 0...100
            case .noiseReduction, .colorNoiseReduction:
                return 0...100
            case .noiseDetail:
                return 0...100
            case .lensCorrection:
                return 0...100
            case .perspectiveVertical, .perspectiveHorizontal:
                return -100...100
            case .distortion:
                return -100...100
            case .cropX, .cropY:
                return 0...1
            case .cropWidth, .cropHeight:
                return 0...1
            case .cropRotation:
                return -45...45
            case .straighten:
                return -10...10
            case .vignetteAmount:
                return -100...100
            case .vignetteMidpoint, .vignetteRoundness:
                return 0...100
            case .grainAmount, .grainSize, .grainRoughness:
                return 0...100
            case .toneCurveControlPoint:
                return 0...1
            case .hslHue:
                return -180...180
            case .hslSaturation, .hslLuminance:
                return -100...100
            }
        }
    }
}

// MARK: - Edit Categories
extension EditInstruction.EditType {
    enum Category {
        case tone
        case color
        case detail
        case geometry
        case effects

        var types: [EditInstruction.EditType] {
            switch self {
            case .tone:
                return [.exposure, .contrast, .highlights, .shadows, .whites, .blacks]
            case .color:
                return [.temperature, .tint, .saturation, .vibrance, .hslHue, .hslSaturation, .hslLuminance]
            case .detail:
                return [.texture, .clarity, .sharpAmount, .sharpRadius, .sharpMasking,
                       .noiseReduction, .noiseDetail, .colorNoiseReduction]
            case .geometry:
                return [.cropX, .cropY, .cropWidth, .cropHeight, .cropRotation, .straighten,
                       .lensCorrection, .perspectiveVertical, .perspectiveHorizontal, .distortion]
            case .effects:
                return [.dehaze, .vignetteAmount, .vignetteMidpoint, .vignetteRoundness,
                       .grainAmount, .grainSize, .grainRoughness]
            }
        }
    }
}
