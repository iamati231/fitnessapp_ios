import XCTest
@testable import DeltiqCore

/// Ticket: Template-Programme gruppieren — Abnahmekriterien (rein modell-seitig).
/// UI-Tests (Search/Filter) sind Simulator-only und hier nicht abgedeckt.
final class ProgramTemplateCategoryTests: XCTestCase {

    // "Kraft & Hypertrophie" erscheint exakt einmal als raw focus
    func testKraftHypertrophieAppearsExactlyOnceFocus() {
        let foci = Set(ProgramTemplates.all.map(\.focus))
        XCTAssertTrue(foci.contains("Kraft & Hypertrophie"))
        XCTAssertFalse(foci.contains("Kraft + Hypertrophie"), "'+' statt '&' erzeugt Doppel-Section")
    }

    // fullBody3xExperienced und upperLower teilen denselben focus
    func testFullBody3xExperiencedAndUpperLowerShareFocus() {
        let fullBody3x = ProgramTemplates.all.first { $0.id == "full_body_3x_experienced" }!
        let upperLower  = ProgramTemplates.all.first { $0.id == "upper_lower" }!
        XCTAssertEqual(fullBody3x.focus, upperLower.focus)
        XCTAssertEqual(fullBody3x.focus, "Kraft & Hypertrophie")
    }

    // CrossFit-Templates haben focus "CrossFit", Kettlebell-Templates "Kettlebell"
    func testCrossFitAndKettlebellAreSeparateCategories() {
        let crossfitIds   = ["crossfit_bodyweight_rx", "crossfit_bodyweight_scaled", "crossfit_weighted"]
        let kettlebellIds = ["kettlebell_beginner", "kettlebell_advanced", "kettlebell_complexes"]

        let crossfitFoci   = ProgramTemplates.all.filter { crossfitIds.contains($0.id) }.map(\.focus)
        let kettlebellFoci = ProgramTemplates.all.filter { kettlebellIds.contains($0.id) }.map(\.focus)

        XCTAssertEqual(crossfitFoci.count, 3, "Alle 3 CrossFit-Templates gefunden")
        XCTAssertTrue(crossfitFoci.allSatisfy { $0 == "CrossFit" }, "CrossFit-Templates: focus muss 'CrossFit' sein")

        XCTAssertEqual(kettlebellFoci.count, 3, "Alle 3 Kettlebell-Templates gefunden")
        XCTAssertTrue(kettlebellFoci.allSatisfy { $0 == "Kettlebell" }, "Kettlebell-Templates: focus muss 'Kettlebell' sein")

        XCTAssertTrue(Set(crossfitFoci).isDisjoint(with: Set(kettlebellFoci)), "Keine gemeinsame Kategorie")
    }

    // categoryOrder entspricht exakt der geforderten Reihenfolge
    func testCategoryOrderIsExact() {
        let expected = [
            "Anfänger",
            "Kraft & Hypertrophie",
            "Hypertrophie",
            "Kraft",
            "Hybrid & Athletik",
            "Funktionelle Fitness",
            "CrossFit",
            "Kettlebell",
            "Defizit-Phase",
            "Athletik",
        ]
        XCTAssertEqual(ProgramTemplates.categoryOrder, expected)
    }

    // categoryOrder deckt alle vorhandenen focus-Werte ab
    func testCategoryOrderCoversAllFoci() {
        let allFoci = Set(ProgramTemplates.all.map(\.focus))
        for focus in allFoci {
            XCTAssertTrue(
                ProgramTemplates.categoryOrder.contains(focus),
                "focus '\(focus)' fehlt in categoryOrder — würde im Picker hinten landen"
            )
        }
    }

    // Alle 21 Templates bleiben erhalten
    func testAllTemplatesPreserved() {
        XCTAssertEqual(ProgramTemplates.all.count, 21)
    }
}
