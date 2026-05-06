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

    /// Requests a new rest-timer activity. Cancels any existing one first so we
    /// never have overlapping timers (matches the in-app bar's behavior).
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

        if let existing = current {
            await existing.end(nil, dismissalPolicy: .immediate)
            current = nil
        }

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
    public func endRestTimer(reason: RestTimerEndReason = .skipped) async {
        #if os(iOS)
        guard let current else { return }

        switch reason {
        case .skipped:
            await current.end(nil, dismissalPolicy: .immediate)
        case .completed:
            // Final-state update so the widget shows "Pause vorbei" before dismissal.
            let finalState = RestTimerAttributes.ContentState(
                endDate: Date(),
                originalSeconds: 0,
                isFinished: true
            )
            let finalContent = ActivityContent(
                state: finalState,
                staleDate: Date().addingTimeInterval(30)
            )
            await current.end(
                finalContent,
                dismissalPolicy: .after(Date().addingTimeInterval(8))
            )
        }
        self.current = nil
        #endif
    }

    /// Posts a one-shot PR-celebration as the final state of the running activity,
    /// then dismisses ~8 seconds later. Use when the workout finished with at
    /// least one new personal record — the headline (e.g. "🏆 100 kg Bankdruecken")
    /// replaces the timer surface in both the Lock-Screen and Dynamic-Island
    /// renderings.
    ///
    /// No-op when no activity is running — finishing a workout without a timer
    /// in flight just means the celebration only goes via local notification.
    public func endRestTimerWithPR(prMessage: String) async {
        #if os(iOS)
        guard let current else { return }

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
        await current.end(
            celebrationContent,
            dismissalPolicy: .after(Date().addingTimeInterval(8))
        )
        self.current = nil
        #endif
    }
}
