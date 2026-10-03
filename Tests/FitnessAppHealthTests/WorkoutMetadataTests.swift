import XCTest
@testable import FitnessAppHealth

/// Die eigenen Metadaten eines nach Health geschriebenen Workouts. Health zeigt
/// sie roh an: eine Zahl mit allen Stellen ("5.750184774575019"), ein Text so, wie
/// er ist. Deshalb werden die Zahlen gerundet und die Uebungen ein lesbarer Text.
final class WorkoutMetadataTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func draft(
        kind: HealthWorkoutKind = .strengthTraining,
        distance: Double? = nil,
        pace: Double? = nil,
        sets: Int? = nil,
        volume: Double? = nil,
        names: [String] = []
    ) -> HealthWorkoutDraft {
        HealthWorkoutDraft(
            kind: kind,
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            isIndoor: true,
            totalDistanceKm: distance,
            averagePaceMinPerKm: pace,
            totalSets: sets,
            totalVolumeKg: volume,
            exerciseNames: names
        )
    }

    // MARK: - Zahlen

    /// Der Fall aus Health: 4,51 km in 25:56 ergaben 5.750184774575019.
    func testPaceIsRoundedToTwoDecimals() {
        let metadata = draft(kind: .running, pace: 5.750184774575019).customMetadata
        XCTAssertEqual(metadata[HealthWorkoutDraft.MetadataKey.averagePaceMinPerKm] as? Double, 5.75)
    }

    func testPaceRoundingKeepsTwoSignificantDecimals() {
        func rounded(_ pace: Double) -> Double? {
            draft(kind: .running, pace: pace).customMetadata[HealthWorkoutDraft.MetadataKey.averagePaceMinPerKm] as? Double
        }
        XCTAssertEqual(rounded(6.0), 6.0)
        XCTAssertEqual(rounded(5.7691), 5.77)
        XCTAssertEqual(rounded(5.7649), 5.76)
        XCTAssertEqual(rounded(3.75), 3.75)
    }

    /// Summe mehrerer Logs: 1,1 + 2,2 ist binaer 3.3000000000000003 - in Health
    /// stuende genau das.
    func testDistanceAndVolumeLoseTheFloatingPointNoise() {
        let metadata = draft(distance: 1.1 + 2.2, volume: 0.1 + 0.2 + 3400.95).customMetadata
        XCTAssertEqual(metadata[HealthWorkoutDraft.MetadataKey.totalDistanceKm] as? Double, 3.3)
        XCTAssertEqual(metadata[HealthWorkoutDraft.MetadataKey.totalVolumeKg] as? Double, 3401.25)
    }

    /// Ein Zeitformat hat keine Saetze und kein Volumen: kein "0" in Health.
    func testZeroAndMissingValuesAreOmitted() {
        let metadata = draft(distance: 0, pace: 0, sets: 0, volume: 0).customMetadata
        XCTAssertTrue(metadata.isEmpty)
        XCTAssertTrue(draft().customMetadata.isEmpty)
    }

    func testNonFiniteValuesAreOmitted() {
        let metadata = draft(distance: .nan, pace: .infinity, volume: -.infinity).customMetadata
        XCTAssertTrue(metadata.isEmpty)
    }

    func testSetsAndVolumeAreWrittenWhenSomethingWasLogged() {
        let metadata = draft(sets: 14, volume: 3401.25).customMetadata
        XCTAssertEqual(metadata[HealthWorkoutDraft.MetadataKey.totalSets] as? Int, 14)
        XCTAssertEqual(metadata[HealthWorkoutDraft.MetadataKey.totalVolumeKg] as? Double, 3401.25)
    }

    /// Die Uebungsliste gehoert nicht zu den Zahlen: Sie wird getrennt geschrieben
    /// (optional - lehnt HealthKit sie ab, entsteht das Workout ohne sie).
    func testTheExerciseListIsNotPartOfTheNumericMetadata() {
        let metadata = draft(sets: 3, volume: 900, names: ["Bankdrücken"]).customMetadata
        XCTAssertNil(metadata[HealthWorkoutDraft.MetadataKey.exercises])
    }

    // MARK: - Uebungsliste

    func testExerciseListIsJoinedInOrder() {
        XCTAssertEqual(
            draft(names: ["Bankdrücken", "Kniebeuge", "Rudern"]).exerciseListText,
            "Bankdrücken, Kniebeuge, Rudern"
        )
    }

    func testExerciseListDropsDuplicatesAndBlanks() {
        XCTAssertEqual(
            HealthWorkoutDraft.exerciseListText(for: [" Bankdrücken ", "", "Kniebeuge", "Bankdrücken", "  ", "Kniebeuge"]),
            "Bankdrücken, Kniebeuge"
        )
    }

    func testNoNamesMeansNoList() {
        XCTAssertNil(draft().exerciseListText)
        XCTAssertNil(HealthWorkoutDraft.exerciseListText(for: ["", "  "]))
    }

    /// Zu lang: ganze Namen, soweit sie samt Hinweis auf die uebrigen passen.
    func testALongListShowsWholeNamesAndTheNumberOfTheOthers() {
        let names = (1...30).map { "Übung Nummer \($0)" }
        let text = HealthWorkoutDraft.exerciseListText(for: names, maximumBytes: 60)
        XCTAssertEqual(text, "Übung Nummer 1, Übung Nummer 2, Übung Nummer 3 +27")
        XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, 60)
    }

    func testTheListNeverExceedsTheLimitInBytes() {
        // Umlaute und Sonderzeichen belegen mehrere Bytes.
        let names = ["Schrägbankdrücken", "Rumänisches Kreuzheben", "Frontkniebeuge", "Überzüge",
                     "Hüftheben", "Wadenheben stehend", "Bizepscurl", "Trizepsdrücken am Kabel",
                     "Seitheben", "Face Pulls", "Klimmzüge", "Dips"]
        for limit in 20...200 {
            let text = HealthWorkoutDraft.exerciseListText(for: names, maximumBytes: limit)
            XCTAssertNotNil(text)
            XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, limit, "Limit \(limit)")
        }
    }

    func testExactlyAtTheLimitIsNotShortened() {
        let text = HealthWorkoutDraft.exerciseListText(for: ["abc", "def"], maximumBytes: 8)
        XCTAssertEqual(text, "abc, def")
        XCTAssertEqual(HealthWorkoutDraft.exerciseListText(for: ["abc", "def"], maximumBytes: 7), "abc +1")
    }

    /// Ein einzelner Name, der allein nicht passt, wird gekuerzt — nie mitten in
    /// einem Zeichen.
    func testASingleTooLongNameIsCutWithoutSplittingACharacter() {
        let text = HealthWorkoutDraft.exerciseListText(for: ["Übungsname mit sehr vielen Umlauten äöü"], maximumBytes: 10)
        XCTAssertEqual(text, "Übungs…")
        XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, 10)
    }

    func testTheDefaultLimitIsUsed() {
        let names = (1...100).map { "Übung \($0)" }
        let text = HealthWorkoutDraft.exerciseListText(for: names)
        XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, HealthWorkoutDraft.maximumExerciseListBytes)
        XCTAssertTrue(text?.hasPrefix("Übung 1, Übung 2") ?? false)
    }
}
