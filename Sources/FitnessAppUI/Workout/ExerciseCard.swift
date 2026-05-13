#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// One card per exercise inside `ActiveWorkoutView` — header (name + target) plus N
/// `SetRow`s, where N = `exercise.sets`. Owns the actual `ExerciseLog` insertion;
/// notifies the parent (via `onSetLogged`) so the rest timer can start.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseCard: View {
    let exercise: Exercise
    let session: WorkoutSession
    /// Fired when ANY set is logged. Carries the 0-based set index so the parent
    /// can label the Live Activity ("Satz 2 von 4") accurately.
    let onSetLogged: (_ setIndex: Int) -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                SetRow(
                    setIndex: setIndex,
                    exercise: exercise,
                    session: session,
                    existingLog: existingLog(forSetIndex: setIndex),
                    previousLog: previousLog(forSetIndex: setIndex),
                    onLogged: { weight, reps, rir in
                        logSet(setIndex: setIndex, weight: weight, reps: reps, rir: rir)
                    },
                    onUnlog: {
                        unlogSet(setIndex: setIndex)
                    }
                )
                if setIndex < exercise.sets - 1 {
                    Divider().opacity(0.4)
                }
            }

            if completedSetCount >= exercise.sets {
                Label("Alle Sätze erledigt", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                Text(targetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            progressPill
        }
    }

    private var targetText: String {
        if exercise.isCardio {
            return "Cardio • \(exercise.restSeconds)s Pause"
        }
        let unit = exercise.isTimeBased ? "Sek" : "Wdh"
        let range = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        return "\(exercise.sets) × \(range) \(unit) • \(exercise.restSeconds)s Pause"
    }

    private var progressPill: some View {
        Text("\(completedSetCount) / \(exercise.sets)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(progressFillColor)
            .foregroundStyle(completedSetCount >= exercise.sets ? .green : .primary)
            .clipShape(Capsule())
    }

    private var progressFillColor: Color {
        completedSetCount >= exercise.sets
            ? Color.green.opacity(0.18)
            : Color.secondary.opacity(0.18)
    }

    // MARK: Lookups

    private var sessionLogs: [ExerciseLog] {
        session.logs.filter { $0.exercise == exercise }
    }

    private var completedSetCount: Int {
        sessionLogs.count
    }

    private func existingLog(forSetIndex index: Int) -> ExerciseLog? {
        sessionLogs.first { $0.setIndex == index }
    }

    /// Most recent log of this exercise + setIndex from a prior COMPLETED session.
    /// Live in-progress logs are filtered out so the hint shows what the user did
    /// LAST workout, not what they just typed two minutes ago.
    private func previousLog(forSetIndex index: Int) -> ExerciseLog? {
        exercise.logs
            .filter {
                $0.session?.isCompleted == true
                && $0.setIndex == index
            }
            .sorted { $0.date > $1.date }
            .first
    }

    // MARK: Actions

    private func logSet(setIndex: Int, weight: Double, reps: Int, rir: Float) {
        let log = ExerciseLog(
            date: Date(),
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            rpe: 0,                          // unused in this UI; reserved for future
            rir: rir,
            comment: nil,
            exercise: exercise,
            session: session
        )
        modelContext.insert(log)
        onSetLogged(setIndex)
    }

    /// DEL-045: Tap-on-completed-row revert. Loescht den `ExerciseLog` fuer
    /// diesen Set-Index, sodass die Row wieder in den editable State zurueck-
    /// faellt (TextFields aktiv, Checkmark hollow). Kein Notify nach oben —
    /// der Rest-Timer wird *nicht* zurueckgesetzt, weil der User vermutlich
    /// nur einen Tippfehler korrigieren will, nicht die ganze Pause-Logik
    /// neu starten.
    private func unlogSet(setIndex: Int) {
        guard let log = existingLog(forSetIndex: setIndex) else { return }
        modelContext.delete(log)
    }
}
#endif
