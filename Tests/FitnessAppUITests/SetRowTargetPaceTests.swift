#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Task 8 (laufcoaching-remediation-round-2, Decision 1 - "Pace muss zum
/// tatsaechlich uebernommenen Trainingsinhalt passen"): die Vorschau zeigt
/// die Ziel-Pace seit Runde 1 (`CardioFeasibilityDayRowPaceTests`), aber die
/// tatsaechlich geloggte Trainings-Zeile (`ActiveWorkoutView`/`SetRow`)
/// zeigte bisher gar keine Ziel-Pace. Source-introspection (kein SwiftUI-
/// Render-Harness in diesem Repo), gleiches Muster wie
/// `CardioFeasibilityDayRowPaceTests`.
final class SetRowTargetPaceTests: XCTestCase {

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

    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    /// Same idea as `matchingBraceBlock`, but for a parenthesized call's
    /// argument list (e.g. `SetRow(...)`) - braces inside trailing closure
    /// arguments must NOT confuse the scope, so this balances "(" / ")".
    private static func matchingParenBlock(in source: String, afterOpenParen start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "(" { depth += 1 } else if char == ")" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    // MARK: - SetRow: gating + pace computation

    func testSetRowComputesTargetPaceOnlyWhenGatesHold() throws {
        let source = try contents(of: "Workout/SetRow.swift")

        // The gating logic must live in its own small property/function so
        // it can be found and reasoned about independently of the view body.
        guard let hintRange = source.range(of: "var targetPaceHint: String? {") else {
            XCTFail("targetPaceHint not found in SetRow.swift"); return
        }
        let hintBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: hintRange.upperBound))

        XCTAssertTrue(hintBlock.contains("content.isCardio"), "must gate on content.isCardio")
        XCTAssertTrue(hintBlock.contains("content.targetDurationMinutes"), "must gate on the duration-based branch, not the distance/interval one")
        XCTAssertTrue(hintBlock.contains("cardioCoachingEnabled"), "must gate on the live cardioCoachingEnabled flag - same as the preview's scopeLine fix (Review Focus 1: Coach aus -> keine Verhaltensaenderung)")
        XCTAssertTrue(hintBlock.contains("CardioExerciseZone.forExerciseName(content.nameSnapshot)"), "must classify via the stable anchor name")
        XCTAssertFalse(hintBlock.contains("content.customNameSnapshot"), "must NEVER classify via the user-renamable custom name (Task 1 reviewer note)")

        XCTAssertTrue(hintBlock.contains("current5kReferenceSeconds"), "must read the threaded reference-time parameter")
        XCTAssertTrue(hintBlock.contains("PaceZoneCalculator.easyPaceMinutesPerKm") || hintBlock.contains("PaceZoneCalculator.tempoPaceMinutesPerKm"),
                      "must reuse the existing zone pace calculators, not a hand-rolled formula")
        XCTAssertTrue(hintBlock.contains("PaceCalculator.formatPace"), "known pace must use PaceCalculator.formatPace, not a hand-rolled format")
        XCTAssertTrue(hintBlock.contains("cardioFeasibility.day.paceUnknown"), "unknown pace must fall back to the SAME qualitative label the preview already ships, not a new key")
        XCTAssertFalse(hintBlock.contains("formatPace(nil)"), "must never render the raw empty-field placeholder")

        // The distance/interval branch (Task 3: never carries a pace) must
        // stay untouched - the gating function must not reference
        // targetDistanceKm at all.
        XCTAssertFalse(hintBlock.contains("targetDistanceKm"), "must not touch the distance/interval branch - it never carries a pace")
    }

    /// Fix round 1 (Review): a non-nil but non-positive
    /// `current5kReferenceSeconds` (e.g. `0`, or corrupted/imported data via
    /// `DataImportService.row.int("current_5k_reference_seconds")`) must
    /// ALSO fall back to `cardioFeasibility.day.paceUnknown`, not
    /// `PaceCalculator.formatPace`'s raw "—:—— /km" placeholder -
    /// `PaceZoneCalculator.easyPaceMinutesPerKm`/`.tempoPaceMinutesPerKm`
    /// return `nil` for non-positive input (division safety,
    /// `CardioProfile.swift`), so the paceUnknown decision must branch on
    /// the COMPUTED pace result, never merely on whether a reference time
    /// was provided at all - same principle `CardioFeasibilityDayRow`
    /// already follows for its own pace display.
    func testTargetPaceHintFallsBackToPaceUnknownForAnyNilComputedPaceNotJustAMissingReferenceTime() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        guard let hintRange = source.range(of: "var targetPaceHint: String? {") else {
            XCTFail("targetPaceHint not found in SetRow.swift"); return
        }
        let hintBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: hintRange.upperBound))

        // The old (buggy) shape short-circuited straight to paceUnknown the
        // moment `current5kReferenceSeconds` was `nil`, leaving a
        // non-positive-but-non-nil value to sail through to
        // `PaceCalculator.formatPace` unguarded. That exact shape must be
        // gone.
        XCTAssertFalse(hintBlock.contains("current5kReferenceSeconds else"),
                        "must not special-case only a MISSING reference time - a non-positive one must be caught too")

        // The fallback must instead be gated on the computed pace value
        // itself, so both a missing AND a non-positive reference time (and
        // any other case PaceZoneCalculator maps to nil) produce the same
        // qualitative fallback.
        XCTAssertTrue(hintBlock.contains("current5kReferenceSeconds.flatMap"),
                      "must feed the optional reference time through the pace calculators rather than unwrapping it early and assuming success")

        // The paceUnknown fallback must be the else-branch of unwrapping
        // the COMPUTED pace result (a `guard let <paceVariable> else { ...
        // paceUnknown ... }`), not of unwrapping `current5kReferenceSeconds`
        // directly.
        guard let paceGuardRange = hintBlock.range(of: "guard let paceMinutesPerKm else {") else {
            XCTFail("expected a `guard let paceMinutesPerKm else { ... }` gating the paceUnknown fallback on the COMPUTED pace, not the raw reference time"); return
        }
        let paceGuardBlock = try XCTUnwrap(Self.matchingBraceBlock(in: hintBlock, afterOpenBrace: paceGuardRange.upperBound))
        XCTAssertTrue(paceGuardBlock.contains("cardioFeasibility.day.paceUnknown"),
                      "the computed-pace guard's else-branch must be exactly where paceUnknown is returned")
    }

    func testCardioStatusZoneUsesTargetPaceHintInTheEmptySlot() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        guard let zoneRange = source.range(of: "var cardioStatusZone: some View {") else {
            XCTFail("cardioStatusZone not found"); return
        }
        let zoneBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: zoneRange.upperBound))

        XCTAssertTrue(zoneBlock.contains("targetPaceHint"), "the previously-empty Color.clear slot must now show the target-pace hint when available")
        // Completed/previous-run states must stay exactly as before - this
        // is purely an additional branch, not a reshuffle of existing ones.
        XCTAssertTrue(zoneBlock.contains("cardioCompletedSummary(log)"))
        XCTAssertTrue(zoneBlock.contains("cardioPreviousHint(prev)"))
    }

    func testSetRowThreadsLiveParametersNotFrozenSnapshotFields() throws {
        let source = try contents(of: "Workout/SetRow.swift")

        XCTAssertTrue(source.contains("let current5kReferenceSeconds: Int?"), "must be threaded as a plain, non-cached parameter")
        XCTAssertTrue(source.contains("let cardioCoachingEnabled: Bool"), "coach-enabled must also be threaded live, not assumed")

        // Review Focus 5 / Decision 1 ("live, not frozen"): the new fields
        // must NOT be added to the frozen session-content snapshot type.
        let snapshotSource = try String(
            contentsOf: sourcesRoot
                .deletingLastPathComponent() // Sources
                .appendingPathComponent("FitnessAppCore/Training/TrainingDayContentSnapshot.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(snapshotSource.contains("current5kReferenceSeconds"), "the live reference time must never be frozen into the session-content snapshot")
        XCTAssertFalse(snapshotSource.contains("targetPaceMinutesPerKm"), "pace must never be stored on ExerciseEntry - always re-derived live (round 1 design decision)")
    }

    // MARK: - ExerciseCard: parameter passthrough

    func testExerciseCardThreadsParametersIntoEverySetRow() throws {
        let source = try contents(of: "Workout/ExerciseCard.swift")

        XCTAssertTrue(source.contains("let current5kReferenceSeconds: Int?"), "ExerciseCard must accept the parameter to pass it on")
        XCTAssertTrue(source.contains("let cardioCoachingEnabled: Bool"), "ExerciseCard must accept the coach flag to pass it on")

        guard let setRowCallRange = source.range(of: "SetRow(") else {
            XCTFail("SetRow( construction not found in ExerciseCard.swift"); return
        }
        let callBlock = try XCTUnwrap(Self.matchingParenBlock(in: source, afterOpenParen: setRowCallRange.upperBound))
        XCTAssertTrue(callBlock.contains("current5kReferenceSeconds: current5kReferenceSeconds"), "must forward the parameter unchanged, not re-derive or cache it")
        XCTAssertTrue(callBlock.contains("cardioCoachingEnabled: cardioCoachingEnabled"), "must forward the coach flag unchanged")
    }

    // MARK: - ActiveWorkoutView: live @Query source, no caching

    func testActiveWorkoutViewSourcesParametersLiveFromTheQuery() throws {
        let source = try contents(of: "Workout/ActiveWorkoutView.swift")

        guard let constructionRange = source.range(of: "ExerciseCard(") else {
            XCTFail("ExerciseCard( construction not found in ActiveWorkoutView.swift"); return
        }
        let callBlock = try XCTUnwrap(Self.matchingParenBlock(in: source, afterOpenParen: constructionRange.upperBound))

        XCTAssertTrue(callBlock.contains("profiles.first?.current5kReferenceSeconds"), "must read straight off the live @Query result, never a cached/@State copy")
        XCTAssertTrue(callBlock.contains("profiles.first?.cardioCoachingEnabled"), "must read straight off the live @Query result, never a cached/@State copy")
    }

    // MARK: - Fix I-2 (Final-Review, Round 2), corrected in Fix-Round 2: gated on generationSource != .manual

    /// Fix-Round 2 (re-review finding): a narrow `== .cardioCoach` gate was
    /// WRONG - `generationSource: .cardioCoach` is only ever set on the two
    /// "create a separate new plan" fallback paths in
    /// `CardioFeasibilityCardModel.swift`. The two REAL coach paths
    /// (onboarding, the `PlanBuilderView` wizard) stamp
    /// `generationSource == .planBuilder`, and in-place adjustment
    /// (`CoachAdjustmentCardModel.accept`) never changes `generationSource`
    /// at all - so the narrow gate would almost never show the pace for real
    /// users. The gate must pass for ANY generator-built plan (`.planBuilder`
    /// OR `.cardioCoach`) and only exclude `.manual` (template-instantiated
    /// plans, where `ProgramTemplates.swift`'s literal "Long Run" exercises
    /// carry a completely different, non-tempo meaning).
    func testSetRowTargetPaceHintAlsoGatesOnNonManualPlan() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        guard let hintRange = source.range(of: "var targetPaceHint: String? {") else {
            XCTFail("targetPaceHint not found in SetRow.swift"); return
        }
        let hintBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: hintRange.upperBound))
        XCTAssertTrue(hintBlock.contains("isGeneratorPlan"), "must also gate on the plan's generationSource, not just cardioCoachingEnabled - template plans can contain same-named, differently-meant exercises")
        XCTAssertTrue(source.contains("let isGeneratorPlan: Bool"), "must be threaded as a plain, non-cached parameter, same pattern as cardioCoachingEnabled/current5kReferenceSeconds")
        XCTAssertFalse(hintBlock.contains("== .cardioCoach"), "must NOT narrow the gate to the rare cardioCoach-only source - the real coach paths use .planBuilder")
    }

    func testExerciseCardThreadsIsGeneratorPlanIntoEverySetRow() throws {
        let source = try contents(of: "Workout/ExerciseCard.swift")
        XCTAssertTrue(source.contains("let isGeneratorPlan: Bool"), "ExerciseCard must accept the flag to pass it on")

        guard let setRowCallRange = source.range(of: "SetRow(") else {
            XCTFail("SetRow( construction not found in ExerciseCard.swift"); return
        }
        let callBlock = try XCTUnwrap(Self.matchingParenBlock(in: source, afterOpenParen: setRowCallRange.upperBound))
        XCTAssertTrue(callBlock.contains("isGeneratorPlan: isGeneratorPlan"), "must forward the flag unchanged, not re-derive or cache it")
    }

    /// `ActiveWorkoutView` must derive the flag from `session.day?.plan?.
    /// generationSource` - the existing threading path, no new `@Query` -
    /// and must exclude ONLY `.manual`, covering BOTH `.planBuilder` (the
    /// real coach/onboarding/wizard path) and `.cardioCoach` (the rarer
    /// "separate new plan" fallback path).
    func testActiveWorkoutViewDerivesIsGeneratorPlanFromSessionDayPlanGenerationSourceExcludingOnlyManual() throws {
        let source = try contents(of: "Workout/ActiveWorkoutView.swift")
        guard let constructionRange = source.range(of: "ExerciseCard(") else {
            XCTFail("ExerciseCard( construction not found in ActiveWorkoutView.swift"); return
        }
        let callBlock = try XCTUnwrap(Self.matchingParenBlock(in: source, afterOpenParen: constructionRange.upperBound))
        XCTAssertTrue(
            callBlock.contains("session.day?.plan?.generationSource"),
            "must read generationSource off session.day?.plan, the existing threading path - no new @Query needed"
        )
        XCTAssertTrue(
            callBlock.contains("!= .manual"),
            "must exclude only .manual, not narrow to == .cardioCoach - the real coach paths (onboarding, PlanBuilderView) stamp .planBuilder"
        )
        XCTAssertFalse(callBlock.contains("== .cardioCoach"), "must not regress to the too-narrow single-case gate")
        // Fix-Round 2 (explicit nil-safety requirement): a nil plan/
        // generationSource ("we don't know the source") must NOT pass the
        // gate - it must not silently default to `true`.
        XCTAssertTrue(
            callBlock.contains(".map { $0 != .manual } ?? false") || callBlock.contains(".map({ $0 != .manual }) ?? false"),
            "a nil plan/generationSource must explicitly fall back to false, never default to true"
        )
    }

    /// Fix-Round 2 (the main gap the narrow `== .cardioCoach` gate missed):
    /// beyond the source-introspection checks above, this exercises the
    /// EXACT gate expression (`(session.day?.plan?.generationSource).map {
    /// $0 != .manual } ?? false`, copied verbatim from `ActiveWorkoutView.
    /// swift`) against REAL `WorkoutSession`/`TrainingDay`/`TrainingPlan`
    /// SwiftData objects - a `.planBuilder`-sourced day (the real
    /// onboarding/wizard coach path) must pass the gate, a `.manual`-sourced
    /// day (template-instantiated, literal "Long Run" exercises with a
    /// different meaning) must NOT, and a session with no `day`/plan at all
    /// must also NOT (unknown source is not a reason to show the pace).
    @available(iOS 17.0, macOS 14.0, *)
    @MainActor
    func testIsGeneratorPlanGatePassesForPlanBuilderAndCardioCoachButNotManualOrUnknownSource() throws {
        let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        func isGeneratorPlan(_ session: WorkoutSession) -> Bool {
            (session.day?.plan?.generationSource).map { $0 != .manual } ?? false
        }

        let planBuilderPlan = TrainingPlan(name: "Wizard", weeks: 8, isActive: true, targetEnvironment: .gym, generationSource: .planBuilder)
        context.insert(planBuilderPlan)
        let planBuilderDay = TrainingDay(name: "Run", weekday: 2, type: .fullBody, plan: planBuilderPlan)
        context.insert(planBuilderDay)
        let planBuilderSession = WorkoutSession(day: planBuilderDay)
        context.insert(planBuilderSession)
        XCTAssertTrue(isGeneratorPlan(planBuilderSession), ".planBuilder (the real onboarding/wizard coach path) must pass the gate")

        let cardioCoachPlan = TrainingPlan(name: "Coach", weeks: 8, isActive: true, targetEnvironment: .gym, generationSource: .cardioCoach)
        context.insert(cardioCoachPlan)
        let cardioCoachDay = TrainingDay(name: "Run", weekday: 2, type: .fullBody, plan: cardioCoachPlan)
        context.insert(cardioCoachDay)
        let cardioCoachSession = WorkoutSession(day: cardioCoachDay)
        context.insert(cardioCoachSession)
        XCTAssertTrue(isGeneratorPlan(cardioCoachSession), ".cardioCoach (the separate-new-plan fallback path) must also pass the gate")

        let manualPlan = TrainingPlan(name: "Template", weeks: 8, isActive: true, targetEnvironment: .gym, generationSource: .manual)
        context.insert(manualPlan)
        let manualDay = TrainingDay(name: "Long Run", weekday: 2, type: .cardio, plan: manualPlan)
        context.insert(manualDay)
        let manualSession = WorkoutSession(day: manualDay)
        context.insert(manualSession)
        XCTAssertFalse(isGeneratorPlan(manualSession), ".manual (template-instantiated, e.g. ProgramTemplates's own \"Long Run\") must NOT pass the gate")

        let noDaySession = WorkoutSession(day: nil)
        context.insert(noDaySession)
        XCTAssertFalse(isGeneratorPlan(noDaySession), "an unknown source (no day) must NOT default to passing the gate")

        let orphanDay = TrainingDay(name: "Orphan", weekday: 2, type: .fullBody, plan: nil)
        context.insert(orphanDay)
        let noPlanSession = WorkoutSession(day: orphanDay)
        context.insert(noPlanSession)
        XCTAssertFalse(isGeneratorPlan(noPlanSession), "an unknown source (day without a plan) must NOT default to passing the gate")
    }

    // MARK: - Fix I-3 (Final-Review, Round 2): target pace must not hide behind an existing previousLog

    /// Before the fix, `cardioStatusZone` checked `previousLog` BEFORE
    /// `targetPaceHint` in a strict if/else-if chain - once a user completed
    /// the exercise even once, every later not-yet-logged session hit the
    /// `previousLog` branch first and the target pace never showed again.
    /// `targetPaceHint` must now also be referenced INSIDE the `previousLog`
    /// branch (combined rendering), not only in the final, otherwise-
    /// unreachable `else if let targetPaceHint` fallback.
    func testCardioStatusZoneShowsTargetPaceAlongsidePreviousLogNotOnlyInItsAbsence() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        guard let zoneRange = source.range(of: "var cardioStatusZone: some View {") else {
            XCTFail("cardioStatusZone not found"); return
        }
        let zoneBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: zoneRange.upperBound))

        guard let previousLogBranchRange = zoneBlock.range(of: "let prev = previousLog,") else {
            XCTFail("previousLog branch not found in cardioStatusZone"); return
        }
        guard let fallbackRange = zoneBlock.range(of: "} else if let targetPaceHint {") else {
            XCTFail("targetPaceHint fallback branch not found in cardioStatusZone"); return
        }
        XCTAssertTrue(fallbackRange.lowerBound > previousLogBranchRange.lowerBound, "Testaufbau: fallback branch must come after the previousLog branch")
        let previousLogBranchBody = zoneBlock[previousLogBranchRange.upperBound..<fallbackRange.lowerBound]
        XCTAssertTrue(
            previousLogBranchBody.contains("targetPaceHint"),
            "targetPaceHint must be referenced inside the previousLog branch too, so it is visible alongside a previous run, not only when there is nothing else to show"
        )
    }

    /// `active.set.targetPaceFormat` is the only new localization key this
    /// task introduces (`cardioFeasibility.day.paceUnknown` is reused as-is)
    /// - DE/EN/TR must be complete.
    func testTargetPaceFormatKeyIsFullyLocalized() throws {
        let strings = try contents(of: "Resources/Localizable.xcstrings")
        let key = "active.set.targetPaceFormat"
        guard let keyRange = strings.range(of: "\"\(key)\": {") else {
            XCTFail("\(key) not found - add it alongside active.set.previousFormat"); return
        }
        guard let block = Self.matchingBraceBlock(in: strings, afterOpenBrace: keyRange.upperBound) else {
            XCTFail("no matching block for \(key)"); return
        }
        for language in ["\"de\": {", "\"en\": {", "\"tr\": {"] {
            XCTAssertTrue(block.contains(language), "missing localization for \(key): \(language)")
        }
    }
}
#endif
