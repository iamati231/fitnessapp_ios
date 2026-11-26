import XCTest

/// Audit-Fund (Modul 21, PlanBuilderView): `isPreSeededFlow` war eine
/// computed property auf `selectedKinds`, kippte also live auf `false`,
/// sobald der Nutzer im Handoff-Pfad alle vorbefuellten Karten einzeln
/// entfernte — die dazugehoerigen Kommentare verlangen aber ein einmaliges,
/// bei Sheet-Oeffnung gepinntes Signal (analog `hasExplicitEquipmentPreferences`).
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class PlanBuilderPreSeededFlowPinnedTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanBuilderView.swift"),
                encoding: .utf8
            )
        }
    }

    func testIsPreSeededFlowIsAStoredPropertyNotALiveComputation() throws {
        let text = try source
        XCTAssertFalse(text.contains("private var isPreSeededFlow: Bool { !selectedKinds.isEmpty }"),
                       "isPreSeededFlow must no longer recompute live from the mutable selectedKinds array")
        XCTAssertTrue(text.contains("private let isPreSeededFlow: Bool"),
                      "isPreSeededFlow must be a stored property, pinned once like hasExplicitEquipmentPreferences")
    }

    func testInitPinsIsPreSeededFlowFromInitialInputSelections() throws {
        let text = try source
        guard let start = text.range(of: "public init(") else {
            return XCTFail("init(initialInput:...) not found")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of init not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("self.isPreSeededFlow = initialInput.map { !$0.selections.isEmpty } ?? false"),
                      "isPreSeededFlow must be derived once from initialInput.selections in init, not from selectedKinds")
    }
}
