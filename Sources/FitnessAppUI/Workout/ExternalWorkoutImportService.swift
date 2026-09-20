#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Importiert Lauf-/Rad-Workouts, die eine ANDERE App (z.B. Adidas Running,
/// Strava) nach Apple Health geschrieben hat, als neue `WorkoutSession` +
/// `ExerciseLog`. Lebt bewusst in `FitnessAppUI`, weil das das einzige Modul
/// ist, das sowohl `FitnessAppHealth` (fuer die HealthKit-Query) als auch
/// `FitnessAppData`/SwiftData (fuer die Persistenz) referenziert —
/// `FitnessAppHealth` selbst kennt SwiftData gar nicht.
///
/// **Kein Anchor-Query, keine Persistenz eines "letzter Sync"-Cursors**: bei
/// den ueblichen Datenmengen einer Einzelnutzer-App ist ein voller Re-Scan
/// bei jedem Sync (App-Start bzw. manueller Button) unproblematisch, und die
/// beiden Dedup-Schluessel unten (siehe `syncExternalWorkouts`) machen ihn
/// idempotent. Ein Anchor-Query waere eine reine Effizienz-Optimierung fuer
/// spaeter, kein Korrektheits-Fix.
@MainActor
public enum ExternalWorkoutImportService {

    /// Holt externe Workouts aus HealthKit, verwirft bereits importierte
    /// (per `healthKitSampleUUID`) und solche, die zeitlich schon mit einer
    /// bestehenden Session ueberlappen (z.B. manuell nacherfasst), und legt
    /// fuer den Rest automatisch eine neue `WorkoutSession` an. Best-effort —
    /// wirft nie, HealthKit-Fehler landen bereits in `healthKit.lastError`.
    public static func syncExternalWorkouts(
        healthKit: HealthKitController,
        context: ModelContext
    ) async {
        let samples = await healthKit.fetchExternalWorkouts(since: nil)
        guard !samples.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false }
        ))) ?? []

        var knownUUIDs = Set(existing.compactMap(\.healthKitSampleUUID))
        // `var`, nicht `let`: muss um jede in DIESEM Sync-Lauf neu eingefuegte
        // Session wachsen. Sonst wuerden zwei verschiedene HK-Samples fuer
        // dasselbe reale Event (z.B. ein Lauf, den sowohl Adidas Running ALS
        // AUCH Strava getrackt und mit unterschiedlicher UUID nach HealthKit
        // geschrieben haben) im selben Durchlauf beide durchrutschen — der
        // Overlap-Check saehe fuer das zweite Sample immer noch nur den
        // DB-Stand von vor dem Sync, nicht die Session aus dem ersten Sample.
        var existingWindows = existing.map { (start: $0.startTime, end: $0.endTime) }

        for sample in samples {
            guard !knownUUIDs.contains(sample.hkUUID) else { continue }
            let overlaps = ExternalWorkoutDedup.overlapsExisting(
                sampleStart: sample.startDate,
                sampleEnd: sample.endDate,
                existingWindows: existingWindows
            )
            guard !overlaps else { continue }
            insertSession(for: sample, in: context)
            knownUUIDs.insert(sample.hkUUID)
            existingWindows.append((start: sample.startDate, end: sample.endDate))
        }

        try? context.save()
    }

    /// Name der Bibliotheks-Vorlage je Aktivitaet — exakt die bestehenden
    /// Cardio-Eintraege aus `ExerciseLibraryData`, keine neuen Namen.
    private static func templateName(for activity: ExternalWorkoutActivityType) -> String {
        switch activity {
        case .running: return "Freier Lauf"
        case .cycling: return "Radfahren (outdoor)"
        }
    }

    private static func insertSession(for sample: ExternalWorkoutSample, in context: ModelContext) {
        let name = templateName(for: sample.activityType)
        let template = try? context.fetch(FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate<ExerciseTemplate> { $0.name == name }
        )).first

        // Freistehende Exercise ohne Tag/Plan — gleiches `day: nil`-Muster
        // wie bei CSV-importierten Sessions (DataImportService.importWorkouts),
        // die ebenfalls ohne day_id auskommen.
        let exercise = Exercise(
            name: name,
            sets: 1,
            orderIndex: 0,
            isCardio: true,
            isCompound: template?.isSystemCompound ?? false,
            systemicFatigueFactor: template?.systemicFatigueFactor ?? 0.35,
            localMuscleDamageFactor: template?.localMuscleDamageFactor ?? 0.35,
            cnsDemandFactor: template?.cnsDemandFactor ?? 0.25,
            axialLoadFactor: template?.axialLoadFactor ?? 0.20,
            technicalComplexityFactor: template?.technicalComplexityFactor ?? 0.30,
            recoveryClass: template?.recoveryClass ?? .medium,
            primaryMuscle: template?.primaryMuscle,
            equipment: template?.equipment,
            day: nil
        )
        context.insert(exercise)

        let durationSeconds = max(0, Int(sample.endDate.timeIntervalSince(sample.startDate).rounded()))
        let session = WorkoutSession(
            startTime: sample.startDate,
            endTime: sample.endDate,
            durationMinutes: durationSeconds / 60,
            exerciseCount: 1,
            totalSets: 1,
            totalVolumeKg: 0.0,
            isCompleted: true,
            isAdHoc: true,
            importSourceName: sample.sourceName,
            healthKitSampleUUID: sample.hkUUID
        )
        context.insert(session)

        let log = ExerciseLog(
            date: sample.startDate,
            setIndex: 0,
            weight: 0,
            reps: 0,
            rir: 0,
            exercise: exercise,
            session: session,
            distanceKm: sample.distanceKm,
            durationSeconds: durationSeconds
        )
        context.insert(log)
    }
}
#endif
