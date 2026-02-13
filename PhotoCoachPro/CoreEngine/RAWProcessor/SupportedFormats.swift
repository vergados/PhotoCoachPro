//
//  SupportedFormats.swift
//  PhotoCoachPro
//
//  RAW format detection and metadata
//

import Foundation

/// RAW format detection and capabilities
struct RAWFormat {
    let fileExtension: String
    let manufacturer: String
    let description: String
    let supportsRAWFilter: Bool

    static let allFormats: [RAWFormat] = [
        // Adobe
        RAWFormat(fileExtension: "dng", manufacturer: "Adobe", description: "Digital Negative", supportsRAWFilter: true),

        // Nikon
        RAWFormat(fileExtension: "nef", manufacturer: "Nikon", description: "Nikon Electronic Format", supportsRAWFilter: true),
        RAWFormat(fileExtension: "nrw", manufacturer: "Nikon", description: "Nikon RAW", supportsRAWFilter: true),

        // Canon
        RAWFormat(fileExtension: "cr2", manufacturer: "Canon", description: "Canon RAW 2", supportsRAWFilter: true),
        RAWFormat(fileExtension: "cr3", manufacturer: "Canon", description: "Canon RAW 3", supportsRAWFilter: true),
        RAWFormat(fileExtension: "crw", manufacturer: "Canon", description: "Canon RAW", supportsRAWFilter: true),

        // Sony
        RAWFormat(fileExtension: "arw", manufacturer: "Sony", description: "Sony RAW", supportsRAWFilter: true),
        RAWFormat(fileExtension: "srf", manufacturer: "Sony", description: "Sony RAW Format", supportsRAWFilter: true),
        RAWFormat(fileExtension: "sr2", manufacturer: "Sony", description: "Sony RAW 2", supportsRAWFilter: true),

        // Fujifilm
        RAWFormat(fileExtension: "raf", manufacturer: "Fujifilm", description: "Fuji RAW", supportsRAWFilter: true),

        // Olympus/OM System
        RAWFormat(fileExtension: "orf", manufacturer: "Olympus", description: "Olympus RAW", supportsRAWFilter: true),

        // Panasonic
        RAWFormat(fileExtension: "rw2", manufacturer: "Panasonic", description: "Panasonic RAW 2", supportsRAWFilter: true),
        RAWFormat(fileExtension: "raw", manufacturer: "Panasonic", description: "Panasonic RAW", supportsRAWFilter: true),

        // Pentax
        RAWFormat(fileExtension: "pef", manufacturer: "Pentax", description: "Pentax Electronic File", supportsRAWFilter: true),
        RAWFormat(fileExtension: "dcs", manufacturer: "Pentax", description: "Pentax DCS", supportsRAWFilter: true),

        // Leica
        RAWFormat(fileExtension: "rwl", manufacturer: "Leica", description: "Leica RAW", supportsRAWFilter: true),

        // Apple
        RAWFormat(fileExtension: "dng", manufacturer: "Apple", description: "Apple ProRAW", supportsRAWFilter: true),

        // Phase One
        RAWFormat(fileExtension: "iiq", manufacturer: "Phase One", description: "Intelligent Image Quality", supportsRAWFilter: true),

        // Hasselblad
        RAWFormat(fileExtension: "3fr", manufacturer: "Hasselblad", description: "Hasselblad 3F RAW", supportsRAWFilter: true),

        // Sigma
        RAWFormat(fileExtension: "x3f", manufacturer: "Sigma", description: "Sigma X3F", supportsRAWFilter: true),
    ]

    /// Check if file extension is a RAW format
    static func isRAWFormat(_ fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased()
        return allFormats.contains { $0.fileExtension == ext }
    }

    /// Get RAW format info for extension
    static func format(for fileExtension: String) -> RAWFormat? {
        let ext = fileExtension.lowercased()
        return allFormats.first { $0.fileExtension == ext }
    }

    /// All supported extensions
    static var supportedExtensions: [String] {
        allFormats.map { $0.fileExtension }
    }

    /// User-friendly list of supported formats
    static var supportedFormatsDescription: String {
        let manufacturers = Set(allFormats.map { $0.manufacturer }).sorted()
        return manufacturers.joined(separator: ", ")
    }
}
