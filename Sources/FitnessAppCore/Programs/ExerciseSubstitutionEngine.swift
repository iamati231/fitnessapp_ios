import Foundation

/// Smart-Onboarding-Epic Phase 5: eine einzelne vorgenommene Ersetzung,
/// samt Position, damit die UI "Vorher -> Nachher" an der richtigen Stelle
/// zeigen kann.
public struct ExerciseReplacement: Sendable, Equatable {
    public let slot: ExerciseSlot
    public let originalName: String
    public let replacementName: String
    public let ruleID: String
    public let reasonKey: String

    public init(slot: ExerciseSlot, originalName: String, replacementName: String, ruleID: String, reasonKey: String) {
        self.slot = slot
        self.originalName = originalName
        self.replacementName = replacementName
        self.ruleID = ruleID
        self.reasonKey = reasonKey
    }
}

/// Smart-Onboarding-Epic Phase 5: Grund, warum eine einzelne Luecke NICHT
/// automatisch geschlossen wurde — fuer die transparente "ungeklaert"-Liste.
public enum UnresolvedExerciseReason: Sendable, Equatable {
    /// `.uncertain`-Funde (unbekanntes Item, unbekannte Stueckzahl, nicht
    /// annotierte Uebung) werden NIE automatisch ersetzt (Audit-Vorgabe
    /// Abschnitt 1, woertlich) — reine Klaerungs-Hinweise.
    case needsClarification(PlanEquipmentGapReason)
    /// Definitiv fehlend, aber keine freigegebene Regel greift (keine Regel
    /// fuer diese Quelle, oder jede vorhandene Regel hat im Kontext `nil`
    /// geliefert bzw. ihr Ziel ist selbst nicht erfuellt).
    case noApprovedSubstitute
    /// Definitiv fehlend, aber die Uebung liegt in einem global gesperrten
    /// Kontext (Cardio, Warmup/Cooldown, Zeitformat-Tag) — wird nie ersetzt.
    case globallyExcluded
}

public struct UnresolvedExercise: Sendable, Equatable {
    public let slot: ExerciseSlot
    public let exerciseName: String
    public let reason: UnresolvedExerciseReason

    public init(slot: ExerciseSlot, exerciseName: String, reason: UnresolvedExerciseReason) {
        self.slot = slot
        self.exerciseName = exerciseName
        self.reason = reason
    }
}

/// Smart-Onboarding-Epic Phase 5: Ergebnis eines Anpassungsversuchs fuer EINE
/// konkrete Quell-Variante. Ein Entwurf, keine Mutation — nichts hieraus wird
/// gespeichert, bevor der Nutzer explizit zustimmt (Audit-Vorgabe Abschnitt 1,
/// Punkt 20).
public struct PlanAdaptationDraft: Sendable, Equatable {
    public let sourceVariant: CheckedPlanVariant
    public let adaptedDays: [DaySpec]
    public let replacements: [ExerciseReplacement]
    public let unresolved: [UnresolvedExercise]
    public let finalEquipmentStatus: PlanEquipmentStatus
    /// Programm-Ebene-Befunde aus `PlanAdaptationValidator` — nicht-leer
    /// bedeutet IMMER "nicht freigebbar", unabhaengig vom Equipment-Status.
    public let validatorBlockers: [String]

    public init(
        sourceVariant: CheckedPlanVariant,
        adaptedDays: [DaySpec],
        replacements: [ExerciseReplacement],
        unresolved: [UnresolvedExercise],
        finalEquipmentStatus: PlanEquipmentStatus,
        validatorBlockers: [String]
    ) {
        self.sourceVariant = sourceVariant
        self.adaptedDays = adaptedDays
        self.replacements = replacements
        self.unresolved = unresolved
        self.finalEquipmentStatus = finalEquipmentStatus
        self.validatorBlockers = validatorBlockers
    }

    /// EINZIGE Quelle der Wahrheit fuer "darf das zur Freigabe angeboten
    /// werden" — kombiniert bewusst Equipment-Status UND Validator-Blocker in
    /// einer Eigenschaft, damit kein Aufrufer versehentlich nur den
    /// Equipment-Teil prueft und den Programm-Validator vergisst.
    public var isFullyResolved: Bool {
        finalEquipmentStatus.isAvailable && validatorBlockers.isEmpty
    }
}

/// Smart-Onboarding-Epic Phase 5 (PLAN_SUBSTITUTION_ENGINE.md): wendet die
/// freigegebene Regel-Menge deterministisch auf EINE konkrete Quell-Variante
/// an. Keine Regelketten — ein Ersatz wird nie seinerseits erneut geprueft
/// oder ersetzt (Test "Repeated evaluation -> same output, no rule chains").
public enum ExerciseSubstitutionEngine {

    public static func adapt(
        variant: CheckedPlanVariant,
        rules: [ReviewedSubstitutionRule] = ReviewedSubstitutionCatalog.all,
        context: SubstitutionContext,
        profile: UserEquipmentProfile
    ) -> PlanAdaptationDraft {
        let rulesBySource = Dictionary(grouping: rules, by: \.sourceExerciseName)
            .mapValues { $0.sorted { $0.priority < $1.priority } }

        let report = PlanEquipmentChecker.fullReport(days: variant.days, against: profile)

        var replacementBySlot: [ExerciseSlot: (ExerciseSpec, ExerciseReplacement)] = [:]
        var unresolved: [UnresolvedExercise] = []

        for finding in report.missing {
            let day = variant.days[finding.slot.dayIndex]
            let original = day.exercises[finding.slot.exerciseIndex]

            guard isEligibleForSubstitution(exercise: original, day: day) else {
                unresolved.append(UnresolvedExercise(slot: finding.slot, exerciseName: finding.exerciseName, reason: .globallyExcluded))
                continue
            }

            guard let candidates = rulesBySource[finding.exerciseName], !candidates.isEmpty else {
                unresolved.append(UnresolvedExercise(slot: finding.slot, exerciseName: finding.exerciseName, reason: .noApprovedSubstitute))
                continue
            }

            var applied: (ExerciseSpec, ExerciseReplacement)?
            for rule in candidates {
                guard let prescribed = rule.buildPrescription(original, context) else { continue }
                // Die Regel allein reicht nicht — das vorgeschlagene Ziel
                // muss selbst annotiert UND gegen das Profil bestaetigt
                // erfuellt sein, nie nur "existiert im Katalog".
                guard let targetSpec = ExerciseLibraryData.byName[rule.targetExerciseName],
                      let targetRequirement = targetSpec.equipmentRequirement,
                      targetRequirement.evaluate(against: profile).isSatisfied
                else { continue }

                applied = (prescribed, ExerciseReplacement(
                    slot: finding.slot,
                    originalName: original.name,
                    replacementName: rule.targetExerciseName,
                    ruleID: rule.id,
                    reasonKey: rule.reasonKey
                ))
                break
            }

            if let applied {
                replacementBySlot[finding.slot] = applied
            } else {
                unresolved.append(UnresolvedExercise(slot: finding.slot, exerciseName: finding.exerciseName, reason: .noApprovedSubstitute))
            }
        }

        // `uncertain`-Funde werden NIE ersetzt — nur als Klaerungs-Hinweis
        // durchgereicht (Audit-Vorgabe Abschnitt 1).
        for finding in report.uncertain {
            unresolved.append(UnresolvedExercise(slot: finding.slot, exerciseName: finding.exerciseName, reason: .needsClarification(finding.reason)))
        }

        let adaptedDays = applyReplacements(replacementBySlot.mapValues { $0.0 }, to: variant.days)
        let replacements = replacementBySlot.values.map(\.1).sorted {
            ($0.slot.dayIndex, $0.slot.exerciseIndex) < ($1.slot.dayIndex, $1.slot.exerciseIndex)
        }
        let finalStatus = PlanEquipmentChecker.check(days: adaptedDays, against: profile)
        let validatorBlockers = PlanAdaptationValidator.validate(
            originalDays: variant.days, adaptedDays: adaptedDays, context: context
        )

        return PlanAdaptationDraft(
            sourceVariant: variant,
            adaptedDays: adaptedDays,
            replacements: replacements,
            unresolved: unresolved.sorted { ($0.slot.dayIndex, $0.slot.exerciseIndex) < ($1.slot.dayIndex, $1.slot.exerciseIndex) },
            finalEquipmentStatus: finalStatus,
            validatorBlockers: validatorBlockers
        )
    }

    /// Globale Sperren (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 1): Cardio,
    /// Nicht-Working-Set-Rollen und jeder Zeitformat-Tag (AMRAP/EMOM/Auf-Zeit/
    /// Circuit) sind NIE Substitutions-Kandidaten, unabhaengig von jeder
    /// Einzel-Regel.
    private static func isEligibleForSubstitution(exercise: ExerciseSpec, day: DaySpec) -> Bool {
        guard !exercise.isCardio else { return false }
        guard exercise.role == .workingSet else { return false }
        guard day.timeFormat == nil else { return false }
        return true
    }

    private static func applyReplacements(_ replacements: [ExerciseSlot: ExerciseSpec], to days: [DaySpec]) -> [DaySpec] {
        guard !replacements.isEmpty else { return days }
        return days.enumerated().map { dayIndex, day in
            let newExercises = day.exercises.enumerated().map { exerciseIndex, exercise in
                replacements[ExerciseSlot(dayIndex: dayIndex, exerciseIndex: exerciseIndex)] ?? exercise
            }
            // Alle uebrigen DaySpec-Felder unveraendert uebernehmen (Vorgabe:
            // "preserve ... every DaySpec field").
            return DaySpec(
                name: day.name,
                localizationKey: day.localizationKey,
                type: day.type,
                sequenceIndex: day.sequenceIndex,
                exercises: newExercises,
                timeFormat: day.timeFormat,
                timeCapMinutes: day.timeCapMinutes,
                circuitRounds: day.circuitRounds,
                circuitRestSeconds: day.circuitRestSeconds,
                circuitMode: day.circuitMode
            )
        }
    }
}

/// Smart-Onboarding-Epic Phase 5: Programm-Ebene-Pruefungen, UNABHAENGIG von
/// der reinen Equipment-Pruefung. Ein nicht-leeres Ergebnis bedeutet immer
/// "nicht freigebbar" (siehe `PlanAdaptationDraft.isFullyResolved`).
public enum PlanAdaptationValidator {
    public static func validate(originalDays: [DaySpec], adaptedDays: [DaySpec], context: SubstitutionContext) -> [String] {
        var blockers: [String] = []

        for (original, adapted) in zip(originalDays, adaptedDays) {
            // 1) Kollision: ein Ersatz darf keinen NEUEN Namens-Duplikat-Fall
            //    innerhalb desselben Tages erzeugen, der vorher nicht bestand.
            let originalCounts = Dictionary(grouping: original.exercises, by: \.name).mapValues(\.count)
            let adaptedCounts = Dictionary(grouping: adapted.exercises, by: \.name).mapValues(\.count)
            for (name, count) in adaptedCounts where count > 1 && (originalCounts[name] ?? 0) <= 1 {
                blockers.append("validator.duplicateExerciseIntroduced:\(adapted.name):\(name)")
            }

            // 2) Muskelgruppen-Abdeckung: eine Muskelgruppe, die der Tag vorher
            //    abdeckte, darf nach der Anpassung nicht komplett verschwinden.
            let originalMuscles = Set(original.exercises.compactMap { ExerciseLibraryData.byName[$0.name]?.primaryMuscle })
            let adaptedMuscles = Set(adapted.exercises.compactMap { ExerciseLibraryData.byName[$0.name]?.primaryMuscle })
            let lostMuscles = originalMuscles.subtracting(adaptedMuscles)
            if !lostMuscles.isEmpty {
                blockers.append("validator.lostMuscleCoverage:\(adapted.name):\(lostMuscles.map(\.rawValue).sorted().joined(separator: ","))")
            }

            // 3) Satz-Verteilung: Gesamtzahl der Saetze pro Tag darf sich durch
            //    eine Substitution nicht aendern (Defensiv-Netz gegen
            //    zukuenftige Regeln, die Abschnitt 4 verletzen — alle aktuell
            //    freigegebenen Regeln uebernehmen `sets` ohnehin 1:1).
            let originalSets = original.exercises.reduce(0) { $0 + $1.sets }
            let adaptedSets = adapted.exercises.reduce(0) { $0 + $1.sets }
            if originalSets != adaptedSets {
                blockers.append("validator.setDistributionChanged:\(adapted.name)")
            }
        }

        // 4) Kraft-Anker-Rueckfallnetz: ein `isSystemCompound`-Original darf
        //    im Kraft-Ziel-Kontext nie ersetzt worden sein — redundant zu den
        //    Regel-eigenen Gates, aber als unabhaengige zweite Pruefung
        //    bewusst nicht entfernt (Vorgabe: Programm-Validator ist
        //    ZUSAETZLICH zur Regel-Pruefung erforderlich, kein Ersatz dafuer).
        if context.goal == .strength {
            for (original, adapted) in zip(originalDays, adaptedDays) {
                for (originalExercise, adaptedExercise) in zip(original.exercises, adapted.exercises)
                where originalExercise.name != adaptedExercise.name {
                    if ExerciseLibraryData.byName[originalExercise.name]?.isSystemCompound == true {
                        blockers.append("validator.strengthAnchorReplaced:\(adapted.name):\(originalExercise.name)")
                    }
                }
            }
        }

        return blockers
    }
}
