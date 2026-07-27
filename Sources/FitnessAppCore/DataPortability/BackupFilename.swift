import Foundation

/// DEL-227: Dateinamens-Schema der Backup-Generationen.
///
/// Zeitstempel und Ausloeser stecken im NAMEN, nicht in einer Manifest-Datei.
/// Zwei Gruende: ein Manifest ist eine zusaetzliche Datei, die mit dem
/// Verzeichnis auseinanderlaufen kann (halb geschriebene Backups, manuell
/// geloeschte Dateien), und `creationDate` aus den Datei-Attributen ueberlebt
/// keinen Kopiervorgang — bei Geraetewechsel oder iCloud-Sync waeren alle
/// Backups ploetzlich "von heute".
///
/// Liegt bewusst in Core und nicht bei `BackupService`: reine String- und
/// Datums-Arbeit ohne SwiftData, damit der Roundtrip
/// `make` → `parse` testbar ist. Ein Parse-Fehler wuerde bestehende Backups
/// aus der Wiederherstellungs-Liste verschwinden lassen — genau der Fall, in
/// dem der User sie braucht.
public enum BackupFilename {

    /// Warum eine Generation entstanden ist.
    public enum Reason: String, Sendable, CaseIterable {
        /// Regelmaessige automatische Sicherung.
        case automatic
        /// Vom User ausgeloest.
        case manual
        /// Sicherung unmittelbar VOR einem Import — der Rueckweg, falls der
        /// Import nicht das gebracht hat, was der User erwartete.
        case preImport
    }

    public static let prefix = "deltiq-backup_"
    public static let fileExtension = "zip"

    /// `deltiq-backup_<reason>_<yyyyMMdd-HHmmss>.zip`
    public static func make(reason: Reason, at date: Date) -> String {
        "\(prefix)\(reason.rawValue)_\(stamp.string(from: date)).\(fileExtension)"
    }

    /// Gegenstueck zu `make`. `nil` fuer alles, was nicht dem Schema
    /// entspricht — fremde Dateien im Verzeichnis werden dadurch ignoriert
    /// statt als kaputtes Backup angeboten.
    public static func parse(_ name: String) -> (reason: Reason, date: Date)? {
        guard name.hasPrefix(prefix), name.hasSuffix(".\(fileExtension)") else { return nil }
        let core = String(name.dropFirst(prefix.count).dropLast(fileExtension.count + 1))
        // maxSplits: 1 — der Zeitstempel enthaelt selbst keinen Unterstrich,
        // aber so bleibt das Schema robust, falls je ein Reason mit
        // Unterstrich dazukommt.
        let parts = core.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let reason = Reason(rawValue: String(parts[0])),
              let date = stamp.date(from: String(parts[1]))
        else { return nil }
        return (reason, date)
    }

    /// Fixe Locale + UTC: der Name muss auf jedem Geraet identisch aufgebaut
    /// sein und wieder parsebar bleiben, unabhaengig von den
    /// Regionaleinstellungen des Users. `en_US_POSIX` schuetzt zusaetzlich
    /// gegen nicht-gregorianische Kalender-Einstellungen.
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
