import Foundation

/// Ausfuehrungsschritte fuer Library-Uebungen (de / en / tr).
/// Daten kommen aus exercise_instructions.json (generiert via build_exercise_instructions.py).
public enum ExerciseInstructionsProvider {

    public struct Steps: Sendable {
        public let de: [String]
        public let en: [String]
        public let tr: [String]

        /// Gibt Schritte in der bevorzugten Sprache zurueck; Fallback: DE -> EN.
        public func preferred() -> [String] {
            let lang = Locale.current.language.languageCode?.identifier ?? "de"
            switch lang {
            case "tr": return tr.isEmpty ? de : tr
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
        _cache = raw.compactMapValues { dict in
            guard
                let de = dict["de"],
                let en = dict["en"],
                let tr = dict["tr"]
            else { return nil }
            return Steps(de: de, en: en, tr: tr)
        }
    }
}
