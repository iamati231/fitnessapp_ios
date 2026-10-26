import XCTest

/// Audit-Fund (Follow-up-UI-Audit, "Picking or getting a template-based
/// training plan never saves it"): `ProgramInstantiator.instantiate(...)`
/// inserted Plan+Tage+Uebungen, aber weder die Funktion noch ihre beiden
/// Aufrufer (`ProgramTemplatePickerView.instantiate`, `OnboardingView`s
/// Template-Zweig) riefen `modelContext.save()` - beide hingen komplett am
/// impliziten SwiftData-Autosave. Quelltext-Pruefung (gleiches Muster wie
/// `BodyDataEditorRollbackTests`), weil `save()` keinen Test-Seam fuer einen
/// echten Fehlschlag hat.
final class PlanAdoptionSaveErrorHandlingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources")
    }

    private func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// `ProgramTemplatePickerView.instantiate(_:selection:)`: ein
    /// fehlgeschlagener Save darf weder `dismiss()` noch den
    /// `navigation.workoutPath.append(plan)` ausloesen - sonst navigiert die
    /// UI in einen Plan, der nie gespeichert wurde.
    func testTemplatePickerInstantiateReturnsBeforeDismissOnSaveFailure() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("FitnessAppUI/Workout/ProgramTemplatePickerView.swift"),
            encoding: .utf8
        )
        let cleaned = stripLineComments(text)

        guard let funcStart = cleaned.range(of: "private func instantiate(_ template: ProgramTemplate, selection: ResolvedPlanSelection) {") else {
            return XCTFail("instantiate(_:selection:) not found at the expected signature")
        }
        guard let tryRange = cleaned.range(of: "try modelContext.save()", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("must use do/catch around modelContext.save() instead of relying on implicit autosave")
        }
        guard let catchRange = cleaned.range(of: "} catch {", range: tryRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = cleaned.range(of: "\n        }", range: catchRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = cleaned[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(plan)"),
                      "a failed save must delete the just-inserted plan (cascade removes its days/exercises)")
        XCTAssertTrue(catchBody.contains("return"),
                      "the catch block must return before dismiss()/navigation")

        guard let dismissCall = cleaned.range(of: "dismiss()", range: catchEnd.upperBound..<cleaned.endIndex) else {
            return XCTFail("dismiss() must still be called on the success path")
        }
        XCTAssertTrue(dismissCall.lowerBound > catchEnd.upperBound,
                      "dismiss() must only happen AFTER the catch block, i.e. only on a successful save")
    }

    /// `OnboardingView`s Template-Zweig: analoges Muster zum bereits
    /// bestehenden `customPlanInput`-Zweig direkt darunter - kein Alert
    /// (Profil-Insert kann RootView schon umgeschaltet haben), aber auch
    /// kein stilles Verschwinden: `OnboardingPlanCreationNotice.markFailed()`.
    func testOnboardingTemplateBranchMarksFailureOnSaveFailure() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("FitnessAppUI/OnboardingView.swift"),
            encoding: .utf8
        )
        let cleaned = stripLineComments(text)

        guard let instantiateCall = cleaned.range(of: "let plan = ProgramInstantiator.instantiate(") else {
            return XCTFail("ProgramInstantiator.instantiate(...) call (captured) not found in OnboardingView")
        }
        guard let tryRange = cleaned.range(of: "try modelContext.save()", range: instantiateCall.upperBound..<cleaned.endIndex) else {
            return XCTFail("must use do/catch around modelContext.save() instead of relying on implicit autosave")
        }
        guard let catchRange = cleaned.range(of: "} catch {", range: tryRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = cleaned.range(of: "\n            }", range: catchRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = cleaned[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(plan)"),
                      "a failed save must delete the just-inserted plan (cascade removes its days/exercises)")
        XCTAssertTrue(catchBody.contains("OnboardingPlanCreationNotice.markFailed()"),
                      "failure must surface via the same notice as the sibling customPlanInput branch")
    }
}
