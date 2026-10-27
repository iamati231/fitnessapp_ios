#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
import FitnessAppData
import FitnessAppCore

/// Paket 3a (Laufversäumnis-Hinweis, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// deckt alle 10 vom Auftraggeber verbindlich geforderten Fälle ab.
///
/// Zeitmodell: alle Tests nutzen die FLEXIBLE Wochenkadenz (kein
/// `generatorInput` auf dem Plan -> `usesFixedWeekdays == nil` ->
/// `PlanParticipationEvaluator` faellt konservativ auf
/// `.flexibleWeeklyCadence` zurueck). Das macht die Tests unabhaengig von
/// konkreten Wochentags-Zahlen — nur Tageszaehlung zaehlt. Mit GENAU EINEM
/// identifizierten Lauf-Tag (`nonRestDayCount == 1`, also "1x/Woche
/// angenommen") und einem 14-Tage-Fenster ergibt ein Plan, der schon VOR
/// dem Fenster aktiviert wurde, `elapsedDays == 15` ->
/// `plannedCount == floor(15/7) == 2` — exakt die Paket-3a-Schwelle
/// (`CardioCoachingAdvisor.minimumMissedRunDaysToFlag == 2`), wenn im
/// Fenster nichts geloggt wurde.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MissedRunDaysCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Plan wird in allen Schwellen-Tests lange vor `now` aktiviert, damit
    /// das 14-Tage-Fenster vollständig innerhalb der Planlaufzeit liegt
    /// (siehe Typ-Doku oben). Profil hat zusätzlich ein erreichbares
    /// Laufziel (10K, 20 Wochen, 20 km/Woche Basis — identisch zu
    /// `CoachAdjustmentCardModelTests`), damit `coachAdjustment` in den
    /// Tests, die das brauchen (8/9/10), nicht `nil` ist.
    private func makeProfileAndPlan(
        activatedAt: Date,
        isActive: Bool = true,
        coachEnabled: Bool = true,
        runningDayHasKnownSportKind: Bool = true
    ) -> (profile: UserBodyProfile, plan: TrainingPlan, runDay: TrainingDay) {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: coachEnabled, cardioGoal: .tenK
        )
        // `CardioFeasibilityCalculator.evaluate` (ueber `CoachAdjustmentCardModel.make`)
        // vergleicht `raceDate` gegen das ECHTE `Date()`, nicht gegen die
        // fiktiven Test-Zeitstempel oben (`PlanParticipationEvaluator`/
        // `MissedRunDayEvaluator` bekommen `now`/`calendar` dagegen explizit
        // injiziert) — der Anker muss deshalb am echten "jetzt" haengen,
        // identisch zu `CoachAdjustmentCardModelTests`.
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: isActive, targetEnvironment: .gym)
        plan.activatedAt = activatedAt
        context.insert(plan)

        let runDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(runDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
        if runningDayHasKnownSportKind {
            run.enduranceSportKind = .running
        }
        context.insert(run)
        runDay.exercises.append(run)
        // `RunCoachPlanAdjustment.isEligibleForAdjustment` verlangt einen
        // passenden Generator-Fingerprint (sonst gilt der Tag als "manuell
        // angefasst" und `CoachAdjustmentCardModel.accept` tut nichts) —
        // gleiches Muster wie `CoachAdjustmentCardModelTests.makeProfileAndPlan`.
        runDay.generationFingerprint = runDay.currentContentFingerprint
        plan.days.append(runDay)

        try? context.save()
        return (profile, plan, runDay)
    }

    /// Finding 1 (Lauf-Coaching-Audit): fuegt `count` zusaetzliche, sofort einfuegbare Ruhetage
    /// (`isAutoFilledPlaceholder: true`, identisch zum echten `ProgramInstantiator`-Muster) zu
    /// `plan` hinzu - lokal pro Test, NICHT in `makeProfileAndPlan` selbst, damit die anderen,
    /// nicht `accept()` aufrufenden Tests in dieser Datei unangetastet bleiben.
    private func addEligibleRestDays(count: Int, to plan: TrainingPlan, startingWeekday: Int) {
        for offset in 0..<count {
            let restDay = TrainingDay(
                name: "Ruhetag", weekday: startingWeekday + offset, type: .rest, plan: plan,
                localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
            )
            context.insert(restDay)
            plan.days.append(restDay)
        }
    }

    @discardableResult
    private func logSession(day: TrainingDay, date: Date, outcome: PlanParticipationEvaluator.SessionOccurrence.Outcome) -> WorkoutSession {
        switch outcome {
        case .completed:
            let session = WorkoutSession(startTime: date, endTime: date, isCompleted: true, day: day)
            context.insert(session)
            return session
        case .partial:
            let session = WorkoutSession(startTime: date, endTime: date, isCompleted: false, day: day)
            context.insert(session)
            context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 2, exercise: day.exercises.first, session: session))
            return session
        case .startedOnly:
            let session = WorkoutSession(startTime: date, endTime: date, isCompleted: false, day: day)
            context.insert(session)
            return session
        }
    }

    // MARK: - 1. Coach aus → kein Hinweis

    func testCoachOffYieldsNoHint() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1), coachEnabled: false)
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc))
    }

    // MARK: - 2. Unzureichende/unklare Daten → kein Versäumnis-Hinweis

    func testAmbiguousSportKindYieldsNoHint() throws {
        // Cardio-Tag existiert, aber `enduranceSportKind` ist nicht gepflegt
        // (Altbestand) — darf NIE aus Namen/Typ geraten werden, siehe
        // `MissedRunDayEvaluator.isRunningDay`-Doku. Keine Sessions geloggt,
        // also waere ohne diesen Guard sogar die maximale Versaeumnis-Zahl
        // moeglich — der Hinweis muss trotzdem ausbleiben.
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1), runningDayHasKnownSportKind: false)
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc))
    }

    func testUnknownActivationAnchorYieldsNoHint() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        plan.activatedAt = nil
        try context.save()
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc))
    }

    // MARK: - 3. Schwelle erreicht → genau ein verständlicher Hinweis

    func testThresholdReachedYieldsExactlyOneUnderstandableHint() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        // Keine einzige Session im gesamten Fenster.
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        XCTAssertEqual(model.summary.missedCount, 2)
        // "genau EIN Hinweis": `make` liefert ein einzelnes Modell, kein
        // Array o.ae. — es gibt strukturell nur EINE Stelle, die diesen Text
        // ausgibt (der neue `CoachingContext.cardioMissedRunDays`-Fall in
        // der bestehenden `activeSoftCoachingContext`-Prioritaetskette).
        //
        // CI-Fund (kein Feature-Bug, siehe `docs/DELTIQ_DEVICE_ACCEPTANCE.md`,
        // Abschnitt "Paket 3a"): ein `swift test`-Lauf auf GitHub Actions
        // kopiert `Localizable.xcstrings` nur ROH in den Ressourcen-Bundle
        // ("Copying Localizable.xcstrings", kein "Compiling") statt es wie
        // ein echter Xcode-App-Build zu kompilieren — `CoachingMessageProvider`s
        // `String(localized:bundle:)`-Aufloesung liefert unter DIESEM
        // Build-Pfad fuer JEDEN Catalog-Key (nicht nur den neuen) den Key
        // unveraendert zurueck, `resolve(key:)` meldet das dann als "nicht
        // uebersetzt". Deshalb hier bewusst KEINE Assertion auf den
        // AUFGELOESTEN Text — die Catalog-Eintraege selbst (drei Tonfaelle,
        // de/en/tr, reine Beobachtung ohne Ursachenzuschreibung) sind
        // 1:1 nach dem Muster von `coaching.soft.cardioMissedLongRun.*`
        // gebaut, das im echten App-Build bereits produktiv funktioniert.
    }

    // MARK: - 4. Teiltraining/laufende Session/Pause → nicht pauschal als ausgefallen gewertet

    func testPartialStartedOrPausedPlanIsNotCountedAsFlatOutMissed() throws {
        let fixedNow = d(2024, 2, 1)

        // 4a: ein `.partial` (angefangen, nicht beendet) Log im Fenster
        // reduziert `missedCount` — zaehlt NICHT als verfehlt.
        let (profile, plan, runDay) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        logSession(day: runDay, date: d(2024, 1, 25), outcome: .partial)
        try context.save()
        let partialResult = MissedRunDayEvaluator.evaluate(plan: plan, in: context, now: fixedNow, calendar: utc)
        guard case .evaluated(let partialSummary) = partialResult else {
            return XCTFail("haette auswertbar sein muessen: \(partialResult)")
        }
        XCTAssertEqual(partialSummary.partialCount, 1)
        XCTAssertEqual(partialSummary.missedCount, 1, "ein Partial-Log darf nicht als verfehlt gezaehlt werden")
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc),
                     "unter der Schwelle (1 < 2) -> kein Hinweis")

        // 4b: eine pausierte Plan-Aktivierung (isActive == false) liefert nie
        // einen Hinweis, egal wie die Historie aussieht — kein verlaesslicher
        // Periodenende-Zeitpunkt.
        let (pausedProfile, pausedPlan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1), isActive: false)
        XCTAssertNil(MissedRunDaysCardModel.make(for: pausedProfile, activePlan: pausedPlan, in: context, now: fixedNow, calendar: utc))
    }

    // MARK: - 5. Planwechsel → keine falsche Übernahme alter Versäumnisse

    func testPlanSwitchDoesNotInheritPreviousPlansMissedDays() throws {
        let fixedNow = d(2024, 2, 1)

        // Alter Plan: inzwischen deaktiviert, mit massiven Versaeumnissen in
        // seiner eigenen Laufzeit.
        let (_, oldPlan, _) = makeProfileAndPlan(activatedAt: d(2023, 1, 1))
        oldPlan.isActive = false
        try context.save()

        // Neuer, GERADE ERST aktivierter Plan desselben Nutzers (2 Tage alt) —
        // zu jung, um ueberhaupt eine faellige Gelegenheit zu haben.
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let newPlan = TrainingPlan(name: "Neuer Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        newPlan.activatedAt = utc.date(byAdding: .day, value: -2, to: fixedNow)
        context.insert(newPlan)
        let newRunDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: newPlan)
        context.insert(newRunDay)
        let newRun = Exercise(name: "Easy Run", isCardio: true, day: newRunDay)
        newRun.enduranceSportKind = .running
        context.insert(newRun)
        newRunDay.exercises.append(newRun)
        newPlan.days.append(newRunDay)
        try context.save()

        let result = MissedRunDayEvaluator.evaluate(plan: newPlan, in: context, now: fixedNow, calendar: utc)
        guard case .notReliablyEvaluable(.noOpportunityDueYet) = result else {
            return XCTFail("der neue Plan ist zu jung fuer eine faellige Gelegenheit, nicht: \(result)")
        }
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: newPlan, in: context, now: fixedNow, calendar: utc))
    }

    // MARK: - 6. Ablehnen übersteht Kaltstart und unterdrückt erneutes sofortiges Anzeigen

    func testDismissSurvivesColdStartAndSuppressesImmediateReappearance() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        model.dismiss(profile: profile)
        try context.save()
        XCTAssertEqual(profile.missedRunHintDismissedFingerprint, model.fingerprint)

        // "Kaltstart": ein voellig neuer `make`-Aufruf, keine In-Memory-
        // Caches — die Unterdrueckung lebt ausschliesslich im persistierten
        // `UserBodyProfile`-Feld.
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc))
    }

    // MARK: - 7. Neue Beobachtung + abgelaufene Unterdrückung ermöglicht Neubewertung

    /// WICHTIG: bei einem bereits VOLL gesättigten rollierenden Fenster (die
    /// 14 Tage liegen komplett innerhalb der Planlaufzeit) bleibt
    /// `missedCount` bei unveraendertem Verhalten STABIL auf der
    /// Fenster-Obergrenze — er kann nicht "weiter steigen", ohne dass sich
    /// Plan oder Kadenz aendern (das ist beabsichtigt, siehe
    /// `missedRunHintFingerprint`-Doku: sonst liefe jede Unterdrueckung
    /// taeglich ab). Eine ECHTE neue Beobachtung zeigt sich deshalb hier
    /// korrekt in der WACHSTUMSPHASE: ein Plan, dessen Fenster bei der ersten
    /// Messung noch nicht voll "eingeschwungen" ist (`periodStart ==
    /// activatedAt`, noch nicht `== windowStart`), sammelt mit jedem
    /// weiteren Tag zusaetzliche faellige, unerfuellte Gelegenheiten.
    func testNewObservationAfterDismissAllowsReappearance() throws {
        let fixedNow = d(2024, 2, 1)
        // Zwei Lauf-Tage/Woche, Plan erst vor 7 Tagen aktiviert (also noch
        // juenger als das 14-Tage-Fenster) -> bei `fixedNow` genau 2 faellige,
        // unerfuellte Gelegenheiten (Schwelle erreicht).
        let activatedAt = utc.date(byAdding: .day, value: -7, to: fixedNow)!
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        plan.activatedAt = activatedAt
        context.insert(plan)
        for weekday in [2, 4] {
            let runDay = TrainingDay(name: "Run", weekday: weekday, type: .cardio, plan: plan)
            context.insert(runDay)
            let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
            run.enduranceSportKind = .running
            context.insert(run)
            runDay.exercises.append(run)
            plan.days.append(runDay)
        }
        try context.save()

        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        XCTAssertEqual(model.summary.missedCount, 2)
        model.dismiss(profile: profile)
        try context.save()
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc))

        // Eine weitere Woche vergeht ohne jede Session: das Fenster ist jetzt
        // VOLL eingeschwunden (`periodStart == activatedAt == windowStart`),
        // also mehr faellige Gelegenheiten als bei der ersten Messung — eine
        // echte neue Beobachtung, keine blosse Fenster-Drift (`planActivatedAt`
        // im Fingerprint bleibt dabei unveraendert).
        let laterNow = utc.date(byAdding: .day, value: 7, to: fixedNow)!
        guard let reappeared = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: laterNow, calendar: utc) else {
            return XCTFail("nach einer neuen Beobachtung haette der Hinweis wieder erscheinen muessen")
        }
        XCTAssertGreaterThan(reappeared.summary.missedCount, model.summary.missedCount)
        XCTAssertNotEqual(reappeared.fingerprint, model.fingerprint)
    }

    // MARK: - Restpunkt 1 (Re-Trigger-Korrektur): gedeckelter missedCount + neue Gelegenheit

    /// Der eingangs dokumentierte Schwachpunkt: bei einem voll gesättigten
    /// rollierenden Fenster bleibt `missedCount` nach dem Ablehnen auf der
    /// Fenster-Obergrenze STEHEN, obwohl taeglich eine weitere Gelegenheit
    /// verstreicht (eine alte faellt gleichzeitig aus dem Fenster heraus).
    /// `concludedOpportunityCount` (ungeclampt) erkennt das trotzdem: eine
    /// Woche nach dem Ablehnen ist genau eine neue, abgeschlossene
    /// Lauf-Gelegenheit verstrichen (siehe `MissedRunDayEvaluatorTests.
    /// testTotalConcludedRunOpportunitiesGrowsMonotonicallyAndIsNotWindowClamped`)
    /// — die Auslöseschwelle (`missedCount >= 2`) bleibt dabei weiterhin
    /// erfüllt, nur eben bei UNVERAENDERTEM Zaehler.
    func testReappearsAfterDismissWhenNewOpportunityConcludedDespiteCappedMissedCount() throws {
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))

        let now1 = d(2024, 3, 1)
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now1, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        XCTAssertEqual(model.summary.missedCount, 2)
        model.dismiss(profile: profile)
        try context.save()
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now1, calendar: utc))

        let now3 = d(2024, 3, 8)
        guard let reappeared = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now3, calendar: utc) else {
            return XCTFail("eine neue abgeschlossene Gelegenheit haette den Hinweis wieder zeigen muessen, trotz gedeckeltem Zaehler")
        }
        XCTAssertEqual(reappeared.summary.missedCount, model.summary.missedCount, "Zaehler bleibt an der Fenster-Obergrenze gedeckelt")
        XCTAssertNotEqual(reappeared.fingerprint, model.fingerprint)
    }

    /// Kehrseite: OHNE eine neue abgeschlossene Gelegenheit seit der letzten
    /// Unterdrückung darf der Hinweis NICHT erneut erscheinen, auch wenn
    /// seither Kalenderzeit vergangen ist.
    func testStaysSuppressedWithoutNewOpportunityEvenAsTimePasses() throws {
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))

        let now1 = d(2024, 3, 1)
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now1, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        model.dismiss(profile: profile)
        try context.save()

        // Ein Tag spaeter: floor(62/7) == floor(61/7) == 8 - KEINE neue
        // Gelegenheit ist verstrichen (siehe MissedRunDayEvaluatorTests).
        let now2 = d(2024, 3, 2)
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: now2, calendar: utc),
                     "ohne neue abgeschlossene Gelegenheit darf der Hinweis nicht erneut aufgefordert werden")
    }

    // MARK: - Restpunkt 2 (Planbindung): Übernahme DESSELBEN Plans unterdrückt sofortiges erneutes Auslösen

    /// `CoachAdjustmentCardModel.accept` passt `targetPlan` IN-PLACE an
    /// (`activatedAt` bleibt unveraendert - kein Planwechsel). Die VOR der
    /// Anpassung aufgelaufenen Versaeumnisse im rollierenden Fenster
    /// duerfen danach nicht unmittelbar erneut den Hinweis ausloesen -
    /// siehe `CoachAdjustmentCardModel.accept`-Kommentar (Restpunkt 2).
    func testAcceptingAdjustmentOnSamePlanDoesNotImmediatelyRetriggerHintFromStaleMisses() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        // Finding 1 (Lauf-Coaching-Audit): `makeProfileAndPlan`s Standardziel `.tenK` braucht 3
        // Lauftage, die Fixture hat nur 1 anfassbaren Tag - ohne freie Ruhetage wirft `accept()`
        // jetzt korrekt `insufficientRestDays` statt wie vor dem Fix still nur 1 von 3 Tagen zu
        // ersetzen. 2 zusaetzliche Ruhetage geben dem Einfuege-Pfad genug Platz.
        addEligibleRestDays(count: 2, to: plan, startingWeekday: 3)
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        guard let coachAdjustment = model.coachAdjustment else {
            return XCTFail("fuer diesen Test wird ein verfuegbarer Anpassungsvorschlag erwartet")
        }
        let activatedAtBefore = plan.activatedAt

        let appliedCount = try coachAdjustment.accept(plan: plan, profile: profile, in: context, now: fixedNow, calendar: utc)
        XCTAssertGreaterThan(appliedCount, 0)
        XCTAssertEqual(plan.activatedAt, activatedAtBefore, "DESSELBEN Plans - activatedAt bleibt unveraendert, kein Planwechsel")

        // Unmittelbar danach, bei UNVERAENDERTEM `now`: die VOR der Anpassung
        // aufgelaufenen alten Versaeumnisse duerfen den Hinweis nicht sofort
        // erneut zeigen, obwohl im Fenster weiterhin keine Session geloggt
        // ist.
        XCTAssertNil(MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc),
                     "stale Versaeumnisse vor der gerade uebernommenen Anpassung duerfen nicht sofort wieder aufpoppen")
    }

    // MARK: - 8. Frühere Annahme ist KEINE dauerhafte CTA-Sperre

    func testPreviousCoachAdjustmentAcceptanceDoesNotPermanentlyBlockCTA() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, _) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))

        // Simuliert eine BEREITS fruehrer erfolgte Paket-1-Uebernahme fuer
        // genau diese Ziel/Renndatum/Wochenvolumen-Kombination.
        guard let raceDate = profile.cardioRaceDate, let weeklyVolume = profile.weeklyBaseVolumeKm else {
            return XCTFail("Testdaten unvollstaendig")
        }
        profile.cardioPlanAdjustmentFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: profile.cardioGoal, raceDate: raceDate, weeklyBaseVolumeKm: weeklyVolume
        )
        try context.save()

        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette trotz frueherer Uebernahme erscheinen muessen")
        }
        guard let coachAdjustment = model.coachAdjustment else {
            return XCTFail("CTA (CoachAdjustmentCardModel) darf durch eine fruehere Annahme NICHT dauerhaft gesperrt werden")
        }
        XCTAssertTrue(coachAdjustment.isAlreadyApplied, "Testannahme: genau diese Kombination wurde bereits uebernommen")
    }

    // MARK: - 9. Öffnen und Abbrechen verändert keinen Plan

    func testOpeningAndCancellingChangesNoPlan() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, runDay) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        let dayCountBefore = plan.days.count
        let exerciseCountBefore = runDay.activeExercises.count

        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }
        // "Oeffnen": nur lesen (CTA-Verfuegbarkeit pruefen), "Abbrechen": gar
        // nichts weiter aufrufen — weder `dismiss()` noch `accept()`.
        _ = model.coachAdjustment

        XCTAssertEqual(plan.days.count, dayCountBefore)
        XCTAssertEqual(runDay.activeExercises.count, exerciseCountBefore)
        XCTAssertNil(profile.missedRunHintDismissedFingerprint)
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint)
    }

    // MARK: - 10. Übernahme bleibt ausschließlich im vorhandenen Paket-1-Pfad

    func testAdoptionStaysExclusivelyInThePackageOneAdjustmentPath() throws {
        let fixedNow = d(2024, 2, 1)
        let (profile, plan, runDay) = makeProfileAndPlan(activatedAt: d(2024, 1, 1))
        // Finding 1 (Lauf-Coaching-Audit): `.tenK` braucht 3 Lauftage, die Fixture hat nur 1
        // anfassbaren Tag - 2 zusaetzliche Ruhetage geben dem spaeteren `accept()`-Aufruf (unten)
        // genug Platz. Sie sind von Anfang an Teil von `plan.days`, daher die angepasste Zahl 3
        // (statt 1) in der folgenden "dismiss() ruehrt den Plan nicht an"-Pruefung.
        addEligibleRestDays(count: 2, to: plan, startingWeekday: 3)
        guard let model = MissedRunDaysCardModel.make(for: profile, activePlan: plan, in: context, now: fixedNow, calendar: utc) else {
            return XCTFail("Hinweis haette erscheinen muessen")
        }

        // `dismiss()` ist die einzige Mutation, die `MissedRunDaysCardModel`
        // SELBST anbietet — sie ruehrt den Plan nicht an.
        model.dismiss(profile: profile)
        XCTAssertEqual(plan.days.count, 3)
        XCTAssertEqual(runDay.activeExercises.count, 1)

        // Jede tatsaechliche PLAN-Aenderung laeuft ausschliesslich ueber den
        // bereits bestehenden, separat getesteten Paket-1-Pfad.
        guard let coachAdjustment = model.coachAdjustment else {
            return XCTFail("fuer diesen Test wird ein verfuegbarer Anpassungsvorschlag erwartet")
        }
        let appliedCount = try coachAdjustment.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(appliedCount, 0, "die einzige Mutationsstelle bleibt CoachAdjustmentCardModel.accept")
    }
}
#endif
