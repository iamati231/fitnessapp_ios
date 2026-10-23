#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import FitnessAppHealth

/// Player fuer das Zirkel-Zeitformat (Nutzer-Feedback, Kettlebell-Komplexe):
/// feste Rundenzahl, feste konfigurierbare Pause zwischen den Runden. Anders
/// als AMRAP/EMOM/Auf-Zeit (eine gemeinsame Uhr fuer den ganzen Tag) hat der
/// Zirkel ZWEI Phasen pro Runde - eine ungezeitete Arbeitsphase (der User
/// bestimmt selbst, wann eine Runde fertig ist) und eine gezeitete Pause
/// dazwischen (`restEndDate`, groser Countdown-Ring). `circuitMode`
/// entscheidet, WIE eine Runde als fertig erkannt wird: `.fixedReps` hakt
/// jede Uebung einzeln ab und erkennt automatisch, `.toFailure` hat keine
/// feste Wiederholungszahl und braucht den manuellen "Runde beenden"-Knopf.
///
/// Peer zu `AMRAPPlayerView`/`EMOMPlayerView`/`ForTimePlayerView` in
/// `TimedWorkoutPlayerView.swift` - eigene Datei, weil die Zwei-Phasen-
/// Logik (Arbeit + Pause) mehr eigenen State braucht als die anderen drei.
@available(iOS 17.0, macOS 14.0, *)
struct CircuitPlayerView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    /// Nutzer-Feedback: der Timer muss auch dann korrekt weiterlaufen, wenn
    /// die App im Hintergrund war - gleiches Muster wie bei den anderen drei
    /// Playern (siehe `restEndDate`/`checkRestElapsed()` unten).
    @Environment(\.scenePhase) private var scenePhase

    @State private var roundsCompleted = 0
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false

    /// `.fixedReps`: welche Uebungen der LAUFENDEN Runde schon abgehakt
    /// sind. Anders als `ForTimePlayerView.checkedRounds` (kumulativ ueber
    /// die ganze Session) wird das bei jedem Rundenwechsel wieder geleert -
    /// eine Zirkel-Runde ist ein abgeschlossener Zyklus, keine fortlaufende
    /// Zaehlung.
    @State private var checkedInRound: [PersistentIdentifier: Int] = [:]

    /// `nil` = gerade wird eine Runde gearbeitet, non-nil = Pause laeuft,
    /// Ende der Pause. Wanduhr-Anker wie `session.startTime` bei den
    /// anderen Playern - ueberlebt Hintergrund/Resume korrekt.
    @State private var restEndDate: Date?
    /// Write-Once-Flags pro Pause (bei jedem `beginRest()` zurueckgesetzt) -
    /// gleiches Muster wie `AMRAPPlayerView.hasFiredLastMinuteWarning`.
    @State private var hasFiredRest60 = false
    @State private var hasFiredRest30 = false

    /// README 2.15/23b-23c: Vorlauf-Countdown vor der allerersten Runde -
    /// identisches Muster wie bei den anderen drei Playern.
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// Hintergrund-Lauf (stilles Audio + Live Activity), siehe
    /// `TimedWorkoutBackground`. Haengt an der Lebensdauer des Players: Wird er
    /// zerstoert, waehrend er nicht sichtbar ist (anderer Tab, dann App-Reset oder
    /// "Verwerfen & starten"), ruft kein `onDisappear` mehr `end()` - der Deinit des
    /// Handles raeumt dann auf.
    @State private var background = TimedWorkoutBackgroundRun()

    /// Bugfix (Nutzer-Feedback): siehe ausfuehrliche Begruendung bei
    /// `AMRAPPlayerView.init` - "Training fortsetzen" erzeugt eine
    /// komplett neue View-Instanz fuer dieselbe Session, jedes `@State`
    /// faellt auf seinen Default zurueck. `session.circuitRoundsCompleted`
    /// ist `nil`, bis `finishPreroll()` es beim ALLERERSTEN echten Start auf
    /// 0 setzt - ein Nicht-nil-Wert beweist also "Vorlauf schon
    /// durchlaufen". Stellt zusaetzlich wieder her, ob gerade eine Pause
    /// lief (`circuitRestEndDate`) und welche Uebungen der laufenden Runde
    /// schon abgehakt waren (`circuitCurrentRoundCheckedRaw`).
    init(session: WorkoutSession) {
        self.session = session
        if let existingRounds = session.circuitRoundsCompleted {
            prerollTotal = 0
            _prerollRemaining = State(initialValue: 0)
            _roundsCompleted = State(initialValue: existingRounds)
            _restEndDate = State(initialValue: session.circuitRestEndDate)
            if let raw = session.circuitCurrentRoundCheckedRaw {
                // P8 Stufe-2: ueber die statische, snapshot-first
                // Hilfsfunktion (self.resolvedExercises waere hier noch
                // nicht erreichbar) - schuetzt vor Fehlzuordnung nach einer
                // externen Umsortierung des Tages.
                let exercisesAtInit = Self.resolvedExercises(for: session)
                _checkedInRound = State(initialValue: Self.decodeCheckedInRound(raw, exercises: exercisesAtInit))
            }
        } else {
            let stored = storedPrerollSeconds()
            prerollTotal = stored
            _prerollRemaining = State(initialValue: stored)
        }
    }

    /// Serialisiert, welche Uebungen der laufenden Runde abgehakt sind, als
    /// kommagetrennte `orderIndex`-Liste. P8 Stufe-2-Nachbesserung:
    /// `orderIndex` ist der EINGEFRORENE Snapshot-Wert (`entry.orderIndex`),
    /// nicht mehr `exercise.orderIndex` live — die ursprüngliche Annahme
    /// ("ändert sich während einer laufenden Session nicht") galt nur für
    /// diesen Player selbst; eine externe Umsortierung über `DayEditorView`
    /// verschiebt den LIVEN `orderIndex` sehr wohl (siehe `ForTimePlayerView`
    /// fuer dieselbe Korrektur). Anders als `ForTimePlayerView`s Format
    /// braucht es keine Anzahl pro Uebung (binaer: abgehakt oder nicht),
    /// daher genuegt die reine Liste. "-"-Platzhalter fuer "nichts
    /// abgehakt" - ein leerer String wuerde beim CSV-Roundtrip zu `nil`
    /// normalisiert (siehe `ForTimePlayerView`s identische Begruendung).
    private static func encodeCheckedInRound(
        _ checked: [PersistentIdentifier: Int],
        exercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)]
    ) -> String {
        let indices = exercises.compactMap { pair -> String? in
            guard (checked[pair.exercise.persistentModelID] ?? 0) > 0 else { return nil }
            return "\(pair.entry.orderIndex)"
        }
        return indices.isEmpty ? "-" : indices.joined(separator: ",")
    }

    private static func decodeCheckedInRound(
        _ raw: String,
        exercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)]
    ) -> [PersistentIdentifier: Int] {
        guard raw != "-", !raw.isEmpty else { return [:] }
        var result: [PersistentIdentifier: Int] = [:]
        for piece in raw.split(separator: ",") {
            guard let orderIndex = Int(piece), let match = exercises.first(where: { $0.entry.orderIndex == orderIndex }) else { continue }
            result[match.exercise.persistentModelID] = 1
        }
        return result
    }

    /// P8 Stufe-2 (Resume-Isolation): Mitgliedschaft/Reihenfolge/Identität
    /// kommen aus dem eingefrorenen Snapshot dieser Session, aufgelöst
    /// gegen die aktuell noch existierenden Live-Objekte
    /// (`SessionContentResolver`) — siehe `AMRAPPlayerView.resolvedExercises`
    /// für die volle Begründung. Entfernte Übungen werden stillschweigend
    /// ausgelassen (kein `ExerciseLog`-Pfad hier, der eine sichtbare
    /// Markierung bräuchte).
    private var resolvedExercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)] {
        Self.resolvedExercises(for: session)
    }
    /// Statisch, damit `init` sie vor dem Setzen aller Stored Properties
    /// aufrufen kann (`self.resolvedExercises` wäre dort nicht erlaubt).
    private static func resolvedExercises(for session: WorkoutSession) -> [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)] {
        guard let day = session.day else { return [] }
        switch session.contentSnapshotState {
        case .available(let snapshot):
            return SessionContentResolver.resolve(snapshot: snapshot, liveExercises: day.activeExercises)
                .compactMap { item -> (TrainingDayContentSnapshot.ExerciseEntry, Exercise)? in
                    guard case .live(let entry, let exercise) = item else { return nil }
                    return (entry, exercise)
                }
        case .notCaptured, .unreadable:
            return day.activeExercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { (TrainingDayContentSnapshotWriter.snapshotEntry(for: $0), $0) }
        }
    }
    private var exercises: [Exercise] { resolvedExercises.map(\.exercise) }
    private func entry(for exercise: Exercise) -> TrainingDayContentSnapshot.ExerciseEntry {
        resolvedExercises.first { $0.exercise.persistentModelID == exercise.persistentModelID }?.entry
            ?? TrainingDayContentSnapshotWriter.snapshotEntry(for: exercise)
    }
    // P8 Stufe-2: snapshot-first — `circuitMode` steuert die TATSÄCHLICHE
    // Rundenabschluss-Logik (`.toFailure` vs. `.fixedReps`), nicht nur die
    // Anzeige; `totalRounds`/`restSeconds` ebenso die Timer-/Abschlusslogik.
    private var totalRounds: Int { session.contentSnapshotCircuitRounds ?? defaultCircuitRounds() }
    private var restSeconds: Int { session.contentSnapshotCircuitRestSeconds ?? defaultCircuitRestSeconds() }
    private var circuitMode: CircuitRoundMode { session.contentSnapshotCircuitMode ?? .fixedReps }

    private var pillLabel: String {
        String(localized: "timedWorkout.circuit.pillLabel", bundle: .module)
    }

    private var roundContextText: String {
        // Waehrend der Arbeitsphase zeigt es die Runde, an der gerade
        // gearbeitet wird (`roundsCompleted + 1`), waehrend der Pause die
        // zuletzt ABGESCHLOSSENE Runde - beides liest sich als "wo stehe
        // ich gerade", nicht als off-by-one-Fehler.
        let displayedRound = restEndDate != nil ? roundsCompleted : min(roundsCompleted + 1, totalRounds)
        return String(format: String(localized: "timedWorkout.circuit.roundContext", bundle: .module), displayedRound, totalRounds).uppercased()
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
                    timedWorkoutPrerollExerciseList(exercises)
                } else if let restEndDate {
                    restContent(restEndDate)
                } else {
                    workingContent
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-fix: .navigationBarBackButtonHidden(true) also disables the swipe-back
        // gesture; re-enable it. See deltiqSwipeBackEnabled() in Theme.swift.
        .deltiqSwipeBackEnabled()
        .onAppear {
            if prerollRemaining > 0 {
                playPrerollTone(remaining: prerollRemaining, enabled: timerSoundEnabled)
                background.beginPreroll(soundEnabled: timerSoundEnabled)
            } else {
                startBackground()
            }
        }
        // Muss in JEDEM Ausstiegspfad laufen (Speichern, Verwerfen, Zurueck-Chevron):
        // sonst laeuft das stille Audio weiter und die Live Activity bleibt stehen.
        // Ausnahme Tab-Wechsel: Der Player lebt dann weiter (Uhr, Toene, Zaehlung) und
        // der Lauf geht unveraendert weiter - Plan ist der Tab des Workout-Stapels, ein
        // anderer Tab bedeutet "weggeschaltet", nicht "verlassen". Speichern (Summary
        // ueberdeckt den Player) und Pop passieren dagegen immer auf dem Plan-Tab.
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
            // Review-Fund (Zirkel-Feature): der Sekunden-Pieps darf NUR hier
            // im Tick-Handler leben, nicht in `checkRestElapsed()` selbst -
            // die Funktion wird auch vom `scenePhase`-Ruecksprung gerufen
            // (gleich unten), und `Timer.publish` kann kurz danach fuer
            // DIESELBE aufgerundete Sekunde nochmal feuern. Ohne diese
            // Trennung wuerde der Pieps beim Rueckkehren aus dem Hintergrund
            // gelegentlich doppelt erklingen. Exakt dasselbe Muster wie
            // `EMOMPlayerView`s Zehn-Sekunden-Pieps, der ebenfalls nur im
            // Tick-`onReceive` steht, waehrend `resyncMinuteState()` (dessen
            // Pendant zu `checkRestElapsed()`) von beiden Stellen gerufen
            // wird, aber selbst stumm bleibt.
            if timerSoundEnabled, let remaining = remainingRestSeconds(), (1...10).contains(remaining) {
                TimerSoundPlayer.shared.playShort()
            }
            checkRestElapsed()
            syncBackground()
        }
        // Nutzer-Feedback: sofortige Pruefung beim Ruecksprung aus dem
        // Hintergrund statt bis zum naechsten Tick zu warten - gleiches
        // Muster wie bei den anderen drei Playern.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            checkRestElapsed()
            syncBackground(resend: true)
        }
        .safeAreaInset(edge: .bottom) {
            if prerollRemaining > 0 {
                timedWorkoutPrerollStartBar { finishPreroll() }
            } else if restEndDate != nil {
                restSkipBar
            } else if circuitMode == .toFailure {
                roundActionBar
            } else {
                fixedRepsProgressBar
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

    @ViewBuilder
    private var workingContent: some View {
        DeltiqContextRow([
            DeltiqContextItem(String(localized: "timedWorkout.running.label", bundle: .module), style: .accent),
            DeltiqContextItem(roundContextText, style: .accent)
        ])

        DeltiqSection {
            ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                if circuitMode == .fixedReps {
                    exerciseCheckRow(exercise, showsDivider: index != exercises.count - 1)
                } else {
                    DeltiqRow(
                        label: exercise.displayName,
                        value: timedFormatTargetLabel(repsMin: entry(for: exercise).repsMin, isTimeBased: entry(for: exercise).isTimeBased),
                        showsDivider: index != exercises.count - 1
                    )
                }
            }
            timedWorkoutHintRow(String(
                localized: circuitMode == .fixedReps
                    ? "timedWorkout.circuit.fixedRepsHint"
                    : "timedWorkout.circuit.toFailureHint",
                bundle: .module
            ))
        }
    }

    private func exerciseCheckRow(_ exercise: Exercise, showsDivider: Bool) -> some View {
        let checked = (checkedInRound[exercise.persistentModelID] ?? 0) > 0
        let targetEntry = entry(for: exercise)
        return VStack(spacing: 0) {
            Button {
                toggleExerciseChecked(exercise)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.displayName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        Text(timedFormatTargetLabel(repsMin: targetEntry.repsMin, isTimeBased: targetEntry.isTimeBased))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                    Spacer()
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(checked ? Color.Deltiq.success : Color.Deltiq.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsDivider {
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private func restContent(_ restEndDate: Date) -> some View {
        DeltiqContextRow([
            DeltiqContextItem(String(localized: "timedWorkout.circuit.pauseLabel", bundle: .module), style: .accent),
            DeltiqContextItem(roundContextText, style: .neutral)
        ])

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(restEndDate.timeIntervalSince(context.date).rounded(.up)))
            DeltiqCard(accentEdge: true) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.Deltiq.fill, lineWidth: 11)
                        Circle()
                            .trim(from: 0, to: restSeconds > 0 ? CGFloat(remaining) / CGFloat(restSeconds) : 0)
                            .stroke(Color.deltiqOrange, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(remaining)")
                            .font(.system(size: 56, weight: .heavy))
                            .fitnessNumberStyle()
                            .foregroundStyle(Color.primary)
                    }
                    .frame(width: 200, height: 200)
                    Text("timedWorkout.circuit.pauseLabel", bundle: .module)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }

        DeltiqSection {
            timedWorkoutHintRow(String(localized: "timedWorkout.circuit.pauseHint", bundle: .module))
        }
    }

    /// Punkte-Menue mit zwei Eintraegen statt nur Verwerfen (README 2.10/19e):
    /// "Speichern" sichert den aktuellen Stand jederzeit ohne Rueckfrage,
    /// "Verwerfen" bleibt destruktiv mit Bestaetigung wie bisher.
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

    /// Gemeinsamer Speicherpfad fuer den Menue-Eintrag UND das natuerliche
    /// Ende (letzte Runde abgeschlossen) — `completedTarget` spiegelt exakt,
    /// ob `isFinished` zum Zeitpunkt des Aufrufs schon (alle Runden
    /// geschafft) oder noch nicht (vorzeitig ueber das Menue) erreicht war.
    private func saveNow() {
        session.circuitRoundsCompleted = roundsCompleted
        session.completedTarget = isFinished
        session.timeFormatSnapshot = .circuit
        finishTimedSession(
            session, modelContext: modelContext, healthKit: healthKit,
            prNotifications: prNotifications, navigation: navigation,
            prCelebrationsEnabled: prCelebrationsEnabled
        )
    }

    /// README 2.15/23b-23c: Uebergang von Vorlauf in den echten Lauf.
    /// `session.circuitRoundsCompleted = 0` markiert hier zuverlaessig
    /// "diese Session hat jetzt begonnen", der Wert war bis hierher `nil`.
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        session.circuitRoundsCompleted = 0
        // TestingBot-Regressionscheck (Block B, Deltiq-Abnahme): ohne
        // dieses Save faellt der Marker nach einem Kaltstart VOR der
        // ersten Runde wieder auf `nil` zurueck - der Vorlauf wuerde
        // faelschlich neu starten (identisches Muster wie AMRAPs
        // `finishPreroll()` in TimedWorkoutPlayerView.swift).
        try? modelContext.save()
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        startBackground()
    }

    /// Hintergrund-Lauf (stilles Audio + Live Activity) starten bzw. beim
    /// Wiederaufnehmen ("Training fortsetzen") wieder aufnehmen - erst, wenn die Uhr
    /// laeuft: `session.startTime` ist erst nach dem Vorlauf der Anker.
    private func startBackground() {
        background.begin(for: session, format: .circuit, soundEnabled: timerSoundEnabled)
        syncBackground()
    }

    /// Billig genug fuer jeden Tick: `TimedLiveContent` aendert sich nur beim
    /// Wechsel zwischen Arbeit und Pause und beim Rundenwechsel (die Uhren zaehlt
    /// das System selbst).
    private func syncBackground(resend: Bool = false) {
        background.sync(
            TimedLiveContent.circuit(
                anchor: session.startTime,
                restEnd: restEndDate,
                restSeconds: restSeconds,
                roundsCompleted: roundsCompleted,
                totalRounds: totalRounds,
                isFinished: isFinished,
                now: Date()
            ),
            resend: resend
        )
    }

    /// Anders als bei AMRAP/EMOM/Auf-Zeit ist die ARBEITSPHASE selbst nicht
    /// gezeitet - der User bestimmt selbst, wann eine Runde fertig ist
    /// (per Checkbox-Auto-Erkennung bei `.fixedReps` oder manuell bei
    /// `.toFailure`). Nur die PAUSE zwischen den Runden hat eine Uhr,
    /// deshalb kein "Deckel erreicht"-Check hier wie bei den anderen
    /// Formaten - siehe stattdessen `checkRestElapsed()`.
    private func toggleExerciseChecked(_ exercise: Exercise) {
        let key = exercise.persistentModelID
        let alreadyChecked = (checkedInRound[key] ?? 0) > 0
        checkedInRound[key] = alreadyChecked ? 0 : 1
        // TestingBot-Regressionscheck (Block B, Deltiq-Abnahme): ohne
        // `context.save()` uebersteht diese Mutation keinen echten
        // Kaltstart (siehe TimedWorkoutPlayerView.completeRound()-Doku,
        // identisches Muster).
        session.circuitCurrentRoundCheckedRaw = Self.encodeCheckedInRound(checkedInRound, exercises: resolvedExercises)
        try? modelContext.save()
        DeltiqHaptics.notify(.success)
        guard !alreadyChecked else { return }   // Nur beim NEUEN Abhaken pruefen, nicht beim Zurueck-Abhaken.
        if exercises.allSatisfy({ (checkedInRound[$0.persistentModelID] ?? 0) > 0 }) {
            completeCurrentRound()
        }
    }

    /// Gemeinsamer Pfad fuer die automatische Rundenerkennung (`.fixedReps`,
    /// alle Uebungen abgehakt) UND den manuellen "Runde beenden"-Knopf
    /// (`.toFailure`, oder als Override bei `.fixedReps`). Letzte Runde
    /// speichert direkt durch - anders als AMRAP's Deckel gibt es hier
    /// keine "angebrochene Runde" (die Arbeitsphase ist ungezeitet, eine
    /// Runde ist immer entweder fertig oder noch gar nicht beendet), also
    /// auch keinen Grund fuer einen zusaetzlichen Review-Schritt vor dem
    /// Speichern.
    private func completeCurrentRound() {
        roundsCompleted += 1
        session.circuitRoundsCompleted = roundsCompleted
        // TestingBot-Regressionscheck (Block B, Deltiq-Abnahme): wie
        // `toggleExerciseChecked` oben - der Finish-Zweig unten speichert
        // bereits ueber `saveNow()`, der Zwischenstand hier (noch nicht
        // letzte Runde) bisher nicht.
        try? modelContext.save()
        DeltiqHaptics.notify(.success)
        if roundsCompleted >= totalRounds {
            isFinished = true
            saveNow()
        } else {
            beginRest()
        }
    }

    /// Nutzer-Feedback: der Uebergang in die Pause muss auffallen ("der
    /// User soll darauf aufmerksam gemacht werden, dass eine Pause folgt")
    /// - eigene Haptik + langer Ton HIER, direkt am Uebergang, zusaetzlich
    /// zum Erfolgs-Feedback aus `completeCurrentRound()` unmittelbar davor.
    private func beginRest() {
        checkedInRound = [:]
        session.circuitCurrentRoundCheckedRaw = nil
        let end = Date().addingTimeInterval(TimeInterval(restSeconds))
        restEndDate = end
        session.circuitRestEndDate = end
        // TestingBot-Regressionscheck (Block B, Deltiq-Abnahme): wie
        // `completeCurrentRound()` oben - ohne Save uebersteht weder das
        // Zuruecksetzen von `circuitCurrentRoundCheckedRaw` noch der neue
        // Pausen-Anker einen echten Kaltstart.
        try? modelContext.save()
        hasFiredRest60 = false
        hasFiredRest30 = false
        DeltiqHaptics.notify(.warning)
        if timerSoundEnabled {
            TimerSoundPlayer.shared.playLong()
        }
        syncBackground()
    }

    private func endRest() {
        restEndDate = nil
        session.circuitRestEndDate = nil
        // TestingBot-Geraetebefund (Deltiq-Abnahme, Punkt 4): `beginRest()`
        // (oben) speichert den neuen Pausen-Anker explizit, `endRest()`
        // (Pausenablauf UND "Skip rest") hatte denselben Sofort-Save bisher
        // NICHT - auf echtem Geraet reproduziert: Pause ueberspringen, sofort
        // Force-Quit + Kaltstart -> die App zeigte nach dem Neustart wieder
        // die (eigentlich schon beendete) Pause an, weil `circuitRestEndDate`
        // auf der Store-Datei nie auf `nil` gesetzt wurde. Gleiches
        // Fix-Muster wie die uebrigen zehn Fundstellen aus f2a31a5.
        try? modelContext.save()
        DeltiqHaptics.notify(.success)
        if timerSoundEnabled {
            TimerSoundPlayer.shared.playLong()
        }
        syncBackground()
    }

    /// Wanduhr-Ablesung der laufenden Pause, `nil` wenn gerade keine Pause
    /// laeuft. Geteilt zwischen dem Tick-Handler (Sekunden-Pieps, siehe
    /// dortiger Kommentar) und `checkRestElapsed()` - EINE Quelle der
    /// Wahrheit statt zweier parallel berechneter Werte, die bei
    /// unterschiedlichen `Date()`-Aufrufen leicht auseinanderlaufen koennten.
    private func remainingRestSeconds(at now: Date = Date()) -> Int? {
        guard let restEndDate else { return nil }
        return max(0, Int(restEndDate.timeIntervalSince(now).rounded(.up)))
    }

    /// Nutzer-Feedback: Pieps-Schema "beim Start, bei 60, bei 30, dann jede
    /// Sekunde von 10 auf 0". Der Start-Pieps sitzt in `beginRest()`
    /// (Uebergangs-Moment, kein Tick-Check noetig), der Sekunden-Pieps lebt
    /// im Tick-Handler in `body` (siehe dortiger Kommentar, warum er NICHT
    /// hier stehen darf) - hier nur die 60/30-Schwellen und der Uebergang
    /// bei Ablauf. `restSeconds > 60`/`> 30` blendet die jeweilige Schwelle
    /// aus, wenn die konfigurierte Pause gar nicht so lang ist - sonst
    /// wuerde eine 45s-Pause sofort beim Start ein zweites Mal (redundant
    /// zum Start-Pieps) bei "60" ausloesen. Wird sowohl vom Tick ALS AUCH
    /// vom `scenePhase`-Ruecksprung gerufen - deshalb bleiben 60/30
    /// Write-Once-Flag-geschuetzt (ein zweifacher Aufruf fuer denselben
    /// Schwellenwert darf nicht zweimal piepen), waehrend der Sekunden-Pieps
    /// diesen Schutz nicht braucht, weil er hier gar nicht mehr steht.
    private func checkRestElapsed() {
        guard let remaining = remainingRestSeconds() else { return }
        if restSeconds > 60, remaining <= 60, !hasFiredRest60 {
            hasFiredRest60 = true
            if timerSoundEnabled { TimerSoundPlayer.shared.playShort() }
        }
        if restSeconds > 30, remaining <= 30, !hasFiredRest30 {
            hasFiredRest30 = true
            if timerSoundEnabled { TimerSoundPlayer.shared.playShort() }
        }
        if remaining <= 0 {
            endRest()
        }
    }

    private var restSkipBar: some View {
        Button {
            endRest()
        } label: {
            Text("timedWorkout.circuit.skipRest", bundle: .module)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .deltiqButtonStyle()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    /// `.toFailure`s einziger Weg, eine Runde zu beenden (keine feste
    /// Wiederholungszahl, die sich automatisch erkennen liesse) - bei
    /// `.fixedReps` bewusst NICHT zusaetzlich angeboten (siehe
    /// `fixedRepsProgressBar`), um nicht zwei widerspruechliche Wege
    /// ("Checkbox" vs. "Knopf, obwohl noch nicht alle abgehakt") nebeneinander
    /// zu haben.
    private var roundActionBar: some View {
        Button {
            completeCurrentRound()
        } label: {
            Text("timedWorkout.circuit.finishRound", bundle: .module)
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

    /// `.fixedReps` braucht keinen zusaetzlichen Knopf - die Checkboxen oben
    /// SIND die Interaktion, ein "Runde beenden"-Knopf daneben waere
    /// zweideutig (erzwingt er alle Haekchen, oder ignoriert er sie?). Reine
    /// Fortschritts-Anzeige statt eines Knopfes.
    private var fixedRepsProgressBar: some View {
        let checkedCount = exercises.filter { (checkedInRound[$0.persistentModelID] ?? 0) > 0 }.count
        return Text(String(format: String(localized: "timedWorkout.circuit.checkedProgress", bundle: .module), checkedCount, exercises.count))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }
}
#endif
