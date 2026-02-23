//
//  ImageRenderer.swift
//  PhotoCoachPro
//
//  Renders CIImage → CGImage → UIImage/NSImage for display
//

import Foundation
import CoreImage
import CoreGraphics

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

/// Renders CIImage to display-ready formats
actor ImageRenderer {
    private let context: CIContext
    private let colorSpaceManager: ColorSpaceManager

    init(
        context: CIContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!]),
        colorSpaceManager: ColorSpaceManager
    ) {
        self.context = context
        self.colorSpaceManager = colorSpaceManager
    }

    // MARK: - Render to CGImage

    func renderCGImage(from ciImage: CIImage) async -> CGImage? {
        let displaySpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpace(name: CGColorSpace.sRGB)!

        return context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: .RGBA8,
            colorSpace: displaySpace
        )
    }

    func renderCGImage(from ciImage: CIImage, colorSpace: CGColorSpace) async -> CGImage? {
        context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }

    // MARK: - Render to Platform Image

    func renderPlatformImage(from ciImage: CIImage) async -> PlatformImage? {
        guard let cgImage = await renderCGImage(from: ciImage) else {
            return nil
        }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    // MARK: - Render at Specific Size

    func renderScaled(
        from ciImage: CIImage,
        targetSize: CGSize,
        scale: CGFloat = 1.0
    ) async -> PlatformImage? {
        let extent = ciImage.extent
        let scaleX = (targetSize.width * scale) / extent.width
        let scaleY = (targetSize.height * scale) / extent.height
        let scaleFactor = min(scaleX, scaleY)

        let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = await renderCGImage(from: scaledImage) else {
            return nil
        }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        #elseif canImport(AppKit)
        let size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    // MARK: - Export Rendering

    /// Render for export with specific color space
    func renderForExport(
        from ciImage: CIImage,
        colorSpace: CGColorSpace,
        format: CIFormat = .RGBA16
    ) async -> CGImage? {
        context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: format,
            colorSpace: colorSpace
        )
    }

    /// Render to JPEG data
    func renderJPEG(
        from ciImage: CIImage,
        quality: Double = 0.9,
        colorSpace: CGColorSpace? = nil
    ) async -> Data? {
        let targetSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let cgImage = await renderForExport(from: ciImage, colorSpace: targetSpace, format: .RGBA8) else {
            return nil
        }

        #if canImport(UIKit)
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: quality)
        #elseif canImport(AppKit)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }

    /// Render to TIFF data (16-bit, lossless)
    func renderTIFF(from ciImage: CIImage, colorSpace: CGColorSpace? = nil) async -> Data? {
        let targetSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.adobeRGB1998)!
        return context.tiffRepresentation(
            of: ciImage,
            format: .RGBA16,
            colorSpace: targetSpace,
            options: [:]
        )
    }

    /// Render to HEIC data
    func renderHEIC(from ciImage: CIImage, quality: Double = 0.9, colorSpace: CGColorSpace? = nil) async -> Data? {
        let targetSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3)!
        return context.heifRepresentation(
            of: ciImage,
            format: .RGBA8,
            colorSpace: targetSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        )
    }

    /// Render to PNG data
    func renderPNG(from ciImage: CIImage, colorSpace: CGColorSpace? = nil) async -> Data? {
        let targetSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let cgImage = await renderForExport(from: ciImage, colorSpace: targetSpace, format: .RGBA8) else {
            return nil
        }

        #if canImport(UIKit)
        let image = UIImage(cgImage: cgImage)
        return image.pngData()
        #elseif canImport(AppKit)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }
}
