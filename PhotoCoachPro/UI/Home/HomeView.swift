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
    @State private var showPhotosPicker = false
    @State private var showSettings = false
    @ObservedObject private var privacySettings = PrivacySettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if photos.isEmpty {
                        emptyState
                    } else {
                        if privacySettings.cloudSyncEnabled {
                            SyncStatusView()
                                .padding(.horizontal)
                        }
                        statsBar
                        photoGrid
                    }
                }
                .padding(.top, 20)
            }
            .background(DS.bg)
            .navigationTitle("Photo Library")
            #if os(iOS)
            .toolbarBackground(DS.bgRaised, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    importButton
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(DS.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SyncSettingsView()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self) else { return }
                        await appState.importPhotoFromPickerData(data)
                    } catch {
                        appState.errorMessage = "Failed to load photo: \(error.localizedDescription)"
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
            ZStack {
                Circle()
                    .fill(DS.accentDim)
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(DS.accent)
            }

            VStack(spacing: 10) {
                Text("Photo Library")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)

                Text("Import your first photo to unlock AI-powered editing,\nprofessional presets, and expert coaching")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            importButton
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "photo.stack",
                value: "\(photos.count)",
                label: "Photos"
            )

            StatCard(
                icon: "wand.and.stars",
                value: "\(photos.filter { $0.editRecord != nil }.count)",
                label: "Edited"
            )

            StatCard(
                icon: "star.fill",
                value: "\(photos.filter { $0.isFavorite }.count)",
                label: "Favorites"
            )
        }
        .padding(.horizontal, 20)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(photos) { photo in
                PhotoGridItem(photo: photo) {
                    Task {
                        await appState.openPhoto(photo)
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deletePhoto(photo)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func deletePhoto(_ photo: PhotoRecord) {
        // Remove the sandboxed file if this photo was imported by data copy
        if photo.resolvedSourceType == .fileSystem, !photo.filePath.isEmpty {
            try? FileManager.default.removeItem(at: photo.fileURL)
        }
        try? appState.database.deletePhoto(photo)
    }

    private var importButton: some View {
        Menu {
            Button(action: { showingFilePicker = true }) {
                Label("From Files...", systemImage: "folder")
            }

            #if os(iOS)
            Button(action: { showPhotosPicker = true }) {
                Label("From Photos", systemImage: "photo.on.rectangle")
            }
            #endif
        } label: {
            Label("Import Photo", systemImage: "plus.circle.fill")
        }
        #if os(iOS)
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .jpeg, .png, .heic, .rawImage],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let accessGranted = url.startAccessingSecurityScopedResource()
                        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

                        #if os(macOS)
                        let bookmarkData = try? url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #else
                        let bookmarkData = try? url.bookmarkData(
                            options: [],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #endif

                        await appState.importPhotoFromFileSystem(url: url, bookmarkData: bookmarkData)
                    }
                case .failure(let error):
                    await MainActor.run {
                        appState.errorMessage = "Failed to import photo: \(error.localizedDescription)"
                    }
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
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.accent)

            Text(value)
                .dsValue()

            Text(label)
                .dsLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .dsCard()
    }
}
