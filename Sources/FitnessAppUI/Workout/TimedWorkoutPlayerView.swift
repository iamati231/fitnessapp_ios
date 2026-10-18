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
        case .circuit: CircuitPlayerView(session: session)
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
/// Nutzer-Feedback (13. August, zweite Runde): nicht mehr `private` -
/// `CircuitPlayerView` (eigene Datei, `CircuitWorkoutPlayerView.swift`)
/// braucht denselben Speicherpfad wie die drei Player hier.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
func finishTimedSession(
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
    // P8 Stufe-2: kein erneuter capture-Aufruf — siehe
    // ActiveWorkoutView.finishWorkout für die Begründung. Gilt für alle vier
    // Zeitformate (AMRAP/EMOM/Auf Zeit/Circuit), die diese Funktion teilen.
    session.isCompleted = true
    // Sonst bleibt's beim init-Default 0 - ActiveWorkoutView.finishWorkout()
    // setzt das analog aus der Plan-Uebungsliste (siehe dort), Zeitformat-
    // Tage haben aber nie ExerciseLogs, aus denen es sich sonst herleiten liesse.
    // P8 Stufe-2: aus dem eingefrorenen Snapshot (aufgelöst gegen die noch
    // existierenden Live-Objekte), NICHT mehr aus dem ggf. zwischenzeitlich
    // extern veränderten Live-Tag — gleiches Prinzip wie
    // `ActiveWorkoutView.finishWorkout`s `resolvedExercises.count`.
    session.exerciseCount = {
        guard let day = session.day else { return 0 }
        switch session.contentSnapshotState {
        case .available(let snapshot):
            return SessionContentResolver.resolve(snapshot: snapshot, liveExercises: day.activeExercises)
                .filter { if case .live = $0 { return true } else { return false } }
                .count
        case .notCaptured, .unreadable:
            return day.activeExercises.count
        }
    }()

    let detectedPR = PersonalRecordSync.recordTimedFormatPR(for: session, in: modelContext)
    // README 2.16 (28c): gleiche Tonlage-Kopplung wie ActiveWorkoutView.finishWorkout()
    // - hier ohne @Query, da finishTimedSession eine freie Funktion ist.
    let tone = (try? modelContext.fetch(FetchDescriptor<UserBodyProfile>()))?.first?.coachingTone ?? .analytical
    let celebration = prCelebrationsEnabled
        ? PRCelebration.make(from: detectedPR.map { [$0] } ?? [], tone: tone)
        : nil

    // Nach Apple Health schreiben (Schalter + Klassifikation wie in
    // ActiveWorkoutView.finishWorkout). Kein Set-/Volumen-Logging bei
    // Zeitformaten - Dauer ist das aussagekraeftige Signal; ein Zeitformat-Tag
    // aus reinen Cardio-Uebungen (Lauf-/Rad-Intervall) zaehlt als Cardio.
    HealthWorkoutWriter.pushLive(session: session, healthKit: healthKit, context: modelContext)
    if let celebration {
        Task {
            await prNotifications.scheduleCelebration(title: celebration.title, body: celebration.body)
        }
    }

    navigation.workoutPath.append(SummaryRoute(session: session))
}

/// Loescht eine noch nicht abgeschlossene Zeitformat-Session (Abbrechen-Pfad
/// im Ellipsis-Menu). Frueher (vor README 2.35) waren Zeitformat-Tage immer
/// reine Plan-Tage - ein Discard durfte nur die Session loeschen, nie den
/// Tag (der gehoert weiter zum Plan). Seit dem Ad-Hoc-Zeitformat-Start
/// (`DashboardView.beginTimedAdHocWorkout` legt den Tag an,
/// `DayEditorView.actuallyStartNewSession` die Session, 43b) gibt es aber
/// auch ephemere, planlose `TrainingDay`s hier - ohne dieses Mit-Loeschen
/// wuerde ein verworfener Ad-Hoc-Start einen verwaisten Tag fuer immer im
/// Store zuruecklassen, exakt das Problem, das `ActiveWorkoutView`s
/// `sweepEmptyAdHocSession()` bzw. `DayEditorView`s
/// `sweepAbandonedAdHocDayIfNeeded()` fuer die jeweils anderen Ad-Hoc-Pfade
/// schon loesen. `session.day` wird VOR dem Session-Delete gesichert statt
/// danach gelesen, weil die Beziehung ohne Inverse nullified (Task #115).
/// Nicht mehr `private` (Nutzer-Feedback, 13. August, zweite Runde) -
/// `CircuitPlayerView` (eigene Datei) braucht denselben Abbrechen-Pfad.
@MainActor
func discardTimedSession(_ session: WorkoutSession, modelContext: ModelContext, dismiss: DismissAction) {
    let orphanedAdHocDay = session.isAdHoc ? session.day : nil
    modelContext.delete(session)
    if let orphanedAdHocDay {
        modelContext.delete(orphanedAdHocDay)
    }
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
    case .forTime, .circuit:
        // Zirkel-Tage spiegeln `TrainingDay.circuitRounds` redundant in
        // `ExerciseSpec.sets` (gleiche Konvention wie Auf-Zeit, das ebenso
        // kein eigenes Tages-Rundenfeld hat) - so braucht diese rein
        // anzeigende Funktion keinen dritten Parameter fuer die Rundenzahl.
        return "\(max(sets, 1))× \(target)"
    }
}

/// Anzeigename des Formats - dieselben Werte, die die Player schon als
/// Eyebrow/Pill-Label nutzen (AMRAP/EMOM sind Akronyme, unveraendert in
/// DE/EN/TR). Fuer die Format-Kapsel ausserhalb des Players (README 2.10),
/// damit dort kein zweiter Satz Strings entsteht.
func timedFormatDisplayName(_ format: WorkoutTimeFormat) -> String {
    switch format {
    case .amrap:   return "AMRAP"
    case .emom:    return "EMOM"
    case .forTime: return String(localized: "timedWorkout.forTime.pillLabel", bundle: .module)
    case .circuit: return String(localized: "timedWorkout.circuit.pillLabel", bundle: .module)
    }
}

/// Loc-Key fuer den "keine festen Pausen"-Fusshinweis ausserhalb des
/// Players (README 2.10/19c-19d, TemplatePreviewView + DayEditorView) - dort
/// steht statt einer (erfundenen) Pausen-Angabe eine ehrliche Erklaerung,
/// was das Format bedeutet. Zirkel hat tatsaechlich feste Pausen (anders als
/// die anderen drei Formate) - der Hint erklaert stattdessen, dass die Pause
/// per Konfiguration kommt, nicht als erfundener Wert.
func timedFormatHintKey(for format: WorkoutTimeFormat) -> String {
    switch format {
    case .amrap:   return "day.editor.timedFormat.hintAmrap"
    case .emom:    return "day.editor.timedFormat.hintEmom"
    case .forTime: return "day.editor.timedFormat.hintForTime"
    case .circuit: return "day.editor.timedFormat.hintCircuit"
    }
}

/// Vorschlagswert fuer einen Dauer-Stepper/neu angelegten Zeitformat-Tag,
/// solange `timeCapMinutes` noch nil ist - identisch zum Fallback, den die
/// Player selbst benutzen (`AMRAPPlayerView.capSeconds`/
/// `EMOMPlayerView.totalMinutes`, beide `?? 15`/`?? 12`). Geteilt zwischen
/// `DayEditorView`s Stepper und `DashboardView`s Ad-Hoc-Zeitformat-Start
/// (README 2.35, 43b), damit beide Stellen densel­ben Vorschlag machen.
/// `.forTime` braucht keinen Default, das Cap ist dort optional. `.circuit`
/// hat gar kein Minuten-Dauer-Konzept (Runden + Pause statt Uhr) - der
/// Rueckgabewert wird fuer dieses Format nirgends gelesen, siehe stattdessen
/// `defaultCircuitRounds()`/`defaultCircuitRestSeconds()` (FitnessAppCore -
/// werden auch von `DayAnalyzer` in FitnessAppData gebraucht, muessen also
/// unterhalb von UI liegen).
func defaultTimedFormatDurationMinutes(for format: WorkoutTimeFormat) -> Int {
    switch format {
    case .amrap: return 15
    case .emom: return 12
    case .forTime: return 0
    case .circuit: return 0
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
/// Nicht mehr `private` - `CircuitPlayerView` (eigene Datei) braucht
/// denselben Vorlauf-Mechanismus.
func storedPrerollSeconds() -> Int {
    UserDefaults.standard.object(forKey: "pref_preroll_seconds") as? Int ?? 10
}

/// Tonschema (Nutzerwunsch): jede Sekunde des Vorlaufs piept kurz, GO bei
/// Erreichen von 0 bekommt weiterhin den langen Ton - identisch fuer alle
/// drei Formate und an denselben Schalter `pref_timer_sound` gekoppelt wie
/// die EMOM-Minutentoene. Gilt unveraendert fuer alle drei einstellbaren
/// Vorlauf-Laengen (5/10/15s, siehe SettingsView.prerollSeconds-Picker).
/// Vorherige Fassung (README 2.15/23c) piepte nur bei 10 (Vorwarnung) und
/// 3/2/1 - bei 10s/15s Vorlauf blieb der Grossteil der Sekunden stumm.
@MainActor
func playPrerollTone(remaining: Int, enabled: Bool) {
    guard enabled else { return }
    if remaining > 0 {
        TimerSoundPlayer.shared.playShort()
    } else {
        TimerSoundPlayer.shared.playLong()
    }
}

/// Gemeinsamer Zeitblock waehrend des Vorlaufs - dieselbe Ring-Geometrie
/// wie der EMOM-Minutenring, ohne Uebungsname darunter (es hat ja noch
/// keine begonnen).
@available(iOS 17.0, macOS 14.0, *)
func timedWorkoutPrerollCard(remaining: Int, total: Int) -> some View {
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
func timedWorkoutPrerollExerciseList(_ exercises: [Exercise]) -> some View {
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
func timedWorkoutPrerollStartBar(onStart: @escaping () -> Void) -> some View {
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
    /// Nutzer-Feedback: der Timer muss auch dann korrekt weiterlaufen, wenn
    /// die App im Hintergrund war. `scenePhase` allein loest hier schon einen
    /// Re-Render aus (der die computed `elapsedSeconds` frisch aus `Date()`
    /// liest); der `.onChange` unten prueft zusaetzlich SOFORT beim
    /// Ruecksprung, ob der Deckel waehrend des Hintergrunds schon
    /// ueberschritten wurde, statt bis zum naechsten Tick zu warten.
    @Environment(\.scenePhase) private var scenePhase

    @State private var roundsCompleted = 0
    /// Nutzer-Feedback (13. August, zweite Runde): Wiederholungen der
    /// angebrochenen Runde sind wieder eingebbar - anders als vor Ticket A
    /// ("Teil-Wiederholungen entfernt") aber NICHT mehr durchgehend
    /// waehrend des Laufens, sondern nur noch als letzter Schritt in
    /// `finishBar`, nachdem der Deckel erreicht wurde (siehe
    /// `checkCapReached()`). Default 0 deckt genau den Fall ab, dass die
    /// Runde ueberhaupt nicht begonnen wurde.
    @State private var partialReps = 0
    /// Welche Uebung `partialReps` gerade meint - nur relevant/sichtbar,
    /// wenn der Zirkel mehr als eine Uebung hat (`partialRepsExercisePickerRow`).
    /// Wird in `checkCapReached()` auf die erste Uebung vorbelegt, damit
    /// `partialRepsExercise` nie ins generische Leere faellt, sobald
    /// `finishBar` erscheint.
    @State private var partialRepsExerciseID: PersistentIdentifier?
    @State private var isFinished = false
    /// Feature (Nutzerwunsch): einmaliger Hinweis-Ton beim Eintritt in die
    /// letzte Minute des Zeit-Caps. Write-Once-Flag nach demselben Muster
    /// wie `hasFiredCompletionFeedback` in `RestTimerBar` - verhindert, dass
    /// der Ton bei jedem weiteren Tick innerhalb der letzten Minute erneut
    /// abgespielt wird.
    @State private var hasFiredLastMinuteWarning = false
    @State private var showingDiscardConfirm = false
    /// Hintergrund-Lauf (stilles Audio + Live Activity), siehe
    /// `TimedWorkoutBackground`. Haengt an der Lebensdauer des Players: Wird er
    /// zerstoert, waehrend er nicht sichtbar ist (anderer Tab, dann App-Reset oder
    /// "Verwerfen & starten"), ruft kein `onDisappear` mehr `end()` - der Deinit des
    /// Handles raeumt dann auf.
    @State private var background = TimedWorkoutBackgroundRun()
    /// README 2.15/23b-23c: Vorlauf-Countdown vor dem eigentlichen Lauf -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    /// README 2.26 (Nutzer-Feedback, Screenshot Cindy/AMRAP): bleibt als
    /// `@State` (siehe Historie unten), dient aber nur noch dem Deckel-Check
    /// und der Vorlauf-Dekrementierung - die Live-ANZEIGE (Uhr, Leiste,
    /// Verstrichen-Zeile) haengt seit diesem Fix an `TimelineView` statt an
    /// einem erzwungenen State-Schreiben pro Tick (siehe `body`). Vorher
    /// schrieb der Handler bei JEDEM Tick unbedingt `displayTick += 1`, nur
    /// um ein Redraw zu erzwingen - das trieb `.onReceive` dazu, seine
    /// Combine-Anmeldung bei JEDER Rekonstruktion neu aufzubauen (Timer-
    /// Publisher sind nicht `Equatable`, SwiftUI kann "dieselbe Anmeldung
    /// wie eben" also nicht billig feststellen). `.autoconnect()` bindet die
    /// Lebensdauer des zugrundeliegenden Timers an genau DIESE Anmeldung,
    /// nicht an den Publisher selbst - eine Anmeldung, die vor Ablauf der
    /// eigenen Sekunde schon wieder verworfen und neu aufgebaut wird, kommt
    /// nie zum Fertig-Ticken. Ohne den unbedingten Pro-Tick-Schreibzwang
    /// bleibt die Anmeldung jetzt so lange stabil, wie tatsaechlich nichts
    /// anderes im View schreibt.
    /// Aeltere Historie: als einfaches `let` wurde der Publisher bei JEDER
    /// Rekonstruktion komplett neu ERZEUGT (noch vor jeder Anmeldungsfrage) -
    /// ein reiner Stored-`let` mit Default-Ausdruck wird von SwiftUI nicht
    /// ueber Rekonstruktionen hinweg festgehalten, nur `@State` ist das.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Bugfix (Nutzer-Feedback): "Training fortsetzen" (z.B.
    /// `DayEditorView.resumeOpenSession`) haengt eine NEUE
    /// `ActiveSessionRoute` an den Navigationspfad, wodurch SwiftUI eine
    /// KOMPLETT NEUE `AMRAPPlayerView`-Instanz fuer dieselbe, bereits
    /// laufende `session` erzeugt - jedes `@State` (inkl. `roundsCompleted`
    /// und `prerollRemaining`) faellt dabei auf seinen Default zurueck, der
    /// Vorlauf fing deshalb von neuem an UND `finishPreroll()` haette
    /// `session.startTime` ein zweites Mal auf "jetzt" gesetzt (die bereits
    /// verstrichene Cap-Zeit waere verschluckt worden).
    /// `session.roundsCompleted` ist `nil`, bis `finishPreroll()` es beim
    /// ALLERERSTEN echten Start auf 0 setzt (siehe dort) - ein Nicht-nil-Wert
    /// beweist also zuverlaessig "diese Session hat den Vorlauf schon einmal
    /// durchlaufen", ganz ohne neues Schema-Feld. Vorlauf wird in diesem
    /// Fall komplett uebersprungen, `roundsCompleted` aus der Session
    /// wiederhergestellt.
    init(session: WorkoutSession) {
        self.session = session
        if let existingRounds = session.roundsCompleted {
            prerollTotal = 0
            _prerollRemaining = State(initialValue: 0)
            _roundsCompleted = State(initialValue: existingRounds)
        } else {
            let stored = storedPrerollSeconds()
            prerollTotal = stored
            _prerollRemaining = State(initialValue: stored)
        }
    }

    /// P8 Stufe-2 (Resume-Isolation): Mitgliedschaft/Reihenfolge/Identität
    /// kommen aus dem eingefrorenen Snapshot dieser Session, aufgelöst
    /// gegen die aktuell noch existierenden Live-Objekte
    /// (`SessionContentResolver`) — eine externe Änderung am Tag seit
    /// Session-Start (Übung hinzugefügt/entfernt/umsortiert) darf weder
    /// die Zirkel-Liste noch die Rundenlogik (`currentExercise`/
    /// `exercises.count`) beeinflussen. Entfernte Übungen (kein Live-
    /// Gegenstück mehr) werden hier stillschweigend ausgelassen — anders
    /// als `ActiveWorkoutView` erzeugt AMRAP keine `ExerciseLog`s pro
    /// Übung, es gibt also keinen "neu loggen"-Fall, der eine sichtbare
    /// Markierung bräuchte.
    private var resolvedExercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)] {
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
    // Feature (Dauer konfigurierbar): 15 Min. ist der Default, den auch der
    // Stepper in DayEditorView anbietet, wenn `timeCapMinutes` noch nil ist.
    // P8 Stufe-2: snapshot-first — steuert die tatsächliche Timer-Logik, nicht nur die Anzeige.
    private var capSeconds: Int { max(1, (session.contentSnapshotTimeCapMinutes ?? 15)) * 60 }

    /// Nutzer-Feedback: aus der Wanduhr abgeleitet statt Tick-fuer-Tick
    /// hochgezaehlt - `Timer.publish` pausiert komplett, sobald die App
    /// backgrounded wird (iOS haelt RunLoop-Timer fuer suspendierte Apps
    /// an), ein reiner Akkumulator wuerde die Hintergrund-Sekunden also
    /// stillschweigend verschlucken. `session.startTime` ist ohnehin schon
    /// der um den Vorlauf bereinigte Anker (`finishPreroll()`), also reicht
    /// die Differenz zu `Date()` - waehrend des Vorlaufs selbst (noch kein
    /// echter Start) liefert das 0.
    private var elapsedSeconds: Int {
        guard prerollRemaining == 0 else { return 0 }
        return max(0, Int(Date().timeIntervalSince(session.startTime)))
    }

    /// README 2.18 Nachtrag (28c/27d): "1 RUNDEN" - vierte Fundstelle der
    /// "1 Saetze"-Familie. Gleiches Muster wie dashboard.recent.sets.one/
    /// .other: Zahl steckt im Format-String, nicht mehr in der Konkatenation.
    /// Nutzer-Feedback (13. August, zweite Runde): traegt wieder den
    /// "+ N Wdh."-Zusatz der angebrochenen Runde, sobald `finishBar` (nach
    /// Deckel-Ende) einen Wert > 0 eingestellt hat - identisch zum Verhalten
    /// vor Ticket A, nur dass `partialReps` jetzt ausschliesslich dort
    /// geaendert wird, nicht mehr durchgehend waehrend des Laufens.
    private var roundsContextText: String {
        let suffix = roundsCompleted == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "timedWorkout.amrap.rounds.\(suffix)")
        let roundsPart = String(localized: key, bundle: .module)
            .replacingOccurrences(of: "%lld", with: "\(roundsCompleted)")
        guard partialReps > 0 else { return roundsPart.uppercased() }
        let repsPart = "\(partialReps) " + String(localized: "unit.reps.short", bundle: .module)
        return (roundsPart + " + " + repsPart).uppercased()
    }

    /// Faellt auf die erste Uebung zurueck, wenn `partialRepsExerciseID`
    /// noch nicht gesetzt ist (kann nur der Fall sein, bevor `finishBar`
    /// je gerendert wurde) oder auf eine inzwischen entfernte Uebung
    /// zeigt.
    private var partialRepsExercise: Exercise? {
        if let partialRepsExerciseID, let match = exercises.first(where: { $0.persistentModelID == partialRepsExerciseID }) {
            return match
        }
        return exercises.first
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
                    // README 2.26 (Nutzer-Feedback): dritte Kapsel "LÄUFT" -
                    // eine stehende Uhr war von einer laufenden nicht zu
                    // unterscheiden, waehrend der Vorlauf mit "STARTET GLEICH"
                    // (timedWorkoutPrerollCard) schon einen Zustandshinweis
                    // trug. Nur solange die Session noch wirklich laeuft -
                    // nach `isFinished` steht die Uhr echt (Deckel erreicht,
                    // `finishBar` wartet auf die letzte Wiederholungs-Eingabe
                    // + "Speichern"), "LÄUFT" waere dann selbst die
                    // Falschmeldung.
                    DeltiqContextRow(
                        (isFinished ? [] : [DeltiqContextItem(String(localized: "timedWorkout.running.label", bundle: .module), style: .accent)]) + [
                        DeltiqContextItem(roundsContextText, style: .accent),
                        DeltiqContextItem(
                            String(format: String(localized: "timedWorkout.amrap.capContext", bundle: .module), (session.contentSnapshotTimeCapMinutes ?? 15)).uppercased(),
                            style: .neutral
                        )
                    ])

                    // README 2.26 (Nutzer-Feedback): Uhr, Leiste und
                    // Verstrichen-Zeile bekommen ihren Takt jetzt von
                    // `TimelineView` statt von einem erzwungenen State-
                    // Schreiben pro Tick (siehe Kommentar bei `tick` oben) -
                    // der Zeitpunkt ist eine sichtbare Eingabe (`context.date`),
                    // kein Nebeneffekt, und es gibt keine Combine-Anmeldung
                    // mehr, die vorzeitig abreissen kann.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let liveElapsed = max(0, Int(context.date.timeIntervalSince(session.startTime)))
                        DeltiqCard(accentEdge: true) {
                            VStack(spacing: 8) {
                                Text(PaceCalculator.formatDuration(max(0, capSeconds - liveElapsed)))
                                    .font(.system(size: 64, weight: .heavy))
                                    .fitnessNumberStyle()
                                    .foregroundStyle(Color.primary)
                                ProgressView(value: Double(min(liveElapsed, capSeconds)), total: Double(capSeconds))
                                    .tint(Color.deltiqOrange)
                                Text(
                                    String(
                                        format: String(localized: "timedWorkout.elapsed", bundle: .module),
                                        // README 2.26 (Kleinigkeit): "—" ist fuer
                                        // einen FEHLENDEN Wert richtig, fuer eine
                                        // echte Null falsch - gleiche Unterscheidung
                                        // wie die Pausen-Zeile in ExerciseCard.swift
                                        // (`restSeconds == 0`). Aufrufstelle
                                        // entscheidet, nicht `PaceCalculator`.
                                        liveElapsed > 0 ? PaceCalculator.formatDuration(liveElapsed) : "0:00"
                                    )
                                )
                                .font(.system(size: 12))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    DeltiqSection {
                        ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                            DeltiqRow(
                                label: exercise.displayName,
                                value: timedFormatTargetLabel(repsMin: entry(for: exercise).repsMin, isTimeBased: entry(for: exercise).isTimeBased),
                                showsDivider: index != exercises.count - 1
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
            // README 2.26: der Tick treibt hier nur noch den Deckel-Check -
            // die Live-Anzeige haengt seit diesem Fix an `TimelineView`
            // (siehe `body`), kein erzwungenes State-Schreiben pro Tick mehr
            // noetig (siehe Kommentar bei `tick` oben, warum das sogar
            // schaedlich war).
            guard !isFinished else { return }
            checkLastMinuteWarning()
            checkCapReached()
            syncBackground()
        }
        // Nutzer-Feedback: sobald die App wieder aktiv wird, sofort pruefen
        // statt bis zum naechsten Tick zu warten - `elapsedSeconds` selbst
        // ist schon korrekt (Wanduhr-basiert), es geht nur darum, `isFinished`
        // nicht erst mit bis zu 1s Verzoegerung nachzuziehen.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            checkLastMinuteWarning()
            checkCapReached()
            syncBackground(resend: true)
        }
        .safeAreaInset(edge: .bottom) {
            if prerollRemaining > 0 {
                timedWorkoutPrerollStartBar { finishPreroll() }
            } else if isFinished {
                // Nutzer-Feedback (13. August, zweite Runde): `checkCapReached()`
                // speichert nicht mehr selbst - `finishBar` ist der letzte
                // Schritt, um die angebrochene Runde noch einzutragen.
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
    /// Zeitpunkt des Aufrufs schon (regulaer, Deckel erreicht) oder noch
    /// nicht (vorzeitig ueber das Menue) erreicht war. Das Menue bleibt
    /// bewusst der ungefragte Sofort-Pfad ("ohne Rueckfrage", README 2.10/
    /// 19e) - `partialReps`/`partialRepsExerciseID` haben dort noch ihren
    /// Default (0/nil), weil `finishBar` in diesem Pfad nie sichtbar wird.
    private func saveNow() {
        session.roundsCompleted = roundsCompleted
        session.partialReps = partialReps
        session.partialRepsExerciseName = partialReps > 0 ? partialRepsExercise?.displayName : nil
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
    /// mit (`finishTimedSession` liest `session.startTime`). Laeuft nur beim
    /// ALLERERSTEN echten Start (ein Resume ueberspringt den Vorlauf
    /// komplett, siehe `init`) - `session.roundsCompleted = 0` markiert hier
    /// zuverlaessig "diese Session hat jetzt begonnen", der Wert war bis
    /// hierher `nil`.
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        session.roundsCompleted = 0
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        startBackground()
    }

    /// Hintergrund-Lauf (stilles Audio + Live Activity) starten bzw. beim
    /// Wiederaufnehmen ("Training fortsetzen") wieder aufnehmen - erst, wenn die Uhr
    /// laeuft: `session.startTime` ist erst nach dem Vorlauf der Anker.
    private func startBackground() {
        background.begin(
            sessionKey: session.backgroundSessionKey,
            format: .amrap,
            dayName: session.displayDayName,
            soundEnabled: timerSoundEnabled
        )
        syncBackground()
    }

    /// Billig genug fuer jeden Tick: `TimedLiveContent` ist bei unveraendertem
    /// Zustand gleich, dann geht nichts an die Live Activity.
    private func syncBackground(resend: Bool = false) {
        background.sync(
            TimedLiveContent.amrap(
                anchor: session.startTime,
                capSeconds: capSeconds,
                roundsCompleted: roundsCompleted,
                now: Date()
            ),
            resend: resend
        )
    }

    /// Nutzer-Feedback: `elapsedSeconds` ist Wanduhr-basiert, prueft sich
    /// also von selbst korrekt nach - dieser Check muss nur EXISTIEREN,
    /// nicht selbst die Zeit fortschreiben. Gerufen vom Tick (Normalfall,
    /// waehrend die App vorne ist) UND vom Ruecksprung aus dem Hintergrund
    /// (damit der Deckel-Ablauf nicht erst mit Verzoegerung ankommt).
    /// Nutzer-Feedback (13. August, zweite Runde): speichert nicht mehr
    /// automatisch - der Deckel kann mitten in einer Runde erreicht werden,
    /// die angebrochene Runde verdient noch einen Wert, bevor die Session
    /// tatsaechlich abgeschlossen wird (`finishBar` uebernimmt das, inkl.
    /// eigenem "Speichern"-Knopf, der `saveNow()` ruft). Vorbelegung von
    /// `partialRepsExerciseID` auf die erste Uebung passiert genau hier,
    /// nicht schon im `init` - erst ab jetzt gibt es ueberhaupt eine Stelle,
    /// die den Wert liest (`partialRepsExercise`/`finishBar`).
    private func checkCapReached() {
        guard !isFinished, elapsedSeconds >= capSeconds else { return }
        isFinished = true
        partialRepsExerciseID = exercises.first?.persistentModelID
        DeltiqHaptics.notify(.success)
        // Das Signal bei gesperrtem Bildschirm: ohne den Ton kaeme die App
        // ueber das Ende nur per Haptik (im Hintergrund wirkungslos) davon.
        playTimeUpTone(overshootSeconds: elapsedSeconds - capSeconds, enabled: timerSoundEnabled)
        syncBackground()
    }

    /// Feature (Nutzerwunsch): akustischer + haptischer Hinweis beim Eintritt
    /// in die letzte Minute vor Ablauf des Zeit-Caps. Wanduhr-basiert wie
    /// `checkCapReached()` (kein Pro-Tick-Akkumulator) und aus demselben
    /// Grund an ZWEI Stellen gerufen (Tick UND Ruecksprung aus dem
    /// Hintergrund) - sonst wuerde ein Hintergrund-Ausflug, der die
    /// 60-Sekunden-Marke ueberspringt, den Hinweis nie ausloesen.
    /// `remaining > 0` schliesst den Fall aus, dass die App erst NACH
    /// Ablauf des Caps wieder aktiv wird - dann hat `checkCapReached()`
    /// bereits das eigentliche Fertig-Signal uebernommen, ein nachtraeglicher
    /// "eine Minute uebrig"-Hinweis waere falsch.
    private func checkLastMinuteWarning() {
        let remaining = capSeconds - elapsedSeconds
        guard !hasFiredLastMinuteWarning, !isFinished, remaining > 0, remaining <= 60 else { return }
        hasFiredLastMinuteWarning = true
        if timerSoundEnabled {
            // Gleicher lange Ton wie EMOMs Minutenwechsel (`resyncMinuteState`)
            // - im bestehenden Klang-Vokabular dieser App steht er fuer
            // "eine Zeit-Schwelle wurde ueberschritten", nicht nur fuer GO.
            TimerSoundPlayer.shared.playLong()
        }
        DeltiqHaptics.notify(.warning)
    }

    /// Bugfix (Teil-Wiederholungen entfernt): der "+1 Runde"-Knopf ist der
    /// einzige verbleibende Weg, den Rundenstand zu aendern - keine
    /// Zwischenschritte pro Uebung/Station mehr.
    /// Bugfix (Nutzer-Feedback): `session.roundsCompleted` wird jetzt bei
    /// JEDER Runde mitgeschrieben, nicht erst bei `saveNow()` - sonst wuerde
    /// ein "Training fortsetzen" zwischen zwei Runden wieder auf den zuletzt
    /// GESPEICHERTEN Stand zurueckfallen statt auf den zuletzt GEZAEHLTEN.
    private func completeRound() {
        roundsCompleted += 1
        session.roundsCompleted = roundsCompleted
        DeltiqHaptics.notify(.success)
        syncBackground()
    }

    private var roundBar: some View {
        VStack(spacing: 10) {
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
                // Nachtrag 13. August (README 2.34, Nutzer-Feedback): 49pt
                // erfuellt Apples 44pt-Minimum, ist fuer wiederholte, hastige
                // Taps mitten im Satz (ausser Atem, schwitzige/zitternde
                // Finger) knapp bemessen - zumal direkt neben einem gleich
                // hohen, nicht interaktiven Kasten. Beide auf 64pt.
                // deltiqButtonStyle() bleibt unveraendert (jeder andere Knopf
                // haette das Problem sonst mit) - der Rundenknopf baut dessen
                // Optik hier lokal mit expliziter Mindesthoehe nach.
                .frame(width: 76, height: 64)
                .background(Color.Deltiq.fill)
                .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))

                Button {
                    completeRound()
                } label: {
                    Text("timedWorkout.amrap.addRound", bundle: .module)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
                .background(Color.Deltiq.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.deltiqOrange.opacity(0.25), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Deltiq.surface.ignoresSafeArea(edges: .bottom))
    }

    /// Nutzer-Feedback (13. August, zweite Runde): letzter Schritt, nachdem
    /// der Deckel erreicht wurde - anders als vor Ticket A NICHT durchgehend
    /// waehrend des Laufs sichtbar (das war der als "fiddly" entfernte
    /// Teil), sondern nur noch hier, einmalig. Uebungs-Picker nur bei einem
    /// Mehr-Uebungs-Zirkel noetig - bei genau einer Uebung (z.B. dem
    /// Ad-Hoc-Zeitformat-Start, README 2.35/43b) steht `partialRepsExercise`
    /// schon ohne jede Auswahl fest.
    private var finishBar: some View {
        VStack(spacing: 10) {
            timedWorkoutHintRow(String(localized: "timedWorkout.amrap.partialReps.hint", bundle: .module))
            if exercises.count > 1 {
                partialRepsExercisePickerRow
            }
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

    /// Wechsel der Uebung setzt `partialReps` zurueck auf 0 - ein
    /// mitgenommener Zaehler vom vorher gewaehlten Ziel waere fuer das neue
    /// Ziel (anderer Wiederholungs-/Sekunden-Deckel) i.d.R. falsch. Gleiches
    /// Verhalten wie der Stations-Wechsel vor Ticket A.
    private var partialRepsExercisePickerRow: some View {
        DeltiqControlRow(label: String(localized: "timedWorkout.amrap.partialReps.exercise", bundle: .module)) {
            Picker(selection: Binding<PersistentIdentifier?>(
                get: { partialRepsExerciseID ?? exercises.first?.persistentModelID },
                set: { newValue in
                    partialRepsExerciseID = newValue
                    partialReps = 0
                }
            )) {
                ForEach(exercises, id: \.persistentModelID) { exercise in
                    Text(exercise.displayName).tag(exercise.persistentModelID as PersistentIdentifier?)
                }
            } label: { EmptyView() }
            .pickerStyle(.menu)
        }
    }

    /// README 2.15/23d (wiederhergestellt): Label traegt den Namen der
    /// gewaehlten Uebung statt eines generischen "Zusaetzliche Wdh." - "7"
    /// allein sagt nicht, ob sieben Liegestuetze oder sieben Kniebeugen.
    /// Stepper-Range an das tatsaechliche Ziel gebunden statt 0...999 - die
    /// volle Wiederholungszahl MUSS man fuer eine komplette Runde sowieso
    /// schaffen, ein offener Zaehler bis 999 suggerierte faelschlich freie
    /// Wahl. Anders als vor Ticket A kein automatisches Vorruecken zur
    /// naechsten Station beim Erreichen des Ziels - die Zeit ist an dieser
    /// Stelle schon abgelaufen, es gibt kein "naechste Station" mehr.
    private var partialRepsStepperRow: some View {
        DeltiqControlRow(
            label: partialRepsExercise?.displayName ?? String(localized: "timedWorkout.amrap.partialReps", bundle: .module),
            showsDivider: false
        ) {
            HStack(spacing: 8) {
                Text(partialRepsValueText)
                    .font(.system(size: 17))
                    .fitnessNumberStyle()
                Stepper(value: $partialReps, in: 0...(partialRepsExercise?.repsMin ?? 999)) {
                    Text("\(partialReps)")
                        .fitnessNumberStyle()
                }
                .labelsHidden()
            }
        }
    }

    private var partialRepsValueText: String {
        guard let partialRepsExercise else { return "\(partialReps)" }
        return "\(partialReps) / \(partialRepsExercise.repsMin)"
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
    /// Nutzer-Feedback: der Timer muss auch dann korrekt weiterlaufen, wenn
    /// die App im Hintergrund war - siehe `totalElapsedSeconds` unten.
    @Environment(\.scenePhase) private var scenePhase

    @State private var completedMinutes: Set<Int> = []
    @State private var isFinished = false
    @State private var showingDiscardConfirm = false
    /// Nutzer-Feedback: haelt fest, welche Minute beim LETZTEN Resync
    /// bekannt war - unterscheidet einen echten Live-Uebergang
    /// (`currentMinute` steigt genau um 1 -> langer Ton) von einem
    /// Hintergrund-Aufholsprung (mehrere Minuten auf einmal). Beim
    /// Aufholsprung wird still resynchronisiert statt den Ton nachtraeglich
    /// abzuspielen - das haben die Hintergrund-Notifications schon
    /// uebernommen (siehe `scheduleBackgroundSignals`).
    @State private var lastKnownMinute = 1
    /// Nutzer-Feedback (Verifikation): eine Hintergrund-Notification kann
    /// genau EINE Minutengrenze ueberqueren, waehrend die App kurz
    /// backgrounded war (z.B. Bildschirm gesperrt/entsperrt) - das sieht
    /// fuer `resyncMinuteState()` identisch zu einem normalen Live-Uebergang
    /// aus (`currentMinute == lastKnownMinute + 1`), obwohl iOS den Ton der
    /// Notification bereits abgespielt hat. Ohne dieses Flag wuerde der
    /// lange Ton beim Zurueckkehren ein zweites Mal ausgeloest.
    @State private var wasBackgroundedSinceLastResync = false
    /// Hintergrund-Lauf (stilles Audio + Live Activity), siehe
    /// `TimedWorkoutBackground`. Haengt an der Lebensdauer des Players: Wird er
    /// zerstoert, waehrend er nicht sichtbar ist (anderer Tab, dann App-Reset oder
    /// "Verwerfen & starten"), ruft kein `onDisappear` mehr `end()` - der Deinit des
    /// Handles raeumt dann auf.
    @State private var background = TimedWorkoutBackgroundRun()
    /// README 2.15/23b-23c: Vorlauf-Countdown vor der ersten Minute -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    /// README 2.26: bleibt als `@State`, dient aber nur noch dem Deckel-
    /// Check und den Signaltoenen (`resyncMinuteState`) - die Live-ANZEIGE
    /// haengt seit diesem Fix an `TimelineView` statt an einem erzwungenen
    /// State-Schreiben pro Tick. Ausfuehrliche Begruendung bei derselben
    /// Property in `AMRAPPlayerView`.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Bugfix (Nutzer-Feedback): siehe ausfuehrliche Begruendung bei
    /// `AMRAPPlayerView.init` - identisches Problem ("Training fortsetzen"
    /// erzeugt eine komplett neue View-Instanz fuer dieselbe Session),
    /// identische Loesung. `session.completedMinuteCount` ist `nil`, bis
    /// `finishPreroll()` es beim allerersten echten Start auf 0 setzt - ein
    /// Nicht-nil-Wert beweist also "Vorlauf schon durchlaufen".
    /// Persistiert ist nur die ANZAHL, nicht welche konkreten Minuten
    /// abgehakt wurden - "die ersten N Minuten" rekonstruiert das bei der
    /// ueblichen sequentiellen Abhak-Reihenfolge exakt; bei uebersprungenen
    /// Minuten weicht nur der Haekchen-Zustand DIESER einen Minute
    /// kosmetisch ab, die gespeicherte Gesamtzahl bleibt in jedem Fall
    /// korrekt. `lastKnownMinute` wird auf die AKTUELLE Minute vorbelegt
    /// (statt Default 1), sonst wuerde `resyncMinuteState()` beim ersten
    /// Tick nach dem Resume faelschlich einen Live-Uebergangston abspielen,
    /// wenn genau Minute 2 gerade laeuft.
    init(session: WorkoutSession) {
        self.session = session
        if let existingCount = session.completedMinuteCount {
            prerollTotal = 0
            _prerollRemaining = State(initialValue: 0)
            _completedMinutes = State(initialValue: existingCount > 0 ? Set(1...existingCount) : [])
            // P8 Stufe-2: snapshot-first, konsistent mit `totalMinutes` unten.
            let totalMinutesAtInit = max(1, session.contentSnapshotTimeCapMinutes ?? 12)
            let elapsedAtInit = max(0, Int(Date().timeIntervalSince(session.startTime)))
            _lastKnownMinute = State(initialValue: min(elapsedAtInit / 60 + 1, totalMinutesAtInit))
        } else {
            let stored = storedPrerollSeconds()
            prerollTotal = stored
            _prerollRemaining = State(initialValue: stored)
        }
    }

    /// P8 Stufe-2 (Resume-Isolation): siehe `AMRAPPlayerView.resolvedExercises`
    /// für die volle Begründung — hier zusätzlich kritisch, weil
    /// `currentExercise(atMinute:)` über `exercises.count` rotiert: eine
    /// extern geänderte Übungszahl würde sonst verschieben, WELCHE Übung in
    /// welcher Minute dran ist.
    private var resolvedExercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)] {
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
    // P8 Stufe-2: snapshot-first — steuert die tatsächliche Minuten-/Rotationslogik, nicht nur die Anzeige.
    private var totalMinutes: Int { max(1, session.contentSnapshotTimeCapMinutes ?? 12) }
    /// Nutzer-Feedback: aus der Wanduhr abgeleitet statt Tick-fuer-Tick
    /// hochgezaehlt - gleiches Muster wie bei AMRAP/Auf Zeit. `Timer.publish`
    /// pausiert komplett im Hintergrund, ein Akkumulator wuerde die
    /// verpassten Sekunden verschlucken.
    private var totalElapsedSeconds: Int {
        totalElapsedSeconds(at: Date())
    }
    /// README 2.26: parametrisierte Fassung, damit `TimelineView` in `body`
    /// dieselbe Formel mit `context.date` statt `Date()` aufrufen kann -
    /// eine einzige Quelle der Wahrheit statt zweier paralleler
    /// Implementierungen. Die unparametrisierte `totalElapsedSeconds`
    /// bleibt fuer alle bestehenden, nicht-visuellen Aufrufstellen
    /// (Deckel-Check, Ton-Logik) unveraendert bestehen.
    private func totalElapsedSeconds(at now: Date) -> Int {
        guard prerollRemaining == 0 else { return 0 }
        return max(0, Int(now.timeIntervalSince(session.startTime)))
    }
    private var currentMinute: Int { currentMinute(elapsed: totalElapsedSeconds) }
    private func currentMinute(elapsed: Int) -> Int {
        min(elapsed / 60 + 1, totalMinutes)
    }
    private var secondsIntoMinute: Int {
        totalElapsedSeconds % 60
    }
    private var isPastCap: Bool {
        totalElapsedSeconds >= totalMinutes * 60
    }
    /// Bei mehr Minuten als Uebungen wiederholt sich der Zirkel (z.B. 2
    /// Uebungen ueber 12 Minuten = 6 Durchgaenge).
    private var currentExercise: Exercise? { currentExercise(atMinute: currentMinute) }
    private func currentExercise(atMinute minute: Int) -> Exercise? {
        guard !exercises.isEmpty else { return nil }
        return exercises[(minute - 1) % exercises.count]
    }
    private var nextExercise: Exercise? { nextExercise(atMinute: currentMinute) }
    private func nextExercise(atMinute minute: Int) -> Exercise? {
        guard !exercises.isEmpty, minute < totalMinutes else { return nil }
        return exercises[minute % exercises.count]
    }
    private var remainingInMinute: Int { remainingInMinute(elapsed: totalElapsedSeconds) }
    private func remainingInMinute(elapsed: Int) -> Int { max(0, 60 - elapsed % 60) }

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
                    // README 2.26 (Nutzer-Feedback): Kontextzeile, Ring und
                    // Naechste-Minute-Zeile bekommen ihren Takt jetzt von
                    // `TimelineView` statt von einem erzwungenen State-
                    // Schreiben pro Tick (siehe Kommentar bei `tick` oben) -
                    // alle drei haengen an derselben Wanduhr-Ablesung
                    // (`context.date`), also EINE gemeinsame `TimelineView`
                    // statt drei getrennter. Dazu dritte Kapsel "LÄUFT" -
                    // eine stehende Uhr war von einer laufenden nicht zu
                    // unterscheiden.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let liveElapsed = totalElapsedSeconds(at: context.date)
                        let liveMinute = currentMinute(elapsed: liveElapsed)
                        let liveRemaining = remainingInMinute(elapsed: liveElapsed)
                        let liveExercise = currentExercise(atMinute: liveMinute)
                        let liveNextExercise = nextExercise(atMinute: liveMinute)

                        // Nachtrag 6. August, abends (README 2.9/18e): die erste
                        // Kapsel zeigte bisher "EMOM" - dasselbe wie der Eyebrow
                        // direkt darueber. Live-Stand der geschafften Minuten ist
                        // die Information, die sonst nirgends in der Kopfzone steht.
                        // README 2.26 (Nutzer-Feedback): dritte Kapsel "LÄUFT",
                        // solange die Session noch wirklich laeuft - nach
                        // `isFinished` (Deckel erreicht, `finishBar` wartet auf
                        // "Speichern") waere sie selbst die Falschmeldung.
                        DeltiqContextRow(
                            (isFinished ? [] : [DeltiqContextItem(String(localized: "timedWorkout.running.label", bundle: .module), style: .accent)]) + [
                            DeltiqContextItem(
                                String(format: String(localized: "timedWorkout.emom.completedPill", bundle: .module), completedMinutes.count).uppercased(),
                                style: .accent
                            ),
                            DeltiqContextItem(
                                String(
                                    format: String(localized: "timedWorkout.emom.minuteContext", bundle: .module),
                                    min(liveMinute, totalMinutes), totalMinutes
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
                                        .trim(from: 0, to: CGFloat(liveRemaining) / 60.0)
                                        .stroke(Color.deltiqOrange, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 2) {
                                        Text("\(liveRemaining)")
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

                                if let liveExercise {
                                    Text(liveExercise.displayName)
                                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(.center)
                                    Text(timedFormatTargetLabel(repsMin: entry(for: liveExercise).repsMin, isTimeBased: entry(for: liveExercise).isTimeBased))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.deltiqOrange)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if let liveNextExercise {
                            DeltiqSection {
                                DeltiqRow(
                                    label: liveNextExercise.displayName,
                                    subtitle: String(localized: "timedWorkout.emom.nextMinute", bundle: .module),
                                    value: timedFormatTargetLabel(repsMin: entry(for: liveNextExercise).repsMin, isTimeBased: entry(for: liveNextExercise).isTimeBased),
                                    showsDivider: false
                                )
                            }
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
                background.beginPreroll(soundEnabled: timerSoundEnabled)
            } else {
                scheduleBackgroundSignals(audioRunning: startBackground())
            }
        }
        .onDisappear {
            // Muss in JEDEM Ausstiegspfad laufen (Finish, Discard, Zurueck-
            // Chevron) - sonst poppen spaeter Banner fuer eine laengst
            // verlassene Session auf (und das stille Audio liefe weiter).
            // Ausnahme Tab-Wechsel: Der Player lebt dann weiter (Uhr, Toene, Zaehlung)
            // und der Hintergrund-Lauf geht unveraendert weiter - Plan ist der Tab des
            // Workout-Stapels, ein anderer Tab bedeutet "weggeschaltet", nicht
            // "verlassen". Speichern (Summary ueberdeckt den Player) und Pop passieren
            // dagegen immer auf dem Plan-Tab. `end()` raeumt auch die Rueckfall-
            // Benachrichtigungen dieses EMOM ab (Token-geschuetzt: der Abgang eines
            // alten Players loescht nicht die Signale eines neueren Laufs).
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
            // README 2.26: der Tick treibt hier nur noch Ton-Logik und
            // `resyncMinuteState()` - die Live-Anzeige haengt seit diesem
            // Fix an `TimelineView` (siehe `body`).
            // Zehn Signaltoene ab 0:10 (Nutzerwunsch, vorher nur die letzten
            // drei) - kuendigt den bevorstehenden Minutenwechsel deutlich
            // frueher an, Blick bleibt auf der Hantel.
            if timerSoundEnabled, (1...10).contains(remainingInMinute) {
                TimerSoundPlayer.shared.playShort()
            }
            resyncMinuteState()
            syncBackground()
        }
        // Nutzer-Feedback: sofortige Pruefung beim Ruecksprung aus dem
        // Hintergrund statt bis zum naechsten Tick zu warten - gleiches
        // Muster wie bei AMRAP/Auf Zeit. Verifikation (Workflow): der
        // Uebergang IN den Hintergrund wird jetzt ebenfalls erfasst, damit
        // `resyncMinuteState()` einen genau-eine-Minute-Sprung waehrend eines
        // kurzen Hintergrund-Ausflugs nicht mit einem echten Live-Uebergang
        // verwechselt (siehe `wasBackgroundedSinceLastResync`).
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Nur ohne Hintergrund-Audio kann eine Benachrichtigung den Ton schon
                // gespielt haben - mit Audio gibt es keine, und der naechste Tick spielt
                // den Ton selbst (sonst ginge ein Minutenwechsel in dieser Sekunde stumm
                // verloren).
                wasBackgroundedSinceLastResync = !TimedWorkoutBackground.shared.isAudioRunning
                return
            }
            guard newPhase == .active else { return }
            resyncMinuteState()
            syncBackground(resend: true)
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
    /// beim Mount - sonst waeren sie um die Vorlauf-Laenge zu frueh. Laeuft
    /// nur beim ALLERERSTEN echten Start (ein Resume ueberspringt den
    /// Vorlauf komplett, siehe `init`) - `session.completedMinuteCount = 0`
    /// markiert hier zuverlaessig "diese Session hat jetzt begonnen".
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        session.completedMinuteCount = 0
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        scheduleBackgroundSignals(audioRunning: startBackground())
    }

    /// Hintergrund-Lauf (stilles Audio + Live Activity) starten bzw. beim
    /// Wiederaufnehmen ("Training fortsetzen") wieder aufnehmen - erst, wenn die Uhr
    /// laeuft: `session.startTime` ist erst nach dem Vorlauf der Anker. Gibt zurueck,
    /// ob das Hintergrund-Audio laeuft (siehe `scheduleBackgroundSignals`).
    @discardableResult
    private func startBackground() -> Bool {
        background.begin(
            sessionKey: session.backgroundSessionKey,
            format: .emom,
            dayName: session.displayDayName,
            soundEnabled: timerSoundEnabled
        )
        syncBackground()
        return TimedWorkoutBackground.shared.isAudioRunning
    }

    /// Billig genug fuer jeden Tick: `TimedLiveContent` ist innerhalb einer Minute
    /// gleich, nur der Minutenwechsel schickt ein Update an die Live Activity.
    private func syncBackground(resend: Bool = false) {
        background.sync(
            TimedLiveContent.emom(
                anchor: session.startTime,
                totalMinutes: totalMinutes,
                exerciseNames: exercises.map(\.displayName),
                now: Date()
            ),
            resend: resend
        )
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
    /// bedeutet, dass der Vorlauf-Zweig in `onReceive` nie greift). Der Mount
    /// kommt allerdings auch bei jeder Rueckkehr auf den Tab: dann plant dieser Aufruf
    /// mitten im Lauf neu - siehe `elapsedSeconds` unten.
    /// Laeuft das Hintergrund-Audio (`audioRunning`, Einstellung "Im Hintergrund
    /// weiterlaufen"), spielt die App die Toene selbst weiter - Benachrichtigungen
    /// kaemen dann zusaetzlich und jeder Minutenwechsel klaenge doppelt. Sie bleiben
    /// der Rueckfall fuer ausgeschaltetes oder nicht startbares Hintergrund-Audio.
    /// Der Zeitplan haengt am START des Laufs (`elapsedSeconds`): Wer mitten im Lauf
    /// neu plant (Tab-Rueckkehr, "Training fortsetzen"), verschiebt die Signale sonst
    /// um die schon verstrichene Zeit - und fuer einen beendeten Lauf gibt es keine.
    private func scheduleBackgroundSignals(audioRunning: Bool) {
        guard timerSoundEnabled, !audioRunning, !isPastCap else { return }
        let elapsed = totalElapsedSeconds
        Task {
            await ReminderScheduler.scheduleEMOMSignals(
                totalMinutes: totalMinutes,
                elapsedSeconds: elapsed,
                minuteTitle: "EMOM",
                minuteBodyFormat: String(localized: "timedWorkout.emom.notification.nextMinute", bundle: .module),
                finishTitle: "EMOM",
                finishBody: String(localized: "timedWorkout.emom.notification.complete", bundle: .module)
            )
        }
    }

    /// Nutzer-Feedback: `currentMinute`/`secondsIntoMinute` sind jetzt
    /// Wanduhr-basiert und daher immer korrekt - diese Funktion sorgt nur
    /// noch dafuer, dass der lange Uebergangston GENAU EINMAL pro echtem
    /// Live-Uebergang faellt (`currentMinute` steigt exakt um 1), waehrend
    /// ein Hintergrund-Aufholsprung ueber mehrere Minuten still
    /// resynchronisiert wird (die Hintergrund-Notifications haben das
    /// Audio-Feedback fuer die verpassten Minuten schon uebernommen), und
    /// dass `isFinished`/`completedMinutes` beim Erreichen des Deckels
    /// korrekt gesetzt werden.
    /// Verifikation (Workflow): ein Hintergrund-Ausflug kann GENAU EINE
    /// Minutengrenze ueberqueren (kurzes Sperren/Entsperren) - das sieht fuer
    /// den `+1`-Vergleich unten identisch zu einem echten Live-Uebergang
    /// aus, obwohl die Hintergrund-Notification den Ton dafuer schon
    /// gespielt hat. `wasBackgroundedSinceLastResync` unterscheidet die
    /// beiden Faelle zusaetzlich zur Sprunggroesse; `defer` setzt es bei
    /// jedem Durchlauf zurueck, damit ein spaeterer echter Live-Uebergang
    /// nicht faelschlich stumm bleibt.
    private func resyncMinuteState() {
        guard !isFinished else { return }
        defer { wasBackgroundedSinceLastResync = false }
        if isPastCap {
            isFinished = true
            // Nachtrag 6. August (README 2.9/OFFENE-VIEWS): ein komplett
            // durchgezogener Lauf zaehlt als alle Minuten geschafft,
            // unabhaengig davon ob "Minute geschafft" jedes Mal angetippt
            // wurde - sonst landet ein voll absolviertes EMOM als 0 im
            // Verlauf.
            completedMinutes = Set(1...totalMinutes)
            session.completedMinuteCount = totalMinutes
            DeltiqHaptics.notify(.success)
            // Ende des Laufs hoerbar machen (bei gesperrtem Bildschirm das einzige
            // Signal) und die Live Activity auf "Geschafft" stellen.
            // Eine zugestellte Benachrichtigung hat das Ende schon angezeigt
            // (`wasBackgroundedSinceLastResync`): dann nicht zusaetzlich der Ton der App.
            playTimeUpTone(
                overshootSeconds: totalElapsedSeconds - totalMinutes * 60,
                enabled: timerSoundEnabled && !wasBackgroundedSinceLastResync
            )
            syncBackground()
            return
        }
        guard currentMinute != lastKnownMinute else { return }
        // `secondsIntoMinute <= 2`: nur ein LIVE erlebter Uebergang bekommt den Ton. Kehrt
        // die App erst spaeter zurueck (Hintergrund-Audio durch einen Anruf unterbrochen,
        // App angehalten), waere ein verspaeteter Ton falsch - dann bleibt es still.
        if currentMinute == lastKnownMinute + 1, timerSoundEnabled, !wasBackgroundedSinceLastResync,
           secondsIntoMinute <= 2 {
            TimerSoundPlayer.shared.playLong()
        }
        lastKnownMinute = currentMinute
    }

    /// Tippen markiert die LAUFENDE Minute als geschafft - ein einzelner
    /// Tap-Bereich pro Zeiteinheit, gleiches Interaktionsmuster wie AMRAPs
    /// "+1 Runde".
    private var doneBar: some View {
        Button {
            if completedMinutes.insert(currentMinute).inserted {
                // Bugfix (Nutzer-Feedback): laufend persistieren statt erst
                // bei `saveNow()` - sonst wuerde "Training fortsetzen"
                // zwischen zwei abgehakten Minuten wieder auf den zuletzt
                // GESPEICHERTEN statt den zuletzt ABGEHAKTEN Stand zurueckfallen.
                session.completedMinuteCount = completedMinutes.count
                DeltiqHaptics.notify(.success)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: completedMinutes.contains(currentMinute) ? "checkmark.circle.fill" : "checkmark.circle")
                Text("timedWorkout.emom.markDone", bundle: .module)
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            // Nachtrag 13. August (README 2.34, Nutzer-Feedback): wie
            // AMRAPs Rundenknopf auf 64pt statt der 49pt aus
            // deltiqButtonStyle() (unveraendert) - derselbe Knopf wird
            // mitten in der Uebung, ausser Atem, wiederholt angetippt.
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
    /// Nutzer-Feedback: der Timer muss auch dann korrekt weiterlaufen, wenn
    /// die App im Hintergrund war - siehe `elapsedSeconds` unten.
    @Environment(\.scenePhase) private var scenePhase

    /// Bugfix (Nutzer-Feedback): "Training fortsetzen" erzeugt eine neue
    /// View-Instanz fuer dieselbe Session (siehe ausfuehrliche Begruendung
    /// bei `AMRAPPlayerView.init`) - anders als dort reicht hier kein
    /// einzelner Int als Restore-Signal, weil der Fortschritt PRO UEBUNG
    /// gezaehlt wird. `session.forTimeCheckedRoundsRaw` persistiert das
    /// jetzt (siehe `WorkoutSession.swift`), `init`/`toggleRound` halten
    /// diesen `@State` und das Modell synchron.
    @State private var checkedRounds: [PersistentIdentifier: Int] = [:]
    @State private var isFinished = false
    /// Verifikation (Workflow-Nachtrag): `elapsedSeconds` ist bewusst eine
    /// reine Wanduhr-Ablesung und waechst deshalb unbegrenzt weiter, AUCH
    /// nachdem `isFinished` schon feststeht - ohne diesen eingefrorenen
    /// Schnappschuss wuerde ein Zoegern vor dem Tippen auf "Speichern" die
    /// gespeicherte Zielzeit verfaelschen (frueher fror der reine Akkumulator
    /// automatisch ein, sobald `isFinished` griff). Wird bei Abschluss
    /// GENAU EINMAL gesetzt (`toggleRound` bei letztem Haekchen,
    /// `checkCapReached` bei Deckel-Ende) und beim Zurueck-Abhaken wieder
    /// geloescht.
    @State private var finishedElapsedSeconds: Int?
    @State private var showingDiscardConfirm = false
    /// Hintergrund-Lauf (stilles Audio + Live Activity), siehe
    /// `TimedWorkoutBackground`. Haengt an der Lebensdauer des Players: Wird er
    /// zerstoert, waehrend er nicht sichtbar ist (anderer Tab, dann App-Reset oder
    /// "Verwerfen & starten"), ruft kein `onDisappear` mehr `end()` - der Deinit des
    /// Handles raeumt dann auf.
    @State private var background = TimedWorkoutBackgroundRun()
    /// README 2.15/23b-23c: Vorlauf-Countdown vor dem eigentlichen Lauf -
    /// `prerollTotal` ist die Einstellung zum Mount-Zeitpunkt (unveraenderlich
    /// waehrend die View lebt), `prerollRemaining` zaehlt runter. 0
    /// ueberspringt die Phase komplett (Einstellung war deaktiviert).
    @State private var prerollRemaining: Int
    private let prerollTotal: Int
    /// README 2.26: bleibt als `@State`, dient aber nur noch dem Deckel-
    /// Check - die Live-ANZEIGE haengt seit diesem Fix an `TimelineView`
    /// statt an einem erzwungenen State-Schreiben pro Tick. Ausfuehrliche
    /// Begruendung bei derselben Property in `AMRAPPlayerView`.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Bugfix (Nutzer-Feedback): siehe ausfuehrliche Begruendung bei
    /// `AMRAPPlayerView.init` - identisches Problem, analoge Loesung.
    /// `session.forTimeCheckedRoundsRaw` ist `nil`, bis `finishPreroll()`
    /// es beim allerersten echten Start auf den "-"-Platzhalter setzt - ein
    /// Nicht-nil-Wert beweist also "Vorlauf schon durchlaufen". Die Exercise-Liste wird
    /// hier ueber den PARAMETER `session` (nicht `self`) berechnet, um
    /// `decodeCheckedRounds` aufrufen zu koennen, bevor alle Stored
    /// Properties gesetzt sind - `self.exercises` waere an dieser Stelle
    /// nicht erlaubt.
    init(session: WorkoutSession) {
        self.session = session
        if let raw = session.forTimeCheckedRoundsRaw {
            prerollTotal = 0
            _prerollRemaining = State(initialValue: 0)
            // P8 Stufe-2: ueber die statische, snapshot-first Hilfsfunktion
            // (nicht `self.resolvedExercises`, die noch nicht erreichbar
            // waere) - schuetzt `decodeCheckedRounds` davor, nach einer
            // externen Umsortierung des Tages die falsche Uebung zu treffen.
            let exercisesAtInit = Self.resolvedExercises(for: session)
            _checkedRounds = State(initialValue: Self.decodeCheckedRounds(raw, exercises: exercisesAtInit))
        } else {
            let stored = storedPrerollSeconds()
            prerollTotal = stored
            _prerollRemaining = State(initialValue: stored)
        }
    }

    /// Serialisiert `checkedRounds` (Schluessel: `Exercise.persistentModelID`,
    /// nicht selbst speicherbar) als "orderIndex=Anzahl"-Paare, kommagetrennt.
    /// P8 Stufe-2-Nachbesserung: `orderIndex` ist der EINGEFRORENE
    /// Snapshot-Wert (`entry.orderIndex`), NICHT mehr `exercise.orderIndex`
    /// live — die ursprüngliche Annahme ("ändert sich während einer
    /// laufenden Session nicht, kein Editieren der Übungsliste im Player")
    /// galt nur für DIESEN Player; eine externe Umsortierung über
    /// `DayEditorView`, während die Session offen bleibt, verschiebt den
    /// LIVEN `orderIndex` sehr wohl — `decodeCheckedRounds` hätte dann beim
    /// nächsten Resume die falsche Übung getroffen. Uebungen ohne abgehakte
    /// Runde werden weggelassen. Ergaebe das insgesamt den leeren String
    /// (frischer Start ODER die letzte verbliebene Markierung wurde gerade
    /// zurueckgenommen), wird statt dessen der Platzhalter "-"
    /// zurueckgegeben - ein leerer String wuerde beim CSV-Export/Import-
    /// Roundtrip zu `nil` normalisiert und damit "gestartet, 0 abgehakt"
    /// faelschlich zu "Vorlauf nie durchlaufen".
    private static func encodeCheckedRounds(
        _ checkedRounds: [PersistentIdentifier: Int],
        exercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)]
    ) -> String {
        let joined = exercises
            .compactMap { pair -> String? in
                guard let count = checkedRounds[pair.exercise.persistentModelID], count > 0 else { return nil }
                return "\(pair.entry.orderIndex)=\(count)"
            }
            .joined(separator: ",")
        return joined.isEmpty ? "-" : joined
    }

    /// Kehrt `encodeCheckedRounds` um. Robust gegen leere/kaputte Eintraege
    /// (ueberspringt sie statt zu crashen, deckt auch den "-"-Platzhalter
    /// ab - er hat kein "=" und faellt beim Parsen einfach durch) und gegen
    /// ein inzwischen entferntes `orderIndex` (kann dann keiner aktuellen
    /// Uebung mehr zugeordnet werden, faellt also ebenfalls weg statt einen
    /// Fehlerwert zu erzeugen). Matcht gegen `entry.orderIndex` (eingefroren),
    /// nicht gegen die ggf. extern verschobene Live-Position.
    private static func decodeCheckedRounds(
        _ raw: String,
        exercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)]
    ) -> [PersistentIdentifier: Int] {
        guard !raw.isEmpty else { return [:] }
        var result: [PersistentIdentifier: Int] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=")
            guard parts.count == 2, let orderIndex = Int(parts[0]), let count = Int(parts[1]) else { continue }
            if let match = exercises.first(where: { $0.entry.orderIndex == orderIndex }) {
                result[match.exercise.persistentModelID] = count
            }
        }
        return result
    }

    /// P8 Stufe-2 (Resume-Isolation): siehe `AMRAPPlayerView.resolvedExercises`
    /// — hier zusätzlich kritisch für `totalBoxes`/`exerciseRoundsRow`, die
    /// pro Übung `sets` als Checkbox-Anzahl lesen (Satzvorgabe, nicht nur
    /// Anzeige).
    private var resolvedExercises: [(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)] {
        Self.resolvedExercises(for: session)
    }
    /// Statisch (statt nur Instanz-Property), damit `init` sie VOR dem
    /// Setzen aller Stored Properties aufrufen kann (`self.resolvedExercises`
    /// wäre dort nicht erlaubt) — identische Logik wie die Instanz-Property
    /// oben, auch fuer `encodeCheckedRounds`/`decodeCheckedRounds` genutzt
    /// (siehe dort: `orderIndex`-Matching muss den EINGEFRORENEN Snapshot-
    /// Wert nutzen, nicht den live ggf. durch externe Umsortierung
    /// verschobenen).
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
    /// Nutzer-Feedback: aus der Wanduhr abgeleitet statt Tick-fuer-Tick
    /// hochgezaehlt - gleiches Muster wie bei AMRAP (siehe dortiger
    /// Kommentar): `Timer.publish` pausiert komplett im Hintergrund, ein
    /// Akkumulator wuerde die verpassten Sekunden verschlucken.
    private var elapsedSeconds: Int {
        guard prerollRemaining == 0 else { return 0 }
        return max(0, Int(Date().timeIntervalSince(session.startTime)))
    }
    /// Verifikation (Workflow-Nachtrag): das eigentliche Ergebnis - fuer
    /// Anzeige NACH Abschluss und fuer `saveNow()` - ist der eingefrorene
    /// Schnappschuss, sobald einer existiert, sonst die laufende Wanduhr.
    private var resultElapsedSeconds: Int {
        resultElapsedSeconds(at: Date())
    }
    /// README 2.26: parametrisierte Fassung, damit `TimelineView` in `body`
    /// dieselbe Formel mit `context.date` statt `Date()` aufrufen kann -
    /// der eingefrorene Schnappschuss (falls vorhanden) hat weiterhin
    /// Vorrang vor jeder Wanduhr-Ablesung, live oder nicht.
    private func resultElapsedSeconds(at now: Date) -> Int {
        guard let finishedElapsedSeconds else {
            guard prerollRemaining == 0 else { return 0 }
            return max(0, Int(now.timeIntervalSince(session.startTime)))
        }
        return finishedElapsedSeconds
    }
    /// Optionaler Abbruch-Deckel - anders als AMRAP/EMOM ist bei Auf Zeit
    /// meist gar keiner gesetzt, das Pensum selbst beendet den Lauf.
    /// P8 Stufe-2: snapshot-first.
    private var capSeconds: Int? { session.contentSnapshotTimeCapMinutes.map { $0 * 60 } }
    // P8 Stufe-2: `entry.sets` statt `exercise.sets` — das Gesamtpensum ("wie
    // viele Haekchen insgesamt") ist eine eingefrorene Satzvorgabe dieser
    // Session, keine Live-Ableitung.
    private var totalBoxes: Int { resolvedExercises.reduce(0) { $0 + max($1.entry.sets, 1) } }
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
                    // README 2.26 (Nutzer-Feedback): zweite Kapsel "LÄUFT",
                    // solange die Session noch wirklich laeuft - nach
                    // `isFinished` (Pensum/Deckel erreicht, "Geschafft!" steht
                    // schon in der Karte) waere sie selbst die Falschmeldung.
                    DeltiqContextRow(
                        (isFinished ? [] : [DeltiqContextItem(String(localized: "timedWorkout.running.label", bundle: .module), style: .accent)]) + [
                        DeltiqContextItem(
                            String(
                                format: String(localized: "timedWorkout.forTime.progressContext", bundle: .module),
                                checkedBoxes, totalBoxes
                            ).uppercased(),
                            style: .accent
                        )
                    ])

                    // README 2.26 (Nutzer-Feedback): die Hero-Zahl bekommt
                    // ihren Takt jetzt von `TimelineView` statt von einem
                    // erzwungenen State-Schreiben pro Tick (siehe Kommentar
                    // bei `tick` oben) - `resultElapsedSeconds(at:)` bevorzugt
                    // weiterhin den eingefrorenen Schnappschuss, falls einer
                    // existiert, sonst die Wanduhr-Ablesung aus `context.date`.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let liveResult = resultElapsedSeconds(at: context.date)
                        DeltiqCard(accentEdge: true) {
                            VStack(spacing: 4) {
                                Text(
                                    // README 2.26 (Kleinigkeit): "—" ist fuer
                                    // einen FEHLENDEN Wert richtig, fuer eine
                                    // echte Null falsch (direkt beim Start,
                                    // bevor die erste Sekunde vergangen ist) -
                                    // gleiche Unterscheidung wie AMRAPs
                                    // Verstrichen-Zeile.
                                    liveResult > 0 ? PaceCalculator.formatDuration(liveResult) : "0:00"
                                )
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
            // README 2.26: der Tick treibt hier nur noch den Deckel-Check -
            // die Live-Anzeige haengt seit diesem Fix an `TimelineView`
            // (siehe `body`).
            guard !isFinished else { return }
            checkCapReached()
            syncBackground()
        }
        // Nutzer-Feedback: sofortige Pruefung beim Ruecksprung aus dem
        // Hintergrund statt bis zum naechsten Tick zu warten - gleiches
        // Muster wie bei AMRAP.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            checkCapReached()
            syncBackground(resend: true)
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
        session.finishTimeSeconds = resultElapsedSeconds
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
    /// mit (`finishTimedSession` liest `session.startTime`). Laeuft nur
    /// beim ALLERERSTEN echten Start (ein Resume ueberspringt den Vorlauf
    /// komplett, siehe `init`) - das Setzen von `session.forTimeCheckedRoundsRaw`
    /// (hier immer der "-"-Platzhalter, da `checkedRounds` waehrend des
    /// Vorlaufs garantiert noch leer ist) markiert hier zuverlaessig "diese
    /// Session hat jetzt begonnen".
    private func finishPreroll() {
        prerollRemaining = 0
        session.startTime = Date()
        session.forTimeCheckedRoundsRaw = Self.encodeCheckedRounds(checkedRounds, exercises: resolvedExercises)
        playPrerollTone(remaining: 0, enabled: timerSoundEnabled)
        startBackground()
    }

    /// Hintergrund-Lauf (stilles Audio + Live Activity) starten bzw. beim
    /// Wiederaufnehmen ("Training fortsetzen") wieder aufnehmen - erst, wenn die Uhr
    /// laeuft: `session.startTime` ist erst nach dem Vorlauf der Anker.
    private func startBackground() {
        background.begin(
            sessionKey: session.backgroundSessionKey,
            format: .forTime,
            dayName: session.displayDayName,
            soundEnabled: timerSoundEnabled
        )
        syncBackground()
    }

    /// Billig genug fuer jeden Tick: `TimedLiveContent` ist bei unveraendertem
    /// Zustand gleich (die Uhr zaehlt das System selbst), dann geht nichts an die
    /// Live Activity.
    private func syncBackground(resend: Bool = false) {
        background.sync(
            TimedLiveContent.forTime(
                anchor: session.startTime,
                capSeconds: capSeconds,
                checkedBoxes: checkedBoxes,
                totalBoxes: totalBoxes,
                finishedElapsedSeconds: finishedElapsedSeconds,
                now: Date()
            ),
            resend: resend
        )
    }

    /// Nutzer-Feedback: `elapsedSeconds` ist Wanduhr-basiert, prueft sich
    /// also von selbst korrekt nach - dieser Check muss nur EXISTIEREN,
    /// nicht selbst die Zeit fortschreiben. Gerufen vom Tick (Normalfall)
    /// UND vom Ruecksprung aus dem Hintergrund.
    private func checkCapReached() {
        guard !isFinished, let capSeconds, elapsedSeconds >= capSeconds else { return }
        isFinished = true
        // Verifikation (Workflow-Nachtrag): eingefroren auf den Deckel selbst,
        // nicht auf den zufaelligen `elapsedSeconds`-Wert im Moment des
        // Checks (Tick-Granularitaet oder ein Hintergrund-Ruecksprung
        // koennten sonst leicht darueber liegen).
        finishedElapsedSeconds = capSeconds
        DeltiqHaptics.notify(.success)
        // Das Signal bei gesperrtem Bildschirm: Haptik allein wirkt im
        // Hintergrund nicht.
        playTimeUpTone(overshootSeconds: elapsedSeconds - capSeconds, enabled: timerSoundEnabled)
        syncBackground()
    }

    private var isLastBoxRemainingHintVisible: Bool {
        totalBoxes > 0 && checkedBoxes == totalBoxes - 1
    }

    private func exerciseRoundsRow(_ exercise: Exercise) -> some View {
        // P8 Stufe-2: Checkbox-Anzahl + Zielwert-Label kommen aus dem
        // eingefrorenen Snapshot-Eintrag, nicht aus der ggf. extern
        // geänderten Live-Übung.
        let targetEntry = entry(for: exercise)
        let rounds = max(targetEntry.sets, 1)
        let checked = checkedRounds[exercise.persistentModelID] ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                Text(timedFormatTargetLabel(repsMin: targetEntry.repsMin, isTimeBased: targetEntry.isTimeBased))
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
        // Bugfix (Nutzer-Feedback): laufend persistieren statt erst bei
        // `saveNow()` - sonst wuerde "Training fortsetzen" zwischen zwei
        // Haekchen wieder auf den zuletzt GESPEICHERTEN statt den zuletzt
        // ABGEHAKTEN Stand zurueckfallen.
        session.forTimeCheckedRoundsRaw = Self.encodeCheckedRounds(checkedRounds, exercises: resolvedExercises)
        DeltiqHaptics.notify(.success)
        if checkedBoxes == totalBoxes {
            isFinished = true
            if let capSeconds, elapsedSeconds >= capSeconds {
                // Bugfix (Audit): der Deckel hatte die Zeit schon eingefroren,
                // BEVOR der letzte Kasten abgehakt wurde - `elapsedSeconds`
                // lief seither als reine Wanduhr weiter und ist inzwischen
                // groesser als der Deckel. Ohne diesen Zweig wuerde das
                // spaete Abhaken die bereits eingefrorene Zielzeit wieder
                // ueberschreiben und faelschlich verlaengern.
                finishedElapsedSeconds = capSeconds
            } else {
                // Verifikation (Workflow-Nachtrag): JETZT einfrieren, nicht erst
                // beim Speichern - `elapsedSeconds` ist Wanduhr-basiert und
                // wuerde sonst bis zum tatsaechlichen Speichern-Tap weiterlaufen.
                finishedElapsedSeconds = elapsedSeconds
            }
        } else if let capSeconds, elapsedSeconds >= capSeconds {
            // Zeit-Deckel hat schon beendet - ein Abhaken darf die Uhr nicht wieder starten.
        } else {
            isFinished = false
            finishedElapsedSeconds = nil
        }
        syncBackground()
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
