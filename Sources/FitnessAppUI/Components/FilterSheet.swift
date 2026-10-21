#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

// DEL-210: Aus dem gelöschten ExercisePickerView.swift extrahiert — die
// FilterSheet wird jetzt ausschließlich von der vereinheitlichten
// ExerciseLibraryView (Bibliothek + Picker-Modus) genutzt und lebt als
// eigenständige Komponente.

/// DEL-136 Part D: Multi-Select-Filter für Equipment + Muscle Group.
/// Zwei Sections, jeweils mit allen verfuegbaren Cases als Toggle-Rows.
/// Per-row Tap macht das Toggle smooth + spring-animiert. Footer-Button
/// raeumt alle Filter weg. Dismissal via Drag-down oder "Fertig".
@available(iOS 17.0, macOS 14.0, *)
struct FilterSheet: View {
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var selectedMuscles: Set<MuscleGroup>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        FilterToggleRow(
                            label: String(localized: equipment.localizedName),
                            isOn: Binding(
                                get: { selectedEquipment.contains(equipment) },
                                set: { newValue in
                                    if newValue { selectedEquipment.insert(equipment) }
                                    else        { selectedEquipment.remove(equipment) }
                                }
                            )
                        )
                    }
                    .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("picker.exercise.filter.section.equipment", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)

                Section {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        FilterToggleRow(
                            label: String(localized: muscle.localizedName),
                            isOn: Binding(
                                get: { selectedMuscles.contains(muscle) },
                                set: { newValue in
                                    if newValue { selectedMuscles.insert(muscle) }
                                    else        { selectedMuscles.remove(muscle) }
                                }
                            )
                        )
                    }
                    .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("picker.exercise.filter.section.muscle", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)

                // Reset-Button am Ende. Disabled wenn schon nichts ausgewaehlt.
                Section {
                    Button(role: .destructive) {
                        selectedEquipment.removeAll()
                        selectedMuscles.removeAll()
                    } label: {
                        HStack {
                            Spacer()
                            Text("picker.exercise.filter.reset", bundle: .module)
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .disabled(selectedEquipment.isEmpty && selectedMuscles.isEmpty)
                    .listRowBackground(Color.Deltiq.surface)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("picker.exercise.filter.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("common.done", bundle: .module)
                    }
                }
            }
        }
    }
}

/// Kleine Helper-Row mit Checkmark-Indikator statt iOS-Toggle-Switch.
/// Tap toggled den Bool und triggered die Animation; visuell aufgeraeumter
/// als Switch fuer multi-select Listen.
@available(iOS 17.0, macOS 14.0, *)
struct FilterToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.deltiqOrange : Color.Deltiq.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
