// DEL-174: DataImportService — Phase 2 (Import) für die CSV-in-ZIP-Datenportabilität.
//
// Symmetrisch zu DataExportService. Akzeptiert ein ZIP-Archiv, das vom
// Export-Pfad (oder einem schema-kompatiblen anderen Tool) erzeugt wurde,
// und merged die Daten in den aktiven SwiftData-Container.
//
// **Konflikt-Strategie**: Append-only mit Duplikat-Erkennung. Wir löschen
// niemals bestehende Daten — der User behält jede Trainings-Session, jeden
// PR, jedes Profil. Doppelte Zeilen (gleicher natürlicher Schlüssel) werden
// übersprungen, nicht überschrieben:
//   - UserBodyProfile: existiert → skip ganzer Import-Block (Singleton)
//   - BodyMeasurement: skip wenn `date` + `weightKg` matchen
//   - WaterEntry: skip wenn `date` + `amountMl` matchen
//   - Gear: skip wenn `name` + `type` matchen
//   - ExerciseTemplate (custom): skip wenn `name` matched (case-insensitive)
//   - TrainingPlan: IMMER als neuer Plan, da User mehrere
//     gleich-benannte Pläne haben können (z.B. Push/Pull/Legs Mk1 vs Mk2)
//   - WorkoutSession: skip wenn `startTime` (ISO-Sekunde) matched
//   - ExerciseLog: skip wenn session+setIndex+exerciseNameSnapshot match
//   - PersonalRecordEntry: skip wenn date+exerciseName+kind match
//
// **Fehlerbehandlung**: Pro-Zeile-resilient. Eine kaputte Date-Spalte in
// row 47 verwirft NUR diese Zeile; der Rest der CSV läuft weiter. Alle
// verworfenen Zeilen landen in einer `errors.csv`, die die UI als Share-
// Anhang anbietet. Der Hauptimport selbst wirft nur bei strukturellen
// Schäden (kaputtes ZIP, fehlendes meta.json, inkompatible formatVersion).

#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import ZIPFoundation

/// Welche Strategie der ImportService beim Mergen anwendet.
public enum DataImportStrategy: String, Sendable, CaseIterable {
    /// Default. Fügt fehlende Zeilen hinzu, erkennt Duplikate über
    /// natürliche Schlüssel (date+name etc.) und überspringt sie — nichts
    /// Bestehendes wird je angetastet. Sicher für jedes Szenario.
    case appendOnly

    /// Destruktiv. Löscht ALLE User-Daten (Profile, Workouts, Logs, Maße,
    /// Pläne, Custom-Templates, Gear, Water, PRs) und installiert dann
    /// das Backup. Sinnvoll für "Neues Gerät / Account-Wechsel"-Flow.
    /// **Anwendung erfordert UI-Warnung mit destruktivem Confirm.**
    case replace
}

/// DEL-176: Live-Progress-Tick, den der ImportService an einen optionalen
/// Handler weiterreicht. Pro CSV-Phase einmal — die UI rendert daraus eine
/// Linear-ProgressView + aktuellen Dateinamen.
///
/// `phase` ist ein stabiler Identifier (z.B. `"workouts.csv"`), keine
/// lokalisierte Anzeige — die UI mappt das auf einen Catalog-Key. So
/// kann die Lokalisierung an einem Ort liegen und der Service bleibt
/// sprachfest.
public struct ImportProgress: Sendable, Equatable {
    public let phase: String
    public let filesCompleted: Int
    public let filesTotal: Int

    public var fraction: Double {
        guard filesTotal > 0 else { return 0 }
        return Double(filesCompleted) / Double(filesTotal)
    }
}

/// Ergebnis eines erfolgreich gestarteten Imports. Auch wenn Errors aufgetreten
/// sind: das ist KEIN throwing-error — die UI rendert den Result mit
/// Imported/Skipped/Failed-Zähler und der User kann errors.csv teilen.
public struct DataImportResult: Sendable {
    public let formatVersion: String
    public let exportedAt: String
    public let imported: [String: Int]   // filename → inserted row count
    public let skipped:  [String: Int]   // filename → duplicate row count (kept original)
    public let errorRows: Int
    /// CSV mit den fehlgeschlagenen Zeilen — exact-shape: file,line,reason.
    /// Nil wenn `errorRows == 0`.
    public let errorsCSV: Data?

    public var totalImported: Int { imported.values.reduce(0, +) }
    public var totalSkipped:  Int { skipped.values.reduce(0, +) }
}

/// DEL-226: Ergebnis des Trockenlaufs — was steckt in dieser Datei?
///
/// Existiert, weil der Import bis hierher ein Sprung ins Dunkle war: der User
/// waehlte eine ZIP und erfuhr erst NACH dem Schreiben, was drin war. Bei der
/// `replace`-Strategie ist das der Moment, in dem der eigene Bestand schon weg
/// ist. Genau so ist der Datenverlust im Mai 2026 gelaufen.
public struct DataImportPreview: Sendable {
    public let formatVersion: String
    public let exportedAt: String
    public let appVersion: String
    /// Zeilen pro CSV-Datei (ohne Header).
    public let rowCountsByFile: [String: Int]
    /// Enthaelt das Backup einen aktiven Trainingsplan? Der Punkt, an dem sich
    /// ein Import am sichtbarsten auf den Alltag auswirkt.
    public let containsActivePlan: Bool

    public init(
        formatVersion: String,
        exportedAt: String,
        appVersion: String,
        rowCountsByFile: [String: Int],
        containsActivePlan: Bool
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.rowCountsByFile = rowCountsByFile
        self.containsActivePlan = containsActivePlan
    }

    public var totalRows: Int { rowCountsByFile.values.reduce(0, +) }

    /// Dateien mit Inhalt, alphabetisch — fuer eine stabile Anzeige-Reihenfolge.
    public var nonEmptyFiles: [(name: String, rows: Int)] {
        rowCountsByFile
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { (name: $0.key, rows: $0.value) }
    }
}

/// Stateless service. Mirrors DataExportService.
public enum DataImportService {

    /// Mit welchen `formatVersion`s der Importer kompatibel ist. Patch- und
    /// Minor-Bumps werden toleriert (additive Felder), Major-Bumps explicit
    /// gefilet — sonst frisst der Importer Daten, die er nicht versteht.
    public static let supportedMajorVersion = 1

    /// Hauptentry. Wirft bei strukturellen Fehlern (kaputtes ZIP, fehlendes
    /// meta.json, falsche formatVersion). Reihen-lokale Fehler landen im
    /// Result.
    ///
    /// `progressHandler` wird vor jeder Phase einmal aufgerufen. Bei großen
    /// Backups (Jahre History) braucht der Import sonst sichtbar mehrere
    /// Sekunden — der User soll sehen, dass die App nicht hängt. Der
    /// Handler MUSS thread-safe sein (er läuft auf dem ImportService-Actor,
    /// nicht zwingend Main); UI-Code im Handler also via `Task { @MainActor }`
    /// oder analog dispatchen.
    /// Hauptentry. Wirft bei strukturellen Fehlern (kaputtes ZIP, fehlendes
    /// meta.json, falsche formatVersion). Reihen-lokale Fehler landen im
    /// Result.
    public static func performImport(
        zipData: Data,
        context: ModelContext,
        strategy: DataImportStrategy = .appendOnly,
        progressHandler: (@Sendable (ImportProgress) -> Void)? = nil
    ) throws -> DataImportResult {

        // 1) ZIP entpacken.
        //
        // Vorherige Approaches haben in Release-Builds nicht zuverlässig
        // funktioniert:
        //   - Closure-Consumer-Pattern (`archive.extract(entry) { chunk in
        //     buffer.append(chunk) }`) lieferte teilweise leere Buffer mit
        //     Whole-Module-Optimization.
        //   - Per-Entry `archive.extract(entry, to: url)` lieferte bei
        //     DEFLATE-komprimierten Files (compressedSize < uncompressedSize)
        //     teilweise nur den Header-Teil — die CSV-Reader sahen dann nur
        //     die erste Zeile (Spaltennamen), keine Daten. Resultat: 0/0
        //     für alle Files trotz validem ZIP-Inhalt.
        //
        // Jetzt nutzen wir `FileManager.default.unzipItem(at:to:)` — die
        // High-Level-Convenience-API aus ZIPFoundation. Das ist die
        // battle-tested Variante, die intern die komplette Decompression-
        // Pipeline fährt und die FileManager benutzt für Disk-IO. Trade-off:
        // wir müssen die ZIP-Bytes erst auf Disk schreiben, weil
        // unzipItem nur URL-zu-URL kann (keine Data-Variante). Bei einem
        // Power-User-Backup mit ~50KB-ZIP ist die zusätzliche Disk-IO
        // vernachlässigbar.
        // DEL-226: Entpacken + Validieren liegt in `extractAndValidate`, damit
        // der Dry-Run (`preview`) EXAKT dieselben Pruefungen durchlaeuft. Eine
        // zweite Kopie waere genau die Art Divergenz, bei der die Vorschau
        // "sieht gut aus" sagt und der Import danach scheitert.
        let (files, meta) = try extractAndValidate(zipData: zipData)
        return try runImport(
            files: files,
            meta: meta,
            context: context,
            strategy: strategy,
            progressHandler: progressHandler
        )
    }

    /// DEL-226: Trockenlauf. Entpackt und validiert das ZIP genau wie ein
    /// echter Import, schreibt aber NICHTS. Liefert, was in der Datei steckt,
    /// damit der User vor dem Zugriff auf seinen Bestand sieht, ob es die
    /// richtige Datei ist.
    ///
    /// Bewusst KEINE Simulation der Duplikat-Erkennung: die haenge an den
    /// Importern und muesste hier nachgebaut werden — eine zweite Wahrheit,
    /// die mit der ersten auseinanderlaeuft und dann falsche Zahlen
    /// verspricht. Die Vorschau beantwortet stattdessen die Frage, die der
    /// User wirklich hat: "ist das die richtige Datei, und wie viel steckt
    /// drin — verglichen mit dem, was ich jetzt habe?"
    public static func preview(zipData: Data) throws -> DataImportPreview {
        let (files, meta) = try extractAndValidate(zipData: zipData)

        var rowCounts: [String: Int] = [:]
        for (name, data) in files where name.hasSuffix(".csv") {
            guard let text = String(data: data, encoding: .utf8),
                  let reader = try? CSVReader(text) else {
                rowCounts[name] = 0
                continue
            }
            rowCounts[name] = reader.rows().count
        }

        // Ein aktiver Plan im Backup ist der Punkt, an dem sich ein Import
        // sichtbar auf den Alltag auswirkt — deshalb explizit ausweisen.
        var containsActivePlan = false
        if let plans = files["plans.csv"],
           let text = String(data: plans, encoding: .utf8),
           let reader = try? CSVReader(text) {
            containsActivePlan = reader.rows().contains { ($0.bool("is_active") ?? false) }
        }

        return DataImportPreview(
            formatVersion: meta.formatVersion,
            exportedAt: meta.exportedAt,
            appVersion: meta.appVersion,
            rowCountsByFile: rowCounts,
            containsActivePlan: containsActivePlan
        )
    }

    /// Entpackt das ZIP und fuehrt alle Struktur-Pruefungen durch, ohne den
    /// `ModelContext` anzufassen.
    private static func extractAndValidate(zipData: Data) throws -> ([String: Data], MetaPayload) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("deltiq-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // ZIP-Bytes als File schreiben, dann unzippen.
        let zipFileURL = tmpDir.appendingPathComponent("import.zip")
        try zipData.write(to: zipFileURL)

        let extractedDir = tmpDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: zipFileURL, to: extractedDir)
        } catch {
            throw ImportError.zipNotReadable
        }

        // Files aus extractedDir lesen. Wir nutzen `enumerator` damit
        // Wrapper-Folders (z.B. `export-2026-05-29/profile.csv` aus einem
        // Finder-Repack) auch erreicht werden — der enumerator geht tiefer
        // als nur die Top-Level.
        var files: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(
            at: extractedDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]   // filter ._* and .DS_Store automatisch
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            let key = fileURL.lastPathComponent
            // Doppelter Schutz gegen macOS-Metadaten — auch wenn
            // .skipsHiddenFiles greift, fangen wir __MACOSX-Folders
            // explizit ab (die werden in iOS' .skipsHiddenFiles nicht
            // immer als hidden erkannt).
            if fileURL.pathComponents.contains("__MACOSX") { continue }
            if key.hasPrefix("._") || key == ".DS_Store" { continue }

            // Nur regular files lesen, keine Directories.
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues?.isRegularFile == true else { continue }

            let data = try Data(contentsOf: fileURL)
            files[key] = data
        }

        // 2) meta.json validieren — strukturelle Voraussetzung.
        guard let metaData = files["meta.json"], !metaData.isEmpty else {
            throw ImportError.missingMeta
        }
        let meta = try JSONDecoder().decode(MetaPayload.self, from: metaData)
        try Self.validateFormatVersion(meta.formatVersion)

        // 3) Anchor-File-Check. Mindestens eine der drei zentralen
        //    CSV-Tabellen muss vorhanden UND non-empty sein.
        let anchors = ["profile.csv", "workouts.csv", "plans.csv"]
        let hasUsableData = anchors.contains { name in
            guard let data = files[name] else { return false }
            return data.count > 50
        }
        guard hasUsableData else {
            throw ImportError.zipNotReadable
        }

        return (files, meta)
    }

    /// Fuehrt den eigentlichen Import auf bereits validierten Dateien aus.
    /// Getrennt von `extractAndValidate`, damit der Dry-Run dieselbe
    /// Validierung nutzen kann, ohne diesen schreibenden Teil zu beruehren.
    private static func runImport(
        files: [String: Data],
        meta: MetaPayload,
        context: ModelContext,
        strategy: DataImportStrategy,
        progressHandler: (@Sendable (ImportProgress) -> Void)?
    ) throws -> DataImportResult {

        // 4) ERST JETZT — nach voll-validiertem ZIP — dürfen wir die
        //    bestehenden Daten anfassen.
        if strategy == .replace {
            progressHandler?(ImportProgress(phase: "wipe", filesCompleted: 0, filesTotal: 0))
            try wipeAllUserData(context: context)
            try context.save()
        }

        // 3) Pro-Zeile-Fehler werden hier gesammelt.
        // (DEL-199: Das DEL-184/186-Diagnose-Gerüst — _decode/_reader-Rows
        // mit Byte-Dumps pro File — ist nach dem DEL-188-Parser-Fix wieder
        // ausgebaut. errors.csv enthält jetzt nur noch echte Row-Errors.)
        var errorBuffer = ErrorBuffer()
        var imported: [String: Int] = [:]
        var skipped:  [String: Int] = [:]

        // idMap: Export-UUID → frisches SwiftData-Objekt.
        var idMap: [String: AnyObject] = [:]

        let allFiles = [
            "profile.csv",
            "settings.csv",
            "gear.csv",
            "custom_exercises.csv",
            "plans.csv",
            "measurements.csv",
            "water_log.csv",
            "plan_days.csv",
            "workouts.csv",
            "plan_exercises.csv",
            "workout_sets.csv",
            "personal_records.csv",
        ]
        var completed = 0
        let totalFiles = allFiles.count

        func tick(_ filename: String, _ body: () throws -> Void) throws {
            progressHandler?(ImportProgress(
                phase: filename,
                filesCompleted: completed,
                filesTotal: totalFiles
            ))
            try body()
            completed += 1
        }

        // 4) PASS 1 — Roots ohne FK-Abhängigkeiten.
        try tick("profile.csv") {
            if let csv = files["profile.csv"] {
                let (ok, dup, errs) = try importProfile(csv: csv, context: context)
                imported["profile.csv"] = ok; skipped["profile.csv"] = dup
                errorBuffer.append(file: "profile.csv", errors: errs)
            }
        }
        try tick("settings.csv") {
            if let csv = files["settings.csv"] {
                // DEL-209: App-Einstellungen (Reminder, kg/lbs, Theme, ...).
                // Whitelist-gefiltert in SettingsPortability — unbekannte
                // Keys landen im skipped-Counter, nie in UserDefaults.
                let (ok, dup) = importSettings(csv: csv)
                imported["settings.csv"] = ok; skipped["settings.csv"] = dup
            }
        }
        try tick("gear.csv") {
            if let csv = files["gear.csv"] {
                let (ok, dup, errs) = try importGear(csv: csv, context: context, idMap: &idMap)
                imported["gear.csv"] = ok; skipped["gear.csv"] = dup
                errorBuffer.append(file: "gear.csv", errors: errs)
            }
        }
        try tick("custom_exercises.csv") {
            if let csv = files["custom_exercises.csv"] {
                let (ok, dup, errs) = try importCustomExercises(csv: csv, context: context, idMap: &idMap)
                imported["custom_exercises.csv"] = ok; skipped["custom_exercises.csv"] = dup
                errorBuffer.append(file: "custom_exercises.csv", errors: errs)
            }
        }
        try tick("plans.csv") {
            if let csv = files["plans.csv"] {
                let (ok, dup, errs) = try importPlans(csv: csv, context: context, idMap: &idMap)
                imported["plans.csv"] = ok; skipped["plans.csv"] = dup
                errorBuffer.append(file: "plans.csv", errors: errs)
            }
        }
        try tick("measurements.csv") {
            if let csv = files["measurements.csv"] {
                let (ok, dup, errs) = try importMeasurements(csv: csv, context: context)
                imported["measurements.csv"] = ok; skipped["measurements.csv"] = dup
                errorBuffer.append(file: "measurements.csv", errors: errs)
            }
        }
        try tick("water_log.csv") {
            if let csv = files["water_log.csv"] {
                let (ok, dup, errs) = try importWaterLog(csv: csv, context: context)
                imported["water_log.csv"] = ok; skipped["water_log.csv"] = dup
                errorBuffer.append(file: "water_log.csv", errors: errs)
            }
        }

        // 5) PASS 2 — Objekte mit FKs in Pass-1.
        try tick("plan_days.csv") {
            if let csv = files["plan_days.csv"] {
                let (ok, dup, errs) = try importPlanDays(csv: csv, context: context, idMap: &idMap)
                imported["plan_days.csv"] = ok; skipped["plan_days.csv"] = dup
                errorBuffer.append(file: "plan_days.csv", errors: errs)
            }
        }
        try tick("workouts.csv") {
            if let csv = files["workouts.csv"] {
                let (ok, dup, errs) = try importWorkouts(csv: csv, context: context, idMap: &idMap)
                imported["workouts.csv"] = ok; skipped["workouts.csv"] = dup
                errorBuffer.append(file: "workouts.csv", errors: errs)
            }
        }

        // 6) PASS 3 — Children mit FKs in Pass-2.
        try tick("plan_exercises.csv") {
            if let csv = files["plan_exercises.csv"] {
                let (ok, dup, errs) = try importPlanExercises(csv: csv, context: context, idMap: &idMap)
                imported["plan_exercises.csv"] = ok; skipped["plan_exercises.csv"] = dup
                errorBuffer.append(file: "plan_exercises.csv", errors: errs)
            }
        }
        try tick("workout_sets.csv") {
            if let csv = files["workout_sets.csv"] {
                let (ok, dup, errs) = try importLogs(csv: csv, context: context, idMap: idMap)
                imported["workout_sets.csv"] = ok; skipped["workout_sets.csv"] = dup
                errorBuffer.append(file: "workout_sets.csv", errors: errs)
            }
        }
        try tick("personal_records.csv") {
            if let csv = files["personal_records.csv"] {
                let (ok, dup, errs) = try importPRs(csv: csv, context: context, idMap: idMap)
                imported["personal_records.csv"] = ok; skipped["personal_records.csv"] = dup
                errorBuffer.append(file: "personal_records.csv", errors: errs)
            }
        }

        progressHandler?(ImportProgress(phase: "save", filesCompleted: totalFiles, filesTotal: totalFiles))

        // 7) Persist all changes atomically.
        try context.save()

        let errorsCSV: Data? = errorBuffer.totalCount > 0 ? errorBuffer.toCSV() : nil

        return DataImportResult(
            formatVersion: meta.formatVersion,
            exportedAt: meta.exportedAt,
            imported: imported,
            skipped:  skipped,
            errorRows: errorBuffer.totalCount,
            errorsCSV: errorsCSV
        )
    }


    // MARK: - Replace-Strategie: kompletter Wipe vor dem Merge

    /// Löscht ALLE User-Daten in deletion-rule-konformer Reihenfolge —
    /// gleiches Pattern wie `SettingsView.resetApp`, aber explizit ohne
    /// die System-Library-Templates (`isCustom == false`). Diese werden
    /// vom `LibrarySeeder` beim nächsten App-Start ohnehin neu geseedet;
    /// löschen würde nur die Custom-Eintragsdaten und User-Renames der
    /// System-Lifts beeinflussen, was wir nicht wollen.
    ///
    /// **Cascade-Regel-konform**: per-instance delete statt
    /// `delete(model:)`-Batch (NSBatchDeleteRequest umgeht
    /// `@Relationship`-Cascades und löst "mandatory OTO nullify"-
    /// Violations aus). Children-first ordering. Save passiert NICHT
    /// hier — der eigentliche Import sammelt seine Inserts an und ruft
    /// am Ende ein einziges `save()`, das den Wipe und den Merge atomisch
    /// committet.
    private static func wipeAllUserData(context: ModelContext) throws {
        try deleteEach(of: PersonalRecordEntry.self, in: context)
        try deleteEach(of: ExerciseLog.self,         in: context)
        try deleteEach(of: WorkoutSession.self,      in: context)
        try deleteEach(of: Exercise.self,            in: context)
        try deleteEach(of: TrainingDay.self,         in: context)
        try deleteEach(of: TrainingPlan.self,        in: context)
        // Nur Custom-Templates wegräumen — System-Library kommt vom Seeder.
        let customTemplates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
            .filter { $0.isCustom }
        for t in customTemplates { context.delete(t) }
        try deleteEach(of: WaterEntry.self,          in: context)
        try deleteEach(of: BodyMeasurement.self,     in: context)
        try deleteEach(of: Gear.self,                in: context)
        try deleteEach(of: UserBodyProfile.self,     in: context)
    }

    private static func deleteEach<T: PersistentModel>(of type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items { context.delete(item) }
    }

    // MARK: - Format version check

    private static func validateFormatVersion(_ version: String) throws {
        // "1.0.0" → major == 1
        let parts = version.split(separator: ".")
        guard let majorString = parts.first, let major = Int(majorString) else {
            throw ImportError.unsupportedFormatVersion(version)
        }
        guard major == Self.supportedMajorVersion else {
            throw ImportError.unsupportedFormatVersion(version)
        }
    }

    // MARK: - Meta payload

    private struct MetaPayload: Decodable {
        let formatVersion: String
        let exportedAt: String
        let appVersion: String
        let files: [String]?
    }

    // MARK: - Errors

    public enum ImportError: Error, LocalizedError {
        case zipNotReadable
        case missingMeta
        case unsupportedFormatVersion(String)

        public var errorDescription: String? {
            switch self {
            case .zipNotReadable:
                return "Archiv konnte nicht gelesen werden — beschädigte ZIP-Datei?"
            case .missingMeta:
                return "Archiv enthält kein meta.json — falsches Format?"
            case .unsupportedFormatVersion(let v):
                return "Format-Version \(v) wird von dieser App-Version nicht unterstützt."
            }
        }
    }

    // MARK: - Error buffer

    private struct RowError {
        let line: Int
        let reason: String
    }

    private struct ErrorBuffer {
        private(set) var totalCount: Int = 0
        private var rows: [(String, RowError)] = []

        mutating func append(file: String, errors: [RowError]) {
            for e in errors {
                rows.append((file, e))
            }
            totalCount += errors.count
        }

        func toCSV() -> Data {
            var w = CSVWriter(headers: ["file", "line", "reason"])
            for (file, err) in rows {
                w.appendRow([file, String(err.line), err.reason])
            }
            return w.data()
        }
    }

    // MARK: - Pass 1: Profile

    private static func importProfile(csv: Data, context: ModelContext) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        // DEL-191: Profil ist ein Singleton — "append" macht keinen Sinn,
        // ein Restore SOLL die Profil-Präferenzen (Dashboard-Layout, Ziele,
        // Vorname, Coaching-Ton, Equipment) zurückbringen. Vorher wurde der
        // Import komplett geskippt wenn schon ein Profil existierte (z.B.
        // nach Neu-Onboarding) — Folge: Dashboard-Einordnung + Settings aus
        // dem Backup gingen verloren. Jetzt: existierendes Profil wird
        // IN-PLACE mit den Backup-Werten überschrieben (kein Duplikat, keine
        // verwaisten Relationships). Gibt es noch kein Profil → frisch
        // inserten wie bisher.
        let existing = try context.fetch(FetchDescriptor<UserBodyProfile>())
        let target = existing.first

        var errors: [RowError] = []
        var imported = 0

        for row in reader.rows() {
            guard let birthDate = row.date("birth_date"),
                  let height = row.double("height_cm") else {
                errors.append(.init(line: row.lineNumber, reason: "missing birth_date or height_cm"))
                continue
            }
            let profileEnum = BodyFormulaProfile(rawValue: row["profile"]) ?? .male
            let envEnum = EnvironmentType(rawValue: row["environment"]) ?? .gym

            let p = target ?? UserBodyProfile(
                birthDate: birthDate,
                heightCm: height,
                profile: profileEnum,
                goalWeightKg: row.double("goal_weight_kg"),
                environment: envEnum
            )
            // Bei einem existierenden Profil die Kern-Felder explizit
            // überschreiben (der Init oben läuft dann nicht).
            if target != nil {
                p.birthDate = birthDate
                p.heightCm = height
                p.profile = profileEnum
                p.goalWeightKg = row.double("goal_weight_kg")
                p.environment = envEnum
            }
            p.firstName = row.optionalString("first_name")
            p.coachingToneRaw = row.optionalString("coaching_tone") ?? CoachingTone.analytical.rawValue
            p.trainingGoalRaw = row.optionalString("training_goal") ?? TrainingGoal.hybrid.rawValue
            p.equipmentPreferencesRaw = splitMulti(row["equipment_preferences"])
            let dashboardRaw = splitMulti(row["dashboard_widgets"])
            if !dashboardRaw.isEmpty { p.activeDashboardWidgetsRaw = dashboardRaw }
            let heroRaw = splitMulti(row["hero_metric_slots"])
            if !heroRaw.isEmpty { p.heroMetricSlotsRaw = heroRaw }
            // DEL-203: additive Spalte — ältere ZIPs ohne sie → Default 1.
            p.weeklyWorkoutGoal = row.int("weekly_workout_goal") ?? 1

            if target == nil {
                context.insert(p)
            }
            imported += 1
            // Nur die erste Profil-Zeile verarbeiten — Singleton.
            break
        }
        return (imported, 0, errors)
    }

    // MARK: - Pass 1: Settings (DEL-209)

    /// Wendet die Whitelist-Settings aus settings.csv an. Kein FK, kein
    /// SwiftData — reine UserDefaults-Anwendung. (applied, skipped).
    private static func importSettings(csv: Data) -> (Int, Int) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        guard let reader = try? CSVReader(text) else { return (0, 0) }
        let rows = reader.rows().compactMap { row -> (key: String, value: String)? in
            let key = row["key"]
            guard !key.isEmpty else { return nil }
            return (key, row["value"])
        }
        let result = SettingsPortability.apply(rows)
        return (result.applied, result.skipped)
    }

    // MARK: - Pass 1: Gear

    private static func importGear(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        let existing = try context.fetch(FetchDescriptor<Gear>())
        var existingIndex: [String: Gear] = [:]
        for g in existing {
            existingIndex[Self.gearKey(name: g.name, type: g.type.rawValue)] = g
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            let exportID = row["id"]
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty,
                  let type = GearType(rawValue: row["type"]) else {
                errors.append(.init(line: row.lineNumber, reason: "missing or invalid name/type"))
                continue
            }
            let key = Self.gearKey(name: name, type: type.rawValue)
            if let dup = existingIndex[key] {
                // Bestehendes Gear referenzieren, damit Sessions auf das
                // korrekte SwiftData-Objekt zeigen.
                if !exportID.isEmpty { idMap[exportID] = dup }
                skipped += 1
                continue
            }
            let g = Gear(
                name: name,
                type: type,
                maxDistanceKm: row.double("max_distance_km") ?? 800,
                currentDistanceKm: row.double("current_distance_km") ?? 0,
                isActive: row.bool("is_active") ?? true,
                createdAt: row.date("created_at_utc") ?? Date()
            )
            context.insert(g)
            existingIndex[key] = g
            if !exportID.isEmpty { idMap[exportID] = g }
            imported += 1
        }
        return (imported, skipped, errors)
    }

    private static func gearKey(name: String, type: String) -> String {
        "\(name.lowercased())|\(type)"
    }

    // MARK: - Pass 1: Custom Exercises

    private static func importCustomExercises(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        // Dedup-Index: alle ExerciseTemplates (system + custom) — wenn der
        // User eine eigene Übung "Squat Variante" hat und das ZIP auch eine
        // bringt, soll nur eine existieren.
        let existing = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        var existingIndex: [String: ExerciseTemplate] = [:]
        for t in existing {
            existingIndex[t.name.lowercased()] = t
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            let exportID = row["id"]
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty,
                  let equipment = Equipment(rawValue: row["equipment"]),
                  let muscle = MuscleGroup(rawValue: row["primary_muscle"]) else {
                errors.append(.init(line: row.lineNumber, reason: "missing or invalid name/equipment/primary_muscle"))
                continue
            }
            if let dup = existingIndex[name.lowercased()] {
                if !exportID.isEmpty { idMap[exportID] = dup }
                skipped += 1
                continue
            }
            let difficulty = DifficultyLevel(rawValue: row["difficulty_level"]) ?? .intermediate
            let recovery = ExerciseRecoveryClass(rawValue: row["recovery_class"]) ?? .medium
            let t = ExerciseTemplate(
                name: name,
                equipment: equipment,
                primaryMuscle: muscle,
                isCustom: row.bool("is_custom") ?? true,
                difficultyLevel: difficulty,
                isSystemCompound: row.bool("is_system_compound") ?? false,
                isTimeBased: row.bool("is_time_based") ?? false,
                isCardio: row.bool("is_cardio") ?? false,
                systemicFatigueFactor: row.double("systemic_fatigue_factor") ?? 0.35,
                localMuscleDamageFactor: row.double("local_muscle_damage_factor") ?? 0.35,
                cnsDemandFactor: row.double("cns_demand_factor") ?? 0.25,
                axialLoadFactor: row.double("axial_load_factor") ?? 0.20,
                technicalComplexityFactor: row.double("technical_complexity_factor") ?? 0.30,
                recoveryClass: recovery,
                localizationKey: row.optionalString("localization_key"),
                isSystemProvided: row.bool("is_system_provided") ?? false
            )
            context.insert(t)
            existingIndex[name.lowercased()] = t
            if !exportID.isEmpty { idMap[exportID] = t }
            imported += 1
        }
        return (imported, skipped, errors)
    }

    // MARK: - Pass 1: Plans

    private static func importPlans(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        var errors: [RowError] = []
        var imported = 0

        // DEL-192 wollte, dass nach einem Restore GENAU der Backup-Plan aktiv
        // ist: dazu wurden vorher alle bestehenden aktiven Plaene deaktiviert.
        //
        // DEL-225 ersetzt das durch eine Regel, die keinen Bestand anfasst:
        // der aktive Zustand aus dem Backup wird nur uebernommen, wenn
        // aktuell KEIN Plan aktiv ist.
        //   * Restore (`replace`): die Datenbank ist vorher gewischt, es gibt
        //     keinen aktiven Plan → Backup-Zustand gilt, wie von DEL-192
        //     gewuenscht.
        //   * Import in eine frische Installation: dito.
        //   * Ergaenzender Import (`appendOnly`) bei laufendem Training: der
        //     eigene aktive Plan bleibt aktiv, der importierte kommt inaktiv
        //     an und kann bewusst uebernommen werden. Vorher schaltete ein
        //     beliebiges fremdes Backup den laufenden Plan des Users still um.
        //
        // Nebeneffekt, den die alte Fassung nicht abdeckte: enthaelt das
        // Backup MEHRERE aktive Plaene, wird nur der erste aktiv — sonst
        // haette der User danach zwei "aktive" Plaene.
        let existingPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        var mayActivate = !existingPlans.contains(where: \.isActive)

        for row in reader.rows() {
            let exportID = row["id"]
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty else {
                errors.append(.init(line: row.lineNumber, reason: "missing name"))
                continue
            }
            let env = EnvironmentType(rawValue: row["target_environment"]) ?? .gym

            let plan = TrainingPlan(
                name: name,
                customName: row.optionalString("custom_name"),
                programType: row["program_type"],
                descriptionText: row["description"],
                weeks: row.int("weeks") ?? 12,
                // DEL-192: aktiven Zustand aus dem Backup honorieren. Vorher
                // hardcoded false → nach Restore war kein Plan aktiv, der
                // User musste manuell aktivieren. Da wir oben alle
                // bestehenden Aktiven deaktiviert haben, gibt es keinen
                // Doppel-Aktiv-Konflikt.
                // DEL-225: nur wenn aktuell kein Plan aktiv ist (siehe oben).
                isActive: mayActivate && (row.bool("is_active") ?? false),
                targetEnvironment: env,
                isTemplate: row.bool("is_template") ?? false,
                localizationKey: row.optionalString("localization_key")
            )
            if let override = row.double("progression_target_rir_override") {
                plan.progressionTargetRIROverride = Float(override)
            }
            // Bugfix (Audit): additive Spalte, siehe DataExportService.buildPlans.
            // Aeltere ZIPs ohne die Spalte -> nil, "neu rechnen" bleibt fuer sie
            // einfach deaktiviert (unveraendertes Verhalten von vorher), statt
            // dass diese Zeile crasht oder eine leere Zeichenkette als "echtes"
            // JSON missversteht.
            if let raw = row.optionalString("generator_input_raw") {
                plan.generatorInputRaw = raw
            }
            // DEL-225: Sobald ein Plan aktiv gesetzt wurde, darf kein weiterer
            // folgen — ein Backup mit mehreren aktiven Plaenen soll nicht in
            // zwei gleichzeitig aktiven Plaenen resultieren.
            if plan.isActive { mayActivate = false }
            context.insert(plan)
            if !exportID.isEmpty { idMap[exportID] = plan }
            imported += 1
        }
        return (imported, 0, errors)
    }

    // MARK: - Pass 1: Measurements

    private static func importMeasurements(csv: Data, context: ModelContext) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        // Dedup-Index: (date.timeIntervalSince1970 rounded to second, weightKg×100)
        // — so überleben Floating-Wackler im Sub-mg-Bereich.
        let existing = try context.fetch(FetchDescriptor<BodyMeasurement>())
        var dupSet = Set<String>()
        for m in existing {
            dupSet.insert(Self.measurementKey(date: m.date, weightKg: m.weightKg))
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            guard let date = row.date("date_utc"),
                  let weight = row.double("weight_kg") else {
                errors.append(.init(line: row.lineNumber, reason: "missing date_utc or weight_kg"))
                continue
            }
            let key = Self.measurementKey(date: date, weightKg: weight)
            if dupSet.contains(key) {
                skipped += 1
                continue
            }
            let m = BodyMeasurement(
                date: date,
                ageYearsAtMeasurement: row.int("age_years_at_measurement") ?? 0,
                weightKg: weight,
                neckCm: row.double("neck_cm"),
                waistCm: row.double("waist_cm"),
                hipCm: row.double("hip_cm"),
                shoulderCm: row.double("shoulder_cm"),
                chestCm: row.double("chest_cm"),
                upperArmCm: row.double("upper_arm_cm"),
                thighCm: row.double("thigh_cm"),
                calfCm: row.double("calf_cm"),
                upperArmLeftCm: row.double("upper_arm_left_cm"),
                upperArmRightCm: row.double("upper_arm_right_cm"),
                thighLeftCm: row.double("thigh_left_cm"),
                thighRightCm: row.double("thigh_right_cm"),
                bmi: row.double("bmi"),
                navyBodyFatPct: row.double("navy_body_fat_pct"),
                deurenbergBodyFatPct: row.double("deurenberg_body_fat_pct"),
                selectedBodyFatPct: row.double("selected_body_fat_pct"),
                fatFreeMassKg: row.double("fat_free_mass_kg"),
                ffmi: row.double("ffmi"),
                normalizedFfmi: row.double("normalized_ffmi"),
                bmr: row.double("bmr")
            )
            context.insert(m)
            dupSet.insert(key)
            imported += 1
        }
        return (imported, skipped, errors)
    }

    private static func measurementKey(date: Date, weightKg: Double) -> String {
        let seconds = Int(date.timeIntervalSince1970)
        let cents = Int((weightKg * 100).rounded())
        return "\(seconds)|\(cents)"
    }

    // MARK: - Pass 1: Water log

    private static func importWaterLog(csv: Data, context: ModelContext) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        let existing = try context.fetch(FetchDescriptor<WaterEntry>())
        var dupSet = Set<String>()
        for e in existing {
            dupSet.insert("\(Int(e.date.timeIntervalSince1970))|\(e.amountMl)")
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            guard let date = row.date("date_utc"),
                  let ml = row.int("amount_ml") else {
                errors.append(.init(line: row.lineNumber, reason: "missing date_utc or amount_ml"))
                continue
            }
            let key = "\(Int(date.timeIntervalSince1970))|\(ml)"
            if dupSet.contains(key) {
                skipped += 1
                continue
            }
            let e = WaterEntry(date: date, amountMl: ml)
            context.insert(e)
            dupSet.insert(key)
            imported += 1
        }
        return (imported, skipped, errors)
    }

    // MARK: - Pass 2: Plan Days

    private static func importPlanDays(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        var errors: [RowError] = []
        var imported = 0

        for row in reader.rows() {
            let exportID = row["id"]
            let planID = row["plan_id"]
            // DEL-189: Orphan-Toleranz. TrainingDay.plan ist optional, also
            // erlauben wir Days mit nil plan (z.B. exportierter Bestand,
            // dessen ursprünglicher Plan via .nullify-deleteRule entfernt
            // wurde). Wenn planID leer ist → kein Lookup, day kommt rein
            // ohne Plan-Backref. Wenn planID gesetzt aber unknown → wir
            // loggen einen Hinweis, importieren aber trotzdem (besser ein
            // orphan-Day mit Snapshot als verlorene Plan-Struktur).
            let plan = idMap[planID] as? TrainingPlan
            if !planID.isEmpty && plan == nil {
                errors.append(.init(line: row.lineNumber, reason: "plan_id \(planID) not found — importing as orphan"))
            }
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty else {
                errors.append(.init(line: row.lineNumber, reason: "missing name"))
                continue
            }
            let type = DayType(rawValue: row["type"]) ?? .custom
            let intensity = DayIntensity(rawValue: row["next_intensity"]) ?? .normal
            // Bugfix (Audit): additive Spalten, siehe DataExportService.buildDays.
            // Aeltere ZIPs ohne sie -> beide nil, exakt der schon immer
            // bestehende "normaler Satz/Wiederholungs-Tag"-Bestandsfall.
            let timeFormat = row.optionalString("time_format").flatMap(WorkoutTimeFormat.init(rawValue:))

            let day = TrainingDay(
                name: name,
                customName: row.optionalString("custom_name"),
                weekday: row.int("weekday") ?? 1,
                type: type,
                nextIntensity: intensity,
                plan: plan,
                localizationKey: row.optionalString("localization_key"),
                timeFormat: timeFormat,
                timeCapMinutes: row.int("time_cap_minutes")
            )
            context.insert(day)
            if !exportID.isEmpty { idMap[exportID] = day }
            imported += 1
        }
        return (imported, 0, errors)
    }

    // MARK: - Pass 2: Workouts

    private static func importWorkouts(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        // Dedup-Index: startTime → existierende Session. Sub-Sekunde
        // genügt (kein User wird zwei Workouts in der gleichen Sekunde
        // starten).
        let existing = try context.fetch(FetchDescriptor<WorkoutSession>())
        var dupIndex: [Int: WorkoutSession] = [:]
        for s in existing {
            dupIndex[Int(s.startTime.timeIntervalSince1970)] = s
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            let exportID = row["id"]
            guard let start = row.date("start_time_utc"),
                  let end = row.date("end_time_utc") else {
                errors.append(.init(line: row.lineNumber, reason: "missing start_time_utc or end_time_utc"))
                continue
            }
            let key = Int(start.timeIntervalSince1970)
            if let existingSession = dupIndex[key] {
                // Duplikat — den existierenden in die idMap eintragen,
                // damit nachfolgende workout_sets diesen Session-Pointer
                // benutzen statt neue Logs an einen neuen leeren Container
                // zu hängen.
                if !exportID.isEmpty { idMap[exportID] = existingSession }
                skipped += 1
                continue
            }
            // Bugfix (Audit): additive Spalten, siehe DataExportService.
            // buildWorkouts. Aeltere ZIPs ohne sie -> `timeFormatSnapshot`
            // bleibt nil (normale Krafteinheit), die restlichen Felder ihre
            // Modell-Defaults (nil/false) - unveraendertes Verhalten von vorher.
            let timeFormatSnapshot = row.optionalString("time_format_snapshot").flatMap(WorkoutTimeFormat.init(rawValue:))

            let s = WorkoutSession(
                startTime: start,
                endTime: end,
                durationMinutes: row.int("duration_minutes") ?? 0,
                exerciseCount: row.int("exercise_count") ?? 0,
                totalSets: row.int("total_sets") ?? 0,
                totalVolumeKg: row.double("total_volume_kg") ?? 0,
                notes: row.optionalString("notes"),
                isCompleted: row.bool("is_completed") ?? true,
                isRestDay: row.bool("is_rest_day") ?? false,
                isAdHoc: row.bool("is_ad_hoc") ?? false,
                dayName: row.optionalString("day_name_snapshot"),
                timeFormatSnapshot: timeFormatSnapshot,
                roundsCompleted: row.int("rounds_completed"),
                partialReps: row.int("partial_reps"),
                partialRepsExerciseName: row.optionalString("partial_reps_exercise_name"),
                finishTimeSeconds: row.int("finish_time_seconds"),
                completedMinuteCount: row.int("completed_minute_count"),
                completedTarget: row.bool("completed_target") ?? false
            )
            if let feeling = row.int("session_feeling") {
                s.sessionFeeling = feeling
            }
            // Gear/Day-Backref via idMap (lookup nur, kein Fehler wenn nicht da).
            if let gear = idMap[row["gear_id"]] as? Gear { s.gear = gear }
            if let day = idMap[row["day_id"]] as? TrainingDay { s.day = day }

            context.insert(s)
            dupIndex[key] = s
            if !exportID.isEmpty { idMap[exportID] = s }
            imported += 1
        }
        return (imported, skipped, errors)
    }

    // MARK: - Pass 3: Exercises

    private static func importPlanExercises(
        csv: Data,
        context: ModelContext,
        idMap: inout [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        var errors: [RowError] = []
        var imported = 0
        // DEL-225: gesammelte Swap-Referenzen fuer den Nachlauf unten.
        var pendingSwapRefs: [(exercise: Exercise, originalExportID: String)] = []

        for row in reader.rows() {
            let exportID = row["id"]
            let dayID = row["day_id"]
            // DEL-189: Orphan-Toleranz analog zu PlanDays. Exercise.day ist
            // Optional — wir importieren auch wenn day nicht in idMap, mit
            // einer Info-Zeile in den errors.csv (nicht abbrechend).
            let day = idMap[dayID] as? TrainingDay
            if !dayID.isEmpty && day == nil {
                errors.append(.init(line: row.lineNumber, reason: "day_id \(dayID) not found — importing as orphan"))
            }
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty else {
                errors.append(.init(line: row.lineNumber, reason: "missing name"))
                continue
            }
            let role = ExerciseRole(rawValue: row["role"]) ?? .workingSet
            let recovery = ExerciseRecoveryClass(rawValue: row["recovery_class"]) ?? .medium
            let supersetId = UUID(uuidString: row["superset_id"])
            let primaryMuscle = MuscleGroup(rawValue: row["primary_muscle"])
            let equipment = Equipment(rawValue: row["equipment"])

            let e = Exercise(
                name: name,
                customName: row.optionalString("custom_name"),
                sets: row.int("sets") ?? 3,
                repsMin: row.int("reps_min") ?? 8,
                repsMax: row.int("reps_max") ?? 12,
                restSeconds: row.int("rest_seconds") ?? 90,
                notes: row.optionalString("notes"),
                suggestedWeight: row.double("suggested_weight_kg"),
                orderIndex: row.int("order_index") ?? 0,
                targetRir: row.double("target_rir").map(Float.init) ?? 2.0,
                weightReducedNote: row.optionalString("weight_reduced_note"),
                isCardio: row.bool("is_cardio") ?? false,
                isTimeBased: row.bool("is_time_based") ?? false,
                isArchived: row.bool("is_archived") ?? false,
                smartProgressionEnabled: row.bool("smart_progression_enabled") ?? true,
                progressionStep: row.double("progression_step") ?? 2.5,
                isCompound: row.bool("is_compound") ?? false,
                targetDistanceKm: row.double("target_distance_km"),
                targetDurationMinutes: row.int("target_duration_minutes"),
                supersetId: supersetId,
                role: role,
                systemicFatigueFactor: row.double("systemic_fatigue_factor") ?? 0.35,
                localMuscleDamageFactor: row.double("local_muscle_damage_factor") ?? 0.35,
                cnsDemandFactor: row.double("cns_demand_factor") ?? 0.25,
                axialLoadFactor: row.double("axial_load_factor") ?? 0.20,
                technicalComplexityFactor: row.double("technical_complexity_factor") ?? 0.30,
                recoveryClass: recovery,
                primaryMuscle: primaryMuscle,
                equipment: equipment,
                day: day
            )
            if let cardioEquipRaw = row.optionalString("cardio_equipment") {
                e.cardioEquipmentRaw = cardioEquipRaw
            }
            // DEL-208: Deload-Zustand normalisieren. Wurde das Backup mitten
            // in einer Deload-Woche (DEL-200) erstellt, enthält
            // suggested_weight_kg das HALBIERTE Gewicht und
            // deload_original_weight das Original. Der Deload-Timer lebt in
            // AppStorage und ist nicht portabel — ohne Normalisierung
            // blieben die reduzierten Gewichte auf dem neuen Gerät dauerhaft
            // hängen (kein Banner, kein Auto-Restore). Deshalb: Original
            // zurückschreiben, Snapshot leer lassen — der Import landet im
            // sauberen Nicht-Deload-Zustand.
            if let original = row.double("deload_original_weight"), original > 0 {
                e.suggestedWeight = original
            }
            context.insert(e)
            if !exportID.isEmpty { idMap[exportID] = e }
            // DEL-225: Swap-Referenz erst nach dem Durchlauf aufloesen — die
            // Original-Uebung kann in derselben Datei WEITER UNTEN stehen und
            // waere hier noch nicht in der idMap.
            if let originalID = row.optionalString("swapped_from_original") {
                pendingSwapRefs.append((exercise: e, originalExportID: originalID))
            }
            imported += 1
        }

        // DEL-225: Zweiter Durchlauf fuer die Swap-Referenzen (DEL-091
        // Urlaubs-Modus). Ohne diese Spalte war das Original nach einem Restore
        // verloren und der Tausch nicht mehr zuruecknehmbar. Nicht aufloesbare
        // Referenzen sind kein Fehler, sondern erwartbar bei Teil-Backups —
        // sie landen als Info in errors.csv.
        for ref in pendingSwapRefs {
            if let original = idMap[ref.originalExportID] as? Exercise {
                ref.exercise.swappedFromOriginal = original
            } else {
                errors.append(.init(
                    line: 0,
                    reason: "swapped_from_original \(ref.originalExportID) not found — Swap-Referenz bleibt leer"
                ))
            }
        }
        return (imported, 0, errors)
    }

    // MARK: - Pass 3: Logs

    private static func importLogs(
        csv: Data,
        context: ModelContext,
        idMap: [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        // Dedup-Strategie für Logs: session.startTime + logDate + setIndex +
        // nameSnapshot (DEL-225: logDate ist neu, siehe `logKey`).
        // Wir bauen den Index aus den BESTEHENDEN Logs (vor diesem Import-Lauf).
        // Die in diesem Lauf neu eingefügten Sessions haben per Definition
        // keine bestehenden Logs, also können wir nicht-naiv ohne Konflikt
        // einfügen.
        let existing = try context.fetch(FetchDescriptor<ExerciseLog>())
        var dupSet = Set<String>()
        for l in existing {
            dupSet.insert(Self.logKey(
                // DEL-230: `?? l.date` ist entscheidend und war der Grund,
                // warum Orphan-Logs bei JEDEM Import erneut eingefuegt wurden.
                // Die Lese-Seite unten setzt bei fehlender Session den
                // Log-eigenen `date` als Session-Anker ein (`?? date`), diese
                // Seite liess das Feld dagegen leer und der Schluessel begann
                // mit "-1". Fuer Logs ohne Session-Backref (DEL-189-Pfad)
                // konnten die beiden Schluessel deshalb nie uebereinstimmen —
                // ein Re-Import derselben ZIP legte den Orphan jedes Mal neu an.
                // Der Fehler ist aelter als DEL-225 und blieb unsichtbar, weil
                // `swift test` seit Mitte Mai nicht mehr lief (DEL-230).
                sessionStart: l.session?.startTime ?? l.date,
                logDate: l.date,
                setIndex: l.setIndex,
                nameSnapshot: l.exerciseNameSnapshot
            ))
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            let sessionID = row["session_id"]
            // DEL-189: ExerciseLog.session ist optional (DEL-051 Snapshot-
            // Pattern: PR-Detection liest exerciseNameSnapshot, nicht den
            // session-Pointer). Orphan-Logs werden importiert, damit die
            // History (32KB workout_sets!) zurückkommt, auch wenn der
            // session-Backref leer ist.
            let session = idMap[sessionID] as? WorkoutSession
            if !sessionID.isEmpty && session == nil {
                errors.append(.init(line: row.lineNumber, reason: "session_id \(sessionID) not found — importing as orphan"))
            }
            guard let date = row.date("date_utc") else {
                errors.append(.init(line: row.lineNumber, reason: "missing date_utc"))
                continue
            }
            let setIndex = row.int("set_index") ?? 0
            let nameSnap = row.optionalString("exercise_name_snapshot")
            let dupKey = Self.logKey(
                // Dedup über session.startTime falls vorhanden, sonst über
                // den Log-eigenen `date` — orphan-Logs haben keinen Session-
                // Pointer mehr.
                sessionStart: session?.startTime ?? date,
                logDate: date,
                setIndex: setIndex,
                nameSnapshot: nameSnap
            )
            if dupSet.contains(dupKey) {
                skipped += 1
                continue
            }

            let exercise = idMap[row["exercise_id"]] as? Exercise

            let log = ExerciseLog(
                date: date,
                setIndex: setIndex,
                weight: row.double("weight_kg") ?? 0,
                reps: row.int("reps") ?? 0,
                rpe: row.double("rpe") ?? 0,
                rir: row.double("rir").map(Float.init) ?? 0,
                comment: row.optionalString("comment"),
                exercise: exercise,
                session: session,
                distanceKm: row.double("distance_km"),
                durationSeconds: row.int("duration_seconds")
            )
            // Snapshot-Felder explizit überschreiben — der Init zieht sie aus
            // der Live-Exercise, aber wir importieren die HISTORISCHE Wahrheit
            // (manuell gepflegte oder migrierte Snapshots dürfen nicht
            // verlorengehen).
            log.exerciseNameSnapshot = nameSnap
            log.exerciseIsCardioSnapshot = row.bool("exercise_is_cardio_snapshot") ?? false
            log.exerciseIsTimeBasedSnapshot = row.bool("exercise_is_time_based_snapshot") ?? false
            log.exerciseCardioEquipmentSnapshot = row.optionalString("exercise_cardio_equipment_snapshot")

            context.insert(log)
            dupSet.insert(dupKey)
            imported += 1
        }
        return (imported, skipped, errors)
    }

    /// Dedup-Schluessel eines Satzes.
    ///
    /// DEL-225: `logDate` ist neu und behebt einen stillen Datenverlust. Vorher
    /// bestand der Schluessel aus (session.startTime, setIndex, nameSnapshot).
    /// Wer dieselbe Uebung ZWEIMAL in einem Training hatte — schwerer
    /// Hauptsatz frueh, Back-off-Saetze spaeter, ein voellig normales Muster,
    /// und nichts in der App verhindert es — bekam fuer beide Serien
    /// (gleiche Session, gleicher Name, Satz-Index jeweils ab 0) identische
    /// Schluessel. Die komplette zweite Serie wurde beim Import als Duplikat
    /// verworfen.
    ///
    /// Warum der Log-Zeitstempel und nicht die Uebungs-Identitaet: Die
    /// Uebungs-Identitaet waere die intuitive Wahl, macht den Import aber
    /// KAPUTT. `importPlanExercises` hat kein Dedup, ein zweiter Import
    /// derselben ZIP legt also neue Exercise-Rows an. Ein Schluessel ueber
    /// deren Identitaet wuerde dann nicht mehr matchen und saemtliche Logs
    /// erneut einfuegen — aus "verliert Saetze" wuerde "verdoppelt alles".
    /// Der Log-Zeitstempel dagegen liegt auf beiden Seiten vor (im CSV als
    /// `date_utc`, an bestehenden Logs als `date`) und ist ueber
    /// Import-Zyklen stabil.
    ///
    /// Sekunden-Granularitaet ist Absicht: der Export schreibt Millisekunden,
    /// eine in der DB liegende `Date` kann feinere Praezision haben. Beim
    /// Roundtrip wuerde ein Sub-Millisekunden-Anteil abgeschnitten, die
    /// Schluessel wichen um Bruchteile ab und der Re-Import wuerde
    /// duplizieren. Zwei Serien derselben Uebung in derselben Sekunde sind
    /// dagegen kein realer Fall.
    private static func logKey(
        sessionStart: Date?,
        logDate: Date?,
        setIndex: Int,
        nameSnapshot: String?
    ) -> String {
        let s = sessionStart.map { Int($0.timeIntervalSince1970) } ?? -1
        let d = logDate.map { Int($0.timeIntervalSince1970) } ?? -1
        let n = nameSnapshot ?? ""
        return "\(s)|\(d)|\(setIndex)|\(n)"
    }

    // MARK: - Pass 3: PRs

    private static func importPRs(
        csv: Data,
        context: ModelContext,
        idMap: [String: AnyObject]
    ) throws -> (Int, Int, [RowError]) {
        let text = String(data: csv, encoding: .utf8) ?? ""
        let reader: CSVReader
        do { reader = try CSVReader(text) } catch { return (0, 0, []) }

        let existing = try context.fetch(FetchDescriptor<PersonalRecordEntry>())
        var dupSet = Set<String>()
        for p in existing {
            dupSet.insert(Self.prKey(date: p.date, name: p.exerciseName, kind: p.kindRaw))
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            guard let date = row.date("date_utc") else {
                errors.append(.init(line: row.lineNumber, reason: "missing date_utc"))
                continue
            }
            let name = row["exercise_name"]
            let kind = row["kind"]
            guard !name.isEmpty, !kind.isEmpty else {
                errors.append(.init(line: row.lineNumber, reason: "missing exercise_name or kind"))
                continue
            }
            let key = Self.prKey(date: date, name: name, kind: kind)
            if dupSet.contains(key) {
                skipped += 1
                continue
            }
            let session = idMap[row["session_id"]] as? WorkoutSession

            let p = PersonalRecordEntry(
                date: date,
                exerciseName: name,
                kindRaw: kind,
                value: row.double("value") ?? 0,
                previousValue: row.double("previous_value") ?? 0,
                weightKg: row.double("weight_kg") ?? 0,
                reps: row.int("reps") ?? 0,
                cardioEquipmentRaw: row.optionalString("cardio_equipment"),
                session: session
            )
            context.insert(p)
            dupSet.insert(key)
            imported += 1
        }
        return (imported, skipped, errors)
    }

    private static func prKey(date: Date, name: String, kind: String) -> String {
        "\(Int(date.timeIntervalSince1970))|\(name.lowercased())|\(kind)"
    }

    // MARK: - Helpers

    /// Splitter für die `equipment_preferences` / `dashboard_widgets` /
    /// `hero_metric_slots`-Spalten, die wir als `;`-separated joinen.
    private static func splitMulti(_ raw: String) -> [String] {
        raw.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
    }
}

#endif
