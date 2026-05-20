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

    /// UX-202: gating fuer die Hero-Spring-In-Animation. Wird via .onAppear
    /// im Hero auf true gesetzt; im isReadOnly-Mode (History-Replay) sofort
    /// auf true, sodass das Celebration-Spring nur beim frischen Finish
    /// triggert.
    @State private var hasAppeared: Bool = false

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
            // UX-202: Achievements ueber den Stats — der User soll erst den
            // Reward sehen, dann die Zahlen analysieren. Read-Only-Replay
            // ueberspringt die Sektion, weil die Achievements zum Frisch-
            // Finish-Moment gehoeren (heaviestOfWeek waere im Replay stale
            // sobald die naechste Session in derselben Woche kommt).
            if !isReadOnly, !achievements.isEmpty {
                achievementsSection
            }
            if isEditingSets {
                editMetaSection
            }
            if !personalRecords.isEmpty {
                prSection
            }
            // DEL-052/053: Smart-Progression-Celebration nur im New-Mode, nicht
            // in History-Replays. Im History-Replay wuerden die Outcomes stale
            // sein (suggestedWeight wurde seither evtl. mehrfach weiter-geupdated).
            if !isReadOnly, !progressionOutcomes.isEmpty {
                progressionSection
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
                    Button {
                        if isEditingHistory {
                            // Beim Beenden vom Edit-Mode: totals neu berechnen
                            // + persistieren, falls der User Set-Werte angefasst hat.
                            recalculateSessionTotals()
                            try? modelContext.save()
                        }
                        isEditingHistory.toggle()
                    } label: {
                        Text(isEditingHistory
                             ? "summary.toolbar.done"
                             : "summary.toolbar.edit",
                             bundle: .module)
                    }
                }
            }
        }
    }

    private var navigationTitleText: String {
        if isReadOnly {
            return isEditingHistory
                ? String(localized: "summary.editTitle", bundle: .module)
                : String(localized: "summary.detailTitle", bundle: .module)
        }
        return String(localized: "summary.title", bundle: .module)
    }

    /// Im Edit-Mode bekommt der User Datum + Dauer als editierbare Felder.
    /// Wird oben in der List eingeblendet, ueber statsSection.
    private var editMetaSection: some View {
        Section {
            DatePicker(selection: $session.startTime,
                       displayedComponents: [.date, .hourAndMinute]) {
                Text("summary.date", bundle: .module)
            }
            Stepper(value: $session.durationMinutes, in: 0...600, step: 5) {
                LabeledContent {
                    Text(String(format: String(localized: "summary.durationMinutes", bundle: .module), session.durationMinutes))
                } label: {
                    Text("summary.duration", bundle: .module)
                }
            }
        } header: {
            Text("summary.editMeta.header", bundle: .module)
        } footer: {
            Text("summary.editMeta.footer", bundle: .module)
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

    /// DEL-051: snapshot-first. Logs ohne Snapshot UND ohne Live-Exercise
    /// werden uebersprungen, sonst greifen wir auf die persistierten Snapshot-
    /// Felder zu, sodass Plan-Side-Mutations die PR-Detection nicht stoeren.
    private var sessionLifts: [LiftAttempt] {
        session.logs.compactMap { log -> LiftAttempt? in
            guard let name = log.resolvedExerciseName else { return nil }
            return LiftAttempt(
                exerciseName: name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: log.resolvedIsCardio,
                isTimeBased: log.resolvedIsTimeBased,
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds
            )
        }
    }

    /// All logs from completed sessions OTHER than this one — the baseline against
    /// which `PRDetector` measures. DEL-051: nutzt Snapshot-Felder.
    private var historicalLifts: [LiftAttempt] {
        let thisSessionID = session.persistentModelID
        return allLogs.compactMap { log -> LiftAttempt? in
            guard let name = log.resolvedExerciseName,
                  let logSession = log.session,
                  logSession.isCompleted,
                  logSession.persistentModelID != thisSessionID
            else { return nil }
            return LiftAttempt(
                exerciseName: name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: log.resolvedIsCardio,
                isTimeBased: log.resolvedIsTimeBased,
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds
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
                Text("summary.section.personalRecords", bundle: .module)
            }
        } footer: {
            Text("summary.prFooter", bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: - DEL-052/053 Smart Auto-Progression

    /// Read-only re-evaluation der Progression-Outcomes. Read-only weil
    /// `ActiveWorkoutView.finishWorkout` bereits den Mutating-Pass gemacht
    /// hat — wir wollen die Celebration hier nur RENDERN, nicht
    /// weiterschieben.
    private var progressionOutcomes: [ProgressionApplicator.ProgressionOutcome] {
        ProgressionApplicator.evaluateOnly(for: session)
    }

    private var progressionSection: some View {
        Section {
            ForEach(progressionOutcomes) { outcome in
                ProgressionBadge(outcome: outcome)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(Color.deltiqOrange)
                Text("summary.section.progression", bundle: .module)
            }
        } footer: {
            Text("summary.progressionFooter", bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: - UX-202 Achievements (Workout-of-Week, Volume-of-Week, Streak)

    /// UX-202: nicht-PR Erfolge fuer den Reward-Moment. Read-only —
    /// `WorkoutAchievementDetector` macht alle Vergleiche aus den
    /// History-Sessions (`allLogs.compactMap(\.session)`) gegen die
    /// aktuelle Session.
    private var achievements: [WorkoutAchievementDetector.Achievement] {
        // History via Session-Set aus allLogs ableiten. Set-Dedup laeuft
        // ueber persistentModelID; minimaler Overhead, vermeidet einen
        // zweiten @Query.
        var seen: Set<PersistentIdentifier> = []
        var history: [WorkoutSession] = []
        for log in allLogs {
            guard let s = log.session,
                  !seen.contains(s.persistentModelID) else { continue }
            seen.insert(s.persistentModelID)
            history.append(s)
        }
        return WorkoutAchievementDetector.detect(
            session: session,
            history: history
        )
    }

    @ViewBuilder
    private var achievementsSection: some View {
        Section {
            ForEach(achievements) { ach in
                AchievementBadge(achievement: ach)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.deltiqOrange)
                Text("summary.achievements.section", bundle: .module)
            }
        }
    }

    // MARK: -

    private var heroSection: some View {
        // UX-202: Reward-Moment-Hero. Vorher: 60pt-Checkmark, statisch. Jetzt:
        //   * 88pt-Checkmark mit weicher Spring-In-Skalierung beim ersten
        //     Render (0.4 -> 1.0 in einer dampedDamping=0.55 Feder).
        //   * Subtle Glow via `.shadow` mit DeltiqOrange-Tint — gibt dem Icon
        //     den "leuchtenden Trophaeen"-Look ohne in Confetti zu verfallen.
        //   * Title-Typo eine Stufe groesser (.title.weight(.bold)) damit die
        //     Hierarchie unten in den Stat-Hero-Numbers fortgesetzt wirkt.
        // Read-Only-Replay (History-Detail) ueberspringt das Spring, weil
        // die Anim nur zum frischen Finish gehoert — beim Replay wuerde es
        // jedes Mal triggern und nervt.
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 88))
                    .symbolRenderingMode(.hierarchical)   // DEL-059
                    .foregroundStyle(.green)
                    .shadow(color: Color.deltiqOrange.opacity(0.35),
                            radius: hasAppeared ? 18 : 0,
                            x: 0, y: 0)
                    .scaleEffect(hasAppeared ? 1.0 : 0.4)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                Text("summary.hero.title", bundle: .module)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                if let dayName = session.dayName {
                    Text(dayName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .onAppear {
                if isReadOnly {
                    // Replay: skip the celebration spring, render final state.
                    hasAppeared = true
                    return
                }
                // Tiny 50ms delay damit das List-Layout zuerst settled — sonst
                // wirkt die Spring-Anim wie ein "schon-da-vor-dem-Render"-Pop.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.05)) {
                    hasAppeared = true
                }
            }
        }
    }

    /// UX-202: dreistufige Stat-Hierarchy.
    ///   * Hero-Stat: dominante Zahl (typisch Volumen-kg fuer Strength,
    ///     Distanz-km fuer Cardio). 56pt, rounded, monospacedDigit,
    ///     DeltiqOrange — der visuelle Anker der Karte.
    ///   * Sekundaer-Stats: Dauer + Saetze als kleinere Geschwister-
    ///     Stats. Bleiben drin damit die "Wie viel hab ich gemacht"-
    ///     Frage komplett beantwortet ist, aber konkurrieren nicht mehr
    ///     mit dem Hero um Aufmerksamkeit.
    private var statsSection: some View {
        Section {
            VStack(spacing: 20) {
                heroStatView
                Divider().opacity(0.6)
                HStack(spacing: 0) {
                    SummaryStat(label: String(localized: "active.stats.duration", bundle: .module),
                                value: formattedDuration)
                    statDivider
                    SummaryStat(label: String(localized: "active.stats.sets", bundle: .module),
                                value: "\(session.totalSets)")
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("summary.section.stats", bundle: .module)
        }
    }

    /// UX-202: Hero-Stat-Auswahl je nach Session-Kategorie.
    /// - Strength/Mixed → Volumen-kg (typischer Erfolgsindikator)
    /// - Cardio mit Distanz → km
    /// - Cardio ohne Distanz (Indoor-Bike, Time-only) → Minuten
    @ViewBuilder
    private var heroStatView: some View {
        let hero = heroStat
        VStack(spacing: 4) {
            Text(hero.value)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.deltiqOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(hero.unitKey, bundle: .module)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Repräsentiert den Hero-Wert + sein Unit-Label (lokalisiert).
    private struct HeroStat {
        let value: String
        let unitKey: LocalizedStringKey
    }

    private var heroStat: HeroStat {
        switch session.sessionCategory {
        case .pureCardio:
            let km = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
            if km > 0 {
                let str = km == km.rounded()
                    ? "\(Int(km))"
                    : km.truncated(to: 2).formattedTwoDecimals
                return HeroStat(value: str, unitKey: "summary.hero.unit.km")
            }
            return HeroStat(value: "\(session.durationMinutes)",
                            unitKey: "summary.hero.unit.minutes")
        case .mixed, .pureStrength:
            return HeroStat(value: formattedVolume, unitKey: "summary.hero.unit.volumeKg")
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
                Section {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("summary.note.label", bundle: .module)
                }
            }
        } else {
            Section {
                TextField(
                    text: Binding(
                        get: { session.notes ?? "" },
                        set: { session.notes = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text("summary.note.placeholder", bundle: .module),
                    axis: .vertical
                ) {
                    Text("summary.note.label", bundle: .module)
                }
                .lineLimit(3...8)
            } header: {
                Text("summary.note.label", bundle: .module)
            } footer: {
                Text("summary.note.footer", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var breakdownSections: some View {
        if exercisesWithLogs.isEmpty {
            Section {
                Text("summary.setsEmpty", bundle: .module)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } header: {
                Text("summary.setsHeader", bundle: .module)
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
                Text(exercise.displayName)
                Spacer()
                if let best = bestSet(in: logs) {
                    Text("\(String(localized: "summary.exercise.bestPrefix", bundle: .module)): \(formatSetSummary(best, exercise: exercise))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        } footer: {
            Text(formatBreakdownFooter(setsCount: logs.count, volume: formatVolume(logs)))
                .font(.footnote)
        }
    }

    /// DEL-126: i18n-Footer "X Satz/Sätze • Y kg Volumen". Plural-Branch wird
    /// via Namespace-Keys (`.one` / `.other`) statt Apple-Format-Pattern
    /// abgebildet — Xcode 26.4.1's `GenerateStringSymbols`-Step verschluckt
    /// sich an variations.plural in xcstrings (Build-Saga DEL-121).
    private func formatBreakdownFooter(setsCount: Int, volume: String) -> String {
        let key: String.LocalizationValue = setsCount == 1
            ? "summary.exercise.footer.one"
            : "summary.exercise.footer.other"
        let raw = String(localized: key, bundle: .module)
        return raw
            .replacingOccurrences(of: "%1$lld", with: "\(setsCount)")
            .replacingOccurrences(of: "%2$@",   with: volume)
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
            Text("summary.finishFooter", bundle: .module)
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
        let minUnit = String(localized: "unit.minutes.short", bundle: .module)
        return "\(mins) \(minUnit)"
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
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        if exercise.isCardio {
            return "\(log.reps) \(exercise.isTimeBased ? secUnit : repUnit)"
        }
        if exercise.isTimeBased {
            return "\(log.reps) \(secUnit)"
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
                .symbolRenderingMode(.hierarchical)   // DEL-059
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(kindColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .innerLightStroke(cornerRadius: 8)    // DEL-059

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
            // DEL-064: fastestPace ist lower-is-better — die Verbesserung
            // ist ein negativer Delta. Wir zeigen sie als positiv-formatiertes
            // Improvement, sonst sieht der Trophy-Pill aus wie ein Rueckschritt.
            Text(improvementPill)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    /// DEL-064: kind-aware Improvement-Prozent. Lower-is-better-Kinds
    /// (`.fastestPace`) invertieren den Delta-Vorzug.
    private var improvementPill: String {
        let isLowerBetter: Bool = (record.kind == .fastestPace)
        let raw = record.deltaPercent
        let improvement = isLowerBetter ? -raw : raw
        return "+\(formatDelta(improvement))"
    }

    private var kindIcon: String {
        switch record.kind {
        case .estimated1RM:     "bolt.fill"
        case .heaviestWeight:   "scalemass.fill"
        case .bestSet:          "chart.bar.fill"
        case .maxReps:          "arrow.up.arrow.down"
        case .maxHoldSeconds:   "stopwatch.fill"
        // DEL-064 Cardio-PRs
        case .longestDistance:  "figure.run.circle.fill"
        case .fastestPace:      "hare.fill"
        }
    }

    private var kindColor: Color {
        switch record.kind {
        case .estimated1RM:     .orange
        case .heaviestWeight:   .red
        case .bestSet:          .blue
        case .maxReps:          .purple
        case .maxHoldSeconds:   .yellow
        case .longestDistance:  Color.deltiqOrange
        case .fastestPace:      .green
        }
    }

    private var kindLabel: String {
        switch record.kind {
        case .estimated1RM:     String(localized: "pr.kind.estimated1RM",    bundle: .module)
        case .heaviestWeight:   String(localized: "pr.kind.heaviestWeight",  bundle: .module)
        case .bestSet:          String(localized: "pr.kind.bestSet",         bundle: .module)
        case .maxReps:          String(localized: "pr.kind.maxReps",         bundle: .module)
        case .maxHoldSeconds:   String(localized: "pr.kind.maxHoldSeconds",  bundle: .module)
        case .longestDistance:  String(localized: "pr.kind.longestDistance", bundle: .module)
        case .fastestPace:      String(localized: "pr.kind.fastestPace",     bundle: .module)
        }
    }

    /// Per-kind detail string. Three flavors:
    ///   - Weighted PRs: "X kg × Y → Z kg (vorher V kg)"  (or " kg-Vol" for bestSet)
    ///   - maxReps:      "Y Wdh → Y Wdh (vorher V Wdh)"   (weight always 0 here)
    ///   - maxHoldSeconds: "Y Sek → Y Sek (vorher V Sek)"
    private var detailLine: String {
        // DEL-126: alle Inline-Strings via xcstrings — Sek/Wdh/vorher/kg-Vol
        // mappen DE/EN/TR korrekt.
        let prev = String(localized: "pr.previousShort", bundle: .module)
        let volSfx = String(localized: "pr.volumeSuffix", bundle: .module)
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        switch record.kind {
        case .maxReps:
            let prevReps = Int(record.previousValue.rounded())
            return "\(record.reps) \(repUnit) (\(prev) \(prevReps) \(repUnit))"

        case .maxHoldSeconds:
            let prevSec = Int(record.previousValue.rounded())
            return "\(record.reps) \(secUnit) (\(prev) \(prevSec) \(secUnit))"

        case .estimated1RM, .heaviestWeight, .bestSet:
            let weightStr = formatWeight(record.weightKg)
            let prevStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.previousValue)) \(volSfx)"
                default:              return "\(formatWeight(record.previousValue)) kg"
                }
            }()
            let nowStr: String = {
                switch record.kind {
                case .bestSet:        return "\(formatWeight(record.newValue)) \(volSfx)"
                default:              return "\(formatWeight(record.newValue)) kg"
                }
            }()
            return "\(weightStr) kg × \(record.reps) → \(nowStr) (\(prev) \(prevStr))"

        // DEL-064 Cardio-PRs
        case .longestDistance:
            return "\(formatKm(record.newValue)) km (\(prev) \(formatKm(record.previousValue)) km)"
        case .fastestPace:
            return "\(formatPace(record.newValue)) (\(prev) \(formatPace(record.previousValue)))"
        }
    }

    /// DEL-064: km-Formatter — Integer wenn ganzzahlig, sonst 2 Nachkommastellen.
    private func formatKm(_ km: Double) -> String {
        km == km.rounded() ? "\(Int(km))" : km.truncated(to: 2).formattedTwoDecimals
    }

    /// DEL-064: Pace-Formatter (min/km Double → "5:42 /km"-String).
    private func formatPace(_ minutesPerKm: Double) -> String {
        guard minutesPerKm.isFinite, minutesPerKm > 0 else { return "—:——" }
        let total = Int((minutesPerKm * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }

    private func formatDelta(_ percent: Double) -> String {
        // Round to nearest %, integer display
        "\(Int((percent * 100).rounded())) %"
    }
}

// MARK: - UX-202 Achievement Badge

/// Eine Zeile in der UX-202-Achievements-Section. Visuell baut sie auf
/// dem gleichen Frame wie PRBadge + ProgressionBadge auf (36×36 Icon-
/// Square mit gradientem Tint + Title + Subtitle) — Konsistenz im
/// Reward-Layout, sodass User die drei Zell-Typen sofort als Achievement-
/// Familie wiedererkennt.
@available(iOS 17.0, macOS 14.0, *)
private struct AchievementBadge: View {
    let achievement: WorkoutAchievementDetector.Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .innerLightStroke(cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch achievement.kind {
        case .weeklyMilestone:           return "flame.fill"
        case .heaviestOfWeek:            return "scalemass.fill"
        case .longestOfWeek:             return "clock.badge.checkmark"
        case .longestDistanceOfWeek:     return "figure.run"
        }
    }

    private var tint: Color {
        switch achievement.kind {
        case .weeklyMilestone:           return .orange
        case .heaviestOfWeek:            return Color.deltiqOrange
        case .longestOfWeek:             return .blue
        case .longestDistanceOfWeek:     return .green
        }
    }

    private var title: String {
        switch achievement.kind {
        case .weeklyMilestone(let count):
            let raw = String(localized: "summary.achievements.weeklyMilestone.titleFormat",
                             bundle: .module)
            // Direct %lld substitution — Apple-Plural-Pattern wuerde an
            // Xcode-26.4.1's GenerateStringSymbols ersticken (DEL-121).
            return raw.replacingOccurrences(of: "%lld", with: "\(count)")
        case .heaviestOfWeek:
            return String(localized: "summary.achievements.heaviestOfWeek.title", bundle: .module)
        case .longestOfWeek:
            return String(localized: "summary.achievements.longestOfWeek.title", bundle: .module)
        case .longestDistanceOfWeek:
            return String(localized: "summary.achievements.longestDistanceOfWeek.title", bundle: .module)
        }
    }

    private var subtitle: String {
        switch achievement.kind {
        case .weeklyMilestone:
            return String(localized: "summary.achievements.weeklyMilestone.subtitle", bundle: .module)
        case .heaviestOfWeek:
            return String(localized: "summary.achievements.heaviestOfWeek.subtitle", bundle: .module)
        case .longestOfWeek:
            return String(localized: "summary.achievements.longestOfWeek.subtitle", bundle: .module)
        case .longestDistanceOfWeek:
            return String(localized: "summary.achievements.longestDistanceOfWeek.subtitle", bundle: .module)
        }
    }
}

// MARK: - DEL-052/053 Progression Badge

/// Eine Zeile in der Smart-Progression-Section von WorkoutSummary. Pro
/// Uebung zeigt sie das alte/neue Ziel-Gewicht (oder "Deload"-Hinweis) plus
/// einen kurzen Motivations-Text. Hold-Outcomes landen nicht hier (sie
/// kommen nicht vom Applicator).
@available(iOS 17.0, macOS 14.0, *)
private struct ProgressionBadge: View {
    let outcome: ProgressionApplicator.ProgressionOutcome

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)   // DEL-059
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .innerLightStroke(cornerRadius: 8)    // DEL-059

            VStack(alignment: .leading, spacing: 2) {
                Text(outcome.exerciseName)
                    .font(.body.weight(.semibold))
                Text(headlineText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detailText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Spacer()
            deltaPill
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch outcome.action {
        case .increaseWeight: return "arrow.up.right.circle.fill"
        case .deload:         return "arrow.down.right.circle.fill"
        case .hold:           return "minus.circle.fill"   // unreachable
        }
    }

    private var tint: Color {
        switch outcome.action {
        case .increaseWeight: return Color.deltiqOrange
        case .deload:         return .gray
        case .hold:           return .secondary
        }
    }

    private var headlineText: String {
        switch outcome.action {
        case .increaseWeight: return String(localized: "progression.headline.increase", bundle: .module)
        case .deload:         return String(localized: "progression.headline.deload",   bundle: .module)
        case .hold:           return ""
        }
    }

    /// Detail-Zeile: zeigt das neue Ziel-Gewicht plus den Delta-Hinweis.
    private var detailText: String {
        guard let newWeight = outcome.newSuggestedWeight else {
            // Defensive: ohne new-weight kann hoechstens "Schritt +X kg"
            // raus.
            return deltaString
        }
        return String(format: String(localized: "progression.detail.newTargetFormat", bundle: .module),
                      formatWeight(newWeight))
    }

    private var deltaPill: some View {
        Text(deltaString)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(outcome.action.weightDelta >= 0 ? Color.deltiqOrange : .secondary)
            .monospacedDigit()
    }

    private var deltaString: String {
        let delta = outcome.action.weightDelta
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
        let absVal = abs(delta)
        let valStr = absVal == absVal.rounded()
            ? "\(Int(absVal))"
            : absVal.truncated(to: 2).formattedTwoDecimals
        return "\(sign)\(valStr) kg"
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.truncated(to: 2).formattedTwoDecimals
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            // DEL-059: rounded-bold Zahl + winziges getrocknetes Label
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
            Text(label.uppercased()).deltiqLabel()
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
            Text(String(format: String(localized: "set.numberLabel", bundle: .module), log.setIndex + 1))
                .font(.subheadline.weight(.semibold))
                .frame(width: 64, alignment: .leading)

            Text(rowText)
                .font(.callout)
                .monospacedDigit()

            Spacer()
        }
    }

    /// DEL-032 Edit-Modus: Gewicht/Reps als TextField + RIR als Stepper.
    /// DEL-038 Layout-Fix: drei klar getrennte Spalten mit festen Frames,
    /// Spacer dazwischen statt der Overlay-Hack-Loesung von Welle 5.
    @ViewBuilder
    private var editRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "set.numberLabel", bundle: .module), log.setIndex + 1))
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                if !exercise.isCardio && !exercise.isTimeBased {
                    weightField
                    Divider().frame(height: 24)
                }
                repsField
                Spacer(minLength: 12)
                rirBlock
            }
        }
        .padding(.vertical, 6)
    }

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("kg", value: $log.weight, format: .number)
                .frame(width: 56)
                .multilineTextAlignment(.leading)
                .font(.title3.monospacedDigit())
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("kg").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var repsField: some View {
        // DEL-126: i18n-Sek/Wdh-Labels.
        let secUnit = String(localized: "unit.seconds.short", bundle: .module)
        let repUnit = String(localized: "unit.reps.short", bundle: .module)
        let unit = exercise.isTimeBased ? secUnit : repUnit
        return VStack(alignment: .leading, spacing: 2) {
            TextField(unit, value: $log.reps, format: .number)
                .frame(width: 48)
                .multilineTextAlignment(.leading)
                .font(.title3.monospacedDigit())
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// RIR-Block: Label oben, Stepper darunter — kein Overlay-Trick mehr.
    private var rirBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("RIR \(formatRIR(log.rir))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Stepper(value: $log.rir, in: 0...10, step: 0.5) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private var rowText: String {
        if exercise.isCardio {
            // DEL-058: Cardio-Set zeigt Distance / Duration / Pace statt
            // kg × reps. Auslassbar wenn keiner der Felder gefuellt.
            var parts: [String] = []
            if let d = log.distanceKm, d > 0 {
                let dStr = d == d.rounded() ? "\(Int(d))" : d.truncated(to: 2).formattedTwoDecimals
                parts.append("\(dStr) km")
            }
            if let s = log.durationSeconds, s > 0 {
                parts.append(PaceCalculator.formatDuration(s))
            }
            if let d = log.distanceKm, let s = log.durationSeconds, d > 0, s > 0 {
                parts.append(PaceCalculator.pace(distanceKm: d, durationSeconds: s))
            }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        }
        if exercise.isTimeBased {
            let secUnit = String(localized: "unit.seconds.short", bundle: .module)
            return "\(log.reps) \(secUnit) (RIR \(formatRIR(log.rir)))"
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
