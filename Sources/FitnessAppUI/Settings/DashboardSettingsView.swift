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
            // DEL-132 (Phase 1): Hero-Section ZUERST — sie sitzt auch im
            // gerenderten Dashboard oben, also matched die visuelle
            // Vertikal-Reihenfolge das Settings-Layout.
            heroActiveSection
            heroInactiveSection
            activeSection
            inactiveSection
        }
        .navigationTitle(Text("dashboardSettings.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // DEL-109: EditButton schaltet den nativen iOS-Drag-Mode an —
        // ohne den gibt's keine sichtbaren Drag-Handles.
        .toolbar {
            ToolbarItem(placement: .deltiqTrailing) {
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

    // MARK: - DEL-132 Hero-Sektion (Hero-Metric-Slots, max 3)

    /// Aktive Hero-Slots: Drag-to-reorder + Toggle-to-remove. Identisches
    /// Pattern wie `activeSection`, nur dass die Liste auf max 3 Slots
    /// gecapped ist (siehe `HeroMetricType.maxSlots`).
    @ViewBuilder
    private var heroActiveSection: some View {
        Section {
            if profile.heroMetricSlots.isEmpty {
                Text("dashboardSettings.section.hero.empty", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(profile.heroMetricSlots, id: \.self) { slot in
                    heroActiveRow(slot)
                }
                .onMove(perform: moveHero)
            }
        } header: {
            Text("dashboardSettings.section.hero.title", bundle: .module)
        } footer: {
            Text("dashboardSettings.section.hero.footer", bundle: .module)
                .font(.footnote)
        }
    }

    private func heroActiveRow(_ slot: HeroMetricType) -> some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(slot.localizationKey), bundle: .module)
                .font(.body)
            Spacer()
            // DEL-132 (Phase 1): gleiche Toggle-as-removal-Logic wie
            // aktiver Widget-Section.
            // DEL-132 (Phase 4): Spring-Animation um die Mutation,
            // sodass die Row beim Toggle-Off rauschmelzt statt
            // schlagartig zu poppen — sieht weicher aus auf der
            // Settings-List.
            Toggle("", isOn: Binding(
                get: { true },
                set: { isActive in
                    if !isActive {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            var copy = profile.heroMetricSlots
                            copy.removeAll { $0 == slot }
                            profile.heroMetricSlots = copy
                        }
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private func moveHero(from source: IndexSet, to destination: Int) {
        // DEL-132 (Phase 4): Spring auch beim Reorder — sieht smooth
        // aus, die Cards animieren in ihre neuen Slots.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            var arr = profile.heroMetricSlots
            arr.move(fromOffsets: source, toOffset: destination)
            profile.heroMetricSlots = arr
        }
    }

    /// Verfuegbare Hero-Slots (die NICHT in der aktiven Liste sind).
    /// Add-Button ist disabled, sobald `maxSlots` erreicht — User
    /// kriegt einen erklaerenden Footer-Hint statt einer scheinbar
    /// kaputten Plus-Taste.
    @ViewBuilder
    private var heroInactiveSection: some View {
        let inactive = HeroMetricType.allCases
            .filter { !profile.heroMetricSlots.contains($0) }
        let atMax = profile.heroMetricSlots.count >= HeroMetricType.maxSlots

        if !inactive.isEmpty {
            Section {
                ForEach(inactive, id: \.self) { slot in
                    HStack {
                        Text(LocalizedStringKey(slot.localizationKey), bundle: .module)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            // DEL-132 (Phase 4): Spring beim Add-Tap, damit
                            // der neue Slot smooth in die aktive Liste
                            // einsliden + auf dem Dashboard mit dem
                            // entsprechenden Hero-Transition erscheinen.
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                var arr = profile.heroMetricSlots
                                arr.append(slot)
                                profile.heroMetricSlots = arr
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(atMax ? Color.secondary : Color.deltiqOrange)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(atMax)
                    }
                }
            } header: {
                Text("dashboardSettings.section.heroInactive.title", bundle: .module)
            } footer: {
                Text(atMax
                     ? "dashboardSettings.section.hero.maxReached"
                     : "dashboardSettings.section.heroInactive.footer",
                     bundle: .module)
                    .font(.footnote)
            }
        }
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
