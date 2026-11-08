#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqUI
@testable import DeltiqData
import DeltiqCore

/// Kapazitätsprüfung Zielwechsel-Anpassung (HM → Marathon "nicht genug freie Tage"-Bug):
/// analyze() und accept() müssen dieselbe Kapazitätsberechnung verwenden.
/// Kapazitätsregel: Rest + Free kombiniert (addiert), nicht jeweils separat (ODER).
/// Stärkekonversion: (Rest + Free) + Strength kombiniert, nicht Strength allein.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class GoalChangeCapacityTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDownWithError() throws {
        container = nil
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private func previewViewSource() throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent("Cardio/CoachAdjustmentPreviewView.swift"), encoding: .utf8)
    }

    private func cardModelSource() throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent("Cardio/CoachAdjustmentCardModel.swift"), encoding: .utf8)
    }

    private func withoutLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let r = line.range(of: "//") { return line[line.startIndex..<r.lowerBound] }
                return line
            }
            .joined(separator: "\n")
    }

    // MARK: - Source-Introspection: UI capacity fix

    /// .ready-Pfad: Kapazitätsprüfung für "Auf aktuellen Plan anwenden"-Button
    /// muss Rest + Free ADDIEREN, nicht mit ODER prüfen.
    /// Schlägt fehl solange `insertableRestDays.count >= extraNeeded || freeWeekdaysForNewDays.count >= extraNeeded`
    /// statt `(insertableRestDays.count + freeWeekdaysForNewDays.count) >= extraNeeded`.
    func testReadyPath_normalCapacityCombinesRestAndFreeWeekdays() throws {
        let src = withoutLineComments(try previewViewSource())
        // After fix: a local variable `normalCapacity` or combined addition must exist.
        // The OLD buggy pattern: insertableRestDays.count >= extraNeeded followed by || freeWeekdays
        let buggyPattern = "insertableRestDays.count >= extraNeeded"
        XCTAssertFalse(
            src.contains(buggyPattern),
            "BUG: .ready-Pfad prüft insertableRestDays separat statt kombiniert mit freeWeekdaysForNewDays"
        )
        // After fix: combined addition is used
        let combinedPattern = "insertableRestDays.count + model.analysis.freeWeekdaysForNewDays.count"
        let namedCapacity = "normalCapacity"
        XCTAssertTrue(
            src.contains(combinedPattern) || src.contains(namedCapacity),
            "Nach Fix muss die Kapazität als Rest+Free-Summe berechnet werden"
        )
    }

    /// .ready-Pfad: Stärkekonversion-Schwelle muss die bereits verfügbare
    /// Normalkapazität (Rest+Free) einbeziehen, nicht Strength allein prüfen.
    func testReadyPath_strengthSectionUsesTotalCapacityNotStrengthAlone() throws {
        let src = withoutLineComments(try previewViewSource())
        let buggyStrengthCheck = "convertibleStrengthDays.count >= extraNeeded"
        XCTAssertFalse(
            src.contains(buggyStrengthCheck),
            "BUG: Stärke-Schwelle prüft convertibleStrengthDays allein statt totalCapacity"
        )
        let combined = "totalCapacity"
        XCTAssertTrue(
            src.contains(combined),
            "Nach Fix muss totalCapacity = normalCapacity + convertibleStrengthDays.count genutzt werden"
        )
    }

    /// .noEligibleCardioDay-Pfad: identische Kapazitätsregel wie .ready.
    func testNoEligiblePath_normalCapacityCombinesRestAndFreeWeekdays() throws {
        let src = withoutLineComments(try previewViewSource())
        // The old code: `let enoughInsertable = model.analysis.insertableRestDays.count >= newCardioDays(for: model).count`
        // and `let enoughFree = model.analysis.freeWeekdaysForNewDays.count >= desired.count`
        // connected by `if enoughInsertable || enoughFree`
        let buggyA = "enoughInsertable || enoughFree"
        XCTAssertFalse(
            src.contains(buggyA),
            "BUG: .noEligibleCardioDay-Pfad verbindet Einzelprüfungen mit ODER statt kombinierter Summe"
        )
    }

    /// .noEligibleCardioDay-Pfad: Stärkekonversion prüft Gesamtkapazität.
    func testNoEligiblePath_strengthSectionUsesTotalCapacity() throws {
        let src = withoutLineComments(try previewViewSource())
        // After fix: totalCapacity is used in the noEligibleCardioDay branch too,
        // so `convertibleStrengthDays.count >= desired.count` standalone must be gone.
        let buggyStrengthNoEligible = "convertibleStrengthDays.count >= desired.count"
        XCTAssertFalse(
            src.contains(buggyStrengthNoEligible),
            "BUG: .noEligibleCardioDay-Pfad prüft Stärke allein statt Gesamtkapazität"
        )
    }

    // MARK: - Source-Introspection: accept() combined rest+free

    /// accept() muss im else-Zweig (eligibleRestDays < remainderCount) Rest UND freie
    /// Wochentage GEMEINSAM nutzen statt nur freie Wochentage allein zu versuchen.
    func testAcceptElseBranch_combinesRestDaysAndFreeWeekdays() throws {
        let src = try cardModelSource()
        // After fix: when eligibleRestDays.count < remainderCount, the code must use
        // both rest days AND free weekdays — indicated by a combined sufficiency check.
        // The buggy pattern: guard selectedWds.count >= remainderCount (tries free alone).
        // After fix: the guard/condition accounts for restCount + freeCount.
        let combinedGuard = "neededFromFree"  // name used in fixed implementation
        let altCombined = "restCount + "       // alternative: restCount + freeCount >= remainderCount
        XCTAssertTrue(
            src.contains(combinedGuard) || src.contains(altCombined),
            "BUG: accept()-else-Zweig nutzt freie Wochentage allein statt Rest+Free kombiniert"
        )
    }

    // MARK: - Behavioral: combined rest+free in accept()

    /// Rest=1, Free=1 (1 freier Wochentag), remainderCount=2:
    /// combined 1+1=2 reicht — accept() muss alle 3 tenK-Lauftage erzeugen.
    /// Schlägt mit aktuellem Code fehl (guard auf freeWds.count=1 < 2).
    func testAccept_combinedRestAndFree_sufficientForRemainder_succeeds() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        // 1 eligible cardio day (weekday 2)
        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .fullBody, plan: plan)
        context.insert(cardioDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: cardioDay)
        context.insert(run)
        cardioDay.exercises.append(run)
        cardioDay.generationFingerprint = cardioDay.currentContentFingerprint
        plan.days.append(cardioDay)

        // 1 insertable rest day (weekday 3)
        let restDay = TrainingDay(
            name: "Ruhetag", weekday: 3, type: .rest, plan: plan,
            localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
        )
        context.insert(restDay)
        plan.days.append(restDay)

        // Fill weekdays 1,4,5,6 with non-insertable rest so only weekday 7 is free
        for wd in [1, 4, 5, 6] {
            let d = TrainingDay(name: "Ruhetag", weekday: wd, type: .rest, plan: plan)
            context.insert(d)
            plan.days.append(d)
        }
        // weekday 7 is free (not in plan.days) → freeWeekdays = [7]

        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein CoachAdjustmentCardModel erzeugt")
        }
        // tenK braucht 3 Lauftage: 1 eligible + remainderCount=2.
        // insertableRestDays.count=1, freeWeekdays.count=1, combined=2 >= remainderCount=2.
        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(count, 3, "accept() muss alle 3 tenK-Lauftage erzeugen (1 ersetzen + 2 einfügen)")
    }

    // MARK: - Behavioral: HM → Marathon exact bug scenario

    /// Setup: 3 anfassbare Lauftage, 1 anfassbarer Stärketag, 2 Stärketage mit
    /// Trainingshistorie (nicht anfassbar), 1 auto-Ruhetag, 0 freie Wochentage.
    /// Marathon braucht 5 Lauftage: extraNeeded=2, insertableRest=1, convertibleStrength=1.
    /// Combined 1+1=2 ≥ 2 → Stärke-Konversionspfad muss gezeigt werden.
    private func makeHMToMarathonPlan(profile: UserBodyProfile) -> TrainingPlan {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        // 3 anfassbare Lauftage (Wochentage 1-3)
        for wd in 1...3 {
            let d = TrainingDay(name: "Run", weekday: wd, type: .cardio, plan: plan)
            context.insert(d)
            let ex = Exercise(name: "Easy Run", isCardio: true, day: d)
            context.insert(ex)
            d.exercises.append(ex)
            d.generationFingerprint = d.currentContentFingerprint
            plan.days.append(d)
        }

        // 1 anfassbarer Stärketag ohne Sessions (Wochentag 4) → 1 konvertierbarer Tag
        let strengthDay = TrainingDay(name: "Legs", weekday: 4, type: .legs, plan: plan)
        context.insert(strengthDay)
        let squat = Exercise(name: "Squat", sets: 3, orderIndex: 0, primaryMuscle: .quads, day: strengthDay)
        context.insert(squat)
        strengthDay.exercises.append(squat)
        strengthDay.generationFingerprint = strengthDay.currentContentFingerprint
        plan.days.append(strengthDay)

        // 2 Stärketage MIT Session (Wochentage 5-6) → nicht konvertierbar
        for wd in 5...6 {
            let d = TrainingDay(name: "Push", weekday: wd, type: .chest, plan: plan)
            context.insert(d)
            let ex = Exercise(name: "Bench Press", sets: 3, orderIndex: 0, day: d)
            context.insert(ex)
            d.exercises.append(ex)
            d.generationFingerprint = d.currentContentFingerprint
            let session = WorkoutSession(startTime: Date(), day: d)
            context.insert(session)
            d.sessions.append(session)
            plan.days.append(d)
        }

        // 1 auto-Ruhetag (Wochentag 7) → 1 einfügbarer Ruhetag
        let restDay = TrainingDay(
            name: "Ruhetag", weekday: 7, type: .rest, plan: plan,
            localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
        )
        context.insert(restDay)
        plan.days.append(restDay)
        // Alle 7 Wochentage besetzt → freeWeekdays = []

        return plan
    }

    private func makeMarathonProfile() -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .marathon
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 30)
        profile.weeklyBaseVolumeKm = 50
        context.insert(profile)
        return profile
    }

    /// Analyse gibt für das HM→Marathon-Szenario genau 1 einfügbaren Ruhetag zurück.
    func testHMToMarathon_analysisShowsOneInsertableRestDay() throws {
        let profile = makeMarathonProfile()
        let plan = makeHMToMarathonPlan(profile: profile)
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        XCTAssertEqual(model.analysis.insertableRestDays.count, 1,
            "Szenario-Voraussetzung: genau 1 auto-Ruhetag einfügbar")
    }

    /// Analyse gibt für das HM→Marathon-Szenario genau 1 konvertierbaren Stärketag zurück.
    func testHMToMarathon_analysisShowsOneConvertibleStrengthDay() throws {
        let profile = makeMarathonProfile()
        let plan = makeHMToMarathonPlan(profile: profile)
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        XCTAssertEqual(model.analysis.convertibleStrengthDays.count, 1,
            "Szenario-Voraussetzung: genau 1 Stärketag konvertierbar (kein Session, Marathon braucht 0 Stärketage)")
    }

    /// Kombinierte Kapazität (Ruhetag + Stärketag) deckt extraNeeded=2 — belegt, dass
    /// die UI die Stärke-Konversionsoption zeigen MUSS statt "notEnoughRoom".
    func testHMToMarathon_combinedCapacityCoversExtraNeeded() throws {
        let profile = makeMarathonProfile()
        let plan = makeHMToMarathonPlan(profile: profile)
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        guard case .ready(let ids) = model.analysis.cardioAvailability else {
            return XCTFail("erwartet .ready, da 3 anfassbare Lauftage vorhanden")
        }
        let desiredCount = 5  // Marathon
        let extraNeeded = max(0, desiredCount - ids.count)
        XCTAssertEqual(extraNeeded, 2, "Szenario: 5 Marathon - 3 anfassbare Lauftage = 2 fehlende")
        let normalCapacity = model.analysis.insertableRestDays.count + model.analysis.freeWeekdaysForNewDays.count
        let totalCapacity = normalCapacity + model.analysis.convertibleStrengthDays.count
        XCTAssertGreaterThanOrEqual(totalCapacity, extraNeeded,
            "totalCapacity=\(totalCapacity) muss extraNeeded=\(extraNeeded) decken → Stärke-Sektion soll gezeigt werden")
        XCTAssertLessThan(normalCapacity, extraNeeded,
            "normalCapacity=\(normalCapacity) allein reicht NICHT → kein normaler Apply-Button")
    }

    /// accept(convertStrengthDaysIfNeeded: true) muss im HM→Marathon-Szenario
    /// alle 5 Marathon-Lauftage erzeugen.
    func testHMToMarathon_acceptWithStrengthConversion_returnsFive() throws {
        let profile = makeMarathonProfile()
        let plan = makeHMToMarathonPlan(profile: profile)
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context, convertStrengthDaysIfNeeded: true)
        XCTAssertEqual(count, 5, "Stärke-Konversionspfad muss 5 Marathon-Lauftage erzeugen")
    }

    /// accept() OHNE Stärkekonversion muss im HM→Marathon-Szenario 0 zurückgeben
    /// (Kapazität insufficient → korrekte Schranke).
    func testHMToMarathon_acceptWithoutStrengthConversion_returnsZero() throws {
        let profile = makeMarathonProfile()
        let plan = makeHMToMarathonPlan(profile: profile)
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context, convertStrengthDaysIfNeeded: false)
        XCTAssertEqual(count, 0, "ohne Stärkekonversion: 1 Ruhetag < 2 benötigt → accept() muss 0 zurückgeben")
    }

    // MARK: - Behavioral: Finding A — eligibleDays.isEmpty combined rest+free

    /// T1: 1 Ruhetag + 1 freier Wochentag, desired=2 → insertCombined liefert 2,
    /// beide Tage erhalten type == .cardio (kein partielles Ergebnis).
    func testFindingA_insertCombined_oneRest_oneFree_inserts2() throws {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let restDay = TrainingDay(
            name: "Ruhetag", weekday: 3, type: .rest, plan: plan,
            localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
        )
        context.insert(restDay)
        plan.days.append(restDay)
        // wd4-6 besetzt damit wd7 frei bleibt
        for wd in [4, 5, 6] {
            let d = TrainingDay(name: "Ruhetag", weekday: wd, type: .rest, plan: plan)
            context.insert(d)
            plan.days.append(d)
        }
        try context.save()

        let spec = DaySpec(name: "Run", type: .cardio, sequenceIndex: 1, exercises: [])
        let count = try PlanGeneratorInstantiator.insertCoachCardioDaysUsingRestAndFreeWeekdays(
            plan: plan, restDays: [restDay], weekdays: [7],
            newCardioDays: [spec, spec], in: context
        )

        XCTAssertEqual(count, 2, "rest=1 + free=1 → 2 neue Cardio-Tage erwartet")
        let cardioDays = plan.days.filter { $0.type == .cardio }
        XCTAssertEqual(cardioDays.count, 2, "beide Tage müssen type == .cardio haben")
        XCTAssertEqual(restDay.type, .cardio, "Ruhetag wd3 muss in .cardio umgewandelt worden sein")
    }

    /// T2: Gleiche Ausgangslage aber kein freier Wochentag → guard wirft
    /// insufficientRestDays BEVOR jede Mutation, plan.days unverändert.
    func testFindingA_insertCombined_insufficientCapacity_throwsBeforeMutation() throws {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let restDay = TrainingDay(
            name: "Ruhetag", weekday: 3, type: .rest, plan: plan,
            localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
        )
        context.insert(restDay)
        plan.days.append(restDay)
        try context.save()

        let spec = DaySpec(name: "Run", type: .cardio, sequenceIndex: 1, exercises: [])
        let daysBefore = plan.days.count

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDaysUsingRestAndFreeWeekdays(
                plan: plan, restDays: [restDay], weekdays: [],
                newCardioDays: [spec, spec], in: context
            )
        ) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.CardioInsertionError, .insufficientRestDays)
        }
        XCTAssertEqual(plan.days.count, daysBefore, "bei Kapazitätsfehler: keine Mutation")
        XCTAssertEqual(restDay.type, .rest, "Ruhetag-Typ muss unverändert .rest bleiben")
    }

    /// T3: Save-Fehler nach den in-memory-Mutationen → revert stellt ALLE Änderungen
    /// zurück; frischer Kontext auf demselben In-Memory-Store bestätigt: weder
    /// Ruhetag-Konvertierung noch neuer Cardio-Tag wurden persistiert.
    func testFindingA_insertCombined_saveFailure_noPartialPersistentChange() throws {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let restDay = TrainingDay(
            name: "Ruhetag", weekday: 3, type: .rest, plan: plan,
            localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
        )
        context.insert(restDay)
        plan.days.append(restDay)
        // wd4-6 besetzt damit wd7 frei bleibt
        for wd in [4, 5, 6] {
            let d = TrainingDay(name: "Ruhetag", weekday: wd, type: .rest, plan: plan)
            context.insert(d)
            plan.days.append(d)
        }
        try context.save()
        let daysBefore = plan.days.count

        // Save-Fehler simulieren: alle in-memory-Mutationen finden statt, aber save schlägt fehl
        struct TestSaveError: Error {}
        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        let spec = DaySpec(name: "Run", type: .cardio, sequenceIndex: 1, exercises: [])
        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDaysUsingRestAndFreeWeekdays(
                plan: plan, restDays: [restDay], weekdays: [7],
                newCardioDays: [spec, spec], in: context
            )
        ) { error in
            XCTAssert(error is TestSaveError)
        }

        // In-Memory-Rollback
        XCTAssertEqual(restDay.type, .rest, "Ruhetag wd3 muss nach Rollback wieder .rest sein")
        XCTAssertEqual(plan.days.count, daysBefore,
            "kein neuer Tag auf wd7 darf im plan.days-Array stehen")

        // Persistenz-Verifikation: frischer Kontext zeigt nur den initial gespeicherten Zustand
        let freshCtx = ModelContext(container)
        let storedDays = try freshCtx.fetch(FetchDescriptor<TrainingDay>())
        XCTAssertNil(storedDays.first { $0.weekday == 7 },
            "kein Tag auf wd7 darf im Store persistiert sein")
        XCTAssertEqual(storedDays.first { $0.weekday == 3 }?.type, .rest,
            "Ruhetag wd3 muss im Store weiterhin type .rest haben")
    }

    /// T4: eligibleDays.isEmpty + eligibleRestDays.isEmpty → freeWds-Pfad (bestehend).
    func testFindingA_accept_eligibleDaysEmpty_onlyFreeWeekdays_insertsCorrectly() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        // 3 Stärketage, keine Auto-Ruhetage → eligibleRestDays.isEmpty
        for wd in [1, 2, 3] {
            let d = TrainingDay(name: "Legs", weekday: wd, type: .legs, plan: plan)
            context.insert(d)
            let ex = Exercise(name: "Squat", sets: 3, orderIndex: 0, primaryMuscle: .quads, day: d)
            context.insert(ex)
            d.exercises.append(ex)
            d.generationFingerprint = d.currentContentFingerprint
            plan.days.append(d)
        }
        // wd4-7 sind frei
        try context.save()
        let daysBefore = plan.days.count

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell erzeugt — freeWds-Kapazität sollte genügen")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(count, 0, "freeWds-Pfad: mindestens 1 Cardio-Tag eingefügt")
        XCTAssertEqual(plan.days.count, daysBefore + count,
            "freeWds-Pfad erzeugt neue TrainingDay-Objekte")
        let cardioDays = plan.days.filter { $0.type == .cardio }
        XCTAssertEqual(cardioDays.count, count, "eingefügte Tage sind type .cardio")
    }

    /// T5: eligibleDays.isEmpty + eligibleRestDays.count >= desired → reiner Rest-Pfad (bestehend).
    func testFindingA_accept_eligibleDaysEmpty_enoughRestDaysAlone_insertsCorrectly() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        // 1 Stärketag, 4 Auto-Ruhetage (mehr als tenK braucht) → reiner Rest-Pfad
        let strengthDay = TrainingDay(name: "Legs", weekday: 1, type: .legs, plan: plan)
        context.insert(strengthDay)
        let squat = Exercise(name: "Squat", sets: 3, orderIndex: 0, primaryMuscle: .quads, day: strengthDay)
        context.insert(squat)
        strengthDay.exercises.append(squat)
        strengthDay.generationFingerprint = strengthDay.currentContentFingerprint
        plan.days.append(strengthDay)
        for wd in [2, 3, 4, 5] {
            let d = TrainingDay(
                name: "Ruhetag", weekday: wd, type: .rest, plan: plan,
                localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
            )
            context.insert(d)
            plan.days.append(d)
        }
        try context.save()
        let daysBefore = plan.days.count

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell erzeugt")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(count, 0, "reiner Rest-Pfad: Cardio-Tage aus Ruhetagen eingefügt")
        XCTAssertEqual(plan.days.count, daysBefore,
            "reiner Rest-Pfad: keine neuen Tage, nur vorhandene Ruhetage umgewandelt")
    }

    /// T6: Manuell bearbeitete und abgeschlossene Einheiten bleiben unverändert
    /// nach accept() mit kombiniertem Rest+Free-Pfad (eligibleDays.isEmpty).
    func testFindingA_accept_eligibleDaysEmpty_combined_preservesCompletedSessions() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        // 1 Stärketag MIT abgeschlossener Session — muss unverändert bleiben
        let completedDay = TrainingDay(name: "Legs", weekday: 1, type: .legs, plan: plan)
        context.insert(completedDay)
        let squat = Exercise(name: "Squat", sets: 3, orderIndex: 0, primaryMuscle: .quads, day: completedDay)
        context.insert(squat)
        completedDay.exercises.append(squat)
        completedDay.generationFingerprint = completedDay.currentContentFingerprint
        let session = WorkoutSession(startTime: Date(), day: completedDay)
        context.insert(session)
        completedDay.sessions.append(session)
        plan.days.append(completedDay)

        // 2 Auto-Ruhetage (restCount=2 < tenK=3 → neededFromFree=1 → kombinierter Pfad)
        for wd in [2, 3] {
            let d = TrainingDay(
                name: "Ruhetag", weekday: wd, type: .rest, plan: plan,
                localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
            )
            context.insert(d)
            plan.days.append(d)
        }
        // wd4-6 nicht-einfügbare Ruhetage, wd7 ist frei
        for wd in [4, 5, 6] {
            let d = TrainingDay(name: "Ruhetag", weekday: wd, type: .rest, plan: plan)
            context.insert(d)
            plan.days.append(d)
        }
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell erzeugt")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(count, 0, "kombinierter Pfad: Cardio-Tage eingefügt")

        // Abgeschlossene Session und Stärketag-Daten dürfen nicht angetastet worden sein
        XCTAssertEqual(completedDay.sessions.count, 1,
            "abgeschlossene Session muss nach accept() erhalten bleiben")
        XCTAssertEqual(completedDay.name, "Legs", "manuell benannter Tag muss unverändert bleiben")
        XCTAssertEqual(completedDay.type, .legs, "Stärketag-Typ muss unverändert bleiben")
        XCTAssertEqual(completedDay.activeExercises.count, 1,
            "Stärkeübung muss unverändert erhalten bleiben")
    }

    /// Regressions-Schutz: accept() mit genug Ruhetagen allein muss weiterhin funktionieren.
    func testAccept_sufficientRestDaysAlone_succeeds() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .fullBody, plan: plan)
        context.insert(cardioDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: cardioDay)
        context.insert(run)
        cardioDay.exercises.append(run)
        cardioDay.generationFingerprint = cardioDay.currentContentFingerprint
        plan.days.append(cardioDay)

        // 2 auto-Ruhetage reichen für remainderCount=2 allein
        for wd in [3, 4] {
            let d = TrainingDay(
                name: "Ruhetag", weekday: wd, type: .rest, plan: plan,
                localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
            )
            context.insert(d)
            plan.days.append(d)
        }
        try context.save()

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("kein Modell")
        }
        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(count, 3, "2 Ruhetage allein reichen für 2 fehlende tenK-Lauftage")
    }
}
#endif
