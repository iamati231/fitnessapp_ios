#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Seeds the `ExerciseTemplate` library with the canonical entries from
/// `ExerciseLibraryData`. Idempotent: skips if any template already exists.
///
/// Called from `RootView.task` on every app launch (cheap — one fetch-count
/// query). New users get the full library on first start; existing users with
/// hand-added custom templates aren't disturbed.
@MainActor
public enum LibrarySeeder {

    /// Returns true if the library was actually seeded (was empty before),
    /// false if it was already populated.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ExerciseTemplate>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return false }

        for spec in ExerciseLibraryData.all {
            let template = ExerciseTemplate(
                name: spec.name,
                equipment: spec.equipment,
                primaryMuscle: spec.primaryMuscle,
                isCustom: false,
                difficultyLevel: spec.difficultyLevel,
                isSystemCompound: spec.isSystemCompound,
                isTimeBased: spec.isTimeBased
            )
            context.insert(template)
        }
        return true
    }
}
#endif
