import Foundation

struct Repository: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var projectPath: String
    var branch: String

    init(id: UUID = UUID(), name: String, projectPath: String, branch: String) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.branch = branch
    }
}
