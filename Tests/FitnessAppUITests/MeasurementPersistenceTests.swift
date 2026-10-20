#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// E01 (Deltiq-Geraeteabnahme, `docs/DELTIQ_DEVICE_ACCEPTANCE.md`): der
/// `editingMeasurement`-Zweig von `MeasurementView.save(profile:)`
/// ueberschrieb das bestehende `BodyMeasurement`-Objekt im Speicher, aber
/// OHNE anschliessenden `context.save()` — derselbe Musterfehler, der in
/// `DayEditorPersistenceTests` und `deleteCurrentMeasurement` bereits
/// mehrfach gefunden und gefixt wurde. `save()` selbst bleibt `private`
/// und liest `@Environment(\.modelContext)`; ein direkter Aufruf ohne
/// lebenden `.modelContainer`-Kontext traefe nicht den hier aufgesetzten
/// Context (siehe `DayEditorPersistenceTests`-Typ-Dokumentation). Dieser
/// Test beweist deshalb die zugrundeliegende Fix-Technik: dieselbe
/// Objekt-Mutation + SOFORTIGER `context.save()` uebersteht einen echten
/// Store-Neustart, der einen App-Kaltstart kurz nach dem Tippen auf den
/// Haken nachbildet.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MeasurementPersistenceTests: XCTestCase {

    func testEditedMeasurementWithImmediateSaveSurvivesARealStoreRestartWithoutDuplication() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("measurement-edit-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let existing = BodyMeasurement.makeWeightOnly(
                date: originalDate, ageYears: 30, weightKg: 80, heightCm: 180, profile: .male
            )
            context.insert(existing)
            try context.save()

            // Exakt die Sequenz aus dem `editingMeasurement`-Zweig von
            // `save(profile:)` nach dem Fix: bestehendes Objekt mutieren
            // (Gewicht geaendert), SOFORT `context.save()` — kein weiterer
            // Schritt, der SwiftDatas impliziten Autosave haette ausloesen
            // koennen.
            existing.weightKg = 82.5
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let measurements = try reopened.mainContext.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(measurements.count, 1, "Bearbeiten darf keine Dopplung erzeugen")
        XCTAssertEqual(measurements.first?.weightKg, 82.5, "die Bearbeitung muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(measurements.first?.date, originalDate, "Bearbeiten darf keinen neuen Eintrag anlegen, sondern muss den bestehenden ueberschreiben")
    }
}
#endif
