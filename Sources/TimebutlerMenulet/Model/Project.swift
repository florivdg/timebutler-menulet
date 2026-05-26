import Foundation

struct Project: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let isFavorite: Bool?
}

struct ProjectsResponse: Codable, Equatable {
    let projects: [Project]
    let defaultProjectId: String?
    let isProjectMandatory: Bool?
}
