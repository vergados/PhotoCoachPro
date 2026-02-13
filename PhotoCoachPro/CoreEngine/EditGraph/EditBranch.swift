//
//  EditBranch.swift
//  PhotoCoachPro
//
//  Branch support for non-linear editing
//

import Foundation

/// Branch in the edit graph (for advanced non-linear editing)
struct EditBranch: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var parentBranchID: UUID?
    var branchPointIndex: Int          // Index in parent where this branch diverges
    var stack: EditStack
    var createdDate: Date
    var modifiedDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        parentBranchID: UUID? = nil,
        branchPointIndex: Int = 0,
        stack: EditStack = EditStack(),
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentBranchID = parentBranchID
        self.branchPointIndex = branchPointIndex
        self.stack = stack
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
}

/// Multi-branch edit graph (Phase 1: simplified to single branch)
struct EditGraph: Codable, Equatable {
    private(set) var branches: [EditBranch]
    private(set) var activeBranchID: UUID

    init(mainBranch: EditBranch = EditBranch(name: "Main")) {
        self.branches = [mainBranch]
        self.activeBranchID = mainBranch.id
    }

    var activeBranch: EditBranch {
        get {
            branches.first { $0.id == activeBranchID } ?? branches[0]
        }
        set {
            if let index = branches.firstIndex(where: { $0.id == activeBranchID }) {
                branches[index] = newValue
            }
        }
    }

    var activeStack: EditStack {
        get { activeBranch.stack }
        set { activeBranch.stack = newValue }
    }

    // MARK: - Branch Management (Phase 1: stub for future)

    mutating func createBranch(name: String, fromIndex: Int) -> UUID {
        let newBranch = EditBranch(
            name: name,
            parentBranchID: activeBranchID,
            branchPointIndex: fromIndex,
            stack: EditStack()
        )
        branches.append(newBranch)
        return newBranch.id
    }

    mutating func switchToBranch(id: UUID) {
        guard branches.contains(where: { $0.id == id }) else { return }
        activeBranchID = id
    }

    mutating func deleteBranch(id: UUID) {
        guard id != branches[0].id else { return }  // Can't delete main branch
        branches.removeAll { $0.id == id }
        if activeBranchID == id {
            activeBranchID = branches[0].id
        }
    }
}
