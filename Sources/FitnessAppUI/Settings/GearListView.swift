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
                    Label("Noch keine Ausrüstung", systemImage: "shoe")
                } description: {
                    Text("Lege deine Laufschuhe an, damit die App deine Kilometer automatisch trackt.")
                } actions: {
                    Button {
                        showingNewGearSheet = true
                    } label: {
                        Label("Schuh anlegen", systemImage: "plus")
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
                    Text("Cardio-Workouts buchen ihre Distanz automatisch auf den im Finish-Sheet ausgewaehlten Schuh.")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Ausrüstung")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewGearSheet = true
                } label: {
                    Label("Hinzufügen", systemImage: "plus")
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
                    Text("INAKTIV").deltiqLabel()
                }
            }
            ProgressView(value: min(gear.progress, 1.0))
                .tint(gear.needsReplacement ? .red : Color.deltiqOrange)
            if gear.needsReplacement {
                Label("Schuh erneuern — Dämpfung erschöpft.", systemImage: "exclamationmark.triangle.fill")
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
            Section("Allgemein") {
                TextField("Name (z.B. Nike Pegasus 40)", text: $name)
                Picker("Typ", selection: $type) {
                    Text("Laufschuh").tag(GearType.shoe)
                    Text("Fahrrad").tag(GearType.bike)
                }
                Toggle("Aktiv (im Picker anbieten)", isOn: $isActive)
            }
            Section("Distanz") {
                Stepper(value: $maxDistance, in: 100...3000, step: 50) {
                    LabeledContent("Max. km", value: "\(Int(maxDistance))")
                }
                TextField("Bisherige km",
                          value: $currentDistance,
                          format: .number,
                          prompt: Text("0"))
                    .decimalKeyboard()
            } footer: {
                Text("Laufschuhe verlieren nach ~600–800 km ihre Dämpfung. Bei Erreichen des Maximums warnt die App.")
                    .font(.footnote)
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
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
        if case .new = mode { return "Neue Ausrüstung" }
        return "Bearbeiten"
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
