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
    private let fingerprint: String

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
        let planInput = proposedGoal.map(CardioFeasibilityCalculator.planGeneratorInput(for:))
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
    @discardableResult
    public func accept(profile: UserBodyProfile, in context: ModelContext) -> TrainingPlan? {
        guard hasPlan,
              let planInput, let planResult, let proposedGoal,
              let raceDate = profile.cardioRaceDate,
              let weeklyVolume = profile.weeklyBaseVolumeKm
        else { return nil }
        let plan = PlanGeneratorInstantiator.build(
            from: planInput, in: context, result: planResult, generationSource: .cardioCoach
        )
        profile.cardioGoal = proposedGoal
        profile.cardioFeasibilityDismissedFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: proposedGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
        )
        return plan
    }

    /// "Verwerfen"/"Ziel behalten": blendet die Karte aus, bis Ziel,
    /// Renn-Datum oder Wochenvolumen sich aendern. Ruehrt `cardioGoal` NICHT
    /// an - der Nutzer bleibt explizit beim grossen Ziel stehen.
    public func dismiss(profile: UserBodyProfile) {
        profile.cardioFeasibilityDismissedFingerprint = fingerprint
    }
}
#endif
