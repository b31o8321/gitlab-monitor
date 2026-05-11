import Foundation

struct Repository: Identifiable, Equatable {
    let id: UUID
    var name: String
    var projectPath: String
    var branchSelector: BranchSelector

    init(id: UUID = UUID(), name: String, projectPath: String, branchSelector: BranchSelector) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.branchSelector = branchSelector
    }

    /// Convenience for callers using a fixed branch name.
    init(id: UUID = UUID(), name: String, projectPath: String, branch: String) {
        self.init(id: id, name: name, projectPath: projectPath, branchSelector: .fixed(branch))
    }
}

extension Repository: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case projectPath
        case branchSelector
        case branch  // legacy
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(projectPath, forKey: .projectPath)
        try c.encode(branchSelector, forKey: .branchSelector)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let name = try c.decode(String.self, forKey: .name)
        let projectPath = try c.decode(String.self, forKey: .projectPath)

        let selector: BranchSelector
        if let s = try c.decodeIfPresent(BranchSelector.self, forKey: .branchSelector) {
            selector = s
        } else if let legacyBranch = try c.decodeIfPresent(String.self, forKey: .branch) {
            selector = .fixed(legacyBranch)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .branchSelector,
                in: c,
                debugDescription: "Missing branchSelector and legacy branch field"
            )
        }

        self.init(id: id, name: name, projectPath: projectPath, branchSelector: selector)
    }
}
