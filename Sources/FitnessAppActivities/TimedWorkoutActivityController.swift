import Foundation
import FitnessAppCore
#if os(iOS)
import ActivityKit
#endif

/// `@MainActor`-Fassade, ueber die der Zeitformat-Koordinator der UI die Live
/// Activity steuert. Auf Nicht-iOS-Plattformen (Linux-/macOS-Tests) ist jede
/// Methode ein No-Op.
///
/// Anders als beim Rest-Timer (`RestTimerActivityController`) ist hier nichts
/// "einmal starten, einmal beenden": Die UI meldet bei jedem Zustandswechsel den
/// aktuellen Inhalt (`apply`), der Controller entscheidet, ob er die Activity
/// anlegt, aktualisiert oder in Ruhe laesst:
///
///   * Es gibt schon eine Activity fuer diesen Lauf -> Update (kein Neuanlegen,
///     sonst flackert die Dynamic Island - siehe DEL-112 beim Rest-Timer).
///   * Es gab eine, sie ist weg und WIR haben sie nicht beendet -> der Nutzer hat
///     sie weggewischt. Das respektieren wir, sonst spraenge sie bei jedem
///     Rundentipp wieder auf.
///   * Sonst -> Geister fremder Laeufe beenden, neu anlegen.
///
/// Alle Aufrufe laufen streng nacheinander (`enqueue`): Die ActivityKit-Aufrufe
/// sind `async`, und zwei sich ueberholende Updates koennten sonst den alten
/// Stand ueber den neuen legen oder ein Update nach dem Beenden eine Activity
/// wieder aufleben lassen.
@MainActor
public final class TimedWorkoutActivityController {

    /// So lange bleibt der "Geschafft"-Stand nach dem Ende des Laufs auf dem
    /// Sperrbildschirm stehen, falls der Nutzer nicht zurueckkehrt. Kehrt er in die
    /// App zurueck und speichert, beendet `end()` ihn sofort.
    public static let finishedLingerSeconds: TimeInterval = 10 * 60

    /// Letzter Fehler von `Activity.request` (z.B. App nicht im Vordergrund oder
    /// Live Activities in den iOS-Einstellungen aus). Nur zur Diagnose.
    public private(set) var lastError: (any Error)?

    #if os(iOS)
    /// Fuer welchen Lauf zuletzt eine Activity angelegt wurde.
    private var requestedKey: String?
    /// `true`, wenn die Activity von uns beendet wurde (nicht vom Nutzer).
    private var endedByUs = false
    #endif

    private var queueTail: Task<Void, Never>?

    public init() {}

    /// Legt die Live Activity fuer diesen Lauf an oder aktualisiert sie.
    public func apply(
        sessionKey: String,
        format: WorkoutTimeFormat,
        formatName: String,
        dayName: String,
        content: TimedLiveContent,
        texts: TimedWorkoutLiveTexts
    ) {
        enqueue { [self] in
            await performApply(
                sessionKey: sessionKey, format: format, formatName: formatName,
                dayName: dayName, content: content, texts: texts
            )
        }
    }

    /// Beendet alle Zeitformat-Live-Activities sofort (Lauf gespeichert,
    /// verworfen, Player verlassen oder Geister nach einem App-Neustart).
    public func end() {
        enqueue { [self] in
            await performEnd()
        }
    }

    // MARK: - Ablauf

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queueTail
        queueTail = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func performApply(
        sessionKey: String,
        format: WorkoutTimeFormat,
        formatName: String,
        dayName: String,
        content: TimedLiveContent,
        texts: TimedWorkoutLiveTexts
    ) async {
        #if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TimedWorkoutAttributes.ContentState(content: content, texts: texts)
        let activityContent = ActivityContent(state: state, staleDate: content.staleDate)

        let all = Activity<TimedWorkoutAttributes>.activities
        let existing = all.first {
            $0.attributes.sessionKey == sessionKey && ($0.activityState == .active || $0.activityState == .stale)
        }

        if let existing {
            for other in all where other.id != existing.id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
            if content.phase == .finished {
                // Zeit abgelaufen oder Pensum geschafft: den Endstand noch eine
                // Weile zeigen, dann verschwindet die Activity von selbst.
                await existing.end(
                    activityContent,
                    dismissalPolicy: .after(Date().addingTimeInterval(Self.finishedLingerSeconds))
                )
                endedByUs = true
            } else {
                await existing.update(activityContent)
                endedByUs = false
            }
            requestedKey = sessionKey
            return
        }

        // Kein Endstand fuer eine Activity, die es nicht (mehr) gibt.
        if content.phase == .finished { return }
        // Weg, aber nicht von uns beendet: der Nutzer hat sie weggewischt.
        if requestedKey == sessionKey, !endedByUs { return }

        for stale in all {
            await stale.end(nil, dismissalPolicy: .immediate)
        }
        let attributes = TimedWorkoutAttributes(
            sessionKey: sessionKey, format: format, formatName: formatName, dayName: dayName
        )
        do {
            _ = try Activity.request(attributes: attributes, content: activityContent, pushType: nil)
            requestedKey = sessionKey
            endedByUs = false
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }

    private func performEnd() async {
        #if os(iOS)
        for activity in Activity<TimedWorkoutAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        endedByUs = true
        #endif
    }
}
