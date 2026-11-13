extension ExerciseSecondaryMuscles {
    /// Secondary muscles for `key`, with `primary` removed and duplicates dropped,
    /// preserving the original order. Returns [] when no entry exists for `key`.
    public static func filtered(for key: String, excluding primary: MuscleGroup) -> [MuscleGroup] {
        guard let raw = byNormalizedName[key] else { return [] }
        var seen = Set<MuscleGroup>()
        return raw.filter { $0 != primary && seen.insert($0).inserted }
    }
}
