#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): `GearEditorView.
/// save()` (private struct inside `GearListView.swift`) had NO
/// `modelContext.save()` call at all in either mode — it relied entirely on
/// SwiftData's implicit autosave, the exact same bug class already found and
/// fixed in `DayEditorView.saveAndDismiss()`/`PlanEditorView.saveAndDismiss()`
/// (see `DayEditorPersistenceTests`). A new `Gear` entry inserted right
/// before a cold start could silently vanish.
///
/// `save()` stays `private` and reads `self.modelContext` from
/// `@Environment` — a directly-constructed `GearEditorView` without a live
/// SwiftUI/`.modelContainer` context would not hit the context this test
/// sets up (same reasoning as `DayEditorPersistenceTests`'s type doc). This
/// test therefore proves the same underlying fix technique `GearEditorView.
/// save()` now applies: insert + IMMEDIATE `context.save()` survives a real
/// store restart, while the previous insert-only sequence did not.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class GearEditorPersistenceTests: XCTestCase {

    func testNewGearWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gear-editor-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            // Exakt die Sequenz aus `GearEditorView.save()` (`.new`-Modus)
            // nach dem Fix: neues `Gear` einfuegen, SOFORT `context.save()`
            // — kein weiterer Schritt, der SwiftDatas impliziten Autosave
            // haette ausloesen koennen.
            let gear = Gear(name: "Laufschuh A", type: .shoe, maxDistanceKm: 800, currentDistanceKm: 120, isActive: true)
            context.insert(gear)
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let gears = try reopened.mainContext.fetch(FetchDescriptor<Gear>())
        XCTAssertEqual(gears.map(\.name), ["Laufschuh A"],
                        "die Neuanlage muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(gears.first?.currentDistanceKm, 120)
    }

    // MARK: - ponytail-audit (zweiter Durchlauf): Rollback bei fehlgeschlagenem Save im .edit-Zweig
    //
    // Gleicher Fehler wie `CardioGoalEditorView.save()` (Commit 8bdb416, siehe
    // `CardioGoalEditorPersistenceTests`): der `.edit`-Zweig mutierte das
    // lebende `Gear`-Objekt direkt, BEVOR `context.save()` lief - bei einem
    // Fehler blieben die nie bestaetigten Entwurfswerte unveraendert auf
    // `gear` stehen (nur der `.new`-Zweigs frisch eingefuegtes Objekt wurde
    // zurueckgerollt). `save()` ist `private` ohne testbare Laufzeit-
    // Oberflaeche und dieses Projekt hat keinen verlaesslichen Weg, einen
    // echten `ModelContext.save()` ausserhalb eines DI-Seams zum Scheitern zu
    // bringen (siehe `CardioGoalEditorPersistenceTests`-Typ-Doku) - daher
    // dieselbe Quelltext-Pruefung: Schnappschuss VOR der Mutation, Wieder-
    // herstellung im `catch`-Block VOR der Fehlermeldung.

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var gearListViewSource: String {
        get throws { try readSource("Sources/FitnessAppUI/Settings/GearListView.swift") }
    }

    func testFailedSaveSnapshotsAndRestoresAllFiveMutatedGearFieldsInEditMode() throws {
        let source = try gearListViewSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let mutationStart = source.range(of: "editSnapshot = (gear, gear.name, gear.type, gear.maxDistanceKm, gear.currentDistanceKm, gear.isActive)") else {
            return XCTFail("the .edit snapshot was not found before the mutation")
        }
        guard let editAssignmentStart = source.range(of: "gear.name = trimmed", range: mutationStart.upperBound..<source.endIndex) else {
            return XCTFail("the .edit mutation block was not found after the snapshot")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let errorMessageAssignment = source.range(of: "saveErrorMessage = String(localized: \"day.editor.save.failed\"", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("save()'s error-message assignment was not found")
        }

        XCTAssertTrue(
            mutationStart.upperBound <= editAssignmentStart.lowerBound,
            "the snapshot must be taken BEFORE the .edit mutations, not after"
        )

        let catchBody = String(source[catchStart.upperBound..<errorMessageAssignment.lowerBound])
        XCTAssertTrue(
            catchBody.contains("if let editSnapshot {"),
            "a failed save's catch block must restore the .edit snapshot, guarded so the .new case is untouched"
        )
        for property in ["name", "type", "maxDistanceKm", "currentDistanceKm", "isActive"] {
            XCTAssertTrue(
                catchBody.contains("editSnapshot.gear.\(property) = editSnapshot.\(property)"),
                "catch block must restore gear.\(property) from the snapshot"
            )
        }
    }
}
#endif
