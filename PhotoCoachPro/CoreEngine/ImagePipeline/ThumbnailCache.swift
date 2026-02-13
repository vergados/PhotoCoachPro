//
//  ThumbnailCache.swift
//  PhotoCoachPro
//
//  Fast thumbnail generation with LRU cache
//

import Foundation
import CoreImage
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Fast thumbnail cache with LRU eviction
actor ThumbnailCache {
    private var cache: [CacheKey: CachedThumbnail] = [:]
    private let maxCacheSize: Int
    private let thumbnailSize: CGSize
    private let context: CIContext

    init(
        maxCacheSize: Int = 200,
        thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    ) {
        self.maxCacheSize = maxCacheSize
        self.thumbnailSize = thumbnailSize
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Cache Access

    func thumbnail(for key: CacheKey) -> PlatformImage? {
        guard let cached = cache[key] else { return nil }

        // Update access time (LRU)
        var updated = cached
        updated.lastAccessTime = Date()
        cache[key] = updated

        return cached.image
    }

    func setThumbnail(_ image: PlatformImage, for key: CacheKey) {
        cache[key] = CachedThumbnail(image: image)

        // Evict if over limit
        if cache.count > maxCacheSize {
            evictOldest()
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    func cacheSize() -> Int {
        cache.count
    }

    // MARK: - Thumbnail Generation

    func generateThumbnail(from ciImage: CIImage, for key: CacheKey) async -> PlatformImage? {
        // Check cache first
        if let cached = thumbnail(for: key) {
            return cached
        }

        // Generate thumbnail
        let thumbnail = await generateScaledImage(from: ciImage)

        // Cache it
        if let thumbnail = thumbnail {
            setThumbnail(thumbnail, for: key)
        }

        return thumbnail
    }

    private func generateScaledImage(from ciImage: CIImage) async -> PlatformImage? {
        let extent = ciImage.extent
        let scaleX = thumbnailSize.width / extent.width
        let scaleY = thumbnailSize.height / extent.height
        let scale = min(scaleX, scaleY)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpace(name: CGColorSpace.linearSRGB)!

        guard let cgImage = context.createCGImage(
            scaledImage,
            from: scaledImage.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            return nil
        }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    // MARK: - LRU Eviction

    private func evictOldest() {
        guard let oldestKey = cache.min(by: { $0.value.lastAccessTime < $1.value.lastAccessTime })?.key else {
            return
        }
        cache.removeValue(forKey: oldestKey)
    }

    // MARK: - Cache Key

    struct CacheKey: Hashable {
        let photoID: UUID
        let editHash: String  // Hash of edit stack to detect changes

        init(photoID: UUID, editStack: [EditInstruction]) {
            self.photoID = photoID
            // Simple hash of instruction count and types
            self.editHash = "\(editStack.count)-\(editStack.map { $0.type.rawValue }.joined())"
        }
    }

    private struct CachedThumbnail {
        let image: PlatformImage
        var lastAccessTime: Date

        init(image: PlatformImage) {
            self.image = image
            self.lastAccessTime = Date()
        }
    }
}
