import Foundation

/// DEL-098: Grobe Recovery-Einordnung einer Uebung — als zusaetzliche
/// Heuristik neben den feingranularen Faktoren (systemic, local, cns,
/// axial, technical).
///
/// Wird vom UI fuer Quick-Decisions verwendet (z.B. "darf der User heute
/// noch eine Extreme-Klasse-Uebung machen?"), waehrend der detaillierte
/// Recovery-Score aus den Multiplikatoren errechnet wird.
public enum ExerciseRecoveryClass: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case extreme

    /// Display-Label (DE) fuer UI-Surfaces.
    public var label: String {
        switch self {
        case .low:     return "Leicht"
        case .medium:  return "Moderat"
        case .high:    return "Schwer"
        case .extreme: return "Extrem"
        }
    }
}
