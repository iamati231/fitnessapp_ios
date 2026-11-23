import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): `HealthWorkoutWriter.pushLive` ist
/// bewusst nicht-blockierend - der Aufrufer (Abschluss-Flow) wird nie
/// blockiert, der Export-Marker (`healthKitExportedAt`) wird erst NACH dem
/// bestaetigten `await healthKit.saveWorkout(...)` gesetzt. In diesem
/// Fenster haelt `WorkoutHealthExportService.prepare()` ("Export fruehere
/// Trainings") dieselbe Session faelschlich fuer noch-nie-exportiert und
/// schreibt sie ein zweites Mal nach Health. Quelltext-Pruefung (kein
/// Test-Seam fuer `HealthKitController`, echtes HealthKit laesst sich in
/// einem Unit-Test nicht sicher ansteuern), gleiches Muster wie die
/// uebrigen Save-Error-/Persistence-Quelltext-Tests dieses Moduls.
final class HealthWorkoutWriterPendingExportTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI/Workout")
    }

    private func source(_ file: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(file), encoding: .utf8)
    }

    /// `pendingLiveExportStartTimes` must be inserted into BEFORE the `Task`
    /// is created (so the window is closed for any synchronous caller that
    /// runs between `pushLive` returning and the Task's first suspension
    /// point), and removed via `defer` (so a thrown/early-returning outcome
    /// never leaves a session stuck marked "pending" forever).
    func testPushLiveMarksStartTimePendingBeforeTheTaskAndClearsItViaDefer() throws {
        let text = try source("HealthWorkoutWriter.swift")
        guard let funcStart = text.range(of: "static func pushLive(") else {
            return XCTFail("pushLive not found at expected signature")
        }
        guard let insertRange = text.range(of: "pendingLiveExportStartTimes.insert(startTime)", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("pushLive must insert startTime into pendingLiveExportStartTimes")
        }
        guard let taskRange = text.range(of: "Task {", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("pushLive must still launch its background Task")
        }
        XCTAssertLessThan(insertRange.lowerBound, taskRange.lowerBound,
                          "startTime must be marked pending BEFORE the Task is created, not from inside it")
        guard let deferRange = text.range(of: "defer { pendingLiveExportStartTimes.remove(startTime) }", range: taskRange.upperBound..<text.endIndex) else {
            return XCTFail("the Task must clear the pending marker via defer, so every exit path (success, failure, early return) clears it")
        }
        XCTAssertLessThan(taskRange.upperBound, deferRange.lowerBound)
    }

    /// `WorkoutHealthExportService.prepare()` must skip a session whose
    /// startTime is still pending a live export, BEFORE building a candidate
    /// for it - otherwise it would plan and write a duplicate.
    func testPrepareSkipsSessionsPendingALiveExport() throws {
        let text = try source("WorkoutHealthExportService.swift")
        guard let funcStart = text.range(of: "static func prepare(") else {
            return XCTFail("prepare() not found at expected signature")
        }
        guard let loopStart = text.range(of: "for session in sessions {", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("prepare()'s session loop not found")
        }
        guard let guardRange = text.range(of: "guard !HealthWorkoutWriter.isPendingLiveExport(startTime: session.startTime) else { continue }", range: loopStart.upperBound..<text.endIndex) else {
            return XCTFail("prepare() must skip sessions pending a live export")
        }
        guard let candidateRange = text.range(of: "let candidate = HealthWorkoutWriter.candidate(for: session)", range: loopStart.upperBound..<text.endIndex) else {
            return XCTFail("prepare() must still build a candidate for non-pending sessions")
        }
        XCTAssertLessThan(guardRange.lowerBound, candidateRange.lowerBound,
                          "the pending-export guard must run before the candidate is built, so an in-flight session is never even classified")
    }
}
