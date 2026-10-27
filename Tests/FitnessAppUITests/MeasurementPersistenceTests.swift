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

    // MARK: - Audit-Fix: Rollback bei fehlgeschlagenem Save im Edit-Zweig
    //
    // `save(profile:)`s `editingMeasurement`-Zweig mutierte bis zu 20 Felder
    // auf `existing` VOR `context.save()` - bei einem Fehler blieben die nie
    // bestaetigten Werte unveraendert stehen (identischer Musterfehler wie
    // `CardioGoalEditorView.save()`, dort bereits gefixt, Commit 8bdb416).
    // `save(profile:)` ist `private` ohne testbare Laufzeit-Oberflaeche
    // (liest `@Environment(\.modelContext)`), daher Quelltext-Pruefung -
    // selbes Muster wie `CardioGoalEditorPersistenceTests`.

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var measurementViewSource: String {
        get throws { try readSource("Sources/FitnessAppUI/MeasurementView.swift") }
    }

    private static let rollbackFields: [String] = [
        "weightKg", "neckCm", "waistCm", "hipCm", "shoulderCm", "chestCm", "calfCm",
        "upperArmCm", "upperArmLeftCm", "upperArmRightCm",
        "thighCm", "thighLeftCm", "thighRightCm",
        "bmi", "navyBodyFatPct", "deurenbergBodyFatPct", "selectedBodyFatPct",
        "fatFreeMassKg", "ffmi", "normalizedFfmi", "bmr",
    ]

    func testFailedSaveSnapshotsAndRestoresAllTwentyMutatedMeasurementFields() throws {
        let source = try measurementViewSource
        guard let editBranchStart = source.range(of: "if let existing = editingMeasurement {") else {
            return XCTFail("the editingMeasurement branch was not found at the expected signature")
        }
        guard let mutationStart = source.range(of: "let hasFullCircumferences", range: editBranchStart.upperBound..<source.endIndex) else {
            return XCTFail("the mutation block was not found where expected")
        }
        guard let catchStart = source.range(of: "} catch {", range: editBranchStart.upperBound..<source.endIndex) else {
            return XCTFail("the edit branch's catch block was not found")
        }
        guard let errorMessageAssignment = source.range(of: "saveErrorMessage = String(localized: \"day.editor.save.failed\"", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("the edit branch's error-message assignment was not found")
        }

        let beforeMutation = String(source[editBranchStart.upperBound..<mutationStart.lowerBound])
        let catchBody = String(source[catchStart.upperBound..<errorMessageAssignment.lowerBound])

        for field in Self.rollbackFields {
            let suffix = field.prefix(1).uppercased() + field.dropFirst()
            XCTAssertTrue(
                beforeMutation.contains("let original\(suffix) = existing.\(field)"),
                "save(profile:) must snapshot existing.\(field) BEFORE the mutating block, so a failed save can restore it"
            )
            XCTAssertTrue(
                catchBody.contains("existing.\(field) = original\(suffix)"),
                "a failed save's catch block must restore existing.\(field) from its snapshot before the error message is set"
            )
        }
    }

    func testEditBranchNeverUsesABlanketContextRollback() throws {
        let source = try measurementViewSource
        guard let editBranchStart = source.range(of: "if let existing = editingMeasurement {") else {
            return XCTFail("the editingMeasurement branch was not found at the expected signature")
        }
        guard let catchStart = source.range(of: "} catch {", range: editBranchStart.upperBound..<source.endIndex) else {
            return XCTFail("the edit branch's catch block was not found")
        }
        guard let catchEnd = source.range(of: "\n            }", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("the edit branch's catch block end was not found")
        }
        // The catch block's own explanatory comment deliberately mentions `modelContext.rollback()`
        // in prose to say why it's NOT used - strip `//` comment lines before checking, so that
        // explanation doesn't trip the very assertion it's explaining (same fix already applied to
        // CardioGoalEditorPersistenceTests after it hit this exact false positive in CI).
        let catchCode = source[catchStart.upperBound..<catchEnd.lowerBound]
            .split(separator: "\n")
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
        XCTAssertFalse(
            catchCode.contains("modelContext.rollback()"),
            "the edit branch must restore the twenty fields individually, never via a blanket modelContext.rollback() that could discard unrelated pending changes"
        )
    }
}
#endif
