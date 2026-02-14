//
//  SavePresetView.swift
//  PhotoCoachPro
//
//  Save current edits as preset
//

import SwiftUI

/// Save current edit stack as preset
struct SavePresetView: View {
    let editRecord: EditRecord
    @State private var presetName = ""
    @State private var category: Preset.PresetCategory = .custom
    @State private var presetDescription = ""
    @State private var tags = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    private let manager = PresetManager()

    var body: some View {
        NavigationStack {
            Form {
                // Name section
                Section {
                    TextField("Preset Name", text: $presetName)
                        .autocorrectionDisabled()

                    Picker("Category", selection: $category) {
                        ForEach(Preset.PresetCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                } header: {
                    Text("Basic Information")
                }

                // Description section
                Section {
                    ZStack(alignment: .topLeading) {
                        if presetDescription.isEmpty {
                            Text("Describe this preset...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }

                        TextEditor(text: $presetDescription)
                            .frame(minHeight: 80)
                    }

                    TextField("Tags (comma separated)", text: $tags)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                } header: {
                    Text("Description & Tags")
                } footer: {
                    Text("Tags help you find this preset later. Separate with commas.")
                }

                // Preview section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)

                            Text("\(editRecord.editStack.activeInstructions.count) adjustments")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !editRecord.editStack.activeInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(editRecord.editStack.activeInstructions.prefix(5)) { instruction in
                                    HStack {
                                        Text(instruction.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text(String(format: "%+.2f", instruction.value))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }

                                if editRecord.editStack.activeInstructions.count > 5 {
                                    Text("+ \(editRecord.editStack.activeInstructions.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Adjustments Preview")
                }

                // Validation section
                Section {
                    validationView
                }
            }
            .navigationTitle("Save Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await savePreset()
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Validation View

    private var validationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presetName.isEmpty {
                ValidationRow(
                    icon: "xmark.circle.fill",
                    message: "Preset name is required",
                    isError: true
                )
            } else {
                ValidationRow(
                    icon: "checkmark.circle.fill",
                    message: "Preset name is valid",
                    isError: false
                )
            }

            if editRecord.editStack.activeInstructions.isEmpty {
                ValidationRow(
                    icon: "exclamationmark.triangle.fill",
                    message: "No adjustments to save",
                    isError: true
                )
            } else {
                ValidationRow(
                    icon: "checkmark.circle.fill",
                    message: "\(editRecord.editStack.activeInstructions.count) adjustments ready",
                    isError: false
                )
            }

            // Duplicate type warning
            let duplicateTypes = Dictionary(grouping: editRecord.editStack.activeInstructions, by: { $0.type })
                .filter { $0.value.count > 1 }

            if !duplicateTypes.isEmpty {
                ValidationRow(
                    icon: "exclamationmark.triangle.fill",
                    message: "Duplicate edit types detected",
                    isError: false
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var canSave: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editRecord.editStack.activeInstructions.isEmpty
    }

    private var parsedTags: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Save Preset

    private func savePreset() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let preset = try await manager.createFromEditRecord(
                editRecord,
                name: presetName.trimmingCharacters(in: .whitespaces),
                category: category,
                description: presetDescription.isEmpty ? nil : presetDescription,
                tags: parsedTags
            )

            print("Saved preset: \(preset.name)")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Validation Row

private struct ValidationRow: View {
    let icon: String
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isError ? .red : .green)
                .font(.caption)

            Text(message)
                .font(.caption)
                .foregroundColor(isError ? .red : .secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    var graph = EditGraph()
    graph.activeStack.add(EditInstruction(type: .exposure, value: 0.5))
    graph.activeStack.add(EditInstruction(type: .contrast, value: 0.3))
    graph.activeStack.add(EditInstruction(type: .saturation, value: 0.2))

    return SavePresetView(editRecord: EditRecord(
        photoID: UUID(),
        editGraph: graph
    ))
}
