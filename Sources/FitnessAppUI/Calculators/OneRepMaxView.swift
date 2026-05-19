#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// 1RM calculator: weight + reps -> Epley / Brzycki / average estimate, with a
/// percentage table so the user knows what to load for hypertrophy / strength work.
@available(iOS 17.0, macOS 14.0, *)
public struct OneRepMaxView: View {

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var weight: Double?
    @State private var reps:   Int = 5

    public init() {}

    private var unit: String { weightUnitRaw == "lbs" ? "lbs" : "kg" }

    public var body: some View {
        Form {
            inputsSection
            estimatesSection
            percentageTableSection
        }
        .navigationTitle(Text("calc.index.oneRm.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
    }

    // MARK: Sections

    private var inputsSection: some View {
        // `Section(_ titleKey:content:footer:)` (positional title + footer) confuses
        // the macOS 14 type checker. Use the explicit `header:` / `footer:` form,
        // which only matches one overload.
        Section {
            TextField(value: $weight, format: .number, prompt: Text("calc.oneRm.weightPlaceholder", bundle: .module)) {
                Text(String(format: String(localized: "calc.oneRm.weightLabel", bundle: .module), unit))
            }
            .decimalKeyboard()

            Stepper(value: $reps, in: 1...36) {
                LabeledContent {
                    Text("\(reps)")
                } label: {
                    Text("calc.oneRm.reps", bundle: .module)
                }
            }
        } header: {
            Text("calc.oneRm.section.input", bundle: .module)
        } footer: {
            Text("calc.oneRm.input.footer", bundle: .module)
                .font(.footnote)
        }
    }

    private var estimatesSection: some View {
        Section {
            if let weight,
               let epley   = ExerciseCalculations.estimate1RM(weightKg: weight, reps: reps),
               let brzycki = ExerciseCalculations.estimate1RMBrzycki(weightKg: weight, reps: reps),
               let average = ExerciseCalculations.estimate1RMAverage(weightKg: weight, reps: reps)
            {
                row("Epley",   value: epley)
                row("Brzycki", value: brzycki)
                row(String(localized: "calc.oneRm.row.average", bundle: .module), value: average, highlight: true)
            } else {
                Text("calc.oneRm.weightRequired", bundle: .module)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } header: {
            Text("calc.oneRm.section.estimate", bundle: .module)
        }
    }

    private var percentageTableSection: some View {
        Section {
            if let weight,
               let avg = ExerciseCalculations.estimate1RMAverage(weightKg: weight, reps: reps)
            {
                ForEach(percentageTable, id: \.percent) { entry in
                    HStack {
                        Text("\(Int(entry.percent * 100)) %")
                            .frame(width: 56, alignment: .leading)
                            .monospacedDigit()
                        Text("\((avg * entry.percent).truncated(to: 2).formattedTwoDecimals) \(unit)")
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: String(localized: "calc.oneRm.repsHint", bundle: .module), entry.repsHint))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            } else {
                Text("calc.oneRm.tableEmpty", bundle: .module)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } header: {
            Text("calc.oneRm.section.percentages", bundle: .module)
        } footer: {
            Text("calc.oneRm.percentages.footer", bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: Row helper

    private func row(_ label: String, value: Double, highlight: Bool = false) -> some View {
        LabeledContent {
            Text("\(value.truncated(to: 2).formattedTwoDecimals) \(unit)")
                .fontWeight(highlight ? .semibold : .regular)
                .monospacedDigit()
        } label: {
            Text(label)
                .fontWeight(highlight ? .semibold : .regular)
        }
    }

    // MARK: %1RM table reference

    private struct PercentRow {
        let percent: Double
        let repsHint: Int
    }

    /// Classic %1RM-to-reps mapping. The hint is the rep count typically achievable at
    /// that intensity for a trained lifter. Sources: NSCA, Prilepin, common bro-science.
    private let percentageTable: [PercentRow] = [
        PercentRow(percent: 1.00, repsHint: 1),
        PercentRow(percent: 0.95, repsHint: 2),
        PercentRow(percent: 0.90, repsHint: 4),
        PercentRow(percent: 0.85, repsHint: 6),
        PercentRow(percent: 0.80, repsHint: 8),
        PercentRow(percent: 0.75, repsHint: 10),
        PercentRow(percent: 0.70, repsHint: 12),
        PercentRow(percent: 0.65, repsHint: 15)
    ]
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        OneRepMaxView()
    }
}
#endif
#endif
