import ActivityKit
import WidgetKit
import SwiftUI
import FitnessAppActivities

/// Live Activity for the in-workout rest timer.
///
/// Renders three surfaces driven by the same `RestTimerAttributes` declared in
/// `FitnessAppActivities`:
///   1. Lock Screen / Banner: full-width card with exercise name, set number,
///      countdown, and an auto-updating `ProgressView`.
///   2. Dynamic Island (compact): timer icon + remaining time. Visible while
///      the user is in another app.
///   3. Dynamic Island (expanded): exercise name, set X/Y, prominent countdown.
///
/// Self-updating timers (`Text(timerInterval:)`, `ProgressView(timerInterval:)`)
/// run on the OS side — no per-second push from the app needed.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen / Banner
            LockScreenTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (long-press / press-and-hold on the Island).
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Satz \(context.attributes.setNumber) / \(context.attributes.totalSets)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isFinished ? "Pause vorbei" : "Pause")
                        .font(.caption)
                        .foregroundStyle(context.state.isFinished ? .green : .cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(context.state.isFinished ? .green : .cyan)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)            // verhindert Wackeln beim Sekundenwechsel
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            }
            // Tap → opens the app at fitnessapp://workout/active.
            // Custom URL scheme is registered in App/FitnessApp/Info.plist.
            .widgetURL(FitnessAppDeepLink.activeWorkout)
            .keylineTint(.cyan)
        }
    }
}

// MARK: - Lock Screen layout

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(context.attributes.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Satz \(context.attributes.setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(context.state.isFinished ? "Pause vorbei" : "Pause laeuft")
                    .font(.subheadline)
                Spacer()
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(context.state.isFinished ? .green : .cyan)
            }

            ProgressView(
                timerInterval: Date()...context.state.endDate,
                countsDown: true
            )
            .tint(context.state.isFinished ? .green : .cyan)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }
}
