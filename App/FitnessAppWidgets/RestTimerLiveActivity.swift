import ActivityKit
import WidgetKit
import SwiftUI
import FitnessAppActivities

/// Live Activity for the in-workout rest timer.
///
/// Renders three surfaces driven by the same `RestTimerAttributes` declared in
/// `FitnessAppActivities`:
///   1. Lock Screen / Banner: full-width card with exercise name, set number,
///      countdown, and an auto-updating `ProgressView`. **PR-celebration mode**
///      replaces the timer surface with a trophy headline.
///   2. Dynamic Island (compact): timer icon + remaining time. In celebration
///      mode the trophy + short PR string takes over.
///   3. Dynamic Island (expanded): exercise name, set X/Y, prominent countdown.
///      In celebration mode the bottom region shows the headline.
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
                    if context.state.prMessage != nil {
                        Text("Personal Record!")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                    } else {
                        Text(context.state.isFinished ? "Pause vorbei" : "Pause")
                            .font(.caption)
                            .foregroundStyle(context.state.isFinished ? .green : .cyan)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let prMessage = context.state.prMessage {
                        Text(prMessage)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    } else {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(context.state.isFinished ? .green : .cyan)
                            .multilineTextAlignment(.center)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.prMessage != nil ? "trophy.fill" : "timer")
                    .foregroundStyle(context.state.prMessage != nil ? .yellow : .cyan)
            } compactTrailing: {
                if let prMessage = context.state.prMessage {
                    Text(prMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                } else {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 44)            // verhindert Wackeln beim Sekundenwechsel
                }
            } minimal: {
                Image(systemName: context.state.prMessage != nil ? "trophy.fill" : "timer")
                    .foregroundStyle(context.state.prMessage != nil ? .yellow : .cyan)
            }
            // Tap → opens the app at fitnessapp://workout/active.
            // Custom URL scheme is registered in App/FitnessApp/Info.plist.
            .widgetURL(FitnessAppDeepLink.activeWorkout)
            .keylineTint(context.state.prMessage != nil ? .yellow : .cyan)
        }
    }
}

// MARK: - Lock Screen layout

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        if let prMessage = context.state.prMessage {
            celebrationLayout(prMessage: prMessage)
        } else {
            timerLayout
        }
    }

    // MARK: PR-celebration variant — replaces the timer ring with a trophy card.

    private func celebrationLayout(prMessage: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Personal Record!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.yellow)
                Spacer()
            }

            HStack {
                Text(prMessage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }

            HStack {
                Text("Im Trophy Room ansehen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: Default rest-timer variant.

    private var timerLayout: some View {
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
