import Foundation

/// DEL-228: Entscheidet, ob eine automatische Backup-Generation faellig ist.
///
/// Reine Funktion in Core, damit die Kanten testbar sind — und die sind hier
/// weniger harmlos, als die Frage "ist mehr als ein Tag vergangen" aussieht:
/// ein Fehler in Richtung "nie faellig" heisst, dass der User glaubt, Backups
/// zu haben, und keine hat.
public enum BackupSchedule {

    /// Standard-Abstand zwischen automatischen Generationen.
    public static let defaultInterval: TimeInterval = 24 * 60 * 60

    /// - Parameters:
    ///   - lastBackupAt: Zeitpunkt der letzten automatischen Sicherung.
    ///     `nil` = es gab noch keine.
    ///   - now: aktuelle Zeit (injizierbar fuer Tests).
    ///   - interval: Mindestabstand.
    ///   - hasData: Ist überhaupt etwas zu sichern? Eine frische Installation
    ///     soll keine leeren Generationen produzieren, die spaeter die
    ///     Rotation belegen und echte Backups verdraengen.
    public static func shouldCreateBackup(
        lastBackupAt: Date?,
        now: Date,
        interval: TimeInterval = defaultInterval,
        hasData: Bool
    ) -> Bool {
        guard hasData else { return false }
        guard let lastBackupAt else {
            // Noch nie gesichert und es gibt Daten → sofort.
            return true
        }
        let elapsed = now.timeIntervalSince(lastBackupAt)
        // Negatives `elapsed` heisst: der gespeicherte Zeitpunkt liegt in der
        // ZUKUNFT. Passiert bei manueller Uhr-Umstellung, Zeitzonen-Reisen
        // oder einem Restore aus einem Backup mit fremdem Zeitstempel. Ohne
        // diesen Zweig waere nie wieder ein Backup faellig, bis die echte Zeit
        // den falschen Stempel eingeholt hat — im Extremfall jahrelang.
        // Deshalb: Zukunfts-Stempel gilt als "faellig", der naechste Lauf
        // korrigiert ihn auf die echte Zeit.
        if elapsed < 0 { return true }
        return elapsed >= interval
    }
}
