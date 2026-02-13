//
//  ExportSettings.swift
//  PhotoCoachPro
//
//  Export configuration models
//

import Foundation
import CoreImage

/// Export settings configuration
struct ExportSettings: Codable, Identifiable, Equatable {
    var id: UUID
    var format: ExportFormat
    var quality: ExportQuality
    var colorSpace: ColorSpaceOption
    var resolution: ResolutionOption
    var metadata: MetadataOption
    var name: String?

    init(
        id: UUID = UUID(),
        format: ExportFormat = .jpeg,
        quality: ExportQuality = .high,
        colorSpace: ColorSpaceOption = .sRGB,
        resolution: ResolutionOption = .original,
        metadata: MetadataOption = .preserve,
        name: String? = nil
    ) {
        self.id = id
        self.format = format
        self.quality = quality
        self.colorSpace = colorSpace
        self.resolution = resolution
        self.metadata = metadata
        self.name = name
    }

    // MARK: - Export Format

    enum ExportFormat: String, Codable, CaseIterable {
        case jpeg = "JPEG"
        case png = "PNG"
        case tiff = "TIFF"
        case heic = "HEIC"

        var fileExtension: String {
            switch self {
            case .jpeg: return "jpg"
            case .png: return "png"
            case .tiff: return "tif"
            case .heic: return "heic"
            }
        }

        var utType: String {
            switch self {
            case .jpeg: return "public.jpeg"
            case .png: return "public.png"
            case .tiff: return "public.tiff"
            case .heic: return "public.heic"
            }
        }

        var supportsTransparency: Bool {
            self == .png || self == .tiff
        }

        var supportsCompression: Bool {
            self == .jpeg || self == .heic
        }

        var description: String {
            switch self {
            case .jpeg: return "JPEG - Universal compatibility, smaller file size"
            case .png: return "PNG - Lossless, supports transparency"
            case .tiff: return "TIFF - Professional, maximum quality"
            case .heic: return "HEIC - Modern, efficient compression"
            }
        }
    }

    // MARK: - Quality

    enum ExportQuality: String, Codable, CaseIterable {
        case maximum = "Maximum"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var compressionQuality: Double {
            switch self {
            case .maximum: return 1.0
            case .high: return 0.9
            case .medium: return 0.8
            case .low: return 0.6
            }
        }

        var description: String {
            switch self {
            case .maximum: return "Best quality, largest file size"
            case .high: return "Excellent quality, reasonable size"
            case .medium: return "Good quality, smaller size"
            case .low: return "Basic quality, smallest size"
            }
        }
    }

    // MARK: - Color Space

    enum ColorSpaceOption: String, Codable, CaseIterable {
        case sRGB = "sRGB"
        case displayP3 = "Display P3"
        case adobeRGB = "Adobe RGB"
        case proPhotoRGB = "ProPhoto RGB"

        var colorSpace: CGColorSpace? {
            switch self {
            case .sRGB: return CGColorSpace(name: CGColorSpace.sRGB)
            case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)
            case .adobeRGB: return CGColorSpace(name: CGColorSpace.adobeRGB1998)
            case .proPhotoRGB: return CGColorSpace(name: CGColorSpace.genericRGBLinear)
            }
        }

        var description: String {
            switch self {
            case .sRGB: return "Standard RGB - Web & most displays"
            case .displayP3: return "Wide gamut - Apple displays"
            case .adobeRGB: return "Professional - Print workflows"
            case .proPhotoRGB: return "Maximum gamut - Photography"
            }
        }
    }

    // MARK: - Resolution

    enum ResolutionOption: String, Codable, CaseIterable {
        case original = "Original"
        case large = "Large (4K)"
        case medium = "Medium (2K)"
        case small = "Small (1080p)"
        case custom = "Custom"

        var maxDimension: Int? {
            switch self {
            case .original: return nil
            case .large: return 3840
            case .medium: return 2560
            case .small: return 1920
            case .custom: return nil
            }
        }

        var description: String {
            switch self {
            case .original: return "Full resolution"
            case .large: return "4K (3840px)"
            case .medium: return "2K (2560px)"
            case .small: return "1080p (1920px)"
            case .custom: return "Specify dimensions"
            }
        }
    }

    // MARK: - Metadata

    enum MetadataOption: String, Codable, CaseIterable {
        case preserve = "Preserve All"
        case basic = "Basic Only"
        case strip = "Remove All"

        var description: String {
            switch self {
            case .preserve: return "Keep all EXIF, IPTC, GPS data"
            case .basic: return "Keep camera settings, remove GPS"
            case .strip: return "Remove all metadata for privacy"
            }
        }
    }

    // MARK: - Computed Properties

    var estimatedFileSize: String {
        // Rough estimates
        switch (format, quality) {
        case (.jpeg, .maximum), (.heic, .maximum):
            return "~8-12 MB"
        case (.jpeg, .high), (.heic, .high):
            return "~4-6 MB"
        case (.jpeg, .medium), (.heic, .medium):
            return "~2-3 MB"
        case (.jpeg, .low), (.heic, .low):
            return "~1-2 MB"
        case (.png, _):
            return "~15-25 MB"
        case (.tiff, _):
            return "~50-100 MB"
        }
    }

    // MARK: - Presets

    static let webOptimized = ExportSettings(
        format: .jpeg,
        quality: .high,
        colorSpace: .sRGB,
        resolution: .medium,
        metadata: .strip,
        name: "Web Optimized"
    )

    static let socialMedia = ExportSettings(
        format: .jpeg,
        quality: .high,
        colorSpace: .sRGB,
        resolution: .large,
        metadata: .basic,
        name: "Social Media"
    )

    static let print = ExportSettings(
        format: .tiff,
        quality: .maximum,
        colorSpace: .adobeRGB,
        resolution: .original,
        metadata: .preserve,
        name: "Print"
    )

    static let archival = ExportSettings(
        format: .png,
        quality: .maximum,
        colorSpace: .displayP3,
        resolution: .original,
        metadata: .preserve,
        name: "Archival"
    )

    static let allPresets: [ExportSettings] = [
        webOptimized,
        socialMedia,
        print,
        archival
    ]
}

// MARK: - Export Job

struct ExportJob: Identifiable, Equatable {
    var id: UUID
    var photoID: UUID
    var settings: ExportSettings
    var status: ExportStatus
    var progress: Double
    var outputURL: URL?
    var error: String?
    var startTime: Date
    var endTime: Date?

    init(
        id: UUID = UUID(),
        photoID: UUID,
        settings: ExportSettings,
        status: ExportStatus = .pending,
        progress: Double = 0.0,
        outputURL: URL? = nil,
        error: String? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil
    ) {
        self.id = id
        self.photoID = photoID
        self.settings = settings
        self.status = status
        self.progress = progress
        self.outputURL = outputURL
        self.error = error
        self.startTime = startTime
        self.endTime = endTime
    }

    enum ExportStatus: String, Equatable {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .processing: return "gearshape.2"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .cancelled: return "xmark.circle"
            }
        }

        var color: String {
            switch self {
            case .pending: return "gray"
            case .processing: return "blue"
            case .completed: return "green"
            case .failed: return "red"
            case .cancelled: return "orange"
            }
        }
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    mutating func updateProgress(_ progress: Double) {
        self.progress = min(1.0, max(0.0, progress))
        if self.progress > 0 && status == .pending {
            status = .processing
        }
    }

    mutating func complete(url: URL) {
        status = .completed
        progress = 1.0
        outputURL = url
        endTime = Date()
    }

    mutating func fail(error: String) {
        status = .failed
        self.error = error
        endTime = Date()
    }

    mutating func cancel() {
        status = .cancelled
        endTime = Date()
    }
}

// MARK: - Batch Export

struct BatchExportJob: Identifiable {
    var id: UUID = UUID()
    var jobs: [ExportJob]
    var settings: ExportSettings
    var outputDirectory: URL
    var createdAt: Date

    init(
        jobs: [ExportJob],
        settings: ExportSettings,
        outputDirectory: URL,
        createdAt: Date = Date()
    ) {
        self.jobs = jobs
        self.settings = settings
        self.outputDirectory = outputDirectory
        self.createdAt = createdAt
    }

    var totalJobs: Int {
        jobs.count
    }

    var completedJobs: Int {
        jobs.filter { $0.status == .completed }.count
    }

    var failedJobs: Int {
        jobs.filter { $0.status == .failed }.count
    }

    var overallProgress: Double {
        guard !jobs.isEmpty else { return 0 }
        let totalProgress = jobs.map { $0.progress }.reduce(0, +)
        return totalProgress / Double(jobs.count)
    }

    var isComplete: Bool {
        jobs.allSatisfy { $0.status == .completed || $0.status == .failed }
    }
}
