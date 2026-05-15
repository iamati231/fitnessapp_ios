import Foundation

/// DEL-057: Wie der User die gerade abgeschlossene Session subjektiv
/// empfunden hat. Wird am Ende des Workouts auf einer Half-Sheet abgefragt
/// und vom `ProgressionApplicator` als Erschoepfungs-Veto ausgewertet:
/// `.hard` und `.destroyed` veto'en JEDE Gewichts-Erhoehung im naechsten
/// Workout, weil der User schon am Limit war — mehr drauflegen waere
/// ueberfordernd.
///
/// Persistiert als rawValue (Int 1...5) in `WorkoutSession.sessionFeeling`.
public enum SessionFeeling: Int, CaseIterable, Sendable, Hashable {
    case great    = 1   // Grossartig — Locker, koennte noch viel mehr
    case good     = 2   // Gut
    case okay     = 3   // Okay
    case hard     = 4   // Sehr schwer — User schon an seiner Grenze
    case destroyed = 5  // Zerstoert / Am Limit

    /// True wenn das Feeling so erschoepfend war, dass im naechsten Workout
    /// KEINE Gewichts-Erhoehung stattfinden darf. Veto-Schwelle = `.hard`.
    public var vetoesProgression: Bool {
        switch self {
        case .hard, .destroyed: return true
        case .great, .good, .okay: return false
        }
    }

    /// Deutscher User-Label fuer das Half-Sheet. UI mappt via diesem
    /// Property, damit die Strings nicht ueber die ganze Codebase zerstreut
    /// rumliegen.
    public var label: String {
        switch self {
        case .great:     return "Großartig"
        case .good:      return "Gut"
        case .okay:      return "Okay"
        case .hard:      return "Sehr schwer"
        case .destroyed: return "Zerstört / Am Limit"
        }
    }

    /// SF-Symbol fuer die Half-Sheet-Buttons. Visuell von happy → exhausted.
    public var symbol: String {
        switch self {
        case .great:     return "face.smiling.inverse"
        case .good:      return "face.smiling"
        case .okay:      return "face.dashed"
        case .hard:      return "figure.strengthtraining.traditional"
        case .destroyed: return "exclamationmark.triangle.fill"
        }
    }
}
