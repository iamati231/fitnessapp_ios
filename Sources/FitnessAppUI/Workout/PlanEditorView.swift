#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Edits a single `TrainingPlan` — name, weeks, environment, isActive flag, plus the
/// list of `TrainingDay`s. Setting a plan to "active" unsets the flag on every other
/// plan so there's always at most one active plan at a time.
@available(iOS 17.0, macOS 14.0, *)
public struct PlanEditorView: View {

    @Bindable public var plan: TrainingPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    @Query private var allPlans: [TrainingPlan]

    // DEL-022 — Environment-Swap-State
    @State private var pendingEnvironmentSwap: PendingEnvironmentSwap?
    @State private var swapResultToast: String?

    public init(plan: TrainingPlan) {
        self.plan = plan
    }

    public var body: some View {
        Form {
            if isReadOnly {
                templateBanner
            }
            metaSection
            settingsSection
            daysSection
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // DEL-022 — Trainingsort-Wechsel triggert Confirmation-Dialog mit
        // Optionen "Übungen anpassen" / "Nur Trainingsort ändern" / "Abbrechen".
        .onChange(of: plan.targetEnvironment) { oldValue, newValue in
            guard oldValue != newValue,
                  // Nur wenn es ueberhaupt Uebungen gibt — leerer Plan braucht
                  // keinen Swap.
                  plan.days.contains(where: { !$0.exercises.isEmpty }),
                  !isReadOnly
            else { return }
            pendingEnvironmentSwap = PendingEnvironmentSwap(
                oldEnv: oldValue,
                newEnv: newValue
            )
        }
        .confirmationDialog(
            "Trainingsort geändert",
            isPresented: Binding(
                get: { pendingEnvironmentSwap != nil },
                set: { if !$0 { pendingEnvironmentSwap = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingEnvironmentSwap
        ) { swap in
            Button("Übungen anpassen") {
                performEnvironmentSwap(to: swap.newEnv)
                pendingEnvironmentSwap = nil
            }
            Button("Nur Trainingsort ändern") {
                pendingEnvironmentSwap = nil
            }
            Button("Abbrechen", role: .cancel) {
                // Picker rueckgaengig machen
                plan.targetEnvironment = swap.oldEnv
                pendingEnvironmentSwap = nil
            }
        } message: { swap in
            Text("Sollen die Übungen an deinen neuen Trainingsort angepasst werden? Übungen ohne passende Alternative bleiben im Plan und brauchen manuelle Anpassung.")
        }
        .overlay(alignment: .bottom) {
            if let msg = swapResultToast {
                Label(msg, systemImage: "checkmark.seal.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Bundle der zwei Environments fuer den ConfirmationDialog. Equatable
    /// damit der Dialog korrekt presenting-binden kann.
    private struct PendingEnvironmentSwap: Equatable {
        let oldEnv: EnvironmentType
        let newEnv: EnvironmentType
    }

    /// True wenn der Plan via `ProgramInstantiator` aus einem Template
    /// generiert wurde (`isTemplate=true`). Custom-Plaene starten mit
    /// `isTemplate=false` und bleiben editierbar — auch wenn der User
    /// manuell einen Programm-Typ eintippt (DEL-013-Fix).
    private var isReadOnly: Bool {
        plan.isTemplate
    }

    // MARK: Sections

    private var templateBanner: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.indigo.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Template-Plan")
                        .font(.body.weight(.semibold))
                    Text("Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(Color.indigo.opacity(0.08))
    }

    private var metaSection: some View {
        Section("Plan-Info") {
            TextField("Name", text: $plan.name)
                .disabled(isReadOnly)
            TextField("Programm-Typ", text: $plan.programType)
                .disabled(isReadOnly)
            TextField("Beschreibung (optional)", text: $plan.descriptionText, axis: .vertical)
                .lineLimit(2...5)
                .disabled(isReadOnly)
        }
    }

    private var settingsSection: some View {
        // Wochen + Trainingsort bleiben editierbar — der User kann sein
        // Template kuerzen oder die Equipment-Auswahl anpassen, ohne die
        // Uebungs-Struktur zu zerschiessen. Active-Toggle bleibt fuer Plan-
        // Wechsel offen.
        Section("Einstellungen") {
            Stepper(value: $plan.weeks, in: 1...52) {
                LabeledContent("Wochen", value: "\(plan.weeks)")
            }

            Picker("Trainingsort", selection: $plan.targetEnvironment) {
                Text("Gym").tag(EnvironmentType.gym)
                Text("Home-Gym").tag(EnvironmentType.homeGym)
                Text("Ohne Equipment").tag(EnvironmentType.noEquipment)
            }

            Toggle("Als aktiven Plan setzen", isOn: Binding(
                get: { plan.isActive },
                set: { setActive($0) }
            ))
        }
    }

    @ViewBuilder
    private var daysSection: some View {
        Section {
            if plan.days.isEmpty {
                Text(isReadOnly
                     ? "Template hat keine Trainings-Tage konfiguriert (sollte nicht passieren)."
                     : "Noch keine Trainings-Tage. Tippe '+' oben rechts um deinen ersten Tag anzulegen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if isReadOnly {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                }
                // onDelete bewusst NICHT registriert — Template-Tage sind gesetzt
            } else {
                ForEach(orderedDays) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                }
                .onDelete(perform: deleteDays)
            }
        } header: {
            HStack {
                Text("Trainings-Tage")
                Spacer()
                if !isReadOnly {
                    // Menu statt Single-Button-Action: User entscheidet pro Klick,
                    // ob Trainings- oder Ruhetag (DEL-021/023). Default-Behavior
                    // vorher: implizit ein leerer Tag, der wegen
                    // `day.exercises.isEmpty` faelschlich als Ruhetag erkannt
                    // wurde — jetzt explizit.
                    Menu {
                        Button {
                            createNewDay(type: .custom)
                        } label: {
                            Label("Trainingstag", systemImage: "figure.strengthtraining.traditional")
                        }
                        Button {
                            createNewDay(type: .rest)
                        } label: {
                            Label("Ruhetag", systemImage: "bed.double.fill")
                        }
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } footer: {
            Text(isReadOnly
                 ? "Template — Tage sind festgelegt. Tippe einen Tag an, um die Übungen zu sehen."
                 : "Sortiert nach Wochentag (Mo-So). Editiere den Wochentag im Tag selber.")
                .font(.footnote)
        }
    }

    // MARK: Derived

    /// Days sorted Mon-first via the shared `PlanNavigator` helper.
    private var orderedDays: [TrainingDay] {
        PlanNavigator.sortByWeekdayMondayFirst(plan.days)
    }

    // MARK: Actions

    private func setActive(_ active: Bool) {
        if active {
            for other in allPlans where other.persistentModelID != plan.persistentModelID {
                other.isActive = false
            }
        }
        plan.isActive = active
    }

    /// Legt einen neuen Tag (Trainings- ODER Ruhetag) im Plan an. Bei
    /// Trainingstagen navigieren wir direkt in den DayEditor, damit der User
    /// gleich Uebungen hinzufuegen kann. Ruhetage werden nur in der Liste
    /// gespeichert — kein Editor noetig.
    private func createNewDay(type: DayType) {
        let nextWeekday = (plan.days.map(\.weekday).max() ?? 1) % 7 + 1
        let defaultName: String
        switch type {
        case .rest: defaultName = "Ruhetag"
        default:    defaultName = "Tag \(plan.days.count + 1)"
        }
        let day = TrainingDay(
            name: defaultName,
            weekday: nextWeekday,
            type: type,
            plan: plan
        )
        modelContext.insert(day)
        // Bei Ruhetagen lassen wir den User auf der Liste — er kann den Tag
        // bei Bedarf umbenennen, aber muss nicht zwingend in den Editor.
        // Bei Trainingstagen springen wir direkt rein um Uebungen hinzuzufuegen.
        if type != .rest {
            navigation.workoutPath.append(day)
        }
    }

    private func deleteDays(at offsets: IndexSet) {
        let toDelete = offsets.map { orderedDays[$0] }
        for day in toDelete {
            modelContext.delete(day)
        }
    }

    /// DEL-022: Geht alle Uebungen des Plans durch und ersetzt sie pro Mapping
    /// aus `ExerciseLibraryData.alternatives`. Drei Resolutions:
    ///   - `.swap`: neue Uebung mit gleichem orderIndex + day einfuegen, alte
    ///     loeschen (sauberer SwiftData-Lifecycle).
    ///   - `.keep`: keine Alternative — bleibt im Plan, faellt in den "manuell
    ///     ueberpruefen"-Bucket.
    ///   - `.stayCompatible`: Uebung ist nativ im neuen Env nutzbar, kein Swap.
    ///
    /// `suggestedWeight` wird beim Swap auf nil gesetzt — die alte Last
    /// passt selten zur neuen Uebung. User trifft beim ersten Workout neu.
    private func performEnvironmentSwap(to newEnv: EnvironmentType) {
        var swapped = 0
        var kept = 0
        var compatible = 0

        for day in plan.days {
            let snapshot = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            for exercise in snapshot {
                switch ExerciseLibraryData.resolveAlternative(
                    forExerciseName: exercise.name,
                    targetEnvironment: newEnv
                ) {
                case .swap(let altSpec):
                    let newExercise = Exercise(
                        name: altSpec.name,
                        sets: exercise.sets,
                        repsMin: exercise.repsMin,
                        repsMax: exercise.repsMax,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        suggestedWeight: nil,   // andere Uebung → Last neu kalibrieren
                        orderIndex: exercise.orderIndex,
                        targetRir: exercise.targetRir,
                        weightReducedNote: exercise.weightReducedNote,
                        // ExerciseTemplateSpec hat (noch) kein isCardio-Flag —
                        // unsere Alternative-Mappings sind alle Strength-Lifts,
                        // also hardcode false. Wenn das Mapping spaeter Cardio-
                        // Substitutes bekommt, hier Detection via Name oder
                        // dedicated Spec-Feld nachruesten.
                        isCardio: false,
                        isTimeBased: altSpec.isTimeBased,
                        day: day
                    )
                    modelContext.insert(newExercise)
                    modelContext.delete(exercise)
                    swapped += 1
                case .keep:
                    kept += 1
                case .stayCompatible:
                    compatible += 1
                }
            }
        }

        // Toast-Message bauen
        var parts: [String] = []
        if swapped > 0    { parts.append("\(swapped) ersetzt") }
        if kept > 0       { parts.append("\(kept) ohne Alternative") }
        if compatible > 0 { parts.append("\(compatible) unverändert") }
        let message = parts.isEmpty ? "Keine Übungen zum Anpassen" : parts.joined(separator: " · ")

        withAnimation(.easeOut(duration: 0.2)) {
            swapResultToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                swapResultToast = nil
            }
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct DayRow: View {
    let day: TrainingDay

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(weekdayShort(day.weekday))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .background(Color.blue.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(day.name)
                    .font(.body.weight(.medium))
                Text("\(day.exercises.count) Übungen • \(intensityLabel(day.nextIntensity))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func weekdayShort(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    private func intensityLabel(_ intensity: DayIntensity) -> String {
        switch intensity {
        case .normal: return "Normal"
        case .light:  return "Leicht"
        case .heavy:  return "Schwer"
        }
    }
}
#endif
