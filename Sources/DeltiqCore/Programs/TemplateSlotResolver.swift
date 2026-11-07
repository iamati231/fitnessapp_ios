import Foundation

/// Ein Slot eines Templates: die kuratierte Standard-Uebung plus eine fest
/// freigegebene Liste gepruefter Alternativen (Prioritaetsreihenfolge).
public struct TemplateSlot: Sendable, Equatable {
    public let defaultExerciseName: String
    public let reviewedAlternatives: [String]
    public let sets: Int
    public let repsMin: Int
    public let repsMax: Int
    public let restSeconds: Int

    public init(
        defaultExerciseName: String,
        reviewedAlternatives: [String],
        sets: Int,
        repsMin: Int,
        repsMax: Int,
        restSeconds: Int
    ) {
        self.defaultExerciseName = defaultExerciseName
        self.reviewedAlternatives = reviewedAlternatives
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
    }
}

public enum SlotResolution: Sendable, Equatable {
    case `default`(ExerciseSpec)
    case alternative(ExerciseSpec, usedName: String)
    /// Caller MUST surface this; never substitute silently.
    case unresolved(PlanEquipmentGapReason)
}

public enum TemplateSlotResolver {
    /// Prueft NUR `defaultExerciseName` und danach `reviewedAlternatives` in
    /// Reihenfolge, je ueber die bestehende `ExerciseRequirement.evaluate`.
    /// Gewinner ist ausschliesslich `.satisfied`: `.unknown` (z.B. Kettlebell
    /// in `gymDefault`) zaehlt nie als erfuellt. Kein Katalog-Suchlauf.
    public static func resolve(slot: TemplateSlot, against profile: UserEquipmentProfile) -> SlotResolution {
        func spec(_ name: String) -> ExerciseSpec {
            ExerciseSpec(name: name, sets: slot.sets, repsMin: slot.repsMin,
                         repsMax: slot.repsMax, restSeconds: slot.restSeconds)
        }

        // OR semantics (candidates are alternatives, one must work): `.missing`
        // only if EVERY candidate is definitively unmet. Any unknown or
        // unannotated candidate keeps the slot `.uncertain`, like `.any` in
        // ExerciseRequirement.evaluate.
        var firstUnmet: [UnmetReason]?
        var firstUnknown: [UnmetReason]?
        var allDefinitelyUnmet = true
        let candidates = [slot.defaultExerciseName] + slot.reviewedAlternatives

        for (index, name) in candidates.enumerated() {
            guard let requirement = ExerciseLibraryData.byName[name]?.equipmentRequirement else {
                allDefinitelyUnmet = false // unannotated: soft signal, same as .unknown
                continue
            }
            switch requirement.evaluate(against: profile) {
            case .satisfied:
                return index == 0 ? .default(spec(name)) : .alternative(spec(name), usedName: name)
            case let .unmet(reasons):
                if firstUnmet == nil { firstUnmet = reasons }
            case let .unknown(reasons):
                allDefinitelyUnmet = false
                if firstUnknown == nil { firstUnknown = reasons }
            }
        }

        if allDefinitelyUnmet, let reasons = firstUnmet { return .unresolved(.missing(reasons)) }
        if let reasons = firstUnknown { return .unresolved(.uncertain(reasons)) }
        return .unresolved(.notAnnotated)
    }
}
