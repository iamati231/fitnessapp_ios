#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData

/// Der lokale "schon nach Health gesendet"-Marker: Wer in Health alles loescht,
/// muss den Export frueherer Trainings erneut starten koennen
/// (`HealthExportMarker.reset`), ohne dass Ruhetage, importierte oder nicht
/// abgeschlossene Sessions davon beruehrt werden.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class HealthExportMarkerTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }
    private let stamp = Date(timeIntervalSince1970: 1_760_000_000)

    @discardableResult
    private func makeSession(
        offsetDays: Int = 0,
        completed: Bool = true,
        restDay: Bool = false,
        importSource: String? = nil,
        sampleUUID: String? = nil,
        marked: Bool
    ) -> WorkoutSession {
        let start = stamp.addingTimeInterval(Double(offsetDays) * 86_400)
        let session = WorkoutSession(
            startTime: start,
            endTime: start.addingTimeInterval(1_800),
            durationMinutes: 30,
            exerciseCount: 1,
            totalSets: 3,
            totalVolumeKg: 900,
            isCompleted: completed,
            isRestDay: restDay,
            dayName: "Test",
            importSourceName: importSource,
            healthKitSampleUUID: sampleUUID,
            healthKitExportedAt: marked ? stamp : nil
        )
        context.insert(session)
        return session
    }

    func testCountsOnlyMarkedCompletedNativeWorkouts() {
        makeSession(offsetDays: 0, marked: true)
        makeSession(offsetDays: 1, marked: true)
        makeSession(offsetDays: 2, marked: false)
        makeSession(offsetDays: 3, completed: false, marked: true)
        makeSession(offsetDays: 4, restDay: true, marked: true)
        makeSession(offsetDays: 5, importSource: "Adidas Running", marked: true)
        makeSession(offsetDays: 6, sampleUUID: "ABC", marked: true)
        try? context.save()

        XCTAssertEqual(HealthExportMarker.markedCount(in: context), 2)
    }

    func testResetClearsTheMarkerAndReturnsTheCount() {
        let first = makeSession(offsetDays: 0, marked: true)
        let second = makeSession(offsetDays: 1, marked: true)
        let unmarked = makeSession(offsetDays: 2, marked: false)
        try? context.save()

        XCTAssertEqual(HealthExportMarker.reset(in: context), 2)

        XCTAssertNil(first.healthKitExportedAt)
        XCTAssertNil(second.healthKitExportedAt)
        XCTAssertNil(unmarked.healthKitExportedAt)
        XCTAssertEqual(HealthExportMarker.markedCount(in: context), 0)
    }

    /// Importierte Sessions, Ruhetage und nicht abgeschlossene Trainings behalten
    /// ihren Marker: der Export fasst sie nie an, ein Zuruecksetzen aendert dort
    /// nichts.
    func testResetLeavesImportedRestDayAndIncompleteSessionsAlone() {
        let imported = makeSession(offsetDays: 0, importSource: "Strava", marked: true)
        let withUUID = makeSession(offsetDays: 1, sampleUUID: "XYZ", marked: true)
        let rest = makeSession(offsetDays: 2, restDay: true, marked: true)
        let open = makeSession(offsetDays: 3, completed: false, marked: true)
        let native = makeSession(offsetDays: 4, marked: true)
        try? context.save()

        XCTAssertEqual(HealthExportMarker.reset(in: context), 1)

        XCTAssertNil(native.healthKitExportedAt)
        XCTAssertEqual(imported.healthKitExportedAt, stamp)
        XCTAssertEqual(withUUID.healthKitExportedAt, stamp)
        XCTAssertEqual(rest.healthKitExportedAt, stamp)
        XCTAssertEqual(open.healthKitExportedAt, stamp)
    }

    func testResetWithNothingMarkedIsANoOp() {
        makeSession(marked: false)
        try? context.save()

        XCTAssertEqual(HealthExportMarker.reset(in: context), 0)
        XCTAssertEqual(HealthExportMarker.markedCount(in: context), 0)
    }

    func testEmptyStoreHasNothingMarked() {
        XCTAssertEqual(HealthExportMarker.markedCount(in: context), 0)
        XCTAssertEqual(HealthExportMarker.reset(in: context), 0)
    }
}
#endif
