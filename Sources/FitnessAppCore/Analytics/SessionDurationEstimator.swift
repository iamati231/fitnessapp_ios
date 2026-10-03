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

    /// Die Sekunden, die das Training als gedauert gilt (bei `.measured` die Wanduhr).
    public let seconds: Int
    public let basis: Basis

    public init(seconds: Int, basis: Basis) {
        self.seconds = seconds
        self.basis = basis
    }

    /// Ganze Minuten, ABGERUNDET wie ueberall in der App (`durationMinutes`):
    /// 25:56 sind 25 Min, nie 26. Die genauen Sekunden bleiben in `seconds`, damit
    /// Beginn und Ende (und der Health-Eintrag) die Zeit exakt halten.
    public var minutes: Int { seconds / 60 }

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
        let measured = SessionDurationEstimate(seconds: wall, basis: .measured)

        let cardioSeconds = loggedCardioSeconds(in: logs)
        let strengthLogs = logs.filter { !$0.isCardio }

        let cardioIsRetro = cardioSeconds > wall + cardioToleranceSeconds
        let strengthIsRetro = strengthLogs.count >= minimumSetsForEstimate
            && wall < strengthLogs.count * minimumLiveSecondsPerSet
        // Reines Cardio: Die eingetragene Zeit IST die Dauer, sobald sie die
        // Wanduhr ueberschreitet — auch knapp (Start einige Sekunden nach dem
        // Loslaufen). Sonst stuende neben dem Satz "32:53" eine Dauer von "32:41".
        // Bei Mischtagen bleibt die Toleranz: dort kann die Cardio-Zeit Teil einer
        // laengeren Wanduhr sein.
        let pureCardioExceedsWall = strengthLogs.isEmpty && cardioSeconds > wall
        guard cardioIsRetro || strengthIsRetro || pureCardioExceedsWall else { return measured }

        // Exakte Sekunden, nicht auf Minuten gerundet; nie unter der Wanduhr.
        let content = cardioSeconds + estimatedStrengthSeconds(for: strengthLogs)
        let seconds = min(max(wall, content), max(maximumMinutes * 60, wall))
        return SessionDurationEstimate(
            seconds: seconds,
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
        let minutes = min(cardioSeconds / 60, maximumMinutes)
        return minutes > storedMinutes ? minutes : nil
    }

    /// Die Dauer auf die Sekunde, wenn Beginn und Ende zur gespeicherten Dauer
    /// passen (`durationMinutes` ist deren abgerundete Minutenzahl). Passen sie
    /// nicht — die Dauer wurde im Verlauf geaendert, oder das Ende ist veraltet —,
    /// ist nur die Minutenzahl verlaesslich: `nil`.
    public static func exactSeconds(startToEndSeconds: Int, storedMinutes: Int) -> Int? {
        guard startToEndSeconds > 0, startToEndSeconds / 60 == storedMinutes else { return nil }
        return startToEndSeconds
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
