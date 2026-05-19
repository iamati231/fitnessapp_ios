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

    /// Startet einen Rest-Timer-Activity ODER updatet eine existierende.
    ///
    /// **DEL-044 — Singleton-Garantie:** vor dem (Neu-)Request killen wir alle
    /// stale Activities mit `.immediate`-Dismissal. Sonst koennten Geister-
    /// Activities aus App-Crash/Restart parallel zur neuen weiterlaufen.
    ///
    /// **DEL-112 — Update-statt-Respawn:** wenn schon eine Activity fuer
    /// **dieselbe** `exerciseName` laeuft (auch im Linger-State nach Timer-
    /// Ablauf), updaten wir nur den ContentState statt eine zweite Instanz
    /// zu spawnen. Frueher loeste der End+Request-Tanz den Endless-Spinner-
    /// Bug in der Dynamic Island aus, weil iOS in der Uebergangs-Phase die
    /// Activity-Identitaet verlor.
    ///
    /// Uebungswechsel mid-Pause (seltener Edge-Case) loest weiterhin
    /// End+Respawn aus — dort akzeptieren wir das geringe Spinner-Restrisiko.
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

        let newState = RestTimerAttributes.ContentState(
            endDate: endDate,
            originalSeconds: originalSeconds,
            setNumber: setNumber,
            totalSets: totalSets
        )
        // staleDate leicht hinter endDate — iOS rendert den "vorbei"-State
        // kurz weiter, selbst wenn wir vor dem expliziten End-Call crashen.
        let newContent = ActivityContent(
            state: newState,
            staleDate: endDate.addingTimeInterval(60)
        )

        // DEL-112: Wiederverwendbare Activity finden — gleicher exerciseName,
        // noch nicht im ended-State. Linger nach completed (.after) zaehlt
        // weiterhin als wiederverwendbar — verhindert genau den Spinner-Bug
        // wenn der naechste Set-Timer waehrend des 8s-Lingers startet.
        let allActivities = Activity<RestTimerAttributes>.activities
        if let reusable = allActivities.first(where: {
            $0.attributes.exerciseName == exerciseName && $0.activityState != .ended
        }) {
            await reusable.update(newContent)
            current = reusable
            // Stale Activities anderer Uebungen sind in dem Pfad sehr
            // unwahrscheinlich, aber defensiv aufraeumen.
            for stale in allActivities where stale.id != reusable.id {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
            lastError = nil
        } else {
            // Kein wiederverwendbarer Slot — alle stale killen + neu requesten.
            for stale in allActivities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
            current = nil

            let attributes = RestTimerAttributes(exerciseName: exerciseName)
            do {
                current = try Activity.request(
                    attributes: attributes,
                    content: newContent,
                    pushType: nil
                )
                lastError = nil
            } catch {
                lastError = error
            }
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
            // DEL-112: setNumber/totalSets aus dem letzten bekannten State
            // ziehen, damit der Counter im "Pause vorbei"-Banner nicht
            // visuell auf 1/1 zurueckspringt.
            let lastState = current?.content.state
            let finalState = RestTimerAttributes.ContentState(
                endDate: Date(),
                originalSeconds: 0,
                setNumber: lastState?.setNumber ?? 1,
                totalSets: lastState?.totalSets ?? 1,
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
        // DEL-112: setNumber/totalSets aus letztem bekannten State preserven.
        let lastState = current?.content.state
        let celebrationState = RestTimerAttributes.ContentState(
            endDate: Date(),                // already "over"
            originalSeconds: 0,
            setNumber: lastState?.setNumber ?? 1,
            totalSets: lastState?.totalSets ?? 1,
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
