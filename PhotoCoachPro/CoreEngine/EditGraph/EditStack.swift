//
//  EditStack.swift
//  PhotoCoachPro
//
//  Ordered list of edit instructions with undo/redo support
//

import Foundation

/// Ordered list of instructions with undo/redo capability
struct EditStack: Codable, Equatable {
    private(set) var instructions: [EditInstruction]
    private(set) var currentIndex: Int  // Points to last applied instruction

    init(instructions: [EditInstruction] = []) {
        self.instructions = instructions
        self.currentIndex = instructions.count - 1
    }

    // MARK: - Queries

    /// Instructions currently applied (up to currentIndex)
    var activeInstructions: [EditInstruction] {
        guard currentIndex >= 0 else { return [] }
        return Array(instructions[0...currentIndex])
    }

    var canUndo: Bool {
        currentIndex >= 0
    }

    var canRedo: Bool {
        currentIndex < instructions.count - 1
    }

    var isEmpty: Bool {
        instructions.isEmpty
    }

    // MARK: - Mutations

    /// Add new instruction (discards any redo history)
    mutating func add(_ instruction: EditInstruction) {
        // Remove any instructions after current index (they were undone)
        if currentIndex < instructions.count - 1 {
            instructions = Array(instructions[0...currentIndex])
        }

        instructions.append(instruction)
        currentIndex = instructions.count - 1
    }

    /// Update existing instruction by ID
    mutating func update(_ instruction: EditInstruction) {
        guard let index = instructions.firstIndex(where: { $0.id == instruction.id }) else {
            return
        }
        instructions[index] = instruction
    }

    /// Remove instruction by ID
    mutating func remove(id: UUID) {
        instructions.removeAll { $0.id == id }
        currentIndex = min(currentIndex, instructions.count - 1)
    }

    /// Undo last instruction
    mutating func undo() {
        guard canUndo else { return }
        currentIndex -= 1
    }

    /// Redo next instruction
    mutating func redo() {
        guard canRedo else { return }
        currentIndex += 1
    }

    /// Clear all instructions
    mutating func clear() {
        instructions.removeAll()
        currentIndex = -1
    }

    /// Replace entire stack (for preset application)
    mutating func replace(with newInstructions: [EditInstruction]) {
        instructions = newInstructions
        currentIndex = newInstructions.count - 1
    }

    // MARK: - Batch Operations

    /// Find most recent instruction of given type
    func mostRecent(ofType type: EditInstruction.EditType) -> EditInstruction? {
        activeInstructions.last { $0.type == type }
    }

    /// Get all active instructions of given type
    func all(ofType type: EditInstruction.EditType) -> [EditInstruction] {
        activeInstructions.filter { $0.type == type }
    }

    /// Get current value for instruction type (or default if not present)
    func currentValue(for type: EditInstruction.EditType) -> Double {
        mostRecent(ofType: type)?.value ?? type.defaultValue
    }
}

// MARK: - Edit History for UI
extension EditStack {
    struct HistoryItem: Identifiable {
        let id: UUID
        let type: EditInstruction.EditType
        let value: Double
        let timestamp: Date
        let isActive: Bool
    }

    var historyItems: [HistoryItem] {
        instructions.enumerated().map { index, instruction in
            HistoryItem(
                id: instruction.id,
                type: instruction.type,
                value: instruction.value,
                timestamp: instruction.timestamp,
                isActive: index <= currentIndex
            )
        }
    }
}
