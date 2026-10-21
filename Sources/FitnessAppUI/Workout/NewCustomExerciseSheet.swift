#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-159: Beim Anlegen einer Custom-Uebung erfasste Metadaten. Wird vom
/// `NewCustomExerciseSheet` produziert und an `ExercisePickerView.onCreateCustom`
/// uebergeben — die Caller (DayEditor / ActiveWorkout / WorkoutSummary) bauen
/// daraus Template + Exercise mit korrekten Werten.
public struct CustomExerciseDraft: Sendable, Equatable {
    public var name: String
    public var primaryMuscle: MuscleGroup
    public var equipment: Equipment
    public var isCompound: Bool

    public init(
        name: String,
        primaryMuscle: MuscleGroup,
        equipment: Equipment,
        isCompound: Bool
    ) {
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
        self.isCompound = isCompound
    }
}

/// DEL-159: Erstell-Sheet fuer eine Custom-Uebung. Erfasst Name + Zielmuskel
/// + Equipment + Compound/Isolation. Alle Felder sind OPTIONAL im Sinne von
/// "vorbelegt mit sichtbaren Defaults" — der User kann direkt "Hinzufuegen"
/// tippen, sieht aber die Defaults und kann sie korrigieren (kein Blocker).
@available(iOS 17.0, macOS 14.0, *)
struct NewCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Vorausgefuellter Name aus dem Picker-Textfeld.
    @State private var name: String
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var equipment: Equipment = .bodyweight
    @State private var isCompound: Bool = false

    /// Liefert den fertigen Draft, wenn der User "Hinzufuegen" tippt.
    let onCommit: (CustomExerciseDraft) -> Void

    init(initialName: String, onCommit: @escaping (CustomExerciseDraft) -> Void) {
        _name = State(initialValue: initialName)
        self.onCommit = onCommit
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "picker.exercise.namePlaceholder", bundle: .module),
                        text: $name
                    )
                    .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("customExercise.section.name", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)

                Section {
                    Picker(selection: $primaryMuscle) {
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            Text(muscle.localizedName).tag(muscle)
                        }
                    } label: {
                        Text("customExercise.field.muscle", bundle: .module)
                    }
                    .listRowBackground(Color.Deltiq.surface)

                    Picker(selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { equip in
                            Text(equip.localizedName).tag(equip)
                        }
                    } label: {
                        Text("customExercise.field.equipment", bundle: .module)
                    }
                    .listRowBackground(Color.Deltiq.surface)

                    Toggle(isOn: $isCompound) {
                        Text("customExercise.field.compound", bundle: .module)
                    }
                    .tint(Color.deltiqOrange)
                    .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("customExercise.section.metadata", bundle: .module)
                } footer: {
                    Text("customExercise.section.metadataFooter", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("customExercise.title", bundle: .module))
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
                    Button {
                        onCommit(CustomExerciseDraft(
                            name: trimmedName,
                            primaryMuscle: primaryMuscle,
                            equipment: equipment,
                            isCompound: isCompound
                        ))
                        dismiss()
                    } label: {
                        Text("customExercise.add", bundle: .module)
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
#endif
