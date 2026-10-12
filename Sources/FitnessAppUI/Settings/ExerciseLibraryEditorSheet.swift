#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-161: Metadaten-Editor fuer die Uebungsbibliothek. Drei Modi, abgeleitet
/// aus dem uebergebenen Template:
///   * `template == nil`        → **Create**: legt ein neues Custom-Template an.
///   * `template.isCustom`      → **Edit**: editiert Name/Muskel/Equipment/
///                                 Compound des bestehenden Custom-Templates.
///   * `template` System-Eintrag → **Read-Only**: zeigt die Basis-Metadaten,
///                                 nicht editierbar (App-Templates geschuetzt).
///
/// Bewusst KEINE Sets/Reps/Pausen-Felder — die gehoeren in den Plan-/Workout-
/// Kontext (`ExerciseEditorView`), nicht in die Bibliothek (siehe Ticket).
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseLibraryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Bestehendes Template (Edit/Read-Only) oder nil (Create).
    private let existing: ExerciseTemplate?

    @State private var name: String
    @State private var muscle: MuscleGroup
    @State private var equipment: Equipment
    @State private var isCompound: Bool

    init(template: ExerciseTemplate?) {
        self.existing = template
        _name = State(initialValue: template?.name ?? "")
        _muscle = State(initialValue: template?.primaryMuscle ?? .chest)
        _equipment = State(initialValue: template?.equipment ?? .bodyweight)
        _isCompound = State(initialValue: template?.isSystemCompound ?? false)
    }

    /// Read-Only fuer System-Templates (vorhanden + nicht custom).
    private var isReadOnly: Bool {
        guard let existing else { return false }
        return !existing.isCustom
    }

    private var isCreate: Bool { existing == nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Im Read-Only-Mode den lokalisierten Display-Namen zeigen (System-
    /// Templates tragen den DE-Base in `name`); sonst den editierbaren Namen.
    private var titleText: String {
        if isCreate {
            return String(localized: "customExercise.title", bundle: .module)
        }
        return existing?.displayName ?? trimmedName
    }

    var body: some View {
        NavigationStack {
            Form {
                if isReadOnly {
                    readOnlyContent
                } else {
                    editableContent
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(titleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text(isReadOnly ? "common.done" : "common.cancel", bundle: .module)
                    }
                }
                if !isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { save() } label: {
                            Text(isCreate ? "customExercise.add" : "common.done", bundle: .module)
                        }
                        .disabled(trimmedName.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: Editable (create + custom edit)

    @ViewBuilder
    private var editableContent: some View {
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
            Picker(selection: $muscle) {
                ForEach(MuscleGroup.allCases, id: \.self) { m in
                    Text(m.localizedName).tag(m)
                }
            } label: {
                Text("customExercise.field.muscle", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            Picker(selection: $equipment) {
                ForEach(Equipment.allCases, id: \.self) { e in
                    Text(e.localizedName).tag(e)
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

    // MARK: Read-only (system templates)

    @ViewBuilder
    private var readOnlyContent: some View {
        Section {
            HStack {
                Spacer()
                ExerciseGifView(exerciseName: existing?.name ?? trimmedName, displayName: titleText)
                    .frame(width: 140, height: 140)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        Section {
            LabeledContent {
                Text(muscle.localizedName)
            } label: {
                Text("customExercise.field.muscle", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            LabeledContent {
                Text(equipment.localizedName)
            } label: {
                Text("customExercise.field.equipment", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            LabeledContent {
                Text(isCompound ? "common.yes" : "common.no", bundle: .module)
            } label: {
                Text("customExercise.field.compound", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("customExercise.section.metadata", bundle: .module)
        } footer: {
            Text("library.readOnlyFooter", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: Save

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let existing {
            // Edit: Felder zurueckschreiben (nur Custom erreicht diesen Pfad).
            existing.name = trimmedName
            existing.primaryMuscle = muscle
            existing.equipment = equipment
            existing.isSystemCompound = isCompound
        } else {
            // Create: neues Custom-Template anlegen.
            let template = ExerciseTemplate(
                name: trimmedName,
                equipment: equipment,
                primaryMuscle: muscle,
                isCustom: true,
                isSystemCompound: isCompound,
                isSystemProvided: false
            )
            modelContext.insert(template)
        }
        try? modelContext.save()
        dismiss()
    }
}
#endif
