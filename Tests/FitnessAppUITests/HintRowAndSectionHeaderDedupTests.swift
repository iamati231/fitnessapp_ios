import XCTest

/// Audit-Fund (vierter Follow-up-UI-Audit, Fund 3+4): `hintRow(_:)` war
/// byte-identisch in 17 Dateien dupliziert, `sectionHeader` in zwei
/// Gruppen (Plain-Text + Localization-Key) in je 3 bzw. 2 Dateien. Jetzt
/// geteilte Funktionen in `Theme.swift` - dieser Test haelt fest, dass
/// keine der betroffenen Dateien ihre Kopie wieder einfuehrt.
final class HintRowAndSectionHeaderDedupTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(path), encoding: .utf8)
    }

    func testThemeHasTheSharedHelpers() throws {
        let theme = try read("FitnessAppUI/Theme.swift")
        XCTAssertTrue(theme.contains("func hintRow(_ text: String) -> some View {"))
        XCTAssertTrue(theme.contains("func sectionHeader(_ text: String) -> some View {"))
        XCTAssertTrue(theme.contains("func sectionHeaderForKey(_ key: String) -> some View {"))
    }

    func testNoneOfTheHintRowFilesRedefineIt() throws {
        let files = [
            "FitnessAppUI/Cardio/CardioCoachSetupFields.swift",
            "FitnessAppUI/Calculators/OneRepMaxView.swift",
            "FitnessAppUI/Calculators/TDEEView.swift",
            "FitnessAppUI/Calculators/PlateCalculatorView.swift",
            "FitnessAppUI/MeasurementView.swift",
            "FitnessAppUI/Settings/CardioGoalEditorView.swift",
            "FitnessAppUI/Settings/DataExportView.swift",
            "FitnessAppUI/Settings/BodyDataEditorView.swift",
            "FitnessAppUI/Settings/BackupListView.swift",
            "FitnessAppUI/Settings/DataImportView.swift",
            "FitnessAppUI/Settings/ProfileEditorView.swift",
            "FitnessAppUI/Settings/PeriodicCheckInView.swift",
            "FitnessAppUI/Settings/GearListView.swift",
            "FitnessAppUI/Settings/SettingsDataConnectionsView.swift",
            "FitnessAppUI/Settings/SettingsAppExperienceView.swift",
            "FitnessAppUI/Settings/SettingsView.swift",
            "FitnessAppUI/Settings/TrainingLocationEquipmentEditorView.swift",
        ]
        for file in files {
            let text = try read(file)
            XCTAssertFalse(text.contains("func hintRow("),
                           "\(file) must reuse the shared hintRow(_:) instead of its own copy")
            XCTAssertTrue(text.contains("hintRow("),
                          "\(file) must actually call hintRow(...) somewhere")
        }
    }

    /// `HealthWorkoutWriteView` has an extra `.fixedSize(...)` modifier on
    /// its hintRow, so it was deliberately left as its own copy rather than
    /// forced into the shared one (would have meant touching 10 call sites
    /// to re-add the modifier at every usage).
    func testHealthWorkoutWriteViewKeepsItsOwnVariant() throws {
        let text = try read("FitnessAppUI/Settings/HealthWorkoutWriteView.swift")
        XCTAssertTrue(text.contains("private func hintRow(_ text: String) -> some View {"))
    }

    func testNoneOfThePlainSectionHeaderFilesRedefineIt() throws {
        let files = [
            "FitnessAppUI/Workout/DayEditorView.swift",
            "FitnessAppUI/Settings/ExerciseLibraryView.swift",
            "FitnessAppUI/Workout/WorkoutSummaryView.swift",
        ]
        for file in files {
            let text = try read(file)
            XCTAssertFalse(text.contains("func sectionHeader(_ text: String) -> some View {"),
                           "\(file) must reuse the shared sectionHeader(_:) instead of its own copy")
            XCTAssertTrue(text.contains("sectionHeader("))
        }
    }

    func testNoneOfTheKeyedSectionHeaderFilesRedefineIt() throws {
        let files = [
            "FitnessAppUI/Settings/DashboardSettingsView.swift",
            "FitnessAppUI/Workout/PlanEditorView.swift",
        ]
        for file in files {
            let text = try read(file)
            XCTAssertFalse(text.contains("func sectionHeader(_ key: String) -> some View {"),
                           "\(file) must reuse the shared sectionHeaderForKey(_:) instead of its own copy")
            XCTAssertTrue(text.contains("sectionHeaderForKey("),
                          "\(file) must call the renamed shared helper")
        }
    }
}
