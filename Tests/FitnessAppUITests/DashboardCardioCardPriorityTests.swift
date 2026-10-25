#if canImport(SwiftUI)
import XCTest

/// Task 8 (Laufcoaching-Plan-Integration): das Dashboard's fixe Cardio-
/// Karten-Slot kannte bisher nur `CardioFeasibilityCardModel` ("kein aktiver
/// Plan, hier ein Vorschlag") - `CoachAdjustmentCardModel` ("aktiver Plan,
/// Anpassung ausstehend") war dort nie verdrahtet. Source-introspection
/// (kein SwiftUI-Render-Harness in diesem Repo), gleiches Muster wie
/// `MehrInformationArchitectureTests`.
final class DashboardCardioCardPriorityTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Leitplanke 6 (`CoachAdjustmentCardModel.swift`): die beiden Karten
    /// duerfen fuer denselben Zustand nie gleichzeitig angeboten werden - der
    /// aktiver-Plan-Fall (`CoachAdjustmentCardModel`) muss im fixen Slot VOR
    /// dem Fallback (`cardioFeasibilityModel`) geprueft werden.
    func testDashboardChecksCoachAdjustmentBeforeCardioFeasibilityInTheFixedCardSlot() throws {
        let source = try contents(of: "DashboardView.swift")
        let coachAdjustmentIndex = source.range(of: "CoachAdjustmentCardModel.make(for:")?.lowerBound
        let feasibilityIndex = source.range(of: "if let model = cardioFeasibilityModel")?.lowerBound
        XCTAssertNotNil(coachAdjustmentIndex, "the fixed card slot must also check CoachAdjustmentCardModel")
        if let coachAdjustmentIndex, let feasibilityIndex {
            XCTAssertLessThan(coachAdjustmentIndex, feasibilityIndex, "CoachAdjustmentCardModel (active-plan case) must take priority, per the existing Leitplanke 6 precedence")
        }
    }

    /// Die beiden Zweige muessen ein einzelnes `if/else if` sein, nicht zwei
    /// unabhaengige `if`s - sonst koennten beide Karten gleichzeitig rendern.
    func testTheTwoCardsAreMutuallyExclusiveViaElseIf() throws {
        let source = try contents(of: "DashboardView.swift")
        guard let adjustmentRange = source.range(of: "let adjustment = CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan)") else {
            XCTFail("CoachAdjustmentCardModel-Aufruf nicht gefunden")
            return
        }
        let tail = source[adjustmentRange.upperBound...]
        guard let elseIfRange = tail.range(of: "} else if let model = cardioFeasibilityModel {") else {
            XCTFail("muss als `} else if let model = cardioFeasibilityModel {` direkt an den Adjustment-Zweig anschliessen")
            return
        }
        // Zwischen beiden darf nur der eine Karten-Aufruf stehen, kein
        // zweites eigenstaendiges `if`.
        let between = tail[tail.startIndex..<elseIfRange.lowerBound]
        XCTAssertFalse(between.contains("\n                    if "), "die beiden Zweige muessen ein einzelnes if/else if sein, nicht zwei unabhaengige ifs")
    }

    /// Die neue Karte muss dasselbe, bestehende Sheet oeffnen wie die
    /// Laufversaeumnis-Karte - kein zweiter Anpassungs-Mechanismus.
    func testNewCardReusesTheExistingMissedRunAdjustmentPreviewState() throws {
        let source = try contents(of: "DashboardView.swift")
        XCTAssertTrue(
            source.contains("private func laufcoachingAdjustmentCard(_ adjustment: CoachAdjustmentCardModel, plan: TrainingPlan) -> some View"),
            "laufcoachingAdjustmentCard(_:plan:) fehlt oder hat eine andere Signatur"
        )
        guard let methodRange = source.range(of: "private func laufcoachingAdjustmentCard(_ adjustment: CoachAdjustmentCardModel, plan: TrainingPlan) -> some View") else {
            XCTFail("laufcoachingAdjustmentCard nicht gefunden")
            return
        }
        let methodBody = source[methodRange.upperBound...].prefix(2000)
        XCTAssertTrue(
            methodBody.contains("showingMissedRunAdjustmentPreview = true"),
            "die CTA der neuen Karte muss das bestehende showingMissedRunAdjustmentPreview setzen, kein neues @State"
        )
        XCTAssertFalse(
            source.contains("@State private var showingCoachAdjustmentPreview"),
            "es darf kein zweiter, neuer @State fuer dasselbe Sheet entstehen"
        )
    }
}
#endif
