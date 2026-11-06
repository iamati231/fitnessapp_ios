#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 9 des Tickets - "was wurde ausgewertet, was wurde erkannt,
/// warum"). Rein lesend/anzeigend - reicht `model`/`profile` nicht an
/// irgendeinen Plan-Mutationspfad weiter.
@available(iOS 17.0, macOS 14.0, *)
struct RaceProgressDetailView: View {
    @Bindable var profile: UserBodyProfile
    let model: RaceProgressCardModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "raceProgress.detail.title", bundle: .module),
                onBack: { dismiss() }
            )
            List {
                outcomeSection
                if !model.assessment.weeklyFlags.isEmpty {
                    weeklyOverviewSection
                }
                if !concerns.isEmpty {
                    concernsSection
                }
                if !model.assessment.dataGaps.isEmpty {
                    dataGapsSection
                }
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
    }

    private var concerns: [RaceProgressAssessment.Concern] {
        switch model.assessment.outcome {
        case .onTrack, .insufficientData: return []
        case .attentionNeeded(let c), .offTrack(let c): return c
        }
    }

    @ViewBuilder
    private var outcomeSection: some View {
        Section {
            Text(outcomeHeadline)
                .font(.headline)
            if let lastAnalyzed = profile.raceProgressLastAnalyzedAt {
                Text(String(
                    format: String(localized: "raceProgress.detail.lastAnalyzed", bundle: .module),
                    lastAnalyzed.formatted(date: .abbreviated, time: .omitted)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var outcomeHeadline: String {
        switch model.assessment.outcome {
        case .onTrack: return String(localized: "raceProgress.outcome.onTrack", bundle: .module)
        case .attentionNeeded: return String(localized: "raceProgress.outcome.attentionNeeded", bundle: .module)
        case .offTrack: return String(localized: "raceProgress.outcome.offTrack", bundle: .module)
        case .insufficientData: return String(localized: "raceProgress.outcome.insufficientData", bundle: .module)
        }
    }

    /// "Welche Daten wurden ausgewertet?" (Ticket Abschnitt 9) - zeigt die
    /// tatsaechliche Wochenserie (`model.weeklySeries`), nicht nur die
    /// abstrakten Flags, damit der Nutzer die Zahlen hinter der Einschaetzung
    /// nachvollziehen kann.
    @ViewBuilder
    private var weeklyOverviewSection: some View {
        Section {
            ForEach(Array(zip(model.weeklySeries, model.assessment.weeklyFlags).enumerated()), id: \.offset) { _, pair in
                let (point, flag) = pair
                HStack {
                    Text(point.weekStart.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text(String(format: "%.1f km", point.runningDistanceKm))
                    Text(flagText(flag))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        } header: {
            Text("raceProgress.detail.weeksHeader", bundle: .module)
        }
    }

    private func flagText(_ flag: RaceProgressAssessment.WeeklyFlag?) -> String {
        guard let flag else { return String(localized: "raceProgress.weekFlag.active", bundle: .module) }
        switch flag {
        case .beforeCoachingObservationPeriod: return String(localized: "raceProgress.weekFlag.beforeObservation", bundle: .module)
        case .strengthOnlyWeek: return String(localized: "raceProgress.weekFlag.strengthOnly", bundle: .module)
        case .crossTrainingOnlyWeek: return String(localized: "raceProgress.weekFlag.crossTraining", bundle: .module)
        case .ambiguousActivityWeek: return String(localized: "raceProgress.weekFlag.ambiguous", bundle: .module)
        case .genuineGap: return String(localized: "raceProgress.weekFlag.gap", bundle: .module)
        }
    }

    @ViewBuilder
    private var concernsSection: some View {
        Section {
            ForEach(Array(concerns.enumerated()), id: \.offset) { _, concern in
                Text(concernText(concern))
                    .font(.subheadline)
            }
        } header: {
            Text("raceProgress.detail.concernsHeader", bundle: .module)
        }
    }

    private func concernText(_ concern: RaceProgressAssessment.Concern) -> String {
        switch concern {
        case .loadIncreasedTooFast(let percent, let weeks):
            return String(
                format: String(localized: "raceProgress.concern.loadIncreasedTooFast", bundle: .module),
                Int((percent * 100).rounded()), weeks
            )
        case .insufficientRecovery(let weeks):
            return String(format: String(localized: "raceProgress.concern.insufficientRecovery", bundle: .module), weeks)
        case .volumePlateau(let weeks):
            return String(format: String(localized: "raceProgress.concern.volumePlateau", bundle: .module), weeks)
        case .goalLikelyUnrealistic:
            return String(localized: "raceProgress.concern.goalLikelyUnrealistic", bundle: .module)
        case .recentTrainingGap(let weeks):
            return String(format: String(localized: "raceProgress.concern.recentTrainingGap", bundle: .module), weeks)
        }
    }

    @ViewBuilder
    private var dataGapsSection: some View {
        Section {
            ForEach(Array(model.assessment.dataGaps.enumerated()), id: \.offset) { _, gap in
                Text(dataGapText(gap))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("raceProgress.detail.dataGapsHeader", bundle: .module)
        }
    }

    private func dataGapText(_ gap: RaceProgressAssessment.DataGap) -> String {
        switch gap {
        case .insufficientHistory(let available, let needed):
            return String(
                format: String(localized: "raceProgress.dataGap.insufficientHistory", bundle: .module),
                available, needed
            )
        case .noHeartRateData:
            return String(localized: "raceProgress.dataGap.noHeartRateData", bundle: .module)
        case .coachingObservationStartUnknown:
            return String(localized: "raceProgress.dataGap.coachingObservationStartUnknown", bundle: .module)
        case .ambiguousActivityPresent(let count):
            return String(format: String(localized: "raceProgress.dataGap.ambiguousActivityPresent", bundle: .module), count)
        }
    }
}
#endif
