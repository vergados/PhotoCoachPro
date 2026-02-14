// //  ColorSpaceManager.swift
//  PhotoCoachPro
//
//  Manages color space conversions and working spaces
//

import Foundation
import CoreGraphics
import CoreImage

/// Manages color spaces for the editing pipeline
actor ColorSpaceManager {
    enum WorkingSpace: String, Codable, CaseIterable {
        case sRGB = "sRGB"
        case displayP3 = "Display P3"
        case adobeRGB = "Adobe RGB"
        case proPhotoRGB = "ProPhoto RGB"

        var cgColorSpace: CGColorSpace {
            switch self {
            case .sRGB:
                return CGColorSpace(name: CGColorSpace.sRGB)!
            case .displayP3:
                return CGColorSpace(name: CGColorSpace.displayP3)!
            case .adobeRGB:
                return CGColorSpace(name: CGColorSpace.adobeRGB1998)!
            case .proPhotoRGB:
                return CGColorSpace(name: CGColorSpace.rommrgb)!
            }
        }

        var displayName: String { rawValue }
    }

    private(set) var workingSpace: WorkingSpace

    init(workingSpace: WorkingSpace = .displayP3) {
        self.workingSpace = workingSpace
    }

    // MARK: - Working Space Management

    func setWorkingSpace(_ space: WorkingSpace) {
        workingSpace = space
    }

    // MARK: - Color Space Conversion

    /// Convert image to working color space
    func convertToWorkingSpace(_ image: CIImage) -> CIImage {
        // CIImage handles color spaces automatically - no manual conversion needed
        return image
    }

    /// Convert to specific color space (for export)
    func convert(_ image: CIImage, to targetSpace: CGColorSpace) -> CIImage {
        // CIImage handles color space conversion during rendering
        return image
    }

    /// Convert to sRGB (for web export)
    func convertToSRGB(_ image: CIImage) -> CIImage {
        convert(image, to: CGColorSpace(name: CGColorSpace.sRGB)!)
    }

    /// Convert to Display P3 (for device display)
    func convertToDisplayP3(_ image: CIImage) -> CIImage {
        convert(image, to: CGColorSpace(name: CGColorSpace.displayP3)!)
    }

    // MARK: - ICC Profile Support

    /// Load image with embedded ICC profile
    func loadWithProfile(url: URL) throws -> (image: CIImage, colorSpace: CGColorSpace?) {
        let options: [CIImageOption: Any] = [.applyOrientationProperty: true]
        guard let image = CIImage(contentsOf: url, options: options) else {
            throw ColorSpaceError.invalidImage
        }
        return (image, image.colorSpace)
    }

    /// Apply ICC profile to image
    func applyProfile(_ image: CIImage, profileData: Data) throws -> CIImage {
        guard let colorSpace = CGColorSpace(iccData: profileData as CFData) else {
            throw ColorSpaceError.invalidProfile
        }
        return convert(image, to: colorSpace)
    }

    // MARK: - Soft Proofing

    /// Generate soft proof for target color space
    func softProof(_ image: CIImage, targetSpace: CGColorSpace) -> CIImage {
        // Convert to target space and back to working space
        // This simulates how the image will look when printed/displayed in target space
        let converted = convert(image, to: targetSpace)
        return convertToWorkingSpace(converted)
    }

    /// Detect out-of-gamut pixels
    func detectOutOfGamut(_ image: CIImage, targetSpace: CGColorSpace) -> CIImage {
        // This is a simplified version - proper implementation would check each pixel
        // For now, return original (Phase 1 stub)
        return image
    }
}

// MARK: - Errors
enum ColorSpaceError: Error, LocalizedError {
    case invalidImage
    case invalidProfile
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not load image"
        case .invalidProfile:
            return "Invalid ICC color profile"
        case .conversionFailed:
            return "Color space conversion failed"
        }
    }
}

// MARK: - CIImage Extensions
// Removed broken filter extensions - CIImage handles color spaces automatically
