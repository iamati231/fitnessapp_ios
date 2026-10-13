#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// Localized display names for domain enums. Lives in `FitnessAppUI` rather than
/// `FitnessAppCore` because translation strings are a UI concern — the core stays
/// platform-agnostic and dependency-free.
///
/// Each `localizedName` returns a `LocalizedStringResource` that `Text(_:)` can
/// render directly. Keys mirror the enum cases (`equipment.barbell`, etc.) — the
/// catalog file is the single source of truth.

public extension BodyFormulaProfile {
    var localizedName: LocalizedStringResource {
        switch self {
        case .male:   LocalizedStringResource("sex.male",   bundle: .fitnessAppUI)
        case .female: LocalizedStringResource("sex.female", bundle: .fitnessAppUI)
        }
    }
}

public extension EnvironmentType {
    var localizedName: LocalizedStringResource {
        switch self {
        case .gym:         LocalizedStringResource("environment.gym",          bundle: .fitnessAppUI)
        case .homeGym:     LocalizedStringResource("environment.home_gym",     bundle: .fitnessAppUI)
        case .noEquipment: LocalizedStringResource("environment.no_equipment", bundle: .fitnessAppUI)
        }
    }
}

public extension Equipment {
    var localizedName: LocalizedStringResource {
        switch self {
        case .barbell:    LocalizedStringResource("equipment.barbell",    bundle: .fitnessAppUI)
        case .dumbbell:   LocalizedStringResource("equipment.dumbbell",   bundle: .fitnessAppUI)
        case .bodyweight: LocalizedStringResource("equipment.bodyweight", bundle: .fitnessAppUI)
        case .machine:    LocalizedStringResource("equipment.machine",    bundle: .fitnessAppUI)
        case .cable:      LocalizedStringResource("equipment.cable",      bundle: .fitnessAppUI)
        case .kettlebell: LocalizedStringResource("equipment.kettlebell", bundle: .fitnessAppUI)
        case .band:       LocalizedStringResource("equipment.band",       bundle: .fitnessAppUI)
        }
    }
}

public extension CardioEquipment {
    /// DEL-155: lokalisierter Anzeigename fuer den Cardio-Equipment-Picker
    /// im Verlauf + ExerciseEditor.
    var localizedName: LocalizedStringResource {
        switch self {
        case .none:          LocalizedStringResource("cardioEquipment.none",          bundle: .fitnessAppUI)
        case .treadmill:     LocalizedStringResource("cardioEquipment.treadmill",     bundle: .fitnessAppUI)
        case .bikeOutdoor:   LocalizedStringResource("cardioEquipment.bikeOutdoor",   bundle: .fitnessAppUI)
        case .ergometer:     LocalizedStringResource("cardioEquipment.ergometer",     bundle: .fitnessAppUI)
        case .rowingMachine: LocalizedStringResource("cardioEquipment.rowingMachine", bundle: .fitnessAppUI)
        }
    }

    /// DEL-155: SF-Symbol fuer die Picker-Zeile / das Verlaufs-Badge.
    var iconName: String {
        switch self {
        case .none:          return "figure.run"
        case .treadmill:     return "figure.run.treadmill"
        case .bikeOutdoor:   return "bicycle"
        case .ergometer:     return "figure.indoor.cycle"
        case .rowingMachine: return "figure.rower"
        }
    }
}

public extension MuscleGroup {
    var localizedName: LocalizedStringResource {
        switch self {
        case .chest:      LocalizedStringResource("muscle.chest",      bundle: .fitnessAppUI)
        case .back:       LocalizedStringResource("muscle.back",       bundle: .fitnessAppUI)
        case .shoulders:  LocalizedStringResource("muscle.shoulders",  bundle: .fitnessAppUI)
        case .biceps:     LocalizedStringResource("muscle.biceps",     bundle: .fitnessAppUI)
        case .triceps:    LocalizedStringResource("muscle.triceps",    bundle: .fitnessAppUI)
        case .quads:      LocalizedStringResource("muscle.quads",      bundle: .fitnessAppUI)
        case .hamstrings: LocalizedStringResource("muscle.hamstrings", bundle: .fitnessAppUI)
        case .glutes:     LocalizedStringResource("muscle.glutes",     bundle: .fitnessAppUI)
        case .calves:     LocalizedStringResource("muscle.calves",     bundle: .fitnessAppUI)
        case .core:       LocalizedStringResource("muscle.core",       bundle: .fitnessAppUI)
        }
    }
}

public extension DayType {
    var localizedName: LocalizedStringResource {
        switch self {
        case .chest:     LocalizedStringResource("day_type.chest",     bundle: .fitnessAppUI)
        case .back:      LocalizedStringResource("day_type.back",      bundle: .fitnessAppUI)
        case .legs:      LocalizedStringResource("day_type.legs",      bundle: .fitnessAppUI)
        case .shoulders: LocalizedStringResource("day_type.shoulders", bundle: .fitnessAppUI)
        case .arms:      LocalizedStringResource("day_type.arms",      bundle: .fitnessAppUI)
        case .push:      LocalizedStringResource("day_type.push",      bundle: .fitnessAppUI)
        case .pull:      LocalizedStringResource("day_type.pull",      bundle: .fitnessAppUI)
        case .upper:     LocalizedStringResource("day_type.upper",     bundle: .fitnessAppUI)
        case .lower:     LocalizedStringResource("day_type.lower",     bundle: .fitnessAppUI)
        case .fullBody:  LocalizedStringResource("day_type.full_body", bundle: .fitnessAppUI)
        case .rest:      LocalizedStringResource("day_type.rest",      bundle: .fitnessAppUI)
        case .custom:    LocalizedStringResource("day_type.custom",    bundle: .fitnessAppUI)
        // DEL-055: dedizierte Run-/Cardio-Tage fuer Hybrid-Plaene.
        case .cardio:    LocalizedStringResource("day_type.cardio",    bundle: .fitnessAppUI)
        }
    }
}

public extension DayIntensity {
    var localizedName: LocalizedStringResource {
        switch self {
        case .normal: LocalizedStringResource("day_intensity.normal", bundle: .fitnessAppUI)
        case .light:  LocalizedStringResource("day_intensity.light",  bundle: .fitnessAppUI)
        case .heavy:  LocalizedStringResource("day_intensity.heavy",  bundle: .fitnessAppUI)
        }
    }
}

public extension DifficultyLevel {
    var localizedName: LocalizedStringResource {
        switch self {
        case .beginner:     LocalizedStringResource("difficulty.beginner",     bundle: .fitnessAppUI)
        case .intermediate: LocalizedStringResource("difficulty.intermediate", bundle: .fitnessAppUI)
        case .advanced:     LocalizedStringResource("difficulty.advanced",     bundle: .fitnessAppUI)
        }
    }
}

/// README 2.20: beide Enums leben in `FitnessAppCore` OHNE eigenes
/// `Bundle.module` (siehe `PlanGenerator.swift`-Datei-Kommentar) und exposen
/// deshalb nur den rohen `titleKey`/`titleKey`-String statt eines vollen
/// Switches wie oben - hier wird der Key nur noch in eine
/// `LocalizedStringResource` gehuellt, kein zweiter Switch noetig.
public extension TrainingTypeKind {
    var localizedName: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(titleKey), bundle: .fitnessAppUI)
    }
}

public extension PlanLoadLevel {
    var localizedName: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(titleKey), bundle: .fitnessAppUI)
    }
}

// ──────────────────────────────────────────────────────────────────────
// DEL-120: Enum-Localization fuer alle UI-rendered Model-Daten-Enums.
//
// Pattern: das Core-Enum behaelt sein `var label: String { ... }` mit
// deutschen Strings als Legacy + Default-Fallback. Die UI-Layer ruft
// `.localizedName` (LocalizedStringResource) auf und resolved via
// Catalog. Wo das Core-Enum auch ein `blurb` / `description` exposed,
// gibts hier eine zweite Property `localizedBlurb` / `localizedDescription`.
// ──────────────────────────────────────────────────────────────────────

public extension CoachingTone {
    var localizedName: LocalizedStringResource {
        switch self {
        case .analytical: LocalizedStringResource("coaching.tone.analytical.label", bundle: .fitnessAppUI)
        case .motivating: LocalizedStringResource("coaching.tone.motivating.label", bundle: .fitnessAppUI)
        case .strict:     LocalizedStringResource("coaching.tone.strict.label",     bundle: .fitnessAppUI)
        }
    }

    var localizedBlurb: LocalizedStringResource {
        switch self {
        case .analytical: LocalizedStringResource("coaching.tone.analytical.blurb", bundle: .fitnessAppUI)
        case .motivating: LocalizedStringResource("coaching.tone.motivating.blurb", bundle: .fitnessAppUI)
        case .strict:     LocalizedStringResource("coaching.tone.strict.blurb",     bundle: .fitnessAppUI)
        }
    }
}

public extension TrainingGoal {
    var localizedName: LocalizedStringResource {
        switch self {
        case .hypertrophy: LocalizedStringResource("coaching.goal.hypertrophy.label", bundle: .fitnessAppUI)
        case .strength:    LocalizedStringResource("coaching.goal.strength.label",    bundle: .fitnessAppUI)
        case .hybrid:      LocalizedStringResource("coaching.goal.hybrid.label",      bundle: .fitnessAppUI)
        case .weightLoss:  LocalizedStringResource("coaching.goal.weightLoss.label",  bundle: .fitnessAppUI)
        case .fatloss:     LocalizedStringResource("coaching.goal.fatloss.label",     bundle: .fitnessAppUI)
        case .functional:  LocalizedStringResource("coaching.goal.functional.label",  bundle: .fitnessAppUI)
        }
    }

    var localizedBlurb: LocalizedStringResource {
        switch self {
        case .hypertrophy: LocalizedStringResource("coaching.goal.hypertrophy.blurb", bundle: .fitnessAppUI)
        case .strength:    LocalizedStringResource("coaching.goal.strength.blurb",    bundle: .fitnessAppUI)
        case .hybrid:      LocalizedStringResource("coaching.goal.hybrid.blurb",      bundle: .fitnessAppUI)
        case .weightLoss:  LocalizedStringResource("coaching.goal.weightLoss.blurb",  bundle: .fitnessAppUI)
        case .fatloss:     LocalizedStringResource("coaching.goal.fatloss.blurb",     bundle: .fitnessAppUI)
        case .functional:  LocalizedStringResource("coaching.goal.functional.blurb",  bundle: .fitnessAppUI)
        }
    }
}

public extension CardioGoal {
    var localizedName: LocalizedStringResource {
        switch self {
        case .generalFitness: LocalizedStringResource("cardioGoal.generalFitness", bundle: .fitnessAppUI)
        case .fiveK:           LocalizedStringResource("cardioGoal.fiveK",           bundle: .fitnessAppUI)
        case .tenK:            LocalizedStringResource("cardioGoal.tenK",            bundle: .fitnessAppUI)
        case .halfMarathon:    LocalizedStringResource("cardioGoal.halfMarathon",    bundle: .fitnessAppUI)
        case .marathon:        LocalizedStringResource("cardioGoal.marathon",        bundle: .fitnessAppUI)
        }
    }
}

public extension ExperienceLevel {
    var localizedName: LocalizedStringResource {
        switch self {
        case .beginner:     LocalizedStringResource("experience.beginner",     bundle: .fitnessAppUI)
        case .intermediate: LocalizedStringResource("experience.intermediate", bundle: .fitnessAppUI)
        case .advanced:     LocalizedStringResource("experience.advanced",     bundle: .fitnessAppUI)
        }
    }
}

public extension SessionFeeling {
    var localizedName: LocalizedStringResource {
        switch self {
        case .great:     LocalizedStringResource("feeling.great",     bundle: .fitnessAppUI)
        case .good:      LocalizedStringResource("feeling.good",      bundle: .fitnessAppUI)
        case .okay:      LocalizedStringResource("feeling.okay",      bundle: .fitnessAppUI)
        case .hard:      LocalizedStringResource("feeling.hard",      bundle: .fitnessAppUI)
        case .destroyed: LocalizedStringResource("feeling.destroyed", bundle: .fitnessAppUI)
        }
    }
}
#endif
