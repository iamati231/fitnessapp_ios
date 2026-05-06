#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Sticky rest-timer bar that lives in the safe-area-inset of `ActiveWorkoutView`.
/// Counts down from the most recent set's `restSeconds`, fires a success haptic at
/// 0, and auto-dismisses 3 seconds later. The user can finish the rest early via
/// the chevron-skip button (or by tapping the bar itself) — semantically "I'm
/// already ready" rather than "abort the timer".
@available(iOS 17.0, macOS 14.0, *)
struct RestTimerBar: View {

    /// Reason the bar disappeared — relayed up so the parent can choose the matching
    /// dismissal policy for the Live Activity (immediate-dismiss vs. linger).
    enum DismissReason: Sendable {
        case skipped    // user tapped skip while the timer was still running
        case completed  // timer hit 0 naturally, auto-dismiss after 3s ticked
    }

    let endDate: Date
    let originalSeconds: Int
    /// Called when the bar disappears. Carries the reason so the parent can route
    /// to the right Live-Activity dismiss-policy.
    let onDismiss: (DismissReason) -> Void

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var remaining: Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    private var progress: Double {
        guard originalSeconds > 0 else { return 0 }
        let frac = Double(remaining) / Double(originalSeconds)
        return min(max(frac, 0), 1)
    }

    private var isFinished: Bool { remaining == 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: isFinished ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(isFinished ? .green : .blue)
                    .font(.title3)

                Text(isFinished ? "Pause vorbei" : "Pause")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(formatTime(remaining))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isFinished ? .green : .primary)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    onDismiss(isFinished ? .completed : .skipped)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause ueberspringen")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            // Tap on the bar itself acts as skip — easier hit-target than the icon.
            .onTapGesture { onDismiss(isFinished ? .completed : .skipped) }

            // Progress bar fills FROM EMPTY (right) to FULL (left) as time elapses,
            // so the visual cue is "track shrinking" — analogous to a fuse burning down.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(isFinished ? Color.green : Color.blue)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.4), value: progress)
                }
            }
            .frame(height: 3)
        }
        .background(.regularMaterial)
        .onReceive(tick) { now = $0 }
        .onChange(of: remaining) { oldValue, newValue in
            // Fire success haptic exactly once at the transition.
            if oldValue > 0 && newValue == 0 {
                triggerHaptic()
                // Auto-dismiss after 3s so the bar doesn't linger on screen.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onDismiss(.completed)
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func triggerHaptic() {
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
#endif
