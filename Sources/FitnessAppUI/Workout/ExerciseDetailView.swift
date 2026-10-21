#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import FitnessAppCore
import FitnessAppData

/// DEL-201: Verlaufs-Screen für EINE Übung — Stats, e1RM-Chart, PRs und
/// die letzten Sätze. Bisher gab es Trend-Charts nur für die 5 Compounds
/// (Dashboard); hier bekommt jede Übung ihre eigene Historie.
///
/// **Identität ID-first** (Settings-Epic Phase 6, EXLIB-07/09, baut auf dem
/// DEL-051-Snapshot-Pattern auf): Logs/PRs mit aufgeloester
/// `exerciseTemplateID` identifizieren sich darueber — stabil auch nach
/// einem Umbenennen der Vorlage. Nur Alt-Eintraege ohne aufloesbare ID
/// fallen weiterhin auf `resolvedExerciseName`/`exerciseName` zurueck, exakt
/// wie vor Phase 6 — so zählt die Historie auch nach Plan-Löschungen/
/// Equipment-Swaps/Umbenennungen vollständig.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseDetailView: View {

    /// System-Name (deutscher Library-Anker) — matcht die Log-Snapshots.
    /// Fallback-Identitaet fuer Logs/PRs ohne aufloesbare `exerciseTemplateID`
    /// (Settings-Epic Phase 6, EXLIB-07/09).
    let systemName: String
    /// Stabile Vorlagen-ID — primaere Identitaet seit Phase 6. Ueberlebt ein
    /// Umbenennen der Vorlage, anders als `systemName`.
    let exerciseTemplateID: UUID
    /// Lokalisierter Anzeige-Name für den Titel.
    let displayName: String
    /// True für Cardio-Übungen — schaltet Stats auf Distanz/Zeit um.
    let isCardio: Bool

    @Query(sort: \ExerciseLog.date) private var allLogs: [ExerciseLog]
    @Query(sort: \PersonalRecordEntry.date, order: .reverse)
    private var allPRs: [PersonalRecordEntry]

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: erreicht ueber den Leading-Swipe
            // "Verlauf" in ExerciseLibraryView - Eyebrow zeigt den Tab
            // (Mehr), nicht die Bibliothek, siehe OFFENE-VIEWS.md.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: displayName,
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                if logs.isEmpty {
                    emptyState
                } else {
                    statsGrid
                    if !isCardio, chartPoints.count >= 2 {
                        e1rmChart
                    }
                    if !prs.isEmpty {
                        prSection
                    }
                    recentSetsSection
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Daten

    /// Alle Logs dieser Übung, chronologisch. Settings-Epic Phase 6
    /// (EXLIB-07/09): ID-first — ein Log mit aufgeloester `exerciseTemplateID`
    /// zaehlt nur bei ID-Treffer (ueberlebt Umbenennen); nur Logs OHNE
    /// aufloesbare ID fallen weiterhin auf den Namens-Snapshot zurueck
    /// (unveraendertes Alt-Verhalten fuer nicht per Backfill aufloesbare
    /// Bestandsdaten — nie beides gemischt, sonst koennte ein zufaelliger
    /// Namens-Treffer eine andere Uebung faelschlich mit-anzeigen).
    private var logs: [ExerciseLog] {
        allLogs.filter { log in
            if let logTemplateID = log.resolvedExerciseTemplateID {
                return logTemplateID == exerciseTemplateID
            }
            return log.resolvedExerciseName == systemName
        }
    }

    private var prs: [PersonalRecordEntry] {
        allPRs.filter { entry in
            if let entryTemplateID = entry.exerciseTemplateID {
                return entryTemplateID == exerciseTemplateID
            }
            return entry.exerciseName == systemName
        }
    }

    /// Bestes e1RM pro Session — gleiche Aggregation wie der Compound-Chart
    /// (DEL-147: session.startTime als X-Wert, log.date nur als Fallback).
    private var chartPoints: [CompoundPoint] {
        let bySession = Dictionary(grouping: logs) { $0.session?.persistentModelID }
        return bySession.compactMap { (_, sessionLogs) -> CompoundPoint? in
            let estimates = sessionLogs.compactMap {
                ExerciseCalculations.estimate1RMAverage(weightKg: $0.weight, reps: $0.reps)
            }
            guard let best = estimates.max(),
                  let date = sessionLogs.first?.session?.startTime
                        ?? sessionLogs.map(\.date).min() else { return nil }
            return CompoundPoint(date: date, oneRM: best)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                statTile(
                    labelKey: "exercise.detail.stats.sets",
                    value: "\(logs.count)"
                )
                if isCardio {
                    statTile(
                        labelKey: "exercise.detail.stats.distance",
                        value: formatKm(logs.compactMap(\.distanceKm).reduce(0, +))
                    )
                } else {
                    statTile(
                        labelKey: "exercise.detail.stats.volume",
                        value: formatWeight(logs.reduce(0.0) { $0 + $1.weight * Double($1.reps) })
                    )
                }
            }
            HStack(spacing: 12) {
                if isCardio {
                    statTile(
                        labelKey: "exercise.detail.stats.duration",
                        value: formatDuration(logs.compactMap(\.durationSeconds).reduce(0, +))
                    )
                } else {
                    statTile(
                        labelKey: "exercise.detail.stats.maxWeight",
                        value: formatWeight(logs.map(\.weight).max() ?? 0)
                    )
                    statTile(
                        labelKey: "exercise.detail.stats.bestE1RM",
                        value: formatWeight(
                            logs.compactMap {
                                ExerciseCalculations.estimate1RMAverage(weightKg: $0.weight, reps: $0.reps)
                            }.max() ?? 0
                        )
                    )
                }
            }
        }
        .deltiqCardStyle()
    }

    private func statTile(labelKey: String.LocalizationValue, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: labelKey, bundle: .module))
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .fitnessNumberStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var e1rmChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("exercise.detail.chart.title", bundle: .module)
                .font(.headline)
            Chart(chartPoints) { point in
                LineMark(
                    x: .value("Datum", point.date),
                    y: .value("e1RM", point.oneRM)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.deltiqOrange)
                PointMark(
                    x: .value("Datum", point.date),
                    y: .value("e1RM", point.oneRM)
                )
                .foregroundStyle(Color.deltiqOrange)
                .symbolSize(40)
            }
            .frame(height: 180)
            .fitnessNumberStyle()
        }
        .deltiqCardStyle()
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("exercise.detail.prs.title", bundle: .module)
                .font(.headline)
            ForEach(prs.prefix(6)) { pr in
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Color.deltiqOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kindLabel(pr.kindRaw))
                            .font(.subheadline.weight(.medium))
                        Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                    Spacer()
                    Text(formatWeight(pr.value))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
            }
        }
        .deltiqCardStyle()
    }

    /// Resolved `pr.kind.{rawValue}` aus dem Catalog (Keys existieren seit
    /// dem Trophy-Room). Unbekannte Kinds (Zukunfts-Cases) fallen auf den
    /// rawValue zurück statt zu crashen.
    private func kindLabel(_ kindRaw: String) -> String {
        let key = "pr.kind.\(kindRaw)"
        let resolved = String(localized: String.LocalizationValue(key), bundle: .module)
        return resolved == key ? kindRaw : resolved
    }

    // MARK: - Letzte Sätze

    private var recentSetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("exercise.detail.recent.title", bundle: .module)
                .font(.headline)
            ForEach(Array(logs.suffix(15).reversed().enumerated()), id: \.offset) { _, log in
                HStack {
                    Text(log.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    Spacer()
                    if isCardio {
                        Text(cardioLogText(log))
                            .font(.subheadline.monospacedDigit())
                    } else {
                        Text("\(formatWeight(log.weight)) × \(log.reps)")
                            .font(.subheadline.monospacedDigit())
                        Text("RIR \(log.rir.formatted(.number.precision(.fractionLength(0...1))))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.Deltiq.textTertiary)
                    }
                }
            }
        }
        .deltiqCardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(Color.Deltiq.textTertiary)
            Text("exercise.detail.empty", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Formatter

    private func formatWeight(_ kg: Double) -> String {
        if weightUnitRaw == "lbs" {
            let lbs = WeightUnit.lbs.fromKg(kg)
            return "\(lbs.truncated(to: 1).formatted(.number.precision(.fractionLength(0...1)))) lbs"
        }
        return "\(kg.truncated(to: 1).formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    private func formatKm(_ km: Double) -> String {
        "\(km.truncated(to: 1).formatted(.number.precision(.fractionLength(0...1)))) km"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func cardioLogText(_ log: ExerciseLog) -> String {
        var parts: [String] = []
        if let km = log.distanceKm { parts.append(formatKm(km)) }
        if let sec = log.durationSeconds { parts.append(formatDuration(sec)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }
}
#endif
