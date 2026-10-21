#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// reine Analyse, welche Tage eines bestehenden, AKTIVEN `TrainingPlan`
/// eine Coach-Aktivierung automatisch anpassen darf, und ob die
/// vorhandene Bein-Kraftarbeit zum neuen Laufziel passt. Keine
/// SwiftData-Mutation hier - nur Lesen/Klassifizieren, siehe
/// `PlanGeneratorInstantiator.applyCoachCardioAdjustment` fuer die
/// eigentliche Anwendung.
public enum RunCoachPlanAdjustment {

    /// Fuenf Faelle laut Produktvorgabe: passende Bein-Arbeit vorhanden
    /// (`unchanged`), ueberwiegend Oberkoerper (`addSmallAddition`),
    /// bereits umfangreich (`redistribute`), wenig Zeit/Platz
    /// (`replaceForTime`), keine tragfaehige Kombination (`conflict`).
    ///
    /// Wichtige Grenze (Paket 1, Leitplanke 5): diese Klassifikation
    /// erkennt nur, ob Bein-Muskelgruppen ÜBERHAUPT in ausreichendem
    /// Satzvolumen vorkommen (ueber die bestehende, fuer Hypertrophie-
    /// Volumensteuerung gedachte `MuscleVolumeBucket`-Taxonomie, DEL-082).
    /// Sie bewertet NICHT, ob dieses Volumen fuer den LAUFBEZOGENEN Zweck
    /// (z. B. Laufoekonomie/Verletzungspraevention) tatsaechlich
    /// ausreichend ist - dafuer existiert keine belastbare Regel im Projekt,
    /// und es wird hier bewusst KEINE neue, unbelegte Schwelle dafuer
    /// erfunden. "Vorhanden" ≠ "fuer den Laufcoach-Zweck ausreichend".
    public enum LegWorkRecommendation: Equatable, Sendable {
        case unchanged
        case addSmallAddition
        case redistribute
        case replaceForTime
        case conflict
    }

    /// Welche Cardio-Tage eine Zielaenderung automatisch anpassen darf.
    public enum CardioAvailability: Equatable, Sendable {
        /// Mindestens ein Cardio-Tag ist anfassbar - enthaelt dessen IDs in
        /// Plan-Reihenfolge (fuer `applyCoachCardioAdjustment`s `zip`).
        case ready([PersistentIdentifier])
        /// Der Plan hat entweder keinen Cardio-Tag, oder jeder vorhandene
        /// ist geschuetzt (manuell/editiert/mit Historie) - keiner darf
        /// automatisch angepasst werden. Der Aufrufer bietet in diesem Fall
        /// nur "als neuen Plan erstellen"/"beibehalten" an, keine
        /// In-Place-Anpassung.
        case noEligibleCardioDay
        /// Kein aktiver Plan vorhanden.
        case noActivePlan
    }

    public struct Analysis: Equatable, Sendable {
        public let cardioAvailability: CardioAvailability
        public let legWork: LegWorkRecommendation
    }

    /// Bein-Muskelgruppen laut bestehender `MuscleGroup`-Taxonomie
    /// (`Sources/FitnessAppCore/Domain/DomainEnums.swift`) - keine neue
    /// Klassifikation.
    private static let legMuscleGroups: Set<MuscleGroup> = [.quads, .hamstrings, .glutes, .calves]

    /// A12/Architektur-Antwort (Paket 1): ein Tag darf automatisch
    /// angepasst werden, wenn er vom Wizard erzeugt UND seither
    /// unveraendert ist (`generationFingerprint == currentContentFingerprint`,
    /// exakt dasselbe Prinzip wie `PlanGeneratorInstantiator.recalculate`)
    /// UND keine Trainingshistorie traegt. Manuell hinzugefuegte Tage
    /// (kein Fingerprint) oder seither editierte Tage (Fingerprint weicht
    /// ab) sind IMMER geschuetzt.
    ///
    /// Wichtige Grenze (Paket 1, Leitplanke 4): "Fingerprint stimmt
    /// ueberein" heisst nur "seit der Erzeugung NICHT NACHWEISLICH
    /// editiert" - NICHT "der Nutzer wollte diesen Tag bewusst austauschbar
    /// lassen". Ein gespeicherter `TrainingPlan`/`TrainingDay` kennt (anders
    /// als `PlanDraft.isContentFixed`/`isPositionFixed`, die NUR in der
    /// Wizard-Entwurfsschicht vor dem ersten Speichern existieren) KEIN
    /// explizites Fixierungs-Konzept. Diese Funktion behauptet daher
    /// ausdruecklich KEINE Fixierungs-Unterstuetzung, die es auf einem
    /// bereits aktiven Plan real nicht gibt - "nicht erfasst" (kein
    /// Fixierungsfeld vorhanden) ist NICHT dasselbe wie "frei ersetzbar".
    /// Der Fingerprint-Vergleich bleibt der einzige verfuegbare,
    /// nachweisbare Signal-Kandidat fuer "wurde seither angefasst".
    /// Korrektur (Paket 1, Teil 3): `TrainingDay.type == .cardio` reicht
    /// NICHT aus, um einen Cardio-Tag zu erkennen - `PlanGenerator.generate`
    /// (der Ziel-gefuehrte "Plan bauen"-Pfad, genau der, den dieses Paket
    /// anspricht) stempelt JEDEN generierten Tag hartcodiert mit
    /// `type: .fullBody`, unabhaengig vom Inhalt (verifiziert durch Lesen
    /// von `PlanGenerator.generate`). `.cardio` als Tagestyp wird
    /// ausschliesslich von den kuratierten `ProgramTemplates` gesetzt. Die
    /// tatsaechlich verlaessliche Erkennung laeuft daher ueber die
    /// Uebungen selbst (`Exercise.isCardio`, von `PlanGenerator` fuer jede
    /// Lauf-/Rad-Uebung gesetzt) - deckt BEIDE Ursprungspfade ab.
    private static func isCardioDay(_ day: TrainingDay) -> Bool {
        if day.type == .cardio { return true }
        let exercises = day.activeExercises
        return !exercises.isEmpty && exercises.allSatisfy(\.isCardio)
    }

    public static func isEligibleForAdjustment(_ day: TrainingDay) -> Bool {
        guard day.generationFingerprint != nil,
              day.generationFingerprint == day.currentContentFingerprint
        else { return false }
        return day.sessions.isEmpty
    }

    /// Geteilte Filterung fuer `analyze` UND `CoachAdjustmentCardModel.accept`
    /// (Leitplanke 3: `accept` berechnet die anfassbaren Tage am JETZT
    /// aktuellen Planzustand neu, statt veraltete IDs aus `analyze`
    /// weiterzureichen - derselbe Grundsatz wie bei der Coach-
    /// Reaktivierungs-Pruefung).
    public static func eligibleCardioDays(in plan: TrainingPlan) -> [TrainingDay] {
        plan.days.filter(isCardioDay).filter(isEligibleForAdjustment)
    }

    public static func analyze(plan: TrainingPlan?) -> Analysis {
        guard let plan else {
            return Analysis(cardioAvailability: .noActivePlan, legWork: .conflict)
        }

        let eligibleCardio = eligibleCardioDays(in: plan)
        let cardioAvailability: CardioAvailability = eligibleCardio.isEmpty
            ? .noEligibleCardioDay
            : .ready(eligibleCardio.map(\.persistentModelID))

        let eligibleStrengthDays = plan.days.filter {
            $0.type != .rest && !isCardioDay($0) && isEligibleForAdjustment($0)
        }
        let legWork = legWorkRecommendation(eligibleStrengthDays: eligibleStrengthDays)

        return Analysis(cardioAvailability: cardioAvailability, legWork: legWork)
    }

    private static func legWorkRecommendation(eligibleStrengthDays: [TrainingDay]) -> LegWorkRecommendation {
        guard !eligibleStrengthDays.isEmpty else {
            // Keine anfassbare Kraft-Tage (alles manuell/editiert/mit
            // Historie) - keine tragfaehige Kombination fuer eine
            // automatische Ergaenzung, der Nutzer muesste selbst Platz
            // schaffen.
            return .conflict
        }

        let legSets = eligibleStrengthDays
            .flatMap(\.activeExercises)
            .filter { $0.primaryMuscle.map(legMuscleGroups.contains) ?? false }
            .reduce(0) { $0 + $1.sets }

        switch MuscleVolumeBucket(setsThisWeek: legSets) {
        case .maintenance, .optimal:
            return .unchanged
        case .overreaching:
            return .redistribute
        case .untrained:
            // Faustregel (keine wissenschaftliche Herleitung, nur ein
            // einfacher Platz-Proxy): ein Tag mit bereits >=6 Uebungen hat
            // keinen Platz fuer eine Ergaenzung ohne etwas zu entfernen.
            let isAnyDayAlreadyFull = eligibleStrengthDays.contains { $0.activeExercises.count >= 6 }
            return isAnyDayAlreadyFull ? .replaceForTime : .addSmallAddition
        }
    }
}
#endif
