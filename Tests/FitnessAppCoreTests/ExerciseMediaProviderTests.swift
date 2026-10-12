import XCTest
@testable import FitnessAppCore

final class ExerciseMediaProviderTests: XCTestCase {

    // MARK: Namensnormalisierung

    func testNormalizesCaseAndTrimsWhitespace() {
        XCTAssertEqual(ExerciseMediaProvider.normalizedKey(for: "  Kniebeuge  "), "kniebeuge")
        XCTAssertEqual(
            ExerciseMediaProvider.normalizedKey(for: "Bankdrücken"),
            ExerciseMediaProvider.normalizedKey(for: "BANKDRÜCKEN")
        )
    }

    func testNormalizesUmlautsAndSharpS() {
        // 1:1-Port-Anforderung an .scripts/build_exercise_gif_map.py:normalize() —
        // dieselben Transformationsregeln, damit generierte Keys und
        // Laufzeit-Lookup zusammenpassen.
        XCTAssertEqual(ExerciseMediaProvider.normalizedKey(for: "Reißen (Snatch)"), "reissen snatch")
        XCTAssertEqual(ExerciseMediaProvider.normalizedKey(for: "Schrägbankdrücken (aufwärts)"), "schragbankdrucken aufwarts")
    }

    func testCollapsesPunctuationAndMultipleSpaces() {
        XCTAssertEqual(ExerciseMediaProvider.normalizedKey(for: "Klimmzüge (eng/Chin-up)"), "klimmzuge eng chin up")
    }

    /// Klammern werden nur als Satzzeichen entfernt, ihr INHALT bleibt
    /// erhalten. "Shrug (KH)" (Kurzhantel) und "Shrug (LH)" (Langhantel)
    /// sind zwei verschiedene Uebungen in `ExerciseLibraryData` — wuerden
    /// sie auf denselben Key kollabieren, bekaeme eine der beiden am Ende
    /// das GIF der anderen untergeschoben.
    func testKeepsParentheticalQualifiersDistinct() {
        let kh = ExerciseMediaProvider.normalizedKey(for: "Shrug (KH)")
        let lh = ExerciseMediaProvider.normalizedKey(for: "Shrug (LH)")
        XCTAssertEqual(kh, "shrug kh")
        XCTAssertEqual(lh, "shrug lh")
        XCTAssertNotEqual(kh, lh)
    }

    /// Haerteste Garantie gegen ein falsches GIF: alle 186 echten
    /// Bibliotheks-Namen muessen nach der Normalisierung weiterhin
    /// eindeutige Keys ergeben. Eine Kollision hier wuerde bedeuten, dass
    /// eine Uebung nach dem naechsten Skript-Lauf stillschweigend das GIF
    /// einer anderen erbt.
    func testRealLibraryNamesStayUniqueAfterNormalization() {
        let keys = ExerciseLibraryData.all.map { ExerciseMediaProvider.normalizedKey(for: $0.name) }
        let unique = Set(keys)
        if keys.count != unique.count {
            let counts = Dictionary(grouping: keys, by: { $0 }).mapValues { $0.count }
            let collisions = counts.filter { $0.value > 1 }.keys.sorted()
            XCTFail("Normalisierungs-Kollisionen in der echten Bibliothek: \(collisions)")
        }
    }

    // MARK: Matching-Reihenfolge + Override-Prioritaet

    func testOverrideWinsOverResolvedMap() {
        let gif = ExerciseMediaProvider.gifFileName(
            forExerciseName: "Bankdrücken",
            overrides: ["bankdrucken": "override.gif"],
            resolved: ["bankdrucken": "resolved.gif"]
        )
        XCTAssertEqual(gif, "override.gif")
    }

    func testFallsBackToResolvedMapWhenNoOverridePresent() {
        let gif = ExerciseMediaProvider.gifFileName(
            forExerciseName: "Bankdrücken",
            overrides: [:],
            resolved: ["bankdrucken": "resolved.gif"]
        )
        XCTAssertEqual(gif, "resolved.gif")
    }

    func testOverrideForDifferentExerciseDoesNotLeakIntoAnotherLookup() {
        let gif = ExerciseMediaProvider.gifFileName(
            forExerciseName: "Kniebeuge",
            overrides: ["bankdrucken": "override.gif"],
            resolved: ["kniebeuge": "resolved.gif"]
        )
        XCTAssertEqual(gif, "resolved.gif")
    }

    // MARK: nil bei fehlendem GIF

    func testReturnsNilWhenNameInNeitherMap() {
        let gif = ExerciseMediaProvider.gifFileName(
            forExerciseName: "Komplett unbekannte Uebung",
            overrides: ["bankdrucken": "a.gif"],
            resolved: ["kniebeuge": "b.gif"]
        )
        XCTAssertNil(gif)
    }

    /// Custom (User-erstellte) Uebungen stehen nie in den generierten
    /// Tabellen — die Fallback-Default-Parameter (echte generierte Daten)
    /// muessen fuer einen frei erfundenen Namen ebenfalls `nil` liefern,
    /// nie raten.
    func testReturnsNilForUnknownNameAgainstRealGeneratedTables() {
        XCTAssertNil(ExerciseMediaProvider.gifFileName(forExerciseName: "Mein ganz spezieller Custom-Lift #42"))
    }

    // MARK: Konsistenz der generierten Daten

    /// Jeder Override sollte die Automatik bewusst ersetzen/korrigieren,
    /// nicht denselben Wert zufaellig duplizieren — waere ein Hinweis auf
    /// einen stehengebliebenen Override, der keinen Zweck mehr erfuellt.
    func testOverridesDoNotTriviallyDuplicateTheAutomaticMatch() {
        for (key, gif) in ExerciseGifOverrides.byNormalizedName {
            if let resolvedGif = ExerciseGifResolution.byNormalizedName[key] {
                XCTAssertNotEqual(
                    gif, resolvedGif,
                    "Override fuer \(key) dupliziert den automatischen Treffer, statt ihn zu ersetzen"
                )
            }
        }
    }

    /// GIF_OVERRIDES_TASK: konkreter End-to-End-Beleg gegen die ECHTEN
    /// generierten Tabellen (nicht nur injizierte Test-Dicts) — fuer
    /// "Kniebeuge" liefert die automatische Fuzzy-Suche nichts Sicheres
    /// (siehe GIF_MATCH_REPORT.md), der manuell per Tiefensuche gesetzte
    /// Override muss trotzdem durchkommen.
    func testRealOverrideFromDeepSearchResolves() {
        XCTAssertEqual(
            ExerciseMediaProvider.gifFileName(forExerciseName: "Kniebeuge"),
            "1436-Gnfo4FM.gif"
        )
    }

    /// GIF_OVERRIDES_TASK: die neu in die Bibliothek aufgenommenen Uebungen
    /// sind nur ueber ihren direkten Override auffindbar (kein Fuzzy-Match
    /// noetig) — stellt sicher, dass Name und Override-Key tatsaechlich
    /// zusammenpassen (keine Tippfehler zwischen ExerciseLibraryData.swift
    /// und exercise_gif_overrides.json).
    func testNewlyAddedExercisesResolveViaRealOverrides() {
        let expectations: [(name: String, gifFile: String)] = [
            ("Power Clean", "0648-SiWCcTN.gif"),
            ("Reverse Crunch", "0872-nCU1Ekp.gif"),
            ("Burpee mit Kurzhanteln", "1201-0JtKWum.gif"),
        ]
        for (name, gifFile) in expectations {
            XCTAssertEqual(ExerciseMediaProvider.gifFileName(forExerciseName: name), gifFile)
        }
    }

    // MARK: GIF_OVERRIDES_TASK_2 (Runde 3)

    /// Die 15 Praezisions-Varianten (Abschnitt 2) + 3 eigene
    /// Tiefensuche-Treffer (Abschnitt 3) muessen ueber ihren Override
    /// auffindbar sein — dasselbe GIF, das vorher (zu ungenau) an die
    /// FORCE_NO_GIF-Uebung haengte, bzw. ein frisch recherchierter Treffer.
    func testRound3PrecisionVariantsResolveViaRealOverrides() {
        let expectations: [(name: String, gifFile: String)] = [
            ("Einbeinige Split-Kniebeuge (KH)", "0410-qx4fgX7.gif"),
            ("Liegendes Bein-Hüft-Heben", "0865-9IxJdtC.gif"),
            ("Innere Brustpresse (Maschine)", "1301-wDN97Ca.gif"),
            ("Sitzender Kabel-Crunch", "0212-8xUv4J7.gif"),
            ("Kabel Cross-Over (Variation)", "0155-0CXGHya.gif"),
            ("Kettlebell Schulterdrücken sitzend", "0546-BkxB8LW.gif"),
            ("Kettlebell Doppel-Push-Press", "0528-I4KkPdl.gif"),
            ("Kettlebell Thruster", "0550-yWxMvB5.gif"),
            ("Latzug an der Kabelstange", "0150-eYnzaCm.gif"),
            ("Kettlebell Plyo-Liegestütze", "0545-ktf3nvW.gif"),
            ("Kabel Reverse Fly liegend", "0240-PQcUlDi.gif"),
            ("Schulterdrücken (Smith Machine)", "0766-903mzG8.gif"),
            ("Sitzendes Trizepsstrecken (KH)", "2188-kont8Ut.gif"),
            ("Kettlebell Turkish Get-Up (Squat-Stil)", "0551-Ha7SZ3y.gif"),
            ("Sitzendes Wadenheben (KH)", "1379-r29jP7S.gif"),
            ("Beincurl stehend (BW)", "0795-C5jncD2.gif"),
            ("Renegade Row (Kettlebell)", "0521-b9kqlBy.gif"),
            ("Latzug eng (Band)", "0974-DptumMx.gif"),
        ]
        for (name, gifFile) in expectations {
            XCTAssertEqual(ExerciseMediaProvider.gifFileName(forExerciseName: name), gifFile,
                           "'\(name)' sollte per Override '\(gifFile)' auflösen")
        }
    }

    /// Skull Crusher: direkter 100%-Treffer (Bewegung + Equipment identisch)
    /// aus der zweiten Volldatensatz-Suche (Abschnitt 3) — keine neue
    /// Uebung, nur ein Override auf den bestehenden Library-Eintrag.
    func testSkullCrusherResolvesViaRealOverride() {
        XCTAssertEqual(ExerciseMediaProvider.gifFileName(forExerciseName: "Skull Crusher"), "0060-h8LFzo9.gif")
    }

    /// GIF_OVERRIDES_TASK_2, Abschnitt 1: diese 16 Uebungen hatten bisher
    /// einen (zu ungenauen) Override, der jetzt bewusst entfernt und durch
    /// `FORCE_NO_GIF` blockiert wurde — die passend benannte Nachfolge-
    /// Uebung traegt das GIF stattdessen. Haerteste Garantie gegen ein
    /// stillschweigend zurueckkehrendes falsches Match: direkt gegen die
    /// echten generierten Tabellen, nicht nur gegen injizierte Test-Dicts.
    func testForceExcludedExercisesResolveToNilAgainstRealGeneratedTables() {
        let names = [
            "Beinheben (liegend)", "Bulgarische Kniebeuge (KH)", "Brustdrücken (Maschine)",
            "Kabel Crunch", "Kabel Crossover", "Kettlebell Clean to Front Squat",
            "Kettlebell Overhead Press", "Kettlebell Push Press", "Kettlebell Thruster einarmig",
            "Latzug (weit)", "Liegestütze auf Kettlebell", "Reverse Cable Fly",
            "Schulterdrücken (Maschine)", "Trizepsstrecker über Kopf (KH)", "Turkish Get-Up",
            "Wadenheben (KH)",
        ]
        for name in names {
            XCTAssertNil(ExerciseMediaProvider.gifFileName(forExerciseName: name),
                         "'\(name)' sollte nach FORCE_NO_GIF kein GIF mehr liefern")
        }
    }
}
