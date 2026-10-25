#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Deltiq-Geraeteabnahme (Runde 5, `docs/DELTIQ_DEVICE_ACCEPTANCE.md`,
/// C01-Nachtest): `CardioGoalEditorView.save()` mutierte `profile` OHNE
/// anschliessenden `context.save()` - auf dem Geraet ueberlebte ein gerade
/// bestaetigtes Cardio-Update (z. B. "Starting volume") einen Kaltstart kurz
/// danach reproduzierbar NICHT (zweimal unabhaengig reproduziert: der Wert
/// fiel auf den zuletzt tatsaechlich persistierten Stand zurueck), waehrend
/// die In-Memory-/UI-Anzeige bis zum Prozessende korrekt blieb - derselbe
/// Musterfehler wie `MeasurementPersistenceTests`/E01 und die zwoelf zuvor
/// gefixten Stellen. `save()` selbst bleibt `private` und liest
/// `@Environment(\.modelContext)`; ein direkter Aufruf ohne lebenden
/// `.modelContainer`-Kontext traefe nicht den hier aufgesetzten Context
/// (siehe `MeasurementPersistenceTests`-Typ-Doku). Dieser Test beweist daher
/// dieselbe zugrundeliegende Fix-Technik: Mutation + SOFORTIGER
/// `context.save()` uebersteht einen echten Store-Neustart.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioGoalEditorPersistenceTests: XCTestCase {

    func testSavedCardioGoalSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cardio-goal-editor-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        let raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let profile = UserBodyProfile(
                birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
                cardioCoachingEnabled: false, cardioGoal: .generalFitness
            )
            context.insert(profile)
            try context.save()

            // Exakt die Sequenz aus `CardioGoalEditorView.save()` nach dem
            // Fix: das bestehende Profil-Objekt mutieren (Cardio-Felder in
            // einem Rutsch, wie beim Speichern-Tap), SOFORT `context.save()`
            // - kein weiterer Schritt, der SwiftDatas impliziten Autosave
            // haette ausloesen koennen.
            profile.setEnduranceModality(.running, runCoachEnabled: true)
            profile.cardioGoal = .marathon
            profile.cardioRaceDate = raceDate
            profile.weeklyBaseVolumeKm = 10
            profile.maxHeartRateBpm = 180
            profile.current5kReferenceSeconds = 1500
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let profiles = try reopened.mainContext.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertEqual(profiles.count, 1, "Speichern darf kein zweites Profil anlegen")
        let profile = try XCTUnwrap(profiles.first)
        XCTAssertTrue(profile.cardioCoachingEnabled, "muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(profile.enduranceModality, .running)
        XCTAssertEqual(profile.cardioGoal, .marathon)
        XCTAssertEqual(profile.cardioRaceDate, raceDate)
        XCTAssertEqual(profile.weeklyBaseVolumeKm, 10)
        XCTAssertEqual(profile.maxHeartRateBpm, 180)
        XCTAssertEqual(profile.current5kReferenceSeconds, 1500)
    }

    // MARK: - Fund B (Geraete-Nachtest): 5K-Referenzzeit-Validierung
    //
    // `canSave`/`save()`/`zonesSummary` sind `private` Computed-Properties
    // ohne testbare Laufzeit-Oberflaeche (nur `some View`), also liest dieser
    // Abschnitt den Quelltext direkt — selbes Muster wie
    // `AddMealViewSaveErrorStyleTests`/`MainTabStructureTests`.

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var cardioGoalEditorViewSource: String {
        get throws { try readSource("Sources/FitnessAppUI/Settings/CardioGoalEditorView.swift") }
    }

    /// Regression: alle drei 5K-Zeit-Call-Sites (`canSave`, `save()`,
    /// `zonesSummary`) muessen `parseFiveKReferenceSeconds` verwenden, NICHT
    /// mehr `parseDurationToSeconds` — dessen "bare Zahl = Minuten"-Fallback
    /// liess ein bares "2500" unvalidiert als 2500 Minuten durchgehen.
    func testFiveKReferenceCallSitesUseTheDedicatedParser() throws {
        let source = try cardioGoalEditorViewSource
        XCTAssertFalse(
            source.contains("parseDurationToSeconds(draftFiveKReferenceText)"),
            "The 5K-time field must no longer call parseDurationToSeconds anywhere — its bare-number-as-minutes fallback is the exact bug this fix removes."
        )
        XCTAssertFalse(
            source.contains("parseDurationToSeconds(text)"),
            "canSave's local `text` (trimmed draftFiveKReferenceText) must also go through parseFiveKReferenceSeconds."
        )
        let occurrences = source.components(separatedBy: "parseFiveKReferenceSeconds").count - 1
        XCTAssertGreaterThanOrEqual(
            occurrences, 3,
            "Expected parseFiveKReferenceSeconds to be called at all 3 sites (canSave, save(), zonesSummary)."
        )
    }

    /// Fund B: ohne eine sichtbare Fehlermeldung sah der Nutzer nur ein
    /// deaktiviertes Save-Haekchen, ohne zu verstehen warum.
    func testInvalidFiveKReferenceTextRendersAnInlineErrorMessage() throws {
        let source = try cardioGoalEditorViewSource
        XCTAssertTrue(
            source.contains("fiveKReferenceErrorMessage"),
            "A dedicated error-message computed property gated on invalid, non-empty draftFiveKReferenceText must exist."
        )
        XCTAssertTrue(
            source.contains("errorRow(fiveKReferenceErrorMessage)"),
            "The error message must be rendered via the file's existing errorRow(_:) helper, right where the 5K pace hint used to unconditionally render."
        )
        XCTAssertTrue(
            source.contains("profile.cardio.fiveKReference.invalid"),
            "The error message must come from a localized string key, not a hardcoded literal."
        )
    }
}
#endif
