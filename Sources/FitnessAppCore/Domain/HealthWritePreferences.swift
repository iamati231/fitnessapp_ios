import Foundation

/// Welche Trainings Deltiq nach Apple Health schreiben darf (App-Schalter).
///
/// HealthKit kennt nur EINE Schreibberechtigung fuer Trainings ("Trainings");
/// was davon geschrieben wird, entscheidet die App. Diese Schalter gelten fuer
/// das Schreiben nach jedem beendeten Training UND fuer den Export frueherer
/// Trainings (dort als Vorbelegung der Auswahl).
///
/// Wie `ReminderPreferences`: Der Vorgabewert steht EINMAL hier und wird von
/// den `@AppStorage`-Deklarationen der Oberflaeche referenziert. Ein
/// fehlender Key bedeutet Vorgabe, nicht `false` (`UserDefaults.bool(forKey:)`
/// taeuschte beim Kraft-Schalter ein "aus" vor).
///
/// Bewusst NICHT portabel (nicht in `SettingsPortability.whitelist`): Die
/// Berechtigung ist geraetegebunden, ein importiertes "an" auf einem Geraet
/// ohne Freigabe waere ein inkonsistenter Zustand — wie beim Workout-Import-
/// Schalter.
public struct HealthWritePreferences: Equatable, Sendable {

    /// Krafttraining (inkl. Zeitformate AMRAP/EMOM/Auf Zeit/Zirkel; ein Zeitformat-
    /// Tag nur aus Lauf-/Rad-Intervallen zaehlt zu Cardio). An: Die Freigabe
    /// selbst ist das Opt-in.
    public static let defaultStrengthEnabled = true
    /// Cardio (Laufen, Radfahren, ...). Aus: Wer Laeufe schon von einer
    /// anderen App (z.B. Adidas Running) nach Health bekommt, soll sie nicht
    /// doppelt sehen.
    public static let defaultCardioEnabled = false

    public static let strengthEnabledKey = "pref_healthkit_write_strength"
    public static let cardioEnabledKey = "pref_healthkit_write_cardio"

    public var strengthEnabled: Bool
    public var cardioEnabled: Bool

    public init(
        strengthEnabled: Bool = HealthWritePreferences.defaultStrengthEnabled,
        cardioEnabled: Bool = HealthWritePreferences.defaultCardioEnabled
    ) {
        self.strengthEnabled = strengthEnabled
        self.cardioEnabled = cardioEnabled
    }

    public static func load(from defaults: UserDefaults = .standard) -> HealthWritePreferences {
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            (defaults.object(forKey: key) as? Bool) ?? fallback
        }
        return HealthWritePreferences(
            strengthEnabled: bool(strengthEnabledKey, defaultStrengthEnabled),
            cardioEnabled: bool(cardioEnabledKey, defaultCardioEnabled)
        )
    }

    public func isEnabled(_ category: HealthWorkoutCategory) -> Bool {
        switch category {
        case .strength: return strengthEnabled
        case .cardio: return cardioEnabled
        }
    }

    /// Die aktivierten Kategorien als Menge (Vorbelegung der Export-Auswahl).
    public var enabledCategories: Set<HealthWorkoutCategory> {
        var result: Set<HealthWorkoutCategory> = []
        if strengthEnabled { result.insert(.strength) }
        if cardioEnabled { result.insert(.cardio) }
        return result
    }
}
