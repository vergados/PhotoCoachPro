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

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(photo.aspectRatio, contentMode: .fill)

                // Photo info overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.fileName)
                        .font(.caption)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if photo.isRAW {
                            Text("RAW")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        if let editRecord = photo.editRecord, editRecord.hasEdits {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo: \(photo.fileName)")
        .accessibilityHint("Double tap to open")
    }
}
