import Foundation

/// Temporary, in-memory draft for a single dictated set.
/// Not a SwiftData model — discarded on cancel, never partially persisted.
/// `nil` means *missing* (not zero) for weight and reps.
public struct VoiceDraftSet: Identifiable, Sendable {
    public var id = UUID()

    /// Recognized exercise name from the library, or nil if not matched.
    public var exerciseName: String?
    /// Multiple library candidates when recognition is ambiguous.
    public var exerciseMatches: [String]
    /// Weight in kg. nil = user did not specify (must be entered before saving).
    public var weightKg: Double?
    /// Repetition count. nil = missing. For time-based exercises use durationSeconds instead.
    public var reps: Int?
    /// Duration in seconds for time-based exercises (isTimeBased == true).
    public var durationSeconds: Int?
    public var isTimeBased: Bool
    /// True when multiple library exercises match and user must disambiguate.
    public var isExerciseAmbiguous: Bool
    /// Original transcription text this draft was parsed from.
    public var rawText: String

    public var hasMissingFields: Bool {
        if exerciseName == nil && !isExerciseAmbiguous { return true }
        if isTimeBased { return durationSeconds == nil }
        return weightKg == nil || reps == nil
    }

    public init(
        exerciseName: String? = nil,
        exerciseMatches: [String] = [],
        weightKg: Double? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        isTimeBased: Bool = false,
        isExerciseAmbiguous: Bool = false,
        rawText: String = ""
    ) {
        self.exerciseName = exerciseName
        self.exerciseMatches = exerciseMatches
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.isTimeBased = isTimeBased
        self.isExerciseAmbiguous = isExerciseAmbiguous
        self.rawText = rawText
    }
}
