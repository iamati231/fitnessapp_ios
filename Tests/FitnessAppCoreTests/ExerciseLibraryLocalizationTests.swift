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

    /// GIF_OVERRIDES_TASK_2: 15 Praezisions-Varianten fuer per `FORCE_NO_GIF`
    /// ausgeschlossene Eintraege + 3 eigene Tiefensuche-Treffer (Abschnitt 3).
    /// Wie bei den Runde-2-Uebungen gilt: DE/EN/TR-Textwerte selbst werden im
    /// Build-Skript gegen `Localizable.xcstrings` geprueft (TR == EN fuer
    /// alle 18 Keys, verifiziert); hier nur die Swift-seitige Verdrahtung.
    func testRound3ExercisesCarryDistinctLocalizationKeys() {
        let expectations: [(germanName: String, expectedKey: String)] = [
            ("Liegendes Bein-Hüft-Heben", "exercise.name.lyingLegHipRaise"),
            ("Innere Brustpresse (Maschine)", "exercise.name.machineInnerChestPress"),
            ("Sitzender Kabel-Crunch", "exercise.name.cableSeatedCrunch"),
            ("Kabel Cross-Over (Variation)", "exercise.name.cableCrossOverVariation"),
            ("Kettlebell Schulterdrücken sitzend", "exercise.name.kettlebellSeatedPress"),
            ("Kettlebell Doppel-Push-Press", "exercise.name.kettlebellDoublePushPress"),
            ("Kettlebell Thruster", "exercise.name.kettlebellThruster"),
            ("Latzug an der Kabelstange", "exercise.name.cableBarLateralPulldown"),
            ("Kettlebell Plyo-Liegestütze", "exercise.name.kettlebellPlyoPushUp"),
            ("Kabel Reverse Fly liegend", "exercise.name.cableSupineReverseFly"),
            ("Schulterdrücken (Smith Machine)", "exercise.name.smithShoulderPress"),
            ("Sitzendes Trizepsstrecken (KH)", "exercise.name.dumbbellSeatedTricepsExtension"),
            ("Kettlebell Turkish Get-Up (Squat-Stil)", "exercise.name.kettlebellTurkishGetUpSquatStyle"),
            ("Sitzendes Wadenheben (KH)", "exercise.name.dumbbellSeatedCalfRaise"),
            ("Beincurl stehend (BW)", "exercise.name.standingSingleLegCurlBodyweight"),
            ("Renegade Row (Kettlebell)", "exercise.name.kettlebellRenegadeRow"),
            ("Latzug eng (Band)", "exercise.name.bandCloseGripPulldown"),
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

    /// Gegenprobe zu `testSystemCompoundsAreBarbellLiftsOnly` (siehe
    /// ExerciseLibraryDataTests): keine der Runde-3-Uebungen nutzt Barbell,
    /// also darf keine davon `isSystemCompound` tragen — das Flag ist
    /// exklusiv fuer die kanonischen 5 Langhantel-Lifts reserviert, auch
    /// wenn das Quell-JSON ein generisches "compound"-Flag mitliefert.
    func testRound3ExercisesDoNotClaimSystemCompoundFlag() {
        let names = [
            "Innere Brustpresse (Maschine)",
            "Kettlebell Schulterdrücken sitzend", "Kettlebell Doppel-Push-Press",
            "Kettlebell Thruster", "Latzug an der Kabelstange",
            "Kettlebell Plyo-Liegestütze", "Schulterdrücken (Smith Machine)",
            "Kettlebell Turkish Get-Up (Squat-Stil)",
        ]
        for name in names {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == name }) else {
                XCTFail("Neue Uebung '\(name)' fehlt in ExerciseLibraryData")
                continue
            }
            XCTAssertFalse(entry.isSystemCompound, "'\(name)' ist kein Barbell-Lift und darf isSystemCompound nicht setzen")
        }
    }

    /// GIF_TIEFENSUCHE: "Einbeinige Split-Kniebeuge (KH)" (Runde 3) war ein
    /// echtes Duplikat von "Bulgarische Kniebeuge (KH)" — dieselbe
    /// Bewegung (hinterer Fuss auf Bank), per Bild-Sichtung bestaetigt.
    /// Die Neuanlage wurde geloescht, das Original bekommt den Override
    /// zurueck. Haerteste Garantie, dass die Dublette nicht wieder
    /// auftaucht: der Name darf in der Library schlicht nicht mehr existieren.
    func testDuplicateSingleLegSplitSquatWasRemoved() {
        XCTAssertNil(
            ExerciseLibraryData.all.first(where: { $0.name == "Einbeinige Split-Kniebeuge (KH)" }),
            "Dubletten-Uebung haette in Runde 4 entfernt werden muessen"
        )
        XCTAssertNotNil(
            ExerciseLibraryData.all.first(where: { $0.name == "Bulgarische Kniebeuge (KH)" }),
            "Original 'Bulgarische Kniebeuge (KH)' darf durch die Dubletten-Bereinigung nicht verschwinden"
        )
    }

    /// GIF_TIEFENSUCHE.md, Abschnitt "Neue Alternativen": 10 weitere
    /// Praezisions-Uebungen aus der Volltext-Tiefensuche. DE/EN/TR-Werte
    /// (TR == EN) werden wie bei Runde 3 im Build-Skript gegen
    /// Localizable.xcstrings geprueft; hier nur die Swift-Verdrahtung.
    func testRound4ExercisesCarryDistinctLocalizationKeys() {
        let expectations: [(germanName: String, expectedKey: String)] = [
            ("Beinheben auf Flachbank", "exercise.name.lyingLegRaiseFlatBench"),
            ("Wand-Sitz mit Marschieren", "exercise.name.marchSitWall"),
            ("Gehen am Laufband (Steigung)", "exercise.name.walkingInclineTreadmill"),
            ("Assistierte Brust-Dips (kniend)", "exercise.name.assistedChestDipKneeling"),
            ("Schulterdrücken stehend (LH, enger Griff)", "exercise.name.barbellStandingCloseGripMilitaryPress"),
            ("Schulterdrücken stehend (LH, breiter Griff)", "exercise.name.barbellStandingWideMilitaryPress"),
            ("Kettlebell Push Press einarmig", "exercise.name.kettlebellOneArmPushPress"),
            ("Kettlebell Schulterdrücken stehend (zwei Kettlebells)", "exercise.name.kettlebellTwoArmMilitaryPress"),
            ("Floor Press einarmig (LH)", "exercise.name.barbellOneArmFloorPress"),
            ("Kettlebell Clean & Jerk einarmig", "exercise.name.kettlebellOneArmCleanAndJerk"),
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

    /// Gegenprobe wie bei Runde 3: drei der neuen Uebungen nutzen zwar
    /// Barbell, sind aber nicht Teil der kanonischen Big Five und duerfen
    /// daher `isSystemCompound` nicht tragen.
    func testRound4BarbellExercisesDoNotClaimSystemCompoundFlag() {
        let names = [
            "Schulterdrücken stehend (LH, enger Griff)",
            "Schulterdrücken stehend (LH, breiter Griff)",
            "Floor Press einarmig (LH)",
        ]
        for name in names {
            guard let entry = ExerciseLibraryData.all.first(where: { $0.name == name }) else {
                XCTFail("Neue Uebung '\(name)' fehlt in ExerciseLibraryData")
                continue
            }
            XCTAssertEqual(entry.equipment, .barbell, "'\(name)' sollte Barbell-Equipment nutzen")
            XCTAssertFalse(entry.isSystemCompound, "'\(name)' ist nicht Teil der kanonischen Big Five und darf isSystemCompound nicht setzen")
        }
    }
}
