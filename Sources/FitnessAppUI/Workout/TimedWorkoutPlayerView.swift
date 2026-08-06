#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import FitnessAppHealth

/// Player fuer AMRAP/EMOM/Auf-Zeit-Tage (README 2.9, Nachtrag 6. August).
/// "Ein Player mit drei Zeitbloecken, nicht drei Screens" - Kopfzone,
/// Kontextzeile, Zeitblock mit Akzent-Kante, Arbeitskarte und feste Leiste
/// unten sind bei allen drei Formaten gleich, nur der Zeitblock und die
/// Leiste unterscheiden sich.
///
/// Peer zu `ActiveWorkoutView`, nicht ein Modus darin: `WorkoutRootView`
/// waehlt anhand `session.day?.timeFormat`, welcher der beiden Player
/// gerendert wird, bevor irgendeine Seite ueberhaupt entsteht.
@available(iOS 17.0, macOS 14.0, *)
public struct TimedWorkoutPlayerView: View {
    @Bindable public var session: WorkoutSession

    public init(session: WorkoutSession) {
        self.session = session
    }

    public var body: some View {
        switch session.day?.timeFormat {
        case .amrap:   AMRAPPlayerView(session: session)
        case .emom:    EMOMPlayerView(session: session)
        case .forTime: ForTimePlayerView(session: session)
        case nil:      EmptyView()   // WorkoutRootView routet hierher nur mit gesetztem Format.
        }
    }
}

// MARK: - Gemeinsamer Finish-/Discard-Pfad

/// Analog zu `ActiveWorkoutView.finishWorkout()`, aber reduziert auf das,
/// was fuer einen Zeitformat-Tag Sinn ergibt: kein `ProgressionApplicator`
/// (keine Ziel-Gewichte bei AMRAP/EMOM/Auf Zeit), kein Ad-Hoc-/Interference-
/// Handling (Zeitformat-Tage sind reine Plan-Tage, kein Rest-Timer). PR-
/// Detection, HealthKit-Push und Summary-Navigation bleiben gleich. Caller
/// setzt das format-spezifische Ergebnisfeld + `timeFormatSnapshot` auf
/// `session`, BEVOR diese Funktion aufgerufen wird.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
private func finishTimedSession(
    _ session: WorkoutSession,
    modelContext: ModelContext,
    healthKit: HealthKitController,
    prNotifications: PRNotificationCenter,
    navigation: AppNavigation,
    prCelebrationsEnabled: Bool
) {
    DeltiqHaptics.notify(.success)

    let endTime = Date()
    session.endTime = endTime
    session.durationMinutes = max(0, Int(endTime.timeIntervalSince(session.startTime) / 60))
    session.isCompleted = true
    // Sonst bleibt's beim init-Default 0 - ActiveWorkoutView.finishWorkout()
    // setzt das analog aus der Plan-Uebungsliste (siehe dort), Zeitformat-
    // Tage haben aber nie ExerciseLogs, aus denen es sich sonst herleiten liesse.
    session.exerciseCount = session.day?.activeExercises.count ?? 0

    let detectedPR = PersonalRecordSync.recordTimedFormatPR(for: session, in: modelContext)
    let celebration = prCelebrationsEnabled
        ? PRCelebration.make(from: detectedPR.map { [$0] } ?? [])
        : nil

    let workoutStart = session.startTime
    Task {
        // Kein Set-/Volumen-Logging bei Zeitformaten - Dauer ist das
        // aussagekraeftige Signal fuer Apple Health.
        await healthKit.saveWorkout(startDate: workoutStart, endDate: endTime, totalSets: 0, totalVolumeKg: 0)
        if let celebration {
            await prNotifications.scheduleCelebration(title: celebration.title, body: celebration.body)
        }
    }

    navigation.workoutPath.append(SummaryRoute(session: session))
}

/// Loescht eine noch nicht abgeschlossene Zeitformat-Session (Abbrechen-Pfad
/// im Ellipsis-Menu). Zeitformat-Tage sind reine Plan-Tage, kein Ad-Hoc-
/// TrainingDay zum Mitloeschen wie bei `ActiveWorkoutView.discardWorkout()`.
@MainActor
private func discardTimedSession(_ session: WorkoutSession, modelContext: ModelContext, dismiss: DismissAction) {
    modelContext.delete(session)
    dismiss()
}

@available(iOS 17.0, macOS 14.0, *)
private func timedWorkoutHintRow(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 12))
        .foregroundStyle(Color.Deltiq.textSecondary)
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
}

/// "N Wdh." fuer normale Zirkel-Uebungen, "N Sek." fuer `isTimeBased`
/// (z.B. Plank in einem EMOM-Zirkel, README 2.9 Phase 6) - `repsMin` wird
/// bei Zeitformaten als "Wdh./Sek. pro Runde" reused (siehe DaySpec/
/// TrainingDay-Kommentar), keine neuen Felder dafuer noetig. Geteilt
/// zwischen allen drei Playern + WorkoutSummaryView (interne, nicht
/// `private` Sichtbarkeit).
@available(iOS 17.0, macOS 14.0, *)
func timedFormatTargetLabel(_ exercise: Exercise) -> String {
    exercise.isTimeBased
        ? "\(exercise.repsMin) " + String(localized: "unit.seconds.short", bundle: .module)
        : "\(exercise.repsMin) " + String(localized: "unit.reps.short", bundle: .module)
}

// MARK: - AMRAP

@available(iOS 17.0, macOS 14.0, *)
private struct AMRAPPlayerView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true

    @State private var elapsedSeconds = 0
    @State private var roundsCompleted = 0
    @State private var partialReps = 0
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var day: TrainingDay? { session.day }
    private var exercises: [Exercise] {
        (day?.activeExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
    private var capSeconds: Int { max(1, (day?.timeCapMinutes ?? 20)) * 60 }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: "AMRAP",
                title: session.displayDayName,
                onBack: { dismiss() },
                actions: [discardMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                DeltiqContextRow([
                    DeltiqContextItem("AMRAP", style: .accent),
                    DeltiqContextItem(
                        String(format: String(localized: "timedWorkout.amrap.capContext", bundle: .module), (day?.timeCapMinutes ?? 20)).uppercased(),
                        style: .neutral
                    )
                ])

                DeltiqCard(accentEdge: true) {
                    VStack(spacing: 8) {
                        Text(PaceCalculator.formatDuration(max(0, capSeconds - elapsedSeconds)))
                            .font(.system(size: 64, weight: .heavy))
                            .fitnessNumberStyle()
                            .foregroundStyle(Color.primary)
                        ProgressView(value: Double(min(elapsedSeconds, capSeconds)), total: Double(capSeconds))
                            .tint(Color.deltiqOrange)
                        Text(
                            String(
                                format: String(localized: "timedWorkout.elapsed", bundle: .module),
                                PaceCalculator.formatDuration(elapsedSeconds)
                            )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                DeltiqSection {
                    ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                        DeltiqRow(
                            label: exercise.displayName,
                            value: timedFormatTargetLabel(exercise),
                            showsDivider: index != exercises.count - 1
                        )
                    }
                    timedWorkoutHintRow(String(localized: "timedWorkout.amrap.circuitHint", bundle: .module))
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .onReceive(tick) { _ in
            guard !isFinished else { return }
            guard elapsedSeconds < capSeconds else { return }
            elapsedSeconds += 1
            if elapsedSeconds >= capSeconds {
                isFinished = true
                DeltiqHaptics.notify(.success)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isFinished {
                finishBar
            } else {
                roundBar
            }
        }
        .confirmationDialog(
            String(localized: "timedWorkout.discard.confirmTitle", bundle: .module),
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                discardTimedSession(session, modelContext: modelContext, dismiss: dismiss)
            } label: {
                Text("timedWorkout.discard.confirmButton", bundle: .module)
            }
        }
    }

    private var discardMenuAction: DeltiqHeaderAction {
        DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button(role: .destructive) {
                showingDiscardConfirm = true
            } label: {
                Label {
                    Text("timedWorkout.discard.menu", bundle: .module)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
            }
        })
    }

    private var roundBar: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(roundsCompleted)")
                    .font(.system(size: 22, weight: .heavy))
                    .fitnessNumberStyle()
                    .foregroundStyle(Color.primary)
                Text("timedWorkout.amrap.roundsLabel", bundle: .module)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .frame(width: 76, height: 56)
            .background(Color.Deltiq.fill)
            .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))

            Button {
                roundsCompleted += 1
                DeltiqHaptics.notify(.success)
            } label: {
                Text("timedWorkout.amrap.addRound", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    private var finishBar: some View {
        VStack(spacing: 10) {
            DeltiqControlRow(label: String(localized: "timedWorkout.amrap.partialReps", bundle: .module)) {
                Stepper(value: $partialReps, in: 0...999) {
                    Text("\(partialReps)")
                        .fitnessNumberStyle()
                }
                .labelsHidden()
            }
            Button {
                session.roundsCompleted = roundsCompleted
                session.partialReps = partialReps
                session.timeFormatSnapshot = .amrap
                finishTimedSession(
                    session, modelContext: modelContext, healthKit: healthKit,
                    prNotifications: prNotifications, navigation: navigation,
                    prCelebrationsEnabled: prCelebrationsEnabled
                )
            } label: {
                Text("timedWorkout.finish.save", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - EMOM

@available(iOS 17.0, macOS 14.0, *)
private struct EMOMPlayerView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true

    @State private var currentMinute = 1          // 1-basiert
    @State private var secondsIntoMinute = 0      // 0..59
    @State private var completedMinutes: Set<Int> = []
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var day: TrainingDay? { session.day }
    private var exercises: [Exercise] {
        (day?.activeExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
    private var totalMinutes: Int { max(1, day?.timeCapMinutes ?? 12) }
    /// Bei mehr Minuten als Uebungen wiederholt sich der Zirkel (z.B. 2
    /// Uebungen ueber 12 Minuten = 6 Durchgaenge).
    private var currentExercise: Exercise? {
        guard !exercises.isEmpty else { return nil }
        return exercises[(currentMinute - 1) % exercises.count]
    }
    private var nextExercise: Exercise? {
        guard !exercises.isEmpty, currentMinute < totalMinutes else { return nil }
        return exercises[currentMinute % exercises.count]
    }
    private var remainingInMinute: Int { max(0, 60 - secondsIntoMinute) }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: "EMOM",
                title: session.displayDayName,
                onBack: { dismiss() },
                actions: [discardMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                DeltiqContextRow([
                    DeltiqContextItem("EMOM", style: .accent),
                    DeltiqContextItem(
                        String(
                            format: String(localized: "timedWorkout.emom.minuteContext", bundle: .module),
                            min(currentMinute, totalMinutes), totalMinutes
                        ).uppercased(),
                        style: .neutral
                    )
                ])

                DeltiqCard(accentEdge: true) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.Deltiq.fill, lineWidth: 11)
                            Circle()
                                .trim(from: 0, to: CGFloat(remainingInMinute) / 60.0)
                                .stroke(Color.deltiqOrange, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(remainingInMinute)")
                                    .font(.system(size: 56, weight: .heavy))
                                    .fitnessNumberStyle()
                                    .foregroundStyle(Color.primary)
                                Text("timedWorkout.emom.thisMinute", bundle: .module)
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(1.0)
                                    .foregroundStyle(Color.Deltiq.textSecondary)
                            }
                        }
                        .frame(width: 200, height: 200)

                        if let currentExercise {
                            Text(currentExercise.displayName)
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.center)
                            Text(timedFormatTargetLabel(currentExercise))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if let nextExercise {
                    DeltiqSection {
                        DeltiqRow(
                            label: nextExercise.displayName,
                            subtitle: String(localized: "timedWorkout.emom.nextMinute", bundle: .module),
                            value: timedFormatTargetLabel(nextExercise),
                            showsDivider: false
                        )
                    }
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // README 2.9 Phase 4: Alle Minutentrigger im Voraus planen, nicht
        // erst reaktiv beim Minutenwechsel - Timer.publish unten pausiert
        // sobald die App backgrounded wird, es gibt also keine Gelegenheit
        // mehr, waehrend des Trainings nachzuplanen. Gated ueber denselben
        // Pref wie der In-App-Ton (wer den ausgeschaltet hat, will
        // vermutlich auch keine Notification-Toene).
        .task {
            guard timerSoundEnabled else { return }
            await ReminderScheduler.scheduleEMOMSignals(
                totalMinutes: totalMinutes,
                minuteTitle: "EMOM",
                minuteBodyFormat: String(localized: "timedWorkout.emom.notification.nextMinute", bundle: .module),
                finishTitle: "EMOM",
                finishBody: String(localized: "timedWorkout.emom.notification.complete", bundle: .module)
            )
        }
        .onDisappear {
            // Muss in JEDEM Ausstiegspfad laufen (Finish, Discard, Zurueck-
            // Chevron) - sonst poppen spaeter Banner fuer eine laengst
            // verlassene Session auf.
            Task { await ReminderScheduler.cancelEMOMSignals() }
        }
        .onReceive(tick) { _ in
            guard !isFinished else { return }
            // Drei Signaltoene ab 0:03, Blick bleibt auf der Hantel.
            if timerSoundEnabled, (1...3).contains(remainingInMinute) {
                TimerSoundPlayer.shared.playShort()
            }
            secondsIntoMinute += 1
            if secondsIntoMinute >= 60 {
                secondsIntoMinute = 0
                if currentMinute >= totalMinutes {
                    isFinished = true
                    DeltiqHaptics.notify(.success)
                } else {
                    currentMinute += 1
                    if timerSoundEnabled { TimerSoundPlayer.shared.playLong() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isFinished {
                finishBar
            } else {
                doneBar
            }
        }
        .confirmationDialog(
            String(localized: "timedWorkout.discard.confirmTitle", bundle: .module),
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                discardTimedSession(session, modelContext: modelContext, dismiss: dismiss)
            } label: {
                Text("timedWorkout.discard.confirmButton", bundle: .module)
            }
        }
    }

    private var discardMenuAction: DeltiqHeaderAction {
        DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button(role: .destructive) {
                showingDiscardConfirm = true
            } label: {
                Label {
                    Text("timedWorkout.discard.menu", bundle: .module)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
            }
        })
    }

    /// Tippen markiert die LAUFENDE Minute als geschafft - ein einzelner
    /// Tap-Bereich pro Zeiteinheit, gleiches Interaktionsmuster wie AMRAPs
    /// "+1 Runde".
    private var doneBar: some View {
        Button {
            if completedMinutes.insert(currentMinute).inserted {
                DeltiqHaptics.notify(.success)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: completedMinutes.contains(currentMinute) ? "checkmark.circle.fill" : "checkmark.circle")
                Text("timedWorkout.emom.markDone", bundle: .module)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    private var finishBar: some View {
        Button {
            session.completedMinuteCount = completedMinutes.count
            session.timeFormatSnapshot = .emom
            finishTimedSession(
                session, modelContext: modelContext, healthKit: healthKit,
                prNotifications: prNotifications, navigation: navigation,
                prCelebrationsEnabled: prCelebrationsEnabled
            )
        } label: {
            Text("timedWorkout.finish.save", bundle: .module)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Auf Zeit (For Time)

@available(iOS 17.0, macOS 14.0, *)
private struct ForTimePlayerView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true

    @State private var elapsedSeconds = 0
    @State private var checkedRounds: [PersistentIdentifier: Int] = [:]
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var day: TrainingDay? { session.day }
    private var exercises: [Exercise] {
        (day?.activeExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
    /// Optionaler Abbruch-Deckel - anders als AMRAP/EMOM ist bei Auf Zeit
    /// meist gar keiner gesetzt, das Pensum selbst beendet den Lauf.
    private var capSeconds: Int? { day?.timeCapMinutes.map { $0 * 60 } }
    private var totalBoxes: Int { exercises.reduce(0) { $0 + max($1.sets, 1) } }
    private var checkedBoxes: Int {
        exercises.reduce(0) { $0 + (checkedRounds[$1.persistentModelID] ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: pillLabel.uppercased(),
                title: session.displayDayName,
                onBack: { dismiss() },
                actions: [discardMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                DeltiqContextRow([
                    DeltiqContextItem(pillLabel.uppercased(), style: .accent),
                    DeltiqContextItem(
                        String(
                            format: String(localized: "timedWorkout.forTime.progressContext", bundle: .module),
                            checkedBoxes, totalBoxes
                        ).uppercased(),
                        style: .neutral
                    )
                ])

                DeltiqCard(accentEdge: true) {
                    VStack(spacing: 4) {
                        Text(PaceCalculator.formatDuration(elapsedSeconds))
                            .font(.system(size: 64, weight: .heavy))
                            .fitnessNumberStyle()
                            .foregroundStyle(Color.primary)
                        if isFinished {
                            Text("timedWorkout.forTime.finishedLabel", bundle: .module)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.Deltiq.success)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                DeltiqSection {
                    ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                        exerciseRoundsRow(exercise)
                        if index != exercises.count - 1 {
                            Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                        }
                    }
                    if isLastBoxRemainingHintVisible {
                        timedWorkoutHintRow(String(localized: "timedWorkout.forTime.lastRoundHint", bundle: .module))
                    }
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .onReceive(tick) { _ in
            guard !isFinished else { return }
            elapsedSeconds += 1
            if let capSeconds, elapsedSeconds >= capSeconds {
                isFinished = true
                DeltiqHaptics.notify(.success)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isFinished {
                finishBar
            }
        }
        .confirmationDialog(
            String(localized: "timedWorkout.discard.confirmTitle", bundle: .module),
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                discardTimedSession(session, modelContext: modelContext, dismiss: dismiss)
            } label: {
                Text("timedWorkout.discard.confirmButton", bundle: .module)
            }
        }
    }

    private var pillLabel: String {
        String(localized: "timedWorkout.forTime.pillLabel", bundle: .module)
    }

    private var discardMenuAction: DeltiqHeaderAction {
        DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button(role: .destructive) {
                showingDiscardConfirm = true
            } label: {
                Label {
                    Text("timedWorkout.discard.menu", bundle: .module)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
            }
        })
    }

    private var isLastBoxRemainingHintVisible: Bool {
        totalBoxes > 0 && checkedBoxes == totalBoxes - 1
    }

    private func exerciseRoundsRow(_ exercise: Exercise) -> some View {
        let rounds = max(exercise.sets, 1)
        let checked = checkedRounds[exercise.persistentModelID] ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                Text(timedFormatTargetLabel(exercise))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            HStack(spacing: 6) {
                ForEach(0..<rounds, id: \.self) { roundIndex in
                    Button {
                        toggleRound(roundIndex, for: exercise)
                    } label: {
                        Image(systemName: roundIndex < checked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(roundIndex < checked ? Color.Deltiq.success : Color.Deltiq.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinished)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Haekchen sind sequentiell pro Uebung (kein wahlfreier Zugriff): ein
    /// Tap auf Index N markiert alle Runden bis N als erledigt bzw. nimmt
    /// bei einem bereits abgehakten Index alles ab N wieder zurueck.
    private func toggleRound(_ tappedIndex: Int, for exercise: Exercise) {
        let current = checkedRounds[exercise.persistentModelID] ?? 0
        checkedRounds[exercise.persistentModelID] = tappedIndex < current ? tappedIndex : tappedIndex + 1
        DeltiqHaptics.notify(.success)
        if checkedBoxes == totalBoxes {
            isFinished = true
        }
    }

    private var finishBar: some View {
        Button {
            session.finishTimeSeconds = elapsedSeconds
            session.timeFormatSnapshot = .forTime
            finishTimedSession(
                session, modelContext: modelContext, healthKit: healthKit,
                prNotifications: prNotifications, navigation: navigation,
                prCelebrationsEnabled: prCelebrationsEnabled
            )
        } label: {
            Text("timedWorkout.finish.save", bundle: .module)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }
}
#endif
