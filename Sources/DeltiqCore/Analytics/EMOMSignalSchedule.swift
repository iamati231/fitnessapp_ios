import Foundation

/// Ein Minutensignal eines laufenden EMOM, das als Benachrichtigung im Voraus
/// geplant wird (Rueckfall, wenn das Hintergrund-Audio nicht laeuft).
public struct EMOMSignal: Equatable, Sendable {
    /// Die Minute, die mit diesem Signal ENDET (1...Gesamtminuten).
    public let minute: Int
    /// Wann das Signal faellig ist, in ganzen Sekunden ab jetzt (mindestens 1).
    public let delaySeconds: Int
    /// Das Signal der letzten Minute: der EMOM ist komplett.
    public let isFinal: Bool

    public init(minute: Int, delaySeconds: Int, isFinal: Bool) {
        self.minute = minute
        self.delaySeconds = delaySeconds
        self.isFinal = isFinal
    }
}

/// Der Zeitplan der EMOM-Minutensignale - ausgerichtet am START des Laufs, nicht
/// an "jetzt".
///
/// Minute `n` endet `n * 60` Sekunden nach dem Start. Wer den Zeitplan mitten im
/// Lauf neu plant (zurueck auf den Tab, "Training fortsetzen"), muss deshalb die
/// schon verstrichene Zeit abziehen und vergangene Signale auslassen. Frueher
/// begann jede Planung bei "jetzt" bei 60 s und verschob damit alle Signale um die
/// bis dahin verstrichene Zeit - bei einem schon beendeten Lauf gab es sogar
/// Signale fuer eine Zeit, die laengst vorbei war.
public enum EMOMSignalSchedule {

    /// Die noch faelligen Signale, in Minutenreihenfolge. Leer, wenn der Lauf zu
    /// Ende ist (oder keine Minute hat). Ein Signal, das in weniger als einer
    /// Sekunde faellig waere, entfaellt: Der Trigger einer Benachrichtigung braucht
    /// mindestens eine Sekunde, und der Tick der App spielt es dann ohnehin selbst.
    public static func signals(totalMinutes: Int, elapsedSeconds: Int) -> [EMOMSignal] {
        guard totalMinutes > 0 else { return [] }
        let elapsed = max(0, elapsedSeconds)
        return (1...totalMinutes).compactMap { minute in
            let delay = minute * 60 - elapsed
            guard delay >= 1 else { return nil }
            return EMOMSignal(minute: minute, delaySeconds: delay, isFinal: minute == totalMinutes)
        }
    }
}
