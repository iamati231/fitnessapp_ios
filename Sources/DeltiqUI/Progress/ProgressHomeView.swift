#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

@available(iOS 17.0, macOS 14.0, *)
public struct ProgressHomeView: View {
    @Environment(AppNavigation.self) private var navigation
    @Query private var profiles: [UserBodyProfile]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted && !$0.isRestDay },
        sort: \WorkoutSession.startTime, order: .reverse
    )
    private var allSessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var allMeasurements: [BodyMeasurement]

    @State private var period: ProgressPeriod = .fourWeeks

    public init() {}

    private var profile: UserBodyProfile? { profiles.first }

    private var sessionsInPeriod: [WorkoutSession] {
        guard let start = period.startDate else { return allSessions }
        return allSessions.filter { $0.startTime >= start }
    }

    private var measurementsInPeriod: [BodyMeasurement] {
        guard let start = period.startDate else { return allMeasurements }
        return allMeasurements.filter { $0.date >= start }
    }

    private var dataAvailability: ProgressPriorityResolver.DataAvailability {
        .init(
            hasStrengthSessions: sessionsInPeriod.contains { $0.containsStrengthWork },
            hasCardioSessions: sessionsInPeriod.contains { session in
                session.loggedSets.contains { $0.resolvedIsCardio }
                    || session.enduranceRoundsCompleted != nil
            },
            hasBodyMeasurements: !measurementsInPeriod.isEmpty,
            hasPersonalRecords: sessionsInPeriod.contains { !$0.personalRecords.isEmpty },
            hasNutritionLogs: false     // Phase 2
        )
    }

    private var priorityMetrics: [ProgressMetric] {
        guard let goal = profile?.trainingGoal else { return [] }
        return ProgressPriorityResolver.resolve(goal: goal, data: dataAvailability)
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "strength.progress.eyebrow", bundle: .module),
                title: String(localized: "progress.title", bundle: .module)
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodPicker
                    reviewCard
                    navigationSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Subviews

    private var periodPicker: some View {
        DeltiqPeriodPicker(
            items: ProgressPeriod.allCases,
            label: { p in
                switch p {
                case .fourWeeks:   return String(localized: "strength.progress.period.4w", bundle: .module)
                case .twelveWeeks: return String(localized: "strength.progress.period.12w", bundle: .module)
                case .oneYear:     return String(localized: "strength.progress.period.1y", bundle: .module)
                case .allTime:     return String(localized: "strength.progress.period.all", bundle: .module)
                }
            },
            selection: $period
        )
        .padding(.horizontal, -16)
    }

    @ViewBuilder
    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("progress.review.title", bundle: .module)
                .font(.headline)

            if sessionsInPeriod.isEmpty && measurementsInPeriod.isEmpty {
                ContentUnavailableView(
                    String(localized: "progress.review.title", bundle: .module),
                    systemImage: "chart.bar",
                    description: Text("progress.empty.subtitle", bundle: .module)
                )
            } else {
                if !sessionsInPeriod.isEmpty {
                    HStack {
                        // Bug-Fix: "figure.strengthtraining.traditional" und
                        // "figure.stand" haben unterschiedliche native
                        // Seitenverhaeltnisse — beim bisherigen
                        // Label(_:systemImage:) rendern sie trotz gleicher
                        // Font-Groesse unterschiedlich hoch. `.resizable()` +
                        // `.aspectRatio(.fit)` + fixer Frame gleicht beide auf
                        // dieselbe Glyph-Hoehe an (gleiches Prinzip wie
                        // `DeltiqAccentIconModifier.glyphSize`, hier ohne den
                        // dortigen Akzent-Background).
                        Label {
                            Text("\(sessionsInPeriod.count) \(String(localized: "progress.review.sessions", bundle: .module))")
                        } icon: {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        Spacer()
                    }
                }
                if !measurementsInPeriod.isEmpty {
                    HStack {
                        Label {
                            Text(String.localizedStringWithFormat(
                                NSLocalizedString("progress.review.measurements", bundle: .module, comment: ""),
                                measurementsInPeriod.count
                            ))
                        } icon: {
                            Image(systemName: "figure.stand")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        Spacer()
                    }
                }
                if !priorityMetrics.isEmpty {
                    Text("progress.review.focus", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(priorityMetrics, id: \.self) { metric in
                                Text(metric.localizedLabelKey, bundle: .module)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.deltiqOrange.opacity(0.15))
                                    .foregroundStyle(Color.deltiqOrange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var navigationSection: some View {
        DeltiqSection {
            NavigationLink {
                StrengthProgressView()
            } label: {
                DeltiqRow(icon: "dumbbell.fill",
                          label: String(localized: "progress.section.strength", bundle: .module),
                          showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                CardioProgressView()
            } label: {
                DeltiqRow(icon: "heart.fill",
                          label: String(localized: "progress.section.cardio", bundle: .module),
                          showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                MuscleVolumeProgressView()
            } label: {
                DeltiqRow(icon: "figure.strengthtraining.traditional",
                          label: String(localized: "progress.section.muscleVolume", bundle: .module),
                          showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ProgressOverviewView(eyebrowLocKey: "tab.progress")
            } label: {
                DeltiqRow(icon: "figure.stand",
                          label: String(localized: "progress.section.body", bundle: .module),
                          showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                PRHistoryView()
            } label: {
                DeltiqRow(icon: "trophy.fill",
                          label: String(localized: "progress.section.records", bundle: .module),
                          showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                WorkoutHistoryView()
            } label: {
                DeltiqRow(icon: "calendar",
                          label: String(localized: "progress.section.history", bundle: .module),
                          showsChevron: true,
                          showsDivider: false)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Helpers

@available(iOS 17.0, macOS 14.0, *)
private extension ProgressMetric {
    var localizedLabelKey: LocalizedStringKey {
        switch self {
        case .strengthVolume:    return "progress.metric.strengthVolume"
        case .personalRecords:   return "progress.metric.personalRecords"
        case .cardioPerformance: return "progress.metric.cardioPerformance"
        case .bodyComposition:   return "progress.metric.bodyComposition"
        case .workoutFrequency:  return "progress.metric.workoutFrequency"
        case .calorieBalance:    return "progress.metric.calorieBalance"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private enum ProgressPeriod: String, CaseIterable {
    case fourWeeks   = "progress.period.4weeks"
    case twelveWeeks = "progress.period.12weeks"
    case oneYear     = "progress.period.1year"
    case allTime     = "progress.period.alltime"

    var startDate: Date? {
        let now = Date.now
        switch self {
        case .fourWeeks:   return Calendar.current.date(byAdding: .weekOfYear, value: -4, to: now)
        case .twelveWeeks: return Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now)
        case .oneYear:     return Calendar.current.date(byAdding: .year, value: -1, to: now)
        case .allTime:     return nil
        }
    }
}
#endif
