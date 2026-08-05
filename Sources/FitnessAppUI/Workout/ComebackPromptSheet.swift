// DEL-239: Rueckfrage beim Trainingsstart nach einer langen Pause.
//
// Wird VOR dem Anlegen der Session gezeigt. Das ist keine Kosmetik: sobald die
// ActiveWorkoutView ihre Saetze gerendert hat, sperrt sich `SetRow` per
// `didInit` gegen ein zweites Befuellen — eine danach geschriebene
// Gewichtsaenderung erreicht die sichtbaren Felder nicht mehr.
//
// Der Nutzer entscheidet, nicht die App: entweder die Empfehlung, ein eigener
// Prozentsatz, oder volle Last. Die Vorschau zeigt echte Kilogramm statt einer
// Prozentangabe — sie ist gleichzeitig der Ersatz fuer den fehlenden
// "laeuft"-Zustand, weil der Nutzer daran erkennt, ob die Reduktion greift.

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

@available(iOS 17.0, macOS 14.0, *)
struct ComebackPromptSheet: View {

    let assessment: AbsenceDeload.Assessment
    /// Wird mit dem gewaehlten Faktor gerufen, oder mit nil bei Ablehnung.
    let onDecision: (Double?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReduction: Double = 0.1
    @State private var didInitSelection = false

    private var factor: Double { 1.0 - selectedReduction }
    private var changes: [AbsenceDeload.Change] {
        AbsenceDeload.preview(in: modelContext, factor: factor)
    }

    var body: some View {
        NavigationStack {
            List {
                introSection
                if assessment.needsRetest {
                    retestSection
                } else {
                    pickerSection
                    previewSection
                }
                actionSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("comeback.prompt.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onAppear {
            guard !didInitSelection else { return }
            didInitSelection = true
            // Auf der Empfehlung vorbelegen. Ein Test sichert ab, dass jede
            // Empfehlung eine waehlbare Stufe ist.
            let recommended = 1.0 - assessment.recommendedFactor
            selectedReduction = ComebackAdvisor.selectableReductions
                .min { abs($0 - recommended) < abs($1 - recommended) } ?? 0.1
        }
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(
                    format: String(localized: "comeback.prompt.subtitle", bundle: .module),
                    assessment.gapDays
                ))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                Text("comeback.prompt.rationale", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// Ab einem halben Jahr Pause verordnet der Advisor keinen Faktor mehr —
    /// die alte Last ist keine belastbare Referenz.
    private var retestSection: some View {
        Section {
            Text("comeback.prompt.retest", bundle: .module)
                .font(.footnote)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private var pickerSection: some View {
        Section {
            Picker(selection: $selectedReduction) {
                ForEach(ComebackAdvisor.selectableReductions, id: \.self) { value in
                    Text(label(for: value)).tag(value)
                }
            } label: {
                Text("comeback.prompt.amount", bundle: .module)
            }
            #if os(iOS)
            .pickerStyle(.inline)
            #endif
            .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    @ViewBuilder
    private var previewSection: some View {
        let list = changes
        Section {
            if list.isEmpty {
                Text("comeback.prompt.preview.none", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.deltiqOrange)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.Deltiq.surface)
            } else {
                // Nur die ersten fuenf — die Liste soll den Start nicht in eine
                // Tabelle verwandeln.
                ForEach(list.prefix(5), id: \.exerciseName) { change in
                    HStack {
                        Text(change.exerciseName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatted(change.from)) → \(formatted(change.to))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
                .listRowBackground(Color.Deltiq.surface)
                if list.count > 5 {
                    Text(String(
                        format: String(localized: "comeback.prompt.preview.more", bundle: .module),
                        list.count - 5
                    ))
                    .font(.caption2)
                    .foregroundStyle(Color.Deltiq.textTertiary)
                    .listRowBackground(Color.Deltiq.surface)
                }
            }
        } header: {
            Text("comeback.prompt.preview.header", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private var actionSection: some View {
        Section {
            if !assessment.needsRetest {
                Button {
                    onDecision(factor)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("comeback.prompt.apply", bundle: .module)
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .disabled(changes.isEmpty)
                .listRowBackground(Color.Deltiq.surface)
            }
            Button(role: .cancel) {
                onDecision(nil)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("comeback.prompt.decline", bundle: .module)
                    Spacer()
                }
            }
            .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    // MARK: Formatierung

    private func label(for reduction: Double) -> String {
        let percent = Int((reduction * 100).rounded())
        let recommended = 1.0 - assessment.recommendedFactor
        if abs(reduction - recommended) < 0.0001 {
            return String(
                format: String(localized: "comeback.prompt.recommended", bundle: .module),
                percent
            )
        }
        return "\(percent) %"
    }

    private func formatted(_ weight: Double) -> String {
        weight == weight.rounded()
            ? "\(Int(weight))"
            : weight.truncated(to: 2).formattedTwoDecimals
    }
}
#endif
