#if canImport(SwiftUI)
import SwiftUI
import Charts
import DeltiqCore

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// DEL-Progress-02C: Wochenverlauf einer einzelnen Muskelgruppe.
///
/// Zeigt einen Balken-Chart mit wöchentlichen Arbeitssätzen + den Volume-Bucket-
/// Hinweis. Navigation via `MuscleVolumeProgressView.selectedMuscle`.
@available(iOS 17.0, macOS 14.0, *)
public struct MuscleGroupDetailView: View {

    @Environment(\.dismiss) private var dismiss

    public let muscle: MuscleGroup
    public let allSets: [MuscleGroupProgressCalculator.MuscleLoggedSet]

    @State private var period: MuscleGroupProgressCalculator.Period

    public init(
        muscle: MuscleGroup,
        allSets: [MuscleGroupProgressCalculator.MuscleLoggedSet],
        initialPeriod: MuscleGroupProgressCalculator.Period = .twelveWeeks
    ) {
        self.muscle = muscle
        self.allSets = allSets
        _period = State(initialValue: initialPeriod)
    }

    // MARK: - Projections

    private var weeklyPoints: [(weekStart: Date, sets: Int)] {
        MuscleGroupProgressCalculator.weeklyPointsForMuscle(
            muscle, sets: allSets, period: period
        )
    }

    private var totalSets: Int { weeklyPoints.reduce(0) { $0 + $1.sets } }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("muscle.progress.eyebrow"),
                title: String(localized: muscle.localizedName),
                onBack: { dismiss() }
            )

            periodPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statsRow
                    chartSection
                    bucketHint
                }
                .padding(.bottom, 32)
            }
        }
        .deltiqScreen()
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("", selection: $period) {
            ForEach(MuscleGroupProgressCalculator.Period.allCases) { p in
                Text(periodLabel(p)).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func periodLabel(_ p: MuscleGroupProgressCalculator.Period) -> String {
        switch p {
        case .fourWeeks:   return loc("strength.progress.period.4w")
        case .twelveWeeks: return loc("strength.progress.period.12w")
        case .oneYear:     return loc("strength.progress.period.1y")
        case .allTime:     return loc("strength.progress.period.all")
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        DeltiqSection("") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalSets)")
                        .font(.title2.weight(.bold))
                    Text(loc("muscle.progress.overview.totalSets"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(bucketLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(bucketColor)
                    Text(loc("muscle.progress.detail.currentWeek"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
        }
    }

    private var currentBucket: MuscleVolumeBucket {
        let thisWeekSets = weeklyPoints.last?.sets ?? 0
        return MuscleVolumeBucket(setsThisWeek: thisWeekSets)
    }

    private var bucketLabel: String { currentBucket.label }

    private var bucketColor: Color {
        switch currentBucket {
        case .untrained:    return .secondary
        case .maintenance:  return Color.orange.opacity(0.8)
        case .optimal:      return Color.deltiqOrange
        case .overreaching: return .red
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        DeltiqSection(loc("muscle.progress.detail.chart.title").uppercased()) {
            Chart {
                ForEach(weeklyPoints, id: \.weekStart) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Sets", point.sets)
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
                    if let n = v.as(Int.self) {
                        AxisValueLabel("\(n)")
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityLabel("\(String(localized: muscle.localizedName)) \(loc("muscle.progress.detail.chart.title"))")
        }
    }

    // MARK: - Bucket hint

    private var bucketHint: some View {
        Text(loc("muscle.progress.bucket.hint"))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }
}

#endif
