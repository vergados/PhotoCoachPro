//
//  ShareView.swift
//  PhotoCoachPro
//
//  iOS share sheet integration
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Share exported photos using iOS share sheet
struct ShareView: View {
    let photoRecord: PhotoRecord
    @State private var settings = ExportSettings.socialMedia
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var showSettings = false
    @State private var exportError: Error?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isExporting {
                    exportingView
                } else {
                    readyView
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showSettings = true
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(isPresented: $showSettings) {
                ExportOptionsView(
                    settings: $settings,
                    onExport: { _ in }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ActivityViewController(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("Share Photo")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(photoRecord.fileName)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 40)

            // Quick share presets
            quickPresetsSection

            Spacer()

            // Share button
            Button(action: startExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Exporting View

    private var exportingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Preparing to share...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Quick Presets

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Share Options")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SharePresetCard(
                        title: "Social Media",
                        icon: "heart.circle",
                        description: "Instagram, Facebook",
                        isSelected: settings.name == "Social Media"
                    ) {
                        settings = .socialMedia
                    }

                    SharePresetCard(
                        title: "Messages",
                        icon: "message",
                        description: "iMessage, WhatsApp",
                        isSelected: settings.name == "Web Optimized"
                    ) {
                        settings = .webOptimized
                    }

                    SharePresetCard(
                        title: "Email",
                        icon: "envelope",
                        description: "Smaller file size",
                        isSelected: settings.name == "Web Optimized"
                    ) {
                        settings = .webOptimized
                    }

                    SharePresetCard(
                        title: "Full Quality",
                        icon: "photo",
                        description: "Maximum quality",
                        isSelected: settings.format == .png && settings.quality == .maximum
                    ) {
                        settings = .archival
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Actions

    private func startExport() {
        isExporting = true

        Task {
            do {
                // Create temporary output URL
                let tempDir = FileManager.default.temporaryDirectory
                let filename = photoRecord.fileName.replacingOccurrences(of: ".", with: "_")
                let outputURL = tempDir.appendingPathComponent("\(filename).\(settings.format.fileExtension)")

                // Simulate export (replace with actual ExportEngine call)
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

                // Store exported URL
                exportedURL = outputURL
                isExporting = false

                // Show share sheet
                showShareSheet = true
            } catch {
                exportError = error
                isExporting = false
            }
        }
    }
}

// MARK: - Share Preset Card

private struct SharePresetCard: View {
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(width: 140, height: 100)
            .padding()
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    var activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: activities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// MARK: - Preview

#Preview {
    ShareView(
        photoRecord: PhotoRecord(
            filePath: "/path/to/photo.jpg",
            fileName: "sunset.jpg",
            fileSize: 5000000,
            width: 4000,
            height: 3000,
            format: "JPEG",
            colorSpace: "sRGB",
            captureDate: Date()
        )
    )
}
