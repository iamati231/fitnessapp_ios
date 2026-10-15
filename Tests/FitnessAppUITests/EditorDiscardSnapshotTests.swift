#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// UI-Refactor (Korrektur, Punkt 5; erweitert um die 3. Korrektur-Runde
/// V1-V3): gezielte Tests fuer die Capture/Apply/Equatable-Vertraege der
/// vier Editor-Snapshot-Structs (`ExerciseSnapshot`, `TrainingDaySnapshot`,
/// `PlanMetaSnapshot`, `ProfileMetaSnapshot`) UND fuer die `internal`
/// Pure-Logic-Funktionen, die `PlanEditorView`/`DayEditorView` fuer
/// Reorder-Discard (V1) und Plan-Reaktivierung (V3) tragen. Diese Structs/
/// Funktionen sind `internal` (nicht `public`), deshalb `@testable import
/// FitnessAppUI`.
///
/// Diese Datei ist wie ihre Produktionsdateien `#if canImport(SwiftUI) &&
/// canImport(SwiftData)`-gegated und existiert auf Linux schlicht nicht
/// (die Bedingung ist dort `false`) — sie kompiliert und laeuft NUR auf
/// einem Apple-Runner (z.B. dem macOS-CI-Runner, der dieses Package schon
/// heute baut, siehe Kommentare in DayEditorView.swift/PlanEditorView.swift
/// zu `Mindestversion macOS 14`). Linux-`swift test` ist fuer diese Datei
/// keine Verifikation — das gilt fuer alle SwiftUI-gegateten Dateien dieses
/// Pakets, nicht nur fuer diese.
///
/// V1/V3-Tests instanziieren `PlanEditorView`/`DayEditorView` direkt als
/// reinen Struct-Wert (ueber ihren oeffentlichen `init(plan:)`/`init(day:)`)
/// und rufen NUR `internal` Funktionen auf, die ausschliesslich den
/// uebergebenen `plan`/`day` (ein `@Bindable`-Parameter — ein normaler
/// Objekt-Verweis, kein SwiftUI-Rendering noetig) sowie ihre eigenen,
/// EXPLIZITEN Parameter anfassen (`comparedTo:`/`usingSnapshot:`/
/// `otherActivePlanIDAtOpen:amongCandidates:`) — nie `@Query`- oder
/// `@Environment`-rueckgebundene Properties (`allPlans`, `modelContext`,
/// `dismiss`, `navigation`). Deshalb ist das Konstruieren der View hier
/// sicher, obwohl kein echter SwiftUI-/`.modelContainer`-Rendering-Kontext
/// existiert.
///
/// Was hier NACH WIE VOR NICHT getestet wird (braucht einen echten View-/
/// UI-Test-Harness, den dieses Repo nicht hat): die eigentliche View-
/// Verdrahtung (DeltiqHeader-Chevron/Checkmark, Discard-Dialog, `.onChange`-
/// Unterdrueckung waehrend eines Reverts, `.interactiveDismissDisabled`/
/// `.deltiqSwipeBackEnabled`, `.onAppear`s Erfassung von
/// `otherActivePlanIDAtOpen` aus der LIVE `allPlans`-Query) sowie
/// Cross-Entity-Seiteneffekte, die nicht in einer der hier getesteten reinen
/// Funktionen liegen (Custom-Template-Ruecksync in `ExerciseEditorView.
/// revertToSnapshot()`). Diese bleiben nur per echtem Geraete-/Simulator-
/// Test verifizierbar.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class EditorDiscardSnapshotTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - ExerciseSnapshot

    func testExerciseSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(name: "Bankdrücken", sets: 4, repsMin: 6, repsMax: 10, notes: "locker")
        ctx.insert(exercise)

        let snapshot = ExerciseSnapshot.capture(from: exercise)
        snapshot.apply(to: exercise)

        XCTAssertEqual(exercise.sets, 4)
        XCTAssertEqual(exercise.repsMin, 6)
        XCTAssertEqual(exercise.repsMax, 10)
        XCTAssertEqual(exercise.notes, "locker")
    }

    func testExerciseSnapshotDetectsFieldChange() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(name: "Kniebeuge", sets: 3)
        ctx.insert(exercise)

        let snapshot = ExerciseSnapshot.capture(from: exercise)
        exercise.sets = 5
        XCTAssertNotEqual(snapshot, ExerciseSnapshot.capture(from: exercise))
    }

    /// Kernvertrag von `revertToSnapshot()`: mehrere Felder gleichzeitig
    /// geaendert (inkl. Custom-Metadaten), ein einziges `apply(to:)` muss
    /// ALLE wieder auf den Ausgangszustand bringen — kein Teil-Rollback.
    func testExerciseSnapshotApplyRevertsMultipleFieldsAtOnce() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(
            name: "Eigene Übung", sets: 3, repsMin: 8, repsMax: 12,
            isCardio: false, isCompound: false,
            primaryMuscle: .chest, equipment: .bodyweight
        )
        ctx.insert(exercise)
        let snapshot = ExerciseSnapshot.capture(from: exercise)

        exercise.sets = 10
        exercise.isCardio = true
        exercise.isCompound = true
        exercise.primaryMuscle = .back
        exercise.equipment = .barbell
        exercise.notes = "geändert"
        XCTAssertNotEqual(snapshot, ExerciseSnapshot.capture(from: exercise))

        snapshot.apply(to: exercise)
        XCTAssertEqual(exercise.sets, 3)
        XCTAssertFalse(exercise.isCardio)
        XCTAssertFalse(exercise.isCompound)
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(exercise.equipment, .bodyweight)
        XCTAssertNil(exercise.notes)
        XCTAssertEqual(snapshot, ExerciseSnapshot.capture(from: exercise))
    }

    // MARK: - TrainingDaySnapshot

    func testTrainingDaySnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Push Day", weekday: 2, type: .custom, nextIntensity: .heavy)
        ctx.insert(day)

        let snapshot = TrainingDaySnapshot.capture(from: day)
        snapshot.apply(to: day)

        XCTAssertEqual(day.weekday, 2)
        XCTAssertEqual(day.type, .custom)
        XCTAssertEqual(day.nextIntensity, .heavy)
    }

    /// `metaSection`-Scope (siehe Doc-Kommentar am Struct): Typ-Wechsel auf
    /// `.rest` und zurueck ist das zentrale Szenario fuer die
    /// Ruhetag-Darstellung — muss vollstaendig revertierbar sein.
    func testTrainingDaySnapshotRevertsTypeAndTimeFormatChange() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Montag", weekday: 2, type: .custom)
        ctx.insert(day)
        let snapshot = TrainingDaySnapshot.capture(from: day)

        day.type = .rest
        day.timeFormat = .amrap
        day.timeCapMinutes = 20
        XCTAssertNotEqual(snapshot, TrainingDaySnapshot.capture(from: day))

        snapshot.apply(to: day)
        XCTAssertEqual(day.type, .custom)
        XCTAssertNil(day.timeFormat)
        XCTAssertNil(day.timeCapMinutes)
    }

    // MARK: - PlanMetaSnapshot

    func testPlanMetaSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Mein Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        ctx.insert(plan)

        let snapshot = PlanMetaSnapshot.capture(from: plan)
        snapshot.apply(to: plan)

        XCTAssertEqual(plan.weeks, 8)
        XCTAssertTrue(plan.isActive)
        XCTAssertEqual(plan.targetEnvironment, .gym)
    }

    /// Kernvertrag der Korrektur: `targetEnvironment` UND `isActive` sind
    /// jetzt Teil des Snapshots (vorher bewusst ausgeschlossen) — ein
    /// einziges `apply(to:)` muss beide zusammen mit den einfachen Feldern
    /// zuruecksetzen.
    func testPlanMetaSnapshotRevertsEnvironmentAndActiveFlagTogether() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Plan A", weeks: 12, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let snapshot = PlanMetaSnapshot.capture(from: plan)

        plan.weeks = 4
        plan.isActive = true
        plan.targetEnvironment = .homeGym
        XCTAssertNotEqual(snapshot, PlanMetaSnapshot.capture(from: plan))

        snapshot.apply(to: plan)
        XCTAssertEqual(plan.weeks, 12)
        XCTAssertFalse(plan.isActive)
        XCTAssertEqual(plan.targetEnvironment, .gym)
        XCTAssertEqual(snapshot, PlanMetaSnapshot.capture(from: plan))
    }

    // MARK: - ProfileMetaSnapshot

    func testProfileMetaSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            trainingGoal: .hybrid
        )
        ctx.insert(profile)

        let snapshot = ProfileMetaSnapshot.capture(from: profile)
        snapshot.apply(to: profile)

        XCTAssertEqual(profile.heightCm, 180)
        XCTAssertEqual(profile.profile, .male)
        XCTAssertEqual(profile.trainingGoal, .hybrid)
    }

    /// Szenario aus `ProfileEditorView.revertToSnapshot()`s Doc-Kommentar:
    /// Cardio-Felder gemeinsam geaendert, ein `apply(to:)` muss alle
    /// zuruecksetzen (der `fiveKReferenceText`-Puffer-Resync selbst ist
    /// View-State und bleibt hier unteilbar ungetestet, siehe Datei-Header).
    func testProfileMetaSnapshotRevertsCardioFieldsTogether() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 170, profile: .female,
            cardioCoachingEnabled: false, cardioGoal: .generalFitness
        )
        ctx.insert(profile)
        let snapshot = ProfileMetaSnapshot.capture(from: profile)

        profile.cardioCoachingEnabled = true
        profile.cardioGoal = .marathon
        profile.current5kReferenceSeconds = 1500
        profile.weeklyWorkoutGoal = 6
        XCTAssertNotEqual(snapshot, ProfileMetaSnapshot.capture(from: profile))

        snapshot.apply(to: profile)
        XCTAssertFalse(profile.cardioCoachingEnabled)
        XCTAssertEqual(profile.cardioGoal, .generalFitness)
        XCTAssertNil(profile.current5kReferenceSeconds)
        XCTAssertEqual(profile.weeklyWorkoutGoal, 1)
    }

    // MARK: - Korrektur-Runde 3 (V1/V2/V3)

    /// Korrektur V2: `rebaselineTargetEnvironment()` (PlanEditorView) macht
    /// NUR `targetEnvironment` zur neuen Baseline — ein zu diesem Zeitpunkt
    /// noch offener, unabhaengiger Formular-Edit (`customName`) muss
    /// weiterhin dirty UND per Discard revertierbar bleiben. Ein frueheres
    /// volles `PlanMetaSnapshot.capture(from:)` (das jetzt behobene V2-
    /// Problem) haette beide Aenderungen faelschlich gemeinsam bestaetigt.
    func testPlanMetaSnapshotTargetedRebaselineLeavesOtherFieldsDirty() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Plan A", weeks: 12, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        var snapshot = PlanMetaSnapshot.capture(from: plan)

        // Zwei unabhaengige, gleichzeitig offene Aenderungen:
        plan.customName = "Mein Plan"        // noch unbestaetigter Formular-Edit
        plan.targetEnvironment = .homeGym    // wird GLEICH ueber Adapt/Restore bestaetigt
        XCTAssertNotEqual(snapshot, PlanMetaSnapshot.capture(from: plan))

        // Entspricht exakt PlanEditorView.rebaselineTargetEnvironment().
        snapshot.targetEnvironment = plan.targetEnvironment

        XCTAssertEqual(snapshot.targetEnvironment, plan.targetEnvironment, "targetEnvironment gilt jetzt als bestaetigt")
        XCTAssertNotEqual(snapshot, PlanMetaSnapshot.capture(from: plan), "customName bleibt ein offener, dirty Edit")
        XCTAssertNotEqual(snapshot.customName, plan.customName)

        snapshot.apply(to: plan)
        XCTAssertNil(plan.customName, "customName muss beim Verwerfen zurueckgerollt werden")
        XCTAssertEqual(plan.targetEnvironment, .homeGym, "targetEnvironment bleibt bestaetigt, kein Rollback")
    }

    /// Korrektur V1 (PlanEditorView): reines Umsortieren der Tage (Wochentage
    /// rotiert, siehe `moveDays`) OHNE jede andere Aenderung muss als dirty
    /// erkannt und exakt zurueckgerollt werden.
    func testPlanEditorViewDetectsAndRevertsDayReorder() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let monday = TrainingDay(name: "A", weekday: 2, type: .custom, plan: plan)
        let wednesday = TrainingDay(name: "B", weekday: 4, type: .custom, plan: plan)
        ctx.insert(monday)
        ctx.insert(wednesday)

        let view = PlanEditorView(plan: plan)
        let weekdayAtOpen: [PersistentIdentifier: Int] = [
            monday.persistentModelID: monday.weekday,
            wednesday.persistentModelID: wednesday.weekday
        ]
        XCTAssertFalse(view.dayOrderIsDirty(comparedTo: weekdayAtOpen))

        // Simuliert einen Drag&Drop-Reorder (siehe `moveDays`): die beiden
        // Wochentag-Werte tauschen den Platz.
        monday.weekday = 4
        wednesday.weekday = 2
        XCTAssertTrue(view.dayOrderIsDirty(comparedTo: weekdayAtOpen))

        view.revertDayOrder(usingSnapshot: weekdayAtOpen)
        XCTAssertEqual(monday.weekday, 2)
        XCTAssertEqual(wednesday.weekday, 4)
        XCTAssertFalse(view.dayOrderIsDirty(comparedTo: weekdayAtOpen))
    }

    /// Korrektur V1: ein NEU angelegter Tag (kein Eintrag im Open-Snapshot)
    /// bleibt beim Reorder-Revert unangetastet — Anlegen ist eine eigene,
    /// sofort wirksame Aktion (siehe `dayWeekdayAtOpen`-Doc).
    func testPlanEditorViewIgnoresNewlyAddedDayInReorderRevert() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let monday = TrainingDay(name: "A", weekday: 2, type: .custom, plan: plan)
        ctx.insert(monday)

        let view = PlanEditorView(plan: plan)
        let weekdayAtOpen: [PersistentIdentifier: Int] = [monday.persistentModelID: monday.weekday]

        let newDay = TrainingDay(name: "C", weekday: 7, type: .custom, plan: plan)
        ctx.insert(newDay)
        XCTAssertFalse(view.dayOrderIsDirty(comparedTo: weekdayAtOpen), "Ein neuer Tag allein ist kein Reorder")

        view.revertDayOrder(usingSnapshot: weekdayAtOpen)
        XCTAssertEqual(newDay.weekday, 7, "Neu angelegte Tage bleiben beim Reorder-Revert unangetastet")
    }

    /// Korrektur V1 (DayEditorView): reines Umsortieren der Uebungen
    /// (`orderIndex`, siehe `moveExercises`) OHNE jede andere Aenderung muss
    /// als dirty erkannt und exakt zurueckgerollt werden.
    func testDayEditorViewDetectsAndRevertsExerciseReorder() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Tag", weekday: 2, type: .custom)
        ctx.insert(day)
        let first = Exercise(name: "Bankdrücken", orderIndex: 0, day: day)
        let second = Exercise(name: "Kniebeuge", orderIndex: 1, day: day)
        ctx.insert(first)
        ctx.insert(second)

        let view = DayEditorView(day: day)
        let orderAtOpen: [PersistentIdentifier: Int] = [
            first.persistentModelID: first.orderIndex,
            second.persistentModelID: second.orderIndex
        ]
        XCTAssertFalse(view.exerciseOrderIsDirty(comparedTo: orderAtOpen))

        first.orderIndex = 1
        second.orderIndex = 0
        XCTAssertTrue(view.exerciseOrderIsDirty(comparedTo: orderAtOpen))

        view.revertExerciseOrder(usingSnapshot: orderAtOpen)
        XCTAssertEqual(first.orderIndex, 0)
        XCTAssertEqual(second.orderIndex, 1)
        XCTAssertFalse(view.exerciseOrderIsDirty(comparedTo: orderAtOpen))
    }

    /// Korrektur V1: eine NEU hinzugefuegte Uebung (kein Eintrag im
    /// Open-Snapshot) bleibt beim Reorder-Revert unangetastet — Hinzufuegen
    /// ist eine eigene, sofort wirksame Aktion (siehe
    /// `exerciseOrderIndexAtOpen`-Doc).
    func testDayEditorViewIgnoresNewlyAddedExerciseInReorderRevert() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Tag", weekday: 2, type: .custom)
        ctx.insert(day)
        let first = Exercise(name: "Bankdrücken", orderIndex: 0, day: day)
        ctx.insert(first)

        let view = DayEditorView(day: day)
        let orderAtOpen: [PersistentIdentifier: Int] = [first.persistentModelID: first.orderIndex]

        let added = Exercise(name: "Kniebeuge", orderIndex: 1, day: day)
        ctx.insert(added)
        XCTAssertFalse(view.exerciseOrderIsDirty(comparedTo: orderAtOpen), "Eine neue Uebung allein ist kein Reorder")

        view.revertExerciseOrder(usingSnapshot: orderAtOpen)
        XCTAssertEqual(added.orderIndex, 1, "Neu hinzugefuegte Uebungen bleiben beim Reorder-Revert unangetastet")
    }

    /// Korrektur V3 — das eigentliche gemeldete Szenario: Plan A ist aktiv,
    /// User oeffnet den Editor fuer Plan B, schaltet B an (verdraengt A ueber
    /// `setActive(true)`) und wieder aus (`setActive(false)` reaktiviert
    /// NIEMANDEN automatisch). A bleibt danach faelschlich inaktiv, obwohl
    /// B wieder exakt im Ausgangszustand ist — `planToReactivateOnDiscard`
    /// muss A trotzdem anhand der beim Oeffnen erfassten ID wiederfinden.
    func testPlanToReactivateOnDiscardSurvivesOnOffToggleSequence() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let planA = TrainingPlan(name: "A", weeks: 8, isActive: true, targetEnvironment: .gym)
        let planB = TrainingPlan(name: "B", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(planA)
        ctx.insert(planB)

        let view = PlanEditorView(plan: planB)
        let otherAtOpen = planA.persistentModelID // von .onAppear erfasst, als B's Editor oeffnete

        // "B einschalten" (wie setActive(true), verdraengt A):
        planA.isActive = false
        planB.isActive = true
        // "B wieder ausschalten" (wie setActive(false), reaktiviert niemanden):
        planB.isActive = false

        XCTAssertFalse(planA.isActive, "A ist nach der Toggle-Sequenz faelschlich inaktiv")
        let found = view.planToReactivateOnDiscard(otherActivePlanIDAtOpen: otherAtOpen, amongCandidates: [planA, planB])
        XCTAssertEqual(found?.persistentModelID, planA.persistentModelID)

        found?.isActive = true
        XCTAssertTrue(planA.isActive)
        XCTAssertFalse(planB.isActive)
    }

    /// Korrektur V3: wurde der andere Plan waehrend der Sitzung nie
    /// angefasst, ist die Reaktivierung ein folgenloses No-Op (schon aktiv).
    func testPlanToReactivateOnDiscardIsNoOpWhenOtherStillActive() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let planA = TrainingPlan(name: "A", weeks: 8, isActive: true, targetEnvironment: .gym)
        let planB = TrainingPlan(name: "B", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(planA)
        ctx.insert(planB)

        let view = PlanEditorView(plan: planB)
        let found = view.planToReactivateOnDiscard(otherActivePlanIDAtOpen: planA.persistentModelID, amongCandidates: [planA, planB])
        XCTAssertEqual(found?.persistentModelID, planA.persistentModelID)
        XCTAssertTrue(found?.isActive ?? false, "A war die ganze Zeit aktiv - Reaktivierung ist ein No-Op")
    }

    /// Korrektur V3: war dieser Plan beim Oeffnen selbst schon aktiv (oder
    /// gar keiner), gibt es keinen "anderen Plan" zu reaktivieren.
    func testPlanToReactivateOnDiscardReturnsNilWhenNoOtherPlanWasActiveAtOpen() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Solo", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let view = PlanEditorView(plan: plan)
        XCTAssertNil(view.planToReactivateOnDiscard(otherActivePlanIDAtOpen: nil, amongCandidates: [plan]))
    }

    /// Korrektur post-Review (Finding 2): `otherActivePlanIDAtOpen == nil`
    /// (kein anderer Plan war beim Oeffnen aktiv) darf NICHT als dirty
    /// gelten. Der urspruengliche `other?.isActive != true`-Vergleich liefert
    /// bei `nil` faelschlich `true` und markiert einen nie angefassten,
    /// inaktiven Plan als dirty.
    func testOtherActivePlanStateIsDirtyIsFalseWhenNoOtherPlanWasActiveAtOpen() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Solo", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let view = PlanEditorView(plan: plan)
        XCTAssertFalse(view.otherActivePlanStateIsDirty(otherActivePlanIDAtOpen: nil, amongCandidates: [plan]))
    }

    /// Korrektur V3 (Regressionsschutz nach Finding-2-Fix): die eigentliche
    /// An-Aus-Toggle-Sequenz muss weiterhin als dirty erkannt werden.
    func testOtherActivePlanStateIsDirtyDetectsOnOffToggleSequence() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let planA = TrainingPlan(name: "A", weeks: 8, isActive: true, targetEnvironment: .gym)
        let planB = TrainingPlan(name: "B", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(planA)
        ctx.insert(planB)

        let view = PlanEditorView(plan: planB)
        let otherAtOpen = planA.persistentModelID

        planA.isActive = false
        planB.isActive = true
        planB.isActive = false

        XCTAssertTrue(view.otherActivePlanStateIsDirty(otherActivePlanIDAtOpen: otherAtOpen, amongCandidates: [planA, planB]))
    }

    /// Korrektur post-Review (Finding 2): blieb der andere Plan die ganze
    /// Zeit aktiv, ist das ein folgenloses No-Op, nicht dirty.
    func testOtherActivePlanStateIsDirtyIsFalseWhenOtherStillActive() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let planA = TrainingPlan(name: "A", weeks: 8, isActive: true, targetEnvironment: .gym)
        let planB = TrainingPlan(name: "B", weeks: 8, isActive: false, targetEnvironment: .gym)
        ctx.insert(planA)
        ctx.insert(planB)

        let view = PlanEditorView(plan: planB)
        XCTAssertFalse(view.otherActivePlanStateIsDirty(otherActivePlanIDAtOpen: planA.persistentModelID, amongCandidates: [planA, planB]))
    }

    // MARK: - Korrektur V4 (MeasurementView)

    /// Korrektur V4: `MeasurementFieldSnapshot` ist die Vergleichsbasis fuer
    /// `MeasurementView.isDirty` — Grundvertrag wie bei den anderen drei
    /// Snapshot-Structs: identischer Feldstand ist gleich, ein veraendertes
    /// Feld macht sie ungleich. Der eigentliche Bug (Haken oben rechts rief
    /// nie `save(profile:)` auf, sondern togglete nur einen Lese-/Editier-
    /// Modus) war reine View-Verdrahtung ohne `@Query`/`@Environment`-freie
    /// Pure-Logic-Stelle und bleibt deshalb — wie die View-seitige
    /// Verdrahtung generell (siehe Datei-Header) — nur per echtem Geraete-/
    /// Simulator-Test verifizierbar: dort muss geprueft werden, dass der
    /// Haken beim Bearbeiten einer bestehenden Messung tatsaechlich
    /// speichert (keine neue Zeile, Werte bleiben nach erneutem Oeffnen).
    func testMeasurementFieldSnapshotEquatableContract() {
        let a = MeasurementFieldSnapshot(weightKg: 82.5, neckCm: 38, waistCm: 85, hipCm: nil, shoulderCm: 110, chestCm: 100, bicepsCm: 35, thighCm: 55, calfCm: 38)
        let sameValues = MeasurementFieldSnapshot(weightKg: 82.5, neckCm: 38, waistCm: 85, hipCm: nil, shoulderCm: 110, chestCm: 100, bicepsCm: 35, thighCm: 55, calfCm: 38)
        XCTAssertEqual(a, sameValues)

        var changed = a
        changed.weightKg = 83.0
        XCTAssertNotEqual(a, changed)
    }

    /// Korrektur V4: der Default-Init (verwendet von `fieldsAtOpen`, bevor
    /// der Edit-Mode-Prefill gelaufen ist) muss parameterlos aufrufbar sein
    /// und alle Felder auf `nil` setzen.
    func testMeasurementFieldSnapshotDefaultInitIsAllNil() {
        let snapshot = MeasurementFieldSnapshot()
        XCTAssertEqual(snapshot, MeasurementFieldSnapshot(
            weightKg: nil, neckCm: nil, waistCm: nil, hipCm: nil,
            shoulderCm: nil, chestCm: nil, bicepsCm: nil, thighCm: nil, calfCm: nil
        ))
    }

    // MARK: - Korrektur post-Review (Finding 3: ProfileEditorView)

    /// Exaktes Szenario aus dem Review: Coaching-Ton aendern (offener,
    /// unbestaetigter Formular-Edit) -> Cardio-Aktion bestaetigen (eigene,
    /// bereits abgeschlossene Aktion, setzt `cardioGoal` + rebaselined NUR
    /// dieses Feld via `rebaselineCardioGoal()`) -> Verwerfen. Der
    /// urspruengliche Bug (volles `rebaselineSnapshot()` nach jeder
    /// Feasibility-Aktion) haette den Coaching-Ton-Edit faelschlich mit
    /// bestaetigt; der Discard haette ihn nicht mehr zurueckgerollt.
    func testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            coachingTone: .analytical, cardioGoal: .generalFitness
        )
        ctx.insert(profile)

        let view = ProfileEditorView(profile: profile)

        // Unabhaengiger, noch offener Formular-Edit:
        profile.coachingTone = .motivating
        // Cardio-Aktion wird ueber ihre eigene, separate CTA bestaetigt
        // (entspricht `CardioFeasibilityCardModel.accept` + direkt folgendem
        // `rebaselineCardioGoal()`-Aufruf in der View):
        profile.cardioGoal = .marathon
        view.rebaselineCardioGoal()

        view.revertToSnapshot()

        XCTAssertEqual(profile.coachingTone, .analytical, "Unabhaengiger Coaching-Ton-Edit muss beim Verwerfen zurueckgerollt werden")
        XCTAssertEqual(profile.cardioGoal, .marathon, "Bestaetigtes cardioGoal bleibt bestehen, kein Teil-Rollback")
    }
}
#endif
