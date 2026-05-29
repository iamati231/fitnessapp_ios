// DEL-173: DataExportService — Phase 1 (Export only).
//
// Sammelt alle User-Daten aus der SwiftData-Datenbank, serialisiert sie in
// eine Reihe RFC-4180-CSV-Files und packt sie in ein ZIP-Archiv, das die
// UI anschließend per Share-Sheet/UIDocumentPicker rausgibt.
//
// **Scope** (Akzeptanzkriterien aus dem Ticket):
//   - profile.csv         — UserBodyProfile (1 row)
//   - measurements.csv    — BodyMeasurement
//   - water_log.csv       — WaterEntry
//   - workouts.csv        — WorkoutSession (mit dayName-Snapshot + gear_id FK)
//   - workout_sets.csv    — ExerciseLog (mit session_id + exercise_id FK + Snapshots)
//   - plans.csv           — TrainingPlan
//   - plan_days.csv       — TrainingDay (mit plan_id FK)
//   - plan_exercises.csv  — Exercise (mit day_id FK)
//   - personal_records.csv — PersonalRecordEntry (mit session_id FK)
//   - gear.csv            — Gear
//   - custom_exercises.csv — ExerciseTemplate where isCustom == true
//   - meta.json           — formatVersion + exportedAt + appVersion
//
// **ID-Strategie**: SwiftData PersistentIdentifier ist nicht stable über
// App-Reinstalls; deshalb generieren wir pro Export-Lauf für jedes Objekt
// eine frische UUID und mappen alle Cross-CSV-FKs darüber. Beim Phase-2
// Importer wird die UUID neu auf SwiftData-IDs aufgelöst.
//
// **Was NICHT exportiert wird**: ExerciseTemplate-Library (System-Daten,
// kommt aus ExerciseLibraryData.swift), CoachingMessage-Cache,
// derived Forecasts/Trends (DSGVO Art. 20 erfordert nur "bereitgestellte"
// und beobachtete Daten — interne Scores sind ableitbar).

#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import ZIPFoundation

/// Snapshot mit ZIP-Bytes + Filename — die UI weiß sonst nichts vom Inhalt.
public struct DataExportBundle: Sendable {
    public let data: Data
    public let suggestedFilename: String
    public let totalRows: Int
}

/// Stateless service. Wird vom UI mit dem aktiven ModelContext aufgerufen
/// und produziert eine `DataExportBundle`. Wirft, wenn das ZIP-Archiv nicht
/// gebaut werden kann (Disk-Full, ZIPFoundation-Fehler etc.).
public enum DataExportService {

    /// Format-Version dieses CSV-Schemas. Bei breaking changes hochzählen
    /// und im Importer (Phase 2) explizit branchen. Patch-Bumps (1.0.x) für
    /// additiv-rückwärtskompatible Feldergänzungen.
    public static let formatVersion = "1.0.0"

    /// Hauptentry — sammelt alles, baut das ZIP, gibt es zurück.
    public static func makeExport(context: ModelContext, appVersion: String = "—") throws -> DataExportBundle {
        // 1) ID-Map. Für jedes SwiftData-Objekt erzeugen wir eine UUID, die
        //    durch alle CSVs hindurch stabil bleibt. Cross-File-Referenzen
        //    nutzen diese UUIDs als FKs. ObjectIdentifier ist innerhalb
        //    eines App-Laufs stabil und Hashable — passt.
        //
        // Hinweis zur Closure-Signatur: kein `for:`-Label, weil die Funktion
        // unten an die Builder als `(AnyObject) -> String`-Closure
        // weitergereicht wird. Closures verlieren ihre Argument-Labels in
        // Swift — der Build kracht sonst mit "extraneous argument label".
        var idMap: [ObjectIdentifier: String] = [:]
        func id(_ object: AnyObject) -> String {
            let oid = ObjectIdentifier(object)
            if let existing = idMap[oid] { return existing }
            let new = UUID().uuidString
            idMap[oid] = new
            return new
        }

        // 2) Fetches. Eine fetch-Phase pro Modell. Reihenfolge: erst die
        //    Roots (Profile/Plan/Gear), dann die abhängigen Children. Das
        //    sorgt dafür, dass die FK-Lookups beim Schreiben bereits eine
        //    UUID im idMap finden.
        let profiles    = try context.fetch(FetchDescriptor<UserBodyProfile>())
        let plans       = try context.fetch(FetchDescriptor<TrainingPlan>())
        let days        = try context.fetch(FetchDescriptor<TrainingDay>())
        let exercises   = try context.fetch(FetchDescriptor<Exercise>())
        let gears       = try context.fetch(FetchDescriptor<Gear>())
        let sessions    = try context.fetch(FetchDescriptor<WorkoutSession>())
        let logs        = try context.fetch(FetchDescriptor<ExerciseLog>())
        let prs         = try context.fetch(FetchDescriptor<PersonalRecordEntry>())
        let measurements = try context.fetch(FetchDescriptor<BodyMeasurement>())
        let waters      = try context.fetch(FetchDescriptor<WaterEntry>())
        // Custom-Exercises: alle ExerciseTemplates mit isCustom=true. Die System-
        // Library wird vom App-Bundle bei jedem Start neu seedet, exportieren wir
        // nicht.
        let allTemplates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        let customExercises = allTemplates.filter { $0.isCustom }

        // 3) CSV-Builds.
        var files: [(name: String, data: Data)] = []

        files.append(("profile.csv",          buildProfile(profiles, id: id)))
        files.append(("measurements.csv",     buildMeasurements(measurements, id: id)))
        files.append(("water_log.csv",        buildWaterLog(waters, id: id)))
        files.append(("plans.csv",            buildPlans(plans, id: id)))
        files.append(("plan_days.csv",        buildDays(days, id: id)))
        files.append(("plan_exercises.csv",   buildExercises(exercises, id: id)))
        files.append(("workouts.csv",         buildWorkouts(sessions, id: id)))
        files.append(("workout_sets.csv",     buildLogs(logs, id: id)))
        files.append(("personal_records.csv", buildPRs(prs, id: id)))
        files.append(("gear.csv",             buildGear(gears, id: id)))
        files.append(("custom_exercises.csv", buildCustomExercises(customExercises, id: id)))

        // meta.json bewusst NEBEN den CSVs (kein _meta in CSV — sauberere
        // Trennung Schema-Metadata vs. Daten).
        let meta = MetaPayload(
            formatVersion: Self.formatVersion,
            exportedAt: CSVWriter.iso8601(Date()),
            appVersion: appVersion,
            files: files.map { $0.name }
        )
        let metaData = try JSONEncoder.prettyEncoder.encode(meta)
        files.append(("meta.json", metaData))

        // 4) ZIP-Erstellung via ZIPFoundation. In-memory Archive: kein
        //    temporäres Disk-File, weniger Cleanup-Pflicht, schneller.
        guard let archive = Archive(accessMode: .create) else {
            throw ExportError.zipCreationFailed
        }
        for entry in files {
            try archive.addEntry(
                with: entry.name,
                type: .file,
                uncompressedSize: Int64(entry.data.count),
                compressionMethod: .deflate,
                provider: { position, size in
                    let start = Int(position)
                    let end = min(start + size, entry.data.count)
                    return entry.data.subdata(in: start..<end)
                }
            )
        }
        guard let zipData = archive.data else {
            throw ExportError.zipCreationFailed
        }

        // 5) Filename. ISO-Datum + Stunde, damit zwei Exporte am selben Tag
        //    unterscheidbar bleiben. Slashes verboten in Files-App.
        let filename = "deltiq-export-\(Self.filenameStamp(Date())).zip"
        let totalRows = profiles.count + measurements.count + waters.count
            + plans.count + days.count + exercises.count
            + sessions.count + logs.count + prs.count
            + gears.count + customExercises.count

        return DataExportBundle(
            data: zipData,
            suggestedFilename: filename,
            totalRows: totalRows
        )
    }

    // MARK: - Filename helper

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func filenameStamp(_ date: Date) -> String {
        filenameFormatter.string(from: date)
    }

    // MARK: - Errors

    public enum ExportError: Error, LocalizedError {
        case zipCreationFailed

        public var errorDescription: String? {
            switch self {
            case .zipCreationFailed: return "Konnte ZIP-Archiv nicht erstellen."
            }
        }
    }

    // MARK: - Meta payload

    private struct MetaPayload: Encodable {
        let formatVersion: String
        let exportedAt: String
        let appVersion: String
        let files: [String]
    }

    // MARK: - CSV builders

    private static func buildProfile(
        _ profiles: [UserBodyProfile],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "birth_date", "height_cm", "profile", "goal_weight_kg",
            "environment", "first_name", "coaching_tone", "training_goal",
            "equipment_preferences", "dashboard_widgets", "hero_metric_slots"
        ])
        for p in profiles {
            w.appendRow([
                id(p),
                CSVWriter.iso8601(p.birthDate),
                CSVWriter.decimal(p.heightCm),
                p.profile.rawValue,
                CSVWriter.decimal(p.goalWeightKg),
                p.environment.rawValue,
                p.firstName ?? "",
                p.coachingToneRaw,
                p.trainingGoalRaw,
                p.equipmentPreferencesRaw.joined(separator: ";"),
                p.activeDashboardWidgetsRaw.joined(separator: ";"),
                p.heroMetricSlotsRaw.joined(separator: ";")
            ])
        }
        return w.data()
    }

    private static func buildMeasurements(
        _ items: [BodyMeasurement],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "date_utc", "age_years_at_measurement", "weight_kg",
            "neck_cm", "waist_cm", "hip_cm", "shoulder_cm", "chest_cm",
            "upper_arm_cm", "thigh_cm", "calf_cm",
            "upper_arm_left_cm", "upper_arm_right_cm",
            "thigh_left_cm", "thigh_right_cm",
            "bmi", "navy_body_fat_pct", "deurenberg_body_fat_pct",
            "selected_body_fat_pct", "fat_free_mass_kg",
            "ffmi", "normalized_ffmi", "bmr"
        ])
        for m in items {
            w.appendRow([
                id(m),
                CSVWriter.iso8601(m.date),
                String(m.ageYearsAtMeasurement),
                CSVWriter.decimal(m.weightKg),
                CSVWriter.decimal(m.neckCm),
                CSVWriter.decimal(m.waistCm),
                CSVWriter.decimal(m.hipCm),
                CSVWriter.decimal(m.shoulderCm),
                CSVWriter.decimal(m.chestCm),
                CSVWriter.decimal(m.upperArmCm),
                CSVWriter.decimal(m.thighCm),
                CSVWriter.decimal(m.calfCm),
                CSVWriter.decimal(m.upperArmLeftCm),
                CSVWriter.decimal(m.upperArmRightCm),
                CSVWriter.decimal(m.thighLeftCm),
                CSVWriter.decimal(m.thighRightCm),
                CSVWriter.decimal(m.bmi),
                CSVWriter.decimal(m.navyBodyFatPct),
                CSVWriter.decimal(m.deurenbergBodyFatPct),
                CSVWriter.decimal(m.selectedBodyFatPct),
                CSVWriter.decimal(m.fatFreeMassKg),
                CSVWriter.decimal(m.ffmi),
                CSVWriter.decimal(m.normalizedFfmi),
                CSVWriter.decimal(m.bmr)
            ])
        }
        return w.data()
    }

    private static func buildWaterLog(
        _ items: [WaterEntry],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: ["id", "date_utc", "amount_ml"])
        for e in items {
            w.appendRow([
                id(e),
                CSVWriter.iso8601(e.date),
                String(e.amountMl)
            ])
        }
        return w.data()
    }

    private static func buildPlans(
        _ items: [TrainingPlan],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "name", "custom_name", "program_type", "description",
            "weeks", "is_active", "target_environment", "is_template",
            "progression_target_rir_override", "localization_key"
        ])
        for p in items {
            w.appendRow([
                id(p),
                p.name,
                p.customName ?? "",
                p.programType,
                p.descriptionText,
                String(p.weeks),
                CSVWriter.bool(p.isActive),
                p.targetEnvironment.rawValue,
                CSVWriter.bool(p.isTemplate),
                p.progressionTargetRIROverride.map { CSVWriter.decimal(Double($0)) } ?? "",
                p.localizationKey ?? ""
            ])
        }
        return w.data()
    }

    private static func buildDays(
        _ items: [TrainingDay],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "plan_id", "name", "custom_name", "weekday",
            "type", "next_intensity", "localization_key"
        ])
        for d in items {
            w.appendRow([
                id(d),
                d.plan.map { id($0) } ?? "",
                d.name,
                d.customName ?? "",
                String(d.weekday),
                d.type.rawValue,
                d.nextIntensity.rawValue,
                d.localizationKey ?? ""
            ])
        }
        return w.data()
    }

    private static func buildExercises(
        _ items: [Exercise],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "day_id", "name", "custom_name",
            "sets", "reps_min", "reps_max", "rest_seconds",
            "notes", "suggested_weight_kg", "order_index",
            "target_rir", "weight_reduced_note",
            "is_cardio", "is_time_based", "is_archived",
            "smart_progression_enabled", "progression_step",
            "is_compound", "target_distance_km", "target_duration_minutes",
            "cardio_equipment", "primary_muscle", "equipment",
            "superset_id", "role",
            "systemic_fatigue_factor", "local_muscle_damage_factor",
            "cns_demand_factor", "axial_load_factor",
            "technical_complexity_factor", "recovery_class"
        ])
        for e in items {
            // Imperatives Append statt großem Array-Literal — Swift's
            // Type-Inference gibt bei 30+ Heterogen-Elementen mit Optionals
            // und ?? auf ("unable to type-check this expression in
            // reasonable time"). Step-by-step ist trivial inferierbar.
            var row: [String] = []
            row.append(id(e))
            row.append(e.day.map { id($0) } ?? "")
            row.append(e.name)
            row.append(e.customName ?? "")
            row.append(String(e.sets))
            row.append(String(e.repsMin))
            row.append(String(e.repsMax))
            row.append(String(e.restSeconds))
            row.append(e.notes ?? "")
            row.append(CSVWriter.decimal(e.suggestedWeight))
            row.append(String(e.orderIndex))
            row.append(CSVWriter.decimal(Double(e.targetRir), fractionDigits: 1))
            row.append(e.weightReducedNote ?? "")
            row.append(CSVWriter.bool(e.isCardio))
            row.append(CSVWriter.bool(e.isTimeBased))
            row.append(CSVWriter.bool(e.isArchived))
            row.append(CSVWriter.bool(e.smartProgressionEnabled))
            row.append(CSVWriter.decimal(e.progressionStep))
            row.append(CSVWriter.bool(e.isCompound))
            row.append(CSVWriter.decimal(e.targetDistanceKm))
            row.append(e.targetDurationMinutes.map(String.init) ?? "")
            row.append(e.cardioEquipmentRaw ?? "")
            row.append(e.primaryMuscleRaw ?? "")
            row.append(e.equipmentRaw ?? "")
            row.append(e.supersetId?.uuidString ?? "")
            row.append(e.roleRaw)
            row.append(CSVWriter.decimal(e.systemicFatigueFactor))
            row.append(CSVWriter.decimal(e.localMuscleDamageFactor))
            row.append(CSVWriter.decimal(e.cnsDemandFactor))
            row.append(CSVWriter.decimal(e.axialLoadFactor))
            row.append(CSVWriter.decimal(e.technicalComplexityFactor))
            row.append(e.recoveryClassRaw)
            w.appendRow(row)
        }
        return w.data()
    }

    private static func buildWorkouts(
        _ items: [WorkoutSession],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "start_time_utc", "end_time_utc", "duration_minutes",
            "exercise_count", "total_sets", "total_volume_kg",
            "notes", "is_completed", "is_rest_day", "is_ad_hoc",
            "day_name_snapshot", "session_feeling",
            "gear_id", "day_id"
        ])
        for s in items {
            w.appendRow([
                id(s),
                CSVWriter.iso8601(s.startTime),
                CSVWriter.iso8601(s.endTime),
                String(s.durationMinutes),
                String(s.exerciseCount),
                String(s.totalSets),
                CSVWriter.decimal(s.totalVolumeKg),
                s.notes ?? "",
                CSVWriter.bool(s.isCompleted),
                CSVWriter.bool(s.isRestDay),
                CSVWriter.bool(s.isAdHoc),
                s.dayName ?? "",
                s.sessionFeeling.map(String.init) ?? "",
                s.gear.map { id($0) } ?? "",
                s.day.map { id($0) } ?? ""
            ])
        }
        return w.data()
    }

    private static func buildLogs(
        _ items: [ExerciseLog],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "session_id", "exercise_id",
            "date_utc", "set_index",
            "weight_kg", "reps", "rpe", "rir", "comment",
            "exercise_name_snapshot",
            "exercise_is_cardio_snapshot", "exercise_is_time_based_snapshot",
            "exercise_cardio_equipment_snapshot",
            "distance_km", "duration_seconds"
        ])
        for l in items {
            // Step-by-step append, gleiches Argument wie bei buildExercises.
            var row: [String] = []
            row.append(id(l))
            row.append(l.session.map { id($0) } ?? "")
            row.append(l.exercise.map { id($0) } ?? "")
            row.append(CSVWriter.iso8601(l.date))
            row.append(String(l.setIndex))
            row.append(CSVWriter.decimal(l.weight))
            row.append(String(l.reps))
            row.append(CSVWriter.decimal(l.rpe, fractionDigits: 1))
            row.append(CSVWriter.decimal(Double(l.rir), fractionDigits: 1))
            row.append(l.comment ?? "")
            row.append(l.exerciseNameSnapshot ?? "")
            row.append(CSVWriter.bool(l.exerciseIsCardioSnapshot))
            row.append(CSVWriter.bool(l.exerciseIsTimeBasedSnapshot))
            row.append(l.exerciseCardioEquipmentSnapshot ?? "")
            row.append(CSVWriter.decimal(l.distanceKm))
            row.append(l.durationSeconds.map(String.init) ?? "")
            w.appendRow(row)
        }
        return w.data()
    }

    private static func buildPRs(
        _ items: [PersonalRecordEntry],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "date_utc", "exercise_name", "kind",
            "value", "previous_value", "weight_kg", "reps",
            "cardio_equipment", "session_id"
        ])
        for p in items {
            w.appendRow([
                id(p),
                CSVWriter.iso8601(p.date),
                p.exerciseName,
                p.kindRaw,
                CSVWriter.decimal(p.value),
                CSVWriter.decimal(p.previousValue),
                CSVWriter.decimal(p.weightKg),
                String(p.reps),
                p.cardioEquipmentRaw ?? "",
                p.session.map { id($0) } ?? ""
            ])
        }
        return w.data()
    }

    private static func buildGear(
        _ items: [Gear],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "name", "type", "max_distance_km",
            "current_distance_km", "is_active", "created_at_utc"
        ])
        for g in items {
            w.appendRow([
                id(g),
                g.name,
                g.type.rawValue,
                CSVWriter.decimal(g.maxDistanceKm),
                CSVWriter.decimal(g.currentDistanceKm),
                CSVWriter.bool(g.isActive),
                CSVWriter.iso8601(g.createdAt)
            ])
        }
        return w.data()
    }

    private static func buildCustomExercises(
        _ items: [ExerciseTemplate],
        id: (AnyObject) -> String
    ) -> Data {
        var w = CSVWriter(headers: [
            "id", "name", "equipment", "primary_muscle",
            "is_custom", "difficulty_level",
            "is_system_compound", "is_time_based", "is_cardio",
            "localization_key", "is_system_provided",
            "systemic_fatigue_factor", "local_muscle_damage_factor",
            "cns_demand_factor", "axial_load_factor",
            "technical_complexity_factor", "recovery_class"
        ])
        for t in items {
            w.appendRow([
                id(t),
                t.name,
                t.equipment.rawValue,
                t.primaryMuscle.rawValue,
                CSVWriter.bool(t.isCustom),
                t.difficultyLevel.rawValue,
                CSVWriter.bool(t.isSystemCompound),
                CSVWriter.bool(t.isTimeBased),
                CSVWriter.bool(t.isCardio),
                t.localizationKey ?? "",
                CSVWriter.bool(t.isSystemProvided),
                CSVWriter.decimal(t.systemicFatigueFactor),
                CSVWriter.decimal(t.localMuscleDamageFactor),
                CSVWriter.decimal(t.cnsDemandFactor),
                CSVWriter.decimal(t.axialLoadFactor),
                CSVWriter.decimal(t.technicalComplexityFactor),
                t.recoveryClassRaw
            ])
        }
        return w.data()
    }
}

// MARK: - Pretty JSON Encoder

private extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

#endif
