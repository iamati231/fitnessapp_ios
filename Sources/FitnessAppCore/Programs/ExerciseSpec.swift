import Foundation

/// Pure-data spec for one planned exercise inside a `ProgramTemplate`. Used to seed
/// `Exercise` rows when a user picks a template from the library.
///
/// Lives in Core (no SwiftData dependency) so the templates are testable on every
/// platform — only `ProgramInstantiator` (in `FitnessAppData`) materializes them
/// into actual `Exercise` @Model rows.
public struct ExerciseSpec: Sendable, Hashable {
    public let name: String
    public let sets: Int
    public let repsMin: Int
    public let repsMax: Int
    public let restSeconds: Int
    public let targetRir: Float
    /// True for cardio finishers — UI shows duration/level fields instead of kg/reps.
    public let isCardio: Bool

    public init(
        name: String,
        sets: Int,
        repsMin: Int,
        repsMax: Int,
        restSeconds: Int = 90,
        targetRir: Float = 2.0,
        isCardio: Bool = false
    ) {
        self.name = name
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.targetRir = targetRir
        self.isCardio = isCardio
    }
}
