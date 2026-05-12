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
                    Button {
                        createNewDay()
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

    private func createNewDay() {
        let nextWeekday = (plan.days.map(\.weekday).max() ?? 1) % 7 + 1
        let day = TrainingDay(
            name: "Tag \(plan.days.count + 1)",
            weekday: nextWeekday,
            type: .custom,
            plan: plan
        )
        modelContext.insert(day)
        navigation.workoutPath.append(day)
    }

    private func deleteDays(at offsets: IndexSet) {
        let toDelete = offsets.map { orderedDays[$0] }
        for day in toDelete {
            modelContext.delete(day)
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
