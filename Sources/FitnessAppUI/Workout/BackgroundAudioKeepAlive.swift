#if canImport(AVFoundation)
import AVFoundation
#endif
import Foundation

/// Haelt die App bei gesperrtem Bildschirm oder in einer anderen App am Laufen,
/// solange ein Zeitformat-Lauf (AMRAP, EMOM, Auf Zeit, Zirkel) laeuft - damit die
/// Signaltoene ueberhaupt erklingen und die Live Activity aktuell bleibt.
///
/// **Warum so:** iOS haelt eine App im Hintergrund an, sobald sie nichts "tut".
/// Mit dem Hintergrundmodus `audio` (Info.plist, `UIBackgroundModes`) und einer
/// aktiven Audio-Session darf sie laufen, solange sie Audio ABSPIELT. Die Piepser
/// der Zeitformate (`TimerSoundPlayer`) sind kurz - dazwischen spielt dieser
/// Player eine unhoerbare Endlosschleife (eine Sekunde, hoechstens +-1 von 32768,
/// rund -90 dBFS). Die bestehende Uhr-Logik der Player (Sekundentakt, Toene,
/// Minutenwechsel) laeuft dadurch unveraendert weiter.
///
/// **Rechtfertigung (App Review 2.5.4):** Hintergrund-Audio gibt es nur fuer
/// hoerbare Signale - die Intervalltoene (kurze Piepser vor dem Wechsel, langer Ton
/// beim Wechsel/Ende) sind genau das. Laeuft nur, solange ein Lauf laeuft und der
/// Nutzer es nicht ausgeschaltet hat (`TimedWorkoutBackground`).
///
/// Dieselbe Session-Kategorie wie `TimerSoundPlayer` (`.playback` +
/// `.mixWithOthers`): Spotify/Apple Music laufen weiter, der Stumm-Schalter
/// zaehlt nicht. Unterbrechungen (Anruf, Siri, Wecker) pausieren den Player - er
/// startet danach selbst wieder (`ensureRunning`).
@MainActor
final class BackgroundAudioKeepAlive {

    static let shared = BackgroundAudioKeepAlive()

    /// `true`, solange der stille Player wirklich laeuft.
    private(set) var isRunning = false

    /// `start()` wurde gerufen und `stop()` noch nicht: Soll er laufen?
    private var isWanted = false

    #if canImport(AVFoundation)
    private var player: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    #endif

    private init() {}

    /// Startet das stille Dauer-Audio. Mehrfaches Rufen ist harmlos. `true`, wenn es
    /// laeuft - nur dann ist die App im Hintergrund wirklich am Leben.
    @discardableResult
    func start() -> Bool {
        isWanted = true
        #if canImport(AVFoundation)
        observeSession()
        #endif
        ensureRunning()
        return isRunning
    }

    func stop() {
        isWanted = false
        #if canImport(AVFoundation)
        player?.stop()
        player = nil
        removeObservers()
        #endif
        isRunning = false
    }

    /// Stellt den Player wieder her, falls er stehen geblieben ist (Unterbrechung
    /// ohne "weiter"-Hinweis, Route-Wechsel, zurueckgesetzte Medien-Dienste). Billig
    /// genug, um sie jede Sekunde zu rufen - die Player tun das ueber den Koordinator.
    func ensureRunning() {
        guard isWanted else { return }
        #if canImport(AVFoundation)
        if let player, player.isPlaying {
            isRunning = true
            return
        }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            isRunning = false
            return
        }
        #endif
        if player == nil {
            player = Self.makeSilentPlayer()
        }
        isRunning = player?.play() ?? false
        #else
        isRunning = false
        #endif
    }

    // MARK: - Session-Ereignisse

    #if canImport(AVFoundation)
    private func observeSession() {
        #if os(iOS)
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Die Benachrichtigungen kommen auf `.main` an; `assumeIsolated` haelt das
        // fest, ohne Nicht-Sendable-Werte (`Notification`) ueber Isolationsgrenzen
        // zu reichen.
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleInterruption(rawType: rawType)
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.ensureRunning()
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.rebuildAfterMediaServicesReset()
            }
        })
        #endif
    }

    private func removeObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    #if os(iOS)
    /// Nach dem Ende einer Unterbrechung (Anruf aufgelegt, Siri fertig) wieder
    /// anspielen. Der Beginn braucht nichts: das System pausiert den Player selbst.
    private func handleInterruption(rawType: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        if type == .ended {
            ensureRunning()
        }
    }

    /// Nach einem Reset der Medien-Dienste sind alle Player ungueltig.
    private func rebuildAfterMediaServicesReset() {
        player?.stop()
        player = nil
        ensureRunning()
    }
    #endif

    // MARK: - Stille

    /// Eine Sekunde, 8 kHz, mono, 16 Bit PCM, als WAV im Speicher - keine Datei im
    /// Bundle noetig. Die Samples schwanken um +-1: echte Null-Daten koennte das
    /// System als "nichts zu spielen" behandeln, ein Pegel von rund -90 dBFS liegt
    /// dagegen unter dem Rauschen jedes Wandlers und ist nicht zu hoeren.
    private static func makeSilentPlayer() -> AVAudioPlayer? {
        let sampleRate = 8_000
        let sampleCount = sampleRate
        let dataSize = sampleCount * 2

        var bytes: [UInt8] = []
        bytes.reserveCapacity(44 + dataSize)
        func put32(_ value: UInt32) {
            bytes.append(contentsOf: [
                UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
                UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)
            ])
        }
        func put16(_ value: UInt16) {
            bytes.append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
        }
        bytes.append(contentsOf: Array("RIFF".utf8))
        put32(UInt32(36 + dataSize))
        bytes.append(contentsOf: Array("WAVE".utf8))
        bytes.append(contentsOf: Array("fmt ".utf8))
        put32(16)                          // Groesse des fmt-Blocks
        put16(1)                           // PCM
        put16(1)                           // mono
        put32(UInt32(sampleRate))
        put32(UInt32(sampleRate * 2))      // Bytes pro Sekunde
        put16(2)                           // Bytes pro Sample-Frame
        put16(16)                          // Bit pro Sample
        bytes.append(contentsOf: Array("data".utf8))
        put32(UInt32(dataSize))
        for index in 0..<sampleCount {
            let sample: Int16 = (index / 20) % 2 == 0 ? 1 : -1
            put16(UInt16(bitPattern: sample))
        }

        guard let player = try? AVAudioPlayer(data: Data(bytes), fileTypeHint: AVFileType.wav.rawValue) else {
            return nil
        }
        player.numberOfLoops = -1          // endlos
        player.prepareToPlay()
        return player
    }
    #endif
}
