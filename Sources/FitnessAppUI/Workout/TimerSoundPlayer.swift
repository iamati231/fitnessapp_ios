#if canImport(AVFoundation)
import AVFoundation
#endif
import Foundation

/// Plays the workout timer's custom beep sounds via `AVAudioPlayer`.
///
/// DEL-045-Update Punkt 4: Wir sind weg von `AudioServicesPlaySystemSound`,
/// weil die iOS-System-IDs (1057, 1320, 1005, ...) wie Benachrichtigungs- oder
/// Error-Toene klingen — nicht wie ein Sport-Timer. Stattdessen liefern wir
/// zwei winzige WAV-Dateien (`beep_short.wav`, `beep_long.wav`) mit der
/// Library aus und spielen sie ueber `AVAudioPlayer` ab. Garantiert exakt das
/// "bip-bip-bip-biiiip"-Erlebnis.
///
/// **Lifetime-Hinweis:** `AVAudioPlayer`-Instanzen muessen *am Leben gehalten*
/// werden, bis sie fertig gespielt haben — ein lokaler `let player = try
/// AVAudioPlayer(...)` wuerde sofort wieder deallocated, bevor irgendetwas zu
/// hoeren ist. Deshalb haelt diese Klasse die letzte Player-Instanz als
/// Property; sie wird beim naechsten `play(...)`-Aufruf ueberschrieben (was
/// fuer Counter-Pips OK ist — der vorige Pip ist da laengst durch).
///
/// `@MainActor` weil die Aufrufer (`SetRow.playCountdownBeep` etc.) auch auf
/// dem Main-Actor laufen und der `AVAudioPlayer` ohnehin keine echte
/// Concurrency-Anforderungen hat.
@MainActor
final class TimerSoundPlayer {

    /// Singleton — beim allerersten Zugriff lazily instantiated.
    static let shared = TimerSoundPlayer()

    #if canImport(AVFoundation)
    private var shortPlayer: AVAudioPlayer?
    private var longPlayer: AVAudioPlayer?
    #endif

    private init() {
        #if canImport(AVFoundation)
        // Audio-Session konfigurieren:
        //   * `.playback` ueberschreibt den Silent-Switch — wichtig fuer
        //     Gym-User, die ihr iPhone stumm haben, aber den Timer-Beep
        //     hoeren wollen. Vorher (AudioServicesPlaySystemSound) ging das
        //     auch durch, also waere `.ambient` eine Regression.
        //   * `.mixWithOthers` laesst Spotify/Apple-Music in Ruhe — der
        //     Beep mischt sich kurz drueber, statt die Musik anzuhalten.
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        shortPlayer = makePlayer(name: "beep_short")
        longPlayer  = makePlayer(name: "beep_long")
        // Pre-loaded buffers reduzieren die Latenz beim ersten Pip.
        shortPlayer?.prepareToPlay()
        longPlayer?.prepareToPlay()
        #endif
    }

    /// Spielt den kurzen, hohen Pip — Counter-Tick (3/2/1).
    func playShort() {
        #if canImport(AVFoundation)
        shortPlayer?.currentTime = 0
        shortPlayer?.play()
        #endif
    }

    /// Spielt den laengeren, tieferen Ton — GO! (Countdown vorbei) oder
    /// Ziel-Zeit-erreicht-Signal.
    func playLong() {
        #if canImport(AVFoundation)
        longPlayer?.currentTime = 0
        longPlayer?.play()
        #endif
    }

    // MARK: - Helpers

    #if canImport(AVFoundation)
    /// Sucht die Resource-WAV im `Bundle.module` (SwiftPM-Resources). Crash
    /// is silent — falls die Datei jemals fehlt, bleibt der Player nil und
    /// `play*()` ist ein No-Op (besser als App-Crash zur Workout-Zeit).
    private func makePlayer(name: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav") else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
    #endif
}
