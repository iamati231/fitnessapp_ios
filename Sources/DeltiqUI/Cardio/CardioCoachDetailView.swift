#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

/// Detail-Ansicht fuer die Lauf-Coaching-Karte: zeigt Trainingsstand,
/// Wochenplan, Ziel-Fortschritt und Erholungs-Tipps.
/// Daten kommen aus dem aufrufenden DashboardView und einem eigenen @Query
/// fuer die 8-Wochen-Laufhistorie.
@available(iOS 17.0, macOS 14.0, *)
struct CardioCoachDetailView: View {
    @Bindable var profile: UserBodyProfile
    let model: CardioFeasibilityCardModel
    let daysSinceLastRunSession: Int?
    let last7DaysRunSessionCount: Int
    let last7DaysRunVolumeKm: Double
    let raceProgressModel: RaceProgressCardModel?
    let densityAssessment: TrainingDensityAnalyzer.Assessment?
    let loadTrend: TrainingLoadTrend?
    let planAdjustmentPending: Bool

    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\WorkoutSession.startTime, order: .reverse)])
    private var allSessions: [WorkoutSession]

    // MARK: - Historische Laufanalyse (Section 3)

    private var runSessionsLast8Weeks: [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date()) ?? .distantPast
        return allSessions.filter {
            $0.isRealWorkout && $0.startTime >= cutoff && $0.logs.contains { $0.resolvedIsCardio }
        }
    }

    /// Wochenbuckets letzte 8 Wochen: (KW-Label, km). Keine Interpolation.
    private var last8WeeksBuckets: [(label: String, km: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<8).reversed().map { weeksAgo -> (label: String, km: Double) in
            let refDate = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) ?? now
            guard let interval = cal.dateInterval(of: .weekOfYear, for: refDate) else {
                return ("", 0)
            }
            let sessions = runSessionsLast8Weeks.filter {
                $0.startTime >= interval.start && $0.startTime < interval.end
            }
            let km = sessions.reduce(0.0) { $0 + $1.totalDistanceKm }
            let weekNum = cal.component(.weekOfYear, from: interval.start)
            return ("KW\(weekNum)", km)
        }
    }

    /// Einfache regelbasierte Einschaetzung aus tatsaechlichen Daten.
    private var coachingInsight: String? {
        let buckets = last8WeeksBuckets
        let nonEmpty = buckets.filter { $0.km > 0 }
        guard nonEmpty.count >= 2 else { return nil }
        let last = nonEmpty[nonEmpty.count - 1].km
        let prev = nonEmpty[nonEmpty.count - 2].km
        if prev > 0 && (last - prev) / prev > 0.15 {
            return String(localized: "cardioCoach.insight.volumeSpike", bundle: .module)
        }
        let avgPerWeek = Double(runSessionsLast8Weeks.count) / 8.0
        if avgPerWeek < 1.5 {
            return String(localized: "cardioCoach.insight.lowFrequency", bundle: .module)
        }
        return String(localized: "cardioCoach.insight.onTrack", bundle: .module)
    }

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "widget.runCoachCard.name", bundle: .module),
                onBack: { dismiss() }
            )
            List {
                statusSection
                historicalSection
                if model.hasPlan { planSection }
                progressSection
                loadSection
                if profile.cardioCoachingEnabled { integratedSection }
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            if let days = daysSinceLastRunSession {
                Text(String(format: String(localized: "cardioCoach.detail.lastRun", bundle: .module), days))
            } else {
                Text("cardioCoach.detail.noRunSessions", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            if last7DaysRunSessionCount > 0 {
                Text(String(format: String(localized: "cardioCoach.detail.runsPerWeek", bundle: .module), last7DaysRunSessionCount))
            }
            if last7DaysRunVolumeKm > 0 {
                Text(String(format: String(localized: "cardioCoach.detail.volumePerWeek", bundle: .module), last7DaysRunVolumeKm))
            }
        } header: {
            Text("cardioCoach.detail.status.header", bundle: .module)
        }
    }

    @ViewBuilder
    private var historicalSection: some View {
        Section {
            let buckets = last8WeeksBuckets
            if buckets.allSatisfy({ $0.km == 0 }) {
                Text("cardioCoach.detail.history.empty", bundle: .module)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                        BarMark(
                            x: .value("KW", bucket.label),
                            y: .value("km", bucket.km)
                        )
                        .foregroundStyle(Color.deltiqOrange.opacity(0.75))
                    }
                }
                .frame(height: 90)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let s = value.as(String.self) {
                                Text(s).font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let km = value.as(Double.self) {
                                Text("\(Int(km))km").font(.caption2)
                            }
                        }
                    }
                }
                if let insight = coachingInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("cardioCoach.detail.history.header", bundle: .module)
        }
    }

    @ViewBuilder
    private var planSection: some View {
        if let days = model.planResult?.days, !days.isEmpty {
            Section {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    CardioFeasibilityDayRow(day: day)
                }
            } header: {
                Text("cardioCoach.detail.plan.header", bundle: .module)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        Section {
            Text(String(localized: profile.cardioGoal.localizedName))
                .fontWeight(.medium)
            if let raceDate = profile.cardioRaceDate, raceDate > Date() {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: raceDate).day ?? 0
                Text(String(
                    format: String(localized: "dashboard.coachAdjustment.daysToRace", bundle: .module),
                    days
                ))
                .foregroundStyle(.secondary)
            }
            Text(model.detailText)
                .foregroundStyle(.secondary)
            volumeChart
        } header: {
            Text("cardioCoach.detail.progress.header", bundle: .module)
        }
    }

    @ViewBuilder
    private var volumeChart: some View {
        if let startVol = profile.weeklyBaseVolumeKm, startVol > 0,
           let raceDate = profile.cardioRaceDate, raceDate > Date() {
            let totalWeeks = Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear ?? 0
            let goal = model.proposedGoal ?? profile.cardioGoal
            // Alle Punkte direkt — kein chartPoints-Sampling, das einzelne
            // Wochen ueberspringt und visuelle Luecken erzeugt (Section 4A).
            let allPoints = CardioFeasibilityCalculator.weeklyVolumeProjection(
                startKm: startVol, goal: goal, weeksAvailable: totalWeeks
            )
            let peakKm = allPoints.max(by: { $0.km < $1.km })?.km ?? 0
            if !allPoints.isEmpty {
                Chart {
                    ForEach(0..<allPoints.count, id: \.self) { i in
                        BarMark(
                            x: .value("Woche", allPoints[i].week),
                            y: .value("km", allPoints[i].km)
                        )
                        .foregroundStyle(
                            allPoints[i].km < peakKm * 0.8
                                ? Color.deltiqOrange.opacity(0.5)
                                : Color.deltiqOrange.opacity(0.85)
                        )
                    }
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let w = value.as(Int.self) {
                                Text("W\(w)").font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let km = value.as(Double.self) {
                                Text("\(Int(km))km").font(.caption2)
                            }
                        }
                    }
                }
                // Trainingsplan-Zusammenfassung: Start, Peak, Wochen
                if let first = allPoints.first {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0f km", first.km)).font(.caption.weight(.medium))
                            Text("Start").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .center, spacing: 2) {
                            Text(String(format: "%.0f km", peakKm)).font(.caption.weight(.medium))
                            Text("Peak").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(totalWeeks)").font(.caption.weight(.medium))
                            Text(String(localized: "cardioCoach.detail.trainingWeeks", bundle: .module))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var loadSection: some View {
        Section {
            if let refSecs = profile.current5kReferenceSeconds,
               let easy = PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: refSecs),
               let tempo = PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: refSecs) {
                Text(String(
                    format: String(localized: "profile.cardio.paceZones", bundle: .module),
                    PaceCalculator.formatPace(easy),
                    PaceCalculator.formatPace(tempo)
                ))
                .foregroundStyle(.secondary)
                // Pace-Quelle transparent machen (Section 4B)
                Text("cardioCoach.detail.paceEstimate", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("cardioCoach.detail.paceNoReference", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            if let vol = profile.weeklyBaseVolumeKm, vol > 0 {
                Text(String(
                    format: String(localized: "profile.cardio.adjustment.detail.startVolume", bundle: .module),
                    Int(vol)
                ))
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("cardioCoach.detail.load.header", bundle: .module)
        }
    }
    // MARK: - Integrierte Coaching-Empfehlung (Section 6)

    @ViewBuilder
    private var integratedSection: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysToRace: Int? = profile.cardioRaceDate.flatMap { raceDate in
            let d = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: raceDate)).day ?? 0
            return d > 0 ? d : nil
        }
        let outcome = IntegratedRunCoachAdvisor.assess(
            raceProgress: raceProgressModel?.assessment,
            loadTrend: loadTrend,
            densityAssessment: densityAssessment,
            weeksToRace: daysToRace.map { $0 / 7 },
            daysToRace: daysToRace,
            planAdjustmentPending: planAdjustmentPending
        )
        Section {
            Text(localizedAction(outcome.primaryAction))
                .fontWeight(.medium)
            Text(localizedRationale(outcome.rationale))
                .foregroundStyle(.secondary)
            ForEach(Array(outcome.dataQualityIssues.enumerated()), id: \.offset) { _, issue in
                Text(localizedDataQuality(issue))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("cardioCoach.detail.integrated.header", bundle: .module)
        }
    }

    private func localizedAction(_ action: CoachingAction) -> String {
        switch action {
        case .maintainCurrent:
            return String(localized: "integratedCoach.action.maintainCurrent", bundle: .module)
        case .reduceLoadThisWeek:
            return String(localized: "integratedCoach.action.reduceLoadThisWeek", bundle: .module)
        case .increaseWeeklyVolume(let pct):
            let pctStr = String(format: "+%.0f %%", pct * 100)
            return String(format: String(localized: "integratedCoach.action.increaseWeeklyVolume", bundle: .module), pctStr)
        case .reassessGoal:
            return String(localized: "integratedCoach.action.reassessGoal", bundle: .module)
        case .planAdjustmentAvailable:
            return String(localized: "integratedCoach.action.planAdjustmentAvailable", bundle: .module)
        case .buildRunningBase:
            return String(localized: "integratedCoach.action.buildRunningBase", bundle: .module)
        case .insufficientData:
            return String(localized: "integratedCoach.action.insufficientData", bundle: .module)
        }
    }

    private func localizedRationale(_ rationale: CoachingRationale) -> String {
        switch rationale {
        case .positiveProgressHighLoad:
            return String(localized: "integratedCoach.rationale.positiveProgressHighLoad", bundle: .module)
        case .positiveProgressStableLoad:
            return String(localized: "integratedCoach.rationale.positiveProgressStableLoad", bundle: .module)
        case .plateauNearRace(let weeks):
            return String(format: String(localized: "integratedCoach.rationale.plateauNearRace", bundle: .module), weeks)
        case .goalLikelyUnreachable:
            return String(localized: "integratedCoach.rationale.goalLikelyUnreachable", bundle: .module)
        case .recentGapDetected:
            return String(localized: "integratedCoach.rationale.recentGapDetected", bundle: .module)
        case .recoveryNeeded:
            return String(localized: "integratedCoach.rationale.recoveryNeeded", bundle: .module)
        case .noRunningData:
            return String(localized: "integratedCoach.rationale.noRunningData", bundle: .module)
        case .crossTrainingOnly:
            return String(localized: "integratedCoach.rationale.crossTrainingOnly", bundle: .module)
        case .shortHistory:
            return String(localized: "integratedCoach.rationale.shortHistory", bundle: .module)
        case .planJustAdjusted:
            return String(localized: "integratedCoach.rationale.planJustAdjusted", bundle: .module)
        }
    }

    private func localizedDataQuality(_ issue: DataQualityIssue) -> String {
        switch issue {
        case .runningDistanceMissing(let n):
            return String(format: String(localized: "integratedCoach.dataQuality.runningDistanceMissing", bundle: .module), n)
        case .ambiguousActivitiesPresent(let n):
            return String(format: String(localized: "integratedCoach.dataQuality.ambiguousActivitiesPresent", bundle: .module), n)
        case .durationDataUnavailable:
            return String(localized: "integratedCoach.dataQuality.durationDataUnavailable", bundle: .module)
        case .historyTooShort(let avail, let needed):
            return String(format: String(localized: "integratedCoach.dataQuality.historyTooShort", bundle: .module), avail, needed)
        case .recoveryEvidenceUnavailable:
            return String(localized: "integratedCoach.dataQuality.recoveryEvidenceUnavailable", bundle: .module)
        case .densityHistoryInsufficient(let days):
            return String(format: String(localized: "integratedCoach.dataQuality.densityHistoryInsufficient", bundle: .module), days)
        }
    }
}
#endif
