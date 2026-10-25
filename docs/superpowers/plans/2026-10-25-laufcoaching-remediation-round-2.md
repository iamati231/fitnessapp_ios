# Laufcoaching-Remediation-Round-2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three product gaps the user identified after reviewing `2026-10-25-laufcoaching-plan-integration.md`'s final review: (1) the baseline-derived pace must survive onto the adopted plan's actual training day, not just the pre-adoption preview; (2) the cardio goal (and, where known, weekly base volume) must actually shape the first generated plan's running structure, not just its pace; (3) the feasibility-suggested, achievable goal must be the one thing every acceptance path (Dashboard, Profile, Plan tab) previews and applies — through the EXISTING `CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView` flow, not a second parallel mechanism.

**Architecture:** Extend the already-established, reviewed `CardioRunProfile`-threading pattern (name-based zone detection, live re-derivation from the current profile, never a stored "truth") to a third display site (`SetRow`, the live/adopted training-day view). Give `PlanGenerator.cardioCandidates` two new, separately-testable pure decisions — run-type mix by `CardioGoal`, distance/duration scaling by `weeklyBaseVolumeKm` — alongside the existing pace-by-reference-time decision, reusing `CardioFeasibilityCalculator`'s existing per-goal volume table instead of inventing a second one. Fold feasibility evaluation into `CoachAdjustmentCardModel` itself so it carries a `suggestedGoal` the same way `CardioFeasibilityCardModel` already does, and make `CoachAdjustmentPreviewView`/`accept()` use and apply that suggested goal — closing the dead-end the first plan's final review found, without adding a second UI flow.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest — unchanged from the first plan. Same module split (`FitnessAppCore` pure / `FitnessAppData` SwiftData / `FitnessAppUI` SwiftUI).

**Spec:** `docs/specs/claude-laufcoaching-integration.md` (original ticket), `docs/superpowers/plans/2026-10-25-laufcoaching-plan-integration.md` (first plan — this one builds directly on its `CardioRunProfile`/`CoachAdjustmentCardModel`/`PaceZoneCalculator` work, do not duplicate it), and the user's three written decisions below, which are now binding requirements, not suggestions.

## The three decisions (binding, do not re-litigate in review)

1. **Pace must persist past adoption.** The pace shown in previews must also appear on the actual, adopted training day — not only in pre-adoption previews. It is derived live from the runner's profile and baseline (never a stale stored value); when no reference time exists, a qualitative intensity range/hint replaces it — never a fabricated precise number. This is not a cosmetic add-on: the displayed pace must match the day the user actually trains.
2. **The cardio goal must shape the first plan, not just seed the profile.** `CardioGoal` drives the selection/structure of running units (e.g. quality-session mix). A known, credible weekly base volume shapes volume/distance. A known reference time shapes pace. These are three separate, separately-owned decisions — not one calculation that tries to do all three. With insufficient data the generator stays conservative, and nothing in onboarding/UI promises precision the generator doesn't deliver.
3. **The suggested, achievable goal must survive the entire adjustment flow, on all three surfaces.** The adjustment preview shows the goal that was actually proposed; accepting it applies exactly that goal, never silently reverting to the original one. All three surfaces (Dashboard, Profile, Plan tab) use the same logic. On failure, the existing plan is left untouched. This is fixed inside the existing `CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView` flow — no second, parallel consent mechanism.

An end-to-end pass (activate coach → pick a goal → generate a plan → open the adjustment preview → accept → inspect the adopted training day) is the acceptance bar for this round, not just per-function unit tests — see Task 9.

## Global Constraints

- Everything additive; no SwiftData schema change, no migration. (`Exercise`/`TrainingDay` already mirror `targetDistanceKm`/`targetDurationMinutes`/`enduranceSportKind` — this round adds no new persisted field for pace; it stays a live, re-derived display value everywhere, exactly like the first plan.)
- `PlanGeneratorInstantiator` (`apply`/`revert`/`applyCoachCardioAdjustment`) stays the only write path for `TrainingDay`/`TrainingPlan` mutation.
- Zone detection (easy/tempo/interval) for a cardio exercise is by name match against the Library's fixed exercise-name strings ("Easy Run", "Long Run", the interval exercise name) — the SAME pattern already reviewed and shipped twice in the first plan (`CardioFeasibilityDayRow`, `PlanBuilderView.scopeLine`). Do not invent a new explicit zone field; do not duplicate the name-matching logic — factor it into one shared helper if it needs to appear a third time (see Task 1).
- Coach-off behavior stays byte-for-byte unchanged everywhere this round touches (Review Focus 1 from the first plan still applies in full — it was violated once already and caught in review; do not repeat that).
- No AI/FoundationModels anywhere in this round — all three decisions stay deterministic, per the original ticket's §7 and the first plan's own constraint.
- DE/EN/TR localization mandatory for any new string; run `python .scripts/dead_catalog_v3.py` after any `Localizable.xcstrings` change — "UNUSED: 0".
- `CardioFeasibilityCardModel` and `CoachAdjustmentCardModel` keep their existing "Leitplanke 6" precedence (never both shown for the same state) — Task 6/7 change what `CoachAdjustmentCardModel` computes and applies, not this precedence rule.

## Review Focus

1. **Coach off, any goal:** every one of this round's changes (pace display, goal-driven structure, suggested-goal application) must be completely inert when `cardioCoachingEnabled == false` — re-verify this holds after each task, not just once at the end; this exact class of regression was caught once already in the first plan's final review.
2. **Insufficient baseline data (no reference time, no weekly volume, or both):** the generator must stay conservative and the UI must never claim a precision it doesn't have — a test for "goal known, baseline unknown" must exist for Task 2/3's new structure logic, mirroring the existing "pace unknown → qualitative fallback" test from the first plan.
3. **Repeated acceptance across all three surfaces with the SAME suggested goal:** accepting from Dashboard, then from Profile, then from the Plan tab (in any order, for the same underlying suggestion) must not re-apply or duplicate anything — `CoachAdjustmentCardModel`'s existing fingerprint-based idempotency guard must keep working once it also carries a `suggestedGoal`.
4. **Acceptance failure leaves the existing plan and `profile.cardioGoal` byte-for-byte untouched** — this exact rollback discipline was added, broken by a follow-up fix, and re-fixed once already in the first plan (Task 7's two fix rounds); Task 7 here must not regress it while adding suggested-goal support.
5. **The adopted day's pace is read from the LIVE profile, never a value computed at generation time** — a user who sets up a plan without a reference time, then adds one later, must see the correct pace on their already-adopted day the next time they open it (no re-generation, no re-adoption needed).

---

## Task 1: Shared cardio-zone-by-name helper (de-duplicate before adding a third call site)

**Files:**
- Create: `Sources/FitnessAppCore/Analytics/CardioExerciseZone.swift`
- Modify: `Sources/FitnessAppUI/Cardio/CardioFeasibilityDayRow.swift` (replace its inline name check with the new helper)
- Modify: `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` (replace its inline name check with the new helper, in `scopeLine(for:)`)
- Test: `Tests/FitnessAppCoreTests/CardioExerciseZoneTests.swift`

**Interfaces:**
- Produces: `public enum CardioExerciseZone: Sendable, Equatable { case easy, tempo, interval, other }` and `public static func CardioExerciseZone.forExerciseName(_ name: String) -> CardioExerciseZone` (exact case names/signature are your call — the two existing call sites currently match on literal strings like `"Easy Run"`/`"Long Run"`; read `PlanGenerator.swift`'s `RunZone.exerciseName` cases first to get the exact, current literal strings right, don't guess them from memory).
- Consumes: nothing new.

- [ ] **Step 1: Write failing tests** — one per zone, asserting `CardioExerciseZone.forExerciseName("Easy Run") == .easy`, `.forExerciseName("Long Run") == .tempo`, the interval exercise's exact name → `.interval`, and an unrelated name (e.g. "Bank Press" or "Radfahren (outdoor)") → `.other`.
- [ ] **Step 2: Run tests to verify they fail**

Run: `swift build --target FitnessAppCoreTests` (this is pure Core, compiles and the probe/build approach works on this Windows machine per `local-swift-verification` memory)
Expected: FAIL — `CardioExerciseZone` not found.

- [ ] **Step 3: Implement `CardioExerciseZone`** in the new file, matching on the exact strings from `PlanGenerator.RunZone.exerciseName` (read it first — do not hardcode a guess).
- [ ] **Step 4: Replace the inline checks** in `CardioFeasibilityDayRow.swift`'s `subtitle` and `PlanBuilderView.swift`'s `scopeLine(for:)` with calls to the new helper — this is a refactor of ALREADY-SHIPPED, reviewed code; keep the exact same visible behavior, verify by re-reading both functions' full bodies before and after your change line-by-line.
- [ ] **Step 5: Run tests to verify they pass**, and re-read `CardioFeasibilityDayRowPaceTests.swift`'s existing tests to confirm your refactor doesn't change what they assert (they test the OLD inline string, not the new helper — if they still pass unchanged, your refactor is behavior-preserving; if they need updating to reference the helper instead, do that too, but do not change their assertions' meaning).
- [ ] **Step 6: Commit**

```bash
git add Sources/FitnessAppCore/Analytics/CardioExerciseZone.swift Sources/FitnessAppUI/Cardio/CardioFeasibilityDayRow.swift Sources/FitnessAppUI/Workout/PlanBuilderView.swift Tests/FitnessAppCoreTests/CardioExerciseZoneTests.swift
git commit -m "refactor: extract shared cardio-zone-by-name helper before adding a third call site"
```

---

## Task 2: Goal-driven run-type structure (Decision 2, part 1 — "goal shapes selection/structure")

**Files:**
- Modify: `Sources/FitnessAppCore/Analytics/CardioFeasibilityCalculator.swift` (reuse, do not duplicate, its existing `targetWeeklyVolumeKm(for:)`)
- Create or extend: a new pure function — your call whether this lives as a new static method on `CardioFeasibilityCalculator` (it already owns the per-goal volume table) or as a new small enum/type in the same file — e.g. `public static func runTypeMix(for goal: CardioGoal) -> [RunPurpose]` where `RunPurpose` is a small new Sendable enum (`.easy`, `.quality`, `.long` — your call on exact naming, but it must map cleanly onto the EXISTING `PlanGenerator.RunZone` cycle `[.easy, .interval, .tempo]`, not replace it — see Task 3).
- Test: extend `Tests/FitnessAppCoreTests/CardioFeasibilityCalculatorTests.swift`

**Interfaces:**
- Consumes: `CardioGoal` (existing).
- Produces: a pure function from `CardioGoal` to a description of which run purposes/how many quality sessions a week should contain for that goal. Decide the actual mapping yourself from the original ticket's intent (§3: "Die Läufe sollen einen konkreten Trainingszweck haben... nur soweit passend zum Ziel") — e.g. `.marathon`/`.halfMarathon` lean toward more easy/long-run volume and fewer hard quality sessions than `.fiveK`/`.tenK`, which can sustain more interval/tempo work relative to total volume. Write down your reasoning in a doc comment; this is a product/training-science judgment call within the task's scope, not something to escalate — keep it simple and defensible, not a scientific claim (same spirit as the existing `PaceZoneCalculator` factor comments: "grobe Naeherungen... keine individuelle Trainingsempfehlung").

- [ ] **Step 1: Write failing tests** for at least two contrasting goals (e.g. `.fiveK` vs `.marathon`) producing a different run-type mix, plus `.generalFitness` (which has no target volume per `targetWeeklyVolumeKm` — decide and test what it returns: likely the most conservative/easy-leaning default).
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement** the function, reusing `targetWeeklyVolumeKm(for:)` only if your chosen design needs it (it may not — the run-type MIX and the VOLUME scaling, per Decision 2, are separate concerns; don't conflate them here, Task 3 handles volume).
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Analytics/CardioFeasibilityCalculator.swift Tests/FitnessAppCoreTests/CardioFeasibilityCalculatorTests.swift
git commit -m "feat: derive a goal-specific run-type mix, separate from pace and volume"
```

---

## Task 3: Volume-aware distance/duration scaling (Decision 2, part 2 — "known weekly volume shapes volume")

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/PlanGenerator.swift` (`cardioCandidates`, the `.running` branch)
- Modify: `Sources/FitnessAppCore/Analytics/CardioRunProfile.swift` is NOT touched — `weeklyBaseVolumeKm` already exists on it since Task 2 of the first plan; this task only makes `cardioCandidates` finally READ it (confirmed by the first plan's final review: today nothing reads `.goal`/`.weeklyBaseVolumeKm` from `CardioRunProfile`, only `.current5kReferenceSeconds`).
- Test: extend `Tests/FitnessAppCoreTests/PlanGeneratorTests.swift`

**Interfaces:**
- Consumes: `CardioRunProfile.goal`/`.weeklyBaseVolumeKm` (existing fields, newly read), Task 2's run-type-mix function, `CardioFeasibilityCalculator.targetWeeklyVolumeKm(for:)` (existing).
- Produces: `cardioCandidates`'s `.running` branch uses `selection.cardioRunProfile?.goal` to pick the run-type mix (Task 2) instead of the current fixed `[.easy, .interval, .tempo]` cycle when a profile is present (when absent, the EXACT existing cycle/behavior must remain — Review Focus 1); and, when `weeklyBaseVolumeKm` is known and credible (non-nil, positive), scales easy/long-run `targetDurationMinutes` (or `targetDistanceKm` where distance-based) proportionally — conservatively, never aggressively — toward a sensible session size for that volume. When `weeklyBaseVolumeKm` is unknown, duration/distance targets stay exactly as they are today (the existing `sessionDurationMinutes`-driven calculation) — this is the "stay conservative with insufficient data" half of Decision 2.

- [ ] **Step 1: Write failing tests**: (a) `CardioRunProfile` with a goal but no weekly volume → distance/duration unchanged from today's output (Review Focus 2); (b) two different goals with a profile but no volume → different run-TYPE mix (quality-session count/placement) per Task 2, but the SAME overall day count as `GoalDrivenPlanSelectionBuilder.makeSelections` already decided before `cardioCandidates` ever runs (this task only changes what happens WITHIN the already-allocated running days — it must not touch day-count allocation, which is `GoalDrivenPlanSelectionBuilder`'s existing, unmodified layer from the first plan's Task 4); (c) a profile WITH a credible weekly volume → measurably different (larger) easy/long-run targets than without one, for the same goal; (d) no `cardioRunProfile` at all → byte-for-byte identical to pre-this-task output (extend the existing `testCardioCandidatesWithoutProfileMatchesPreviousOutputExactly`-style regression test, don't replace it).
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement** inside `cardioCandidates`'s `.running` branch. Keep the `.interval` zone's existing distance-only behavior (0.4 km) completely untouched — this round doesn't change interval sizing, only easy/long-run volume and the overall purpose mix.
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Programs/PlanGenerator.swift Tests/FitnessAppCoreTests/PlanGeneratorTests.swift
git commit -m "feat: let a known cardio goal and weekly volume shape generated run structure, not just pace"
```

---

## Task 4: Onboarding copy does not overpromise

**Files:**
- Modify: `Sources/FitnessAppUI/OnboardingView.swift` (the `runCoachCardioGoal` question added by the first plan's Task 5 — check its exact current copy/keys first)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings` only if the existing copy needs correcting (likely NOT a new key — check first whether the existing `onboarding.runCoachGoal.subtitle` already avoids over-promising, or needs a word changed)

**Interfaces:** none new.

- [ ] **Step 1: Read the current onboarding goal-question copy** (title/subtitle keys added by the first plan). Per Decision 2, the generator NOW does use the goal for structure (Tasks 2-3) but still needs a credible weekly volume/reference time for volume/pace specifics — the subtitle should not claim more precision than the generator delivers for a brand-new user with no logged history yet (who, on day one, has no `weeklyBaseVolumeKm`/`current5kReferenceSeconds` at all — those come from later logged activity, see `CardioBaselineCalculator`).
- [ ] **Step 2: If the existing copy already correctly sets this expectation, no change needed** — say so in your report, do not edit copy that's already accurate just to have made a change.
- [ ] **Step 3: If it overpromises, correct it** (e.g. avoid phrasing that implies the FIRST plan will be precisely tailored when the user has logged nothing yet) — smallest possible wording change, DE/EN/TR all updated together, verify with `dead_catalog_v3.py`.
- [ ] **Step 4: Commit** (skip if Step 2 found nothing to change — then this task closes with no commit).

---

## Task 5: Document the three decisions where future reviews will look

**Files:**
- Modify: `docs/PLANUNG_BEGLEITUNG_AUDIT.md` (append, following the same pattern as the first plan's Task 1)

**Interfaces:** none (documentation only).

- [ ] **Step 1: Append a new dated section** (`## Laufcoaching-Remediation-Round-2: drei verbindliche Produktentscheidungen (2026-10-25)`) recording the user's three decisions verbatim in substance (see "The three decisions" above), a pointer to this plan file, and a note that these supersede the first plan's "Important 1"/"onboarding goal" open questions from its final review.
- [ ] **Step 2: Commit**

```bash
git add docs/PLANUNG_BEGLEITUNG_AUDIT.md
git commit -m "docs: record the three binding remediation decisions for laufcoaching round 2"
```

---

## Task 6: Fold feasibility evaluation into CoachAdjustmentCardModel (Decision 3, part 1 — one model carries the suggested goal)

**Files:**
- Modify: `Sources/FitnessAppUI/Cardio/CoachAdjustmentCardModel.swift`
- Test: extend `Tests/FitnessAppUITests/CoachAdjustmentCardModelTests.swift`

**Interfaces:**
- Consumes: `CardioFeasibilityCalculator.evaluate(goal:raceDate:weeklyBaseVolumeKm:)` (existing — already used by `CardioFeasibilityCardModel.make`, now ALSO used here).
- Produces: `CoachAdjustmentCardModel` gains a new stored property, e.g. `public let proposedGoal: CardioGoal?` (name it to match `CardioFeasibilityCardModel.proposedGoal`'s existing convention for consistency). `make(for:activePlan:)` computes it the same way `CardioFeasibilityCardModel.make` already does: run `CardioFeasibilityCalculator.evaluate(...)`, and `proposedGoal = verdict.feasible ? profile.cardioGoal : verdict.suggestedGoal`. If `evaluate(...)` returns `nil` (no race date/weekly volume/goal check applicable), `proposedGoal` should default to `profile.cardioGoal` (no feasibility opinion available, use what the user set) — do NOT make the WHOLE `CoachAdjustmentCardModel.make` return `nil` just because feasibility can't be evaluated; it should still work for a plain "apply current goal" adjustment when there's no race-date/volume to check feasibility against. Read `CardioFeasibilityCardModel.swift:69-97` (`make(for:)`) fully before writing this — you are reusing its exact evaluation logic, not reinventing it; consider whether a small shared private helper between the two models is warranted (your call — if the duplication is small and the two call sites diverge meaningfully in their nil-handling as described above, two call sites is fine per YAGNI; don't force a shared abstraction for its own sake).

- [ ] **Step 1: Write failing tests**: (a) feasible verdict → `proposedGoal == profile.cardioGoal`; (b) infeasible verdict with a smaller achievable goal → `proposedGoal == verdict.suggestedGoal`, NOT `profile.cardioGoal`; (c) no race date/weekly volume set at all → `proposedGoal == profile.cardioGoal` (the "no feasibility opinion, use current" fallback) AND `CoachAdjustmentCardModel.make` still returns non-nil (assuming an active plan + eligible cardio day exist) rather than `nil`.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Cardio/CoachAdjustmentCardModel.swift Tests/FitnessAppUITests/CoachAdjustmentCardModelTests.swift
git commit -m "feat: CoachAdjustmentCardModel now carries the feasibility-suggested goal"
```

---

## Task 7: Preview shows and accept() applies the suggested goal (Decision 3, part 2 — close the dead end)

**Files:**
- Modify: `Sources/FitnessAppUI/Cardio/CoachAdjustmentCardModel.swift` (`accept(plan:profile:in:now:calendar:)`)
- Modify: `Sources/FitnessAppUI/Cardio/CoachAdjustmentPreviewView.swift` (the preview copy/day generation)
- Test: extend `Tests/FitnessAppUITests/CoachAdjustmentCardModelTests.swift` and (if the preview's own content is covered by a test file) its test file too

**Interfaces:**
- Consumes: Task 6's new `proposedGoal` property.
- Produces: `CoachAdjustmentCardModel.accept(...)` uses `self.proposedGoal` (not `profile.cardioGoal` directly) when calling `Self.cardioOnlyDaySpecs(for:cardioRunProfile:)` — so the applied days actually match the SUGGESTED goal. On success, it also sets `profile.cardioGoal = proposedGoal` (mirroring what `CardioFeasibilityCardModel.accept`'s completion closure already does for its own path, per the first plan's Task 7 fix) so the profile stays consistent with what was just applied. `CoachAdjustmentPreviewView` (currently builds `newCardioDays` via `CoachAdjustmentCardModel.cardioOnlyDaySpecs(for: profile.cardioGoal)` — a pre-existing gap flagged but not fixed by the first plan's final review, "Minor 3") must be updated to use `model.proposedGoal` too, so the preview the user sees matches what accepting will actually apply (Decision 3: "Die Anpassungsvorschau soll das tatsächlich vorgeschlagene Ziel anzeigen").

**Failure/rollback (Review Focus 4 — do not regress the first plan's Task 7 fix):** if `accept(...)` throws, `profile.cardioGoal` must be restored to its value before the attempt (same save-then-restore pattern the first plan's Task 7 fix round 2 already established for `CardioFeasibilityCardModel.accept` — read that commit's diff, `108fb64` in the first plan's history, for the exact pattern to replicate here).

- [ ] **Step 1: Write failing tests**: (a) accepting with an infeasible verdict and a suggested smaller goal → the adjusted plan's cardio day content matches `proposedGoal`'s specs (not the stale goal), AND `profile.cardioGoal == proposedGoal` afterward (mirror the first plan's `testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace` test, which covered exactly this for `CardioFeasibilityCardModel` — this task closes the equivalent gap in `CoachAdjustmentCardModel`); (b) a forced save failure during `accept(...)` → `profile.cardioGoal` is restored to its pre-attempt value, mirroring the first plan's `testAcceptRestoresTheOriginalCardioGoalWhenTheInPlaceAdjustmentFails` (reuse the same `PlanGeneratorInstantiator.saveOverrideForTesting` DI seam that test already established); (c) `CoachAdjustmentPreviewView`'s day-generation call uses `model.proposedGoal`, not `profile.cardioGoal` directly (source-introspection check, same style as the rest of this repo's UI tests).
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Cardio/CoachAdjustmentCardModel.swift Sources/FitnessAppUI/Cardio/CoachAdjustmentPreviewView.swift Tests/FitnessAppUITests/CoachAdjustmentCardModelTests.swift
git commit -m "fix: CoachAdjustmentPreviewView previews and applies the suggested goal, not the stale one"
```

---

## Task 8: Pace persists onto the adopted training day (Decision 1)

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/SetRow.swift` (the `cardioSetRow`/`cardioPaceLabel`/placeholder area)
- Modify: `Sources/FitnessAppUI/Workout/ExerciseCard.swift` and/or `Sources/FitnessAppUI/Workout/ActiveWorkoutView.swift` — whichever is the correct place to thread `current5kReferenceSeconds: Int?` down from the existing `@Query private var profiles: [UserBodyProfile]` in `ActiveWorkoutView.swift:89` through to `SetRow` (read both files' existing parameter-threading for other per-user settings, e.g. how `weight_unit`/similar display settings already reach `SetRow`, and follow the SAME existing pattern rather than inventing a new one — this is a read-before-you-write task, the exact threading path is not fully mapped out in this plan).
- Test: new `Tests/FitnessAppUITests/SetRowTargetPaceTests.swift` (source-introspection style, same pattern as the rest of this repo's UI tests)

**Interfaces:**
- Consumes: Task 1's `CardioExerciseZone.forExerciseName(_:)`, the existing `PaceZoneCalculator.easyPaceMinutesPerKm`/`.tempoPaceMinutesPerKm`, `content.nameSnapshot`/`content.isCardio`/`content.targetDurationMinutes` (existing, on `TrainingDayContentSnapshot.ExerciseEntry`).
- Produces: a new small label/line in `SetRow`'s `cardioSetRow`, visible only before the user has entered their own distance/duration (i.e., while the existing `cardioDistancePlaceholder`/`cardioDurationPlaceholder` would show), reading something like "Ziel-Pace: 5:30 /km" when `content.isCardio`, `CardioExerciseZone.forExerciseName(content.nameSnapshot)` is `.easy` or `.tempo`, `content.targetDurationMinutes != nil` (duration-based, matching the existing Task 3/9 constraint that the interval/distance zone never carries a pace), and a live `current5kReferenceSeconds` is available — computed via `PaceCalculator.formatPace(...)` exactly like the existing call sites. When the zone/duration conditions hold but no reference time is available, show the SAME qualitative fallback copy already shipped for the preview (`cardioFeasibility.day.paceUnknown`, reused — not a new key). When `content` isn't a duration-based running exercise at all, show nothing new (zero visual change from today).

- [ ] **Step 1: Write failing tests** asserting: the new label's source reads `content.nameSnapshot` via `CardioExerciseZone`, calls `PaceCalculator.formatPace` for the known-pace case and the existing `cardioFeasibility.day.paceUnknown` key for the unknown case, and that it's gated on `content.isCardio`/duration-based (not touching the `.interval`/distance case).
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Thread `current5kReferenceSeconds` down** from `ActiveWorkoutView`'s existing `@Query` to `SetRow`, following this codebase's existing pattern for threading per-profile display settings through this same view hierarchy (read it first, do not guess).
- [ ] **Step 4: Implement the label** in `SetRow.cardioSetRow`, visually consistent with the existing `cardioPaceLabel`/placeholder styling (small caption, not competing with the live-logging `PACE` display that shows the user's actual typed result).
- [ ] **Step 5: Run tests to verify they pass**
- [ ] **Step 6: Self-review against Review Focus 5** — confirm the pace is computed from the CURRENT `profiles.first?.current5kReferenceSeconds` at render time (a live `@Query`-backed read), never a value frozen anywhere.
- [ ] **Step 7: Commit**

```bash
git add Sources/FitnessAppUI/Workout/SetRow.swift Sources/FitnessAppUI/Workout/ExerciseCard.swift Sources/FitnessAppUI/Workout/ActiveWorkoutView.swift Tests/FitnessAppUITests/SetRowTargetPaceTests.swift
git commit -m "feat: show the live target pace on the adopted training day, not only in previews"
```

---

## Task 9: End-to-end regression pass

**Files:** none new — verification, plus any regression fixes this step uncovers.

- [ ] **Step 1: Run `python .scripts/dead_catalog_v3.py`**, confirm "UNUSED: 0".
- [ ] **Step 2: Trigger Apple CI**, confirm green, with explicit attention to: every test file touched by Tasks 1-8, PLUS the full non-regression list from the first plan's Task 10 (same 16 suites — they must still be green), PLUS the first plan's own Review Focus 1-5 tests (must still pass unchanged).
- [ ] **Step 3: Write and verify one new, explicit end-to-end scenario test** (or a small set of them) that exercises the literal sequence the user named: coach activation → goal selection → plan generation → opening the adjustment preview → accepting → inspecting the adopted day's content. This cannot be a single XCTest method spanning SwiftUI screens (no render harness in this repo) — compose it as a sequence of the already-existing, now-extended model-level calls that back each step (`UserBodyProfile.setEnduranceModality`/`cardioGoal`/`cardioCoachingEnabled` → `GoalDrivenPlanSelectionBuilder.makeSelections(..., cardioRunProfile:)` → `PlanGenerator.generate` → `CoachAdjustmentCardModel.make`/`.proposedGoal` → `.accept(...)` → re-read the resulting `TrainingDay`'s content and assert it matches the proposed goal's structure/pace) in ONE integration-style test in `Tests/FitnessAppDataTests/` (needs a real `ModelContainer`, follow `PlanGeneratorInstantiatorTests`'s established setup pattern) rather than a chain of mocks — this is the closest equivalent to the user's requested end-to-end check that this repo's test infrastructure can express.
- [ ] **Step 4: Commit** only if Steps 1-3 required a fix; otherwise this task closes the plan with no commit of its own.
