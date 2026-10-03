import XCTest
@testable import FitnessAppHealth

/// Die eigenen Metadaten eines nach Health geschriebenen Workouts. Health zeigt
/// sie roh an: eine Zahl mit allen Stellen ("5.750184774575019"), ein Text so, wie
/// er ist. Deshalb werden die Zahlen gerundet und die Uebungen ein lesbarer Text.
final class WorkoutMetadataTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private let labels = HealthWorkoutMetadataLabels.default

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
        XCTAssertEqual(metadata[labels.averagePace] as? Double, 5.75)
    }

    func testPaceRoundingKeepsTwoSignificantDecimals() {
        func rounded(_ pace: Double) -> Double? {
            draft(kind: .running, pace: pace).customMetadata[labels.averagePace] as? Double
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
        XCTAssertEqual(metadata[labels.distanceKm] as? Double, 3.3)
        XCTAssertEqual(metadata[labels.volumeKg] as? Double, 3401.25)
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
        XCTAssertEqual(metadata[labels.sets] as? Int, 14)
        XCTAssertEqual(metadata[labels.volumeKg] as? Double, 3401.25)
    }

    /// Die Uebungsliste steht unter ihrer Beschriftung bei den uebrigen Feldern.
    func testTheExerciseListIsPartOfTheCustomMetadata() {
        let metadata = draft(sets: 3, volume: 900, names: ["Bankdrücken", "Kniebeuge"]).customMetadata
        XCTAssertEqual(metadata[labels.exercises] as? String, "Bankdrücken, Kniebeuge")
        XCTAssertEqual(metadata[labels.sets] as? Int, 3)
    }

    func testWithoutNamesThereIsNoExerciseEntry() {
        XCTAssertNil(draft(sets: 3, volume: 900).customMetadata[labels.exercises])
    }

    // MARK: - Beschriftungen

    /// Health zeigt den Schluessel woertlich an: kurze, lesbare Texte statt eines
    /// Paketnamens wie `com.atamya.FitnessApp.TotalSets`.
    func testTheKeysAreShortReadableTextsNotAPackageName() {
        let full = draft(
            kind: .running, distance: 4.51, pace: 5.75, sets: 3, volume: 900, names: ["Liegestütze"]
        ).customMetadata
        XCTAssertEqual(Set(full.keys), [
            labels.sets, labels.volumeKg, labels.distanceKm, labels.averagePace, labels.exercises
        ])
        for key in full.keys {
            XCTAssertFalse(key.contains("com.atamya"), key)
            XCTAssertLessThanOrEqual(key.count, 24, key)
        }
    }

    func testTheDefaultLabelsAreEnglish() {
        XCTAssertEqual(labels.exercises, "Exercises")
        XCTAssertEqual(labels.sets, "Sets")
        XCTAssertEqual(labels.volumeKg, "Volume (kg)")
        XCTAssertEqual(labels.distanceKm, "Distance (km)")
        XCTAssertEqual(labels.averagePace, "Avg. pace (min/km)")
    }

    /// Die UI-Schicht reicht die Beschriftungen in der App-Sprache durch.
    func testGivenLabelsAreUsedAsKeys() {
        let german = HealthWorkoutMetadataLabels(
            exercises: "Übungen", sets: "Sätze", volumeKg: "Volumen (kg)",
            distanceKm: "Distanz (km)", averagePace: "Ø Pace (min/km)"
        )
        let metadata = HealthWorkoutDraft(
            kind: .strengthTraining, startDate: start, endDate: start.addingTimeInterval(600),
            isIndoor: true, totalSets: 3, totalVolumeKg: 900, exerciseNames: ["Liegestütze"],
            metadataLabels: german
        ).customMetadata
        XCTAssertEqual(metadata["Übungen"] as? String, "Liegestütze")
        XCTAssertEqual(metadata["Sätze"] as? Int, 3)
        XCTAssertEqual(metadata["Volumen (kg)"] as? Double, 900)
        XCTAssertNil(metadata[labels.sets])
    }

    /// Leer oder im reservierten "HK"-Namensraum von Apple ist kein brauchbarer
    /// Schluessel: dann gilt die englische Vorgabe.
    func testBlankOrReservedLabelsFallBackToTheDefaults() {
        let broken = HealthWorkoutMetadataLabels(
            exercises: "  ", sets: "HKSets", volumeKg: " Volumen ",
            distanceKm: "", averagePace: "HKAveragePace"
        )
        let metadata = HealthWorkoutDraft(
            kind: .running, startDate: start, endDate: start.addingTimeInterval(600),
            isIndoor: false, totalDistanceKm: 5, averagePaceMinPerKm: 6, totalSets: 2,
            totalVolumeKg: 100, exerciseNames: ["Dips"], metadataLabels: broken
        ).customMetadata
        XCTAssertEqual(metadata[labels.exercises] as? String, "Dips")
        XCTAssertEqual(metadata[labels.sets] as? Int, 2)
        XCTAssertEqual(metadata["Volumen"] as? Double, 100, "Leerraum am Rand wird entfernt")
        XCTAssertEqual(metadata[labels.distanceKm] as? Double, 5)
        XCTAssertEqual(metadata[labels.averagePace] as? Double, 6)
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

    /// Auch wenn schon der erste Name allein nicht passt, sagt die Liste, wie viele
    /// weitere es gibt.
    func testATooLongFirstNameStillCountsTheOthers() {
        let text = HealthWorkoutDraft.exerciseListText(
            for: ["Übungsname mit sehr vielen Umlauten äöü", "Zweite"], maximumBytes: 12
        )
        XCTAssertEqual(text, "Übung… +1")
        XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, 12)
    }

    /// Bei einem winzigen Limit entfaellt der Hinweis zugunsten des Limits.
    func testATinyLimitDropsTheCountInsteadOfExceedingTheLimit() {
        let text = HealthWorkoutDraft.exerciseListText(for: ["Übung", "Zweite"], maximumBytes: 4)
        XCTAssertEqual(text, "…")
    }

    func testTheLimitHoldsForEverySmallLimitFromThreeBytes() {
        let names = ["Übungsname mit sehr vielen Umlauten äöü", "Zweite Übung", "Dritte", "日本語の名前", "Dips"]
        for limit in 3...60 {
            let text = HealthWorkoutDraft.exerciseListText(for: names, maximumBytes: limit)
            XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, limit, "Limit \(limit)")
        }
    }

    // MARK: - Rueckfall ohne Liste

    /// Nur eine Ablehnung dieses Trainings bzw. ein allgemeiner Speicherfehler kann
    /// an der optionalen Uebungsliste liegen — nicht eine fehlende Berechtigung oder
    /// ein gesperrtes Geraet (sie scheitern ohne Liste genauso).
    func testOnlyARejectedWorkoutOrAGenericSaveFailureMayBeCausedByTheList() {
        XCTAssertTrue(HealthKitError.invalidWorkout(reason: "x").mayBeCausedByOptionalMetadata)
        XCTAssertTrue(HealthKitError.saveFailed(reason: "x").mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.writeNotAuthorized.mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.databaseInaccessible.mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.unavailable.mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.queryFailed(reason: "x").mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.authorizationFailed(reason: "x").mayBeCausedByOptionalMetadata)
        XCTAssertFalse(HealthKitError.invalidValue(reason: "x").mayBeCausedByOptionalMetadata)
    }

    func testTheDefaultLimitIsUsed() {
        let names = (1...100).map { "Übung \($0)" }
        let text = HealthWorkoutDraft.exerciseListText(for: names)
        XCTAssertLessThanOrEqual(text?.utf8.count ?? .max, HealthWorkoutDraft.maximumExerciseListBytes)
        XCTAssertTrue(text?.hasPrefix("Übung 1, Übung 2") ?? false)
    }
}
