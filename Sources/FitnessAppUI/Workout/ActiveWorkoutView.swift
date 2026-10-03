#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import FitnessAppHealth

/// DEL-108: Set-Level-Identifier fuer den Time-Exercise-Lock. Loest die
/// DEL-097-Regression: vorher hat der Lock nur die Exercise-Identitaet
/// gespeichert, sodass mehrere Saetze derselben Uebung (z.B. Plank Satz 1
/// + Satz 2) parallel starten konnten. Jetzt ist der Lock-Key kombiniert
/// aus exerciseID UND setIndex — same-exercise different-set wird genauso
/// blockiert wie cross-exercise.
///
/// `exerciseName` ist denormalisiert fuer den Blocked-Hint im UI; geht
/// NICHT in Equality/Hashing ein, damit Renames der Live-Exercise nicht
/// versehentlich den Lock zerschiessen.
@available(iOS 17.0, macOS 14.0, *)
public struct ActiveTimedSetID: Hashable, Sendable {
    public let exerciseID: PersistentIdentifier
    public let setIndex: Int
    public let exerciseName: String

    public init(exerciseID: PersistentIdentifier, setIndex: Int, exerciseName: String) {
        self.exerciseID = exerciseID
        self.setIndex = setIndex
        self.exerciseName = exerciseName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(exerciseID)
        hasher.combine(setIndex)
    }

    public static func == (lhs: ActiveTimedSetID, rhs: ActiveTimedSetID) -> Bool {
        lhs.exerciseID == rhs.exerciseID && lhs.setIndex == rhs.setIndex
    }
}

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

    /// DEL-204: gleiche Keys wie RestTimerBar/Settings — gaten die
    /// Background-Notification fürs Timer-Ende. Beide aus = kein Banner.
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true

    /// DEL-086: Interference-Banner-Dismiss-State. User kann das Warn-Banner
    /// per Tap auf "x" wegklicken; persistiert nur fuer diese Session-View-
    /// Instanz (State, kein AppStorage — bei der naechsten Session
    /// soll's wieder erscheinen, wenn die Bedingungen erfuellt sind).
    @State private var interferenceWarningDismissed: Bool = false

    /// DEL-086: Recent-Cardio-Sessions fuer die Interference-Detection.
    /// FetchDescriptor mit Datums-Predikat auf die letzten 24 Stunden,
    /// nur isCompleted-Sessions.
    @Query private var recentSessions: [WorkoutSession]

    /// README 2.16 (28c): liefert die Tonlage fuer `PRCelebration.make` -
    /// Emoji nur bei "Motivierend", damit PR-Feier und Coach-Texte
    /// konsistent bleiben.
    @Query private var profiles: [UserBodyProfile]

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

    /// DEL-097 + DEL-108: Session-weiter Single-Lock fuer time-based Halte-
    /// Timer. Nur EIN Halte-Set (Exercise × setIndex) darf gleichzeitig
    /// laufen. DEL-097 hat ursprünglich nur Exercise-Identitaet gespeichert
    /// → mehrere Saetze derselben Uebung konnten parallel starten (Regression
    /// auf dem Screenshot). DEL-108 schliesst die Luecke mit dem
    /// `ActiveTimedSetID`-Tuple.
    /// Wichtig: Rein UI-State, NICHT persistiert — wenn die App killt
    /// werden Timer eh nicht resumed (sind `@State` in der Row), also
    /// muss der Lock auch nicht ueberleben.
    @State private var activeTimedSet: ActiveTimedSetID?

    /// Rest-timer state. nil = no timer running.
    @State private var restTimerEnd: Date?
    @State private var restTimerOriginalSeconds: Int = 0

    /// DEL-154: Ad-Hoc-Edit/Delete-State.
    ///   * `exerciseToEdit` triggert das ExerciseEditorView-Sheet.
    ///   * `exercisePendingDelete` triggert den Confirm-Dialog, wenn die zu
    ///     entfernende Uebung bereits geloggte Saetze in DIESER Session hat.
    @State private var exerciseToEdit: Exercise?
    @State private var exercisePendingDelete: Exercise?

    public init(session: WorkoutSession) {
        self.session = session
    }

    public var body: some View {
        // DEL-039: paginierte Ansicht statt scrollbarer Single-Page-List.
        // Kopf oben fix, dann TabView mit einer Page pro Uebung + einer
        // finalen "Finish"-Page (Save/Discard). User swipt horizontal
        // zwischen Uebungen, page-indicator unten zeigt Position.
        //
        // Signature-Geruest 1.2/1.3: eigene Kopfzone (Eyebrow = Live-Timer)
        // statt navigationTitle, Kontextzeile statt statsCard. Der Rest der
        // paginatedBody-Struktur (TabView.page mit einer ExerciseCard pro
        // Seite) bleibt unangetastet - .deltiqScreen() eignet sich hier
        // NICHT, weil es eine eigene ScrollView um den gesamten Inhalt legt,
        // die mit der TabView-Pagination kollidieren wuerde.
        VStack(spacing: 0) {
            // Bugfix (Audit): war ein `@State private var now` + `.onReceive`
            // -Combine-Timer, der `now` bei JEDEM Tick unbedingt schrieb, nur
            // um ein Redraw zu erzwingen - exakt das Muster, das in
            // TimedWorkoutPlayerView.swift bereits als Ursache des
            // Vordergrund-Freeze-Bugs identifiziert wurde (siehe dortiger
            // Kommentar bei `tick`). `TimelineView` uebernimmt den Redraw
            // jetzt eigenstaendig, `context.date` ist die sichtbare Eingabe.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                DeltiqHeader(
                    eyebrow: String(
                        format: String(localized: "active.context.eyebrow.running", bundle: .module),
                        formattedDuration(at: context.date)
                    ),
                    title: session.displayDayName,
                    onBack: { dismiss() },
                    actions: headerActions
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                // DEL-086: Interference-Warning ueber dem Header. Banner zieht
                // sich aus, sobald der User es dismissed oder die Bedingungen
                // nicht erfuellt sind.
                interferenceBanner
                activeContextRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            paginatedBody
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        .deltiqSwipeBackEnabled()
        .keyboardDismissToolbar()
        // DEL-108: Wenn ein Halte-Timer-Set startet, killt das den Rest-
        // Timer sofort. Rationale — ein laufender Pausen-Timer waehrend
        // einer aktiven Plank ist semantisch widerspruechlich (User
        // pausiert nicht, sondern haelt aktiv). Wir clearen die Bar, ohne
        // Sound/Haptic-Feedback (ist kein Timer-Ende, nur Cleanup).
        .onChange(of: activeTimedSet) { oldValue, newValue in
            guard oldValue == nil, newValue != nil else { return }
            if restTimerEnd != nil {
                restTimerEnd = nil
                cancelRestTimerNotification()
                Task { await restTimerActivity.endRestTimer(reason: .skipped) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let end = restTimerEnd {
                RestTimerBar(
                    endDate: end,
                    originalSeconds: restTimerOriginalSeconds,
                    onDismiss: { reason in
                        restTimerEnd = nil
                        // DEL-204: bei .completed im Vordergrund hat die
                        // Notification nie gefeuert (Foreground-Suppression)
                        // — pending + delivered abräumen ist in beiden
                        // Fällen das Richtige.
                        cancelRestTimerNotification()
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
                // DEL-137: Session-Category + adaptive Distanz/Pace-Texte
                // damit die Finish-Sheet bei Cardio-Sessions die richtigen
                // Eckdaten zeigt (siehe statsCard oben).
                sessionCategory: dayCategory,
                distanceText: formatTotalDistance(),
                avgPaceText: formatAveragePace(),
                // DEL-158: Gear-Picker erscheint sobald Cardio dabei war —
                // auch bei Mixed Workouts, nicht nur bei reinem Cardio.
                showGearPicker: sessionHasLoggedCardio,
                onConfirm: { feeling, gear in
                    showingFinishConfirm = false
                    session.sessionFeeling = feeling.rawValue
                    // DEL-084 + DEL-158: Gear zuweisen + Cardio-Distanz auf
                    // Gear buchen (auch bei Mixed Workouts). `distanceKm` ist
                    // bei Strength-Logs nil → totalKm zaehlt nur die Cardio-km.
                    if let gear, sessionHasLoggedCardio {
                        session.gear = gear
                        // DEL-222: Buchung ueber GearOdometer — den einen
                        // Schreiber von currentDistanceKm.
                        GearOdometer.book(
                            deltaKm: GearOdometer.distanceKm(of: session),
                            to: gear
                        )
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
            Text(String(format: String(localized: "active.discard.message", bundle: .module), loggedSetsCount))
        }
        // DEL-096: Ad-Hoc-Picker. Custom-Eintragen ist hier bewusst nicht
        // erlaubt — Library-Pick reicht, alles weitere lebt im DayEditor.
        .sheet(isPresented: $showingAdHocPicker) {
            // DEL-210: einheitliche Übungs-Auswahl (= Bibliothek im
            // Picker-Modus).
            ExerciseLibraryPickerSheet(
                planEnvironment: nil,
                onSelect: { template in
                    addAdHocExercise(from: template)
                    showingAdHocPicker = false
                },
                onCreateCustom: { draft in
                    addAdHocCustomExercise(draft)
                    showingAdHocPicker = false
                }
            )
        }
        // DEL-154: Edit-Sheet fuer Ad-Hoc-Uebungen. ExerciseEditorView ist
        // fuer day.plan == nil voll editierbar (isReadOnly greift nur bei
        // Template-Plaenen) — Sets/Reps/Pause/RIR/Equipment-Flags/Notes
        // koennen also mitten im Workout angepasst werden.
        .sheet(item: $exerciseToEdit) { exercise in
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
        // DEL-154: Delete-Confirm — nur wenn die Uebung bereits geloggte
        // Saetze in dieser Session hat (sonst entfernen wir direkt, weniger
        // Reibung bei versehentlich hinzugefuegten Uebungen).
        .confirmationDialog(
            Text("active.exercise.removeConfirmTitle", bundle: .module),
            isPresented: Binding(
                get: { exercisePendingDelete != nil },
                set: { if !$0 { exercisePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let exercise = exercisePendingDelete {
                    deleteAdHocExercise(exercise)
                }
                exercisePendingDelete = nil
            } label: {
                Text("active.exercise.removeConfirmCta", bundle: .module)
            }
            Button(role: .cancel) {
                exercisePendingDelete = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("active.exercise.removeConfirmMessage", bundle: .module)
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

    /// Signature-Geruest 1.2: max. 2 Kopfzeilen-Aktionen. "+Übung" nur bei
    /// non-empty Ad-Hoc-Sessions (User darf jederzeit weitere Uebungen
    /// einschieben, Plan-Sessions kriegen den Button bewusst NICHT — dort
    /// kommt die Uebungs-Liste aus dem Plan und mid-workout-Adds wuerden
    /// den Pagination-State unter den Fuessen wegrotieren). Ellipsis ist
    /// immer da und haengt am bereits existierenden Discard-Dialog.
    private var headerActions: [DeltiqHeaderAction] {
        var actions: [DeltiqHeaderAction] = []
        if session.isAdHoc, let day = session.day, !day.activeExercises.isEmpty {
            actions.append(DeltiqHeaderAction(systemImage: "plus") {
                showingAdHocPicker = true
            })
        }
        // Explizites `menu:`-Label statt bare trailing closure - sonst muss
        // der Compiler zwischen den beiden DeltiqHeaderAction-Initializern
        // (action: () -> Void vs. menu: () -> MenuContent) per Typ-Inferenz
        // entscheiden, was bei einem View-liefernden Closure-Body unnoetig
        // fragil waere.
        actions.append(DeltiqHeaderAction(systemImage: "ellipsis", menu: {
            Button(role: .destructive) {
                showingDiscardConfirm = true
            } label: {
                Text("active.action.discard", bundle: .module)
            }
        }))
        return actions
    }

    /// DEL-061 + DEL-081, umgestellt auf Signature-Geruest 1.3: ersetzt die
    /// bisherige statsCard (Dauer|Saetze/Distanz|Volumen/Pace) durch zwei
    /// Kapseln. Dauer wandert in den Eyebrow (Live-Timer, siehe body).
    /// Die zweite Kapsel passt sich an die Tages-Kategorie an: bei reinem
    /// Cardio zeigt sie Distanz statt Volumen (Ruecksprache — eine woertlich
    /// feste "Volumen"-Kapsel waere an einem Cardio-Tag bedeutungslos, weil
    /// Cardio-Logs keine Gewicht×Wdh-Volumen-Zahl haben). ⌀-Pace und die
    /// Satz-Zaehlung fallen damit aus der Kopfzone — beide bleiben aber
    /// weiterhin Teil des Finish-Sheets (siehe .sheet(isPresented:
    /// $showingFinishConfirm) weiter oben, unveraendert).
    @ViewBuilder
    private var activeContextRow: some View {
        let exercises = session.day.map { orderedExercises(in: $0) } ?? []
        // Signature-Geruest 2.16: die Volumen-Kapsel erschien bisher auch VOR
        // dem ersten geloggten Satz ("VOLUMEN 0,00 KG") - erscheint jetzt erst,
        // sobald wirklich etwas geloggt ist. Die Distanz-Kapsel am Cardio-Tag
        // bleibt unbedingt (dort gab es keinen gemeldeten Leerlauf-Fall).
        let currentVolumeKg = session.logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        let secondPill: DeltiqContextItem? = {
            if dayCategory == .pureCardio {
                return DeltiqContextItem(
                    String(
                        format: String(localized: "active.context.distance", bundle: .module),
                        formatTotalDistance(stripUnit: true)
                    ),
                    style: .neutral
                )
            }
            guard currentVolumeKg > 0 else { return nil }
            return DeltiqContextItem(
                String(
                    format: String(localized: "active.context.volume", bundle: .module),
                    formatVolume()
                ),
                style: .neutral
            )
        }()

        if !exercises.isEmpty {
            if currentPageIndex < exercises.count {
                // %1$d/%2$d bewusst manuell ersetzt statt via String(format:) -
                // gleiche Konvention wie an anderen Mehrfach-Platzhalter-
                // Stellen im Catalog (z.B. dashboard.openSession.message.
                // withInfo): vermeidet %d-vs-%lld-Interger-Groessen-
                // Mismatches bei mehreren positionellen Platzhaltern.
                let exerciseTemplate = String(localized: "active.context.exercise", bundle: .module)
                let exerciseText = exerciseTemplate
                    .replacingOccurrences(of: "%1$d", with: "\(currentPageIndex + 1)")
                    .replacingOccurrences(of: "%2$d", with: "\(exercises.count)")
                let firstPill = DeltiqContextItem(exerciseText, style: .accent)
                let items = secondPill.map { [firstPill, $0] } ?? [firstPill]
                DeltiqContextRow(items)
            } else {
                // Finish-Seite (currentPageIndex == exercises.count): kein
                // "Uebung x/y" mehr sinnvoll, nur noch die zweite Kapsel (falls
                // vorhanden).
                DeltiqContextRow(secondPill.map { [$0] } ?? [])
            }
        }
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
                    Text("active.interference.title", bundle: .module)
                        .font(.subheadline.weight(.semibold))
                    Text("active.interference.message", bundle: .module)
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
                .accessibilityLabel(Text("active.interference.dismiss", bundle: .module))
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

    /// DEL-158: True wenn die Session MINDESTENS eine Cardio-Uebung mit
    /// geloggter Distanz oder Dauer enthaelt — unabhaengig davon, ob das
    /// Workout rein Cardio oder gemischt (Kraft + Cardio) war. Steuert die
    /// Sichtbarkeit des Gear-Pickers + die Distanz-Buchung. Bewusst getrennt
    /// von der Health-Klassifikation (`HealthWorkoutPlanner`): ein Mix-Day mit
    /// wenig Cardio soll als Krafttraining in Apple Health landen, aber sehr
    /// wohl Laufschuhe zuordnen koennen.
    private var sessionHasLoggedCardio: Bool {
        session.logs.contains { log in
            log.resolvedIsCardio
            && (((log.distanceKm ?? 0) > 0) || ((log.durationSeconds ?? 0) > 0))
        }
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
                // Bugfix (Audit): Identitaet ueber die Uebung selbst, nicht
                // die Array-Position - sonst uebernimmt SwiftUI nach dem
                // Loeschen einer Uebung mitten im Ad-Hoc-Workout die bereits
                // gemountete SetRow-Instanz (samt getippter Werte) fuer die
                // nachgerueckte Uebung an derselben Position weiter.
                ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { idx, exercise in
                    ScrollView {
                        ExerciseCard(
                            exercise: exercise,
                            session: session,
                            activeTimedSet: $activeTimedSet,
                            onSetLogged: { setIndex in
                                startRestTimer(for: exercise, setIndex: setIndex)
                                maybeAutoAdvance(after: exercise, exercises: exercises, currentIndex: idx)
                            },
                            // DEL-154: Edit/Delete nur im Ad-Hoc-Workout.
                            onEdit: session.isAdHoc ? { exerciseToEdit = exercise } : nil,
                            onDelete: session.isAdHoc ? { requestDeleteExercise(exercise) } : nil
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
                            activeTimedSet: $activeTimedSet,
                            onSetLogged: { setIndex in
                                startRestTimer(for: exercise, setIndex: setIndex)
                            },
                            onEdit: session.isAdHoc ? { exerciseToEdit = exercise } : nil,
                            onDelete: session.isAdHoc ? { requestDeleteExercise(exercise) } : nil
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
                    Label {
                        Text("active.empty.session.title", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                        .font(.headline)
                    Text("active.empty.session.message", bundle: .module)
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
                    Text("active.empty.adhoc.title", bundle: .module)
                        .font(.title3.weight(.bold))
                    Text("active.empty.adhoc.message", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // DEL-102: Hero-CTA migriert auf .deltiqButtonStyle() — der
                // zentrale Modifier kapselt Gradient + Glow + Padding und
                // ersetzt die fruehere manuelle HStack-/Padding-Kaskade.
                Button {
                    showingAdHocPicker = true
                } label: {
                    Label {
                        Text("active.addExerciseCTA", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Button(role: .destructive) {
                    showingDiscardConfirm = true
                } label: {
                    Text("active.discard.cta", bundle: .module)
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

            Text("active.placeholder.subtext", bundle: .module)
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

    /// Snapshot-Aufrufstellen (z.B. `FinishWorkoutSheet`s `durationText`)
    /// nutzen weiterhin diese Date()-basierte Form; die live-tickende
    /// Kopfzone nutzt `formattedDuration(at:)` mit `context.date` aus der
    /// `TimelineView` in `body`.
    private var formattedDuration: String { formattedDuration(at: Date()) }

    private func formattedDuration(at now: Date) -> String {
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
        return total.truncated(to: 0).formattedNoDecimals
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
        // Das eigentliche "Timer-State" sitzt in restTimerEnd. Auf nil
        // setzen blendet die RestTimerBar aus + verhindert dass die alte
        // Bar fuer einen Frame mit-rendert.
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
        // DEL-204: Background-Feedback. Sound/Haptik der RestTimerBar
        // feuern nur im Vordergrund — wenn der User das Handy weglegt
        // oder die App wechselt, kam bisher NICHTS. Die Local Notification
        // schließt die Lücke; im Vordergrund unterdrückt der AppDelegate
        // sie (kein Doppel-Feedback). Gated über dieselben Prefs wie das
        // In-App-Feedback: wer Sound UND Haptik aus hat, will auch keine
        // Banner.
        if timerSoundEnabled || timerHapticsEnabled {
            let title = String(localized: "rest.notification.title", bundle: .module)
            let body = String(
                format: String(localized: "rest.notification.body", bundle: .module),
                exercise.displayName, setIndex + 2, exercise.sets
            )
            Task {
                await ReminderScheduler.scheduleRestTimerEnd(
                    after: bounded, title: title, body: body
                )
            }
        }
    }

    /// DEL-204: räumt die geplante "Pause vorbei"-Notification ab. Muss in
    /// JEDEM Pfad laufen, der den Timer beendet/ersetzt — sonst ploppt das
    /// Banner einer längst geskippten Pause auf.
    private func cancelRestTimerNotification() {
        Task { await ReminderScheduler.cancelRestTimerEnd() }
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
        // UX-204: Success-Notification-Haptik zum Workout-Ende. Drei kurze
        // Impulse (das Standard-`.success` Pattern auf iOS) markieren den
        // Reward-Moment haptisch — synchron zum Spring-In des grossen
        // Checkmarks auf WorkoutSummaryView, der gleich erscheint.
        DeltiqHaptics.notify(.success)

        let endTime = Date()

        session.endTime = endTime
        session.durationMinutes = max(0, Int(endTime.timeIntervalSince(session.startTime) / 60))
        // DEL-221: Aggregate ueber den einen Schreiber (recomputeTotals).
        // DEL-092: exerciseCount zaehlt das, was der User tatsaechlich gemacht
        // hat — wenn Warmups versteckt waren, fliessen sie nicht in die
        // History-Stat. Deshalb explizit uebergeben statt abgeleitet.
        session.recomputeTotals(
            exerciseCount: session.day.map { orderedExercises(in: $0).count } ?? 0
        )
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

        // Nach Apple Health schreiben — gemaess den Schaltern (Einstellungen →
        // Apple Health → Trainings in Health: Krafttraining / Cardio) und der
        // log-basierten Klassifikation (`HealthWorkoutPlanner`): Cardio ohne
        // Distanz bleibt Cardio, Radfahren ist kein Laufen, Laufband ist
        // indoor. Der Draft wird SYNCHRON als Wert gebaut (session.* mutiert
        // spaeter), danach wird die Session nicht mehr angefasst.
        HealthWorkoutWriter.pushLive(session: session, healthKit: healthKit)

        // Clear any running rest timer (in-app + Live Activity). Branching:
        //   - PRs detected + Celebrations on → push final state with trophy
        //     headline, fire a local notification, let the activity linger ~8s.
        //   - PRs detected + Celebrations off (DEL-078) → quiet skip-dismiss,
        //     der Trophy-Room bleibt aber gefuellt fuer den User, der's
        //     spaeter aktiv anschauen will.
        //   - No PRs → quiet skip-dismiss as before.
        restTimerEnd = nil
        // DEL-204: Workout beendet → keine "Pause vorbei"-Notification mehr.
        cancelRestTimerNotification()
        let celebration = prCelebrationsEnabled
            ? PRCelebration.make(from: detectedPRs, tone: profiles.first?.coachingTone ?? .analytical)
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
        // DEL-149: Library-Base-Name (deutsche Anker-Form) statt
        // template.displayName. Begruendung siehe DayEditorView.addExercise.
        // Der locale-aware Display-Lookup laeuft beim Render-Pfad ueber die
        // `Exercise.displayName`-Extension.
        let exercise = Exercise(
            name: template.name,
            // DEL-157: Cardio/Time-Based starten mit 1 Satz (siehe
            // DayEditorView.addExercise).
            sets: (template.isCardio || template.isTimeBased) ? 1 : 3,
            orderIndex: day.activeExercises.count,
            isCardio: template.isCardio,
            isTimeBased: template.isTimeBased,
            isCompound: template.isSystemCompound,
            // DEL-098: Recovery-Faktoren mit propagieren — Ad-Hoc-Sessions
            // sollen genauso korrekt in den Scoring-Algorithmus fliessen
            // wie Plan-Workouts.
            systemicFatigueFactor: template.systemicFatigueFactor,
            localMuscleDamageFactor: template.localMuscleDamageFactor,
            cnsDemandFactor: template.cnsDemandFactor,
            axialLoadFactor: template.axialLoadFactor,
            technicalComplexityFactor: template.technicalComplexityFactor,
            recoveryClass: template.recoveryClass,
            // DEL-163: Muskel + Equipment vom Template uebernehmen (siehe
            // DayEditorView.addExercise) — sonst Defaults im Editor.
            primaryMuscle: template.primaryMuscle,
            equipment: template.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// Custom-Uebung im Ad-Hoc-Flow — analog zu `DayEditorView.addCustomExercise`.
    /// Legt ein neues `ExerciseTemplate` (`isCustom: true`) in der Library
    /// an, damit die Uebung beim naechsten Picker-Open auswaehlbar bleibt.
    private func addAdHocCustomExercise(_ draft: CustomExerciseDraft) {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let day = session.day else { return }

        // DEL-159: Metadaten aus dem Erstell-Sheet (Muskel/Equipment/Compound)
        // — siehe DayEditorView.addCustomExercise.
        let template = ExerciseTemplate(
            name: trimmed,
            equipment: draft.equipment,
            primaryMuscle: draft.primaryMuscle,
            isCustom: true,
            isSystemCompound: draft.isCompound
        )
        modelContext.insert(template)

        let exercise = Exercise(
            name: trimmed,
            orderIndex: day.activeExercises.count,
            isCompound: draft.isCompound,
            primaryMuscle: draft.primaryMuscle,
            equipment: draft.equipment,
            day: day
        )
        modelContext.insert(exercise)
    }

    /// DEL-154: Entry-Point fuer das Entfernen einer Ad-Hoc-Uebung. Hat die
    /// Uebung in DIESER Session schon geloggte Saetze, fragen wir per
    /// Confirm-Dialog nach (Saetze gehen mit verloren). Sonst entfernen wir
    /// direkt — eine eben erst hinzugefuegte, noch unbenutzte Uebung soll
    /// ohne Reibung wieder verschwinden.
    private func requestDeleteExercise(_ exercise: Exercise) {
        let hasLogs = session.logs.contains { $0.exercise == exercise }
        if hasLogs {
            exercisePendingDelete = exercise
        } else {
            deleteAdHocExercise(exercise)
        }
    }

    /// DEL-154: Entfernt eine Ad-Hoc-Uebung samt ihrer in dieser Session
    /// geloggten Saetze. `ExerciseLog.exercise` ist `.nullify`, also muessen
    /// die Logs explizit geloescht werden (sonst blieben verwaiste Logs mit
    /// Snapshot in der Session-Statistik haengen). Danach den Paginator-Index
    /// clampen, damit die TabView nicht auf eine entfernte Seite zeigt.
    private func deleteAdHocExercise(_ exercise: Exercise) {
        guard let day = session.day else { return }

        // 1) Logs dieser Uebung in DIESER Session loeschen.
        let logs = session.logs.filter { $0.exercise == exercise }
        for log in logs {
            modelContext.delete(log)
        }

        // 2) Uebung selbst entfernen.
        modelContext.delete(exercise)

        // 3) Paginator-Index clampen + Exercise-Count auffrischen. Nach dem
        // Delete kann currentPageIndex auf eine nicht mehr existente Seite
        // zeigen → auf die letzte gueltige Seite (oder die Finish-Page) ziehen.
        let remaining = orderedExercises(in: day).count
        if currentPageIndex > remaining {
            currentPageIndex = remaining
        }
        // DEL-221: Dieser Pfad hat gerade Logs geloescht (Schritt 1), also
        // muessen totalSets/totalVolumeKg mit. Vorher wurde nur
        // exerciseCount aktualisiert und die Summen blieben auf dem Stand
        // VOR dem Delete stehen — unkritisch solange die Session offen ist
        // (der Finish rechnet neu), aber inkonsistent, sobald irgendetwas
        // die offene Session liest.
        session.recomputeTotals(exerciseCount: remaining)
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
    /// DEL-137: Session-Category-Branch fuer die summarySection — vorher
    /// zeigte die Sheet IMMER "Dauer + Saetze + Volumen-kg", was bei
    /// reinen Cardio-Sessions unsinnig wirkt (siehe statsCard im
    /// ActiveWorkoutView, der bereits adaptiv ist).
    let sessionCategory: SessionCategory
    /// DEL-137: Distanz-Text (z.B. "5 km"), nur bei pureCardio + mixed
    /// gerendert.
    let distanceText: String
    /// DEL-137: Ø Pace ("8:00 /km"), nur bei pureCardio gerendert.
    let avgPaceText: String
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
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("active.finish.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Text("common.cancel", bundle: .module)
                    }
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
            Text("active.finish.gear", bundle: .module)
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
                                .foregroundStyle(gear.needsReplacement ? Color.Deltiq.error : Color.Deltiq.textSecondary)
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
                                    : Color.Deltiq.divider,
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
            Text("active.finish.summary", bundle: .module)
                .font(.headline)
            // DEL-137: drei-Wege-Branch identisch zum statsCard oben in der
            // Active-Workout-View. Hier in der Finish-Sheet, da kommt die
            // Sheet hochgepoppt direkt VOR dem finishWorkout-Pass, sollte
            // die Eckdaten in derselben Sprache zeigen — kein abrupter
            // Wechsel von "Distanz/Pace" (live) zu "Saetze/Volumen" (finish).
            HStack(spacing: 0) {
                summaryStat(label: String(localized: "active.summary.duration", bundle: .module), value: durationText)
                Divider().frame(height: 32)
                switch sessionCategory {
                case .pureCardio:
                    summaryStat(label: String(localized: "active.stats.distance", bundle: .module),
                                value: distanceText)
                    Divider().frame(height: 32)
                    summaryStat(label: String(localized: "active.stats.avgPace", bundle: .module),
                                value: avgPaceText)
                case .mixed:
                    summaryStat(label: String(localized: "active.summary.volume", bundle: .module),
                                value: "\(volumeText) kg")
                    Divider().frame(height: 32)
                    summaryStat(label: String(localized: "active.stats.distance", bundle: .module),
                                value: distanceText)
                case .pureStrength:
                    summaryStat(label: String(localized: "active.summary.sets", bundle: .module),
                                value: "\(setsCount)")
                    Divider().frame(height: 32)
                    summaryStat(label: String(localized: "active.summary.volume", bundle: .module),
                                value: "\(volumeText) kg")
                }
            }
            .padding(.vertical, 8)
            .background(Color.Deltiq.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("active.finish.feeling.title", bundle: .module)
                .font(.headline)
            Text("active.finish.feeling.message", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
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
                    Text("\(feeling.rawValue). \(String(localized: feeling.localizedName))")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if feeling.vetoesProgression {
                        Text("active.finish.feeling.noProgression", bundle: .module)
                            .font(.caption2)
                            .foregroundStyle(Color.Deltiq.textSecondary)
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
                    .stroke(selected == feeling ? Color.deltiqOrange : Color.Deltiq.divider,
                            lineWidth: selected == feeling ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        Button {
            onConfirm(selected, selectedGear)
        } label: {
            Label {
                Text("active.finish.save", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
            }
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
    }
}
#endif
