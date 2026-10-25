#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest

/// Equipment-Vielfalt Phase 1 Task 4, Step 8: source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo, gleiches Muster wie
/// `SetRowTargetPaceTests`/`CardioFeasibilityDayRowPaceTests`). Beweist, dass
/// `PlanEditorView`s neue Equipment-Luecken-Anzeige
///   (a) `SavedPlanEquipmentCheck.report(` direkt in einem `body`/computed-
///       property-Kontext aufruft — NIE ueber einen dazwischenliegenden
///       `@State`-Cache (sonst stale nach einer Profil-Aenderung an anderer
///       Stelle in der App), und
///   (b) dafuer die BEREITS BESTEHENDE `userProfiles`-Query dieser View
///       liest, statt eine zweite, eigene Profil-Abfrage einzufuehren.
final class PlanEditorEquipmentGapBannerTests: XCTestCase {

    private var source: String {
        get throws {
            let path = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // FitnessAppUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/FitnessAppUI/Workout/PlanEditorView.swift")
            return try String(contentsOf: path, encoding: .utf8)
        }
    }

    func testEquipmentGapReportIsAPlainComputedPropertyNotState() throws {
        let src = try source
        XCTAssertTrue(src.contains("private var equipmentGapReport: PlanEquipmentReport?"),
                       "equipmentGapReport muss als plain computed property existieren")
        XCTAssertFalse(src.contains("@State private var equipmentGapReport"),
                        "equipmentGapReport darf NICHT aus einem @State-Cache stammen, sondern muss bei jedem Zugriff frisch rechnen (gleiches Prinzip wie ProgramTemplatePickerView.resolvedSelection)")
    }

    func testEquipmentGapReportCallsSavedPlanEquipmentCheckReportDirectly() throws {
        let src = try source
        XCTAssertTrue(src.contains("SavedPlanEquipmentCheck.report(for: plan, against: profile)"),
                       "Die Luecken-Pruefung muss SavedPlanEquipmentCheck.report( direkt aufrufen, nicht ueber eine eigene Neuimplementierung")
    }

    func testEquipmentGapReportReadsTheExistingUserProfilesQueryNotANewOne() throws {
        let src = try source
        // Die View hat bereits GENAU EINE `@Query private var userProfiles:
        // [UserBodyProfile]` — Task 4 darf keine zweite hinzufuegen.
        let queryOccurrences = src.components(separatedBy: "@Query private var userProfiles").count - 1
        XCTAssertEqual(queryOccurrences, 1, "Es darf weiterhin nur EINE userProfiles-Query geben")
        XCTAssertTrue(src.contains("userProfiles.first?.equipmentProfile"),
                       "equipmentGapReport muss das Profil aus der BESTEHENDEN userProfiles-Query lesen (gleicher Zugriffsstil wie an den anderen userProfiles.first-Stellen dieser View)")
    }

    func testEquipmentGapSectionIsWiredIntoTheList() throws {
        let src = try source
        XCTAssertTrue(src.contains("equipmentGapSection"), "Die neue Section muss tatsaechlich in body/List eingebunden sein")
        // Nur sichtbar, wenn tatsaechlich eine Luecke existiert — Decision 1
        // (warnen, nicht blockieren) verlangt keine Anzeige im Normalfall.
        XCTAssertTrue(src.contains("!report.isFullyAvailable"),
                       "Die Section darf nur erscheinen, wenn PlanEquipmentReport.isFullyAvailable == false ist")
    }
}
#endif
