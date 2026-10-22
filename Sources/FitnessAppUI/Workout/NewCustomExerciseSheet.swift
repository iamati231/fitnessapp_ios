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
    /// UI-Refactor (DeltiqHeader-Muster, Task 7 docs/superpowers/sdd/2026-10-22-ui-consistency):
    /// siehe `ExerciseLibraryEditorSheet`/`BodyDataEditorView` fuer dasselbe Muster.
    @State private var showingDiscardConfirm = false

    /// Name beim Oeffnen (vorausgefuellt aus dem Picker-Suchtext) — Referenz
    /// fuer `isDirty`, damit ein unveraenderter Vorbelegungs-Name nicht faelschlich
    /// als "etwas zu verlieren" gilt.
    private let initialTrimmedName: String

    /// Liefert den fertigen Draft, wenn der User "Hinzufuegen" tippt.
    let onCommit: (CustomExerciseDraft) -> Void

    init(initialName: String, onCommit: @escaping (CustomExerciseDraft) -> Void) {
        _name = State(initialValue: initialName)
        self.initialTrimmedName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onCommit = onCommit
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// UI-Refactor (DeltiqHeader-Muster): Chevron fragt nur nach, wenn der
    /// User den Vorbelegungs-Namen oder einen der Metadaten-Defaults
    /// tatsaechlich geaendert hat (gleiches Prinzip wie
    /// `ExerciseLibraryEditorSheet.isDirty` im Create-Modus).
    private var isDirty: Bool {
        trimmedName != initialTrimmedName
            || primaryMuscle != .chest
            || equipment != .bodyweight
            || isCompound != false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UI-Refactor (DeltiqHeader-Muster fuer Editoren): ersetzt das
                // vormals native Cancel/Hinzufuegen-Toolbar. Das
                // `isDisabled: trimmedName.isEmpty`-Gate des bisherigen
                // "Hinzufuegen"-Buttons wandert unveraendert in die neue
                // `DeltiqHeaderAction`.
                DeltiqHeader(
                    eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                    title: String(localized: "customExercise.title", bundle: .module),
                    onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                    actions: [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            isDisabled: trimmedName.isEmpty,
                            accessibilityLabel: String(localized: "customExercise.add", bundle: .module)
                        ) {
                            onCommit(CustomExerciseDraft(
                                name: trimmedName,
                                primaryMuscle: primaryMuscle,
                                equipment: equipment,
                                isCompound: isCompound
                            ))
                            dismiss()
                        }
                    ]
                )
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
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            // UI-Refactor (gleiches Prinzip wie ExerciseLibraryEditorSheet):
            // interaktives Wegziehen des Sheets ist sonst ein ungesicherter
            // Verlassen-Weg am Discard-Dialog vorbei. Ohne Aenderungen
            // (`!isDirty`) bleibt es normal moeglich.
            .interactiveDismissDisabled(isDirty)
        }
    }
}
#endif
