#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// die "Coach aktiviert → bestehenden Plan anpassen"-Vorschlagskarte.
///
/// Leitplanke 6 (Koordination mit `CardioFeasibilityCardModel`): beide
/// Karten duerfen fuer dieselbe Ziel/Renndatum/Wochenvolumen-Kombination
/// NIE gleichzeitig angeboten werden. Vertrag: dieses Modell ist nur dann
/// nicht-`nil`, wenn ein AKTIVER Plan existiert - ein Aufrufer, der
/// BEIDE Karten kennt, PRUEFT DIESES MODELL ZUERST und zeigt
/// `CardioFeasibilityCardModel` nur, wenn `CoachAdjustmentCardModel.make`
/// `nil` liefert (kein aktiver Plan, Coach aus, oder kein Ziel/Renndatum/
/// Wochenvolumen gepflegt) — die neue Karte hat Vorrang, sobald ein
/// aktiver Plan existiert, die alte bleibt fuer den reinen
/// "kein aktiver Plan"-Fall zustaendig. UI-Verdrahtung an den drei
/// Aufrufstellen (ProfileEditorView/DashboardView/PlansListView) steht
/// noch aus — dieser Vertrag gilt fuer JEDE davon.
public struct CoachAdjustmentCardModel: Equatable {
    public let verdict: CardioFeasibilityCalculator.Result
    public let analysis: RunCoachPlanAdjustment.Analysis
    public let fingerprint: String

    /// Leitplanke 1: eindeutig ablesbar, ob GENAU DIESE Kombination bereits
    /// uebernommen wurde — ueber das separate
    /// `UserBodyProfile.cardioPlanAdjustmentFingerprint` (siehe dortige
    /// Doku: NICHT `cardioFeasibilityDismissedFingerprint`, das nicht
    /// zwischen Ablehnen/Uebernehmen unterscheiden kann).
    public let isAlreadyApplied: Bool

    public static func make(for profile: UserBodyProfile, activePlan: TrainingPlan?) -> CoachAdjustmentCardModel? {
        guard let activePlan,
              profile.cardioCoachingEnabled,
              let raceDate = profile.cardioRaceDate,
              let weeklyVolume = profile.weeklyBaseVolumeKm,
              let verdict = CardioFeasibilityCalculator.evaluate(
                  goal: profile.cardioGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
              )
        else { return nil }

        let fingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: profile.cardioGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
        )
        return CoachAdjustmentCardModel(
            verdict: verdict,
            analysis: RunCoachPlanAdjustment.analyze(plan: activePlan),
            fingerprint: fingerprint,
            isAlreadyApplied: profile.cardioPlanAdjustmentFingerprint == fingerprint
        )
    }

    /// Nur die generierten Cardio-Tagesinhalte aus einem vollen
    /// `CardioFeasibilityCalculator.planGeneratorInput(for:)`-Ergebnis
    /// (das mischt Lauf- UND Kraft-Tage) - kein zweiter Cardio-Rechner,
    /// reiner Filter auf das bereits vorhandene Generator-Ergebnis.
    public static func cardioOnlyDaySpecs(for goal: CardioGoal) -> [DaySpec] {
        let result = PlanGenerator.generate(from: CardioFeasibilityCalculator.planGeneratorInput(for: goal))
        return result.days.map(\.spec).filter { spec in
            !spec.exercises.isEmpty && spec.exercises.allSatisfy(\.isCardio)
        }
    }

    /// Leitplanke 3 (Wiederholungssicherheit fuer den Merge-Pfad):
    /// `PlanCreationOperation` schuetzt nachweislich nur den "neuen Plan
    /// erzeugen"-Pfad (`CardioFeasibilityCardModel.accept`, andere
    /// Semantik: erzeugen statt veraendern) - fuer diesen Merge-Pfad gilt
    /// ein EIGENER, einfacherer Schutz: `isAlreadyApplied` (oben, aus
    /// `make` fuer GENAU diesen `fingerprint` berechnet) macht einen
    /// zweiten `accept`-Aufruf fuer dieselbe Kombination (Doppeltap, erneuter
    /// Tap nach bereits erfolgreicher Uebernahme) zu einem kompletten No-Op
    /// — kein erneutes `applyCoachCardioAdjustment`, keine zusaetzlichen
    /// Tage/Uebungen. Schlaegt das Speichern mitten im Anwenden fehl, rollt
    /// `applyCoachCardioAdjustment` (ueber `revert`, siehe dortige Doku)
    /// bereits vollstaendig zurueck, BEVOR `cardioPlanAdjustmentFingerprint`
    /// gesetzt wird (siehe unten) — ein erneuter Versuch nach einem Fehler
    /// sieht den Plan daher im exakten Vorzustand und wendet dieselbe
    /// Anpassung korrekt (nicht doppelt) an.
    ///
    /// Berechnet die anfassbaren Tage am JETZT aktuellen `plan`-Zustand neu
    /// (`RunCoachPlanAdjustment.eligibleCardioDays`), nicht aus einer
    /// moeglicherweise veralteten `analysis` von `make`.
    ///
    /// Leitplanke 2: ruehrt `profile.cardioCoachingEnabled` (Praeferenz)
    /// NIEMALS an — nur `cardioPlanAdjustmentFingerprint` (Zustand "wurde
    /// uebernommen"). Beide sind bewusst getrennte Dinge.
    /// Paket-3a-Restpunkt 2 (Planbindung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
    /// `now`/`calendar` sind injizierbar (Default = echtes `Date()`/`.current`,
    /// identisches Muster wie `MissedRunDaysCardModel.make`) — nur fuer
    /// deterministische Tests der Unterdrueckung unten gebraucht, das
    /// Produktivverhalten bleibt unveraendert (echte Zeit).
    @discardableResult
    @MainActor
    public func accept(
        plan: TrainingPlan, profile: UserBodyProfile, in context: ModelContext,
        now: Date = Date(), calendar: Calendar = .current
    ) throws -> Int {
        // Bugfix (Leitplanke 3, vor Geräteeinsatz gefunden): `self.isAlreadyApplied`
        // ist ein am `make`-Zeitpunkt eingefrorener Snapshot (Value-Type) -
        // ein zweiter `accept`-Aufruf auf DERSELBEN Modell-Instanz (z. B. ein
        // Doppeltap, der denselben `CoachAdjustmentCardModel`-Wert zweimal
        // auswertet) wuerde diesen Schutz NICHT greifen sehen, obwohl der
        // erste Aufruf `profile.cardioPlanAdjustmentFingerprint` bereits
        // gesetzt hat. Der eigentliche Schutz MUSS daher `profile` live zum
        // Zeitpunkt dieses Aufrufs lesen, nicht die eingefrorene Kopie.
        guard profile.cardioPlanAdjustmentFingerprint != fingerprint else { return 0 }
        let eligibleDays = RunCoachPlanAdjustment.eligibleCardioDays(in: plan)
        let newCardioDays = Self.cardioOnlyDaySpecs(for: profile.cardioGoal)
        let count = try PlanGeneratorInstantiator.applyCoachCardioAdjustment(
            eligibleDays: eligibleDays, newCardioDays: newCardioDays, in: context
        )
        guard count > 0 else { return 0 }
        profile.cardioPlanAdjustmentFingerprint = fingerprint

        // Restpunkt 2 (Planbindung): dieser Pfad aendert DENSELBEN Plan
        // in-place (`activatedAt` bleibt unveraendert, siehe Typ-Doku oben) -
        // die bereits VOR dieser Anpassung aufgelaufenen Lauf-Versaeumnisse
        // im rollierenden Fenster bleiben dadurch (anders als bei einem
        // echten Planwechsel, der `activatedAt` neu setzt) unveraendert
        // "verfehlt". Ohne diesen Schritt wuerde `MissedRunDaysCardModel`
        // beim naechsten Rendern denselben oder sogar einen NEUEN Hinweis
        // zeigen (ein vorher nicht-laufender Cardio-Tag kann durch die neuen
        // `newCardioDays` erstmals zum Lauf-Tag werden und seine
        // ebenfalls-nie-geloggte Vergangenheit rueckwirkend als verfehlt
        // einbringen) - unmittelbar NACHDEM der Nutzer gerade reagiert hat.
        // Reuse des bestehenden `dismiss()`-Mechanismus statt eines neuen
        // Felds/Mutationspfads: markiert exakt den JETZT aktuellen
        // (Post-Anpassungs-)Zustand als bereits gesehen. Ein echter NEUER
        // Versaeumnis-Fall NACH der Anpassung hebt die Unterdrueckung ganz
        // regulaer wieder auf (Restpunkt 1: `concludedOpportunityCount`
        // steigt mit jeder weiteren verstrichenen Gelegenheit).
        MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now, calendar: calendar)?
            .dismiss(profile: profile)
        return count
    }
}
#endif
