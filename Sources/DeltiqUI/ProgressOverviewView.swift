#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import Charts
import DeltiqCore
import DeltiqData

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// Einstiegspunkt "Fortschritt & Messungen" unter "Mehr" (UI-Ticket
/// "Tab-Leiste vereinfachen", 2026-11-06) — ersetzt den entfallenen
/// `AppTab.measurement`-Tab, erreichbar ueber `ProgressRoute.overview`
/// (siehe AppNavigation.swift), genau eine Ebene tief wie `CalculatorsView`.
///
/// Reiner Lese-/Uebersichts-Einstieg: `MeasurementView` bleibt unveraendert
/// das Eingabe-/Bearbeitungsformular (siehe dortige Doku) — diese View
/// fasst nur den aktuellen Stand, die Entwicklung und die Historie
/// zusammen und verlinkt in dasselbe Formular. Keine zweite Berechnung fuer
/// KFA/BMI/FFMI: dieselbe `BodyCalculations.computeDerivedFields` wie
/// `MeasurementView.derivedMetrics`, dieselbe `HistoryRow` wie dessen
/// Messungshistorie.
@available(iOS 17.0, macOS 14.0, *)
public struct ProgressOverviewView: View {

    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]
    /// Reverse-chronologisch — `.first` ist die juengste Messung, identisch
    /// zur Query in `DashboardView`/`MeasurementView`.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    /// "Neue Messung erfassen" (Abschnitt D) — Push ueber den Header-Plus,
    /// identisches Pattern zu `NutritionDayView`s "Mahlzeit hinzufuegen".
    @State private var showingNewMeasurement = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.group.progress", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    DeltiqHeaderAction(
                        systemImage: "plus",
                        accessibilityLabel: loc("progress.action.newMeasurement")
                    ) {
                        showingNewMeasurement = true
                    }
                ]
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let profile = profiles.first {
                        if let latest = measurements.first {
                            currentSection(profile: profile, latest: latest)
                            developmentSection
                        } else {
                            // Ticket: "Keine kuenstlichen Verlaeufe aus
                            // einzelnen Messpunkten" — ohne jede Messung gibt
                            // es noch nicht einmal einen "aktuellen Stand".
                            DashboardEmptyState(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "dashboard.trend.emptyTitle",
                                description: "dashboard.trend.emptyDescription"
                            )
                            .deltiqCardStyle()
                        }
                        historySection
                    } else {
                        ContentUnavailableView(
                            loc("measurement.empty.title"),
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("measurement.empty.description", bundle: .module)
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
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
        .navigationDestination(isPresented: $showingNewMeasurement) {
            MeasurementView()
        }
    }

    // MARK: - A. Aktueller Messstand

    @ViewBuilder
    private func currentSection(profile: UserBodyProfile, latest: BodyMeasurement) -> some View {
        DeltiqSection(loc("progress.section.current.title").uppercased()) {
            DeltiqControlRow(label: loc("progress.current.date.label")) {
                valueText(latest.date.formatted(date: .abbreviated, time: .omitted))
            }
            DeltiqControlRow(
                label: loc("progress.current.weight.label"),
                showsDivider: hasAnyAdditionalValue(latest) || derivedMetrics(profile: profile, latest: latest) != nil
            ) {
                valueText(formattedWeight(latest.weightKg))
            }
            additionalValueRows(latest)
            if let derived = derivedMetrics(profile: profile, latest: latest) {
                metricRow(loc("measurement.derived.bmi"), value: derived.bmi)
                if let navy = derived.navyBodyFatPct {
                    metricRow(loc("measurement.derived.navy.label"), value: navy, suffix: " %", showsDivider: false)
                } else {
                    metricRow(loc("measurement.derived.deurenberg"), value: derived.deurenbergBodyFatPct, suffix: " %", showsDivider: false)
                }
            }
        }
    }

    /// "Weitere zuletzt erfasste Koerperwerte, sofern vorhanden" (Ticket
    /// Abschnitt A) — nur nicht-nil Umfaenge der juengsten Messung, in
    /// derselben Reihenfolge wie `MeasurementView`s Pflicht-/Zusatzfelder.
    private func hasAnyAdditionalValue(_ m: BodyMeasurement) -> Bool {
        [m.neckCm, m.waistCm, m.hipCm, m.chestCm, m.thighCm, m.calfCm].contains { $0 != nil }
    }

    @ViewBuilder
    private func additionalValueRows(_ m: BodyMeasurement) -> some View {
        let rows: [(String.LocalizationValue, Double?)] = [
            ("measurement.field.neck", m.neckCm),
            ("measurement.field.waist", m.waistCm),
            ("measurement.field.hip", m.hipCm),
            ("measurement.field.chest", m.chestCm),
            ("measurement.field.thigh", m.thighCm),
            ("measurement.field.calf", m.calfCm)
        ]
        let present = rows.compactMap { key, value in value.map { (key, $0) } }
        ForEach(Array(present.enumerated()), id: \.offset) { idx, entry in
            let (key, value) = entry
            DeltiqControlRow(label: circumferenceLabel(key), showsDivider: idx < present.count - 1) {
                valueText(formattedCm(value))
            }
        }
    }

    // shortcut: depends on xcstrings values containing literal "(cm)"; update if key values change.
    // Identisch zu `MeasurementView.circumferenceLabel` — derselbe Grund:
    // nur EIN gemeinsames Label pro Umfang-Feld fuer kg/cm- und lbs/in-Modus,
    // keine zweite xcstrings-Variante pro Einheit.
    private func circumferenceLabel(_ key: String.LocalizationValue) -> String {
        weightUnitRaw == "lbs"
            ? loc(key).replacingOccurrences(of: "(cm)", with: "(in)")
            : loc(key)
    }

    private func derivedMetrics(profile: UserBodyProfile, latest: BodyMeasurement) -> DerivedBodyMetrics? {
        guard latest.weightKg > 0, profile.heightCm > 0 else { return nil }
        return BodyCalculations.computeDerivedFields(
            weightKg: latest.weightKg,
            heightCm: profile.heightCm,
            ageYears: profile.ageYears,
            profile: profile.profile,
            neckCm: latest.neckCm,
            waistCm: latest.waistCm,
            hipCm: latest.hipCm
        )
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .fitnessNumberStyle()
    }

    @ViewBuilder
    private func metricRow(_ label: String, value: Double, suffix: String = "", showsDivider: Bool = true) -> some View {
        DeltiqControlRow(label: label, showsDivider: showsDivider) {
            valueText(value.truncated(to: 2).formattedTwoDecimals + suffix)
        }
    }

    private func formattedWeight(_ kg: Double) -> String {
        let unit = WeightUnit(rawSetting: weightUnitRaw)
        return unit.fromKg(kg).formattedWeightInput() + " \(unit.weightLabel)"
    }

    private func formattedCm(_ cm: Double) -> String {
        let unit = WeightUnit(rawSetting: weightUnitRaw)
        return unit.fromCm(cm).truncated(to: 2).formattedTwoDecimals + " \(unit.heightLabel)"
    }

    // MARK: - B. Entwicklung

    /// Mindestens zwei Messungen, bevor ueberhaupt ein Verlauf gezeigt wird
    /// — ein einzelner Punkt waere ein erfundener "Verlauf" (Ticket: "Keine
    /// kuenstlichen Verlaeufe aus einzelnen Messpunkten").
    @ViewBuilder
    private var developmentSection: some View {
        DeltiqSection(loc("progress.section.development.title").uppercased()) {
            if measurements.count < 2 {
                DashboardEmptyState(
                    icon: "chart.xyaxis.line",
                    title: "progress.development.needMore.title",
                    description: "progress.development.needMore.description"
                )
            } else {
                weightChart
                if let delta = BodyCalculations.weeklyWeightDelta(measurements: measurements) {
                    let unit = WeightUnit(rawSetting: weightUnitRaw)
                    let displayDelta = unit.fromKg(abs(delta))
                    DeltiqControlRow(label: loc("progress.development.weightChange.label"), showsDivider: false) {
                        valueText((delta >= 0 ? "+" : "−") + displayDelta.truncated(to: 2).formattedTwoDecimals + " \(unit.weightLabel)")
                    }
                }
            }
        }
    }

    /// Bewusst OHNE Prognose-/Ziel-Linie (anders als `DashboardView.trendChart`,
    /// dessen optionales Dashboard-Widget das bereits abdeckt) — das Ticket
    /// verlangt fuer diese Uebersicht nur den tatsaechlichen Verlauf mit
    /// Datum und Einheit, keine zweite Forecast-Implementierung.
    private var weightChart: some View {
        let unit = WeightUnit(rawSetting: weightUnitRaw)
        let points: [(date: Date, weight: Double)] = measurements.reversed().map { ($0.date, unit.fromKg($0.weightKg)) }
        let seriesLabel = weightUnitRaw == "lbs" ? "Gewicht (lbs)" : "Gewicht (kg)"
        return Chart {
            ForEach(points, id: \.date) { p in
                LineMark(
                    x: .value(String(localized: "chart.axis.date", bundle: .module), p.date),
                    y: .value(seriesLabel, p.weight)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.deltiqOrange)

                PointMark(
                    x: .value(String(localized: "chart.axis.date", bundle: .module), p.date),
                    y: .value(seriesLabel, p.weight)
                )
                .foregroundStyle(Color.deltiqOrange)
                .symbolSize(40)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 180)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - C. Messungshistorie

    @ViewBuilder
    private var historySection: some View {
        DeltiqSection(loc("measurement.section.history").uppercased()) {
            if measurements.isEmpty {
                DeltiqRow(label: loc("measurement.history.empty"), showsDivider: false)
            } else {
                let recent = Array(measurements.prefix(12))
                ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { idx, m in
                    historyRow(m, showsDivider: idx < recent.count - 1)
                }
                if measurements.count > 12 {
                    hintRow(
                        String(localized: "measurement.history.older", bundle: .module)
                            .replacingOccurrences(of: "%lld", with: "\(measurements.count - 12)")
                    )
                } else {
                    hintRow(loc("measurement.history.hint"))
                }
            }
        }
    }

    /// Identisch zu `MeasurementView.historyRow` — gleiche `HistoryRow`
    /// (dort `internal` statt `private` gemacht), gleiche Bearbeiten-
    /// Navigation, gleicher Loesch-/Validierungsschutz (lebt in
    /// `MeasurementView(editing:)` selbst, hier unveraendert wiederverwendet).
    private func historyRow(_ measurement: BodyMeasurement, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                MeasurementView(editing: measurement)
            } label: {
                HStack(spacing: 12) {
                    HistoryRow(measurement: measurement)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Deltiq.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Messungen") {
    NavigationStack {
        ProgressOverviewView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil") {
    NavigationStack {
        ProgressOverviewView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
}
#endif
#endif
