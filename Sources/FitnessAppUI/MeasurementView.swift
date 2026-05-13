#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Entry form for a new (or existing) body measurement.
///
/// **Sektion-Struktur (DEL-029)** — geschlechtsabhaengig:
///
///   1. **Pflichtwerte**: Gewicht + die zwingenden Umfaenge fuer die Navy-KFA-
///      Formel.
///        - Mann: Gewicht, Hals, Taille (Schulter direkt darunter als
///          optionales Ratio-Feld).
///        - Frau: Gewicht, Hals, Taille, Hüfte.
///   2. **Auswertung**: Live-Vorschau aller Derived-Metrics + geschlechts-
///      spezifische Ratio-Kachel (SWR fuer Maenner, WHR fuer Frauen).
///   3. **Weitere Umfaenge**: Optionale Felder, die NICHT in die Formeln
///      fliessen — fuer Progress-Tracking. Geschlechtsspezifische Reihen-
///      folge.
///
/// **Two modes** (DEL-025):
///   - `init()`            → New-Mode (Insert)
///   - `init(editing:)`    → Edit-Mode (Update existing record)
///
/// **Apple Health integration**: in New-Mode auto-fill Gewicht aus dem
/// neuesten HK-Sample. Beim Speichern werden Gewicht + KFA + FFM zurueck
/// nach Apple Health geschrieben.
@available(iOS 17.0, macOS 14.0, *)
public struct MeasurementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]

    private let editingMeasurement: BodyMeasurement?

    @State private var weightKg: Double?
    @State private var neckCm:   Double?
    @State private var waistCm:  Double?
    @State private var hipCm:    Double?
    @State private var shoulderCm: Double?

    @State private var chestCm:     Double?
    @State private var bicepsCm:    Double?  // = upperArmCm im Model
    @State private var thighCm:     Double?
    @State private var calfCm:      Double?

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var historicalMeasurements: [BodyMeasurement]

    @State private var lastSavedAt: Date?
    @State private var didAttemptHealthKitAutofill = false
    @State private var weightCameFromHealth = false
    @State private var lastHealthFilledWeight: Double?
    @State private var didPrefillFromExisting = false

    public init() {
        self.editingMeasurement = nil
    }

    public init(editing measurement: BodyMeasurement) {
        self.editingMeasurement = measurement
    }

    private var isEditMode: Bool { editingMeasurement != nil }

    public var body: some View {
        Form {
            if let profile = profiles.first {
                profileSection(profile)
                // ── Sektion 1: Pflichtwerte (geschlechtsspezifisch)
                requiredFieldsSection(forProfile: profile)
                // ── Sektion 2: Auswertung (KFA/BMI/FFMI/Ratios)
                derivedSection(forProfile: profile)
                ratiosSection(forProfile: profile)
                // ── Sektion 3: Weitere Umfaenge (optional, geschlechtsspez.)
                additionalMeasurementsSection(forProfile: profile)
                // HealthKit + Actions + History
                if !isEditMode {
                    healthKitSection
                }
                actionsSection(forProfile: profile)
                if !isEditMode {
                    historySection
                }
            } else {
                ContentUnavailableView(
                    "Kein Profil",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Lege erst dein Profil im Onboarding an, danach können wir Messwerte berechnen.")
                )
            }
        }
        .navigationTitle(isEditMode ? "Messung bearbeiten" : "Neue Messung")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
        .task {
            if isEditMode, !didPrefillFromExisting, let m = editingMeasurement {
                applyExistingMeasurement(m)
                didPrefillFromExisting = true
            }
            if !isEditMode {
                await healthKit.refreshAuthorizationStatus()
                await tryAutoFillFromHealthKit()
            }
        }
    }

    // MARK: - Profile-Section (Single-Source-of-Truth)

    private func profileSection(_ profile: UserBodyProfile) -> some View {
        Section("Profil") {
            LabeledContent("Größe",
                value: profile.heightCm.formattedTwoDecimals + " cm")
            LabeledContent("Alter",
                value: "\(ageYears(for: profile)) Jahre")
            LabeledContent("Geschlecht",
                value: profile.profile == .male ? "Männlich" : "Weiblich")
            if let goal = profile.goalWeightKg {
                LabeledContent("Zielgewicht",
                    value: goal.formattedTwoDecimals + " kg")
            }
        }
    }

    // MARK: - Sektion 1: Pflichtwerte (geschlechtsspezifisch)

    /// **Pflichtfelder fuer KFA-Berechnung**:
    ///   - Mann: Gewicht, Hals, Taille. Schulter darunter als optional fuer
    ///     SWR-Ratio.
    ///   - Frau: Gewicht, Hals, Taille, Hüfte.
    ///
    /// Apple-Health-Badge wird unter dem Gewichtsfeld eingeblendet, wenn der
    /// Wert per Auto-Fill aus dem HK-Profil kam.
    @ViewBuilder
    private func requiredFieldsSection(forProfile profile: UserBodyProfile) -> some View {
        Section {
            // Gewicht (immer Pflicht)
            decimalField("Gewicht (kg)", value: $weightKg)
                .onChange(of: weightKg) { _, newValue in
                    if weightCameFromHealth, newValue != lastHealthFilledWeight {
                        weightCameFromHealth = false
                        lastHealthFilledWeight = nil
                    }
                }
            if weightCameFromHealth, weightKg != nil {
                Label("Aus Apple Health übernommen", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .listRowSeparator(.hidden)
            }

            // Hals (immer Pflicht)
            decimalField("Halsumfang (cm)", value: $neckCm)
            Text("Messen Sie knapp unterhalb des Kehlkopfs, Band waagrecht und leicht anliegend.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)

            // Taille (immer Pflicht, sex-spezifischer Hint)
            decimalField("Taille (cm)", value: $waistCm)
            Text(profile.profile == .male
                 ? "Im Bereich des Bauchnabels."
                 : "Es sollte an der schmalsten Stelle entnommen werden.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)

            // Hüfte: Pflicht bei Frauen, optional/anders gruppiert bei Maennern
            if profile.profile == .female {
                decimalField("Hüfte (cm)", value: $hipCm)
                Text("Es sollte an der breitesten Stelle abgenommen werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            } else {
                // Männer: Schulter direkt in Pflicht-Section (optional fuer SWR-Ratio).
                decimalField("Schulterumfang (cm)", value: $shoulderCm)
                Text("Es sollte an der breitesten Stelle abgenommen werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
        } header: {
            Text("Pflichtwerte")
        } footer: {
            Text(profile.profile == .female
                 ? "Gewicht, Hals, Taille und Hüfte werden für die Navy-KFA-Berechnung benötigt."
                 : "Gewicht, Hals und Taille werden für die Navy-KFA-Berechnung benötigt. Schulter optional für das Schulter-zu-Taillen-Verhältnis.")
                .font(.footnote)
        }
    }

    // MARK: - Sektion 3: Weitere Umfaenge (geschlechtsspezifische Reihenfolge)

    @ViewBuilder
    private func additionalMeasurementsSection(forProfile profile: UserBodyProfile) -> some View {
        Section {
            if profile.profile == .male {
                // Maenner: Brust, Bizeps, Hüfte, Oberschenkel, Wade
                // (Schulter ist schon oben als Pflicht-optional)
                decimalField("Brust (cm)",        value: $chestCm)
                decimalField("Bizeps (cm)",       value: $bicepsCm)
                decimalField("Hüfte (cm)",        value: $hipCm)
                decimalField("Oberschenkel (cm)", value: $thighCm)
                decimalField("Wade (cm)",         value: $calfCm)
            } else {
                // Frauen: Schulter, Brust, Bizeps, Oberschenkel, Wade
                // (Hüfte ist schon oben als Pflicht)
                decimalField("Schulter (cm)",     value: $shoulderCm)
                if shoulderCm != nil {
                    Text("Es sollte an der breitesten Stelle abgenommen werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
                decimalField("Brust (cm)",        value: $chestCm)
                decimalField("Bizeps (cm)",       value: $bicepsCm)
                decimalField("Oberschenkel (cm)", value: $thighCm)
                decimalField("Wade (cm)",         value: $calfCm)
            }
        } header: {
            Text("Weitere Umfänge")
        } footer: {
            Text("Diese Werte fließen NICHT in die KFA/Navy-Berechnung — sie dienen deinem persönlichen Progress-Tracking.")
                .font(.footnote)
        }
    }

    // MARK: - Sektion 2: Auswertung

    private func derivedSection(forProfile profile: UserBodyProfile) -> some View {
        Section("Live-Auswertung") {
            if let derived = derivedMetrics(for: profile) {
                metricRow("BMI", value: derived.bmi)
                navyRow(derived.navyBodyFatPct, profileSex: profile.profile)
                metricRow("KFA Deurenberg", value: derived.deurenbergBodyFatPct, suffix: " %")
                metricRow("Fettfreie Masse", value: derived.fatFreeMassKg, suffix: " kg")
                metricRow("FFMI", value: derived.ffmi)
                metricRow("Norm. FFMI", value: derived.normalizedFfmi)
                metricRow("BMR", value: derived.bmr, suffix: " kcal")
            } else {
                Text("Trage Gewicht ein, um die Auswertung zu sehen.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// DEL-026: Geschlechtsspezifische Body-Ratio-Tile. Nur sichtbar wenn die
    /// noetigen Werte ausgefuellt sind.
    @ViewBuilder
    private func ratiosSection(forProfile profile: UserBodyProfile) -> some View {
        switch profile.profile {
        case .female:
            if let waist = waistCm, let hip = hipCm, waist > 0, hip > 0 {
                Section {
                    ratioTile(
                        title: "WHR — Taille/Hüfte",
                        value: waist / hip,
                        label: whrLabel(waist / hip),
                        icon: "figure.dress.line.vertical.figure",
                        tint: .purple
                    )
                } header: {
                    Text("Körper-Proportion")
                } footer: {
                    Text("WHR < 0,80 = gesundes Risikoprofil bei Frauen. > 0,85 = erhöhtes Risiko.")
                        .font(.footnote)
                }
            }
        case .male:
            if let shoulder = shoulderCm, let waist = waistCm, shoulder > 0, waist > 0 {
                Section {
                    ratioTile(
                        title: "SWR — Schulter/Taille",
                        value: shoulder / waist,
                        label: swrLabel(shoulder / waist),
                        icon: "figure.arms.open",
                        tint: .blue
                    )
                } header: {
                    Text("Körper-Proportion")
                } footer: {
                    Text("Goldener V-Schnitt ~ 1,618 (Schulter ≈ 1,6× Taille). SWR < 1,3 = wenig V-Form, > 1,5 = ausgeprägt.")
                        .font(.footnote)
                }
            }
        }
    }

    private func ratioTile(title: String, value: Double, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.truncated(to: 2).formattedTwoDecimals)
                    .font(.title3.weight(.semibold).monospacedDigit())
            }
            Spacer()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func whrLabel(_ ratio: Double) -> String {
        switch ratio {
        case ..<0.80: return "Gesund"
        case ..<0.85: return "Grenzwert"
        default:      return "Erhöht"
        }
    }

    private func swrLabel(_ ratio: Double) -> String {
        switch ratio {
        case ..<1.30: return "Schmal"
        case ..<1.50: return "Mittel"
        case ..<1.62: return "Ausgeprägt"
        default:      return "V-Shape"
        }
    }

    // MARK: - HealthKit + Actions + History sections (unveraendert vs. DEL-025)

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            if !healthKit.isAvailable {
                Label("Apple Health auf diesem Gerät nicht verfügbar.",
                      systemImage: "heart.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                switch healthKit.authorizationStatus {
                case .notDetermined:
                    Button {
                        Task { await healthKit.requestAuthorization() }
                    } label: {
                        Label("Apple Health verbinden", systemImage: "heart.fill")
                    }
                case .sharingAuthorized:
                    HStack {
                        Label("Verbunden", systemImage: "heart.fill")
                            .foregroundStyle(.pink)
                        Spacer()
                        if let lastSync = healthKit.lastSyncDate {
                            Text("Sync \(lastSync.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Button {
                        Task { await pullLatestWeightFromHealth() }
                    } label: {
                        Label("Aktuelles Gewicht aus Apple Health", systemImage: "arrow.down.circle")
                    }
                case .sharingDenied:
                    Label("Apple Health blockiert. Ändere die Berechtigung in den iOS-Einstellungen.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .unavailable:
                    Label("Apple Health nicht verfügbar.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            if healthKit.authorizationStatus == .sharingAuthorized {
                Text("Bei Verbindung wird das aktuellste Waagen-Gewicht beim Öffnen vorausgefüllt. Beim Speichern werden Gewicht, KFA und FFM zurück nach Apple Health geschrieben.")
                    .font(.footnote)
            }
        }
    }

    private func actionsSection(forProfile profile: UserBodyProfile) -> some View {
        Section {
            Button {
                save(profile: profile)
            } label: {
                Label(isEditMode ? "Änderungen speichern" : "Messung speichern",
                      systemImage: "tray.and.arrow.down")
            }
            .disabled(!canSave(profile: profile))

            if isEditMode {
                Button(role: .destructive) {
                    deleteCurrentMeasurement()
                } label: {
                    Label("Messung löschen", systemImage: "trash")
                }
            }

            if let lastSavedAt {
                Text(isEditMode
                     ? "Zuletzt geändert: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))"
                     : "Zuletzt gespeichert: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if !canSave(profile: profile) {
                Text(missingFieldsHint(profile: profile))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section {
            if historicalMeasurements.isEmpty {
                Text("Noch keine Messungen — speichere oben deinen ersten Wert.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(historicalMeasurements.prefix(12))) { m in
                    NavigationLink {
                        MeasurementView(editing: m)
                    } label: {
                        HistoryRow(measurement: m)
                    }
                }
            }
        } header: {
            Text("Verlauf")
        } footer: {
            if historicalMeasurements.count > 12 {
                Text("Älteste \(historicalMeasurements.count - 12) Messungen ausgeblendet.")
                    .font(.footnote)
            } else if !historicalMeasurements.isEmpty {
                Text("Tippe einen Eintrag an, um die Werte zu bearbeiten.")
                    .font(.footnote)
            }
        }
    }

    // MARK: - Row helpers

    private func metricRow(_ label: String, value: Double, suffix: String = "") -> some View {
        LabeledContent(label, value: value.truncated(to: 2).formattedTwoDecimals + suffix)
    }

    private func navyRow(_ navy: Double?, profileSex: BodyFormulaProfile) -> some View {
        HStack {
            Text("KFA Navy")
            Spacer()
            if let navy {
                Text(navy.truncated(to: 2).formattedTwoDecimals + " %")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            } else {
                Text(profileSex == .female
                     ? "Hals/Taille/Hüfte erforderlich"
                     : "Hals/Taille erforderlich")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(label))
            .decimalKeyboard()
    }

    // MARK: - Edit-Mode pre-fill

    private func applyExistingMeasurement(_ m: BodyMeasurement) {
        weightKg   = m.weightKg
        neckCm     = m.neckCm
        waistCm    = m.waistCm
        hipCm      = m.hipCm
        shoulderCm = m.shoulderCm
        chestCm    = m.chestCm
        calfCm     = m.calfCm
        bicepsCm   = m.upperArmCm ?? averageOrNil(m.upperArmLeftCm, m.upperArmRightCm)
        thighCm    = m.thighCm    ?? averageOrNil(m.thighLeftCm, m.thighRightCm)
    }

    private func averageOrNil(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (.some(x), .some(y)): return (x + y) / 2
        case let (.some(x), nil):       return x
        case let (nil, .some(y)):       return y
        default:                        return nil
        }
    }

    // MARK: - Domain glue + validation

    private func ageYears(for profile: UserBodyProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
    }

    private func derivedMetrics(for profile: UserBodyProfile) -> DerivedBodyMetrics? {
        guard let weightKg, weightKg > 0, profile.heightCm > 0 else { return nil }
        return BodyCalculations.computeDerivedFields(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: ageYears(for: profile),
            profile: profile.profile,
            neckCm: neckCm,
            waistCm: waistCm,
            hipCm: hipCm
        )
    }

    /// DEL-029: Pflicht-Validation. Save-Button bleibt disabled bis alle
    /// geschlechtsspezifischen Pflichtfelder gefuellt UND > 0 sind.
    ///   Maenner: Gewicht, Hals, Taille
    ///   Frauen:  Gewicht, Hals, Taille, Hüfte
    private func canSave(profile: UserBodyProfile) -> Bool {
        guard let w = weightKg, w > 0,
              let n = neckCm, n > 0,
              let waist = waistCm, waist > 0
        else { return false }
        if profile.profile == .female {
            guard let h = hipCm, h > 0 else { return false }
        }
        return true
    }

    /// Erklaerung welche Pflichtfelder noch fehlen — zeigt's im
    /// Actions-Footer wenn `canSave` false ist.
    private func missingFieldsHint(profile: UserBodyProfile) -> String {
        var missing: [String] = []
        if (weightKg ?? 0) <= 0 { missing.append("Gewicht") }
        if (neckCm ?? 0)   <= 0 { missing.append("Hals") }
        if (waistCm ?? 0)  <= 0 { missing.append("Taille") }
        if profile.profile == .female, (hipCm ?? 0) <= 0 {
            missing.append("Hüfte")
        }
        return "Pflichtfeld\(missing.count == 1 ? "" : "er") noch leer: \(missing.joined(separator: ", "))."
    }

    // MARK: - Save / Delete

    private func save(profile: UserBodyProfile) {
        guard let weightKg, canSave(profile: profile) else { return }

        if let existing = editingMeasurement {
            // Edit-Mode: ueberschreibe existing Record.
            let recomputed = BodyMeasurement.makeDerived(
                date: existing.date,
                ageYears: existing.ageYearsAtMeasurement,
                weightKg: weightKg,
                heightCm: profile.heightCm,
                profile: profile.profile,
                neckCm: neckCm,
                waistCm: waistCm,
                hipCm: hipCm,
                shoulderCm: shoulderCm,
                chestCm: chestCm,
                upperArmCm: bicepsCm,
                thighCm: thighCm,
                calfCm: calfCm
            )
            existing.weightKg = recomputed.weightKg
            existing.neckCm = recomputed.neckCm
            existing.waistCm = recomputed.waistCm
            existing.hipCm = recomputed.hipCm
            existing.shoulderCm = recomputed.shoulderCm
            existing.chestCm = recomputed.chestCm
            existing.upperArmCm = recomputed.upperArmCm
            existing.thighCm = recomputed.thighCm
            existing.calfCm = recomputed.calfCm
            existing.upperArmLeftCm = nil
            existing.upperArmRightCm = nil
            existing.thighLeftCm = nil
            existing.thighRightCm = nil
            existing.bmi = recomputed.bmi
            existing.navyBodyFatPct = recomputed.navyBodyFatPct
            existing.deurenbergBodyFatPct = recomputed.deurenbergBodyFatPct
            existing.selectedBodyFatPct = recomputed.selectedBodyFatPct
            existing.fatFreeMassKg = recomputed.fatFreeMassKg
            existing.ffmi = recomputed.ffmi
            existing.normalizedFfmi = recomputed.normalizedFfmi
            existing.bmr = recomputed.bmr

            lastSavedAt = Date()
            dismiss()
        } else {
            let measurement = BodyMeasurement.makeDerived(
                ageYears: ageYears(for: profile),
                weightKg: weightKg,
                heightCm: profile.heightCm,
                profile: profile.profile,
                neckCm: neckCm,
                waistCm: waistCm,
                hipCm: hipCm,
                shoulderCm: shoulderCm,
                chestCm: chestCm,
                upperArmCm: bicepsCm,
                thighCm: thighCm,
                calfCm: calfCm
            )
            modelContext.insert(measurement)
            lastSavedAt = measurement.date

            let bodyFatPct = measurement.selectedBodyFatPct
                ?? measurement.navyBodyFatPct
                ?? measurement.deurenbergBodyFatPct
            Task { @MainActor in
                await healthKit.saveMeasurement(
                    weightKg: measurement.weightKg,
                    bodyFatPct: bodyFatPct,
                    fatFreeMassKg: measurement.fatFreeMassKg,
                    date: measurement.date
                )
            }

            resetFields()
        }
    }

    private func deleteCurrentMeasurement() {
        guard let existing = editingMeasurement else { return }
        modelContext.delete(existing)
        dismiss()
    }

    private func resetFields() {
        weightKg = nil
        neckCm   = nil
        waistCm  = nil
        hipCm    = nil
        shoulderCm = nil
        chestCm = nil
        bicepsCm = nil
        thighCm = nil
        calfCm = nil
    }

    // MARK: - HealthKit auto-fill (only in New-Mode)

    private func tryAutoFillFromHealthKit() async {
        guard !didAttemptHealthKitAutofill else { return }
        didAttemptHealthKitAutofill = true

        guard healthKit.authorizationStatus == .sharingAuthorized,
              weightKg == nil,
              let kg = await healthKit.latestWeightKg()
        else { return }

        if weightKg == nil {
            lastHealthFilledWeight = kg
            weightCameFromHealth = true
            weightKg = kg
        }
    }

    private func pullLatestWeightFromHealth() async {
        guard let kg = await healthKit.latestWeightKg() else { return }
        lastHealthFilledWeight = kg
        weightCameFromHealth = true
        weightKg = kg
    }
}

// MARK: - History Row

@available(iOS 17.0, macOS 14.0, *)
private struct HistoryRow: View {
    let measurement: BodyMeasurement

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(measurement.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.body.weight(.semibold))
                if let kfa = bestBodyFatPct {
                    Text("KFA \(kfa.truncated(to: 1).formattedTwoDecimals) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(measurement.weightKg.truncated(to: 2).formattedTwoDecimals) kg")
                    .font(.body.monospacedDigit())
                if let bicepsAvg = bicepsDisplay {
                    Text("Bizeps \(bicepsAvg.truncated(to: 1).formattedTwoDecimals) cm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var bestBodyFatPct: Double? {
        measurement.selectedBodyFatPct
            ?? measurement.navyBodyFatPct
            ?? measurement.deurenbergBodyFatPct
    }

    private var bicepsDisplay: Double? {
        if let single = measurement.upperArmCm { return single }
        switch (measurement.upperArmLeftCm, measurement.upperArmRightCm) {
        case let (.some(l), .some(r)): return (l + r) / 2
        case let (.some(l), nil):       return l
        case let (nil, .some(r)):       return r
        default:                        return nil
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Männliches Profil") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Weibliches Profil") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.femaleProfileContainer)
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Kein Profil (Empty State)") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
    .environment(HealthKitController())
}
#endif
#endif
