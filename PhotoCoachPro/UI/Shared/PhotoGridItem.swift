//
//  PhotoGridItem.swift
//  PhotoCoachPro
//
//  Reusable photo grid thumbnail cell
//

import SwiftUI

struct PhotoGridItem: View {
    let photo: PhotoRecord
    let onTap: () -> Void

    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail image or placeholder
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Loading placeholder
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.15),
                                    Color.gray.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(photo.aspectRatio, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundStyle(.secondary.opacity(0.3))
                        )
                }

                // Photo info overlay with glassmorphism
                VStack(alignment: .leading, spacing: 6) {
                    Text(photo.fileName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if photo.isRAW {
                            Text("RAW")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.9))
                                )
                        }

                        if let editRecord = photo.editRecord, editRecord.hasEdits {
                            Image(systemName: "wand.and.stars.inverse")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.9))
                                )
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.7),
                            .black.opacity(0.3),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: Color.black.opacity(isHovering ? 0.15 : 0.08),
                radius: isHovering ? 12 : 8,
                x: 0,
                y: isHovering ? 6 : 4
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .task {
            await loadThumbnail()
        }
        .accessibilityLabel("Photo: \(photo.fileName)")
        .accessibilityHint("Double tap to open")
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() async {
        do {
            // Load image
            let loaded = try await appState.imageLoader.load(from: photo.fileURL)

            // Generate thumbnail
            let cacheKey = ThumbnailCache.CacheKey(photoID: photo.id, editStack: [])
            if let thumb = await appState.thumbnailCache.generateThumbnail(from: loaded.image, for: cacheKey) {
                await MainActor.run {
                    self.thumbnail = thumb
                }
            }
        } catch {
            print("Failed to load thumbnail for \(photo.fileName): \(error)")
        }
    }
}
