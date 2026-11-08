import Foundation

/// Wie die Trainingstage auf die Woche verteilt werden. Bildet 1:1 auf die
/// bereits bestehenden `PlanGeneratorInput`-Felder `usesFixedWeekdays`/
/// `fixedWeekdays` ab (Audit §1: "Flexible Reihenfolge vs. feste Wochentage
/// ist bereits vollstaendig unterstuetzt") — kein zweites Scheduling-Konzept.
public enum SchedulingMode: Sendable, Hashable {
    /// Apple-Calendar-Schema (1 = Sonntag ... 7 = Samstag) — identische
    /// Konvention wie `PlanGeneratorInput.fixedWeekdays` und
    /// `ProgramInstantiator.instantiate(selectedWeekdays:)`.
    case fixedWeekdays([Int])
    case flexibleOrder
}

/// Die drei Aufrufer, die denselben `PlanningContext`/`PlanDraft`-Vertrag
/// teilen sollen (Vorgabe: "Uebergabe zwischen Onboarding/Builder/
/// Plananpassung"). Traegt bewusst KEINE konkrete Plan-Referenz: `TrainingPlan`
/// ist ein SwiftData-`@Model` (DeltiqData/DeltiqUI), und Core bleibt
/// SwiftData-frei (siehe Datei-Kommentar in `DaySpec.swift`). Welcher
/// bestehende Plan ggf. bearbeitet wird, haelt ausschliesslich der Aufrufer —
/// Core kennt nur die Betriebsart.
public enum PlanningMode: Sendable, Equatable {
    case onboarding
    case builderCreate
    case builderEdit
    case profileAdaptation
}

/// Ein Validierungsbefund zu einem `PlanningContext`. Jeder Fall entspricht
/// genau einer der im Audit (P2.0-Abnahme) benannten Invarianten.
public enum PlanningContextIssue: Sendable, Equatable {
    /// `daysPerWeek` zaehlt UNTERSCHIEDLICHE Kalendertage — eine Woche hat
    /// nur sieben, also ist 1...7 der einzige gueltige Bereich (siehe
    /// `PlanningContext.daysPerWeek`-Dokumentation).
    case daysPerWeekOutOfRange(Int)
    case sessionDurationMinutesNotPositive(Int)
    /// "`scheduling == .fixedWeekdays(x)` erfordert `x.count == daysPerWeek`".
    case fixedWeekdaysCountMismatch(expected: Int, actual: Int)
    case fixedWeekdaysOutOfRange([Int])
    case fixedWeekdaysNotUnique([Int])
}

/// Planung-&-Trainingsbegleitung-Epic, P2.0: der gemeinsame Planungskontext,
/// den Onboarding, der neue zielorientierte Builder UND die
/// profiländerungsgetriebene Plananpassung (P4) teilen sollen — ersetzt
/// NICHT `PlanGeneratorInput` (das bleibt die Eingabe des bestehenden,
/// trainingsart-basierten "Plan bauen"-Wizards A), sondern beschreibt die
/// Antworten des NEUEN, zielorientierten Einstiegs (Audit §1: "kein
/// zielorientierter Einstieg" ist genau die Luecke, die dieser Typ schliesst).
///
/// Reine Core-Werttypen, kein `ModelContext`-Bezug (Testplattform: Linux).
public struct PlanningContext: Sendable, Equatable {
    public var goal: TrainingGoal
    /// Anzahl UNTERSCHIEDLICHER Kalendertage mit Training in der Woche —
    /// 1...7 (siehe `issues`), da eine Woche nur sieben Tage hat und dieser
    /// Vertrag kein Konzept von "mehrere Einheiten an einem Tag" kennt:
    /// jeder Trainingstag bildet genau auf einen `DraftDay`/Wochentag ab
    /// (siehe `SchedulingMode.fixedWeekdays`). Ein Aufrufer, der mehrfache
    /// Einheiten pro Tag abbilden will, braucht dafuer einen eigenen,
    /// spaeteren Vertrag — dieser Typ unterstuetzt es weder stillschweigend
    /// noch durch Abschneiden, sondern meldet einen Wert ausserhalb 1...7
    /// explizit ueber `issues`.
    public var daysPerWeek: Int
    /// Muss positiv sein (siehe `issues`) — eine Einheit mit 0 oder
    /// negativer Dauer ist fachlich nicht sinnvoll.
    public var sessionDurationMinutes: Int
    public var scheduling: SchedulingMode
    public var environment: EnvironmentType
    /// Das individuell erfasste Profil — NICHT bereits das effektiv
    /// anzuwendende (siehe `effectiveEquipment`).
    public var equipmentProfile: UserEquipmentProfile
    /// Siehe `UserEquipmentProfile.confirmRemainingAsUnavailable` — `true`
    /// erst nach abgeschlossener Erfassung. Identischer Zweck wie das
    /// bereits persistierte `confirmEquipmentProfileComplete`-Feld.
    public var equipmentProfileConfirmedComplete: Bool

    public init(
        goal: TrainingGoal,
        daysPerWeek: Int,
        sessionDurationMinutes: Int,
        scheduling: SchedulingMode,
        environment: EnvironmentType,
        equipmentProfile: UserEquipmentProfile,
        equipmentProfileConfirmedComplete: Bool
    ) {
        self.goal = goal
        self.daysPerWeek = daysPerWeek
        self.sessionDurationMinutes = sessionDurationMinutes
        self.scheduling = scheduling
        self.environment = environment
        self.equipmentProfile = equipmentProfile
        self.equipmentProfileConfirmedComplete = equipmentProfileConfirmedComplete
    }

    /// Alle verletzten Invarianten — leer heisst "gueltig". Eine Liste statt
    /// eines einzelnen Bool, damit eine aufrufende UI (spaeter, P3) mehrere
    /// gleichzeitige Probleme konkret benennen kann statt nur "ungueltig".
    public var issues: [PlanningContextIssue] {
        var result: [PlanningContextIssue] = []

        if !(1...7).contains(daysPerWeek) {
            result.append(.daysPerWeekOutOfRange(daysPerWeek))
        }
        if sessionDurationMinutes <= 0 {
            result.append(.sessionDurationMinutesNotPositive(sessionDurationMinutes))
        }
        switch scheduling {
        case .fixedWeekdays(let weekdays):
            if weekdays.count != daysPerWeek {
                result.append(.fixedWeekdaysCountMismatch(expected: daysPerWeek, actual: weekdays.count))
            }
            let outOfRange = weekdays.filter { !(1...7).contains($0) }
            if !outOfRange.isEmpty {
                result.append(.fixedWeekdaysOutOfRange(outOfRange))
            }
            if Set(weekdays).count != weekdays.count {
                result.append(.fixedWeekdaysNotUnique(weekdays))
            }
        case .flexibleOrder:
            break
        }
        return result
    }

    public var isValid: Bool { issues.isEmpty }

    /// Das tatsaechlich fuer Matching/Vorschau/Instanziierung zu verwendende
    /// Equipment-Profil. Delegiert vollstaendig an den BESTEHENDEN
    /// `EquipmentPlanningResolver` (Smart-Onboarding-Epic Phase 6) statt eine
    /// zweite Equipment-Aufloesung einzufuehren — ein Gym-Nutzer ohne
    /// individuelle Einrichtung bekommt damit automatisch die dokumentierte
    /// Standard-Gym-Annahme statt einer stillen Luecke (Audit-§P2.0-Abnahme).
    public var effectiveEquipment: EquipmentPlanningContext {
        EquipmentPlanningResolver.resolve(
            environment: environment,
            individualProfile: equipmentProfile,
            confirmedComplete: equipmentProfileConfirmedComplete
        )
    }
}
