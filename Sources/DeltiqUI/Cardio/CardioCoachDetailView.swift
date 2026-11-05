#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

/// Detail-Ansicht fuer die Lauf-Coaching-Karte: zeigt Trainingsstand,
/// Wochenplan, Ziel-Fortschritt und Erholungs-Tipps.
/// Daten kommen aus dem aufrufenden DashboardView (kein eigener @Query).
@available(iOS 17.0, macOS 14.0, *)
struct CardioCoachDetailView: View {
    @Bindable var profile: UserBodyProfile
    let model: CardioFeasibilityCardModel
    let daysSinceLastRunSession: Int?
    let last7DaysRunSessionCount: Int
    let last7DaysRunVolumeKm: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "widget.runCoachCard.name", bundle: .module),
                onBack: { dismiss() }
            )
            List {
                statusSection
                if model.hasPlan { planSection }
                progressSection
                loadSection
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
            let allPoints = CardioFeasibilityCalculator.weeklyVolumeProjection(
                startKm: startVol, goal: goal, weeksAvailable: totalWeeks
            )
            let points = CardioFeasibilityCalculator.chartPoints(from: allPoints, maxCount: 20)
            if !points.isEmpty {
                Chart {
                    ForEach(0..<points.count, id: \.self) { i in
                        BarMark(
                            x: .value("Woche", points[i].week),
                            y: .value("km", points[i].km)
                        )
                        .foregroundStyle(Color.deltiqOrange.opacity(0.75))
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
}
#endif
