//
//  BatchCorrectionSuggester.swift
//  PhotoCoachPro
//
//  Suggests and applies batch corrections
//

import Foundation
import CoreImage

/// Suggests batch corrections based on consistency analysis
actor BatchCorrectionSuggester {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    // MARK: - Generate Suggestions

    /// Generate batch correction suggestions
    func suggestCorrections(
        for report: ConsistencyReport,
        images: [(image: CIImage, photoID: UUID)]
    ) async -> [BatchCorrectionSuggestion] {
        var suggestions: [BatchCorrectionSuggestion] = []

        // Exposure correction
        if report.metrics.exposureConsistency.score < 0.7 {
            let exposureSuggestion = await suggestExposureCorrection(images: images, outliers: report.outliers)
            suggestions.append(exposureSuggestion)
        }

        // White balance correction
        if report.metrics.whiteBalanceConsistency.score < 0.7 {
            let wbSuggestion = await suggestWhiteBalanceCorrection(images: images)
            suggestions.append(wbSuggestion)
        }

        // Color correction
        if report.metrics.colorConsistency.score < 0.7 {
            let colorSuggestion = await suggestColorCorrection(images: images)
            suggestions.append(colorSuggestion)
        }

        return suggestions
    }

    // MARK: - Exposure Correction

    private func suggestExposureCorrection(
        images: [(image: CIImage, photoID: UUID)],
        outliers: [ConsistencyReport.OutlierPhoto]
    ) async -> BatchCorrectionSuggestion {
        // Calculate target exposure (use median to avoid outlier influence)
        var brightnesses: [(photoID: UUID, brightness: Double)] = []

        for item in images {
            let brightness = await calculateBrightness(item.image)
            brightnesses.append((item.photoID, brightness))
        }

        let sorted = brightnesses.sorted { $0.brightness < $1.brightness }
        guard !sorted.isEmpty else {
            return BatchCorrectionSuggestion(
                id: UUID(),
                category: "Exposure",
                description: "No images to correct",
                affectedPhotos: [],
                corrections: [:],
                estimatedImprovement: 0
            )
        }
        let medianBrightness = sorted[sorted.count / 2].brightness

        // Generate per-photo corrections
        var corrections: [UUID: EditInstruction] = [:]

        for item in brightnesses {
            let diff = medianBrightness - item.brightness
            if abs(diff) > 0.05 {  // Threshold for correction
                let exposureAdjustment = diff * 10.0  // Approximate EV conversion
                corrections[item.photoID] = EditInstruction(
                    type: .exposure,
                    value: exposureAdjustment
                )
            }
        }

        return BatchCorrectionSuggestion(
            id: UUID(),
            category: "Exposure",
            description: "Normalize exposure to median brightness",
            affectedPhotos: Array(corrections.keys),
            corrections: corrections,
            estimatedImprovement: 0.3
        )
    }

    private func calculateBrightness(_ image: CIImage) async -> Double {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)

        return Double(0.2126 * bitmap[0] + 0.7152 * bitmap[1] + 0.0722 * bitmap[2])
    }

    // MARK: - White Balance Correction

    private func suggestWhiteBalanceCorrection(
        images: [(image: CIImage, photoID: UUID)]
    ) async -> BatchCorrectionSuggestion {
        // Use first photo as reference (or allow user to select)
        guard let reference = images.first else {
            return BatchCorrectionSuggestion(
                id: UUID(),
                category: "White Balance",
                description: "No reference photo available",
                affectedPhotos: [],
                corrections: [:],
                estimatedImprovement: 0
            )
        }

        let referenceWB = await calculateColorBalance(reference.image)

        var corrections: [UUID: EditInstruction] = [:]

        let refCCT = estimateCCT(r: referenceWB.r, g: referenceWB.g, b: referenceWB.b)

        for item in images.dropFirst() {
            let wb = await calculateColorBalance(item.image)
            let itemCCT = estimateCCT(r: wb.r, g: wb.g, b: wb.b)

            // Kelvin difference: positive means reference is warmer (target needs cooling)
            let kelvinDiff = refCCT - itemCCT

            // EditEngine maps offset → targetTemp = 6500 + offset * 10, so offset = kelvinDiff / 10
            let tempOffset = kelvinDiff / 10.0

            if abs(tempOffset) > 5 {  // Skip negligible differences (<50K)
                corrections[item.photoID] = EditInstruction(
                    type: .temperature,
                    value: tempOffset
                )
            }
        }

        let refKelvin = Int(refCCT.rounded())
        return BatchCorrectionSuggestion(
            id: UUID(),
            category: "White Balance",
            description: "Match white balance to first photo (~\(refKelvin)K)",
            affectedPhotos: Array(corrections.keys),
            corrections: corrections,
            estimatedImprovement: 0.25
        )
    }

    /// Estimates correlated color temperature (Kelvin) from average R, G, B values (0–1).
    /// Uses the blue-to-red ratio as a proxy for position on the Planckian locus,
    /// calibrated so that balanced channels (R≈B) map to ~6500K (D65).
    /// Range is clamped to 1500K–15000K to handle extreme scenes.
    private func estimateCCT(r: Double, g: Double, b: Double) -> Double {
        guard r > 0, b > 0 else { return 6500 }
        // B/R > 1 → cooler (higher K); B/R < 1 → warmer (lower K)
        // Empirically: CCT ≈ 6500 * (B/R)^1.09 at D65, B/R ≈ 1.0
        let cct = 6500.0 * pow(b / r, 1.09)
        return max(1500, min(15000, cct))
    }

    private func calculateColorBalance(_ image: CIImage) async -> (r: Double, g: Double, b: Double) {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return (0, 0, 0) }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return (0, 0, 0) }

        var bitmap = [Float](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)

        return (
            r: Double(bitmap[0]),
            g: Double(bitmap[1]),
            b: Double(bitmap[2])
        )
    }

    // MARK: - Color Correction

    private func suggestColorCorrection(
        images: [(image: CIImage, photoID: UUID)]
    ) async -> BatchCorrectionSuggestion {
        // Suggest saturation normalization
        var corrections: [UUID: EditInstruction] = [:]

        // Calculate median saturation
        var saturations: [(photoID: UUID, saturation: Double)] = []

        for item in images {
            let saturation = calculateAverageSaturation(item.image)
            saturations.append((item.photoID, saturation))
        }

        let sorted = saturations.sorted { $0.saturation < $1.saturation }
        guard !sorted.isEmpty else {
            return BatchCorrectionSuggestion(
                id: UUID(),
                category: "Color",
                description: "No images to correct",
                affectedPhotos: [],
                corrections: [:],
                estimatedImprovement: 0
            )
        }
        let medianSaturation = sorted[sorted.count / 2].saturation

        for item in saturations {
            let diff = (medianSaturation - item.saturation) * 100.0

            if abs(diff) > 5.0 {
                corrections[item.photoID] = EditInstruction(
                    type: .vibrance,
                    value: diff
                )
            }
        }

        return BatchCorrectionSuggestion(
            id: UUID(),
            category: "Color",
            description: "Normalize color saturation",
            affectedPhotos: Array(corrections.keys),
            corrections: corrections,
            estimatedImprovement: 0.2
        )
    }

    private func calculateAverageSaturation(_ image: CIImage) -> Double {
        let sampleSize = 32
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return 0.3 }

        let toOrigin = CGAffineTransform(translationX: -ext.minX, y: -ext.minY)
        let scale = CGAffineTransform(
            scaleX: CGFloat(sampleSize) / ext.width,
            y: CGFloat(sampleSize) / ext.height
        )
        let sampled = image.transformed(by: toOrigin.concatenating(scale))

        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        context.render(
            sampled,
            toBitmap: &pixelData,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: nil
        )

        var total: Double = 0
        let n = sampleSize * sampleSize
        for i in 0..<n {
            let r = Double(pixelData[i * 4])     / 255.0
            let g = Double(pixelData[i * 4 + 1]) / 255.0
            let b = Double(pixelData[i * 4 + 2]) / 255.0
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            total += maxC > 0 ? (maxC - minC) / maxC : 0
        }
        return total / Double(n)
    }
}

// MARK: - Batch Correction Suggestion

struct BatchCorrectionSuggestion: Identifiable, Equatable {
    var id: UUID
    var category: String
    var description: String
    var affectedPhotos: [UUID]
    var corrections: [UUID: EditInstruction]  // Per-photo corrections
    var estimatedImprovement: Double  // 0.0 to 1.0

    static func == (lhs: BatchCorrectionSuggestion, rhs: BatchCorrectionSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}
