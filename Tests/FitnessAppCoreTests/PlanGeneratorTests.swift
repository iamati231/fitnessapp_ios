import XCTest
@testable import FitnessAppCore

final class PlanGeneratorTests: XCTestCase {

    private func selection(
        _ kind: TrainingTypeKind,
        days: Int,
        minutes: Int = 45,
        experience: DifficultyLevel = .intermediate,
        timeFormat: WorkoutTimeFormat? = nil
    ) -> PlanGeneratorTypeSelection {
        PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: minutes, experience: experience, timeFormat: timeFormat)
    }

    private func input(
        _ selections: [PlanGeneratorTypeSelection],
        equipment: Set<Equipment> = [],
        usesFixedWeekdays: Bool = false,
        fixedWeekdays: [Int] = []
    ) -> PlanGeneratorInput {
        PlanGeneratorInput(
            selections: selections,
            equipmentPreferences: equipment,
            usesFixedWeekdays: usesFixedWeekdays,
            fixedWeekdays: fixedWeekdays
        )
    }

    // MARK: - Grundlagen

    func testEmptySelectionsProducesEmptyResult() {
        let result = PlanGenerator.generate(from: input([]))
        XCTAssertTrue(result.days.isEmpty)
        XCTAssertNil(result.explanationKey)
    }

    func testSingleStrengthTypeProducesRequestedDayCount() {
        let result = PlanGenerator.generate(from: input([selection(.barbell, days: 3)]))
        XCTAssertEqual(result.days.count, 3)
    }

    func testDaysAreSequentiallyIndexedFromOne() {
        let result = PlanGenerator.generate(from: input([selection(.dumbbell, days: 4)]))
        let indices = result.days.map(\.spec.sequenceIndex)
        XCTAssertEqual(indices, [1, 2, 3, 4])
    }

    // MARK: - README 2.20: Kettlebell-EMOM-Finisher

    func testKettlebellThreeDaysAddsExactlyOneEmomFinisher() {
        // 45 Min (Test-Default) liegt oberhalb des EMOM-Finisher-Deckels,
        // wird also auf das Maximum von 30 geklemmt (Bugfix, Audit: vorher
        // fix 20, unabhaengig von der gewaehlten Sessiondauer).
        let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3)]))
        let emomDays = result.days.filter { $0.spec.timeFormat == .emom }
        XCTAssertEqual(emomDays.count, 1)
        XCTAssertEqual(emomDays.first?.spec.timeCapMinutes, 30)
    }

    /// Bugfix (Audit): der EMOM-Finisher-Deckel muss die vom User gewaehlte
    /// Sessiondauer respektieren (auf einen sinnvollen EMOM-Bereich
    /// geklemmt), nicht immer denselben Fixwert liefern.
    func testKettlebellEmomFinisherCapScalesWithSessionDurationWithinBounds() {
        let short = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3, minutes: 15)]))
        XCTAssertEqual(short.days.first { $0.spec.timeFormat == .emom }?.spec.timeCapMinutes, 15)

        let midRange = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3, minutes: 20)]))
        XCTAssertEqual(midRange.days.first { $0.spec.timeFormat == .emom }?.spec.timeCapMinutes, 20)

        let veryShort = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3, minutes: 5)]))
        XCTAssertEqual(veryShort.days.first { $0.spec.timeFormat == .emom }?.spec.timeCapMinutes, 10, "unter 10 Minuten lohnt sich die Rotation kaum")

        let veryLong = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3, minutes: 120)]))
        XCTAssertEqual(veryLong.days.first { $0.spec.timeFormat == .emom }?.spec.timeCapMinutes, 30, "ueber 30 Minuten waere ein \"Finisher\" kein Finisher mehr")
    }

    func testKettlebellTwoDaysHasNoEmomFinisher() {
        // README 2.20: der Finisher gilt nur ab >=3 Tagen.
        let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: 2)]))
        XCTAssertTrue(result.days.allSatisfy { $0.spec.timeFormat == nil })
    }

    // MARK: - README 2.21: Tages-Titel-Kollision

    /// Nutzer-Feedback: `muscleFocusLabel` konnte bei mehreren Krafttagen
    /// derselben Art denselben Titel liefern (z.B. zwei Kettlebell-Tage
    /// beide "Push & Pull"), obwohl sich die Uebungen unterscheiden
    /// (`group[dayIndex % group.count]` waehlt andere Uebungen, nur die
    /// ERSTEN ZWEI Muskel-Kategorien sind identisch). Testet die Erwartung
    /// black-box statt die interne Kollisions-Ursache nachzubilden - egal
    /// WELCHE Tage kollidieren, `disambiguateDuplicateNames` muss sie
    /// eindeutig machen.
    func testStrengthDaysOfSameKindNeverShareIdenticalName() {
        for days in 2...6 {
            let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: days)]))
            let names = result.days.map { $0.spec.name }
            XCTAssertEqual(names.count, Set(names).count, "Tages-Titel wiederholen sich bei \(days) Tagen: \(names)")
        }
    }

    /// Bugfix (Audit): `UInt8(65 + letterIndex)` produzierte ab dem 27.
    /// Duplikat entweder Muell-Zeichen oder trapte per Ueberlauf. Nicht
    /// ueber die UI erreichbar (Cap: 7 Tage/Woche insgesamt), aber der
    /// Core-API selbst fehlt diese Grenze - erzwingt die Kollision direkt
    /// ueber `PlanGeneratorTypeSelection`, das den UI-Cap nicht kennt.
    /// Radfahren-Tage teilen sich IMMER denselben Basisnamen, daher
    /// garantiert `days: 30` genau 30 Kollisionen in einem Aufruf.
    func testDisambiguationSuffixFallsBackToNumbersPastTwentySixDuplicates() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 30)]))
        let names = Set(result.days.map { $0.spec.name })
        XCTAssertEqual(names.count, 30, "alle 30 Titel muessen trotz Buchstaben-Ueberlauf eindeutig bleiben")
        XCTAssertTrue(names.contains("Radfahren Z"), "26. Duplikat bekommt noch den letzten Buchstaben")
        XCTAssertTrue(names.contains("Radfahren 27"), "27. Duplikat muss auf einen Zahlen-Fallback ausweichen")
        XCTAssertTrue(names.contains("Radfahren 30"))
    }

    func testCardioDaysOfSameKindNeverShareIdenticalName() {
        for days in 2...7 {
            let cycling = PlanGenerator.generate(from: input([selection(.cycling, days: days)]))
            let cyclingNames = cycling.days.map { $0.spec.name }
            XCTAssertEqual(cyclingNames.count, Set(cyclingNames).count, "Radfahren-Titel wiederholen sich bei \(days) Tagen: \(cyclingNames)")

            let running = PlanGenerator.generate(from: input([selection(.running, days: days)]))
            let runningNames = running.days.map { $0.spec.name }
            XCTAssertEqual(runningNames.count, Set(runningNames).count, "Lauf-Titel wiederholen sich bei \(days) Tagen: \(runningNames)")
        }
    }

    // MARK: - README 2.20: Lauf-Typologie

    func testRunningThreeDaysCoversAllThreeZones() {
        let result = PlanGenerator.generate(from: input([selection(.running, days: 3)]))
        let exerciseNames = Set(result.days.flatMap { $0.spec.exercises.map(\.name) })
        XCTAssertEqual(exerciseNames, ["Easy Run", "Long Run", "Intervalle"])
        // Paket 2 (Sportart-Unterscheidung): muss am Entstehungsort gesetzt
        // werden, nicht erst spaeter aus dem Namen zurueckgeraten.
        XCTAssertTrue(result.days.allSatisfy { $0.spec.exercises.allSatisfy { $0.enduranceSportKind == .running } })
    }

    func testRunningTwoDaysNeverPlacesTwoHardZonesTogether() {
        // README 2.20 (18/20): "ruhig" deckt genau diese Luecke bei 2 Tagen.
        let result = PlanGenerator.generate(from: input([selection(.running, days: 2)]))
        let names = result.days.map { $0.spec.exercises.first?.name }
        XCTAssertTrue(names.contains("Easy Run"), "2-Tage-Zyklus muss die ruhige Zone enthalten")
    }

    func testCyclingProducesUniformCandidatesWithoutZones() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 2)]))
        XCTAssertEqual(result.days.count, 2)
        XCTAssertTrue(result.days.allSatisfy { $0.spec.exercises.map(\.name) == ["Radfahren (outdoor)"] })
        XCTAssertTrue(result.days.allSatisfy { $0.spec.exercises.allSatisfy { $0.enduranceSportKind == .cycling } })
    }

    // MARK: - DEL-098-Datentreue: keine erfundenen Uebungsnamen

    /// Regression: ein frueherer Entwurf dieses Generators benutzte erfundene
    /// Namen fuer Cardio-Uebungen ("exercise.name.run" etc.), wodurch
    /// `ProgramInstantiator`s namensbasierter Library-Abgleich fehlschlug und
    /// generische Isolations-Defaults statt der getunten DEL-098-Faktoren
    /// eingesetzt wurden. Jeder erzeugte `ExerciseSpec.name` MUSS ein exakter
    /// Treffer in `ExerciseLibraryData.all` sein.
    func testAllGeneratedExerciseNamesExistInLibrary() {
        let allKinds: [PlanGeneratorTypeSelection] = TrainingTypeKind.allCases.map {
            selection($0, days: $0.isCardio ? 2 : 3)
        }
        let result = PlanGenerator.generate(from: input(allKinds))
        let libraryNames = Set(ExerciseLibraryData.all.map(\.name))
        for day in result.days {
            for exercise in day.spec.exercises {
                XCTAssertTrue(
                    libraryNames.contains(exercise.name),
                    "\"\(exercise.name)\" (Tag \"\(day.spec.name)\") ist kein exakter Library-Treffer"
                )
            }
        }
    }

    func testBeginnerExperienceOnlyPicksBeginnerExercises() {
        let result = PlanGenerator.generate(from: input([selection(.barbell, days: 2, experience: .beginner)]))
        let specByName = Dictionary(uniqueKeysWithValues: ExerciseLibraryData.all.map { ($0.name, $0) })
        for day in result.days {
            for exercise in day.spec.exercises {
                XCTAssertEqual(specByName[exercise.name]?.difficultyLevel, .beginner)
            }
        }
    }

    // MARK: - Belastungs-Kapsel (relativ, siehe PlanGenerator.loadLevels)

    func testSingleDayResultGetsMediumLoadLevel() {
        let result = PlanGenerator.generate(from: input([selection(.barbell, days: 1)]))
        XCTAssertEqual(result.days.count, 1)
        XCTAssertEqual(result.days.first?.loadLevel, .medium)
    }

    // MARK: - Erklaerungs-Satz

    func testSingleTypeProducesNoExplanation() {
        let result = PlanGenerator.generate(from: input([selection(.barbell, days: 4)]))
        XCTAssertNil(result.explanationKey)
    }

    func testMixedTypesWithEnoughDaysProducesExplanation() {
        let result = PlanGenerator.generate(from: input([
            selection(.kettlebell, days: 3),
            selection(.running, days: 2)
        ]))
        XCTAssertNotNil(result.explanationKey)
    }

    // MARK: - Bugfix (Nutzer-Feedback): "Neu rechnen" liefert keine neuen Plaene

    /// Regressions-Schutz: `shuffle` ist additiv, jeder bestehende Aufrufer
    /// (u.a. `PlanGeneratorInstantiator.recalculate`, alle anderen Tests in
    /// dieser Datei) ruft `generate(from:)` ohne den Parameter auf und muss
    /// exakt das alte, deterministische Verhalten behalten.
    func testShuffleFalseKeepsGenerateFullyDeterministic() {
        let selections = [selection(.barbell, days: 5, experience: .advanced)]
        let withoutParameter = PlanGenerator.generate(from: input(selections))
        let explicitFalse = PlanGenerator.generate(from: input(selections), shuffle: false)
        XCTAssertEqual(exerciseFingerprint(withoutParameter), exerciseFingerprint(explicitFalse))
    }

    /// Kern der Ticket-Anforderung: `shuffle: true` muss ueber mehrere
    /// Versuche mindestens einmal eine andere Uebungsauswahl liefern als die
    /// deterministische Baseline. `.advanced` erlaubt alle drei
    /// Schwierigkeitsstufen und maximiert damit den Pool pro Muskelgruppe -
    /// je groesser der Pool, desto unwahrscheinlicher, dass 30 gemischte
    /// Versuche rein zufaellig alle exakt auf der Baseline-Reihenfolge
    /// landen (kein `.shuffled()`-Determinismus vorausgesetzt - der Test
    /// wertet ueber viele Versuche aus statt einen einzelnen Lauf zu fixieren).
    func testShuffleTrueCanProduceADifferentExerciseSelection() {
        let selections = [selection(.barbell, days: 5, experience: .advanced)]
        let baseline = exerciseFingerprint(PlanGenerator.generate(from: input(selections)))

        let foundDifferentVariant = (0..<30).contains { _ in
            exerciseFingerprint(PlanGenerator.generate(from: input(selections), shuffle: true)) != baseline
        }
        XCTAssertTrue(foundDifferentVariant, "shuffle: true muss ueber mehrere Versuche mindestens einmal eine andere Uebungsauswahl liefern")
    }

    /// Mischen darf nur WELCHE Uebungen gezogen werden aendern - Tagesanzahl,
    /// die Kettlebell->EMOM-Finisher-Regel (genau ein EMOM-Tag ab 3 Tagen)
    /// und die Eindeutigkeit der Tagesnamen (`disambiguateDuplicateNames`)
    /// muessen unabhaengig davon weiter gelten.
    func testShuffleTruePreservesDayCountFormatsAndUniqueNames() {
        let selections = [selection(.kettlebell, days: 4, experience: .advanced)]
        let baseline = PlanGenerator.generate(from: input(selections))
        let shuffled = PlanGenerator.generate(from: input(selections), shuffle: true)

        XCTAssertEqual(shuffled.days.count, baseline.days.count)
        XCTAssertEqual(shuffled.days.filter { $0.spec.timeFormat == .emom }.count, 1)
        XCTAssertEqual(Set(shuffled.days.map(\.spec.name)).count, shuffled.days.count,
                       "Namensdisambiguierung muss auch nach dem Mischen jeden Tagesnamen eindeutig halten")
    }

    /// README 2.20/Bugfix-Kommentar in `PlanGenerator.generate`: Cardio hat
    /// pro Lauf-Zone nur eine feste Uebung (kein Pool), `shuffle` darf die
    /// Cardio-Auswahl deshalb gar nicht veraendern - nur die Kraft-Kandidaten
    /// werden gemischt.
    func testShuffleTrueDoesNotAffectCardioExerciseChoice() {
        let selections = [selection(.running, days: 5)]
        let baseline = exerciseFingerprint(PlanGenerator.generate(from: input(selections)))
        let shuffled = exerciseFingerprint(PlanGenerator.generate(from: input(selections), shuffle: true))
        XCTAssertEqual(baseline, shuffled)
    }

    private func exerciseFingerprint(_ result: PlanGenerator.Result) -> [[String]] {
        result.days.map { $0.spec.exercises.map(\.name) }
    }

    // MARK: - DEL-247: localizationKey fuer generierte Tage

    /// Kernanforderung des Tickets: JEDER generierte Tag muss einen
    /// aufloesbaren Key tragen, unabhaengig von Trainingsart - vorher war
    /// `localizationKey` fuer diesen Codepfad immer `nil`.
    func testEveryGeneratedDayHasANonEmptyLocalizationKey() {
        let allKinds: [PlanGeneratorTypeSelection] = TrainingTypeKind.allCases.map {
            selection($0, days: $0.isCardio ? 2 : 3)
        }
        let result = PlanGenerator.generate(from: input(allKinds))
        for day in result.days {
            XCTAssertNotNil(day.spec.localizationKey, "Tag \"\(day.spec.name)\" hat keinen localizationKey")
            XCTAssertFalse(day.spec.localizationKey?.isEmpty ?? true)
        }
    }

    /// Radfahren komponiert `name`/`localizationKey` aus genau EINEM Teil
    /// (kein Fokus-Zusatz) - der Key muss exakt `TrainingTypeKind.cycling.
    /// titleKey` sein, ohne jeden Trennzeichen-Zusatz.
    func testCyclingLocalizationKeyIsBareKindKey() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 1)]))
        XCTAssertEqual(result.days.first?.spec.localizationKey, "planBuilder.type.cycling")
    }

    /// Derselbe rohe Buchstaben-Suffix, den `disambiguateDuplicateNames` an
    /// `name` haengt ("Radfahren B"), muss ans `#`-Ende des Keys wandern -
    /// sonst driften Anzeige (aus `name`, Fallback) und Key (aus
    /// `localizationKey`, Regelfall) fuer EN/TR-Nutzer auseinander.
    func testCyclingDisambiguationSuffixAppearsOnBothNameAndKey() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 2)]))
        let sorted = result.days.sorted { $0.spec.name < $1.spec.name }
        XCTAssertEqual(sorted.map(\.spec.name), ["Radfahren A", "Radfahren B"])
        XCTAssertEqual(sorted.map(\.spec.localizationKey), ["planBuilder.type.cycling#A", "planBuilder.type.cycling#B"])
    }

    /// Die drei Lauf-Zonen-Titel sind komplett eigenstaendige Keys (kein
    /// `kind·focus`-Aufbau, siehe `RunZone.localizationKey`-Dokumentation).
    func testRunningZonesMapToTheirOwnStandaloneKeys() {
        let result = PlanGenerator.generate(from: input([selection(.running, days: 3)]))
        let keys = Set(result.days.compactMap(\.spec.localizationKey))
        XCTAssertEqual(keys, ["planBuilder.day.runEasy", "planBuilder.day.runTempo", "planBuilder.day.runInterval"])
    }

    /// Kettlebell-EMOM-Finisher komponiert immer `kind·day_type.full_body` -
    /// unabhaengig davon, welche Uebungen der Pool liefert.
    func testKettlebellEmomFinisherKeyComposesKindAndFullBody() {
        let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3)]))
        let emomDay = result.days.first { $0.spec.timeFormat == .emom }
        XCTAssertEqual(emomDay?.spec.localizationKey, "planBuilder.type.kettlebell·day_type.full_body")
    }

    /// Krafttage komponieren `kind·focus` - `focus` ist entweder eine
    /// `day_type.*`/`muscle.core`-Kategorie (moeglicherweise `&`-verbunden zu
    /// zweit) oder der "Ganzkoerper N"-Fallback mit rohem Zahlen-Suffix.
    /// Statt einen konkreten Fokus vorherzusagen (haengt von der Library-
    /// Reihenfolge ab), prueft dieser Test die FORM: erster Teil ist immer
    /// der Kind-Key, jeder Bestandteil danach ist entweder ein bekannter
    /// Fokus-Key oder der Ganzkoerper-Fallback mit Ziffern-Suffix.
    func testStrengthDayLocalizationKeyStartsWithKindKeyAndHasValidFocus() {
        let knownFocusKeys: Set<String> = ["day_type.push", "day_type.pull", "day_type.legs", "muscle.core"]
        for kind in [TrainingTypeKind.barbell, .dumbbell, .kettlebell, .bodyweight] {
            let result = PlanGenerator.generate(from: input([selection(kind, days: 4)]))
            for day in result.days where day.spec.timeFormat != .emom {
                guard let key = day.spec.localizationKey else {
                    XCTFail("Krafttag \"\(day.spec.name)\" hat keinen localizationKey")
                    continue
                }
                XCTAssertTrue(key.hasPrefix("\(kind.titleKey)·"), "\"\(key)\" beginnt nicht mit dem Kind-Key von \(kind)")
                let focusPart = key
                    .dropFirst(kind.titleKey.count + 1)
                    .split(separator: "#").first.map(String.init) ?? ""
                let isKnownFocus = focusPart.split(separator: "&").allSatisfy { knownFocusKeys.contains(String($0)) }
                let isFullBodyFallback = focusPart == "day_type.full_body"
                XCTAssertTrue(isKnownFocus || isFullBodyFallback, "unerwarteter Fokus-Teil \"\(focusPart)\" in \"\(key)\"")
            }
        }
    }

    /// Regressionsschutz fuer den in `disambiguateDuplicateNames` dokumentierten
    /// Fall: `name` und `localizationKey` muessen fuer JEDEN generierten Tag
    /// dieselbe Anzahl an "Teilen" haben (Trennzeichen " · "/" & " in `name`
    /// vs. `·`/`&` im Key) - sonst haetten sich die zwei parallelen
    /// Repraesentationen auseinanderentwickelt.
    func testNameAndLocalizationKeySegmentCountsStayInSyncAcrossAllKinds() {
        let allKinds: [PlanGeneratorTypeSelection] = TrainingTypeKind.allCases.map {
            selection($0, days: $0.isCardio ? 3 : 4)
        }
        let result = PlanGenerator.generate(from: input(allKinds))
        for day in result.days {
            guard let key = day.spec.localizationKey else {
                XCTFail("Tag \"\(day.spec.name)\" hat keinen localizationKey")
                continue
            }
            let nameSegments = day.spec.name
                .components(separatedBy: " · ")
                .flatMap { $0.components(separatedBy: " & ") }
                .count
            let keySegments = key
                .split(separator: "#").first.map(String.init).map { keyPart -> Int in
                    keyPart.split(separator: "·").flatMap { $0.split(separator: "&") }.count
                } ?? 0
            XCTAssertEqual(nameSegments, keySegments, "Segment-Anzahl weicht ab: name=\"\(day.spec.name)\" key=\"\(key)\"")
        }
    }

    // MARK: - README 2.35: Zeitformat fuer Laufen/Radfahren

    func testRunningAmrapProducesSingleRepeatedTimedExercise() {
        let result = PlanGenerator.generate(from: input([selection(.running, days: 2, timeFormat: .amrap)]))
        XCTAssertEqual(result.days.count, 2)
        for day in result.days {
            XCTAssertEqual(day.spec.timeFormat, .amrap)
            XCTAssertEqual(day.spec.exercises.map(\.name), ["Lauf-Intervall"])
            XCTAssertEqual(day.spec.exercises.first?.sets, 1, "AMRAP zaehlt Runden live, nicht ueber `sets`")
            XCTAssertEqual(day.spec.exercises.first?.enduranceSportKind, .running)
        }
    }

    func testCyclingEmomProducesSingleRepeatedTimedExercise() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 2, timeFormat: .emom)]))
        XCTAssertEqual(result.days.count, 2)
        for day in result.days {
            XCTAssertEqual(day.spec.timeFormat, .emom)
            XCTAssertEqual(day.spec.exercises.map(\.name), ["Rad-Intervall"])
            XCTAssertEqual(day.spec.exercises.first?.sets, 1, "EMOM zaehlt Minuten live, nicht ueber `sets`")
        }
    }

    /// README 2.35: Auf Zeit hat keine live-gezaehlten Runden wie AMRAP/EMOM -
    /// `ForTimePlayerView` hakt stattdessen `sets` viele Boxen ab, deshalb
    /// braucht nur dieses Format eine echte Rundenzahl > 1.
    func testRunningForTimeSetsFiveRoundsAndNoTimeCap() {
        let result = PlanGenerator.generate(from: input([selection(.running, days: 1, timeFormat: .forTime)]))
        XCTAssertEqual(result.days.first?.spec.exercises.first?.sets, 5)
        XCTAssertNil(result.days.first?.spec.timeCapMinutes, "Auf Zeit hat wie die kuratierten ForTime-Vorlagen ueblicherweise keinen Deckel")
    }

    /// Gleiches Klemm-Verhalten wie der bestehende Kettlebell-EMOM-Finisher
    /// (`testKettlebellEmomFinisherCapScalesWithSessionDurationWithinBounds`) -
    /// derselbe [10, 30]-Bereich, hier fuer AMRAP/EMOM auf Lauf-/Rad-Tagen.
    func testRunningAmrapTimeCapScalesWithSessionDurationWithinBounds() {
        let short = PlanGenerator.generate(from: input([selection(.running, days: 1, minutes: 15, timeFormat: .amrap)]))
        XCTAssertEqual(short.days.first?.spec.timeCapMinutes, 15)

        let veryShort = PlanGenerator.generate(from: input([selection(.running, days: 1, minutes: 5, timeFormat: .amrap)]))
        XCTAssertEqual(veryShort.days.first?.spec.timeCapMinutes, 10)

        let veryLong = PlanGenerator.generate(from: input([selection(.running, days: 1, minutes: 120, timeFormat: .amrap)]))
        XCTAssertEqual(veryLong.days.first?.spec.timeCapMinutes, 30)
    }

    func testTimedCardioDaysOfSameKindNeverShareIdenticalName() {
        let result = PlanGenerator.generate(from: input([selection(.cycling, days: 5, timeFormat: .emom)]))
        let names = result.days.map { $0.spec.name }
        XCTAssertEqual(names.count, Set(names).count, "Zeitformat-Radfahren-Titel wiederholen sich: \(names)")
    }

    /// Regressionsschutz analog zu `testAllGeneratedExerciseNamesExistInLibrary`:
    /// die neuen `isTimeBased`-Cardio-Eintraege muessen exakte Library-Treffer
    /// sein, sonst faellt `ProgramInstantiator` auf generische Isolations-
    /// Defaults zurueck UND `isTimeBased` bleibt faelschlich `false`.
    func testTimedCardioExerciseNamesExistInLibraryAndAreTimeBased() {
        let libraryByName = Dictionary(uniqueKeysWithValues: ExerciseLibraryData.all.map { ($0.name, $0) })
        for (kind, format, expectedName) in [
            (TrainingTypeKind.running, WorkoutTimeFormat.amrap, "Lauf-Intervall"),
            (TrainingTypeKind.cycling, WorkoutTimeFormat.emom, "Rad-Intervall")
        ] {
            let result = PlanGenerator.generate(from: input([selection(kind, days: 1, timeFormat: format)]))
            let exerciseName = result.days.first?.spec.exercises.first?.name
            XCTAssertEqual(exerciseName, expectedName)
            let libraryEntry = exerciseName.flatMap { libraryByName[$0] }
            XCTAssertEqual(libraryEntry?.isTimeBased, true, "\(expectedName) muss isTimeBased sein, sonst zeigt der Player \"Wdh.\" statt \"Sek.\"")
            XCTAssertEqual(libraryEntry?.isCardio, true)
        }
    }

    /// README 2.35: die vier Kraft-Arten haben keinen Format-Picker im
    /// Assistenten - `PlanGeneratorTypeSelection.timeFormat` existiert zwar
    /// als Feld auf dem Typ, `strengthCandidates`/`kettlebellEmomCandidate`
    /// duerfen es aber nie lesen, damit ein (UI-seitig ohnehin unerreichbares)
    /// gesetztes Feld dort keine stille Verhaltensaenderung ausloest.
    func testTimeFormatOnStrengthKindsIsIgnoredByGenerator() {
        let withFormat = PlanGenerator.generate(from: input([selection(.barbell, days: 3, timeFormat: .amrap)]))
        let withoutFormat = PlanGenerator.generate(from: input([selection(.barbell, days: 3)]))
        XCTAssertEqual(withFormat.days.map(\.spec.name), withoutFormat.days.map(\.spec.name))
        XCTAssertTrue(withFormat.days.allSatisfy { $0.spec.timeFormat == nil })
    }

    /// `PlanGeneratorInput` wird als JSON auf `TrainingPlan.generatorInputRaw`
    /// gespeichert ("neu rechnen"), `timeFormat` muss also verlustfrei durch
    /// Encode/Decode kommen.
    func testTimeFormatSurvivesJSONRoundtrip() {
        let original = selection(.running, days: 2, timeFormat: .emom)
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(PlanGeneratorTypeSelection.self, from: data)
        XCTAssertEqual(decoded.timeFormat, .emom)
    }

    /// Bugfix-Vorbeugung: ein VOR diesem Feld gespeicherter `generatorInputRaw`-
    /// Snapshot hat gar keinen "timeFormat"-Schluessel im JSON - muss trotzdem
    /// ohne Fehler zu `nil` decodieren, sonst wuerde "neu rechnen" fuer jeden
    /// bereits bestehenden Plan mit einem Decode-Fehler abbrechen.
    func testMissingTimeFormatKeyDecodesToNilForBackwardCompatibility() {
        let legacyJSON = """
        {"kind":"running","daysPerWeek":2,"sessionDurationMinutes":45,"experience":"intermediate"}
        """
        let decoded = try! JSONDecoder().decode(PlanGeneratorTypeSelection.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.timeFormat)
    }

    // MARK: - P2.4: Public Inits für externe Rekonstruktion (PlanBuilderView/PlanDraft)

    /// `PlanBuilderView` haelt die bearbeitete Wochenvorschau ab P2.4 in einem
    /// `PlanDraft` und muss daraus spaeter wieder ein `PlanGenerator.Result`
    /// zusammensetzen (siehe dortige `currentResult`), um den unveraenderten
    /// `onGenerated`-Vertrag zu bedienen. Vorher hatten `GeneratedDay`/`Result`
    /// nur einen `internal` Memberwise-Init (ein `public struct` mit
    /// ausschliesslich `public let`-Feldern bekommt in Swift trotzdem keinen
    /// `public` Init synthetisiert). Dieser Test belegt, dass die neuen
    /// expliziten Inits ein Resultat verlustfrei rekonstruieren.
    func testGeneratedDayAndResultPublicInitsReconstructEquivalentResult() {
        let original = PlanGenerator.generate(from: input([selection(.barbell, days: 3)]))
        XCTAssertFalse(original.days.isEmpty)

        let reconstructedDays = original.days.map {
            PlanGenerator.Result.GeneratedDay(spec: $0.spec, loadLevel: $0.loadLevel)
        }
        let reconstructed = PlanGenerator.Result(days: reconstructedDays, explanationKey: original.explanationKey)

        XCTAssertEqual(reconstructed.days.map(\.spec.name), original.days.map(\.spec.name))
        XCTAssertEqual(reconstructed.days.map(\.spec.sequenceIndex), original.days.map(\.spec.sequenceIndex))
        XCTAssertEqual(reconstructed.days.map(\.loadLevel), original.days.map(\.loadLevel))
        XCTAssertEqual(reconstructed.explanationKey, original.explanationKey)
    }

    /// `explanationKey` hat im neuen Init einen Default (`nil`), damit
    /// Aufrufer, die Tage ohne Erklaertext zusammensetzen, ihn nicht jedes
    /// Mal angeben muessen.
    func testResultInitExplanationKeyDefaultsToNil() {
        let original = PlanGenerator.generate(from: input([selection(.barbell, days: 1)]))
        let day = PlanGenerator.Result.GeneratedDay(spec: original.days[0].spec, loadLevel: original.days[0].loadLevel)
        let result = PlanGenerator.Result(days: [day])
        XCTAssertNil(result.explanationKey)
    }
}
