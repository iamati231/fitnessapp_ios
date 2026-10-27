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
    /// UI-Refactor (DeltiqHeader-Muster): siehe `BodyDataEditorView`.
    @State private var showingDiscardConfirm = false
    /// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): Doppeltap-
    /// Schutz fuer `save()` (Create legt sonst zwei Templates an).
    @State private var isSaving = false
    /// Task 5: sichtbare Fehlermeldung statt des bisher verschluckten
    /// `try? modelContext.save()`-Fehlers.
    @State private var saveErrorMessage: String?

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
            VStack(spacing: 0) {
                // UI-Refactor (DeltiqHeader-Muster fuer Editoren): ersetzt
                // natives Cancel/Done-Toolbar. Im Read-Only-Modus (System-
                // Template) gibt es nichts zu speichern/verwerfen — Chevron
                // schliesst dann immer sofort, kein Checkmark im Header.
                DeltiqHeader(
                    eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                    title: titleText,
                    onBack: {
                        if !isReadOnly && isDirty {
                            showingDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    },
                    actions: isReadOnly ? [] : [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            isDisabled: trimmedName.isEmpty || isSaving,
                            accessibilityLabel: String(localized: isCreate ? "customExercise.add" : "common.done", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                Form {
                    if isReadOnly {
                        readOnlyContent
                    } else {
                        editableContent
                    }
                    if let saveErrorMessage {
                        Section {
                            Text(saveErrorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.Deltiq.error)
                                .listRowBackground(Color.Deltiq.surface)
                        }
                    }
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
            // UI-Refactor (Korrektur, Punkt 4): interaktives Wegziehen des
            // Sheets ist sonst ein ungesicherter Verlassen-Weg am Discard-
            // Dialog vorbei. Read-Only (System-Template) hat nichts zu
            // verlieren — dort bleibt Wegziehen frei moeglich.
            .interactiveDismissDisabled(isReadOnly ? false : isDirty)
        }
    }

    /// UI-Refactor (DeltiqHeader-Muster): Create-Modus vergleicht gegen die
    /// Init-Defaults (keine `existing`-Vorlage vorhanden), Edit-Modus gegen
    /// die geladene Custom-Vorlage. Read-Only erreicht diese Property nie
    /// (siehe `onBack` oben).
    private var isDirty: Bool {
        guard let existing, !isCreate else {
            return !name.isEmpty || muscle != .chest || equipment != .bodyweight || isCompound != false
        }
        return name != existing.name
            || muscle != existing.primaryMuscle
            || equipment != existing.equipment
            || isCompound != existing.isSystemCompound
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
        guard !isSaving, !trimmedName.isEmpty else { return }
        isSaving = true

        var insertedTemplate: ExerciseTemplate?
        // Rollback-Fix (ponytail-audit, gleiches Muster wie CardioGoalEditorView.save(),
        // Commit 8bdb416): Schnappschuss VOR der Mutation - ohne das blieben die vier
        // Felder nach einem fehlgeschlagenen Save auf `existing` stehen, obwohl der
        // Nutzer "Speichern fehlgeschlagen" sah.
        let originalName: String?
        let originalMuscle: MuscleGroup?
        let originalEquipment: Equipment?
        let originalIsCompound: Bool?
        if let existing {
            originalName = existing.name
            originalMuscle = existing.primaryMuscle
            originalEquipment = existing.equipment
            originalIsCompound = existing.isSystemCompound
            // Edit: Felder zurueckschreiben (nur Custom erreicht diesen Pfad).
            existing.name = trimmedName
            existing.primaryMuscle = muscle
            existing.equipment = equipment
            existing.isSystemCompound = isCompound
        } else {
            originalName = nil
            originalMuscle = nil
            originalEquipment = nil
            originalIsCompound = nil
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
            insertedTemplate = template
        }
        // Task 5: `try?` verschluckte den Fehler bisher komplett — ein
        // fehlgeschlagener Save sah fuer den Nutzer wie Erfolg aus
        // (`dismiss()` lief unconditional).
        do {
            try modelContext.save()
        } catch {
            if let insertedTemplate {
                modelContext.delete(insertedTemplate)
            }
            if let existing, let originalName, let originalMuscle, let originalEquipment, let originalIsCompound {
                existing.name = originalName
                existing.primaryMuscle = originalMuscle
                existing.equipment = originalEquipment
                existing.isSystemCompound = originalIsCompound
            }
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            isSaving = false
            return
        }
        dismiss()
    }
}
#endif
