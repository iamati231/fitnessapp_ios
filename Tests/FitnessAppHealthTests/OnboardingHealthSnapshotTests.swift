import XCTest
@testable import FitnessAppHealth

/// Settings-Epic Phase 4 (Befund PE-H1): `hasApplicableProfileFields` steuert in
/// `ProfileEditorView.requestHealthPull()`, ob der Bestaetigungsdialog oder der
/// "nichts gefunden"-Hinweis gezeigt wird — und ist der einzige Teil dieses
/// Flows, der ohne SwiftData/SwiftUI (also auf Linux) ueberhaupt pruefbar ist.
/// Die eigentliche Profil-Mutation (`applyHealthPull`) haengt am SwiftData-Modell
/// `UserBodyProfile` und bleibt Apple-seitig zu verifizieren.
final class OnboardingHealthSnapshotTests: XCTestCase {

    private func snapshot(
        dateOfBirth: Date? = nil,
        sex: BiologicalSex = .notSet,
        heightCm: Double? = nil,
        weightKg: Double? = nil
    ) -> OnboardingHealthSnapshot {
        OnboardingHealthSnapshot(dateOfBirth: dateOfBirth, sex: sex, heightCm: heightCm, weightKg: weightKg)
    }

    func testEmptySnapshotHasNoApplicableFields() {
        XCTAssertFalse(OnboardingHealthSnapshot.empty.hasApplicableProfileFields)
    }

    func testBirthdateAloneIsApplicable() {
        XCTAssertTrue(snapshot(dateOfBirth: Date()).hasApplicableProfileFields)
    }

    func testMaleSexAloneIsApplicable() {
        XCTAssertTrue(snapshot(sex: .male).hasApplicableProfileFields)
    }

    func testFemaleSexAloneIsApplicable() {
        XCTAssertTrue(snapshot(sex: .female).hasApplicableProfileFields)
    }

    /// `.other`/`.notSet` sind aus Health-Sicht "kein Wert" — duerfen nicht so
    /// behandelt werden, als haette Health etwas geliefert.
    func testOtherAndNotSetSexAreNotApplicableOnTheirOwn() {
        XCTAssertFalse(snapshot(sex: .other).hasApplicableProfileFields)
        XCTAssertFalse(snapshot(sex: .notSet).hasApplicableProfileFields)
    }

    func testPositiveHeightAloneIsApplicable() {
        XCTAssertTrue(snapshot(heightCm: 180).hasApplicableProfileFields)
    }

    /// Ein `0`- oder negativer Groessenwert ist kein plausibler Health-Wert.
    func testZeroOrNegativeHeightIsNotApplicable() {
        XCTAssertFalse(snapshot(heightCm: 0).hasApplicableProfileFields)
        XCTAssertFalse(snapshot(heightCm: -1).hasApplicableProfileFields)
    }

    /// Gewicht zaehlt bewusst NIE mit — es lebt ausschliesslich in
    /// `BodyMeasurement`, nie im Profil (siehe `applyHealthPull`).
    func testWeightAloneIsNeverApplicable() {
        XCTAssertFalse(snapshot(weightKg: 70).hasApplicableProfileFields)
    }

    func testAllFieldsPresentIsApplicable() {
        XCTAssertTrue(
            snapshot(dateOfBirth: Date(), sex: .female, heightCm: 165, weightKg: 60).hasApplicableProfileFields
        )
    }
}
