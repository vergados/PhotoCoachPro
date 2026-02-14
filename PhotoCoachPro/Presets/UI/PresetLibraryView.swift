//
//  PresetLibraryView.swift
//  PhotoCoachPro
//
//  Browse and manage presets
//

import SwiftUI

/// Browse preset library
struct PresetLibraryView: View {
    @State private var presets: [Preset] = []
    @State private var selectedCategory: Preset.PresetCategory? = nil
    @State private var searchQuery = ""
    @State private var showFavoritesOnly = false
    @State private var selectedPreset: Preset? = nil
    @State private var isLoading = true

    private let manager = PresetManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filters
                searchAndFilters

                // Presets grid
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPresets.isEmpty {
                    emptyState
                } else {
                    presetsGrid
                }
            }
            .navigationTitle("Presets")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button(action: { }) {
                            Label("Import Preset", systemImage: "square.and.arrow.down")
                        }

                        Button(action: { }) {
                            Label("Create Preset", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await loadPresets()
            }
        }
    }

    // MARK: - Search and Filters

    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search presets", text: $searchQuery)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil,
                        count: presets.count
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(Preset.PresetCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            count: presets.filter { $0.category == category }.count
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Favorites toggle
            Toggle(isOn: $showFavoritesOnly) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Favorites Only")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Presets Grid

    private var presetsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(filteredPresets) { preset in
                    PresetCard(preset: preset) {
                        selectedPreset = preset
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedPreset) { preset in
            PresetDetailView(preset: preset)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Presets Found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { searchQuery = ""; selectedCategory = nil; showFavoritesOnly = false }) {
                Text("Clear Filters")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateMessage: String {
        if showFavoritesOnly {
            return "You haven't favorited any presets yet."
        } else if !searchQuery.isEmpty {
            return "No presets match your search."
        } else if selectedCategory != nil {
            return "No presets in this category."
        } else {
            return "No presets available."
        }
    }

    // MARK: - Filtered Presets

    private var filteredPresets: [Preset] {
        var filtered = presets

        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }

        // Filter by favorites
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { preset in
                preset.name.lowercased().contains(query) ||
                preset.tags.contains { $0.lowercased().contains(query) } ||
                preset.category.rawValue.lowercased().contains(query)
            }
        }

        return filtered
    }

    // MARK: - Load Presets

    private func loadPresets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            presets = try await manager.fetchAll()
        } catch {
            print("Failed to load presets: \(error)")
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: Preset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail placeholder
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1.0, contentMode: .fit)

                    Image(systemName: preset.category.icon)
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                .cornerRadius(12)

                // Preset info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Spacer()

                        if preset.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }

                    Text(preset.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack {
                        if preset.isBuiltIn {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }

                        Text("\(preset.instructionCount) edits")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        if preset.usageCount > 0 {
                            Text("\(preset.usageCount) uses")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PresetLibraryView()
}
