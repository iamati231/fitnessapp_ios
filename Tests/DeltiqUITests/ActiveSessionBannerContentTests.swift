#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import XCTest
import SwiftData
import DeltiqCore
import DeltiqData
@testable import DeltiqUI

/// Crash fix (TestFlight 0.1.0/175, see `ActiveSessionBannerContent`'s own
/// doc comment in `PlansListView.swift`): `ActiveSessionBanner` now renders
/// from a plain-value `ActiveSessionBannerContent` snapshot instead of a
/// live `WorkoutSession`, so it never re-reads an `@Model` property that
/// could be invalidated by `DashboardView.discardOtherOpenSessionsAndStartNew()`
/// deleting that exact session from a sibling tab. This test only proves the
/// snapshot itself is accurate at extraction time — the crash this fixes is
/// a SwiftUI rendering-timing issue with no automated UI-test harness in
/// this repo, same caveat as `PlanRowContentTests`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ActiveSessionBannerContentTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testContentUsesDayNameSnapshotWhenDayIsNil() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startTime: start, dayName: "Ganzkoerper A", day: nil)
        context.insert(session)
        try context.save()

        let content = ActiveSessionBannerContent(session)

        XCTAssertEqual(content.displayName, "Ganzkoerper A")
        XCTAssertEqual(content.startTime, start)
    }

    /// DEL-129: wenn weder eine lebende `day`-Referenz noch ein
    /// `dayName`-Snapshot existiert, ueberschreibt der Banner die generische
    /// `displayDayName`-Fallback-Kette mit seinem eigenen, aktiveren Text.
    func testContentFallsBackToActiveBannerNameWhenDayAndDayNameAreNil() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = WorkoutSession(dayName: nil, day: nil)
        context.insert(session)
        try context.save()

        let content = ActiveSessionBannerContent(session)

        XCTAssertEqual(content.displayName, String(localized: "plans.active.fallbackName", bundle: .module))
    }
}
#endif
