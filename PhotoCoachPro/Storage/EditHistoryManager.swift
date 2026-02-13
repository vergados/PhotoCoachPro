//
//  EditHistoryManager.swift
//  PhotoCoachPro
//
//  Manages edit history persistence and undo/redo
//

import Foundation

/// Manages edit history for a photo
@MainActor
class EditHistoryManager: ObservableObject {
    @Published private(set) var editRecord: EditRecord

    private let database: LocalDatabase

    init(editRecord: EditRecord, database: LocalDatabase = .shared) {
        self.editRecord = editRecord
        self.database = database
    }

    // MARK: - Current State

    var editStack: EditStack {
        editRecord.editStack
    }

    var canUndo: Bool {
        editStack.canUndo
    }

    var canRedo: Bool {
        editStack.canRedo
    }

    var hasEdits: Bool {
        !editStack.isEmpty
    }

    // MARK: - Mutations

    func addInstruction(_ instruction: EditInstruction) {
        var stack = editRecord.editStack
        stack.add(instruction)
        editRecord.editStack = stack
        save()
    }

    func updateInstruction(_ instruction: EditInstruction) {
        var stack = editRecord.editStack
        stack.update(instruction)
        editRecord.editStack = stack
        save()
    }

    func removeInstruction(id: UUID) {
        var stack = editRecord.editStack
        stack.remove(id: id)
        editRecord.editStack = stack
        save()
    }

    func undo() {
        var stack = editRecord.editStack
        stack.undo()
        editRecord.editStack = stack
        save()
    }

    func redo() {
        var stack = editRecord.editStack
        stack.redo()
        editRecord.editStack = stack
        save()
    }

    func clearAll() {
        var stack = editRecord.editStack
        stack.clear()
        editRecord.editStack = stack
        save()
    }

    // MARK: - Presets

    func applyPreset(_ preset: EditPreset) {
        var stack = editRecord.editStack
        stack.replace(with: preset.instructions)
        editRecord.editStack = stack
        save()
    }

    func copySettings() -> [EditInstruction] {
        editStack.activeInstructions
    }

    func pasteSettings(_ instructions: [EditInstruction]) {
        var stack = editRecord.editStack
        stack.replace(with: instructions)
        editRecord.editStack = stack
        save()
    }

    // MARK: - Queries

    func currentValue(for type: EditInstruction.EditType) -> Double {
        editStack.currentValue(for: type)
    }

    func hasInstruction(ofType type: EditInstruction.EditType) -> Bool {
        editStack.mostRecent(ofType: type) != nil
    }

    // MARK: - Persistence

    private func save() {
        do {
            try database.context.save()
        } catch {
            print("Failed to save edit history: \(error)")
        }
    }

    // MARK: - Reset

    func resetToOriginal() {
        clearAll()
    }
}
