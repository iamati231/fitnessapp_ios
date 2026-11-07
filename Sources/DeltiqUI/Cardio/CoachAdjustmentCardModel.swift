#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore
import DeltiqData

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// die "Coach aktiviert → bestehenden Plan anpassen"-Vorschlagskarte.
///
/// Leitplanke 6 (Koordination mit `CardioFeasibilityCardModel`): beide
/// Karten duerfen fuer dieselbe Ziel/Renndatum/Wochenvolumen-Kombination
/// NIE gleichzeitig angeboten werden. Vertrag: dieses Modell ist nur dann
/// nicht-`nil`, wenn ein AKTIVER Plan existiert - ein Aufrufer, der
/// BEIDE Karten kennt, PRUEFT DIESES MODELL ZUERST und zeigt
/// `CardioFeasibilityCardModel` nur, wenn `CoachAdjustmentCardModel.make`
/// `nil` liefert (kein aktiver Plan oder Coach aus) — die neue Karte hat
/// Vorrang, sobald ein aktiver Plan existiert, die alte bleibt fuer den
/// reinen "kein aktiver Plan"-Fall zustaendig. UI-Verdrahtung an allen drei
/// Aufrufstellen (ProfileEditorView/DashboardView/PlansListView) ist
/// inzwischen vollstaendig - dieser Vertrag gilt fuer jede davon identisch.
///
/// Task 6 Praezisierung: "kein Ziel/Renndatum/Wochenvolumen gepflegt" macht
/// dieses Modell NICHT mehr `nil` (anders als `CardioFeasibilityCardModel`,
/// dessen Vertrag unveraendert bleibt) - ohne Renn-Datum/Wochenvolumen gibt
/// es nur keinen Machbarkeits-Check (`verdict == nil`), die reine
/// "aktuelles Ziel auf den Plan anwenden"-Funktion bleibt verfuegbar.
public struct CoachAdjustmentCardModel: Equatable {
    /// Task 6 (Decision 3 Teil 1): `nil`, wenn kein Machbarkeits-Check
    /// moeglich ist (kein Renn-Datum oder kein Wochenvolumen gepflegt) -
    /// anders als vorher macht ein fehlender Check das gesamte Modell NICHT
    /// mehr `nil` (siehe `make` unten): die reine "aktuelles Ziel auf den
    /// Plan anwenden"-Funktion bleibt davon unberuehrt, nur gibt es dann
    /// keine Machbarkeits-Meinung anzuzeigen.
    public let verdict: CardioFeasibilityCalculator.Result?
    /// Das Ziel, das tatsaechlich angewendet werden soll - identische
    /// Berechnung wie `CardioFeasibilityCardModel.proposedGoal` (siehe
    /// dortige Doku): bei `verdict.feasible` das unveraenderte
    /// `profile.cardioGoal`, sonst `verdict.suggestedGoal` (`nil`, wenn
    /// selbst das kleinste gepruefte Ziel nicht mehr aufgeht). Ohne Verdikt
    /// (`verdict == nil`, kein Renn-Datum/Wochenvolumen) gibt es keine
    /// Machbarkeits-Meinung - dann faellt `proposedGoal` auf das
    /// unveraenderte `profile.cardioGoal` zurueck ("kein Check moeglich,
    /// nimm was der Nutzer eingestellt hat").
    ///
    /// Task 7: `accept()` und `CoachAdjustmentPreviewView` lesen dieses Feld
    /// jetzt statt des rohen `profile.cardioGoal` - siehe `accept()` unten
    /// fuer die konkrete Verdrahtung ("effectiveProposedGoal").
    public let proposedGoal: CardioGoal?
    public let analysis: RunCoachPlanAdjustment.Analysis
    public let fingerprint: String

    /// Leitplanke 1: eindeutig ablesbar, ob GENAU DIESE Kombination bereits
    /// uebernommen wurde — ueber das separate
    /// `UserBodyProfile.cardioPlanAdjustmentFingerprint` (siehe dortige
    /// Doku: NICHT `cardioFeasibilityDismissedFingerprint`, das nicht
    /// zwischen Ablehnen/Uebernehmen unterscheiden kann).
    public let isAlreadyApplied: Bool

    public static func make(for profile: UserBodyProfile, activePlan: TrainingPlan?) -> CoachAdjustmentCardModel? {
        guard let activePlan, profile.cardioCoachingEnabled else { return nil }

        // `evaluate` nimmt raceDate/weeklyBaseVolumeKm bereits optional
        // entgegen und liefert selbst `nil`, wenn eines von beiden fehlt -
        // derselbe Rechenweg wie `CardioFeasibilityCardModel.make`, hier
        // aber bewusst NICHT hinter einem `guard let`, der das gesamte
        // Modell unterdruecken wuerde (siehe Typ-Doku oben).
        let verdict = CardioFeasibilityCalculator.evaluate(
            goal: profile.cardioGoal, raceDate: profile.cardioRaceDate, weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
        )
        let proposedGoal: CardioGoal?
        if let verdict {
            proposedGoal = verdict.feasible ? profile.cardioGoal : verdict.suggestedGoal
        } else {
            proposedGoal = profile.cardioGoal
        }

        // `suppressionFingerprint` nimmt raceDate/weeklyBaseVolumeKm (anders
        // als `evaluate`) NICHT optional entgegen - fehlen sie, gibt es
        // keine aus Renn-Datum/Wochenvolumen ableitbare Identitaet fuer
        // diese Kombination; der Fingerprint haengt dann allein am (in
        // diesem Fall einzig relevanten) Ziel.
        //
        // Fix I-1 (Final-Review, Round 2): der Fingerprint MUSS aus demselben
        // effektiven Ziel wie `proposedGoal` berechnet werden (`proposedGoal
        // ?? profile.cardioGoal`), NICHT aus dem rohen, moeglicherweise
        // veralteten `profile.cardioGoal` - sonst weicht der hier gespeicherte
        // Fingerprint (vor `accept()`, altes Ziel) von dem ab, den eine
        // FRISCHE `make`-Auswertung NACH `accept()` liefert (`profile.cardioGoal`
        // wurde dort bereits auf `proposedGoal` aktualisiert), und
        // `isAlreadyApplied` ist faelschlich `false`. Gleiches Prinzip wie
        // `CardioFeasibilityCardModel`s `fingerprint`/`proposedGoal` (siehe
        // dortige Doku).
        let effectiveGoal = proposedGoal ?? profile.cardioGoal
        let fingerprint: String
        if let raceDate = profile.cardioRaceDate, let weeklyVolume = profile.weeklyBaseVolumeKm {
            fingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
                goal: effectiveGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
            )
        } else {
            fingerprint = "goalOnly#\(effectiveGoal.rawValue)"
        }

        return CoachAdjustmentCardModel(
            verdict: verdict,
            proposedGoal: proposedGoal,
            analysis: RunCoachPlanAdjustment.analyze(plan: activePlan, targetGoal: effectiveGoal),
            fingerprint: fingerprint,
            isAlreadyApplied: profile.cardioPlanAdjustmentFingerprint == fingerprint
        )
    }

    /// Nur die generierten Cardio-Tagesinhalte aus einem vollen
    /// `CardioFeasibilityCalculator.planGeneratorInput(for:)`-Ergebnis
    /// (das mischt Lauf- UND Kraft-Tage) - kein zweiter Cardio-Rechner,
    /// reiner Filter auf das bereits vorhandene Generator-Ergebnis.
    ///
    /// `cardioRunProfile` (Task 9 Nachbesserung, Review-Fund): wie
    /// `CardioFeasibilityCalculator.planGeneratorInput` selbst - ohne diesen
    /// Parameter bliebe `targetPaceMinutesPerKm` auf jedem ueber diesen
    /// Merge-Pfad erzeugten Lauf-Tag immer `nil`. Default `nil` erhaelt
    /// bestehende Aufrufer/Tests ohne Baseline unveraendert.
    public static func cardioOnlyDaySpecs(for goal: CardioGoal, cardioRunProfile: CardioRunProfile? = nil) -> [DaySpec] {
        let result = PlanGenerator.generate(from: CardioFeasibilityCalculator.planGeneratorInput(for: goal, cardioRunProfile: cardioRunProfile))
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
    /// "Nicht jetzt" fuer die Dashboard-Karte — setzt den Dismiss-Fingerprint,
    /// ohne Plan oder Profil-Ziel anzutasten.
    public func dismiss(profile: UserBodyProfile) {
        profile.cardioAdjustmentCardDismissedFingerprint = fingerprint
    }

    /// `convertStrengthDaysIfNeeded`: Nachbesserung ("Krafttraining bei
    /// Laufzieländerung erhalten"). `false` (Default) - Krafttage werden
    /// NIE angefasst, auch nicht wenn die Ziel-Tabelle sie fuer
    /// `effectiveProposedGoal` als ueberfluessig ausweist; reicht die
    /// Kapazitaet aus bestehenden Lauftagen + einfuegbaren Ruhetagen +
    /// freien Wochentagen dann nicht, liefert `accept()` `0` (wie vor
    /// dieser Nachbesserung und vor dem zurueckgenommenen Zwischenstand).
    /// Nur wenn der Aufrufer diesen Parameter explizit `true` setzt - nach
    /// einer eigenen, separaten Nutzerbestaetigung in
    /// `CoachAdjustmentPreviewView` (nie als Teil des normalen "Auf
    /// aktuellen Plan anwenden") - durfen die ueberzaehligen Krafttage
    /// (`RunCoachPlanAdjustment.convertibleStrengthDays`) zusaetzlich
    /// herangezogen werden.
    @discardableResult
    @MainActor
    public func accept(
        plan: TrainingPlan, profile: UserBodyProfile, in context: ModelContext,
        convertStrengthDaysIfNeeded: Bool = false,
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
        // Task 7 (Decision 3 Teil 2): die anzuwendenden Tage muessen dem
        // tatsaechlich VORGESCHLAGENEN Ziel entsprechen (`proposedGoal`),
        // nicht dem moeglicherweise nicht erreichbaren `profile.cardioGoal`
        // - sonst wendet `accept` genau das Ziel an, das der Machbarkeits-
        // Check gerade als nicht erreichbar verworfen hat. Fallback auf
        // `profile.cardioGoal`, wenn selbst kein kleineres Ziel mehr
        // erreichbar ist (`proposedGoal == nil`, siehe dortige Doku) - dann
        // gibt es keinen besseren Vorschlag, den man stattdessen anwenden
        // koennte.
        let effectiveProposedGoal = proposedGoal ?? profile.cardioGoal
        // Nachbesserung ("Krafttraining bei Laufzieländerung erhalten"):
        // bestehende Krafttage zaehlen nur dann als anfassbar, wenn der
        // Aufrufer das explizit bestaetigt hat (`convertStrengthDaysIfNeeded`)
        // - niemals automatisch nur weil die Ziel-Tabelle sie fuer
        // `effectiveProposedGoal` als ueberfluessig ausweist.
        let eligibleDays = convertStrengthDaysIfNeeded
            ? RunCoachPlanAdjustment.eligibleDaysForGoalChange(in: plan, targetGoal: effectiveProposedGoal)
            : RunCoachPlanAdjustment.eligibleCardioDays(in: plan)
        // Task 9 Nachbesserung: dieselbe Baseline-Weitergabe wie
        // `CardioFeasibilityCardModel.make` - `accept` rechnet bei jedem
        // Aufruf frisch aus dem aktuellen `profile`, die Baseline ist also
        // automatisch immer aktuell, ohne eigene Re-Derive-Logik.
        let newCardioDays = Self.cardioOnlyDaySpecs(
            for: effectiveProposedGoal,
            cardioRunProfile: CardioRunProfile(
                goal: effectiveProposedGoal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )

        let count: Int
        if eligibleDays.isEmpty {
            // Task 7: kein ersetzbarer Cardio-Tag - Fallback auf Task 5/6s
            // Einfuege-Pfad (Ruhetag -> Cardio-Tag). Re-Validierung IMMER frisch
            // am JETZT aktuellen `plan` (`eligibleRestDaysForInsertion`), NIEMALS
            // die beim `make`-Zeitpunkt eingefrorene `analysis.insertableRestDays`
            // - derselbe Grundsatz wie `eligibleCardioDays` oben und
            // `isAlreadyApplied`/`eligibleDays` ueberall sonst in diesem Typ.
            // Review-Korrektur: NICHT `CardioFeasibilityCalculator.runTypeMix(...).count`
            // - das ist ein easy/quality-MUSTER, das ueber die tatsaechliche Lauf-Tage-Zahl
            // ZYKLISCH angewendet wird (`PlanGenerator.swift`: `mix[dayIndex % mix.count]`),
            // keine 1:1-Lauf-Tage-Zahl (stimmt z. B. fuer `.tenK`/`.marathon` nicht mit der
            // echten Tage-Zahl ueberein). `newCardioDays.count` (oben, aus `cardioOnlyDaySpecs`,
            // demselben `PlanGenerator.generate`-Ergebnis) ist die tatsaechliche Anzahl neu zu
            // erzeugender Cardio-Tage fuer dieses Ziel.
            let eligibleRestDays = RunCoachPlanAdjustment.eligibleRestDaysForInsertion(in: plan)
            if eligibleRestDays.isEmpty {
                // Kein isAutoFilledPlaceholder-Ruhetag mehr vorhanden (z.B.
                // nach manuellem Loeschen) - Fallback: neue Tage auf freien
                // Wochentagen erzeugen statt silent 0 zurueckzugeben.
                let freeWds = RunCoachPlanAdjustment.freeWeekdays(in: plan)
                let selectedWds = RunCoachPlanAdjustment.selectWeekdaysForNewDays(
                    free: freeWds, count: newCardioDays.count, otherDays: plan.days
                )
                guard selectedWds.count >= newCardioDays.count else { return 0 }
                count = try PlanGeneratorInstantiator.insertCoachCardioDaysOnFreeWeekdays(
                    plan: plan, weekdays: selectedWds, newCardioDays: newCardioDays, in: context
                )
            } else {
                let selectedRestDays = RunCoachPlanAdjustment.selectRestDaysForInsertion(
                    eligible: eligibleRestDays, count: newCardioDays.count, otherDays: plan.days
                )
                count = try PlanGeneratorInstantiator.insertCoachCardioDays(
                    plan: plan, restDays: selectedRestDays, newCardioDays: newCardioDays, in: context
                )
            }
        } else if newCardioDays.count > eligibleDays.count {
            // Finding 1 (Lauf-Coaching-Audit): neues Ziel braucht MEHR Lauftage als
            // vorhandene anfassbare Cardio-Tage - ALLE eligibleDays ersetzen UND den
            // Rest atomar in freie Ruhetage einfuegen (kein stiller Teilerfolg: reicht
            // der Platz nicht, wirft dies VOR jeder Mutation - derselbe Vertrag wie der
            // reine Einfuege-Pfad oben). Vorher: `applyCoachCardioAdjustment`s `zip`
            // stoppte still bei `eligibleDays.count`, der Rest wurde nie erzeugt, aber
            // trotzdem als vollstaendiger Erfolg gemeldet und der Fingerprint gesetzt.
            let remainderCount = newCardioDays.count - eligibleDays.count
            let eligibleRestDays = RunCoachPlanAdjustment.eligibleRestDaysForInsertion(in: plan)
            if eligibleRestDays.count >= remainderCount {
                let selectedRestDays = RunCoachPlanAdjustment.selectRestDaysForInsertion(
                    eligible: eligibleRestDays, count: remainderCount, otherDays: plan.days
                )
                count = try PlanGeneratorInstantiator.applyCoachCardioAdjustmentInsertingRemainder(
                    eligibleDays: eligibleDays, newCardioDays: newCardioDays,
                    restDays: selectedRestDays, plan: plan, in: context
                )
            } else {
                // Zielwechsel-Fallback: freie Wochentage nutzen wenn Ruhetage nicht allein reichen.
                // Kapazitätsregel: Rest + Free kombiniert (identisch zur UI-Kapazitätsprüfung).
                // shortcut: Ersetzung + Einfuegen in zwei/drei Schritten statt atomar;
                // upgradeable zu applyCoachCardioAdjustmentInsertingRemainderOnFreeWeekdays
                // wenn Rollback bei save-Fehlern in Schritt 2 gebraucht wird.
                let freeWds = RunCoachPlanAdjustment.freeWeekdays(in: plan)
                let restCount = eligibleRestDays.count
                let neededFromFree = remainderCount - restCount
                guard freeWds.count >= neededFromFree else { return 0 }
                if restCount > 0 {
                    // Kombiniert: alle verfügbaren Ruhetage + Rest auf freien Wochentagen.
                    let selectedRestDays = RunCoachPlanAdjustment.selectRestDaysForInsertion(
                        eligible: eligibleRestDays, count: restCount, otherDays: plan.days
                    )
                    let step1Count = try PlanGeneratorInstantiator.applyCoachCardioAdjustmentInsertingRemainder(
                        eligibleDays: eligibleDays,
                        newCardioDays: Array(newCardioDays.prefix(eligibleDays.count + restCount)),
                        restDays: selectedRestDays, plan: plan, in: context
                    )
                    let step2Count = neededFromFree > 0 ? try PlanGeneratorInstantiator.insertCoachCardioDaysOnFreeWeekdays(
                        plan: plan,
                        weekdays: RunCoachPlanAdjustment.selectWeekdaysForNewDays(
                            free: freeWds, count: neededFromFree, otherDays: plan.days
                        ),
                        newCardioDays: Array(newCardioDays.dropFirst(eligibleDays.count + restCount)),
                        in: context
                    ) : 0
                    count = step1Count + step2Count
                } else {
                    let selectedWds = RunCoachPlanAdjustment.selectWeekdaysForNewDays(
                        free: freeWds, count: remainderCount, otherDays: plan.days
                    )
                    guard selectedWds.count >= remainderCount else { return 0 }
                    let replaceCount = try PlanGeneratorInstantiator.applyCoachCardioAdjustment(
                        eligibleDays: eligibleDays,
                        newCardioDays: Array(newCardioDays.prefix(eligibleDays.count)),
                        in: context
                    )
                    let insertCount = try PlanGeneratorInstantiator.insertCoachCardioDaysOnFreeWeekdays(
                        plan: plan,
                        weekdays: selectedWds,
                        newCardioDays: Array(newCardioDays.dropFirst(eligibleDays.count)),
                        in: context
                    )
                    count = replaceCount + insertCount
                }
            }
        } else if newCardioDays.count < eligibleDays.count {
            // Finding 1: neues Ziel braucht WENIGER Lauftage - die ersten
            // `newCardioDays.count` eligibleDays ersetzen, die ueberzaehligen auf
            // Ruhetage zuruecksetzen statt sie unveraendert/unerklaert stehen zu lassen.
            // Vorher: die ueberzaehligen Tage blieben als veraltete, zum neuen Ziel
            // nicht mehr passende Cardio-Tage unangetastet stehen.
            count = try PlanGeneratorInstantiator.applyCoachCardioAdjustmentReleasingSurplus(
                eligibleDays: eligibleDays, newCardioDays: newCardioDays, in: context
            )
        } else {
            count = try PlanGeneratorInstantiator.applyCoachCardioAdjustment(
                eligibleDays: eligibleDays, newCardioDays: newCardioDays, in: context
            )
        }
        guard count > 0 else { return 0 }
        profile.cardioPlanAdjustmentFingerprint = fingerprint
        // Mirrors `CardioFeasibilityCardModel.accept`'s completion closure,
        // which also only writes `profile.cardioGoal` after confirmed
        // success - unlike that sibling path, nothing here mutates
        // `profile.cardioGoal` BEFORE this point (no nested
        // `CoachAdjustmentCardModel.make` re-derivation from a live-mutated
        // goal is needed inside this function, since `self` is already a
        // fully-built instance), so there is nothing to roll back on the
        // `throws` path above: a failed `applyCoachCardioAdjustment` leaves
        // `profile.cardioGoal` untouched by construction.
        profile.cardioGoal = effectiveProposedGoal

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
