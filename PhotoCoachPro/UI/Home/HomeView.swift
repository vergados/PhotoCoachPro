//
//  HomeView.swift
//  PhotoCoachPro
//
//  Main library/home view
//

import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \PhotoRecord.importedDate, order: .reverse) var photos: [PhotoRecord]

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingFilePicker = false
    @State private var showingImportMenu = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor.windowBackgroundColor),
                        Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if photos.isEmpty {
                            emptyState
                        } else {
                            statsBar
                            photoGrid
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Photo Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    importButton
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let tempURL = saveTempFile(data: data) {
                        await appState.importPhoto(from: tempURL)
                    }
                }
            }
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay()
            }
        }
        .overlay {
            if let error = appState.errorMessage {
                ErrorBanner(message: error) {
                    appState.errorMessage = nil
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 32) {
            // Modern icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Your Photo Library Awaits")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Import your first photo to unlock AI-powered editing,\nprofessional presets, and expert coaching")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            importButton
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "photo.stack",
                value: "\(photos.count)",
                label: "Photos",
                color: .blue
            )

            StatCard(
                icon: "wand.and.stars",
                value: "\(photos.filter { $0.editRecord != nil }.count)",
                label: "Edited",
                color: .purple
            )

            StatCard(
                icon: "star.fill",
                value: "0",
                label: "Favorites",
                color: .orange
            )
        }
        .padding(.horizontal, 20)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(photos) { photo in
                PhotoGridItem(photo: photo) {
                    Task {
                        await appState.openPhoto(photo)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var importButton: some View {
        Menu {
            Button(action: { showingFilePicker = true }) {
                Label("From Files...", systemImage: "folder")
            }

            #if os(iOS)
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("From Photos", systemImage: "photo.on.rectangle")
            }
            #endif
        } label: {
            Label("Import Photo", systemImage: "plus.circle.fill")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .jpeg, .png, .heic, .rawImage],
            allowsMultipleSelection: false
        ) { result in
            print("🔵 File importer callback triggered")
            Task {
                switch result {
                case .success(let urls):
                    print("🔵 File picker success: \(urls.count) files")
                    if let url = urls.first {
                        print("🔵 Selected file: \(url.lastPathComponent)")
                        // Get access to security-scoped resource
                        let accessGranted = url.startAccessingSecurityScopedResource()
                        print("🔵 Security access granted: \(accessGranted)")
                        defer { url.stopAccessingSecurityScopedResource() }

                        await appState.importPhoto(from: url)
                    } else {
                        print("❌ No file in URLs array")
                    }
                case .failure(let error):
                    print("❌ File picker error: \(error)")
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        #if os(iOS)
        [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)]
        #else
        [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)]
        #endif
    }

    // MARK: - Helpers

    private func saveTempFile(data: Data) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        try? data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Modern Stat Card Component

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}
