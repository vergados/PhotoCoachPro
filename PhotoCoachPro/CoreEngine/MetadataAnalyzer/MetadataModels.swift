//
//  MetadataModels.swift
//  PhotoCoachPro
//
//  Structured metadata types for EXIF/IPTC/XMP data
//

import Foundation
import CoreLocation

/// Structured EXIF data snapshot
struct EXIFData: Codable, Equatable {
    // Camera settings
    var cameraMake: String?
    var cameraModel: String?
    var lensMake: String?
    var lensModel: String?

    // Exposure settings
    var exposureTime: String?           // e.g. "1/250"
    var fNumber: Double?                // e.g. 2.8
    var iso: Int?                       // e.g. 400
    var exposureBias: Double?           // EV compensation
    var exposureProgram: String?        // Manual, Aperture Priority, etc.

    // Focus settings
    var focalLength: Double?            // mm
    var focalLength35mmEquiv: Double?   // 35mm equivalent
    var focusMode: String?

    // Date/Time
    var dateTimeOriginal: Date?
    var dateTimeDigitized: Date?
    var modifyDate: Date?

    // Location
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var gpsAltitude: Double?

    // Image properties
    var colorSpace: String?             // sRGB, Display P3, Adobe RGB
    var pixelWidth: Int?
    var pixelHeight: Int?
    var orientation: Int?               // EXIF orientation (1-8)

    // Advanced
    var whiteBalance: String?
    var meteringMode: String?
    var flash: String?
    var software: String?

    var location: CLLocation? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        let altitude = gpsAltitude ?? 0
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: dateTimeOriginal ?? Date()
        )
    }
}

/// IPTC/XMP metadata
struct IPTCData: Codable, Equatable {
    var creator: String?
    var copyright: String?
    var caption: String?
    var keywords: [String]
    var headline: String?
    var credit: String?
    var source: String?
    var city: String?
    var state: String?
    var country: String?

    init(
        creator: String? = nil,
        copyright: String? = nil,
        caption: String? = nil,
        keywords: [String] = [],
        headline: String? = nil,
        credit: String? = nil,
        source: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil
    ) {
        self.creator = creator
        self.copyright = copyright
        self.caption = caption
        self.keywords = keywords
        self.headline = headline
        self.credit = credit
        self.source = source
        self.city = city
        self.state = state
        self.country = country
    }
}

/// Complete metadata package
struct PhotoMetadata: Codable, Equatable {
    var exif: EXIFData?
    var iptc: IPTCData?

    init(exif: EXIFData? = nil, iptc: IPTCData? = nil) {
        self.exif = exif
        self.iptc = iptc
    }
}
