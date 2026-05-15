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
        // DEL-057: statt einem flachen Confirmation-Dialog jetzt ein
        // Half-Sheet, das den User nach dem subjektiven Session-Gefuehl
        // fragt. Das Feeling fliesst in den `ProgressionApplicator` ein:
        // Bei "Sehr schwer" oder "Zerstoert" wird jede `.increaseWeight`-
        // Action gevetoed.
        .sheet(isPresented: $showingFinishConfirm) {
            FinishWorkoutSheet(
                durationText: formattedDuration,
                setsCount: loggedSetsCount,
                volumeText: formatVolume(),
                onConfirm: { feeling in
                    showingFinishConfirm = false
                    session.sessionFeeling = feeling.rawValue
                    finishWorkout()
                },
                onCancel: { showingFinishConfirm = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

    /// DEL-061: dynamische Stats-Karte. Wenn ALLE aktiven Uebungen des Tages
    /// Cardio sind (z.B. Hybrid-Lauftag), zeigen wir die Lauf-Metriken
    /// statt der Kraft-Metriken. Mixed-Day-Edge-Case faellt auf den Strength-
    /// Header zurueck — in der Praxis sind Hybrid-Plaene single-purpose-Days.
    @ViewBuilder
    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBlock(label: "Dauer", value: formattedDuration, monospacedDigit: true)
            divider
            if isCardioSession {
                StatBlock(label: "Distanz", value: formatTotalDistance(), monospacedDigit: true)
                divider
                StatBlock(label: "⌀ Pace", value: formatAveragePace(), monospacedDigit: true)
            } else {
                StatBlock(label: "Sätze", value: "\(loggedSetsCount)", monospacedDigit: true)
                divider
                StatBlock(label: "Volumen kg", value: formatVolume(), monospacedDigit: true)
            }
        }
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .innerLightStroke(cornerRadius: 16, opacity: 0.08)
    }

    /// True wenn alle aktiven Uebungen des Tages Cardio-Lifts sind. Bei
    /// reinen Run-Sessions (Hybrid Easy Run / Long Run / Intervalle-Tage)
    /// trifft das zu — Mix-Tage fallen auf Strength-Default zurueck.
    private var isCardioSession: Bool {
        guard let exercises = session.day?.activeExercises, !exercises.isEmpty
        else { return false }
        return exercises.allSatisfy { $0.isCardio }
    }

    /// DEL-061: Summe aller `distanceKm` der Session-Logs. Format: "5,5 km".
    private func formatTotalDistance() -> String {
        let total = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        guard total > 0 else { return "—" }
        if total == total.rounded() {
            return "\(Int(total)) km"
        }
        return "\(total.truncated(to: 2).formattedTwoDecimals) km"
    }

    /// DEL-061: gewichtete Average-Pace ueber alle Cardio-Logs der Session.
    /// `total_seconds / total_km` → korrekt auch bei unterschiedlichen
    /// Splits pro Set.
    private func formatAveragePace() -> String {
        let totalKm = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        let totalSec = session.logs.compactMap(\.durationSeconds).reduce(0, +)
        guard totalKm > 0, totalSec > 0 else { return "—:——" }
        let pace = PaceCalculator.minutesPerKm(distanceKm: totalKm, durationSeconds: totalSec)
        // Wir wollen die "/km"-Suffix-Variante hier KOMPAKT — also Format
        // selbst kuerzen.
        guard let pace, pace > 0 else { return "—:——" }
        let totalSeconds = Int((pace * 60.0).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
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
        if let day = session.day, !day.activeExercises.isEmpty {
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

    /// DEL-049: filtert archivierte Urlaubs-Modus-Snapshots aus dem Active-
    /// Workout-Flow — sonst sieht der User bei Plan-Switch Geist-Uebungen
    /// in der TabView.
    private func orderedExercises(in day: TrainingDay) -> [Exercise] {
        day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
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
        session.exerciseCount = session.day?.activeExercises.count ?? 0
        session.totalSets = logs.count
        session.totalVolumeKg = logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        session.isCompleted = true

        // Persist any newly-set PRs to the Trophy Room (`PersonalRecordEntry`).
        // Runs against all OTHER completed sessions in the store as history —
        // strict-greater-than only, so a tied session produces no rows.
        let detectedPRs = PersonalRecordSync.recordPRs(for: session, in: modelContext)

        // DEL-052/053 — Smart Auto-Progression. Iteriert ueber die
        // Plan-Uebungen der Session, evaluiert pro Uebung "Double-Progression"
        // und schreibt das neue Ziel-Gewicht in `Exercise.suggestedWeight`.
        // Side-effects sind unkritisch fuer die nachfolgenden Steps —
        // PR-Sync + HealthKit-Push haben die Logs schon konsumiert.
        // Die `ProgressionApplicator`-Result wird IM SUMMARY-VIEW erneut
        // (read-only) berechnet, daher hier Discard.
        _ = ProgressionApplicator.apply(to: session, in: modelContext)

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

// MARK: - DEL-057 FinishWorkoutSheet

/// Half-Sheet, die beim Tappen auf "Training beenden" hochkommt. Zeigt die
/// Eckdaten (Dauer, Saetze, Volumen) und fragt das subjektive Session-
/// Gefuehl ab. Erst nach Auswahl + Tippen auf "Speichern" wird der
/// Workout-Finish-Pfad in `ActiveWorkoutView` durchgeschaltet — das Feeling
/// fliesst dann in den `ProgressionApplicator`-Veto-Check.
@available(iOS 17.0, macOS 14.0, *)
private struct FinishWorkoutSheet: View {
    let durationText: String
    let setsCount: Int
    let volumeText: String
    let onConfirm: (SessionFeeling) -> Void
    let onCancel: () -> Void

    /// Default-Selektion: Okay (3) — neutraler Mittelpunkt, der das
    /// Progression-Veto NICHT triggert. So crasht ein Default-Submit den
    /// Algorithmus nicht.
    @State private var selected: SessionFeeling = .okay

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    feelingSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Workout beenden")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dein Workout")
                .font(.headline)
            HStack(spacing: 0) {
                summaryStat(label: "Dauer", value: durationText)
                Divider().frame(height: 32)
                summaryStat(label: "Sätze", value: "\(setsCount)")
                Divider().frame(height: 32)
                summaryStat(label: "Volumen", value: "\(volumeText) kg")
            }
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wie hat sich das Training angefühlt?")
                .font(.headline)
            Text("Die App nutzt das fuer die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(SessionFeeling.allCases, id: \.self) { feeling in
                    feelingRow(feeling)
                }
            }
        }
    }

    private func feelingRow(_ feeling: SessionFeeling) -> some View {
        Button {
            selected = feeling
        } label: {
            HStack(spacing: 12) {
                Image(systemName: feeling.symbol)
                    .font(.title3)
                    .foregroundStyle(selected == feeling ? .white : Color.deltiqOrange)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(selected == feeling ? Color.deltiqOrange : Color.deltiqOrange.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(feeling.rawValue). \(feeling.label)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if feeling.vetoesProgression {
                        Text("Kein Gewichts-Plus im nächsten Workout")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selected == feeling {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected == feeling ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                            lineWidth: selected == feeling ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        Button {
            onConfirm(selected)
        } label: {
            HStack {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                Text("Workout speichern")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.deltiqOrange.gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
#endif
