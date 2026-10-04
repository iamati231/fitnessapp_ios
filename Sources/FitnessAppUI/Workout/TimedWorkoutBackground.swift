#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities

/// Verbindet einen laufenden Zeitformat-Player (AMRAP, EMOM, Auf Zeit, Zirkel) mit
/// dem, was im Hintergrund weiterlaufen muss: das stille Hintergrund-Audio
/// (`BackgroundAudioKeepAlive`, haelt die Uhr- und Ton-Logik der Player am Leben)
/// und die Live Activity (`TimedWorkoutActivityController`).
///
/// Ablauf aus Sicht eines Players (ueber `TimedWorkoutBackgroundRun`):
///   0. Der Vorlauf beginnt -> `beginPreroll(...)`: Er laeuft ebenfalls vom
///      Sekundentakt der App; nur das stille Audio, noch keine Live Activity.
///   1. Die Uhr laeuft (nach dem Vorlauf, auch beim Wiederaufnehmen) ->
///      `begin(...)`: Lauf anmelden, Token merken.
///   2. Jeder Tick und jeder Zustandswechsel -> `sync(_:token:)`. Das ist
///      absichtlich billig und darf jede Sekunde gerufen werden: Der Inhalt
///      (`TimedLiveContent`) aendert sich nur bei echten Zustandswechseln, nur
///      dann geht ein Update an die Live Activity. Das stille Audio laeuft nur,
///      solange ein hoerbares Signal anstehen kann
///      (`TimedLiveContent.needsAudioInBackground`).
///   3. Der Player verschwindet (gespeichert, verworfen, zurueck) -> `end(token:)`.
///
/// **Token:** "Training fortsetzen" haengt einen NEUEN Player an den Pfad, waehrend
/// der alte noch verschwindet. Dessen `end` darf den Lauf des neuen nicht
/// abbauen - jedes `begin` vergibt ein neues Token, aeltere werden ignoriert.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TimedWorkoutBackground {

    static let shared = TimedWorkoutBackground()

    /// `UserDefaults`-/`@AppStorage`-Schluessel des Schalters in den Einstellungen
    /// ("Im Hintergrund weiterlaufen"). Standard: an.
    static let audioPreferenceKey = "pref_timer_background_audio"

    /// Wartezeit von `endOrphans()` in Sekunden.
    private static let orphanGraceSeconds = 3

    private struct Run {
        let sessionKey: String
        let format: WorkoutTimeFormat
        let formatName: String
        let dayName: String
    }

    private let activities = TimedWorkoutActivityController()
    private let audio = BackgroundAudioKeepAlive.shared

    private var lastToken = 0
    private var activeToken: Int?
    private var run: Run?
    private var lastSent: TimedLiveContent?
    /// Darf fuer den laufenden Lauf Hintergrund-Audio laufen (Schalter + Ton an)?
    private var audioWanted = false

    /// `true`, wenn das stille Hintergrund-Audio gerade laeuft - dann spielt die App
    /// die Signale selbst, und der EMOM plant keine Benachrichtigungen dazu (sonst
    /// klaenge jeder Minutenwechsel doppelt).
    var isAudioRunning: Bool { audio.isRunning }

    private init() {}

    /// Gelesen wie `storedPrerollSeconds()`: `object(forKey:)`, damit ein fehlender
    /// Eintrag (Erstinstallation) "an" bedeutet statt des UserDefaults-Standards `false`.
    static func audioPreferenceEnabled() -> Bool {
        UserDefaults.standard.object(forKey: audioPreferenceKey) as? Bool ?? true
    }

    /// Der Vorlauf (5-15 s) laeuft ebenfalls vom Sekundentakt der App: Wird der
    /// Bildschirm waehrenddessen gesperrt, bliebe er sonst stehen, und das GO kaeme
    /// erst nach dem Entsperren. Nur das stille Audio - die Live Activity gibt es
    /// erst mit der Uhr (`begin`), die als neues Token den Vorlauf abloest.
    func beginPreroll(soundEnabled: Bool) -> Int {
        lastToken += 1
        activeToken = lastToken
        run = nil
        lastSent = nil
        audioWanted = soundEnabled && Self.audioPreferenceEnabled()
        if audioWanted {
            audio.start()
        } else {
            audio.stop()
        }
        return lastToken
    }

    /// Die Uhr eines Laufs laeuft. `soundEnabled` ist der Schalter "Ton abspielen":
    /// Ohne hoerbare Signale gibt es keinen Grund fuer Hintergrund-Audio. Das Audio
    /// startet erst mit dem ersten `sync` - nur wenn dann ein Signal anstehen kann.
    func begin(sessionKey: String, format: WorkoutTimeFormat, dayName: String, soundEnabled: Bool) -> Int {
        lastToken += 1
        activeToken = lastToken
        run = Run(
            sessionKey: sessionKey,
            format: format,
            formatName: timedFormatDisplayName(format),
            dayName: dayName
        )
        lastSent = nil
        audioWanted = soundEnabled && Self.audioPreferenceEnabled()
        if !audioWanted {
            audio.stop()
        }
        return lastToken
    }

    /// Meldet den aktuellen Stand. Veraltete Token (ein ueberholter Player) werden
    /// ignoriert. `resend` sendet den Inhalt auch dann, wenn er sich nicht geaendert
    /// hat: beim Zurueckkehren in den Vordergrund, wo eine Live Activity, deren
    /// Anlegen im Hintergrund scheiterte (ActivityKit startet nur im Vordergrund),
    /// nachgeholt werden kann - ohne das schluckt der Vergleich unten den Inhalt.
    func sync(_ content: TimedLiveContent, token: Int, resend: Bool = false) {
        guard token == activeToken, let run else { return }
        if audioWanted {
            if content.needsAudioInBackground {
                // Billig: haelt den Player am Laufen und stellt ihn nach einer
                // Unterbrechung wieder her.
                let wasRunning = audio.isRunning
                audio.start()
                if !wasRunning, audio.isRunning, run.format == .emom {
                    // Das Audio sprang erst nach dem Start an (z.B. Anruf beendet): Die
                    // als Rueckfall geplanten EMOM-Benachrichtigungen klaengen jetzt
                    // zusaetzlich zu den Toenen der App.
                    Task { await ReminderScheduler.cancelEMOMSignals() }
                }
            } else {
                // Nichts, was ein Ton ankuendigen muesste (Ende erreicht, Auf Zeit ohne
                // Limit, Zirkel-Arbeitsphase): Das stille Audio muss nicht laufen. Der
                // Endton selbst spielt auf einem eigenen Player zu Ende. Beginnt wieder
                // eine Lage mit Signalen (Zirkel-Pause, Auf Zeit: ein Haekchen zurueck),
                // startet es hier erneut - dann ist die App im Vordergrund.
                audio.stop()
            }
        }
        // Nur bei geaendertem Inhalt uebersetzen und senden - der Normalfall (jede
        // Sekunde) bleibt billig.
        guard resend || content != lastSent else { return }
        lastSent = content
        activities.apply(
            sessionKey: run.sessionKey,
            format: run.format,
            formatName: run.formatName,
            dayName: run.dayName,
            content: content,
            texts: Self.texts(for: run.format, content: content)
        )
    }

    /// Der Player verschwindet: Audio aus, Live Activity weg.
    func end(token: Int) {
        guard token == activeToken else { return }
        tearDown()
    }

    /// Beendet den laufenden Lauf, egal wem er gehoert: App-Reset ("Alle Daten
    /// loeschen") - dort ist kein Player mehr da, der `end` riefe.
    func endAll() {
        tearDown()
    }

    private func tearDown() {
        let wasEMOM = run?.format == .emom
        activeToken = nil
        run = nil
        lastSent = nil
        audioWanted = false
        audio.stop()
        activities.end()
        if wasEMOM {
            // Die als Rueckfall geplanten EMOM-Benachrichtigungen gehoeren zum Lauf.
            // Hier statt im Player: Das Token schuetzt einen neueren Lauf davor, dass
            // der Abgang eines alten Players dessen frisch geplante Signale loescht.
            Task { await ReminderScheduler.cancelEMOMSignals() }
        }
    }

    /// Nach einem App-Start: Eine Live Activity eines frueheren Prozesses (App
    /// beendet, waehrend ein Lauf lief) hat keinen Player mehr, der sie fuehrt.
    /// Das Aufraeumen wartet einen Moment: Der Tipp auf die Live Activity, der die App
    /// kalt startet, oeffnet das Training und startet damit einen neuen Lauf - die
    /// Reihenfolge mit diesem Aufruf ist nicht festgelegt. Laeuft nach der Frist schon
    /// ein Lauf, bleibt er (und seine Live Activity) unberuehrt.
    func endOrphans() {
        Task { [self] in
            try? await Task.sleep(for: .seconds(Self.orphanGraceSeconds))
            guard activeToken == nil else { return }
            activities.end()
        }
    }

    // MARK: - Texte

    /// Die Texte der Live Activity in der Sprache der App - bestehende Schluessel
    /// der Player, damit nichts doppelt gepflegt wird.
    private static func texts(for format: WorkoutTimeFormat, content: TimedLiveContent) -> TimedWorkoutLiveTexts {
        let phase: String
        switch content.phase {
        case .running:  phase = String(localized: "timedWorkout.running.label", bundle: .module)
        case .rest:     phase = String(localized: "timedWorkout.circuit.pauseLabel", bundle: .module)
        case .finished: phase = String(localized: "timedWorkout.forTime.finishedLabel", bundle: .module)
        }

        let total = content.counterTotal ?? content.counter
        let status: String
        switch format {
        case .amrap:
            let pattern = content.counter == 1
                ? String(localized: "timedWorkout.amrap.rounds.one", bundle: .module)
                : String(localized: "timedWorkout.amrap.rounds.other", bundle: .module)
            status = String(format: pattern, content.counter)
        case .emom:
            status = String(
                format: String(localized: "timedWorkout.emom.minuteContext", bundle: .module),
                content.counter, total
            )
        case .forTime:
            status = String(
                format: String(localized: "timedWorkout.forTime.progressContext", bundle: .module),
                content.counter, total
            )
        case .circuit:
            status = String(
                format: String(localized: "timedWorkout.circuit.roundContext", bundle: .module),
                content.counter, total
            )
        }

        let nextLabel = format == .emom
            ? String(localized: "timedWorkout.emom.nextMinute", bundle: .module)
            : ""
        return TimedWorkoutLiveTexts(phase: phase, status: status, nextLabel: nextLabel)
    }
}

/// Haengt den Hintergrund-Lauf eines Players an dessen LEBENSDAUER: Liegt es als
/// `@State` im Player, ruft der Deinit `end`, sobald SwiftUI den Zustand freigibt.
///
/// Noetig, weil `onDisappear` allein nicht reicht: Bei einem Tab-Wechsel bleibt der
/// Lauf absichtlich bestehen (der Player lebt ja weiter). Wird der Player dann
/// zerstoert, waehrend er nicht sichtbar ist - "Alle Daten loeschen", "Verwerfen &
/// starten" auf dem Dashboard -, kommt kein `onDisappear` mehr, und das stille Audio
/// spielte bis zum Prozessende weiter. Das Token schuetzt wie immer einen neueren
/// Lauf: Ein `end` mit altem Token ist wirkungslos.
@available(iOS 17.0, macOS 14.0, *)
final class TimedWorkoutBackgroundRun {

    private(set) var token: Int?

    @MainActor
    func beginPreroll(soundEnabled: Bool) {
        token = TimedWorkoutBackground.shared.beginPreroll(soundEnabled: soundEnabled)
    }

    @MainActor
    func begin(sessionKey: String, format: WorkoutTimeFormat, dayName: String, soundEnabled: Bool) {
        token = TimedWorkoutBackground.shared.begin(
            sessionKey: sessionKey, format: format, dayName: dayName, soundEnabled: soundEnabled
        )
    }

    @MainActor
    func sync(_ content: TimedLiveContent, resend: Bool = false) {
        guard let token else { return }
        TimedWorkoutBackground.shared.sync(content, token: token, resend: resend)
    }

    @MainActor
    func end() {
        guard let token else { return }
        self.token = nil
        TimedWorkoutBackground.shared.end(token: token)
    }

    deinit {
        guard let token else { return }
        Task { @MainActor in
            TimedWorkoutBackground.shared.end(token: token)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension WorkoutSession {
    /// Erkennt denselben Lauf ueber ein neu aufgebautes View hinweg: `startTime` wird
    /// beim Ende des Vorlaufs EINMAL gesetzt und aendert sich danach nicht mehr
    /// (anders als die `persistentModelID`, die sich beim ersten Speichern einer
    /// neuen Session aendern kann).
    var backgroundSessionKey: String {
        String(Int(startTime.timeIntervalSince1970))
    }
}

/// Langer Ton, wenn die Zeit eines Zeitformats ablaeuft (Deckel von AMRAP/EMOM/
/// Auf Zeit) - das Signal, auf das man bei gesperrtem Bildschirm wartet.
///
/// `overshootSeconds` ist, wie weit der Deckel schon ueberschritten ist. Nur ein
/// Ablauf, der gerade eben passiert ist, bekommt den Ton: Kehrt jemand erst
/// Minuten nach dem Ende in die App zurueck (Hintergrund-Audio aus, App war
/// angehalten), waere ein spaeter Ton falsch.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
func playTimeUpTone(overshootSeconds: Int, enabled: Bool) {
    guard enabled, overshootSeconds <= 2 else { return }
    TimerSoundPlayer.shared.playLong()
}
#endif
