import XCTest
@testable import FitnessAppCore

final class ProgramTemplatesTests: XCTestCase {

    // MARK: Inventory + uniqueness

    func testElevenProgramsAreShipped() {
        XCTAssertEqual(ProgramTemplates.all.count, 11,
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

    // MARK: Day-spec sanity

    func testEveryProgramHasAtLeastOneTrainingDay() {
        for template in ProgramTemplates.all {
            let trainingDays = template.days.filter { !$0.exercises.isEmpty }
            XCTAssertFalse(trainingDays.isEmpty,
                           "\(template.name) has zero training days — only rest days")
        }
    }

    func testWeekdaysAreInCalendarRange() {
        // Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
        // Anything outside this range would silently break weekday-based UI sorting.
        for template in ProgramTemplates.all {
            for day in template.days {
                XCTAssertTrue((1...7).contains(day.weekday),
                              "\(template.name) / \(day.name) has weekday \(day.weekday) outside Calendar range 1-7")
            }
        }
    }

    func testNoTrainingDayHasOverlappingWeekdayWithAnother() {
        // Each weekday slot can hold at most one day — if there are duplicates,
        // the picker UI shows them in indeterminate order.
        for template in ProgramTemplates.all {
            let weekdays = template.days.map(\.weekday)
            XCTAssertEqual(weekdays.count, Set(weekdays).count,
                           "\(template.name) has two days on the same weekday")
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

    func testRestDaysHaveZeroExercises() {
        for template in ProgramTemplates.all {
            for day in template.days where day.type == .rest {
                XCTAssertTrue(day.exercises.isEmpty,
                              "\(template.name) / rest day '\(day.name)' has \(day.exercises.count) exercises — should be zero")
            }
        }
    }

    func testDaysPerWeekFieldMatchesActualTrainingDays() {
        // The promised count in the picker UI must match what the user actually
        // ends up with after instantiation. Drift here is a UX bug.
        for template in ProgramTemplates.all {
            let actualTrainingDays = template.days.filter { !$0.exercises.isEmpty }.count
            XCTAssertEqual(actualTrainingDays, template.daysPerWeek,
                           "\(template.name) advertises \(template.daysPerWeek) days/week but has \(actualTrainingDays) non-rest days")
        }
    }

    // MARK: Environment targeting

    func testHomeGymProgramHasOnlyDumbbellExercises() {
        // The 'Home Gym Hero' program is supposed to be runnable with just dumbbells.
        // If a barbell or machine sneaks in, the targeting promise breaks.
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
        // The fat-loss program is the only one with explicit `isCardio: true` exercises.
        // If any other program flips this flag, surface it loudly so we can review.
        for template in ProgramTemplates.all where template.id != "fat_loss_fullbody" {
            let cardioExercises = template.days.flatMap { $0.exercises }.filter { $0.isCardio }
            XCTAssertTrue(cardioExercises.isEmpty,
                          "\(template.name) has unexpected cardio-flagged exercises: \(cardioExercises.map(\.name))")
        }
    }
}
