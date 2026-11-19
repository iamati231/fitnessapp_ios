#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// DEL-Progress-02B: Ausdauer-Fortschritt.
///
/// Zeigt wöchentliche Laufdistanz, Pace-Trend und Überblickszahlen für
/// Cardio-Einheiten, gefiltert nach Periode (4W/12W/1J/Gesamt).
/// Berechnungslogik in `DeltiqCore.CardioProgressCalculator`.
@available(iOS 17.0, macOS 14.0, *)
public struct CardioProgressView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .forward)
    private var sessions: [WorkoutSession]

    @State private var period: CardioProgressCalculator.Period = .twelveWeeks

    public init() {}

    // MARK: - Projections

    private var distanceUnit: String { weightUnitRaw == "lbs" ? "mi" : "km" }
    private var distanceFactor: Double { distanceUnit == "mi" ? 0.621371 : 1.0 }
    // Pace converts inversely: longer/km → shorter/mi for the same speed.
    private var paceFactor: Double { distanceUnit == "mi" ? 1.609344 : 1.0 }

    private var allActivities: [TrainingActivity] {
        TrainingActivityExtractor.extract(from: sessions)
    }

    private var overviewStats: CardioProgressCalculator.OverviewStats {
        CardioProgressCalculator.overviewStats(activities: allActivities, period: period)
    }

    private var weeklyPoints: [CardioVolumeOverTimePoint] {
        CardioProgressCalculator.weeklyPoints(activities: allActivities, period: period)
    }

    private var hasRunData: Bool { overviewStats.sessionCount > 0 }
    private var hasOtherCardioOnly: Bool {
        overviewStats.sessionCount == 0 && overviewStats.otherCardioSessionCount > 0
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: "",
                title: loc("cardio.progress.title"),
                onBack: { dismiss() }
            )

            periodPicker

            if hasRunData {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewSection
                        distanceChartSection
                        if weeklyPoints.contains(where: { $0.averagePaceMinutesPerKm != nil }) {
                            paceChartSection
                        }
                    }
                    .padding(.bottom, 32)
                }
            } else if hasOtherCardioOnly {
                otherCardioOnlyState
            } else {
                ScrollView {
                    DashboardEmptyState(
                        icon: "heart.fill",
                        title: "cardio.progress.emptyTitle",
                        description: "cardio.progress.emptyDescription"
                    )
                    .deltiqCardStyle()
                    .padding(.top, 18)
                }
            }
        }
        .deltiqScreen()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Other-cardio-only state

    private var otherCardioOnlyState: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "figure.outdoor.cycle")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Text(loc("cardio.progress.noRunsTitle"))
                    .font(.headline)
                Text(String(format: loc("cardio.progress.noRunsDescription"),
                            overviewStats.otherCardioSessionCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .deltiqCardStyle()
            .padding(.top, 18)
        }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("", selection: $period) {
            ForEach(CardioProgressCalculator.Period.allCases) { p in
                Text(periodLabel(p)).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func periodLabel(_ p: CardioProgressCalculator.Period) -> String {
        switch p {
        case .fourWeeks:   return loc("strength.progress.period.4w")
        case .twelveWeeks: return loc("strength.progress.period.12w")
        case .oneYear:     return loc("strength.progress.period.1y")
        case .allTime:     return loc("strength.progress.period.all")
        }
    }

    // MARK: - Overview section

    private var overviewSection: some View {
        DeltiqSection(loc("cardio.progress.section.overview").uppercased()) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(value: "\(overviewStats.sessionCount)",
                         label: loc("strength.progress.overview.sessions"))
                statCell(value: formattedDistance(overviewStats.totalDistanceKm),
                         label: loc("cardio.progress.overview.distance"))
                if let longest = overviewStats.longestRunKm {
                    statCell(value: formattedDistance(longest),
                             label: loc("cardio.progress.overview.longestRun"))
                }
                if let pace = overviewStats.bestPaceMinPerKm {
                    statCell(value: formattedPace(pace),
                             label: loc("cardio.progress.overview.bestPace"))
                }
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

    // MARK: - Distance chart

    private var distanceChartSection: some View {
        DeltiqSection(loc("cardio.progress.chart.distance.title").uppercased()) {
            Chart {
                ForEach(weeklyPoints) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value(distanceUnit, point.runningDistanceKm * distanceFactor)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.8))
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
                        AxisValueLabel("\(Int(d)) \(distanceUnit)")
                    }
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Pace chart

    private var paceChartSection: some View {
        DeltiqSection(loc("cardio.progress.chart.pace.title").uppercased()) {
            Chart {
                ForEach(weeklyPoints) { point in
                    if let pace = point.averagePaceMinutesPerKm {
                        LineMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Pace", pace * paceFactor)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)

                        PointMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Pace", pace * paceFactor)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(36)
                    }
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
                        // d is already in the display unit (pace * paceFactor); do NOT convert again.
                        AxisValueLabel(formatPaceLabel(d))
                    }
                }
            }
            // Lower pace = faster: invert Y so improvement shows as upward trend.
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Text(loc("cardio.progress.chart.pace.disclaimer"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private func formattedDistance(_ km: Double) -> String {
        let v = km * distanceFactor
        return v >= 100
            ? String(format: "%.0f %@", v, distanceUnit)
            : String(format: "%.1f %@", v, distanceUnit)
    }

    /// Format a canonical min/km value, converting to the current unit.
    private func formattedPace(_ minPerKm: Double) -> String {
        formatPaceLabel(minPerKm * paceFactor)
    }

    /// Format a value that is already in the current pace unit (min/km or min/mi).
    /// Used for Y-axis labels whose values come from chart data already multiplied by paceFactor.
    private func formatPaceLabel(_ val: Double) -> String {
        let mins = Int(val)
        let secs = Int((val - Double(mins)) * 60)
        return String(format: "%d:%02d /%@", mins, secs, distanceUnit)
    }
}

#endif
