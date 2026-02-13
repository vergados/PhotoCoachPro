//
//  MaskRefinementBrush.swift
//  PhotoCoachPro
//
//  Manual brush-based mask editing
//

import Foundation
import CoreImage
import CoreGraphics

/// Brush tool for manual mask refinement
actor MaskRefinementBrush {
    private let context: CIContext

    // Brush settings
    var brushSize: Double = 50.0        // Pixels
    var brushHardness: Double = 0.8     // 0.0 (soft) to 1.0 (hard)
    var brushOpacity: Double = 1.0      // 0.0 to 1.0
    var brushMode: BrushMode = .paint   // Paint or erase

    enum BrushMode {
        case paint      // Add to mask (white)
        case erase      // Remove from mask (black)
    }

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    // MARK: - Stroke Operations

    /// Apply brush stroke to mask
    func applyStroke(
        to mask: CIImage,
        points: [CGPoint],
        mode: BrushMode? = nil
    ) async -> CIImage {
        guard points.count >= 2 else { return mask }

        let currentMode = mode ?? brushMode

        // Create stroke image
        let strokeImage = createStrokeImage(points: points, extent: mask.extent)

        // Composite stroke onto mask
        let compositedMask: CIImage

        switch currentMode {
        case .paint:
            // Add stroke (lighten)
            compositedMask = mask.applyingFilter("CILightenBlendMode", parameters: [
                kCIInputBackgroundImageKey: mask,
                kCIInputImageKey: strokeImage
            ])
        case .erase:
            // Subtract stroke (darken with inverted stroke)
            let invertedStroke = strokeImage.applyingFilter("CIColorInvert")
            compositedMask = mask.applyingFilter("CIDarkenBlendMode", parameters: [
                kCIInputBackgroundImageKey: mask,
                kCIInputImageKey: invertedStroke
            ])
        }

        return compositedMask
    }

    /// Apply single touch point (for tap-to-paint)
    func applyPoint(to mask: CIImage, at point: CGPoint, mode: BrushMode? = nil) async -> CIImage {
        await applyStroke(to: mask, points: [point, point], mode: mode)
    }

    // MARK: - Stroke Generation

    private func createStrokeImage(points: [CGPoint], extent: CGRect) -> CIImage {
        // Create graphics context
        let size = extent.size

        #if canImport(UIKit)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return CIImage(color: .clear).cropped(to: extent)
        }
        #elseif canImport(AppKit)
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return CIImage(color: .clear).cropped(to: extent)
        }
        #endif

        // Configure brush
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(brushSize)
        ctx.setAlpha(brushOpacity)

        // Create gradient for soft brush
        if brushHardness < 1.0 {
            // Soft brush with gradient
            let gradient = createBrushGradient(hardness: brushHardness)

            for i in 0..<points.count - 1 {
                let start = points[i]
                let end = points[i + 1]

                ctx.saveGState()
                ctx.addPath(createLinePath(from: start, to: end, width: brushSize))
                ctx.clip()

                // Draw gradient along stroke
                drawStrokeGradient(ctx: ctx, from: start, to: end, gradient: gradient)

                ctx.restoreGState()
            }
        } else {
            // Hard brush (solid)
            ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 1.0))

            ctx.beginPath()
            ctx.move(to: points[0])
            for point in points.dropFirst() {
                ctx.addLine(to: point)
            }
            ctx.strokePath()
        }

        #if canImport(UIKit)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else {
            return CIImage(color: .clear).cropped(to: extent)
        }
        #elseif canImport(AppKit)
        guard let cgImage = ctx.makeImage() else {
            return CIImage(color: .clear).cropped(to: extent)
        }
        #endif

        return CIImage(cgImage: cgImage)
    }

    private func createBrushGradient(hardness: Double) -> CGGradient {
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let locations: [CGFloat] = [0.0, CGFloat(hardness), 1.0]
        let components: [CGFloat] = [
            1.0, 1.0,  // Center: white
            1.0, 1.0,  // Hardness point: white
            1.0, 0.0   // Edge: transparent
        ]

        return CGGradient(
            colorSpace: colorSpace,
            colorComponents: components,
            locations: locations,
            count: 3
        )!
    }

    private func createLinePath(from start: CGPoint, to end: CGPoint, width: CGFloat) -> CGPath {
        let path = CGMutablePath()

        // Create capsule shape for stroke segment
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let radius = width / 2

        // Perpendicular offset
        let perpX = -sin(angle) * radius
        let perpY = cos(angle) * radius

        path.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
        path.addLine(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
        path.addArc(center: end, radius: radius, startAngle: angle + .pi / 2, endAngle: angle - .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
        path.addArc(center: start, radius: radius, startAngle: angle - .pi / 2, endAngle: angle + .pi / 2, clockwise: true)
        path.closeSubpath()

        return path
    }

    private func drawStrokeGradient(ctx: CGContext, from start: CGPoint, to: CGPoint, gradient: CGGradient) {
        // Draw radial gradients at start and end
        let radius = brushSize / 2

        ctx.drawRadialGradient(
            gradient,
            startCenter: start,
            startRadius: 0,
            endCenter: start,
            endRadius: radius,
            options: []
        )

        ctx.drawRadialGradient(
            gradient,
            startCenter: end,
            startRadius: 0,
            endCenter: end,
            endRadius: radius,
            options: []
        )
    }

    // MARK: - Flood Fill

    /// Flood fill from point (magic wand)
    func floodFill(
        mask: CIImage,
        sourceImage: CIImage,
        at point: CGPoint,
        tolerance: Double = 0.1
    ) async -> CIImage {
        // Simplified flood fill
        // Production version would use proper seed fill algorithm

        // Sample color at point
        let sampleRect = CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)

        // Create color-based mask
        let colorMask = sourceImage.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": tolerance
        ])

        // Combine with existing mask
        return mask.applyingFilter("CILightenBlendMode", parameters: [
            kCIInputBackgroundImageKey: mask,
            kCIInputImageKey: colorMask
        ])
    }
}

// MARK: - Brush Presets
extension MaskRefinementBrush {
    struct BrushPreset {
        let size: Double
        let hardness: Double
        let opacity: Double

        static let soft = BrushPreset(size: 100, hardness: 0.3, opacity: 0.8)
        static let medium = BrushPreset(size: 50, hardness: 0.7, opacity: 1.0)
        static let hard = BrushPreset(size: 30, hardness: 1.0, opacity: 1.0)
        static let eraser = BrushPreset(size: 80, hardness: 0.5, opacity: 1.0)
    }

    func applyPreset(_ preset: BrushPreset) {
        brushSize = preset.size
        brushHardness = preset.hardness
        brushOpacity = preset.opacity
    }
}
