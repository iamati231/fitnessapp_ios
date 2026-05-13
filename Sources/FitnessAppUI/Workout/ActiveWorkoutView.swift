#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import FitnessAppHealth

/// Active workout screen — Phase-2: per-exercise cards, set logging, rest timer.
///
/// Layout: scrolling list of `ExerciseCard`s, sticky rest-timer bar in the bottom
/// safe-area inset, two confirmation dialogs for finish/discard. Stats (duration,
/// total sets, total volume) update live as sets are logged.
@available(iOS 17.0, macOS 14.0, *)
public struct ActiveWorkoutView: View {

    @Bindable public var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(RestTimerActivityController.self) private var restTimerActivity
    @Environment(PRNotificationCenter.self) private var prNotifications
    @Environment(HealthKitController.self) private var healthKit

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// DEL-039: aktuelle Page in der paginierten TabView. 0..N-1 sind die
    /// Uebungs-Pages, Page N ist die "Finish"-Seite mit Save/Discard.
    @State private var currentPageIndex: Int = 0

    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false

    /// Rest-timer state. nil = no timer running.
    @State private var restTimerEnd: Date?
    @State private var restTimerOriginalSeconds: Int = 0

    public init(session: WorkoutSession) {
        self.session = session
    }

    public var body: some View {
        // DEL-039: paginierte Ansicht statt scrollbarer Single-Page-List.
        // Stats oben fix, dann TabView mit einer Page pro Uebung + einer
        // finalen "Finish"-Page (Save/Discard). User swipt horizontal
        // zwischen Uebungen, page-indicator unten zeigt Position.
        VStack(spacing: 0) {
            statsCard
                .padding(.horizontal)
                .padding(.top, 8)

            paginatedBody
        }
        .background(Color(.gray).opacity(0.04).ignoresSafeArea())
        .navigationTitle(session.dayName ?? "Training")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .keyboardDismissToolbar()
        .onReceive(tick) { now = $0 }
        .safeAreaInset(edge: .bottom) {
            if let end = restTimerEnd {
                RestTimerBar(
                    endDate: end,
                    originalSeconds: restTimerOriginalSeconds,
                    onDismiss: { reason in
                        restTimerEnd = nil
                        Task {
                            await restTimerActivity.endRestTimer(
                                reason: reason == .completed ? .completed : .skipped
                            )
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            Text("active.confirm.finish.title", bundle: .module),
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button { finishWorkout() } label: {
                Text("active.action.save", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("Dauer wird auf \(formattedDuration) gesetzt, \(loggedSetsCount) Sätze und \(formatVolume()) kg Volumen geloggt.")
        }
        .confirmationDialog(
            Text("active.confirm.discard.title", bundle: .module),
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                discardWorkout()
            } label: {
                Text("active.action.discard", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("Die Session und alle \(loggedSetsCount) bisher geloggten Sätze gehen verloren.")
        }
    }

    // MARK: Sections

    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBlock(label: "Dauer", value: formattedDuration, monospacedDigit: true)
            divider
            StatBlock(label: "Sätze", value: "\(loggedSetsCount)", monospacedDigit: true)
            divider
            StatBlock(label: "Volumen kg", value: formatVolume(), monospacedDigit: true)
        }
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 32)
    }

    /// DEL-039: paginierte TabView mit einer Übung pro Seite + finaler Save/
    /// Discard-Seite. Page-Indicator unten zeigt Position. Auto-Advance bei
    /// vollständig geloggter Übung nach kurzer Verzögerung (1.2s — gibt User
    /// Zeit, den Rest-Timer-Start zu registrieren).
    @ViewBuilder
    private var paginatedBody: some View {
        if let day = session.day, !day.exercises.isEmpty {
            let exercises = orderedExercises(in: day)
            #if os(iOS)
            TabView(selection: $currentPageIndex) {
                ForEach(Array(exercises.enumerated()), id: \.offset) { idx, exercise in
                    ScrollView {
                        ExerciseCard(
                            exercise: exercise,
                            session: session,
                            onSetLogged: { setIndex in
                                startRestTimer(for: exercise, setIndex: setIndex)
                                maybeAutoAdvance(after: exercise, exercises: exercises, currentIndex: idx)
                            }
                        )
                        .padding()
                    }
                    .tag(idx)
                }
                // Finish-Page als letzte Tab
                ScrollView {
                    actionsCard
                        .padding()
                }
                .tag(exercises.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #else
            // macOS-Preview-Fallback: keine paginierte TabView, klassische
            // ScrollView-Liste.
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(exercises) { exercise in
                        ExerciseCard(
                            exercise: exercise,
                            session: session,
                            onSetLogged: { setIndex in
                                startRestTimer(for: exercise, setIndex: setIndex)
                            }
                        )
                    }
                    actionsCard
                }
                .padding()
            }
            #endif
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Diese Session hat keine Übungen.", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text("Vermutlich wurde der Plan-Tag nach dem Start geleert. Du kannst die Session verwerfen oder ohne Sätze beenden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                actionsCard
                    .padding(.horizontal)
                    .padding(.top, 12)
            }
        }
    }

    /// Wenn alle Saetze der aktuellen Uebung jetzt geloggt sind, swipe nach
    /// kurzer Pause auf die naechste Page. Gibt dem User Zeit, den Rest-Timer-
    /// Start visuell zu registrieren (kommt parallel als safeAreaInset).
    private func maybeAutoAdvance(after exercise: Exercise,
                                   exercises: [Exercise],
                                   currentIndex idx: Int) {
        let loggedSets = exercise.logs.filter { $0.session?.persistentModelID == session.persistentModelID }.count
        // Alle Saetze inkl. dem gerade geloggten sind durch?
        guard loggedSets >= exercise.sets else { return }
        // Bereits auf der letzten Page? Naechste waere die Finish-Page —
        // advance ist hier OK (zeigt automatisch Save/Discard).
        let nextIndex = idx + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPageIndex = nextIndex
            }
        }
    }

    private var actionsCard: some View {
        VStack(spacing: 8) {
            Button {
                showingFinishConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("active.action.save", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.green.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showingDiscardConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("active.action.discard", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                    .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Text("Set-Logging mit Vorgaben & Rest-Timer • Live Activities folgen im Xcode-Target.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: Derived

    private func orderedExercises(in day: TrainingDay) -> [Exercise] {
        day.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var formattedDuration: String {
        let elapsed = max(0, Int(now.timeIntervalSince(session.startTime)))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var loggedSetsCount: Int {
        session.logs.count
    }

    private func formatVolume() -> String {
        let total = session.logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return total.truncated(to: 0).formattedTwoDecimals
    }

    // MARK: Rest-timer

    /// `restSeconds == 0` is intentional (drop sets, supersets, rest-pause) — DO NOT
    /// auto-start a timer in that case. Otherwise cap at 600s (10 min) as a safety
    /// guard against typo'd 9000-second rests. Also drives the Live Activity, so
    /// the timer keeps running on the lock-screen and Dynamic Island when the user
    /// backgrounds the app.
    /// DEL-044: harter Reset zuerst. Wenn der User einen neuen Satz speichert,
    /// waehrend die Pause des vorigen Satzes noch laeuft (z.B. nach Skip), wird
    /// die alte Subscription invalidiert + die existing Activity beendet,
    /// BEVOR der neue Timer gesetzt wird. Garantiert: immer maximal ein
    /// laufender Timer pro Workout.
    private func startRestTimer(for exercise: Exercise, setIndex: Int) {
        // ── 1) Harter Reset des aktuellen In-App-Timers ─────────────────
        // Die `Timer.publish(every: 1, ...)` Subscription oben bleibt fix
        // (sie liefert nur den `now`-Tick); das eigentliche "Timer-State"
        // sitzt in restTimerEnd. Auf nil setzen blendet die RestTimerBar
        // aus + verhindert dass die alte Bar fuer einen Frame mit-rendert.
        restTimerEnd = nil
        restTimerOriginalSeconds = 0

        // ── 2) Harter Reset der Live-Activity ───────────────────────────
        // Synchron via Task — die Activity-Cleanup-Logik im neuen
        // startRestTimer beendet zusaetzlich alle stale activities,
        // aber wir cleanen hier defensive vorab.
        Task { await restTimerActivity.endRestTimer(reason: .skipped) }

        // ── 3) Validate + neuen Timer setzen ────────────────────────────
        let raw = exercise.restSeconds
        guard raw > 0 else { return }
        let bounded = min(raw, 600)
        let endDate = Date().addingTimeInterval(TimeInterval(bounded))

        restTimerOriginalSeconds = bounded
        restTimerEnd = endDate

        Task {
            await restTimerActivity.startRestTimer(
                exerciseName: exercise.name,
                setNumber: setIndex + 1,
                totalSets: exercise.sets,
                endDate: endDate,
                originalSeconds: bounded
            )
        }
    }

    // MARK: Lifecycle

    private func finishWorkout() {
        let endTime = Date()
        let logs = session.logs

        session.endTime = endTime
        session.durationMinutes = max(0, Int(endTime.timeIntervalSince(session.startTime) / 60))
        session.exerciseCount = session.day?.exercises.count ?? 0
        session.totalSets = logs.count
        session.totalVolumeKg = logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        session.isCompleted = true

        // Persist any newly-set PRs to the Trophy Room (`PersonalRecordEntry`).
        // Runs against all OTHER completed sessions in the store as history —
        // strict-greater-than only, so a tied session produces no rows.
        let detectedPRs = PersonalRecordSync.recordPRs(for: session, in: modelContext)

        // Push the workout to Apple Health as a strength-training session.
        // Best-effort: when HealthKit is unauthorised or unavailable, this is a
        // no-op. Captures startTime/endTime/totalSets/totalVolumeKg so the
        // Fitness app and Activity rings update without the user having to
        // re-log anything. Snapshotted now because session.* may mutate later.
        let workoutStart = session.startTime
        let workoutEnd = endTime
        let workoutSets = session.totalSets
        let workoutVolume = session.totalVolumeKg
        Task {
            await healthKit.saveWorkout(
                startDate: workoutStart,
                endDate: workoutEnd,
                totalSets: workoutSets,
                totalVolumeKg: workoutVolume
            )
        }

        // Clear any running rest timer (in-app + Live Activity). Branching:
        //   - PRs detected → push a final celebration state with trophy headline,
        //     fire a local notification (lock-screen banner), let the activity
        //     linger ~8s so the Dynamic Island shows the brag.
        //   - No PRs → quiet skip-dismiss as before.
        restTimerEnd = nil
        let celebration = PRCelebration.make(from: detectedPRs)
        Task { [celebration] in
            if let celebration {
                await restTimerActivity.endRestTimerWithPR(prMessage: celebration.activityLine)
                await prNotifications.scheduleCelebration(
                    title: celebration.title,
                    body: celebration.body
                )
            } else {
                await restTimerActivity.endRestTimer(reason: .skipped)
            }
        }

        // Push the summary onto the workout-tab navigation stack. The user reviews
        // the workout there and ends the flow with "Speichern & zum Dashboard".
        navigation.workoutPath.append(SummaryRoute(session: session))
    }

    private func discardWorkout() {
        Task { await restTimerActivity.endRestTimer(reason: .skipped) }
        modelContext.delete(session)
        dismiss()
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct StatBlock: View {
    let label: String
    let value: String
    var monospacedDigit: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .applyIf(monospacedDigit) { $0.monospacedDigit() }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, _ transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
#endif
