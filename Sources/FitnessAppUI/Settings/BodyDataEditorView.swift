#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Befunde `PE-B1`/`PE-G1`):
/// kombinierte Körperdaten-Karte — Größe, aktuelles Gewicht (mit Datum) und
/// optionales Zielgewicht an EINEM Ort, statt auf `bodyCard`/`goalCard`
/// verteilt. Lokaler Draft mit explizitem Speichern/Abbrechen (keine
/// Aenderung waehrend des Tippens persistiert) — anders als der Rest von
/// `ProfileEditorView`, der bewusst autosaved: Mehrfeld-Eingaben mit
/// Gewichts-Erfassung brauchen einen atomaren Commit, kein Zwischenstand darf
/// als Messung durchgehen.
///
/// Gewicht ist NICHT vorausgefuellt im Sinne eines bearbeitbaren Altwerts,
/// sondern startet leer mit dem letzten Wert nur als Platzhalter/Kontext —
/// `weightTouched` unterscheidet "nichts eingegeben" (kein neuer Eintrag,
/// auch wenn Groesse/Zielgewicht geaendert wurden) von "bewusst erneut
/// denselben Wert eingetragen" (legt trotzdem eine neue `BodyMeasurement`-
/// Zeile an — Pflicht-Vorgabe: derselbe Wert zu einem spaeteren Zeitpunkt
/// muss erfassbar bleiben).
@available(iOS 17.0, macOS 14.0, *)
struct BodyDataEditorView: View {
    @Bindable var profile: UserBodyProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var draftHeightCm: Double
    @State private var draftGoalWeightKg: Double?
    @State private var draftWeightKg: Double?
    @State private var weightTouched = false

    init(profile: UserBodyProfile) {
        self.profile = profile
        _draftHeightCm = State(initialValue: profile.heightCm)
        _draftGoalWeightKg = State(initialValue: profile.goalWeightKg)
        _draftWeightKg = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heightSection
                    weightSection
                    goalSection
                }
                .padding()
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            .keyboardDismissToolbar()
            .navigationTitle(String(localized: "profile.bodyData.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .module)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", bundle: .module)) {
                        save()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var heightSection: some View {
        DeltiqSection(String(localized: "profile.section.body", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "onboarding.field.heightCm", bundle: .module), showsDivider: false) {
                TextField(
                    String(localized: "onboarding.field.heightCm", bundle: .module),
                    value: $draftHeightCm, format: .number,
                    prompt: Text(String(localized: "profile.body.heightPlaceholder", bundle: .module))
                )
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15))
                .fitnessNumberStyle()
                .frame(maxWidth: 140)
            }
        }
    }

    @ViewBuilder
    private var weightSection: some View {
        DeltiqSection(String(localized: "profile.bodyData.weight.header", bundle: .module).uppercased(), accentEdge: true) {
            DeltiqControlRow(label: String(localized: "profile.bodyData.weight.label", bundle: .module), showsDivider: false) {
                TextField(
                    String(localized: "profile.bodyData.weight.label", bundle: .module),
                    value: weightFieldBinding, format: .number.precision(.fractionLength(0...2)),
                    prompt: Text(weightPlaceholder)
                )
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15))
                .fitnessNumberStyle()
                .frame(maxWidth: 140)
            }
            if let latest = measurements.first {
                hintRow(String(format: String(localized: "profile.bodyData.weight.lastEntry", bundle: .module),
                                latest.date.formatted(date: .abbreviated, time: .omitted)))
            } else {
                hintRow(String(localized: "profile.bodyData.weight.noEntry", bundle: .module))
            }
            NavigationLink {
                MeasurementView()
            } label: {
                DeltiqRow(
                    icon: "ruler",
                    label: String(localized: "profile.bodyData.weight.fullMeasurement", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
            hintRow(String(localized: "profile.bodyData.weight.footer", bundle: .module))
        }
    }

    private var goalSection: some View {
        DeltiqSection(String(localized: "onboarding.section.goals", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "onboarding.field.goalWeightKg", bundle: .module), showsDivider: false) {
                let displayValue = Binding<Double?>(
                    get: { draftGoalWeightKg },
                    set: { draftGoalWeightKg = $0?.rounded(toDecimals: 2) }
                )
                TextField(
                    String(localized: "onboarding.field.goalWeightKg", bundle: .module),
                    value: displayValue, format: .number.precision(.fractionLength(0...2)),
                    prompt: Text(String(localized: "profile.goal.weightPlaceholder", bundle: .module))
                )
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15))
                .fitnessNumberStyle()
                .frame(maxWidth: 140)
            }
            hintRow(String(localized: "profile.goal.footer", bundle: .module))
        }
    }

    /// Setzt `weightTouched` bei jeder tatsaechlichen Eingabe — unabhaengig
    /// davon, ob der neue Wert zufaellig mit dem Platzhalter uebereinstimmt.
    private var weightFieldBinding: Binding<Double?> {
        Binding(
            get: { draftWeightKg },
            set: { newValue in
                draftWeightKg = newValue?.rounded(toDecimals: 2)
                weightTouched = true
            }
        )
    }

    private var weightPlaceholder: String {
        guard let latest = measurements.first else {
            return String(localized: "profile.bodyData.weight.placeholderEmpty", bundle: .module)
        }
        return latest.weightKg.formattedWeightInput()
    }

    private var canSave: Bool {
        guard Self.heightRange.contains(draftHeightCm) else { return false }
        if weightTouched, let w = draftWeightKg { return w > 0 }
        return true
    }

    private static let heightRange: ClosedRange<Double> = 100...250

    private func save() {
        profile.heightCm = draftHeightCm
        profile.goalWeightKg = draftGoalWeightKg
        // Groesse/Zielgewicht allein (oder ein nie angefasstes Gewichtsfeld)
        // legen bewusst KEINEN neuen Gewichtseintrag an — nur eine
        // tatsaechliche Eingabe tut das, auch wenn sie zufaellig dem letzten
        // bekannten Wert entspricht (Pflicht-Vorgabe).
        if weightTouched, let weightKg = draftWeightKg, weightKg > 0 {
            let ageYears = Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
            let measurement = BodyMeasurement.makeWeightOnly(
                ageYears: ageYears,
                weightKg: weightKg,
                heightCm: draftHeightCm,
                profile: profile.profile
            )
            modelContext.insert(measurement)
        }
        dismiss()
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}
#endif
