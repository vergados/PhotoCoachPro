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

    var body: some View {
        NavigationStack {
            ScrollView {
                if photos.isEmpty {
                    emptyState
                } else {
                    photoGrid
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
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("No Photos")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import photos to get started")
                .foregroundStyle(.secondary)

            importButton
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var photoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(photos) { photo in
                PhotoGridItem(photo: photo) {
                    Task {
                        await appState.openPhoto(photo)
                    }
                }
            }
        }
        .padding()
    }

    private var importButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Import", systemImage: "plus")
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
