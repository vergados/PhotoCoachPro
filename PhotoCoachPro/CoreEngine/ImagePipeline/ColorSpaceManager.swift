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
    private let context: CIContext

    init(workingSpace: WorkingSpace = .displayP3) {
        self.workingSpace = workingSpace
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Working Space Management

    func setWorkingSpace(_ space: WorkingSpace) {
        workingSpace = space
    }

    // MARK: - Color Space Conversion

    /// Convert image to working color space
    func convertToWorkingSpace(_ image: CIImage) -> CIImage {
        convert(image, to: workingSpace.cgColorSpace)
    }

    /// Convert to specific color space by rendering into target space and reconstructing.
    /// Uses the same CGImage round-trip pattern as detectOutOfGamut().
    func convert(_ image: CIImage, to targetSpace: CGColorSpace) -> CIImage {
        guard let cgImage = context.createCGImage(
            image, from: image.extent, format: .RGBA8, colorSpace: targetSpace
        ) else { return image }
        return CIImage(cgImage: cgImage)
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

    /// Detect out-of-gamut pixels and return image with red overlay on clipped areas.
    ///
    /// Approach: render the image into the target color space (clipping any out-of-gamut
    /// colors), convert back to CIImage, compute the per-pixel absolute difference, amplify
    /// it into a binary mask, then blend a red overlay onto the original where the mask is
    /// non-zero. Pixels that were in-gamut round-trip identically, so they produce zero
    /// difference and no overlay.
    func detectOutOfGamut(_ image: CIImage, targetSpace: CGColorSpace) -> CIImage {
        // 1. Render to CGImage in the target space — clips out-of-gamut colors to boundary
        guard let cgClipped = context.createCGImage(
            image, from: image.extent, format: .RGBA8, colorSpace: targetSpace
        ) else { return image }

        // 2. Convert the clipped bitmap back to CIImage for comparison
        let clippedCI = CIImage(cgImage: cgClipped)

        // 3. Compute absolute per-pixel difference between original and round-tripped image
        //    CIDifferenceBlendMode outputs |A − B| per channel
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else { return image }
        diffFilter.setValue(image, forKey: kCIInputImageKey)
        diffFilter.setValue(clippedCI, forKey: kCIInputBackgroundImageKey)
        guard let diffImage = diffFilter.outputImage else { return image }

        // 4. Amplify: sum R+G+B channels and multiply by 500 so even tiny differences
        //    (≥ 0.002) become fully opaque in the mask after clamping
        guard let amplifyFilter = CIFilter(name: "CIColorMatrix") else { return image }
        amplifyFilter.setValue(diffImage, forKey: kCIInputImageKey)
        // Each output channel = (inR + inG + inB) * 500
        let channelVec = CIVector(x: 500, y: 500, z: 500, w: 0)
        amplifyFilter.setValue(channelVec, forKey: "inputRVector")
        amplifyFilter.setValue(channelVec, forKey: "inputGVector")
        amplifyFilter.setValue(channelVec, forKey: "inputBVector")
        // Alpha: amplify input alpha so mask is opaque wherever there is any difference
        amplifyFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1000), forKey: "inputAVector")
        guard let amplifiedImage = amplifyFilter.outputImage else { return image }

        // 5. Clamp to [0, 1] to create binary mask
        guard let clampFilter = CIFilter(name: "CIColorClamp") else { return image }
        clampFilter.setValue(amplifiedImage, forKey: kCIInputImageKey)
        clampFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputMinComponents")
        clampFilter.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")
        guard let maskImage = clampFilter.outputImage else { return image }

        // 6. Generate a semi-transparent red overlay covering the full image extent
        guard let colorGen = CIFilter(name: "CIConstantColorGenerator") else { return image }
        colorGen.setValue(CIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.75), forKey: kCIInputColorKey)
        guard let redOverlay = colorGen.outputImage?.cropped(to: image.extent) else { return image }

        // 7. Blend red overlay onto original image using the out-of-gamut mask
        //    Background = original, foreground = red, mask controls opacity
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return image }
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(redOverlay, forKey: kCIInputImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage ?? image
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
