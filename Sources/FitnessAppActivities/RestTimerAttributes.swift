#if os(iOS)
import Foundation
import ActivityKit

/// Live Activity attributes for the rest timer.
///
/// **DEL-112 Schema-Migration:** Frueher waren `setNumber` + `totalSets` in
/// den (statischen) `Attributes`. Folge: jedes Set einer Uebung brauchte
/// eine neue Activity — End-mit-Linger der alten + Request der neuen
/// loeste den Endless-Spinner-Bug aus, weil iOS in der Uebergangs-Phase
/// die Activity-Identitaet verliert.
///
/// Jetzt: nur `exerciseName` bleibt statisch (selten geaendert mid-Activity).
/// `setNumber` + `totalSets` wandern in `ContentState` → koennen via
/// `activity.update(content:)` ohne Activity-Wechsel aktualisiert werden,
/// solange der User in derselben Uebung bleibt.
///
/// Das Widget-Extension-Target importiert diesen Typ aus
/// `FitnessAppActivities` und rendert ihn via `ActivityConfiguration(for:)`.
public struct RestTimerAttributes: ActivityAttributes {

    /// Dynamic part — wird via `activity.update(content:)` aktualisiert,
    /// ohne dass die Activity selber gestoppt + neu requestet werden muss.
    /// `endDate` laesst das Widget den Timer per `Text(timerInterval:)`
    /// selbststaendig herunterzaehlen — die App muss nicht jede Sekunde
    /// pushen.
    ///
    /// **`prMessage`** ist die Post-Finish-Celebration: wenn der User ein
    /// Workout mit mindestens einem PR beendet, pushen wir einen finalen
    /// State mit diesem Feld gesetzt — die Trophy-Headline ersetzt die
    /// Timer-Surface in Lock-Screen + Dynamic Island. Die Activity dismisst
    /// sich ~8s spaeter via `.after(...)`-Policy.
    public struct ContentState: Codable, Hashable {
        public let endDate: Date
        public let originalSeconds: Int
        /// DEL-112: Set-Counter wandert von Attributes hierher — erlaubt
        /// `.update()` statt End+Request beim Wechsel auf den naechsten Satz.
        public let setNumber: Int
        public let totalSets: Int
        public let isFinished: Bool
        public let prMessage: String?

        public init(
            endDate: Date,
            originalSeconds: Int,
            setNumber: Int = 1,
            totalSets: Int = 1,
            isFinished: Bool = false,
            prMessage: String? = nil
        ) {
            self.endDate = endDate
            self.originalSeconds = originalSeconds
            self.setNumber = setNumber
            self.totalSets = totalSets
            self.isFinished = isFinished
            self.prMessage = prMessage
        }
    }

    /// Static metadata — frozen at activity-start. Mid-Activity-Wechsel der
    /// Uebung (z.B. User springt von Bankdruecken zu Klimmzuegen waehrend
    /// der Pause noch laeuft) loest weiterhin einen sauberen End+Respawn
    /// aus — Uebungswechsel mid-Pause ist ein seltener Edge-Case, hier
    /// ist der Spinner-Bug akzeptable Restrisiko.
    public let exerciseName: String

    public init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
}
#endif
