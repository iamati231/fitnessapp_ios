#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Integration tests for `PlanGeneratorInstantiator` (README 2.20 "Plan
/// bauen") against a real in-memory `ModelContainer`. `build`/`recalculate`
/// mutate a live SwiftData object graph and are order/identity-sensitive —
/// pure generator logic (day content, ordering, load levels) is covered by
/// `PlanGeneratorTests` in FitnessAppCoreTests; these tests only verify the
/// SwiftData boundary: fingerprinting, stable day identity across edits, and
/// archived-exercise preservation.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanGeneratorInstantiatorTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
        // Nachbesserung (P2.3-Review, Punkt 1): DI-Seam ist ein STATISCHER
        // Override auf dem Typ, nicht Instanz-State — muss nach jedem Test
        // zurueckgesetzt werden, sonst "leakt" ein in einem Test gesetzter
        // Mock in alle nachfolgenden Tests dieser (oder einer anderen)
        // Testklasse.
        PlanGeneratorInstantiator.fetchAllSessionsOverrideForTesting = nil
        // Nachbesserung (Task #197): gleicher Grund wie oben - statischer
        // Override, muss nach jedem Test zurueckgesetzt werden.
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
        PlanGeneratorInstantiator.fetchActivePlansOverrideForTesting = nil
        // Nachbesserung (zweite Korrekturrunde): gleicher Grund wie oben - statischer Override.
        PlanGeneratorInstantiator.rebindOverrideForTesting = nil
    }

    private var context: ModelContext { container.mainContext }

    private func selection(
        _ kind: TrainingTypeKind,
        days: Int,
        minutes: Int = 45,
        experience: DifficultyLevel = .intermediate
    ) -> PlanGeneratorTypeSelection {
        PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: minutes, experience: experience)
    }

    private func input(_ selections: [PlanGeneratorTypeSelection]) -> PlanGeneratorInput {
        PlanGeneratorInput(selections: selections, equipmentPreferences: [], usesFixedWeekdays: false)
    }

    /// Audit-Korrektur P2.1: `environment`/`equipmentProfile` sind auf
    /// `PlanGeneratorInstantiator.build` bewusst Pflichtparameter ohne
    /// Default (siehe dortige Dokumentation — kein versteckter Default soll
    /// den gerade behobenen `.gym`-Hardcode durch einen anderen ersetzen).
    /// Dieser Test-Wrapper traegt NUR einen neutralen Testwert fuer die
    /// Mehrheit der Tests hier nach, denen Trainingsort/Equipment
    /// gleichgueltig ist (sie pruefen Fingerprinting/Sequencing/Recalculate).
    /// Die environment-/equipment-spezifischen Tests weiter unten rufen
    /// `PlanGeneratorInstantiator.build` direkt mit expliziten Werten auf.
    @discardableResult
    private func buildPlan(
        from input: PlanGeneratorInput,
        environment: EnvironmentType = .gym,
        equipmentProfile: UserEquipmentProfile = UserEquipmentProfile(),
        result precomputed: PlanGenerator.Result? = nil,
        generationSource: GenerationSource = .manual,
        generatorGoal: TrainingGoal? = nil
    ) throws -> TrainingPlan? {
        try PlanGeneratorInstantiator.build(
            from: input, in: context,
            environment: environment, equipmentProfile: equipmentProfile,
            result: precomputed, generationSource: generationSource,
            generatorGoal: generatorGoal
        )
    }

    // MARK: - build()

    func testBuildStampsFingerprintAndSequenceIndexOnEveryWorkoutDay() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 3)])))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, 3)
        for day in workoutDays {
            XCTAssertNotNil(day.generationFingerprint)
            XCTAssertNotNil(day.generatorSequenceIndex)
            XCTAssertEqual(day.generationFingerprint, day.currentContentFingerprint)
        }
        let sequenceIndices = Set(workoutDays.compactMap(\.generatorSequenceIndex))
        XCTAssertEqual(sequenceIndices, [1, 2, 3], "jeder Tag muss einen eigenen, eindeutigen sequenceIndex bekommen")
    }

    func testBuildReturnsNilWhenGeneratorProducesNoDays() throws {
        // Kein Selections-Eintrag -> PlanGenerator.generate liefert leer.
        XCTAssertNil(try buildPlan(from: input([])))
    }

    // Handoff "Lauf-Coaching - Machbarkeits-Check": generationSource wird
    // an den frisch instanziierten Plan durchgereicht - CardioFeasibility-
    // CardModel.accept()/.acceptCustom() verlassen sich darauf, dass der so
    // gebaute Plan spaeter als .cardioCoach erkennbar ist. Ohne expliziten
    // Parameter bleibt es beim Default .manual (bestehendes Verhalten aller
    // anderen Tests in dieser Datei).
    func testBuildStampsExplicitGenerationSource() throws {
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.running, days: 2)]), generationSource: .cardioCoach
        ))
        XCTAssertEqual(plan.generationSource, .cardioCoach)
    }

    func testBuildDefaultsGenerationSourceToManual() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        XCTAssertEqual(plan.generationSource, .manual)
    }

    /// Bugfix (Nutzer-Feedback, "Neu rechnen"-Shuffle): `build` darf einen
    /// bereits berechneten `PlanGenerator.Result` nicht verwerfen und
    /// stattdessen `input` erneut (und damit wieder deterministisch) neu
    /// rechnen - sonst weicht ein instanziierter Plan von der zuletzt in
    /// der Wizard-Vorschau gezeigten (z.B. gemischten) Variante ab.
    /// `differentResult` kommt bewusst aus einer STRUKTURELL anderen
    /// Auswahl (Kurzhantel statt Langhantel) ueber die oeffentliche
    /// `generate`-API - ohne den Fix wuerden die Tagesnamen zwangslaeufig
    /// den Langhantel-Namen von `barbellInput` entsprechen, nicht denen aus
    /// `differentResult`.
    func testBuildUsesThePrecomputedResultInsteadOfRecomputingFromInput() throws {
        let barbellInput = input([selection(.barbell, days: 2)])
        let differentResult = PlanGenerator.generate(from: input([selection(.dumbbell, days: 2)]))
        XCTAssertFalse(differentResult.days.isEmpty)

        let plan = try XCTUnwrap(buildPlan(from: barbellInput, result: differentResult))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, differentResult.days.count)
        XCTAssertEqual(Set(workoutDays.map(\.name)), Set(differentResult.days.map { $0.spec.name }),
                       "build() muss den durchgereichten Result verwenden, nicht `from: input` neu rechnen")

        // `plan.generatorInput` bleibt trotzdem das ECHTE `barbellInput` -
        // ein spaeteres `recalculate` fuer den adoptierten Plan soll
        // weiterhin deterministisch aus dem passenden Input arbeiten, nicht
        // aus der einmaligen Vorschau-Variante.
        XCTAssertEqual(plan.generatorInput, barbellInput)
    }

    // MARK: - recalculate() Grundfaelle

    func testRecalculateIsNoOpForPlansWithoutGeneratorInput() throws {
        let plan = TrainingPlan(name: "Custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary, .init(rewrittenCount: 0, skippedDueToHistoryCount: 0))
    }

    func testRecalculateSkipsDayWithEditedExerciseSets() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, 2)
        let editedDay = try XCTUnwrap(workoutDays.first)
        let originalExerciseCount = editedDay.activeExercises.count
        // Simuliert eine User-Aenderung ueber ExerciseEditorView.
        editedDay.activeExercises.first?.sets += 1

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 1, "nur der unangetastete zweite Tag darf neu geschrieben werden")
        XCTAssertEqual(editedDay.activeExercises.count, originalExerciseCount, "editierter Tag bleibt inhaltlich stehen")
    }

    // MARK: - README-2.20-Review-Fund: stabile Tag-Identitaet

    /// Regression: eine fruehere Fassung von `recalculate` matchte generierte
    /// gegen bestehende Tage rein ueber die Position in einer Montag-first-
    /// sortierten "nur Trainingstage"-Liste. Sobald ein Tag ueber
    /// `DayEditorView` zum Ruhetag gemacht (oder auf einen anderen Wochentag
    /// verschoben) wird, verschiebt das die Position JEDES NACHFOLGENDEN
    /// Tages in dieser Liste - die nachfolgenden, eigentlich unangetasteten
    /// Tage bekamen dadurch den Inhalt eines JEWEILS ANDEREN Tages
    /// zugeschrieben. `generatorSequenceIndex` macht das Matching stabil.
    func testRecalculatePreservesCorrectContentAfterEarlierDayBecomesRest() throws {
        // Drei STRUKTURELL verschiedene Trainingsarten, damit sich vertauschter
        // Inhalt zwischen Tagen zweifelsfrei nachweisen laesst.
        let mixedInput = input([
            selection(.kettlebell, days: 1),
            selection(.running, days: 1),
            selection(.cycling, days: 1)
        ])
        let plan = try XCTUnwrap(buildPlan(from: mixedInput))
        let workoutDaysBefore = PlanNavigator.sortByWeekdayMondayFirst(plan.days.filter { $0.type != .rest })
        XCTAssertEqual(workoutDaysBefore.count, 3)

        let nameBySequenceIndex = try Dictionary(
            uniqueKeysWithValues: workoutDaysBefore.map { (try XCTUnwrap($0.generatorSequenceIndex), $0.name) }
        )
        XCTAssertEqual(Set(nameBySequenceIndex.values).count, 3, "die drei Trainingsarten muessen unterscheidbare Tages-Namen erzeugen")

        // User macht den ERSTEN (Montag-first) Tag zum Ruhetag.
        let editedDay = workoutDaysBefore[0]
        editedDay.type = .rest

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 2)

        // Der bearbeitete Tag bleibt Ruhetag - sein Fingerprint (jetzt inkl.
        // `type`) passt nicht mehr, "neu rechnen" darf ihn nicht anfassen.
        XCTAssertEqual(editedDay.type, .rest)

        // Jeder VERBLEIBENDE Trainingstag muss GENAU seinen eigenen,
        // urspruenglichen Inhalt zurueckbekommen - nicht den eines
        // benachbarten Tages.
        for day in workoutDaysBefore.dropFirst() {
            let sequenceIndex = try XCTUnwrap(day.generatorSequenceIndex)
            XCTAssertEqual(day.name, nameBySequenceIndex[sequenceIndex],
                            "Tag mit sequenceIndex \(sequenceIndex) hat den falschen Inhalt bekommen")
        }
    }

    // MARK: - README-2.20-Review-Fund: archivierte Uebungen ueberleben

    /// Regression: eine fruehere Fassung von `apply()` loeschte VOR dem
    /// Neu-Erzeugen die komplette `exercises`-Relationship (aktiv +
    /// archiviert) statt nur `activeExercises`. Das reisst jedes archivierte
    /// Original mit, auf das `PlanEnvironmentMigrator.restoreOriginals` beim
    /// Verlassen des Urlaubs-Modus angewiesen ist.
    ///
    /// Testet gezielt NUR `apply()`s Loesch-Verhalten, nicht das reale
    /// Zusammenspiel mit `PlanEnvironmentMigrator` (dessen genaue Swap-/
    /// Restore-Mechanik ist nicht Gegenstand dieser Datei): der Fingerprint
    /// wird nach dem Archivieren bewusst manuell neu gesetzt, um genau den
    /// Zustand herzustellen, in dem `recalculate` den Tag als unangetastet
    /// einstuft und `apply()` tatsaechlich aufruft.
    func testApplyPreservesArchivedExercisesWhenOverwritingAnUntouchedDay() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 1)])))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })

        let archived = try XCTUnwrap(day.activeExercises.first)
        archived.isArchived = true
        day.generationFingerprint = day.currentContentFingerprint

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 1)
        XCTAssertTrue(day.archivedExercises.contains(where: { $0 === archived }),
                       "archivierte Uebung darf beim Neu-Rechnen nicht verloren gehen")
    }

    // MARK: - Audit-Korrektur P2.1: targetEnvironment kommt vom Aufrufer, nie hartcodiert

    /// Die Kern-Regression: `makeTemplate` setzte vorher IMMER `.gym`,
    /// unabhaengig vom tatsaechlichen Trainingsort. Direkter Gegenbeweis mit
    /// einem Wert, der garantiert NICHT der alte Hardcode ist.
    func testBuildUsesTheExplicitlyPassedEnvironmentNotAHardcodedGym() throws {
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.barbell, days: 2)]), environment: .homeGym
        ))
        XCTAssertEqual(plan.targetEnvironment, .homeGym)
    }

    /// Szenario 1: Gym mit Kurzhanteln.
    func testBuildGymWithDumbbellsKeepsTheExplicitGymEnvironment() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.dumbbell, days: 3)]), environment: .gym, equipmentProfile: profile
        ))
        XCTAssertEqual(plan.targetEnvironment, .gym)
    }

    /// Szenario 2: Home-Gym mit Langhantel — Vorgabe Punkt 2: eine fuer
    /// "Gym" typische Langhantel darf den explizit gewaehlten Home-Gym-Ort
    /// NICHT stillschweigend auf `.gym` "korrigieren". Equipment ist nur
    /// fuer die Ausfuehrbarkeitspruefung da, nicht fuer die Ortswahl.
    func testBuildHomeGymWithBarbellIsNotReinterpretedAsGym() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.barbell] = .available
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.barbell, days: 3)]), environment: .homeGym, equipmentProfile: profile
        ))
        XCTAssertEqual(plan.targetEnvironment, .homeGym)
    }

    /// Szenario 3: Bodyweight ohne Geraete.
    func testBuildBodyweightWithoutEquipmentKeepsTheExplicitNoEquipmentEnvironment() throws {
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.bodyweight, days: 3)]), environment: .noEquipment, equipmentProfile: UserEquipmentProfile()
        ))
        XCTAssertEqual(plan.targetEnvironment, .noEquipment)
    }

    /// Szenario 4: explizit bestaetigt FEHLENDES Equipment (nicht nur
    /// unbekannt) darf den Trainingsort ebenfalls nicht verfaelschen.
    func testBuildWithExplicitlyMissingEquipmentKeepsTheExplicitEnvironment() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.barbell] = .unavailable
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.barbell, days: 2)]), environment: .gym, equipmentProfile: profile
        ))
        XCTAssertEqual(plan.targetEnvironment, .gym)
    }

    /// Szenario 5: unbekannte Ausstattung (Default-Profil, kein Item
    /// angefasst) — darf ebenso wenig zu einer anderen Ortswahl fuehren.
    func testBuildWithUnknownEquipmentKeepsTheExplicitEnvironment() throws {
        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.kettlebell, days: 2)]), environment: .homeGym, equipmentProfile: UserEquipmentProfile()
        ))
        XCTAssertEqual(plan.targetEnvironment, .homeGym)
    }

    // MARK: - P5.2: generatorGoal verbindet PlanSelectionResolver mit dem Builder-Pfad

    /// P5.2: ohne `generatorGoal` (alle drei bestehenden Aufrufer unveraendert
    /// — Onboarding, CardioFeasibilityCard, der preseeded Builder-Handoff)
    /// bleibt das bisherige Verhalten exakt erhalten: eine Uebung, die nicht
    /// zum Profil passt, wird NICHT ersetzt, nur die alte Legacy-Variantenwahl
    /// laeuft (`userEquipmentProfile:` an `ProgramInstantiator.instantiate`).
    func testBuildWithoutGeneratorGoalNeverSubstitutesExercises() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let squat = ExerciseSpec(name: "Kniebeuge", sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90, targetRir: 2)
        let day = DaySpec(name: "Legs", type: .legs, sequenceIndex: 1, exercises: [squat])
        let result = PlanGenerator.Result(days: [.init(spec: day, loadLevel: .medium)])

        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.barbell, days: 1)]), equipmentProfile: profile, result: result
        ))
        let names = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        XCTAssertTrue(names.contains("Kniebeuge"), "Ohne generatorGoal darf sich am materialisierten Plan nichts aendern")
    }

    /// P5.2: MIT einem echten `generatorGoal` (P3.1s zielorientierter
    /// Builder-Einstieg, `PlanBuilderView.selectedTrainingGoal`) laeuft jetzt
    /// derselbe `PlanSelectionResolver.resolve`-Pfad wie `TemplatePreviewView`
    /// fuer Templates — eine Uebung mit einer reviewten Substitutionsregel
    /// ("Kniebeuge" -> "Goblet Squat" bei Nicht-Kraft-Ziel + repsMax >= 10,
    /// siehe `ExerciseSubstitutionRules.swift`), die nicht zum Profil passt,
    /// wird jetzt TATSAECHLICH im instanziierten Plan ersetzt, nicht nur in
    /// einer separaten Vorschau (die Spezifikationsluecke, die P5.2 schliesst).
    func testBuildWithGeneratorGoalSubstitutesAnUnavailableExerciseUsingAReviewedRule() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let squat = ExerciseSpec(name: "Kniebeuge", sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90, targetRir: 2)
        let day = DaySpec(name: "Legs", type: .legs, sequenceIndex: 1, exercises: [squat])
        let result = PlanGenerator.Result(days: [.init(spec: day, loadLevel: .medium)])

        let plan = try XCTUnwrap(buildPlan(
            from: input([selection(.barbell, days: 1)]), equipmentProfile: profile, result: result,
            generatorGoal: .hypertrophy
        ))
        let names = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        XCTAssertFalse(names.contains("Kniebeuge"), "Eine Langhantel-Uebung ohne Langhantel-Equipment darf nicht unveraendert bleiben")
        XCTAssertTrue(names.contains("Goblet Squat"), "Die reviewte Ersatzuebung muss tatsaechlich im materialisierten Plan landen")
    }

    // MARK: - P2.3: createPlan(for:) — EIN Einstiegspunkt statt vier Kopien

    private func makeProfile(
        environment: EnvironmentType = .gym,
        equipmentProfile: UserEquipmentProfile = UserEquipmentProfile(),
        equipmentProfileConfirmedComplete: Bool = false
    ) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 180,
            profile: .male,
            goalWeightKg: 80,
            environment: environment
        )
        profile.equipmentProfile = equipmentProfile
        profile.equipmentProfileConfirmedComplete = equipmentProfileConfirmedComplete
        context.insert(profile)
        return profile
    }

    /// `createPlan(for:)` muss exakt dieselbe Aufloesung liefern wie die
    /// vorher an vier Stellen unabhaengig kopierte Resolve+Build-Sequenz:
    /// `environment` kommt vom Profil, nicht aus dem Equipment hergeleitet
    /// (identische Garantie wie `testBuildUsesTheExplicitlyPassedEnvironmentNotAHardcodedGym`,
    /// hier ueber den neuen konsolidierten Einstiegspunkt).
    func testCreatePlanResolvesEnvironmentFromProfile() throws {
        let profile = makeProfile(environment: .homeGym)
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.createPlan(
            from: input([selection(.barbell, days: 2)]),
            for: profile, generationSource: .cardioCoach, in: context
        ))
        XCTAssertEqual(plan.targetEnvironment, .homeGym)
        XCTAssertEqual(plan.generationSource, .cardioCoach)
    }

    /// Gegenprobe zu `testBuildReturnsNilWhenGeneratorProducesNoDays`, ueber
    /// den neuen Einstiegspunkt: ein leeres Generator-Ergebnis darf auch hier
    /// nichts anlegen.
    func testCreatePlanReturnsNilWhenGeneratorProducesNoDays() throws {
        let profile = makeProfile()
        XCTAssertNil(try PlanGeneratorInstantiator.createPlan(
            from: input([]), for: profile, generationSource: .manual, in: context
        ))
    }

    // MARK: - P2.3-Review Punkt 1: Fetch-Fehler darf NIE als "keine Session" gelten

    /// Kern-Regression des Fail-Safe-Fundes: schlaegt die Session-Pruefung
    /// selbst fehl (hier via DI-Seam simuliert), muss `recalculate` werfen
    /// UND NICHT EINEN EINZIGEN Tag anfassen — ein `(try? ...) ?? []` im
    /// Schutzpfad haette den Fehler still als "keine Session" gewertet und
    /// waere ungebremst weitergelaufen.
    func testRecalculateThrowsAndChangesNothingWhenSessionCheckFails() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let workoutDays = plan.days.filter { $0.type != .rest }
        let fingerprintsBefore = workoutDays.map(\.generationFingerprint)
        let exerciseIDsBefore = workoutDays.map { Set($0.activeExercises.map(\.persistentModelID)) }

        struct SimulatedFetchFailure: Error {}
        PlanGeneratorInstantiator.fetchAllSessionsOverrideForTesting = { throw SimulatedFetchFailure() }

        XCTAssertThrowsError(try PlanGeneratorInstantiator.recalculate(plan, in: context)) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.RecalculateError, .sessionCheckFailed)
        }

        // Keine Mutation — jeder Tag ist exakt wie vor dem fehlgeschlagenen Aufruf.
        let fingerprintsAfter = workoutDays.map(\.generationFingerprint)
        let exerciseIDsAfter = workoutDays.map { Set($0.activeExercises.map(\.persistentModelID)) }
        XCTAssertEqual(fingerprintsAfter, fingerprintsBefore, "kein Tag darf nach einem fehlgeschlagenen Sicherheits-Check neu gestempelt sein")
        XCTAssertEqual(exerciseIDsAfter, exerciseIDsBefore, "keine Uebung darf nach einem fehlgeschlagenen Sicherheits-Check ersetzt worden sein")
    }

    /// Gegenprobe: ohne Override (echter, erfolgreicher Fetch) bleibt das
    /// bisherige Verhalten erhalten — der Fail-Safe darf den Erfolgspfad
    /// nicht beeintraechtigen.
    ///
    /// Korrektur (Review): die vorherige Fassung erwartete faelschlich
    /// `rewrittenCount: 0` — ein frisch gebauter Tag hat zwar denselben
    /// Fingerprint wie bei der Erzeugung, aber GENAU DAS ist per Vertrag
    /// "unangetastet" (siehe `recalculate`-Doku: "ersetzt NUR unangetastete
    /// Tage") und wird deshalb neu geschrieben, NICHT uebersprungen. Ein
    /// passender Fingerprint ERLAUBT das Ueberschreiben, er verhindert es
    /// nicht — nur ein ABWEICHENDER Fingerprint (= echter User-Edit, siehe
    /// `testRecalculateSkipsDayWithEditedExerciseSets`) blockiert.
    func testRecalculateSucceedsNormallyWithoutOverride() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let workoutDayCount = plan.days.filter { $0.type != .rest }.count
        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary, .init(rewrittenCount: workoutDayCount, skippedDueToHistoryCount: 0),
                       "unangetastete Tage (passender Fingerprint, keine Session) werden neu geschrieben, nicht uebersprungen")
    }

    // MARK: - P2.3-Review Punkt 2: konservativer Schutz JEDER Session (nicht nur laufender)

    /// Ein Tag mit einer gerade LAUFENDEN (nicht abgeschlossenen) Session
    /// wird komplett uebersprungen, sichtbar ueber `skippedDueToHistoryCount`
    /// — nicht nur inhaltlich unangetastet, sondern im Rueckgabewert auch
    /// als "wegen Historie uebersprungen" auffindbar, nicht nur als
    /// "zufaellig nicht neu geschrieben".
    func testRecalculateSkipsDayWithActiveSessionAndReportsIt() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, 2)
        let dayWithActiveSession = try XCTUnwrap(workoutDays.first)
        let originalExerciseIDs = Set(dayWithActiveSession.activeExercises.map(\.persistentModelID))

        let activeSession = WorkoutSession(isCompleted: false, day: dayWithActiveSession)
        context.insert(activeSession)

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 1, "nur der Tag OHNE Session darf neu geschrieben werden")
        XCTAssertEqual(summary.skippedDueToHistoryCount, 1, "muss sichtbar als historienbedingt uebersprungen gemeldet werden")
        XCTAssertEqual(
            Set(dayWithActiveSession.activeExercises.map(\.persistentModelID)),
            originalExerciseIDs,
            "Tag mit laufender Session darf nicht angefasst werden, obwohl sein Fingerprint unveraendert ist"
        )
    }

    /// KORREKTUR (P2.3-Review): die urspruengliche P2.3-Fassung liess eine
    /// ABGESCHLOSSENE Session "neu rechnen" nicht blockieren und bewies nur
    /// "der ExerciseLog wird nicht geloescht" — das ist KEIN Nachweis
    /// unveraenderter Historie, siehe `testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned`
    /// unten: `cnsFatigueScore`/`localMuscleDamageScore` fallen auf 0.0
    /// zurueck, sobald `exercise == nil` ist. Konservativ bis zur Inhalts-/
    /// Versionsabsicherung: JEDE Session (auch abgeschlossen) blockiert jetzt
    /// — der Tag bleibt komplett unangetastet, die Log-Referenz bleibt
    /// vollstaendig intakt (nicht nur "ueberlebt orphan").
    func testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 1)])))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })
        let originalExercise = try XCTUnwrap(day.activeExercises.first)
        let originalExerciseIDs = Set(day.activeExercises.map(\.persistentModelID))

        let completedSession = WorkoutSession(isCompleted: true, day: day)
        context.insert(completedSession)
        let log = ExerciseLog(date: Date(), setIndex: 0, weight: 60, reps: 8, rir: 2.0,
                               exercise: originalExercise, session: completedSession)
        context.insert(log)

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 0, "ein Tag mit JEDER Session (auch abgeschlossen) darf nicht neu geschrieben werden")
        XCTAssertEqual(summary.skippedDueToHistoryCount, 1)
        XCTAssertEqual(Set(day.activeExercises.map(\.persistentModelID)), originalExerciseIDs,
                       "Uebungen bleiben unveraendert - keine Ersetzung, also auch keine Verwaisung noetig")
        XCTAssertNotNil(log.exercise, "die Log-Referenz bleibt vollstaendig intakt, nicht nur ueberlebend-aber-verwaist")
        XCTAssertTrue(log.exercise === originalExercise, "dieselbe Uebungs-Instanz, keine Ersetzung - Auswertung (CNS-/Muskel-Score) bleibt dadurch unveraendert korrekt")
    }

    /// Begruendet DIREKT, warum Punkt 2 konservativ JEDE Session blockiert
    /// statt nur zu pruefen, ob der `ExerciseLog` die Loeschung ueberlebt:
    /// Name/Cardio/TimeBased-Identitaet ueberleben einen Exercise-Delete
    /// ueber die Snapshot-Felder (`resolvedExerciseName` etc., siehe
    /// `ExerciseLog`-Typ-Doku) — aber `cnsFatigueScore`/
    /// `localMuscleDamageScore` (reine `Auswertung`, keine reinen
    /// Snapshot-Werte) fallen auf `0.0` zurueck. "Der Log existiert noch"
    /// ist deshalb ausdruecklich KEIN Beweis fuer unveraenderte Historie.
    func testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 1)])))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })
        let exercise = try XCTUnwrap(day.activeExercises.first)
        XCTAssertGreaterThan(exercise.cnsDemandFactor, 0, "Testvoraussetzung: Faktor muss ungleich 0 sein, sonst beweist der Test nichts")

        let log = ExerciseLog(date: Date(), setIndex: 0, weight: 60, reps: 8, rir: 2.0, exercise: exercise)
        context.insert(log)

        let nameBefore = log.resolvedExerciseName
        let cnsBefore = log.cnsFatigueScore
        XCTAssertGreaterThan(cnsBefore, 0, "Testvoraussetzung: mit Live-Referenz muss ein echter Score herauskommen")

        // Simuliert, was ein Exercise-Delete fuer den Log bedeutet
        // (`.nullify`-Relationship, kein Cascade) — direkt gesetzt statt
        // `context.delete(exercise)`, um unabhaengig von `recalculate` nur
        // diese EINE Eigenschaft von `ExerciseLog` zu pruefen.
        log.exercise = nil

        XCTAssertEqual(log.resolvedExerciseName, nameBefore, "Identitaet bleibt ueber den Snapshot erhalten")
        XCTAssertEqual(log.cnsFatigueScore, 0.0, "Auswertung degradiert MESSBAR, sobald die Live-Referenz fehlt - genau der Befund, der Punkt 2 rechtfertigt")
    }

    // MARK: - Task #197: Commit-/Speicherfehler-Behandlung

    private struct TestSaveError: Error {}

    /// Kern-Regression: ein fehlgeschlagener Save in `build` darf den
    /// Aufrufer-Context NICHT in einem inkonsistenten Zustand zuruecklassen.
    /// Beweist BEIDE Haelften: der neue Plan verschwindet, UND der VORHER
    /// aktive Plan ist weiterhin aktiv.
    /// Mechanismus (Review nach Task #197): `build` arbeitet auf einem
    /// isolierten Scratch-Context (siehe Typ-Doku Punkt 1) - `planA` (im
    /// Aufrufer-Context) wird vom gescheiterten zweiten Versuch technisch
    /// NIE beruehrt, nicht erst mutiert und dann zurueckgesetzt.
    func testBuildRollsBackNewPlanAndRestoresPreviousActivePlanWhenSaveFails() throws {
        let planA = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        XCTAssertTrue(planA.isActive)

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(try buildPlan(from: input([selection(.dumbbell, days: 3)]))) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.PlanCreationError, .saveFailed)
        }

        XCTAssertTrue(planA.isActive, "vorheriger aktiver Plan darf durch den gescheiterten Versuch nie beruehrt werden")
        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "der fehlgeschlagene zweite Plan darf nicht haengen bleiben")
    }

    /// `createPlan` muss denselben Fehler nur durchreichen, nicht
    /// verschlucken — sie ist ein duenner Wrapper um `build`.
    func testCreatePlanPropagatesSaveFailure() throws {
        let profile = makeProfile()
        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(try PlanGeneratorInstantiator.createPlan(
            from: input([selection(.barbell, days: 2)]), for: profile, generationSource: .manual, in: context
        )) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.PlanCreationError, .saveFailed)
        }
    }

    /// Nachbesserung (Review nach Task #197, geforderter Test 4): ein
    /// fehlgeschlagener Versuch darf einen ERNEUTEN, diesmal erfolgreichen
    /// Versuch nicht behindern — kein verwaistes Fragment vom ersten
    /// Versuch.
    /// User-Entscheidung (P0-Audit neue Spezifikation): mehrere gleichzeitig
    /// aktive Plaene sind gewollt - `planA` bleibt deshalb aktiv, auch nachdem
    /// `planB` erfolgreich erstellt wurde (siehe `ProgramInstantiator.instantiate`-
    /// Typ-Doku).
    func testFailedCreationIsRepeatableWithoutOrphanedObjects() throws {
        let planA = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }
        XCTAssertThrowsError(try buildPlan(from: input([selection(.dumbbell, days: 3)])))

        PlanGeneratorInstantiator.saveOverrideForTesting = nil
        let planB = try XCTUnwrap(buildPlan(from: input([selection(.dumbbell, days: 3)])))

        XCTAssertTrue(planB.isActive)
        XCTAssertTrue(planA.isActive, "mehrere gleichzeitig aktive Plaene sind gewollt - der neue Plan deaktiviert aeltere nicht")
        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 2, "genau Plan A und der jetzt erfolgreiche Plan B - kein Fragment vom gescheiterten Versuch")
    }

    /// Nachbesserung (Review nach Task #197, Punkt 3 der Vorgabe): scheitert
    /// die Pruefung, welche Plaene aktiv sind, selbst (z.B. Fetch-Fehler),
    /// darf GAR KEINE Mutation stattgefunden haben - kein `(try? ...) ?? []`.
    func testBuildAbortsBeforeAnyMutationWhenActivePlanCheckFails() throws {
        let planA = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        XCTAssertTrue(planA.isActive)

        PlanGeneratorInstantiator.fetchActivePlansOverrideForTesting = { throw TestSaveError() }

        XCTAssertThrowsError(try buildPlan(from: input([selection(.dumbbell, days: 3)]))) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.PlanCreationError, .activePlanCheckFailed)
        }

        XCTAssertTrue(planA.isActive, "darf unveraendert bleiben, da vor jeder Mutation abgebrochen wurde")
        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "kein zweiter Plan darf angelegt worden sein")
    }

    /// Nachbesserung (Review nach Task #197, geforderter Test 1): `build`
    /// arbeitet auf einem isolierten Scratch-Context (Typ-Doku Punkt 1) -
    /// eine unabhaengige, im Aufrufer-Context noch NICHT gespeicherte
    /// Aenderung darf dadurch NICHT mitgespeichert werden. Prueft das direkt
    /// gegen einen DRITTEN, frischen Verifikations-Context auf demselben
    /// Container (nicht gegen den Aufrufer-Context selbst, dessen
    /// In-Memory-Zustand die eigene offene Aenderung natuerlich weiterhin
    /// zeigt) - nur so laesst sich zeigen, was TATSAECHLICH auf dem Store
    /// gelandet ist.
    func testBuildDoesNotSaveIndependentPendingChangeInCallerContext() throws {
        let independentProfile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        context.insert(independentProfile)
        XCTAssertTrue(context.hasChanges, "Testvoraussetzung: die unabhaengige Aenderung muss selbst noch ungespeichert sein")

        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        XCTAssertFalse(plan.days.isEmpty)

        let verificationContext = ModelContext(container)
        let savedProfiles = try verificationContext.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertTrue(savedProfiles.isEmpty, "unabhaengiges, nicht selbst gespeichertes Profil wurde faelschlich mitgespeichert")
    }

    /// `recalculate` kann (anders als `build`) nicht per Context-Isolation
    /// zurueckbauen — siehe Typ-Doku "Operations-/Fehlervertrag" Punkt 1.
    /// Der Fehler muss trotzdem sichtbar geworfen werden statt in einer
    /// stillen Autosave-Abhaengigkeit zu verschwinden.
    func testRecalculatePropagatesSaveFailureAsThrownError() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(try PlanGeneratorInstantiator.recalculate(plan, in: context)) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.RecalculateError, .saveFailed)
        }
    }

    /// Nachbesserung (Review nach Task #197, geforderter Test 2): ein
    /// Save-Fehler bei `recalculate` darf WEDER den dauerhaften (bereits
    /// persistierten) NOCH einen anschliessend erneut gespeicherten Zustand
    /// veraendern. Prueft explizit BEIDE Zeitpunkte - direkt nach dem
    /// Fehler (zeigt den vollstaendigen `revert(...)`) UND nach einem
    /// GENUINEN, spaeteren Save (zeigt, dass nichts vom gescheiterten
    /// Versuch nachtraeglich haengen geblieben ist und still mitgenommen
    /// wird).
    func testRecalculateSaveFailureLeavesNoStructuralChangeEvenAfterLaterSave() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })
        let originalExerciseIDs = Set(day.activeExercises.map(\.persistentModelID))
        let originalName = day.name

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }
        XCTAssertThrowsError(try PlanGeneratorInstantiator.recalculate(plan, in: context))

        XCTAssertEqual(day.name, originalName, "Tagesfelder muessen sofort nach dem Fehler zurueckgesetzt sein")
        XCTAssertEqual(
            Set(day.activeExercises.map(\.persistentModelID)), originalExerciseIDs,
            "aktive Uebungen muessen sofort nach dem Fehler wieder exakt die urspruenglichen sein"
        )

        // Jetzt ein GENUINER Save (Override entfernt) - darf nichts vom
        // gescheiterten Versuch nachtraeglich uebernehmen, weil `revert`
        // bereits alles zurueckgesetzt hat, bevor dieser Save ueberhaupt
        // startet.
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
        try context.save()
        XCTAssertEqual(day.name, originalName)
        XCTAssertEqual(Set(day.activeExercises.map(\.persistentModelID)), originalExerciseIDs)
    }

    /// Begrenzter Commit-Scope: wenn kein einziger Tag neu geschrieben wurde
    /// (hier: jeder Tag durch eine Session blockiert), darf `recalculate`
    /// erst gar keinen Save versuchen — der auf "immer werfen" gesetzte
    /// Override darf in diesem Fall NICHT feuern.
    func testRecalculateSkipsSaveEntirelyWhenNothingWasRewritten() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        for day in plan.days where day.type != .rest {
            context.insert(WorkoutSession(isCompleted: true, day: day))
        }

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary.rewrittenCount, 0)
        XCTAssertEqual(summary.skippedDueToHistoryCount, 2)
    }

    // MARK: - Task #197, zweite Korrekturrunde: drei eng begrenzte Vertragsluecken

    /// Nachbesserung (zweite Korrekturrunde, geforderter Test "Erfolgreiche Aktivierung ist auch im
    /// aufrufenden Context korrekt sichtbar"): ein eigener, expliziter Beweis fuer die
    /// Scratch-Context-Rueckbindung auf dem GLUECKSPFAD (kein Fehler) - nicht nur ein Nebeneffekt
    /// anderer Tests, die dasselbe implizit mitpruefen.
    func testBuildReturnsAPlanThatIsVisibleAndActiveInTheCallerContext() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        XCTAssertTrue(plan.isActive)

        let fetchedPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(fetchedPlans.count, 1)
        let fetchedPlan = try XCTUnwrap(fetchedPlans.first)
        XCTAssertEqual(fetchedPlan.persistentModelID, plan.persistentModelID)
        XCTAssertTrue(fetchedPlan.isActive)
        XCTAssertTrue(fetchedPlan === plan, "muss dasselbe, im Aufrufer-Context lebende Objekt sein")
    }

    /// Nachbesserung (zweite Korrekturrunde, Punkt B): ein TRANSIENTER Rueckbindungsfehler (z.B.
    /// eine kurze Stoerung) darf nicht sofort den Aufrufer erreichen - `createPlan` versucht GENAU
    /// EINMAL erneut aufzuloesen, BEVOR irgendein Fehler nach aussen dringt. Gelingt der zweite
    /// Versuch, kehrt `createPlan` ganz normal mit dem Plan zurueck - der Aufrufer bemerkt nichts.
    func testCreatePlanTransparentlyRecoversFromATransientRebindFailure() throws {
        let profile = makeProfile()
        var rebindAttempts = 0
        PlanGeneratorInstantiator.rebindOverrideForTesting = { id, ctx in
            rebindAttempts += 1
            // Erster Versuch (innerhalb von `build`) schlaegt fehl, zweiter (`createPlan`s
            // interner Retry) nutzt die echte Aufloesung.
            return rebindAttempts == 1 ? nil : (ctx.model(for: id) as? TrainingPlan)
        }

        let plan = try XCTUnwrap(PlanGeneratorInstantiator.createPlan(
            from: input([selection(.barbell, days: 2)]), for: profile, generationSource: .manual, in: context
        ))
        XCTAssertTrue(plan.isActive)
        XCTAssertEqual(rebindAttempts, 2, "genau ein automatischer Wiederholungsversuch, kein weiterer")

        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "trotz des transienten Fehlers darf nur EIN Plan existieren")
    }

    /// Nachbesserung (zweite Korrekturrunde, geforderter Test "Commit erfolgreich + Rueckbindung
    /// fehlgeschlagen -> Retry ohne Duplikat"): scheitert auch `createPlan`s interner
    /// Wiederholungsversuch, muss `createdButRebindFailed` (NICHT `saveFailed`) geworfen werden -
    /// der Plan ist trotzdem bereits echt persistiert (Beweis ueber einen DRITTEN, frischen
    /// Context). Eine SPAETERE Wiederaufnahme ueber dieselbe ID (nachdem die Stoerung behoben ist)
    /// darf NIEMALS einen zweiten Plan anlegen.
    func testCreatePlanThrowsCreatedButRebindFailedAndLaterResolvesWithoutDuplicate() throws {
        let profile = makeProfile()
        PlanGeneratorInstantiator.rebindOverrideForTesting = { _, _ in nil }

        var capturedPlanID: PersistentIdentifier?
        XCTAssertThrowsError(try PlanGeneratorInstantiator.createPlan(
            from: input([selection(.barbell, days: 2)]), for: profile, generationSource: .manual, in: context
        )) { error in
            guard let creationError = error as? PlanGeneratorInstantiator.PlanCreationError,
                  case .createdButRebindFailed(let planID) = creationError else {
                XCTFail("falscher Fehlertyp, erwartet .createdButRebindFailed: \(error)")
                return
            }
            capturedPlanID = planID
        }
        let planID = try XCTUnwrap(capturedPlanID)

        // Der Plan EXISTIERT bereits persistiert, trotz des geworfenen Fehlers - ueber einen
        // DRITTEN, frischen Context nachgewiesen (nicht den Aufrufer-Context, dessen In-Memory-
        // Zustand hier nichts ueber den tatsaechlichen Store-Inhalt beweist).
        let verificationContext = ModelContext(container)
        let persistedPlans = try verificationContext.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(persistedPlans.count, 1, "der Plan muss trotz createdButRebindFailed bereits gespeichert sein")

        // "Retry": die Stoerung ist vorbei, erneut ueber DIESELBE ID aufloesen - OHNE
        // build/createPlan nochmal aufzurufen.
        PlanGeneratorInstantiator.rebindOverrideForTesting = nil
        let resolved = PlanGeneratorInstantiator.resolveCreatedPlan(id: planID, in: context)
        XCTAssertEqual(resolved?.persistentModelID, planID, "Wiederaufnahme ueber dieselbe ID muss nach Behebung gelingen")

        let allPlansAfterRetry = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlansAfterRetry.count, 1, "die Wiederaufnahme darf NIE einen zweiten Plan anlegen")
    }

    /// Nachbesserung (zweite Korrekturrunde, geforderter Test "Fremde offene Aenderung ueberlebt
    /// recalculate ungespeichert"): eine Aenderung an einem voellig unabhaengigen Objekt (hier ein
    /// frisch inserted `UserBodyProfile`, ohne jede Beziehung zu `plan`) muss `recalculate` VOR
    /// jeder eigenen Mutation blockieren - und darf von einem danach versuchten Save nicht
    /// mitgenommen worden sein.
    func testRecalculateBlocksWhenAnUnrelatedIndependentChangeIsPending() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })
        let originalName = day.name
        let originalExerciseIDs = Set(day.activeExercises.map(\.persistentModelID))

        let independentProfile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        context.insert(independentProfile)
        XCTAssertTrue(context.hasChanges, "Testvoraussetzung: die fremde Aenderung muss selbst noch ungespeichert sein")

        XCTAssertThrowsError(try PlanGeneratorInstantiator.recalculate(plan, in: context)) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.RecalculateError, .independentChangesPending)
        }

        XCTAssertEqual(day.name, originalName, "keine Mutation am Plan")
        XCTAssertEqual(Set(day.activeExercises.map(\.persistentModelID)), originalExerciseIDs)

        // Die fremde Aenderung ist WEITERHIN nur im Aufrufer-Context pending, nicht gespeichert -
        // Gegenprobe ueber einen DRITTEN, frischen Context auf demselben Container.
        let verificationContext = ModelContext(container)
        let savedProfiles = try verificationContext.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertTrue(savedProfiles.isEmpty, "unabhaengige Aenderung darf von recalculate nicht gespeichert worden sein")
    }

    /// Regressionsschutz (zweite Korrekturrunde): eine noch nicht autogespeicherte Aenderung AM
    /// SELBEN Plan (z.B. ein in `PlanEditorView` gerade editiertes `customName` -
    /// `TrainingPlan` ist dort ein `@Bindable`-Autosave-Screen) ist KEIN "fremder" Zustand und
    /// darf `recalculate` NICHT blockieren - siehe `hasIndependentPendingChanges`-Doku. Ein
    /// simples `context.hasChanges` haette hier faelschlich abgebrochen.
    func testRecalculateIsNotBlockedByAPendingEditOnTheSamePlan() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        plan.customName = "Noch nicht gespeicherte Umbenennung"
        XCTAssertTrue(context.hasChanges, "Testvoraussetzung: die eigene Aenderung muss selbst noch ungespeichert sein")

        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertGreaterThan(summary.rewrittenCount, 0, "eine ausstehende Aenderung AM SELBEN Plan darf recalculate nicht blockieren")
        XCTAssertEqual(plan.customName, "Noch nicht gespeicherte Umbenennung", "recalculate ruehrt plan.customName (Plan-Ebene) nicht an")
    }
}
#endif
