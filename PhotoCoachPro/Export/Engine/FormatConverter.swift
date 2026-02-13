//
//  FormatConverter.swift
//  PhotoCoachPro
//
//  Image format conversion
//

import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Convert images between formats
actor FormatConverter {

    /// Convert image to specified format and quality
    func convert(
        _ image: CIImage,
        to format: ExportSettings.ExportFormat,
        quality: ExportSettings.ExportQuality,
        context: CIContext
    ) async throws -> Data {
        switch format {
        case .jpeg:
            return try convertToJPEG(image, quality: quality, context: context)
        case .png:
            return try convertToPNG(image, context: context)
        case .tiff:
            return try convertToTIFF(image, context: context)
        case .heic:
            return try convertToHEIC(image, quality: quality, context: context)
        }
    }

    // MARK: - JPEG

    private func convertToJPEG(
        _ image: CIImage,
        quality: ExportSettings.ExportQuality,
        context: CIContext
    ) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        let options: [CIImageRepresentationOption: Any] = [
            .jpegCompressionQuality: quality.compressionQuality as NSNumber
        ]

        guard let data = context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: options
        ) else {
            throw ExportError.formatConversionFailed
        }

        return data
    }

    // MARK: - PNG

    private func convertToPNG(
        _ image: CIImage,
        context: CIContext
    ) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        guard let data = context.pngRepresentation(
            of: image,
            format: .RGBA8,
            colorSpace: colorSpace,
            options: [:]
        ) else {
            throw ExportError.formatConversionFailed
        }

        return data
    }

    // MARK: - TIFF

    private func convertToTIFF(
        _ image: CIImage,
        context: CIContext
    ) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.adobeRGB1998)!

        guard let data = context.tiffRepresentation(
            of: image,
            format: .RGBA16,
            colorSpace: colorSpace,
            options: [:]
        ) else {
            throw ExportError.formatConversionFailed
        }

        return data
    }

    // MARK: - HEIC

    private func convertToHEIC(
        _ image: CIImage,
        quality: ExportSettings.ExportQuality,
        context: CIContext
    ) throws -> Data {
        #if os(iOS) || os(macOS)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        if #available(iOS 11.0, macOS 10.13, *) {
            let options: [CIImageRepresentationOption: Any] = [
                .heifCompressionQuality: quality.compressionQuality as NSNumber
            ]

            guard let data = context.heifRepresentation(
                of: image,
                format: .RGBA8,
                colorSpace: colorSpace,
                options: options
            ) else {
                throw ExportError.formatConversionFailed
            }

            return data
        } else {
            throw ExportError.formatConversionFailed
        }
        #else
        throw ExportError.formatConversionFailed
        #endif
    }

    // MARK: - Utilities

    /// Get appropriate color space for format
    func colorSpaceForFormat(_ format: ExportSettings.ExportFormat) -> CGColorSpace? {
        switch format {
        case .jpeg, .png, .heic:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case .tiff:
            return CGColorSpace(name: CGColorSpace.adobeRGB1998)
        }
    }

    /// Get appropriate CIFormat for export format
    func ciFormatForExportFormat(_ format: ExportSettings.ExportFormat) -> CIFormat {
        switch format {
        case .jpeg, .png, .heic:
            return .RGBA8
        case .tiff:
            return .RGBA16
        }
    }

    /// Check if format is available on current platform
    func isFormatAvailable(_ format: ExportSettings.ExportFormat) -> Bool {
        switch format {
        case .jpeg, .png, .tiff:
            return true
        case .heic:
            #if os(iOS)
            return true
            #elseif os(macOS)
            if #available(macOS 10.13, *) {
                return true
            } else {
                return false
            }
            #else
            return false
            #endif
        }
    }
}
