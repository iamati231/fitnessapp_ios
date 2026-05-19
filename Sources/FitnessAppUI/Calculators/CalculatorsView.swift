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
                        title: String(localized: "calc.index.plate.title", bundle: .module),
                        subtitle: String(localized: "calc.index.plate.subtitle", bundle: .module)
                    )
                }
                NavigationLink(destination: OneRepMaxView()) {
                    CalculatorRow(
                        icon: "figure.strengthtraining.traditional",
                        tint: .orange,
                        title: String(localized: "calc.index.1rm.title", bundle: .module),
                        subtitle: String(localized: "calc.index.1rm.subtitle", bundle: .module)
                    )
                }
                NavigationLink(destination: TDEEView()) {
                    CalculatorRow(
                        icon: "flame.fill",
                        tint: .red,
                        title: String(localized: "calc.index.tdee.title", bundle: .module),
                        subtitle: String(localized: "calc.index.tdee.subtitle", bundle: .module)
                    )
                }
                NavigationLink(destination: WaterTrackerView()) {
                    CalculatorRow(
                        icon: "drop.fill",
                        tint: .cyan,
                        title: String(localized: "calc.index.water.title", bundle: .module),
                        subtitle: String(localized: "calc.index.water.subtitle", bundle: .module)
                    )
                }
            } footer: {
                Text("calc.index.footer", bundle: .module)
                    .font(.footnote)
            }
        }
        .navigationTitle(Text("calc.index.title", bundle: .module))
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
