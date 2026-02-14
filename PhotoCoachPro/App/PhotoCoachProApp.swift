//
//  PhotoCoachProApp.swift
//  PhotoCoachPro
//
//  Main app entry point
//

import SwiftUI
import SwiftData

@main
struct PhotoCoachProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(appState.database.container)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Photo...") {
                    // File picker will be handled in UI
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
        #endif
    }
}

// MARK: - Content View (Main Navigation)
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Library
            HomeView()
                .tabItem {
                    Label("Library", systemImage: "photo.stack")
                }
                .tag(AppState.AppTab.home)

            // Editor (opens when photo selected)
            EditorView()
                .tabItem {
                    Label("Editor", systemImage: "slider.horizontal.3")
                }
                .tag(AppState.AppTab.editor)

            // Presets & Templates
            PresetLibraryView()
                .tabItem {
                    Label("Presets", systemImage: "photo.stack.fill")
                }
                .tag(AppState.AppTab.presets)

            // AI Coaching
            CritiqueDashboardView()
                .tabItem {
                    Label("Coaching", systemImage: "star.fill")
                }
                .tag(AppState.AppTab.coaching)
        }
    }
}

// MARK: - Critique Dashboard

struct CritiqueDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \PhotoRecord.importedDate, order: .reverse) var photos: [PhotoRecord]

    @State private var selectedPhoto: PhotoRecord?
    @State private var critiqueResult: CritiqueResult?
    @State private var isAnalyzing = false
    @State private var analyzer = ImageAnalyzer()

    var body: some View {
        NavigationStack {
            if let result = critiqueResult, let photo = selectedPhoto {
                CritiqueResultView(critique: result)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Analyze Another") {
                                critiqueResult = nil
                                selectedPhoto = nil
                            }
                        }
                    }
            } else if photos.isEmpty {
                emptyState
            } else {
                photoSelectionView
            }
        }
        .overlay {
            if isAnalyzing {
                LoadingOverlay()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("AI Photo Coaching")
                .font(.title)
                .fontWeight(.bold)

            Text("Import photos first to get AI-powered critique and improvement suggestions")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 60)
        .navigationTitle("AI Coaching")
    }

    private var photoSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a photo to analyze (\(photos.count) photos)")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)], spacing: 16) {
                    ForEach(photos) { photo in
                        Button(action: {
                            analyzePhoto(photo)
                        }) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                Text(photo.fileName)
                                    .font(.caption)
                            }
                            .frame(width: 200, height: 200)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("AI Coaching")
    }

    private func analyzePhoto(_ photo: PhotoRecord) {
        selectedPhoto = photo
        isAnalyzing = true

        Task {
            do {
                let loaded = try await appState.imageLoader.load(from: photo.fileURL)
                let result = try await analyzer.analyze(loaded.image, photoID: photo.id)

                let record = try CritiqueRecord.from(result)
                try appState.database.saveCritique(record)

                await MainActor.run {
                    critiqueResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    isAnalyzing = false
                    selectedPhoto = nil
                }
            }
        }
    }
}
