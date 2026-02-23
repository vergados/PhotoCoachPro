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
        // Draw radial gradient circles along the full stroke length so coverage is
        // continuous. Spacing at radius/2 ensures adjacent circles overlap and
        // eliminate the unfilled gap that appeared in the middle of long strokes.
        let radius = brushSize / 2
        let dx = to.x - start.x
        let dy = to.y - start.y
        let length = sqrt(dx * dx + dy * dy)

        // Step along the segment, stamping a gradient circle every half-radius.
        // Always include at least the start and end points.
        let step = max(radius / 2.0, 1.0)
        let stepCount = length > 0 ? Int((length / step).rounded(.up)) : 0

        for i in 0...stepCount {
            let t = stepCount > 0 ? CGFloat(i) / CGFloat(stepCount) : 0
            let center = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
    }

    // MARK: - Flood Fill

    /// Flood fill from point (magic wand) — 4-connected BFS in RGB space.
    ///
    /// Renders `sourceImage` to a raw RGBA8 buffer, samples the seed color at
    /// `point`, then grows outward through 4-connected neighbours whose RGB
    /// distance to the seed colour is within `tolerance` (0 = exact match,
    /// 1 = accept any colour).  The resulting fill region is blended into the
    /// existing mask using lighten compositing.
    func floodFill(
        mask: CIImage,
        sourceImage: CIImage,
        at point: CGPoint,
        tolerance: Double = 0.1
    ) async -> CIImage {
        let ext    = sourceImage.extent
        let width  = Int(ext.width)
        let height = Int(ext.height)
        guard width > 0, height > 0 else { return mask }

        // Normalise image to origin so pixel indices are contiguous
        let normalized = sourceImage.transformed(
            by: CGAffineTransform(translationX: -ext.minX, y: -ext.minY))

        // Render to RGBA8 pixel buffer
        let stride4    = width * 4
        var srcBytes   = [UInt8](repeating: 0, count: height * stride4)
        context.render(normalized,
                       toBitmap: &srcBytes,
                       rowBytes: stride4,
                       bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       format: .RGBA8,
                       colorSpace: nil)

        // Map tap point into buffer coordinates (clamp to valid range)
        let seedX = max(0, min(width  - 1, Int((point.x - ext.minX).rounded())))
        let seedY = max(0, min(height - 1, Int((point.y - ext.minY).rounded())))

        // Sample seed colour in 0–255 space
        let si    = (seedY * width + seedX) * 4
        let seedR = Double(srcBytes[si])
        let seedG = Double(srcBytes[si + 1])
        let seedB = Double(srcBytes[si + 2])

        // tolerance 0–1 maps to Euclidean distance 0–255√3 ≈ 441.67
        let maxDist = tolerance * 441.67
        let tolSq   = maxDist * maxDist

        // BFS — output single-channel mask (0 = not selected, 255 = selected)
        var outBytes = [UInt8](repeating: 0, count: width * height)
        var visited  = [Bool](repeating: false, count: width * height)

        var queue = [(Int, Int)]()
        queue.reserveCapacity(min(width * height, 131_072))
        queue.append((seedX, seedY))
        visited[seedY * width + seedX] = true

        var head = 0
        while head < queue.count {
            let (cx, cy) = queue[head]
            head += 1

            let pi = (cy * width + cx) * 4
            let dr = Double(srcBytes[pi])     - seedR
            let dg = Double(srcBytes[pi + 1]) - seedG
            let db = Double(srcBytes[pi + 2]) - seedB

            guard dr*dr + dg*dg + db*db <= tolSq else { continue }

            outBytes[cy * width + cx] = 255

            // 4-connected neighbours
            for (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)] {
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let ni = ny * width + nx
                if !visited[ni] {
                    visited[ni] = true
                    queue.append((nx, ny))
                }
            }
        }

        // Reconstruct fill region as a CIImage (grayscale → RGBA8).
        // Initialize to 0 (black = not selected) so any pixel the fill loop does not
        // reach defaults to "not selected" rather than the incorrect "selected" (255).
        var rgbaBytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<outBytes.count {
            let v = outBytes[i]
            rgbaBytes[i*4]     = v
            rgbaBytes[i*4 + 1] = v
            rgbaBytes[i*4 + 2] = v
            rgbaBytes[i*4 + 3] = 255
        }
        let fillImage = CIImage(
            bitmapData: Data(rgbaBytes),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: nil
        ).transformed(by: CGAffineTransform(translationX: ext.minX, y: ext.minY))

        // Blend fill into existing mask
        return mask.applyingFilter("CILightenBlendMode", parameters: [
            kCIInputBackgroundImageKey: mask,
            kCIInputImageKey: fillImage
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
