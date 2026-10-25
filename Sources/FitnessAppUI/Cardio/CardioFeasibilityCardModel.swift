#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Handoff "Lauf-Coaching - Machbarkeits-Check": ein Rechenstand, den Profil-
/// Editor, Dashboard und Plan-Tab alle gleich lesen (2.30: "keine
/// gespeicherte ausstehende Empfehlung ... jede Stelle ruft
/// `CardioFeasibilityCalculator` live auf"). Jede Oberflaeche baut ihre
/// eigene Kartenoptik/Copy um dieses Modell herum (Profil: voll, Dashboard:
/// verkuerzt, Plan-Tab: gestrichelter Rand) - geteilt wird nur die
/// Berechnung, nicht das Layout.
public struct CardioFeasibilityCardModel {
    public let currentGoal: CardioGoal
    public let verdict: CardioFeasibilityCalculator.Result
    /// Ziel, fuer das `planInput`/`planResult` gerechnet sind: bei
    /// `verdict.feasible` ist das `currentGoal` selbst, sonst
    /// `verdict.suggestedGoal`. `nil`, wenn selbst das kleinste gepruefte
    /// Ziel (5 km) nicht mehr in der verbleibenden Zeit aufgeht - dann gibt
    /// es nichts vorzuschlagen, nur die Warnung ohne Plan-Vorschau.
    public let proposedGoal: CardioGoal?
    public let planInput: PlanGeneratorInput?
    public let planResult: PlanGenerator.Result?
    /// Identifiziert, welche konkrete Ziel/Renndatum/Wochenvolumen-Kombination dieses Modell
    /// beschreibt. Oeffentlich, damit ein Aufrufer (z.B. `PlansListView`) eine pro Vorgang
    /// gehaltene `PlanCreationOperation` (siehe dortige Doku: "braucht eine neue Instanz")
    /// gezielt dann austauschen kann, wenn sich die angezeigte Karte auf eine ANDERE Kombination
    /// bezieht als die, fuer die der vorherige Vorgang committed wurde - siehe
    /// `PlansListView.acceptOperationFingerprint`.
    public let fingerprint: String

    /// `false` wenn `proposedGoal` zwar existiert, der Generator dafuer aber
    /// nichts gefunden hat (z.B. eine leere Bibliotheks-Kombination) - der
    /// Aufrufer sollte den "Uebernehmen"/"Vorschlag annehmen"-Knopf dann
    /// deaktivieren, gleiches Prinzip wie `PlanBuilderView`s "disabled solange
    /// result leer/nil ist".
    public var hasPlan: Bool { !(planResult?.days.isEmpty ?? true) }

    /// Ein fertiger Verdikt-Satz (Wochen noetig/verfuegbar, plus Vorschlag
    /// falls vorhanden) - geteilt zwischen Profil/Dashboard/Plan-Tab, damit
    /// nicht drei Oberflaechen denselben Text unabhaengig zusammensetzen.
    /// Nur die Ueberschrift/Kartenoptik bleibt je Oberflaeche eigen (siehe
    /// Typ-Doku).
    public var detailText: String {
        if verdict.feasible {
            return String(
                format: String(localized: "cardioFeasibility.detail.feasible", bundle: .module),
                verdict.weeksNeeded, verdict.weeksAvailable
            )
        }
        if let suggested = proposedGoal {
            return String(
                format: String(localized: "cardioFeasibility.detail.infeasibleWithSuggestion", bundle: .module),
                verdict.weeksNeeded, verdict.weeksAvailable, String(localized: suggested.localizedName)
            )
        }
        return String(
            format: String(localized: "cardioFeasibility.detail.infeasibleNoSuggestion", bundle: .module),
            verdict.weeksNeeded, verdict.weeksAvailable
        )
    }

    /// `nil`, wenn die Karte auf keiner der drei Oberflaechen erscheinen
    /// soll: Cardio-Coaching aus, kein Renn-Datum, kein Wochenvolumen, Ziel
    /// "Allgemeine Fitness" (kein Zielvolumen, siehe
    /// `CardioFeasibilityCalculator.targetWeeklyVolumeKm`), oder der aktuelle
    /// Fingerprint wurde bereits verworfen/angenommen.
    public static func make(for profile: UserBodyProfile) -> CardioFeasibilityCardModel? {
        guard profile.cardioCoachingEnabled,
              let raceDate = profile.cardioRaceDate,
              let weeklyVolume = profile.weeklyBaseVolumeKm,
              let verdict = CardioFeasibilityCalculator.evaluate(
                  goal: profile.cardioGoal,
                  raceDate: raceDate,
                  weeklyBaseVolumeKm: weeklyVolume
              )
        else { return nil }

        let fingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: profile.cardioGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
        )
        guard profile.cardioFeasibilityDismissedFingerprint != fingerprint else { return nil }

        let proposedGoal: CardioGoal? = verdict.feasible ? profile.cardioGoal : verdict.suggestedGoal
        // Task 9 Nachbesserung (Review-Fund): ohne die hier gebaute
        // `CardioRunProfile` blieb `targetPaceMinutesPerKm` auf JEDEM ueber
        // diese Karte erzeugten Lauf-Tag immer `nil` - diese Funktion
        // rechnet bei jedem Aufruf frisch (kein Caching), die Baseline ist
        // also automatisch immer aktuell, ohne eigene Re-Derive-Logik.
        let planInput = proposedGoal.map { goal in
            CardioFeasibilityCalculator.planGeneratorInput(
                for: goal,
                cardioRunProfile: CardioRunProfile(
                    goal: goal,
                    current5kReferenceSeconds: profile.current5kReferenceSeconds,
                    weeklyBaseVolumeKm: weeklyVolume
                )
            )
        }
        let planResult = planInput.map { PlanGenerator.generate(from: $0) }

        return CardioFeasibilityCardModel(
            currentGoal: profile.cardioGoal,
            verdict: verdict,
            proposedGoal: proposedGoal,
            planInput: planInput,
            planResult: planResult,
            fingerprint: fingerprint
        )
    }

    /// Instanziiert den Vorschlag als echten `TrainingPlan`
    /// (`generationSource == .cardioCoach`) und zieht bei einem kleineren
    /// Vorschlag `profile.cardioGoal` mit (User-Entscheidung: Profil-Anzeige
    /// und gebauter Plan sollen zusammenpassen, sonst wuerde derselbe Check
    /// beim naechsten Aufruf mit dem UNVERAENDERTEN grossen Ziel erneut
    /// "nicht erreichbar" melden). Schreibt den Fingerprint fuer die
    /// NEUE Kombination (Ziel nach dem Mitziehen, gleiches Renn-Datum/
    /// Wochenvolumen) fest, nicht fuer die alte - sonst erschiene die Karte
    /// beim naechsten Aufruf sofort wieder, jetzt positiv fuer das neue Ziel.
    /// `nil`, wenn `hasPlan == false` oder der Generator (defensiv) doch
    /// nichts liefert.
    // Bugfix (CI): PlanGeneratorInstantiator ist @MainActor - der Aufruf aus
    // diesem nicht isolierten Struct-Kontext ist unter Swift 6 ein
    // Compile-Fehler. Die Aufrufer (ProfileEditorView/PlansListView-Button-
    // Actions) laufen ohnehin bereits auf dem Main Actor, kein await noetig.
    ///
    /// Nachbesserung (Task #197, vierte Korrekturrunde, Punkt 3): nimmt jetzt eine vom Aufrufer
    /// gehaltene `PlanCreationOperation` entgegen, statt selbst `createPlan` direkt + `try` zu
    /// rufen. Grund: der cardioGoal-/Fingerprint-Abschluss unten darf NICHT an die unmittelbare
    /// Rueckkehr dieser Funktion gebunden sein - scheitert die Rueckbindung (siehe
    /// `PlanCreationError.createdButRebindFailed`) und wird der Plan erst bei einem SPAETEREN Tap
    /// aufgeloest, muss GENAU DIESER Abschluss (mit den HIER, JETZT bestaetigten Werten von
    /// `proposedGoal`/`raceDate`/`weeklyVolume` - nicht mit denen eines womoeglich spaeter anders
    /// berechneten Aufrufs) alsdann trotzdem laufen. `operation.attempt(...)` uebernimmt das:
    /// `completion` wird als Closure UEBERGEBEN, aber nur beim allerersten erfolgreichen Abschluss
    /// dieser `operation`-Instanz tatsaechlich ausgefuehrt (siehe `PlanCreationOperation`-Typ-Doku)
    /// - ob das SOFORT oder erst bei einem spaeteren `attempt(...)`/`resumeIfCommitted(...)`-Aufruf
    /// passiert, macht fuer das Ergebnis keinen Unterschied. Liefert den vollen
    /// `PlanCreationOperation.Outcome` statt nur `TrainingPlan?` - der Aufrufer leitet Button-
    /// Beschriftung/Fehlermeldung direkt daraus ab (siehe dortige Typ-Doku), kein `throws` mehr
    /// noetig.
    @discardableResult
    @MainActor
    public func accept(
        profile: UserBodyProfile, in context: ModelContext, using operation: PlanCreationOperation,
        activePlan: TrainingPlan? = nil
    ) -> PlanCreationOperation.Outcome? {
        // Einmal committed, ist die urspruengliche Vorbedingungspruefung hinfaellig - es wird
        // nichts mehr NEU erzeugt (siehe `PlanCreationOperation`-Doku: `create()` ist nach dem
        // ersten Commit fuer diese Instanz strukturell unerreichbar), nur noch eine bereits
        // abgeschlossene Erstellung aufgeloest und ihr Abschluss ggf. nachgeholt. Ein inzwischen
        // ggf. veraendertes `profile` (z.B. `hasPlan` waere jetzt `false`) darf diese Wiederaufnahme
        // nicht blockieren.
        if let resumed = operation.resumeIfCommitted(in: context) {
            return resumed
        }
        // Task 7 (Duplikat-Vermeidung, Laufcoaching-Plan-Integration): existiert bereits ein
        // AKTIVER, anpassbarer Plan (`activePlan` nicht `nil` UND
        // `RunCoachPlanAdjustment.analyze(plan:).cardioAvailability == .ready`), wird GENAU
        // DIESER Plan angepasst statt ein zweiter, separater `TrainingPlan` erzeugt - wiederholte
        // Zielaenderungen erzeugten vorher bei jedem Tap einen weiteren `generationSource ==
        // .cardioCoach`-Plan. Reuse des bereits in Paket 1 gebauten/getesteten
        // `CoachAdjustmentCardModel`/`RunCoachPlanAdjustment`-Pfads statt einer zweiten
        // Implementierung. Dieser Zweig braucht `operation` bewusst NICHT: das Risiko, gegen das
        // `PlanCreationOperation` unten schuetzt (ein committeter, aber nicht mehr aufloesbarer
        // NEUER Plan), existiert hier nicht - es wird kein neuer Plan erzeugt, nur der bereits
        // bekannte `activePlan` veraendert. `CoachAdjustmentCardModel.accept` traegt dafuer
        // seinen EIGENEN Doppeltap-Schutz (`profile.cardioPlanAdjustmentFingerprint`, siehe
        // dortige Doku). Fehlt `activePlan`, existiert kein aktiver Plan (`.noActivePlan`) oder
        // ist keiner seiner Cardio-Tage anfassbar (`.noEligibleCardioDay`), bleibt der bisherige
        // "neuen Plan erstellen"-Pfad unten unveraendert der Fallback.
        //
        // Review-Korrektur (Critical), Wortlaut aktualisiert nach Fix I-1 (Final-Review Fix-Runde 2):
        // seit Fix I-1 berechnet `CoachAdjustmentCardModel.make` seinen `fingerprint` aus
        // `proposedGoal ?? profile.cardioGoal` (demselben effektiven Ziel, das `proposedGoal` selbst
        // nutzt) - ein veralteter, am ALTEN Ziel haengender Fingerprint (der urspruengliche Grund
        // fuer dieses Vorziehen) ist dadurch kein Risiko mehr, auch OHNE die Mutation hier.
        // `profile.cardioGoal` muss trotzdem VOR `make`/`accept` auf `proposedGoal` vorgezogen
        // werden - aus einem ANDEREN, weiterhin gueltigen Grund: `make(for: activePlan:)` berechnet
        // sein EIGENES `verdict`/`proposedGoal` aus `profile.cardioGoal` NEU, mit den zum
        // `accept`-Zeitpunkt AKTUELLEN (moeglicherweise seit der Vorschau geaenderten) `raceDate`/
        // `weeklyVolume`. Ohne das Vorziehen wuerde diese Neuberechnung vom noch unveraenderten,
        // urspruenglich infeasiblen `profile.cardioGoal` ausgehen und `suggestedGoal(below:...)`
        // koennte - bei inzwischen geaenderten `raceDate`/`weeklyVolume` - ein ANDERES kleineres Ziel
        // liefern als das hier bereits entschiedene `proposedGoal`. Das Vorziehen macht die
        // Neuberechnung stattdessen zu einer direkten Machbarkeits-Pruefung GENAU DIESES
        // `proposedGoal` (es wird dann schlicht `feasible`, `make`s eigenes `proposedGoal` bleibt
        // unveraendert `profile.cardioGoal`) - `adjustmentModel.accept` wendet so sicher dasselbe,
        // hier bereits bestaetigte Ziel an.
        //
        // Review-Korrektur (Important): die Plan-Mutation selbst wird bei einem Fehlschlag von
        // `adjustmentModel.accept` bereits vollstaendig intern zurueckgerollt (siehe
        // `PlanGeneratorInstantiator.revert`/`applyCoachCardioAdjustment`-Doku) - `profile.cardioGoal`
        // ist davon aber NICHT betroffen, es wurde ja hier, ausserhalb dieses rollback-faehigen
        // Bereichs, direkt zugewiesen. Ohne explizites Zuruecksetzen bliebe `profile.cardioGoal`
        // nach einem gescheiterten Versuch auf `proposedGoal` haengen, OHNE dass irgendetwas
        // tatsaechlich uebernommen wurde - ein inkonsistenter Teilzustand, den der sibling "neuen
        // Plan erstellen"-Pfad unten strukturell gar nicht erst zulassen kann (er setzt
        // `profile.cardioGoal` ausschliesslich in der `completion`-Closure, die nur bei
        // bestaetigtem `.success` ueberhaupt laeuft). `previousCardioGoal` haelt den Stand VOR
        // dieser Zuweisung fest, um ihn in jedem Fehlschlag-Pfad (Guard unten UND `catch`)
        // wiederherzustellen.
        if let activePlan,
           case .ready = RunCoachPlanAdjustment.analyze(plan: activePlan).cardioAvailability,
           let proposedGoal,
           let raceDate = profile.cardioRaceDate,
           let weeklyVolume = profile.weeklyBaseVolumeKm {
            let previousCardioGoal = profile.cardioGoal
            profile.cardioGoal = proposedGoal
            guard let adjustmentModel = CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan) else {
                // Defensiv: nach dem Mitziehen oben sollte `make` hier nicht mehr scheitern
                // koennen (`proposedGoal` ist per Definition ein fuer dasselbe Renn-Datum/
                // Wochenvolumen bereits als erreichbar geprueftes Ziel) - ein unerwartetes `nil`
                // behandeln wir wie einen gescheiterten Abschluss, statt blind weiterzumachen.
                profile.cardioGoal = previousCardioGoal
                return .failedBeforeCommit
            }
            do {
                _ = try adjustmentModel.accept(plan: activePlan, profile: profile, in: context)
                // Nachbesserung (P2.3-Review, Punkt 3, siehe Typ-Doku oben): denselben Grundsatz
                // wie die `completion`-Closure unten befolgen - NICHT `adjustmentModel.fingerprint`
                // (das waere der VOR dem Mitziehen berechnete, alte Stand), sondern frisch aus
                // `proposedGoal` berechnet, sonst erschiene die Karte beim naechsten Aufruf sofort
                // wieder.
                profile.cardioFeasibilityDismissedFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
                    goal: proposedGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
                )
                return .success(activePlan)
            } catch {
                // Siehe Doku-Block oben: die Plan-Mutation ist bereits vollstaendig zurueckgerollt -
                // `profile.cardioGoal` muss das symmetrisch nachvollziehen, sonst bliebe das
                // Vorschlags-Ziel haengen, obwohl nichts uebernommen wurde.
                profile.cardioGoal = previousCardioGoal
                return .failedBeforeCommit
            }
        }
        guard hasPlan,
              let planInput, let planResult, let proposedGoal,
              let raceDate = profile.cardioRaceDate,
              let weeklyVolume = profile.weeklyBaseVolumeKm
        else { return nil }
        // Nachbesserung (P2.3): `createPlan(for:)` buendelt die vorher hier
        // inline stehende Resolve+Build-Sequenz (siehe dortige Doku) — ein
        // Aufruf statt vier unabhaengiger Kopien derselben zwei Zeilen.
        return operation.attempt(
            in: context,
            create: {
                try PlanGeneratorInstantiator.createPlan(
                    from: planInput, result: planResult,
                    for: profile, generationSource: .cardioCoach, in: context
                )
            },
            completion: {
                // Nachbesserung (P2.3-Review, Punkt 3): `cardioGoal`/Fingerprint werden NUR bei
                // TATSAECHLICHEM Erfolg fortgeschrieben (siehe `PlanCreationOperation.attempt`s
                // `completion`-Vertrag: laeuft nur bei `.success`). Nutzt bewusst die HIER
                // (zum Zeitpunkt dieses Aufrufs) bestaetigten `proposedGoal`/`raceDate`/
                // `weeklyVolume` - nicht Werte, die ein spaeterer, erneuter `accept`-Aufruf
                // (z.B. nach einer zwischenzeitlichen Profilaenderung) anders berechnen wuerde.
                profile.cardioGoal = proposedGoal
                profile.cardioFeasibilityDismissedFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
                    goal: proposedGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
                )
            }
        )
    }

    /// "Verwerfen"/"Ziel behalten": blendet die Karte aus, bis Ziel,
    /// Renn-Datum oder Wochenvolumen sich aendern. Ruehrt `cardioGoal` NICHT
    /// an - der Nutzer bleibt explizit beim grossen Ziel stehen.
    public func dismiss(profile: UserBodyProfile) {
        profile.cardioFeasibilityDismissedFingerprint = fingerprint
    }

    /// Nachtrag "Plan anpassen": derselbe Instanziierungs-Effekt wie
    /// `accept(profile:in:)`, aber fuer einen im "Plan bauen"-Assistenten
    /// selbst angepassten Input/Ergebnis statt `planInput`/`planResult` -
    /// kein zweiter Preview-Rechner, der Wizard liefert `PlanGenerator.generate`
    /// bereits selbst. Ruehrt bewusst NICHT `profile.cardioGoal` an: der
    /// angepasste Mix hat nach freier Bearbeitung keine verlaessliche 1:1-
    /// Entsprechung zu einem `CardioGoal` mehr. Schreibt trotzdem denselben
    /// Fingerprint wie eine direkte Annahme (empfohlene Entscheidung im
    /// Ticket) - sonst zeigt der Hinweis auf den anderen beiden Oberflaechen
    /// weiter an, obwohl der Nutzer sein Anliegen bereits geloest hat. Da
    /// `cardioGoal` hier unveraendert bleibt, ist `self.fingerprint` (aus
    /// `make(for:)`, bereits fuer den aktuellen `profile`-Stand berechnet)
    /// exakt der richtige Wert - keine Neuberechnung noetig.
    /// Nachbesserung (Task #197, vierte Korrekturrunde, Punkt 3): gleiches Muster wie
    /// `accept(profile:in:using:)` oben - `operation` traegt den Abschluss (hier nur der
    /// Fingerprint, `cardioGoal` bleibt unveraendert) ueber eine moegliche spaetere
    /// Wiederaufnahme hinweg, mit dem HIER (zum Zeitpunkt dieses Aufrufs) bereits bekannten
    /// `self.fingerprint`.
    @discardableResult
    @MainActor
    public func acceptCustom(
        input: PlanGeneratorInput,
        result: PlanGenerator.Result,
        profile: UserBodyProfile,
        in context: ModelContext,
        using operation: PlanCreationOperation
    ) -> PlanCreationOperation.Outcome? {
        if let resumed = operation.resumeIfCommitted(in: context) {
            return resumed
        }
        guard !result.days.isEmpty else { return nil }
        // Nachbesserung (P2.3): siehe `accept(profile:in:using:)` oben.
        let confirmedFingerprint = fingerprint
        return operation.attempt(
            in: context,
            create: {
                try PlanGeneratorInstantiator.createPlan(
                    from: input, result: result,
                    for: profile, generationSource: .cardioCoach, in: context
                )
            },
            completion: {
                profile.cardioFeasibilityDismissedFingerprint = confirmedFingerprint
            }
        )
    }
}
#endif
