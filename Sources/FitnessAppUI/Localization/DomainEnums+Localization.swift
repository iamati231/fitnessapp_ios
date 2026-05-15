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
#endif
