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
    /// DEL-097 + DEL-108: Session-weiter Time-Set-Lock (Exercise × setIndex).
    /// Reicht durch zur SetRow, die den Lock claimt bzw. den eigenen
    /// Start-Button blockiert, wenn ein anderer Satz (gleicher oder fremder
    /// Uebung) den Slot bereits haelt.
    @Binding var activeTimedSet: ActiveTimedSetID?
    /// Fired when ANY set is logged. Carries the 0-based set index so the parent
    /// can label the Live Activity ("Satz 2 von 4") accurately.
    let onSetLogged: (_ setIndex: Int) -> Void

    /// DEL-154: Optionale Edit-/Delete-Hooks. Werden NUR im Ad-Hoc-Workout
    /// gesetzt (`session.isAdHoc`) — dort hat der User die Uebungen selbst
    /// hinzugefuegt und darf sie strukturell aendern bzw. wieder entfernen.
    /// Bei Plan-Workouts bleiben beide `nil` → kein Menu, Plan bleibt
    /// unangetastet.
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // UX-203: berechne EINMAL pro Render den aktiven Satz — der erste
        // mit `existingLog == nil`. Wenn alle completed sind, bleibt es nil
        // und keine Row bekommt den active-Highlight. Wird pro SetRow
        // weitergereicht, damit die Row nicht selber nach activeIndex
        // suchen muss (vermeidet O(n²) in der For-Each).
        let active = activeSetIndex
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
                    activeTimedSet: $activeTimedSet,
                    isActiveSet: setIndex == active,
                    onLogged: { values in
                        logSet(setIndex: setIndex, values: values)
                    },
                    onUnlog: {
                        unlogSet(setIndex: setIndex)
                    }
                )
                if setIndex < exercise.sets - 1 {
                    // UX-203: Divider noch ruhiger (0.4 → 0.2), weil die
                    // Active-Set-Background-Tint jetzt die primaere
                    // visuelle Trennung uebernimmt.
                    Divider().opacity(0.2)
                }
            }

            if completedSetCount >= exercise.sets {
                Label {
                    Text("workout.allSetsDone", bundle: .module)
                } icon: {
                    Image(systemName: "flag.checkered")
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // DEL-059: subtile Licht-Kante — gibt dem Card das premium-erhabene
        // Gefuehl auf Dark-Mode, no-op auf Light-Mode.
        .innerLightStroke(cornerRadius: 16, opacity: 0.08)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // DEL-124: Active-Workout Card-Header via displayName.
                    Text(exercise.displayName)
                        .font(.headline)
                    // DEL-087: Pill markiert Warmup/Cooldown-Uebungen optisch.
                    if exercise.role != .workingSet {
                        Text(rolePillText)
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
                // UX-203: Set-Metadata ruhiger — .caption → .caption2,
                // .secondary → .tertiary, plus monospacedDigit damit Zahlen
                // beim Editieren (z.B. Pause-Stepper) nicht in der Breite
                // springen. Bleibt lesbar, drueckt aber sich weiter in
                // den Hintergrund gegenueber dem Exercise-Name.
                Text(targetText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            progressPill
            // DEL-154: Edit/Delete-Menu — nur wenn der Parent Hooks liefert
            // (Ad-Hoc-Workout). In der paginierten TabView gibt es keine
            // List-Swipe-Actions, daher ein Ellipsis-Menu im Header.
            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label {
                                Text("active.exercise.edit", bundle: .module)
                            } icon: {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label {
                                Text("active.exercise.remove", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("active.exercise.menuAccessibility", bundle: .module))
            }
        }
    }

    /// DEL-087: Label-Text fuer die Role-Pill im Header.
    private var rolePillText: String {
        switch exercise.role {
        case .warmup:     return "WARM-UP"
        case .cooldown:   return "COOL-DOWN"
        case .workingSet: return ""
        }
    }

    /// DEL-128: vollstaendige i18n der Card-Subtitle-Zeile.
    /// Vorher inline DE-Strings ("Cardio", "Wdh"/"Sek", "Pause") — im EN/TR-
    /// Mode wurden die durchgereicht und produzierten halb-deutsche Sub-
    /// titel. Jetzt:
    ///   * Cardio-Branch:   "Cardio • 150s Pause" / "Cardio • 150s rest"
    ///                      / "Kardiyo • 150s mola"
    ///   * Strength-Branch: "3 × 6-8 Wdh • 150s Pause" / "3 × 6-8 reps •
    ///                      150s rest" / "3 × 6-8 tkr • 150s mola"
    /// Format-Strings sind im Catalog als `exercise.target.cardioFormat` /
    /// `.strengthFormat` mit positionellen %1$/%2$/...-Placeholders
    /// definiert; Swift macht die Substitution via `String(format:)`.
    private var targetText: String {
        let pauseLabel = String(localized: "exercise.rest.label", bundle: .module)
        if exercise.isCardio {
            let cardioLabel = String(localized: "exercise.kind.cardio", bundle: .module)
            let fmt = String(localized: "exercise.target.cardioFormat", bundle: .module)
            return String(format: fmt, cardioLabel, exercise.restSeconds, pauseLabel)
        }
        let unit = exercise.isTimeBased
            ? String(localized: "unit.seconds.short", bundle: .module)
            : String(localized: "unit.reps.short", bundle: .module)
        let range = exercise.repsMin == exercise.repsMax
            ? "\(exercise.repsMin)"
            : "\(exercise.repsMin)-\(exercise.repsMax)"
        let fmt = String(localized: "exercise.target.strengthFormat", bundle: .module)
        return String(format: fmt, exercise.sets, range, unit, exercise.restSeconds, pauseLabel)
    }

    private var progressPill: some View {
        Text("\(completedSetCount) / \(exercise.sets)")
            .font(.caption.weight(.bold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(progressFillColor)
            .foregroundStyle(completedSetCount >= exercise.sets ? .green : .primary)
            .clipShape(Capsule())
            // DEL-059: feine Lichtkante auf der Pill
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
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

    /// UX-203: liefert den Index des "naechsten anstehenden" Sets — also
    /// den niedrigsten setIndex ohne existing log. Nil = alle Sets dieser
    /// Uebung sind completed. Wird in `body` einmal evaluiert und an die
    /// SetRow-Children durchgereicht, damit der visuelle Active-Highlight
    /// in einer einzigen Quelle der Wahrheit lebt.
    private var activeSetIndex: Int? {
        // Set der Logs ueber setIndex bilden — O(n) Lookup statt n×n.
        let completed = Set(sessionLogs.map(\.setIndex))
        for i in 0..<exercise.sets where !completed.contains(i) {
            return i
        }
        return nil
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

    /// DEL-058: nimmt jetzt das `LoggedSetValues`-Bundle und uebernimmt
    /// auch Cardio-Felder (distanceKm/durationSeconds) in den persistierten
    /// `ExerciseLog`.
    private func logSet(setIndex: Int, values: LoggedSetValues) {
        let log = ExerciseLog(
            date: Date(),
            setIndex: setIndex,
            weight: values.weight,
            reps: values.reps,
            rpe: 0,                          // unused in this UI; reserved for future
            rir: values.rir,
            comment: nil,
            exercise: exercise,
            session: session,
            distanceKm: values.distanceKm,
            durationSeconds: values.durationSeconds
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
