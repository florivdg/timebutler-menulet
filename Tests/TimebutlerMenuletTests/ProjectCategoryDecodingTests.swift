import XCTest
@testable import TimebutlerMenulet

final class ProjectCategoryDecodingTests: XCTestCase {
    func testProjectsResponseDecodes() throws {
        let json = """
        {
          "projects": [
            { "id": "5", "name": "Website Relaunch", "isFavorite": true },
            { "id": "6", "name": "Internal", "isFavorite": false }
          ],
          "defaultProjectId": "5",
          "isProjectMandatory": true
        }
        """
        let decoded = try JSONDecoder().decode(ProjectsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.projects.count, 2)
        XCTAssertEqual(decoded.projects.first?.id, "5")
        XCTAssertEqual(decoded.projects.first?.isFavorite, true)
        XCTAssertEqual(decoded.defaultProjectId, "5")
        XCTAssertEqual(decoded.isProjectMandatory, true)
    }

    func testCategoriesResponseDecodes() throws {
        let json = """
        {
          "categories": [
            { "id": "7", "name": "Internal project" }
          ],
          "defaultCategoryId": "7",
          "isCategoryMandatory": false
        }
        """
        let decoded = try JSONDecoder().decode(CategoriesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.categories.first?.name, "Internal project")
        XCTAssertEqual(decoded.defaultCategoryId, "7")
        XCTAssertEqual(decoded.isCategoryMandatory, false)
    }
}
