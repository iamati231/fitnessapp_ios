#if canImport(SwiftData) && canImport(SwiftUI)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Bruecke zwischen den SwiftData-Sessions, der reinen Planungslogik in Core
/// (`HealthWorkoutPlanner`) und der HealthKit-Schicht. Lebt in `FitnessAppUI`,
/// weil nur dieses Modul Data, Core und Health zugleich kennt (`FitnessAppHealth`
/// haengt bewusst nicht von Core ab).
///
/// Gemeinsam genutzt vom Schreiben nach jedem beendeten Training
/// (`pushLive`) und vom Export frueherer Trainings
/// (`WorkoutHealthExportService`) — beide fragen dieselbe Entscheidungsfunktion.
@MainActor
enum HealthWorkoutWriter {

    /// Wert-Snapshot einer Session fuer den Planer. SYNCHRON, ohne Suspension:
    /// nach einem `await` darf kein SwiftData-Modell mehr angefasst werden (die
    /// Session kann inzwischen geloescht sein), daher wird hier alles gelesen,
    /// was spaeter gebraucht wird.
    static func candidate(for session: WorkoutSession) -> HealthWorkoutCandidate {
        let logs: [HealthWorkoutLogInput] = session.loggedSets.map { log in
            let storedName = log.resolvedExerciseName ?? ""
            // Fremdsprachige Snapshots (EN/TR, vor dem Namens-Backfill) auf den
            // DE-Basisnamen zurueckfuehren, sonst fielen sie auf `mixedCardio`.
            let name = ExerciseNameLookup.canonicalBaseName(forStoredName: storedName) ?? storedName
            let isCardio = log.resolvedIsCardio
            return HealthWorkoutLogInput(
                exerciseName: name,
                isCardio: isCardio,
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds,
                equipment: isCardio ? log.resolvedCardioEquipment : .none
            )
        }

        // Zeitformate haben nie Logs; nur der (noch vorhandene) Tag verraet, ob
        // es ein reiner Cardio-Tag war.
        let dayIsAllCardio: Bool? = session.day.map { day in
            let active = day.activeExercises
            let working = active.filter { $0.role == .workingSet }
            let relevant = working.isEmpty ? active : working
            return !relevant.isEmpty && relevant.allSatisfy { $0.isCardio }
        }

        return HealthWorkoutCandidate(
            startTime: session.startTime,
            endTime: session.endTime,
            durationMinutes: session.durationMinutes,
            isCompleted: session.isCompleted,
            isRestDay: session.isRestDay,
            isImported: session.importSourceName != nil || session.healthKitSampleUUID != nil,
            hasExportMarker: session.healthKitExportedAt != nil,
            hasTimeFormat: session.timeFormatSnapshot != nil,
            dayIsAllCardio: dayIsAllCardio,
            logs: logs,
            totalSets: session.totalSets,
            totalVolumeKg: session.totalVolumeKg,
            exactDurationSeconds: session.exactDurationSeconds
        )
    }

    static func kind(for activity: HealthWorkoutActivity) -> HealthWorkoutKind {
        switch activity {
        case .strength:    return .strengthTraining
        case .running:     return .running
        case .walking:     return .walking
        case .cycling:     return .cycling
        case .mixedCardio: return .mixedCardio
        }
    }

    static func draft(from plan: HealthWorkoutPlan) -> HealthWorkoutDraft {
        HealthWorkoutDraft(
            kind: kind(for: plan.activity),
            startDate: plan.start,
            endDate: plan.end,
            isIndoor: plan.isIndoor,
            sampleDistanceKm: plan.distanceKm,
            totalDistanceKm: plan.totalDistanceKm,
            averagePaceMinPerKm: plan.averagePaceMinPerKm,
            totalSets: plan.totalSets,
            totalVolumeKg: plan.totalVolumeKg
        )
    }

    /// Schreibt ein soeben beendetes Training nach Apple Health — gemaess den
    /// Schaltern (Kraft/Cardio), der Klassifikation und der Trainings-
    /// Berechtigung (die der Service beim Schreiben frisch prueft).
    ///
    /// Best-effort und still, wie bisher: Der Aufrufer (Abschluss-Flow,
    /// Navigation zur Zusammenfassung) wird nie blockiert. Der Draft wird
    /// SYNCHRON als Wert gebaut; der `Task` fasst die Session nicht mehr an
    /// (nur ueber den Start-Zeitpunkt wird sie fuer den Marker neu gesucht).
    ///
    /// Nach BESTAETIGTEM Schreiben (`.written`) bekommt die Session den
    /// Export-Marker: Eine spaeter im Verlauf geaenderte Dauer oder Startzeit
    /// fuehrt dann beim Export frueherer Trainings nicht zu einem zweiten Eintrag
    /// in Health (der alte bleibt, wie er live geschrieben wurde). Bei
    /// `.unverified`, Fehlern oder fehlender Berechtigung bleibt der Marker aus —
    /// der Export gleicht solche Trainings mit Health ab.
    static func pushLive(session: WorkoutSession, healthKit: HealthKitController, context: ModelContext) {
        let snapshot = Self.candidate(for: session)
        let prefs = HealthWritePreferences.load()
        let decision = HealthWorkoutPlanner.decide(
            snapshot,
            enabledCategories: prefs.enabledCategories,
            now: Date()
        )
        guard case .write(let plan) = decision else { return }
        let healthDraft = Self.draft(from: plan)
        let startTime = snapshot.startTime
        Task {
            let outcome = try? await healthKit.saveWorkout(healthDraft)
            guard case .written? = outcome else { return }
            WorkoutHealthExportService.markExported(startTime: startTime, in: context)
            try? context.save()
        }
    }
}
#endif
