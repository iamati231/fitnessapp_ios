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

    /// DEL-234: Gruende, aus denen der Service bewusst NICHT sichert.
    public enum BackupError: Error, LocalizedError {
        /// Die App laeuft auf dem eingefrorenen Alt-Store (siehe
        /// `SharedStore.Health`). Ein Backup waere eine Momentaufnahme
        /// veralteter Daten.
        case storeUnhealthy(String)

        public var errorDescription: String? {
            switch self {
            case .storeUnhealthy(let detail):
                return "Backup abgebrochen: die App laeuft auf einem Ersatz-Datenspeicher, "
                    + "der Stand ist moeglicherweise veraltet. Grund: \(detail)"
            }
        }
    }

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

    /// `Documents/Backups`. Wird bei Bedarf angelegt.
    ///
    /// DEL-237: lag vorher in `Application Support`. Das ist der technisch
    /// korrekte Ort fuer App-verwaltete Daten — aber fuer den Nutzer
    /// unsichtbar und unerreichbar. Genau das war die Beschwerde: die
    /// automatischen Backups existierten, man kam nur nicht an sie heran, und
    /// ein Backup, an das man im Ernstfall nicht herankommt, ist keins.
    ///
    /// `Documents` erscheint zusammen mit `UIFileSharingEnabled` +
    /// `LSSupportsOpeningDocumentsInPlace` (Info.plist) in der Dateien-App
    /// unter "Auf meinem iPhone → Deltiq". Von dort kann der Nutzer eine
    /// Generation per Drag nach iCloud Drive ziehen, in eine Mail haengen oder
    /// auf den Rechner kopieren — ohne die App zu oeffnen und ohne Export-Flow.
    ///
    /// Zweiter Effekt, der hier mehr wiegt als die Sichtbarkeit: `Documents`
    /// ist im iCloud-/Finder-Geraetebackup enthalten. Damit ueberleben die
    /// Generationen erstmals einen Geraeteverlust — der Fall, gegen den
    /// `Application Support` zwar half (Deinstallation ausgenommen), aber der
    /// App-Group-Container ausdruecklich nicht.
    ///
    /// Migration ist nicht noetig: der BackupService ist nie ausgeliefert
    /// worden (letzter Tag v0.1.73 = DEL-216, BackupService kam mit DEL-227).
    /// Auf Entwickler-Geraeten liegengebliebene Generationen am alten Pfad
    /// werden einmalig mitgenommen, damit dort nichts verwaist.
    public static func backupsDirectory() throws -> URL {
        let base = URL.documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        adoptLegacyGenerationsIfAny(into: base)
        return base
    }

    /// DEL-237: Holt Generationen vom alten `Application Support`-Pfad ab.
    ///
    /// Nur fuer Entwickler- und TestFlight-Zwischenstaende relevant; in der
    /// Breite hat nie jemand Backups am alten Ort gehabt. Bewusst `move` und
    /// nicht `copy`: sonst haette der Nutzer zwei Saetze Generationen, von
    /// denen die Rotation nur einen pflegt. Fehler werden geschluckt — ein
    /// misslungener Umzug darf das Anlegen neuer Backups nicht blockieren.
    private static func adoptLegacyGenerationsIfAny(into destination: URL) {
        let fm = FileManager.default
        let legacy = URL.applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        guard fm.fileExists(atPath: legacy.path) else { return }
        let entries = (try? fm.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil)) ?? []
        for entry in entries where BackupFilename.parse(entry.lastPathComponent) != nil {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            guard !fm.fileExists(atPath: target.path) else { continue }
            try? fm.moveItem(at: entry, to: target)
        }
        // Leeres Alt-Verzeichnis aufraeumen; schlaegt fehl solange noch etwas
        // drinliegt, was genau richtig ist.
        try? fm.removeItem(at: legacy)
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
        return try store(bundle: bundle, reason: reason, now: now)
    }

    /// Settings-Epic Phase 5 (Befunde DX-02c/BL-07): fuer User-initiierte
    /// Aufrufe (manueller Export, "Jetzt sichern", Vorab-Sicherung vor
    /// Import/Reset) — haelt den Main-Thread waehrend ZIP-Kompression +
    /// Schreiben/Rotieren der Generation responsiv. `createBackup` (oben)
    /// bleibt fuer den automatischen Hintergrund-Lauf
    /// (`runAutomaticBackupIfDue`) unveraendert synchron — dort ist das
    /// gewollt (siehe dortiger Kommentar).
    @discardableResult
    public static func createBackupAsync(
        context: ModelContext,
        reason: Reason,
        appVersion: String = "—",
        now: Date = Date()
    ) async throws -> Generation {
        let bundle = try await DataExportService.makeExportAsync(context: context, appVersion: appVersion)
        // `store` beruehrt weder `context` noch ein lebendes SwiftData-
        // Objekt (nur Dateisystem-I/O auf dem bereits fertigen, Sendable
        // `bundle`) — sicher per `Task.detached`.
        return try await Task.detached {
            try store(bundle: bundle, reason: reason, now: now)
        }.value
    }

    /// Legt ein SCHON ERZEUGTES Export-Bundle als Generation ab.
    ///
    /// Getrennt von `createBackup`, damit der manuelle Export in den
    /// Einstellungen seine Daten nicht zweimal aufbauen muss: er teilt das ZIP
    /// per Share-Sheet UND hinterlegt es hier als dauerhafte Generation. Vorher
    /// war ein manueller Export fluechtig — lag der User ihn nicht selbst
    /// irgendwohin, war er weg.
    @discardableResult
    public static func store(
        bundle: DataExportBundle,
        reason: Reason,
        now: Date = Date()
    ) throws -> Generation {
        // DEL-234: Nichts schreiben, wenn die App auf dem eingefrorenen
        // Alt-Store laeuft. Sonst wandert ein Wochen alter Stand als neue
        // Generation in die Rotation und verdraengt die guten — aus einem
        // behebbaren Oeffnen-Fehler wuerde endgueltiger Datenverlust.
        // Gilt fuer JEDEN Grund, auch manuell und preImport: solange
        // ungeklaert ist, welcher Store die Wahrheit haelt, ist ein Backup
        // keine Sicherung, sondern eine Faelschung.
        if case .fellBackAfterGroupStoreFailure(let reason) = SharedStore.health {
            throw BackupError.storeUnhealthy(reason)
        }
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
        // Settings-Epic Phase 5 (Befund BL-03): `try`, nicht `try?` — ein
        // echter Lesefehler (Berechtigung entzogen, Datentraeger-Problem) muss
        // bis zur UI durchgereicht werden. `backupsDirectory()` legt das
        // Verzeichnis bereits an, falls es fehlt; eine "leere Liste, weil
        // noch nie gesichert wurde" kommt also nie hierueber zustande —
        // dieser Aufruf scheitert nur, wenn danach wirklich etwas kaputt ist.
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey]
        )

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

    // MARK: - Automatischer Lauf (DEL-228)

    /// UserDefaults-Key des letzten automatischen Backups.
    ///
    /// Bewusst NICHT in der `SettingsPortability`-Whitelist: der Zeitpunkt
    /// beschreibt den Zustand DIESES Geraets. Wuerde er mitwandern, haette ein
    /// frisch eingerichtetes Geraet einen Stempel von gestern und wuerde
    /// glauben, es sei schon gesichert.
    public static let lastAutoBackupKey = "backup.lastAutomaticAt"

    /// Erzeugt eine automatische Generation, falls faellig. Wird beim Wechsel
    /// der App in den Hintergrund gerufen — dort ist ein kurzer, synchroner
    /// Schreibvorgang unkritisch und der Zustand gerade konsistent.
    ///
    /// Fehler werden bewusst geschluckt: ein fehlgeschlagenes Hintergrund-
    /// Backup darf niemals den App-Lifecycle stoeren. Es wird lediglich der
    /// Zeitstempel nicht gesetzt, sodass der naechste Versuch erneut greift.
    ///
    /// - Returns: die erzeugte Generation, oder `nil` wenn nichts faellig war
    ///   bzw. der Versuch fehlschlug.
    @discardableResult
    public static func runAutomaticBackupIfDue(
        context: ModelContext,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        appVersion: String = "—"
    ) -> Generation? {
        // DEL-234: Frueh raus, wenn die App auf dem Ersatz-Store laeuft. `store`
        // wuerde ohnehin werfen, aber dann waeren Fetch, CSV-Bau und ZIP schon
        // umsonst gelaufen. Der Zeitstempel bleibt absichtlich ungesetzt, damit
        // der naechste Hintergrund-Wechsel es erneut versucht, sobald der
        // Store wieder gesund ist.
        if case .fellBackAfterGroupStoreFailure = SharedStore.health { return nil }

        let stored = defaults.double(forKey: lastAutoBackupKey)
        let lastBackupAt: Date? = stored > 0 ? Date(timeIntervalSince1970: stored) : nil

        // "Hat der User Daten?" — eine abgeschlossene Session genuegt als
        // Signal. Ohne diese Pruefung wuerde eine frische Installation leere
        // Generationen anlegen, die spaeter die Rotation belegen und echte
        // Backups verdraengen.
        var descriptor = FetchDescriptor<WorkoutSession>()
        descriptor.fetchLimit = 1
        let hasData = ((try? context.fetchCount(descriptor)) ?? 0) > 0

        guard BackupSchedule.shouldCreateBackup(
            lastBackupAt: lastBackupAt,
            now: now,
            hasData: hasData
        ) else { return nil }

        do {
            let generation = try createBackup(
                context: context,
                reason: .automatic,
                appVersion: appVersion,
                now: now
            )
            defaults.set(now.timeIntervalSince1970, forKey: lastAutoBackupKey)
            return generation
        } catch {
            return nil
        }
    }

}
#endif
