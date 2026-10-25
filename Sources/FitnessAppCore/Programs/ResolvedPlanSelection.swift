import Foundation

/// Smart-Onboarding-Epic Phase 5.3/5.4 (PLAN_SUBSTITUTION_ENGINE.md): die
/// EINE konkrete, freigegebene Auswahl fuer ein Template — das Ergebnis, das
/// Vorschau UND Instanziierung gleichermassen verwenden (Erweiterung des
/// bestehenden Phase-4-Datenflusses, siehe `ProgramTemplate.
/// bestEquipmentCheckedVariant`, KEIN zweites, unabhaengiges Auswahlsystem).
public struct ResolvedPlanSelection: Sendable, Equatable {
    public let templateID: String
    /// `nil` = Basis-Variante, sonst eine konkrete `EquipmentVariant`.
    public let variantProfile: EquipmentProfile?
    public let days: [DaySpec]
    public let equipmentStatus: PlanEquipmentStatus
    /// Non-nil AUSSCHLIESSLICH wenn diese Auswahl tatsaechlich eine
    /// erfolgreich geloeste Anpassung verwendet (`isFullyResolved == true`).
    /// Ein gescheiterter Anpassungsversuch landet NIE hier — `days` zeigt in
    /// dem Fall transparent die unveraenderte (nicht passende) Variante.
    public let appliedAdaptation: PlanAdaptationDraft?
    /// Alle versuchten, aber NICHT vollstaendig geloesten Entwuerfe — rein
    /// informativ fuer die UI ("das haben wir versucht, das fehlt noch"),
    /// niemals Grundlage fuer `days`/`equipmentStatus`.
    public let consideredButUnresolvedAdaptations: [PlanAdaptationDraft]
    public let ruleSetVersion: String
    /// Schnappschuss des Profils, gegen das aufgeloest wurde — Grundlage fuer
    /// die Phase-5.4-Veraltungs-Pruefung vor dem Speichern.
    public let equipmentSnapshot: UserEquipmentProfile

    public init(
        templateID: String,
        variantProfile: EquipmentProfile?,
        days: [DaySpec],
        equipmentStatus: PlanEquipmentStatus,
        appliedAdaptation: PlanAdaptationDraft?,
        consideredButUnresolvedAdaptations: [PlanAdaptationDraft],
        ruleSetVersion: String,
        equipmentSnapshot: UserEquipmentProfile
    ) {
        self.templateID = templateID
        self.variantProfile = variantProfile
        self.days = days
        self.equipmentStatus = equipmentStatus
        self.appliedAdaptation = appliedAdaptation
        self.consideredButUnresolvedAdaptations = consideredButUnresolvedAdaptations
        self.ruleSetVersion = ruleSetVersion
        self.equipmentSnapshot = equipmentSnapshot
    }

    public var isAdapted: Bool { appliedAdaptation != nil }

    /// Smart-Onboarding-Epic Phase 5.4: "Before saving, recheck against the
    /// current equipment snapshot and reject stale/incompatible selection."
    /// Ein einfacher Wertevergleich reicht — `UserEquipmentProfile` ist
    /// `Equatable`, jede Aenderung (auch nur eine neu erfasste Stueckzahl)
    /// macht die Auswahl veraltet und verlangt eine frische Freigabe.
    public func isStale(comparedTo currentProfile: UserEquipmentProfile) -> Bool {
        equipmentSnapshot != currentProfile
    }
}

/// Smart-Onboarding-Epic Phase 5.3: loest EIN Template gegen ein echtes
/// `UserEquipmentProfile` auf — zuerst die unveraenderte Phase-4-Logik
/// (vollstaendig passende Variante gewinnt IMMER, ohne jeden
/// Anpassungsversuch), erst danach, wenn nichts passt, eine Substitutions-
/// Bewertung JEDER konkreten Quell-Variante (PLAN_SUBSTITUTION_ENGINE.md
/// Abschnitt 3).
public enum PlanSelectionResolver {
    public static func resolve(
        template: ProgramTemplate,
        profile: UserEquipmentProfile,
        context: SubstitutionContext,
        rules: [ReviewedSubstitutionRule] = ReviewedSubstitutionCatalog.all
    ) -> ResolvedPlanSelection {
        // Equipment-Vielfalt Phase 1 Task 4: slot-bearing templates (Task 3's
        // `slots`/`resolvedSlots(against:)`) resolve HERE FIRST, before the
        // `equipmentVariants`/`ExerciseSubstitutionEngine` path below ever
        // runs. `resolvedSlots` returns `nil` for every template without
        // `slots` (all 17 untouched ones) — those fall through unchanged to
        // the existing logic.
        if let slotResult = template.resolvedSlots(against: profile) {
            let equipmentStatus: PlanEquipmentStatus
            if slotResult.gaps.isEmpty {
                equipmentStatus = .available
            } else if slotResult.gaps.contains(where: {
                if case .missing = $0.reason { return true }
                return false
            }) {
                // Ein definitives Nein gewinnt immer — identische Regel wie
                // `PlanEquipmentChecker.check`.
                equipmentStatus = .unavailable(gaps: slotResult.gaps)
            } else {
                equipmentStatus = .unknown(gaps: slotResult.gaps)
            }

            let appliedAdaptation: PlanAdaptationDraft?
            if slotResult.usedAlternatives.isEmpty {
                appliedAdaptation = nil
            } else {
                appliedAdaptation = PlanAdaptationDraft(
                    sourceVariant: CheckedPlanVariant(profile: nil, days: template.days, equipmentStatus: equipmentStatus),
                    adaptedDays: slotResult.days,
                    replacements: slotResult.usedAlternatives.map { usage in
                        ExerciseReplacement(
                            slot: ExerciseSlot(dayIndex: usage.dayIndex, exerciseIndex: usage.exerciseIndex),
                            originalName: usage.originalName,
                            replacementName: usage.usedName,
                            ruleID: "slot:\(usage.originalName)->\(usage.usedName)",
                            reasonKey: "picker.plan.equipment.slotAlternative"
                        )
                    },
                    // Unresolved slots are reported via `equipmentStatus`'s
                    // gaps instead — never duplicated here (brief Interfaces).
                    unresolved: [],
                    finalEquipmentStatus: equipmentStatus,
                    validatorBlockers: []
                )
            }

            return ResolvedPlanSelection(
                templateID: template.id,
                // Slots resolution isn't tied to a single named `EquipmentProfile`.
                variantProfile: nil, days: slotResult.days,
                equipmentStatus: equipmentStatus, appliedAdaptation: appliedAdaptation,
                // The slots path has exactly one outcome per profile, not
                // multiple competing variant attempts — nothing else was
                // "considered".
                consideredButUnresolvedAdaptations: [],
                ruleSetVersion: ReviewedSubstitutionCatalog.version,
                equipmentSnapshot: profile
            )
        }

        // Punkt 2: eine bereits vollstaendig passende Variante gewinnt immer
        // unveraendert — identisch zur Phase-4-Auswahl, kein Adaptionsversuch
        // noetig oder zulaessig.
        let defaultBest = template.bestEquipmentCheckedVariant(against: profile)
        if defaultBest.equipmentStatus.isAvailable {
            return ResolvedPlanSelection(
                templateID: template.id, variantProfile: defaultBest.profile, days: defaultBest.days,
                equipmentStatus: defaultBest.equipmentStatus, appliedAdaptation: nil,
                consideredButUnresolvedAdaptations: [], ruleSetVersion: ReviewedSubstitutionCatalog.version,
                equipmentSnapshot: profile
            )
        }

        // Punkt 3: JEDE konkrete Quell-Variante einzeln bewerten — nicht nur
        // die von Phase 4 bevorzugte Basis.
        let costByRuleID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0.deviationCost) })
        let attempts: [(variant: CheckedPlanVariant, draft: PlanAdaptationDraft)] = template
            .equipmentCheckedVariants(against: profile)
            .map { variant in (variant, ExerciseSubstitutionEngine.adapt(variant: variant, rules: rules, context: context, profile: profile)) }

        func priority(_ profile: EquipmentProfile?) -> Int { profile?.priority ?? EquipmentProfile.barbellGym.priority }
        func deviationCost(_ draft: PlanAdaptationDraft) -> Int {
            draft.replacements.reduce(0) { $0 + (costByRuleID[$1.ruleID] ?? 1) }
        }

        // Punkt 5: unter den vollstaendig geloesten Entwuerfen zuerst wenige
        // Substitutionen, dann niedrige Abweichungskosten, dann stabile
        // Prioritaet/Reihenfolge — NIE technisch schwerere Ersetzungen
        // bevorzugen (die Regeln selbst lehnen diese bereits ab, siehe
        // Kontext-Gates).
        let resolved = attempts.filter { $0.draft.isFullyResolved }
        if let winner = resolved.min(by: { lhs, rhs in
            if lhs.draft.replacements.count != rhs.draft.replacements.count {
                return lhs.draft.replacements.count < rhs.draft.replacements.count
            }
            let lhsCost = deviationCost(lhs.draft), rhsCost = deviationCost(rhs.draft)
            if lhsCost != rhsCost { return lhsCost < rhsCost }
            return priority(lhs.variant.profile) > priority(rhs.variant.profile)
        }) {
            return ResolvedPlanSelection(
                templateID: template.id, variantProfile: winner.variant.profile, days: winner.draft.adaptedDays,
                equipmentStatus: winner.draft.finalEquipmentStatus, appliedAdaptation: winner.draft,
                consideredButUnresolvedAdaptations: attempts.filter { !$0.draft.isFullyResolved }.map(\.draft),
                ruleSetVersion: ReviewedSubstitutionCatalog.version, equipmentSnapshot: profile
            )
        }

        // Punkt 6/7: nichts vollstaendig geloest -> transparente, UNVERAENDERTE
        // Basis-Variante (identisch zu Phase 4) — NIE eine unvollstaendig
        // adaptierte Variante als "die Auswahl" ausgeben. Versuchte Entwuerfe
        // bleiben als Information erhalten (fuer "das fehlt noch").
        return ResolvedPlanSelection(
            templateID: template.id, variantProfile: defaultBest.profile, days: defaultBest.days,
            equipmentStatus: defaultBest.equipmentStatus, appliedAdaptation: nil,
            consideredButUnresolvedAdaptations: attempts.map(\.draft),
            ruleSetVersion: ReviewedSubstitutionCatalog.version, equipmentSnapshot: profile
        )
    }
}
