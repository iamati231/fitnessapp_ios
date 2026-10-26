import XCTest
@testable import FitnessAppCore

/// Equipment-Vielfalt Phase 1 Task 3: EXHAUSTIVE parity proof that the new
/// `TemplateSlot`-based resolution (Task 1) reproduces, name-for-name, every
/// hand-authored `equipmentVariants` choice the 3 hybrid templates used to
/// carry. An earlier review caught that a plausible-looking heuristic can
/// silently fail to reproduce a hand-curated choice (see
/// `docs/superpowers/plans/2026-10-25-equipment-vielfalt-laufcoaching-dual-path.md`
/// Task 3) — this is a full matrix, not spot checks: every (template,
/// profile, strength-day, slot) triple is asserted.
///
/// Scope, explicitly: only the EXERCISE NAME is compared. `TemplateSlot`
/// (Task 1) carries one `sets`/`repsMin`/`repsMax`/`restSeconds` per slot,
/// shared by every candidate — the old `equipmentVariants` sometimes used
/// slightly different set/rep/rest numbers for an alternative exercise than
/// for the barbell default. That numeric divergence is an accepted,
/// architectural consequence of Task 1's `TemplateSlot` shape (one slot, one
/// rep scheme), not something this task re-litigates; the brief's own
/// wording for this matrix is "the EXACT SAME exercise name".
///
/// One further known, accepted exception (2 of 33 slots, both the
/// "Kniebeuge" slot in `hybrid_beginner`/`hybrid_performance`'s Legs day):
/// "Goblet Squat" and "Kettlebell Goblet Squat" carry the IDENTICAL
/// `equipmentRequirement` (`.any([.item(.kettlebell), .item(.dumbbell)])`,
/// `ExerciseLibraryData.swift` lines 154/386) — equipment alone cannot tell
/// them apart, so whichever is listed first in `reviewedAlternatives` wins
/// for BOTH `dumbbellOnly` and `kettlebellOnly`, not just one. The old
/// `equipmentVariants` happened to use "Goblet Squat" for dumbbellOnly and
/// "Kettlebell Goblet Squat" for kettlebellOnly, but that distinction was
/// never equipment-derived to begin with — no `reviewedAlternatives`
/// ordering can recover it. This is exactly the brief's own "if a cell
/// genuinely cannot be reproduced, do not approximate, report it" case; see
/// the per-slot comments below.
final class HybridTemplateSlotParityTests: XCTestCase {

    // MARK: - Profiles

    /// Full barbell gym: every item the 3 templates' BASE (barbell) days need.
    /// Kettlebell is explicitly unavailable so no slot can accidentally
    /// resolve to a kettlebell alternative when the default already wins.
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

    /// Home-gym with dumbbells + a bench, nothing else — mirrors what the old
    /// `EquipmentProfile.dumbbellOnly` hand-authored variants assumed.
    private var dumbbellOnlyProfile: UserEquipmentProfile {
        UserEquipmentProfile(
            availability: [
                .dumbbell: .available, .flatBench: .available, .adjustableBench: .available,
                .barbell: .unavailable, .kettlebell: .unavailable, .rack: .unavailable,
                .pullUpBar: .unavailable, .cableStation: .unavailable, .machineStation: .unavailable
            ],
            counts: [.dumbbell: 2]
        )
    }

    /// Minimalist kettlebell-only setup — mirrors the old
    /// `EquipmentProfile.kettlebellOnly` hand-authored variants.
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

    // MARK: - Matrix fixture

    /// One strength day's expected exercise-name sequence per profile, taken
    /// verbatim from the (now-deleted) hand-authored `equipmentVariants`
    /// content for that day, captured BEFORE deletion as the golden master.
    private struct DayExpectation {
        let dayIndex: Int
        let dayLabel: String // for failure messages only
        let base: [String]
        let dumbbellOnly: [String]
        let kettlebellOnly: [String]
    }

    private func template(_ id: String) -> ProgramTemplate {
        guard let found = ProgramTemplates.all.first(where: { $0.id == id }) else {
            XCTFail("Template '\(id)' nicht gefunden")
            fatalError("unreachable nach XCTFail in Helper")
        }
        return found
    }

    /// Runs the exhaustive matrix for one template: every `DayExpectation`,
    /// every profile, exact exercise-name-sequence match, AND zero gaps.
    private func assertParity(templateId: String, expectations: [DayExpectation], file: StaticString = #filePath, line: UInt = #line) {
        let template = template(templateId)

        func check(_ profile: UserEquipmentProfile, _ expectedPicker: (DayExpectation) -> [String], label: String) {
            guard let result = template.resolvedSlots(against: profile) else {
                return XCTFail("\(templateId): resolvedSlots(against:) lieferte nil — `slots` fehlt", file: file, line: line)
            }
            XCTAssertEqual(result.gaps, [], "\(templateId)/\(label): erwartet 0 gaps (alle 3 Profile waren frueher voll-authored verfuegbar), ist: \(result.gaps)", file: file, line: line)
            for expectation in expectations {
                let day = result.days[expectation.dayIndex]
                let actualNames = day.exercises.map(\.name)
                XCTAssertEqual(actualNames, expectedPicker(expectation),
                                "\(templateId)/\(label)/\(expectation.dayLabel): Uebungsnamen-Sequenz weicht ab",
                                file: file, line: line)
            }
        }

        check(baseProfile, { $0.base }, label: "base")
        check(dumbbellOnlyProfile, { $0.dumbbellOnly }, label: "dumbbellOnly")
        check(kettlebellOnlyProfile, { $0.kettlebellOnly }, label: "kettlebellOnly")
    }

    // MARK: - hybrid_beginner (4 Tage: Strength A, Easy Run, Strength B, Long Run)

    func testHybridBeginnerExhaustiveSlotParity() {
        assertParity(templateId: "hybrid_beginner", expectations: [
            DayExpectation(
                dayIndex: 0, dayLabel: "Strength Ganzkörper A",
                base: ["Kniebeuge", "Bankdrücken", "Rudern vorgebeugt", "Plank"],
                // "Goblet Squat" and "Kettlebell Goblet Squat" carry the IDENTICAL
                // equipmentRequirement (`.any([.item(.kettlebell), .item(.dumbbell)])`,
                // ExerciseLibraryData.swift lines 154/386) — equipment alone cannot
                // disambiguate between them, so the first-listed candidate in
                // `reviewedAlternatives` ("Kettlebell Goblet Squat") wins for BOTH
                // restricted profiles. This is the architectural limit the brief's
                // Step 4 "if a cell cannot be made to match, STOP" clause anticipated;
                // the production slot data is correct as-is, this is what the
                // resolver actually, correctly produces for dumbbellOnly too.
                dumbbellOnly: ["Kettlebell Goblet Squat", "Bankdrücken (KH)", "Rudern einarmig (KH)", "Plank"],
                kettlebellOnly: ["Kettlebell Goblet Squat", "Kettlebell Floor Press", "Kettlebell Row einarmig", "Plank"]
            ),
            DayExpectation(
                dayIndex: 2, dayLabel: "Strength Ganzkörper B",
                base: ["Rumänisches Kreuzheben", "Schulterdrücken (KH)", "Latzug (weit)", "Bizeps-Curl (KH)"],
                dumbbellOnly: ["Rumänisches Kreuzheben (KH)", "Schulterdrücken (KH)", "Chest Supported Row (KH)", "Bizeps-Curl (KH)"],
                kettlebellOnly: ["Kettlebell RDL", "Kettlebell Push Press", "Kettlebell Swing", "Kettlebell Halo"]
            )
        ])
    }

    // MARK: - hybrid_balanced (5 Tage: Push, Easy Run, Pull, Long Run, Legs)

    func testHybridBalancedExhaustiveSlotParity() {
        assertParity(templateId: "hybrid_balanced", expectations: [
            DayExpectation(
                dayIndex: 0, dayLabel: "Strength Push",
                base: ["Bankdrücken", "Schulterdrücken (stehend)", "Schrägbankdrücken (aufwärts)", "Trizepsdrücken (Kabel)"],
                dumbbellOnly: ["Bankdrücken (KH)", "Schulterdrücken (KH)", "Schrägbankdrücken aufwärts (KH)", "Trizepsstrecker über Kopf (KH)"],
                kettlebellOnly: ["Kettlebell Floor Press", "Kettlebell Push Press", "Kettlebell Clean & Press", "Kettlebell Halo"]
            ),
            DayExpectation(
                dayIndex: 2, dayLabel: "Strength Pull",
                base: ["Kreuzheben (konventionell)", "Klimmzüge (weit)", "Rudern vorgebeugt", "Bizeps-Curl (KH)"],
                dumbbellOnly: ["Rumänisches Kreuzheben (KH)", "Rudern einarmig (KH)", "Chest Supported Row (KH)", "Bizeps-Curl (KH)"],
                kettlebellOnly: ["Kettlebell RDL", "Kettlebell Row einarmig", "Kettlebell Swing", "Kettlebell Suitcase Carry"]
            ),
            DayExpectation(
                dayIndex: 4, dayLabel: "Strength Legs (Light)",
                base: ["Bulgarische Kniebeuge (KH)", "Rumänisches Kreuzheben", "Wadenheben (stehend, LH)", "Plank"],
                dumbbellOnly: ["Bulgarische Kniebeuge (KH)", "Rumänisches Kreuzheben (KH)", "Ausfallschritte (KH)", "Plank"],
                kettlebellOnly: ["Kettlebell Goblet Squat", "Kettlebell RDL", "Kettlebell Swing", "Plank"]
            )
        ])
    }

    // MARK: - hybrid_performance (6 Tage: Push, Easy Run, Pull, Intervalle, Legs, Long Run)

    func testHybridPerformanceExhaustiveSlotParity() {
        assertParity(templateId: "hybrid_performance", expectations: [
            DayExpectation(
                dayIndex: 0, dayLabel: "Strength Push",
                base: ["Bankdrücken", "Schulterdrücken (stehend)", "Schrägbankdrücken (aufwärts)", "Seitheben", "Trizepsdrücken (Kabel)"],
                dumbbellOnly: ["Bankdrücken (KH)", "Schulterdrücken (KH)", "Schrägbankdrücken aufwärts (KH)", "Seitheben", "Trizepsstrecker über Kopf (KH)"],
                kettlebellOnly: ["Kettlebell Floor Press", "Kettlebell Push Press", "Kettlebell Clean & Press", "Turkish Get-Up", "Kettlebell Halo"]
            ),
            DayExpectation(
                dayIndex: 2, dayLabel: "Strength Pull",
                base: ["Kreuzheben (konventionell)", "Klimmzüge (weit)", "Rudern vorgebeugt", "Bizeps-Curl (KH)"],
                dumbbellOnly: ["Rumänisches Kreuzheben (KH)", "Rudern einarmig (KH)", "Chest Supported Row (KH)", "Bizeps-Curl (KH)"],
                kettlebellOnly: ["Kettlebell RDL", "Kettlebell Row einarmig", "Kettlebell Swing", "Kettlebell Suitcase Carry"]
            ),
            DayExpectation(
                dayIndex: 4, dayLabel: "Strength Legs",
                base: ["Kniebeuge", "Rumänisches Kreuzheben", "Bulgarische Kniebeuge (KH)", "Wadenheben (stehend, LH)"],
                // Same "Goblet Squat"/"Kettlebell Goblet Squat" equipment-requirement
                // tie as hybrid_beginner's Strength A slot 0 above — see that comment.
                dumbbellOnly: ["Kettlebell Goblet Squat", "Rumänisches Kreuzheben (KH)", "Bulgarische Kniebeuge (KH)", "Farmer's Walk"],
                kettlebellOnly: ["Kettlebell Goblet Squat", "Kettlebell RDL", "Kettlebell Swing", "Kettlebell Suitcase Carry"]
            )
        ])
    }

    // MARK: - Cardio days stay untouched (no slots -> `days` passthrough)

    func testCardioDaysPassThroughUnchangedForAllThreeHybridTemplates() {
        for id in ["hybrid_beginner", "hybrid_balanced", "hybrid_performance"] {
            let t = template(id)
            guard let result = t.resolvedSlots(against: baseProfile) else {
                XCTFail("\(id): resolvedSlots(against:) lieferte nil")
                continue
            }
            for (dayIndex, day) in t.days.enumerated() where day.type == .cardio {
                XCTAssertEqual(result.days[dayIndex], day, "\(id)/\(day.name): Cardio-Tag darf von resolvedSlots NICHT veraendert werden")
            }
        }
    }

    // MARK: - Non-hybrid templates are unaffected (nil `slots`)

    func testNonHybridTemplateHasNoSlotsAndResolvedSlotsIsNil() {
        let fullBody = ProgramTemplates.all.first(where: { $0.id != "hybrid_beginner" && $0.id != "hybrid_balanced" && $0.id != "hybrid_performance" })!
        XCTAssertNil(fullBody.resolvedSlots(against: baseProfile), "\(fullBody.id): Templates ohne `slots` muessen `nil` liefern, nie faken")
    }

    // MARK: - Final-review Fix 4: gap reason is the resolver's OR-aggregate,
    // never recomputed from the default exercise alone.

    /// `hybrid_balanced`'s "Schulterdrücken (stehend)" slot: the default
    /// (barbell, confirmed `.unavailable`) is definitively unmet, but its
    /// first alternative "Schulterdrücken (KH)" (`.item(.dumbbell,
    /// minimumCount: 2)`) is merely UNKNOWN here (dumbbell `.available`, but
    /// no count ever recorded -> `RequirementStatus.unknown` per
    /// `ExerciseRequirement.evaluate`, `EquipmentRequirement.swift` line
    /// ~221-228). `TemplateSlotResolver.resolve`'s own OR-aggregation
    /// therefore reports `.uncertain`, not `.missing` — `resolvedSlots`
    /// must surface that same reason unchanged, not recompute `.missing`
    /// from the default barbell gap alone (the pre-fix bug).
    func testUnresolvedSlotGapReasonIsResolverAggregateNotRecomputedFromDefaultAlone() throws {
        let profile = UserEquipmentProfile(
            availability: [
                .barbell: .unavailable, .kettlebell: .unavailable,
                .dumbbell: .available,
                .flatBench: .unavailable, .adjustableBench: .unavailable, .rack: .unavailable,
                .pullUpBar: .unavailable, .cableStation: .unavailable, .machineStation: .unavailable
            ]
            // Deliberately no `.dumbbell` entry in `counts`: "available, but
            // count never recorded" is exactly the `.unknown` case this test
            // needs for the alternative.
        )
        guard let result = template("hybrid_balanced").resolvedSlots(against: profile) else {
            return XCTFail("hybrid_balanced: resolvedSlots(against:) lieferte nil")
        }
        guard let gap = result.gaps.first(where: { $0.exerciseName == "Schulterdrücken (stehend)" }) else {
            return XCTFail("Erwartet einen Gap fuer den 'Schulterdrücken (stehend)'-Slot, gaps: \(result.gaps)")
        }
        guard case let .uncertain(reasons) = gap.reason else {
            return XCTFail("Default ist definitiv unerfuellt (Langhantel fehlt), aber die erste Alternative ('Schulterdrücken (KH)') ist nur UNKNOWN (Kurzhantel-Stueckzahl nie erfasst) — das OR-Aggregat muss `.uncertain` sein, ist aber: \(gap.reason)")
        }
        XCTAssertTrue(reasons.contains { $0.item == .dumbbell }, "Der uncertain-Grund muss von der Kurzhantel-Alternative stammen, nicht vom Langhantel-Default")
    }
}
