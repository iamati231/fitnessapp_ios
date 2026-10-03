import Foundation

/// Wie lange ein Training dauerte, wenn die Wanduhr zwischen Start und Beenden
/// nicht stimmen kann: Wer einen Lauf erst NACH dem Laufen einträgt, startet und
/// beendet das Training binnen einer Minute, der eingetragene Lauf dauerte aber
/// 26. Die Wanduhr misst dann das Eintragen, nicht das Training.
public struct SessionDurationEstimate: Sendable, Equatable {

    public enum Basis: Sendable, Equatable {
        /// Wanduhr zwischen Start und Beenden: das Training lief live mit.
        case measured
        /// Nachgetragenes Cardio-Training: die eingetragene Zeit der Cardio-Sätze.
        case loggedCardioTime
        /// Nachgetragenes Krafttraining (auch mit Cardio-Anteil): der Kraftanteil
        /// ist aus der Satzzahl GESCHÄTZT, der Cardio-Anteil ist die eingetragene Zeit.
        case estimatedFromSets
    }

    public let minutes: Int
    public let basis: Basis

    public init(minutes: Int, basis: Basis) {
        self.minutes = minutes
        self.basis = basis
    }

    /// Weicht die Dauer von der gemessenen Wanduhr ab?
    public var isCorrected: Bool { basis != .measured }
}

/// Reine Regel ohne SwiftData — die einzige Stelle, die entscheidet, ob eine
/// Wanduhr-Dauer glaubwürdig ist und was sonst gilt.
///
/// - **Cardio** hat eine vom Nutzer eingetragene Zeit (`durationSeconds`). Ist sie
///   länger als die Wanduhr (plus Toleranz), kann das Training nicht live
///   aufgezeichnet worden sein: Es zählt die eingetragene Zeit.
/// - **Krafttraining** hat nur Sätze. Dauerte die Wanduhr weniger als
///   `minimumLiveSecondsPerSet` je Satz, ist sie ebenfalls das Eintragen und nicht
///   das Trainieren; dann gilt eine Schätzung aus der Satzzahl (Satzdauer plus
///   Pause der jeweiligen Übung).
/// - Alles andere (live aufgezeichnet) behält die Wanduhr unverändert.
public enum SessionDurationEstimator {

    /// Eingabe je geloggtem Satz (Platzhalter-Zeilen vorher aussortieren).
    public struct LogInput: Sendable, Equatable {
        public let isCardio: Bool
        /// Eingetragene Zeit eines Cardio-Satzes.
        public let durationSeconds: Int?
        /// Pause der Übung (Kraft); `nil` = Standard.
        public let restSeconds: Int?

        public init(isCardio: Bool, durationSeconds: Int? = nil, restSeconds: Int? = nil) {
            self.isCardio = isCardio
            self.durationSeconds = durationSeconds
            self.restSeconds = restSeconds
        }
    }

    /// Dauer eines Kraft-Satzes selbst, ohne Pause.
    public static let secondsPerSet = 45
    /// Pause, wenn die Übung keine nennt (entspricht dem Standard der Übungen).
    public static let defaultRestSeconds = 90
    public static let maximumRestSeconds = 300
    /// Kürzer als das je Satz kann ein Kraft-Training nicht live gelaufen sein
    /// (auch Supersätze ohne Pause brauchen pro Satz länger).
    public static let minimumLiveSecondsPerSet = 30
    /// Unter dieser Satzzahl wird nicht geschätzt (ein, zwei schnelle Sätze sind
    /// ein legitim kurzes Training).
    public static let minimumSetsForEstimate = 3
    /// Spielraum, bevor Cardio-Zeit länger als die Wanduhr als Nachtrag gilt.
    public static let cardioToleranceSeconds = 60
    /// Obergrenze einer korrigierten Dauer (entspricht dem Verlaufs-Editor).
    public static let maximumMinutes = 600

    /// Dauer für ein soeben beendetes Training.
    /// - Parameter wallClockSeconds: Sekunden zwischen Start und Beenden.
    public static func estimate(wallClockSeconds: Int, logs: [LogInput]) -> SessionDurationEstimate {
        let wall = max(0, wallClockSeconds)
        let measured = SessionDurationEstimate(minutes: wall / 60, basis: .measured)

        let cardioSeconds = loggedCardioSeconds(in: logs)
        let strengthLogs = logs.filter { !$0.isCardio }

        let cardioIsRetro = cardioSeconds > wall + cardioToleranceSeconds
        let strengthIsRetro = strengthLogs.count >= minimumSetsForEstimate
            && wall < strengthLogs.count * minimumLiveSecondsPerSet
        guard cardioIsRetro || strengthIsRetro else { return measured }

        let content = cardioSeconds + estimatedStrengthSeconds(for: strengthLogs)
        let minutes = min(max((max(wall, content) + 30) / 60, wall / 60), maximumMinutes)
        return SessionDurationEstimate(
            minutes: minutes,
            basis: strengthLogs.isEmpty ? .loggedCardioTime : .estimatedFromSets
        )
    }

    /// Bestehendes Training: NUR der sichere Fall — die gespeicherte Dauer ist
    /// kürzer als die eingetragene Cardio-Zeit. Das war nie ein live
    /// aufgezeichnetes Training; die Cardio-Zeit ist dann eine untere Grenze der
    /// Dauer. Kraftanteile werden bei bestehenden Daten NICHT geschätzt.
    /// - Returns: die neue Dauer in Minuten oder `nil`, wenn nichts zu korrigieren ist.
    public static func repairedMinutes(storedMinutes: Int, logs: [LogInput]) -> Int? {
        let cardioSeconds = loggedCardioSeconds(in: logs)
        guard cardioSeconds > max(storedMinutes, 0) * 60 + cardioToleranceSeconds else { return nil }
        let minutes = min((cardioSeconds + 30) / 60, maximumMinutes)
        return minutes > storedMinutes ? minutes : nil
    }

    // MARK: Hilfen

    private static func loggedCardioSeconds(in logs: [LogInput]) -> Int {
        logs.reduce(0) { total, log in
            log.isCardio ? total + max(log.durationSeconds ?? 0, 0) : total
        }
    }

    private static func estimatedStrengthSeconds(for strengthLogs: [LogInput]) -> Int {
        strengthLogs.reduce(0) { total, log in
            let rest = min(max(log.restSeconds ?? defaultRestSeconds, 0), maximumRestSeconds)
            return total + secondsPerSet + rest
        }
    }
}
