#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import FitnessAppCore
import FitnessAppData

/// Home screen — landing surface answering three questions on app open:
///   1. Where am I (latest weight + body-fat + FFMI)?
///   2. What's next (today's training day from the active plan)?
///   3. What did I do recently (last completed workouts + weight trend)?
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    /// Reverse-chronological so `.first` is the latest measurement.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @Query private var profiles: [UserBodyProfile]

    @Query(filter: #Predicate<TrainingPlan> { $0.isActive == true })
    private var activePlans: [TrainingPlan]

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completedSessions: [WorkoutSession]

    /// Trophy-Room teaser uses this to show count + latest exercise.
    /// Reverse-sort so `.first` is the most recent PR.
    @Query(sort: \PersonalRecordEntry.date, order: .reverse)
    private var personalRecords: [PersonalRecordEntry]

    /// DEL-042: laufende, nicht-abgeschlossene Sessions. Wenn `.first` nicht
    /// nil ist, gibt's eine offene Session, die der User entweder fortsetzen
    /// oder verwerfen sollte. Die PlanDayCard adaptiert daraufhin den
    /// Start-Button-Text + Farbe, und beim Klick auf eine andere-Plan-Session
    /// erscheint ein Conflict-Dialog.
    @Query(filter: #Predicate<WorkoutSession> {
        $0.isCompleted == false && $0.isRestDay == false
    }, sort: \WorkoutSession.startTime, order: .reverse)
    private var openSessions: [WorkoutSession]

    /// DEL-042: ConfirmationDialog-State fuer den Konflikt-Pfad.
    /// pendingNewStart-Closure wird aufgerufen wenn der User "Altes verwerfen"
    /// waehlt — sie liefert die Aktion fuer einen frischen Insert.
    @State private var showingActiveSessionConflict = false
    @State private var pendingNewStart: (() -> Void)?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroMetrics
                planDayCard
                trophyRoomCard
                historyCard
                trendChart
                compoundLiftChart
                recentWorkoutsCard
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("Dashboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: MeasurementView()) {
                    Label("Neue Messung", systemImage: "plus.circle.fill")
                }
            }
        }
        // DEL-042: Conflict-Dialog wenn der User in Plan A starten will,
        // waehrend in Plan B noch eine offene Session lebt.
        .confirmationDialog(
            "Aktives Training gefunden",
            isPresented: $showingActiveSessionConflict,
            titleVisibility: .visible
        ) {
            Button("Altes verwerfen & Neu starten", role: .destructive) {
                discardOtherOpenSessionsAndStartNew()
            }
            Button("Altes fortsetzen") {
                resumeAnyOpenFromConflict()
            }
            Button("Abbrechen", role: .cancel) {
                pendingNewStart = nil
            }
        } message: {
            if let open = openSessions.first {
                Text("Es läuft noch eine Session vom \(open.startTime.formatted(.relative(presentation: .named))) (\(open.dayName ?? "Unbekannt")). Was möchtest du tun?")
            } else {
                Text("Es gibt bereits eine offene Trainings-Session.")
            }
        }
    }

    // MARK: - Trophy Room teaser

    /// Compact entry-point to `PRHistoryView`. Counts personal-record entries
    /// across the store and shows the latest exercise that produced one — gives
    /// the user something to tap on even when the rest of the dashboard is dense.
    private var trophyRoomCard: some View {
        NavigationLink {
            PRHistoryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.yellow.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trophy Room")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if prCount == 0 {
                        Text("Noch keine PRs — beende ein Workout, um den ersten zu setzen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(prCount) Rekorde\(latestPRSummary.map { " • \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var prCount: Int { personalRecords.count }

    /// "Bankdrücken vor 2 Tagen" — short last-PR teaser when the table has rows.
    private var latestPRSummary: String? {
        guard let latest = personalRecords.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: latest.date, relativeTo: Date())
        return "\(latest.exerciseName) \(relative)"
    }

    // MARK: - History teaser (DEL-019)

    /// Prominent entry point to the full WorkoutHistoryView. Mirror der Trophy-
    /// Room-Card: kompakt, klickbar, mit Count und letztem-Workout-Teaser.
    /// Vorher war die History nur ueber "Alle anzeigen" am Ende der Recent-
    /// Workouts-Sektion erreichbar — User-Feedback war "find ich nicht".
    private var historyCard: some View {
        NavigationLink {
            WorkoutHistoryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trainingsverlauf")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(historyTeaserText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var historyTeaserText: String {
        let real = completedSessions.filter { !$0.isRestDay }
        if real.isEmpty {
            return "Noch keine Trainings — starte oben dein erstes."
        }
        if let latest = real.first {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: latest.startTime, relativeTo: Date())
            return "\(real.count) Trainings • zuletzt \(relative)"
        }
        return "\(real.count) Trainings"
    }

    // MARK: - Hero metrics

    private var heroMetrics: some View {
        Group {
            if let latest = measurements.first {
                HStack(spacing: 12) {
                    MetricCard(
                        label: "Gewicht",
                        value: latest.weightKg.truncated(to: 2).formattedTwoDecimals,
                        unit: "kg",
                        delta: weeklyWeightDelta()
                    )
                    MetricCard(
                        label: "KFA Navy",
                        value: latest.navyBodyFatPct?.truncated(to: 2).formattedTwoDecimals ?? "—",
                        unit: latest.navyBodyFatPct != nil ? "%" : nil,
                        delta: nil
                    )
                    MetricCard(
                        label: "FFMI",
                        value: latest.ffmi?.truncated(to: 2).formattedTwoDecimals ?? "—",
                        unit: nil,
                        delta: nil
                    )
                }
            } else {
                EmptyMetricsCard()
            }
        }
    }

    /// Thin glue over `BodyCalculations.weeklyWeightDelta`. The Core algorithm
    /// is widget/watch-shareable; this view-side wrapper just adapts the @Query
    /// result to the value-type API.
    private func weeklyWeightDelta() -> Double? {
        BodyCalculations.weeklyWeightDelta(measurements: measurements)
    }

    // MARK: - Trend chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Gewichts-Trend")
                    .font(.headline)
                Spacer()
                if !forecastPoints.isEmpty {
                    Text("Prognose 4 / 8 W.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if measurements.isEmpty {
                EmptyTrendCard()
            } else if measurements.count < 3 {
                InsufficientDataCard(currentCount: measurements.count)
            } else {
                Chart {
                    // Historical points + connecting line.
                    ForEach(historicalPoints, id: \.date) { p in
                        LineMark(
                            x: .value("Datum", p.date),
                            y: .value("Gewicht (kg)", p.weight),
                            series: .value("Serie", "Tatsächlich")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Datum", p.date),
                            y: .value("Gewicht (kg)", p.weight)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(40)
                    }

                    // Forecast: starts at the last historical point so the line stays
                    // continuous, then extends to +4w and (when reliable) +8w.
                    if !forecastPoints.isEmpty {
                        ForEach(forecastPoints, id: \.date) { p in
                            LineMark(
                                x: .value("Datum", p.date),
                                y: .value("Gewicht (kg)", p.weight),
                                series: .value("Serie", "Prognose")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                    }

                    // Goal-weight reference line if the user set one in onboarding.
                    if let goal = profiles.first?.goalWeightKg {
                        RuleMark(y: .value("Ziel", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(.green.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Ziel \(goal.truncated(to: 2).formattedTwoDecimals) kg")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 220)

                if isTrendUnreliable {
                    Label("Werte schwanken stark — Prognose ausgeblendet, bis sich der Trend stabilisiert.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if forecastPoints.isEmpty && measurements.count >= 3 {
                    Label("Mehr Werte über mind. 1 Woche für eine Prognose nötig.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Chronologically-ordered historical points (Charts wants left-to-right by date).
    private var historicalPoints: [(date: Date, weight: Double)] {
        measurements.reversed().map { ($0.date, $0.weightKg) }
    }

    /// Forecast series: anchors at the last historical point, then extends to +4w (and
    /// +8w when both projections are available). Empty when the trend is unreliable
    /// or `projectWeightTrend` returns nil — caller branches on that.
    private var forecastPoints: [(date: Date, weight: Double)] {
        guard !isTrendUnreliable,
              let lastHistorical = measurements.first
        else { return [] }

        let anchor = (date: lastHistorical.date, weight: lastHistorical.weightKg)
        let p4 = BodyCalculations.projectWeightTrend(measurements: measurements, weeksAhead: 4)
        let p8 = BodyCalculations.projectWeightTrend(measurements: measurements, weeksAhead: 8)

        var points: [(date: Date, weight: Double)] = [anchor]
        if let p4 {
            points.append((date: lastHistorical.date.addingTimeInterval(4 * 7 * 24 * 3600), weight: p4))
        }
        if let p8 {
            points.append((date: lastHistorical.date.addingTimeInterval(8 * 7 * 24 * 3600), weight: p8))
        }
        // Just the anchor isn't a useful "forecast line".
        return points.count >= 2 ? points : []
    }

    private var isTrendUnreliable: Bool {
        BodyCalculations.isTrendUnreliable(measurements: measurements)
    }

    // MARK: - Plan Day Card ("Was steht heute an?")

    @ViewBuilder
    private var planDayCard: some View {
        if let plan = activePlans.first, !plan.days.isEmpty {
            let day = nextScheduledDay(in: plan)
            // Nur explizit als .rest markierte Tage gelten als Ruhetag.
            // Leere Trainingstage (User noch nicht fertig konfiguriert) sind
            // KEINE Ruhetage — sie zeigen den disabled "Training starten"-
            // Button mit Hint, dass Uebungen fehlen (DEL-021/023).
            let isRestDay = day.type == .rest
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: isRestDay ? "bed.double.fill" : "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background((isRestDay ? Color.purple : Color.blue).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRestDay ? "Heute: Ruhetag" : "Nächstes Training")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(day.name)
                            .font(.title3.weight(.bold))
                    }
                    Spacer()
                }

                if isRestDay {
                    Text("Regeneration ist Teil des Plans. Wenn du den Tag durch hast, hak ihn ab — dann zeigt dir das Dashboard morgen das nächste echte Training.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if !day.exercises.isEmpty {
                    Text(exercisesPreview(for: day))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if isRestDay {
                    Button {
                        markRestDaySkipped(plan: plan, day: day)
                    } label: {
                        HStack {
                            Spacer()
                            Label("Ruhetag abschließen", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.purple.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                } else {
                    // DEL-042: Button-State adaptiv. Wenn offene Session
                    // existiert: orange "Fortsetzen"-Button, navigiert in die
                    // existing Session. Sonst: blauer "Direkt starten".
                    activeWorkoutButton(plan: plan, day: day)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            // No active plan or active plan has no days yet.
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activePlans.isEmpty ? "Kein aktiver Plan" : "Plan noch leer")
                        .font(.body.weight(.semibold))
                    Text(activePlans.isEmpty
                         ? "Lege im Plan-Tab deinen ersten Trainings-Plan an."
                         : "Füge deinem aktiven Plan im Plan-Tab Tage und Übungen hinzu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Plan-Tab") {
                    navigation.selectedTab = .plan
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    /// Sequential-rotation pick. Delegates to `PlanNavigator` (Core) so widgets
    /// + watch can reuse the exact same logic without dragging FitnessAppData in.
    private func nextScheduledDay(in plan: TrainingPlan) -> TrainingDay {
        let sortedDays = PlanNavigator.sortByWeekdayMondayFirst(plan.days)
        let completedCount = completedSessions.filter {
            $0.day?.plan?.persistentModelID == plan.persistentModelID
        }.count
        let idx = PlanNavigator.nextScheduledIndex(
            dayCount: sortedDays.count,
            completedSessions: completedCount
        ) ?? 0
        return sortedDays[idx]
    }

    private func exercisesPreview(for day: TrainingDay) -> String {
        let names = day.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map(\.name)
        let suffix = day.exercises.count > 3 ? " …" : ""
        return "\(day.exercises.count) Übungen — \(names.joined(separator: ", "))\(suffix)"
    }

    /// DEL-042: Adaptive Start-Button. Drei States:
    ///   1. Keine offene Session       → "Direkt starten" (blau, neu)
    ///   2. Offene Session AUF DEM-Tag → "Fortsetzen" (orange, navigiert in
    ///      die existing Session — kein neuer Insert)
    ///   3. Offene Session AUF ANDEREM Tag → "Direkt starten" (blau), aber
    ///      Klick triggert Conflict-Dialog mit drei Optionen.
    @ViewBuilder
    private func activeWorkoutButton(plan: TrainingPlan, day: TrainingDay) -> some View {
        let matchingOpen = openSessionForDay(day)
        let hasOtherOpen = matchingOpen == nil && !openSessions.isEmpty

        Button {
            if let open = matchingOpen {
                // Direkt fortsetzen — keine neue Session.
                resumeSession(open, plan: plan)
            } else if hasOtherOpen {
                // Konflikt: andere-Plan-Session offen. Vorberbereitung der
                // "Neu starten"-Action, dann Dialog zeigen.
                pendingNewStart = {
                    actuallyStartNewWorkout(plan: plan, day: day)
                }
                showingActiveSessionConflict = true
            } else {
                actuallyStartNewWorkout(plan: plan, day: day)
            }
        } label: {
            HStack {
                Spacer()
                Label(
                    matchingOpen != nil ? "Laufendes Training fortsetzen" : "Direkt starten",
                    systemImage: matchingOpen != nil ? "play.circle.fill" : "play.fill"
                )
                .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 10)
            .background((matchingOpen != nil ? Color.orange : Color.blue).gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Liefert eine offene Session, deren `.day` mit dem uebergebenen Day
    /// uebereinstimmt — fuer den "Fortsetzen"-Pfad.
    private func openSessionForDay(_ day: TrainingDay) -> WorkoutSession? {
        openSessions.first { $0.day?.persistentModelID == day.persistentModelID }
    }

    /// Navigiert in die existing offene Session, OHNE eine neue zu erstellen.
    private func resumeSession(_ session: WorkoutSession, plan: TrainingPlan) {
        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(plan)
        if let day = session.day {
            navigation.workoutPath.append(day)
        }
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// Verwirft alle ANDEREN offenen Sessions + startet eine neue. Wird vom
    /// ConfirmationDialog im Conflict-Path aufgerufen.
    private func discardOtherOpenSessionsAndStartNew() {
        for open in openSessions {
            modelContext.delete(open)
        }
        try? modelContext.save()
        pendingNewStart?()
        pendingNewStart = nil
    }

    /// Resume-Pfad fuer den Conflict-Dialog: springt in die existing Session
    /// (welche auch immer die juengste offene ist).
    private func resumeAnyOpenFromConflict() {
        guard let open = openSessions.first else { return }
        let plan = open.day?.plan ?? activePlans.first
        if let plan {
            resumeSession(open, plan: plan)
        }
        pendingNewStart = nil
    }

    /// Deep-link from Dashboard into ActiveWorkout: build a stack [plan, day, active]
    /// on the workout tab so the user can back out to DayEditor (after Discard) or
    /// PlanEditor without losing context.
    private func actuallyStartNewWorkout(plan: TrainingPlan, day: TrainingDay) {
        guard !day.exercises.isEmpty else { return }

        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: day.exercises.count,
            isCompleted: false,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)

        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(plan)
        navigation.workoutPath.append(day)
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// Erzeugt eine "skipped"-WorkoutSession fuer einen Ruhetag. Die Session
    /// ist `isCompleted=true` (damit der PlanNavigator-Pointer auf den
    /// naechsten echten Tag advanced), `isRestDay=true` (damit History,
    /// Trophy-Room und Recent-Workouts-Card sie nicht anzeigen).
    private func markRestDaySkipped(plan: TrainingPlan, day: TrainingDay) {
        let now = Date()
        let session = WorkoutSession(
            startTime: now,
            endTime: now,
            durationMinutes: 0,
            exerciseCount: 0,
            totalSets: 0,
            totalVolumeKg: 0,
            isCompleted: true,
            isRestDay: true,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)
    }

    // MARK: - Compound Lift Chart

    /// Names of the five canonical compound lifts (matches `isSystemCompound: true`
    /// in `ExerciseLibraryData`). Hard-coded here so the dashboard doesn't need to
    /// query the seed library at every render.
    private static let compoundLiftNames = [
        "Kniebeuge",
        "Bankdrücken",
        "Kreuzheben (konventionell)",
        "Schulterdrücken (stehend)",
        "Rudern vorgebeugt"
    ]

    /// One series per compound lift. Each series carries one point per session
    /// (the best estimated 1RM of any set in that session). Lifts with fewer
    /// than 2 data points are dropped — a "trend" needs at least two sessions.
    private var compoundSeries: [CompoundSeries] {
        let liftNames = Set(Self.compoundLiftNames)

        return Self.compoundLiftNames.compactMap { name in
            // All logs across all completed sessions for this lift
            let liftLogs = completedSessions.flatMap { session in
                session.logs.filter { log in
                    log.exercise.map { liftNames.contains($0.name) && $0.name == name } ?? false
                }
            }

            // Group by session, pick best 1RM per session
            let bySession = Dictionary(grouping: liftLogs) { log in
                log.session?.persistentModelID
            }

            let points: [CompoundPoint] = bySession.compactMap { (_, logs) -> CompoundPoint? in
                let estimates = logs.compactMap { log -> Double? in
                    ExerciseCalculations.estimate1RMAverage(weightKg: log.weight, reps: log.reps)
                }
                guard let best = estimates.max(),
                      let firstDate = logs.map(\.date).min() else { return nil }
                return CompoundPoint(date: firstDate, oneRM: best)
            }
            .sorted { $0.date < $1.date }

            // Need ≥2 points for a meaningful line
            guard points.count >= 2 else { return nil }
            return CompoundSeries(exerciseName: name, points: points)
        }
    }

    @ViewBuilder
    private var compoundLiftChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Compound-Lift-Trend")
                    .font(.headline)
                Spacer()
                Text("Geschätztes 1RM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let series = compoundSeries
            if series.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Noch zu wenig Daten")
                            .font(.subheadline)
                        Text("Sobald du eine Compound-Übung in zwei Sessions geloggt hast, erscheint hier der Trend.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points) { point in
                            LineMark(
                                x: .value("Datum", point.date),
                                y: .value("1RM (kg)", point.oneRM),
                                series: .value("Lift", line.exerciseName)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(by: .value("Lift", line.exerciseName))
                            .symbol(by: .value("Lift", line.exerciseName))

                            PointMark(
                                x: .value("Datum", point.date),
                                y: .value("1RM (kg)", point.oneRM)
                            )
                            .foregroundStyle(by: .value("Lift", line.exerciseName))
                            .symbolSize(40)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 220)
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Recent workouts

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Workouts")
                    .font(.headline)
                Spacer()
                if completedSessions.contains(where: { !$0.isRestDay }) {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Text("Alle anzeigen")
                            .font(.subheadline)
                    }
                }
            }

            // Rest-day-marker sessions don't count as "Trainingseinheiten".
            let realRecentSessions = completedSessions.filter { !$0.isRestDay }
            if realRecentSessions.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Noch keine Trainingseinheiten")
                            .font(.subheadline)
                        Text("Starte oben dein erstes Training.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                let recent = Array(realRecentSessions.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { idx, session in
                        NavigationLink {
                            WorkoutSummaryView(session: session, isReadOnly: true)
                        } label: {
                            DashboardSessionRow(session: session)
                        }
                        .buttonStyle(.plain)

                        if idx < recent.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Compound Lift Chart data

@available(iOS 17.0, macOS 14.0, *)
struct CompoundPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let oneRM: Double
}

@available(iOS 17.0, macOS 14.0, *)
struct CompoundSeries: Identifiable {
    let id = UUID()
    let exerciseName: String
    let points: [CompoundPoint]
}

// MARK: - Recent-row subview

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.dayName ?? "Training")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                    Text("•")
                    Text("\(session.durationMinutes) Min")
                    Text("•")
                    Text("\(session.totalSets) Sätze")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct MetricCard: View {
    let label: String
    let value: String
    let unit: String?
    let delta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let delta {
                deltaLabel(delta)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func deltaLabel(_ delta: Double) -> some View {
        let prefix = delta > 0 ? "+" : (delta < 0 ? "" : "±")
        let formatted = abs(delta).truncated(to: 2).formattedTwoDecimals
        let arrow = delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus")
        return HStack(spacing: 2) {
            Image(systemName: arrow)
            Text("\(prefix)\(formatted) kg")
            Text("/ Wo.")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .monospacedDigit()
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EmptyMetricsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Noch keine Messungen", systemImage: "scalemass")
                .font(.headline)
            Text("Tippe auf '+' oben rechts, um deinen ersten Wert einzutragen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EmptyTrendCard: View {
    var body: some View {
        Label("Trag deine erste Messung ein, um den Trend zu sehen.",
              systemImage: "chart.line.uptrend.xyaxis")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct InsufficientDataCard: View {
    let currentCount: Int

    var body: some View {
        Label("\(currentCount) von 3 nötigen Messungen — Linear-Regression startet ab 3 Werten über mind. 1 Woche.",
              systemImage: "chart.line.uptrend.xyaxis")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard mit 6 Wochen Daten") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard ohne Daten (Empty State)") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Dashboard mit nur 1 Wert") {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewSeed.singleMeasurementContainer)
}
#endif
#endif
