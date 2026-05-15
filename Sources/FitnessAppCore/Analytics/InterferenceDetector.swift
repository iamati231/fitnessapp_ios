import Foundation

/// DEL-086: Hybrid-Interference-Detection. Wenn der User in den letzten
/// 24 Stunden eine sehr harte Cardio-Einheit absolviert hat, ist sein
/// zentrales Nervensystem vorermuedet — schwere Lower-Body-Compounds am
/// nachsten Tag erhoehen das Verletzungsrisiko. Die App warnt dann.
///
/// Pure-Logik in Core, damit der Algorithmus 1:1 auf Windows-CI testbar
/// bleibt und View-Layer (ActiveWorkoutView) nur den Banner rendert.
public enum InterferenceDetector {

    /// Schwellen-Konfiguration. Kann spaeter via User-Override aus den
    /// Settings ueberschrieben werden; aktuell hardcoded.
    public static let lookbackHours: Double = 24
    public static let veryLongDurationMinutes: Int = 60
    public static let veryLongDistanceKm: Double = 10

    /// Lower-Body-Compound-Lifts, die der App in der heutigen Session ein
    /// Verletzungs-Risiko-Signal triggern. Match per `localizedCaseInsensitive
    /// Contains` auf den Uebungs-Namen — auch Varianten ("Front Squat",
    /// "Sumo-Kreuzheben", "Rumänisches Kreuzheben") schlagen so an.
    public static let heavyLowerBodyKeywords: [String] = [
        "Kniebeuge",
        "Squat",
        "Kreuzheben",
        "Deadlift",
        "Hip Thrust",
        "Ausfallschritte",
        "Lunge",
        "Beinpresse",
        "Leg Press",
        "Bulgar"     // Bulgarische Kniebeuge
    ]

    /// Pure-Funktion: Decide-or-not. Input-Tuples werden vom View-Layer aus
    /// SwiftData-Objekten projiziert (siehe ActiveWorkoutView).
    ///
    /// - Parameter recentCardioSessions: Cardio-Sessions, deren `endTime`
    ///   innerhalb der letzten 24h liegt. Pro Session: (feeling, durationMin,
    ///   distanceKm).
    /// - Parameter plannedExerciseNames: Namen der Uebungen, die in der
    ///   GERADE GESTARTETEN Session geplant sind (`day.activeExercises`).
    /// - Returns: True wenn beide Bedingungen zutreffen — harte Cardio
    ///   gestern UND heavy Lower-Body heute. Caller rendert dann das Banner.
    public static func shouldWarn(
        recentCardioSessions: [(feeling: Int?, durationMin: Int, distanceKm: Double)],
        plannedExerciseNames: [String]
    ) -> Bool {
        // 1) Gab es eine harte Cardio-Einheit in den letzten 24h?
        let hadHardCardio = recentCardioSessions.contains { session in
            let isHardByFeeling = (session.feeling ?? 0) >= 4
            let isHardByDuration = session.durationMin >= veryLongDurationMinutes
            let isHardByDistance = session.distanceKm >= veryLongDistanceKm
            return isHardByFeeling || isHardByDuration || isHardByDistance
        }
        guard hadHardCardio else { return false }

        // 2) Enthaelt die heutige Session schwere Lower-Body-Compounds?
        let hasHeavyLower = plannedExerciseNames.contains { name in
            heavyLowerBodyKeywords.contains { keyword in
                name.localizedCaseInsensitiveContains(keyword)
            }
        }
        return hasHeavyLower
    }
}
