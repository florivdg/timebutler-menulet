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

final class CategoryResolutionTests: XCTestCase {
    func testResolvedOnceCategoriesHaveLoaded() {
        XCTAssertFalse(AppState.isCategoryUnresolved(
            hasLoadedCategories: true, isCategoryMandatory: true, pinnedCategoryId: "7"
        ))
    }

    func testUnresolvedWhenPinnedCategoryCannotBeChecked() {
        XCTAssertTrue(AppState.isCategoryUnresolved(
            hasLoadedCategories: false, isCategoryMandatory: false, pinnedCategoryId: "7"
        ))
    }

    func testUnresolvedWhenCategoryIsMandatory() {
        XCTAssertTrue(AppState.isCategoryUnresolved(
            hasLoadedCategories: false, isCategoryMandatory: true, pinnedCategoryId: nil
        ))
    }

    func testResolvedWhenNothingIsPinnedAndNothingIsMandatory() {
        XCTAssertFalse(AppState.isCategoryUnresolved(
            hasLoadedCategories: false, isCategoryMandatory: false, pinnedCategoryId: nil
        ))
        XCTAssertFalse(AppState.isCategoryUnresolved(
            hasLoadedCategories: false, isCategoryMandatory: false, pinnedCategoryId: ""
        ))
    }
}

final class EffectiveCategoryTests: XCTestCase {
    func testNeverChosenUsesAccountDefault() {
        XCTAssertEqual(AppState.effectiveCategoryId(
            pinnedCategoryId: nil, knownCategoryIds: ["7"], defaultCategoryId: "7"
        ), "7")
    }

    func testExplicitNoneBeatsAccountDefault() {
        XCTAssertNil(AppState.effectiveCategoryId(
            pinnedCategoryId: "", knownCategoryIds: ["7"], defaultCategoryId: "7"
        ))
    }

    func testPinnedCategoryWins() {
        XCTAssertEqual(AppState.effectiveCategoryId(
            pinnedCategoryId: "9", knownCategoryIds: ["7", "9"], defaultCategoryId: "7"
        ), "9")
    }

    func testStalePinFallsBackToAccountDefault() {
        XCTAssertEqual(AppState.effectiveCategoryId(
            pinnedCategoryId: "42", knownCategoryIds: ["7"], defaultCategoryId: "7"
        ), "7")
    }
}
