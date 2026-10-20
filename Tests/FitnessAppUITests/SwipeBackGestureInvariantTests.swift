import XCTest

/// Deltiq-Geraeteabnahme (E05): `.navigationBarBackButtonHidden(true)` nimmt auf
/// iOS als Nebenwirkung die native Swipe-Back-Geste mit runter (siehe
/// `deltiqSwipeBackEnabled()`-Dokumentation in `Theme.swift`). Jede Stelle, die
/// den Back-Button so ausblendet, muss die Geste ueber `.deltiqSwipeBackEnabled(...)`
/// im selben File explizit wiederherstellen - sonst bleibt sie auf dieser
/// Verschachtelungsebene dauerhaft tot. `ExerciseEditorView` hatte genau diesen
/// Aufruf vergessen (gefunden beim Geraete-Nachtest E05: Zurueckwischen
/// funktionierte in Plan-Editor und Tag-Editor, aber nicht mehr in der dritten,
/// tiefsten Ebene, dem Uebungs-Editor).
///
/// Bewusst NUR auf die drei Editoren der in E05 geprueften Verschachtelungskette
/// (Plan-Editor -> Tag-Editor -> Uebungs-Editor) beschraenkt, nicht auf jede
/// Stelle im Projekt, die `.navigationBarBackButtonHidden(true)` setzt -
/// mehrere andere Screens (z.B. aktive Workout-Player, Listen-Wurzeln) blenden
/// den Back-Button absichtlich fuer eigene Navigationsformen aus, bei denen die
/// native Swipe-Geste gar nicht gilt; die hier zu pruefende Kette ist exakt die
/// in Dokument 04 (E05) genannte. Liest die Produktionsquellen direkt von der
/// Platte, braucht also kein SwiftUI/SwiftData und laeuft auch auf Linux.
final class SwipeBackGestureInvariantTests: XCTestCase {
    private var workoutSourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SwipeBackGestureInvariantTests.swift
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Workout")
    }

    /// Die E05-Verschachtelungskette aus Dokument 04: Plan-Editor -> Tag-Editor
    /// -> Uebungs-Editor.
    private static let nestedEditorFileNames = [
        "PlanEditorView.swift",
        "DayEditorView.swift",
        "ExerciseEditorView.swift",
    ]

    func testEachNestedEditorInTheE05ChainRestoresSwipeBack() throws {
        var violations: [String] = []
        for fileName in Self.nestedEditorFileNames {
            let fileURL = workoutSourcesDirectory.appendingPathComponent(fileName)
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertTrue(
                contents.contains(".navigationBarBackButtonHidden(true)"),
                "\(fileName) sollte weiterhin .navigationBarBackButtonHidden(true) setzen "
                    + "(sonst ist diese Annahme des Tests ueberholt)."
            )
            if !contents.contains(".deltiqSwipeBackEnabled(") {
                violations.append(fileName)
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Diese Editoren der E05-Verschachtelungskette blenden den Back-Button aus, "
                + "stellen die Swipe-Back-Geste aber nie mit .deltiqSwipeBackEnabled(...) wieder her: "
                + violations.joined(separator: ", ")
        )
    }
}
