import XCTest

/// Audit-Fund (Modul Programs-Core): `majorMuscleGroups` war `Set<MuscleGroup>`,
/// dessen Iterationsreihenfolge wegen Swifts pro-Prozess-randomisiertem Hasher
/// nicht ueber zwei Prozesslaeufe hinweg garantiert gleich ist - widerspricht
/// dem dokumentierten deterministischen `shuffle: false`-Vertrag von
/// `generate(from:)`, auf den sich u.a. `PlanGeneratorInstantiator.recalculate`
/// verlaesst. `majorMuscleGroups` ist `private`, daher per Source-Inspection
/// statt direktem Zugriff geprueft (etabliertes Muster fuer private
/// Implementierungsdetails in dieser Codebase - die Nichtdeterminismus-Luecke
/// selbst ist in einem einzelnen Testprozess nicht beobachtbar, da der
/// Hash-Seed pro Prozess fix bleibt).
final class PlanGeneratorMuscleCoverageOrderTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqCore/Programs/PlanGenerator.swift"),
                encoding: .utf8
            )
        }
    }

    func testMajorMuscleGroupsIsAnOrderedArrayNotASet() throws {
        let code = try source
        XCTAssertTrue(
            code.contains("private static let majorMuscleGroups: [MuscleGroup] ="),
            "majorMuscleGroups must be a deterministically-ordered Array, not a Set - Set iteration order is not stable across process launches (randomized Hasher seed), which breaks generate(from:shuffle:false)'s documented deterministic-output contract"
        )
        XCTAssertFalse(
            code.contains("private static let majorMuscleGroups: Set<MuscleGroup> ="),
            "majorMuscleGroups must not regress back to Set<MuscleGroup>"
        )
    }
}
