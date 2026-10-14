import Foundation

/// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md Abschnitt
/// 13): Ergebnis der Equipment-Pruefung einer KONKRETEN Planvariante (alle
/// Tage, alle Uebungen) gegen ein echtes `UserEquipmentProfile` — die
/// Nachfolge-Pruefung zur reinen Mengen-Teilmengen-Logik aus Phase 1-3
/// (`PlanMatchmaker.requiredEquipment(for:)` / `EquipmentProfile.
/// requiredEquipment`), jetzt pro Uebung statt nur pro Template.
///
/// Dieselbe Dreiwertigkeit wie `RequirementStatus` (EquipmentRequirement.swift),
/// nur auf Plan-Ebene aggregiert: EIN definitiv fehlendes Item schlaegt jede
/// andere, noch unklare Uebung ("ein definitives Nein gewinnt"). Ohne
/// definitiv Fehlendes, aber mit mindestens einer unklaren oder noch nicht
/// annotierten Uebung, ist die GESAMTE Variante `.unknown` — niemals
/// `.available`. Fehlende Annotation ist NIEMALS gleichbedeutend mit "keine
/// Anforderung" (Audit-Vorgabe) und zaehlt deshalb als `.unknown`-Grund, nicht
/// als automatisch erfuellt.
public enum PlanEquipmentStatus: Sendable, Equatable {
    /// Jede Uebung der Variante ist annotiert UND jede Anforderung ist gegen
    /// das Profil bestaetigt erfuellt.
    case available
    /// Mindestens eine annotierte Uebung hat eine definitiv NICHT erfuellte
    /// Anforderung.
    case unavailable(gaps: [PlanEquipmentGap])
    /// Keine Uebung ist definitiv unerfuellt, aber mindestens eine ist entweder
    /// noch nicht annotiert oder ihre Anforderung ist gegen das Profil (noch)
    /// nicht entscheidbar (z.B. Stueckzahl nicht erfasst, Item `.unknown`).
    case unknown(gaps: [PlanEquipmentGap])

    public var isAvailable: Bool { self == .available }

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    public var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }

    /// Alle betroffenen Uebungen, unabhaengig vom Gesamtstatus — leer nur bei
    /// `.available`.
    public var gaps: [PlanEquipmentGap] {
        switch self {
        case .available: return []
        case let .unavailable(gaps), let .unknown(gaps): return gaps
        }
    }
}

/// Eine einzelne betroffene Uebung einer Planvariante samt Grund, warum sie
/// (noch) nicht als sicher erfuellt gilt.
public struct PlanEquipmentGap: Sendable, Equatable {
    public let exerciseName: String
    public let reason: PlanEquipmentGapReason

    public init(exerciseName: String, reason: PlanEquipmentGapReason) {
        self.exerciseName = exerciseName
        self.reason = reason
    }
}

public enum PlanEquipmentGapReason: Sendable, Equatable {
    /// Die Uebung hat (noch) kein `equipmentRequirement` im Katalog erfasst —
    /// Audit-Vorgabe: "fehlende Annotation ist niemals automatisch 'keine
    /// Anforderungen'", deshalb ein eigener, von `.uncertain` unterschiedener
    /// Grund (hier fehlt die KATALOG-Angabe, nicht die NUTZER-Angabe).
    case notAnnotated
    /// Die Uebung ist annotiert, ihre Anforderung ist gegen das Profil aber
    /// definitiv NICHT erfuellt.
    case missing([UnmetReason])
    /// Die Uebung ist annotiert, ein Teil der Anforderung ist gegen das Profil
    /// aber noch unklar (Item `.unknown` oder Stueckzahl nicht erfasst).
    case uncertain([UnmetReason])
}

/// Prueft eine konkrete Tage-Liste (= eine Planvariante) Uebung fuer Uebung
/// gegen ein `UserEquipmentProfile`. Reiner Aggregator ueber
/// `ExerciseRequirement.evaluate(against:)` — die eigentliche Drei-Werte-Logik
/// pro Uebung lebt unveraendert in `EquipmentRequirement.swift`.
public enum PlanEquipmentChecker {
    public static func check(days: [DaySpec], against profile: UserEquipmentProfile) -> PlanEquipmentStatus {
        var missingGaps: [PlanEquipmentGap] = []
        var uncertainGaps: [PlanEquipmentGap] = []

        for day in days {
            for exercise in day.exercises {
                guard let spec = ExerciseLibraryData.byName[exercise.name],
                      let requirement = spec.equipmentRequirement
                else {
                    // Kein Katalog-Treffer ODER (noch) keine Annotation —
                    // beides heisst "wir wissen es nicht", nie "passt schon".
                    uncertainGaps.append(PlanEquipmentGap(exerciseName: exercise.name, reason: .notAnnotated))
                    continue
                }
                switch requirement.evaluate(against: profile) {
                case .satisfied:
                    continue
                case let .unmet(reasons):
                    missingGaps.append(PlanEquipmentGap(exerciseName: exercise.name, reason: .missing(reasons)))
                case let .unknown(reasons):
                    uncertainGaps.append(PlanEquipmentGap(exerciseName: exercise.name, reason: .uncertain(reasons)))
                }
            }
        }

        if !missingGaps.isEmpty { return .unavailable(gaps: missingGaps) }
        if !uncertainGaps.isEmpty { return .unknown(gaps: uncertainGaps) }
        return .available
    }
}

/// Eine konkrete, instanziierbare Planvariante samt ihrem Equipment-
/// Pruefergebnis. `profile == nil` heisst "Basis-/Default-Variante"
/// (`ProgramTemplate.days`), sonst eine explizite `EquipmentVariant` aus
/// `ProgramTemplate.equipmentVariants`.
public struct CheckedPlanVariant: Sendable, Equatable {
    public let profile: EquipmentProfile?
    public let days: [DaySpec]
    public let equipmentStatus: PlanEquipmentStatus

    public init(profile: EquipmentProfile?, days: [DaySpec], equipmentStatus: PlanEquipmentStatus) {
        self.profile = profile
        self.days = days
        self.equipmentStatus = equipmentStatus
    }
}

public extension ProgramTemplate {
    /// Alle instanziierbaren Varianten dieses Templates (Basis + jede
    /// `equipmentVariants`-Variante), jede mit ihrem eigenen
    /// Pro-Uebung-Pruefergebnis gegen das echte `UserEquipmentProfile`.
    func equipmentCheckedVariants(against profile: UserEquipmentProfile) -> [CheckedPlanVariant] {
        var result = [
            CheckedPlanVariant(profile: nil, days: days, equipmentStatus: PlanEquipmentChecker.check(days: days, against: profile))
        ]
        for variant in equipmentVariants ?? [] {
            result.append(CheckedPlanVariant(
                profile: variant.profile,
                days: variant.days,
                equipmentStatus: PlanEquipmentChecker.check(days: variant.days, against: profile)
            ))
        }
        return result
    }

    /// Smart-Onboarding-Epic Phase 4, Punkt 6: EINZIGE Variantenwahl fuer
    /// Vorschau UND Instanziierung — beide rufen diese eine Funktion auf,
    /// damit sie nie wieder auseinanderlaufen koennen (gleiches Prinzip wie
    /// `resolvedDays(forUserEquipment:)` in Phase 1, nur jetzt mit der
    /// praezisen Pro-Uebung-Pruefung statt der groben Mengen-Teilmengen-Pruefung).
    ///
    /// Prioritaet: zuerst eine Variante mit `.available` (unter mehreren
    /// verfuegbaren gewinnt die mit der hoechsten `EquipmentProfile.priority`,
    /// die Basis-Variante zaehlt dabei wie `.barbellGym`). Keine verfuegbare ->
    /// die hoechstpriorisierte `.unknown`-Variante (koennte noch passen, wird
    /// aber nicht als sicher passend ausgegeben). Keine verfuegbare oder
    /// unklare -> die Basis-Variante MIT ihrem `.unavailable`-Status: Punkt 7/8
    /// verbietet eine stillschweigende Ersatz-Variante — die Luecke wird
    /// transparent zurueckgegeben, nicht verschwiegen.
    func bestEquipmentCheckedVariant(against profile: UserEquipmentProfile) -> CheckedPlanVariant {
        let checked = equipmentCheckedVariants(against: profile)

        func priority(_ profile: EquipmentProfile?) -> Int {
            profile?.priority ?? EquipmentProfile.barbellGym.priority
        }
        let ordered = checked.sorted { priority($0.profile) > priority($1.profile) }

        if let available = ordered.first(where: { $0.equipmentStatus.isAvailable }) { return available }
        if let unknown = ordered.first(where: { $0.equipmentStatus.isUnknown }) { return unknown }
        return ordered.first { $0.profile == nil } ?? ordered[0]
    }
}
