import XCTest
@testable import FitnessAppCore

final class ProgramTemplatesTests: XCTestCase {

    // MARK: Inventory + uniqueness

    func testNineteenProgramsAreShipped() {
        // README 2.9: 14 → 19 Programme (CrossFit Bodyweight Rx/Scaled,
        // CrossFit mit Gewichten, Kettlebell Beginner/Advanced dazu).
        XCTAssertEqual(ProgramTemplates.all.count, 19,
                       "Editing the catalog needs an explicit count update — fail-fast prevents silent template drops")
    }

    func testProgramIDsAreUnique() {
        let ids = ProgramTemplates.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate program id detected")
    }

    func testProgramNamesAreUnique() {
        let names = ProgramTemplates.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "duplicate program name detected")
    }

    // MARK: Day-spec sanity (DEL-088 Rolling-Days)

    func testEveryProgramHasAtLeastOneTrainingDay() {
        for template in ProgramTemplates.all {
            XCTAssertFalse(template.days.isEmpty,
                           "\(template.name) hat keinen einzigen Trainingstag")
        }
    }

    /// DEL-088: Statt weekday haben Tage jetzt sequenceIndex (1-basiert,
    /// laufend 1...daysPerWeek). Keine Rest-Days mehr in Templates.
    func testSequenceIndexIsContinuousFromOne() {
        for template in ProgramTemplates.all {
            let indices = template.days.map(\.sequenceIndex).sorted()
            let expected = Array(1...template.daysPerWeek)
            XCTAssertEqual(indices, expected,
                           "\(template.name): sequenceIndex muss kontinuierlich 1...\(template.daysPerWeek) sein, ist \(indices)")
        }
    }

    func testNoTrainingDayHasDuplicateSequenceIndex() {
        for template in ProgramTemplates.all {
            let indices = template.days.map(\.sequenceIndex)
            XCTAssertEqual(indices.count, Set(indices).count,
                           "\(template.name) hat zwei Tage mit demselben sequenceIndex")
        }
    }

    /// DEL-088: Es darf KEINE Rest-Days mehr in den Templates geben.
    /// Der ProgramInstantiator fuellt die nicht-angekreuzten Wochentage
    /// automatisch mit `.rest` auf.
    func testNoRestDaysInTemplates() {
        for template in ProgramTemplates.all {
            let restDays = template.days.filter { $0.type == .rest }
            XCTAssertTrue(restDays.isEmpty,
                          "\(template.name) hat noch Rest-Day(s) in den Seed-Daten — Rolling-Days entfernt sie alle")
        }
    }

    // MARK: Exercise-spec sanity

    func testExerciseRepRangesAreValid() {
        for template in ProgramTemplates.all {
            for day in template.days {
                for exercise in day.exercises {
                    XCTAssertGreaterThan(exercise.sets, 0,
                                         "\(template.name) / \(day.name) / \(exercise.name): zero sets")
                    XCTAssertGreaterThan(exercise.repsMin, 0,
                                         "\(template.name) / \(day.name) / \(exercise.name): non-positive repsMin")
                    XCTAssertGreaterThanOrEqual(exercise.repsMax, exercise.repsMin,
                                                "\(template.name) / \(day.name) / \(exercise.name): repsMax (\(exercise.repsMax)) < repsMin (\(exercise.repsMin))")
                    XCTAssertGreaterThanOrEqual(exercise.restSeconds, 0,
                                                "\(template.name) / \(day.name) / \(exercise.name): negative restSeconds")
                }
            }
        }
    }

    func testDaysPerWeekFieldMatchesActualTrainingDays() {
        // The promised count in the picker UI must match what the user actually
        // ends up with after instantiation.
        // DEL-088: Templates enthalten jetzt NUR Trainings-Tage — die Anzahl
        // muss exakt `daysPerWeek` entsprechen.
        for template in ProgramTemplates.all {
            XCTAssertEqual(template.days.count, template.daysPerWeek,
                           "\(template.name) advertises \(template.daysPerWeek) days/week but has \(template.days.count) training days")
        }
    }

    // MARK: Environment targeting

    func testHomeGymProgramHasOnlyDumbbellExercises() {
        let homeGym = ProgramTemplates.all.first { $0.id == "home_gym_hero" }
        XCTAssertNotNil(homeGym, "home_gym_hero template not found")

        guard let homeGym else { return }
        XCTAssertEqual(homeGym.targetEnvironment, .homeGym)

        let allowedNames = Set(
            ExerciseLibraryData.all
                .filter { [.dumbbell, .bodyweight, .band].contains($0.equipment) }
                .map(\.name)
        )
        for day in homeGym.days {
            for exercise in day.exercises {
                XCTAssertTrue(allowedNames.contains(exercise.name),
                              "home_gym_hero references '\(exercise.name)' which isn't in the dumbbell/bodyweight/band library subset")
            }
        }
    }

    func testBodyweightProgramHasOnlyBodyweightExercises() {
        let bw = ProgramTemplates.all.first { $0.id == "bodyweight_mastery" }
        XCTAssertNotNil(bw)

        guard let bw else { return }
        XCTAssertEqual(bw.targetEnvironment, .noEquipment)

        let allowedNames = Set(
            ExerciseLibraryData.all
                .filter { [.bodyweight, .band].contains($0.equipment) }
                .map(\.name)
        )
        for day in bw.days {
            for exercise in day.exercises {
                XCTAssertTrue(allowedNames.contains(exercise.name),
                              "bodyweight_mastery references '\(exercise.name)' which isn't in the bodyweight/band library subset")
            }
        }
    }

    // MARK: Cardio + Time-based propagation

    func testCardioFlagOnlySetForKnownCardioFinishers() {
        let allowedCardioCarriers: Set<String> = [
            "fat_loss_fullbody",
            "hybrid_beginner",
            "hybrid_balanced",
            "hybrid_performance"
        ]
        for template in ProgramTemplates.all where !allowedCardioCarriers.contains(template.id) {
            let cardioExercises = template.days.flatMap { $0.exercises }.filter { $0.isCardio }
            XCTAssertTrue(cardioExercises.isEmpty,
                          "\(template.name) has unexpected cardio-flagged exercises: \(cardioExercises.map(\.name))")
        }
    }

    // MARK: README 2.9 Zeitformate (AMRAP/EMOM/Auf Zeit)

    /// AMRAP/EMOM brauchen einen Deckel, sonst weiss der Player nicht, wann
    /// die Runde/Minute endet (die View-Defaults von 12/20 Minuten sind nur
    /// ein Nothelfer fuer fehlerhafte Daten, kein Ersatz fuer echte Werte
    /// in den Templates selbst).
    func testAmrapAndEmomDaysHaveATimeCap() {
        for template in ProgramTemplates.all {
            for day in template.days {
                guard let format = day.timeFormat, format == .amrap || format == .emom else { continue }
                XCTAssertNotNil(day.timeCapMinutes,
                                "\(template.name) / \(day.name): \(format) ohne timeCapMinutes")
                XCTAssertGreaterThan(day.timeCapMinutes ?? 0, 0,
                                     "\(template.name) / \(day.name): timeCapMinutes muss positiv sein")
            }
        }
    }

    /// Zeitformat-Tage tragen kein Ad-Hoc-/Zusatz-Feld, das sie versehentlich
    /// wie einen normalen Kraft-Tag behandeln liesse — DayType.rest ist fuer
    /// Zeitformat-Tage genauso ausgeschlossen wie fuer normale Tage.
    func testTimedFormatDaysAreNeverRestDays() {
        for template in ProgramTemplates.all {
            for day in template.days where day.timeFormat != nil {
                XCTAssertNotEqual(day.type, .rest,
                                  "\(template.name) / \(day.name) ist ein Zeitformat-Tag mit type .rest")
            }
        }
    }

    // MARK: DEL-090 Quiz-Tags

    /// Jeder Plan muss mindestens ein Experience-Level UND ein Goal als Tag
    /// tragen — sonst kann der `PlanMatchmaker` ihn nicht ranken.
    func testEveryTemplateHasOnboardingTags() {
        for template in ProgramTemplates.all {
            XCTAssertFalse(template.targetExperience.isEmpty,
                           "\(template.name) hat keine targetExperience-Tags")
            XCTAssertFalse(template.targetGoals.isEmpty,
                           "\(template.name) hat keine targetGoals-Tags")
        }
    }
}
