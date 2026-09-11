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
        selectedWeekdays: [Int]? = nil,
        // DEL-170: User-Equipment-Präferenzen. Steuert die Auswahl der
        // `EquipmentVariant`. Leer = keine Variant-Auswahl, Caller bekommt
        // die Standard-Variante (`template.days`).
        userEquipment: Set<Equipment> = []
    ) -> TrainingPlan {
        // 1) Deactivate every existing plan.
        let allPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        for plan in allPlans {
            plan.isActive = false
        }

        // 2) Library-Lookups fuer isTimeBased + isCompound.
        let (timeBasedNames, compoundNames) = libraryLookupNames()

        // DEL-098: Library-Spec-Lookup nach Namen, damit wir die statischen
        // Belastungsfaktoren auf die neu instanziierten Plan-Uebungen ziehen
        // koennen. Uebungen ohne Library-Match (z.B. ungewoehnliche Custom-
        // Namen in Templates) bekommen die Default-Faktoren von `Exercise.init`.
        let specByName = libraryLookupSpecs()

        // 3) Create new active plan.
        // DEL-123: localizationKey aus dem Template-Spec propagieren, damit
        // die SwiftData-Plan-Row beim Display via TrainingPlan.displayName
        // multilingual rendert (statt das deutsche `name`-Feld zu zeigen).
        let plan = TrainingPlan(
            name: template.name,
            programType: template.id,
            descriptionText: template.tagline,
            weeks: 12,
            isActive: true,
            targetEnvironment: template.targetEnvironment,
            isTemplate: false,
            localizationKey: template.localizationKey
        )
        context.insert(plan)

        // 4) Wochentag-Sequenz aufloesen.
        //    - Caller liefert die User-Auswahl ODER wir fallen auf Defaults.
        //    - Sortieren in chronologischer Mo→So-Reihenfolge, damit
        //      sequenceIndex 1 immer auf den ersten ausgewaehlten Wochentag faellt.
        let rawWeekdays = selectedWeekdays ?? defaultWeekdays(for: template.daysPerWeek)
        let normalized = normalize(weekdays: rawWeekdays, expectedCount: template.daysPerWeek)

        // 5) Workout-Tage mappen (sequenceIndex → realer Wochentag).
        // DEL-170: Variant-Auswahl. Wenn das Template Equipment-Variants hat
        // UND der User Equipment-Präferenzen gepflegt hat, wählen wir die
        // beste passende Variante. Sonst: Standard `template.days` (das ist
        // die implizite Barbell-Gym-Variante).
        let resolvedDays: [DaySpec] = {
            guard let variants = template.equipmentVariants, !userEquipment.isEmpty else {
                return template.days
            }
            // Base-Variante (template.days = barbellGym-implizit) bevorzugen,
            // wenn der User Barbell + Dumbbell hat.
            let baseRequires = EquipmentProfile.barbellGym.requiredEquipment
            if baseRequires.isSubset(of: userEquipment) {
                return template.days
            }
            // Sonst die priorisierte beste Variante; Fallback auf base.
            return EquipmentVariant.bestMatch(in: variants, userOwns: userEquipment)?.days
                ?? template.days
        }()
        let sortedDays = resolvedDays.sorted { $0.sequenceIndex < $1.sequenceIndex }
        var workoutDayWeekdays = Set<Int>()
        for (idx, daySpec) in sortedDays.enumerated() {
            guard idx < normalized.count else { break }   // Defensive
            let targetWeekday = normalized[idx]
            workoutDayWeekdays.insert(targetWeekday)

            // DEL-123: localizationKey aus dem DaySpec propagieren — gleiche
            // Idee wie auf Plan-Ebene, nur fuer die Tag-Zelle.
            let day = TrainingDay(
                name: daySpec.name,
                weekday: targetWeekday,
                type: daySpec.type,
                plan: plan,
                localizationKey: daySpec.localizationKey,
                timeFormat: daySpec.timeFormat,
                timeCapMinutes: daySpec.timeCapMinutes,
                circuitRounds: daySpec.circuitRounds,
                circuitRestSeconds: daySpec.circuitRestSeconds,
                circuitMode: daySpec.circuitMode
            )
            context.insert(day)

            for (orderIndex, exerciseSpec) in daySpec.exercises.enumerated() {
                // DEL-098: Wenn der Name in der Library bekannt ist, nehmen
                // wir die handgepflegten Faktoren. Sonst greifen die
                // Defaults aus `Exercise.init` ("moderate Isolation").
                let exercise = makeExercise(
                    from: exerciseSpec,
                    orderIndex: orderIndex,
                    timeBasedNames: timeBasedNames,
                    compoundNames: compoundNames,
                    librarySpecByName: specByName,
                    day: day
                )
                context.insert(exercise)
            }
        }

        // 6) Restliche Wochentage mit Auto-Rest-Days auffuellen, damit der
        //    Plan eine vollstaendige Wochen-Ansicht hat (Plan-Editor, Dashboard-
        //    Day-Card, Calendar-Navigation alle auf 7 Tagen).
        for weekday in 1...7 where !workoutDayWeekdays.contains(weekday) {
            // DEL-123: Auto-Rest-Days bekommen den day.restDay.title-Key,
            // damit sie "Rest Day" / "Dinlenme Günü" rendern und nicht
            // "Ruhetag" durch alle Sprachen schleppen.
            let restDay = TrainingDay(
                name: "Ruhetag",
                weekday: weekday,
                type: .rest,
                plan: plan,
                localizationKey: "day.restDay.title"
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

    /// Materialisiert einen einzelnen `ExerciseSpec` in eine `Exercise`
    /// inklusive DEL-098-Bibliotheks-Anreicherung — extrahiert aus der
    /// Schleife oben, damit `PlanGeneratorInstantiator` (README 2.20 "neu
    /// rechnen") sie ohne Duplikation wiederverwenden kann statt die
    /// Anreicherungs-Logik ein zweites Mal abzutippen (Risiko: die beiden
    /// Kopien laufen bei einer spaeteren DEL-098-Aenderung auseinander).
    /// Nimmt die Lookup-Tabellen als Parameter entgegen statt sie selbst zu
    /// bauen, damit `instantiate`s bestehende Einmal-Berechnung vor der
    /// Tage-Schleife (siehe oben) ihren Performance-Vorteil behaelt.
    public static func makeExercise(
        from spec: ExerciseSpec,
        orderIndex: Int,
        timeBasedNames: Set<String>,
        compoundNames: Set<String>,
        librarySpecByName: [String: ExerciseTemplateSpec],
        day: TrainingDay?
    ) -> Exercise {
        let librarySpec = librarySpecByName[spec.name]
        return Exercise(
            name: spec.name,
            sets: spec.sets,
            repsMin: spec.repsMin,
            repsMax: spec.repsMax,
            restSeconds: spec.restSeconds,
            orderIndex: orderIndex,
            targetRir: spec.targetRir,
            isCardio: spec.isCardio,
            isTimeBased: timeBasedNames.contains(spec.name),
            isCompound: compoundNames.contains(spec.name),
            targetDistanceKm: spec.targetDistanceKm,
            targetDurationMinutes: spec.targetDurationMinutes,
            role: spec.role,
            systemicFatigueFactor: librarySpec?.systemicFatigueFactor ?? 0.35,
            localMuscleDamageFactor: librarySpec?.localMuscleDamageFactor ?? 0.35,
            cnsDemandFactor: librarySpec?.cnsDemandFactor ?? 0.25,
            axialLoadFactor: librarySpec?.axialLoadFactor ?? 0.20,
            technicalComplexityFactor: librarySpec?.technicalComplexityFactor ?? 0.30,
            recoveryClass: librarySpec?.recoveryClass ?? .medium,
            day: day
        )
    }

    /// Baut die beiden Namens-Lookup-Sets, die `makeExercise` braucht -
    /// gleiche Berechnung wie in `instantiate` oben, herausgezogen damit
    /// `PlanGeneratorInstantiator` sie nicht duplizieren muss.
    public static func libraryLookupNames() -> (timeBased: Set<String>, compound: Set<String>) {
        let timeBased = Set(ExerciseLibraryData.all.filter { $0.isTimeBased }.map { $0.name })
        let compound = Set(ExerciseLibraryData.all.filter { $0.isSystemCompound }.map { $0.name })
        return (timeBased, compound)
    }

    /// Namens-Lookup fuer die DEL-098-Faktoren - gleiche Berechnung wie in
    /// `instantiate` oben, herausgezogen fuer `PlanGeneratorInstantiator`.
    public static func libraryLookupSpecs() -> [String: ExerciseTemplateSpec] {
        Dictionary(uniqueKeysWithValues: ExerciseLibraryData.all.map { ($0.name, $0) })
    }
}
#endif
