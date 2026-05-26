#if canImport(SwiftUI)
import Foundation
import FitnessAppCore

/// DEL-149: Sprachsichere Aufloesung eines persistierten Uebungs-Namens
/// (egal ob Snapshot oder Live-Referenz). Dient zwei Zwecken:
///
///   1. **Runtime-Render-Helper** — `Exercise.resolvedDisplayName(forStoredName:)`
///      ruft `localizationKey(forStoredName:)` und resolved gegen die
///      aktuelle Locale. Damit rendert die PR-Card sprachfest, selbst wenn
///      ein historischer Snapshot noch unter alter Locale geschrieben wurde
///      (vor der Backfill-Migration).
///
///   2. **Backfill-Reverse-Lookup** — `canonicalBaseName(forStoredName:)`
///      gibt den deutschen Library-Base-Namen zurueck, sodass
///      `ExerciseNameBackfill` die DB-Eintraege auf den stabilen Anker
///      umschreiben kann.
///
/// **Wie der Reverse-Lookup funktioniert:** Beim ersten Zugriff wird einmalig
/// eine Map `[lokalisierter Name : localizationKey]` aufgebaut, indem fuer
/// jeden Library-Eintrag mit `localizationKey` die DE/EN/TR-Translation
/// abgefragt wird. Damit erkennen wir z.B. dass "Koşu Bandı" (TR von
/// "exercise.name.treadmill") in Wirklichkeit dem Eintrag mit DE-Base
/// "Laufband" entspricht.
///
/// Locales sind hartcoded auf `["de", "en", "tr"]` — das matched die
/// `Localizable.xcstrings`-Sprachen. Wenn spaeter eine 4. Sprache dazu kommt,
/// hier ergaenzen.
enum ExerciseNameLookup {

    /// Liefert den `localizationKey` (z.B. `"exercise.name.treadmill"`) fuer
    /// einen persistierten Snapshot-Namen, ueber zwei Strategien:
    ///   1. Direkter Match gegen den DE-Base-Namen aus `ExerciseLibraryData`.
    ///   2. Reverse-Lookup ueber alle DE/EN/TR-Translations der Library-Keys.
    /// `nil` zurueck wenn der Name ein freier User-Custom-Wert ist (keine
    /// Library-Entsprechung).
    static func localizationKey(forStoredName name: String) -> String? {
        if let entry = ExerciseLibraryData.all.first(where: { $0.name == name }),
           let key = entry.localizationKey {
            return key
        }
        return reverseLookupCache[name]
    }

    /// Liefert den kanonischen DE-Base-Namen aus der Library, falls `name`
    /// in irgendeiner unterstuetzten Locale einer Library-Uebung entspricht.
    /// `nil` fuer Custom-Uebungen (kein Library-Hit).
    static func canonicalBaseName(forStoredName name: String) -> String? {
        if libraryNamesSet.contains(name) { return name }
        guard let key = reverseLookupCache[name] else { return nil }
        return ExerciseLibraryData.all.first { $0.localizationKey == key }?.name
    }

    // MARK: - Internals

    /// O(1)-Set der kanonischen DE-Base-Namen — Fast-Path fuer den
    /// Idempotenz-Check.
    private static let libraryNamesSet: Set<String> = Set(
        ExerciseLibraryData.all.map(\.name)
    )

    /// Reverse-Lookup-Cache: lokalisierte Name-Variante → localizationKey.
    /// Wird einmal pro App-Lifetime aufgebaut (static let = lazy + thread-safe).
    private static let reverseLookupCache: [String: String] = buildReverseLookupCache()

    /// Baut die Reverse-Map durch Probing aller Library-Keys gegen alle
    /// unterstuetzten Locale-Bundles. Skipped die DE-Base-Translation (die
    /// ist ohnehin der Fast-Path-Match).
    private static func buildReverseLookupCache() -> [String: String] {
        var map: [String: String] = [:]
        let locales = ["de", "en", "tr"]
        for entry in ExerciseLibraryData.all {
            guard let key = entry.localizationKey else { continue }
            for locale in locales {
                guard let translation = lookupInLocale(key: key, locale: locale),
                      translation != entry.name else { continue }
                map[translation] = key
            }
        }
        return map
    }

    /// Direktes Bundle-Lookup gegen ein konkretes `.lproj`-Verzeichnis. SPM
    /// kompiliert `Localizable.xcstrings` zu einem Resource-Bundle mit
    /// per-Locale `.lproj`/Localizable.strings. Wenn der Pfad nicht
    /// existiert (z.B. Build-Variante ohne diese Locale), faellt das auf
    /// `nil` zurueck — der Backfill no-op't dann fuer diesen Namen.
    private static func lookupInLocale(key: String, locale: String) -> String? {
        guard let lprojPath = Bundle.module.path(forResource: locale, ofType: "lproj"),
              let lprojBundle = Bundle(path: lprojPath) else { return nil }
        // Sentinel-Pattern: wenn der Key nicht existiert, gibt
        // `localizedString` den Default zurueck — also unseren Sentinel.
        // Damit unterscheiden wir "Key nicht gefunden" von "leerer String".
        let sentinel = "__DELTIQ_MISSING__"
        let value = lprojBundle.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? nil : value
    }
}
#endif
