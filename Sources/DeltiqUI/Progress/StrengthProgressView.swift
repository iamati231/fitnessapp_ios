#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// DEL-Progress-02A: Kraftfortschritt-Übersicht.
///
/// Zeigt Trainingsüberblick (Sessions, Sätze, Volumen, PRs) gefiltert nach
/// Periode (4W/12W/1J/Gesamt) und eine priorisierte Übungsliste mit geschätztem
/// 1-Wiederholungsmaximum. Tippen auf eine Übung öffnet `StrengthExerciseDetailView`
/// mit 1RM-Trendchart und Bestleistungs-Tabelle.
///
/// Berechnungslogik liegt vollständig in `DeltiqCore.StrengthProgressCalculator`,
/// hier werden nur SwiftData-Objekte in Werttypen projiziert.
@available(iOS 17.0, macOS 14.0, *)
public struct StrengthProgressView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .forward)
    private var sessions: [WorkoutSession]

    @Query(sort: \PersonalRecordEntry.date, order: .forward)
    private var prEntries: [PersonalRecordEntry]

    @State private var period: StrengthProgressCalculator.Period = .twelveWeeks

    public init() {}

    // MARK: - Projections

    private var weightUnit: String { weightUnitRaw == "lbs" ? "lbs" : "kg" }

    private var allLogs: [StrengthProgressCalculator.StrengthLog] {
        sessions.flatMap { session in
            session.logs.compactMap { log -> StrengthProgressCalculator.StrengthLog? in
                guard let name = log.resolvedExerciseName, !name.isEmpty else { return nil }
                return StrengthProgressCalculator.StrengthLog(
                    sessionStartTime: session.startTime,
                    exerciseName: name,
                    templateID: log.resolvedExerciseTemplateID,
                    weightKg: log.weight,
                    reps: log.reps,
                    rpe: log.rpe,
                    rir: log.rir,
                    isCardio: log.resolvedIsCardio,
                    isTimeBased: log.resolvedIsTimeBased,
                    isPlaceholder: log.isEmptyPlaceholder,
                    logID: log.persistentModelID.hashValue.description
                )
            }
        }
    }

    // Logs filtered to the selected period — shared by overview, exercise list, and detail view.
    private var filteredLogs: [StrengthProgressCalculator.StrengthLog] {
        guard let cutoff = period.cutoff() else { return allLogs }
        return allLogs.filter { $0.sessionStartTime >= cutoff }
    }

    private var overviewStats: StrengthProgressCalculator.OverviewStats {
        let strengthPRs = prEntries.filter {
            StrengthProgressCalculator.isStrengthPRKind($0.kindRaw)
        }
        return StrengthProgressCalculator.overviewStats(
            logs: allLogs,
            strengthSessionDates: sessions.filter(\.containsStrengthWork).map(\.startTime),
            prDates: strengthPRs.map(\.date),
            period: period
        )
    }

    private var exerciseSummaries: [StrengthProgressCalculator.ExerciseSummary] {
        StrengthProgressCalculator.exerciseSummaries(logs: filteredLogs)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("strength.progress.eyebrow"),
                title: loc("strength.progress.title"),
                onBack: { dismiss() }
            )

            periodPicker

            if exerciseSummaries.isEmpty {
                ScrollView {
                    DashboardEmptyState(
                        icon: "dumbbell.fill",
                        title: "strength.progress.emptyTitle",
                        description: "strength.progress.emptyDescription"
                    )
                    .deltiqCardStyle()
                    .padding(.top, 18)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewSection
                        exercisesSection
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .deltiqScreen()
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("", selection: $period) {
            ForEach(StrengthProgressCalculator.Period.allCases) { p in
                Text(periodLabel(p)).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func periodLabel(_ p: StrengthProgressCalculator.Period) -> String {
        switch p {
        case .fourWeeks:   return loc("strength.progress.period.4w")
        case .twelveWeeks: return loc("strength.progress.period.12w")
        case .oneYear:     return loc("strength.progress.period.1y")
        case .allTime:     return loc("strength.progress.period.all")
        }
    }

    // MARK: - Overview section

    private var overviewSection: some View {
        DeltiqSection(loc("strength.progress.section.overview").uppercased()) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(value: "\(overviewStats.sessionCount)",
                         label: loc("strength.progress.overview.sessions"))
                statCell(value: "\(overviewStats.workSetCount)",
                         label: loc("strength.progress.overview.sets"))
                statCell(value: formattedVolume(overviewStats.volumeKg),
                         label: loc("strength.progress.overview.volume"))
                statCell(value: "\(overviewStats.prCount)",
                         label: loc("strength.progress.overview.prs"))
            }
            .padding(16)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formattedVolume(_ kg: Double) -> String {
        // Bodyweight-only sessions produce sets but zero external weight — show "—" not "0 kg".
        if kg == 0 { return "—" }
        let v = weightUnit == "lbs" ? kg * 2.20462 : kg
        return v >= 1000
            ? String(format: "%.1f k%@", v / 1000, weightUnit)
            : String(format: "%.0f %@", v, weightUnit)
    }

    // MARK: - Exercises section

    private var exercisesSection: some View {
        DeltiqSection(loc("strength.progress.section.exercises").uppercased()) {
            ForEach(Array(exerciseSummaries.enumerated()), id: \.element.id) { index, summary in
                NavigationLink {
                    StrengthExerciseDetailView(
                        summary: summary, logs: filteredLogs, weightUnit: weightUnit)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(sessionCountLabel(summary.sessionCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let rm = summary.best1RMKg {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formattedWeightKg(rm))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("1RM*")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if index < exerciseSummaries.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    private func sessionCountLabel(_ count: Int) -> String {
        count == 1
            ? loc("strength.progress.exercise.sessions.one")
            : String(format: loc("strength.progress.exercise.sessions.other"), count)
    }

    private func formattedWeightKg(_ kg: Double) -> String {
        let v = weightUnit == "lbs" ? kg * 2.20462 : kg
        return String(format: "%.1f %@", v, weightUnit)
    }
}

// MARK: - Exercise Detail

/// Detailansicht einer Übung: 1RM-Trendchart + Bestleistungs-Tabelle.
/// Tippen auf einen Chart-Punkt blendet eine Callout-Zeile ein.
@available(iOS 17.0, macOS 14.0, *)
struct StrengthExerciseDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let summary: StrengthProgressCalculator.ExerciseSummary
    let logs: [StrengthProgressCalculator.StrengthLog]
    let weightUnit: String

    @State private var selectedPoint: StrengthProgressCalculator.OneRMPoint?

    private var points: [StrengthProgressCalculator.OneRMPoint] {
        StrengthProgressCalculator.oneRMHistory(
            logs: logs, exerciseName: summary.name, templateID: summary.templateID)
    }

    private var bestSets: [StrengthProgressCalculator.SetDetail] {
        StrengthProgressCalculator.bestSets(
            logs: logs, exerciseName: summary.name, templateID: summary.templateID)
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("strength.progress.eyebrow"),
                title: summary.name,
                onBack: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !points.isEmpty {
                        oneRMSection
                    }
                    if !bestSets.isEmpty {
                        bestSetsSection
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .deltiqScreen()
        .deltiqSwipeBackEnabled()
    }

    // MARK: - 1RM section

    private var oneRMSection: some View {
        DeltiqSection(loc("strength.progress.chart.oneRM.title").uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("1RM", displayWeight(point.estimatedKg))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("1RM", displayWeight(point.estimatedKg))
                        )
                        .foregroundStyle(selectedPoint?.id == point.id ? Color.primary : Color.accentColor)
                        .symbolSize(selectedPoint?.id == point.id ? 100 : 36)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        if let d = v.as(Double.self) {
                            AxisValueLabel("\(Int(d)) \(weightUnit)")
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Color.clear.contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    if let frame = proxy.plotFrame {
                                        let x = val.location.x - geo[frame].origin.x
                                        if let date = proxy.value(atX: x, as: Date.self) {
                                            selectedPoint = closestPoint(to: date)
                                        }
                                    }
                                }
                                // No onEnded: callout stays visible until a new point is tapped.
                            )
                    }
                }

                if let sel = selectedPoint {
                    selectedCallout(sel)
                        .transition(.opacity)
                }

                Text(loc("strength.progress.chart.oneRM.disclaimer"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private func selectedCallout(_ point: StrengthProgressCalculator.OneRMPoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date, format: .dateTime.day().month().year())
                    .font(.caption.weight(.medium))
                Text(setLabel(weightKg: point.weightKg, reps: point.reps, isTimeBased: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if point.rpe > 0 {
                pill("RPE \(String(format: "%.0f", point.rpe))")
            }
            if point.rir >= 0 {
                pill("\(String(format: "%.0f", Double(point.rir))) RIR")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - Best sets section

    private var bestSetsSection: some View {
        DeltiqSection(loc("strength.progress.section.bestSets").uppercased()) {
            ForEach(Array(bestSets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.sessionDate, format: .dateTime.day().month(.abbreviated).year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(setLabel(weightKg: set.weightKg, reps: set.reps, isTimeBased: set.isTimeBased))
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if set.rpe > 0 { pill("RPE \(String(format: "%.0f", set.rpe))") }
                        if set.rir >= 0 { pill("\(String(format: "%.0f", Double(set.rir))) RIR") }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                if index < bestSets.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    // MARK: - Helpers

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }

    private func setLabel(weightKg: Double, reps: Int, isTimeBased: Bool) -> String {
        if isTimeBased { return "\(reps) \(loc("unit.seconds.short"))" }
        if weightKg > 0 { return "\(displayWeightStr(weightKg)) × \(reps)" }
        return "\(reps) \(loc("unit.reps.short"))"
    }

    private func displayWeight(_ kg: Double) -> Double {
        weightUnit == "lbs" ? kg * 2.20462 : kg
    }

    private func displayWeightStr(_ kg: Double) -> String {
        String(format: "%.1f %@", displayWeight(kg), weightUnit)
    }

    private func closestPoint(to date: Date) -> StrengthProgressCalculator.OneRMPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

#endif
