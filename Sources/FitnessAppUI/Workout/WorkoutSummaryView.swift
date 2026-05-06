#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Workout-completion review screen. Pushed onto the workout navigation stack from
/// `ActiveWorkoutView.finishWorkout()`. Session is already saved (`isCompleted=true`,
/// totals populated) — this view is a review surface plus the notes-entry surface,
/// not a "save vs cancel" gate.
@available(iOS 17.0, macOS 14.0, *)
public struct WorkoutSummaryView: View {

    @Bindable public var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    /// True when invoked from history (`WorkoutHistoryView`) — hides the finish-CTA,
    /// disables swipe-to-delete on sets, makes notes read-only, and re-enables the
    /// system back button so the user can return to the history list.
    public let isReadOnly: Bool

    public init(session: WorkoutSession, isReadOnly: Bool = false) {
        self.session = session
        self.isReadOnly = isReadOnly
    }

    public var body: some View {
        List {
            heroSection
            statsSection
            notesSection
            breakdownSections
            if !isReadOnly {
                finishSection
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(isReadOnly ? "Workout-Detail" : "Zusammenfassung")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(!isReadOnly)
    }

    // MARK: Sections

    private var heroSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("summary.hero.title", bundle: .module)
                    .font(.title2.weight(.bold))
                if let dayName = session.dayName {
                    Text(dayName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var statsSection: some View {
        Section("Zusammenfassung") {
            HStack(spacing: 0) {
                SummaryStat(label: "Dauer", value: formattedDuration)
                statDivider
                SummaryStat(label: "Saetze", value: "\(session.totalSets)")
                statDivider
                SummaryStat(label: "Volumen kg", value: formattedVolume)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if isReadOnly {
            // Hide the section entirely when there's no note — empty state is uglier
            // than a missing section in a history-detail view.
            if let notes = session.notes, !notes.isEmpty {
                Section("Notiz") {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            Section("Notiz") {
                TextField(
                    "Wie war's? Schmerzen, Pump, Performance ...",
                    text: Binding(
                        get: { session.notes ?? "" },
                        set: { session.notes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)
            } footer: {
                Text("Tauchen spaeter in der History pro Session auf — gut fuer Form-Cues und Verletzungs-Tracking.")
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var breakdownSections: some View {
        if exercisesWithLogs.isEmpty {
            Section("Saetze") {
                Text("Keine Saetze geloggt.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } else {
            ForEach(exercisesWithLogs, id: \.exercise.persistentModelID) { entry in
                exerciseSection(for: entry.exercise, logs: entry.logs)
            }
        }
    }

    private func exerciseSection(for exercise: Exercise, logs: [ExerciseLog]) -> some View {
        Section {
            // .onDelete only registers when isReadOnly is false — in history mode,
            // accidental swipes shouldn't be able to mutate completed records.
            if isReadOnly {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise)
                }
            } else {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise)
                }
                .onDelete { offsets in
                    deleteSets(of: exercise, indices: offsets)
                }
            }
        } header: {
            HStack {
                Text(exercise.name)
                Spacer()
                if let best = bestSet(in: logs) {
                    Text("Best: \(formatSetSummary(best, exercise: exercise))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        } footer: {
            Text("\(logs.count) Saetze • \(formatVolume(logs)) kg Volumen")
                .font(.footnote)
        }
    }

    private var finishSection: some View {
        Section {
            Button {
                navigation.returnToDashboard()
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("summary.action.finish", bundle: .module)
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                    .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 6)
                .foregroundStyle(.white)
            }
            .listRowBackground(Color.green)
        } footer: {
            Text("Die Session ist bereits gespeichert. Der Button schliesst die Zusammenfassung und bringt dich zurueck aufs Dashboard.")
                .font(.footnote)
        }
    }

    // MARK: Derived

    /// Logs grouped by exercise, ordered by `Exercise.orderIndex` (matches the plan).
    private var exercisesWithLogs: [(exercise: Exercise, logs: [ExerciseLog])] {
        let grouped = Dictionary(grouping: session.logs) { $0.exercise?.persistentModelID }
        return grouped.compactMap { (_, logs) -> (Exercise, [ExerciseLog])? in
            guard let exercise = logs.first?.exercise else { return nil }
            return (exercise, logs.sorted { $0.setIndex < $1.setIndex })
        }
        .sorted { $0.0.orderIndex < $1.0.orderIndex }
    }

    private var formattedDuration: String {
        let mins = session.durationMinutes
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) Min"
    }

    private var formattedVolume: String {
        session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 32)
    }

    // MARK: Best-set / volume helpers

    private func bestSet(in logs: [ExerciseLog]) -> ExerciseLog? {
        logs.max { lhs, rhs in
            lhs.weight * Double(lhs.reps) < rhs.weight * Double(rhs.reps)
        }
    }

    private func formatVolume(_ logs: [ExerciseLog]) -> String {
        let total = logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return total.truncated(to: 0).formattedTwoDecimals
    }

    private func formatSetSummary(_ log: ExerciseLog, exercise: Exercise) -> String {
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? "Sek" : "Wdh")"
        }
        if exercise.isTimeBased {
            return "\(log.reps) Sek"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps)"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    // MARK: Delete + re-index

    /// Deletes specific logs of an exercise, then re-indexes the remaining sets so
    /// `setIndex` stays a contiguous 0..n-1. Re-indexing keeps the "Letztes: ..."
    /// hint logic correct in future workouts (it matches by `setIndex`).
    private func deleteSets(of exercise: Exercise, indices: IndexSet) {
        let logs = exercise.logs
            .filter { $0.session?.persistentModelID == session.persistentModelID }
            .sorted { $0.setIndex < $1.setIndex }

        for index in indices {
            modelContext.delete(logs[index])
        }

        // Re-index remaining sets in this exercise.
        let remaining = exercise.logs
            .filter { $0.session?.persistentModelID == session.persistentModelID }
            .sorted { $0.setIndex < $1.setIndex }
        for (i, log) in remaining.enumerated() {
            log.setIndex = i
        }

        // Update session-level aggregates.
        session.totalSets = session.logs.count
        session.totalVolumeKg = session.logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SetSummaryRow: View {
    let log: ExerciseLog
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 8) {
            Text("Satz \(log.setIndex + 1)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 64, alignment: .leading)

            Text(rowText)
                .font(.callout)
                .monospacedDigit()

            Spacer()
        }
    }

    private var rowText: String {
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? "Sek" : "Wdh")"
        }
        if exercise.isTimeBased {
            return "\(log.reps) Sek (RIR \(formatRIR(log.rir)))"
        }
        return "\(formatWeight(log.weight)) kg × \(log.reps) (RIR \(formatRIR(log.rir)))"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatRIR(_ rir: Float) -> String {
        rir == rir.rounded() ? String(format: "%.0f", rir) : String(format: "%.1f", rir)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Summary mit voller Push-Session") {
    SummaryPreviewWrapper()
        .modelContainer(PreviewSeed.activeSessionContainer)
        .environment(AppNavigation())
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryPreviewWrapper: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completed: [WorkoutSession]

    var body: some View {
        if let session = completed.first {
            NavigationStack {
                WorkoutSummaryView(session: session)
            }
        } else {
            Text("Keine abgeschlossene Session im Preview-Container")
        }
    }
}
#endif
#endif
