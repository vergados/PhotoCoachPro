//
//  ColorAnalyzer.swift
//  PhotoCoachPro
//
//  Analyzes color harmony and white balance
//

import Foundation
import CoreImage

/// Analyzes color quality and harmony
actor ColorAnalyzer {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func analyze(_ image: CIImage) async throws -> CritiqueResult.CategoryScore {
        var score: Double = 0.5
        var issues: [String] = []
        var strengths: [String] = []

        // Analyze saturation
        let saturationScore = analyzeSaturation(image)
        score += saturationScore * 0.3

        if saturationScore < 0.4 {
            issues.append("Colors are muted")
        } else if saturationScore > 0.8 {
            strengths.append("Vibrant colors")
        }

        // Analyze white balance
        let wbScore = analyzeWhiteBalance(image)
        score += wbScore * 0.4

        if wbScore < 0.5 {
            issues.append("Color cast detected")
        } else if wbScore > 0.8 {
            strengths.append("Accurate white balance")
        }

        // Analyze color harmony
        let harmonyScore = analyzeColorHarmony(image)
        score += harmonyScore * 0.3

        if harmonyScore > 0.7 {
            strengths.append("Good color harmony")
        }

        score = max(0, min(1, score))

        let notes = generateNotes(score: score, saturationScore: saturationScore, wbScore: wbScore)

        return CritiqueResult.CategoryScore(
            score: score,
            notes: notes,
            detectedIssues: issues,
            strengths: strengths
        )
    }

    // MARK: - Saturation Analysis

    private func analyzeSaturation(_ image: CIImage) -> Double {
        // Calculate average saturation
        let avgSaturation = calculateAverageSaturation(image)

        // Ideal saturation: 0.3-0.6
        if avgSaturation >= 0.3 && avgSaturation <= 0.6 {
            return 1.0
        } else if avgSaturation < 0.2 {
            return 0.4  // Too muted
        } else if avgSaturation > 0.8 {
            return 0.5  // Oversaturated
        } else {
            return 0.7
        }
    }

    private func calculateAverageSaturation(_ image: CIImage) -> Double {
        // Convert to HSV and measure S channel
        let hsvImage = image.applyingFilter("CIHueAdjust", parameters: [:])

        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        areaAverage.setValue(hsvImage, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaAverage.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // Approximate saturation from RGB variance
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        let maxC = max(r, g, b)
        let minC = min(r, g, b)

        let saturation = maxC > 0 ? (maxC - minC) / maxC : 0

        return saturation
    }

    // MARK: - White Balance Analysis

    private func analyzeWhiteBalance(_ image: CIImage) -> Double {
        // Analyze color cast by checking RGB balance
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        areaAverage.setValue(image, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = areaAverage.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0])
        let g = Double(bitmap[1])
        let b = Double(bitmap[2])

        // Calculate color cast
        let avg = (r + g + b) / 3.0
        let rDiff = abs(r - avg) / avg
        let gDiff = abs(g - avg) / avg
        let bDiff = abs(b - avg) / avg

        let maxDiff = max(rDiff, gDiff, bDiff)

        // Good white balance: less than 10% deviation
        if maxDiff < 0.05 {
            return 1.0  // Excellent
        } else if maxDiff < 0.10 {
            return 0.8  // Good
        } else if maxDiff < 0.20 {
            return 0.6  // Fair
        } else {
            return 0.3  // Poor (strong color cast)
        }
    }

    // MARK: - Color Harmony

    private func analyzeColorHarmony(_ image: CIImage) -> Double {
        // Simplified: good harmony = limited color palette
        // Analyze color distribution

        // For now, return neutral score
        // Production version would analyze color wheel distribution
        return 0.7
    }

    private func generateNotes(score: Double, saturationScore: Double, wbScore: Double) -> String {
        var notes = ""

        if score > 0.8 {
            notes = "Excellent color rendition. "
        } else if score > 0.6 {
            notes = "Good color quality. "
        } else {
            notes = "Colors need adjustment. "
        }

        if saturationScore < 0.5 {
            notes += "Colors appear muted or dull. "
        } else if saturationScore > 0.8 {
            notes += "Vibrant, punchy colors. "
        }

        if wbScore < 0.6 {
            notes += "Color cast detected - adjust white balance. "
        } else if wbScore > 0.8 {
            notes += "Accurate white balance. "
        }

        return notes.trimmingCharacters(in: .whitespaces)
    }
}
