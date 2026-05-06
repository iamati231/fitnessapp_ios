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

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var targetWeight: Double?
    @State private var barWeight:    Double?
    @State private var inventory:    [Double: Int] = PlateCalculator.Unit.kg.defaultInventory

    public init() {}

    private var unit: PlateCalculator.Unit {
        PlateCalculator.Unit(rawValue: weightUnitRaw) ?? .kg
    }

    public var body: some View {
        Form {
            unitSection
            inputsSection
            resultsSection
            inventorySection
        }
        .navigationTitle("Hantel-Rechner")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { ensureDefaultsForCurrentUnit() }
        .onChange(of: weightUnitRaw) { _, _ in resetForCurrentUnit() }
    }

    // MARK: Sections

    private var unitSection: some View {
        Section {
            Picker("Einheit", selection: $weightUnitRaw) {
                Text("kg").tag("kg")
                Text("lbs").tag("lbs")
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("App-weit umschaltbar. DB speichert immer metrisch — nur die Anzeige aendert sich.")
                .font(.footnote)
        }
    }

    private var inputsSection: some View {
        Section("Zielgewicht & Stange") {
            TextField("Zielgewicht (\(unit.rawValue))",
                      value: $targetWeight, format: .number,
                      prompt: Text("z.B. \(unit == .kg ? "100" : "225")"))
                .decimalKeyboard()

            TextField("Stange (\(unit.rawValue))",
                      value: $barWeight, format: .number,
                      prompt: Text("z.B. \(unit == .kg ? "20" : "45")"))
                .decimalKeyboard()
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if let targetWeight, targetWeight > unit.maxTarget {
                    Text("Maximal \(formatPlate(unit.maxTarget)) \(unit.rawValue) Zielgewicht.")
                        .foregroundStyle(.red)
                }
                if let barWeight, barWeight > unit.maxBar {
                    Text("Maximal \(formatPlate(unit.maxBar)) \(unit.rawValue) Stange.")
                        .foregroundStyle(.red)
                }
            }
            .font(.footnote)
        }
    }

    private var resultsSection: some View {
        Section("Ergebnis") {
            if plates.isEmpty {
                Text(emptyResultHint)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                PlateBarVisualization(plates: plates, unit: unit)
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                LabeledContent("Pro Seite",
                    value: "\(formatPlate(perSideLoaded)) \(unit.rawValue)")
                LabeledContent("Geladen gesamt",
                    value: "\(formatPlate(actualTotal)) \(unit.rawValue)")
                if isShortOfTarget {
                    Label("Mit deinem Inventar nur \(formatPlate(actualTotal)) \(unit.rawValue) erreichbar (\(formatDelta(targetDelta))).",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(breakdownText)
                    .font(.callout.monospacedDigit())
            }
        }
    }

    private var inventorySection: some View {
        Section {
            ForEach(unit.availablePlates, id: \.self) { plate in
                inventoryRow(for: plate)
            }
            Button("Inventar zuruecksetzen") {
                inventory = unit.defaultInventory
            }
            .font(.callout)
        } header: {
            Text("Inventar pro Seite")
        } footer: {
            Text("Cap pro Plate: \(unit == .kg ? "25/20 kg → 10, alle anderen → 1" : "45/35 lbs → 10, alle anderen → 1"). Auf 0 setzen, wenn die Plate bei dir fehlt.")
                .font(.footnote)
        }
    }

    private func inventoryRow(for plate: Double) -> some View {
        let cap = unit.defaultInventory[plate] ?? 0
        let count = inventory[plate] ?? 0
        return HStack {
            Circle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 12, height: 12)
            Text("\(formatPlate(plate)) \(unit.rawValue)")
            Spacer()
            Text("\(count) Stk")
                .monospacedDigit()
                .foregroundStyle(count == 0 ? .secondary : .primary)
            Stepper("",
                value: Binding(
                    get: { inventory[plate] ?? 0 },
                    set: { inventory[plate] = $0 }
                ),
                in: 0...cap
            )
            .labelsHidden()
        }
    }

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
        if targetWeight == nil { return "Trag dein Zielgewicht ein." }
        if barWeight    == nil { return "Trag das Stangen-Gewicht ein." }
        if let t = targetWeight, let b = barWeight, t <= b {
            return "Zielgewicht muss schwerer sein als die Stange."
        }
        return "Mit dem aktuellen Inventar bleibt nichts ueber der Stange."
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
