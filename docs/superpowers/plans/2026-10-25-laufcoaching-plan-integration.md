# Laufcoaching-Plan-Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the running coach (`cardioCoachingEnabled`) a real, measurable effect on the plan the user actually gets — integrated running days instead of a disconnected recommendation — while reusing the already-shipped Paket-1/2/3a adjustment flow and interval data model, and continuing `docs/PLANUNG_BEGLEITUNG_AUDIT.md`'s P3/P4 phases instead of building a parallel track.

**Architecture:** Thread an optional `CardioRunProfile` (goal + baseline) from `UserBodyProfile` through `GoalDrivenPlanSelectionBuilder`/`PlanGenerator.cardioCandidates` so endurance/hybrid-goal running days get baseline-aware pace labeling instead of generic placeholders; redirect `CardioFeasibilityCardModel.accept()` to the existing `CoachAdjustmentCardModel`/`RunCoachPlanAdjustment` in-place-adjustment path whenever an eligible active plan exists, so repeated goal changes stop creating new standalone plans; merge the Dashboard's fixed cardio card slot so `CoachAdjustmentCardModel` (active-plan case) takes priority over `CardioFeasibilityCardModel` (no-plan case), matching the already-documented "Leitplanke 6" precedence; wire the already-computed `PaceZoneCalculator`/`PaceCalculator.formatPace` into the day/exercise detail display.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest. `FitnessAppCore` (pure, Linux-testable) / `FitnessAppData` (SwiftData) / `FitnessAppUI` (SwiftUI) module split, unchanged.

**Spec:** `docs/specs/claude-laufcoaching-integration.md` (ticket), `docs/PLANUNG_BEGLEITUNG_AUDIT.md` §Phasenplan P3.1/P3.4/P4.3 (this plan is their continuation, per explicit user decision 2026-10-25), `docs/DELTIQ_DEVICE_ACCEPTANCE.md` Pakete 1–3a (components being reused, not rebuilt). Phase-1 audit already delivered to the user as `Laufcoaching_Audit_Phase1.md`.

## Correction vs. the Phase-1 audit

The audit's Risiko 2 ("A12 distributionConflict-Banner-UI fehlt noch") was based on a stale note in `docs/DELTIQ_DEVICE_ACCEPTANCE.md`. Live code check (`Sources/FitnessAppUI/Workout/PlanBuilderView.swift:1549-1582`) shows the banner **and** the disabled-adopt-button guard are already fully wired. **No task in this plan touches A12 — it is already closed.**

## Global Constraints

- `cardioCoachingEnabled` stays the single coach switch — never add a second flag (established invariant, `UserBodyProfile.swift:262-278`).
- All new persisted fields are additive with a `nil`/empty default, decoding old data unchanged — same pattern as `PlanGeneratorTypeSelection.timeFormat`/`.equipmentPool` (`PlanGeneratorInput.swift:77-94`). No migration code.
- `PlanGeneratorInstantiator` (`apply`/`revert`/`applyCoachCardioAdjustment`) stays the only write path for `TrainingDay`/`TrainingPlan` mutation — no second mutation route.
- No stored `targetPace`/intensity field anywhere — pace/intensity is always computed on the fly from `CardioGoal`/`current5kReferenceSeconds` via `PaceZoneCalculator`, never cached, so it can't go stale when the reference time improves (established decision, `CardioProfile.swift:36-52`).
- Without a usable `current5kReferenceSeconds`, show a qualitative intensity label, never a fabricated precise pace (user decision 2026-10-25, point 3). `maxHeartRateBpm` is never read — no heart-rate-zone logic exists in the codebase (verified, audit §1.5).
- DE/EN/TR localization is mandatory for every new string; run `python .scripts/dead_catalog_v3.py` after any `Localizable.xcstrings` change — acceptance criterion "UNUSED: 0".
- No new source/settings/localization-file touching outside this plan's own tasks; no KI/AI integration in this epic (user decision 2026-10-25, point: "zunächst keine KI").
- iOS 17+ compatibility unchanged; this epic adds no `@available(iOS 26...)`-gated code.

## Review Focus

1. **Coach off, goal endurance/hybrid:** plan generation must stay byte-for-byte identical to today — no task may make `GoalDrivenPlanSelectionBuilder.makeSelections`'s existing 5 positional-parameter call sites behave differently when the new parameter is omitted/`nil`. Pinned in Task 4's regression test.
2. **Coach on, goal `.strength`/`.hypertrophy`/`.functional`/`.weightLoss`:** activating the coach must never turn a strength plan into a running plan — `makeSelections`'s `case .hypertrophy, .strength, .functional, .weightLoss` branch never reads `CardioRunProfile`. Pinned in Task 4's test.
3. **Repeated cardio-goal changes with an active, eligible plan:** must adjust the same plan, not create another separate `TrainingPlan` — this is the concrete, previously-undecided duplicate-plan question from the audit, now resolved by user decision 2026-10-25, point 1. Pinned in Task 7's test.
4. **Active plan with no eligible cardio day** (all cardio days manually edited or carry session history): `CardioFeasibilityCardModel.accept()` must still be reachable as a fallback (new separate plan), not silently produce nothing. Pinned in Task 7's test.
5. **Missing `current5kReferenceSeconds`:** the generated day's exercise must carry no pace number and the UI must render the qualitative fallback label, not `PaceCalculator.formatPace`'s `"—:—— /km"` placeholder presented as if it were a real pace. Pinned in Task 3's and Task 9's tests.

---

## Task 1: Document the scope decision in the living planning audit

**Files:**
- Modify: `docs/PLANUNG_BEGLEITUNG_AUDIT.md` (append a new dated section after the current last line, 3098)

**Interfaces:** none (documentation only).

- [ ] **Step 1: Append a new section** titled `## Laufcoaching-Ticket als Fortsetzung von P3.4/P4.3 (2026-10-25)` recording: the three user decisions from chat (duplicate-plan handling, dashboard-card consolidation, fallback-intensity-instead-of-fake-pace), the mapping of this plan's tasks onto P3.1/P3.4/P4.3, and a pointer to this plan file's path.
- [ ] **Step 2: Commit**

```bash
git add docs/PLANUNG_BEGLEITUNG_AUDIT.md
git commit -m "docs: record laufcoaching ticket as continuation of P3.4/P4.3"
```

---

## Task 2: `CardioRunProfile` Core type

**Files:**
- Create: `Sources/FitnessAppCore/Analytics/CardioRunProfile.swift`
- Test: `Tests/FitnessAppCoreTests/CardioRunProfileTests.swift`

**Interfaces:**
- Produces: `public struct CardioRunProfile: Sendable, Hashable, Codable { public let goal: CardioGoal; public let current5kReferenceSeconds: Int?; public let weeklyBaseVolumeKm: Double? }` with a `public init(goal:current5kReferenceSeconds:weeklyBaseVolumeKm:)`.

- [ ] **Step 1: Write the failing test**

```swift
func testCardioRunProfileRoundTripsThroughJSON() throws {
    let profile = CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
    let data = try JSONEncoder().encode(profile)
    let decoded = try JSONDecoder().decode(CardioRunProfile.self, from: data)
    XCTAssertEqual(decoded, profile)
}

func testCardioRunProfileDecodesWithMissingOptionalFieldsFromOlderJSON() throws {
    let json = Data(#"{"goal":"fiveK"}"#.utf8)
    let decoded = try JSONDecoder().decode(CardioRunProfile.self, from: json)
    XCTAssertEqual(decoded.goal, .fiveK)
    XCTAssertNil(decoded.current5kReferenceSeconds)
    XCTAssertNil(decoded.weeklyBaseVolumeKm)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CardioRunProfileTests` (or the project's Apple-CI if local `swift test` is blocked, per `local_swift_verification` memory)
Expected: FAIL with "cannot find 'CardioRunProfile' in scope"

- [ ] **Step 3: Implement `CardioRunProfile` in `Sources/FitnessAppCore/Analytics/CardioRunProfile.swift`**

Same shape/doc-comment style as `CardioGoal`/`PaceZoneCalculator` in `CardioProfile.swift` (pure value type, no SwiftData). One short doc comment: this is the plan-generation-facing projection of a user's cardio baseline, assembled by the caller from `UserBodyProfile`.

- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Analytics/CardioRunProfile.swift Tests/FitnessAppCoreTests/CardioRunProfileTests.swift
git commit -m "feat: add CardioRunProfile plan-generation input type"
```

---

## Task 3: Baseline-aware pace labeling in `PlanGenerator.cardioCandidates`

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/PlanGenerator.swift:656-738` (`cardioCandidates`)
- Modify: `Sources/FitnessAppCore/Programs/PlanGeneratorInput.swift` (add field to `PlanGeneratorTypeSelection`)
- Test: `Tests/FitnessAppCoreTests/PlanGeneratorTests.swift`

**Interfaces:**
- Consumes: `CardioRunProfile` (Task 2), `PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds:)` / `.tempoPaceMinutesPerKm(fiveKReferenceSeconds:)` (existing, `CardioProfile.swift:70-76`).
- Produces: `PlanGeneratorTypeSelection.cardioRunProfile: CardioRunProfile?` (new field, default `nil`, additive — same pattern as `timeFormat`/`equipmentPool`). `cardioCandidates` reads `selection.cardioRunProfile` instead of a new parameter, so `generate(from:)`'s own signature does not change.

- [ ] **Step 1: Write the failing tests**

```swift
func testCardioCandidatesSetsEasyAndTempoPaceWhenBaselineIsKnown() {
    let selection = PlanGeneratorTypeSelection(
        kind: .running, daysPerWeek: 3, sessionDurationMinutes: 30, experience: .intermediate,
        cardioRunProfile: CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
    )
    let result = PlanGenerator.generate(from: PlanGeneratorInput(selections: [selection], equipmentPreferences: [], usesFixedWeekdays: false))
    let easyDay = result.days[0].spec.exercises[0] // cycle starts at .easy
    XCTAssertEqual(easyDay.targetPaceMinutesPerKm, PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: 1500))
}

func testCardioCandidatesLeavesPaceNilWithoutReferenceTime() {
    let selection = PlanGeneratorTypeSelection(
        kind: .running, daysPerWeek: 1, sessionDurationMinutes: 30, experience: .intermediate,
        cardioRunProfile: CardioRunProfile(goal: .tenK, current5kReferenceSeconds: nil, weeklyBaseVolumeKm: nil)
    )
    let result = PlanGenerator.generate(from: PlanGeneratorInput(selections: [selection], equipmentPreferences: [], usesFixedWeekdays: false))
    XCTAssertNil(result.days[0].spec.exercises[0].targetPaceMinutesPerKm)
}

func testCardioCandidatesWithoutProfileMatchesPreviousOutputExactly() {
    // Regression for Review Focus 1: identical selection, no `cardioRunProfile`, must
    // produce the exact existing output (compare against the existing fixture/
    // assertions already in this test file for plain running selections).
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PlanGeneratorTests`
Expected: FAIL — `targetPaceMinutesPerKm` not defined on `ExerciseSpec`, `cardioRunProfile` not defined on `PlanGeneratorTypeSelection`.

- [ ] **Step 3: Add `cardioRunProfile: CardioRunProfile? = nil` to `PlanGeneratorTypeSelection`** (`PlanGeneratorInput.swift`, alongside `timeFormat`/`equipmentPool`), same doc-comment convention (nil decodes for pre-existing `generatorInputRaw` snapshots).

- [ ] **Step 4: Add `targetPaceMinutesPerKm: Double? = nil` to `ExerciseSpec`** (`ExerciseSpec.swift`), same additive-field convention as `targetDistanceKm`. Doc comment: computed once at generation time from the selection's `cardioRunProfile`, never stored as a user-facing "truth" — display code still re-derives it live where a fresher baseline exists (see Task 9).

- [ ] **Step 5: In `cardioCandidates(for:)`, for `.easy`/`.tempo` zones**, when `selection.cardioRunProfile?.current5kReferenceSeconds` is non-nil, set `targetPaceMinutesPerKm` to `PaceZoneCalculator.easyPaceMinutesPerKm`/`.tempoPaceMinutesPerKm` respectively; leave `nil` otherwise. The `.interval` zone is unchanged (stays distance-based, no new pace factor invented — Global Constraints).

- [ ] **Step 6: Run tests to verify they pass**
- [ ] **Step 7: Commit**

```bash
git add Sources/FitnessAppCore/Programs/PlanGenerator.swift Sources/FitnessAppCore/Programs/PlanGeneratorInput.swift Sources/FitnessAppCore/Programs/ExerciseSpec.swift Tests/FitnessAppCoreTests/PlanGeneratorTests.swift
git commit -m "feat: baseline-aware pace on generated easy/tempo running days"
```

---

## Task 4: `GoalDrivenPlanSelectionBuilder` forwards the cardio profile for endurance/hybrid goals

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/GoalDrivenPlanSelectionBuilder.swift` (`makeSelections`, `enduranceSelections`)
- Test: `Tests/FitnessAppCoreTests/GoalDrivenPlanSelectionBuilderTests.swift`

**Interfaces:**
- Consumes: `CardioRunProfile` (Task 2).
- Produces: `makeSelections(goal:enduranceModality:totalDaysPerWeek:sessionDurationMinutes:experience:equipmentPreferences:cardioRunProfile: CardioRunProfile? = nil)` — new **trailing, defaulted** parameter, so the one existing call site (`PlanBuilderView.swift:1412`) keeps compiling if not yet updated, and every existing test call keeps compiling unchanged.

- [ ] **Step 1: Write the failing tests**

```swift
func testEnduranceGoalForwardsCardioProfileToRunningSelection() {
    let profile = CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
    let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
        goal: .endurance, enduranceModality: .running, totalDaysPerWeek: 3,
        sessionDurationMinutes: 30, experience: .intermediate, equipmentPreferences: [],
        cardioRunProfile: profile
    )
    XCTAssertEqual(selections.first?.cardioRunProfile, profile)
}

func testStrengthGoalsNeverReceiveACardioProfileEvenIfOneIsPassed() {
    let profile = CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
    for goal: TrainingGoal in [.hypertrophy, .strength, .functional, .weightLoss] {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: goal, enduranceModality: nil, totalDaysPerWeek: 3,
            sessionDurationMinutes: 30, experience: .intermediate, equipmentPreferences: [.barbell],
            cardioRunProfile: profile
        )
        XCTAssertTrue(selections.allSatisfy { $0.cardioRunProfile == nil }, "goal \(goal) must never carry a cardio profile")
    }
}

func testOmittingCardioRunProfileReproducesExistingEnduranceOutputExactly() {
    // Regression for Review Focus 1: call makeSelections with the SAME arguments
    // an existing passing test in this file already uses (no cardioRunProfile
    // argument), assert the result is unchanged.
}
```

- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Add the trailing `cardioRunProfile: CardioRunProfile? = nil` parameter to `makeSelections`**; thread it into `enduranceSelections(modality:totalDays:sessionDurationMinutes:experience:)` by adding the same trailing defaulted parameter there, and set it only on the `PlanGeneratorTypeSelection` built for `.running`/`.cycling` kinds inside `.endurance`/`.hybrid` branches — never inside the `.hypertrophy/.strength/.functional/.weightLoss` branch.
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Programs/GoalDrivenPlanSelectionBuilder.swift Tests/FitnessAppCoreTests/GoalDrivenPlanSelectionBuilderTests.swift
git commit -m "feat: thread cardio baseline into endurance/hybrid plan selections"
```

---

## Task 5: Onboarding asks the cardio goal when the coach is wanted

**Files:**
- Modify: `Sources/FitnessAppUI/OnboardingView.swift` (`enduranceModalityStep` around line 957-982, `finishOnboarding()` around line 2156-2160)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (new keys, DE/EN/TR)
- Test: `Tests/FitnessAppUITests/OnboardingRunCoachGoalTests.swift` (new, source-introspection style — same pattern as `MehrInformationArchitectureTests`/`PlanBuilderResultDayRowTemplateAlignmentTests`: read the `.swift` source, assert on literal content, no SwiftUI render harness in this repo)

**Interfaces:**
- Consumes: `CardioGoal` (existing, `CardioProfile.swift`).
- Produces: new `@State private var runCoachCardioGoal: CardioGoal = .generalFitness` in `OnboardingView`; `finishOnboarding()` sets `profile.cardioGoal = runCoachCardioGoal` only when `runCoachWanted` ends up `true` for the finally-chosen modality.

- [ ] **Step 1: Write the failing tests**

```swift
func testEnduranceModalityStepAsksForCardioGoalOnlyWhenCoachIsWanted() throws {
    let source = try contents(of: "OnboardingView.swift") // same helper pattern as MehrInformationArchitectureTests
    guard let stepRange = source.range(of: "private var enduranceModalityStep: some View {") else {
        XCTFail("enduranceModalityStep not found"); return
    }
    let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: stepRange.upperBound))
    XCTAssertTrue(block.contains("runCoachCardioGoal"), "the goal question must live inside this step")
    // The goal question must be nested inside the existing `if runCoachWanted`-ish
    // gate, not always visible — assert it appears textually after the existing
    // "if let enduranceModality, enduranceModality.supportsRunCoach" guard.
}

func testFinishOnboardingPersistsCardioGoalOnlyWhenCoachEndsUpEnabled() throws {
    let source = try contents(of: "OnboardingView.swift")
    guard let range = source.range(of: "if needsEnduranceModalityStep {") else {
        XCTFail("finishOnboarding endurance block not found"); return
    }
    let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
    XCTAssertTrue(block.contains("profile.cardioGoal = runCoachCardioGoal"))
}
```

- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Add the goal picker.** Inside `enduranceModalityStep`'s existing `if let enduranceModality, enduranceModality.supportsRunCoach { ... }` block (`OnboardingView.swift:957-982`), after the existing coach-on/off `coachingCard` pair, add a `if runCoachWanted { ... }` section with a `CardioGoal.allCases`-driven picker (same `coachingCard(...)` component already used throughout this file), bound to the new `@State runCoachCardioGoal`. New localization keys: `onboarding.runCoachGoal.title`/`.subtitle` plus reuse of `CardioGoal.localizedName` (already exists) for each option's label — no new per-goal strings.
- [ ] **Step 4: Persist it.** In `finishOnboarding()`, inside the existing `if needsEnduranceModalityStep { ... }` block (line 2156-2160), after the `setEnduranceModality` call, add: `if profile.cardioCoachingEnabled { profile.cardioGoal = runCoachCardioGoal }`. Race date / weekly volume / 5k reference stay unasked here (scoped decision: "schrittweise erfragen" per spec §9 — the full `CardioGoalEditorView` remains the place to complete the baseline later; onboarding only seeds the goal category so plan generation, Task 3/4, has something non-default to use immediately).
- [ ] **Step 5: Add the two new xcstrings keys (DE/EN/TR)** following the established Python-script-against-`Localizable.xcstrings` pattern (brace-counting verification, not comma-dependent — see `MehrInformationArchitectureTests`'s documented bugfix).
- [ ] **Step 6: Run tests to verify they pass**, then run `python .scripts/dead_catalog_v3.py` and confirm "UNUSED: 0".
- [ ] **Step 7: Commit**

```bash
git add Sources/FitnessAppUI/OnboardingView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppUITests/OnboardingRunCoachGoalTests.swift
git commit -m "feat: onboarding asks the cardio goal when the run coach is enabled"
```

---

## Task 6: `PlanBuilderView` passes the real cardio profile into plan generation

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/PlanBuilderView.swift:1402-1427` (`currentInput`)
- Test: `Tests/FitnessAppUITests/PlanBuilderCardioProfileWiringTests.swift` (new, source-introspection style)

**Interfaces:**
- Consumes: `GoalDrivenPlanSelectionBuilder.makeSelections(..., cardioRunProfile:)` (Task 4), `profiles.first: UserBodyProfile?` (existing `@Query`, already used at lines 640/1479/2344).
- Produces: nothing new for later tasks — this is the final wiring point for Requirement A.

- [ ] **Step 1: Write the failing test**

```swift
func testCurrentInputPassesCardioRunProfileWhenCoachIsEnabled() throws {
    let source = try contents(of: "Workout/PlanBuilderView.swift")
    guard let range = source.range(of: "private var currentInput: PlanGeneratorInput {") else {
        XCTFail("currentInput not found"); return
    }
    let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
    XCTAssertTrue(block.contains("cardioRunProfile:"), "GoalDrivenPlanSelectionBuilder.makeSelections must receive a cardio profile")
    XCTAssertTrue(block.contains("cardioCoachingEnabled"), "the profile must only be built when the coach is actually enabled")
}
```

- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement.** Inside `currentInput`'s `else` branch (the `GoalDrivenPlanSelectionBuilder.makeSelections` call), add a local `let cardioRunProfile: CardioRunProfile? = (profiles.first?.cardioCoachingEnabled == true) ? profiles.first.map { CardioRunProfile(goal: $0.cardioGoal, current5kReferenceSeconds: $0.current5kReferenceSeconds, weeklyBaseVolumeKm: $0.weeklyBaseVolumeKm) } : nil` and pass `cardioRunProfile: cardioRunProfile` as the new trailing argument.
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Workout/PlanBuilderView.swift Tests/FitnessAppUITests/PlanBuilderCardioProfileWiringTests.swift
git commit -m "feat: PlanBuilderView feeds the real cardio baseline into plan generation"
```

---

## Task 7: Stop creating duplicate plans — route `CardioFeasibilityCardModel.accept()` through the existing adjustment path

**Files:**
- Modify: `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift:130-173` (`accept(profile:in:using:)`) — add a new parameter, see Interfaces.
- Modify the 3 call sites to pass it: `Sources/FitnessAppUI/Cardio/CoachAdjustmentPreviewView.swift:154` (already holds the exact plan as its own `activePlan` init parameter — pass it straight through), `Sources/FitnessAppUI/Workout/PlansListView.swift:345`, `Sources/FitnessAppUI/Settings/ProfileEditorView.swift:845` (both already query/hold the active plan for other purposes in the same file — reuse, don't re-fetch).
- Test: `Tests/FitnessAppUITests/CardioFeasibilityCardModelTests.swift` (existing file, extend) or `Tests/FitnessAppDataTests/` equivalent if the existing suite for this type lives there — confirm with `grep -rl CardioFeasibilityCardModel Tests/` before adding.

**Interfaces:**
- Consumes: `RunCoachPlanAdjustment.analyze(plan:)` → `.cardioAvailability` (existing, `RunCoachPlanAdjustment.swift:114-130`), `CoachAdjustmentCardModel.make(for:activePlan:)` / `.accept(plan:profile:in:now:calendar:) throws -> Int` (existing, `CoachAdjustmentCardModel.swift:34-137`).
- Produces: `accept(profile: UserBodyProfile, in: ModelContext, using: PlanCreationOperation, activePlan: TrainingPlan?)` — one new, trailing, defaulted (`= nil`) parameter, so no caller is forced to change if it genuinely has none. Return type stays `PlanCreationOperation.Outcome?` (existing cases observed in call sites: `.success`, `.nothingToCreate`, `.committedButUnresolved`, plus `nil`). Map `CoachAdjustmentCardModel.accept`'s `Int` result: `0` → `.nothingToCreate` (mirrors its existing "no eligible day / already applied" no-op semantics), `> 0` → `.success`, a caught thrown error → `.committedButUnresolved` (consistent with `operation.attempt`'s existing "mutation may have partially happened" semantics for this case).

- [ ] **Step 1: Write the failing tests**

```swift
func testAcceptAdjustsTheExistingPlanInPlaceWhenAnEligibleCardioDayExists() throws {
    // Arrange: a profile with cardioCoachingEnabled + raceDate + weeklyBaseVolumeKm
    // set such that CardioFeasibilityCardModel.make(for:) is non-nil, AND an
    // active TrainingPlan whose cardio day is untouched since generation
    // (RunCoachPlanAdjustment.isEligibleForAdjustment == true).
    // Act: call model.accept(profile:in:using:) with that active plan in context.
    // Assert: TrainingPlan count in the context is unchanged (no new plan),
    // the existing plan's cardio day content changed to match the new goal,
    // and profile.cardioPlanAdjustmentFingerprint now equals
    // CardioFeasibilityCalculator.suppressionFingerprint(goal:raceDate:weeklyBaseVolumeKm:).
}

func testAcceptStillCreatesANewPlanWhenNoActivePlanExists() {
    // Existing behavior, pinned: no active TrainingPlan in context →
    // a new TrainingPlan with generationSource == .cardioCoach is created,
    // exactly as today.
}

func testAcceptStillCreatesANewPlanWhenTheActivePlanHasNoEligibleCardioDay() {
    // Active plan exists but every cardio day has been manually edited
    // (generationFingerprint != currentContentFingerprint) or carries session
    // history — RunCoachPlanAdjustment.analyze(...).cardioAvailability is
    // .noEligibleCardioDay — same "create a new plan" fallback as today.
}
```

- [ ] **Step 2: Run tests to verify the first one fails** (the other two already pass against current code — confirm, don't break them).
- [ ] **Step 3: Implement.** Add the `activePlan: TrainingPlan? = nil` parameter to `accept(profile:in:using:)`. At the top of its body, before the existing `hasPlan`/`planInput` guard: if `activePlan` is non-nil and `RunCoachPlanAdjustment.analyze(plan: activePlan).cardioAvailability` is `.ready`, build `CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan)` and, if non-nil, delegate to its `accept(plan:profile:in:now:calendar:)` instead of the existing `operation.attempt(create: ...)` branch, mapping its `Int` result/thrown error to `PlanCreationOperation.Outcome?` per the Interfaces block above. Otherwise (no `activePlan`, or `.noEligibleCardioDay`/`.noActivePlan`), fall through to the existing create-a-new-plan logic unchanged. Update the 3 call sites to pass their already-held active plan.
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift Tests/FitnessAppUITests/CardioFeasibilityCardModelTests.swift
git commit -m "fix: adjust the existing active plan instead of creating a duplicate on repeated cardio goal changes"
```

---

## Task 8: Consolidate the Dashboard's fixed cardio card

**Files:**
- Modify: `Sources/FitnessAppUI/DashboardView.swift:232-239` (fixed-card slot), `:2461-2505` (`cardioFeasibilityModel`/`cardioFeasibilityDashboardCard`)
- Test: `Tests/FitnessAppUITests/DashboardCardioCardPriorityTests.swift` (new, source-introspection style)

**Interfaces:**
- Consumes: `CoachAdjustmentCardModel.make(for:activePlan:)` (existing — currently never called from `DashboardView`), `CardioFeasibilityCardModel.make(for:)` (existing, already called here).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing test**

```swift
func testDashboardChecksCoachAdjustmentBeforeCardioFeasibilityInTheFixedCardSlot() throws {
    let source = try contents(of: "DashboardView.swift")
    let coachAdjustmentIndex = source.range(of: "CoachAdjustmentCardModel.make(for:")?.lowerBound
    let feasibilityIndex = source.range(of: "if let model = cardioFeasibilityModel")?.lowerBound
    XCTAssertNotNil(coachAdjustmentIndex, "the fixed card slot must also check CoachAdjustmentCardModel")
    if let coachAdjustmentIndex, let feasibilityIndex {
        XCTAssertLessThan(coachAdjustmentIndex, feasibilityIndex, "CoachAdjustmentCardModel (active-plan case) must take priority, per the existing Leitplanke 6 precedence")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement.** At the fixed-card slot (`DashboardView.swift:232-239`), before the existing `if let model = cardioFeasibilityModel { cardioFeasibilityDashboardCard(model) }`, add `if let activePlan = activePlans.first, let adjustment = CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan), !adjustment.isAlreadyApplied { laufcoachingAdjustmentCard(adjustment, plan: activePlan) } else if let model = cardioFeasibilityModel { cardioFeasibilityDashboardCard(model) }` — a single `if/else if`, not two independent `if`s, so the two cards never both render for the same state (reuses the precedence already documented in `CoachAdjustmentCardModel.swift:12-21`). Write `laufcoachingAdjustmentCard(_:plan:)` as a new private `some View` method next to `cardioFeasibilityDashboardCard`, same `DeltiqCard` shape, with a CTA that sets the existing `showingMissedRunAdjustmentPreview`-style `@State` (add a dedicated `@State private var showingCoachAdjustmentPreview = false` if `showingMissedRunAdjustmentPreview` is reused by the missed-run-days widget for a different plan reference — check before reusing) opening `CoachAdjustmentPreviewView(profile: profile, activePlan: activePlan)` (existing view, already used at line 354).
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/DashboardView.swift Tests/FitnessAppUITests/DashboardCardioCardPriorityTests.swift
git commit -m "feat: surface the coach-adjustment card ahead of the feasibility card on the Dashboard"
```

---

## Task 9: Pace/intensity display in the plan day and training-day detail

**Files:**
- Modify: wherever a cardio `ExerciseSpec`/`Exercise`'s distance/duration is currently rendered for a plan preview and a live training day — locate with `grep -rn "targetDistanceKm\|targetDurationMinutes" Sources/FitnessAppUI/` before editing (candidates seen in the audit: `CardioFeasibilityDayRow.swift`, `CardioSetRow` referenced from `PaceCalculator.swift`'s own doc comment, `PlanEditorView.swift`'s day detail).
- Test: for each modified view, a source-introspection test asserting `PaceCalculator.formatPace`/qualitative-fallback text appears, following the existing per-file pattern.

**Interfaces:**
- Consumes: `ExerciseSpec.targetPaceMinutesPerKm` (Task 3) where generated from a plan, OR — for a day whose cardio exercise predates this plan (no stored pace) — `PaceZoneCalculator.easyPaceMinutesPerKm`/`.tempoPaceMinutesPerKm(fiveKReferenceSeconds:)` computed live from the CURRENT `profile.current5kReferenceSeconds` (always prefer the live value over the stored one, per Global Constraints — a stored pace can only get staler, never fresher).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing tests** (one per modified file) asserting the view's source calls `PaceCalculator.formatPace` and, in an `else`/`??`/guard-fallback branch, a qualitative intensity string (new key `exercise.cardio.intensityFallback` or similar — only create a new key if no existing one fits; check `Localizable.xcstrings` for an existing "locker"/"moderat"/"intensiv"-style key first).
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement** the pace/fallback rendering at each located call site. One line per site: `current5kReferenceSeconds != nil ? PaceCalculator.formatPace(zonePace) : String(localized: "exercise.cardio.intensityFallback", bundle: .module)` (exact zone — easy vs. tempo — determined by the same `RunZone` the day's title/localization key already encodes, don't re-derive it from scratch).
- [ ] **Step 4: Add any new xcstrings key (DE/EN/TR)**, verify with the brace-counting test pattern, run `dead_catalog_v3.py`.
- [ ] **Step 5: Run tests to verify they pass**
- [ ] **Step 6: Commit**

```bash
git add <modified views> <new/modified tests> Sources/FitnessAppUI/Resources/Localizable.xcstrings
git commit -m "feat: show baseline-derived pace or a qualitative fallback on cardio plan days"
```

---

## Task 10: Full regression pass

**Files:** none new — verification only.

- [ ] **Step 1: Run `python .scripts/dead_catalog_v3.py`**, confirm "UNUSED: 0".
- [ ] **Step 2: Trigger Apple CI** (`gh workflow run apple-ci-comparison.yml --ref <branch>`) and confirm green, with explicit attention to the full test list from the Phase-1 audit §7 (`PlanDraftTests`, `PlanGeneratorTests`, `GoalDrivenPlanSelectionBuilderTests`, `PlanGeneratorInstantiatorTests`, `PlanCreationOperationTests`, `RunCoachPlanAdjustmentTests`, `CoachAdjustmentCardModelTests`, `MissedRunDaysCardAdjustmentWiringTests`, `TrainingDayEnduranceIntervalFieldsTests`, `MissedRunDaysCardModelTests`, `MissedRunDayEvaluatorTests`, `DeviceAcceptanceFixturePaket3aTests`, `CardioFeasibilityCalculatorTests`, `CardioCoachingAdvisorTests`, `PaceCalculatorTests`, `DashboardWidgetTypeTests`) — none may regress.
- [ ] **Step 3: Manually re-read the 5 Review Focus scenarios above against the merged diff** and confirm each has a passing test that would fail without this plan's changes.
- [ ] **Step 4: Commit** only if Step 1 required a fix; otherwise this task closes the plan with no commit of its own.
