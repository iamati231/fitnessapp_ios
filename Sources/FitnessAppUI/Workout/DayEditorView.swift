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

    // DEL-048: Bottom-Up Konflikt-Detection. Wenn der User eine Uebung aus
    // dem Picker waehlt, deren Equipment im aktuellen Plan-Env nicht
    // funktioniert (z.B. Beinpresse in einem Bodyweight-Plan), halten wir
    // sie hier zwischen und zeigen einen Confirmation-Dialog.
    @State private var pendingEquipmentConflict: PendingEquipmentConflict?
    @State private var swapResultToast: String?

    private struct PendingEquipmentConflict: Equatable {
        let template: ExerciseTemplate
        let requiredEnv: EnvironmentType   // minimal-fitting env (.gym oder .homeGym)
        let planEnv: EnvironmentType
    }

    /// DEL-042: laeuft eine WorkoutSession noch im Hintergrund (z.B. wegen
    /// App-Crash oder vergessenes Speichern)? Wenn ja, blockiert ein Confirm-
    /// Dialog den Direktstart und gibt dem User drei Optionen.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == false && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var openSessions: [WorkoutSession]

    @State private var showingOpenSessionDialog = false

    public init(day: TrainingDay) {
        self.day = day
    }

    public var body: some View {
        Group {
            if isRestDay {
                // Ruhetag bekommt eine drastisch reduzierte Layout-Variante
                // (DEL-015) — keine Picker, keine Übungen-Section, nur Hero-
                // Icon + Skip-Button. Vermeidet die irritierenden "0 Übungen"-
                // und "Intensität: Keine"-Eintraege.
                restDayLayout
            } else {
                Form {
                    metaSection
                    startSection
                    exercisesSection
                }
            }
        }
        .navigationTitle(day.name.isEmpty ? "Tag" : day.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView(
                planEnvironment: day.plan?.targetEnvironment,
                onSelect: { template in handleExerciseSelection(template) },
                onCreateCustom: { name in addCustomExercise(named: name) }
            )
        }
        // DEL-048: Equipment-Konflikt-Confirmation. Wenn der User mit Filter
        // OFF eine inkompatible Uebung gewaehlt hat, fragen wir hier nach.
        .confirmationDialog(
            "Equipment-Konflikt",
            isPresented: Binding(
                get: { pendingEquipmentConflict != nil },
                set: { if !$0 { pendingEquipmentConflict = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEquipmentConflict
        ) { conflict in
            // Option A: Plan-Env auf Gym/Home umstellen UND Uebung adden.
            Button("Plan auf \(environmentLabel(conflict.requiredEnv)) umstellen") {
                switchPlanEnvAndAdd(conflict: conflict)
                pendingEquipmentConflict = nil
            }
            // Option B: Trotzdem adden, Plan-Env unveraendert lassen. Die
            // Uebung wird vermutlich beim ersten Workout-Start als "kein
            // Equipment vorhanden" stossen, aber der User hat die freie Wahl.
            Button("Nur Übung hinzufügen") {
                addExercise(from: conflict.template)
                pendingEquipmentConflict = nil
            }
            Button("Abbrechen", role: .cancel) {
                pendingEquipmentConflict = nil
            }
        } message: { conflict in
            Text("„\(conflict.template.name)\" erfordert Equipment, das in \(environmentLabel(conflict.planEnv))-Plänen normalerweise nicht verfügbar ist. Möchtest du den Plan-Typ entsprechend anpassen?")
        }
        .overlay(alignment: .bottom) {
            if let msg = swapResultToast {
                Label(msg, systemImage: "arrow.triangle.2.circlepath")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $exerciseToEdit) { exercise in
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
        // DEL-042: Open-Session-Recovery-Dialog. Triggered von startSession()
        // wenn eine ungespeicherte Session existiert. Drei Optionen plus Cancel.
        .confirmationDialog(
            "Laufendes Training",
            isPresented: $showingOpenSessionDialog,
            titleVisibility: .visible
        ) {
            Button("Fortsetzen") {
                resumeOpenSession()
            }
            Button("Speichern & neu starten") {
                completeOpenSessionAndStartNew()
            }
            Button("Verwerfen & neu starten", role: .destructive) {
                discardOpenSessionAndStartNew()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            if let open = openSessions.first {
                Text("Es gibt bereits ein angefangenes Training (\(open.dayName ?? "Unbekannt"), gestartet \(open.startTime.formatted(.relative(presentation: .named)))). Was möchtest du tun?")
            } else {
                Text("Es gibt bereits ein angefangenes Training.")
            }
        }
    }

    /// Hero-Card-Layout fuer Ruhetage: grosses Sofa-Icon, klare Botschaft,
    /// prominenter "Abschliessen"-Button. Versteckt alle Editor-Metadaten,
    /// die fuer einen "Tag-ohne-Training" sinnlos sind.
    @ViewBuilder
    private var restDayLayout: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 96))
                .foregroundStyle(.white)
                .frame(width: 140, height: 140)
                .background(Color.purple.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 8) {
                Text(day.name.isEmpty ? "Ruhetag" : day.name)
                    .font(.title.weight(.bold))
                Text("Regeneration ist Teil des Plans. Hak den Tag ab, wenn du durch bist — dein Plan-Pointer springt automatisch zum naechsten echten Training.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                markRestDaySkipped()
            } label: {
                HStack {
                    Spacer()
                    Label("Ruhetag abschließen", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.purple.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: Sections

    /// True wenn der Tag aus einem Template-basierten Plan stammt
    /// (`plan.isTemplate`). Editor-Felder werden dann disabled um die
    /// kuratierte Library-Struktur nicht versehentlich zu zerschiessen.
    /// Custom-Plaene bleiben editierbar (DEL-013-Fix).
    private var isReadOnly: Bool {
        day.plan?.isTemplate ?? false
    }

    /// True nur wenn der Tag explizit als `.rest` markiert ist. Frueher
    /// haben wir `exercises.isEmpty` als Fallback genommen, was leere Tage
    /// faelschlich als Ruhetag detektierte — User konnte gar keinen
    /// Trainingstag mehr anlegen. Jetzt strikt nach Typ (DEL-021/023).
    private var isRestDay: Bool {
        day.type == .rest
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

    /// DEL-048: Entry-Point fuer eine Picker-Auswahl. Checked, ob das
    /// Template-Equipment zum aktuellen Plan-Env passt. Bei Konflikt wird
    /// statt sofortigem Insert der Confirmation-Dialog aufgemacht.
    /// Custom-Templates werden NIE als Konflikt gewertet — der User hat sie
    /// bewusst angelegt.
    private func handleExerciseSelection(_ template: ExerciseTemplate) {
        guard let planEnv = day.plan?.targetEnvironment,
              !template.isCustom,
              !ExerciseLibraryData.isEquipment(template.equipment, compatibleWith: planEnv)
        else {
            addExercise(from: template)
            return
        }
        // Konflikt: schlage das minimal-passende Env vor (homeGym fuer KH/KB/
        // Band, Gym fuer Maschinen/Kabel/LH).
        let required = minimumEnvironment(for: template.equipment)
        pendingEquipmentConflict = PendingEquipmentConflict(
            template: template,
            requiredEnv: required,
            planEnv: planEnv
        )
    }

    /// DEL-048: Mappt Equipment auf das niedrigst-passende Env, das der User
    /// braucht, um die Uebung sinnvoll auszufuehren. Dumbbells/Kettlebells/
    /// Bands gehen schon in HomeGym; Barbell/Machine/Cable brauchen Gym.
    private func minimumEnvironment(for equipment: Equipment) -> EnvironmentType {
        switch equipment {
        case .bodyweight:                                return .noEquipment
        case .dumbbell, .kettlebell, .band:              return .homeGym
        case .barbell, .machine, .cable:                 return .gym
        }
    }

    /// DEL-048: User waehlt "Plan umstellen". Wir setzen das neue Env auf
    /// dem Plan UND lassen den `PlanEnvironmentMigrator` ueber die bereits
    /// vorhandenen Uebungen drueberlaufen (damit z.B. eine KH-Variante nicht
    /// neben einer auf einmal hinfaelligen BW-Variante stehen bleibt). Dann
    /// adden wir die ausloesende Uebung als ganz normale neue Exercise.
    private func switchPlanEnvAndAdd(conflict: PendingEquipmentConflict) {
        guard let plan = day.plan else {
            addExercise(from: conflict.template)
            return
        }
        plan.targetEnvironment = conflict.requiredEnv
        let r = PlanEnvironmentMigrator.migrate(
            plan: plan,
            toEnvironment: conflict.requiredEnv,
            modelContext: modelContext
        )
        // Eigentliche neue Uebung adden (NACH dem Migrator, sonst wird sie
        // selber gleich umsortiert/ersetzt).
        addExercise(from: conflict.template)

        // Toast
        var parts: [String] = []
        parts.append("Plan auf \(environmentLabel(conflict.requiredEnv))")
        if r.swapped > 0 { parts.append("\(r.swapped) ersetzt") }
        let message = parts.joined(separator: " · ")
        withAnimation(.easeOut(duration: 0.2)) {
            swapResultToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                swapResultToast = nil
            }
        }
    }

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "Bodyweight"
        }
    }

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

    /// Triggered vom "Training starten"-Button. Wenn eine ungespeicherte
    /// Session existiert (DEL-042), oeffnet sich der Recovery-Dialog —
    /// erst nach User-Entscheidung wird tatsaechlich neu gestartet.
    private func startSession() {
        if !openSessions.isEmpty {
            showingOpenSessionDialog = true
        } else {
            actuallyStartNewSession()
        }
    }

    /// Erstellt + navigiert in eine neue Session. Wird sowohl direkt
    /// (kein Konflikt) als auch nach Recovery-Entscheidung aufgerufen.
    private func actuallyStartNewSession() {
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

    /// DEL-042 "Fortsetzen": navigiere in die existing offene Session ohne
    /// eine neue zu erstellen.
    private func resumeOpenSession() {
        guard let open = openSessions.first else { return }
        navigation.workoutPath.append(ActiveSessionRoute(session: open))
    }

    /// DEL-042 "Speichern & neu starten": markiere die alte Session als
    /// isCompleted=true (mit den bisher geloggten Saetzen), rechne totals
    /// und starte dann eine neue Session.
    private func completeOpenSessionAndStartNew() {
        guard let open = openSessions.first else {
            actuallyStartNewSession()
            return
        }
        let now = Date()
        open.endTime = now
        open.durationMinutes = max(0, Int(now.timeIntervalSince(open.startTime) / 60))
        open.totalSets = open.logs.count
        open.totalVolumeKg = open.logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        open.isCompleted = true
        try? modelContext.save()
        actuallyStartNewSession()
    }

    /// DEL-042 "Verwerfen": lösche die alte Session inkl. ihrer Logs
    /// (cascade) und starte neu.
    private func discardOpenSessionAndStartNew() {
        guard let open = openSessions.first else {
            actuallyStartNewSession()
            return
        }
        modelContext.delete(open)
        try? modelContext.save()
        actuallyStartNewSession()
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
