import Foundation

struct TimebutlerCategory: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct CategoriesResponse: Codable, Equatable {
    let categories: [TimebutlerCategory]
    let defaultCategoryId: String?
    let isCategoryMandatory: Bool?
}
