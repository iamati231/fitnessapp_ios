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
}
#endif
