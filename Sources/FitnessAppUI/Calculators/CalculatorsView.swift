#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

/// Hub for the utility calculators. Pure dispatcher — each row pushes onto the same
/// NavigationStack so the user gets the standard back-swipe affordance.
///
/// Nachtrag 6. August (README.md, "der Start-Tab weicht den Werkzeugen"):
/// Wurzel des vierten Tabs ("Werkzeuge") statt eine Ebene tief unter "Mehr"
/// gepusht — daher kein `onBack`/`dismiss()` mehr, eine Tab-Wurzel hat
/// nichts zum Zurueckspringen.
@available(iOS 17.0, macOS 14.0, *)
public struct CalculatorsView: View {

    /// Handoff 2.3: der Footer-Text "Alle Rechner arbeiten mit deiner
    /// eingestellten Einheit" wird zur Kontextzeile. Der Vorschlag "EINHEIT:
    /// KG / CM" im Handoff nennt zwei unabhaengige Einheiten - es gibt aber
    /// nur eine einzige Praeferenz (`weight_unit`, kg/lbs), keine separate
    /// cm/inch-Einstellung. Die Kapsel zeigt daher die tatsaechliche,
    /// einzelne Einheit.
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.tools", bundle: .module).uppercased(),
                title: String(localized: "calc.index.title", bundle: .module)
            )

            VStack(alignment: .leading, spacing: 18) {
                DeltiqContextRow([
                    DeltiqContextItem(
                        String(
                            format: String(localized: "calc.index.unitContext", bundle: .module),
                            weightUnitRaw.uppercased()
                        ),
                        style: .neutral
                    )
                ])

                DeltiqSection {
                    NavigationLink(destination: PlateCalculatorView()) {
                        DeltiqRow(
                            icon: "scalemass.fill",
                            label: String(localized: "calc.index.plate.title", bundle: .module),
                            subtitle: String(localized: "calc.index.plate.subtitle", bundle: .module),
                            showsChevron: true
                        )
                    }
                    NavigationLink(destination: OneRepMaxView()) {
                        DeltiqRow(
                            icon: "figure.strengthtraining.traditional",
                            label: String(localized: "calc.index.oneRm.title", bundle: .module),
                            subtitle: String(localized: "calc.index.oneRm.subtitle", bundle: .module),
                            showsChevron: true
                        )
                    }
                    NavigationLink(destination: TDEEView()) {
                        DeltiqRow(
                            icon: "flame.fill",
                            label: String(localized: "calc.index.tdee.title", bundle: .module),
                            subtitle: String(localized: "calc.index.tdee.subtitle", bundle: .module),
                            showsChevron: true
                        )
                    }
                    NavigationLink(destination: WaterTrackerView()) {
                        DeltiqRow(
                            icon: "drop.fill",
                            label: String(localized: "calc.index.water.title", bundle: .module),
                            subtitle: String(localized: "calc.index.water.subtitle", bundle: .module),
                            showsChevron: true,
                            showsDivider: false
                        )
                    }
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
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
