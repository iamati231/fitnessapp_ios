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
                    Text("Laufendes Training")
                } footer: {
                    Text("Tippe auf das Banner, um mit der Session weiterzumachen oder sie zu beenden.")
                        .font(.footnote)
                }
            }

            Section("Pläne") {
                if plans.isEmpty {
                    emptyState
                } else {
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            PlanRow(plan: plan)
                        }
                    }
                    .onDelete(perform: deletePlans)
                }
            }
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Aus Template anlegen", systemImage: "rectangle.stack.fill.badge.plus")
                    }
                    Button {
                        createNewPlan()
                    } label: {
                        Label("Leerer Plan", systemImage: "plus")
                    }
                } label: {
                    Label("Neuer Plan", systemImage: "plus.circle.fill")
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
            Label("Noch kein Plan", systemImage: "list.bullet.rectangle.portrait")
                .font(.headline)
            Text("Lege deinen ersten Trainings-Plan an — Tage, Übungen, Sätze. Der Plan ist die Grundlage für jede Session.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button {
                    showingTemplatePicker = true
                } label: {
                    Label("Aus Template", systemImage: "rectangle.stack.fill.badge.plus")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    createNewPlan()
                } label: {
                    Label("Leer", systemImage: "plus")
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
                        Text("Aktiv")
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
