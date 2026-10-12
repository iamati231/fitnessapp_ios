import XCTest
@testable import FitnessAppCore

/// DEL-111 / DEL-113: Smoke-Tests fuer die Localization-Key-Annotation der
/// Library-Lifts.
///
/// Historie:
///   - DEL-111 hat die i18n-Infrastruktur etabliert (`localizationKey` auf
///     `ExerciseTemplateSpec`) und 13 kanonische Lifts annotiert. Der Rest
///     der Library war absichtlich `nil` (Catalog-Drift-Guard).
///   - DEL-113 erweitert das auf alle ~119 Library-Eintraege. Damit kippt
///     der ehemalige "nil ist OK"-Test in sein Gegenteil: **kein** Library-
///     Eintrag darf jetzt mehr `nil` haben.
final class ExerciseLibraryLocalizationTests: XCTestCase {

    /// Smoke-Test fuer die kanonischen 5 Compounds + Klassiker. Wenn jemand
    /// den deutschen `name` umbenennt, ohne den localizationKey mitzudenken,
    /// faengt dieser Test das.
    func testCanonicalLiftsCarryLocalizationKey() {
        let expectations: [(germanName: String, expectedKey: String)] = [
            ("Kniebeuge",                  "exercise.name.squat"),
            ("Bankdrücken",                "exercise.name.benchpress"),
            ("Kreuzheben (konventionell)", "exercise.name.deadlift"),
            ("Schulterdrücken (stehend)",  "exercise.name.overheadpress"),
            ("Rudern vorgebeugt",          "exercise.name.barbellrow"),
            ("Klimmzüge (eng/Chin-up)",    "exercise.name.pullup"),
            ("Latzug (weit)",              "exercise.name.latpulldown"),
            ("Bizeps-Curl (KH)",           "exercise.name.bicepcurl"),
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

    /// DEL-113: Stichprobe der neu annotierten Lifts. Falls hier was bricht,
    /// hat jemand entweder den deutschen Namen umbenannt oder den Catalog-
    /// Key umgeschmissen.
    func testDEL113NewlyAnnotatedLiftsCarryLocalizationKey() {
        let samples: [(germanName: String, expectedKey: String)] = [
            ("Schrägbankdrücken (aufwärts)",        "exercise.name.inclineBenchPress"),
            ("Hammer Curl",                         "exercise.name.hammerCurl"),
            ("Bulgarische Kniebeuge (KH)",          "exercise.name.bulgarianSplitSquatDB"),
            ("Goblet Squat",                        "exercise.name.gobletSquat"),
            ("Liegestütze",                         "exercise.name.pushup"),
            ("Burpees",                             "exercise.name.burpee"),
            ("Face Pull",                           "exercise.name.facePull"),
            ("Kettlebell Swing",                    "exercise.name.kettlebellSwing"),
            ("Schwimmen",                           "exercise.name.swimming"),
            ("Rumänisches Kreuzheben",              "exercise.name.romanianDeadlift"),
        ]

        for (germanName, expectedKey) in samples {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == germanName }) else {
                XCTFail("Library-Eintrag '\(germanName)' fehlt")
                continue
            }
            XCTAssertEqual(entry.localizationKey, expectedKey,
                           "'\(germanName)' sollte localizationKey '\(expectedKey)' tragen, ist aber '\(entry.localizationKey ?? "nil")'")
        }
    }

    /// DEL-113 Catalog-Drift-Guard: **jeder** Library-Eintrag traegt jetzt
    /// einen Key. Wer einen neuen Lift hinzufuegt, ohne den Key zu setzen,
    /// faellt hier auf die Nase — und wird gezwungen, die xcstrings
    /// nachzuziehen.
    func testEveryLibraryEntryHasLocalizationKey() {
        let missing = ExerciseLibraryData.all
            .filter { $0.localizationKey == nil || $0.localizationKey?.isEmpty == true }
            .map(\.name)
        XCTAssertTrue(missing.isEmpty,
                      "DEL-113-Invariante verletzt — die folgenden Library-Eintraege haben keinen localizationKey: \(missing)")
    }

    /// DEL-113: Catalog-Keys folgen dem Namespace `exercise.name.*`. Wer aus
    /// Versehen ein `exercises.name.*` (Plural) tippt, soll hier kassieren.
    func testAllLocalizationKeysUseCanonicalNamespace() {
        for entry in ExerciseLibraryData.all {
            guard let key = entry.localizationKey else { continue }
            XCTAssertTrue(key.hasPrefix("exercise.name."),
                          "'\(entry.name)' hat einen Key ausserhalb des `exercise.name.*` Namespaces: '\(key)'")
        }
    }

    /// GIF_OVERRIDES_TASK: die 18 per GIF-Tiefensuche neu aufgenommenen
    /// Uebungen muessen denselben Vertrag erfuellen wie jeder andere
    /// Library-Eintrag — eigener Key, keine Kollision mit einem
    /// bestehenden Key. Lokalisierte DE/EN/TR-Werte selbst werden im
    /// Build-Skript (`load_en_names` gegen `Localizable.xcstrings`)
    /// geprueft; hier geht es um die Swift-Seite der Zuordnung.
    func testNewlyAddedExercisesCarryDistinctLocalizationKeys() {
        let expectations: [(germanName: String, expectedKey: String)] = [
            ("Arnold Press (KH)", "exercise.name.dumbbellArnoldPress"),
            ("Arnold Press (Kettlebell)", "exercise.name.kettlebellArnoldPress"),
            ("Ausfallschritt rückwärts (KH)", "exercise.name.dumbbellReverseLunge"),
            ("Ausfallschritt rückwärts (LH)", "exercise.name.barbellReverseLunge"),
            ("Seitlicher Ausfallschritt (LH)", "exercise.name.barbellLateralLunge"),
            ("Kettlebell Windmill", "exercise.name.kettlebellWindmill"),
            ("Kettlebell Pistol Squat", "exercise.name.kettlebellPistolSquat"),
            ("Kettlebell Bent Press", "exercise.name.kettlebellBentPress"),
            ("Power Clean", "exercise.name.powerClean"),
            ("Low-Bar-Kniebeuge (LH)", "exercise.name.lowBarBackSquat"),
            ("Hack Squat (LH)", "exercise.name.barbellHackSquat"),
            ("Hack Squat (Smith)", "exercise.name.smithHackSquat"),
            ("Reverse Crunch", "exercise.name.reverseCrunch"),
            ("Kabel Reverse Crunch", "exercise.name.cableReverseCrunch"),
            ("Handgelenk-Curl (LH)", "exercise.name.barbellWristCurl"),
            ("Handgelenk-Curl (Kabel)", "exercise.name.cableWristCurl"),
            ("Band Pull-Through", "exercise.name.bandPullThrough"),
            ("Burpee mit Kurzhanteln", "exercise.name.dumbbellBurpee"),
        ]

        for (germanName, expectedKey) in expectations {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == germanName }) else {
                XCTFail("Neue Uebung '\(germanName)' fehlt in ExerciseLibraryData — wurde sie umbenannt oder versehentlich entfernt?")
                continue
            }
            XCTAssertEqual(entry.localizationKey, expectedKey,
                           "'\(germanName)' sollte localizationKey '\(expectedKey)' tragen, ist aber '\(entry.localizationKey ?? "nil")'")
        }

        let keys = expectations.map(\.expectedKey)
        XCTAssertEqual(Set(keys).count, keys.count, "Die neuen localizationKeys duerfen sich nicht untereinander doppeln")

        let otherKeys = Set(ExerciseLibraryData.all
            .filter { entry in !expectations.contains { $0.germanName == entry.name } }
            .compactMap(\.localizationKey))
        let collisions = keys.filter(otherKeys.contains)
        XCTAssertTrue(collisions.isEmpty, "Neue localizationKeys kollidieren mit bestehenden Eintraegen: \(collisions)")
    }
}
