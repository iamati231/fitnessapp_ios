import XCTest
@testable import FitnessAppCore

/// P3.3 (Audit "Gezielte Alternativen statt globalem Shuffle"):
/// `PlanGenerator.targetedAlternatives(for:input:count:)` ersetzt den
/// bisherigen "ganze Woche neu mischen"-Weg fuer EINEN einzelnen Tag.
final class PlanGeneratorTargetedAlternativesTests: XCTestCase {

    private func selection(
        _ kind: TrainingTypeKind,
        days: Int,
        minutes: Int = 45,
        experience: DifficultyLevel = .intermediate
    ) -> PlanGeneratorTypeSelection {
        PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: minutes, experience: experience)
    }

    private func input(_ selections: [PlanGeneratorTypeSelection]) -> PlanGeneratorInput {
        PlanGeneratorInput(selections: selections, equipmentPreferences: [], usesFixedWeekdays: false, fixedWeekdays: [])
    }

    func testStrengthDayGetsUpToRequestedAlternativeCount() throws {
        let planInput = input([selection(.dumbbell, days: 3)])
        let generated = PlanGenerator.generate(from: planInput)
        let day = try XCTUnwrap(generated.days.first).spec

        let result = PlanGenerator.targetedAlternatives(for: day, input: planInput, count: 3)
        guard case let .alternatives(alternatives) = result else {
            return XCTFail("expected alternatives for a strength day, got \(result)")
        }
        XCTAssertFalse(alternatives.isEmpty)
        XCTAssertLessThanOrEqual(alternatives.count, 3)
    }

    func testAlternativesNeverRepeatTheOriginalExerciseSet() throws {
        let planInput = input([selection(.bodyweight, days: 2)])
        let generated = PlanGenerator.generate(from: planInput)
        let day = try XCTUnwrap(generated.days.first).spec
        let originalNames = Set(day.exercises.map(\.name))

        let result = PlanGenerator.targetedAlternatives(for: day, input: planInput, count: 3)
        guard case let .alternatives(alternatives) = result else {
            return XCTFail("expected alternatives, got \(result)")
        }
        for alternative in alternatives {
            XCTAssertNotEqual(Set(alternative.exercises.map(\.name)), originalNames)
        }
    }

    func testAlternativesAreMutuallyDistinct() throws {
        let planInput = input([selection(.barbell, days: 2)])
        let generated = PlanGenerator.generate(from: planInput)
        let day = try XCTUnwrap(generated.days.first).spec

        let result = PlanGenerator.targetedAlternatives(for: day, input: planInput, count: 3)
        guard case let .alternatives(alternatives) = result else {
            return XCTFail("expected alternatives, got \(result)")
        }
        let exerciseSets = alternatives.map { Set($0.exercises.map(\.name)) }
        XCTAssertEqual(Set(exerciseSets).count, exerciseSets.count, "alternatives must not repeat each other")
    }

    func testAlternativesPreserveSequenceIndexAndType() throws {
        let planInput = input([selection(.kettlebell, days: 1)])
        let generated = PlanGenerator.generate(from: planInput)
        let day = try XCTUnwrap(generated.days.first).spec

        let result = PlanGenerator.targetedAlternatives(for: day, input: planInput, count: 2)
        guard case let .alternatives(alternatives) = result else {
            return XCTFail("expected alternatives, got \(result)")
        }
        for alternative in alternatives {
            XCTAssertEqual(alternative.sequenceIndex, day.sequenceIndex)
            XCTAssertEqual(alternative.type, day.type)
        }
    }

    func testCardioDayHasNoAlternatives() throws {
        let planInput = input([selection(.running, days: 2)])
        let generated = PlanGenerator.generate(from: planInput)
        let cardioDay = try XCTUnwrap(generated.days.first).spec
        XCTAssertTrue(cardioDay.exercises.contains(where: \.isCardio))

        let result = PlanGenerator.targetedAlternatives(for: cardioDay, input: planInput, count: 3)
        XCTAssertEqual(result, .noAlternativesAvailable)
    }

    func testDayNotMatchingAnySelectionHasNoAlternatives() {
        // Ein Tag mit frei erfundenen Uebungsnamen kann keiner der
        // `input.selections` zugeordnet werden (Abnahme B05: sichtbarer
        // Konflikt statt stiller leerer Liste).
        let foreignDay = DaySpec(
            name: "Fremdplan",
            type: .fullBody,
            sequenceIndex: 1,
            exercises: [ExerciseSpec(name: "Nicht-existente Uebung XYZ", sets: 3, repsMin: 8, repsMax: 10)]
        )
        let planInput = input([selection(.barbell, days: 1)])
        let result = PlanGenerator.targetedAlternatives(for: foreignDay, input: planInput, count: 3)
        XCTAssertEqual(result, .noAlternativesAvailable)
    }

    func testEmptyExerciseDayHasNoAlternatives() {
        let emptyDay = DaySpec(name: "Leer", type: .rest, sequenceIndex: 1, exercises: [])
        let planInput = input([selection(.barbell, days: 1)])
        let result = PlanGenerator.targetedAlternatives(for: emptyDay, input: planInput, count: 3)
        XCTAssertEqual(result, .noAlternativesAvailable)
    }

    func testOtherSelectionsDoNotAffectWhichSelectionMatches() throws {
        // Hybrid-Input (Kraft + Ausdauer): ein reiner Kraft-Tag muss trotz
        // der zusaetzlichen Cardio-Auswahl korrekt der Kraft-Auswahl
        // zugeordnet werden.
        let planInput = input([selection(.dumbbell, days: 2), selection(.running, days: 2)])
        let generated = PlanGenerator.generate(from: planInput)
        let strengthDay = try XCTUnwrap(generated.days.first { !$0.spec.exercises.contains(where: \.isCardio) }).spec

        let result = PlanGenerator.targetedAlternatives(for: strengthDay, input: planInput, count: 2)
        guard case .alternatives = result else {
            return XCTFail("expected alternatives for the strength day in a hybrid input, got \(result)")
        }
    }
}
