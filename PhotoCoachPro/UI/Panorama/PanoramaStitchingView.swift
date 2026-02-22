//
//  PanoramaStitchingView.swift
//  PhotoCoachPro
//
//  Panorama stitching interface
//

import SwiftUI
import SwiftData
import CoreImage

struct PanoramaStitchingView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \PhotoRecord.importedDate, order: .reverse) var photos: [PhotoRecord]

    @State private var selectedPhotos: Set<UUID> = []
    @State private var selectedPhotosOrdered: [UUID] = [] // Track insertion order
    @State private var isStitching = false
    @State private var stitchedImage: CIImage?
    @State private var errorMessage: String?
    @State private var blendWidth: Double = 100
    @State private var projectionMode: ProjectionMode = .cylindrical
    @State private var photoRotations: [UUID: Double] = [:] // Rotation in degrees
    @State private var showRotationControls = false
    @State private var useExposureBlending = true

    private let stitcher = PanoramaStitcher()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if photos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        // Instructions
                        instructionsBanner

                        // Photo selection grid
                        photoSelectionView

                        // Controls
                        controlsPanel

                        // Preview
                        if let stitched = stitchedImage {
                            previewPanel(stitched)
                        }
                    }
                }
            }
            .navigationTitle("Panorama Stitching")
            .overlay {
                if isStitching {
                    LoadingOverlay()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 32) {
            Image(systemName: "panorama")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Panorama Stitching")
                .font(.title)
                .fontWeight(.bold)

            Text("Import photos first to create panoramic images")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var instructionsBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Select 2 or more photos in left-to-right order")
                    .font(.subheadline)

                Spacer()

                Text("\(selectedPhotos.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            if selectedPhotos.count >= 2 {
                Text("Tip: Photos should have overlapping content for best results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var photoSelectionView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(photos) { photo in
                    PhotoSelectionCard(
                        photo: photo,
                        isSelected: selectedPhotos.contains(photo.id),
                        selectionOrder: selectedPhotosOrdered.firstIndex(of: photo.id).map { $0 + 1 }
                    ) {
                        toggleSelection(photo)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Projection mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Projection Mode")
                    .font(.subheadline)

                Picker("Projection", selection: $projectionMode) {
                    Text("Planar (Flat)").tag(ProjectionMode.planar)
                    Text("Cylindrical (Wide)").tag(ProjectionMode.cylindrical)
                }
                .pickerStyle(.segmented)

                Text(projectionMode == .cylindrical ?
                     "Best for wide panoramas - prevents bowing" :
                     "Standard flat projection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Blend width slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blend Width")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(blendWidth))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $blendWidth, in: 50...300, step: 10)
            }

            // Exposure blending toggle
            Toggle(isOn: $useExposureBlending) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exposure Blending")
                        .font(.subheadline)
                    Text("Automatically balance brightness across seams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Rotation controls toggle
            if selectedPhotos.count >= 2 {
                Button(action: { showRotationControls.toggle() }) {
                    Label(showRotationControls ? "Hide Rotation Controls" : "Show Rotation Controls",
                          systemImage: showRotationControls ? "chevron.up" : "chevron.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Rotation sliders (if enabled)
            if showRotationControls && selectedPhotos.count >= 2 {
                rotationControlsSection
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: clearSelection) {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedPhotos.isEmpty)

                Button(action: autoStitchPanorama) {
                    Label("Auto Stitch", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPhotos.count < 2)
                .help("Automatically stitch with smart defaults")

                Button(action: stitchPanorama) {
                    Label("Manual Stitch", systemImage: "panorama")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedPhotos.count < 2)
                .help("Stitch with current settings")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var rotationControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fine-tune Rotation")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(selectedPhotosOrdered, id: \.self) { photoID in
                if let photo = photos.first(where: { $0.id == photoID }),
                   let order = selectedPhotosOrdered.firstIndex(of: photoID) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Image \(order + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(photoRotations[photoID] ?? 0, specifier: "%.1f")°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()

                            Button(action: {
                                photoRotations[photoID] = 0
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        Slider(
                            value: Binding(
                                get: { photoRotations[photoID] ?? 0 },
                                set: { photoRotations[photoID] = $0 }
                            ),
                            in: -5...5,
                            step: 0.1
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func previewPanel(_ image: CIImage) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)

                Spacer()

                Button(action: savePanorama) {
                    Label("Save to Library", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }

            // Image preview
            CIImagePreview(ciImage: image)
                .frame(height: 300)
                .background(Color.black.opacity(0.1))
                .cornerRadius(12)

            // Info
            HStack {
                Label("\(Int(image.extent.width)) × \(Int(image.extent.height))", systemImage: "aspectratio")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func toggleSelection(_ photo: PhotoRecord) {
        if selectedPhotos.contains(photo.id) {
            selectedPhotos.remove(photo.id)
            selectedPhotosOrdered.removeAll { $0 == photo.id }
        } else {
            selectedPhotos.insert(photo.id)
            selectedPhotosOrdered.append(photo.id)
        }
    }

    private func clearSelection() {
        selectedPhotos.removeAll()
        selectedPhotosOrdered.removeAll()
        stitchedImage = nil
    }

    private func autoStitchPanorama() {
        Task {
            isStitching = true
            errorMessage = nil

            do {
                // Get selected photos and auto-order by capture time
                let selectedPhotoRecords = photos.filter { selectedPhotos.contains($0.id) }
                let orderedPhotos = selectedPhotoRecords.sorted { photo1, photo2 in
                    // Sort by EXIF capture time if available, otherwise by import date
                    let date1 = photo1.createdDate
                    let date2 = photo2.createdDate
                    return date1 < date2
                }

                print("🤖 Auto-stitching \(orderedPhotos.count) photos")
                print("   Order: \(orderedPhotos.map { $0.fileName }.joined(separator: " → "))")

                // Load images (no rotation for auto mode)
                var images: [CIImage] = []
                for photo in orderedPhotos {
                    let loaded = try await appState.imageLoader.load(from: photo.fileURL)
                    images.append(loaded.image)
                }

                // Stitch with smart defaults
                let stitched = try await stitcher.stitch(
                    images: images,
                    blendWidth: 100,  // Good default
                    projectionMode: .cylindrical,  // Best for panoramas
                    useExposureBlending: true  // Always blend exposure
                )

                await MainActor.run {
                    stitchedImage = stitched
                    isStitching = false
                    print("✅ Auto-stitch complete: \(Int(stitched.extent.width))×\(Int(stitched.extent.height))")
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Auto-stitch failed: \(error.localizedDescription)"
                    isStitching = false
                }
            }
        }
    }

    private func stitchPanorama() {
        Task {
            isStitching = true
            errorMessage = nil

            do {
                // Get selected photos in order (manual selection order)
                let orderedPhotos = selectedPhotosOrdered.compactMap { id in
                    photos.first(where: { $0.id == id })
                }

                // Load images and apply rotations
                var images: [CIImage] = []
                for photo in orderedPhotos {
                    var loaded = try await appState.imageLoader.load(from: photo.fileURL)
                    var image = loaded.image

                    // Apply rotation if specified
                    if let rotation = photoRotations[photo.id], rotation != 0 {
                        let radians = rotation * .pi / 180.0
                        image = image.transformed(by: CGAffineTransform(rotationAngle: radians))
                        print("  🔄 Rotated image \(photo.id) by \(rotation)°")
                    }

                    images.append(image)
                }

                // Stitch
                let stitched = try await stitcher.stitch(
                    images: images,
                    blendWidth: blendWidth,
                    projectionMode: projectionMode,
                    useExposureBlending: useExposureBlending
                )

                await MainActor.run {
                    stitchedImage = stitched
                    isStitching = false
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isStitching = false
                }
            }
        }
    }

    private func savePanorama() {
        guard let image = stitchedImage else { return }

        Task {
            do {
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")

                // Render to JPEG
                let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
                try context.writeJPEGRepresentation(
                    of: image,
                    to: tempURL,
                    colorSpace: colorSpace,
                    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
                )

                // Import as new photo (no security-scoped bookmark needed for app-generated temp files)
                await appState.importPhotoFromFileSystem(url: tempURL, bookmarkData: nil)

                // Clear state
                await MainActor.run {
                    clearSelection()
                    appState.selectedTab = .home
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save panorama: \(error.localizedDescription)"
                }
            }
        }
    }

    private let context = CIContext()
}

// MARK: - Photo Selection Card

private struct PhotoSelectionCard: View {
    @EnvironmentObject var appState: AppState
    let photo: PhotoRecord
    let isSelected: Bool
    let selectionOrder: Int?
    let action: () -> Void

    @State private var thumbnail: CGImage?
    @State private var isLoading = true

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                Group {
                    if let thumb = thumbnail {
                        #if os(macOS)
                        Image(decorative: thumb, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        #else
                        Image(uiImage: UIImage(cgImage: thumb))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        #endif
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                }
                            }
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .clipped()

                // Selection indicator
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)

                        if let order = selectionOrder {
                            Text("\(order)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                    .shadow(radius: 2)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoading = true

        do {
            // Load image at thumbnail size
            let loaded = try await appState.imageLoader.load(from: photo.fileURL)

            // Scale image down to thumbnail size
            let thumbnailSize = CGSize(width: 300, height: 300) // 2x for retina
            let scale = min(thumbnailSize.width / loaded.image.extent.width,
                          thumbnailSize.height / loaded.image.extent.height)
            let scaledImage = loaded.image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            // Render to CGImage
            if let cgImage = await appState.imageRenderer.renderCGImage(from: scaledImage) {
                await MainActor.run {
                    self.thumbnail = cgImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("⚠️ Failed to load thumbnail for \(photo.fileURL.lastPathComponent): \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - CIImage Preview Helper

private struct CIImagePreview: View {
    @EnvironmentObject var appState: AppState
    let ciImage: CIImage

    @State private var renderedImage: CGImage?

    var body: some View {
        Group {
            if let rendered = renderedImage {
                #if os(macOS)
                Image(decorative: rendered, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: rendered))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .task {
            await renderImage()
        }
    }

    private func renderImage() async {
        // Scale to reasonable preview size
        let maxDimension: CGFloat = 2000
        let scale = min(1.0, maxDimension / max(ciImage.extent.width, ciImage.extent.height))
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        if let cgImage = await appState.imageRenderer.renderCGImage(from: scaledImage) {
            await MainActor.run {
                self.renderedImage = cgImage
            }
        }
    }
}
