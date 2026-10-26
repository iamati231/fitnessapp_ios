import Foundation

/// Pure-data spec for a complete training program (e.g., Push-Pull-Legs, 5×5).
/// Materialized into a `TrainingPlan` + `TrainingDay`s + `Exercise`s by
/// `ProgramInstantiator` in `FitnessAppData`.
public struct ProgramTemplate: Sendable, Hashable, Identifiable {
    /// Stable string identifier — persisted on `TrainingPlan.programType` so we can
    /// detect "user's plan was originally a PPL template" later for re-recommendations.
    public let id: String
    public let name: String
    public let tagline: String
    public let descriptionText: String
    public let focus: String
    public let daysPerWeek: Int
    /// DEL-088: `days` enthaelt jetzt NUR Trainings-Tage, sortiert nach
    /// `sequenceIndex` (1...daysPerWeek). Rest-Tage werden beim Instanziieren
    /// vom `ProgramInstantiator` automatisch in die restlichen Wochentage
    /// gefuellt — der User waehlt seine Wochentage erst beim Adopt.
    public let days: [DaySpec]
    public let targetEnvironment: EnvironmentType
    /// SF Symbol name displayed as the program tile icon. Picked per program;
    /// can be replaced with a real custom-asset on the iOS side later.
    public let iconSystemName: String

    /// DEL-090: Quiz-Matchmaker-Tags. Mehrwertig, damit ein Plan auf mehrere
    /// Antwortkombinationen passen kann (z.B. PPL ist sowohl Hypertrophie als
    /// auch Kraft; Hybrid passt Beginner UND Intermediate).
    public let targetExperience: [ExperienceLevel]
    /// Smart-Onboarding-Epic: vormals `[GoalType]` (eigenes Quiz-Enum) — auf
    /// `TrainingGoal` konsolidiert, damit Quiz-Ziel und Coaching-Ziel dieselbe
    /// Achse sind (kein verlustbehafteter Mapper mehr dazwischen).
    public let targetGoals: [TrainingGoal]

    /// DEL-113: i18n-Lookup-Key fuer den Plan-Namen (Format
    /// `plan.template.<id>`). Optional — wenn gesetzt, rendert die UI den
    /// Plan-Namen aus dem Localizable.xcstrings statt aus dem hardcoded
    /// deutschen `name`. Der `ProgramInstantiator` propagiert weiterhin den
    /// deutschen `name` auf `TrainingPlan.name`, weil die Name-basierte
    /// Lookup-Logik (ExerciseLibraryData.alternatives, PlanEnvironmentMigrator)
    /// auf den deutschen Strings beruht.
    public let localizationKey: String?

    /// DEL-116: i18n-Lookup-Keys fuer die drei Plan-Metadaten-Felder.
    /// Namespace: `plan.template.<id>.tagline / .focus / .description`.
    /// Wenn nil/leer, faellt der DisplayName-Helper auf das jeweilige rohe
    /// DE-Feld (`tagline` / `focus` / `descriptionText`) zurueck — User-
    /// erstellte Custom-Templates sehen also ihren handgetippten Text.
    public let taglineKey: String?
    public let focusKey: String?
    public let descriptionKey: String?

    /// DEL-170: Optionale Equipment-spezifische Varianten des Templates.
    /// `nil` = einzige Variante ist `days` (Standard, Backward-Compat). Wenn
    /// gesetzt, wählt der `ProgramInstantiator` anhand der
    /// `UserBodyProfile.equipmentPreferences` die passende `EquipmentVariant`;
    /// fällt auf `days` zurück, wenn keine kompatibel ist.
    public let equipmentVariants: [EquipmentVariant]?

    /// Equipment-Vielfalt Phase 1 Task 3: slot-based equipment resolution,
    /// additive and independent of `equipmentVariants`. Index-aligned with
    /// `days` — `slots[i]` is the ordered list of `TemplateSlot`s for
    /// `days[i]`, or an empty array for a day with no equipment-dependent
    /// exercises (e.g. a cardio day). `nil` for every template that doesn't
    /// use the slot model (all 17 others) — `resolvedSlots(against:)`
    /// returns `nil` in that case too, never a faked result.
    public let slots: [[TemplateSlot]]?

    public init(
        id: String,
        name: String,
        localizationKey: String? = nil,
        tagline: String,
        taglineKey: String? = nil,
        descriptionText: String,
        descriptionKey: String? = nil,
        focus: String,
        focusKey: String? = nil,
        daysPerWeek: Int,
        days: [DaySpec],
        targetEnvironment: EnvironmentType = .gym,
        iconSystemName: String = "figure.strengthtraining.traditional",
        targetExperience: [ExperienceLevel] = [.intermediate],
        targetGoals: [TrainingGoal] = [.hypertrophy],
        equipmentVariants: [EquipmentVariant]? = nil,
        slots: [[TemplateSlot]]? = nil
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.descriptionText = descriptionText
        self.focus = focus
        self.daysPerWeek = daysPerWeek
        self.days = days
        self.targetEnvironment = targetEnvironment
        self.iconSystemName = iconSystemName
        self.targetExperience = targetExperience
        self.targetGoals = targetGoals
        self.localizationKey = localizationKey
        self.taglineKey = taglineKey
        self.focusKey = focusKey
        self.descriptionKey = descriptionKey
        self.equipmentVariants = equipmentVariants
        self.slots = slots
    }

    /// Manuelle `Equatable`/`Hashable`-Konformanz statt Compiler-Synthese:
    /// `TemplateSlot` (Task 1, feste Signatur) ist bewusst nur `Equatable`,
    /// nicht `Hashable` — die Synthese wuerde an `slots: [[TemplateSlot]]?`
    /// scheitern. `slots` ist pro `id` fest einkompiliert (variiert nie
    /// unabhaengig von den uebrigen Feldern), jedes andere Feld bleibt Teil
    /// der Gleichheit/des Hashes wie zuvor.
    public static func == (lhs: ProgramTemplate, rhs: ProgramTemplate) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.tagline == rhs.tagline &&
        lhs.descriptionText == rhs.descriptionText && lhs.focus == rhs.focus &&
        lhs.daysPerWeek == rhs.daysPerWeek && lhs.days == rhs.days &&
        lhs.targetEnvironment == rhs.targetEnvironment && lhs.iconSystemName == rhs.iconSystemName &&
        lhs.targetExperience == rhs.targetExperience && lhs.targetGoals == rhs.targetGoals &&
        lhs.localizationKey == rhs.localizationKey && lhs.taglineKey == rhs.taglineKey &&
        lhs.focusKey == rhs.focusKey && lhs.descriptionKey == rhs.descriptionKey &&
        lhs.equipmentVariants == rhs.equipmentVariants
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(tagline)
        hasher.combine(descriptionText)
        hasher.combine(focus)
        hasher.combine(daysPerWeek)
        hasher.combine(days)
        hasher.combine(targetEnvironment)
        hasher.combine(iconSystemName)
        hasher.combine(targetExperience)
        hasher.combine(targetGoals)
        hasher.combine(localizationKey)
        hasher.combine(taglineKey)
        hasher.combine(focusKey)
        hasher.combine(descriptionKey)
        hasher.combine(equipmentVariants)
    }

    /// PLAN_EQUIPMENT_MATCHING_AUDIT.md Abschnitt 5.4: EINZIGE Quelle für
    /// "welche Tage-Liste passt zum Equipment" — vorher duplizierte
    /// `ProgramInstantiator.instantiate` diese Logik inline, während die
    /// Vorschau (`TemplatePreviewView.orderedDays`) ungeprüft `days` zeigte.
    /// Für die 3 Templates mit `equipmentVariants` (hybrid_beginner/
    /// _balanced/_performance) konnte die angezeigte Vorschau dadurch von
    /// der tatsächlich gespeicherten Variante abweichen. Beide Call-Sites
    /// rufen jetzt diese eine Funktion auf, damit sie nie wieder
    /// auseinanderlaufen können.
    ///
    /// Leeres `userEquipment` oder keine `equipmentVariants` -> immer die
    /// Basis-Variante (`days`). Erfüllt der Nutzer die `barbellGym`-
    /// Basis-Anforderung, bleibt es ebenfalls bei `days`. Sonst die
    /// prioritätshöchste passende Variante, oder `days` als letzter
    /// Rückfall, falls keine passt.
    public func resolvedDays(forUserEquipment userEquipment: Set<Equipment>) -> [DaySpec] {
        guard let variants = equipmentVariants, !userEquipment.isEmpty else { return days }
        let baseRequires = EquipmentProfile.barbellGym.requiredEquipment
        if baseRequires.isSubset(of: userEquipment) { return days }
        return EquipmentVariant.bestMatch(in: variants, userOwns: userEquipment)?.days ?? days
    }
}

/// Equipment-Vielfalt Phase 1 Task 3: EIN Slot, der statt seiner kuratierten
/// `TemplateSlot.defaultExerciseName` eine `reviewedAlternatives`-Uebung
/// verwendet hat — Position (`dayIndex`/`exerciseIndex`, 0-basiert wie
/// `ExerciseSlot`) plus beide Namen, fuer Transparenz/Debugging.
public struct SlotAlternativeUsage: Sendable, Equatable {
    public let dayIndex: Int
    public let exerciseIndex: Int
    public let originalName: String
    public let usedName: String

    public init(dayIndex: Int, exerciseIndex: Int, originalName: String, usedName: String) {
        self.dayIndex = dayIndex
        self.exerciseIndex = exerciseIndex
        self.originalName = originalName
        self.usedName = usedName
    }
}

/// Equipment-Vielfalt Phase 1 Task 3: Ergebnis von `resolvedSlots(against:)`.
/// `days` ist IMMER vollstaendig befuellt — ein `.unresolved`-Slot behaelt
/// dafuer schlicht seine unveraenderte `defaultExerciseName` (nie
/// weggelassen, nie stillschweigend durch irgendetwas Erfundenes ersetzt);
/// `gaps` macht diesen Fall fuer den Caller sichtbar (Task 4 wandelt das in
/// die bestehende `PlanEquipmentStatus`-Vokabular um).
public struct SlotResolutionResult: Sendable, Equatable {
    public let days: [DaySpec]
    public let gaps: [PlanEquipmentGap]
    public let usedAlternatives: [SlotAlternativeUsage]

    public init(days: [DaySpec], gaps: [PlanEquipmentGap], usedAlternatives: [SlotAlternativeUsage]) {
        self.days = days
        self.gaps = gaps
        self.usedAlternatives = usedAlternatives
    }
}

public extension ProgramTemplate {
    /// Equipment-Vielfalt Phase 1 Task 3: loest JEDEN Slot in `slots` gegen
    /// `profile` auf (`TemplateSlotResolver.resolve`, Task 1 — nie ein
    /// offener Katalog-Suchlauf) und baut daraus eine vollstaendige, neue
    /// `[DaySpec]`-Liste. `nil` fuer jedes Template ohne `slots` (alle 17
    /// anderen) — rein, Task-4-intern; UI-Status-Mapping ist NICHT Teil
    /// dieser Funktion (siehe Task 4).
    func resolvedSlots(against profile: UserEquipmentProfile) -> SlotResolutionResult? {
        guard let slots else { return nil }

        var resolvedDays: [DaySpec] = []
        var gaps: [PlanEquipmentGap] = []
        var usedAlternatives: [SlotAlternativeUsage] = []

        for (dayIndex, day) in days.enumerated() {
            let daySlots = dayIndex < slots.count ? slots[dayIndex] : []
            guard !daySlots.isEmpty else {
                resolvedDays.append(day)
                continue
            }

            var exercises: [ExerciseSpec] = []
            exercises.reserveCapacity(daySlots.count)

            for (exerciseIndex, slot) in daySlots.enumerated() {
                switch TemplateSlotResolver.resolve(slot: slot, against: profile) {
                case let .default(spec):
                    exercises.append(spec)
                case let .alternative(spec, usedName):
                    exercises.append(spec)
                    usedAlternatives.append(SlotAlternativeUsage(
                        dayIndex: dayIndex, exerciseIndex: exerciseIndex,
                        originalName: slot.defaultExerciseName, usedName: usedName
                    ))
                case let .unresolved(reason):
                    // Caller MUST see this: never silently substitute. The
                    // exercise keeps its unchanged default identity; the gap
                    // reason is the resolver's own OR-aggregate across
                    // default + alternatives (never recomputed from the
                    // default exercise alone — that would reintroduce false
                    // `.missing` certainty when an alternative is merely
                    // `.uncertain`).
                    exercises.append(ExerciseSpec(
                        name: slot.defaultExerciseName, sets: slot.sets,
                        repsMin: slot.repsMin, repsMax: slot.repsMax, restSeconds: slot.restSeconds
                    ))
                    gaps.append(PlanEquipmentGap(
                        exerciseName: slot.defaultExerciseName,
                        reason: reason
                    ))
                }
            }

            resolvedDays.append(DaySpec(
                name: day.name, localizationKey: day.localizationKey, type: day.type,
                sequenceIndex: day.sequenceIndex, exercises: exercises,
                timeFormat: day.timeFormat, timeCapMinutes: day.timeCapMinutes,
                circuitRounds: day.circuitRounds, circuitRestSeconds: day.circuitRestSeconds,
                circuitMode: day.circuitMode,
                enduranceWarmupDurationSeconds: day.enduranceWarmupDurationSeconds,
                enduranceCooldownDurationSeconds: day.enduranceCooldownDurationSeconds,
                enduranceIntervalRounds: day.enduranceIntervalRounds,
                enduranceWorkDurationSeconds: day.enduranceWorkDurationSeconds,
                enduranceWorkDistanceKm: day.enduranceWorkDistanceKm,
                enduranceRestDurationSeconds: day.enduranceRestDurationSeconds,
                enduranceSportKind: day.enduranceSportKind
            ))
        }

        return SlotResolutionResult(days: resolvedDays, gaps: gaps, usedAlternatives: usedAlternatives)
    }
}
