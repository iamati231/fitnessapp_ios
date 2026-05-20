#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-084: Verwaltung der Equipment-Liste (primaer Laufschuhe). Listet alle
/// `Gear`-Eintraege mit Progress-Bar (gelaufene / max km) und Markierung
/// rot, wenn ueber Maximum. Add via Toolbar-Button, Edit via Row-Tap,
/// Delete via Swipe.
@available(iOS 17.0, macOS 14.0, *)
public struct GearListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gear.createdAt, order: .reverse) private var allGears: [Gear]

    @State private var editingGear: Gear?
    @State private var showingNewGearSheet = false

    public init() {}

    public var body: some View {
        List {
            if allGears.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("gear.list.empty.title", bundle: .module)
                    } icon: {
                        // DEL-130: Icon-Wechsel von `shoe` auf `backpack.fill`.
                        // Vorher suggerierte der Schuh-Icon den Empty-State
                        // als Lauf-only, obwohl wir hier auch Fahrräder (DEL-
                        // 084) tracken — der User uebersah die Bike-Option.
                        // `backpack.fill` ist ab iOS 17+ verfügbar und steht
                        // generisch fuer "Trainings-Equipment", egal welche
                        // Sportart.
                        Image(systemName: "backpack.fill")
                    }
                } description: {
                    Text("gear.list.empty.description", bundle: .module)
                } actions: {
                    Button {
                        showingNewGearSheet = true
                    } label: {
                        Label {
                            Text("gear.list.empty.cta", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    ForEach(allGears) { gear in
                        Button {
                            editingGear = gear
                        } label: {
                            GearRow(gear: gear)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteGears)
                } footer: {
                    Text("gear.list.footer", bundle: .module)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(Text("gear.list.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewGearSheet = true
                } label: {
                    Label {
                        Text("common.add", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
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

    private func deleteGears(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(allGears[index])
        }
    }
}

// MARK: - GearRow

@available(iOS 17.0, macOS 14.0, *)
private struct GearRow: View {
    let gear: Gear

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: gear.type == .shoe ? "shoe" : "bicycle")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
                    .foregroundStyle(gear.needsReplacement ? .red : Color.deltiqOrange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gear.name)
                        .font(.body.weight(.semibold))
                    Text("\(formatKm(gear.currentDistanceKm)) / \(formatKm(gear.maxDistanceKm)) km")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(gear.needsReplacement ? .red : .secondary)
                }
                Spacer()
                if !gear.isActive {
                    Text("gear.inactive", bundle: .module).deltiqLabel()
                }
            }
            ProgressView(value: min(gear.progress, 1.0))
                .tint(gear.needsReplacement ? .red : Color.deltiqOrange)
            if gear.needsReplacement {
                Label {
                    Text("gear.needsReplacement", bundle: .module)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 0).formattedTwoDecimals
    }
}

// MARK: - GearEditorView (Add + Edit)

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
                Picker(selection: $type) {
                    Text("gear.editor.type.shoe", bundle: .module).tag(GearType.shoe)
                    Text("gear.editor.type.bike", bundle: .module).tag(GearType.bike)
                } label: {
                    Text("gear.editor.field.type", bundle: .module)
                }
                Toggle(isOn: $isActive) {
                    Text("gear.editor.toggle.active", bundle: .module)
                }
            } header: {
                Text("gear.editor.section.general", bundle: .module)
            }
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
                TextField(value: $currentDistance,
                          format: .number,
                          prompt: Text("0")) {
                    Text("gear.editor.field.currentKm", bundle: .module)
                }
                    .decimalKeyboard()
            } header: {
                Text("gear.editor.section.distance", bundle: .module)
            } footer: {
                Text("gear.editor.distance.footer", bundle: .module)
                    .font(.footnote)
            }
        }
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
