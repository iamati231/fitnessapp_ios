#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest

/// Regression guard for the invisible list row bug in PlansListView.
/// `Color.clear.frame(height: 0)` as a List row still occupies default row
/// height, creating a visible gap above plansContextRow. The fix removes that
/// sentinel row and attaches `.id("plans-top")` directly to plansContextRow.
final class PlansListViewScrollAnchorTests: XCTestCase {

    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/Workout/PlansListView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testNoInvisibleColorClearRowInList() throws {
        let src = try source
        XCTAssertFalse(src.contains("Color.clear.frame(height: 0)"),
            "Color.clear.frame(height: 0) must not be used as a List row (causes default row height gap)")
    }

    func testScrollAnchorIdAttachedToPlansContextRow() throws {
        let src = try source
        // plansContextRow must be immediately followed by .id("plans-top")
        XCTAssertTrue(src.contains("plansContextRow\n                        .id(\"plans-top\")") ||
                      src.contains("plansContextRow.id(\"plans-top\")"),
            "'.id(\"plans-top\")' must be a modifier on plansContextRow, not a separate Color.clear row")
    }

    func testScrollToPlansTopAnchorStillPresent() throws {
        let src = try source
        XCTAssertTrue(src.contains("proxy.scrollTo(\"plans-top\""),
            "scrollTo(\"plans-top\") anchor call must still be present for scroll-to-top to work")
    }
}
#endif
