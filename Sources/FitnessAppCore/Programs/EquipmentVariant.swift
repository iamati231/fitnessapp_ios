import Foundation

/// DEL-170: Equipment-„Shape" einer Trainings-Variante. Beschreibt, welche
/// Geräte-Familie ein Programm voraussetzt — orthogonal zur Einzel-Übungs-
/// `Equipment`-Klassifikation. Wird vom Plan-Matchmaker auf die User-Liste
/// `UserBodyProfile.equipmentPreferences` gemappt.
///
/// Reihenfolge der Auswahl-Priorität bei mehreren möglichen Variants:
///   `barbellGym` > `dumbbellOnly` > `kettlebellOnly` > `machineGym`.
/// Wenn der User mehrere Profile abdeckt, gewinnt das stärkste (= barbell).
public enum EquipmentProfile: String, Codable, CaseIterable, Sendable {
    /// Vollständiges Studio mit Rack, Langhantel, Kurzhanteln (Standard-Variante).
    case barbellGym
    /// Nur Kurzhanteln (Home-Gym ohne Rack).
    case dumbbellOnly
    /// Nur Kettlebells (Minimalist-Setup).
    case kettlebellOnly
    /// Maschinen-Studio (Cable + Machines, keine Free-Weights).
    case machineGym

    /// Welche Equipment-Typen muss der User besitzen, damit die Variante
    /// sinnvoll umsetzbar ist? Subset-Match gegen
    /// `UserBodyProfile.equipmentPreferences`.
    public var requiredEquipment: Set<Equipment> {
        switch self {
        case .barbellGym:     return [.barbell, .dumbbell]
        case .dumbbellOnly:   return [.dumbbell]
        case .kettlebellOnly: return [.kettlebell]
        case .machineGym:     return [.machine, .cable]
        }
    }

    /// Auswahl-Priorität (höher = bevorzugt). Wenn mehrere Profile auf die
    /// User-Preferences passen, wählt der Matcher das mit dem höchsten Wert.
    public var priority: Int {
        switch self {
        case .barbellGym:     return 40
        case .dumbbellOnly:   return 30
        case .kettlebellOnly: return 20
        case .machineGym:     return 10
        }
    }
}

/// DEL-170: Eine konkrete `ProgramTemplate`-Variante für ein bestimmtes
/// Equipment-Profil. Hält die abweichende `DaySpec`-Liste; Frequenz, Fokus
/// und Concurrent-Struktur (Verteilung von Strength-/Cardio-Tagen) bleiben
/// per Konvention identisch zur Basis-Variante des Templates.
public struct EquipmentVariant: Sendable, Hashable {
    public let profile: EquipmentProfile
    public let days: [DaySpec]

    public init(profile: EquipmentProfile, days: [DaySpec]) {
        self.profile = profile
        self.days = days
    }
}

public extension EquipmentVariant {
    /// Wählt aus einer Liste die Variante mit der höchsten Priorität, deren
    /// `requiredEquipment` vollständig in den User-Preferences enthalten ist.
    /// Liefert `nil`, wenn nichts passt — Caller (Instantiator) fällt dann
    /// auf `template.days` zurück.
    static func bestMatch(
        in variants: [EquipmentVariant],
        userOwns: Set<Equipment>
    ) -> EquipmentVariant? {
        variants
            .filter { $0.profile.requiredEquipment.isSubset(of: userOwns) }
            .max(by: { $0.profile.priority < $1.profile.priority })
    }
}
