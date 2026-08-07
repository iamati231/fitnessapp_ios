import XCTest
@testable import FitnessAppCore

final class PlanGeneratorTests: XCTestCase {

    private func selection(
        _ kind: TrainingTypeKind,
        days: Int,
        minutes: Int = 45,
        experience: DifficultyLevel = .intermediate
    ) -> PlanGeneratorTypeSelection {
        PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: minutes, experience: experience)
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
        let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: 3)]))
        let emomDays = result.days.filter { $0.spec.timeFormat == .emom }
        XCTAssertEqual(emomDays.count, 1)
        XCTAssertEqual(emomDays.first?.spec.timeCapMinutes, 20)
    }

    func testKettlebellTwoDaysHasNoEmomFinisher() {
        // README 2.20: der Finisher gilt nur ab >=3 Tagen.
        let result = PlanGenerator.generate(from: input([selection(.kettlebell, days: 2)]))
        XCTAssertTrue(result.days.allSatisfy { $0.spec.timeFormat == nil })
    }

    // MARK: - README 2.20: Lauf-Typologie

    func testRunningThreeDaysCoversAllThreeZones() {
        let result = PlanGenerator.generate(from: input([selection(.running, days: 3)]))
        let exerciseNames = Set(result.days.flatMap { $0.spec.exercises.map(\.name) })
        XCTAssertEqual(exerciseNames, ["Easy Run", "Long Run", "Intervalle"])
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
}
