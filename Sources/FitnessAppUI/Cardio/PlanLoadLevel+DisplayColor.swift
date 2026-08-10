#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Geteilte Belastungsfarbe fuer `PlanLoadLevel`-Kapseln - dieselbe Skala wie
/// `PlanBuilderView.loadLevelColor` (README 2.21: eigener dunklerer Ton fuer
/// `.hard`, damit er sich von `deltiqOrange` abhebt), hier oeffentlich, weil
/// die Machbarkeits-Check-Karten auf Profil/Dashboard/Plan-Tab dieselbe
/// Skala brauchen.
public extension PlanLoadLevel {
    var displayColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return Color.deltiqOrange
        case .hard:   return Color(red: 0.80, green: 0.35, blue: 0.05)
        case .tough:  return .red
        }
    }
}
#endif
