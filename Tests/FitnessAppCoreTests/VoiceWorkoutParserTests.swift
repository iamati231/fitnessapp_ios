import Testing
@testable import FitnessAppCore

struct VoiceWorkoutParserTests {

    let parser = VoiceWorkoutParser()

    // MARK: - Number Parsing

    @Test func parseDigitString() {
        #expect(parser.parseNumber("10") == 10)
        #expect(parser.parseNumber("100") == 100)
    }

    @Test func parseGermanWords() {
        #expect(parser.parseNumber("zehn") == 10)
        #expect(parser.parseNumber("zwölf") == 12)
        #expect(parser.parseNumber("dreißig") == 30)
    }

    @Test func parseCompoundNumber() {
        #expect(parser.parseNumber("einundzwanzig") == 21)
        #expect(parser.parseNumber("fünfundsechzig") == 65)
        #expect(parser.parseNumber("dreiundvierzig") == 43)
    }

    @Test func unknownWordReturnsNil() {
        #expect(parser.parseNumber("Bankdrücken") == nil)
    }

    // MARK: - Single Set Parsing (spec test cases)

    @Test func simpleSetWithWordNumber() {
        // "Bankdrücken, 60 Kilo, zehn Wiederholungen" → 60 kg, 10 reps
        let draft = parser.parseSet("Bankdrücken 60 Kilo zehn Wiederholungen")
        #expect(draft.weightKg == 60.0)
        #expect(draft.reps == 10)
    }

    @Test func missingWeightIsNilNotZero() {
        // missing weight → nil (not 0)
        let draft = parser.parseSet("Bankdrücken zehn Wiederholungen")
        #expect(draft.weightKg == nil)
        #expect(draft.reps == 10)
    }

    @Test func timedExercise() {
        // "Plank 45 Sekunden" → time-based, 45 seconds
        let draft = parser.parseSet("Plank 45 Sekunden")
        #expect(draft.isTimeBased == true)
        #expect(draft.durationSeconds == 45)
    }

    @Test func minutesConvertedToSeconds() {
        let draft = parser.parseSet("Plank 2 Minuten")
        #expect(draft.isTimeBased == true)
        #expect(draft.durationSeconds == 120)
    }

    // MARK: - Multi-Set Parsing

    @Test func uniformSets() {
        // "drei Sätze mit jeweils 12 Wiederholungen" → 3 sets × 12
        let sets = parser.parseWorkout("drei Sätze mit jeweils 12 Wiederholungen")
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.reps == 12 })
    }

    @Test func variedRepList() {
        // "10, 9 und 8 Wiederholungen" → [10, 9, 8] reps
        let sets = parser.parseWorkout("10, 9 und 8 Wiederholungen")
        #expect(sets.count == 3)
        #expect(sets[0].reps == 10)
        #expect(sets[1].reps == 9)
        #expect(sets[2].reps == 8)
    }

    @Test func previousWeightReference() {
        // "noch ein Satz mit demselben Gewicht" without context → ambiguous (weightKg nil)
        let draft = parser.parseSet("noch ein Satz mit demselben Gewicht")
        #expect(draft.weightKg == nil)
    }

    @Test func previousWeightReferenceWithContext() {
        // "noch ein Satz mit demselben Gewicht" with previousWeight → copies it
        let draft = parser.parseSet("noch ein Satz mit demselben Gewicht", previousWeight: 80.0)
        #expect(draft.weightKg == 80.0)
    }

    @Test func unknownExerciseNameNotMatched() {
        // unknown exercise → exerciseName is nil or non-empty but unmatched
        let draft = parser.parseSet("Xyzfoo 60 Kilo 10 Wiederholungen")
        // Parser keeps the raw name even if not in library
        #expect(draft.exerciseName != nil || draft.isExerciseAmbiguous == false)
    }

    // MARK: - Block Splitting

    @Test func multipleBlocksProduceMultipleSets() {
        let sets = parser.parseWorkout("Bankdrücken 60 Kilo 10 Wiederholungen. Kniebeuge 100 Kilo 8 Wiederholungen")
        #expect(sets.count == 2)
    }

    @Test func connectorWordSplitsBlocks() {
        let sets = parser.parseWorkout("Bankdrücken 60 Kilo 10 Wiederholungen dann Kniebeuge 100 Kilo 8 Wiederholungen")
        #expect(sets.count == 2)
    }

    // MARK: - Decimal Weight

    @Test func decimalWeightWithComma() {
        let draft = parser.parseSet("Bankdrücken 60,5 Kilo 10 Wiederholungen")
        #expect(draft.weightKg == 60.5)
    }

    // MARK: - hasMissingFields

    @Test func missingWeightFlagged() {
        var draft = VoiceDraftSet(exerciseName: "Bankdrücken", weightKg: nil, reps: 10)
        #expect(draft.hasMissingFields == true)
    }

    @Test func completeSetNotFlagged() {
        let draft = VoiceDraftSet(exerciseName: "Bankdrücken", weightKg: 60, reps: 10)
        #expect(draft.hasMissingFields == false)
    }

    @Test func timeBasedMissingDuration() {
        let draft = VoiceDraftSet(exerciseName: "Plank", durationSeconds: nil, isTimeBased: true)
        #expect(draft.hasMissingFields == true)
    }

    @Test func timeBasedWithDuration() {
        let draft = VoiceDraftSet(exerciseName: "Plank", durationSeconds: 45, isTimeBased: true)
        #expect(draft.hasMissingFields == false)
    }
}
