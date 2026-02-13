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
        #if os(iOS)
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }
                .tag(AppState.AppTab.home)

            if appState.currentPhoto != nil {
                EditorView()
                    .tabItem {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    .tag(AppState.AppTab.editor)
            }
        }
        #elseif os(macOS)
        NavigationSplitView {
            List(selection: $appState.selectedTab) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .tag(AppState.AppTab.home)

                if appState.currentPhoto != nil {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .tag(AppState.AppTab.editor)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200)
        } detail: {
            switch appState.selectedTab {
            case .home:
                HomeView()
            case .editor:
                EditorView()
            case .export:
                Text("Export")
            }
        }
        #endif
    }
}
