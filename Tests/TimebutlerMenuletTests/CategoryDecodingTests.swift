import XCTest
@testable import TimebutlerMenulet

final class CategoryDecodingTests: XCTestCase {
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
