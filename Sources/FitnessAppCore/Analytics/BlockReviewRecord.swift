import Foundation

/// P8 Stufe 3: ein einzelner, bereits abgeschlossener Block-Rückblick,
/// dauerhaft erhalten. Ein späterer Blick auf einen alten Abschluss darf
/// NICHT anhand heutiger Daten zu einem anderen Ergebnis werden — deshalb
/// wird hier der zum Abschluss tatsächlich GEZEIGTE Befund eingefroren,
/// nicht nur ein Zeitstempel.
///
/// **Migrations-Grenze, bewusst nicht aufgelöst:** für einen Plan, dessen
/// einziger Abschluss noch aus der Zeit VOR diesem Feature stammt (reine
/// `TrainingPlan.reviewCompletedAt`/`.reviewDecisionRaw`-Felder, P7), ist
/// der gezeigte Befund selbst nie gespeichert worden. `shownOutcome`/
/// `shownDataGaps` bleiben für einen so migrierten Eintrag `nil` — NIE
/// rückwirkend erfunden (siehe `FourWeekReviewDueStatus.history(for:)`,
/// wo ein solcher Eintrag aus den Alt-Feldern nachgebildet wird).
public struct BlockReviewRecord: Sendable, Equatable, Codable {
    /// Beginn dieses Blocks. `nil` nur, wenn selbst dieser nicht bekannt
    /// war (z. B. ein migrierter Alt-Abschluss ohne `activatedAt` UND ohne
    /// `reviewObservationStartedAt`) — nie nachträglich erfunden.
    public let blockStart: Date?
    /// Zeitpunkt der tatsächlichen, ausdrücklichen Nutzeraktion, mit der
    /// dieser Block abgeschlossen wurde. Markiert zugleich den Beginn des
    /// NÄCHSTEN Blocks (siehe `FourWeekReviewDueStatus.currentBlockStart`).
    public let completedAt: Date
    public let decision: FourWeekReviewDueCalculator.Decision?
    public let shownOutcome: FourWeekReviewOrchestrator.Outcome?
    public let shownDataGaps: [FourWeekReviewOrchestrator.DataGap]?

    public init(
        blockStart: Date?,
        completedAt: Date,
        decision: FourWeekReviewDueCalculator.Decision?,
        shownOutcome: FourWeekReviewOrchestrator.Outcome?,
        shownDataGaps: [FourWeekReviewOrchestrator.DataGap]?
    ) {
        self.blockStart = blockStart
        self.completedAt = completedAt
        self.decision = decision
        self.shownOutcome = shownOutcome
        self.shownDataGaps = shownDataGaps
    }
}
