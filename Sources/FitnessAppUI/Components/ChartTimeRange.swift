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

    /// Harte X-Achsen-Domain, die HEUTE endet. `nil` fuer `.max` (Auto-Scale
    /// gegen die echten Datenpunkte).
    ///
    /// Wichtig: die Domain endet bewusst bei `now` (nicht beim letzten
    /// Trainings-Punkt), damit der User auch dann ein Gefuehl fuer die
    /// Zeitabstaende bekommt, wenn das letzte Training ein paar Tage her ist.
    func domain(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard let monthsBack,
              let start = calendar.date(byAdding: .month, value: -monthsBack, to: now)
        else { return nil }
        return start...now
    }

    /// Untere Grenze der Domain = Cutoff fuer die Punkt-Filterung. `nil` =
    /// kein Filter (`.max` zeigt alle Punkte).
    func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        domain(now: now, calendar: calendar)?.lowerBound
    }

    /// Tick-Abstand (in Tagen) fuer die X-Achsen-Labels. `nil` → automatische
    /// Verteilung (`.automatic(desiredCount:)`). Werte so gewaehlt, dass sich
    /// die Datums-Texte bei der jeweiligen Domain-Breite nicht ueberschneiden.
    var axisStrideDays: Int? {
        switch self {
        case .oneMonth:    return 14   // ~3 Ticks ueber 1 Monat (Anfang/Mitte/Ende)
        case .threeMonths: return 30   // ~3-4 Ticks ueber 3 Monate
        case .max:         return nil  // Auto — Spannweite unbekannt
        }
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
