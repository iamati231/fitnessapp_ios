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
                    "Noch keine Workouts",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Beende dein erstes Training, um deine Historie zu sehen.")
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
        .navigationTitle("Historie")
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
            VStack {
                Text(dayNumber)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(monthShort)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 44, height: 44)
            .background(Color.blue.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.dayName ?? "Training")
                    .font(.body.weight(.semibold))
                statsLine
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statsLine: some View {
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
