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

    /// DEL-143: User-Toggle für RIR-Tooltips, gleicher AppStorage-Key
    /// wie SetRow. Default true.
    @AppStorage("showRirTooltips") private var showRirTooltips: Bool = true

    /// DEL-143: Tooltip-Controller für den Target-RIR-Slider in der
    /// Pause-RIR-Section. Wird beim Drag-Start gezeigt, Drag-Release
    /// + 1.8s → fade-out.
    @State private var rirTooltip = RIRTooltipController()

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
                // DEL-125: TextField bindet auf customName (User-Override),
                // Placeholder zeigt den lokalisierten System-Namen. Leeres
                // Feld + Placeholder = "User hat nicht umbenannt".
                TextField(
                    text: Binding(
                        get: { exercise.customName ?? "" },
                        set: { exercise.customName = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text(exercise.localizedSystemName)
                ) {
                    Text("editor.exercise.field.name", bundle: .module)
                }
                    .disabled(isReadOnly)
                Toggle(isOn: $exercise.isCardio) {
                    Text("editor.exercise.toggle.cardio", bundle: .module)
                }
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isCardio) { _, isOn in
                        if isOn { exercise.isTimeBased = false }
                    }
                Toggle(isOn: $exercise.isTimeBased) {
                    Text("editor.exercise.toggle.timeBased", bundle: .module)
                }
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isTimeBased) { _, isOn in
                        if isOn { exercise.isCardio = false }
                    }
            } header: {
                Text("editor.exercise.section.general", bundle: .module)
            } footer: {
                if isReadOnly {
                    Text("editor.exercise.templateLocked", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("editor.exercise.general.footer", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // DEL-062 + DEL-066: Section-Sichtbarkeit via zentraler Logik
            // aus `ExerciseEditorSections.evaluate`.
            if sectionVisibility.setsAndReps {
                Section {
                    Stepper(value: $exercise.sets, in: 1...20) {
                        LabeledContent {
                            Text("\(exercise.sets)")
                        } label: {
                            Text("editor.exercise.sets", bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    Stepper(value: $exercise.repsMin, in: 1...100) {
                        LabeledContent {
                            Text("\(exercise.repsMin)")
                        } label: {
                            Text(exercise.isTimeBased
                                 ? "editor.exercise.field.secondsMin"
                                 : "editor.exercise.field.repsMin",
                                 bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    Stepper(value: $exercise.repsMax, in: max(exercise.repsMin, 1)...200) {
                        LabeledContent {
                            Text("\(exercise.repsMax)")
                        } label: {
                            Text(exercise.isTimeBased
                                 ? "editor.exercise.field.secondsMax"
                                 : "editor.exercise.field.repsMax",
                                 bundle: .module)
                        }
                    }
                    .disabled(isReadOnly)
                    .onChange(of: exercise.repsMin) { _, newMin in
                        if exercise.repsMax < newMin { exercise.repsMax = newMin }
                    }
                } header: {
                    Text("editor.exercise.section.setsReps", bundle: .module)
                }
            }

            if sectionVisibility.cardioTargets {
                cardioTargetSection
            }

            if sectionVisibility.pauseAndIntensity {
                Section {
                    Stepper(value: $exercise.restSeconds, in: 0...600, step: 15) {
                        LabeledContent {
                            Text("\(exercise.restSeconds)s")
                        } label: {
                            Text("editor.exercise.rest", bundle: .module)
                        }
                    }
                    if sectionVisibility.targetRIR {
                        targetRIRSliderRow
                    }
                } header: {
                    Text("editor.exercise.section.pauseRIR", bundle: .module)
                }
            }

            if sectionVisibility.suggestedWeight {
                Section {
                    TextField("kg",
                              value: Binding(
                                get: { exercise.suggestedWeight },
                                set: { exercise.suggestedWeight = $0 }
                              ),
                              format: .number,
                              prompt: Text("editor.exercise.field.weightExample", bundle: .module))
                        .decimalKeyboard()
                } header: {
                    Text("editor.exercise.section.suggestedWeight", bundle: .module)
                }
            }

            if sectionVisibility.smartProgression {
                progressionSection
            }

            Section {
                TextField(String(localized: "editor.exercise.field.notePlaceholder", bundle: .module),
                          text: Binding(
                            get: { exercise.notes ?? "" },
                            set: { exercise.notes = $0.isEmpty ? nil : $0 }
                          ),
                          axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("editor.exercise.section.notes", bundle: .module)
            }
        }
        // DEL-124: navigationTitle via displayName, damit Library-Uebungen
        // im EN/TR-Mode auch hier korrekt rendern.
        .navigationTitle(exercise.name.isEmpty
                         ? String(localized: "active.addExercise", bundle: .module)
                         : exercise.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: {
                    Text("common.done", bundle: .module)
                }
            }
        }
    }

    /// DEL-062: dedizierte Section fuer Cardio-Ziele. Distanz + Dauer sind
    /// optional — der User kann z.B. nur eine Ziel-Distanz setzen und die
    /// Dauer offen lassen ("how fast can I run 5k").
    private var cardioTargetSection: some View {
        Section {
            TextField(String(localized: "editor.exercise.distanceKm", bundle: .module),
                      value: Binding(
                        get: { exercise.targetDistanceKm },
                        set: { exercise.targetDistanceKm = $0 }
                      ),
                      format: .number,
                      prompt: Text("editor.exercise.field.distanceExample", bundle: .module))
                .decimalKeyboard()
            Stepper(value: Binding(
                get: { exercise.targetDurationMinutes ?? 0 },
                set: { exercise.targetDurationMinutes = $0 > 0 ? $0 : nil }
            ), in: 0...240, step: 5) {
                LabeledContent {
                    Text(exercise.targetDurationMinutes.map { "\($0)" } ?? "—")
                } label: {
                    Text("editor.exercise.field.durationMin", bundle: .module)
                }
            }
        } header: {
            Text("editor.exercise.section.cardioTarget", bundle: .module)
        }
    }

    private func rirString(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }

    // MARK: - DEL-143 Target-RIR-Slider mit Tooltip-Bloop

    /// Slider-basierter Target-RIR-Picker. Ersetzt den frueheren
    /// Stepper, damit das Tooltip-Bloop-Pattern (onDragStart/End)
    /// dasselbe ist wie auf der Active-Workout-SetRow.
    ///
    /// Layout: Label + aktueller Wert oben, Slider darunter — der
    /// Tooltip-Overlay wird oben rechts/center über dem Slider
    /// platziert (offset y: -38) und ist non-hit-testing, damit der
    /// Slider darunter normal interagierbar bleibt.
    @ViewBuilder
    private var targetRIRSliderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("editor.exercise.field.targetRIR", bundle: .module)
                Spacer()
                Text(rirString(exercise.targetRir))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            Slider(
                value: $exercise.targetRir,
                in: 0...5,
                step: 0.5,
                onEditingChanged: { editing in
                    guard showRirTooltips else { return }
                    rirTooltip.setVisible(editing)
                }
            )
            .tint(Color.deltiqOrange)
            .disabled(isReadOnly)
            .overlay(alignment: .top) {
                RIRTooltipBloop(rir: exercise.targetRir,
                                isVisible: rirTooltip.isVisible)
                    .offset(y: -38)
            }
        }
    }

    // MARK: - DEL-052/053 Smart-Progression

    @ViewBuilder
    private var progressionSection: some View {
        Section {
            Toggle(isOn: $exercise.smartProgressionEnabled) {
                Text("editor.exercise.toggle.smartOverload", bundle: .module)
            }
            if exercise.smartProgressionEnabled {
                Toggle(isOn: $exercise.isCompound) {
                    Text("editor.exercise.toggle.compoundLift", bundle: .module)
                }
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
                Text("editor.exercise.smartOff", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    /// Footer-Wording erklaert die RIR-Schwelle. Wird je nach Compound-Toggle
    /// dynamisch angepasst, damit der User direkt sieht, wann die App
    /// progressed.
    private var progressionFooterText: String {
        // DEL-151: lokalisiert via String-Catalog — vorher hartcodierte
        // deutsche Literale, die auf TR/EN-iPhones deutsch stehen blieben.
        if exercise.isCompound {
            return String(localized: "editor.exercise.smartProgressionFooterCompound", bundle: .module)
        } else {
            return String(localized: "editor.exercise.smartProgressionFooterIsolation", bundle: .module)
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
