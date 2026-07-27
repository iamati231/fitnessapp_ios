#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// DEL-227: Automatische Backup-Generationen.
///
/// **Warum das existiert.** Bis hierher gab es faktisch kein Backup. Der
/// manuelle CSV-Export landete im **Caches**-Verzeichnis und war nur so lange
/// real, wie der User ihn aus dem Share-Sheet heraus irgendwohin geschoben hat
/// — iOS darf Caches jederzeit leeren. Kein iCloud, keine Generationen, kein
/// Rückweg. Genau dieser fehlende Rückweg hat den Datenverlust im Mai 2026 so
/// teuer gemacht: der Import loeschte den Bestand und es gab keinen Stand von
/// gestern.
///
/// **Ablageort.** `Application Support/Backups`. Bewusst NICHT der
/// App-Group-Container: der ueberlebt weder eine Deinstallation noch einen
/// Geraeteverlust, also genau die Faelle, gegen die ein Backup schuetzen soll.
/// Der naechste Schritt ist der iCloud-Drive-Container — der braucht ein
/// Entitlement und einen Portal-Schritt und kommt deshalb separat.
///
/// **Rotation.** Es werden die `maxGenerations` jüngsten Generationen
/// behalten, aeltere fallen raus. Grund fuer mehrere Generationen statt einer:
/// eine stille Datenkorruption faellt oft erst Tage spaeter auf, und ein
/// einzelnes Backup waere dann schon mit dem kaputten Stand ueberschrieben.
public enum BackupService {

    /// Wie viele Generationen aufbewahrt werden.
    public static let maxGenerations = 5

    /// Beschreibt eine Generation, wie sie die Restore-UI anzeigt.
    public struct Generation: Identifiable, Sendable, Equatable {
        public let url: URL
        public let createdAt: Date
        public let byteCount: Int
        /// Zeilen ueber alle CSV-Dateien — grobe, aber verstaendliche
        /// Groessenangabe ("1.240 Datensaetze").
        public let rowCount: Int
        /// Ausloeser: automatisch, manuell oder Sicherung vor einem Import.
        public let reason: Reason

        public var id: URL { url }

        public init(url: URL, createdAt: Date, byteCount: Int, rowCount: Int, reason: Reason) {
            self.url = url
            self.createdAt = createdAt
            self.byteCount = byteCount
            self.rowCount = rowCount
            self.reason = reason
        }
    }

    /// Warum eine Generation entstanden ist. Steckt im Dateinamen, damit die
    /// Zuordnung auch ohne Manifest funktioniert — Schema und Parser liegen in
    /// `FitnessAppCore.BackupFilename`, wo sie ohne SwiftData getestet sind.
    public typealias Reason = BackupFilename.Reason

    // MARK: - Pfade

    /// `Application Support/Backups`. Wird bei Bedarf angelegt.
    public static func backupsDirectory() throws -> URL {
        let base = URL.applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    // MARK: - Erzeugen

    /// Erzeugt eine neue Generation und raeumt anschliessend auf.
    ///
    /// - Returns: die erzeugte Generation.
    @discardableResult
    public static func createBackup(
        context: ModelContext,
        reason: Reason,
        appVersion: String = "—",
        now: Date = Date()
    ) throws -> Generation {
        let bundle = try DataExportService.makeExport(context: context, appVersion: appVersion)
        let dir = try backupsDirectory()
        let url = dir.appendingPathComponent(BackupFilename.make(reason: reason, at: now))

        // Atomar schreiben: erst in eine Temp-Datei derselben Partition, dann
        // umbenennen. Ein abgebrochener Schreibvorgang darf keine halbe
        // ZIP-Datei hinterlassen, die spaeter als gueltiges Backup angeboten
        // wird.
        let tmp = dir.appendingPathComponent("_writing_\(UUID().uuidString).tmp")
        try bundle.data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)

        // Backups gehoeren nicht in ein iCloud-Dokument-Backup des
        // Caches-Typs, aber sie sollen auch nicht vom System weggeraeumt
        // werden. Application Support ist persistent; das Ausschliessen vom
        // Geraete-Backup waere kontraproduktiv, deshalb bewusst NICHT gesetzt.

        try pruneOldGenerations(keeping: maxGenerations)

        return Generation(
            url: url,
            createdAt: now,
            byteCount: bundle.data.count,
            rowCount: bundle.totalRows,
            reason: reason
        )
    }

    // MARK: - Auflisten

    /// Alle vorhandenen Generationen, jüngste zuerst.
    ///
    /// Der Zeitstempel kommt aus dem Dateinamen und nicht aus den
    /// Datei-Attributen: ein Kopiervorgang (Geraetewechsel, iCloud-Sync)
    /// veraendert `creationDate`, den Namen aber nicht.
    public static func listGenerations() throws -> [Generation] {
        let dir = try backupsDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []

        var result: [Generation] = []
        for url in urls where url.pathExtension.lowercased() == BackupFilename.fileExtension {
            guard let parsed = BackupFilename.parse(url.lastPathComponent) else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            result.append(Generation(
                url: url,
                createdAt: parsed.date,
                byteCount: size,
                // Zeilenzahl steht nicht im Namen; die Restore-UI zeigt sie
                // erst, wenn das ZIP fuer die Vorschau gelesen wird.
                rowCount: 0,
                reason: parsed.reason
            ))
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    /// Loescht die aeltesten Generationen, bis nur noch `keeping` übrig sind.
    /// Zusaetzlich werden liegengebliebene `_writing_*.tmp`-Reste entfernt.
    public static func pruneOldGenerations(keeping: Int) throws {
        let dir = try backupsDirectory()
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for leftover in all where leftover.lastPathComponent.hasPrefix("_writing_") {
            try? FileManager.default.removeItem(at: leftover)
        }

        let generations = try listGenerations()
        guard generations.count > keeping else { return }
        for old in generations.dropFirst(keeping) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

    public static func delete(_ generation: Generation) throws {
        try FileManager.default.removeItem(at: generation.url)
    }

}
#endif
