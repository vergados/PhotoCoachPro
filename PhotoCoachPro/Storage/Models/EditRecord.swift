//
//  EditRecord.swift
//  PhotoCoachPro
//
//  SwiftData model for edit history
//

import Foundation
import SwiftData

@Model
final class EditRecord {
    @Attribute(.unique) var id: UUID
    var photoID: UUID
    var createdDate: Date
    var modifiedDate: Date

    // Edit graph (stored as Codable)
    @Attribute(.externalStorage) var editGraphData: Data?

    // Relationship back to photo
    @Relationship(deleteRule: .nullify, inverse: \PhotoRecord.editRecord)
    var photo: PhotoRecord?

    // Computed property
    var editGraph: EditGraph {
        get {
            guard let data = editGraphData,
                  let graph = try? JSONDecoder().decode(EditGraph.self, from: data) else {
                return EditGraph()
            }
            return graph
        }
        set {
            editGraphData = try? JSONEncoder().encode(newValue)
            modifiedDate = Date()
        }
    }

    var editStack: EditStack {
        get { editGraph.activeStack }
        set {
            var graph = editGraph
            graph.activeStack = newValue
            editGraph = graph
        }
    }

    init(
        id: UUID = UUID(),
        photoID: UUID,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        editGraph: EditGraph = EditGraph()
    ) {
        self.id = id
        self.photoID = photoID
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.editGraph = editGraph
    }
}

// MARK: - Convenience
extension EditRecord {
    var hasEdits: Bool {
        !editGraph.activeStack.isEmpty
    }

    var editCount: Int {
        editGraph.activeStack.activeInstructions.count
    }
}
