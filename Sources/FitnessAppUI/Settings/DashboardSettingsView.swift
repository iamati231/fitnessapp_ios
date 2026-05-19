#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-109: Dashboard-Widget-Manager. Erlaubt dem User:
///   * Reihenfolge der aktiven Widgets per Drag & Drop zu ändern
///   * einzelne Widgets per Toggle zu deaktivieren
///   * inaktive Widgets per "+"-Button wieder zu aktivieren
///
/// Persistierung läuft direkt auf `UserBodyProfile.activeDashboardWidgets`
/// (Computed-Setter ueber `activeDashboardWidgetsRaw`). Die DashboardView
/// liest das gleiche Profil per @Query und re-rendert automatisch sobald
/// sich das `[String]`-Array aendert.
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardSettingsView: View {

    @Bindable public var profile: UserBodyProfile

    public init(profile: UserBodyProfile) {
        self.profile = profile
    }

    public var body: some View {
        List {
            activeSection
            inactiveSection
        }
        .navigationTitle(Text("dashboardSettings.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // DEL-109: EditButton schaltet den nativen iOS-Drag-Mode an —
        // ohne den gibt's keine sichtbaren Drag-Handles.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        #endif
    }

    // MARK: Aktive Sektion (drag + toggle)

    @ViewBuilder
    private var activeSection: some View {
        Section {
            if profile.activeDashboardWidgets.isEmpty {
                Text("dashboardSettings.empty", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(profile.activeDashboardWidgets, id: \.self) { widget in
                    activeRow(widget)
                }
                .onMove(perform: moveActive)
            }
        } header: {
            Text("dashboardSettings.section.active.title", bundle: .module)
        } footer: {
            Text("dashboardSettings.section.active.footer", bundle: .module)
                .font(.footnote)
        }
    }

    private func activeRow(_ widget: DashboardWidgetType) -> some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(widget.localizationKey), bundle: .module)
                .font(.body)
            Spacer()
            // Toggle steuert nur das Entfernen aus der aktiven Liste —
            // ein "false"-Set löscht das Widget, ein "true"-Set ist NoOp
            // (es ist ohnehin schon aktiv, weil wir es hier rendern).
            Toggle("", isOn: Binding(
                get: { true },
                set: { isActive in
                    if !isActive {
                        var copy = profile.activeDashboardWidgets
                        copy.removeAll { $0 == widget }
                        profile.activeDashboardWidgets = copy
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private func moveActive(from source: IndexSet, to destination: Int) {
        var arr = profile.activeDashboardWidgets
        arr.move(fromOffsets: source, toOffset: destination)
        profile.activeDashboardWidgets = arr
    }

    // MARK: Inaktive Sektion (re-aktivieren via "+")

    @ViewBuilder
    private var inactiveSection: some View {
        let inactiveWidgets = DashboardWidgetType.allCases
            .filter { !profile.activeDashboardWidgets.contains($0) }

        if !inactiveWidgets.isEmpty {
            Section {
                ForEach(inactiveWidgets, id: \.self) { widget in
                    HStack {
                        Text(LocalizedStringKey(widget.localizationKey), bundle: .module)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            var arr = profile.activeDashboardWidgets
                            arr.append(widget)
                            profile.activeDashboardWidgets = arr
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.deltiqOrange)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("dashboardSettings.section.inactive.title", bundle: .module)
            } footer: {
                Text("dashboardSettings.section.inactive.footer", bundle: .module)
                    .font(.footnote)
            }
        }
    }
}
#endif
