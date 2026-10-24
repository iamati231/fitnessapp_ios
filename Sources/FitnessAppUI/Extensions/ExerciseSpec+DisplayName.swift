#if canImport(SwiftUI)
import Foundation
import FitnessAppCore

/// Ticket (Schritt-3-Vorschau, "Dadurch kann ich vor der Fertigstellung nicht
/// beurteilen, ob der Plan sinnvoll ist"): `PlanBuilderView.resultDayRow` and
/// `ProgramTemplatePickerView.dayCard` both need to render a plain-data
/// `ExerciseSpec`'s localized name and its sets/reps/time detail line.
/// Pulled out of `ProgramTemplatePickerView` (where this already existed as
/// three private instance methods) into shared, standalone functions instead
/// of writing a second copy — same reuse this module already does for
/// `timedFormatCircuitLabel`/`timedFormatDisplayName` in
/// `TimedWorkoutPlayerView.swift`.

/// DEL-118: `ExerciseSpec.name` is the German raw string from the template/
/// generator source. If it matches a library entry, resolve via that
/// entry's `localizationKey`; otherwise fall back to the raw string (custom
/// plan strings without a library match).
func localizedExerciseName(_ name: String) -> String {
    if let entry = ExerciseLibraryData.all.first(where: { $0.name == name }),
       let key = entry.localizationKey, !key.isEmpty {
        return String(localized: String.LocalizationValue(key), bundle: .module)
    }
    return name
}

/// README 2.9 Phase 6: `ExerciseSpec` has no own `isTimeBased` field — the
/// `ProgramInstantiator` only derives that via a name lookup against
/// `ExerciseLibraryData` once it materializes the spec. For a preview that
/// still sits before instantiation, do the same lookup here.
private func isTimeBasedSpec(_ name: String) -> Bool {
    ExerciseLibraryData.all.first(where: { $0.name == name })?.isTimeBased ?? false
}

/// DEL-118: format string for the detail line (sets × reps × rest) via
/// xcstrings. A timed day (`dayFormat != nil`) shows only the per-round
/// target instead — sets × reps × rest makes no sense for an AMRAP/EMOM/
/// for-time day (the clock decides the rounds, there is no fixed rest).
func detailLine(for exercise: ExerciseSpec, dayFormat: WorkoutTimeFormat?) -> String {
    if let dayFormat {
        return timedFormatCircuitLabel(
            repsMin: exercise.repsMin, isTimeBased: isTimeBasedSpec(exercise.name),
            sets: exercise.sets, format: dayFormat
        )
    }
    if exercise.isCardio {
        return String(format: String(localized: "workout.detail.cardio", bundle: .module), exercise.restSeconds)
    }
    let repsText = exercise.repsMin == exercise.repsMax
        ? "\(exercise.repsMin)"
        : "\(exercise.repsMin)-\(exercise.repsMax)"
    // Templates/generator specs have no per-ExerciseSpec `isTimeBased` flag —
    // we uniformly use the reps variant. Time-based lifts (e.g. Plank) carry
    // seconds in repsMin/Max.
    let key = exercise.sets == 1 ? "workout.detail.reps.one" : "workout.detail.reps.other"
    let template = String(localized: String.LocalizationValue(key), bundle: .module)
    return template
        .replacingOccurrences(of: "%1$lld", with: "\(exercise.sets)")
        .replacingOccurrences(of: "%2$@",   with: repsText)
        .replacingOccurrences(of: "%3$lld", with: "\(exercise.restSeconds)")
}

/// Device-Bugreport ("Platzoptimierung Schritt 3"): sets × reps WITHOUT the
/// rest clause — `PlanBuilderView.resultDayRow`'s compact strength-exercise
/// row shows the rest time separately as an icon + number instead of
/// repeating the localized "Pause"/"rest"/"mola" word on every one of a
/// day's 5-6 exercises. Same sets/reps wording and `workout.detail.reps.*`
/// pattern as `detailLine` above, just without the trailing `%3$lld` clause.
func setsRepsText(for exercise: ExerciseSpec) -> String {
    let repsText = exercise.repsMin == exercise.repsMax
        ? "\(exercise.repsMin)"
        : "\(exercise.repsMin)-\(exercise.repsMax)"
    let key = exercise.sets == 1 ? "workout.detail.setsReps.one" : "workout.detail.setsReps.other"
    let template = String(localized: String.LocalizationValue(key), bundle: .module)
    return template
        .replacingOccurrences(of: "%1$lld", with: "\(exercise.sets)")
        .replacingOccurrences(of: "%2$@",   with: repsText)
}
#endif
