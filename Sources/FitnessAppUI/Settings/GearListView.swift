#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-084: Verwaltung der Equipment-Liste (primaer Laufschuhe). Listet alle
/// `Gear`-Eintraege mit Progress-Bar (gelaufene / max km) und Markierung
/// rot, wenn ueber Maximum. Add via Header-Action, Edit via Row-Tap,
/// Delete via explizitem Knopf (kein List mehr, also keine Swipe-Geste).
@available(iOS 17.0, macOS 14.0, *)
public struct GearListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gear.createdAt, order: .reverse) private var allGears: [Gear]

    @State private var editingGear: Gear?
    @State private var showingNewGearSheet = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // BackupListView/DataExportView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "gear.list.title", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    DeltiqHeaderAction(systemImage: "plus") {
                        showingNewGearSheet = true
                    }
                ]
            )

            VStack(alignment: .leading, spacing: 18) {
                if allGears.isEmpty {
                    emptyState
                } else {
                    gearCard
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
        .sheet(isPresented: $showingNewGearSheet) {
            NavigationStack {
                GearEditorView(mode: .new)
            }
        }
        .sheet(item: $editingGear) { gear in
            NavigationStack {
                GearEditorView(mode: .edit(gear))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        DashboardEmptyState(
            icon: "backpack.fill",
            title: "gear.list.empty.title",
            description: "gear.list.empty.description",
            ctaTitle: "gear.list.empty.cta",
            ctaAction: { showingNewGearSheet = true }
        )
        .deltiqCardStyle()
    }

    // MARK: - Gear list

    private var gearCard: some View {
        DeltiqSection {
            ForEach(allGears) { gear in
                gearRow(gear, showsDivider: gear.id != allGears.last?.id)
            }
            hintRow(String(localized: "gear.list.footer", bundle: .module))
        }
    }

    private func gearRow(_ gear: Gear, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: gear.type == .shoe ? "shoe" : "bicycle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(gear.needsReplacement ? Color.Deltiq.error : Color.deltiqOrange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gear.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("\(formatKm(gear.currentDistanceKm)) / \(formatKm(gear.maxDistanceKm)) km")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(gear.needsReplacement ? Color.Deltiq.error : Color.Deltiq.textSecondary)
                    }
                    Spacer()
                    if !gear.isActive {
                        Text("gear.inactive", bundle: .module).deltiqLabel()
                    }
                    // Ersetzt das bisherige .onDelete-Swipe (List-exklusiv,
                    // funktioniert nicht mehr ausserhalb einer List) durch
                    // einen expliziten Loesch-Knopf pro Zeile — Zeilen-Tap
                    // bleibt fuer "Bearbeiten" reserviert.
                    Button {
                        delete(gear)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.Deltiq.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                ProgressView(value: min(gear.progress, 1.0))
                    .tint(gear.needsReplacement ? Color.Deltiq.error : Color.deltiqOrange)
                if gear.needsReplacement {
                    Label {
                        Text("gear.needsReplacement", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Deltiq.error)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                editingGear = gear
            }
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private func delete(_ gear: Gear) {
        modelContext.delete(gear)
    }

    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 0).formattedTwoDecimals
    }
}

// MARK: - GearEditorView (Add + Edit)

/// Gruppe B (Sheet): praesentiert per `.sheet`, Cancel/Fertig statt
/// Zurueck-Navigation - bekommt bewusst KEIN DeltiqHeader (siehe Handoff-
/// Regel "Sheets sind kein Fall fuer DeltiqHeader"). Native Toolbar/Titel
/// bleiben; die Form-Rows tragen jetzt die Deltiq-Karten-Flaeche.
@available(iOS 17.0, macOS 14.0, *)
private struct GearEditorView: View {
    enum Mode {
        case new
        case edit(Gear)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: GearType = .shoe
    @State private var maxDistance: Double = 800
    @State private var currentDistance: Double = 0
    @State private var isActive: Bool = true
    @State private var didInit: Bool = false

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "gear.editor.field.name", bundle: .module), text: $name)
                    .listRowBackground(Color.Deltiq.surface)
                Picker(selection: $type) {
                    Text("gear.editor.type.shoe", bundle: .module).tag(GearType.shoe)
                    Text("gear.editor.type.bike", bundle: .module).tag(GearType.bike)
                } label: {
                    Text("gear.editor.field.type", bundle: .module)
                }
                .listRowBackground(Color.Deltiq.surface)
                Toggle(isOn: $isActive) {
                    Text("gear.editor.toggle.active", bundle: .module)
                }
                .tint(Color.deltiqOrange)
                .listRowBackground(Color.Deltiq.surface)
            } header: {
                Text("gear.editor.section.general", bundle: .module)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
            // Xcode-26-Fix: Section("Distanz") { … } footer: { … } prallt
            // gegen den strikten Section-API-Match — string-init kollidiert
            // mit der footer-Trailing-Closure-Overload. Explizit den
            // `header:` Closure verwenden, dann ist es eindeutig.
            Section {
                Stepper(value: $maxDistance, in: 100...3000, step: 50) {
                    LabeledContent {
                        Text("\(Int(maxDistance))")
                    } label: {
                        Text("gear.editor.field.maxKm", bundle: .module)
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
                TextField(value: $currentDistance,
                          format: .number,
                          prompt: Text("0")) {
                    Text("gear.editor.field.currentKm", bundle: .module)
                }
                    .decimalKeyboard()
                    .listRowBackground(Color.Deltiq.surface)
            } header: {
                Text("gear.editor.section.distance", bundle: .module)
            } footer: {
                Text("gear.editor.distance.footer", bundle: .module)
                    .font(.footnote)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
        .scrollContentBackground(.hidden)
        .background(Color.Deltiq.background.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Text("common.cancel", bundle: .module)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button { save() } label: {
                    Text("common.save", bundle: .module)
                }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard !didInit else { return }
            didInit = true
            if case .edit(let gear) = mode {
                name = gear.name
                type = gear.type
                maxDistance = gear.maxDistanceKm
                currentDistance = gear.currentDistanceKm
                isActive = gear.isActive
            }
        }
    }

    private var navigationTitle: String {
        if case .new = mode { return String(localized: "gear.editor.title.new", bundle: .module) }
        return String(localized: "gear.editor.title.edit", bundle: .module)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .new:
            let gear = Gear(
                name: trimmed,
                type: type,
                maxDistanceKm: maxDistance,
                currentDistanceKm: currentDistance,
                isActive: isActive
            )
            modelContext.insert(gear)
        case .edit(let gear):
            gear.name = trimmed
            gear.type = type
            gear.maxDistanceKm = maxDistance
            gear.currentDistanceKm = currentDistance
            gear.isActive = isActive
        }
        dismiss()
    }
}
#endif
