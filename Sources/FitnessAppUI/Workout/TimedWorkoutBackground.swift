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
/// Ablauf aus Sicht eines Players:
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
    /// ignoriert.
    func sync(_ content: TimedLiveContent, token: Int) {
        guard token == activeToken, let run else { return }
        if audioWanted {
            if content.needsAudioInBackground {
                // Billig: haelt den Player am Laufen und stellt ihn nach einer
                // Unterbrechung wieder her.
                audio.start()
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
        guard content != lastSent else { return }
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
        activeToken = nil
        run = nil
        lastSent = nil
        audioWanted = false
        audio.stop()
        activities.end()
    }

    /// Nach einem App-Start: Eine Live Activity eines frueheren Prozesses (App
    /// beendet, waehrend ein Lauf lief) hat keinen Player mehr, der sie fuehrt.
    /// Laeuft schon ein neuer Lauf (z.B. per Tipp auf die Live Activity gestartet),
    /// bleibt er unberuehrt.
    func endOrphans() {
        guard activeToken == nil else { return }
        activities.end()
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
