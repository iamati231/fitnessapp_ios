#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path):
/// ersetzt das bisherige, nicht-deterministische `activePlans.first` auf den
/// Dashboard-Cardio-Karten (Coach-Anpassung, Laufversaeumnis-Hinweis) durch
/// eine einzige, dokumentierte Regel. Liegt in `FitnessAppData` statt
/// `FitnessAppCore`, weil die Signatur `[TrainingPlan]` nimmt und
/// `TrainingPlan` ein SwiftData-Modell dieses Moduls ist (gleiche Begruendung
/// wie bei `RunCoachPlanAdjustment`/`ProgramInstantiator`). Nimmt ein bereits
/// gefetchtes Array entgegen, fetcht/mutiert selbst nichts — eine
/// deterministische Funktion ueber ihren Input.
public enum ActivePlanResolver {
    /// Eindeutige, dokumentierte Regel fuer "welcher aktive Plan ist der
    /// Laufcoaching-relevante" (Review-Punkt 6 - ersetzt die vage
    /// "generationSource == .cardioCoach ODER zuletzt aktiviert"-Formulierung):
    /// 1. Genau EIN Plan mit `generationSource == .cardioCoach` unter den
    ///    aktiven Plaenen -> dieser gewinnt immer.
    /// 2. KEIN Plan mit `generationSource == .cardioCoach` -> der einzige
    ///    aktive Plan gewinnt, wenn es nur einen gibt; bei mehreren
    ///    aktiven Nicht-Cardio-Plaenen (kein heute vorgesehener Fall,
    ///    aber moeglich) gibt es KEINE verlaessliche Zuordnung -> `nil`,
    ///    niemals ein geratener Plan.
    /// 3. MEHR ALS EIN Plan mit `generationSource == .cardioCoach`
    ///    (Grenzfall, z.B. zwei Laufcoaching-Vorgaenge nacheinander) ->
    ///    der mit dem SPAETESTEN `activatedAt` gewinnt, aber NUR wenn
    ///    dieser Wert unter den Kandidaten eindeutig ist. `TrainingPlan`
    ///    hat kein eigenes stabiles `id`-Feld (nur `activatedAt: Date?`,
    ///    sonst ausschliesslich SwiftDatas interne, dafuer nicht
    ///    vorgesehene `PersistentIdentifier`) - ein erfundener zweiter
    ///    Sortierschluessel waere eine stille, bedeutungslose Pseudo-
    ///    Ordnung. Bei echtem Gleichstand (identischer `activatedAt`-Wert
    ///    ODER mehrere `nil`) unter den Cardio-Coach-Kandidaten -> `nil`,
    ///    niemals eine von der Array-Reihenfolge abhaengige Wahl.
    public static func cardioRelevantPlan(among activePlans: [TrainingPlan]) -> TrainingPlan? {
        let cardioCoachPlans = activePlans.filter { $0.generationSource == .cardioCoach }
        switch cardioCoachPlans.count {
        case 0:
            return activePlans.count == 1 ? activePlans[0] : nil
        case 1:
            return cardioCoachPlans[0]
        default:
            guard let latest = cardioCoachPlans.compactMap(\.activatedAt).max() else { return nil }
            let withLatest = cardioCoachPlans.filter { $0.activatedAt == latest }
            return withLatest.count == 1 ? withLatest[0] : nil
        }
    }
}
#endif
