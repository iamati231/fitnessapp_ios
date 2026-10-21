import Foundation

/// Die gespeicherten Erinnerungs-Praeferenzen (Wasser + Messung), aufgeloest
/// gegen dieselben Vorgabewerte wie die `@AppStorage`-Deklarationen in der
/// SettingsView.
///
/// Warum das ein eigener Typ ist: Die Schalter stehen in `UserDefaults`, die
/// eigentlichen Benachrichtigungen aber im System — und die wurden nie
/// geplant (Ende des Onboardings, Backup-Import) oder gehen verloren
/// (Geraete-Wiederherstellung). Wer die Planung aus den gespeicherten Werten
/// ableitet, kann sie an jeder dieser Stellen erneut anstossen.
///
/// `UserDefaults.bool(forKey:)` allein taugt dafuer nicht: Es liefert `false`
/// fuer einen fehlenden Key, die Oberflaeche zeigt dort aber den Schalter AN
/// (Vorgabe `true`). Hier gilt deshalb dieselbe Logik wie bei `@AppStorage`:
/// fehlender Key = Vorgabewert, vorhandener Key = gespeicherter Wert.
public struct ReminderPreferences: Equatable, Sendable {

    public var waterEnabled: Bool
    /// Abstand der Wasser-Erinnerungen in Stunden (zwischen 08:00 und 20:00).
    public var waterIntervalHours: Int
    public var measurementEnabled: Bool
    /// 1 = Sonntag ... 7 = Samstag (Apple-Konvention, wie `Calendar`).
    public var measurementWeekday: Int
    /// 0...23.
    public var measurementHour: Int

    public init(
        waterEnabled: Bool = true,
        waterIntervalHours: Int = 3,
        measurementEnabled: Bool = true,
        measurementWeekday: Int = 1,
        measurementHour: Int = 8
    ) {
        self.waterEnabled = waterEnabled
        self.waterIntervalHours = waterIntervalHours
        self.measurementEnabled = measurementEnabled
        self.measurementWeekday = measurementWeekday
        self.measurementHour = measurementHour
    }

    // MARK: UserDefaults-Keys (identisch zu den @AppStorage-Keys der SettingsView)

    public static let waterEnabledKey = "pref_water_reminder"
    public static let waterIntervalHoursKey = "pref_water_reminder_hours"
    public static let measurementEnabledKey = "pref_measurement_reminder"
    public static let measurementWeekdayKey = "pref_measurement_reminder_weekday"
    public static let measurementHourKey = "pref_measurement_reminder_hour"

    /// Liest die Praeferenzen. Unplausible Werte (z.B. aus einer fremden oder
    /// beschaedigten settings.csv) fallen auf die Vorgabe zurueck, statt
    /// ungueltige Trigger an das System zu geben.
    public static func load(from defaults: UserDefaults = .standard) -> ReminderPreferences {
        let fallback = ReminderPreferences()

        func bool(_ key: String, _ defaultValue: Bool) -> Bool {
            (defaults.object(forKey: key) as? Bool) ?? defaultValue
        }
        func int(_ key: String, _ defaultValue: Int) -> Int {
            (defaults.object(forKey: key) as? Int) ?? defaultValue
        }

        let hours = int(waterIntervalHoursKey, fallback.waterIntervalHours)
        let weekday = int(measurementWeekdayKey, fallback.measurementWeekday)
        let hour = int(measurementHourKey, fallback.measurementHour)

        return ReminderPreferences(
            waterEnabled: bool(waterEnabledKey, fallback.waterEnabled),
            waterIntervalHours: hours > 0 ? hours : fallback.waterIntervalHours,
            measurementEnabled: bool(measurementEnabledKey, fallback.measurementEnabled),
            measurementWeekday: (1...7).contains(weekday) ? weekday : fallback.measurementWeekday,
            measurementHour: (0...23).contains(hour) ? hour : fallback.measurementHour
        )
    }
}
