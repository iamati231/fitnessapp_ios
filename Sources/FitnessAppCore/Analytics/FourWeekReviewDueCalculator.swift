import Foundation

/// P7.3: reine Fälligkeits-/Abschluss-Logik für den Vier-Wochen-Rückblick,
/// pro Plan. Kein SwiftData, kein `Date()`/`Calendar.current` im Code-Pfad —
/// wie `PlanParticipationEvaluator`/`DeloadAdvisor`/`FourWeekReviewOrchestrator`.
///
/// Produktentscheidungen dieser Stufe (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md,
/// P7.3 — vom Nutzer ausdrücklich festgelegt, keine erfundenen Fristen):
///   * Genau EIN Fälligkeitspunkt, der ERSTE Rückblick, `dueIntervalDays`
///     (28 Tage, aus dem Feature-Namen "Vier-Wochen-Rückblick" abgeleitet,
///     eine festgelegte PRODUKTREGEL, keine wissenschaftliche Grenze) nach
///     dem Zeitanker. Kein automatischer wiederkehrender Zyklus nach
///     Abschluss — spätere Block-Reviews bleiben P8.
///   * KEIN Snooze/Aufschub in dieser Stufe: es existiert kein Push/keine
///     Benachrichtigung, nur eine passive Anzeige — nichts zum Wegklicken.
///   * Bloßes Öffnen des Review-Screens ist KEIN Abschluss. Nur eine
///     ausdrückliche Nutzeraktion (`FourWeekReviewDueStatus.markCompleted`)
///     setzt `reviewCompletedAt`.
///   * "Plan beibehalten" ist ein vollwertiges Abschlussergebnis, keine
///     Nicht-Entscheidung — siehe `Decision.keptAsIs`.
public enum FourWeekReviewDueCalculator {

    public static let dueIntervalDays = 28

    public enum Decision: String, Sendable, Equatable, Codable {
        /// Rückblick abgeschlossen, Plan bewusst unverändert gelassen —
        /// ein vollwertiges Ergebnis, kein Nicht-Ereignis.
        case keptAsIs
        /// Rückblick abgeschlossen, NACHDEM innerhalb dieser Sitzung eine der
        /// angebotenen Aktionen (Deload/Comeback) tatsächlich angewendet wurde.
        case actionTaken
    }

    public enum State: Sendable, Equatable {
        /// Für diesen Zyklus bereits abgeschlossen — kein erneuter Zyklus in
        /// dieser Stufe (P8-Thema), bleibt dauerhaft `completed`.
        case completed(at: Date, decision: Decision?)
        case due(since: Date)
        case notYetDue(dueAt: Date)
        /// Weder ein echter Aktivierungszeitpunkt noch ein Beobachtungs-
        /// Fallback ist bekannt. Der Aufrufer muss EINMALIG, nachvollziehbar
        /// einen Beobachtungsbeginn festlegen (siehe
        /// `TrainingPlan.reviewObservationStartedAt`) — niemals ein
        /// erfundenes historisches Datum annehmen.
        case unknown

        public var isCompleted: Bool {
            if case .completed = self { return true }
            return false
        }
    }

    public static func state(
        activatedAt: Date?,
        reviewObservationStartedAt: Date?,
        reviewCompletedAt: Date?,
        reviewDecision: Decision?,
        now: Date,
        calendar: Calendar = .current
    ) -> State {
        if let reviewCompletedAt {
            return .completed(at: reviewCompletedAt, decision: reviewDecision)
        }
        guard let anchor = activatedAt ?? reviewObservationStartedAt else {
            return .unknown
        }
        guard let dueAt = calendar.date(byAdding: .day, value: dueIntervalDays, to: anchor) else {
            return .unknown
        }
        if now >= dueAt {
            return .due(since: dueAt)
        }
        return .notYetDue(dueAt: dueAt)
    }
}
