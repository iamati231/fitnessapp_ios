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

    /// All ExerciseLogs across the model. Filtered in-memory for the PR-detection
    /// history. SwiftData `@Query` doesn't (yet) reliably support nested-relationship
    /// predicates like `$0.session?.isCompleted == true`, so we keep the predicate
    /// in Swift instead.
    @Query(sort: \ExerciseLog.date)
    private var allLogs: [ExerciseLog]

    /// True when invoked from history (`WorkoutHistoryView`) — hides the finish-CTA,
    /// disables swipe-to-delete on sets, makes notes read-only, and re-enables the
    /// system back button so the user can return to the history list.
    public let isReadOnly: Bool

    /// DEL-032: Aktiviert via "Bearbeiten"-Toolbar-Button im isReadOnly-Mode.
    /// Im aktiven Edit-Mode werden Datum + Set-Werte (Gewicht/Reps/RIR) als
    /// TextField/Stepper editierbar. Notes immer editierbar in beiden Edit-Modi.
    @State private var isEditingHistory: Bool = false

    public init(session: WorkoutSession, isReadOnly: Bool = false) {
        self.session = session
        self.isReadOnly = isReadOnly
    }

    /// Werden Set-Werte als Eingabefelder gerendert?
    /// - New-Mode (post-finish): nein, totals werden vom finishWorkout-Flow
    ///   gesetzt
    /// - History-Detail: nein (default, Read-Only)
    /// - History-Edit (DEL-032): ja
    private var isEditingSets: Bool {
        isReadOnly && isEditingHistory
    }

    public var body: some View {
        List {
            heroSection
            if isEditingSets {
                editMetaSection
            }
            if !personalRecords.isEmpty {
                prSection
            }
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
        .navigationTitle(navigationTitleText)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(!isReadOnly)
        .toolbar {
            // DEL-032: History-Mode bekommt einen Edit-Toggle. Im New-Mode
            // unsichtbar (Edit dort macht keinen Sinn — totals werden gerade
            // erst geschrieben).
            if isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditingHistory ? "Fertig" : "Bearbeiten") {
                        if isEditingHistory {
                            // Beim Beenden vom Edit-Mode: totals neu berechnen
                            // + persistieren, falls der User Set-Werte angefasst hat.
                            recalculateSessionTotals()
                            try? modelContext.save()
                        }
                        isEditingHistory.toggle()
                    }
                }
            }
        }
    }

    private var navigationTitleText: String {
        if isReadOnly {
            return isEditingHistory ? "Workout bearbeiten" : "Workout-Detail"
        }
        return "Zusammenfassung"
    }

    /// Im Edit-Mode bekommt der User Datum + Dauer als editierbare Felder.
    /// Wird oben in der List eingeblendet, ueber statsSection.
    private var editMetaSection: some View {
        Section {
            DatePicker("Datum",
                       selection: $session.startTime,
                       displayedComponents: [.date, .hourAndMinute])
            Stepper(value: $session.durationMinutes, in: 0...600, step: 5) {
                LabeledContent("Dauer", value: "\(session.durationMinutes) Min")
            }
        } header: {
            Text("Eckdaten")
        } footer: {
            Text("Datum + Dauer werden hier ueberschrieben. Set-Werte unten editierst du direkt am Satz.")
                .font(.footnote)
        }
    }

    /// Setzt totalSets + totalVolumeKg aus den (eventuell vom User editierten)
    /// ExerciseLogs neu. Wird beim Verlassen des Edit-Modes gerufen, damit
    /// Dashboard/History-Stats korrekt bleiben.
    private func recalculateSessionTotals() {
        session.totalSets = session.logs.count
        session.totalVolumeKg = session.logs.reduce(0.0) { acc, log in
            acc + log.weight * Double(log.reps)
        }
    }

    // MARK: Sections

    // MARK: - Personal Records

    private var personalRecords: [PersonalRecord] {
        PRDetector.detectPRs(sessionLifts: sessionLifts, history: historicalLifts)
    }

    private var sessionLifts: [LiftAttempt] {
        session.logs.compactMap { log -> LiftAttempt? in
            guard let exercise = log.exercise else { return nil }
            return LiftAttempt(
                exerciseName: exercise.name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: exercise.isCardio,
                isTimeBased: exercise.isTimeBased
            )
        }
    }

    /// All logs from completed sessions OTHER than this one — the baseline against
    /// which `PRDetector` measures.
    private var historicalLifts: [LiftAttempt] {
        let thisSessionID = session.persistentModelID
        return allLogs.compactMap { log -> LiftAttempt? in
            guard let exercise = log.exercise,
                  let logSession = log.session,
                  logSession.isCompleted,
                  logSession.persistentModelID != thisSessionID
            else { return nil }
            return LiftAttempt(
                exerciseName: exercise.name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: exercise.isCardio,
                isTimeBased: exercise.isTimeBased
            )
        }
    }

    private var prSection: some View {
        Section {
            ForEach(personalRecords) { record in
                PRBadge(record: record)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Personal Records")
            }
        } footer: {
            Text("Erkannt durch Vergleich mit allen vorherigen abgeschlossenen Sessions. Cardio bleibt aussen vor — andere Metrik-Domäne.")
                .font(.footnote)
        }
    }

    // MARK: -

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
                SummaryStat(label: "Sätze", value: "\(session.totalSets)")
                statDivider
                SummaryStat(label: "Volumen kg", value: formattedVolume)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        // Notes-Edit erlaubt in: New-Mode (post-finish-Summary, .isReadOnly=false)
        // + History-Edit-Mode (isReadOnly && isEditingHistory). Reine History-
        // Detail-Ansicht: nur Anzeige, keine Editier-Felder.
        let notesEditable = !isReadOnly || isEditingHistory
        if !notesEditable {
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
            Section {
                TextField(
                    text: Binding(
                        get: { session.notes ?? "" },
                        set: { session.notes = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text("Wie war's? Schmerzen, Pump, Performance ..."),
                    axis: .vertical
                ) {
                    Text("Notiz")
                }
                .lineLimit(3...8)
            } header: {
                Text("Notiz")
            } footer: {
                Text("Tauchen später in der History pro Session auf — gut für Form-Cues und Verletzungs-Tracking.")
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var breakdownSections: some View {
        if exercisesWithLogs.isEmpty {
            Section("Sätze") {
                Text("Keine Sätze geloggt.")
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
            // .onDelete only registers when the session is editable — entweder
            // im New-Mode (Post-Finish-Cleanup) oder im History-Edit-Mode
            // (DEL-032: Bearbeiten-Button getoggled).
            let editable = !isReadOnly || isEditingHistory
            if editable {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise, isEditable: isEditingSets)
                }
                .onDelete { offsets in
                    deleteSets(of: exercise, indices: offsets)
                }
            } else {
                ForEach(logs) { log in
                    SetSummaryRow(log: log, exercise: exercise, isEditable: false)
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
            Text("\(logs.count) Sätze • \(formatVolume(logs)) kg Volumen")
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
            Text("Die Session ist bereits gespeichert. Der Button schliesst die Zusammenfassung und bringt dich zurück aufs Dashboard.")
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

    // MARK: Best-set / volume helpers — delegate to Core's WorkoutAnalytics

    /// Returns the ExerciseLog with the highest weight×reps volume. Same algorithm
    /// as `WorkoutAnalytics.bestSet`, but returns the @Model instance so the row
    /// view can read its full state. Inline `.max` mirrors the Core implementation.
    private func bestSet(in logs: [ExerciseLog]) -> ExerciseLog? {
        logs.max { lhs, rhs in
            lhs.weight * Double(lhs.reps) < rhs.weight * Double(rhs.reps)
        }
    }

    private func formatVolume(_ logs: [ExerciseLog]) -> String {
        let attempts = logs.map { LiftAttempt(exerciseName: "",
                                              weightKg: $0.weight,
                                              reps: $0.reps,
                                              date: $0.date) }
        return WorkoutAnalytics.totalVolume(in: attempts)
            .truncated(to: 0)
            .formattedTwoDecimals
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

// MARK: - PR Badge

@available(iOS 17.0, macOS 14.0, *)
private struct PRBadge: View {
    let record: PersonalRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kindIcon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(kindColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.body.weight(.semibold))
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detailLine)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Spacer()
            Text("+\(formatDelta(record.deltaPercent))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var kindIcon: String {
        switch record.kind {
        case .estimated1RM:    "bolt.fill"
        case .heaviestWeight:  "scalemass.fill"
        case .bestSet:         "chart.bar.fill"
        case .maxReps:         "arrow.up.arrow.down"
        case .maxHoldSeconds:  "stopwatch.fill"
        }
    }

    private var kindColor: Color {
        switch record.kind {
        case .estimated1RM:    .orange
        case .heaviestWeight:  .red
        case .bestSet:         .blue
        case .maxReps:         .purple
        case .maxHoldSeconds:  .yellow
        }
    }

    private var kindLabel: String {
        switch record.kind {
        case .estimated1RM:    "Neuer 1RM (geschätzt)"
        case .heaviestWeight:  "Neues Maximalgewicht"
        case .bestSet:         "Neuer Bestsatz (Volumen)"
        case .maxReps:         "Neuer Reps-Rekord"
        case .maxHoldSeconds:  "Neue Bestzeit"
        }
    }

    /// Per-kind detail string. Three flavors:
    ///   - Weighted PRs: "X kg × Y → Z kg (vorher V kg)"  (or " kg-Vol" for bestSet)
    ///   - maxReps:      "Y Wdh → Y Wdh (vorher V Wdh)"   (weight always 0 here)
    ///   - maxHoldSeconds: "Y Sek → Y Sek (vorher V Sek)"
    private var detailLine: String {
        switch record.kind {
        case .maxReps:
            let prev = Int(record.previousValue.rounded())
            return "\(record.reps) Wdh (vorher \(prev) Wdh)"

        case .maxHoldSeconds:
            let prev = Int(record.previousValue.rounded())
            return "\(record.reps) Sek (vorher \(prev) Sek)"

        case .estimated1RM, .heaviestWeight, .bestSet:
            let weightStr = formatWeight(record.weightKg)
            let prevStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.previousValue)) kg-Vol"
                default:              return "\(formatWeight(record.previousValue)) kg"
                }
            }()
            let nowStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.newValue)) kg-Vol"
                default:              return "\(formatWeight(record.newValue)) kg"
                }
            }()
            return "\(weightStr) kg × \(record.reps) → \(nowStr) (vorher \(prevStr))"
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatDelta(_ percent: Double) -> String {
        // Round to nearest %, integer display
        "\(Int((percent * 100).rounded())) %"
    }
}

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
    @Bindable var log: ExerciseLog
    let exercise: Exercise
    /// DEL-032: im History-Edit-Mode wird die Row zu editierbaren TextFields.
    let isEditable: Bool

    var body: some View {
        if isEditable {
            editRow
        } else {
            readOnlyRow
        }
    }

    /// Anzeigemodus — gleicher Text wie vor DEL-032.
    private var readOnlyRow: some View {
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

    /// DEL-032 Edit-Modus: Gewicht/Reps als TextField + RIR als Stepper.
    /// Layout-Lite — nur das Wesentliche, Form-Layout uebernimmt das Sectioning.
    @ViewBuilder
    private var editRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Satz \(log.setIndex + 1)")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                if !exercise.isCardio && !exercise.isTimeBased {
                    weightField
                }
                repsField
                rirStepper
            }
        }
        .padding(.vertical, 4)
    }

    private var weightField: some View {
        HStack(spacing: 4) {
            TextField("kg", value: $log.weight, format: .number)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("kg").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var repsField: some View {
        HStack(spacing: 4) {
            TextField(exercise.isTimeBased ? "Sek" : "Wdh", value: $log.reps, format: .number)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Text(exercise.isTimeBased ? "Sek" : "Wdh").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var rirStepper: some View {
        Stepper(value: $log.rir, in: 0...10, step: 0.5) {
            Text("RIR \(formatRIR(log.rir))")
                .font(.caption)
                .monospacedDigit()
        }
        .labelsHidden()
        .overlay(alignment: .leading) {
            Text("RIR \(formatRIR(log.rir))")
                .font(.caption)
                .monospacedDigit()
                .offset(x: -40)
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
