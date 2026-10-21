#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import FitnessAppHealth

/// Player fuer Paket 2 (Laufcoach-Konzept, `WorkoutTimeFormat.
/// enduranceIntervals`): Einlaufen -> N x (Belastung/Erholung) -> Auslaufen.
/// Anders als `CircuitPlayerView` (eine ungezeitete Arbeitsphase + eine
/// gezeitete Pause) sind hier ALLE vier Abschnitte potenziell gezeitet -
/// nur die Belastungsphase kann je nach Konfiguration auch ungezeitet sein
/// (Strecken- oder offenes Ziel, `isWorkTimed`). Kein Uebungs-Bezug (anders
/// als Zirkel/AMRAP/EMOM): die Einheit selbst IST die Uebung (Laufen/
/// Radfahren), es gibt keine Pro-Runde-Uebungsliste zum Abhaken.
///
/// Peer zu `CircuitPlayerView` - eigene Datei aus demselben Grund (eigener
/// State fuer die Vier-Phasen-Logik).
@available(iOS 17.0, macOS 14.0, *)
struct EnduranceIntervalPlayerView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @Environment(\.scenePhase) private var scenePhase

    @State private var phase: EnduranceIntervalPhase = .warmup
    @State private var currentRoundNumber = 1
    @State private var roundsCompleted = 0
    @State private var phaseEndDate: Date?
    @State private var pausedRemainingSeconds: Int?
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false

    /// README 2.15/23b-23c: Vorlauf-Countdown, identisches Muster wie bei
    /// den anderen Playern.
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var background = TimedWorkoutBackgroundRun()

    /// Wie `CircuitPlayerView.init`: "Training fortsetzen" erzeugt eine
    /// komplett neue View-Instanz fuer dieselbe Session - `session.
    /// endurancePhase` ist `nil`, bis `finishPreroll()` es beim allerersten
    /// echten Start setzt, ein Nicht-nil-Wert beweist also "Vorlauf schon
    /// durchlaufen".
    init(session: WorkoutSession) {
        self.session = session
        if let existingPhase = session.endurancePhase {
            prerollTotal = 0
            _prerollRemaining = State(initialValue: 0)
            _phase = State(initialValue: existingPhase)
            _currentRoundNumber = State(initialValue: session.enduranceCurrentRoundNumber ?? 1)
            _roundsCompleted = State(initialValue: session.enduranceRoundsCompleted ?? 0)
            _phaseEndDate = State(initialValue: session.endurancePhaseEndDate)
            _pausedRemainingSeconds = State(initialValue: session.endurancePausedRemainingSeconds)
        } else {
            let stored = storedPrerollSeconds()
            prerollTotal = stored
            _prerollRemaining = State(initialValue: stored)
        }
    }

    // MARK: - Konfiguration (snapshot-first, siehe WorkoutSessionContentSnapshotFirst)

    private var totalRounds: Int { session.contentSnapshotEnduranceIntervalRounds ?? defaultEnduranceIntervalRounds() }
    private var warmupSeconds: Int { session.contentSnapshotEnduranceWarmupDurationSeconds ?? defaultEnduranceWarmupSeconds() }
    private var cooldownSeconds: Int { session.contentSnapshotEnduranceCooldownDurationSeconds ?? defaultEnduranceCooldownSeconds() }
    private var restSeconds: Int { session.contentSnapshotEnduranceRestDurationSeconds ?? defaultEnduranceRestDurationSeconds() }
    private var workDurationSeconds: Int? { session.contentSnapshotEnduranceWorkDurationSeconds }
    private var workDistanceKm: Double? { session.contentSnapshotEnduranceWorkDistanceKm }
    /// Keine automatische Distanz/Pace-Erfindung (Komponente 3): eine
    /// Belastungsphase ohne Zeit-Ziel ist ungezeitet, egal ob ein
    /// Strecken-Ziel gesetzt ist oder nicht - der User bestaetigt das Ende
    /// manuell ueber `workDoneBar`.
    private var isWorkTimed: Bool { workDurationSeconds != nil }

    private var currentPhaseTotalSeconds: Int {
        switch phase {
        case .warmup:   return max(1, warmupSeconds)
        case .rest:     return max(1, restSeconds)
        case .cooldown: return max(1, cooldownSeconds)
        case .work:     return max(1, workDurationSeconds ?? 1)
        }
    }

    private var pillLabel: String {
        String(localized: "timedWorkout.enduranceIntervals.pillLabel", bundle: .module)
    }

    private var phaseDisplayName: String {
        switch phase {
        case .warmup:   return String(localized: "timedWorkout.enduranceIntervals.warmup", bundle: .module)
        case .work:     return String(localized: "timedWorkout.enduranceIntervals.work", bundle: .module)
        case .rest:     return String(localized: "timedWorkout.enduranceIntervals.rest", bundle: .module)
        case .cooldown: return String(localized: "timedWorkout.enduranceIntervals.cooldown", bundle: .module)
        }
    }

    private var roundContextText: String {
        String(format: String(localized: "timedWorkout.circuit.roundContext", bundle: .module), currentRoundNumber, totalRounds).uppercased()
    }

    private var workTargetLabel: String {
        guard let km = workDistanceKm else {
            return String(localized: "timedWorkout.enduranceIntervals.openTarget", bundle: .module)
        }
        let value = km == km.rounded() ? "\(Int(km))" : km.truncated(to: 2).formattedTwoDecimals
        return "\(value) " + String(localized: "unit.km.lower", bundle: .module)
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: pillLabel.uppercased(),
                title: session.displayDayName,
                onBack: { dismiss() },
                actions: [sessionMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                if prerollRemaining > 0 {
                    timedWorkoutPrerollCard(remaining: prerollRemaining, total: prerollTotal)
                } else {
                    phaseContent
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if prerollRemaining > 0 {
                playPrerollTone(remaining: prerollRemaining, enabled: timerSoundEnabled)
                background.beginPreroll(soundEnabled: timerSoundEnabled)
            } else {
                startBackground()
            }
        }
        // Muss in jedem Ausstiegspfad laufen - identische Begruendung wie
        // `CircuitPlayerView.onDisappear`.
        .onDisappear {
            guard navigation.selectedTab == .plan else { return }
            background.end()
        }
        .onReceive(tick) { _ in
            if prerollRemaining > 0 {
                prerollRemaining -= 1
                if prerollRemaining == 0 {
                    finishPreroll()
                } else {
                    playPrerollTone(remaining: prerollRemaining, enabled: timerSoundEnabled)
                }
                return
            }
            guard !isFinished else { return }
            if timerSoundEnabled, pausedRemainingSeconds == nil, let remaining = remainingPhaseSeconds(), (1...10).contains(remaining) {
                TimerSoundPlayer.shared.playShort()
            }
            checkPhaseElapsed()
            syncBackground()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            checkPhaseElapsed()
            syncBackground(resend: true)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
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

    // MARK: - Hauptinhalt

    @ViewBuilder
    private var phaseContent: some View {
        if phase == .work || phase == .rest {
            DeltiqContextRow([
                DeltiqContextItem(phaseDisplayName.uppercased(), style: .accent),
                DeltiqContextItem(roundContextText, style: phase == .rest ? .neutral : .accent)
            ])
        } else {
            DeltiqContextRow([
                DeltiqContextItem(phaseDisplayName.uppercased(), style: .accent)
            ])
        }

        if let pausedRemainingSeconds {
            pausedPhaseCard(remainingSeconds: pausedRemainingSeconds)
        } else if phase == .work, !isWorkTimed {
            untimedWorkCard
        } else if let phaseEndDate {
            timedPhaseCard(endDate: phaseEndDate)
        }

        DeltiqSection {
            timedWorkoutHintRow(String(localized: String.LocalizationValue(stringLiteral: phaseHintKey), bundle: .module))
        }
    }

    private var phaseHintKey: String {
        switch phase {
        case .warmup:   return "timedWorkout.enduranceIntervals.warmupHint"
        case .cooldown: return "timedWorkout.enduranceIntervals.cooldownHint"
        case .rest:     return "timedWorkout.circuit.pauseHint"
        case .work:     return isWorkTimed ? "timedWorkout.enduranceIntervals.workTimedHint" : "timedWorkout.enduranceIntervals.workOpenHint"
        }
    }

    @ViewBuilder
    private func timedPhaseCard(endDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date).rounded(.up)))
            let total = currentPhaseTotalSeconds
            DeltiqCard(accentEdge: true) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.Deltiq.fill, lineWidth: 11)
                        Circle()
                            .trim(from: 0, to: total > 0 ? CGFloat(remaining) / CGFloat(total) : 0)
                            .stroke(Color.deltiqOrange, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(remaining)")
                            .font(.system(size: 56, weight: .heavy))
                            .fitnessNumberStyle()
                            .foregroundStyle(Color.primary)
                    }
                    .frame(width: 200, height: 200)
                    Text(phaseDisplayName)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func pausedPhaseCard(remainingSeconds: Int) -> some View {
        DeltiqCard(accentEdge: true) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.Deltiq.fill, lineWidth: 11)
                    Text("\(remainingSeconds)")
                        .font(.system(size: 56, weight: .heavy))
                        .fitnessNumberStyle()
                        .foregroundStyle(Color.primary)
                }
                .frame(width: 200, height: 200)
                Text("timedWorkout.enduranceIntervals.paused", bundle: .module)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Ungezeitete Belastung (Strecke/offen): kein Ring, keine erfundene
    /// Distanz/Pace - nur das konfigurierte Ziel als Info, bis der User
    /// manuell "Fertig" bestaetigt (`workDoneBar`).
    private var untimedWorkCard: some View {
        DeltiqCard(accentEdge: true) {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Color.primary)
                Text(workTargetLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - Fusszeile

    @ViewBuilder
    private var bottomBar: some View {
        if prerollRemaining > 0 {
            timedWorkoutPrerollStartBar { finishPreroll() }
        } else if phase == .work, !isWorkTimed {
            workDoneBar
        } else if pausedRemainingSeconds != nil {
            pausedActionBar
        } else {
            timedActionBar
        }
    }

    private var workDoneBar: some View {
        Button {
            advancePhase(skipped: false)
        } label: {
            Text("timedWorkout.enduranceIntervals.workDone", bundle: .module)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.plain)
        .background(Color.Deltiq.primaryGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.deltiqOrange.opacity(0.25), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    private var timedActionBar: some View {
        HStack(spacing: 12) {
            Button {
                pausePhase()
            } label: {
                Text("timedWorkout.enduranceIntervals.pause", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()

            Button {
                advancePhase(skipped: true)
            } label: {
                Text("timedWorkout.enduranceIntervals.skip", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    private var pausedActionBar: some View {
        HStack(spacing: 12) {
            Button {
                resumePhase()
            } label: {
                Text("timedWorkout.enduranceIntervals.resume", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()

            Button {
                advancePhase(skipped: true)
            } label: {
                Text("timedWorkout.enduranceIntervals.skip", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    /// Punkte-Menue, identisches Muster zu `CircuitPlayerView.sessionMenuAction`.
    private var sessionMenuAction: DeltiqHeaderAction {
        DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button {
                saveNow()
            } label: {
                Label {
                    Text("timedWorkout.finish.save", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
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

    // MARK: - Phasenlogik

    /// Uebergang von Vorlauf in den echten Lauf - `session.endurancePhase`
    /// ist bis hierher `nil`, `beginPhase(.warmup)` setzt ihn zuverlaessig.
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        roundsCompleted = 0
        session.enduranceRoundsCompleted = 0
        try? modelContext.save()
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        beginPhase(.warmup)
        startBackground()
    }

    /// Startet einen Abschnitt neu: setzt die Phase, berechnet (falls
    /// gezeitet) einen neuen Wanduhr-Anker und speichert sofort - identisches
    /// "nach jeder Mutation speichern"-Muster wie `CircuitPlayerView.
    /// beginRest()` (TestingBot-Regressionscheck Block B).
    private func beginPhase(_ newPhase: EnduranceIntervalPhase) {
        phase = newPhase
        session.endurancePhase = newPhase
        pausedRemainingSeconds = nil
        session.endurancePausedRemainingSeconds = nil
        if newPhase == .work {
            session.enduranceCurrentRoundNumber = currentRoundNumber
        }
        switch newPhase {
        case .warmup:
            phaseEndDate = Date().addingTimeInterval(TimeInterval(max(0, warmupSeconds)))
        case .rest:
            phaseEndDate = Date().addingTimeInterval(TimeInterval(max(1, restSeconds)))
        case .cooldown:
            phaseEndDate = Date().addingTimeInterval(TimeInterval(max(0, cooldownSeconds)))
        case .work:
            phaseEndDate = workDurationSeconds.map { Date().addingTimeInterval(TimeInterval($0)) }
        }
        session.endurancePhaseEndDate = phaseEndDate
        try? modelContext.save()
        DeltiqHaptics.notify(.warning)
        if timerSoundEnabled {
            TimerSoundPlayer.shared.playLong()
        }
        syncBackground()
    }

    /// Gemeinsamer Uebergangs-Pfad fuer natuerlich abgelaufene UND manuell
    /// beendete Abschnitte. `skipped` ist bei einer GEZEITETEN Phase immer
    /// `true`, wenn die Phase vor Ablauf manuell beendet wurde (der Timer
    /// haette sonst schon selbst `checkPhaseElapsed()` ausgeloest) - bei
    /// einer UNGEZEITETEN Belastungsphase bedeutet der manuelle "Fertig"-
    /// Knopf dagegen die regulaere, einzig moegliche Art, sie zu beenden
    /// (siehe `workDoneBar`), also `skipped: false` (Komponente 3: nur
    /// tatsaechlich uebersprungene Abschnitte duerfen nicht als vollstaendig
    /// absolviert gelten).
    private func advancePhase(skipped: Bool) {
        switch phase {
        case .warmup:
            session.enduranceWarmupSkipped = skipped
            beginPhase(.work)
        case .work:
            if !skipped {
                roundsCompleted += 1
                session.enduranceRoundsCompleted = roundsCompleted
            }
            try? modelContext.save()
            beginPhase(.rest)
        case .rest:
            if currentRoundNumber >= totalRounds {
                beginPhase(.cooldown)
            } else {
                currentRoundNumber += 1
                session.enduranceCurrentRoundNumber = currentRoundNumber
                beginPhase(.work)
            }
        case .cooldown:
            session.enduranceCooldownSkipped = skipped
            isFinished = true
            saveNow()
        }
    }

    private func pausePhase() {
        guard let phaseEndDate, pausedRemainingSeconds == nil else { return }
        let remaining = max(0, Int(phaseEndDate.timeIntervalSinceNow.rounded(.up)))
        pausedRemainingSeconds = remaining
        session.endurancePausedRemainingSeconds = remaining
        self.phaseEndDate = nil
        session.endurancePhaseEndDate = nil
        try? modelContext.save()
        DeltiqHaptics.notify(.success)
        syncBackground()
    }

    private func resumePhase() {
        guard let pausedRemainingSeconds else { return }
        let end = Date().addingTimeInterval(TimeInterval(pausedRemainingSeconds))
        phaseEndDate = end
        session.endurancePhaseEndDate = end
        self.pausedRemainingSeconds = nil
        session.endurancePausedRemainingSeconds = nil
        try? modelContext.save()
        DeltiqHaptics.notify(.success)
        syncBackground()
    }

    private func remainingPhaseSeconds(at now: Date = Date()) -> Int? {
        guard let phaseEndDate else { return nil }
        return max(0, Int(phaseEndDate.timeIntervalSince(now).rounded(.up)))
    }

    private func checkPhaseElapsed() {
        guard pausedRemainingSeconds == nil, let remaining = remainingPhaseSeconds() else { return }
        if remaining <= 0 {
            advancePhase(skipped: false)
        }
    }

    // MARK: - Hintergrund-Lauf (stilles Audio + Live Activity)

    private func startBackground() {
        background.begin(
            sessionKey: session.backgroundSessionKey,
            format: .enduranceIntervals,
            dayName: session.displayDayName,
            soundEnabled: timerSoundEnabled
        )
        syncBackground()
    }

    private func syncBackground(resend: Bool = false) {
        background.sync(
            TimedLiveContent.enduranceIntervals(
                anchor: session.startTime,
                currentPhase: phase,
                phaseEndDate: phaseEndDate,
                pausedRemainingSeconds: pausedRemainingSeconds,
                phaseDurationSeconds: currentPhaseTotalSeconds,
                roundNumber: currentRoundNumber,
                totalRounds: totalRounds,
                isFinished: isFinished,
                now: Date()
            ),
            resend: resend
        )
    }

    // MARK: - Speichern/Verwerfen

    private func saveNow() {
        session.endurancePhase = phase
        session.enduranceCurrentRoundNumber = currentRoundNumber
        session.enduranceRoundsCompleted = roundsCompleted
        session.completedTarget = isFinished
        session.timeFormatSnapshot = .enduranceIntervals
        finishTimedSession(
            session, modelContext: modelContext, healthKit: healthKit,
            prNotifications: prNotifications, navigation: navigation,
            prCelebrationsEnabled: prCelebrationsEnabled
        )
    }
}
#endif
