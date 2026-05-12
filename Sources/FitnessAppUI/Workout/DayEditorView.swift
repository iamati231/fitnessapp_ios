#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Edits a single `TrainingDay`: name, weekday, type, intensity, plus the ordered list
/// of exercises. Hosts the "Training starten" action — creates a `WorkoutSession` and
/// navigates straight into `ActiveWorkoutView`.
@available(iOS 17.0, macOS 14.0, *)
public struct DayEditorView: View {

    @Bindable public var day: TrainingDay
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    @State private var showingPicker = false
    @State private var exerciseToEdit: Exercise?

    public init(day: TrainingDay) {
        self.day = day
    }

    public var body: some View {
        Form {
            metaSection
            startSection
            exercisesSection
        }
        .navigationTitle(day.name.isEmpty ? "Tag" : day.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView(
                onSelect: { template in addExercise(from: template) },
                onCreateCustom: { name in addCustomExercise(named: name) }
            )
        }
        .sheet(item: $exerciseToEdit) { exercise in
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
    }

    // MARK: Sections

    /// True wenn der Tag aus einem Template-basierten Plan stammt
    /// (`plan.programType` non-empty). Editor-Felder werden dann disabled
    /// um die kuratierte Library-Struktur nicht versehentlich zu zerschiessen.
    private var isReadOnly: Bool {
        !(day.plan?.programType.isEmpty ?? true)
    }

    /// True wenn der Tag entweder explizit als `.rest` markiert ist oder
    /// einfach leer ist (Ruhetag im Custom-Plan). In dem Fall blenden wir
    /// "Training starten" aus und zeigen stattdessen "Ruhetag abschließen".
    private var isRestDay: Bool {
        day.type == .rest || day.exercises.isEmpty
    }

    private var metaSection: some View {
        Section {
            TextField("Name", text: $day.name)
                .disabled(isReadOnly)

            Picker("Wochentag", selection: $day.weekday) {
                ForEach(weekdayOptions, id: \.self) { weekday in
                    Text(weekdayName(weekday)).tag(weekday)
                }
            }
            .disabled(isReadOnly)

            Picker("Typ", selection: $day.type) {
                ForEach(DayType.allCases, id: \.self) { type in
                    Text(typeLabel(type)).tag(type)
                }
            }
            .disabled(isReadOnly)

            Picker("Nächste Intensität", selection: $day.nextIntensity) {
                Text("Leicht").tag(DayIntensity.light)
                Text("Normal").tag(DayIntensity.normal)
                Text("Schwer").tag(DayIntensity.heavy)
            }
        } header: {
            Text("Tag-Info")
        } footer: {
            if isReadOnly {
                Text("Dieser Tag gehört zu einem vorgefertigten Plan-Template und kann strukturell nicht bearbeitet werden. Du kannst aber die Trainings-Intensität anpassen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var startSection: some View {
        if isRestDay {
            Section {
                Button {
                    markRestDaySkipped()
                } label: {
                    HStack {
                        Spacer()
                        Label("Ruhetag abschließen", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
            } footer: {
                Text("Markiert den Ruhetag als erledigt — kein leerer Eintrag in der History, aber der Plan-Pointer rückt zum nächsten echten Training.")
                    .font(.footnote)
            }
        } else {
            Section {
                Button {
                    startSession()
                } label: {
                    HStack {
                        Spacer()
                        Label("Training starten", systemImage: "play.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(day.exercises.isEmpty)
            } footer: {
                if day.exercises.isEmpty {
                    Text("Füge erst mindestens eine Übung hinzu, dann kannst du das Training starten.")
                        .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        Section {
            if day.exercises.isEmpty {
                Text(isRestDay ? "Ruhetag — keine Übungen." : "Noch keine Übungen.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else if isReadOnly {
                // Template — Reorder/Delete deaktiviert. Einzelne Übung tappen
                // führt weiterhin in den ExerciseEditor (der seinerseits read-
                // only ist und nur die Trainings-Parameter sichtbar macht).
                ForEach(orderedExercises) { exercise in
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(orderedExercises) { exercise in
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: moveExercises)
                .onDelete(perform: deleteExercises)
            }
        } header: {
            HStack {
                Text("Übungen")
                Spacer()
                if !isReadOnly {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } footer: {
            if isReadOnly {
                Text("Template-Plan — Übungen sind festgelegt. Du kannst sie ansehen, aber nicht hinzufügen, entfernen oder umsortieren.")
                    .font(.footnote)
            } else if !day.exercises.isEmpty {
                Text("Tippe eine Übung an um sie zu bearbeiten. Halten + ziehen ändert die Reihenfolge.")
                    .font(.footnote)
            }
        }
    }

    // MARK: Derived

    private var orderedExercises: [Exercise] {
        day.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var weekdayOptions: [Int] {
        // 2..7,1 puts Monday first and Sunday last for European users.
        [2, 3, 4, 5, 6, 7, 1]
    }

    // MARK: Actions

    private func addExercise(from template: ExerciseTemplate) {
        let exercise = Exercise(
            name: template.name,
            orderIndex: day.exercises.count,
            isTimeBased: template.isTimeBased,
            day: day
        )
        modelContext.insert(exercise)
    }

    private func addCustomExercise(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Persist as a custom template too — the exercise reappears in the picker
        // next time so the user doesn't have to retype it.
        let template = ExerciseTemplate(
            name: trimmed,
            equipment: .barbell,
            primaryMuscle: .chest,
            isCustom: true
        )
        modelContext.insert(template)

        let exercise = Exercise(
            name: trimmed,
            orderIndex: day.exercises.count,
            day: day
        )
        modelContext.insert(exercise)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var arr = orderedExercises
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, exercise) in arr.enumerated() {
            exercise.orderIndex = i
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let arr = orderedExercises
        for index in offsets {
            modelContext.delete(arr[index])
        }
        // Re-index remaining exercises so orderIndex stays a contiguous 0..n-1.
        for (i, exercise) in orderedExercises.enumerated() {
            exercise.orderIndex = i
        }
    }

    private func startSession() {
        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: day.exercises.count,
            isCompleted: false,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
    }

    /// Schreibt eine isRestDay=true-Session in den Store. Der PlanNavigator zaehlt
    /// alle completed-Sessions, also rueckt der Pointer auf den naechsten echten
    /// Tag. Da isRestDay=true, taucht der Eintrag NICHT in History/Trophy-Room
    /// /Recent-Workouts auf. Nach dem Insert poppen wir ein Step im NavigationStack
    /// zurueck zum Plan-Editor, damit der User direkt sieht, dass der Tag erledigt
    /// ist.
    private func markRestDaySkipped() {
        let now = Date()
        let session = WorkoutSession(
            startTime: now,
            endTime: now,
            durationMinutes: 0,
            exerciseCount: 0,
            totalSets: 0,
            totalVolumeKg: 0,
            isCompleted: true,
            isRestDay: true,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
        // Aus dem DayEditor zurueck ins parent (PlanEditor) — der naechste echte
        // Trainings-Tag steht dann direkt im Dashboard-Plan-Day-Card.
        if !navigation.workoutPath.isEmpty {
            navigation.workoutPath.removeLast()
        }
    }

    // MARK: Labels

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    private func typeLabel(_ type: DayType) -> String {
        switch type {
        case .chest:     return "Brust"
        case .back:      return "Rücken"
        case .legs:      return "Beine"
        case .shoulders: return "Schultern"
        case .arms:      return "Arme"
        case .push:      return "Push"
        case .pull:      return "Pull"
        case .upper:     return "Oberkörper"
        case .lower:     return "Unterkörper"
        case .fullBody:  return "Ganzkörper"
        case .rest:      return "Ruhetag"
        case .custom:    return "Custom"
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text("\(exercise.orderIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isCardio {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
            if exercise.isTimeBased {
                Image(systemName: "stopwatch").foregroundStyle(.purple)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var detailLine: String {
        if exercise.isCardio {
            return "Cardio • \(exercise.restSeconds)s Pause"
        }
        let repsText = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        let unit = exercise.isTimeBased ? "Sek" : "Wdh"
        return "\(exercise.sets) Sätze • \(repsText) \(unit) • \(exercise.restSeconds)s Pause"
    }
}
#endif
