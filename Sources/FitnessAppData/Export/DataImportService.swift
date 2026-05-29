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

        // 1) ZIP entpacken. URL-basierte Extract-API ist robuster als das
        //    closure-buffer-Pattern.
        //
        // ZIPFoundation 0.9.x bietet zwei Init-Varianten:
        //   - `init?(data:accessMode:preferredEncoding:)` failable, deprecated
        //   - `init(data:accessMode:preferredEncoding:) throws` neu, empfohlen
        // Wir nehmen die throwing-Variante und mappen den ZIP-Error auf
        // unseren ImportError, damit die UI eine sprechende Meldung
        // rendern kann statt eines ZIP-internen `EntryNotFound`-Texts.
        let archive: Archive
        do {
            archive = try Archive(data: zipData, accessMode: .read)
        } catch {
            throw ImportError.zipNotReadable
        }
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("deltiq-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var files: [String: Data] = [:]
        for entry in archive {
            // macOS-Metadaten komplett ignorieren
            if entry.path.contains("__MACOSX") || entry.path.hasSuffix(".DS_Store") {
                continue
            }
            
            // Path-Normalisierung: "export-2026-05/profile.csv" -> "profile.csv"
            let key = (entry.path as NSString).lastPathComponent
            
            // Verzeichnis-Einträge überspringen
            guard !key.isEmpty, entry.type == Entry.EntryType.file else { continue }

            
            // Versteckte macOS "dotfiles" (z.B. ._workouts.csv) ignorieren, 
            // die Finder oft mit anlegt.
            if key.hasPrefix("._") {
                continue
            }

            let dst = tmpDir.appendingPathComponent(key)
            _ = try archive.extract(entry, to: dst)
            let data = try Data(contentsOf: dst)
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

        // 4) ERST JETZT — nach voll-validiertem ZIP — dürfen wir die
        //    bestehenden Daten anfassen.
        if strategy == .replace {
            progressHandler?(ImportProgress(phase: "wipe", filesCompleted: 0, filesTotal: 0))
            try wipeAllUserData(context: context)
            try context.save()
        }

        // 3) Pro-Zeile-Fehler werden hier gesammelt.
        var errorBuffer = ErrorBuffer()
        var imported: [String: Int] = [:]
        var skipped:  [String: Int] = [:]

        // idMap: Export-UUID → frisches SwiftData-Objekt.
        var idMap: [String: AnyObject] = [:]

        let allFiles = [
            "profile.csv",
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

        // Singleton: wenn es schon ein Profile gibt, importieren wir keines.
        // Der User muss erst über "App zurücksetzen" sauber machen, sonst
        // hätten wir zwei Profile in der DB (was die ganze App verwirrt).
        let existing = try context.fetch(FetchDescriptor<UserBodyProfile>())
        if !existing.isEmpty {
            // Skip aller Profile-Zeilen — der CSV-Export enthielt nur eine.
            return (0, reader.rows().count, [])
        }

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

            let p = UserBodyProfile(
                birthDate: birthDate,
                heightCm: height,
                profile: profileEnum,
                goalWeightKg: row.double("goal_weight_kg"),
                environment: envEnum
            )
            p.firstName = row.optionalString("first_name")
            p.coachingToneRaw = row.optionalString("coaching_tone") ?? CoachingTone.analytical.rawValue
            p.trainingGoalRaw = row.optionalString("training_goal") ?? TrainingGoal.hybrid.rawValue
            p.equipmentPreferencesRaw = splitMulti(row["equipment_preferences"])
            let dashboardRaw = splitMulti(row["dashboard_widgets"])
            if !dashboardRaw.isEmpty { p.activeDashboardWidgetsRaw = dashboardRaw }
            let heroRaw = splitMulti(row["hero_metric_slots"])
            if !heroRaw.isEmpty { p.heroMetricSlotsRaw = heroRaw }

            context.insert(p)
            imported += 1
        }
        return (imported, 0, errors)
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
                // Wichtig: importierte Pläne kommen IMMER inaktiv rein. Der
                // User soll bewusst entscheiden, welcher Plan jetzt sein
                // aktiver ist — sonst überschreibt der Import ggf. den
                // gerade laufenden Plan.
                isActive: false,
                targetEnvironment: env,
                isTemplate: row.bool("is_template") ?? false,
                localizationKey: row.optionalString("localization_key")
            )
            if let override = row.double("progression_target_rir_override") {
                plan.progressionTargetRIROverride = Float(override)
            }
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
            guard let plan = idMap[planID] as? TrainingPlan else {
                // Ohne Plan kein Day — diese Zeile bezieht sich auf einen
                // Plan, den wir nicht importiert haben (System-Plan o.ä.).
                errors.append(.init(line: row.lineNumber, reason: "unknown plan_id: \(planID)"))
                continue
            }
            let name = row.optionalString("name") ?? ""
            guard !name.isEmpty else {
                errors.append(.init(line: row.lineNumber, reason: "missing name"))
                continue
            }
            let type = DayType(rawValue: row["type"]) ?? .custom
            let intensity = DayIntensity(rawValue: row["next_intensity"]) ?? .normal

            let day = TrainingDay(
                name: name,
                customName: row.optionalString("custom_name"),
                weekday: row.int("weekday") ?? 1,
                type: type,
                nextIntensity: intensity,
                plan: plan,
                localizationKey: row.optionalString("localization_key")
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
                dayName: row.optionalString("day_name_snapshot")
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

        for row in reader.rows() {
            let exportID = row["id"]
            let dayID = row["day_id"]
            guard let day = idMap[dayID] as? TrainingDay else {
                errors.append(.init(line: row.lineNumber, reason: "unknown day_id: \(dayID)"))
                continue
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
            context.insert(e)
            if !exportID.isEmpty { idMap[exportID] = e }
            imported += 1
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

        // Dedup-Strategie für Logs: session.startTime + setIndex + nameSnapshot.
        // Wir bauen den Index aus den BESTEHENDEN Logs (vor diesem Import-Lauf).
        // Die in diesem Lauf neu eingefügten Sessions haben per Definition
        // keine bestehenden Logs, also können wir nicht-naiv ohne Konflikt
        // einfügen.
        let existing = try context.fetch(FetchDescriptor<ExerciseLog>())
        var dupSet = Set<String>()
        for l in existing {
            dupSet.insert(Self.logKey(
                sessionStart: l.session?.startTime,
                setIndex: l.setIndex,
                nameSnapshot: l.exerciseNameSnapshot
            ))
        }

        var errors: [RowError] = []
        var imported = 0
        var skipped  = 0

        for row in reader.rows() {
            let sessionID = row["session_id"]
            guard let session = idMap[sessionID] as? WorkoutSession else {
                errors.append(.init(line: row.lineNumber, reason: "unknown session_id: \(sessionID)"))
                continue
            }
            guard let date = row.date("date_utc") else {
                errors.append(.init(line: row.lineNumber, reason: "missing date_utc"))
                continue
            }
            let setIndex = row.int("set_index") ?? 0
            let nameSnap = row.optionalString("exercise_name_snapshot")
            let dupKey = Self.logKey(
                sessionStart: session.startTime,
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

    private static func logKey(sessionStart: Date?, setIndex: Int, nameSnapshot: String?) -> String {
        let s = sessionStart.map { Int($0.timeIntervalSince1970) } ?? -1
        let n = nameSnapshot ?? ""
        return "\(s)|\(setIndex)|\(n)"
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
