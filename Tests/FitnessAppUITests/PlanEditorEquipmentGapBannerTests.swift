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
        XCTAssertTrue(src.contains("SavedPlanEquipmentCheck.report(for: plan, against: context.effectiveProfile)"),
                       "Die Luecken-Pruefung muss SavedPlanEquipmentCheck.report( direkt aufrufen, nicht ueber eine eigene Neuimplementierung")
    }

    func testEquipmentGapReportReadsTheExistingUserProfilesQueryNotANewOne() throws {
        let src = try source
        // Die View hat bereits GENAU EINE `@Query private var userProfiles:
        // [UserBodyProfile]` — Task 4 darf keine zweite hinzufuegen.
        let queryOccurrences = src.components(separatedBy: "@Query private var userProfiles").count - 1
        XCTAssertEqual(queryOccurrences, 1, "Es darf weiterhin nur EINE userProfiles-Query geben")
        XCTAssertTrue(src.contains("guard let profile = userProfiles.first else { return nil }"),
                       "equipmentPlanningContext muss das Profil aus der BESTEHENDEN userProfiles-Query lesen, keine zweite Query einfuehren")
    }

    /// Final-Review Fix 3: die Luecken-Pruefung muss denselben effektiven
    /// Kontext verwenden wie `ProgramTemplatePickerView.equipmentPlanningContext`
    /// (`EquipmentPlanningResolver.resolve`) statt des rohen, individuellen
    /// Profils — sonst liest ein Default-User ohne eigene Einrichtung
    /// (komplett `.unknown`-Profil) hier faelschlich jede annotierte Uebung
    /// als Luecke, obwohl der Picker fuer denselben Fall nur die neutrale
    /// "Annahme"-Anzeige zeigt, nie eine harte Warnung.
    func testEquipmentGapReportRoutesThroughEquipmentPlanningResolverLikeThePicker() throws {
        let src = try source
        XCTAssertTrue(src.contains("EquipmentPlanningResolver.resolve("),
                       "equipmentPlanningContext muss ueber EquipmentPlanningResolver.resolve( aufloesen, exakt wie ProgramTemplatePickerView.equipmentPlanningContext — kein eigener, neu erfundener Aufloesungsweg")
        XCTAssertTrue(src.contains("environment: profile.environment"),
                       "muss environment an den Resolver reichen")
        XCTAssertTrue(src.contains("individualProfile: profile.equipmentProfile"),
                       "muss das individuelle Profil an den Resolver reichen")
        XCTAssertTrue(src.contains("confirmedComplete: profile.equipmentProfileConfirmedComplete"),
                       "muss confirmedComplete an den Resolver reichen")
    }

    /// Eine reine Gym-Planungsannahme (unconfiguriertes Equipment,
    /// `EquipmentPlanningContext.isAssumption == true`) darf NIE die harte
    /// Luecken-Warnung zeigen — exakt die Regel, die
    /// `TemplatePreviewView.isEquipmentAssumption` im Picker bereits
    /// durchsetzt ("nie 'Equipment fehlt' fuer eine Annahme behaupten").
    func testEquipmentGapReportSkipsTheBannerForAnAssumption() throws {
        let src = try source
        guard let propertyRange = src.range(of: "private var equipmentGapReport: PlanEquipmentReport? {") else {
            return XCTFail("equipmentGapReport property not found")
        }
        guard let closeRange = src.range(of: "\n    }", range: propertyRange.upperBound..<src.endIndex) else {
            return XCTFail("could not isolate equipmentGapReport's body")
        }
        let body = src[propertyRange.upperBound..<closeRange.lowerBound]
        XCTAssertTrue(body.contains("context.isAssumption"),
                       "equipmentGapReport muss context.isAssumption pruefen und fuer eine Annahme nil liefern (kein Banner)")
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
