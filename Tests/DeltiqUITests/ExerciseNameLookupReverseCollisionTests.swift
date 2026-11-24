#if canImport(SwiftUI) && canImport(UIKit)
import XCTest
@testable import DeltiqUI

/// Modul-12-Audit (Migration), Fund 1. Zwei echte Library-Eintraege teilen
/// sich EN/TR dieselbe Translation: `exercise.name.calfPressLegPress` und
/// `exercise.name.sledCalfPressLegPress` liefern beide "Leg Press Calf
/// Raise". Der Reverse-Lookup-Cache liess bisher den zuletzt verarbeiteten
/// Eintrag gewinnen (`map[translation] = key`), wodurch ein Bestandsname wie
/// "Leg Press Calf Raise" beim Backfill IMMER auf dieselbe, moeglicherweise
/// falsche Uebung umgeschrieben wurde. `canonicalBaseName` muss fuer einen
/// mehrdeutigen Namen jetzt `nil` liefern (derselbe sichere Fallback wie bei
/// einem Custom-Namen ohne Library-Treffer), waehrend ein eindeutiger
/// Fremdsprach-Name weiterhin normal aufgeloest wird.
final class ExerciseNameLookupReverseCollisionTests: XCTestCase {
    func testAmbiguousTranslationResolvesToNilInsteadOfGuessing() {
        XCTAssertNil(
            ExerciseNameLookup.canonicalBaseName(forStoredName: "Leg Press Calf Raise"),
            "a translation shared by two distinct library entries must not be silently resolved to either one"
        )
        XCTAssertNil(
            ExerciseNameLookup.localizationKey(forStoredName: "Leg Press Calf Raise"),
            "the localization key lookup must degrade the same way as canonicalBaseName for an ambiguous name"
        )
    }

    func testUnambiguousForeignLocaleNameStillResolvesCorrectly() {
        XCTAssertEqual(
            ExerciseNameLookup.canonicalBaseName(forStoredName: "Treadmill"),
            "Laufband",
            "an unambiguous EN/TR translation must still resolve to its DE base name"
        )
    }

    func testGenuineCustomNameWithNoLibraryMatchStaysNil() {
        XCTAssertNil(ExerciseNameLookup.canonicalBaseName(forStoredName: "Mein ganz eigener Custom-Name 12345"))
    }
}
#endif
