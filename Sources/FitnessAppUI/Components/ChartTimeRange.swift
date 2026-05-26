#if canImport(SwiftUI)
import SwiftUI
import Charts

/// DEL-152: Zeitbereichs-Filter fuer die Dashboard-Trend-Charts
/// (Compound-Lift-Trend + Cardio-Pace-Trend).
///
/// Bei langfristiger Nutzung wird die X-Achse mit allen historischen Punkten
/// gedraengt. Dieser Filter klemmt die sichtbare Domain auf 1 / 3 Monate
/// (oder `max` = alle Daten) und sorgt fuer lesbare Achsen-Labels.
///
/// `String`-RawValue, damit `@AppStorage` den gewaehlten Bereich direkt
/// persistieren kann (RawRepresentable-Support, RawValue == String).
enum ChartTimeRange: String, CaseIterable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case max

    var id: String { rawValue }

    /// Kompaktes Label fuer den Segmented-Picker ("1M" / "3M" / "Max").
    var label: String {
        switch self {
        case .oneMonth:    return String(localized: "chart.timeRange.oneMonth", bundle: .module)
        case .threeMonths: return String(localized: "chart.timeRange.threeMonths", bundle: .module)
        case .max:         return String(localized: "chart.timeRange.max", bundle: .module)
        }
    }

    /// Anzahl Monate zurueck ab `now`. `nil` fuer `.max` (keine Domain-Klemme).
    private var monthsBack: Int? {
        switch self {
        case .oneMonth:    return 1
        case .threeMonths: return 3
        case .max:         return nil
        }
    }

    /// Visueller Buffer (in Tagen) an JEDER Domain-Kante. Verhindert, dass der
    /// aktuellste Punkt rechts und der aelteste links an der Grid-Kante kleben.
    private static let edgePaddingDays = 2

    /// Cutoff fuer die Punkt-Filterung — die "echte" Monats-Grenze (heute
    /// minus N Monate), OHNE Padding. `nil` = kein Filter (`.max`).
    ///
    /// Wichtig: das Filtern laeuft gegen die echte Grenze, das Padding ist
    /// rein visuell (siehe `domain`). So liegen Punkte mit etwas Luft zur
    /// linken Kante, ohne dass zusaetzliche Punkte sichtbar werden.
    func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let monthsBack else { return nil }
        return calendar.date(byAdding: .month, value: -monthsBack, to: now)
    }

    /// Gepolsterte X-Achsen-Domain. Endet bei `now + edgePadding` und beginnt
    /// bei `cutoff - edgePadding`, sodass:
    ///   * der heutige Tag NIE an der rechten Kante klebt (rechtes Ende ist
    ///     immer "heute + 2 Tage"),
    ///   * der aelteste Punkt etwas Luft zur linken Kante hat.
    /// `nil` fuer `.max` → Swift-Charts-Auto-Scaling gegen die echten Punkte.
    func domain(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard let cutoff = cutoff(now: now, calendar: calendar) else { return nil }
        let pad = Self.edgePaddingDays
        let lower = calendar.date(byAdding: .day, value: -pad, to: cutoff) ?? cutoff
        let upper = calendar.date(byAdding: .day, value: pad, to: now) ?? now
        return lower...upper
    }

    /// Feste, kalender-verankerte Tick-Daten fuer die X-Achsen-Labels —
    /// UNABHAENGIG von den vorliegenden Trainings-Datenpunkten, damit die
    /// Labels nicht je nach Datenlage hin- und herspringen.
    ///
    ///   * `.oneMonth`   → 1. + 15. jedes Monats im sichtbaren Fenster.
    ///   * `.threeMonths`→ 1. jedes Monats (3-4 Labels).
    ///   * `.max`        → `nil` → `.automatic(desiredCount:)` (Spannweite
    ///     unbekannt, fixe Kalender-Anker waeren ggf. zu dicht/zu spaerlich).
    func axisDates(now: Date = Date(), calendar: Calendar = .current) -> [Date]? {
        guard let domain = domain(now: now, calendar: calendar) else { return nil }
        let daysOfMonth: [Int]
        switch self {
        case .oneMonth:    daysOfMonth = [1, 15]
        case .threeMonths: daysOfMonth = [1]
        case .max:         return nil
        }
        return Self.calendarTicks(
            daysOfMonth: daysOfMonth,
            within: domain,
            calendar: calendar
        )
    }

    /// Erzeugt Kalender-Anker (bestimmte Tage im Monat) innerhalb eines
    /// Datums-Fensters. Iteriert Monat fuer Monat ueber das Fenster und baut
    /// die Tage via `DateComponents` (robuster als `date(bySetting:)`).
    private static func calendarTicks(
        daysOfMonth: [Int],
        within window: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Date] {
        var result: [Date] = []
        // Beim 1. des Monats der unteren Fenster-Grenze starten.
        guard var cursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: window.lowerBound)
        ) else { return [] }

        while cursor <= window.upperBound {
            let comps = calendar.dateComponents([.year, .month], from: cursor)
            for day in daysOfMonth {
                var dc = DateComponents()
                dc.year = comps.year
                dc.month = comps.month
                dc.day = day
                if let tick = calendar.date(from: dc),
                   window.contains(tick) {
                    result.append(tick)
                }
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}

// MARK: - Picker-Component

/// DEL-152: Kompakter Segmented-Picker fuer `ChartTimeRange`. Wird im
/// Chart-Header platziert. Bindet typischerweise an ein `@AppStorage`-Binding.
@available(iOS 17.0, macOS 14.0, *)
struct ChartTimeRangePicker: View {
    @Binding var selection: ChartTimeRange

    var body: some View {
        Picker(selection: $selection) {
            ForEach(ChartTimeRange.allCases) { range in
                Text(range.label).tag(range)
            }
        } label: {
            // Label leer — der Picker sitzt unter einem eigenen Card-Header.
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - View-Helper

@available(iOS 17.0, macOS 14.0, *)
extension View {
    /// DEL-152: Wendet `chartXScale(domain:)` nur an, wenn eine Domain gesetzt
    /// ist. Fuer `.max` (Domain == nil) bleibt das Auto-Scaling von Swift
    /// Charts aktiv.
    @ViewBuilder
    func chartXDomainIfSet(_ domain: ClosedRange<Date>?) -> some View {
        if let domain {
            self.chartXScale(domain: domain)
        } else {
            self
        }
    }
}
#endif
