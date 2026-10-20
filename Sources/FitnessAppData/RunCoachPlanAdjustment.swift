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
    /// ab) sind IMMER geschuetzt - das ist der gesamte Schutzmechanismus
    /// fuer "manuelle Aenderungen/Fixierungen", keine neue Logik noetig.
    public static func isEligibleForAdjustment(_ day: TrainingDay) -> Bool {
        guard day.generationFingerprint != nil,
              day.generationFingerprint == day.currentContentFingerprint
        else { return false }
        return day.sessions.isEmpty
    }

    public static func analyze(plan: TrainingPlan?) -> Analysis {
        guard let plan else {
            return Analysis(cardioAvailability: .noActivePlan, legWork: .conflict)
        }

        let cardioDays = plan.days.filter { $0.type == .cardio }
        let eligibleCardioDays = cardioDays.filter(isEligibleForAdjustment)
        let cardioAvailability: CardioAvailability = eligibleCardioDays.isEmpty
            ? .noEligibleCardioDay
            : .ready(eligibleCardioDays.map(\.persistentModelID))

        let eligibleStrengthDays = plan.days.filter {
            $0.type != .cardio && $0.type != .rest && isEligibleForAdjustment($0)
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
