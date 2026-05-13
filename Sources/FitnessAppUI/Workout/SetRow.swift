#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppCore
import FitnessAppData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Single row inside an `ExerciseCard` — represents one planned set of an exercise.
///
/// Two visual modes:
///  - **Editable** (no log yet): weight + reps text fields + RIR stepper + "Satz speichern" button.
///    Initial values come from the most recent log of the same setIndex (Previous Hint),
///    falling back to `exercise.suggestedWeight` and the midpoint of `repsMin/repsMax`.
///  - **Completed** (a log exists for this session+setIndex): compact read-only summary
///    with relative time. No editing once saved — that simplifies the data path; users
///    who mis-typed can still delete the log via swipe in a future Summary view.
@available(iOS 17.0, macOS 14.0, *)
struct SetRow: View {
    let setIndex: Int
    let exercise: Exercise
    let session: WorkoutSession
    let existingLog: ExerciseLog?
    let previousLog: ExerciseLog?
    /// Called with (weight, reps, rir) when the user taps "Satz speichern".
    let onLogged: (Double, Int, Float) -> Void

    @State private var weight: Double?
    @State private var reps: Int = 0
    @State private var rir: Float = 2.0
    @State private var didInit = false

    /// DEL-040: Zustands-Maschine fuer den Halte-Timer bei isTimeBased-Uebungen.
    @State private var holdState: HoldState = .idle

    /// Local-Timer fuer Countdown/Hold-Tick. Wird in den entsprechenden
    /// State-Transitions aufgesetzt + invalidated.
    @State private var holdTimer: Timer?

    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true

    enum HoldState: Equatable {
        case idle
        case countingDown(secondsLeft: Int)
        case holding(elapsedSeconds: Int)
    }

    var body: some View {
        if let existingLog {
            completedView(log: existingLog)
        } else {
            editableView
                .onAppear { initializeOnce() }
                .onDisappear { invalidateHoldTimer() }
        }
    }

    // MARK: Editable

    private var editableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Satz \(setIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                if let previousLog {
                    Text(previousLogHint(previousLog))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // DEL-040: bei isTimeBased komplett anderer UI-Flow — Start-Button
            // statt Reps-Input, Countdown-Overlay, Live-Hold-Timer mit
            // automatischem Set-Abschluss bei Ziel-Zeit.
            if exercise.isTimeBased && !exercise.isCardio {
                holdTimerControl
            } else {
                manualInputControl
            }
        }
        .padding(.vertical, 6)
    }

    /// Klassischer Manual-Input fuer Strength + Cardio: Gewicht/Reps-TextFields,
    /// RIR-Stepper, "Satz speichern"-Button.
    private var manualInputControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !exercise.isCardio {
                    weightField
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                repsField
                Text("Wdh")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            if !exercise.isCardio {
                Stepper(value: $rir, in: 0...5, step: 0.5) {
                    HStack {
                        Text("RIR")
                            .font(.subheadline)
                        Text(formatRIR(rir))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }

            Button(action: log) {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                    Text("Satz speichern")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(canLog ? Color.green.opacity(0.18) : Color.gray.opacity(0.10))
                .foregroundStyle(canLog ? .green : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!canLog)
        }
    }

    // MARK: - DEL-040 Hold-Timer-Control

    @ViewBuilder
    private var holdTimerControl: some View {
        switch holdState {
        case .idle:
            holdIdleView
        case .countingDown(let secondsLeft):
            holdCountdownView(secondsLeft: secondsLeft)
        case .holding(let elapsed):
            holdRunningView(elapsedSeconds: elapsed)
        }
    }

    private var holdIdleView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ziel: \(targetHoldSeconds) Sek halten")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button {
                startCountdown()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                    Text("Start")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.cyan.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func holdCountdownView(secondsLeft: Int) -> some View {
        VStack(spacing: 6) {
            Text(secondsLeft == 0 ? "GO!" : "\(secondsLeft)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: secondsLeft)
            Text("Mach dich bereit ...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func holdRunningView(elapsedSeconds elapsed: Int) -> some View {
        let target = targetHoldSeconds
        let progress = min(1.0, Double(elapsed) / Double(max(target, 1)))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(elapsed)")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("/ \(target) Sek")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if elapsed >= target {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            // Progress-Bar in Cyan, wechselt auf Grün bei Ziel-Erreichung.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(elapsed >= target ? Color.green : Color.cyan)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())

            Button {
                stopHoldAndLog()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "stop.fill")
                    Text(elapsed >= target ? "Satz speichern" : "Stoppen & speichern")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(elapsed >= target ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                .foregroundStyle(elapsed >= target ? .green : .orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    /// Ziel-Sekunden fuer die Halte-Uebung. Nehmen den repsMin-Wert
    /// (= Minimum-Ziel) als primaere Zielzeit. Wenn nichts gesetzt, fallback 30s.
    private var targetHoldSeconds: Int {
        exercise.repsMin > 0 ? exercise.repsMin : 30
    }

    private func startCountdown() {
        holdState = .countingDown(secondsLeft: 3)
        // 3 ticks im 1s-Intervall — 3 -> 2 -> 1 -> GO -> dann holding.
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                guard case .countingDown(let left) = holdState else {
                    timer.invalidate()
                    return
                }
                if left > 1 {
                    holdState = .countingDown(secondsLeft: left - 1)
                } else if left == 1 {
                    // Zeige "GO!" kurz, dann starte holding.
                    holdState = .countingDown(secondsLeft: 0)
                } else {
                    timer.invalidate()
                    startHolding()
                }
            }
        }
    }

    private func startHolding() {
        holdState = .holding(elapsedSeconds: 0)
        let target = targetHoldSeconds
        var didFireFinishedFeedback = false
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                guard case .holding(let elapsed) = holdState else {
                    timer.invalidate()
                    return
                }
                let next = elapsed + 1
                holdState = .holding(elapsedSeconds: next)
                if next == target && !didFireFinishedFeedback {
                    didFireFinishedFeedback = true
                    triggerHoldCompleteFeedback()
                }
            }
        }
    }

    private func stopHoldAndLog() {
        invalidateHoldTimer()
        guard case .holding(let elapsed) = holdState else { return }
        // Logge die tatsaechlich gehaltene Zeit als reps. Weight stays 0.
        onLogged(0, elapsed, 0)
        holdState = .idle
    }

    private func invalidateHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func triggerHoldCompleteFeedback() {
        #if canImport(UIKit) && !os(watchOS)
        if timerHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
        #if canImport(AudioToolbox)
        if timerSoundEnabled {
            AudioServicesPlaySystemSound(1005)
        }
        #endif
    }

    private var weightField: some View {
        TextField("Gewicht",
                  value: $weight, format: .number,
                  prompt: Text("0"))
            .decimalKeyboard()
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 80)
            .multilineTextAlignment(.trailing)
    }

    private var repsField: some View {
        TextField(exercise.isTimeBased ? "Sek" : "Reps",
                  value: $reps, format: .number,
                  prompt: Text("0"))
            .decimalKeyboard()
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 60)
            .multilineTextAlignment(.trailing)
    }

    // MARK: Completed

    private func completedView(log: ExerciseLog) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            Text("Satz \(setIndex + 1)")
                .font(.subheadline.weight(.semibold))

            Text(loggedSummary(log))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.primary)

            Spacer()

            Text(log.date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .opacity(0.85)
    }

    private func loggedSummary(_ log: ExerciseLog) -> String {
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? "Sek" : "Wdh")"
        }
        if exercise.isTimeBased {
            return "\(log.reps) Sek (RIR \(formatRIR(log.rir)))"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps) (RIR \(formatRIR(log.rir)))"
    }

    private func previousLogHint(_ log: ExerciseLog) -> String {
        if exercise.isTimeBased {
            return "letztes: \(log.reps) Sek"
        }
        return "letztes: \(formatWeight(log.weight)) kg × \(log.reps)"
    }

    // MARK: State init

    /// Initializes weight/reps/rir once when the view first appears. Subsequent appears
    /// (e.g., after the parent re-renders) keep the user's in-progress edits.
    private func initializeOnce() {
        guard !didInit else { return }
        didInit = true

        if let previousLog {
            weight = previousLog.weight > 0 ? previousLog.weight : exercise.suggestedWeight
            reps = previousLog.reps
            rir = previousLog.rir
        } else {
            weight = exercise.suggestedWeight
            reps = midpoint(exercise.repsMin, exercise.repsMax)
            rir = exercise.targetRir
        }
    }

    private func midpoint(_ a: Int, _ b: Int) -> Int { (a + b) / 2 }

    // MARK: Actions

    private var canLog: Bool {
        guard reps > 0 else { return false }
        if exercise.isCardio || exercise.isTimeBased { return true }
        return (weight ?? 0) > 0
    }

    private func log() {
        guard canLog else { return }
        let w = (exercise.isCardio || exercise.isTimeBased) ? 0.0 : (weight ?? 0)
        onLogged(w, reps, rir)
    }

    // MARK: Formatting

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatRIR(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }
}
#endif
