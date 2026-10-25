import XCTest
@testable import FitnessAppCore

/// Task 1 (equipment vielfalt): bounded three-state slot resolver. Only the
/// curated default and the pre-authorized `reviewedAlternatives` are ever
/// considered; `.unknown` is never a win.
final class TemplateSlotResolverTests: XCTestCase {

    private func slot(_ defaultName: String, alternatives: [String] = []) -> TemplateSlot {
        TemplateSlot(defaultExerciseName: defaultName, reviewedAlternatives: alternatives,
                     sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90)
    }

    /// Barbell, flat bench, two dumbbells, machine and cable station, all confirmed.
    private var fullProfile: UserEquipmentProfile {
        UserEquipmentProfile(
            availability: [.barbell: .available, .flatBench: .available, .dumbbell: .available,
                           .machineStation: .available, .cableStation: .available],
            counts: [.dumbbell: 2]
        )
    }

    func testResolveKeepsDefaultExerciseWhenEquipmentAvailable() {
        // Alternative would also work, but quality-first: default is tried first and wins.
        let result = TemplateSlotResolver.resolve(
            slot: slot("Bankdrücken", alternatives: ["Bankdrücken (KH)"]), against: fullProfile)
        guard case let .default(spec) = result else {
            return XCTFail("Default ist erfuellt, muss .default liefern, ist: \(result)")
        }
        XCTAssertEqual(spec.name, "Bankdrücken")
        XCTAssertEqual(spec.sets, 3)
        XCTAssertEqual(spec.repsMin, 8)
        XCTAssertEqual(spec.repsMax, 12)
        XCTAssertEqual(spec.restSeconds, 90)
    }

    func testResolveUsesFirstSatisfiedAlternativeWhenDefaultEquipmentMissing() {
        var profile = fullProfile
        profile.availability[.barbell] = .unavailable
        // Both alternatives are satisfied; the first in priority order must win.
        let result = TemplateSlotResolver.resolve(
            slot: slot("Bankdrücken", alternatives: ["Bankdrücken (KH)", "Brustdrücken (Maschine)"]),
            against: profile)
        guard case let .alternative(spec, usedName) = result else {
            return XCTFail("Default unerfuellt, erste erfuellte Alternative erwartet, ist: \(result)")
        }
        XCTAssertEqual(usedName, "Bankdrücken (KH)")
        XCTAssertEqual(spec.name, "Bankdrücken (KH)")
    }

    func testResolveIsDeterministicAcrossRepeatedCalls() {
        var profile = fullProfile
        profile.availability[.barbell] = .unavailable
        let s = slot("Bankdrücken", alternatives: ["Bankdrücken (KH)", "Brustdrücken (Maschine)"])
        let first = TemplateSlotResolver.resolve(slot: s, against: profile)
        for _ in 0..<5 {
            XCTAssertEqual(TemplateSlotResolver.resolve(slot: s, against: profile), first)
        }
    }

    func testResolveReturnsUnresolvedNeverSilentFallbackWhenNothingSatisfiable() {
        var profile = UserEquipmentProfile()
        profile.availability[.barbell] = .unavailable
        profile.availability[.dumbbell] = .unavailable
        let result = TemplateSlotResolver.resolve(
            slot: slot("Bankdrücken", alternatives: ["Bankdrücken (KH)"]), against: profile)
        guard case .unresolved(.missing(_)) = result else {
            return XCTFail("Nichts erfuellbar muss .unresolved(.missing) liefern, ist: \(result)")
        }
    }

    func testResolveTreatsUnknownAsNotSatisfiedNeverAsAWin() {
        // gymDefault leaves kettlebell .unknown: both candidates are .unknown, not .satisfied.
        let result = TemplateSlotResolver.resolve(
            slot: slot("Kettlebell Swing", alternatives: ["Turkish Get-Up"]),
            against: UserEquipmentProfile.gymDefault)
        guard case .unresolved(.uncertain(_)) = result else {
            return XCTFail(".unknown darf nie gewinnen, muss .unresolved(.uncertain) liefern, ist: \(result)")
        }
    }

    func testResolveNeverConsidersExerciseOutsideDefaultAndReviewedAlternatives() {
        // "Brustdrücken (Maschine)" is satisfied by this profile but NOT listed in the slot.
        var profile = UserEquipmentProfile()
        profile.availability[.barbell] = .unavailable
        profile.availability[.dumbbell] = .unavailable
        profile.availability[.flatBench] = .available
        profile.availability[.machineStation] = .available
        let result = TemplateSlotResolver.resolve(
            slot: slot("Bankdrücken", alternatives: ["Bankdrücken (KH)"]), against: profile)
        guard case .unresolved = result else {
            return XCTFail("Nur Default und reviewedAlternatives duerfen gewinnen, ist: \(result)")
        }
    }
}
