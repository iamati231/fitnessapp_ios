#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppCore
import FitnessAppData

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

    var body: some View {
        if let existingLog {
            completedView(log: existingLog)
        } else {
            editableView
                .onAppear { initializeOnce() }
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

            HStack(spacing: 8) {
                if !exercise.isCardio {
                    weightField
                    Text(exercise.isTimeBased ? "" : "kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                repsField
                Text(exercise.isTimeBased ? "Sek" : "Wdh")
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
        .padding(.vertical, 6)
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
