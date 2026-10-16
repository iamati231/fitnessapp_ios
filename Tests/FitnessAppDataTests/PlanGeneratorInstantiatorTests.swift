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
        generationSource: GenerationSource = .manual
    ) -> TrainingPlan? {
        PlanGeneratorInstantiator.build(
            from: input, in: context,
            environment: environment, equipmentProfile: equipmentProfile,
            result: precomputed, generationSource: generationSource
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

    func testBuildReturnsNilWhenGeneratorProducesNoDays() {
        // Kein Selections-Eintrag -> PlanGenerator.generate liefert leer.
        XCTAssertNil(buildPlan(from: input([])))
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
    func testCreatePlanReturnsNilWhenGeneratorProducesNoDays() {
        let profile = makeProfile()
        XCTAssertNil(PlanGeneratorInstantiator.createPlan(
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
    func testRecalculateSucceedsNormallyWithoutOverride() throws {
        let plan = try XCTUnwrap(buildPlan(from: input([selection(.barbell, days: 2)])))
        let summary = try PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(summary, .init(rewrittenCount: 0, skippedDueToHistoryCount: 0),
                       "frisch gebaute, unveraenderte Tage haben bereits den aktuellen Fingerprint - nichts zu tun, aber kein Fehler")
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
}
#endif
