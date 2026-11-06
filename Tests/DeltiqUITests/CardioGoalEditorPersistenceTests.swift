#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import DeltiqCore
import DeltiqData
@testable import DeltiqUI

/// Deltiq-Geraeteabnahme (Runde 5, `docs/DELTIQ_DEVICE_ACCEPTANCE.md`,
/// C01-Nachtest): `CardioGoalEditorView.save()` mutierte `profile` OHNE
/// anschliessenden `context.save()` - auf dem Geraet ueberlebte ein gerade
/// bestaetigtes Cardio-Update (z. B. "Starting volume") einen Kaltstart kurz
/// danach reproduzierbar NICHT (zweimal unabhaengig reproduziert: der Wert
/// fiel auf den zuletzt tatsaechlich persistierten Stand zurueck), waehrend
/// die In-Memory-/UI-Anzeige bis zum Prozessende korrekt blieb - derselbe
/// Musterfehler wie `MeasurementPersistenceTests`/E01 und die zwoelf zuvor
/// gefixten Stellen. `save()` selbst bleibt `private` und liest
/// `@Environment(\.modelContext)`; ein direkter Aufruf ohne lebenden
/// `.modelContainer`-Kontext traefe nicht den hier aufgesetzten Context
/// (siehe `MeasurementPersistenceTests`-Typ-Doku). Dieser Test beweist daher
/// dieselbe zugrundeliegende Fix-Technik: Mutation + SOFORTIGER
/// `context.save()` uebersteht einen echten Store-Neustart.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioGoalEditorPersistenceTests: XCTestCase {

    func testSavedCardioGoalSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cardio-goal-editor-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        let raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let profile = UserBodyProfile(
                birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
                cardioCoachingEnabled: false, cardioGoal: .generalFitness
            )
            context.insert(profile)
            try context.save()

            // Exakt die Sequenz aus `CardioGoalEditorView.save()` nach dem
            // Fix: das bestehende Profil-Objekt mutieren (Cardio-Felder in
            // einem Rutsch, wie beim Speichern-Tap), SOFORT `context.save()`
            // - kein weiterer Schritt, der SwiftDatas impliziten Autosave
            // haette ausloesen koennen.
            profile.setEnduranceModality(.running, runCoachEnabled: true)
            profile.cardioGoal = .marathon
            profile.cardioRaceDate = raceDate
            profile.weeklyBaseVolumeKm = 10
            profile.maxHeartRateBpm = 180
            profile.current5kReferenceSeconds = 1500
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let profiles = try reopened.mainContext.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertEqual(profiles.count, 1, "Speichern darf kein zweites Profil anlegen")
        let profile = try XCTUnwrap(profiles.first)
        XCTAssertTrue(profile.cardioCoachingEnabled, "muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(profile.enduranceModality, .running)
        XCTAssertEqual(profile.cardioGoal, .marathon)
        XCTAssertEqual(profile.cardioRaceDate, raceDate)
        XCTAssertEqual(profile.weeklyBaseVolumeKm, 10)
        XCTAssertEqual(profile.maxHeartRateBpm, 180)
        XCTAssertEqual(profile.current5kReferenceSeconds, 1500)
    }

    // MARK: - Fund B (Geraete-Nachtest): 5K-Referenzzeit-Validierung
    //
    // `canSave`/`save()`/`zonesSummary` sind `private` Computed-Properties
    // ohne testbare Laufzeit-Oberflaeche (nur `some View`), also liest dieser
    // Abschnitt den Quelltext direkt — selbes Muster wie
    // `AddMealViewSaveErrorStyleTests`/`MainTabStructureTests`.

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var cardioGoalEditorViewSource: String {
        get throws { try readSource("Sources/DeltiqUI/Settings/CardioGoalEditorView.swift") }
    }

    /// Gemeinsamer Laufcoaching-Setup-Schritt: `zonesSummary`/
    /// `fiveKReferenceErrorMessage` leben seit der Extraktion in
    /// `CardioCoachSetupFields` (geteilt mit Onboarding/PlanBuilder), nicht
    /// mehr in `CardioGoalEditorView` selbst - siehe dortige Typ-Doku.
    private var cardioCoachSetupFieldsSource: String {
        get throws { try readSource("Sources/DeltiqUI/Cardio/CardioCoachSetupFields.swift") }
    }

    /// `CardioCoachSetupDraft.current5kReferenceSeconds` ist die dritte
    /// `parseFiveKReferenceSeconds`-Call-Site (geteilt von `canSave`,
    /// `save()` ueber `cardioSetupDraft.current5kReferenceSeconds`, und
    /// `fiveKReferenceErrorMessage`/`zonesSummary` in `CardioCoachSetupFields`).
    private var cardioCoachSetupDraftSource: String {
        get throws { try readSource("Sources/DeltiqCore/Analytics/CardioCoachSetupDraft.swift") }
    }

    /// Regression: alle 5K-Zeit-Call-Sites (ueber `CardioGoalEditorView`,
    /// `CardioCoachSetupDraft` und `CardioCoachSetupFields` verteilt seit der
    /// Setup-Entwurf-Extraktion) muessen `parseFiveKReferenceSeconds`
    /// verwenden, NICHT mehr `parseDurationToSeconds` — dessen "bare Zahl =
    /// Minuten"-Fallback liess ein bares "2500" unvalidiert als 2500 Minuten
    /// durchgehen.
    func testFiveKReferenceCallSitesUseTheDedicatedParser() throws {
        let editorSource = try cardioGoalEditorViewSource
        let fieldsSource = try cardioCoachSetupFieldsSource
        let draftSource = try cardioCoachSetupDraftSource
        for (name, source) in [("CardioGoalEditorView", editorSource), ("CardioCoachSetupFields", fieldsSource), ("CardioCoachSetupDraft", draftSource)] {
            XCTAssertFalse(
                source.contains("parseDurationToSeconds(draftFiveKReferenceText)") || source.contains("parseDurationToSeconds(fiveKReferenceText)"),
                "\(name) must not call parseDurationToSeconds for the 5K-time field — its bare-number-as-minutes fallback is the exact bug this fix removes."
            )
            XCTAssertFalse(
                source.contains("parseDurationToSeconds(text)"),
                "\(name)'s canSave-style local `text` must also go through parseFiveKReferenceSeconds."
            )
        }
        let totalOccurrences = [editorSource, fieldsSource, draftSource]
            .map { $0.components(separatedBy: "parseFiveKReferenceSeconds").count - 1 }
            .reduce(0, +)
        XCTAssertGreaterThanOrEqual(
            totalOccurrences, 3,
            "Expected parseFiveKReferenceSeconds to be called at all 3 logical sites (canSave, CardioCoachSetupDraft.current5kReferenceSeconds, CardioCoachSetupFields' error/zones logic), now spread across 3 files."
        )
    }

    // MARK: - Finding 3 (Laufcoaching-Audit): Rollback bei fehlgeschlagenem Save
    //
    // `save()` mutierte `profile` direkt, BEVOR `context.save()` lief - bei
    // einem Fehler blieben die nie bestaetigten Entwurfswerte unveraendert
    // auf `profile` stehen (siehe Typ-Doku-Kommentar in `save()` selbst).
    // Wie `canSave`/`zonesSummary` oben hat `save()` keine testbare
    // Laufzeit-Oberflaeche (`private`, liest `@Environment(\.modelContext)`,
    // ohne lebenden `.modelContainer` nicht direkt aufrufbar - siehe
    // `testSavedCardioGoalSurvivesARealStoreRestart`s Typ-Doku) UND dieses
    // Projekt hat keinen Unique-Constraint/verlaesslichen Weg, einen echten
    // `ModelContext.save()` ausserhalb eines DI-Seams zum Scheitern zu
    // bringen (anders als `PlanGeneratorInstantiator.saveOverrideForTesting`,
    // dessen Seam NUR funktioniert, weil die dortigen Funktionen oeffentliche
    // Statics sind, direkt von Tests aufrufbar - diese private View-Methode
    // ist es nicht, ein Seam darauf waere toter Code). Dieser Abschnitt
    // prueft daher strukturell per Quelltext, dass jedes der sieben
    // mutierten Felder VOR der Mutation geschnappschusst und im
    // `catch`-Block VOR der Fehlermeldung wiederhergestellt wird.

    /// (snapshotSuffix, propertyName) fuer alle sieben Felder, die `save()`
    /// mutiert - `enduranceModality`/`cardioCoachingEnabled` zusammen ueber
    /// `setEnduranceModality` (siehe dessen Doku in `UserBodyProfile.swift`),
    /// die uebrigen fuenf direkt.
    private static let rollbackFields: [(snapshotSuffix: String, propertyName: String)] = [
        ("EnduranceModality", "enduranceModality"),
        ("CardioCoachingEnabled", "cardioCoachingEnabled"),
        ("CardioGoal", "cardioGoal"),
        ("CardioRaceDate", "cardioRaceDate"),
        ("WeeklyBaseVolumeKm", "weeklyBaseVolumeKm"),
        ("MaxHeartRateBpm", "maxHeartRateBpm"),
        ("Current5kReferenceSeconds", "current5kReferenceSeconds"),
    ]

    func testFailedSaveSnapshotsAndRestoresAllSevenMutatedProfileFields() throws {
        let source = try cardioGoalEditorViewSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let mutationStart = source.range(of: "profile.setEnduranceModality(draftEnduranceModality") else {
            return XCTFail("the mutation block was not found where expected")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let errorMessageAssignment = source.range(of: "saveErrorMessage = String(localized: \"day.editor.save.failed\"", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("save()'s error-message assignment was not found")
        }

        let beforeMutation = String(source[saveStart.lowerBound..<mutationStart.lowerBound])
        let catchBody = String(source[catchStart.upperBound..<errorMessageAssignment.lowerBound])

        for field in Self.rollbackFields {
            XCTAssertTrue(
                beforeMutation.contains("let original\(field.snapshotSuffix) = profile.\(field.propertyName)"),
                "save() must snapshot profile.\(field.propertyName) BEFORE the mutating block, so a failed save can restore it"
            )
            XCTAssertTrue(
                catchBody.contains("profile.\(field.propertyName) = original\(field.snapshotSuffix)"),
                "a failed save's catch block must restore profile.\(field.propertyName) from its snapshot before the error message is set"
            )
        }
    }

    /// Finding 3: der Auftrag warnt explizit vor einem blinden
    /// `modelContext.rollback()` - das wuerde auch andere, unabhaengige,
    /// noch ausstehende Aenderungen im (typischerweise app-weit geteilten)
    /// Context verwerfen. Nur gezielte Feld-Wiederherstellung ist erlaubt.
    func testSaveNeverUsesABlanketContextRollback() throws {
        let source = try cardioGoalEditorViewSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let catchEnd = source.range(of: "\n    }", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("save()'s catch block end was not found")
        }
        // The catch block's own explanatory comment deliberately mentions `modelContext.rollback()`
        // in backtick-quoted prose to say why it's NOT used - strip `//` comment lines before
        // checking, so that explanation doesn't trip the very assertion it's explaining.
        let catchCode = source[catchStart.upperBound..<catchEnd.lowerBound]
            .split(separator: "\n")
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
        XCTAssertFalse(
            catchCode.contains("modelContext.rollback()"),
            "save() must restore the seven fields individually, never via a blanket modelContext.rollback() that could discard unrelated pending changes"
        )
    }

    /// Fund B: ohne eine sichtbare Fehlermeldung sah der Nutzer nur ein
    /// deaktiviertes Save-Haekchen, ohne zu verstehen warum. Lebt seit der
    /// Setup-Entwurf-Extraktion in `CardioCoachSetupFields` (geteilt mit
    /// Onboarding/PlanBuilder) statt direkt in `CardioGoalEditorView` -
    /// `CardioGoalEditorView` zeigt die Meldung weiterhin, nur ueber die
    /// geteilte View statt eigenem Code.
    func testInvalidFiveKReferenceTextRendersAnInlineErrorMessage() throws {
        let editorSource = try cardioGoalEditorViewSource
        XCTAssertTrue(
            editorSource.contains("CardioCoachSetupFields(draft:"),
            "CardioGoalEditorView must render the 5K-time field (and its error message) via the shared CardioCoachSetupFields view."
        )
        let fieldsSource = try cardioCoachSetupFieldsSource
        XCTAssertTrue(
            fieldsSource.contains("fiveKReferenceErrorMessage"),
            "A dedicated error-message computed property gated on invalid, non-empty draft.fiveKReferenceText must exist."
        )
        XCTAssertTrue(
            fieldsSource.contains("errorRow(fiveKReferenceErrorMessage)"),
            "The error message must be rendered via an errorRow(_:) helper, right where the 5K pace hint used to unconditionally render."
        )
        XCTAssertTrue(
            fieldsSource.contains("profile.cardio.fiveKReference.invalid"),
            "The error message must come from a localized string key, not a hardcoded literal."
        )
    }

    // MARK: - Bugfix ("Änderung des Laufziels muss den aktiven Trainingsplan
    // aktualisieren"): ein Zielwechsel bei bereits aktivem Coach speicherte
    // bisher nur `profile.cardioGoal` und schloss den Editor - die bereits
    // bestehende, bereits ausfuehrlich getestete Plan-Anpassungs-Vorschau
    // (`CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView`, siehe
    // `CoachAdjustmentCardModelTests`) wurde nur nie angeboten. `save()` ist
    // `private`, ohne testbare Laufzeit-Oberflaeche (siehe Typ-Doku oben) -
    // Quelltext-Pruefung des Ausloesers, gleiches Muster wie
    // `testFailedSaveSnapshotsAndRestoresAllSevenMutatedProfileFields`.

    func testGoalChangeTriggersTheSameAdjustmentPreviewAsActivatingTheCoach() throws {
        let source = try cardioGoalEditorViewSource
        XCTAssertTrue(
            source.contains("let goalChanged = draftCardioCoachingEnabled && cardioSetupDraft.goal != profile.cardioGoal"),
            "A goal change while the coach stays on must be detected BEFORE profile.cardioGoal is mutated."
        )
        XCTAssertTrue(
            source.contains("if (coachJustActivated || goalChanged), let plan = ActivePlanResolver.cardioRelevantPlan(among: activePlans) {"),
            "Changing the goal must offer the same plan-adjustment preview as activating the coach, not just dismiss."
        )
    }

    /// `goalChanged` must be computed from `profile.cardioGoal` BEFORE the
    /// mutating block below it - comparing against the already-mutated
    /// property would make it permanently false.
    func testGoalChangedIsComputedBeforeProfileIsMutated() throws {
        let source = try cardioGoalEditorViewSource
        guard let goalChangedRange = source.range(of: "let goalChanged =") else {
            return XCTFail("goalChanged not found")
        }
        guard let mutationRange = source.range(of: "profile.cardioGoal = cardioSetupDraft.goal") else {
            return XCTFail("the profile.cardioGoal mutation was not found")
        }
        XCTAssertLessThan(goalChangedRange.lowerBound, mutationRange.lowerBound, "goalChanged must be captured before profile.cardioGoal is overwritten")
    }

    /// Regression guard: a save that only touches unrelated fields (e.g. max
    /// heart rate) while the goal itself is unchanged must not re-trigger the
    /// adjustment preview on every unrelated save.
    func testUnrelatedFieldChangesDoNotFalselyTriggerTheAdjustmentPreview() throws {
        let source = try cardioGoalEditorViewSource
        guard let range = source.range(of: "let goalChanged =") else {
            return XCTFail("goalChanged not found")
        }
        let line = source[range.lowerBound...].prefix(while: { $0 != "\n" })
        XCTAssertTrue(line.contains("cardioSetupDraft.goal != profile.cardioGoal"), "goalChanged must compare goal specifically, not any other field")
        XCTAssertFalse(line.contains("raceDate") || line.contains("weeklyBaseVolumeKm") || line.contains("maxHeartRateBpm"), "goalChanged must not also fire on unrelated field changes")
    }

    // MARK: - Follow-up ticket ("Bestehenden aktiven Lauftrainingsplan nach
    // Zieländerung erneut anpassen"): the three tests above prove the TRIGGER
    // is wired correctly (source-introspection - `save()` is private, no
    // SwiftUI render harness exists in this repo, see file doc above). They
    // do NOT prove the plan itself actually changes, which is exactly what
    // this ticket calls out ("ein Test, der lediglich die Anzeige einer
    // Option ... prueft, reicht nicht"). This test exercises the real
    // data-layer path `save()` wires up end-to-end with a live in-memory
    // `ModelContainer`: `ActivePlanResolver.cardioRelevantPlan` ->
    // `CoachAdjustmentCardModel.make` -> `.accept()` - the same calls
    // `CardioGoalEditorView.save()`/`CoachAdjustmentPreviewView` make, just
    // without the SwiftUI layer in between (which cannot be driven here).
    @MainActor
    func testGoalChangeEndToEndUpdatesTheExistingActivePlanWithoutCreatingASecondOne() throws {
        let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .halfMarathon
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 30)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        // Trainingshistorie, die eine Zieländerung niemals antasten darf.
        let completedDay = TrainingDay(name: "Long Run (done)", weekday: 1, type: .fullBody, plan: plan)
        context.insert(completedDay)
        let completedRun = Exercise(name: "Completed Run", isCardio: true, day: completedDay)
        context.insert(completedRun)
        completedDay.exercises.append(completedRun)
        plan.days.append(completedDay)
        let session = WorkoutSession(startTime: Date(), isCompleted: true, day: completedDay)
        context.insert(session)
        completedDay.sessions.append(session)

        // Der einzige anfassbare Cardio-Tag - "bereits durch Coaching
        // angepasst" wird unten per direkt gesetztem Fingerprint simuliert
        // (identisches Ergebnis zu einem vorherigen echten `accept()`-Lauf,
        // ohne dessen genaue Tage-Zahl fuer `.halfMarathon` hier nachbauen
        // zu muessen).
        let eligibleDay = TrainingDay(name: "Easy Run", weekday: 3, type: .fullBody, plan: plan)
        context.insert(eligibleDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: eligibleDay)
        context.insert(run)
        eligibleDay.exercises.append(run)
        eligibleDay.generationFingerprint = eligibleDay.currentContentFingerprint
        plan.days.append(eligibleDay)

        // Genug einfuegbare Ruhetage, damit der Zielwechsel unabhaengig davon
        // funktioniert, wie viele Lauftage/Woche Marathon gegenueber
        // Halbmarathon tatsaechlich braucht (nicht Gegenstand dieses Tests -
        // das deckt bereits `CoachAdjustmentCardModelTests` ab).
        for offset in 0..<4 {
            let restDay = TrainingDay(
                name: "Ruhetag", weekday: 5 + offset, type: .rest, plan: plan,
                localizationKey: "day.restDay.title", isAutoFilledPlaceholder: true
            )
            context.insert(restDay)
            plan.days.append(restDay)
        }
        try context.save()

        let planCountBefore = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(planCountBefore, 1)

        // "bereits durch Coaching angepasster Plan": die vorherige Anpassung
        // fuer das ALTE Ziel gilt bereits als uebernommen.
        let halfMarathonFingerprint = try XCTUnwrap(CoachAdjustmentCardModel.make(for: profile, activePlan: plan)).fingerprint
        profile.cardioPlanAdjustmentFingerprint = halfMarathonFingerprint

        // Exakt das, was `CardioGoalEditorView.save()` bei einem Zielwechsel
        // jetzt tut: Ziel aendern, dann ueber `ActivePlanResolver` denselben
        // aktiven Plan wiederfinden.
        profile.cardioGoal = .marathon
        let resolvedPlan = try XCTUnwrap(ActivePlanResolver.cardioRelevantPlan(among: [plan]))
        XCTAssertTrue(resolvedPlan === plan, "muss denselben Plan wiederfinden, keinen neuen")

        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: resolvedPlan) else {
            return XCTFail("expected a non-nil model after the goal change")
        }
        XCTAssertFalse(model.isAlreadyApplied, "eine erneute Zieländerung muss wieder angeboten werden, nicht durch den alten Fingerprint unterdrueckt bleiben")

        let expectedSpecs = CoachAdjustmentCardModel.cardioOnlyDaySpecs(
            for: .marathon,
            cardioRunProfile: CardioRunProfile(goal: .marathon, current5kReferenceSeconds: nil, weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm)
        )
        XCTAssertFalse(expectedSpecs.isEmpty, "Testaufbau: Marathon muss Cardio-Tagesinhalte liefern")

        let changedCount = try model.accept(plan: resolvedPlan, profile: profile, in: context)
        XCTAssertGreaterThan(changedCount, 0, "accept() muss den bestehenden Plan tatsaechlich aendern")
        XCTAssertEqual(profile.cardioGoal, .marathon)

        // Der bestehende Plan wurde tatsaechlich aktualisiert - der zuvor
        // anfassbare Tag traegt jetzt den Inhalt fuer Marathon, nicht nur
        // einen anderen Titel/Zielwert im Profil.
        let updatedEligibleDay = try XCTUnwrap(resolvedPlan.days.first { $0.persistentModelID == eligibleDay.persistentModelID })
        XCTAssertEqual(
            updatedEligibleDay.activeExercises.map(\.name), expectedSpecs[0].exercises.map(\.name),
            "der anfassbare Tag muss den Inhalt fuer das NEUE Ziel (Marathon) tragen"
        )

        // Bereits absolvierte Einheiten bleiben vollstaendig unangetastet.
        let unchangedCompletedDay = try XCTUnwrap(resolvedPlan.days.first { $0.persistentModelID == completedDay.persistentModelID })
        XCTAssertEqual(unchangedCompletedDay.sessions.count, 1)
        XCTAssertEqual(unchangedCompletedDay.exercises.map(\.name), ["Completed Run"])

        // Keine zweite aktive Planinstanz entstanden.
        let planCountAfter = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(planCountAfter, 1, "eine Zieländerung darf niemals eine zweite Planinstanz erzeugen")
    }
}
#endif
