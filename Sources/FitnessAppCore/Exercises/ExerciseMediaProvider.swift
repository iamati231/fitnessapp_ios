import Foundation

/// Liefert den Bundle-Dateinamen des Uebungs-GIFs fuer eine Uebung, oder
/// `nil` wenn keiner existiert — dann zeigt die UI einen Platzhalter.
///
/// **Matching-Key:** der deutsche `Exercise`/`ExerciseTemplate`-Name (das
/// ist der De-facto-Primaerschluessel im ganzen Code, siehe
/// `ExerciseTemplate+DisplayName.swift` — nicht `localizationKey`, denn
/// `Exercise` (das Plan-/Workout-Modell) traegt den gar nicht). Wie bei
/// jedem Namens-Lookup gilt: aendert sich ein Uebungsname in
/// `ExerciseLibraryData.swift`, ohne dass das GIF-Mapping neu erzeugt wird,
/// bleibt der alte Snapshot-Name als Key stehen, bis das Mapping neu
/// laeuft — dasselbe bereits akzeptierte Tradeoff wie beim
/// `LibrarySeeder`-Kommentar ("modifizierte Eintraege brauchen manuellen
/// Library-Reset") und bei `TrainingPlan`-Snapshot-Namen.
///
/// `overrides`/`resolved` sind generierte Konstanten
/// (`.scripts/build_exercise_gif_map.py`, siehe `ExerciseGifOverrides` /
/// `ExerciseGifResolution`), als Default-Parameter injiziert — Tests
/// koennen eigene kleine Dictionaries uebergeben, um Reihenfolge/
/// Override-Prioritaet/nil-Fall deterministisch zu pruefen, ohne von den
/// echten ~60 generierten Eintraegen abzuhaengen.
public enum ExerciseMediaProvider {

    /// Normalisiert einen Uebungsnamen zu einem stabilen Lookup-Key:
    /// Kleinschreibung, Umlaute/Akzente entfernt, Satzzeichen durch
    /// Leerzeichen ersetzt, Mehrfach-Leerzeichen zusammengefasst.
    ///
    /// **1:1-Port von `normalize()` in `.scripts/build_exercise_gif_map.py`**
    /// — muss fuer dieselbe Eingabe immer denselben Key liefern wie die
    /// Python-Seite, sonst findet die App die generierten Eintraege nicht.
    /// Klammern werden NUR als Satzzeichen entfernt, ihr Inhalt bleibt
    /// erhalten: "Shrug (KH)" und "Shrug (LH)" sind zwei verschiedene
    /// Uebungen und muessen unterscheidbare Keys behalten.
    public static func normalizedKey(for name: String) -> String {
        var working = name.replacingOccurrences(of: "ß", with: "ss")
        working = working.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        working = working.lowercased()

        var filtered = String.UnicodeScalarView()
        for scalar in working.unicodeScalars {
            if (scalar.value >= 48 && scalar.value <= 57) || (scalar.value >= 97 && scalar.value <= 122) {
                filtered.append(scalar)
            } else {
                filtered.append(" ")
            }
        }

        return String(filtered)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Bundle-Dateiname des GIFs (z.B. `"0025-EIeI8Vf.gif"`) oder `nil`.
    /// Overrides gewinnen immer vor dem automatisch generierten Mapping.
    public static func gifFileName(
        forExerciseName name: String,
        overrides: [String: String] = ExerciseGifOverrides.byNormalizedName,
        resolved: [String: String] = ExerciseGifResolution.byNormalizedName
    ) -> String? {
        let key = normalizedKey(for: name)
        return overrides[key] ?? resolved[key]
    }
}
