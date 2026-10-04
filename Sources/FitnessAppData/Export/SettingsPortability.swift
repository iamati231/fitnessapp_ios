// DEL-209: App-Einstellungen in der CSV-Portabilität.
//
// Die SwiftData-Modelle decken Trainings-/Körperdaten ab — aber Reminder-
// Präferenzen, Einheiten (kg/lbs), Theme, Timer-Feedback usw. leben in
// UserDefaults (@AppStorage) und gingen beim Gerätewechsel bisher verloren.
//
// **Whitelist-Prinzip (Sicherheit):** Es werden NUR explizit gelistete
// Keys exportiert UND importiert. Ein manipuliertes ZIP kann damit keine
// beliebigen UserDefaults schreiben (z.B. interne Flags wie `isResetting`
// oder System-Keys). Unbekannte Keys im Import werden gezählt und
// übersprungen, nie angewendet.
//
// **Bewusst NICHT portabel:** `lastDataExportAt` (gerätespezifisch),
// `deload_until` (ephemerer Zustand, Import normalisiert ohnehin auf
// Original-Gewichte — DEL-208), `isResetting` (Crash-Gate).

import Foundation

public enum SettingsPortability {

    /// Typ eines portablen Settings — bestimmt das Parsing beim Import.
    public enum Kind: Sendable {
        case bool
        case int
        case string
    }

    /// Die EINZIGE Quelle der Wahrheit, welche Settings den Export/Import
    /// passieren dürfen. Neue @AppStorage-Keys, die portabel sein sollen,
    /// HIER eintragen — sonst wandern sie nicht mit.
    public static let whitelist: [(key: String, kind: Kind)] = [
        // Einheiten + Erscheinungsbild
        ("weight_unit",                       .string),  // kg | lbs
        ("pref_appearance",                   .string),  // system | light | dark
        // Timer-Feedback (DEL-018/078)
        ("pref_timer_sound",                  .bool),
        ("pref_timer_haptics",                .bool),
        // Zeitformate im Hintergrund weiterlaufen lassen (stilles Audio): eine
        // Praeferenz wie die uebrigen Timer-Schalter, nicht geraetegebunden.
        ("pref_timer_background_audio",       .bool),
        ("pref_pr_celebrations",              .bool),
        ("pref_preroll_seconds",              .int),
        // Erinnerungen (DEL-018/028)
        ("pref_water_reminder",               .bool),
        ("pref_water_reminder_hours",         .int),
        ("pref_measurement_reminder",         .bool),
        ("pref_measurement_reminder_weekday", .int),
        ("pref_measurement_reminder_hour",    .int),
        // Workout-Verhalten (DEL-092/143/238)
        ("pref_show_warmups",                 .bool),
        ("showRirTooltips",                   .bool),
        // DEL-238: Deload-Automatik an/aus. Gehoert hierher, weil keines der
        // beiden Ausschlusskriterien greift: es ist kein ephemerer Datenzustand
        // wie `deload_until` und nichts gerätespezifisches wie
        // `lastDataExportAt`, sondern eine Praeferenz wie `pref_show_warmups`.
        // Wer die Automatik abgewaehlt hat, will sie auf dem neuen Geraet auch
        // nicht wieder.
        ("pref_deload_enabled",               .bool),
        // Chart-Zeiträume (DEL-152/178)
        ("dashboard.compoundChartRange",      .string),
        ("dashboard.cardioChartRange",        .string),
        ("dashboard.volumeChartRange",        .string),
    ]

    /// Sammelt die vorhandenen Whitelist-Settings als (key, value)-Paare.
    /// Keys ohne gesetzten Wert (User hat den Default nie angefasst)
    /// werden ausgelassen — der Import lässt dann den Ziel-Default stehen.
    public static func collect(from defaults: UserDefaults = .standard) -> [(key: String, value: String)] {
        whitelist.compactMap { entry in
            guard defaults.object(forKey: entry.key) != nil else { return nil }
            switch entry.kind {
            case .bool:
                return (entry.key, defaults.bool(forKey: entry.key) ? "true" : "false")
            case .int:
                return (entry.key, String(defaults.integer(forKey: entry.key)))
            case .string:
                guard let value = defaults.string(forKey: entry.key) else { return nil }
                return (entry.key, value)
            }
        }
    }

    /// Wendet (key, value)-Paare an — NUR Whitelist-Keys, typisiert geparst.
    /// Liefert (applied, skipped): skipped = unbekannte Keys oder
    /// unparsebare Werte. Der Caller reportet das in den Import-Countern.
    @discardableResult
    public static func apply(
        _ rows: [(key: String, value: String)],
        to defaults: UserDefaults = .standard
    ) -> (applied: Int, skipped: Int) {
        let kindsByKey = Dictionary(uniqueKeysWithValues: whitelist.map { ($0.key, $0.kind) })
        var applied = 0
        var skipped = 0
        for row in rows {
            guard let kind = kindsByKey[row.key] else {
                skipped += 1
                continue
            }
            switch kind {
            case .bool:
                switch row.value.lowercased() {
                case "true", "1":  defaults.set(true, forKey: row.key)
                case "false", "0": defaults.set(false, forKey: row.key)
                default: skipped += 1; continue
                }
            case .int:
                guard let value = Int(row.value) else { skipped += 1; continue }
                defaults.set(value, forKey: row.key)
            case .string:
                defaults.set(row.value, forKey: row.key)
            }
            applied += 1
        }
        return (applied, skipped)
    }
}
