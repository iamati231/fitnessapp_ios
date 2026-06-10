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
                    // DEL-142: Tagesanalyse-Card UNTER der Übungs-Liste.
                    // Empty-State wenn keine Übungen, sonst die berechnete
                    // Analyse aus dem `DayAnalyzer`. SwiftUI re-evaluiert
                    // `dayAnalysisSection` bei jeder Re-Render-Pass des
                    // Forms — sobald der User Übungen mutate (add/remove,
                    // sets/reps-changes via Editor), kommt die nächste
                    // Pass mit aktualisierten Werten.
                    dayAnalysisSection
                }
            }
        }
        .navigationTitle(day.name.isEmpty ? String(localized: "day.editor.untitled", bundle: .module) : day.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // DEL-095: EditButton macht den nativen Edit-Mode an, in dem die
        // Drag-Handles fuer Reorder + Delete sichtbar werden. Bei
        // readOnly-Templates blenden wir den Button aus — dort ist Editing
        // ohnehin gesperrt.
        .toolbar {
            if !isReadOnly && !day.activeExercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        #endif
        .sheet(isPresented: $showingPicker) {
            // DEL-210: einheitliche Übungs-Auswahl — dieselbe View wie die
            // Bibliothek unter Einstellungen, im Picker-Modus.
            ExerciseLibraryPickerSheet(
                planEnvironment: day.plan?.targetEnvironment,
                onSelect: { template in handleExerciseSelection(template) },
                onCreateCustom: { draft in addCustomExercise(draft) }
            )
        }
        // DEL-048: Equipment-Konflikt-Confirmation. Wenn der User mit Filter
        // OFF eine inkompatible Uebung gewaehlt hat, fragen wir hier nach.
        .confirmationDialog(
            Text("day.editor.equipmentConflict.title", bundle: .module),
            isPresented: Binding(
                get: { pendingEquipmentConflict != nil },
                set: { if !$0 { pendingEquipmentConflict = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEquipmentConflict
        ) { conflict in
            // Option A: Plan-Env auf Gym/Home umstellen UND Uebung adden.
            Button(String(format: String(localized: "day.editor.equipmentConflict.switchPlan", bundle: .module), environmentLabel(conflict.requiredEnv))) {
                switchPlanEnvAndAdd(conflict: conflict)
                pendingEquipmentConflict = nil
            }
            // Option B: Trotzdem adden, Plan-Env unveraendert lassen. Die
            // Uebung wird vermutlich beim ersten Workout-Start als "kein
            // Equipment vorhanden" stossen, aber der User hat die freie Wahl.
            Button {
                addExercise(from: conflict.template)
                pendingEquipmentConflict = nil
            } label: {
                Text("day.editor.equipmentConflict.justAdd", bundle: .module)
            }
            Button(role: .cancel) {
                pendingEquipmentConflict = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { conflict in
            let template = String(localized: "day.editor.equipmentConflict.message", bundle: .module)
            Text(template
                .replacingOccurrences(of: "%1$@", with: conflict.template.name)
                .replacingOccurrences(of: "%2$@", with: environmentLabel(conflict.planEnv)))
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
            Text("plans.active.title", bundle: .module),
            isPresented: $showingOpenSessionDialog,
            titleVisibility: .visible
        ) {
            Button { resumeOpenSession() } label: {
                Text("session.recovery.resume", bundle: .module)
            }
            Button { completeOpenSessionAndStartNew() } label: {
                Text("session.recovery.saveAndRestart", bundle: .module)
            }
            Button(role: .destructive) { discardOpenSessionAndStartNew() } label: {
                Text("session.recovery.discardAndRestart", bundle: .module)
            }
            Button(role: .cancel) { } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            if let open = openSessions.first {
                // DEL-129: displayDayName liefert hier den lokalisierten
                // Day-Title, sodass der Recovery-Dialog im EN/TR-Mode den
                // richtigen Namen statt eines stale DE-Snapshots zeigt.
                let dayName = (open.day != nil || open.dayName != nil)
                    ? open.displayDayName
                    : String(localized: "session.recovery.dayName.unknown", bundle: .module)
                let stamp = open.startTime.formatted(.relative(presentation: .named))
                let template = String(localized: "session.recovery.message.withInfo", bundle: .module)
                Text(template
                    .replacingOccurrences(of: "%1$@", with: dayName)
                    .replacingOccurrences(of: "%2$@", with: stamp))
            } else {
                Text("session.recovery.message.fallback", bundle: .module)
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
                Text(day.name.isEmpty ? String(localized: "day.restDay.title", bundle: .module) : day.displayName)
                    .font(.title.weight(.bold))
                Text("day.restDay.heroMessage", bundle: .module)
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
                    Label {
                        Text("day.restDay.complete.button", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
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
            // DEL-125: customName + localizedSystemName-Placeholder.
            TextField(
                text: Binding(
                    get: { day.customName ?? "" },
                    set: { day.customName = $0.isEmpty ? nil : $0 }
                ),
                prompt: Text(day.localizedSystemName)
            ) {
                Text("day.editor.field.name", bundle: .module)
            }
                .disabled(isReadOnly)

            Picker(selection: $day.weekday) {
                ForEach(weekdayOptions, id: \.self) { weekday in
                    Text(weekdayName(weekday)).tag(weekday)
                }
            } label: {
                Text("day.editor.field.weekday", bundle: .module)
            }
            .disabled(isReadOnly)

            Picker(selection: $day.type) {
                ForEach(DayType.allCases, id: \.self) { type in
                    Text(typeLabel(type)).tag(type)
                }
            } label: {
                Text("day.editor.field.type", bundle: .module)
            }
            .disabled(isReadOnly)

            Picker(selection: $day.nextIntensity) {
                Text("day_intensity.light", bundle: .module).tag(DayIntensity.light)
                Text("day_intensity.normal", bundle: .module).tag(DayIntensity.normal)
                Text("day_intensity.heavy", bundle: .module).tag(DayIntensity.heavy)
            } label: {
                Text("day.editor.field.nextIntensity", bundle: .module)
            }
        } header: {
            Text("day.editor.section.info", bundle: .module)
        } footer: {
            if isReadOnly {
                Text("day.editor.templateLocked.footer", bundle: .module)
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
                        Label {
                            Text("day.restDay.complete.button", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                            .font(.headline)
                        Spacer()
                    }
                }
            } footer: {
                Text("day.restDay.complete.footer", bundle: .module)
                    .font(.footnote)
            }
        } else {
            // DEL-127: Adaptive Start-CTA. Wenn fuer diesen Day bereits eine
            // offene Session existiert (App-Crash, vergessenes Speichern,
            // oder User hat das Workout abgebrochen ohne zu finishen), zeigen
            // wir "Training fortsetzen" statt "Training starten" — analog zum
            // DashboardView-PlanDayCard-Pattern. Klick fuehrt direkt in die
            // bestehende Session, ohne Recovery-Dialog.
            adaptiveStartSection
        }
    }

    /// DEL-127: ausgelagerter Builder fuer den adaptiven Start-CTA. Wird in
    /// eine eigene @ViewBuilder-Property gezogen, damit das `let openForThisDay`
    /// nicht in einem if-else-Branch der parent-ViewBuilder steht (Swift-5.9-
    /// ResultBuilder-Quirk — Bindings innerhalb verschachtelter Branches
    /// koennen je nach Build-Konfiguration zicken).
    @ViewBuilder
    private var adaptiveStartSection: some View {
        let openForThisDay = openSessionForCurrentDay
        Section {
            Button {
                // UX-204: Medium-Impact-Haptik — der "Training starten"-
                // Klick ist ein bewusster Commitment-Schritt, das verdient
                // ein satteres haptisches Feedback als ein Set-Tap.
                DeltiqHaptics.impact(.medium)
                if let open = openForThisDay {
                    resumeOpenSession(open)
                } else {
                    startSession()
                }
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text(openForThisDay != nil
                             ? "day.editor.start.resume"
                             : "day.editor.start.button",
                             bundle: .module)
                    } icon: {
                        Image(systemName: openForThisDay != nil
                            ? "play.circle.fill"
                            : "play.fill")
                    }
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(day.activeExercises.isEmpty)
        } footer: {
            if day.activeExercises.isEmpty {
                Text("day.editor.start.hintEmpty", bundle: .module)
                    .font(.footnote)
            } else if openForThisDay != nil {
                Text("day.editor.start.resumeHint", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    /// DEL-127: liefert die offene Session, deren `.day` mit dem aktuell
    /// editierten Tag uebereinstimmt. Wenn nil → kein Resume-Pfad,
    /// regulaerer Start-Button wird gerendert.
    private var openSessionForCurrentDay: WorkoutSession? {
        openSessions.first { $0.day?.persistentModelID == day.persistentModelID }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        Section {
            if day.activeExercises.isEmpty {
                Text(isRestDay
                     ? "day.editor.exercises.restDayEmpty"
                     : "day.editor.exercises.empty",
                     bundle: .module)
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
                ForEach(Array(orderedExercises.enumerated()), id: \.element.persistentModelID) { idx, exercise in
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        ExerciseRow(exercise: exercise, isInSuperset: exercise.supersetId != nil)
                    }
                    .buttonStyle(.plain)
                    // DEL-083: Swipe-Action "Mit oberer verbinden" / "Trennen".
                    // Nur sinnvoll ab Index 1 (es muss eine Uebung darueber
                    // existieren). Toggle-Verhalten: angeklickt → verbinden,
                    // erneut angeklickt → wieder aus Superset rausnehmen.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if idx > 0 {
                            Button {
                                toggleSupersetWithPrevious(at: idx)
                            } label: {
                                Label {
                                    Text(exercise.supersetId == nil
                                         ? "day.editor.superset.link"
                                         : "day.editor.superset.unlink",
                                         bundle: .module)
                                } icon: {
                                    Image(systemName: exercise.supersetId == nil
                                        ? "link"
                                        : "link.badge.plus")
                                }
                            }
                            .tint(Color.deltiqOrange)
                        }
                    }
                }
                .onMove(perform: moveExercises)
                .onDelete(perform: deleteExercises)
            }
        } header: {
            HStack {
                Text("day.editor.section.exercises", bundle: .module)
                Spacer()
                if !isReadOnly {
                    Button {
                        showingPicker = true
                    } label: {
                        Label {
                            Text("common.add", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } footer: {
            if isReadOnly {
                Text("day.editor.templateLocked.exercises", bundle: .module)
                    .font(.footnote)
            } else if !day.activeExercises.isEmpty {
                Text("day.editor.exercises.editHint", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    // MARK: - DEL-142 Tagesanalyse

    /// Form-Section um die `DayAnalysisCard`. Drei Branches:
    ///   * Übungs-Liste leer → `.empty`-Card mit Hint
    ///   * `DayAnalyzer.analyze(...)` liefert nil (Edge-Case, wenn alle
    ///     Übungen archived oder Warmup/Cooldown) → ebenfalls `.empty`
    ///   * Sonst → `.analysis(...)`-Card mit den berechneten Werten
    ///
    /// Section-Header bleibt leer — die Card hat ihren eigenen Header
    /// mit Icon + Titel. listRowInsets removed so the Bento-Card-Look
    /// dasselbe Padding-System hat wie auf dem Dashboard.
    @ViewBuilder
    private var dayAnalysisSection: some View {
        Section {
            let exercises = day.activeExercises
            let analysis = DayAnalyzer.analyze(exercises: exercises)

            if let analysis {
                DayAnalysisCard(mode: .analysis(analysis))
            } else {
                DayAnalysisCard(mode: .empty)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    // MARK: Derived

    /// DEL-049: archivierte Snapshots (Urlaubs-Modus) sind aus der UI raus —
    /// nur aktive Uebungen anzeigen + sortieren.
    private var orderedExercises: [Exercise] {
        day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
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

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }

    /// DEL-083: Verbindet die Uebung an `idx` mit der direkt darueber zum
    /// Superset. Beide bekommen die selbe `supersetId`. Wenn die obere
    /// bereits in einem Superset ist, schliessen wir uns dem an statt einen
    /// neuen anzulegen. Erneuter Aufruf → loest die Verbindung.
    private func toggleSupersetWithPrevious(at idx: Int) {
        let arr = orderedExercises
        guard idx > 0, idx < arr.count else { return }
        let current = arr[idx]
        let previous = arr[idx - 1]

        if current.supersetId != nil {
            // Trennen: Wenn current als einziger Teil ihrer Gruppe bleibt
            // (gruppe-size <= 2 nach dem entfernen), nullen wir auch den
            // verbleibenden Partner — denn ein "Superset of 1" macht
            // semantisch keinen Sinn.
            let id = current.supersetId!
            current.supersetId = nil
            let remaining = arr.filter { $0.supersetId == id }
            if remaining.count <= 1 {
                remaining.forEach { $0.supersetId = nil }
            }
        } else {
            // Verbinden: gleicher supersetId wie previous (entweder dessen
            // existierende ID oder eine neu erstellte).
            let id = previous.supersetId ?? UUID()
            previous.supersetId = id
            current.supersetId = id
        }
    }

    private func addExercise(from template: ExerciseTemplate) {
        // DEL-149: NUR der deutsche Library-Base-Name landet in
        // `Exercise.name`. Frueher (DEL-111) wurde hier `template.displayName`
        // genommen — das fror die aktuelle Locale ein und produzierte
        // Eintraege wie "Koşu Bandı"/"Treadmill" in der DB, die nach einem
        // Sprachwechsel falsch gerendert wurden. Der DE-Base ist der stabile
        // Library-Anchor; die UI-Sicht macht den Lookup ueber
        // `displayName` (Extension) wieder lokalisiert.
        let exercise = Exercise(
            name: template.name,
            // DEL-157: Cardio- + Time-Based-Uebungen starten mit genau 1 Satz
            // (eine Distanz-/Dauer- bzw. Halte-Zeile). Die Standard-3-Saetze
            // ergeben fuer einen Lauf/Plank keinen Sinn. Strength bleibt 3.
            sets: (template.isCardio || template.isTimeBased) ? 1 : 3,
            orderIndex: day.activeExercises.count,
            // DEL-080: Cardio-Flag aus dem Library-Template propagieren.
            // Picker-Pick einer Cardio-Uebung (z.B. "Freier Lauf") soll
            // direkt mit `isCardio = true` im Plan landen — sonst kriegt
            // der User die falsche SetRow-UI.
            isCardio: template.isCardio,
            isTimeBased: template.isTimeBased,
            // DEL-053: Compound-Flag aus dem Library-Template ziehen. Die
            // 5 kanonischen Barbell-Lifts werden als Compound markiert,
            // alles andere als Isolation. User kann's spaeter im
            // ExerciseEditor manuell ueberschreiben.
            isCompound: template.isSystemCompound,
            // DEL-098: Belastungsfaktoren aus dem Library-Template ziehen,
            // damit Recovery-/Fatigue-Scoring schon ab dem ersten Workout
            // mit den richtigen Werten rechnet.
            systemicFatigueFactor: template.systemicFatigueFactor,
            localMuscleDamageFactor: template.localMuscleDamageFactor,
            cnsDemandFactor: template.cnsDemandFactor,
            axialLoadFactor: template.axialLoadFactor,
            technicalComplexityFactor: template.technicalComplexityFactor,
            recoveryClass: template.recoveryClass,
            // DEL-163: Muskel + Equipment vom Template uebernehmen. Vorher
            // gingen diese beim Adopt verloren (Exercise fiel im Editor auf
            // Brust/Koerpergewicht zurueck), weil nur isCompound + Faktoren
            // kopiert wurden. Gilt fuer Custom- UND System-Templates.
            primaryMuscle: template.primaryMuscle,
            equipment: template.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    private func addCustomExercise(_ draft: CustomExerciseDraft) {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Persist as a custom template too — the exercise reappears in the picker
        // next time so the user doesn't have to retype it.
        // DEL-159: Metadaten aus dem Erstell-Sheet (Muskel/Equipment/Compound)
        // statt neutraler Defaults — Picker zeigt sie korrekt an, DayAnalyzer
        // kann den Muscle-Focus berechnen.
        let template = ExerciseTemplate(
            name: trimmed,
            equipment: draft.equipment,
            primaryMuscle: draft.primaryMuscle,
            isCustom: true,
            isSystemCompound: draft.isCompound
        )
        modelContext.insert(template)

        let exercise = Exercise(
            name: trimmed,
            orderIndex: day.activeExercises.count,
            isCompound: draft.isCompound,
            primaryMuscle: draft.primaryMuscle,
            equipment: draft.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// DEL-095: Reorder via Drag&Drop. Per `Array.move` umschichten, dann
    /// alle `orderIndex` neu kontinuierlich 0..n-1 vergeben — sonst entstehen
    /// Luecken, die nach dem naechsten Delete unstable sortieren.
    /// **Superset-aware**: Wenn der User eine Uebung zieht, die zu einem
    /// Superset gehoert (`supersetId != nil`), nehmen wir den Partner
    /// automatisch mit. Sonst zerreisst ein versehentlicher Drag die
    /// DEL-083-Kopplung lautlos.
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var arr = orderedExercises
        let expandedSource = expandSupersetGroups(in: arr, base: source)
        arr.move(fromOffsets: expandedSource, toOffset: destination)
        for (i, exercise) in arr.enumerated() {
            exercise.orderIndex = i
        }
    }

    /// Erweitert eine Drag-Source-IndexSet um alle Geschwister-Indices, die
    /// denselben `supersetId` tragen — Superset-Bloecke bleiben so beim
    /// Reorder zusammen.
    private func expandSupersetGroups(in arr: [Exercise], base: IndexSet) -> IndexSet {
        var expanded = base
        for index in base {
            guard index < arr.count, let supersetId = arr[index].supersetId else { continue }
            for (i, ex) in arr.enumerated() where ex.supersetId == supersetId {
                expanded.insert(i)
            }
        }
        return expanded
    }

    /// DEL-049: Loescht eine aktive Uebung UND ihren archivierten Urlaubs-
    /// Modus-Snapshot (`swappedFromOriginal`), sonst bleibt ein toter
    /// Eintrag in der Datenbank zurueck, den der User nirgendwo mehr sieht.
    private func deleteExercises(at offsets: IndexSet) {
        let arr = orderedExercises
        for index in offsets {
            let exercise = arr[index]
            // Original mit-cascaden (chain-cleanup, falls Doppel-Swap).
            var cur: Exercise? = exercise.swappedFromOriginal
            while let next = cur {
                let nextOriginal = next.swappedFromOriginal
                modelContext.delete(next)
                cur = nextOriginal
            }
            modelContext.delete(exercise)
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
            exerciseCount: day.activeExercises.count,
            isCompleted: false,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
    }

    /// DEL-042 "Fortsetzen": navigiere in die existing offene Session ohne
    /// eine neue zu erstellen.
    ///
    /// DEL-127: optionaler `session`-Parameter — wenn vom Dialog-Pfad
    /// (Recovery) ohne Argument aufgerufen, fallbacked es auf
    /// `openSessions.first`. Aus dem adaptiven Plan-Detail-CTA wird die
    /// konkrete `openSessionForCurrentDay` reingereicht, damit auch bei
    /// mehreren offenen Sessions (selten, aber moeglich) die richtige
    /// fortgesetzt wird.
    private func resumeOpenSession(_ session: WorkoutSession? = nil) {
        guard let open = session ?? openSessions.first else { return }
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

    // DEL-121 Final: delegieren an DayType.localizedName statt eigene
    // dayType.*-Keys. Die collidierten via snake_case/camelCase-Normalization
    // mit den legacy day_type.*-Keys (selbes Swift-Symbol). Die EN-Strings
    // wurden ins day_type.* Catalog-Namespace gemerged (Upper Body / Lower
    // Body / Rest Day statt Upper / Lower / Rest), dayType.* Keys deleted.
    private func typeLabel(_ type: DayType) -> String {
        String(localized: type.localizedName)
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseRow: View {
    let exercise: Exercise
    var isInSuperset: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // DEL-083: Superset-Indikator — farbige Klammer/Linie am
            // linken Rand. Nur sichtbar, wenn die Uebung Teil einer
            // verknuepften Gruppe ist.
            Rectangle()
                .fill(isInSuperset ? Color.deltiqOrange : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            Text("\(exercise.orderIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                // DEL-124: displayName resolved via Exercise+DisplayName-
                // Library-Lookup (DEL-118). Plan-Detail-Row zeigt jetzt
                // multilinguale Namen statt das deutsche `name`-Snapshot.
                Text(exercise.displayName)
                    .font(.body)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isInSuperset {
                Image(systemName: "link")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .accessibilityLabel("Superset")
            }
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

    // DEL-118: format-string via xcstrings statt hardcoded DE-Interpolation.
    // Drei Varianten:
    //   * Cardio → "workout.detail.cardio"
    //   * Time-based (Plank, Wall Sit) → "workout.detail.seconds"
    //   * Standard Strength → "workout.detail.reps"
    private var detailLine: String {
        if exercise.isCardio {
            return String(format: String(localized: "workout.detail.cardio", bundle: .module), exercise.restSeconds)
        }
        let repsText = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        let key: String.LocalizationValue = exercise.isTimeBased
            ? "workout.detail.seconds"
            : "workout.detail.reps"
        let template = String(localized: key, bundle: .module)
        return template
            .replacingOccurrences(of: "%1$lld", with: "\(exercise.sets)")
            .replacingOccurrences(of: "%2$@",   with: repsText)
            .replacingOccurrences(of: "%3$lld", with: "\(exercise.restSeconds)")
    }
}
#endif
