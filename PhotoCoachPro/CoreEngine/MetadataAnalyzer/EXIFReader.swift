//
//  EXIFReader.swift
//  PhotoCoachPro
//
//  Read EXIF/IPTC/XMP metadata from images
//

import Foundation
import CoreGraphics
import ImageIO

/// Reads metadata from image files
actor EXIFReader {

    // MARK: - Read Complete Metadata

    func readMetadata(from url: URL) async throws -> PhotoMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.cannotReadFile
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataError.noMetadata
        }

        let exif = extractEXIF(from: properties)
        let iptc = extractIPTC(from: properties)

        return PhotoMetadata(exif: exif, iptc: iptc)
    }

    // MARK: - EXIF Extraction

    private func extractEXIF(from properties: [String: Any]) -> EXIFData {
        var exif = EXIFData()

        // TIFF dictionary (camera info)
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exif.cameraMake = tiffDict[kCGImagePropertyTIFFMake as String] as? String
            exif.cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
            exif.software = tiffDict[kCGImagePropertyTIFFSoftware as String] as? String
            exif.orientation = tiffDict[kCGImagePropertyTIFFOrientation as String] as? Int
        }

        // EXIF dictionary
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Exposure settings
            if let expTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double {
                exif.exposureTime = formatExposureTime(expTime)
            }
            exif.fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double

            if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoArray.first {
                exif.iso = iso
            }

            exif.exposureBias = exifDict[kCGImagePropertyExifExposureBiasValue as String] as? Double

            if let expProgram = exifDict[kCGImagePropertyExifExposureProgram as String] as? Int {
                exif.exposureProgram = formatExposureProgram(expProgram)
            }

            // Focus
            exif.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
            exif.focalLength35mmEquiv = exifDict[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double

            // Lens
            exif.lensMake = exifDict[kCGImagePropertyExifLensMake as String] as? String
            exif.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String

            // Dates
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                exif.dateTimeOriginal = parseEXIFDate(dateString)
            }
            if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized as String] as? String {
                exif.dateTimeDigitized = parseEXIFDate(dateString)
            }

            // Color space
            if let colorSpaceInt = exifDict[kCGImagePropertyExifColorSpace as String] as? Int {
                exif.colorSpace = colorSpaceInt == 1 ? "sRGB" : (colorSpaceInt == 65535 ? "Uncalibrated" : "Unknown")
            }

            // White balance
            if let wbInt = exifDict[kCGImagePropertyExifWhiteBalance as String] as? Int {
                exif.whiteBalance = wbInt == 0 ? "Auto" : "Manual"
            }

            // Metering mode
            if let meteringInt = exifDict[kCGImagePropertyExifMeteringMode as String] as? Int {
                exif.meteringMode = formatMeteringMode(meteringInt)
            }

            // Flash
            if let flashInt = exifDict[kCGImagePropertyExifFlash as String] as? Int {
                exif.flash = flashInt == 0 ? "No Flash" : "Flash Fired"
            }
        }

        // GPS dictionary
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            exif.gpsLatitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double
            exif.gpsLongitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double
            exif.gpsAltitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        }

        // Image dimensions
        exif.pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        exif.pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int

        return exif
    }

    // MARK: - IPTC Extraction

    private func extractIPTC(from properties: [String: Any]) -> IPTCData {
        var iptc = IPTCData()

        guard let iptcDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] else {
            return iptc
        }

        iptc.creator = iptcDict[kCGImagePropertyIPTCCreatorContactInfo as String] as? String
        iptc.copyright = iptcDict[kCGImagePropertyIPTCCopyrightNotice as String] as? String
        iptc.caption = iptcDict[kCGImagePropertyIPTCCaptionAbstract as String] as? String
        iptc.headline = iptcDict[kCGImagePropertyIPTCHeadline as String] as? String
        iptc.credit = iptcDict[kCGImagePropertyIPTCCredit as String] as? String
        iptc.source = iptcDict[kCGImagePropertyIPTCSource as String] as? String
        iptc.city = iptcDict[kCGImagePropertyIPTCCity as String] as? String
        iptc.state = iptcDict[kCGImagePropertyIPTCProvinceState as String] as? String
        iptc.country = iptcDict[kCGImagePropertyIPTCCountryPrimaryLocationName as String] as? String

        if let keywords = iptcDict[kCGImagePropertyIPTCKeywords as String] as? [String] {
            iptc.keywords = keywords
        }

        return iptc
    }

    // MARK: - Helper Formatters

    private func formatExposureTime(_ seconds: Double) -> String {
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        } else {
            let denominator = Int(1.0 / seconds)
            return "1/\(denominator)"
        }
    }

    private func formatExposureProgram(_ value: Int) -> String {
        switch value {
        case 0: return "Not Defined"
        case 1: return "Manual"
        case 2: return "Program AE"
        case 3: return "Aperture Priority"
        case 4: return "Shutter Priority"
        case 5: return "Creative Program"
        case 6: return "Action Program"
        case 7: return "Portrait Mode"
        case 8: return "Landscape Mode"
        default: return "Unknown"
        }
    }

    private func formatMeteringMode(_ value: Int) -> String {
        switch value {
        case 0: return "Unknown"
        case 1: return "Average"
        case 2: return "Center-weighted"
        case 3: return "Spot"
        case 4: return "Multi-spot"
        case 5: return "Pattern"
        case 6: return "Partial"
        default: return "Other"
        }
    }

    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

// MARK: - Errors

enum MetadataError: Error, LocalizedError {
    case cannotReadFile
    case noMetadata
    case invalidMetadata

    var errorDescription: String? {
        switch self {
        case .cannotReadFile:
            return "Cannot read image file"
        case .noMetadata:
            return "No metadata found in image"
        case .invalidMetadata:
            return "Invalid metadata format"
        }
    }
}
