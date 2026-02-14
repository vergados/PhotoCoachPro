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
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Phase 1: Photo Library & Editor
            HomeView()
                .tabItem {
                    Label("Library", systemImage: "photo.stack")
                }
                .tag(0)

            // Phase 4: Presets & Templates
            PresetLibraryView()
                .tabItem {
                    Label("Presets", systemImage: "photo.stack.fill")
                }
                .tag(1)

            // Phase 3: AI Coaching
            CritiqueDashboardView()
                .tabItem {
                    Label("Coaching", systemImage: "star.fill")
                }
                .tag(2)

            // Phase 5: Cloud Sync
            SyncStatusView()
                .tabItem {
                    Label("Sync", systemImage: "icloud")
                }
                .tag(3)
        }
    }
}

// MARK: - Critique Dashboard (Placeholder for Phase 3)

struct CritiqueDashboardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("AI Photo Coaching")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Select a photo from your library to get AI-powered critique and improvement suggestions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.top, 60)
            .navigationTitle("AI Coaching")
        }
    }
}
