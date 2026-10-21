import XCTest
@testable import FitnessAppHealth

/// Die Zustandslogik hinter dem Bildschirm "Trainings in Health". Sie sitzt in
/// den (plattformneutralen) Typen, weil genau hier der Fehler lag: iOS meldet
/// `.sharingDenied` auch fuer einen Typ, der nur zum LESEN angefragt wurde
/// (Workout-Import), und zeigt dann nie wieder einen Dialog. Aus dem
/// Schreibstatus allein war "Nutzer hat abgelehnt" nicht von "iOS fragt nicht
/// mehr" zu unterscheiden.
final class WorkoutWriteAuthorizationTests: XCTestCase {

    private func access(
        _ workout: HealthKitAuthorizationStatus,
        request: HealthKitRequestStatus = .unknown,
        distance: HealthKitAuthorizationStatus = .notDetermined
    ) -> WorkoutAccessState {
        WorkoutWriteAuthorization(workout: workout, distance: distance, workoutRequest: request).workoutAccess
    }

    // MARK: - workoutAccess

    func testGrantedWhenWriteIsAuthorized() {
        XCTAssertEqual(access(.sharingAuthorized), .granted)
        XCTAssertEqual(access(.sharingAuthorized, request: .unnecessary), .granted)
        XCTAssertEqual(access(.sharingAuthorized, request: .shouldRequest), .granted)
    }

    /// Frischer Start (Controller-Anfangswert) und nie gefragt: der Dialog ist moeglich.
    func testNeverAskedCanBeRequested() {
        XCTAssertEqual(access(.notDetermined), .canRequest)
        XCTAssertEqual(access(.notDetermined, request: .shouldRequest), .canRequest)
        // Widerspruechlich ("nie gefragt", aber "unnoetig"): einmal versuchen.
        XCTAssertEqual(access(.notDetermined, request: .unnecessary), .canRequest)
    }

    /// Der Geraetefund: Trainings nur zum Lesen angefragt -> iOS meldet "verweigert",
    /// die Anfrage ist "unnoetig", es gibt keinen Dialog und keinen Schalter in Health.
    func testDeniedWithUnnecessaryRequestIsBlocked() {
        XCTAssertEqual(access(.sharingDenied, request: .unnecessary), .blocked)
    }

    /// "Verweigert", iOS wuerde aber noch fragen: Schaltflaeche statt Sackgasse.
    func testDeniedButAskableCanBeRequested() {
        XCTAssertEqual(access(.sharingDenied, request: .shouldRequest), .canRequest)
    }

    /// Schlaegt die Abfrage des Anfrage-Status fehl, ist ein harmloser Versuch
    /// besser als eine Sackgasse.
    func testDeniedWithUnknownRequestStatusIsTriedOnce() {
        XCTAssertEqual(access(.sharingDenied, request: .unknown), .canRequest)
    }

    func testUnavailable() {
        XCTAssertEqual(access(.unavailable), .unavailable)
        XCTAssertEqual(WorkoutWriteAuthorization.unavailable.workoutAccess, .unavailable)
    }

    // MARK: - canRequestWorkout (gemeinsam von Bildschirm und Service genutzt)

    func testCanRequestWorkoutTruthTable() {
        let requests: [HealthKitRequestStatus] = [.unknown, .shouldRequest, .unnecessary]
        for request in requests {
            XCTAssertTrue(WorkoutWriteAuthorization.canRequestWorkout(status: .notDetermined, request: request))
            XCTAssertFalse(WorkoutWriteAuthorization.canRequestWorkout(status: .sharingAuthorized, request: request))
            XCTAssertFalse(WorkoutWriteAuthorization.canRequestWorkout(status: .unavailable, request: request))
        }
        XCTAssertTrue(WorkoutWriteAuthorization.canRequestWorkout(status: .sharingDenied, request: .shouldRequest))
        XCTAssertTrue(WorkoutWriteAuthorization.canRequestWorkout(status: .sharingDenied, request: .unknown))
        XCTAssertFalse(WorkoutWriteAuthorization.canRequestWorkout(status: .sharingDenied, request: .unnecessary))
    }

    // MARK: - Werte

    func testRequestStatusDefaultsToUnknown() {
        let value = WorkoutWriteAuthorization(workout: .notDetermined, distance: .notDetermined)
        XCTAssertEqual(value.workoutRequest, .unknown)
    }

    /// Der Bildschirm vergleicht den Zustand vor und nach der Anfrage.
    func testEquatableDistinguishesTheRequestStatus() {
        let before = WorkoutWriteAuthorization(workout: .sharingDenied, distance: .notDetermined, workoutRequest: .shouldRequest)
        let same = WorkoutWriteAuthorization(workout: .sharingDenied, distance: .notDetermined, workoutRequest: .shouldRequest)
        let after = WorkoutWriteAuthorization(workout: .sharingDenied, distance: .notDetermined, workoutRequest: .unnecessary)
        XCTAssertEqual(before, same)
        XCTAssertNotEqual(before, after)
    }

    func testCanWriteWorkoutsOnlyWhenAuthorized() {
        XCTAssertTrue(WorkoutWriteAuthorization(workout: .sharingAuthorized, distance: .notDetermined).canWriteWorkouts)
        XCTAssertFalse(WorkoutWriteAuthorization(workout: .sharingDenied, distance: .sharingAuthorized).canWriteWorkouts)
        XCTAssertFalse(WorkoutWriteAuthorization(workout: .notDetermined, distance: .sharingAuthorized).canWriteWorkouts)
    }

    func testDiagnosticDescriptionNamesAllThreeStates() {
        let value = WorkoutWriteAuthorization(workout: .sharingDenied, distance: .notDetermined, workoutRequest: .unnecessary)
        XCTAssertEqual(value.diagnosticDescription, "workout=denied · request=unnecessary · distance=notDetermined")
        XCTAssertEqual(
            WorkoutWriteAuthorization(workout: .sharingAuthorized, distance: .sharingAuthorized, workoutRequest: .shouldRequest).diagnosticDescription,
            "workout=authorized · request=shouldRequest · distance=authorized"
        )
    }
}
