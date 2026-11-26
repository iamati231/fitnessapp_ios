import Foundation

/// Ausfuehrungsschritte fuer Library-Uebungen (de / en / tr).
/// Daten kommen aus exercise_instructions.json (generiert via build_exercise_instructions.py).
public enum ExerciseInstructionsProvider {

    public struct Steps: Sendable {
        public let de: [String]
        public let en: [String]
        public let tr: [String]

        /// Gibt Schritte in der bevorzugten Sprache zurueck; Fallback-Kette:
        /// bevorzugte Sprache -> DE -> EN.
        /// `languageCode`-Override fuer Tests; Default liest die System-Locale.
        public func preferred(languageCode: String? = nil) -> [String] {
            let lang = languageCode ?? Locale.current.language.languageCode?.identifier ?? "de"
            switch lang {
            // Audit-Fund Modul 18: TR fiel bei leerem TR+DE nicht weiter auf EN
            // zurueck, obwohl EN gueltige Schritte haben kann (DE/EN sind
            // dagegen bereits symmetrisch zueinander).
            case "tr": return tr.isEmpty ? (de.isEmpty ? en : de) : tr
            case "en": return en.isEmpty ? de : en
            default:   return de.isEmpty ? en : de
            }
        }
    }

    private static var _cache: [String: Steps]?
    private static let _lock = NSLock()

    public static func steps(for normalizedName: String) -> Steps? {
        _lock.lock()
        defer { _lock.unlock() }
        if _cache == nil { _load() }
        return _cache?[normalizedName]
    }

    // MARK: – private

    private static func _load() {
        guard
            let url = Bundle.module.url(forResource: "exercise_instructions", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [String]]]
        else {
            _cache = [:]
            return
        }
        _cache = raw.compactMapValues(Self.parseSteps)
    }

    // Audit-Fund Modul 18: ein fehlender (nicht nur leerer) Sprach-Key
    // verwarf bisher den gesamten Eintrag inklusive der beiden anderen,
    // vollstaendig vorhandenen Sprachen. Fehlender Key zaehlt jetzt wie ein
    // leeres Array fuer GENAU diese Sprache; nur wenn alle drei leer sind,
    // entfaellt der Eintrag.
    static func parseSteps(from dict: [String: [String]]) -> Steps? {
        let de = dict["de"] ?? []
        let en = dict["en"] ?? []
        let tr = dict["tr"] ?? []
        guard !de.isEmpty || !en.isEmpty || !tr.isEmpty else { return nil }
        return Steps(de: de, en: en, tr: tr)
    }
}
