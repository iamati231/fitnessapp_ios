import Foundation

/// The app's own metadata of a workout written to Apple Health, as plain values.
///
/// Health's detail screen shows custom metadata RAW: the KEY as the label (so the
/// keys are short readable texts, see `HealthWorkoutMetadataLabels`), a number
/// with all its digits (`5.750184774575019`), a text as it is. So the numbers are
/// rounded to what they mean, and the exercises are one readable text. Pure and
/// without HealthKit, so it is tested on every platform.
extension HealthWorkoutDraft {

    /// Longest exercise list in UTF-8 bytes. Conservative on purpose: HealthKit
    /// documents no limit for metadata text.
    public static let maximumExerciseListBytes = 240

    /// All custom entries (not the indoor flag, which is HealthKit's own key),
    /// keyed by the labels:
    /// - sets and volume only when something was logged (a time-format workout
    ///   has no sets — "0 sets" would be noise),
    /// - volume to two decimals, distance to three (metres), pace to two
    ///   (5.750184774575019 → 5.75 min/km, i.e. 5:45 /km),
    /// - the exercise list as one text (`exerciseListText`).
    ///
    /// They are a bonus: if HealthKit rejects the workout with them,
    /// `HealthKitService.saveWorkout` writes it once more without them.
    public var customMetadata: [String: Any] {
        let labels = metadataLabels.sanitized
        var metadata: [String: Any] = [:]
        if let sets = totalSets, sets > 0 {
            metadata[labels.sets] = sets
        }
        if let volume = Self.rounded(totalVolumeKg, decimals: 2) {
            metadata[labels.volumeKg] = volume
        }
        if let km = Self.rounded(totalDistanceKm, decimals: 3) {
            metadata[labels.distanceKm] = km
        }
        if let pace = Self.rounded(averagePaceMinPerKm, decimals: 2) {
            metadata[labels.averagePace] = pace
        }
        if let exerciseList = exerciseListText {
            metadata[labels.exercises] = exerciseList
        }
        return metadata
    }

    /// `value` rounded to `decimals` places; `nil` if missing, not finite, or not
    /// positive after rounding.
    static func rounded(_ value: Double?, decimals: Int) -> Double? {
        guard let value, value.isFinite else { return nil }
        let factor = pow(10.0, Double(decimals))
        let result = (value * factor).rounded() / factor
        return result > 0 ? result : nil
    }

    /// The exercise names as one text: "Bankdrücken, Kniebeuge, Rudern".
    public var exerciseListText: String? {
        Self.exerciseListText(for: exerciseNames)
    }

    /// Names in the given order, blanks and duplicates dropped, joined with ", ".
    /// Longer than `maximumBytes` (UTF-8): whole names as far as they fit, then the
    /// number of the others — "Bankdrücken, Kniebeuge +4". A single name that is
    /// too long is cut with "…". `nil` without any name.
    public static func exerciseListText(
        for names: [String],
        maximumBytes: Int = HealthWorkoutDraft.maximumExerciseListBytes
    ) -> String? {
        var seen = Set<String>()
        var unique: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, seen.insert(name).inserted {
                unique.append(name)
            }
        }
        guard !unique.isEmpty else { return nil }

        let full = unique.joined(separator: ", ")
        if full.utf8.count <= maximumBytes { return full }

        var shown: [String] = []
        for name in unique {
            let omittedAfter = unique.count - shown.count - 1
            let suffix = omittedAfter > 0 ? " +\(omittedAfter)" : ""
            let attempt = (shown + [name]).joined(separator: ", ") + suffix
            if attempt.utf8.count > maximumBytes { break }
            shown.append(name)
        }
        if shown.isEmpty {
            // Not even the first name fits: cut it, and still say how many others
            // there are (if the limit leaves room for that).
            var suffix = unique.count > 1 ? " +\(unique.count - 1)" : ""
            let ellipsis = "…"
            if maximumBytes - ellipsis.utf8.count - suffix.utf8.count < 0 { suffix = "" }
            let room = max(0, maximumBytes - ellipsis.utf8.count - suffix.utf8.count)
            return leadingText(of: unique[0], withinBytes: room) + ellipsis + suffix
        }
        let omitted = unique.count - shown.count
        return shown.joined(separator: ", ") + (omitted > 0 ? " +\(omitted)" : "")
    }

    /// The longest start of `text` within `maximumBytes` UTF-8 bytes, never
    /// splitting a character.
    private static func leadingText(of text: String, withinBytes maximumBytes: Int) -> String {
        var result = ""
        var bytes = 0
        for character in text {
            let size = String(character).utf8.count
            if bytes + size > maximumBytes { break }
            result.append(character)
            bytes += size
        }
        return result
    }
}
