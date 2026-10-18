import XCTest
@testable import FitnessAppCore

/// P8-Vorbereitung, Paket A (`docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`): deckt
/// Encode/Decode-Roundtrip und die explizit geforderten Trainingsvarianten
/// ab (Reihenfolge/Duplikate, Superset, Cardio/Time-Based, Zirkel-Parameter)
/// sowie die drei unterscheidbaren Lese-Fälle (kein Snapshot, gültig leer,
/// beschädigt/nicht unterstützt). Reine Core-Logik, kein SwiftData — läuft
/// auf Linux.
final class TrainingDayContentSnapshotTests: XCTestCase {

    private func makeExercise(
        orderIndex: Int,
        name: String = "Bankdrücken",
        templateID: UUID? = UUID(),
        customName: String? = nil,
        role: ExerciseRole = .workingSet,
        supersetId: UUID? = nil,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        cardioEquipment: CardioEquipment = .none,
        sets: Int = 3,
        repsMin: Int = 8,
        repsMax: Int = 12,
        restSeconds: Int = 90,
        targetRir: Float = 2.0,
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Int? = nil
    ) -> TrainingDayContentSnapshot.ExerciseEntry {
        .init(
            orderIndex: orderIndex, exerciseTemplateID: templateID, nameSnapshot: name,
            customNameSnapshot: customName, role: role, supersetId: supersetId,
            isCardio: isCardio, isTimeBased: isTimeBased, cardioEquipment: cardioEquipment,
            sets: sets, repsMin: repsMin, repsMax: repsMax, restSeconds: restSeconds,
            targetRir: targetRir, targetDistanceKm: targetDistanceKm,
            targetDurationMinutes: targetDurationMinutes
        )
    }

    private func makeSnapshot(
        exercises: [TrainingDayContentSnapshot.ExerciseEntry],
        timeFormat: WorkoutTimeFormat? = nil,
        timeCapMinutes: Int? = nil,
        circuitRounds: Int? = nil,
        circuitRestSeconds: Int? = nil,
        circuitMode: CircuitRoundMode? = nil
    ) -> TrainingDayContentSnapshot {
        .init(
            dayNameSnapshot: "Push A", dayCustomNameSnapshot: nil, dayLocalizationKeySnapshot: "day.pushA",
            weekday: 2, dayType: .chest, timeFormat: timeFormat, timeCapMinutes: timeCapMinutes,
            circuitRounds: circuitRounds, circuitRestSeconds: circuitRestSeconds, circuitMode: circuitMode,
            exercises: exercises
        )
    }

    // MARK: - Roundtrip: Normalfall

    func testRoundtripPreservesAStandardStrengthDay() {
        let snapshot = makeSnapshot(exercises: [
            makeExercise(orderIndex: 0, name: "Bankdrücken", customName: "Mein Bankdrücken"),
            makeExercise(orderIndex: 1, name: "Kurzhantel-Rudern")
        ])
        guard let json = snapshot.encodedJSON() else { return XCTFail("Encoding darf nicht scheitern") }
        guard case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("Decoding des gerade erzeugten JSON darf nicht scheitern")
        }
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.schemaVersion, TrainingDayContentSnapshot.currentSchemaVersion)
    }

    // MARK: - Reihenfolge + mehrfach vorkommende gleiche Übungen

    func testDuplicateNamedExercisesAtDifferentOrderIndexAreBothPreservedDistinctly() {
        let sharedTemplateID = UUID()
        let snapshot = makeSnapshot(exercises: [
            makeExercise(orderIndex: 0, name: "Kurzhantel-Curls", templateID: sharedTemplateID, sets: 4),
            makeExercise(orderIndex: 5, name: "Kurzhantel-Curls", templateID: sharedTemplateID, sets: 2)
        ])
        guard let json = snapshot.encodedJSON(),
              case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("Roundtrip darf nicht scheitern")
        }
        XCTAssertEqual(decoded.exercises.count, 2, "beide Vorkommen bleiben erhalten, keine Namens-Deduplizierung")
        XCTAssertEqual(decoded.exercises.map(\.orderIndex), [0, 5])
        XCTAssertEqual(decoded.exercises.map(\.sets), [4, 2], "die beiden Vorkommen bleiben inhaltlich unterscheidbar")
    }

    // MARK: - Superset-Gruppierung (DEL-083) und Übungsrollen (DEL-087)

    func testSupersetGroupingAndExerciseRolesRoundtrip() {
        let supersetId = UUID()
        let snapshot = makeSnapshot(exercises: [
            makeExercise(orderIndex: 0, name: "Aufwärmen Bankdrücken", role: .warmup),
            makeExercise(orderIndex: 1, name: "Bankdrücken", role: .workingSet, supersetId: supersetId),
            makeExercise(orderIndex: 2, name: "Kurzhantel-Rudern", role: .workingSet, supersetId: supersetId),
            makeExercise(orderIndex: 3, name: "Dehnen", role: .cooldown)
        ])
        guard let json = snapshot.encodedJSON(),
              case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("Roundtrip darf nicht scheitern")
        }
        XCTAssertEqual(decoded.exercises[0].role, .warmup)
        XCTAssertEqual(decoded.exercises[3].role, .cooldown)
        XCTAssertEqual(decoded.exercises[1].supersetId, supersetId)
        XCTAssertEqual(decoded.exercises[2].supersetId, supersetId)
        XCTAssertNotEqual(decoded.exercises[0].supersetId, supersetId, "Warmup steht NICHT im Superset")
    }

    // MARK: - Cardio / Time-Based Zielwerte

    func testCardioAndTimeBasedTargetValuesRoundtrip() {
        let snapshot = makeSnapshot(exercises: [
            makeExercise(
                orderIndex: 0, name: "Easy Run", isCardio: true, cardioEquipment: .treadmill,
                targetDistanceKm: 5.0, targetDurationMinutes: 30
            ),
            makeExercise(orderIndex: 1, name: "Unterarmstütz", isTimeBased: true, repsMin: 45, repsMax: 60)
        ])
        guard let json = snapshot.encodedJSON(),
              case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("Roundtrip darf nicht scheitern")
        }
        XCTAssertTrue(decoded.exercises[0].isCardio)
        XCTAssertEqual(decoded.exercises[0].cardioEquipment, .treadmill)
        XCTAssertEqual(decoded.exercises[0].targetDistanceKm, 5.0)
        XCTAssertEqual(decoded.exercises[0].targetDurationMinutes, 30)
        XCTAssertTrue(decoded.exercises[1].isTimeBased)
        XCTAssertEqual(decoded.exercises[1].repsMin, 45, "Time-Based nutzt repsMin/repsMax als Sekunden (DEL-040), kein eigenes Feld noetig")
    }

    // MARK: - Zeitformat-/Zirkel-Parameter auf Tagesebene

    func testCircuitAndTimeFormatParametersRoundtrip() {
        let snapshot = makeSnapshot(
            exercises: [makeExercise(orderIndex: 0)],
            timeFormat: .circuit, timeCapMinutes: 20,
            circuitRounds: 5, circuitRestSeconds: 60, circuitMode: .fixedReps
        )
        guard let json = snapshot.encodedJSON(),
              case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("Roundtrip darf nicht scheitern")
        }
        XCTAssertEqual(decoded.timeFormat, .circuit)
        XCTAssertEqual(decoded.circuitRounds, 5)
        XCTAssertEqual(decoded.circuitRestSeconds, 60)
        XCTAssertEqual(decoded.circuitMode, .fixedReps)
    }

    // MARK: - Gültig leerer Snapshot (kein Fehler!)

    func testEmptyExerciseListIsAValidSnapshotNotAnError() {
        let snapshot = makeSnapshot(exercises: [])
        guard let json = snapshot.encodedJSON() else { return XCTFail("Encoding darf nicht scheitern") }
        guard case .success(let decoded) = TrainingDayContentSnapshot.decode(fromJSON: json) else {
            return XCTFail("eine leere Übungsliste ist gültig (z.B. Ad-hoc vor der ersten Übung)")
        }
        XCTAssertTrue(decoded.exercises.isEmpty)
    }

    // MARK: - Drei unterscheidbare Lesefälle

    func testCorruptedJSONIsReportedAsCorruptedNotSilentlyReplaced() {
        let result = TrainingDayContentSnapshot.decode(fromJSON: "{ das ist kein JSON")
        guard case .failure(.corrupted) = result else {
            return XCTFail("beschädigtes JSON muss als .corrupted erkannt werden, nicht stillschweigend ersetzt: \(result)")
        }
    }

    func testStructurallyValidButEmptyStringIsCorruptedNotMisreadAsEmptySnapshot() {
        let result = TrainingDayContentSnapshot.decode(fromJSON: "")
        guard case .failure(.corrupted) = result else {
            return XCTFail("leerer String ist kein gültiger, leerer Snapshot, sondern unlesbar: \(result)")
        }
    }

    func testUnsupportedFutureSchemaVersionIsRejectedExplicitly() {
        // Simuliert eine künftige Payload-Version, die dieser Code noch nicht kennt —
        // von Hand gebaut, weil `currentSchemaVersion` nicht von außen überschreibbar ist
        // (das ist Absicht: niemand soll versehentlich eine falsche Version encodieren).
        let futureVersionJSON = """
        {"schemaVersion":99,"dayNameSnapshot":"Push A","dayCustomNameSnapshot":null,
        "dayLocalizationKeySnapshot":null,"weekday":2,"dayType":"chest","timeFormat":null,
        "timeCapMinutes":null,"circuitRounds":null,"circuitRestSeconds":null,"circuitMode":null,
        "exercises":[]}
        """
        let result = TrainingDayContentSnapshot.decode(fromJSON: futureVersionJSON)
        guard case .failure(.unsupportedSchemaVersion(99)) = result else {
            return XCTFail("eine unbekannte Schemaversion darf nie als aktuelle Version geraten/interpretiert werden: \(result)")
        }
    }

    // MARK: - TrainingDayContentSnapshotState (die drei Fälle, mit denen ein Aufrufer rechnen muss)

    func testStateDistinguishesAllThreeCasesCleanly() {
        let snapshot = makeSnapshot(exercises: [makeExercise(orderIndex: 0)])
        guard let json = snapshot.encodedJSON() else { return XCTFail() }

        let available: TrainingDayContentSnapshotState
        switch TrainingDayContentSnapshot.decode(fromJSON: json) {
        case .success(let s): available = .available(s)
        case .failure(let e): available = .unreadable(e)
        }
        XCTAssertEqual(available, .available(snapshot))

        let notCaptured = TrainingDayContentSnapshotState.notCaptured
        XCTAssertNotEqual(notCaptured, available, "kein Snapshot und ein gelesener Snapshot sind nie derselbe Fall")

        let unreadable: TrainingDayContentSnapshotState
        switch TrainingDayContentSnapshot.decode(fromJSON: "kaputt") {
        case .success(let s): unreadable = .available(s)
        case .failure(let e): unreadable = .unreadable(e)
        }
        XCTAssertEqual(unreadable, .unreadable(.corrupted))
        XCTAssertNotEqual(unreadable, notCaptured, "beschädigt ist NICHT dasselbe wie 'nie aufgenommen'")
        XCTAssertNotEqual(unreadable, available)
    }
}
