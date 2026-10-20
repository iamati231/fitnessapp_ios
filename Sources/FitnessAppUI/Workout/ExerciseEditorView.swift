#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Sheet for editing a single Exercise's parameters. Bound directly to the @Model
/// instance — every field change persists via SwiftData's autosave.
///
/// Gruppe B (Sheet): beide Call-Sites (`DayEditorView`, `ActiveWorkoutView`)
/// praesentieren ausschliesslich per `.sheet(item:)` in einem frischen
/// `NavigationStack` — diese View haelt KEINEN eigenen `NavigationStack`
/// (kein NavigationLink im Body noetig).
///
/// UI-Refactor (DeltiqHeader-Muster): ersetzt das vormals native, Cancel-
/// lose "Fertig"-Toolbar durch DeltiqHeader (Checkmark oben rechts, Chevron
/// oben links). Autosave-Screen ohne eigenen Save-Schritt — der Chevron
/// braucht trotzdem Discard-Schutz: `ExerciseSnapshot` haelt den Zustand
/// beim Oeffnen fest und schreibt ihn bei "Aenderungen verwerfen" zurueck
/// (inkl. Custom-Template-Sync, siehe `syncCustomTemplate`) — sonst waere
/// "Verwerfen" bei Live-Autosave nur eine leere UI-Behauptung ohne Wirkung.
/// Der Loesch-Button/-Dialog (DEL-160) bleibt dabei komplett unveraendert
/// ganz unten in roter Warnfarbe.
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseEditorView: View {

    @Bindable public var exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// DEL-160: Confirm-Gate fuer das Loeschen einer Custom-Uebung.
    @State private var showingDeleteConfirm = false

    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): Zustand beim
    /// Oeffnen des Sheets — siehe `ExerciseSnapshot` weiter unten.
    @State private var snapshot: ExerciseSnapshot

    /// DEL-143: User-Toggle für RIR-Tooltips, gleicher AppStorage-Key
    /// wie SetRow. Default true.
    @AppStorage("showRirTooltips") private var showRirTooltips: Bool = true

    /// DEL-143: Tooltip-Controller für den Target-RIR-Slider in der
    /// Pause-RIR-Section. Wird beim Drag-Start gezeigt, Drag-Release
    /// + 1.8s → fade-out.
    @State private var rirTooltip = RIRTooltipController()

    public init(exercise: Exercise) {
        self.exercise = exercise
        _snapshot = State(initialValue: ExerciseSnapshot.capture(from: exercise))
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

    /// UI-Refactor (DeltiqHeader-Muster): Vergleich gegen `ExerciseSnapshot`
    /// vom Oeffnen des Sheets — `ExerciseSnapshot` ist `Equatable`.
    private var isDirty: Bool {
        snapshot != ExerciseSnapshot.capture(from: exercise)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // UI-Refactor (DeltiqHeader-Muster fuer Editoren): ersetzt das
            // vormals native "Fertig"-Toolbar. Autosave-Screen ohne eigenen
            // Speicher-Schritt — der Checkmark ist ein reines "Fertig",
            // deshalb ohne `isDisabled` (kein Validitaets-Gate auf diesem
            // Screen). Der Chevron fragt bei `isDirty` nach, statt sofort zu
            // schliessen (siehe `ExerciseSnapshot` fuer den Rueckroll-Pfad).
            DeltiqHeader(
                eyebrow: String(localized: "tab.plan", bundle: .module).uppercased(),
                title: exercise.name.isEmpty
                    ? String(localized: "active.addExercise", bundle: .module)
                    : exercise.displayName,
                onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                actions: [
                    DeltiqHeaderAction(
                        systemImage: "checkmark",
                        accessibilityLabel: String(localized: "common.done", bundle: .module)
                    ) {
                        dismiss()
                    }
                ]
            )
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
                    .listRowBackground(Color.Deltiq.surface)
                Toggle(isOn: $exercise.isCardio) {
                    Text("editor.exercise.toggle.cardio", bundle: .module)
                }
                    .tint(Color.deltiqOrange)
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isCardio) { _, isOn in
                        if isOn { exercise.isTimeBased = false }
                    }
                    .listRowBackground(Color.Deltiq.surface)
                Toggle(isOn: $exercise.isTimeBased) {
                    Text("editor.exercise.toggle.timeBased", bundle: .module)
                }
                    .tint(Color.deltiqOrange)
                    .disabled(isReadOnly)
                    .onChange(of: exercise.isTimeBased) { _, isOn in
                        if isOn { exercise.isCardio = false }
                    }
                    .listRowBackground(Color.Deltiq.surface)
            } header: {
                Text("editor.exercise.section.general", bundle: .module)
            } footer: {
                if isReadOnly {
                    Text("editor.exercise.templateLocked", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                } else {
                    Text("editor.exercise.general.footer", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            .listRowSeparatorTint(Color.Deltiq.divider)

            // DEL-159: Metadaten-Section fuer Custom-Uebungen (Zielmuskel +
            // Equipment + Compound). Nur fuer frei angelegte Uebungen (kein
            // Library-Match) und nicht-Cardio — Cardio nutzt cardioEquipment
            // (DEL-155) und hat keinen klassischen Hypertrophie-Muskel.
            if isCustomExercise, !exercise.isCardio {
                customMetadataSection
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
                    .listRowBackground(Color.Deltiq.surface)
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
                    .listRowBackground(Color.Deltiq.surface)
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
                    .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("editor.exercise.section.setsReps", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
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
                    .listRowBackground(Color.Deltiq.surface)
                    if sectionVisibility.targetRIR {
                        targetRIRSliderRow
                            .listRowBackground(Color.Deltiq.surface)
                    }
                } header: {
                    Text("editor.exercise.section.pauseRIR", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
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
                        .listRowBackground(Color.Deltiq.surface)
                } header: {
                    Text("editor.exercise.section.suggestedWeight", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
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
                    .listRowBackground(Color.Deltiq.surface)
            } header: {
                Text("editor.exercise.section.notes", bundle: .module)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)

            // DEL-160: Loeschen nur fuer Custom-Uebungen. System-Library-
            // Eintraege duerfen nicht entfernt werden.
            if isCustomExercise {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label {
                            Text("editor.exercise.delete", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
        }
        .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        .keyboardDismissToolbar()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Geraete-Nachtest (Deltiq-Abnahme E05) widerlegt die vorherige Annahme
        // hier: ExerciseEditorView wird von DayEditorView per
        // `.sheet(item:) { NavigationStack { ExerciseEditorView(...) } }`
        // geoeffnet, bekommt also eine EIGENE, frische NavigationStack mit nur
        // sich selbst als Root (anders als PlanEditorView/DayEditorView, die
        // per NavigationLink im GEMEINSAMEN Stack gepusht werden). Ein zuvor
        // ergaenztes `.deltiqSwipeBackEnabled(...)` war hier wirkungslos, weil
        // `SwipeBackHostController.gestureRecognizerShouldBegin` ohnehin immer
        // `false` liefert, sobald `viewControllers.count == 1` (nichts zum
        // Zurueckpoppen vorhanden) — zweifach auf dem Geraet bestaetigt, vor
        // UND nach jenem Versuch identisches Verhalten. Die fuer eine Sheet-
        // Praesentation korrekte Geste ist stattdessen das native Herunter-
        // Wischen zum Schliessen, bereits korrekt ueber
        // `.interactiveDismissDisabled(isDirty)` gesteuert (siehe unten) und
        // auf dem Geraet bestaetigt funktionsfaehig.
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            revertToSnapshot()
            dismiss()
        }
        // UI-Refactor (Korrektur, Punkt 4): interaktives Wegziehen des
        // Sheets ist sonst ein ungesicherter Verlassen-Weg am Discard-Dialog
        // vorbei. Ohne Aenderungen (`!isDirty`) bleibt es normal moeglich.
        .interactiveDismissDisabled(isDirty)
        // DEL-160: Confirm-Dialog vor dem dauerhaften Loeschen.
        .confirmationDialog(
            Text("editor.exercise.deleteConfirmTitle", bundle: .module),
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteCustomExercise()
            } label: {
                Text("editor.exercise.deleteConfirmCta", bundle: .module)
            }
            Button(role: .cancel) { } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("editor.exercise.deleteConfirmMessage", bundle: .module)
        }
    }

    /// DEL-160: Loescht die Custom-Uebung dauerhaft — die bearbeitete
    /// `Exercise`-Instanz UND alle passenden Custom-`ExerciseTemplate`s
    /// (Match ueber Name + isCustom). Historische `ExerciseLog`s ueberleben:
    /// `Exercise.logs` ist `.nullify`, die Logs behalten ihren Namens-Snapshot
    /// (DEL-051) und bleiben fuer PR/History auswertbar. Danach dismiss.
    private func deleteCustomExercise() {
        guard isCustomExercise else { return }
        let name = exercise.name

        // 1) Passende Custom-Templates aus der Bibliothek entfernen.
        let descriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == true && $0.name == name }
        )
        let templates = (try? modelContext.fetch(descriptor)) ?? []
        for template in templates {
            modelContext.delete(template)
        }

        // 2) Die bearbeitete Exercise-Instanz loeschen (Logs nullify-ueberleben).
        modelContext.delete(exercise)
        try? modelContext.save()

        dismiss()
    }

    /// UI-Refactor (DeltiqHeader-Muster): rollt alle Felder auf den Zustand
    /// beim Oeffnen zurueck — noetig, weil `exercise` live autosaved und
    /// "Verwerfen" sonst nur eine leere UI-Behauptung waere. Spiegelt eine
    /// evtl. verworfene Muskel-/Equipment-/Compound-Aenderung zusaetzlich
    /// auf das Custom-Template zurueck (dieselbe Sync-Funktion, die
    /// `customMetadataSection` beim Editieren nutzt, DEL-163) — sonst
    /// bliebe ein verworfener Wert dauerhaft in der Library-Vorlage stehen.
    private func revertToSnapshot() {
        snapshot.apply(to: exercise)
        syncCustomTemplate { template in
            template.primaryMuscle = snapshot.primaryMuscleRaw.flatMap(MuscleGroup.init(rawValue:)) ?? .chest
            template.equipment = snapshot.equipmentRaw.flatMap(Equipment.init(rawValue:)) ?? .bodyweight
            template.isSystemCompound = snapshot.isCompound
        }
    }

    /// DEL-159: True wenn die Uebung KEINEN Library-Eintrag matcht — also
    /// vom User frei angelegt wurde. Nur dann sind Muskel/Equipment/Compound
    /// sinnvoll editierbar (System-Uebungen beziehen diese aus der Library).
    private var isCustomExercise: Bool {
        !ExerciseLibraryData.all.contains { $0.name == exercise.name }
    }

    /// DEL-159: Metadaten-Editor fuer Custom-Uebungen. Schreibt die Override-
    /// Felder `primaryMuscle` / `equipment` / `isCompound` auf die Exercise.
    private var customMetadataSection: some View {
        Section {
            Picker(selection: Binding(
                get: { exercise.primaryMuscle ?? .chest },
                set: { newValue in
                    exercise.primaryMuscle = newValue
                    // DEL-163: Aenderung auf das zugrundeliegende Custom-
                    // Template zurueckspiegeln (AC2).
                    syncCustomTemplate { $0.primaryMuscle = newValue }
                }
            )) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    Text(muscle.localizedName).tag(muscle)
                }
            } label: {
                Text("customExercise.field.muscle", bundle: .module)
            }
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)

            Picker(selection: Binding(
                get: { exercise.equipment ?? .bodyweight },
                set: { newValue in
                    exercise.equipment = newValue
                    syncCustomTemplate { $0.equipment = newValue }
                }
            )) {
                ForEach(Equipment.allCases, id: \.self) { equip in
                    Text(equip.localizedName).tag(equip)
                }
            } label: {
                Text("customExercise.field.equipment", bundle: .module)
            }
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)

            Toggle(isOn: Binding(
                get: { exercise.isCompound },
                set: { newValue in
                    exercise.isCompound = newValue
                    syncCustomTemplate { $0.isSystemCompound = newValue }
                }
            )) {
                Text("customExercise.field.compound", bundle: .module)
            }
            .tint(Color.deltiqOrange)
            .disabled(isReadOnly)
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("customExercise.section.metadata", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// DEL-163: schreibt eine Metadaten-Aenderung auf das/die passende(n)
    /// Custom-`ExerciseTemplate`(s) zurueck (Match ueber Name + isCustom),
    /// damit Bibliothek + Picker mit der editierten Plan-Instanz konsistent
    /// bleiben (AC2). No-op fuer System-Uebungen.
    private func syncCustomTemplate(_ apply: (ExerciseTemplate) -> Void) {
        guard isCustomExercise else { return }
        let name = exercise.name
        let descriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == true && $0.name == name }
        )
        let templates = (try? modelContext.fetch(descriptor)) ?? []
        templates.forEach(apply)
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
                .listRowBackground(Color.Deltiq.surface)
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
            .listRowBackground(Color.Deltiq.surface)
            // DEL-155: Cardio-Equipment-Picker. `@Bindable` exercise →
            // direkter Binding auf die Computed-Property.
            CardioEquipmentPicker(selection: $exercise.cardioEquipment)
                .disabled(isReadOnly)
                .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("editor.exercise.section.cardioTarget", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
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
                Text(exercise.targetRir.formattedRIR)
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
            .tint(Color.deltiqOrange)
            .listRowBackground(Color.Deltiq.surface)
            if exercise.smartProgressionEnabled {
                Toggle(isOn: $exercise.isCompound) {
                    Text("editor.exercise.toggle.compoundLift", bundle: .module)
                }
                .tint(Color.deltiqOrange)
                .listRowBackground(Color.Deltiq.surface)
                Picker("Inkrement", selection: stepBinding) {
                    ForEach(ProgressionStep.allCases, id: \.self) { step in
                        Text(step.label).tag(step)
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
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
        .listRowSeparatorTint(Color.Deltiq.divider)
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

/// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): `Exercise` ist
/// `@Bindable` und autosaved direkt in SwiftData — es gibt keinen Draft wie
/// bei den anderen Editoren. Dieser Snapshot haelt alle in diesem Sheet
/// editierbaren Felder beim Oeffnen fest, damit `isDirty` (Chevron-Discard-
/// Schutz) erkennbar ist UND "Aenderungen verwerfen" die bereits autosaved
/// geschriebenen Live-Werte tatsaechlich zurueckrollen kann. `internal`
/// statt `private`, damit gezielte Tests (siehe `Tests/FitnessAppUITests`)
/// die Capture/Apply-Logik per `@testable import` direkt pruefen koennen.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseSnapshot: Equatable {
    var customName: String?
    var isCardio: Bool
    var isTimeBased: Bool
    var sets: Int
    var repsMin: Int
    var repsMax: Int
    var restSeconds: Int
    var targetRir: Float
    var suggestedWeight: Double?
    var targetDistanceKm: Double?
    var targetDurationMinutes: Int?
    var cardioEquipmentRaw: String?
    var notes: String?
    var primaryMuscleRaw: String?
    var equipmentRaw: String?
    var isCompound: Bool
    var smartProgressionEnabled: Bool
    var progressionStep: Double

    static func capture(from exercise: Exercise) -> ExerciseSnapshot {
        ExerciseSnapshot(
            customName: exercise.customName,
            isCardio: exercise.isCardio,
            isTimeBased: exercise.isTimeBased,
            sets: exercise.sets,
            repsMin: exercise.repsMin,
            repsMax: exercise.repsMax,
            restSeconds: exercise.restSeconds,
            targetRir: exercise.targetRir,
            suggestedWeight: exercise.suggestedWeight,
            targetDistanceKm: exercise.targetDistanceKm,
            targetDurationMinutes: exercise.targetDurationMinutes,
            cardioEquipmentRaw: exercise.cardioEquipmentRaw,
            notes: exercise.notes,
            primaryMuscleRaw: exercise.primaryMuscleRaw,
            equipmentRaw: exercise.equipmentRaw,
            isCompound: exercise.isCompound,
            smartProgressionEnabled: exercise.smartProgressionEnabled,
            progressionStep: exercise.progressionStep
        )
    }

    /// Schreibt alle Felder zurueck auf die Exercise-Instanz. Die gespiegelte
    /// Custom-Template-Synchronisierung (Muskel/Equipment/Compound) passiert
    /// separat in `ExerciseEditorView.revertToSnapshot()`.
    func apply(to exercise: Exercise) {
        exercise.customName = customName
        exercise.isCardio = isCardio
        exercise.isTimeBased = isTimeBased
        exercise.sets = sets
        exercise.repsMin = repsMin
        exercise.repsMax = repsMax
        exercise.restSeconds = restSeconds
        exercise.targetRir = targetRir
        exercise.suggestedWeight = suggestedWeight
        exercise.targetDistanceKm = targetDistanceKm
        exercise.targetDurationMinutes = targetDurationMinutes
        exercise.cardioEquipmentRaw = cardioEquipmentRaw
        exercise.notes = notes
        exercise.primaryMuscleRaw = primaryMuscleRaw
        exercise.equipmentRaw = equipmentRaw
        exercise.isCompound = isCompound
        exercise.smartProgressionEnabled = smartProgressionEnabled
        exercise.progressionStep = progressionStep
    }
}
#endif
