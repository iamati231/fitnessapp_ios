import Foundation

/// Deltiq-Weiterentwicklung, P3.1 (Doc01 §3 "Zielorientierter Einstieg –
/// Option A", "Ziel zuerst, nicht Langhantel-/Kurzhanteltage"): uebersetzt
/// eine Zielkarten-Auswahl (`TrainingGoal` + optionale `EnduranceModality`)
/// in die bestehenden `PlanGeneratorTypeSelection`-Eingaben des
/// UNVERAENDERTEN `PlanGenerator` — keine zweite, parallele Planungslogik
/// (Doc01 §1: "Bestehende fachliche Engine ... erhalten"), nur ein neuer
/// Uebersetzer davor. Der bisherige, direkt trainingsmittel-waehlende
/// Schritt 1 (`PlanBuilderView.typesStep`) bleibt NUR noch fuer den
/// Cardio-Machbarkeits-Handoff erreichbar (dort wird bereits eine konkrete
/// `PlanGeneratorTypeSelection`-Mischung vorgegeben, siehe
/// `PlanBuilderView.init(initialInput:)`).
public enum GoalDrivenPlanSelectionBuilder {

    /// Welches der vier Kraft-`TrainingTypeKind`s fuer ein kraftorientiertes
    /// Ziel verwendet wird — abgeleitet aus dem bereits erfassten
    /// Equipment-Profil (`UserEquipmentProfile.legacyEquipmentPreferences`),
    /// NICHT erneut vom User abgefragt. Prioritaet Langhantel > Kurzhantel >
    /// Kettlebell > Koerpergewicht (strukturierteste/anspruchsvollste zuerst,
    /// Koerpergewicht als universeller, immer gueltiger Fallback).
    public static func preferredStrengthKind(from equipmentPreferences: Set<Equipment>) -> TrainingTypeKind {
        if equipmentPreferences.contains(.barbell) { return .barbell }
        if equipmentPreferences.contains(.dumbbell) { return .dumbbell }
        if equipmentPreferences.contains(.kettlebell) { return .kettlebell }
        return .bodyweight
    }

    /// Baut die vollstaendige Auswahl fuer `PlanGeneratorInput.selections`.
    ///
    /// - `enduranceModality` ist nur fuer `.endurance`/`.hybrid` relevant und
    ///   faellt dort defensiv auf `.running` zurueck, falls noch nicht
    ///   explizit gewaehlt (die aufrufende UI MUSS die Frage vorher stellen,
    ///   siehe `PlanBuilderView`-Goal-Step — dieser Fallback greift nur, falls
    ///   doch einmal aufgerufen, bevor eine Antwort vorliegt).
    /// - `.hybrid` verteilt `totalDaysPerWeek` 50/50 auf Kraft/Ausdauer
    ///   (Kraft bekommt bei ungerader Zahl den zusaetzlichen Tag) — ein
    ///   bewusster, einfacher Produktdefault fuer diese Runde; der spaetere
    ///   visuelle Wocheneditor (P3.2) macht die tatsaechliche Verteilung
    ///   sichtbar und veraenderbar.
    /// - `.both`-Ausdauerform verteilt ebenso 50/50 auf Laufen/Radfahren
    ///   (Laufen bekommt den zusaetzlichen Tag).
    public static func makeSelections(
        goal: TrainingGoal,
        enduranceModality: EnduranceModality?,
        totalDaysPerWeek: Int,
        sessionDurationMinutes: Int,
        experience: DifficultyLevel,
        equipmentPreferences: Set<Equipment>
    ) -> [PlanGeneratorTypeSelection] {
        guard totalDaysPerWeek > 0 else { return [] }

        switch goal {
        case .hypertrophy, .strength, .functional, .weightLoss:
            let kind = preferredStrengthKind(from: equipmentPreferences)
            return [PlanGeneratorTypeSelection(
                kind: kind, daysPerWeek: totalDaysPerWeek,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            )]

        case .endurance:
            return enduranceSelections(
                modality: enduranceModality ?? .running, totalDays: totalDaysPerWeek,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            )

        case .hybrid:
            let strengthDays = Int((Double(totalDaysPerWeek) / 2).rounded(.up))
            let enduranceDays = totalDaysPerWeek - strengthDays
            var result: [PlanGeneratorTypeSelection] = []
            if strengthDays > 0 {
                let kind = preferredStrengthKind(from: equipmentPreferences)
                result.append(PlanGeneratorTypeSelection(
                    kind: kind, daysPerWeek: strengthDays,
                    sessionDurationMinutes: sessionDurationMinutes, experience: experience
                ))
            }
            if enduranceDays > 0 {
                result.append(contentsOf: enduranceSelections(
                    modality: enduranceModality ?? .running, totalDays: enduranceDays,
                    sessionDurationMinutes: sessionDurationMinutes, experience: experience
                ))
            }
            return result
        }
    }

    private static func enduranceSelections(
        modality: EnduranceModality, totalDays: Int,
        sessionDurationMinutes: Int, experience: DifficultyLevel
    ) -> [PlanGeneratorTypeSelection] {
        let kinds = modality.trainingTypeKinds
        guard let firstKind = kinds.first else { return [] }
        guard kinds.count > 1, let secondKind = kinds.dropFirst().first else {
            return [PlanGeneratorTypeSelection(
                kind: firstKind, daysPerWeek: totalDays,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            )]
        }
        let firstDays = Int((Double(totalDays) / 2).rounded(.up))
        let secondDays = totalDays - firstDays
        var result: [PlanGeneratorTypeSelection] = []
        if firstDays > 0 {
            result.append(PlanGeneratorTypeSelection(
                kind: firstKind, daysPerWeek: firstDays,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            ))
        }
        if secondDays > 0 {
            result.append(PlanGeneratorTypeSelection(
                kind: secondKind, daysPerWeek: secondDays,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            ))
        }
        return result
    }
}
