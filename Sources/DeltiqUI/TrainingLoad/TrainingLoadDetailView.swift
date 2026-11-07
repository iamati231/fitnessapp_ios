#if canImport(SwiftUI)
import SwiftUI
import DeltiqCore

/// AI-Running-Coach Phase 2D: 9-teilige Detailansicht der
/// Trainingsbelastungs-Bewertung (`TrainingDensityAnalyzer.Assessment`).
/// Rein lesend — keine Planaenderung, kein SwiftData-Schreibzugriff.
@available(iOS 17.0, macOS 14.0, *)
public struct TrainingLoadDetailView: View {

    public let assessment: TrainingDensityAnalyzer.Assessment

    public init(assessment: TrainingDensityAnalyzer.Assessment) {
        self.assessment = assessment
    }

    public var body: some View {
        NavigationStack {
            List {
                // 1. Bewertung
                Section(header: Text("trainingDensity.detail.sectionAssessment", bundle: .module)) {
                    HStack(spacing: 12) {
                        Image(systemName: outcomeIcon)
                            .font(.title2)
                            .foregroundStyle(outcomeColor)
                        Text(outcomeLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                    Text(String(
                        format: String(localized: "trainingDensity.detail.analyzedPeriod", bundle: .module),
                        assessment.analyzedPeriodDays,
                        assessment.analyzedActivityCount
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // 2. Belastungsentwicklung (aus 2B)
                Section(header: Text("trainingDensity.detail.sectionLoadTrend", bundle: .module)) {
                    Text(loadDevelopmentLabel)
                        .font(.subheadline)
                }

                // 3. Trainingstage (letzte 7 Tage)
                Section(header: Text("trainingDensity.detail.sectionLast7Days", bundle: .module)) {
                    metricRow(value: assessment.trainingDaysLast7, maxValue: 7)
                }

                // 4. Trainingstage (letzte 14 Tage)
                Section(header: Text("trainingDensity.detail.sectionLast14Days", bundle: .module)) {
                    metricRow(value: assessment.trainingDaysLast14, maxValue: 14)
                }

                // 5. Maximale Folgetage
                Section(header: Text("trainingDensity.detail.sectionConsecutive", bundle: .module)) {
                    metricRow(value: assessment.consecutiveTrainingDays, maxValue: 7, threshold: TrainingDensityAnalyzer.highConsecutiveDaysThreshold)
                }

                // 6. Kürzester Laufabstand
                Section(header: Text("trainingDensity.detail.sectionRunGap", bundle: .module)) {
                    gapRow(hours: assessment.minimumRunningGapHours, threshold: TrainingDensityAnalyzer.closeRunningGapHoursThreshold)
                }

                // 7. Kürzester Kraft-Abstand
                Section(header: Text("trainingDensity.detail.sectionStrengthGap", bundle: .module)) {
                    gapRow(hours: assessment.minimumStrengthGapHours, threshold: nil)
                }

                // 8. Erkannte Auffälligkeiten
                Section(header: Text("trainingDensity.detail.sectionConcerns", bundle: .module)) {
                    if assessment.concerns.isEmpty {
                        Text("trainingDensity.detail.noConcerns", bundle: .module)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(assessment.concerns.enumerated()), id: \.offset) { _, concern in
                            Label(concernLabel(concern), systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // 9. Fehlende Daten
                Section(header: Text("trainingDensity.detail.sectionDataGaps", bundle: .module)) {
                    ForEach(Array(assessment.dataGaps.enumerated()), id: \.offset) { _, gap in
                        Label(dataGapLabel(gap), systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Text("trainingDensity.detail.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func metricRow(value: Int, maxValue: Int, threshold: Int? = nil) -> some View {
        HStack {
            Text("\(value) / \(maxValue)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(threshold.map { value >= $0 ? Color.orange : Color.primary } ?? .primary)
            Spacer()
            ProgressView(value: Double(min(value, maxValue)), total: Double(maxValue))
                .tint(threshold.map { value >= $0 ? Color.orange : Color.accentColor } ?? .accentColor)
                .frame(maxWidth: 120)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func gapRow(hours: Double?, threshold: Double?) -> some View {
        if let hours {
            HStack {
                let label = String(format: String(localized: "trainingDensity.detail.hours", bundle: .module), hours)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(threshold.map { hours < $0 ? Color.orange : Color.primary } ?? .primary)
                Spacer()
                if let threshold, hours < threshold {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 2)
        } else {
            Text("trainingDensity.detail.noGapData", bundle: .module)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    // MARK: - Formatierung

    private var outcomeIcon: String {
        switch assessment.outcome {
        case .balanced: return "checkmark.circle.fill"
        case .increasingLoad: return "arrow.up.circle.fill"
        case .highTrainingDensity: return "exclamationmark.circle.fill"
        case .insufficientRecoveryEvidence: return "questionmark.circle.fill"
        case .insufficientData: return "minus.circle.fill"
        }
    }

    private var outcomeColor: Color {
        switch assessment.outcome {
        case .balanced: return .green
        case .increasingLoad, .highTrainingDensity: return .orange
        case .insufficientRecoveryEvidence, .insufficientData: return .secondary
        }
    }

    private var outcomeLabel: String {
        switch assessment.outcome {
        case .balanced: return String(localized: "trainingDensity.outcome.balanced", bundle: .module)
        case .increasingLoad: return String(localized: "trainingDensity.outcome.increasingLoad", bundle: .module)
        case .highTrainingDensity: return String(localized: "trainingDensity.outcome.highTrainingDensity", bundle: .module)
        case .insufficientRecoveryEvidence: return String(localized: "trainingDensity.outcome.insufficientRecoveryEvidence", bundle: .module)
        case .insufficientData: return String(localized: "trainingDensity.outcome.insufficientData", bundle: .module)
        }
    }

    private var loadDevelopmentLabel: String {
        switch assessment.outcome {
        case .insufficientData:
            return String(localized: "trainingDensity.loadDev.insufficientData", bundle: .module)
        default:
            break
        }
        // Readable label from the trend's loadDevelopment
        // Note: assessment doesn't carry the raw trend; the compact card provides
        // this via the detail's init. For now surface the outcome-derived label.
        // shortcut: detail doesn't hold TrainingLoadTrend directly — upgrade if
        // needed to pass trend through, for now outcome-derived summary suffices.
        switch assessment.outcome {
        case .increasingLoad:
            return String(localized: "trainingDensity.outcome.increasingLoad", bundle: .module)
        case .balanced:
            return String(localized: "trainingDensity.loadDev.stable", bundle: .module)
        default:
            return String(localized: "trainingDensity.loadDev.insufficientData", bundle: .module)
        }
    }

    private func concernLabel(_ concern: TrainingDensityAnalyzer.Concern) -> String {
        switch concern {
        case .highConsecutiveTrainingDays(let days):
            return String(format: String(localized: "trainingDensity.concern.highConsecutive", bundle: .module), days)
        case .sixPlusTrainingDaysInWeek(let days):
            return String(format: String(localized: "trainingDensity.concern.denseWeek", bundle: .module), days)
        case .closelySpacedRunningSessions(let hours):
            return String(format: String(localized: "trainingDensity.concern.closeRunGap", bundle: .module), hours)
        case .deloadIndicatedByExistingSystem:
            return String(localized: "trainingDensity.concern.deloadActive", bundle: .module)
        }
    }

    private func dataGapLabel(_ gap: TrainingDensityAnalyzer.DataGap) -> String {
        switch gap {
        case .insufficientHistory(let days):
            return String(format: String(localized: "trainingDensity.dataGap.insufficientHistory", bundle: .module), days)
        case .sessionFeelingUnavailable:
            return String(localized: "trainingDensity.dataGap.sessionFeeling", bundle: .module)
        case .noMeasuredIntensityData:
            return String(localized: "trainingDensity.dataGap.noIntensity", bundle: .module)
        }
    }
}
#endif
