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
        .navigationTitle("1RM-Rechner")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Sections

    private var inputsSection: some View {
        // `Section(_ titleKey:content:footer:)` (positional title + footer) confuses
        // the macOS 14 type checker. Use the explicit `header:` / `footer:` form,
        // which only matches one overload.
        Section {
            TextField(value: $weight, format: .number, prompt: Text("z.B. 100")) {
                Text("Gewicht (\(unit))")
            }
            .decimalKeyboard()

            Stepper(value: $reps, in: 1...36) {
                LabeledContent("Wiederholungen", value: "\(reps)")
            }
        } header: {
            Text("Eingabe")
        } footer: {
            Text("Gueltig fuer 1-36 Reps. Bei sehr hohen Reps wird die Schaetzung unzuverlaessig — die Formeln liefern nur fuer den Hypertrophie- bis Kraft-Bereich (~1-12 Reps) brauchbare Werte.")
                .font(.footnote)
        }
    }

    private var estimatesSection: some View {
        Section("Geschaetztes 1RM") {
            if let weight,
               let epley   = ExerciseCalculations.estimate1RM(weightKg: weight, reps: reps),
               let brzycki = ExerciseCalculations.estimate1RMBrzycki(weightKg: weight, reps: reps),
               let average = ExerciseCalculations.estimate1RMAverage(weightKg: weight, reps: reps)
            {
                row("Epley",   value: epley)
                row("Brzycki", value: brzycki)
                row("Mittelwert", value: average, highlight: true)
            } else {
                Text("Trag Gewicht > 0 ein.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
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
                        Text("~ \(entry.repsHint) Reps")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            } else {
                Text("Tabelle erscheint, sobald 1RM berechnet ist.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } header: {
            Text("Trainings-Last (vom Mittelwert-1RM)")
        } footer: {
            Text("Rep-Hints sind Faustwerte. Effektive Reps haengen vom Trainings-Status und der Bewegung ab.")
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
