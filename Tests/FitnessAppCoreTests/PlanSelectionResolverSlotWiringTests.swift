import XCTest
@testable import FitnessAppCore

/// Equipment-Vielfalt Phase 1 Task 4, Step 1b: end-to-end proof that a
/// `slots`-bearing template (Task 3) now resolves via `TemplateSlotResolver`
/// (Task 1) through `PlanSelectionResolver.resolve` — covering all three
/// `equipmentStatus` outcomes the brief's Interfaces section specifies.
/// Profiles mirror `HybridTemplateSlotParityTests` exactly (same golden
/// fixtures, already proven to reproduce the old `equipmentVariants` content
/// name-for-name).
final class PlanSelectionResolverSlotWiringTests: XCTestCase {

    private var hypertrophyContext: SubstitutionContext { SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced) }

    private func template(_ id: String) -> ProgramTemplate {
        ProgramTemplates.all.first { $0.id == id }!
    }

    /// Full barbell gym — every default exercise resolves via `.default`,
    /// zero alternatives used (same fixture as `HybridTemplateSlotParityTests.baseProfile`).
    private var baseProfile: UserEquipmentProfile {
        UserEquipmentProfile(
            availability: [
                .barbell: .available, .rack: .available,
                .flatBench: .available, .adjustableBench: .available,
                .dumbbell: .available, .kettlebell: .unavailable,
                .pullUpBar: .available, .cableStation: .available, .machineStation: .available
            ],
            counts: [.dumbbell: 2]
        )
    }

    /// Minimalist kettlebell-only setup (same fixture as
    /// `HybridTemplateSlotParityTests.kettlebellOnlyProfile`) — every default
    /// exercise fails, every slot resolves via its kettlebell alternative.
    private var kettlebellOnlyProfile: UserEquipmentProfile {
        UserEquipmentProfile(
            availability: [
                .kettlebell: .available,
                .dumbbell: .unavailable, .barbell: .unavailable, .rack: .unavailable,
                .flatBench: .unavailable, .adjustableBench: .unavailable,
                .pullUpBar: .unavailable, .cableStation: .unavailable, .machineStation: .unavailable
            ]
        )
    }

    /// Nothing at all confirmed available — no default AND no alternative
    /// can ever resolve.
    private var nothingAvailableProfile: UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        return profile
    }

    // MARK: - Outcome 1: .available, no alternatives used

    func testFullBarbellProfileResolvesAvailableWithoutAnyAppliedAdaptation() {
        let selection = PlanSelectionResolver.resolve(template: template("hybrid_beginner"), profile: baseProfile, context: hypertrophyContext)
        XCTAssertEqual(selection.equipmentStatus, .available)
        XCTAssertNil(selection.appliedAdaptation, "Kein Slot musste auf eine Alternative ausweichen")
        XCTAssertFalse(selection.isAdapted)
        XCTAssertEqual(selection.days.first?.exercises.first?.name, "Kniebeuge")
    }

    // MARK: - Outcome 2: .available via appliedAdaptation (alternatives used)

    func testKettlebellOnlyProfileResolvesAvailableViaAppliedAdaptation() {
        let selection = PlanSelectionResolver.resolve(template: template("hybrid_beginner"), profile: kettlebellOnlyProfile, context: hypertrophyContext)
        XCTAssertEqual(selection.equipmentStatus, .available, "Parity-Beweis (HybridTemplateSlotParityTests): 0 gaps fuer kettlebellOnly")
        XCTAssertTrue(selection.isAdapted)
        guard let adaptation = selection.appliedAdaptation else {
            return XCTFail("Alternativen wurden verwendet -> appliedAdaptation darf nicht nil sein")
        }
        XCTAssertFalse(adaptation.replacements.isEmpty)
        XCTAssertTrue(adaptation.replacements.allSatisfy { $0.reasonKey == "picker.plan.equipment.slotAlternative" })
        XCTAssertEqual(adaptation.replacements.first?.ruleID, "slot:Kniebeuge->Kettlebell Goblet Squat")
        XCTAssertEqual(selection.days.first?.exercises.first?.name, "Kettlebell Goblet Squat")
    }

    /// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo,
    /// gleiches Muster wie `SetRowTargetPaceTests`): bestaetigt, dass
    /// `ProgramTemplatePickerView.adaptedEquipmentBanner` exakt das rendert,
    /// was ein slot-basiertes `appliedAdaptation` liefert — `replacements`
    /// mit `originalName`/`replacementName`/`reasonKey`, keine neue Banner-Art.
    func testAdaptedEquipmentBannerSourceRendersSlotBasedReplacementsUnchanged() throws {
        let sourcesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppCoreTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Workout/ProgramTemplatePickerView.swift")
        let source = try String(contentsOf: sourcesRoot, encoding: .utf8)
        XCTAssertTrue(source.contains("if let adaptation = selection.appliedAdaptation"),
                       "Die Banner-Weiche muss weiterhin ausschliesslich auf `appliedAdaptation` reagieren — keine neue, slot-spezifische Bedingung")
        XCTAssertTrue(source.contains("adaptation.replacements"), "Die Vorher/Nachher-Liste muss weiterhin direkt `replacements` lesen")
        XCTAssertTrue(source.contains("replacement.originalName") && source.contains("replacement.replacementName") && source.contains("replacement.reasonKey"),
                       "Keine neue Banner-Implementierung fuer den Slot-Pfad noetig")
    }

    // MARK: - Outcome 3: .unavailable(gaps:)

    func testNothingAvailableProfileResolvesUnavailableWithGaps() {
        let selection = PlanSelectionResolver.resolve(template: template("hybrid_beginner"), profile: nothingAvailableProfile, context: hypertrophyContext)
        guard case let .unavailable(gaps) = selection.equipmentStatus else {
            return XCTFail("Weder Default noch irgendeine Alternative kann hier aufloesen, muss .unavailable sein, ist: \(selection.equipmentStatus)")
        }
        XCTAssertFalse(gaps.isEmpty)
        XCTAssertTrue(gaps.contains { $0.exerciseName == "Kniebeuge" })
        // Transparenz-Vorgabe (Task 3): ein `.unresolved`-Slot behaelt seine
        // unveraenderte `defaultExerciseName`, wird nie stillschweigend ersetzt.
        XCTAssertEqual(selection.days.first?.exercises.first?.name, "Kniebeuge")
    }

    // MARK: - 17 untouched templates: unveraendertes Verhalten

    /// `resolvedSlots(against:)` liefert `nil` fuer jedes Template ohne
    /// `slots` (Task 3, `HybridTemplateSlotParityTests.
    /// testNonHybridTemplateHasNoSlotsAndResolvedSlotsIsNil`) — der neue Zweig
    /// oben wird fuer sie nie betreten, `PlanSelectionResolver.resolve` faellt
    /// fuer alle 17 uebrigen Templates unveraendert auf die bestehende
    /// `bestEquipmentCheckedVariant`/`ExerciseSubstitutionEngine`-Logik durch.
    /// Bestehende Suiten dafuer: `PlanSelectionResolverTests`
    /// (`testResolverPrefersTheSourceVariantNeedingFewerSubstitutions`,
    /// `testResolverFallsBackTransparentlyWhenNoVariantFullyResolves`),
    /// `PlanMatchmakerTests`, `PlanEquipmentCheckTests` — keiner davon nutzt
    /// ein Template mit `slots`, bleiben also unveraendert.
    func testEveryNonHybridTemplateStillBypassesTheNewSlotsBranch() {
        for template in ProgramTemplates.all where !["hybrid_beginner", "hybrid_balanced", "hybrid_performance"].contains(template.id) {
            XCTAssertNil(template.resolvedSlots(against: baseProfile), "\(template.id): darf keine `slots` haben")
        }
    }
}
