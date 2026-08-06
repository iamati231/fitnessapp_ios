#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Read-only list of all completed `WorkoutSession`s, grouped by month. Tapping a
/// row pushes `WorkoutSummaryView` in read-only mode, so the user can scroll
/// through past sätze + notes without risking accidental edits.
@available(iOS 17.0, macOS 14.0, *)
public struct WorkoutHistoryView: View {

    @Environment(\.dismiss) private var dismiss

    // Rest-day-marker sessions (skipped rest days from the Dashboard) live
    // in the store with isCompleted=true so the PlanNavigator advances its
    // pointer, but they aren't workouts and don't belong in History.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt vom Dashboard gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // DashboardSettingsView/DataExportView unter "Mehr".
            DeltiqHeader(
                eyebrow: String(localized: "tab.dashboard", bundle: .module).uppercased(),
                title: String(localized: "dashboard.history.title", bundle: .module),
                onBack: { dismiss() }
            )

            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    DashboardEmptyState(
                        icon: "calendar.badge.exclamationmark",
                        title: "history.empty.title",
                        description: "history.empty.description"
                    )
                    .deltiqCardStyle()
                }
                .deltiqScreen()
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    // DEL-Handoff 3a: Kontextzeile mit Anzahl + letzter Einheit —
                    // dieselbe Formel wie DashboardView.historyTeaserText, nur
                    // als Pill statt Fliesstext.
                    DeltiqContextRow([
                        DeltiqContextItem(historyContextText.uppercased(), style: .neutral)
                    ])
                    ForEach(monthSections) { section in
                        monthCard(section)
                    }
                }
                .deltiqScreen()
            }
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

    // MARK: Sections

    private func monthCard(_ section: MonthSection) -> some View {
        DeltiqSection(section.label.uppercased()) {
            ForEach(section.sessions) { session in
                NavigationLink {
                    WorkoutSummaryView(session: session, isReadOnly: true)
                } label: {
                    HistorySessionRow(session: session, showsDivider: session.id != section.sessions.last?.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Context

    /// Spiegelt `DashboardView.historyTeaserText` — dieselben zwei
    /// xcstrings-Varianten (count+last / count-only), hier als Pill statt
    /// Fliesstext, weil sie in eine `DeltiqContextRow` wandert.
    private var historyContextText: String {
        guard let latest = sessions.first else {
            return String(format: String(localized: "dashboard.history.countOnly", bundle: .module), sessions.count)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: latest.startTime, relativeTo: Date())
        let template = String(localized: "dashboard.history.countWithLast", bundle: .module)
        return template
            .replacingOccurrences(of: "%1$lld", with: "\(sessions.count)")
            .replacingOccurrences(of: "%2$@", with: relative)
    }

    // MARK: Grouping

    private struct MonthSection: Identifiable {
        let id: String     // "yyyy-MM" — sortable
        let label: String  // "Mai 2026" — display
        let sessions: [WorkoutSession]
    }

    private var monthSections: [MonthSection] {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")  // stable sort key

        let labelFormatter = DateFormatter()
        labelFormatter.locale = .current
        labelFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

        let grouped = Dictionary(grouping: sessions) { keyFormatter.string(from: $0.startTime) }

        return grouped.compactMap { (key, sessions) -> MonthSection? in
            guard let first = sessions.first else { return nil }
            return MonthSection(
                id: key,
                label: labelFormatter.string(from: first.startTime),
                sessions: sessions.sorted { $0.startTime > $1.startTime }
            )
        }
        .sorted { $0.id > $1.id }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct HistorySessionRow: View {
    let session: WorkoutSession
    var showsDivider: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // DEL-065: Icon + Hintergrundfarbe je nach Session-Typ.
                //   * Cardio  → figure.run + Orange
                //   * Rest    → bed.double.fill + Orange (eigentlich gefiltert,
                //               aber Edge-Case-safe; Icon-Form ist der einzige
                //               Unterschied zu Cardio/Strength, siehe DEL-105)
                //   * Strength → Datums-Block in Orange wie bisher
                iconBadge
                VStack(alignment: .leading, spacing: 2) {
                    // DEL-129: displayDayName loest day.displayName + Snapshot-
                    // Fallback in einer Extension auf, sodass History-Eintraege
                    // im EN/TR-Modus korrekt rendern.
                    HStack(spacing: 6) {
                        Text(session.displayDayName)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        // README 2.11: unterscheidet einen vorzeitig gespeicherten
                        // Zeitformat-Lauf von einem vollstaendigen beim Durch-
                        // blaettern - sonst liest sich die Kennzahl in `statsLine`
                        // gegen einen vollen Lauf falsch.
                        if isEarlySaveTimedFormat {
                            DeltiqPill(String(localized: "history.early.badge", bundle: .module), style: .neutral)
                        }
                    }
                    statsLine
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    /// README 2.11: siehe `WorkoutSummaryView.isEarlySaveTimedFormat` -
    /// dieselbe Bedingung, hier lokal dupliziert statt geteilt, da beide
    /// Views sonst keine gemeinsame Basis haben.
    private var isEarlySaveTimedFormat: Bool {
        session.timeFormatSnapshot != nil && !session.completedTarget
    }

    @ViewBuilder
    private var iconBadge: some View {
        // README 2.9: eigenes Icon fuer AMRAP/EMOM/Auf Zeit, analog zum
        // Cardio-/Rest-Sonderfall darueber - ein gemeinsames "stopwatch"
        // reicht, die Format-Differenzierung passiert schon in statsLine.
        if session.timeFormatSnapshot != nil {
            VStack {
                Image(systemName: "stopwatch")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .background(Color.deltiqOrange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if isCardioSession {
            // Cardio-Tag: figure.run-Symbol + Orange. Datum wandert als
            // kleiner Untertitel in die statsLine? Nein — wir behalten den
            // Datums-Stempel, aber mit Orange-Tint.
            VStack {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(dayMonthCompact)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 44, height: 44)
            .background(Color.deltiqOrange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if session.day?.type == .rest {
            VStack {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .background(Color.deltiqOrange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // DEL-105: Strength-Datums-Block uebernimmt den Brand-Akzent.
            // Cardio + Strength teilen sich damit den Orange-Ton — Differenzierung
            // laeuft jetzt nur noch ueber das Icon-Layout (figure.run vs Datum).
            VStack {
                Text(dayNumber)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(monthShort)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 44, height: 44)
            .background(Color.deltiqOrange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Kompakte Datums-Zeile fuer den Cardio-Badge, der nur ein Icon zeigt
    /// (Datum als Untertitel statt im Zentrum).
    private var dayMonthCompact: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: session.startTime)
    }

    /// DEL-063 + DEL-081: Drei-State-Stats-Zeile via `SessionCategory`.
    ///   * pureStrength → Dauer · Saetze · Volumen-kg
    ///   * pureCardio   → Dauer · Distanz · Ø-Pace
    ///   * mixed        → Dauer · Volumen · Distanz (Pace + Saetze entfallen
    ///     aus Platzgruenden; User sieht beide Hauptmetriken sofort)
    ///
    /// README 2.9: vierter State fuer Zeitformate, VOR `sessionCategory`
    /// geprueft - die liest aus `logs` und wuerde Zeitformat-Sessions (nie
    /// ExerciseLogs) faelschlich als "0 Saetze · 0 kg" lesen.
    @ViewBuilder
    private var statsLine: some View {
        if let format = session.timeFormatSnapshot {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) \(String(localized: "unit.minutes.short", bundle: .module))")
                Text("•")
                Image(systemName: timedFormatIcon(format))
                Text(timedFormatValueText(format))
            }
            .font(.caption)
            .foregroundStyle(Color.Deltiq.textSecondary)
            .monospacedDigit()
        } else {
            timedFormatAgnosticStatsLine
        }
    }

    @ViewBuilder
    private var timedFormatAgnosticStatsLine: some View {
        switch session.sessionCategory {
        case .pureCardio:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) \(String(localized: "unit.minutes.short", bundle: .module))")
                Text("•")
                Image(systemName: "figure.run")
                Text(totalDistanceText)
                Text("•")
                Image(systemName: "stopwatch")
                Text(averagePaceText)
            }
            .font(.caption)
            .foregroundStyle(Color.Deltiq.textSecondary)
            .monospacedDigit()

        case .mixed:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) \(String(localized: "unit.minutes.short", bundle: .module))")
                Text("•")
                Image(systemName: "scalemass")
                Text("\(session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals) kg")
                Text("•")
                Image(systemName: "figure.run")
                Text(totalDistanceText)
            }
            .font(.caption)
            .foregroundStyle(Color.Deltiq.textSecondary)
            .monospacedDigit()

        case .pureStrength:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) \(String(localized: "unit.minutes.short", bundle: .module))")
                Text("•")
                Image(systemName: "list.number")
                Text("\(session.totalSets)")
                Text("•")
                Image(systemName: "scalemass")
                Text("\(session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals) kg")
            }
            .font(.caption)
            .foregroundStyle(Color.Deltiq.textSecondary)
            .monospacedDigit()
        }
    }

    private func timedFormatIcon(_ format: WorkoutTimeFormat) -> String {
        switch format {
        case .amrap: return "repeat"
        case .emom: return "checkmark.circle"
        case .forTime: return "flag.checkered"
        }
    }

    /// Bare Zahl statt Zahl+Einheit — gleiche Konvention wie "list.number"
    /// oben fuer Saetze: das Icon traegt die Bedeutung, der Wert bleibt kurz
    /// genug fuer die einzeilige Kompakt-Zeile.
    private func timedFormatValueText(_ format: WorkoutTimeFormat) -> String {
        switch format {
        case .amrap: return "\(session.roundsCompleted ?? 0)"
        case .emom: return "\(session.completedMinuteCount ?? 0)"
        case .forTime: return PaceCalculator.formatDuration(session.finishTimeSeconds ?? 0)
        }
    }

    /// DEL-081: True nur fuer reine Cardio-Sessions — Mixed-Sessions bekommen
    /// jetzt das Strength-Style-Icon (Datums-Block) statt des Run-Badge, weil
    /// Strength ueberwiegt visuell wenn beides drin ist.
    private var isCardioSession: Bool {
        session.sessionCategory == .pureCardio
    }

    private var totalDistanceText: String {
        let total = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        guard total > 0 else { return "—" }
        if total == total.rounded() {
            return "\(Int(total)) km"
        }
        return "\(total.truncated(to: 2).formattedTwoDecimals) km"
    }

    private var averagePaceText: String {
        let totalKm = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        let totalSec = session.logs.compactMap(\.durationSeconds).reduce(0, +)
        guard totalKm > 0, totalSec > 0,
              let pace = PaceCalculator.minutesPerKm(distanceKm: totalKm, durationSeconds: totalSec)
        else { return "—:——" }
        let total = Int((pace * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d"
        return formatter.string(from: session.startTime)
    }

    private var monthShort: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "LLL"
        return formatter.string(from: session.startTime).uppercased()
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("History mit einer Session") {
    NavigationStack {
        WorkoutHistoryView()
    }
    .modelContainer(PreviewSeed.activeSessionContainer)
    .environment(AppNavigation())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Leere History") {
    NavigationStack {
        WorkoutHistoryView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
    .environment(AppNavigation())
}
#endif
#endif
