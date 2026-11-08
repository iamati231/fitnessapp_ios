#if canImport(SwiftUI)
import XCTest

/// UI-Ticket ("Deltiq – Informationsarchitektur des Tabs 'Mehr'"): Werkzeuge
/// und Übungsbibliothek gehören nicht länger unter eine "Weitere
/// Einstellungen"-Sammelgruppe (siehe `SettingsGroupOrderAndAttributionTests`
/// fürs Settings-seitige), UND die bestehende Übungsbibliothek soll aus dem
/// Plan Builder/Editor sowie der Übungsalternativen-Auswahl erreichbar
/// bleiben - derselbe Screen, keine zweite Implementierung. Source-
/// introspection (kein SwiftUI-Render-Harness in diesem Repo), gleiches
/// Muster wie `PlanBuilderResultDayRowTemplateAlignmentTests`.
final class MehrInformationArchitectureTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    /// Both contextual entry points must reuse the exact same, existing
    /// `ExerciseLibraryView` (no `()`-free bare reference would also match a
    /// hypothetical second type with a similar name - this is deliberately a
    /// strict literal check) rather than building a second library screen.
    func testPlanBuilderAndPlanEditorBothReuseTheExistingExerciseLibraryView() throws {
        let planBuilderSource = try contents(of: "Workout/PlanBuilderView.swift")
        let planEditorSource = try contents(of: "Workout/PlanEditorView.swift")
        XCTAssertTrue(
            planBuilderSource.contains("ExerciseLibraryView()"),
            "PlanBuilderView muss die bestehende ExerciseLibraryView präsentieren, keine neue Implementierung."
        )
        XCTAssertTrue(
            planEditorSource.contains("ExerciseLibraryView()"),
            "PlanEditorView muss die bestehende ExerciseLibraryView präsentieren, keine neue Implementierung."
        )
    }

    func testPlanBuilderOffersTheLibraryFromBothThePerDayMenuAndTheAlternativesDialog() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        // Zwei getrennte Ausloeser, dieselbe Zielfunktion.
        XCTAssertEqual(
            source.components(separatedBy: "showingExerciseLibrary = true").count - 1, 2,
            "Die Bibliothek muss sowohl aus dem Pro-Tag-Menu (Bearbeiten eines Plans) als auch aus dem Übungsalternativen-Dialog ausgelöst werden können."
        )
        XCTAssertTrue(
            source.contains("@State private var showingExerciseLibrary = false"),
            "Ein einzelner, gemeinsamer Zustand muss beide Ausloeser bedienen - kein zweiter State pro Einstiegspunkt."
        )
    }

    func testPlanEditorOffersTheLibraryFromItsEllipsisMenu() throws {
        let source = try contents(of: "Workout/PlanEditorView.swift")
        XCTAssertTrue(
            source.contains("@State private var showingExerciseLibrary = false"),
            "PlanEditorView muss den Bibliotheks-Zugang ebenfalls anbieten."
        )
        guard let menuRange = source.range(of: "private var planMenuAction: DeltiqHeaderAction? {") else {
            XCTFail("planMenuAction nicht gefunden")
            return
        }
        XCTAssertTrue(
            source[menuRange.upperBound...].contains("showingExerciseLibrary = true"),
            "Der Bibliotheks-Eintrag muss im bestehenden Ellipsis-Menu liegen, kein neuer Menu-Punkt an anderer Stelle."
        )
    }

    // MARK: - Swipe-Back-Regressionstest (schwarze View im Mehr-Tab)

    /// SettingsView ist die Root-View des Mehr-Tabs. Nach dem Zurueckswipen
    /// von einer Sub-View, die `.deltiqSwipeBackEnabled()` (enabled=true) gesetzt
    /// hat, muss SettingsView den `interactivePopGestureRecognizer` explizit
    /// deaktivieren — sonst bleibt isEnabled=true und der native iOS-Recognizer
    /// kann auf der Root-View eine Pop-Transition starten, die zu einem schwarzen,
    /// inhaltsleeren Screen fuehrt.
    ///
    /// Manueller Regressionstest:
    /// 1. Mehr-Tab oeffnen → SettingsView.
    /// 2. Beliebige Unterseite oeffnen (z.B. "Bibliothek & Ausruestung").
    /// 3. Mehrfach zurueckswipen bis SettingsView.
    /// 4. Tab wechseln (z.B. Heute), dann Mehr erneut auswaehlen.
    /// 5. Erneut Unterseite oeffnen und zurueckswipen.
    /// Erwartung: SettingsView bleibt immer vollstaendig gerendert, kein schwarzer Screen.
    func testSettingsViewDisablesSwipeBackGestureAtRoot() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        XCTAssertTrue(
            source.contains(".deltiqSwipeBackEnabled(false)"),
            "SettingsView (Mehr-Tab-Root) muss .deltiqSwipeBackEnabled(false) setzen, " +
            "damit interactivePopGestureRecognizer.isEnabled auf der Root-View false bleibt " +
            "und kein schwarzer Screen nach wiederholtem Zurueckswipen entsteht."
        )
    }

    /// `planBuilder.exerciseLibrary.action` ist die einzige neue Resource für
    /// diesen kontextuellen Zugang - DE/EN/TR müssen vollständig sein.
    func testExerciseLibraryActionLabelIsFullyLocalized() throws {
        let strings = try contents(of: "Resources/Localizable.xcstrings")
        guard let keyRange = strings.range(of: "\"planBuilder.exerciseLibrary.action\": {") else {
            XCTFail("planBuilder.exerciseLibrary.action nicht gefunden")
            return
        }
        // Brace-counting statt eines auf ein nachfolgendes Komma angewiesenen
        // Textmusters - dieser Key kann (und tut es hier) der letzte Eintrag
        // der Datei sein, dessen schliessende Klammer KEIN Komma traegt.
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: strings, afterOpenBrace: keyRange.upperBound))
        for language in ["\"de\": {", "\"en\": {", "\"tr\": {"] {
            XCTAssertTrue(block.contains(language), "fehlende Lokalisierung: \(language)")
        }
    }
}
#endif
