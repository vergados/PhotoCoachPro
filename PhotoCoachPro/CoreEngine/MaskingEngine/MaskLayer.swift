//
//  MaskLayer.swift
//  PhotoCoachPro
//
//  Mask data model with bitmap + feathering
//

import Foundation
import CoreImage
import CoreGraphics

/// Mask layer for selective adjustments
struct MaskLayer: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var type: MaskType
    var featherRadius: Double           // Pixels
    var opacity: Double                 // 0.0 to 1.0
    var inverted: Bool
    var enabled: Bool

    // Bitmap data (stored as PNG data when codable)
    @IgnoredCodable var maskImage: CIImage?

    // For Codable persistence
    private var maskImageData: Data?

    enum MaskType: String, Codable {
        case subject = "Subject"          // Auto-detected subject
        case sky = "Sky"                  // Auto-detected sky
        case background = "Background"    // Auto-detected background
        case brushed = "Brushed"          // Manual brush
        case gradient = "Gradient"        // Linear/radial gradient
        case color = "Color Range"        // Color-based selection
        case luminance = "Luminance"      // Brightness-based selection
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: MaskType,
        maskImage: CIImage? = nil,
        featherRadius: Double = 5.0,
        opacity: Double = 1.0,
        inverted: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.maskImage = maskImage
        self.featherRadius = featherRadius
        self.opacity = opacity
        self.inverted = inverted
        self.enabled = enabled
    }

    // MARK: - Codable Support

    enum CodingKeys: String, CodingKey {
        case id, name, type, featherRadius, opacity, inverted, enabled, maskImageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(MaskType.self, forKey: .type)
        featherRadius = try container.decode(Double.self, forKey: .featherRadius)
        opacity = try container.decode(Double.self, forKey: .opacity)
        inverted = try container.decode(Bool.self, forKey: .inverted)
        enabled = try container.decode(Bool.self, forKey: .enabled)

        if let data = try container.decodeIfPresent(Data.self, forKey: .maskImageData) {
            maskImageData = data
            maskImage = CIImage(data: data)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(featherRadius, forKey: .featherRadius)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(inverted, forKey: .inverted)
        try container.encode(enabled, forKey: .enabled)

        // Convert CIImage to PNG data for persistence
        if let image = maskImage, let data = convertToPNGData(image) {
            try container.encode(data, forKey: .maskImageData)
        }
    }

    private func convertToPNGData(_ image: CIImage) -> Data? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage).pngData()
        #elseif canImport(AppKit)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    // MARK: - Processing

    /// Get processed mask ready for blending
    func processedMask(sourceSize: CGSize) -> CIImage? {
        guard enabled, var mask = maskImage else { return nil }

        // Scale mask to match source size if needed
        let maskExtent = mask.extent
        if maskExtent.size != sourceSize {
            let scaleX = sourceSize.width / maskExtent.width
            let scaleY = sourceSize.height / maskExtent.height
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            mask = mask.transformed(by: transform)
        }

        // Apply feathering
        if featherRadius > 0 {
            mask = mask.applyingGaussianBlur(sigma: featherRadius)
        }

        // Apply opacity
        if opacity < 1.0 {
            mask = mask.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: opacity),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: opacity),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: opacity),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ])
        }

        // Invert if needed
        if inverted {
            mask = mask.applyingFilter("CIColorInvert")
        }

        return mask
    }
}

// MARK: - Property Wrapper for Non-Codable Properties
@propertyWrapper
struct IgnoredCodable<T>: Codable {
    var wrappedValue: T?

    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        wrappedValue = nil
    }

    func encode(to encoder: Encoder) throws {
        // Encoding handled manually in MaskLayer
    }
}

extension IgnoredCodable: Equatable where T: Equatable {}

// MARK: - Mask Presets
extension MaskLayer {
    /// Create empty mask for brushing
    static func empty(size: CGSize, name: String = "Manual Mask") -> MaskLayer {
        let extent = CGRect(origin: .zero, size: size)
        let blackImage = CIImage(color: .black).cropped(to: extent)

        return MaskLayer(
            name: name,
            type: .brushed,
            maskImage: blackImage
        )
    }

    /// Create full mask (all white)
    static func full(size: CGSize, name: String = "Full Mask") -> MaskLayer {
        let extent = CGRect(origin: .zero, size: size)
        let whiteImage = CIImage(color: .white).cropped(to: extent)

        return MaskLayer(
            name: name,
            type: .brushed,
            maskImage: whiteImage
        )
    }
}
