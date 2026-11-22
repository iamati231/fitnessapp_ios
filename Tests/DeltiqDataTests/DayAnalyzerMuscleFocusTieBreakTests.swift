#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Modul-3-Audit: `DayAnalyzer.computeMuscleFocus` sortiert über
/// `perMuscle.map { ... }.sorted { $0.1 > $1.1 }` - `perMuscle` ist ein
/// `[MuscleGroup: Double]`, dessen `.map`-Iterationsreihenfolge nicht
/// stabil garantiert ist. Gleiche Bug-Klasse wie
/// `MuscleGroupProgressCalculator` (Commit 069fa3a, PR #58/#59): ohne
/// Tie-Breaker zeigt `DayAnalysisCard.muscleFocusRow` zwei exakt
/// gleichauf liegende Muskeln je nach Dictionary-Iteration in
/// wechselnder Reihenfolge innerhalb desselben Tiers an.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DayAnalyzerMuscleFocusTieBreakTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Zwei Übungen mit identischen Satz-/RIR-/Compound-Werten, aber
    /// unterschiedlichem Zielmuskel, erzeugen in `computeMuscleFocus` einen
    /// exakten Punktzahl-Gleichstand. Zwei verschiedene Insertion-
    /// Reihenfolgen müssen trotzdem dasselbe (alphabetische) Ergebnis
    /// liefern.
    func testMuscleFocusTieBreaksAlphabeticallyRegardlessOfInsertionOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let quads = Exercise(name: "A", primaryMuscle: .quads)
        let glutes = Exercise(name: "B", primaryMuscle: .glutes)
        context.insert(quads)
        context.insert(glutes)

        let orderA = DayAnalyzer.analyze(exercises: [quads, glutes])
        let orderB = DayAnalyzer.analyze(exercises: [glutes, quads])

        let namesA = try XCTUnwrap(orderA).muscleFocus.map(\.muscle)
        let namesB = try XCTUnwrap(orderB).muscleFocus.map(\.muscle)

        XCTAssertEqual(namesA, [.glutes, .quads], "glutes < quads alphabetisch (rawValue)")
        XCTAssertEqual(namesB, [.glutes, .quads])
    }
}
#endif
