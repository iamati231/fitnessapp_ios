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

    /// A12 (docs/DELTIQ_DEVICE_ACCEPTANCE.md, Runde 11): wie viele
    /// unterscheidbare Disziplinen `goal`/`enduranceModality` auswaehlen -
    /// das Minimum an Tagen, um jeder davon mindestens einen Tag zu geben,
    /// ohne eine still verschwinden zu lassen.
    public static func requiredMinimumDays(goal: TrainingGoal, enduranceModality: EnduranceModality?) -> Int {
        switch goal {
        case .hypertrophy, .strength, .functional, .weightLoss:
            return 1
        case .endurance:
            return (enduranceModality ?? .running).trainingTypeKinds.count
        case .hybrid:
            return 1 + (enduranceModality ?? .running).trainingTypeKinds.count
        }
    }

    /// A12: User-waehlbare Reaktion, wenn `totalDaysPerWeek` nicht reicht,
    /// um jede gewaehlte Disziplin mit mindestens einem Tag zu bedienen -
    /// z. B. Hybrid+"Beides" (Laufen+Radfahren) bei nur 2 Tagen/Woche (1
    /// Kraft + 2x1 Ausdauer waeren noetig). `nil` heisst: `makeSelections`
    /// kann alle gewaehlten Disziplinen unterbringen, kein Konflikt.
    public struct DistributionConflict: Equatable, Sendable {
        public enum Resolution: String, CaseIterable, Sendable {
            /// Tage anders verteilen (z. B. eine Disziplin seltener).
            case changeDistribution
            /// Bewusst einen zusaetzlichen Tag/Woche erlauben.
            case allowExtraDay
            /// Laufziel/Sportartauswahl aendern.
            case changeGoal
            /// Nichts aendern, aktuellen Zustand/Plan vorerst beibehalten.
            case keepExistingPlan
        }
        public let requiredDays: Int
        public let availableDays: Int

        public init(requiredDays: Int, availableDays: Int) {
            self.requiredDays = requiredDays
            self.availableDays = availableDays
        }
    }

    /// A12: prueft VOR `makeSelections`, ob `totalDaysPerWeek` fuer die
    /// gewaehlten Disziplinen reicht. Aufrufer, die eine gewaehlte Sportart
    /// nicht still verschwinden lassen duerfen (Spec-Vorgabe A01/A12),
    /// MUESSEN dies pruefen und bei einem Konflikt die vier `Resolution`-
    /// Optionen anbieten, statt `makeSelections`s bestmoeglichen Kompromiss
    /// kommentarlos zu uebernehmen.
    public static func distributionConflict(
        goal: TrainingGoal, enduranceModality: EnduranceModality?, totalDaysPerWeek: Int
    ) -> DistributionConflict? {
        let required = requiredMinimumDays(goal: goal, enduranceModality: enduranceModality)
        guard totalDaysPerWeek < required else { return nil }
        return DistributionConflict(requiredDays: required, availableDays: totalDaysPerWeek)
    }

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

    /// Bugfix (Epic #3.1): `preferredStrengthKind` above picks exactly ONE
    /// kind by priority (Langhantel > Kurzhantel > Kettlebell > Koerpergewicht)
    /// and discards the rest — selecting "Kurzhantel + Kettlebell" silently
    /// produced a Kurzhantel-only plan, and the selection ORDER (which
    /// equipment the user happened to tap first) had no bearing on this, it
    /// was always the fixed priority list. This plural variant returns EVERY
    /// `TrainingTypeKind` the user actually selected (in the same priority
    /// order, for stable day-distribution below), so `makeSelections` can
    /// give each one its own share of the week instead of only the top
    /// priority match. Falls back to `[.bodyweight]` under the same
    /// conditions `preferredStrengthKind` falls back to it (no matching
    /// equipment selected).
    ///
    /// `machine`/`cable`/`band` are not included: the Plan Generator's
    /// `TrainingTypeKind` has no corresponding case for them yet (its four
    /// cases map 1:1 to Equipment — see `TrainingTypeKind.equipmentFilter`).
    /// Selecting only those three equipment types still falls through to
    /// `[.bodyweight]`, same as before this fix — a known, scoped-out
    /// limitation (needs new `TrainingTypeKind` cases, UI, and localization
    /// keys to resolve properly, which is a larger change than this
    /// targeted fix), not a regression introduced here.
    public static func preferredStrengthKinds(from equipmentPreferences: Set<Equipment>) -> [TrainingTypeKind] {
        let priorityOrder: [(Equipment, TrainingTypeKind)] = [
            (.barbell, .barbell), (.dumbbell, .dumbbell), (.kettlebell, .kettlebell), (.bodyweight, .bodyweight)
        ]
        let matched = priorityOrder.filter { equipmentPreferences.contains($0.0) }.map(\.1)
        return matched.isEmpty ? [.bodyweight] : matched
    }

    /// Bugfix (Epic #3.1): splits `totalDays` as evenly as possible across
    /// `kinds`, giving the leftover days (if `totalDays` doesn't divide
    /// evenly) to the first kinds in priority order — same "extra day goes
    /// to the higher-priority discipline" convention already used for
    /// Hybrid's Kraft/Ausdauer split above. A kind that ends up with 0 days
    /// (more kinds selected than days available) is dropped rather than
    /// producing an empty-exercises day — "nicht jede Ausstattung muss in
    /// jedem einzelnen Training verwendet werden" (Epic #3.1 acceptance).
    private static func distributeDaysAcrossKinds(
        totalDays: Int, kinds: [TrainingTypeKind]
    ) -> [(kind: TrainingTypeKind, days: Int)] {
        guard totalDays > 0, !kinds.isEmpty else { return [] }
        let base = totalDays / kinds.count
        let remainder = totalDays % kinds.count
        return kinds.enumerated()
            .map { index, kind in (kind, base + (index < remainder ? 1 : 0)) }
            .filter { $0.days > 0 }
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
    ///   sichtbar und veraenderbar. A12-Fix: reicht die Ausdauer-Haelfte
    ///   nicht fuer jede gewaehlte Ausdauer-Disziplin (z. B. "Beides" bei
    ///   wenigen Tagen), gibt Kraft genau so viele Tage ab wie noetig,
    ///   statt eine Disziplin still auf 0 fallen zu lassen - siehe
    ///   `distributionConflict` fuer den Fall, dass selbst das nicht reicht.
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
            let kinds = preferredStrengthKinds(from: equipmentPreferences)
            return distributeDaysAcrossKinds(totalDays: totalDaysPerWeek, kinds: kinds).map { kind, days in
                PlanGeneratorTypeSelection(
                    kind: kind, daysPerWeek: days,
                    sessionDurationMinutes: sessionDurationMinutes, experience: experience
                )
            }

        case .endurance:
            return enduranceSelections(
                modality: enduranceModality ?? .running, totalDays: totalDaysPerWeek,
                sessionDurationMinutes: sessionDurationMinutes, experience: experience
            )

        case .hybrid:
            let modality = enduranceModality ?? .running
            let enduranceKinds = modality.trainingTypeKinds
            var strengthDays = Int((Double(totalDaysPerWeek) / 2).rounded(.up))
            var enduranceDays = totalDaysPerWeek - strengthDays
            // A12-Fix (docs/DELTIQ_DEVICE_ACCEPTANCE.md, Runde 11): die
            // Ausdauer-Haelfte reichte bei "Beides" (2 Disziplinen) nicht
            // immer fuer beide gewaehlten Sportarten - z. B. bei 3
            // Default-Tagen bekam Kraft 2, Ausdauer nur 1, und
            // `enduranceSelections` liess Radfahren dann MIT NULL Tagen
            // komplett und ohne Meldung aus der Auswahl fallen. Fix: Kraft
            // gibt genau so viele Tage ab, wie noetig, damit jede gewaehlte
            // Ausdauer-Disziplin mindestens einen Tag bekommt - aber
            // niemals auf 0 (siehe `requiredMinimumDays`-Guard unten, der
            // diesen Fall als echten `distributionConflict` an den
            // Aufrufer zurueckgibt statt hier stillschweigend auf 0 Kraft
            // zu gehen). Bei genau EINER Ausdauer-Disziplin (Normalfall)
            // greift diese Korrektur nie (enduranceDays reicht dafuer
            // immer) - keine Verhaltensaenderung fuer A03/A06/A08.
            if enduranceDays < enduranceKinds.count {
                let shortfall = enduranceKinds.count - enduranceDays
                guard strengthDays - shortfall >= 1 else {
                    // Echter Konflikt: selbst 1 Tag Kraft + je 1 Tag pro
                    // Ausdauer-Disziplin passt nicht in `totalDaysPerWeek`
                    // (siehe `distributionConflict` - der Aufrufer haette
                    // das vorher pruefen und die vier Resolution-Optionen
                    // anbieten sollen). Bestmoeglicher Kompromiss als
                    // Fallback, damit diese Funktion nie leer/inkonsistent
                    // zurueckgibt.
                    var fallback: [PlanGeneratorTypeSelection] = []
                    if strengthDays > 0 {
                        fallback.append(PlanGeneratorTypeSelection(
                            kind: preferredStrengthKind(from: equipmentPreferences), daysPerWeek: strengthDays,
                            sessionDurationMinutes: sessionDurationMinutes, experience: experience
                        ))
                    }
                    if enduranceDays > 0 {
                        fallback.append(contentsOf: enduranceSelections(
                            modality: modality, totalDays: enduranceDays,
                            sessionDurationMinutes: sessionDurationMinutes, experience: experience
                        ))
                    }
                    return fallback
                }
                strengthDays -= shortfall
                enduranceDays += shortfall
            }

            var result: [PlanGeneratorTypeSelection] = []
            if strengthDays > 0 {
                result.append(PlanGeneratorTypeSelection(
                    kind: preferredStrengthKind(from: equipmentPreferences), daysPerWeek: strengthDays,
                    sessionDurationMinutes: sessionDurationMinutes, experience: experience
                ))
            }
            if enduranceDays > 0 {
                result.append(contentsOf: enduranceSelections(
                    modality: modality, totalDays: enduranceDays,
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
