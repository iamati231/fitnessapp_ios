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

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroMetrics
                planDayCard
                trendChart
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

    /// Weight delta vs. the most recent measurement that's at least 6 days older.
    /// Returns nil if no such reference exists.
    private func weeklyWeightDelta() -> Double? {
        guard let latest = measurements.first else { return nil }
        let cutoff = latest.date.addingTimeInterval(-6 * 24 * 3600)
        guard let weekAgo = measurements.first(where: { $0.date <= cutoff }) else { return nil }
        return latest.weightKg - weekAgo.weightKg
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
                            series: .value("Serie", "Tatsaechlich")
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
                    Label("Mehr Werte ueber mind. 1 Woche fuer eine Prognose noetig.",
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Naechstes Training")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(day.name)
                            .font(.title3.weight(.bold))
                    }
                    Spacer()
                }

                if !day.exercises.isEmpty {
                    Text(exercisesPreview(for: day))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Button {
                    startWorkoutDeepLink(plan: plan, day: day)
                } label: {
                    HStack {
                        Spacer()
                        Label("Direkt starten", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(day.exercises.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(day.exercises.isEmpty)
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
                         : "Fuege deinem aktiven Plan im Plan-Tab Tage und Uebungen hinzu.")
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

    /// Sequential rotation: the next training day is `(completedSessionsForThisPlan
    /// % numberOfDays)`. Independent of weekday — works even for users who don't
    /// always train on the same days. Days are ordered by weekday with Monday first.
    private func nextScheduledDay(in plan: TrainingPlan) -> TrainingDay {
        let days = plan.days.sorted { weekdayOrder($0.weekday) < weekdayOrder($1.weekday) }
        let completedCount = completedSessions.filter {
            $0.day?.plan?.persistentModelID == plan.persistentModelID
        }.count
        let nextIndex = days.isEmpty ? 0 : completedCount % days.count
        return days[nextIndex]
    }

    private func exercisesPreview(for day: TrainingDay) -> String {
        let names = day.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map(\.name)
        let suffix = day.exercises.count > 3 ? " …" : ""
        return "\(day.exercises.count) Uebungen — \(names.joined(separator: ", "))\(suffix)"
    }

    /// Translate Calendar's Sun=1..Sat=7 into Mon=0..Sun=6 for European display order.
    private func weekdayOrder(_ weekday: Int) -> Int {
        weekday == 1 ? 6 : weekday - 2
    }

    /// Deep-link from Dashboard into ActiveWorkout: build a stack [plan, day, active]
    /// on the workout tab so the user can back out to DayEditor (after Discard) or
    /// PlanEditor without losing context.
    private func startWorkoutDeepLink(plan: TrainingPlan, day: TrainingDay) {
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

    // MARK: - Recent workouts

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Workouts")
                    .font(.headline)
                Spacer()
                if !completedSessions.isEmpty {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Text("Alle anzeigen")
                            .font(.subheadline)
                    }
                }
            }

            if completedSessions.isEmpty {
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
                let recent = Array(completedSessions.prefix(5))
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
                    Text("\(session.totalSets) Saetze")
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
        Label("\(currentCount) von 3 noetigen Messungen — Linear-Regression startet ab 3 Werten ueber mind. 1 Woche.",
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
