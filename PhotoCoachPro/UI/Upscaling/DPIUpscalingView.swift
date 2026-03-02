//
//  DPIUpscalingView.swift
//  PhotoCoachPro
//
//  Professional DPI upscaling interface
//

import SwiftUI
import SwiftData
import CoreImage
import OSLog

private let logger = Logger(subsystem: "com.photocoachpro", category: "DPIUpscaling")

struct DPIUpscalingView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \PhotoRecord.importedDate, order: .reverse) var photos: [PhotoRecord]

    // Selection state
    @State private var selectedPhoto: PhotoRecord?
    @State private var upscaledImage: PlatformImage?
    @State private var upscaledDimensions: CGSize?

    // UI state
    @State private var isUpscaling = false
    @State private var showThumbnails = true
    @State private var errorMessage: String?

    // Print size configuration
    @State private var selectedCategory: UpscalingPrintSizeCategory = .standard
    @State private var selectedSize: UpscalingPrintSize = UpscalingPrintSize.allSizes[10] // 8×10" default
    @State private var isLandscape = false
    @State private var selectedDPI: Int = 300
    @State private var selectedMethod: UpscalingMethod = .lanczos

    var body: some View {
        VStack(spacing: 0) {
            if photos.isEmpty {
                emptyState
            } else {
                // Compact toolbar
                compactToolbar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background {
                        #if os(macOS)
                        Color(nsColor: NSColor.windowBackgroundColor)
                        #else
                        Color(.systemBackground)
                        #endif
                    }

                Divider()

                // Main content
                ZStack {
                    if let image = upscaledImage, let dims = upscaledDimensions, let photo = selectedPhoto {
                        upscaledPreview(image: image, dimensions: dims, photo: photo)
                    } else if let photo = selectedPhoto {
                        originalPreview(photo: photo)
                    } else {
                        photoSelectionPrompt
                    }
                }

                // Loading indicator (bottom right corner, doesn't block view)
                if isUpscaling {
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Upscaling...")
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding()
                        }
                    }
                }

                // Error message overlay
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(error)
                                .foregroundColor(.white)
                            Button("Dismiss") {
                                errorMessage = nil
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(8)
                        .padding()
                    }
                }

                // Thumbnail strip (toggleable)
                if showThumbnails {
                    Divider()
                    thumbnailStrip
                        .frame(height: 100)
                        .background {
                            #if os(macOS)
                            Color(nsColor: NSColor.controlBackgroundColor)
                            #else
                            Color(.secondarySystemBackground)
                            #endif
                        }
                }
            }
        }
    }

    // MARK: - Compact Toolbar

    private var compactToolbar: some View {
        HStack(spacing: 12) {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(UpscalingPrintSizeCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .frame(width: 160)
            .onChange(of: selectedCategory) {
                updateSelectedSize()
            }

            // Size picker
            Picker("Size", selection: $selectedSize) {
                ForEach(availableSizes, id: \.id) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .frame(width: 140)

            // Orientation toggle
            Button(action: {
                isLandscape.toggle()
                upscaledImage = nil
                upscaledDimensions = nil
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLandscape ? "rectangle" : "rectangle.portrait")
                    Text(isLandscape ? "Landscape" : "Portrait")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isLandscape ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(isLandscape ? "Switch to Portrait" : "Switch to Landscape")

            // DPI picker
            Picker("DPI", selection: $selectedDPI) {
                Text("150 DPI").tag(150)
                Text("240 DPI").tag(240)
                Text("300 DPI").tag(300)
                Text("600 DPI").tag(600)
            }
            .frame(width: 100)

            // Method picker
            Picker("Method", selection: $selectedMethod) {
                Text("Lanczos").tag(UpscalingMethod.lanczos)
                Text("Bicubic").tag(UpscalingMethod.bicubic)
                Text("AI Enhanced").tag(UpscalingMethod.aiEnhanced)
            }
            .frame(width: 120)

            Spacer()

            // Info display
            if let photo = selectedPhoto {
                scaleInfoDisplay(photo: photo)
            }

            // Thumbnail toggle
            Button(action: { showThumbnails.toggle() }) {
                Image(systemName: showThumbnails ? "photo.stack.fill" : "photo.stack")
                    .frame(width: 28, height: 28)
            }
            .help(showThumbnails ? "Hide Thumbnails" : "Show Thumbnails")

            // Upscale button
            Button(action: performUpscale) {
                Text("Upscale")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPhoto == nil || isUpscaling)
        }
    }

    // MARK: - Scale Info Display

    private func scaleInfoDisplay(photo: PhotoRecord) -> some View {
        let dims = currentPrintDimensions
        let reqWidth = Int(dims.width * Double(selectedDPI))
        let reqHeight = Int(dims.height * Double(selectedDPI))
        let scaleX = Double(reqWidth) / Double(photo.width)
        let scaleY = Double(reqHeight) / Double(photo.height)
        let scaleFactor = max(scaleX, scaleY)

        return HStack(spacing: 4) {
            Text("\(String(format: "%.2f", scaleFactor))×")
                .foregroundColor(.secondary)
                .font(.caption)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(reqWidth)×\(reqHeight)")
                .foregroundColor(.blue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Original Preview

    private func originalPreview(photo: PhotoRecord) -> some View {
        OriginalImagePreview(photo: photo, appState: appState)
    }
}

// MARK: - Original Image Preview Component

struct OriginalImagePreview: View {
    let photo: PhotoRecord
    let appState: AppState

    @State private var loadedImage: PlatformImage?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.black

            if let image = loadedImage {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                #endif
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading image...")
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                    Text("Failed to load image")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text(photo.fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let error = loadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            // Info overlay (bottom center)
            if loadedImage != nil {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Original: \(photo.width)×\(photo.height) px")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text("Ready to upscale")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        loadError = nil

        do {
            logger.debug("Loading image: \(photo.fileName)")
            let loaded = try await appState.imageLoader.loadImage(for: photo)

            let context = CIContext()
            guard let cgImage = context.createCGImage(loaded.image, from: loaded.image.extent) else {
                throw NSError(domain: "PhotoCoachPro", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to convert image"
                ])
            }

            #if canImport(UIKit)
            let platformImage = UIImage(cgImage: cgImage)
            #elseif canImport(AppKit)
            let platformImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #endif

            await MainActor.run {
                self.loadedImage = platformImage
                self.isLoading = false
            }
        } catch {
            logger.error("Failed to load image: \(error)")
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Upscaled Preview Extension

extension DPIUpscalingView {
    private func upscaledPreview(image: PlatformImage, dimensions: CGSize, photo: PhotoRecord) -> some View {
        ZStack {
            Color.black

            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            #endif

            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("Upscaled: \(Int(dimensions.width))×\(Int(dimensions.height)) px")
                        .font(.caption)
                        .foregroundColor(.white)

                    let dims = currentPrintDimensions
                    Text("\(String(format: "%.1f", dims.width))×\(String(format: "%.1f", dims.height))\" @ \(selectedDPI) DPI")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Save Image") {
                        saveUpscaledImage(image)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    ThumbnailButton(
                        photo: photo,
                        isSelected: selectedPhoto?.id == photo.id,
                        action: {
                            selectedPhoto = photo
                            upscaledImage = nil
                            upscaledDimensions = nil
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("DPI Upscaling")
                .font(.title)
                .fontWeight(.bold)

            Text("Import photos to start upscaling")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoSelectionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Select a photo to upscale")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Helpers

    private var availableSizes: [UpscalingPrintSize] {
        UpscalingPrintSize.allSizes.filter { $0.category == selectedCategory }
    }

    private var currentPrintDimensions: (width: Double, height: Double) {
        if isLandscape {
            return (selectedSize.heightInches, selectedSize.widthInches)
        } else {
            return (selectedSize.widthInches, selectedSize.heightInches)
        }
    }

    private func updateSelectedSize() {
        if let firstSize = availableSizes.first {
            selectedSize = firstSize
        }
    }

    // MARK: - Actions

    private func performUpscale() {
        guard let photo = selectedPhoto else {
            errorMessage = "No photo selected"
            return
        }

        let dims = currentPrintDimensions
        let targetWidth = Int(dims.width * Double(selectedDPI))
        let targetHeight = Int(dims.height * Double(selectedDPI))

        let megapixels = (targetWidth * targetHeight) / 1_000_000
        if megapixels > 500 {
            errorMessage = "Output too large: \(megapixels)MP. Choose smaller size or lower DPI."
            return
        }

        isUpscaling = true
        errorMessage = nil

        Task {
            do {
                let loaded = try await appState.imageLoader.loadImage(for: photo)
                let actualWidth = Int(loaded.image.extent.width)
                let actualHeight = Int(loaded.image.extent.height)

                let scaleX = Double(targetWidth) / Double(actualWidth)
                let scaleY = Double(targetHeight) / Double(actualHeight)
                let scale = max(scaleX, scaleY)

                if scale < 1.0 {
                    await MainActor.run {
                        errorMessage = "Image is already larger than target size. No upscaling needed."
                        isUpscaling = false
                    }
                    return
                }

                let upscaledCIImage = try await appState.dpiUpscaler.upscale(
                    image: loaded.image,
                    scale: CGFloat(scale),
                    method: selectedMethod
                )

                let platformImage = convertToPlatformImage(upscaledCIImage)
                let resultDims = upscaledCIImage.extent.size

                await MainActor.run {
                    upscaledImage = platformImage
                    upscaledDimensions = resultDims
                    isUpscaling = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Upscaling failed: \(error.localizedDescription)"
                    isUpscaling = false
                }
            }
        }
    }

    private func convertToPlatformImage(_ ciImage: CIImage) -> PlatformImage {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            logger.warning("Failed to create CGImage, using fallback render")
            #if canImport(UIKit)
            return UIImage(ciImage: ciImage)
            #elseif canImport(AppKit)
            let bitmapRep = NSBitmapImageRep(ciImage: ciImage)
            let nsImage = NSImage(size: ciImage.extent.size)
            nsImage.addRepresentation(bitmapRep)
            return nsImage
            #endif
        }
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    private func saveUpscaledImage(_ image: PlatformImage) {
        Task {
            do {
                let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
                let outputDir = picturesURL.appendingPathComponent("PhotoCoachPro/Upscaled", isDirectory: true)
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let originalName = selectedPhoto?.fileName.replacingOccurrences(of: " ", with: "_") ?? "image"
                let baseName = URL(fileURLWithPath: originalName).deletingPathExtension().lastPathComponent
                let filename = "\(baseName)_upscaled_\(timestamp).png"
                let fileURL = outputDir.appendingPathComponent(filename)

                #if canImport(UIKit)
                guard let pngData = image.pngData() else {
                    throw NSError(domain: "PhotoCoachPro", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert image to PNG"
                    ])
                }
                #elseif canImport(AppKit)
                guard let tiffData = image.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "PhotoCoachPro", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert image to PNG"
                    ])
                }
                #endif

                try pngData.write(to: fileURL)

                await MainActor.run {
                    errorMessage = "✅ Saved to: \(outputDir.path)"
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        await MainActor.run {
                            if errorMessage?.hasPrefix("✅") == true {
                                errorMessage = nil
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Thumbnail Button

struct ThumbnailButton: View {
    let photo: PhotoRecord
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                #if canImport(UIKit)
                if let platformImage = UIImage(contentsOfFile: photo.fileURL.path) {
                    Image(uiImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                } else {
                    thumbnailPlaceholder
                }
                #elseif canImport(AppKit)
                if let platformImage = NSImage(contentsOfFile: photo.fileURL.path) {
                    Image(nsImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                } else {
                    thumbnailPlaceholder
                }
                #endif
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Print Size Types

enum UpscalingPrintSizeCategory: String, CaseIterable {
    case walletSmall = "wallet_small"
    case standard = "standard"
    case large = "large"
    case largeFormat = "large_format"
    case panoramic = "panoramic"
    case panoramicLarge = "panoramic_large"

    var displayName: String {
        switch self {
        case .walletSmall: return "Wallet & Small"
        case .standard: return "Standard"
        case .large: return "Large"
        case .largeFormat: return "Large Format"
        case .panoramic: return "Panoramic"
        case .panoramicLarge: return "Panoramic Large"
        }
    }
}

struct UpscalingPrintSize: Identifiable, Hashable {
    let id = UUID()
    let widthInches: Double
    let heightInches: Double
    let category: UpscalingPrintSizeCategory

    var displayName: String {
        "\(String(format: "%.1f", widthInches))×\(String(format: "%.1f", heightInches))\""
    }

    static let allSizes: [UpscalingPrintSize] = [
        // Wallet & Small
        UpscalingPrintSize(widthInches: 2.5, heightInches: 3.5, category: .walletSmall),
        UpscalingPrintSize(widthInches: 4, heightInches: 6, category: .walletSmall),
        UpscalingPrintSize(widthInches: 5, heightInches: 7, category: .walletSmall),

        // Standard
        UpscalingPrintSize(widthInches: 8, heightInches: 10, category: .standard),
        UpscalingPrintSize(widthInches: 8.5, heightInches: 11, category: .standard),
        UpscalingPrintSize(widthInches: 11, heightInches: 14, category: .standard),
        UpscalingPrintSize(widthInches: 12, heightInches: 16, category: .standard),
        UpscalingPrintSize(widthInches: 12, heightInches: 18, category: .standard),
        UpscalingPrintSize(widthInches: 16, heightInches: 20, category: .standard),
        UpscalingPrintSize(widthInches: 16, heightInches: 24, category: .standard),
        UpscalingPrintSize(widthInches: 18, heightInches: 24, category: .standard),

        // Large
        UpscalingPrintSize(widthInches: 20, heightInches: 24, category: .large),
        UpscalingPrintSize(widthInches: 20, heightInches: 30, category: .large),
        UpscalingPrintSize(widthInches: 24, heightInches: 30, category: .large),
        UpscalingPrintSize(widthInches: 24, heightInches: 36, category: .large),

        // Large Format
        UpscalingPrintSize(widthInches: 30, heightInches: 40, category: .largeFormat),
        UpscalingPrintSize(widthInches: 36, heightInches: 48, category: .largeFormat),
        UpscalingPrintSize(widthInches: 40, heightInches: 60, category: .largeFormat),
        UpscalingPrintSize(widthInches: 44, heightInches: 60, category: .largeFormat),

        // Panoramic
        UpscalingPrintSize(widthInches: 8, heightInches: 24, category: .panoramic),
        UpscalingPrintSize(widthInches: 10, heightInches: 30, category: .panoramic),
        UpscalingPrintSize(widthInches: 12, heightInches: 36, category: .panoramic),
        UpscalingPrintSize(widthInches: 16, heightInches: 48, category: .panoramic),
        UpscalingPrintSize(widthInches: 20, heightInches: 60, category: .panoramic),

        // Panoramic Large Format
        UpscalingPrintSize(widthInches: 24, heightInches: 72, category: .panoramicLarge),
        UpscalingPrintSize(widthInches: 30, heightInches: 90, category: .panoramicLarge),
        UpscalingPrintSize(widthInches: 36, heightInches: 108, category: .panoramicLarge),
        UpscalingPrintSize(widthInches: 40, heightInches: 120, category: .panoramicLarge),
    ]
}
