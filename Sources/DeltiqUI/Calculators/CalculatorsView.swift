#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

/// Hub for the utility calculators. Pure dispatcher — each tile pushes onto the
/// same NavigationStack so the user gets the standard back-swipe affordance.
///
/// main-navigation Plan, 2026-10-22, Task 3: zieht vom entfallenen
/// Werkzeuge-Tab eine Ebene tief unter "Mehr" (`SettingsView`) ein — analog
/// zum Vor-6.-August-Stand. Braucht deshalb wieder `onBack`/`dismiss()` und
/// die Swipe-Back-Geste (siehe `ExerciseLibraryView` fuer dasselbe Muster).
///
/// UI-Ticket ("Tab-Leiste vereinfachen", 2026-11-06): genau vier Werkzeuge —
/// eine vertikale Liste war dafuer ueberdimensioniert. Jetzt ein 2x2-Raster
/// (`LazyVGrid`, 2 feste Spalten), jede Kachel voll antippbar. Titel/
/// Untertitel/Icons/Navigation unveraendert identisch zur bisherigen Liste —
/// nur die Anordnung aendert sich, keine neue Wassertracker-Deep-Link-Logik
/// noetig (bleibt wertbasiert ueber `CalculatorsRoute.waterTracker`).
@available(iOS 17.0, macOS 14.0, *)
public struct CalculatorsView: View {

    @Environment(\.dismiss) private var dismiss

    /// Handoff 2.3: der Footer-Text "Alle Rechner arbeiten mit deiner
    /// eingestellten Einheit" wird zur Kontextzeile. Der Vorschlag "EINHEIT:
    /// KG / CM" im Handoff nennt zwei unabhaengige Einheiten - es gibt aber
    /// nur eine einzige Praeferenz (`weight_unit`, kg/lbs), keine separate
    /// cm/inch-Einstellung. Die Kapsel zeigt daher die tatsaechliche,
    /// einzelne Einheit.
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    /// Feste 2-Spalten-Anordnung auf allen unterstuetzten Displaygroessen —
    /// bei genau 4 Kacheln liefert `.adaptive` auf einem iPad/grossen Display
    /// 3-4 Spalten und zerreisst das gewuenschte 2x2-Bild; `.fixed(count: 2)`
    /// behaelt es ueberall bei.
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "calc.index.title", bundle: .module),
                onBack: { dismiss() }
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

                LazyVGrid(columns: columns, spacing: 12) {
                    NavigationLink(destination: PlateCalculatorView()) {
                        CalculatorTile(
                            icon: "scalemass.fill",
                            title: String(localized: "calc.index.plate.title", bundle: .module),
                            subtitle: String(localized: "calc.index.plate.subtitle", bundle: .module)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: OneRepMaxView()) {
                        CalculatorTile(
                            icon: "figure.strengthtraining.traditional",
                            title: String(localized: "calc.index.oneRm.title", bundle: .module),
                            subtitle: String(localized: "calc.index.oneRm.subtitle", bundle: .module)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: TDEEView()) {
                        CalculatorTile(
                            icon: "flame.fill",
                            title: String(localized: "calc.index.tdee.title", bundle: .module),
                            subtitle: String(localized: "calc.index.tdee.subtitle", bundle: .module)
                        )
                    }
                    .buttonStyle(.plain)

                    // main-navigation Plan, 2026-10-22, Task 3, Fix-Runde 1:
                    // wertbasiert (`CalculatorsRoute.waterTracker`, aufgeloest
                    // von der `navigationDestination(for:)`-Registrierung in
                    // RootView) statt `NavigationLink(destination:)` — dieselbe
                    // Route-Maschinerie wie der Wassertracker-Deep-Link, damit
                    // kein Mix aus wert- und view-basierten Pushes zwischen
                    // SettingsView und WaterTrackerView uebrig bleibt. Die
                    // Kachel ist nur ein zweiter Weg dorthin — der Deep-Link
                    // selbst (`RootView.applyPendingRouteIfAny`) haengt die
                    // Route weiterhin direkt an `toolsPath`, unabhaengig von
                    // dieser Ansicht.
                    NavigationLink(value: CalculatorsRoute.waterTracker) {
                        CalculatorTile(
                            icon: "drop.fill",
                            title: String(localized: "calc.index.water.title", bundle: .module),
                            subtitle: String(localized: "calc.index.water.subtitle", bundle: .module)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        .deltiqSwipeBackEnabled()
    }
}

/// Eine Kachel im 2x2-Werkzeugraster. Volle Flaeche antippbar ueber den
/// umschliessenden `NavigationLink` (`.buttonStyle(.plain)` dort entfernt
/// den System-Blau-Tint); feste Mindesthoehe haelt alle vier Kacheln gleich
/// hoch unabhaengig von Textlaenge. Gleiche Oberflaechen-/Eckenkonvention
/// wie `DeltiqSection`/`DeltiqCard` (`Color.Deltiq.surface`,
/// `Deltiq.Radius.card`) — kein neuer Designbaustein fuer vier Kacheln.
@available(iOS 17.0, macOS 14.0, *)
private struct CalculatorTile: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .deltiqAccentIcon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        CalculatorsView()
            // Wassertracker-Zeile ist jetzt wertbasiert (Fix-Runde 1) — ohne
            // diese Registrierung wuerde der Tap im Preview ins Leere laufen.
            .navigationDestination(for: CalculatorsRoute.self) { route in
                switch route {
                case .calculators:
                    CalculatorsView()
                case .waterTracker:
                    WaterTrackerView()
                }
            }
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}
#endif
#endif
