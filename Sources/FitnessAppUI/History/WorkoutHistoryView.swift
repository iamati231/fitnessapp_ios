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

    // Rest-day-marker sessions (skipped rest days from the Dashboard) live
    // in the store with isCompleted=true so the PlanNavigator advances its
    // pointer, but they aren't workouts and don't belong in History.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    public init() {}

    public var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    String(localized: "history.empty.title", bundle: .module),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("history.empty.description", bundle: .module)
                )
            } else {
                List {
                    ForEach(monthSections) { section in
                        Section(section.label) {
                            ForEach(section.sessions) { session in
                                NavigationLink {
                                    WorkoutSummaryView(session: session, isReadOnly: true)
                                } label: {
                                    HistorySessionRow(session: session)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("dashboard.history.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
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

    var body: some View {
        HStack(spacing: 12) {
            // DEL-065: Icon + Hintergrundfarbe je nach Session-Typ.
            //   * Cardio  → figure.run + orange
            //   * Rest    → bed.double.fill + purple (eigentlich gefiltert,
            //               aber Edge-Case-safe)
            //   * Strength → Datums-Block in blau wie bisher
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(session.dayName ?? "Training")
                    .font(.body.weight(.semibold))
                statsLine
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var iconBadge: some View {
        if isCardioSession {
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
            .background(Color.purple.gradient)
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
    @ViewBuilder
    private var statsLine: some View {
        switch session.sessionCategory {
        case .pureCardio:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) Min")
                Text("•")
                Image(systemName: "figure.run")
                Text(totalDistanceText)
                Text("•")
                Image(systemName: "stopwatch")
                Text(averagePaceText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()

        case .mixed:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) Min")
                Text("•")
                Image(systemName: "scalemass")
                Text("\(session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals) kg")
                Text("•")
                Image(systemName: "figure.run")
                Text(totalDistanceText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()

        case .pureStrength:
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("\(session.durationMinutes) Min")
                Text("•")
                Image(systemName: "list.number")
                Text("\(session.totalSets)")
                Text("•")
                Image(systemName: "scalemass")
                Text("\(session.totalVolumeKg.truncated(to: 0).formattedTwoDecimals) kg")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
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
