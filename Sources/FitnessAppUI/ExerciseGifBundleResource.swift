import Foundation

/// Loest einen von `ExerciseMediaProvider` gelieferten GIF-Dateinamen zu
/// einer Bundle-URL auf. Eigene, von SwiftUI unabhaengige Datei (nur
/// Foundation), damit `FitnessAppUITests` sie direkt testen kann, ohne
/// SwiftUI zu importieren.
///
/// **Bug-Historie:** `ExerciseGifs/` liegt bewusst NICHT unter
/// `Sources/FitnessAppUI/Resources/` — `.process("Resources")` in
/// `Package.swift` flacht verschachtelte Unterordner im Bundle ab (alle
/// Dateien landen direkt im Bundle-Root, ohne `ExerciseGifs/`-Praefix).
/// Ein `subdirectory:`-Lookup lief dadurch immer ins Leere, der Platzhalter
/// blieb sichtbar. `ExerciseGifs` ist jetzt ein eigener Top-Level-Resource-
/// Pfad (`.copy("ExerciseGifs")`), der seine Ordnerstruktur im Bundle
/// behaelt. Der Fallback ohne `subdirectory` bleibt als zweite Verteidigungslinie
/// bestehen, falls ein anderer Build-Pfad (XcodeGen/Codemagic) die Resources
/// doch einmal abflacht.
public enum ExerciseGifBundleResource {
    public static func url(forGifFileName fileName: String) -> URL? {
        if let url = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "ExerciseGifs") {
            return url
        }
        if let url = Bundle.module.url(forResource: fileName, withExtension: nil) {
            return url
        }
        #if DEBUG
        print("[ExerciseGifBundleResource] GIF '\(fileName)' ist im generierten Mapping gelistet, aber nicht in Bundle.module auffindbar (weder unter ExerciseGifs/ noch im Bundle-Root).")
        #endif
        return nil
    }
}
