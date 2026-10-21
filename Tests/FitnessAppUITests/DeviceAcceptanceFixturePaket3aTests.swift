#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
import FitnessAppData
import FitnessAppCore

/// Paket-3a-Geraetenachweis (docs/DELTIQ_DEVICE_ACCEPTANCE.md): Selbstcheck
/// fuer `DeviceAcceptanceFixturePaket3a` — stellt sicher, dass die dort
/// erzeugten Testdaten ueber die ECHTE Produktlogik (`MissedRunDayEvaluator`
/// → `CardioCoachingAdvisor` → `MissedRunDaysCardModel.make`) tatsaechlich
/// einen Treffer ergeben, BEVOR dafuer ein TestingBot-Geraetefenster
/// verbraucht wird. Kein Ersatz fuer den Geraetenachweis selbst (reiner
/// Daten-/Logik-Check, keine UI) — siehe dortige Dokumentation.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DeviceAcceptanceFixturePaket3aTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    func testSeedProducesAMissedRunDaysCardHitForTheAffectedPlanOnly() throws {
        let context = try makeContext()
        DeviceAcceptanceFixturePaket3a.seed(in: context)

        let profiles = try context.fetch(FetchDescriptor<UserBodyProfile>())
        let plans = try context.fetch(FetchDescriptor<TrainingPlan>())
        guard let profile = profiles.first,
              let affectedPlan = plans.first(where: { $0.customName == DeviceAcceptanceFixturePaket3a.affectedPlanName }),
              let otherPlan = plans.first(where: { $0.customName == DeviceAcceptanceFixturePaket3a.otherPlanName })
        else {
            XCTFail("Fixture hat nicht die erwarteten Profil-/Plan-Objekte angelegt")
            return
        }

        XCTAssertTrue(profile.cardioCoachingEnabled)
        XCTAssertTrue(affectedPlan.isActive)
        XCTAssertFalse(otherPlan.isActive)
        XCTAssertNotEqual(affectedPlan.displayName, otherPlan.displayName)

        // Der eigentliche Punkt dieses Checks: die normale Auswertungskette
        // erzeugt den Hinweis aus den Fixture-Daten, nicht nur ein
        // kuenstliches `showCard = true`.
        let model = MissedRunDaysCardModel.make(for: profile, activePlan: affectedPlan, in: context)
        let model2 = MissedRunDaysCardModel.make(for: profile, activePlan: affectedPlan, in: context)
        XCTAssertNotNil(model, "Fixture muss einen Laufversaeumnis-Hinweis erzeugen")
        XCTAssertGreaterThanOrEqual(model?.summary.missedCount ?? 0, CardioCoachingAdvisor.minimumMissedRunDaysToFlag)
        XCTAssertNotNil(model?.coachAdjustment, "CTA-Button braucht ein nicht-nil coachAdjustment")
        XCTAssertEqual(model, model2, "deterministisch bei unveraendertem Datenstand")

        // Der zweite Plan darf den Hinweis NICHT ausloesen — er hat weder
        // Lauf-Tage noch ist er aktiv.
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: otherPlan, in: context))
    }

    func testSeedIsIdempotentAcrossAColdStart() throws {
        let context = try makeContext()
        DeviceAcceptanceFixturePaket3a.seed(in: context)
        let firstActivatedAt = try context.fetch(FetchDescriptor<TrainingPlan>())
            .first { $0.customName == DeviceAcceptanceFixturePaket3a.affectedPlanName }?.activatedAt

        // Simuliert Schritt D (echter Kaltstart): derselbe Aufruf darf keine
        // zweiten Plan-/Profil-Objekte anlegen und `activatedAt` nicht
        // veraendern — sonst waere die am Geraet zu pruefende
        // Unterdrueckungs-Bindung (Fingerprint) nach jedem Neustart kaputt.
        DeviceAcceptanceFixturePaket3a.seed(in: context)

        let plans = try context.fetch(FetchDescriptor<TrainingPlan>())
        let profiles = try context.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertEqual(plans.filter { $0.customName == DeviceAcceptanceFixturePaket3a.affectedPlanName }.count, 1)
        XCTAssertEqual(plans.filter { $0.customName == DeviceAcceptanceFixturePaket3a.otherPlanName }.count, 1)
        XCTAssertEqual(profiles.count, 1)
        let secondActivatedAt = plans.first { $0.customName == DeviceAcceptanceFixturePaket3a.affectedPlanName }?.activatedAt
        XCTAssertEqual(firstActivatedAt, secondActivatedAt)
    }
}
#endif
