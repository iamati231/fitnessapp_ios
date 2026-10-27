#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppCore

/// Plate calculator UI: target + bar + per-plate inventory editor + live visualization.
///
/// Reads / writes the global "weight_unit" setting via `@AppStorage` (kg/lbs). Switching
/// units resets target, bar, and inventory back to the unit-appropriate defaults — the
/// alternative (trying to convert across units) would round into nonsense plate stacks.
@available(iOS 17.0, macOS 14.0, *)
public struct PlateCalculatorView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var targetWeight: Double?
    @State private var barWeight:    Double?
    @State private var inventory:    [Double: Int] = PlateCalculator.Unit.kg.defaultInventory

    public init() {}

    private var unit: PlateCalculator.Unit {
        PlateCalculator.Unit(rawValue: weightUnitRaw) ?? .kg
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: Eyebrow zeigt den Elternscreen (Rechner-Hub),
            // nicht den Tab - selbes Muster wie WaterTrackerView.
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "calc.index.plate.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                unitCard
                inputsCard
                resultsCard
                inventoryCard
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
        .keyboardDismissToolbar()
        .onAppear { ensureDefaultsForCurrentUnit() }
        .onChange(of: weightUnitRaw) { _, _ in resetForCurrentUnit() }
    }

    // MARK: Sections

    private var unitCard: some View {
        DeltiqSection(String(localized: "calc.plate.unit.label", bundle: .module).uppercased()) {
            DeltiqSegmentedPicker(
                options: [
                    DeltiqSegmentedOption("kg", label: "kg"),
                    DeltiqSegmentedOption("lbs", label: "lbs")
                ],
                selection: $weightUnitRaw
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            hintRow(String(localized: "calc.plate.unit.footer", bundle: .module))
        }
    }

    private var inputsCard: some View {
        DeltiqSection(String(localized: "calc.plate.section.input", bundle: .module).uppercased()) {
            // Cap 2026-05-21: hartes Maximum auf `unit.maxTarget` (500 kg / 1100 lbs) bzw.
            // `unit.maxBar` (30 kg / 65 lbs) - selbes Pattern wie in SetRow.weightInput -
            // sofortiges Snap auf den Max-Wert verhindert utopische Eingaben (Vertipper,
            // Pasten). Reagiert AUCH bei Unit-Wechsel.
            let targetLabel = String(format: String(localized: "calc.plate.target", bundle: .module), unit.rawValue)
            DeltiqControlRow(label: targetLabel) {
                decimalField(
                    targetLabel,
                    value: $targetWeight,
                    placeholder: String(format: String(localized: "calc.placeholderExample", bundle: .module), unit == .kg ? "100" : "225")
                )
            }
            .onChange(of: targetWeight) { _, newValue in
                if let w = newValue, w > unit.maxTarget {
                    targetWeight = unit.maxTarget
                }
            }

            let barLabel = String(format: String(localized: "calc.plate.bar", bundle: .module), unit.rawValue)
            DeltiqControlRow(label: barLabel, showsDivider: false) {
                decimalField(
                    barLabel,
                    value: $barWeight,
                    placeholder: String(format: String(localized: "calc.placeholderExample", bundle: .module), unit == .kg ? "20" : "45")
                )
            }
            .onChange(of: barWeight) { _, newValue in
                if let w = newValue, w > unit.maxBar {
                    barWeight = unit.maxBar
                }
            }
        }
    }

    private var resultsCard: some View {
        DeltiqSection(String(localized: "calc.plate.section.results", bundle: .module).uppercased()) {
            if plates.isEmpty {
                Text(emptyResultHint)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    PlateBarVisualization(plates: plates, unit: unit)

                    HStack(alignment: .top) {
                        resultMetric(String(localized: "calc.plate.perSide", bundle: .module), value: "\(formatPlate(perSideLoaded)) \(unit.rawValue)")
                        Spacer()
                        resultMetric(String(localized: "calc.plate.loaded", bundle: .module), value: "\(formatPlate(actualTotal)) \(unit.rawValue)", highlight: true)
                    }

                    if isShortOfTarget {
                        shortOfTargetWarning
                    }

                    Text(breakdownText)
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .padding(14)
            }
        }
    }

    private var inventoryCard: some View {
        DeltiqSection(String(localized: "calc.plate.section.inventory", bundle: .module).uppercased()) {
            ForEach(unit.availablePlates, id: \.self) { plate in
                inventoryRow(for: plate)
            }
            DeltiqRow(
                icon: "arrow.counterclockwise",
                label: String(localized: "calc.plate.resetInventory", bundle: .module),
                showsDivider: false,
                action: { inventory = unit.defaultInventory }
            )
            // DEL-122: Unit-spezifischer Footer-Text — pro Einheit ein eigener
            // Catalog-Key, damit die Plate-Limits-Beschreibung in jeder Sprache
            // sauber unit-aware bleibt (kg → 25/20, lbs → 45/35).
            hintRow(String(localized: unit == .kg ? "calc.plate.inventoryFooter.kg" : "calc.plate.inventoryFooter.lbs", bundle: .module))
        }
    }

    private func inventoryRow(for plate: Double) -> some View {
        let cap = unit.defaultInventory[plate] ?? 0
        let count = inventory[plate] ?? 0
        return DeltiqControlRow(label: "\(formatPlate(plate)) \(unit.rawValue)") {
            HStack(spacing: 10) {
                Text(String(format: String(localized: "calc.plate.inventoryRow.count", bundle: .module), count))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(count == 0 ? Color.Deltiq.textTertiary : Color.Deltiq.textSecondary)
                Stepper(
                    "",
                    value: Binding(
                        get: { inventory[plate] ?? 0 },
                        set: { inventory[plate] = $0 }
                    ),
                    in: 0...cap
                )
                .labelsHidden()
            }
        }
    }

    // MARK: Row helpers

    /// DEL-106-Muster (siehe MeasurementView.decimalField): TextField mit Decimal-Keyboard,
    /// rechtsbuendig, `fitnessNumberStyle()`. Kein FocusState/Feld-Enum noetig — dieser
    /// Screen hat keine Previous/Next-Tastatur-Navigation zwischen Feldern.
    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    private func resultMetric(_ label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Color.Deltiq.textTertiary)
            Text(value)
                .font(.system(size: highlight ? 20 : 17, weight: highlight ? .heavy : .semibold))
                .foregroundStyle(highlight ? Color.deltiqOrange : Color.primary)
                .fitnessNumberStyle()
        }
    }

    private var shortOfTargetWarning: some View {
        let template = String(localized: "calc.plate.shortOfTarget", bundle: .module)
        return Label {
            Text(template
                .replacingOccurrences(of: "%1$@", with: formatPlate(actualTotal))
                .replacingOccurrences(of: "%2$@", with: unit.rawValue)
                .replacingOccurrences(of: "%3$@", with: formatDelta(targetDelta)))
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.caption)
        .foregroundStyle(Color.deltiqOrange)
    }

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    // MARK: Derived

    private var plates: [PlateConfig] {
        guard let targetWeight, let barWeight,
              targetWeight > 0, barWeight >= 0,
              targetWeight <= unit.maxTarget,
              barWeight <= unit.maxBar
        else { return [] }
        return PlateCalculator.calculate(
            targetKg: targetWeight,
            barKg: barWeight,
            plates: unit.availablePlates,
            inventory: inventory
        )
    }

    private var perSideLoaded: Double {
        plates.reduce(0.0) { $0 + Double($1.count) * $1.weight }
    }

    private var actualTotal: Double {
        (barWeight ?? 0) + 2 * perSideLoaded
    }

    private var targetDelta: Double {
        (targetWeight ?? 0) - actualTotal
    }

    private var isShortOfTarget: Bool {
        guard let targetWeight, targetWeight > 0 else { return false }
        return abs(targetDelta) > 0.01 && targetDelta > 0
    }

    private var breakdownText: String {
        plates.map { "\($0.count)x\(formatPlate($0.weight))" }.joined(separator: " + ")
    }

    private var emptyResultHint: String {
        if targetWeight == nil { return String(localized: "calc.plate.emptyHint.noTarget", bundle: .module) }
        if barWeight    == nil { return String(localized: "calc.plate.emptyHint.noBar",    bundle: .module) }
        if let t = targetWeight, let b = barWeight, t <= b {
            return String(localized: "calc.plate.emptyHint.targetTooLow", bundle: .module)
        }
        return String(localized: "calc.plate.emptyHint.noInventory", bundle: .module)
    }

    // MARK: Lifecycle helpers

    /// Ensures the inventory state is keyed by the current unit's plate set. Important
    /// when the view first appears with the persisted unit setting.
    private func ensureDefaultsForCurrentUnit() {
        let expectedPlates = Set(unit.availablePlates)
        let actualPlates   = Set(inventory.keys)
        if expectedPlates != actualPlates {
            inventory = unit.defaultInventory
            barWeight = unit == .kg ? 20 : 45
        }
    }

    private func resetForCurrentUnit() {
        targetWeight = nil
        barWeight = unit == .kg ? 20 : 45
        inventory = unit.defaultInventory
    }

    // MARK: Number formatting

    /// Integer-when-whole, decimal-otherwise — same as Android `formatW`.
    /// Locale-aware via `formattedTwoDecimals` for the decimal branch.
    private func formatPlate(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))" : w.formattedTwoDecimals
    }

    private func formatDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "Δ -" : "Δ +"
        return "\(sign)\(formatPlate(abs(delta))) \(unit.rawValue)"
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        PlateCalculatorView()
    }
}
#endif
#endif
