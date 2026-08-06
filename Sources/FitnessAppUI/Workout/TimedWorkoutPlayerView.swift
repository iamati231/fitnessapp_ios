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
func timedWorkoutHintRow(_ text: String) -> some View {
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
/// TrainingDay-Kommentar), keine neuen Felder dafuer noetig.
///
/// Primitive Fassung ohne `Exercise`-Abhaengigkeit: `ExerciseSpec` (Core,
/// Pre-Instanziierung in `TemplatePreviewView`) hat kein `isTimeBased`-Feld
/// (der `ProgramInstantiator` leitet das erst per Namens-Lookup gegen
/// `ExerciseLibraryData` her) - Aufrufer, die noch keine materialisierte
/// `Exercise` haben, machen diesen Lookup selbst und uebergeben das Ergebnis
/// hier rein. Geteilt zwischen allen drei Playern, WorkoutSummaryView,
/// TemplatePreviewView und DayEditorView (interne, nicht `private`
/// Sichtbarkeit).
func timedFormatTargetLabel(repsMin: Int, isTimeBased: Bool) -> String {
    isTimeBased
        ? "\(repsMin) " + String(localized: "unit.seconds.short", bundle: .module)
        : "\(repsMin) " + String(localized: "unit.reps.short", bundle: .module)
}

@available(iOS 17.0, macOS 14.0, *)
func timedFormatTargetLabel(_ exercise: Exercise) -> String {
    timedFormatTargetLabel(repsMin: exercise.repsMin, isTimeBased: exercise.isTimeBased)
}

/// Fuer Auf-Zeit: Rundenzahl × Ziel pro Runde (z.B. "5× 30 Wdh."). AMRAP/EMOM
/// zeigen nur das Ziel - der Zirkel wiederholt sich, bis die Zeit um ist,
/// es gibt keine feste Rundenzahl im Voraus.
func timedFormatCircuitLabel(repsMin: Int, isTimeBased: Bool, sets: Int, format: WorkoutTimeFormat) -> String {
    let target = timedFormatTargetLabel(repsMin: repsMin, isTimeBased: isTimeBased)
    switch format {
    case .amrap, .emom:
        return target
    case .forTime:
        return "\(max(sets, 1))× \(target)"
    }
}

/// Anzeigename des Formats - dieselben Werte, die die drei Player schon als
/// Eyebrow/Pill-Label nutzen (AMRAP/EMOM sind Akronyme, unveraendert in
/// DE/EN/TR). Fuer die Format-Kapsel ausserhalb des Players (README 2.10),
/// damit dort kein zweiter Satz Strings entsteht.
func timedFormatDisplayName(_ format: WorkoutTimeFormat) -> String {
    switch format {
    case .amrap:   return "AMRAP"
    case .emom:    return "EMOM"
    case .forTime: return String(localized: "timedWorkout.forTime.pillLabel", bundle: .module)
    }
}

/// Loc-Key fuer den "keine festen Pausen"-Fusshinweis ausserhalb des
/// Players (README 2.10/19c-19d, TemplatePreviewView + DayEditorView) - dort
/// steht statt einer (erfundenen) Pausen-Angabe eine ehrliche Erklaerung,
/// was das Format bedeutet.
func timedFormatHintKey(for format: WorkoutTimeFormat) -> String {
    switch format {
    case .amrap:   return "day.editor.timedFormat.hintAmrap"
    case .emom:    return "day.editor.timedFormat.hintEmom"
    case .forTime: return "day.editor.timedFormat.hintForTime"
    }
}

// MARK: - Vorlauf-Phase (README 2.15/23b-23c)
//
// Eigene Phase vor dem eigentlichen Lauf, gleich fuer alle drei Formate:
// Ring von n auf 0, Uebungsliste sichtbar aber gedimmt, "Jetzt starten"
// ueberspringt den Rest, Zurueck-Chevron bleibt aktiv (die Kopfzone aendert
// sich nicht - es laeuft ja noch nichts). Laenge ist eine globale
// Einstellung neben dem Timer-Ton (0 = deaktiviert, verhaelt sich exakt wie
// bisher).

/// `object(forKey:)` statt `integer(forKey:)`, damit ein fehlender Eintrag
/// (Erstinstallation) den dokumentierten Default 10 bekommt statt der
/// UserDefaults-Fallback-0 fuer fehlende Int-Keys (gleiches Muster wie
/// `DeltiqHaptics.isEnabled`). Direkter `UserDefaults`-Zugriff statt
/// `@AppStorage`, weil der Wert schon beim ersten Frame feststehen muss -
/// die Player lesen ihn im eigenen `init`, um den Countdown-State korrekt
/// vorzubelegen (kein Flackern zwischen "laeuft schon" und "Vorlauf").
private func storedPrerollSeconds() -> Int {
    UserDefaults.standard.object(forKey: "pref_preroll_seconds") as? Int ?? 10
}

/// Tonschema (README 2.15/23c): kurzer Ton bei 10 Sekunden einmal als
/// Vorwarnung, kurzer Ton bei 3/2/1, langer Ton beim Erreichen von 0 -
/// identisch fuer alle drei Formate und an denselben Schalter
/// `pref_timer_sound` gekoppelt wie die EMOM-Minutentoene. Ein Vorlauf
/// unter zehn Sekunden durchlaeuft die 10 nie, die Vorwarnung entfaellt
/// dadurch von selbst, ohne eigene Fallunterscheidung.
@MainActor
private func playPrerollTone(remaining: Int, enabled: Bool) {
    guard enabled else { return }
    switch remaining {
    case 10, 3, 2, 1: TimerSoundPlayer.shared.playShort()
    case 0: TimerSoundPlayer.shared.playLong()
    default: break
    }
}

/// Gemeinsamer Zeitblock waehrend des Vorlaufs - dieselbe Ring-Geometrie
/// wie der EMOM-Minutenring, ohne Uebungsname darunter (es hat ja noch
/// keine begonnen).
@available(iOS 17.0, macOS 14.0, *)
private func timedWorkoutPrerollCard(remaining: Int, total: Int) -> some View {
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
            Text("timedWorkout.preroll.label", bundle: .module)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Uebungsliste waehrend des Vorlaufs - sichtbar aber gedimmt und nicht
/// interaktiv. Zeigt immer ALLE Uebungen des Tages statt nur "aktuell/
/// naechste" wie EMOMs laufende Anzeige, weil waehrend des Vorlaufs noch
/// keine "aktuell" ist.
@available(iOS 17.0, macOS 14.0, *)
private func timedWorkoutPrerollExerciseList(_ exercises: [Exercise]) -> some View {
    DeltiqSection {
        ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
            DeltiqRow(
                label: exercise.displayName,
                value: timedFormatTargetLabel(exercise),
                showsDivider: index != exercises.count - 1
            )
        }
    }
    .opacity(0.4)
    .allowsHitTesting(false)
}

/// Feste Leiste waehrend des Vorlaufs - einziger Knopf, ueberspringt den
/// Rest des Countdowns.
@available(iOS 17.0, macOS 14.0, *)
private func timedWorkoutPrerollStartBar(onStart: @escaping () -> Void) -> some View {
    Button(action: onStart) {
        Text("timedWorkout.preroll.startNow", bundle: .module)
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
    .deltiqButtonStyle()
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
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
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true

    @State private var elapsedSeconds = 0
    @State private var roundsCompleted = 0
    @State private var partialReps = 0
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    /// README 2.15/23b-23c: Vorlauf-Countdown vor dem eigentlichen Lauf -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    /// README 2.15/23d: welche Uebung `partialReps` gerade meint - tippbar
    /// in der Uebungsliste umzustellen. `nil` = "erste Uebung" (Default nach
    /// Start und nach jedem "+1 Runde"), aufgeloest ueber `currentStation`.
    @State private var currentStationID: PersistentIdentifier?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: WorkoutSession) {
        self.session = session
        let stored = storedPrerollSeconds()
        prerollTotal = stored
        _prerollRemaining = State(initialValue: stored)
    }

    private var day: TrainingDay? { session.day }
    private var exercises: [Exercise] {
        (day?.activeExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
    private var capSeconds: Int { max(1, (day?.timeCapMinutes ?? 20)) * 60 }

    /// Faellt auf die erste Uebung zurueck, wenn noch keine Station
    /// angetippt wurde (oder die Liste zwischenzeitlich leer sein sollte) -
    /// deckt zugleich den "+1 Runde"-Reset ab, der `currentStationID` auf
    /// `nil` setzt statt selbst wieder auf die erste Uebung zu zeigen.
    private var currentStation: Exercise? {
        if let currentStationID, let match = exercises.first(where: { $0.persistentModelID == currentStationID }) {
            return match
        }
        return exercises.first
    }

    /// README 2.12/21a-21b: die Akzentkapsel traegt den vollen Live-Stand,
    /// nicht nur die Runden - "4 RUNDEN + 7 WDH." statt nur "4 RUNDEN". Ohne
    /// angebrochene Wiederholungen bleibt es bei den Runden allein, kein "+ 0".
    private var roundsContextText: String {
        let roundsPart = "\(roundsCompleted) " + String(localized: "timedWorkout.amrap.roundsLabel", bundle: .module)
        guard partialReps > 0 else { return roundsPart.uppercased() }
        let repsPart = "\(partialReps) " + String(localized: "unit.reps.short", bundle: .module)
        return (roundsPart + " + " + repsPart).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: "AMRAP",
                title: session.displayDayName,
                onBack: { dismiss() },
                actions: [sessionMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                if prerollRemaining > 0 {
                    timedWorkoutPrerollCard(remaining: prerollRemaining, total: prerollTotal)
                    timedWorkoutPrerollExerciseList(exercises)
                } else {
                    // Nachtrag 6. August, abends (README 2.9/18e): die erste
                    // Kapsel zeigte bisher "AMRAP" - dasselbe wie der Eyebrow
                    // direkt darueber. Live-Rundenstand ist die Information, die
                    // sonst nirgends in der Kopfzone steht. Nachtrag 6. August,
                    // spaeter (README 2.12/21a-21b): traegt jetzt auch die
                    // angebrochene Runde, sonst steht der volle Live-Stand
                    // nirgends auf einen Blick.
                    DeltiqContextRow([
                        DeltiqContextItem(roundsContextText, style: .accent),
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
                            // README 2.15/23d: Marker fuer die aktuelle
                            // Station - tippbar, um sie umzustellen, statt
                            // sie nur passiv anzuzeigen.
                            DeltiqRow(
                                icon: exercise.persistentModelID == currentStation?.persistentModelID ? "arrow.right.circle.fill" : nil,
                                label: exercise.displayName,
                                value: timedFormatTargetLabel(exercise),
                                showsDivider: index != exercises.count - 1,
                                action: {
                                    currentStationID = exercise.persistentModelID
                                    // Nachtrag (Nutzer-Feedback): der Zaehler
                                    // gehoert der NEUEN Station, nicht der
                                    // vorigen - sonst zeigt ein Wechsel von
                                    // "5/5 Liegestuetze" auf Kniebeugen
                                    // faelschlich "5" statt bei 0 zu starten.
                                    partialReps = 0
                                    DeltiqHaptics.selection()
                                }
                            )
                        }
                        timedWorkoutHintRow(String(localized: "timedWorkout.amrap.circuitHint", bundle: .module))
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
        .onAppear {
            if prerollRemaining > 0 {
                playPrerollTone(remaining: prerollRemaining, enabled: timerSoundEnabled)
            }
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
            guard elapsedSeconds < capSeconds else { return }
            elapsedSeconds += 1
            if elapsedSeconds >= capSeconds {
                isFinished = true
                DeltiqHaptics.notify(.success)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if prerollRemaining > 0 {
                timedWorkoutPrerollStartBar { finishPreroll() }
            } else if isFinished {
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

    /// Gemeinsamer Speicherpfad fuer den Menue-Eintrag UND den Knopf in
    /// `finishBar` — `completedTarget` spiegelt exakt, ob `isFinished` zum
    /// Zeitpunkt des Tippens schon (regulaer) oder noch nicht (vorzeitig)
    /// erreicht war.
    private func saveNow() {
        session.roundsCompleted = roundsCompleted
        session.partialReps = partialReps
        // README 2.15/23d: nur setzen, wenn es ueberhaupt etwas zuzuordnen
        // gibt - sonst wuerde eine Session mit 0 angebrochenen Wdh. trotzdem
        // eine "aktuelle Station" tragen, die nie zustande kam.
        session.partialRepsExerciseName = partialReps > 0 ? currentStation?.displayName : nil
        session.completedTarget = isFinished
        session.timeFormatSnapshot = .amrap
        finishTimedSession(
            session, modelContext: modelContext, healthKit: healthKit,
            prNotifications: prNotifications, navigation: navigation,
            prCelebrationsEnabled: prCelebrationsEnabled
        )
    }

    /// README 2.15/23b-23c: Uebergang von Vorlauf in den echten Lauf - egal
    /// ob durch Ablauf des Countdowns oder "Jetzt starten". Setzt `startTime`
    /// neu auf jetzt, sonst zaehlten die Vorlauf-Sekunden in Dauer/HealthKit
    /// mit (`finishTimedSession` liest `session.startTime`).
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
    }

    /// Nachtrag 6. August, abends (README 2.10/19e): stand bisher nur in
    /// `finishBar`, also erst nach Ablauf der Zielzeit editierbar - waehrend
    /// eines laufenden AMRAP steckt man aber jederzeit in einer angebrochenen
    /// Runde, die Eingabe gehoert daher durchgehend sichtbar, nicht erst am
    /// Ende.
    /// README 2.12/21a-21b: `.labelsHidden()` blendet das Stepper-eigene
    /// Label aus - das war bisher zugleich die EINZIGE Anzeige des Werts, ein
    /// Fehltipp beim Mitzaehlen war nicht erkennbar. Der Wert steht jetzt
    /// zusaetzlich, sichtbar, im rechten Slot vor dem Stepper (Muster der
    /// anderen 15 `DeltiqControlRow`-Stellen im Repo, z.B. `OneRepMaxView`).
    /// README 2.15/23d: Label traegt jetzt den Namen der aktuellen Station
    /// statt des generischen "Zusaetzliche Wdh." - "7" allein sagt nicht,
    /// ob sieben Liegestuetze oder sieben Kniebeugen. Wert zeigt zusaetzlich
    /// das Ziel dahinter ("7 / 10").
    /// Nachtrag (Nutzer-Feedback 6. August): Stepper-Range jetzt an das
    /// tatsaechliche Ziel der Station gebunden statt 0...999 - die
    /// Standard-Wiederholungszahl MUSS man sowieso machen, ein offener
    /// Zaehler bis 999 suggerierte faelschlich freie Wahl. Erreichen des
    /// Ziels ruckt automatisch zur naechsten Station vor (`advancePartialRound`).
    private var partialRepsStepperRow: some View {
        DeltiqControlRow(label: currentStation?.displayName ?? String(localized: "timedWorkout.amrap.partialReps", bundle: .module)) {
            HStack(spacing: 8) {
                Text(partialRepsValueText)
                    .font(.system(size: 17))
                    .fitnessNumberStyle()
                Stepper(value: $partialReps, in: 0...(currentStation?.repsMin ?? 999)) {
                    Text("\(partialReps)")
                        .fitnessNumberStyle()
                }
                .labelsHidden()
                .onChange(of: partialReps) { _, newValue in
                    guard let target = currentStation?.repsMin, target > 0, newValue >= target else { return }
                    advancePartialRound()
                }
            }
        }
    }

    private var partialRepsValueText: String {
        guard let currentStation else { return "\(partialReps)" }
        return "\(partialReps) / \(currentStation.repsMin)"
    }

    private var currentStationIndex: Int? {
        guard let currentStation else { return nil }
        return exercises.firstIndex { $0.persistentModelID == currentStation.persistentModelID }
    }

    /// README (Nutzer-Feedback 6. August): das Erreichen der vollen
    /// Wiederholungszahl an der aktuellen Station bedeutet automatisch
    /// "weiter zur naechsten" - die Standard-Wiederholungen sind ja
    /// ohnehin Pflicht, ein manueller Stationswechsel per Antippen bleibt
    /// nur noch fuer Korrekturen/Spruenge noetig. An der letzten Station
    /// schliesst das Erreichen des Ziels stattdessen eine komplette Runde
    /// ab - identisch zum manuellen "+1 Runde"-Knopf.
    private func advancePartialRound() {
        guard let currentStationIndex else { return }
        let nextIndex = currentStationIndex + 1
        if nextIndex < exercises.count {
            currentStationID = exercises[nextIndex].persistentModelID
            partialReps = 0
            DeltiqHaptics.selection()
        } else {
            completeRound()
        }
    }

    /// Gemeinsamer Pfad fuer den manuellen "+1 Runde"-Knopf UND das
    /// automatische Rundenende aus `advancePartialRound()`.
    private func completeRound() {
        roundsCompleted += 1
        partialReps = 0
        currentStationID = nil
        DeltiqHaptics.notify(.success)
    }

    private var roundBar: some View {
        VStack(spacing: 10) {
            partialRepsStepperRow
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
                // Nachtrag 6. August, abends (README 2.9/18e): war 56pt fix,
                // der Knopf daneben bekommt seine Hoehe aus deltiqButtonStyle
                // (.headline + 14pt vertikales Padding ≈ 49pt) - beide standen
                // in der zentrierten HStack 3.5pt versetzt. 49 matcht die
                // tatsaechliche Knopf-Hoehe.
                .frame(width: 76, height: 49)
                .background(Color.Deltiq.fill)
                .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))

                Button {
                    completeRound()
                } label: {
                    Text("timedWorkout.amrap.addRound", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    private var finishBar: some View {
        VStack(spacing: 10) {
            partialRepsStepperRow
            Button {
                saveNow()
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
    /// README 2.15/23b-23c: Vorlauf-Countdown vor der ersten Minute -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: WorkoutSession) {
        self.session = session
        let stored = storedPrerollSeconds()
        prerollTotal = stored
        _prerollRemaining = State(initialValue: stored)
    }

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
                actions: [sessionMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                if prerollRemaining > 0 {
                    timedWorkoutPrerollCard(remaining: prerollRemaining, total: prerollTotal)
                    timedWorkoutPrerollExerciseList(exercises)
                } else {
                    // Nachtrag 6. August, abends (README 2.9/18e): die erste
                    // Kapsel zeigte bisher "EMOM" - dasselbe wie der Eyebrow
                    // direkt darueber. Live-Stand der geschafften Minuten ist
                    // die Information, die sonst nirgends in der Kopfzone steht.
                    DeltiqContextRow([
                        DeltiqContextItem(
                            String(format: String(localized: "timedWorkout.emom.completedPill", bundle: .module), completedMinutes.count).uppercased(),
                            style: .accent
                        ),
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
            } else {
                scheduleBackgroundSignals()
            }
        }
        .onDisappear {
            // Muss in JEDEM Ausstiegspfad laufen (Finish, Discard, Zurueck-
            // Chevron) - sonst poppen spaeter Banner fuer eine laengst
            // verlassene Session auf.
            Task { await ReminderScheduler.cancelEMOMSignals() }
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
            // Drei Signaltoene ab 0:03, Blick bleibt auf der Hantel.
            if timerSoundEnabled, (1...3).contains(remainingInMinute) {
                TimerSoundPlayer.shared.playShort()
            }
            secondsIntoMinute += 1
            if secondsIntoMinute >= 60 {
                secondsIntoMinute = 0
                if currentMinute >= totalMinutes {
                    isFinished = true
                    // Nachtrag 6. August (README 2.9/OFFENE-VIEWS): ein
                    // komplett durchgezogener Lauf zaehlt als alle Minuten
                    // geschafft, unabhaengig davon ob "Minute geschafft"
                    // jedes Mal angetippt wurde - sonst landet ein voll
                    // absolviertes EMOM als 0 im Verlauf.
                    completedMinutes = Set(1...totalMinutes)
                    DeltiqHaptics.notify(.success)
                } else {
                    currentMinute += 1
                    if timerSoundEnabled { TimerSoundPlayer.shared.playLong() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if prerollRemaining > 0 {
                timedWorkoutPrerollStartBar { finishPreroll() }
            } else if isFinished {
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

    /// Gemeinsamer Speicherpfad fuer den Menue-Eintrag UND den Knopf in
    /// `finishBar` — `completedTarget` spiegelt exakt, ob `isFinished` zum
    /// Zeitpunkt des Tippens schon (regulaer, Minuten schon auf
    /// `Set(1...totalMinutes)` aufgefuellt) oder noch nicht (vorzeitig)
    /// erreicht war.
    private func saveNow() {
        session.completedMinuteCount = completedMinutes.count
        session.completedTarget = isFinished
        session.timeFormatSnapshot = .emom
        finishTimedSession(
            session, modelContext: modelContext, healthKit: healthKit,
            prNotifications: prNotifications, navigation: navigation,
            prCelebrationsEnabled: prCelebrationsEnabled
        )
    }

    /// README 2.15/23b-23c: Uebergang von Vorlauf in den echten Lauf - egal
    /// ob durch Ablauf des Countdowns oder "Jetzt starten". Setzt `startTime`
    /// neu auf jetzt (sonst zaehlten die Vorlauf-Sekunden in Dauer/HealthKit
    /// mit) und stoesst die Hintergrund-Signale erst JETZT an, nicht schon
    /// beim Mount - sonst waeren sie um die Vorlauf-Laenge zu frueh.
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        scheduleBackgroundSignals()
    }

    /// README 2.9 Phase 4: Alle Minutentrigger im Voraus planen, nicht erst
    /// reaktiv beim Minutenwechsel - `Timer.publish` oben pausiert sobald
    /// die App backgrounded wird, es gibt also keine Gelegenheit mehr,
    /// waehrend des Trainings nachzuplanen. Gated ueber denselben Pref wie
    /// der In-App-Ton (wer den ausgeschaltet hat, will vermutlich auch
    /// keine Notification-Toene). Laeuft entweder direkt beim Mount (kein
    /// Vorlauf eingestellt) oder beim Uebergang aus dem Vorlauf
    /// (`finishPreroll`) - nie beides, da sich die beiden Aufrufstellen
    /// gegenseitig ausschliessen (`prerollRemaining == 0` beim Mount
    /// bedeutet, dass der Vorlauf-Zweig in `onReceive` nie greift).
    private func scheduleBackgroundSignals() {
        guard timerSoundEnabled else { return }
        Task {
            await ReminderScheduler.scheduleEMOMSignals(
                totalMinutes: totalMinutes,
                minuteTitle: "EMOM",
                minuteBodyFormat: String(localized: "timedWorkout.emom.notification.nextMinute", bundle: .module),
                finishTitle: "EMOM",
                finishBody: String(localized: "timedWorkout.emom.notification.complete", bundle: .module)
            )
        }
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
            saveNow()
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
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true

    @State private var elapsedSeconds = 0
    @State private var checkedRounds: [PersistentIdentifier: Int] = [:]
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    /// README 2.15/23b-23c: Vorlauf-Countdown vor dem eigentlichen Lauf -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: WorkoutSession) {
        self.session = session
        let stored = storedPrerollSeconds()
        prerollTotal = stored
        _prerollRemaining = State(initialValue: stored)
    }

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
                actions: [sessionMenuAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                if prerollRemaining > 0 {
                    timedWorkoutPrerollCard(remaining: prerollRemaining, total: prerollTotal)
                    timedWorkoutPrerollExerciseList(exercises)
                } else {
                    // Nachtrag 6. August, abends (README 2.9/18e): die erste
                    // Kapsel kam aus derselben `pillLabel`-Variable wie der
                    // Eyebrow direkt darueber - identischer Text zweimal. Anders
                    // als AMRAP/EMOM gibt's bei Auf Zeit keinen weiteren Live-
                    // Zustand, der noch nicht angezeigt wird (Zeit ist schon die
                    // Hero-Zahl, Fortschritt ist schon die verbleibende Kapsel) -
                    // die redundante Kapsel entfaellt komplett statt erfundenen
                    // Inhalt zu zeigen.
                    DeltiqContextRow([
                        DeltiqContextItem(
                            String(
                                format: String(localized: "timedWorkout.forTime.progressContext", bundle: .module),
                                checkedBoxes, totalBoxes
                            ).uppercased(),
                            style: .accent
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
            }
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
            elapsedSeconds += 1
            if let capSeconds, elapsedSeconds >= capSeconds {
                isFinished = true
                DeltiqHaptics.notify(.success)
            }
        }
        // Nachtrag 6. August, abends (README 2.9/18e): stand bisher komplett
        // in `if isFinished` - waehrend des Laufs gab es dadurch als einziges
        // der drei Formate GAR keine feste Leiste, obwohl die gemeinsame
        // Anatomie eine fuer alle drei vorsieht. `finishBar` ist jetzt
        // durchgehend sichtbar und speichert ueber `saveNow()` mit dem
        // jeweils aktuellen Stand, egal ob regulaer oder vorzeitig.
        .safeAreaInset(edge: .bottom) {
            if prerollRemaining > 0 {
                timedWorkoutPrerollStartBar { finishPreroll() }
            } else {
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

    /// Gemeinsamer Speicherpfad fuer den Menue-Eintrag UND den durchgehend
    /// sichtbaren `finishBar`-Knopf — `completedTarget` spiegelt exakt, ob
    /// `isFinished` zum Zeitpunkt des Tippens schon (alle Runden abgehakt
    /// bzw. Zeit-Deckel erreicht) oder noch nicht (vorzeitig) erreicht war.
    /// `PRDetector.detectTimedFormatPR` nutzt genau das, um zu verhindern
    /// dass ein frueh gespeicherter, kuerzerer Lauf als Bestzeit durchgeht.
    private func saveNow() {
        session.finishTimeSeconds = elapsedSeconds
        session.completedTarget = isFinished
        session.timeFormatSnapshot = .forTime
        finishTimedSession(
            session, modelContext: modelContext, healthKit: healthKit,
            prNotifications: prNotifications, navigation: navigation,
            prCelebrationsEnabled: prCelebrationsEnabled
        )
    }

    /// README 2.15/23b-23c: Uebergang von Vorlauf in den echten Lauf - egal
    /// ob durch Ablauf des Countdowns oder "Jetzt starten". Setzt `startTime`
    /// neu auf jetzt, sonst zaehlten die Vorlauf-Sekunden in Dauer/HealthKit
    /// mit (`finishTimedSession` liest `session.startTime`).
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
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
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Haekchen sind sequentiell pro Uebung (kein wahlfreier Zugriff): ein
    /// Tap auf Index N markiert alle Runden bis N als erledigt bzw. nimmt
    /// bei einem bereits abgehakten Index alles ab N wieder zurueck.
    ///
    /// Nachtrag 6. August, abends (README 2.9/18e): das letzte Haekchen
    /// setzte bisher hart `isFinished` und alle Kreise wurden ab da
    /// `.disabled` - ein Fehltipp beendete den Lauf ohne Weg zurueck. Die
    /// Kreise bleiben jetzt immer tappbar; ein Zurueck-Abhaken macht
    /// `isFinished` rueckgaengig, AUSSER der Zeit-Deckel selbst hat schon
    /// beendet (dann ist die Uhr echt abgelaufen, das darf ein Haekchen
    /// nicht wieder aufleben lassen).
    private func toggleRound(_ tappedIndex: Int, for exercise: Exercise) {
        let current = checkedRounds[exercise.persistentModelID] ?? 0
        checkedRounds[exercise.persistentModelID] = tappedIndex < current ? tappedIndex : tappedIndex + 1
        DeltiqHaptics.notify(.success)
        if checkedBoxes == totalBoxes {
            isFinished = true
        } else if let capSeconds, elapsedSeconds >= capSeconds {
            // Zeit-Deckel hat schon beendet - ein Abhaken darf die Uhr nicht wieder starten.
        } else {
            isFinished = false
        }
    }

    private var finishBar: some View {
        Button {
            saveNow()
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
