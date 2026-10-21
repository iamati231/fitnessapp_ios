import Foundation

/// Reine Zustandsmaschine fuer einen pausierbaren Timer (als Stoppuhr oder,
/// von der UI interpretiert, als Countdown), der App-Hintergrundwechsel
/// korrekt uebersteht.
///
/// Verankert an einem `Date` statt einem akkumulierenden, per Timer-Tick
/// dekrementierten Zaehler — dieselbe Konvention wie `RestTimerBar` und
/// `TimedWorkoutPlayerView` in `FitnessAppUI` (deren Kommentare zu
/// Hintergrund-Drift gelten hier identisch). Ein `@State`, das per
/// `Timer.publish` jede Sekunde +/-1 rechnet, verliert Zeit, waehrend die
/// App im Hintergrund ist (das System pausiert Timer dort); ein Anker-Datum
/// plus `Date()`-Differenz bei jedem Redraw ist dagegen immun.
///
/// Dieselbe Instanz deckt sowohl den 30-Sekunden-Countdown (Stuhlkniebeuge:
/// UI zeigt `max(0, 30 - elapsed)`) als auch den Plank-Hoch-Zaehler (UI
/// zeigt `min(60, elapsed)`) ab — der Unterschied liegt rein in der
/// Interpretation durch die aufrufende View, nicht im Zustand selbst.
public struct PausableTimerState: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        case running
        case paused
        case finished
    }

    public private(set) var phase: Phase = .idle
    private var anchor: Date?
    private var accumulated: TimeInterval = 0

    public init() {}

    /// Vergangene Zeit seit `start()`, Pausen ausgenommen.
    public func elapsed(now: Date = Date()) -> TimeInterval {
        guard phase == .running, let anchor else { return accumulated }
        return accumulated + now.timeIntervalSince(anchor)
    }

    /// Kein automatischer Start ohne diesen expliziten Aufruf (Epic: "Kein
    /// automatischer Start eines Timers ohne ausdruecklichen Tap").
    public mutating func start(now: Date = Date()) {
        phase = .running
        anchor = now
        accumulated = 0
    }

    public mutating func pause(now: Date = Date()) {
        guard phase == .running else { return }
        accumulated = elapsed(now: now)
        anchor = nil
        phase = .paused
    }

    public mutating func resume(now: Date = Date()) {
        guard phase == .paused else { return }
        anchor = now
        phase = .running
    }

    /// Bricht komplett ab, ohne ein verwertbares Ergebnis zu hinterlassen
    /// (z.B. Nutzer verlaesst den Test vorzeitig, Formverlust/Schmerz).
    public mutating func cancel() {
        phase = .idle
        anchor = nil
        accumulated = 0
    }

    /// Markiert den Timer als regulaer beendet (Zeit lief ab / Nutzer hat
    /// bestaetigt). `elapsed(now:)` danach stabil, da kein Anker mehr
    /// weiterlaeuft.
    public mutating func finish(now: Date = Date()) {
        accumulated = elapsed(now: now)
        anchor = nil
        phase = .finished
    }
}
