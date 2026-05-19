import XCTest
@testable import FitnessAppCore

/// DEL-111: Smoke-Tests fuer die Localization-Key-Annotation der
/// kanonischen Library-Lifts. Stellt sicher, dass die wichtigsten 5
/// Compounds + Plank den `localizationKey` tragen, sonst rutscht die
/// Library bei einem Refactor stillschweigend zurueck auf deutsche
/// Hardcoded-Namen.
final class ExerciseLibraryLocalizationTests: XCTestCase {

    /// Wenn jemand den deutschen `name` eines kanonischen Lifts
    /// umbenennt, ohne den localizationKey mitzudenken, faengt dieser
    /// Test das.
    func testCanonicalLiftsCarryLocalizationKey() {
        let expectations: [(germanName: String, expectedKey: String)] = [
            ("Kniebeuge",                  "exercise.name.squat"),
            ("Bankdrücken",                "exercise.name.benchpress"),
            ("Kreuzheben (konventionell)", "exercise.name.deadlift"),
            ("Schulterdrücken (stehend)",  "exercise.name.overheadpress"),
            ("Rudern vorgebeugt",          "exercise.name.barbellrow"),
            ("Klimmzüge (eng/Chin-up)",    "exercise.name.pullup"),
            ("Latzug (weit)",              "exercise.name.latpulldown"),
            ("KH-Curl",                    "exercise.name.bicepcurl"),
            ("Beinpresse",                 "exercise.name.legpress"),
            ("Plank",                      "exercise.name.plank"),
            ("Freier Lauf",                "exercise.name.run"),
        ]

        for (germanName, expectedKey) in expectations {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == germanName }) else {
                XCTFail("Library-Eintrag '\(germanName)' fehlt — Rename?")
                continue
            }
            XCTAssertEqual(entry.localizationKey, expectedKey,
                           "'\(germanName)' sollte localizationKey '\(expectedKey)' tragen, ist aber '\(entry.localizationKey ?? "nil")'")
        }
    }

    /// Custom-style nicht-kanonische Library-Eintraege duerfen ruhig nil
    /// als localizationKey haben. Stichprobe.
    func testNonCanonicalLiftsHaveNilLocalizationKey() {
        let nonCanonicalSamples = ["Schrägbankdrücken (aufwärts)", "Hammer Curl", "Bulgarische Kniebeuge (KH)"]
        for name in nonCanonicalSamples {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == name }) else {
                XCTFail("Library-Eintrag '\(name)' fehlt")
                continue
            }
            XCTAssertNil(entry.localizationKey,
                         "'\(name)' ist nicht in den 13 kanonischen Lifts — sollte localizationKey == nil haben (sonst Catalog-Drift)")
        }
    }
}
