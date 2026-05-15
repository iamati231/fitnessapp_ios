#if canImport(SwiftData)
import Foundation
import SwiftData

/// Single source of truth for the SwiftData schema. Update this list whenever a
/// new `@Model` class lands in `Sources/FitnessAppData/` — the App-Target's entry
/// point reads it via `.modelContainer(for: AppSchema.types)` and never needs to
/// list models manually.
///
/// Use from the App entry point:
///
/// ```swift
/// import SwiftUI
/// import FitnessAppUI
/// import FitnessAppData
///
/// @main
/// struct FitnessApp: App {
///     var body: some Scene {
///         WindowGroup { RootView() }
///             .modelContainer(for: AppSchema.types)
///     }
/// }
/// ```
public enum AppSchema {
    /// All persistent models the app stores. Keep this list current — every new
    /// `@Model` class needs an entry, otherwise SwiftData throws at startup
    /// ("Cannot use this object because it has no model context").
    public static let types: [any PersistentModel.Type] = [
        UserBodyProfile.self,
        BodyMeasurement.self,
        TrainingPlan.self,
        TrainingDay.self,
        Exercise.self,
        ExerciseLog.self,
        WorkoutSession.self,
        ExerciseTemplate.self,
        WaterEntry.self,
        PersonalRecordEntry.self,
        Gear.self
    ]
}
#endif
