#if canImport(SwiftData)
import Foundation
import SwiftData

/// DEL-216: App-Group-geteilter SwiftData-Store, damit die Widget-Extension
/// (interaktives Wasser-Widget) denselben Datenbestand lesen + beschreiben
/// kann wie die App.
///
/// **Migrations-Strategie (einmalig, verlustfrei):**
/// Vor DEL-216 lag der Store am SwiftData-Default-Pfad
/// (`Application Support/default.store`). Beim ersten App-Start nach dem
/// Update kopiert `makeAppContainer()` die Store-Dateien in den App-Group-
/// Container. Die Originale werden NIEMALS geloescht — sie bleiben als
/// Rollback-Sicherung liegen (Lehre aus dem DEL-182/188-Datenverlust).
///
/// **Widget-Disziplin:** Das Widget oeffnet den Group-Store ausschliesslich,
/// wenn er bereits existiert (`widgetContainer()` gibt sonst nil). Wuerde
/// das Widget den Store selbst anlegen (z.B. direkt nach einem App-Update,
/// bevor die App je lief), saehe die App beim naechsten Start einen
/// existierenden — aber LEEREN — Group-Store und wuerde die Migration
/// ueberspringen: Bestandsdaten waeren scheinbar weg.
public enum SharedStore {

    /// Muss mit der App Group im Apple Developer Portal + beiden
    /// .entitlements-Dateien uebereinstimmen.
    public static let appGroupIdentifier = "group.com.atamya.FitnessApp"

    /// WidgetKind des Wasser-Widgets — geteilt zwischen App
    /// (`WidgetCenter.reloadTimelines(ofKind:)`) und Widget-Extension
    /// (`StaticConfiguration(kind:)`), damit die Strings nie divergieren.
    public static let waterWidgetKind = "WaterTrackerWidget"

    private static let storeFileName = "default.store"

    /// Ziel-URL des Stores im App-Group-Container. nil, wenn der Prozess
    /// kein App-Group-Entitlement traegt (z.B. unsignierter Simulator-
    /// CI-Build mit CODE_SIGNING_ALLOWED=NO).
    public static var groupStoreURL: URL? {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        return base
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(storeFileName)
    }

    // MARK: - App-Seite

    /// Container fuer die App: migriert bei Bedarf den Default-Store in den
    /// Group-Container und oeffnet ihn dort. Faellt ohne App-Group-Zugriff
    /// (oder bei Group-Container-Fehlern) auf den bisherigen Default-Store
    /// zurueck — Verhalten dann identisch zu vor DEL-216.
    /// DEL-234: Zustand des geoeffneten Stores. Wird von `makeAppContainer()`
    /// gesetzt und von `BackupService` gelesen.
    public enum Health: Equatable, Sendable {
        /// Group-Store offen — Normalfall.
        case ok
        /// Kein App-Group-Zugriff (Entitlement fehlt, z.B. unsignierter
        /// CI-Build) ODER es gab noch nie einen Group-Store. Der Default-Store
        /// ist hier die EINZIGE Wahrheit, also unbedenklich.
        case legacyStoreOnly
        /// Der Group-Store EXISTIERT, liess sich aber nicht oeffnen, und die
        /// App laeuft ersatzweise auf dem alten Default-Store. Das ist ein
        /// Notzustand: der alte Store ist auf dem Stand des Migrationstags
        /// eingefroren, der Nutzer sieht also veraltete Daten.
        case fellBackAfterGroupStoreFailure(String)
    }

    /// Nur schreibend aus `makeAppContainer()`. Kein Concurrency-Schutz noetig:
    /// gesetzt genau einmal beim App-Start, bevor irgendetwas anderes laeuft.
    public private(set) static var health: Health = .legacyStoreOnly

    public static func makeAppContainer() -> ModelContainer {
        let schema = Schema(AppSchema.types)

        if let groupURL = groupStoreURL {
            let groupStoreExisted = FileManager.default.fileExists(atPath: groupURL.path)
            migrateDefaultStoreIfNeeded(to: groupURL)
            do {
                let config = ModelConfiguration(schema: schema, url: groupURL)
                let container = try ModelContainer(for: schema, configurations: config)
                health = .ok
                return container
            } catch {
                // DEL-234: Hier stand vorher "die Default-Store-Originale wurden
                // nie angefasst, also kein Datenverlust" — und der Fallback lief
                // stillschweigend. Das Argument gilt nur fuer den AUGENBLICK der
                // Migration. Danach ist der Group-Store die Wahrheit und der
                // Default-Store auf dem Migrationstag eingefroren.
                //
                // Faellt die App also spaeter still zurueck, sieht der Nutzer
                // Wochen alte Daten ohne jeden Hinweis. Und mit dem
                // automatischen Backup (DEL-228) wuerde dieser veraltete Stand
                // beim naechsten Hintergrund-Wechsel als neue Generation
                // weggeschrieben und ueber die Rotation die guten Generationen
                // verdraengen — aus einem behebbaren Oeffnen-Fehler wuerde
                // damit endgueltiger Datenverlust.
                //
                // Deshalb: Der Fallback bleibt (die App soll benutzbar sein und
                // nicht in eine Crash-Schleife laufen), aber er ist ab jetzt als
                // Notzustand MARKIERT. `BackupService` schreibt in diesem
                // Zustand nichts mehr, und die Bedingung ist damit reversibel.
                //
                // Wichtig ist die Unterscheidung: existierte der Group-Store
                // vorher NICHT, ist ein Oeffnen-Fehler harmlos (frische
                // Installation, nichts zu verlieren) — dann bleibt es beim
                // gutartigen `legacyStoreOnly`.
                health = groupStoreExisted
                    ? .fellBackAfterGroupStoreFailure(String(describing: error))
                    : .legacyStoreOnly
            }
        } else {
            health = .legacyStoreOnly
        }

        do {
            return try ModelContainer(for: schema)
        } catch {
            // Gleiches Crash-Verhalten wie `.modelContainer(for:)` vorher —
            // ohne Store ist die App funktionsunfaehig.
            fatalError("SharedStore: ModelContainer creation failed: \(error)")
        }
    }

    /// Einmalige Kopie der Store-Dateien an den Group-Pfad. No-op, wenn der
    /// Group-Store schon existiert oder es keinen Alt-Store gibt (frische
    /// Installation — SwiftData legt den Store dann direkt am Group-Pfad an).
    ///
    /// Reihenfolge bewusst: erst Sidecars (-shm/-wal), die Haupt-Datei
    /// ZULETZT. Existenz der Haupt-Datei ist das "Migration fertig"-Signal —
    /// bricht die Kopie vorher ab, wird beim naechsten Start sauber neu
    /// angesetzt (stale Sidecar-Reste werden vorab entfernt).
    private static func migrateDefaultStoreIfNeeded(to groupURL: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: groupURL.path) else { return }

        try? fm.createDirectory(
            at: groupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let oldURL = URL.applicationSupportDirectory.appendingPathComponent(storeFileName)
        guard fm.fileExists(atPath: oldURL.path) else { return }

        for suffix in ["-shm", "-wal"] {
            let from = URL(fileURLWithPath: oldURL.path + suffix)
            let to = URL(fileURLWithPath: groupURL.path + suffix)
            try? fm.removeItem(at: to)
            if fm.fileExists(atPath: from.path) {
                try? fm.copyItem(at: from, to: to)
            }
        }
        try? fm.copyItem(at: oldURL, to: groupURL)
    }

    // MARK: - Widget-Seite

    /// Container fuer die Widget-Extension. Gibt nil zurueck, wenn der
    /// Group-Store (noch) nicht existiert — das Widget zeigt dann einen
    /// "App einmal oeffnen"-Hinweis und legt insbesondere KEINEN leeren
    /// Store an (siehe Type-Doc oben).
    public static func widgetContainer() -> ModelContainer? {
        guard let groupURL = groupStoreURL,
              FileManager.default.fileExists(atPath: groupURL.path)
        else { return nil }
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(schema: schema, url: groupURL)
        return try? ModelContainer(for: schema, configurations: config)
    }
}
#endif
