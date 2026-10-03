import Foundation

/// Errors surfaced by `HealthKitService` and `HealthKitController`. Defined as a
/// platform-neutral enum so callers on non-Apple platforms (Windows-CI tests) can
/// still reference the type — they just never see most cases.
public enum HealthKitError: Error, Sendable, LocalizedError {
    case unavailable
    case authorizationFailed(reason: String)
    case queryFailed(reason: String)
    case saveFailed(reason: String)
    case invalidValue(reason: String)
    /// Write permission for the workout type is missing (never asked or
    /// denied), checked fresh at write time.
    case writeNotAuthorized
    /// HealthKit's database is not accessible (typically: device locked).
    case databaseInaccessible
    /// HealthKit rejected THIS workout (e.g. invalid dates); retrying the
    /// same workout will not help.
    case invalidWorkout(reason: String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health ist auf diesem Gerät nicht verfügbar."
        case .authorizationFailed(let reason):
            return "HealthKit-Berechtigung fehlgeschlagen: \(reason)"
        case .queryFailed(let reason):
            return "HealthKit-Abfrage fehlgeschlagen: \(reason)"
        case .saveFailed(let reason):
            return "HealthKit-Speichern fehlgeschlagen: \(reason)"
        case .invalidValue(let reason):
            return "Ungültiger Health-Wert: \(reason)"
        case .writeNotAuthorized:
            return "Apple Health: Schreibzugriff für Trainings fehlt."
        case .databaseInaccessible:
            return "Apple Health ist gerade nicht lesbar (Gerät gesperrt?)."
        case .invalidWorkout(let reason):
            return "Apple Health hat das Training abgelehnt: \(reason)"
        }
    }
}
