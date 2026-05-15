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

    /// True wenn die Uebung zu einem Template-basierten Plan gehoert
    /// (`plan.isTemplate`). Struktur-Felder werden disabled — Trainings-
    /// Parameter (Suggested-Weight, Notiz, RIR) bleiben offen, damit der
    /// User seinen aktuellen Status anpassen kann ohne die Library zu
    /// zerschiessen. Custom-Plaene bleiben editierbar (DEL-013-Fix).
    private var isReadOnly: Bool {
        exercise.day?.plan?.isTemplate ?? false
    }

    /// DEL-066: Single-Source-of-Truth Section-Sichtbarkeit. Identische
    /// Auswertung in den Tests (`ExerciseEditorSectionsTests`) — so kann
    /// die Conditional-Logik nicht zwischen View und Test auseinanderdriften.
    private var sectionVisibility: ExerciseEditorSections.Visibility {
        ExerciseEditorSections.evaluate(
            isCardio: exercise.isCardio,
            isTimeBased: exercise.isTimeBased
        )
    }

    public var body: some View {
        Form {
            // DEL-062: Cardio + Zeit-basiert sind mutually-exclusive — der
            // onChange-Handler verhindert, dass beide gleichzeitig true
            // werden koennen (sonst wuesste die SetRow-View nicht, welchen
            // Branch sie nehmen soll).
            Section {
                TextField("Name", text: $exercise.name)
                    .disabled(isReadOnly)
                Toggle("Cardio", isOn: $exercise.isCardio)
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isCardio) { _, isOn in
                        if isOn { exercise.isTimeBased = false }
                    }
                Toggle("Zeit-basiert", isOn: $exercise.isTimeBased)
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isTimeBased) { _, isOn in
                        if isOn { exercise.isCardio = false }
                    }
            } header: {
                Text("Allgemein")
            } footer: {
                if isReadOnly {
                    Text("Template-Uebung — Name und Cardio/Zeit-Flags sind festgelegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Cardio = Run/Bike (Distanz + Dauer). Zeit-basiert = Plank/Wall-Sit (Hold-Timer). Nur eins gleichzeitig.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // DEL-062 + DEL-066: Section-Sichtbarkeit via zentraler Logik
            // aus `ExerciseEditorSections.evaluate`.
            if sectionVisibility.setsAndReps {
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

            if sectionVisibility.cardioTargets {
                cardioTargetSection
            }

            if sectionVisibility.pauseAndIntensity {
                Section("Pause & Intensität") {
                    Stepper(value: $exercise.restSeconds, in: 0...600, step: 15) {
                        LabeledContent("Pause", value: "\(exercise.restSeconds)s")
                    }
                    if sectionVisibility.targetRIR {
                        Stepper(value: $exercise.targetRir, in: 0...5, step: 0.5) {
                            LabeledContent("Ziel-RIR", value: rirString(exercise.targetRir))
                        }
                    }
                }
            }

            if sectionVisibility.suggestedWeight {
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
            }

            if sectionVisibility.smartProgression {
                progressionSection
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

    /// DEL-062: dedizierte Section fuer Cardio-Ziele. Distanz + Dauer sind
    /// optional — der User kann z.B. nur eine Ziel-Distanz setzen und die
    /// Dauer offen lassen ("how fast can I run 5k").
    private var cardioTargetSection: some View {
        Section("Ziel (optional)") {
            TextField("Distanz (km)",
                      value: Binding(
                        get: { exercise.targetDistanceKm },
                        set: { exercise.targetDistanceKm = $0 }
                      ),
                      format: .number,
                      prompt: Text("z.B. 5,0"))
                .decimalKeyboard()
            Stepper(value: Binding(
                get: { exercise.targetDurationMinutes ?? 0 },
                set: { exercise.targetDurationMinutes = $0 > 0 ? $0 : nil }
            ), in: 0...240, step: 5) {
                LabeledContent("Dauer (min)",
                               value: exercise.targetDurationMinutes.map { "\($0)" } ?? "—")
            }
        }
    }

    private func rirString(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }

    // MARK: - DEL-052/053 Smart-Progression

    @ViewBuilder
    private var progressionSection: some View {
        Section {
            Toggle("Smart Overload aktivieren", isOn: $exercise.smartProgressionEnabled)
            if exercise.smartProgressionEnabled {
                Toggle("Compound-Lift", isOn: $exercise.isCompound)
                Picker("Inkrement", selection: stepBinding) {
                    ForEach(ProgressionStep.allCases, id: \.self) { step in
                        Text(step.label).tag(step)
                    }
                }
            }
        } header: {
            Text("Smart-Progression")
        } footer: {
            if exercise.smartProgressionEnabled {
                Text(progressionFooterText)
                    .font(.footnote)
            } else {
                Text("Aus = das Gewicht wird nie automatisch geaendert. Du behaeltst die volle Kontrolle.")
                    .font(.footnote)
            }
        }
    }

    /// Footer-Wording erklaert die RIR-Schwelle. Wird je nach Compound-Toggle
    /// dynamisch angepasst, damit der User direkt sieht, wann die App
    /// progressed.
    private var progressionFooterText: String {
        if exercise.isCompound {
            return "Compound: Wenn alle Saetze die obere Rep-Grenze schaffst UND der letzte Satz RIR <= 3 hatte, steigt das Gewicht beim naechsten Mal automatisch um den eingestellten Inkrement."
        } else {
            return "Isolation: Wenn alle Saetze die obere Rep-Grenze schaffst UND der letzte Satz RIR <= 1 hatte (also nah am Versagen), steigt das Gewicht beim naechsten Mal um den eingestellten Inkrement."
        }
    }

    /// Picker bindet auf das `ProgressionStep`-enum, persistiert wird der
    /// Double-Wert. `ProgressionStep(closestTo:)` mappt aus dem rohen Wert
    /// auf das naechstgelegene Quick-Picker-Element.
    private var stepBinding: Binding<ProgressionStep> {
        Binding(
            get: { ProgressionStep(closestTo: exercise.progressionStep) },
            set: { exercise.progressionStep = $0.rawValue }
        )
    }
}
#endif
