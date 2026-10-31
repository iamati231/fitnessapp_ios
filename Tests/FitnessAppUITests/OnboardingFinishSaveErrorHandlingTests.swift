import XCTest

/// Audit-Fund (fokussierter Onboarding-Audit, Fund 1): `finishOnboarding()`
/// speicherte Profil + initiale Messung bisher NUR innerhalb der beiden
/// optionalen Plan-Zweige - ohne explizite Plan-Auswahl, ohne Custom-Plan
/// UND einer leeren Empfehlungsliste lief die Funktion durch, ohne je zu
/// speichern. Quelltext-Pruefung, weil `save()` keinen Test-Seam fuer einen
/// echten Fehlschlag hat.
final class OnboardingFinishSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/OnboardingView.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// The profile/measurement save must happen unconditionally, right
    /// after the measurement insert, independent of which (if any) plan
    /// branch runs afterward.
    func testProfileAndMeasurementSaveUnconditionallyBeforeThePlanBranches() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let insertRange = cleaned.range(of: "modelContext.insert(measurement)") else {
            return XCTFail("modelContext.insert(measurement) not found")
        }
        guard let planBranchRange = cleaned.range(of: "Self.templateToAdopt(", range: insertRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("the plan-adopt branch not found after the measurement insert")
        }
        let between = cleaned[insertRange.upperBound..<planBranchRange.lowerBound]

        guard let tryRange = between.range(of: "try modelContext.save()") else {
            return XCTFail("a save must happen between the measurement insert and the plan branches, unconditionally")
        }
        guard let catchRange = between.range(of: "} catch {", range: tryRange.upperBound..<between.endIndex) else {
            return XCTFail("catch block not found")
        }
        XCTAssertTrue(catchRange.lowerBound > tryRange.upperBound)
    }

    /// Both optional plan branches must be gated on the save having
    /// actually succeeded — creating a plan against a profile that never
    /// persisted would be pointless.
    func testBothPlanBranchesAreGatedOnProfileDidSave() throws {
        let cleaned = Self.stripLineComments(try source)
        XCTAssertTrue(
            cleaned.contains("if profileDidSave, let template = Self.templateToAdopt("),
            "the template-adopt branch must require a successful profile save first"
        )
        XCTAssertTrue(
            cleaned.contains("} else if profileDidSave, let customPlanInput, let customPlanResult {"),
            "the custom-plan branch must require a successful profile save first"
        )
    }
}
