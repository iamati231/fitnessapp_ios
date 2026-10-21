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

    // Als Instanzeigenschaft gehalten (gleiches Muster wie
    // `MissedRunDaysCardModelTests`) — ein nur lokal gehaltener Container
    // wird sonst deallokiert, sobald die Helper-Funktion zurückkehrt, und der
    // zurückgegebene `ModelContext` zeigt danach ins Leere (Crash-Ursache
    // des ersten CI-Laufs dieser Datei: Signal 5 in beiden Tests).
    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testSeedProducesAMissedRunDaysCardHitForTheAffectedPlanOnly() throws {
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

    /// Regressionstest fuer einen am Geraet gefundenen echten Bug: die
    /// Lauf-Tage waren nach `seed(in:)` fuer sich genommen "anfassbar"
    /// (`RunCoachPlanAdjustment.isEligibleForAdjustment`), aber
    /// `LibrarySeeder.backfillCustomNamesIfNeeded` laeuft im echten
    /// `RootView.task` UNMITTELBAR NACH diesem Seed und setzt `customName`
    /// auf jedem Tag mit `customName == nil` nachtraeglich — das aenderte
    /// `currentContentFingerprint` NACH dem Einfrieren von
    /// `generationFingerprint` und liess die Vorschau am Geraet faelschlich
    /// den generischen "kein anfassbarer Tag"-Text zeigen statt der
    /// tatsaechlichen Tagesnamen. Fix: `customName` wird in `seed(in:)`
    /// jetzt explizit gesetzt. Dieser Test laesst GENAU dieselbe
    /// Backfill-Funktion wie `RootView.task` ueber die Fixture-Daten laufen.
    func testCardioDaysStayEligibleForAdjustmentEvenAfterTheRealStartupBackfillRuns() throws {
        DeviceAcceptanceFixturePaket3a.seed(in: context)
        _ = LibrarySeeder.backfillCustomNamesIfNeeded(in: context)

        let plans = try context.fetch(FetchDescriptor<TrainingPlan>())
        guard let affectedPlan = plans.first(where: { $0.customName == DeviceAcceptanceFixturePaket3a.affectedPlanName }) else {
            XCTFail("Fixture hat den betroffenen Plan nicht angelegt")
            return
        }

        let analysis = RunCoachPlanAdjustment.analyze(plan: affectedPlan)
        guard case .ready(let ids) = analysis.cardioAvailability else {
            XCTFail("Lauf-Tage muessen nach dem Startup-Backfill weiterhin anfassbar sein, war: \(analysis.cardioAvailability)")
            return
        }
        XCTAssertEqual(ids.count, 3, "alle drei Lauf-Tage, nicht nur ein Teil")
    }

    func testSeedIsIdempotentAcrossAColdStart() throws {
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
