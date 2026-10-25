import Foundation

/// Handoff "Lauf-Coaching - Machbarkeits-Check": prueft, ob ein `CardioGoal`
/// bis zum `cardioRaceDate` bei hoechstens 10 % woechentlicher Steigerung ab
/// dem gepflegten `weeklyBaseVolumeKm` noch erreichbar ist, und schlaegt bei
/// Bedarf das naechstkleinere erreichbare Ziel vor. Analog
/// `CardioBaselineCalculator`/`PaceZoneCalculator`: reine Funktionen, keine
/// SwiftData-Abhaengigkeit - `ProfileEditorView`/`DashboardView`/
/// `PlansListView` liefern nur die Profil-Werte und rendern das Ergebnis,
/// alle drei rufen denselben Rechenweg.
public enum CardioFeasibilityCalculator {

    /// Ergebnis eines Machbarkeits-Checks. `suggestedGoal` ist nur bei
    /// `feasible == false` gesetzt (und dann nur, wenn ueberhaupt ein
    /// kleineres Ziel in der Rampen-Zeit noch aufgeht).
    public struct Result: Equatable {
        public let feasible: Bool
        public let weeksNeeded: Int
        public let weeksAvailable: Int
        public let suggestedGoal: CardioGoal?

        public init(feasible: Bool, weeksNeeded: Int, weeksAvailable: Int, suggestedGoal: CardioGoal?) {
            self.feasible = feasible
            self.weeksNeeded = weeksNeeded
            self.weeksAvailable = weeksAvailable
            self.suggestedGoal = suggestedGoal
        }
    }

    /// Ticket-Vorgabe: hoechstens 10 % Wochenvolumen-Steigerung pro Woche.
    public static let maxWeeklyRampPercent: Double = 0.10
    /// Ticket-Vorgabe: zwei Wochen Taper nach Erreichen des Zielvolumens,
    /// unabhaengig davon wie lang die Rampe selbst war.
    public static let taperWeeks: Int = 2

    /// Von anspruchsvoll zu genuegsam - Reihenfolge, in der `suggestedGoal`
    /// ein kleineres Ziel probiert. "Allgemeine Fitness" fehlt bewusst: sie
    /// hat kein Zielvolumen (siehe `targetWeeklyVolumeKm`) und ist daher auch
    /// als Vorschlag kein sinnvoller Fall - wessen 5-km-Ziel schon nicht
    /// aufgeht, dem hilft kein "dann halt gar kein Ziel" als Vorschlag.
    private static let rampLadder: [CardioGoal] = [.marathon, .halfMarathon, .tenK, .fiveK]

    /// Grobe Richtwerte aus dem Ticket. "Allgemeine Fitness" hat keins -
    /// `nil` heisst hier "der Check entfaellt", nicht "Ziel ist 0 km/Woche".
    public static func targetWeeklyVolumeKm(for goal: CardioGoal) -> Double? {
        switch goal {
        case .generalFitness:  return nil
        case .fiveK:            return 20
        case .tenK:              return 30
        case .halfMarathon:  return 45
        case .marathon:        return 65
        }
    }

    /// Wochen bis zum Zielvolumen (`ceil(log(ziel/start) / log(1.10))`) plus
    /// Taper. `nil`, wenn fuer `goal` kein Zielvolumen existiert oder
    /// `startWeeklyVolumeKm` keine brauchbare Basis ist (siehe
    /// `CardioBaselineCalculator`: `nil` heisst "zu wenig Daten", nicht
    /// "Wert ist Null"). Liegt der Start bereits auf oder ueber dem
    /// Zielvolumen, entfaellt die Rampe - der Taper bleibt trotzdem stehen,
    /// er ist kein Steigerungs-Puffer, sondern Vorbereitung auf den Start.
    public static func weeksNeeded(for goal: CardioGoal, startWeeklyVolumeKm: Double) -> Int? {
        guard let target = targetWeeklyVolumeKm(for: goal), startWeeklyVolumeKm > 0 else { return nil }
        guard startWeeklyVolumeKm < target else { return taperWeeks }
        let rampWeeksExact = ceil(log(target / startWeeklyVolumeKm) / log(1 + maxWeeklyRampPercent))
        // Bugfix (Review): `Int(value)` traps for non-finite values. Ein
        // winziges `startWeeklyVolumeKm` (z.B. aus einem beschaedigten CSV-
        // Import, siehe DataImportService.importProfile) laesst
        // `target / startWeeklyVolumeKm` auf +Infinity ueberlaufen -
        // dasselbe Muster wie der bereits behobene Bug in
        // `Float.formattedRIR`.
        guard rampWeeksExact.isFinite, abs(rampWeeksExact) < Double(Int.max) else { return nil }
        return Int(rampWeeksExact) + taperWeeks
    }

    /// `nil`, wenn kein Check moeglich ist: kein Renn-Datum, keine
    /// Start-Basis oder `goal == .generalFitness`. Sonst immer ein Ergebnis -
    /// auch wenn `feasible == true` (der Aufrufer zeigt dann den kuerzeren,
    /// positiven Text statt Verdikt + Vorschlag).
    public static func evaluate(
        goal: CardioGoal,
        raceDate: Date?,
        weeklyBaseVolumeKm: Double?,
        today: Date = Date()
    ) -> Result? {
        guard let raceDate, raceDate > today,
              let weeklyBaseVolumeKm,
              let needed = weeksNeeded(for: goal, startWeeklyVolumeKm: weeklyBaseVolumeKm)
        else { return nil }
        let available = weeksAvailable(from: today, to: raceDate)
        let feasible = available >= needed
        let suggestion = feasible
            ? nil
            : suggestedGoal(below: goal, weeksAvailable: available, startWeeklyVolumeKm: weeklyBaseVolumeKm)
        return Result(feasible: feasible, weeksNeeded: needed, weeksAvailable: available, suggestedGoal: suggestion)
    }

    private static func weeksAvailable(from today: Date, to raceDate: Date) -> Int {
        max(0, Calendar.current.dateComponents([.weekOfYear], from: today, to: raceDate).weekOfYear ?? 0)
    }

    /// Naechstkleineres Ziel unterhalb `goal` in `rampLadder`, fuer das die
    /// verfuegbare Zeit reicht. `nil`, wenn `goal` schon das kleinste
    /// gepruefte Ziel ist (5 km) oder keines der kleineren Ziele aufgeht.
    private static func suggestedGoal(below goal: CardioGoal, weeksAvailable: Int, startWeeklyVolumeKm: Double) -> CardioGoal? {
        guard let currentIndex = rampLadder.firstIndex(of: goal) else { return nil }
        for candidate in rampLadder[(currentIndex + 1)...] {
            if let needed = weeksNeeded(for: candidate, startWeeklyVolumeKm: startWeeklyVolumeKm), weeksAvailable >= needed {
                return candidate
            }
        }
        return nil
    }

    /// Fingerabdruck aus den drei Werten, die einen Check auslösen - Muster
    /// wie `TrainingDay.currentContentFingerprint`. Aendert sich einer davon,
    /// weicht der Fingerprint ab und die zuvor unterdrueckte Karte
    /// (verworfen ODER bereits angenommen, siehe
    /// `UserBodyProfile.cardioFeasibilityDismissedFingerprint`) erscheint
    /// wieder.
    public static func suppressionFingerprint(goal: CardioGoal, raceDate: Date, weeklyBaseVolumeKm: Double) -> String {
        "\(goal.rawValue)#\(Int(raceDate.timeIntervalSince1970))#\(weeklyBaseVolumeKm)"
    }

    /// Kraft-/Lauf-Mix je Ziel (Ticket-Tabelle). Lauf-Zonen kommen
    /// unveraendert aus der bestehenden Lauf-Typologie in `PlanGenerator`
    /// (ueber `TrainingTypeKind.running`, zyklisch easy/interval/tempo).
    /// Kraft-Kind ist `.bodyweight`: braucht keine Geraete-Annahme - hier
    /// ist unbekannt, was der Nutzer besitzt, und `equipmentPreferences`
    /// bleibt entsprechend leer (wird von `PlanGenerator.strengthCandidates`
    /// ohnehin nicht als Filter gelesen, nur `TrainingTypeKind.equipmentFilter`
    /// entscheidet die Auswahl).
    /// `cardioRunProfile` (Task 9 Nachbesserung, Review-Fund): ohne diesen
    /// Parameter traegt die erzeugte `.running`-Selection nie eine Baseline,
    /// und `PlanGenerator.cardioCandidates` setzt deshalb nie ein
    /// `ExerciseSpec.targetPaceMinutesPerKm` fuer diesen Aufrufer (`nil`
    /// heisst dort "keine Baseline bekannt", siehe `PlanGeneratorInput`-Doku)
    /// - der gleiche Mechanismus, den `GoalDrivenPlanSelectionBuilder` fuer
    /// den regulaeren Plan-Bauen-Assistenten schon nutzt. Default `nil`
    /// erhaelt bestehende Aufrufer/Tests ohne Baseline unveraendert. Nur auf
    /// der `.running`-Selection gesetzt, analog
    /// `GoalDrivenPlanSelectionBuilder.enduranceSelections`s
    /// `.bodyweight`/Kraft-Selection bleibt ohne Profil.
    public static func planGeneratorInput(for goal: CardioGoal, cardioRunProfile: CardioRunProfile? = nil) -> PlanGeneratorInput {
        let runDays: Int
        let strengthDays: Int
        switch goal {
        case .generalFitness, .fiveK:
            runDays = 2
            strengthDays = 2
        case .tenK, .halfMarathon:
            runDays = 3
            strengthDays = 2
        case .marathon:
            runDays = 5
            strengthDays = 0
        }
        var selections: [PlanGeneratorTypeSelection] = [
            PlanGeneratorTypeSelection(
                kind: .running, daysPerWeek: runDays, sessionDurationMinutes: 45, experience: .intermediate,
                cardioRunProfile: cardioRunProfile
            )
        ]
        if strengthDays > 0 {
            selections.append(
                PlanGeneratorTypeSelection(kind: .bodyweight, daysPerWeek: strengthDays, sessionDurationMinutes: 45, experience: .intermediate)
            )
        }
        return PlanGeneratorInput(selections: selections, equipmentPreferences: [], usesFixedWeekdays: false)
    }
}
