import XCTest

/// Audit-Fund (Follow-up-UI-Audit, "ageYears(for:) is copy-pasted
/// identically into 4 files"): `TDEEView`, `MeasurementView`,
/// `NutritionGoalsView`, `SettingsView` hatten je eine byte-identische
/// private `ageYears(for:)`-Helper. Jetzt `UserBodyProfile.ageYears`
/// (FitnessAppData) als einzige Quelle - dieser Test haelt fest, dass keine
/// der vier Dateien die Kopie wieder einfuehrt.
final class AgeYearsDedupTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    func testUserBodyProfileHasTheSharedAgeYearsProperty() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("FitnessAppData/UserBodyProfile.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("public var ageYears: Int {"),
                      "UserBodyProfile must expose the shared ageYears computed property")
    }

    func testNoneOfTheFourUIFilesRedefineAgeYears() throws {
        let files = [
            "FitnessAppUI/Calculators/TDEEView.swift",
            "FitnessAppUI/MeasurementView.swift",
            "FitnessAppUI/Nutrition/NutritionGoalsView.swift",
            "FitnessAppUI/Settings/SettingsView.swift",
        ]
        for file in files {
            let text = try String(contentsOf: sourcesRoot.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(text.contains("func ageYears(for"),
                           "\(file) must reuse UserBodyProfile.ageYears instead of its own copy")
            XCTAssertTrue(text.contains(".ageYears"),
                          "\(file) must actually call profile.ageYears somewhere")
        }
    }
}
