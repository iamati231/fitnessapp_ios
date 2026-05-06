#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

/// Hub for the utility calculators. Pure dispatcher — each row pushes onto the same
/// NavigationStack so the user gets the standard back-swipe affordance.
@available(iOS 17.0, macOS 14.0, *)
public struct CalculatorsView: View {

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink(destination: PlateCalculatorView()) {
                    CalculatorRow(
                        icon: "scalemass.fill",
                        tint: .blue,
                        title: "Hantel-Rechner",
                        subtitle: "Welche Plates fuer dein Zielgewicht — mit Inventar-Cap und visualer Stange."
                    )
                }
                NavigationLink(destination: OneRepMaxView()) {
                    CalculatorRow(
                        icon: "figure.strengthtraining.traditional",
                        tint: .orange,
                        title: "1RM-Rechner",
                        subtitle: "Epley + Brzycki + Mittelwert, plus Trainings-%-Tabelle."
                    )
                }
                NavigationLink(destination: TDEEView()) {
                    CalculatorRow(
                        icon: "flame.fill",
                        tint: .red,
                        title: "Kalorien-Rechner",
                        subtitle: "BMR + TDEE aus deinem Profil und Aktivitaets-Level."
                    )
                }
                NavigationLink(destination: WaterTrackerView()) {
                    CalculatorRow(
                        icon: "drop.fill",
                        tint: .cyan,
                        title: "Wasser-Tracker",
                        subtitle: "Tagesziel = Gewicht × 35 ml. Mit Quick-Add."
                    )
                }
            } footer: {
                Text("Alle Rechner nutzen die gleiche Domain-Logik (FitnessAppCore) wie der Rest der App — Werte sind 1:1 mit Dashboard und MeasurementView.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Rechner")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CalculatorRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        CalculatorsView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}
#endif
#endif
