#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// 1RM calculator: weight + reps -> Epley / Brzycki / average estimate, with a
/// percentage table so the user knows what to load for hypertrophy / strength work.
@available(iOS 17.0, macOS 14.0, *)
public struct OneRepMaxView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var weight: Double?
    @State private var reps:   Int = 5

    public init() {}

    private var unit: String { weightUnitRaw == "lbs" ? "lbs" : "kg" }

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: Eyebrow zeigt den Elternscreen (Rechner-Hub),
            // nicht den Tab - selbes Muster wie WaterTrackerView.
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "calc.index.oneRm.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                inputsCard
                estimatesCard
                percentageTableCard
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
    }

    // MARK: Sections

    private var inputsCard: some View {
        DeltiqSection(String(localized: "calc.oneRm.section.input", bundle: .module).uppercased()) {
            let weightLabel = String(format: String(localized: "calc.oneRm.weightLabel", bundle: .module), unit)
            DeltiqControlRow(label: weightLabel) {
                decimalField(
                    weightLabel,
                    value: $weight,
                    placeholder: String(localized: "calc.oneRm.weightPlaceholder", bundle: .module)
                )
            }
            DeltiqControlRow(label: String(localized: "calc.oneRm.reps", bundle: .module), showsDivider: false) {
                Stepper(value: $reps, in: 1...36) {
                    Text("\(reps)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary)
                        .fitnessNumberStyle()
                }
            }
            hintRow(String(localized: "calc.oneRm.input.footer", bundle: .module))
        }
    }

    private var estimatesCard: some View {
        DeltiqSection(String(localized: "calc.oneRm.section.estimate", bundle: .module).uppercased()) {
            if let weight,
               let epley   = ExerciseCalculations.estimate1RM(weightKg: weight, reps: reps),
               let brzycki = ExerciseCalculations.estimate1RMBrzycki(weightKg: weight, reps: reps),
               let average = ExerciseCalculations.estimate1RMAverage(weightKg: weight, reps: reps)
            {
                VStack(spacing: 4) {
                    Text(String(localized: "calc.oneRm.row.average", bundle: .module).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.deltiqOrange)
                    Text("\(average.truncated(to: 2).formattedTwoDecimals) \(unit)")
                        .font(.system(size: 26, weight: .heavy))
                        .fitnessNumberStyle()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)

                estimateRow("Epley", value: epley, showsDivider: true)
                estimateRow("Brzycki", value: brzycki, showsDivider: false)
            } else {
                Text("calc.oneRm.weightRequired", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
    }

    private var percentageTableCard: some View {
        DeltiqSection(String(localized: "calc.oneRm.section.percentages", bundle: .module).uppercased()) {
            if let weight,
               let avg = ExerciseCalculations.estimate1RMAverage(weightKg: weight, reps: reps)
            {
                ForEach(Array(percentageTable.enumerated()), id: \.offset) { index, entry in
                    percentageRow(entry, average: avg, showsDivider: index < percentageTable.count - 1)
                }
                hintRow(String(localized: "calc.oneRm.percentages.footer", bundle: .module))
            } else {
                Text("calc.oneRm.tableEmpty", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
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

    private func estimateRow(_ label: String, value: Double, showsDivider: Bool) -> some View {
        DeltiqRow(
            label: label,
            value: "\(value.truncated(to: 2).formattedTwoDecimals) \(unit)",
            showsDivider: showsDivider
        )
    }

    private func percentageRow(_ entry: PercentRow, average: Double, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(Int(entry.percent * 100)) %")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)
                Text("\((average * entry.percent).truncated(to: 2).formattedTwoDecimals) \(unit)")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
                    .fitnessNumberStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: String(localized: "calc.oneRm.repsHint", bundle: .module), entry.repsHint))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 40)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
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
