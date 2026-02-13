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
        let context = CIContext()

        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / (3.0 * 255.0)
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

        for item in images.dropFirst() {
            let wb = await calculateColorBalance(item.image)

            // Calculate temperature difference (simplified)
            let tempDiff = (referenceWB.r - wb.r) * 100.0

            corrections[item.photoID] = EditInstruction(
                type: .temperature,
                value: tempDiff
            )
        }

        return BatchCorrectionSuggestion(
            id: UUID(),
            category: "White Balance",
            description: "Match white balance to first photo",
            affectedPhotos: Array(corrections.keys),
            corrections: corrections,
            estimatedImprovement: 0.25
        )
    }

    private func calculateColorBalance(_ image: CIImage) async -> (r: Double, g: Double, b: Double) {
        let context = CIContext()

        guard let filter = CIFilter(name: "CIAreaAverage") else { return (0, 0, 0) }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return (0, 0, 0) }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return (
            r: Double(bitmap[0]) / 255.0,
            g: Double(bitmap[1]) / 255.0,
            b: Double(bitmap[2]) / 255.0
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
            let wb = await calculateColorBalance(item.image)
            let maxC = max(wb.r, wb.g, wb.b)
            let minC = min(wb.r, wb.g, wb.b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0

            saturations.append((item.photoID, saturation))
        }

        let sorted = saturations.sorted { $0.saturation < $1.saturation }
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
