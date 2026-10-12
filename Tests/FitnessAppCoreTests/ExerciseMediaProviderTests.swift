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
}
