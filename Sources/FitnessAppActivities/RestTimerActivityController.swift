import Foundation
import Observation
#if os(iOS)
import ActivityKit
#endif

/// Why an activity might end. The skipped/completed split exists so the widget can
/// display a brief "Pause vorbei"-state on natural completion (lingering 8 seconds
/// before dismissal) versus disappearing instantly when the user opens the next set.
public enum RestTimerEndReason: Sendable {
    case skipped    // user moved on early — dismiss immediately
    case completed  // timer hit 0 naturally — let widget linger briefly
}

/// `@MainActor`-bound facade that the SwiftUI layer drives. On non-Apple platforms
/// (Windows-CI tests) every method is a no-op and `isAvailable` reports false.
///
/// Lifecycle from ActiveWorkoutView's POV:
///   1. User taps "Satz speichern" → `startRestTimer(...)` requests a new Live Activity.
///   2. Bar's skip/timer-zero → `endRestTimer(reason:)` ends + dismisses.
///   3. User finishes/discards the workout → `endRestTimer(reason: .skipped)`.
@MainActor
@Observable
public final class RestTimerActivityController {

    /// True when ActivityKit is present AND the user has Live Activities enabled
    /// in iOS settings. Reads via `ActivityAuthorizationInfo`.
    public private(set) var isAvailable: Bool = false
    public private(set) var lastError: (any Error)?

    #if os(iOS)
    /// Currently-running activity, nil between sets.
    private var current: Activity<RestTimerAttributes>?
    #endif

    public init() {
        refreshAvailability()
    }

    /// Pulls the current "are activities enabled" flag. Cheap; safe to call from
    /// `.task` blocks on view appearance.
    public func refreshAvailability() {
        #if os(iOS)
        isAvailable = ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        isAvailable = false
        #endif
    }

    /// Requests a new rest-timer activity. DEL-044: Singleton-Garantie —
    /// vor dem neuen Activity-Request iterieren wir ueber ALLE laufenden
    /// `Activity<RestTimerAttributes>.activities` und beenden sie mit
    /// `.immediate`-Dismissal. Frueher haben wir nur die getrackte `current`-
    /// Referenz beendet; nach App-Restart oder Crash konnten dort stale
    /// Activities zurueckbleiben, die parallel zur neuen weiterlaufen.
    public func startRestTimer(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        endDate: Date,
        originalSeconds: Int
    ) async {
        #if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            isAvailable = false
            return
        }
        isAvailable = true

        // ── Singleton-Cleanup: ALLE existing Activities killen, nicht nur
        // ── die getrackte `current`-Referenz (DEL-044).
        for stale in Activity<RestTimerAttributes>.activities {
            await stale.end(nil, dismissalPolicy: .immediate)
        }
        current = nil

        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            setNumber: setNumber,
            totalSets: totalSets
        )
        let state = RestTimerAttributes.ContentState(
            endDate: endDate,
            originalSeconds: originalSeconds
        )
        // staleDate slightly past endDate so iOS keeps showing the "vorbei"-state
        // briefly even if we crash before our explicit end-call.
        let content = ActivityContent(
            state: state,
            staleDate: endDate.addingTimeInterval(60)
        )

        do {
            current = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }

    /// Ends the current activity with a dismissal-policy that depends on the reason.
    /// DEL-044: Defensiv auch fuer Skip — alle stale Activities aufraeumen,
    /// damit kein Geister-Timer auf dem Lock-Screen weiterlaeuft.
    public func endRestTimer(reason: RestTimerEndReason = .skipped) async {
        #if os(iOS)
        switch reason {
        case .skipped:
            // Skip cleant ALLE stale Activities — sonst koennte eine
            // Geister-Activity vom App-Crash zurueckbleiben.
            for stale in Activity<RestTimerAttributes>.activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        case .completed:
            // .completed-Pfad: nur die aktuelle bekommt das "Pause vorbei"-
            // Final-State, andere stale Activities werden hard-killt.
            let finalState = RestTimerAttributes.ContentState(
                endDate: Date(),
                originalSeconds: 0,
                isFinished: true
            )
            let finalContent = ActivityContent(
                state: finalState,
                staleDate: Date().addingTimeInterval(30)
            )
            for stale in Activity<RestTimerAttributes>.activities {
                if stale.id == current?.id {
                    await stale.end(
                        finalContent,
                        dismissalPolicy: .after(Date().addingTimeInterval(8))
                    )
                } else {
                    await stale.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        self.current = nil
        #endif
    }

    /// Posts a one-shot PR-celebration as the final state of the running activity,
    /// then dismisses ~8 seconds later. Use when the workout finished with at
    /// least one new personal record — the headline (e.g. "🏆 100 kg Bankdrücken")
    /// replaces the timer surface in both the Lock-Screen and Dynamic-Island
    /// renderings.
    ///
    /// No-op when no activity is running — finishing a workout without a timer
    /// in flight just means the celebration only goes via local notification.
    /// DEL-044: stale activities werden hard-killt, nur die getrackte
    /// `current` bekommt den Celebration-Linger.
    public func endRestTimerWithPR(prMessage: String) async {
        #if os(iOS)
        let celebrationState = RestTimerAttributes.ContentState(
            endDate: Date(),                // already "over"
            originalSeconds: 0,
            isFinished: true,
            prMessage: prMessage
        )
        let celebrationContent = ActivityContent(
            state: celebrationState,
            staleDate: Date().addingTimeInterval(30)
        )
        for stale in Activity<RestTimerAttributes>.activities {
            if stale.id == current?.id {
                await stale.end(
                    celebrationContent,
                    dismissalPolicy: .after(Date().addingTimeInterval(8))
                )
            } else {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.current = nil
        #endif
    }
}
