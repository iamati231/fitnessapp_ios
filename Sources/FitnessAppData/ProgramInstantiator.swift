#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Materializes a `ProgramTemplate` (pure-data spec from Core) into a fully wired
/// `TrainingPlan` + `TrainingDay` + `Exercise` graph in SwiftData. Called from
/// `ProgramTemplatePickerView` (Picker) und `OnboardingView` (Quiz-Result).
///
/// DEL-088 (Rolling Days): Templates enthalten KEINE festen Wochentage mehr.
/// Statt `daySpec.weekday` haben sie `sequenceIndex` (1...daysPerWeek).
/// Der Caller liefert ein `selectedWeekdays: [Int]`-Array mit den vom User
/// ausgewaehlten Apple-Calendar-Wochentagen (Mo=2, Di=3, ..., So=1). Der
/// Instantiator mappt Sequenz-Index auf Wochentag UND fuellt die nicht-
/// angekreuzten Wochentage mit `DayType.rest` automatisch auf.
///
/// Side-effects:
///   1. Deactivates ALL existing TrainingPlans (`isActive = false`).
///   2. Creates a new active `TrainingPlan` from the template metadata.
///   3. Creates `TrainingDay` rows pro Workout-Tag + Auto-Rest-Days.
///   4. Creates `Exercise` rows fuer jeden `ExerciseSpec`.
@MainActor
public enum ProgramInstantiator {

    /// Default-Wochentag-Auswahl pro `daysPerWeek`-Anzahl. Wird verwendet,
    /// wenn der Caller `selectedWeekdays` nicht explizit setzt — z.B. im
    /// `ProgramTemplatePickerView`-Adopt-Flow, bevor wir den DayPickerSheet
    /// einbauen oder fuer Tests.
    ///
    /// Schema: 1=So, 2=Mo, ..., 7=Sa.
    public static func defaultWeekdays(for daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case 1:  return [2]                        // Mo
        case 2:  return [2, 5]                     // Mo, Do
        case 3:  return [2, 4, 6]                  // Mo, Mi, Fr
        case 4:  return [2, 3, 5, 6]               // Mo, Di, Do, Fr
        case 5:  return [2, 3, 4, 5, 6]            // Mo–Fr
        case 6:  return [2, 3, 4, 5, 6, 7]         // Mo–Sa
        case 7:  return [1, 2, 3, 4, 5, 6, 7]      // jeden Tag
        default: return Array(2...min(7, 1 + daysPerWeek))
        }
    }

    /// DEL-088: Instanziiert einen Plan mit User-gewaehlten Wochentagen.
    /// Wirft assertionFailure (im Debug) wenn `selectedWeekdays.count !=
    /// template.daysPerWeek` — Caller-UI muss vorher validieren, dass die
    /// Anzahl stimmt.
    @discardableResult
    public static func instantiate(
        _ template: ProgramTemplate,
        in context: ModelContext,
        selectedWeekdays: [Int]? = nil
    ) -> TrainingPlan {
        // 1) Deactivate every existing plan.
        let allPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        for plan in allPlans {
            plan.isActive = false
        }

        // 2) Library-Lookups fuer isTimeBased + isCompound.
        let timeBasedNames: Set<String> = Set(
            ExerciseLibraryData.all.filter { $0.isTimeBased }.map { $0.name }
        )
        let compoundNames: Set<String> = Set(
            ExerciseLibraryData.all.filter { $0.isSystemCompound }.map { $0.name }
        )

        // 3) Create new active plan.
        let plan = TrainingPlan(
            name: template.name,
            programType: template.id,
            descriptionText: template.tagline,
            weeks: 12,
            isActive: true,
            targetEnvironment: template.targetEnvironment,
            isTemplate: false
        )
        context.insert(plan)

        // 4) Wochentag-Sequenz aufloesen.
        //    - Caller liefert die User-Auswahl ODER wir fallen auf Defaults.
        //    - Sortieren in chronologischer Mo→So-Reihenfolge, damit
        //      sequenceIndex 1 immer auf den ersten ausgewaehlten Wochentag faellt.
        let rawWeekdays = selectedWeekdays ?? defaultWeekdays(for: template.daysPerWeek)
        let normalized = normalize(weekdays: rawWeekdays, expectedCount: template.daysPerWeek)

        // 5) Workout-Tage mappen (sequenceIndex → realer Wochentag).
        let sortedDays = template.days.sorted { $0.sequenceIndex < $1.sequenceIndex }
        var workoutDayWeekdays = Set<Int>()
        for (idx, daySpec) in sortedDays.enumerated() {
            guard idx < normalized.count else { break }   // Defensive
            let targetWeekday = normalized[idx]
            workoutDayWeekdays.insert(targetWeekday)

            let day = TrainingDay(
                name: daySpec.name,
                weekday: targetWeekday,
                type: daySpec.type,
                plan: plan
            )
            context.insert(day)

            for (orderIndex, exerciseSpec) in daySpec.exercises.enumerated() {
                let exercise = Exercise(
                    name: exerciseSpec.name,
                    sets: exerciseSpec.sets,
                    repsMin: exerciseSpec.repsMin,
                    repsMax: exerciseSpec.repsMax,
                    restSeconds: exerciseSpec.restSeconds,
                    orderIndex: orderIndex,
                    targetRir: exerciseSpec.targetRir,
                    isCardio: exerciseSpec.isCardio,
                    isTimeBased: timeBasedNames.contains(exerciseSpec.name),
                    isCompound: compoundNames.contains(exerciseSpec.name),
                    targetDistanceKm: exerciseSpec.targetDistanceKm,
                    targetDurationMinutes: exerciseSpec.targetDurationMinutes,
                    role: exerciseSpec.role,
                    day: day
                )
                context.insert(exercise)
            }
        }

        // 6) Restliche Wochentage mit Auto-Rest-Days auffuellen, damit der
        //    Plan eine vollstaendige Wochen-Ansicht hat (Plan-Editor, Dashboard-
        //    Day-Card, Calendar-Navigation alle auf 7 Tagen).
        for weekday in 1...7 where !workoutDayWeekdays.contains(weekday) {
            let restDay = TrainingDay(
                name: "Ruhetag",
                weekday: weekday,
                type: .rest,
                plan: plan
            )
            context.insert(restDay)
        }

        return plan
    }

    /// Validiert und normalisiert die User-Auswahl auf exakt
    /// `expectedCount` Wochentage. Bei Mismatch faellt auf Defaults zurueck
    /// (statt zu crashen) — UI sollte vorher validieren.
    private static func normalize(weekdays: [Int], expectedCount: Int) -> [Int] {
        let validRange = 1...7
        let unique = Array(Set(weekdays.filter { validRange.contains($0) })).sorted(by: weekdayLessThan)
        if unique.count == expectedCount {
            return unique
        }
        // Fallback bei UI-Bug: Defaults nehmen.
        return defaultWeekdays(for: expectedCount)
    }

    /// Sortiert Wochentage Mo-first → So-last (Apple-Calendar: 1=So, 2=Mo,
    /// ..., 7=Sa, also Mo<Di<...<Sa<So statt natuerlich 1<2<...<7).
    private static func weekdayLessThan(_ a: Int, _ b: Int) -> Bool {
        // 2 (Mo) bis 7 (Sa) zuerst, dann 1 (So).
        let weightA = a == 1 ? 8 : a
        let weightB = b == 1 ? 8 : b
        return weightA < weightB
    }
}
#endif
