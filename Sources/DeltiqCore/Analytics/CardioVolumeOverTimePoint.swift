// AI-Running-Coach Phase 1 (docs/superpowers/plans/
// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 3): ein
// Wochen-Datenpunkt der Lauf-Historie - Vorbild `VolumeWeekPoint`
// (VolumeOverTimeAggregator.swift), um dieselbe lueckenlose, wochenweise
// Darstellung fuer Cardio zu ermoeglichen.

import Foundation

public struct CardioVolumeOverTimePoint: Identifiable, Equatable, Sendable {
    public let weekStart: Date
    /// Nur Einheiten mit `enduranceSportKind == .running`. Nie Cross-Training
    /// oder unbekannte Cardio-Aktivitaet.
    public let runningDistanceKm: Double
    public let runningSessionCount: Int
    /// Laengste einzelne Lauf-Distanz der Woche, `nil` wenn keine Lauf-Einheit
    /// der Woche eine bekannte Distanz traegt (auch wenn `runningSessionCount > 0`).
    public let longestRunKm: Double?
    /// Distanz-gewichteter Durchschnittspace (min/km) ueber alle Lauf-
    /// Einheiten der Woche mit BEIDEN bekannten Werten (Distanz und Dauer).
    /// `nil`, wenn keine einzige Einheit beides traegt.
    public let averagePaceMinutesPerKm: Double?
    /// Immer `nil` in Phase 1 - es existiert keine Herzfrequenz-Datenquelle
    /// pro Lauf (siehe Design-Dokument, "bestaetigte Datenluecken"). Bewusst
    /// als eigenes Feld statt weggelassen, damit eine spaetere Phase die
    /// Spalte nicht neu einfuehren muss.
    public let averageHeartRateBpm: Double?
    /// Bekannte Nicht-Lauf-Ausdauer (`enduranceSportKind == .cycling`).
    public let crossTrainingSessionCount: Int
    /// Cardio-Einheiten mit unbekannter Sportart - echte Mehrdeutigkeit, nie
    /// als Laufen gezaehlt.
    public let ambiguousCardioSessionCount: Int
    /// Krafttrainings-Haeufigkeit dieser Woche (fuer das Lauf/Kraft-
    /// Haeufigkeits-Verhaeltnis, siehe Design-Dokument).
    public let strengthSessionCount: Int

    public var id: Date { weekStart }

    public init(
        weekStart: Date,
        runningDistanceKm: Double,
        runningSessionCount: Int,
        longestRunKm: Double?,
        averagePaceMinutesPerKm: Double?,
        averageHeartRateBpm: Double?,
        crossTrainingSessionCount: Int,
        ambiguousCardioSessionCount: Int,
        strengthSessionCount: Int
    ) {
        self.weekStart = weekStart
        self.runningDistanceKm = runningDistanceKm
        self.runningSessionCount = runningSessionCount
        self.longestRunKm = longestRunKm
        self.averagePaceMinutesPerKm = averagePaceMinutesPerKm
        self.averageHeartRateBpm = averageHeartRateBpm
        self.crossTrainingSessionCount = crossTrainingSessionCount
        self.ambiguousCardioSessionCount = ambiguousCardioSessionCount
        self.strengthSessionCount = strengthSessionCount
    }
}
