#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
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

    /// DEL-041: User-Praeferenzen fuer Timer-Feedback. Werden in SettingsView
    /// als Toggle gepflegt — Default beide ON.
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true

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
                // DEL-059: hierarchical-rendering + DeltiqOrange als Akzent
                // (war vorher .blue — Brand-Konsistenz).
                Image(systemName: isFinished ? "checkmark.circle.fill" : "timer")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isFinished ? .green : Color.deltiqOrange)
                    .font(.title3)

                Text(isFinished ? "PAUSE VORBEI" : "PAUSE").deltiqLabel()

                Spacer()

                // DEL-059: rounded-bold Display fuer den verbleibenden Timer.
                Text(formatTime(remaining))
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isFinished ? .green : .primary)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    onDismiss(isFinished ? .completed : .skipped)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.deltiqOrange.opacity(0.14), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("rest.skip", bundle: .module))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            // Tap on the bar itself acts as skip — easier hit-target than the icon.
            .onTapGesture { onDismiss(isFinished ? .completed : .skipped) }

            // Progress bar fills FROM EMPTY (right) to FULL (left) as time elapses,
            // so the visual cue is "track shrinking" — analogous to a fuse burning down.
            // DEL-059: Gradient-Fill statt flatcolor.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.18))
                    Rectangle()
                        .fill((isFinished ? Color.green : Color.deltiqOrange).gradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.4), value: progress)
                }
            }
            .frame(height: 3)
        }
        .background(.regularMaterial)
        .onReceive(tick) { now = $0 }
        .onChange(of: remaining) { oldValue, newValue in
            // Fire feedback exactly once at the 0-Transition.
            if oldValue > 0 && newValue == 0 {
                triggerEndOfRestFeedback()
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

    /// DEL-041: Sound + Haptic-Burst beim Pausen-Ende. Beides an die User-
    /// Praeferenzen aus DEL-018 gekoppelt — wer Sound/Haptics in Settings
    /// abgestellt hat, bekommt nur das jeweils andere (oder gar nichts).
    private func triggerEndOfRestFeedback() {
        #if canImport(UIKit) && !os(watchOS)
        if timerHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
        #if canImport(AudioToolbox)
        if timerSoundEnabled {
            // SystemSoundID 1005 = "New Mail"-Ding (kurz, klar, nicht aufdringlich).
            // Alternative: 1003 = "SMS-Recieved", 1322 = "Tweet-Sent".
            AudioServicesPlaySystemSound(1005)
        }
        #endif
    }
}
#endif
