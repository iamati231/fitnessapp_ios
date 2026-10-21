#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
import FitnessAppData
import FitnessAppCore

/// Paket-3a-Restpunkt 4 (Neue UI-Anbindung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// gezielter Integrationstest auf Swift-Ebene fuer die NEUE Verdrahtung
/// Karte (`MissedRunDaysCardModel`) → richtiger Plan → Vorschau
/// (`CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView`) — NICHT die
/// bereits 9-fach gerätebestätigte `CoachAdjustmentPreviewView` selbst
/// nochmal (siehe Paket-1-Geräteabnahme oben in der Doku).
///
/// **Abwägung (kein echter Gerätenachweis fuer diesen Punkt):**
/// `CoachAdjustmentPreviewView` ist eine reine, daten-getriebene SwiftUI-View
/// ohne eigene Logik über das bereits getestete `CoachAdjustmentCardModel`
/// hinaus — sie liest nur `CoachAdjustmentCardModel.make(for:activePlan:)`
/// (exakt dieselbe Funktion, die unten direkt aufgerufen wird) und ruft
/// `accept()`/`dismiss()` auf. Der eigentliche Risikopunkt dieses Pakets ist
/// NICHT die View-Darstellung (das IST der bereits gerätebestätigte Paket-1-
/// Pfad), sondern ob `DashboardView` dabei zuverlässig DENSELBEN Plan an
/// Karte UND Sheet durchreicht — bei mehreren gleichzeitig aktiven Plänen
/// (bewusstes Produktverhalten, siehe `PlanParticipationEvaluator`-Doku)
/// ein echtes Risiko. Das ist ohne jedes UI-Rendering mit echten
/// SwiftData-Objekten prüfbar; ein zusätzlicher TestingBot-Gerätenachweis
/// nur für diesen Punkt wäre unverhältnismäßig (der CTA-Button/
/// `.sheet(isPresented:)`-Mechanismus selbst ist exakt der in Paket 1
/// bereits bestätigte, siehe "Gerätenachweis: bewusst entfallen"-Abschnitt).
/// Offen bleibt bewusst: ein visueller Nachweis, dass der AUSLÖSEZUSTAND
/// (Hinweis tatsächlich sichtbar) auf echtem Gerät erreichbar ist — dafür
/// müsste ein mehrwöchiger realer Trainingsverlauf mit Versäumnissen
/// aufgebaut werden, was für eine reine Verdrahtungsprüfung nicht
/// gerechtfertigt ist.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MissedRunDaysCardAdjustmentWiringTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Ein eigener, anfassbarer (`generationFingerprint`-gesetzter) Lauf-Tag
    /// pro Plan, keine Sessions — identisches Muster wie
    /// `MissedRunDaysCardModelTests.makeProfileAndPlan`, hier aber bewusst
    /// MEHRFACH fuer verschiedene `activatedAt`-Werte unter EINEM Profil
    /// (der realistische "mehrere aktive Pläne"-Fall).
    @discardableResult
    private func makePlan(activatedAt: Date, name: String) -> TrainingPlan {
        let plan = TrainingPlan(name: name, weeks: 8, isActive: true, targetEnvironment: .gym)
        plan.activatedAt = activatedAt
        context.insert(plan)
        let runDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(runDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
        run.enduranceSportKind = .running
        context.insert(run)
        runDay.exercises.append(run)
        runDay.generationFingerprint = runDay.currentContentFingerprint
        plan.days.append(runDay)
        return plan
    }

    func testCardReferencesCorrectPlanThroughToPreviewAndCancelChangesNothing() throws {
        let fixedNow = d(2024, 2, 1)
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        // ZWEI gleichzeitig aktive Pläne desselben Profils, mit
        // UNTERSCHIEDLICHEM `activatedAt` (unterschiedliche Planfassung,
        // unterschiedlicher Fingerprint) — genau der Fall, in dem eine
        // falsch durchgereichte Plan-Referenz unbemerkt bliebe, weil beide
        // Pläne strukturell gleich aussehen.
        let targetPlan = makePlan(activatedAt: d(2024, 1, 1), name: "Zielplan (von DashboardView gewählt)")
        let decoyPlan = makePlan(activatedAt: d(2023, 6, 1), name: "Anderer aktiver Plan")
        try context.save()

        // 1. Karte: `activePlan` ist exakt `targetPlan` — simuliert
        // `DashboardView.missedRunDaysModel` mit `activePlans.first ==
        // targetPlan`.
        guard let card = MissedRunDaysCardModel.make(
            for: profile, activePlan: targetPlan, in: context, now: fixedNow, calendar: utc
        ) else {
            return XCTFail("Hinweis haette fuer targetPlan erscheinen muessen")
        }
        guard let cardAdjustment = card.coachAdjustment else {
            return XCTFail("CTA haette verfuegbar sein muessen")
        }

        // 2. "Vorschau öffnet sich korrekt": `DashboardView` übergibt
        // dasselbe `(profile, plan)`-Paar an `CoachAdjustmentPreviewView`,
        // die intern genau diesen Aufruf macht (siehe
        // `CoachAdjustmentPreviewView.model`). Muss DIESELBE Kombination
        // liefern wie die, die der Karten-CTA bereits verspricht — und ihre
        // anfassbaren Tage müssen tatsächlich zu `targetPlan` gehören, NICHT
        // zu `decoyPlan`.
        guard let previewModel = CoachAdjustmentCardModel.make(for: profile, activePlan: targetPlan) else {
            return XCTFail("Preview haette ein Modell fuer targetPlan liefern muessen")
        }
        XCTAssertEqual(previewModel.fingerprint, cardAdjustment.fingerprint, "Karte und Vorschau muessen denselben Vorschlag meinen")
        guard case .ready(let eligibleIDs) = previewModel.analysis.cardioAvailability else {
            return XCTFail("erwartet: mindestens ein anfassbarer Cardio-Tag auf targetPlan")
        }
        let targetPlanDayIDs = Set(targetPlan.days.map(\.persistentModelID))
        let decoyPlanDayIDs = Set(decoyPlan.days.map(\.persistentModelID))
        XCTAssertTrue(eligibleIDs.allSatisfy(targetPlanDayIDs.contains), "Vorschau darf nur Tage DES referenzierten Plans zeigen")
        XCTAssertTrue(eligibleIDs.allSatisfy { !decoyPlanDayIDs.contains($0) }, "Vorschau darf NIEMALS Tage des anderen aktiven Plans zeigen")

        // 3. "Abbrechen ändert nichts": nur lesen, weder `accept()` noch
        // `dismiss()` aufrufen — BEIDE Pläne (auch der unbeteiligte Decoy)
        // müssen unverändert bleiben.
        let targetDayCountBefore = targetPlan.days.count
        let targetExerciseCountBefore = targetPlan.days[0].activeExercises.count
        let decoyDayCountBefore = decoyPlan.days.count
        let decoyExerciseCountBefore = decoyPlan.days[0].activeExercises.count
        _ = previewModel.analysis // "geöffnet, nur betrachtet"

        XCTAssertEqual(targetPlan.days.count, targetDayCountBefore)
        XCTAssertEqual(targetPlan.days[0].activeExercises.count, targetExerciseCountBefore)
        XCTAssertEqual(decoyPlan.days.count, decoyDayCountBefore)
        XCTAssertEqual(decoyPlan.days[0].activeExercises.count, decoyExerciseCountBefore)
        XCTAssertNil(profile.missedRunHintDismissedFingerprint)
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint)
    }

    func testRejectSurvivesColdStartAndDoesNotLeakSuppressionToTheOtherActivePlan() throws {
        let fixedNow = d(2024, 2, 1)
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let targetPlan = makePlan(activatedAt: d(2024, 1, 1), name: "Zielplan")
        let otherPlan = makePlan(activatedAt: d(2023, 6, 1), name: "Anderer aktiver Plan")
        try context.save()

        guard let card = MissedRunDaysCardModel.make(
            for: profile, activePlan: targetPlan, in: context, now: fixedNow, calendar: utc
        ) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        // "Nicht jetzt" (Ablehnen).
        card.dismiss(profile: profile)
        try context.save()

        // "Kaltstart": komplett neuer `make`-Aufruf, keine In-Memory-Caches.
        XCTAssertNil(MissedRunDaysCardModel.make(
            for: profile, activePlan: targetPlan, in: context, now: fixedNow, calendar: utc
        ), "Ablehnen muss den Kaltstart ueberstehen")

        // Der ANDERE aktive Plan hat eine eigene, abweichende Planfassung
        // (anderes `activatedAt` -> anderer Fingerprint) — die Ablehnung fuer
        // `targetPlan` darf ihn NICHT fälschlich mit-unterdrücken, falls er
        // eigenständig ebenfalls eine Versäumnis-Situation hätte.
        guard let otherCard = MissedRunDaysCardModel.make(
            for: profile, activePlan: otherPlan, in: context, now: fixedNow, calendar: utc
        ) else {
            return XCTFail("der andere aktive Plan haette unabhaengig seinen EIGENEN Hinweis zeigen muessen")
        }
        XCTAssertNotEqual(otherCard.fingerprint, card.fingerprint, "unterschiedliche Planfassungen -> unterschiedliche Fingerprints")
    }
}
#endif
