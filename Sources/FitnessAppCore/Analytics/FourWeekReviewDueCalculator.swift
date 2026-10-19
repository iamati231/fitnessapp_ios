import Foundation

/// P7.3/P8 Stufe 3: reine Fälligkeits-Logik für den Block-Rückblick, pro
/// Plan. Kein SwiftData, kein `Date()`/`Calendar.current` im Code-Pfad —
/// wie `PlanParticipationEvaluator`/`DeloadAdvisor`/`FourWeekReviewOrchestrator`.
///
/// **P8 Stufe 3 (docs/P8_STUFE3_BLOCK_RUECKBLICK_PLAN.md) hat die frühere
/// Begrenzung "genau EIN Fälligkeitspunkt" aufgehoben** — spätere Blöcke
/// sind jetzt ein wiederkehrender Zyklus. Was unverändert bleibt:
///   * Der ERSTE Rückblick (P7) bleibt bei `dueIntervalDays` (28 Tage, aus
///     dem Feature-Namen "Vier-Wochen-Rückblick" abgeleitet). Jeder
///     FOLGENDE Block nutzt `subsequentBlockIntervalDays` (42 Tage,
///     Produktentscheidung P8 Stufe 3, keine wissenschaftliche Grenze).
///   * KEIN Snooze/Aufschub: es existiert kein Push/keine Benachrichtigung,
///     nur eine passive Anzeige — nichts zum Wegklicken.
///   * Bloßes Öffnen des Review-Screens ist KEIN Abschluss. Nur eine
///     ausdrückliche Nutzeraktion (`FourWeekReviewDueStatus
///     .completeCurrentBlock`) schließt einen Block ab.
///   * "Plan beibehalten" ist ein vollwertiges Abschlussergebnis, keine
///     Nicht-Entscheidung — siehe `Decision.keptAsIs`.
///
/// **Architektur-Konsequenz:** dieser Typ kennt ab jetzt NUR noch die
/// Fälligkeit des AKTUELL offenen Blocks (`blockStart`/`intervalDays`) —
/// er weiß nichts von vergangenen Abschlüssen mehr (`.completed` ist
/// entfallen, da ein Abschluss nie mehr ein Dauerzustand ist: er eröffnet
/// sofort den nächsten Block mit eigener Fälligkeit). Vergangene Abschlüsse
/// beantwortet stattdessen `FourWeekReviewDueStatus.history(for:)`
/// (FitnessAppData) — getrennt, weil "ist gerade etwas fällig" und "was
/// ist in der Vergangenheit passiert" zwei unabhängige Fragen sind, die in
/// einem wiederkehrenden Zyklus gleichzeitig wahr sein können.
public enum FourWeekReviewDueCalculator {

    public static let dueIntervalDays = 28
    /// P8 Stufe 3, ausdrückliche Produktregel (Auftrag vom 2026-10-19):
    /// "Für nachfolgende Blöcke gelten 42 Tage bis zur Fälligkeit." Keine
    /// wissenschaftliche Trainings- oder Plateau-Schwelle.
    public static let subsequentBlockIntervalDays = 42

    public enum Decision: String, Sendable, Equatable, Codable {
        /// Rückblick abgeschlossen, Plan bewusst unverändert gelassen —
        /// ein vollwertiges Ergebnis, kein Nicht-Ereignis.
        case keptAsIs
        /// Rückblick abgeschlossen, NACHDEM innerhalb dieser Sitzung eine der
        /// angebotenen Aktionen (Deload/Comeback) tatsächlich angewendet wurde.
        case actionTaken
    }

    public enum State: Sendable, Equatable {
        case due(since: Date)
        case notYetDue(dueAt: Date)
        /// Weder ein echter Blockbeginn noch ein Beobachtungs-Fallback ist
        /// bekannt. Der Aufrufer muss EINMALIG, nachvollziehbar einen
        /// Beobachtungsbeginn festlegen (siehe
        /// `TrainingPlan.reviewObservationStartedAt`) — niemals ein
        /// erfundenes historisches Datum annehmen.
        case unknown
    }

    /// - Parameters:
    ///   - blockStart: Beginn des AKTUELL offenen Blocks (erster Block:
    ///     `activatedAt`/`reviewObservationStartedAt`; jeder folgende Block:
    ///     der Kalendertag nach Abschluss des vorigen — siehe
    ///     `FourWeekReviewDueStatus.currentBlockStart(for:)`, wo dieser
    ///     Parameter real berechnet wird). `nil` = unbekannt.
    ///   - intervalDays: `dueIntervalDays` für den ersten Block, sonst
    ///     `subsequentBlockIntervalDays` — vom Aufrufer bestimmt (abhängig
    ///     davon, ob bereits ein Block abgeschlossen wurde), nicht von
    ///     dieser Funktion.
    public static func state(
        blockStart: Date?,
        intervalDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> State {
        guard let anchor = blockStart else {
            return .unknown
        }
        guard let dueAt = calendar.date(byAdding: .day, value: intervalDays, to: anchor) else {
            return .unknown
        }
        if now >= dueAt {
            return .due(since: dueAt)
        }
        return .notYetDue(dueAt: dueAt)
    }
}
