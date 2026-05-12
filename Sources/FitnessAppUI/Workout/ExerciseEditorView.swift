#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Sheet for editing a single Exercise's parameters. Bound directly to the @Model
/// instance — every field change persists via SwiftData's autosave.
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseEditorView: View {

    @Bindable public var exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    /// True wenn die Uebung zu einem Template-basierten Plan gehoert. Struktur-
    /// Felder werden disabled — Trainings-Parameter (Suggested-Weight, Notiz,
    /// RIR) bleiben offen, damit der User seinen aktuellen Status anpassen
    /// kann ohne die Template-Library zu zerschiessen.
    private var isReadOnly: Bool {
        !(exercise.day?.plan?.programType.isEmpty ?? true)
    }

    public var body: some View {
        Form {
            Section {
                TextField("Name", text: $exercise.name)
                    .disabled(isReadOnly)
                Toggle("Cardio", isOn: $exercise.isCardio)
                    .disabled(isReadOnly)
                Toggle("Zeit-basiert (Plank, Wall Sit)", isOn: $exercise.isTimeBased)
                    .disabled(isReadOnly)
            } header: {
                Text("Allgemein")
            } footer: {
                if isReadOnly {
                    Text("Template-Uebung — Name und Cardio/Zeit-Flags sind festgelegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !exercise.isCardio {
                Section("Sätze & Wiederholungen") {
                    Stepper(value: $exercise.sets, in: 1...20) {
                        LabeledContent("Sätze", value: "\(exercise.sets)")
                    }
                    .disabled(isReadOnly)
                    Stepper(value: $exercise.repsMin, in: 1...100) {
                        LabeledContent(exercise.isTimeBased ? "Sek. min" : "Wdh. min",
                                       value: "\(exercise.repsMin)")
                    }
                    .disabled(isReadOnly)
                    Stepper(value: $exercise.repsMax, in: max(exercise.repsMin, 1)...200) {
                        LabeledContent(exercise.isTimeBased ? "Sek. max" : "Wdh. max",
                                       value: "\(exercise.repsMax)")
                    }
                    .disabled(isReadOnly)
                    .onChange(of: exercise.repsMin) { _, newMin in
                        if exercise.repsMax < newMin { exercise.repsMax = newMin }
                    }
                }
            }

            // Pause + Ziel-RIR bleiben editierbar — Trainings-Parameter, die
            // sich legitim individuell anpassen lassen.
            Section("Pause & Intensität") {
                Stepper(value: $exercise.restSeconds, in: 0...600, step: 15) {
                    LabeledContent("Pause", value: "\(exercise.restSeconds)s")
                }
                Stepper(value: $exercise.targetRir, in: 0...5, step: 0.5) {
                    LabeledContent("Ziel-RIR", value: rirString(exercise.targetRir))
                }
            }

            // Suggested-Weight + Notizen bleiben offen — User-eigene Trainings-
            // Daten, gehoeren nicht zur Template-Struktur.
            Section("Vorgeschlagenes Gewicht (optional)") {
                TextField("kg",
                          value: Binding(
                            get: { exercise.suggestedWeight },
                            set: { exercise.suggestedWeight = $0 }
                          ),
                          format: .number,
                          prompt: Text("z.B. 60"))
                    .decimalKeyboard()
            }

            Section("Notizen") {
                TextField("Notiz (optional)",
                          text: Binding(
                            get: { exercise.notes ?? "" },
                            set: { exercise.notes = $0.isEmpty ? nil : $0 }
                          ),
                          axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(exercise.name.isEmpty ? "Übung" : exercise.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private func rirString(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }
}
#endif
