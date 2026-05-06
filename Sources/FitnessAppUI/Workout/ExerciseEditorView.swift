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

    public var body: some View {
        Form {
            Section("Allgemein") {
                TextField("Name", text: $exercise.name)
                Toggle("Cardio", isOn: $exercise.isCardio)
                Toggle("Zeit-basiert (Plank, Wall Sit)", isOn: $exercise.isTimeBased)
            }

            if !exercise.isCardio {
                Section("Saetze & Wiederholungen") {
                    Stepper(value: $exercise.sets, in: 1...20) {
                        LabeledContent("Saetze", value: "\(exercise.sets)")
                    }
                    Stepper(value: $exercise.repsMin, in: 1...100) {
                        LabeledContent(exercise.isTimeBased ? "Sek. min" : "Wdh. min",
                                       value: "\(exercise.repsMin)")
                    }
                    Stepper(value: $exercise.repsMax, in: max(exercise.repsMin, 1)...200) {
                        LabeledContent(exercise.isTimeBased ? "Sek. max" : "Wdh. max",
                                       value: "\(exercise.repsMax)")
                    }
                    .onChange(of: exercise.repsMin) { _, newMin in
                        if exercise.repsMax < newMin { exercise.repsMax = newMin }
                    }
                }
            }

            Section("Pause & Intensitaet") {
                Stepper(value: $exercise.restSeconds, in: 0...600, step: 15) {
                    LabeledContent("Pause", value: "\(exercise.restSeconds)s")
                }
                Stepper(value: $exercise.targetRir, in: 0...5, step: 0.5) {
                    LabeledContent("Ziel-RIR", value: rirString(exercise.targetRir))
                }
            }

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
        .navigationTitle(exercise.name.isEmpty ? "Uebung" : exercise.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
