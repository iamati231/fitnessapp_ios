import Foundation

/// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md):
/// "Ort ist nicht Ausstattung" (Phase 3) bleibt gültig — ein gewählter
/// Trainingsort darf nie automatisch eine Equipment-BESTÄTIGUNG erzeugen.
/// Für Gym-User ohne individuelle Einrichtung erlaubt die Vorgabe trotzdem
/// eine reine PLANUNGSANNAHME (ein übliches Studio), die für Matching/
/// Vorschau wie ein Profil wirkt, aber niemals als bestätigt dargestellt
/// oder gespeichert wird. `source` trägt genau diese Unterscheidung NEBEN
/// dem unveränderten, weiterhin dreiwertigen `UserEquipmentProfile` — bewusst
/// kein viertes `EquipmentAvailability`-Fall (siehe Audit-Doc §1: ein
/// pervasiv genutzter, teils persistierter Typ anzufassen wäre für eine an
/// einer einzigen Stelle entstehende Annahme unverhältnismäßig).
public enum EquipmentPlanningSource: String, Sendable, Equatable {
    /// Erfassung abgeschlossen (`UserEquipmentProfile.confirmRemainingAsUnavailable`
    /// ist gelaufen) — jedes Item ist explizit entschieden.
    case confirmed
    /// Gym gewählt, (noch) nicht individuell eingerichtet — `effectiveProfile`
    /// ist die Standard-Gym-Annahme, überlagert von eventuellen individuellen
    /// Angaben. NIE als "bestätigt" darstellen.
    case gymAssumption
    /// Home-Gym/Kein Equipment, Erfassung läuft noch, oder "später
    /// entscheiden" — `effectiveProfile` ist unverändert das real (teilweise)
    /// erfasste Profil, identisch zum Verhalten vor Phase 6.
    case unconfirmed
}

/// Der fuer Matching/Vorschau/Instanziierung tatsaechlich zu verwendende
/// Equipment-Kontext. Ersetzt NICHT `UserEquipmentProfile` als Datenquelle
/// (keine zweite Equipment-Datenquelle) — `effectiveProfile` wird bei jedem
/// Aufruf aus den bereits persistierten Feldern (`environment`,
/// `equipmentProfile`, `equipmentProfileConfirmedComplete`) frisch berechnet.
public struct EquipmentPlanningContext: Sendable, Equatable {
    public let effectiveProfile: UserEquipmentProfile
    public let source: EquipmentPlanningSource

    public init(effectiveProfile: UserEquipmentProfile, source: EquipmentPlanningSource) {
        self.effectiveProfile = effectiveProfile
        self.source = source
    }

    /// `true` ausschließlich für die Gym-Planungsannahme — steuert, ob die UI
    /// "Für ein übliches Fitnessstudio geplant" statt "Equipment passend" /
    /// "Equipment angepasst" / "Equipment fehlt" zeigen muss (Vorgabe: nie
    /// "Equipment bestätigt" / "Alle Geräte vorhanden" für eine Annahme).
    public var isAssumption: Bool { source == .gymAssumption }
}

public enum EquipmentPlanningResolver {
    /// `individualProfile`/`confirmedComplete` sind exakt die Werte, die
    /// Onboarding und `UserBodyProfile` ohnehin schon führen — keine neuen
    /// Eingaben, nur eine neue Zusammenführung.
    public static func resolve(
        environment: EnvironmentType,
        individualProfile: UserEquipmentProfile,
        confirmedComplete: Bool
    ) -> EquipmentPlanningContext {
        // Eine abgeschlossene Erfassung gewinnt immer — auch im Gym, sobald
        // der User "Ausstattung anpassen" durchlaufen und bestätigt hat, gibt
        // es keine Lücke mehr, die eine Annahme füllen müsste (Vorgabe:
        // "individuell bestätigte Angaben haben Vorrang").
        if confirmedComplete {
            return EquipmentPlanningContext(effectiveProfile: individualProfile, source: .confirmed)
        }
        if environment == .gym {
            // Gym = alle Ausstattungen automatisch bestaetigt; kein manueller Schritt noetig.
            return EquipmentPlanningContext(effectiveProfile: .gymFull, source: .confirmed)
        }
        return EquipmentPlanningContext(effectiveProfile: individualProfile, source: .unconfirmed)
    }

    /// Startet bei der Standard-Gym-Annahme und überschreibt JEDES Item, zu
    /// dem der User selbst schon eine Angabe gemacht hat — ob `.available`
    /// ODER `.unavailable`, nie umgekehrt. "Explizit fehlende Geräte dürfen
    /// niemals durch Gym-Defaults überschrieben werden" (Vorgabe, wörtlich).
    static func mergeIndividualOverGymDefault(_ individual: UserEquipmentProfile) -> UserEquipmentProfile {
        var merged = UserEquipmentProfile.gymDefault
        for (item, availability) in individual.availability {
            merged.availability[item] = availability
        }
        for (item, count) in individual.counts {
            merged.counts[item] = count
        }
        return merged
    }
}

public extension UserEquipmentProfile {
    /// Alle 10 `EquipmentItem`-Faelle auf `.available` — wird als bestaetigt
    /// gespeichertes Profil verwendet, wenn der Nutzer "Gym" als Trainingsort
    /// waehlt. Kein `.unknown`, kein `confirmRemainingAsUnavailable` noetig.
    public static var gymFull: UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        for item in EquipmentItem.allCases {
            profile.availability[item] = .available
        }
        return profile
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §4): zentral definierte, explizit dokumentierte Annahme für ein
    /// ÜBLICHES kommerzielles Fitnessstudio — keine Spezialgeräte, keine
    /// Ringe/Schlingentrainer, keine ungewöhnlichen Aufbauten. Kettlebell und
    /// Widerstandsband bleiben bewusst `.unknown`, nicht `.available`: beide
    /// sind nicht universell genug für eine unbelegte Annahme (siehe Audit-
    /// Doc-Tabelle für die vollständige Begründung je Item).
    static var gymDefault: UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        let assumedAvailable: [EquipmentItem] = [
            .dumbbell, .barbell, .adjustableBench, .rack, .cableStation, .machineStation, .pullUpBar
        ]
        for item in assumedAvailable {
            profile.availability[item] = .available
        }
        // .flatBench, .kettlebell, .resistanceBand bleiben .unknown (Default).
        return profile
    }
}
