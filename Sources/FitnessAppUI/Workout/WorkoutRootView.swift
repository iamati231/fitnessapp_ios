#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppData

/// Workout-tab root. Owns the `NavigationStack` (path is stored in `AppNavigation`
/// so finish-flows can clear it). Declares typed destinations for plans, days,
/// active sessions, and the post-workout summary.
@available(iOS 17.0, macOS 14.0, *)
public struct WorkoutRootView: View {

    @Environment(AppNavigation.self) private var navigation

    public init() {}

    public var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.workoutPath) {
            PlansListView()
                .navigationDestination(for: TrainingPlan.self) { plan in
                    PlanEditorView(plan: plan)
                }
                .navigationDestination(for: TrainingDay.self) { day in
                    DayEditorView(day: day)
                }
                .navigationDestination(for: ActiveSessionRoute.self) { route in
                    // Nachtrag 6. August (README 2.9): Zeitformat-Tage
                    // (AMRAP/EMOM/Auf Zeit) bekommen einen eigenen Player
                    // statt der gepagten Uebungs-Navigation + RestTimerBar -
                    // Peer zu ActiveWorkoutView, nicht ein Modus darin.
                    if route.session.day?.timeFormat != nil {
                        TimedWorkoutPlayerView(session: route.session)
                    } else {
                        ActiveWorkoutView(session: route.session)
                    }
                }
                .navigationDestination(for: SummaryRoute.self) { route in
                    WorkoutSummaryView(session: route.session, isReadOnly: route.isReadOnly)
                }
        }
    }
}

// MARK: - Route wrappers

/// Push value for ActiveWorkoutView. Wraps a `WorkoutSession` so the same model
/// type can also push `WorkoutSummaryView` (via `SummaryRoute`) without conflict.
@available(iOS 17.0, macOS 14.0, *)
public struct ActiveSessionRoute: Hashable {
    public let session: WorkoutSession
    public init(session: WorkoutSession) { self.session = session }
}

@available(iOS 17.0, macOS 14.0, *)
public struct SummaryRoute: Hashable {
    public let session: WorkoutSession
    /// True when invoked from a history-style entry point — disables editing.
    public let isReadOnly: Bool
    public init(session: WorkoutSession, isReadOnly: Bool = false) {
        self.session = session
        self.isReadOnly = isReadOnly
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit PPL-Plan") {
    WorkoutRootView()
        .modelContainer(PreviewSeed.workoutContainer)
        .environment(AppNavigation())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Leer (kein Plan)") {
    WorkoutRootView()
        .modelContainer(PreviewSeed.maleProfileContainer)
        .environment(AppNavigation())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit laufender Session") {
    WorkoutRootView()
        .modelContainer(PreviewSeed.activeSessionContainer)
        .environment(AppNavigation())
}
#endif
#endif
