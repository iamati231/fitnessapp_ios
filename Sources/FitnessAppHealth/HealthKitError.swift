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

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health ist auf diesem Geraet nicht verfuegbar."
        case .authorizationFailed(let reason):
            return "HealthKit-Berechtigung fehlgeschlagen: \(reason)"
        case .queryFailed(let reason):
            return "HealthKit-Abfrage fehlgeschlagen: \(reason)"
        case .saveFailed(let reason):
            return "HealthKit-Speichern fehlgeschlagen: \(reason)"
        case .invalidValue(let reason):
            return "Ungueltiger Health-Wert: \(reason)"
        }
    }
}
