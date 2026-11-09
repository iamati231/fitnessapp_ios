import Foundation

/// AI-Running-Coach Phase 2, Work Package 2A: eine Kalenderwoche, Lauf- UND
/// Krafttrainingsbelastung NEBENEINANDER - niemals zu einer gemeinsamen
/// Zahl zusammengefasst (Ticket Teil C: "Diese Bereiche duerfen nicht durch
/// eine beliebige gemeinsame Zahl ersetzt werden").
///
/// `running` ist das UNVERAENDERTE Phase-1-Ergebnis (`CardioVolumeOverTimePoint`,
/// inkl. Cross-Training-/Unbekannt-Zaehlern) - eingebettet statt Feld fuer
/// Feld kopiert, damit die Wiederverwendung von
/// `CardioVolumeOverTimeAggregator` auch am Typ selbst sichtbar bleibt.
public struct TrainingLoadWeek: Sendable, Equatable, Identifiable {
    public let weekStart: Date
    public let running: CardioVolumeOverTimePoint

    // MARK: - Krafttrainingsbelastung (neu in Phase 2)
    public let strengthSessionCount: Int
    public let strengthSetCount: Int
    public let strengthVolumeKg: Double

    public var id: Date { weekStart }

    public init(
        weekStart: Date,
        running: CardioVolumeOverTimePoint,
        strengthSessionCount: Int,
        strengthSetCount: Int,
        strengthVolumeKg: Double
    ) {
        self.weekStart = weekStart
        self.running = running
        self.strengthSessionCount = strengthSessionCount
        self.strengthSetCount = strengthSetCount
        self.strengthVolumeKg = strengthVolumeKg
    }
}
