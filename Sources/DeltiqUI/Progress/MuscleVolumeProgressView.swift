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

/// DEL-Progress-02C: Trainingsvolumen & Muskelgruppen-Fortschritt.
///
/// Zeigt wöchentliche Arbeitssätze (gesamt + je Muskelgruppe) gefiltert nach
/// Periode (4W/12W/1J/Gesamt). Berechnungslogik in
/// `DeltiqCore.MuscleGroupProgressCalculator`.
@available(iOS 17.0, macOS 14.0, *)
public struct MuscleVolumeProgressView: View {

    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .forward)
    private var sessions: [WorkoutSession]
    @Query private var templates: [ExerciseTemplate]

    @State private var period: MuscleGroupProgressCalculator.Period = .twelveWeeks
    @State private var selectedMuscle: MuscleGroup? = nil

    public init() {}

    // MARK: - Projections

    private var allSets: [MuscleGroupProgressCalculator.MuscleLoggedSet] {
        MuscleSetExtractor.extract(from: sessions, templates: templates)
    }

    private var overviewStats: MuscleGroupProgressCalculator.OverviewStats {
        MuscleGroupProgressCalculator.overviewStats(sets: allSets, period: period)
    }

    private var weeklyPoints: [MuscleGroupProgressCalculator.WeeklyMusclePoint] {
        MuscleGroupProgressCalculator.weeklyPoints(sets: allSets, period: period)
    }

    private var muscleRanking: [(muscle: MuscleGroup, totalSets: Int)] {
        MuscleGroupProgressCalculator.muscleRanking(sets: allSets, period: period)
    }

    private var hasStrengthLogs: Bool { overviewStats.totalWorkingSets > 0 }
    private var hasMuscleData: Bool { overviewStats.totalWorkingSets - overviewStats.unassignedSetCount > 0 }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: "",
                title: loc("muscle.progress.title"),
                onBack: { dismiss() }
            )

            periodPicker

            if !hasStrengthLogs {
                ScrollView {
                    DashboardEmptyState(
                        icon: "figure.strengthtraining.traditional",
                        title: "muscle.progress.emptyTitle",
                        description: "muscle.progress.emptyDescription"
                    )
                    .deltiqCardStyle()
                    .padding(.top, 18)
                }
            } else if !hasMuscleData {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewSection
                        DashboardEmptyState(
                            icon: "questionmark.circle",
                            title: "muscle.progress.emptyMuscleTitle",
                            description: "muscle.progress.emptyMuscleDescription"
                        )
                        .deltiqCardStyle()
                    }
                    .padding(.bottom, 32)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewSection
                        chartSection
                        muscleListSection
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .deltiqScreen()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
        .navigationDestination(item: $selectedMuscle) { muscle in
            MuscleGroupDetailView(muscle: muscle, allSets: allSets, initialPeriod: period)
        }
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

    // MARK: - Overview

    private var overviewSection: some View {
        DeltiqSection(loc("muscle.progress.section.overview").uppercased()) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(value: "\(overviewStats.totalWorkingSets)",
                         label: loc("muscle.progress.overview.totalSets"))
                if let top = overviewStats.mostTrainedMuscle {
                    statCell(value: String(localized: top.localizedName),
                             label: loc("muscle.progress.overview.topMuscle"))
                }
                if overviewStats.busiestWeekSets > 0 {
                    statCell(value: "\(overviewStats.busiestWeekSets)",
                             label: loc("muscle.progress.overview.busiestWeek"))
                }
                statCell(value: "\(overviewStats.sessionCount)",
                         label: loc("strength.progress.overview.sessions"))
                if overviewStats.unassignedSetCount > 0 {
                    statCell(value: "\(overviewStats.unassignedSetCount)",
                             label: loc("muscle.progress.overview.unassignedSets"))
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

    // MARK: - Chart

    private var chartSection: some View {
        DeltiqSection(loc("muscle.progress.chart.title").uppercased()) {
            Chart {
                ForEach(weeklyPoints) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Sets", point.totalSets)
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
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityLabel(loc("muscle.progress.chart.title"))
        }
    }

    // MARK: - Muscle list

    private var muscleListSection: some View {
        DeltiqSection(loc("muscle.progress.section.muscles").uppercased()) {
            ForEach(muscleRanking, id: \.muscle) { entry in
                Button {
                    selectedMuscle = entry.muscle
                } label: {
                    HStack {
                        Text(String(localized: entry.muscle.localizedName))
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("muscle.progress.sets.label",
                                              bundle: .module, comment: ""),
                            entry.totalSets))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(String(localized: entry.muscle.localizedName)), \(entry.totalSets) sets")
            }
        }
    }

}


#endif
