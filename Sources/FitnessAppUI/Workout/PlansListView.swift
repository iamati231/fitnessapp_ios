#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Top-level list of training plans plus a banner for any in-flight workout session.
/// New plans are created with sensible defaults and pushed straight into the editor.
@available(iOS 17.0, macOS 14.0, *)
public struct PlansListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    /// Single-key @Query (sort by name) + in-memory secondary sort by `isActive`.
    /// SortDescriptor with a Bool key-path requires `Compared : NSObject`, which
    /// SwiftData @Model classes are NOT — so multi-descriptor arrays don't compile
    /// on macOS toolchains. Client-side sort is the cleanest workaround.
    @Query(sort: \TrainingPlan.name)
    private var plansByName: [TrainingPlan]

    private var plans: [TrainingPlan] {
        plansByName.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.name < rhs.name
        }
    }

    @Query(filter: #Predicate<WorkoutSession> { !$0.isCompleted },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var activeSessions: [WorkoutSession]

    @State private var showingTemplatePicker = false

    public init() {}

    public var body: some View {
        List {
            if let active = activeSessions.first {
                Section {
                    NavigationLink(value: ActiveSessionRoute(session: active)) {
                        ActiveSessionBanner(session: active)
                    }
                } header: {
                    Text("plans.active.title", bundle: .module)
                } footer: {
                    Text("plans.active.hint", bundle: .module)
                        .font(.footnote)
                }
            }

            Section {
                if plans.isEmpty {
                    emptyState
                } else {
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            PlanRow(plan: plan)
                        }
                        // DEL-070: Swipe-Action "Duplizieren" — User kann
                        // eine Variation seines aktiven Plans bauen, ohne
                        // das Original zu zerschiessen. Loescht keine
                        // Daten, daher non-destructive Color (deltiqOrange).
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                duplicatePlan(plan)
                            } label: {
                                Label {
                                    Text("plans.duplicate", bundle: .module)
                                } icon: {
                                    Image(systemName: "plus.square.on.square")
                                }
                            }
                            .tint(Color.deltiqOrange)
                        }
                    }
                    .onDelete(perform: deletePlans)
                }
            } header: {
                Text("plans.list.title", bundle: .module)
            }
        }
        .navigationTitle(Text("tab.plan", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label {
                            Text("plans.create.fromTemplate", bundle: .module)
                        } icon: {
                            Image(systemName: "rectangle.stack.fill.badge.plus")
                        }
                    }
                    Button {
                        createNewPlan()
                    } label: {
                        Label {
                            Text("plans.create.empty", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                } label: {
                    Label {
                        Text("plans.new", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            ProgramTemplatePickerView()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("plans.empty.title", bundle: .module)
            } icon: {
                Image(systemName: "list.bullet.rectangle.portrait")
            }
                .font(.headline)
            Text("plans.empty.hint", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button {
                    showingTemplatePicker = true
                } label: {
                    // DEL-046: vorher `rectangle.stack.fill.badge.plus` — das
                    // gerenderte SF-Symbol war auf `.borderedProminent` un-
                    // sichtbar (vermutlich wegen `.badge.plus`-Komposition
                    // + Tint-Override). `list.bullet.clipboard` rendert sauber
                    // und harmonisiert visuell mit dem `+` des Leer-Buttons.
                    Label {
                        Text("plans.create.fromTemplateShort", bundle: .module)
                    } icon: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    createNewPlan()
                } label: {
                    Label {
                        Text("plans.create.emptyShort", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    // MARK: Actions

    private func createNewPlan() {
        let plan = TrainingPlan(
            name: "Neuer Plan",
            weeks: 12,
            isActive: plans.isEmpty,                       // first plan is active by default
            targetEnvironment: .gym
        )
        modelContext.insert(plan)
        navigation.workoutPath.append(plan)
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }

    /// DEL-070: Tiefkopie des Plans inkl. Tagen, Uebungen und allen
    /// Trainings-Parametern. Die Kopie startet als `isActive = false`
    /// (User soll bewusst entscheiden, ob er auf die Variante umschaltet)
    /// und bekommt einen "(Kopie)"-Suffix im Namen.
    ///
    /// `isTemplate` bleibt `false` — Templates sind Read-Only-Library-
    /// Seeds, eine User-Duplikat wandert in den editierbaren Plan-Bestand.
    /// Archivierte Snapshot-Uebungen (DEL-049 swappedFromOriginal) werden
    /// NICHT mit-kopiert — die Kopie startet "frisch", ohne Urlaubs-Modus-
    /// Geister.
    private func duplicatePlan(_ source: TrainingPlan) {
        let copy = TrainingPlan(
            name: "\(source.name) (Kopie)",
            programType: source.programType,
            descriptionText: source.descriptionText,
            weeks: source.weeks,
            isActive: false,
            targetEnvironment: source.targetEnvironment,
            isTemplate: false
        )
        copy.progressionTargetRIROverride = source.progressionTargetRIROverride
        modelContext.insert(copy)

        for day in source.days {
            let dayCopy = TrainingDay(
                name: day.name,
                weekday: day.weekday,
                type: day.type,
                nextIntensity: day.nextIntensity,
                plan: copy
            )
            modelContext.insert(dayCopy)

            // Nur AKTIVE Uebungen kopieren — archivierte Urlaubs-Modus-
            // Snapshots gehoeren der Original-Plan-Instanz und sollen
            // nicht in der Kopie geistern.
            for ex in day.activeExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let exCopy = Exercise(
                    name: ex.name,
                    sets: ex.sets,
                    repsMin: ex.repsMin,
                    repsMax: ex.repsMax,
                    restSeconds: ex.restSeconds,
                    notes: ex.notes,
                    suggestedWeight: ex.suggestedWeight,
                    orderIndex: ex.orderIndex,
                    targetRir: ex.targetRir,
                    weightReducedNote: ex.weightReducedNote,
                    isCardio: ex.isCardio,
                    isTimeBased: ex.isTimeBased,
                    smartProgressionEnabled: ex.smartProgressionEnabled,
                    progressionStep: ex.progressionStep,
                    isCompound: ex.isCompound,
                    targetDistanceKm: ex.targetDistanceKm,
                    targetDurationMinutes: ex.targetDurationMinutes,
                    day: dayCopy
                )
                modelContext.insert(exCopy)
            }
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct PlanRow: View {
    let plan: TrainingPlan

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background((plan.isActive ? Color.green : Color.gray).gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plan.name)
                        .font(.body.weight(.semibold))
                    if plan.isActive {
                        Text("plans.activeBadge", bundle: .module)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text("\(plan.days.count) Tage")
                    Text("•")
                    Text("\(plan.weeks) Wochen")
                    Text("•")
                    Text(environmentLabel(plan.targetEnvironment))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "Ohne Equipment"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ActiveSessionBanner: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.orange.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.dayName ?? "Training läuft")
                    .font(.body.weight(.semibold))
                Text("Gestartet \(session.startTime.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
#endif
