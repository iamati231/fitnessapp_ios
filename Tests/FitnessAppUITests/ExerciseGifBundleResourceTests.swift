import XCTest
@testable import FitnessAppCore
@testable import FitnessAppUI

/// Regression-Test fuer den Bug: `Sources/FitnessAppUI/Resources/ExerciseGifs/`
/// lag unter `Resources/`, `.process("Resources")` flacht verschachtelte
/// Unterordner im Bundle ab, `Bundle.module.url(..., subdirectory:
/// "ExerciseGifs")` fand dadurch nie etwas — die Übungsdetail-/Workout-Ansicht
/// zeigte trotz vorhandener Datei nur den Platzhalter. Fix: `ExerciseGifs`
/// ist jetzt ein eigener Top-Level-Resource-Pfad (`.copy("ExerciseGifs")`
/// in `Package.swift`), dieser Test prueft direkt, dass jede im generierten
/// Mapping gelistete GIF-Datei tatsaechlich ueber `Bundle.module` auflösbar
/// ist — nicht nur, dass sie auf der Festplatte existiert.
final class ExerciseGifBundleResourceTests: XCTestCase {

    private var allMappedGifFiles: Set<String> {
        Set(ExerciseGifResolution.byNormalizedName.values)
            .union(ExerciseGifOverrides.byNormalizedName.values)
    }

    func testMappingIsNotEmpty() {
        XCTAssertFalse(
            allMappedGifFiles.isEmpty,
            "ExerciseGifResolution/-Overrides liefern keine Eintraege — .scripts/build_exercise_gif_map.py gelaufen?"
        )
    }

    func testEveryMappedGifFileIsReachableInBundleModule() {
        for gifFile in allMappedGifFiles.sorted() {
            XCTAssertNotNil(
                ExerciseGifBundleResource.url(forGifFileName: gifFile),
                "GIF '\(gifFile)' steht im generierten Mapping, ist aber nicht ueber Bundle.module erreichbar " +
                "— liegt die Datei unter Sources/FitnessAppUI/ExerciseGifs/ und ist sie in Package.swifts " +
                "resources: [...] als eigener, nicht ueberlappender Pfad eingebunden?"
            )
        }
    }

    func testUnknownGifFileNameResolvesToNil() {
        XCTAssertNil(ExerciseGifBundleResource.url(forGifFileName: "does-not-exist-9999.gif"))
    }
}
