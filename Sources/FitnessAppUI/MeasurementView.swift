#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Entry form for a new (or existing) body measurement.
///
/// **Two modes** (DEL-025):
///   - `init()`  → New-Mode: leere Felder, neuer `BodyMeasurement`-Insert beim
///     Speichern. Historie-Liste am Ende der View.
///   - `init(editing:)`  → Edit-Mode: alle Felder mit den Werten der uebergebenen
///     `BodyMeasurement` vorbefuellt. Speichern ueberschreibt den Datensatz
///     statt neu zu insertieren. Historie wird ausgeblendet (User schaut auf
///     ein einzelnes Record).
///
/// Reads the singleton `UserBodyProfile` from the SwiftData context (height, sex, age),
/// lets the user enter weight + circumferences, and shows ALL derived metrics
/// (BMI, Navy/Deurenberg KFA, FFM, FFMI, BMR, WHR/SWR) live as the user types.
///
/// **Apple Health integration**: when authorized, the view auto-fills the weight from
/// the latest HealthKit body-mass sample on appear (only in New-Mode), and after
/// saving writes weight + body-fat % + lean body mass back to HealthKit.
@available(iOS 17.0, macOS 14.0, *)
public struct MeasurementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]

    /// Wenn nicht-nil, sind wir im Edit-Mode und ueberschreiben diesen
    /// Datensatz beim Speichern. Wird vom Caller (HistoryRow-NavigationLink
    /// oder direkter Settings-Klick) gesetzt.
    private let editingMeasurement: BodyMeasurement?

    @State private var weightKg: Double?
    @State private var neckCm:   Double?
    @State private var waistCm:  Double?
    @State private var hipCm:    Double?

    // DEL-027: Zusatz-Umfaenge als Single-Felder (kein L/R mehr — User-Spec).
    // Schema behaelt die L/R-Felder fuer legacy data; UI nutzt nur die Single-
    // Varianten. Beim Edit eines alten Records mit nur L/R-Daten zeigen wir
    // den Mittelwert vorgefuellt und ueberschreiben beim Save in Single.
    @State private var chestCm:     Double?
    @State private var shoulderCm:  Double?
    @State private var upperArmCm:  Double?
    @State private var thighCm:     Double?
    @State private var calfCm:      Double?

    /// Historie der letzten Messungen — Reverse-chronologisch, oben ist neuestes.
    /// Nur in New-Mode angezeigt; im Edit-Mode wuerde es Verwirrung stiften.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var historicalMeasurements: [BodyMeasurement]

    @State private var lastSavedAt: Date?
    /// Set to true once the auto-fill task ran for THIS view appearance.
    @State private var didAttemptHealthKitAutofill = false
    @State private var weightCameFromHealth = false
    @State private var lastHealthFilledWeight: Double?
    /// Tracking-Flag, ob die Edit-Mode-Pre-Fill schon gelaufen ist.
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
                measurementsSection(forProfile: profile)
                extendedMeasurementsSection
                if !isEditMode {
                    healthKitSection
                }
                derivedSection(forProfile: profile)
                ratiosSection(forProfile: profile)
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
            // Edit-Mode: Felder einmalig vorfuellen.
            if isEditMode, !didPrefillFromExisting, let m = editingMeasurement {
                applyExistingMeasurement(m)
                didPrefillFromExisting = true
            }
            // New-Mode: HealthKit-Auto-Fill versuchen.
            if !isEditMode {
                await healthKit.refreshAuthorizationStatus()
                await tryAutoFillFromHealthKit()
            }
        }
    }

    // MARK: Sections

    private func profileSection(_ profile: UserBodyProfile) -> some View {
        Section("Profil (Single Source of Truth)") {
            LabeledContent("Größe",
                value: profile.heightCm.formattedTwoDecimals + " cm")
            LabeledContent("Alter",
                value: "\(ageYears(for: profile)) Jahre")
            LabeledContent("Sex",
                value: profile.profile == .male ? "Männlich" : "Weiblich")
            if let goal = profile.goalWeightKg {
                LabeledContent("Zielgewicht",
                    value: goal.formattedTwoDecimals + " kg")
            }
        }
    }

    private func measurementsSection(forProfile profile: UserBodyProfile) -> some View {
        Section("Messwerte") {
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
            decimalField("Hals (cm)",    value: $neckCm)
            decimalField("Taille (cm)",  value: $waistCm)
            decimalField("Hüfte (cm)" + (profile.profile == .female ? " *" : ""),
                         value: $hipCm)
            if profile.profile == .female {
                Text("* Hüfte ist Pflicht für Navy KFA bei weiblichem Profil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// DEL-027: Zusatz-Umfaenge als Single-Felder. Optional, nur fuer User-
    /// Progress-Tracking — keine Formel-Inputs (KFA/Navy/Deurenberg nutzen
    /// nur Hals/Taille/Huefte). Schulterumfang ist zusaetzlich Input fuer
    /// SWR (Schulter-zu-Taillen-Verhaeltnis) bei Maennern (DEL-026).
    @ViewBuilder
    private var extendedMeasurementsSection: some View {
        Section {
            decimalField("Brust (cm)",        value: $chestCm)
            decimalField("Schulter (cm)",     value: $shoulderCm)
            decimalField("Bizeps (cm)",       value: $upperArmCm)
            decimalField("Oberschenkel (cm)", value: $thighCm)
            decimalField("Wade (cm)",         value: $calfCm)
        } header: {
            Text("Zusätzliche Umfänge")
        } footer: {
            Text("Diese Werte fließen NICHT in die KFA/Navy-Berechnung — sie dienen deinem persönlichen Progress-Tracking. Schulter zusätzlich für das Schulter-zu-Taille-Verhältnis bei Männern.")
                .font(.footnote)
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
                // DEL-025: jede Zeile als NavigationLink in Edit-Mode.
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

    /// DEL-026: Geschlechtsspezifische Koerper-Proportions-Tiles.
    ///   - Frauen: WHR (Waist-to-Hip-Ratio = Taille / Huefte)
    ///   - Maenner: SWR (Shoulder-to-Waist-Ratio = Schulter / Taille)
    @ViewBuilder
    private func ratiosSection(forProfile profile: UserBodyProfile) -> some View {
        switch profile.profile {
        case .female:
            if let waist = waistCm, let hip = hipCm, waist > 0, hip > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.dress.line.vertical.figure")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.purple.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WHR — Taille/Hüfte")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text((waist / hip).truncated(to: 2).formattedTwoDecimals)
                                .font(.title3.weight(.semibold).monospacedDigit())
                        }
                        Spacer()
                        Text(whrLabel(waist / hip))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    HStack(spacing: 12) {
                        Image(systemName: "figure.arms.open")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SWR — Schulter/Taille")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text((shoulder / waist).truncated(to: 2).formattedTwoDecimals)
                                .font(.title3.weight(.semibold).monospacedDigit())
                        }
                        Spacer()
                        Text(swrLabel(shoulder / waist))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Körper-Proportion")
                } footer: {
                    Text("Goldener V-Schnitt ~ 1,618 (Schulter ≈ 1,6× Taille). SWR < 1,3 = wenig V-Form, > 1,5 = ausgeprägt.")
                        .font(.footnote)
                }
            }
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

    private func actionsSection(forProfile profile: UserBodyProfile) -> some View {
        Section {
            Button {
                save(profile: profile)
            } label: {
                Label(isEditMode ? "Änderungen speichern" : "Messung speichern",
                      systemImage: "tray.and.arrow.down")
            }
            .disabled(!canSave)

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
        }
    }

    // MARK: Row helpers

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

    // MARK: Edit-Mode pre-fill

    /// Schreibt die Werte einer bestehenden Messung in die @State-Variablen.
    /// Wird einmalig pro View-Erscheinung in `.task` gerufen, wenn
    /// `editingMeasurement != nil`.
    private func applyExistingMeasurement(_ m: BodyMeasurement) {
        weightKg   = m.weightKg
        neckCm     = m.neckCm
        waistCm    = m.waistCm
        hipCm      = m.hipCm
        shoulderCm = m.shoulderCm
        chestCm    = m.chestCm
        calfCm     = m.calfCm
        // Single-Feld-Fallback fuer legacy L/R-Daten: nimm Mittelwert wenn
        // L+R gesetzt aber kein Single-Wert.
        upperArmCm = m.upperArmCm ?? averageOrNil(m.upperArmLeftCm, m.upperArmRightCm)
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

    // MARK: Domain glue

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

    private var canSave: Bool {
        guard let weightKg, weightKg > 0 else { return false }
        return profiles.first != nil
    }

    private func save(profile: UserBodyProfile) {
        guard let weightKg else { return }

        if let existing = editingMeasurement {
            // Edit-Mode: ueberschreibe das existing Record, behalte die date.
            // Derived-Felder neu berechnen via makeDerived-Helper.
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
                upperArmCm: upperArmCm,
                thighCm: thighCm,
                calfCm: calfCm
            )
            // Werte 1-zu-1 ins existing record schreiben — Identitaet bleibt erhalten,
            // alle Foreign-References (z.B. Reset-Audit-Trails spaeter) intakt.
            existing.weightKg = recomputed.weightKg
            existing.neckCm = recomputed.neckCm
            existing.waistCm = recomputed.waistCm
            existing.hipCm = recomputed.hipCm
            existing.shoulderCm = recomputed.shoulderCm
            existing.chestCm = recomputed.chestCm
            existing.upperArmCm = recomputed.upperArmCm
            existing.thighCm = recomputed.thighCm
            existing.calfCm = recomputed.calfCm
            // Legacy L/R-Felder auf nil setzen — neue Welt nutzt nur Single.
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
            // Edit-Mode: dismiss zurueck zur History-Liste statt zu reseten.
            dismiss()
        } else {
            // New-Mode: insert neuen Datensatz.
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
                upperArmCm: upperArmCm,
                thighCm: thighCm,
                calfCm: calfCm
            )
            modelContext.insert(measurement)
            lastSavedAt = measurement.date

            // Apple-Health-Sync nur in New-Mode (Edit ueberschreibt lokal,
            // HK kennt die historische Messung schon).
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

            // Reset Eingabefelder.
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
        chestCm = nil
        shoulderCm = nil
        upperArmCm = nil
        thighCm = nil
        calfCm = nil
    }

    // MARK: HealthKit auto-fill (only in New-Mode)

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

// MARK: - History Row (DEL-016 + DEL-025)

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

    /// Display-Wert fuer Bizeps: Single-Feld bevorzugt, sonst L/R-Mittel
    /// (Legacy-Daten von vor DEL-027).
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
