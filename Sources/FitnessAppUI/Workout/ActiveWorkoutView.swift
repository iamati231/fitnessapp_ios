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

    /// DEL-078: globaler PR-Celebration-Toggle aus Settings. Wenn false,
    /// skippen wir Save-Screen-Popups, Live-Activity-Linger und Notifications.
    /// PR-Detection selbst (Trophy-Room) bleibt unangetastet.
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true

    /// DEL-092: Globaler Opt-out fuer Warmup-/Cooldown-Uebungen. Wenn `false`,
    /// werden alle Uebungen mit `role == .warmup` oder `.cooldown` in der
    /// Active-Workout-Ansicht versteckt — der Paginator springt direkt zur
    /// ersten Working-Set-Uebung, die Stats-Karte zaehlt sie nicht mit, und
    /// auch HealthKit-Categorization beruecksichtigt nur das, was der User
    /// tatsaechlich macht.
    @AppStorage("pref_show_warmups") private var showWarmups: Bool = true

    /// DEL-086: Interference-Banner-Dismiss-State. User kann das Warn-Banner
    /// per Tap auf "x" wegklicken; persistiert nur fuer diese Session-View-
    /// Instanz (State, kein AppStorage — bei der naechsten Session
    /// soll's wieder erscheinen, wenn die Bedingungen erfuellt sind).
    @State private var interferenceWarningDismissed: Bool = false

    /// DEL-086: Recent-Cardio-Sessions fuer die Interference-Detection.
    /// FetchDescriptor mit Datums-Predikat auf die letzten 24 Stunden,
    /// nur isCompleted-Sessions.
    @Query private var recentSessions: [WorkoutSession]

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// DEL-039: aktuelle Page in der paginierten TabView. 0..N-1 sind die
    /// Uebungs-Pages, Page N ist die "Finish"-Seite mit Save/Discard.
    @State private var currentPageIndex: Int = 0

    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false

    /// DEL-096: In-Workout Exercise-Picker fuer Ad-Hoc-Sessions. Strenger
    /// gated als der DayEditor-Picker — kein Equipment-Konflikt-Dialog,
    /// kein Custom-Eintippen (Ad-Hoc soll schnell sein, der User waehlt
    /// aus der Library und legt los).
    @State private var showingAdHocPicker = false

    /// DEL-097: Session-weiter Single-Lock fuer time-based Halte-Timer.
    /// Nur EINE Time-Exercise (Plank, Wall Sit, ...) darf gleichzeitig
    /// laufen — sobald `startHolding()` in einer SetRow feuert, claimed
    /// sie diese Slot via `activeTimedExercise = exercise`. Andere
    /// SetRows blockieren ihren Start-Button so lange. Stoppen / Saetze
    /// abspeichern released den Slot wieder.
    /// Wichtig: Rein UI-State, NICHT persistiert — wenn die App killt
    /// werden Timer eh nicht resumed (sind `@State` in der Row), also
    /// muss der Lock auch nicht ueberleben.
    @State private var activeTimedExercise: Exercise?

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
        VStack(spacing: 8) {
            // DEL-086: Interference-Warning ueber dem Header. Banner zieht
            // sich aus, sobald der User es dismissed oder die Bedingungen
            // nicht erfuellt sind.
            interferenceBanner
                .padding(.horizontal)
                .padding(.top, 8)
            statsCard
                .padding(.horizontal)

            paginatedBody
        }
        .background(Color(.gray).opacity(0.04).ignoresSafeArea())
        .navigationTitle(session.dayName ?? "Training")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .keyboardDismissToolbar()
        // DEL-096: "+Übung"-Toolbar-Button waehrend einer non-empty
        // Ad-Hoc-Session — User darf jederzeit weitere Uebungen einschieben,
        // ohne den Workflow zu verlassen. Plan-Sessions kriegen den Button
        // bewusst NICHT: dort kommt die Uebungs-Liste aus dem Plan, und
        // mid-workout-Adds wuerden den Pagination-State (currentPageIndex)
        // unter den Fuessen wegrotieren.
        .toolbar {
            if session.isAdHoc, let day = session.day, !day.activeExercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdHocPicker = true
                    } label: {
                        Label("Übung", systemImage: "plus")
                    }
                }
            }
        }
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
                showGearPicker: isPureCardioSessionForHealthKit,
                onConfirm: { feeling, gear in
                    showingFinishConfirm = false
                    session.sessionFeeling = feeling.rawValue
                    // DEL-084: Gear zuweisen + Distanz auf Gear buchen.
                    if let gear, isPureCardioSessionForHealthKit {
                        session.gear = gear
                        let totalKm = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
                        gear.currentDistanceKm += totalKm
                    }
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
        // DEL-096: Ad-Hoc-Picker. Custom-Eintragen ist hier bewusst nicht
        // erlaubt — Library-Pick reicht, alles weitere lebt im DayEditor.
        .sheet(isPresented: $showingAdHocPicker) {
            ExercisePickerView(
                planEnvironment: nil,
                onSelect: { template in
                    addAdHocExercise(from: template)
                    showingAdHocPicker = false
                },
                onCreateCustom: { name in
                    addAdHocCustomExercise(named: name)
                    showingAdHocPicker = false
                }
            )
        }
        // DEL-096: Discard-Sweep. Wenn der User die Session verlaesst und
        // sie ad-hoc + leer + uncompleted ist, raeumen wir die emphemere
        // Session + den ephemeren TrainingDay weg — kein Schrott in der
        // History, kein verwaister Tag im Store.
        .onDisappear {
            sweepEmptyAdHocSession()
        }
    }

    // MARK: Sections

    /// DEL-061 + DEL-081: Stats-Karte mit drei States.
    ///   * pureCardio  → Dauer | Distanz | ⌀ Pace
    ///   * mixed       → Dauer | Volumen kg | Distanz km
    ///   * pureStrength → Dauer | Saetze | Volumen kg
    /// Mixed-Header zeigt allgemeine Werte beider Welten, ohne page-aware
    /// hin- und herzuspringen wenn der User durch die Day-Pages swipet —
    /// das wirkte vorher unruhig.
    @ViewBuilder
    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBlock(label: "Dauer", value: formattedDuration, monospacedDigit: true)
            divider
            switch dayCategory {
            case .pureCardio:
                StatBlock(label: "Distanz", value: formatTotalDistance(), monospacedDigit: true)
                divider
                StatBlock(label: "⌀ Pace", value: formatAveragePace(), monospacedDigit: true)
            case .mixed:
                StatBlock(label: "Volumen kg", value: formatVolume(), monospacedDigit: true)
                divider
                StatBlock(label: "Distanz km", value: formatTotalDistance(stripUnit: true), monospacedDigit: true)
            case .pureStrength:
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

    // MARK: - DEL-086 Hybrid-Interference-Banner

    /// True wenn der User in den letzten 24h eine harte Cardio-Einheit
    /// absolviert hat UND heute schwere Lower-Body-Compounds geplant sind.
    /// Logik in `InterferenceDetector` (Core, pure value-type).
    private var shouldShowInterferenceWarning: Bool {
        guard !interferenceWarningDismissed else { return false }
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date.distantPast
        let recentCardioTuples = recentSessions
            .filter { $0.isCompleted && !$0.isRestDay && $0.endTime >= cutoff }
            .filter { $0.persistentModelID != session.persistentModelID } // nicht die JETZT laufende
            .filter { $0.logs.contains { $0.resolvedIsCardio } }
            .map { sess -> (feeling: Int?, durationMin: Int, distanceKm: Double) in
                (feeling: sess.sessionFeeling,
                 durationMin: sess.durationMinutes,
                 distanceKm: sess.totalDistanceKm)
            }
        // DEL-092: Interference-Detection schaut nur auf das, was der User
        // tatsaechlich macht — gefilterte Warmup-Liste, falls Toggle off.
        let plannedNames = session.day.map { orderedExercises(in: $0).map(\.name) } ?? []
        return InterferenceDetector.shouldWarn(
            recentCardioSessions: recentCardioTuples,
            plannedExerciseNames: plannedNames
        )
    }

    /// Banner-View — DeltiqOrange, dismissable. Wird oberhalb der
    /// paginierten TabView angezeigt.
    @ViewBuilder
    private var interferenceBanner: some View {
        if shouldShowInterferenceWarning {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Du hattest gestern eine harte Einheit")
                        .font(.subheadline.weight(.semibold))
                    Text("Erwäge heute, dein Ziel-RIR bei Beinübungen um +1 zu erhöhen, um dein ZNS nicht zu überlasten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        interferenceWarningDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Banner schließen")
            }
            .padding(12)
            .background(Color.deltiqOrange.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .innerLightStroke(cornerRadius: 12, opacity: 0.08)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// DEL-081: Tages-Kategorie aus der Plan-Day-Komposition. Mixed-Day =
    /// mind. eine Cardio- UND mind. eine Strength-Uebung. Wir lesen das aus
    /// `day.activeExercises`, NICHT aus den geloggten Saetzen — sonst
    /// switcht der Header von "pureStrength" zu "mixed" mitten in der
    /// Session, sobald der User das erste Cardio-Set abhakt.
    private var dayCategory: SessionCategory {
        // DEL-092: respektiert Warmup-Filter — wenn der User Warmups off-toggled,
        // wird ein Hybrid-Day mit Run-Warmup + Strength als pureStrength
        // klassifiziert.
        guard let day = session.day else { return .pureStrength }
        let exercises = orderedExercises(in: day)
        guard !exercises.isEmpty else { return .pureStrength }
        let hasCardio = exercises.contains { $0.isCardio }
        let hasStrength = exercises.contains { !$0.isCardio }
        switch (hasStrength, hasCardio) {
        case (true, true):   return .mixed
        case (false, true):  return .pureCardio
        default:             return .pureStrength
        }
    }

    /// DEL-071: Paging-aware Cardio-Detection FUER DEN HEADER.
    ///   * Reiner Cardio-Day → immer Cardio-Header.
    ///   * Reiner Strength-Day → immer Strength-Header.
    ///   * Mixed-Day → Header reagiert auf die GERADE SICHTBARE Page
    ///     (`currentPageIndex`). Auf der Bankdruecken-Page = Strength-
    ///     Header, auf der Run-Page = Cardio-Header.
    private var isCardioSession: Bool {
        // DEL-092: nutzt orderedExercises(in:) statt direkter activeExercises,
        // damit Warmup-/Cooldown-Filter durchschlaegt.
        guard let day = session.day else { return false }
        let exercises = orderedExercises(in: day)
        guard !exercises.isEmpty else { return false }
        let allCardio = exercises.allSatisfy { $0.isCardio }
        let allStrength = exercises.allSatisfy { !$0.isCardio }
        if allCardio   { return true }
        if allStrength { return false }
        guard currentPageIndex >= 0, currentPageIndex < exercises.count else {
            return false
        }
        return exercises[currentPageIndex].isCardio
    }

    /// DEL-071 + DEL-063: Session-Level-Detection fuer den HealthKit-Push.
    /// Hier brauchen wir die kategorische Antwort "ist das Workout
    /// ueberwiegend Cardio?" — und konservativ heisst das `allSatisfy`,
    /// damit ein Mix-Day NICHT als `.running` in Apple Health landet.
    private var isPureCardioSessionForHealthKit: Bool {
        // DEL-092: respektiert Warmup-Filter — HealthKit-Categorization soll
        // das tracken, was der User tatsaechlich macht.
        guard let day = session.day else { return false }
        let exercises = orderedExercises(in: day)
        guard !exercises.isEmpty else { return false }
        return exercises.allSatisfy { $0.isCardio }
    }

    /// DEL-061: Summe aller `distanceKm` der Session-Logs. Format: "5,5 km".
    /// DEL-081: optional ohne "km"-Suffix (wenn das Label bereits "Distanz km"
    /// signalisiert — Mixed-Header).
    private func formatTotalDistance(stripUnit: Bool = false) -> String {
        let total = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        guard total > 0 else { return "—" }
        let valueStr: String = (total == total.rounded())
            ? "\(Int(total))"
            : total.truncated(to: 2).formattedTwoDecimals
        return stripUnit ? valueStr : "\(valueStr) km"
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
        // DEL-092: empty-check faellt jetzt auf das gefilterte Set —
        // wenn der User Warmups deaktiviert hat, aber ein Tag NUR Warmups
        // enthaelt, zeigen wir die Empty-State-Karte.
        if let day = session.day, !orderedExercises(in: day).isEmpty {
            let exercises = orderedExercises(in: day)
            #if os(iOS)
            TabView(selection: $currentPageIndex) {
                ForEach(Array(exercises.enumerated()), id: \.offset) { idx, exercise in
                    ScrollView {
                        ExerciseCard(
                            exercise: exercise,
                            session: session,
                            activeTimedExercise: $activeTimedExercise,
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
                            activeTimedExercise: $activeTimedExercise,
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
        } else if session.isAdHoc {
            // DEL-096: Empty-State fuer eine frisch gestartete Ad-Hoc-Session.
            // KEIN "Diese Session hat keine Uebungen"-Warnton — das ist hier
            // der erwartete Zustand. Stattdessen freundlicher Hero-CTA, der
            // direkt in den ExercisePicker springt.
            adHocEmptyState
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

    /// DEL-096: Hero-Empty-State fuer Ad-Hoc-Sessions ohne geloggte Uebungen.
    /// Primaerer CTA "Übung hinzufuegen" oeffnet den ExercisePicker.
    /// Sekundaerer Verwerfen-Link, falls der User es sich anders ueberlegt
    /// und gar nicht erst loslegen will — die `.onDisappear`-Sweep-Logik
    /// raeumt die Session dann automatisch weg.
    @ViewBuilder
    private var adHocEmptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)
                    .padding(.top, 40)

                VStack(spacing: 6) {
                    Text("Dein Workout ist noch leer")
                        .font(.title3.weight(.bold))
                    Text("Such dir aus der Library eine Übung — alles weitere passiert wie im Plan-Workout.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    showingAdHocPicker = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color.deltiqOrange.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Button(role: .destructive) {
                    showingDiscardConfirm = true
                } label: {
                    Text("Workout abbrechen")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 40)
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
        // DEL-092: Save-Button hat KEINE all-sets-completed-Gate — Warmups
        // (und auch nicht-abgehakte Working-Sets) duerfen den Abschluss
        // niemals blockieren. Es gibt valide Use-Cases ("ich bin warm,
        // ueberspring den Mobility-Block"), die wir nicht bestrafen wollen.
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
    /// DEL-092: zusaetzlich werden Warmup-/Cooldown-Uebungen unterdrueckt,
    /// wenn der User den `pref_show_warmups`-Toggle abgeschaltet hat. Single
    /// source of truth — alle Paginator-, Categorizer- und Auto-Advance-
    /// Pfade laufen ueber diese Funktion, damit der Toggle global wirkt.
    private func orderedExercises(in day: TrainingDay) -> [Exercise] {
        let active = day.activeExercises
        let visible = showWarmups
            ? active
            : active.filter { $0.role == .workingSet }
        return visible.sorted { $0.orderIndex < $1.orderIndex }
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
        // DEL-083: Superset-Hook. Wenn diese Uebung Teil einer Superset-Gruppe
        // ist, starten wir die Pause NUR wenn alle Partner-Uebungen den
        // aktuellen Set-Index auch schon abgehakt haben (A1 → B1 → Pause;
        // nicht: A1 → Pause → B1).
        if let supersetId = exercise.supersetId,
           !isSupersetRoundComplete(supersetId: supersetId, setIndex: setIndex) {
            // Partner-Uebung steht noch aus → kein Timer-Start, kein Live-
            // Activity-Push. User soll erstmal zur Partner-Page swipen.
            return
        }
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

    /// DEL-083: True wenn fuer alle Uebungen des Supersets der aktuelle
    /// Set-Index bereits geloggt ist. Vergleicht log-counts pro Plan-Uebung
    /// in der Session.
    private func isSupersetRoundComplete(supersetId: UUID, setIndex: Int) -> Bool {
        guard let day = session.day else { return true }
        let group = day.activeExercises.filter { $0.supersetId == supersetId }
        guard !group.isEmpty else { return true }
        let neededLoggedCount = setIndex + 1
        return group.allSatisfy { partner in
            let count = partner.logs.filter {
                $0.session?.persistentModelID == session.persistentModelID
            }.count
            return count >= neededLoggedCount
        }
    }

    // MARK: Lifecycle

    private func finishWorkout() {
        let endTime = Date()
        let logs = session.logs

        session.endTime = endTime
        session.durationMinutes = max(0, Int(endTime.timeIntervalSince(session.startTime) / 60))
        // DEL-092: zaehlt das, was der User tatsaechlich gemacht hat —
        // wenn Warmups versteckt waren, fliessen sie nicht in die History-Stat.
        session.exerciseCount = session.day.map { orderedExercises(in: $0).count } ?? 0
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

        // DEL-063: Push to Apple Health with the correct activity type.
        //   * Pure Cardio-Session (Hybrid Easy/Long/Intervall-Run) →
        //     `.running` + distance-sample, sodass Fitness-Ringe + Lauf-
        //     Statistiken stimmig sind.
        //   * Strength / Mixed → `.traditionalStrengthTraining` wie bisher.
        // Snapshot der relevanten Werte JETZT, weil session.* spaeter mutiert.
        let workoutStart = session.startTime
        let workoutEnd = endTime
        let workoutSets = session.totalSets
        let workoutVolume = session.totalVolumeKg
        let pushAsCardio = isPureCardioSessionForHealthKit
        let cardioTotalKm = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        let cardioTotalSec = session.logs.compactMap(\.durationSeconds).reduce(0, +)
        let cardioPace = PaceCalculator.minutesPerKm(
            distanceKm: cardioTotalKm,
            durationSeconds: cardioTotalSec
        )
        Task {
            if pushAsCardio, cardioTotalKm > 0 {
                await healthKit.saveRunningWorkout(
                    startDate: workoutStart,
                    endDate: workoutEnd,
                    totalDistanceKm: cardioTotalKm,
                    averagePaceMinPerKm: cardioPace
                )
            } else {
                await healthKit.saveWorkout(
                    startDate: workoutStart,
                    endDate: workoutEnd,
                    totalSets: workoutSets,
                    totalVolumeKg: workoutVolume
                )
            }
        }

        // Clear any running rest timer (in-app + Live Activity). Branching:
        //   - PRs detected + Celebrations on → push final state with trophy
        //     headline, fire a local notification, let the activity linger ~8s.
        //   - PRs detected + Celebrations off (DEL-078) → quiet skip-dismiss,
        //     der Trophy-Room bleibt aber gefuellt fuer den User, der's
        //     spaeter aktiv anschauen will.
        //   - No PRs → quiet skip-dismiss as before.
        restTimerEnd = nil
        let celebration = prCelebrationsEnabled
            ? PRCelebration.make(from: detectedPRs)
            : nil
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
        // DEL-096: Ad-Hoc-Sessions schleppen einen ephemeren TrainingDay
        // mit sich — der muss bei Discard mit weg, sonst bleibt ein
        // verwaister Tag mit `plan: nil` im Store zurueck.
        let adHocDay = session.isAdHoc ? session.day : nil
        modelContext.delete(session)
        if let adHocDay {
            modelContext.delete(adHocDay)
        }
        dismiss()
    }

    // MARK: - DEL-096 Ad-Hoc-Workflow

    /// Fuegt eine Library-Uebung als neue `Exercise` zum ephemeren
    /// Ad-Hoc-TrainingDay hinzu. ActiveWorkoutView re-rendert automatisch,
    /// sobald der `day.activeExercises`-Array wieder non-empty ist —
    /// SwiftData reactivity macht den Rest.
    private func addAdHocExercise(from template: ExerciseTemplate) {
        guard let day = session.day else { return }
        let exercise = Exercise(
            name: template.name,
            orderIndex: day.activeExercises.count,
            isCardio: template.isCardio,
            isTimeBased: template.isTimeBased,
            isCompound: template.isSystemCompound,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// Custom-Uebung im Ad-Hoc-Flow — analog zu `DayEditorView.addCustomExercise`.
    /// Legt ein neues `ExerciseTemplate` (`isCustom: true`) in der Library
    /// an, damit die Uebung beim naechsten Picker-Open auswaehlbar bleibt.
    private func addAdHocCustomExercise(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let day = session.day else { return }

        let template = ExerciseTemplate(
            name: trimmed,
            equipment: .barbell,
            primaryMuscle: .chest,
            isCustom: true
        )
        modelContext.insert(template)

        let exercise = Exercise(
            name: trimmed,
            orderIndex: day.activeExercises.count,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// Discard-Sweep: wenn die Session ad-hoc ist, keine Logs hat und
    /// nicht als abgeschlossen markiert wurde, raeumen wir sie auf —
    /// inklusive ephemeres TrainingDay. Verhindert "0 Sätze · 0 kg"-Ghost-
    /// Eintraege in der History, wenn der User nur kurz reingeschaut und
    /// wieder rausnavigiert hat.
    private func sweepEmptyAdHocSession() {
        guard session.isAdHoc,
              !session.isCompleted,
              session.logs.isEmpty
        else { return }
        let day = session.day
        modelContext.delete(session)
        if let day { modelContext.delete(day) }
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
    /// DEL-084: Gear-Picker nur einblenden bei Cardio-Sessions — bei Strength
    /// hat ein "Laufschuh-Picker" keinen Sinn.
    var showGearPicker: Bool = false
    /// DEL-084: onConfirm liefert jetzt zusaetzlich das gewaehlte Gear (nil
    /// bei Strength-Sessions oder wenn User keine Schuhe pflegt).
    let onConfirm: (SessionFeeling, Gear?) -> Void
    let onCancel: () -> Void

    /// Default-Selektion: Okay (3) — neutraler Mittelpunkt, der das
    /// Progression-Veto NICHT triggert. So crasht ein Default-Submit den
    /// Algorithmus nicht.
    @State private var selected: SessionFeeling = .okay
    @State private var selectedGear: Gear?

    /// DEL-084: Aktive Gears aus dem Store. Bei Default-Pick nehmen wir
    /// das Gear mit `isActive == true`, sortiert nach Datum descending
    /// (zuletzt-erstellte zuerst).
    @Query(filter: #Predicate<Gear> { $0.isActive == true },
           sort: \Gear.createdAt, order: .reverse)
    private var activeGears: [Gear]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    feelingSection
                    if showGearPicker, !activeGears.isEmpty {
                        gearPickerSection
                    }
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
            .onAppear {
                // Default: zuletzt-genutzten aktiven Schuh vorauswaehlen.
                if selectedGear == nil {
                    selectedGear = activeGears.first
                }
            }
        }
    }

    /// DEL-084: Gear-Picker. Listet aktive Gears, Selected-Indicator via
    /// Checkmark. User kann "Kein Gear" waehlen (selectedGear = nil).
    private var gearPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verwendete Ausrüstung")
                .font(.headline)
            ForEach(activeGears) { gear in
                Button {
                    selectedGear = (selectedGear?.persistentModelID == gear.persistentModelID) ? nil : gear
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: gear.type == .shoe ? "shoe" : "bicycle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.deltiqOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gear.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(formatKm(gear.currentDistanceKm)) / \(formatKm(gear.maxDistanceKm)) km")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(gear.needsReplacement ? .red : .secondary)
                        }
                        Spacer()
                        if selectedGear?.persistentModelID == gear.persistentModelID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.deltiqOrange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedGear?.persistentModelID == gear.persistentModelID
                                    ? Color.deltiqOrange
                                    : Color.secondary.opacity(0.25),
                                    lineWidth: selectedGear?.persistentModelID == gear.persistentModelID ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 0).formattedTwoDecimals
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
            onConfirm(selected, selectedGear)
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
