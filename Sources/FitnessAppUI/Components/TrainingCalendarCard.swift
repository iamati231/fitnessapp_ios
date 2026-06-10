#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-197: Trainings-Kalender-Card fürs Dashboard — Monatsraster mit
/// Workout-Dots plus Wochen-Streak-Pill im Header.
///
/// Bewusst eine EIGENE Komponenten-Datei statt weiterer computed
/// properties in der ohnehin übergroßen DashboardView. Die Card ist
/// dumm: sie bekommt das fertige `workoutDays`-Set + den Streak aus
/// dem Aggregator und kümmert sich nur um Monats-Navigation + Layout.
@available(iOS 17.0, macOS 14.0, *)
struct TrainingCalendarCard: View {

    /// Normalisierte Trainings-Tage (startOfDay) — Quelle:
    /// `TrainingCalendarAggregator.workoutDays`.
    let workoutDays: Set<Date>
    /// Konsekutive Trainings-Wochen — Quelle:
    /// `TrainingCalendarAggregator.weekStreak`.
    let streak: Int

    /// DEL-202: Tap auf einen Workout-Tag. Nil = Card ist read-only.
    /// Nur Tage MIT Workout sind tappbar — ein leerer Dienstag hat kein
    /// sinnvolles Detail.
    var onDaySelected: ((Date) -> Void)? = nil

    /// Anker des angezeigten Monats (erster Tag des Monats). Default:
    /// aktueller Monat; Chevrons blättern zurück/vor, vor maximal bis
    /// zum aktuellen Monat (Zukunft hat keine Workouts).
    @State private var displayedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            monthNavigator
            weekdayHeader
            dayGrid
        }
        .deltiqCardStyle()
        // DEL-202: .contain statt .combine — combine hätte die Monats-
        // Chevrons und die tappbaren Workout-Tage für VoiceOver
        // verschluckt. Die Zusammenfassung hängt am Header (s.u.).
        .accessibilityElement(children: .contain)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("dashboard.calendar.title", bundle: .module)
                .font(.headline)
                .accessibilityLabel(a11ySummary)
            Spacer()
            if streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text(String(
                        format: String(localized: "dashboard.calendar.streakFormat", bundle: .module),
                        streak
                    ))
                    .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.deltiqOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.deltiqOrange.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: Monats-Navigation

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))
            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isDisplayingCurrentMonth ? .tertiary : .secondary)
            .disabled(isDisplayingCurrentMonth)
        }
    }

    private func shiftMonth(by value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = shifted
        }
    }

    // MARK: Wochentags-Kopfzeile

    /// Locale-rotierte Kurz-Symbole (Mo-first in DE, So-first in US).
    private var rotatedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(rotatedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Tages-Raster

    /// Zellen des Monats: führende nils für den Offset des 1. Tags
    /// relativ zum Wochenbeginn, dann die Tage.
    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: day, to: interval.start))
        }
        return cells
    }

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 28)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isWorkout = workoutDays.contains(calendar.startOfDay(for: day))
        let label = dayCellLabel(day, isWorkout: isWorkout)
        // DEL-202: Workout-Tage werden tappbar, wenn der Parent einen
        // Callback liefert. Plain-Button, damit das Zellen-Layout
        // unverändert bleibt.
        if isWorkout, let onDaySelected {
            Button {
                onDaySelected(calendar.startOfDay(for: day))
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func dayCellLabel(_ day: Date, isWorkout: Bool) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date()
        return Text("\(calendar.component(.day, from: day))")
            .font(.caption2.monospacedDigit().weight(isWorkout ? .bold : .regular))
            .foregroundStyle(dayTextColor(isWorkout: isWorkout, isFuture: isFuture))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                Circle()
                    .fill(isWorkout ? Color.deltiqOrange.opacity(0.85) : Color.clear)
                    .frame(width: 26, height: 26)
            )
            .overlay(
                Circle()
                    .stroke(isToday ? Color.deltiqOrange : Color.clear, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
            )
    }

    private func dayTextColor(isWorkout: Bool, isFuture: Bool) -> Color {
        if isWorkout { return .white }
        if isFuture { return Color.secondary.opacity(0.4) }
        return .primary
    }

    // MARK: Accessibility

    private var a11ySummary: String {
        let monthWorkouts = monthCells
            .compactMap { $0 }
            .filter { workoutDays.contains(calendar.startOfDay(for: $0)) }
            .count
        return String(
            format: String(localized: "dashboard.calendar.a11y", bundle: .module),
            monthWorkouts, streak
        )
    }
}
#endif
