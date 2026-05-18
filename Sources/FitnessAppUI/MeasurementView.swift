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
/// DEL-106: Felder fuer den `@FocusState` in MeasurementView. Hashable
/// damit `.focused($state, equals: .field)` und `.id(field)` zusammen
/// fuer den ScrollViewReader funktionieren.
@available(iOS 17.0, macOS 14.0, *)
public enum MeasurementField: Hashable {
    case weight, neck, waist, hip, shoulder
    case chest, biceps, thigh, calf
}

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

    /// DEL-106: Zentraler FocusState fuer alle Decimal-Felder. Treibt sowohl
    /// die Keyboard-Toolbar (Previous/Next/Done) als auch das Auto-Scroll
    /// im ScrollViewReader.
    @FocusState private var focusedField: MeasurementField?

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var historicalMeasurements: [BodyMeasurement]

    @State private var lastSavedAt: Date?
    @State private var didAttemptHealthKitAutofill = false
    @State private var weightCameFromHealth = false
    @State private var lastHealthFilledWeight: Double?
    @State private var didPrefillFromExisting = false

    /// DEL-034: Edit-Mode startet als reine Detail-Ansicht. Felder werden erst
    /// editierbar, sobald der User oben rechts "Bearbeiten" tippt. Im New-Mode
    /// (kein editingMeasurement) ist die View IMMER editierbar — User soll
    /// direkt eintragen koennen.
    @State private var isEditingEnabled: Bool = false

    /// Sind die Eingabefelder aktuell editierbar? Im New-Mode immer ja,
    /// im Edit-Mode nur wenn der User "Bearbeiten" getippt hat.
    private var fieldsEnabled: Bool {
        !isEditMode || isEditingEnabled
    }

    public init() {
        self.editingMeasurement = nil
    }

    public init(editing measurement: BodyMeasurement) {
        self.editingMeasurement = measurement
    }

    private var isEditMode: Bool { editingMeasurement != nil }

    public var body: some View {
        // DEL-106: ScrollViewReader hostet die Auto-Scroll-Choreografie,
        // wenn der fokussierte Field-State wechselt. ScrollView ersetzt
        // das Apple-Form — Side-Effect: wir verlieren das auto-Scroll-
        // auf-Tastatur-Behavior, und holen es hier explizit zurueck.
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 18) {
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
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                // DEL-106: Bottom-Padding fuer die Tastatur — verhindert,
                // dass die letzten Felder unter der Tastatur "stecken" bleiben.
                .padding(.bottom, focusedField == nil ? 24 : 80)
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            // DEL-106: Auto-Scroll auf das aktive Feld. .center sorgt fuer
            // sichtbaren Bereich oberhalb der Tastatur.
            .onChange(of: focusedField) { _, newValue in
                guard let field = newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(field, anchor: .center)
                }
            }
        }
        .navigationTitle(navTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // DEL-034: Edit-Mode startet read-only. Toolbar-Button toggled
            // den Edit-State. Im New-Mode unsichtbar (Felder eh editierbar).
            if isEditMode {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditingEnabled ? "Fertig" : "Bearbeiten") {
                        isEditingEnabled.toggle()
                    }
                }
            }
            // DEL-106: Keyboard-Accessory mit Previous/Next/Done. Da der
            // .decimalPad keinen Return-Key hat, brauchen wir das hier
            // zwingend — ohne kann der User die Tastatur nur per Swipe-
            // down zumachen, und das ist auf grossen iPhones umstaendlich.
            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    moveFocus(by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveFocus(by: -1))

                Button {
                    moveFocus(by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveFocus(by: 1))

                Spacer()

                Button("Fertig") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
                .tint(Color.deltiqOrange)
            }
            #endif
        }
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

    /// Titel-Mapping: New-Mode immer "Neue Messung", Edit-Mode wechselt
    /// zwischen "Messung (Detail)" und "Messung bearbeiten" je nach
    /// Editing-Toggle.
    private var navTitle: String {
        if isEditMode {
            return isEditingEnabled ? "Messung bearbeiten" : "Messung"
        }
        return "Neue Messung"
    }

    // MARK: - Profile-Section (Single-Source-of-Truth)

    @ViewBuilder
    private func profileSection(_ profile: UserBodyProfile) -> some View {
        DeltiqFormSection(header: "Profil") {
            DeltiqFormRow(label: "Größe") {
                Text(profile.heightCm.formattedTwoDecimals + " cm")
                    .foregroundStyle(.secondary)
                    .fitnessNumberStyle()
            }
            DeltiqFormRow(label: "Alter") {
                Text("\(ageYears(for: profile)) Jahre")
                    .foregroundStyle(.secondary)
                    .fitnessNumberStyle()
            }
            DeltiqFormRow(label: "Geschlecht") {
                Text(profile.profile == .male ? "Männlich" : "Weiblich")
                    .foregroundStyle(.secondary)
            }
            if let goal = profile.goalWeightKg {
                DeltiqFormRow(label: "Zielgewicht") {
                    Text(goal.formattedTwoDecimals + " kg")
                        .foregroundStyle(.secondary)
                        .fitnessNumberStyle()
                }
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
        DeltiqFormSection(header: "Pflichtwerte") {
            // Gewicht (immer Pflicht)
            measurementRow(label: "Gewicht (kg)", value: $weightKg, field: .weight)
                .onChange(of: weightKg) { _, newValue in
                    if weightCameFromHealth, newValue != lastHealthFilledWeight {
                        weightCameFromHealth = false
                        lastHealthFilledWeight = nil
                    }
                }
            if weightCameFromHealth, weightKg != nil {
                HStack {
                    Label("Aus Apple Health übernommen", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            // Hals (immer Pflicht)
            measurementRow(label: "Halsumfang (cm)", value: $neckCm, field: .neck)
            fieldHint("Messen Sie knapp unterhalb des Kehlkopfs, Band waagrecht und leicht anliegend.")

            // Taille (immer Pflicht, sex-spezifischer Hint)
            measurementRow(label: "Taille (cm)", value: $waistCm, field: .waist)
            fieldHint(profile.profile == .male
                      ? "Im Bereich des Bauchnabels."
                      : "Es sollte an der schmalsten Stelle entnommen werden.")

            // Hüfte: Pflicht bei Frauen, optional/anders gruppiert bei Maennern
            if profile.profile == .female {
                measurementRow(label: "Hüfte (cm)", value: $hipCm, field: .hip)
                fieldHint("Es sollte an der breitesten Stelle abgenommen werden.")
            } else {
                // Männer: Schulter direkt in Pflicht-Section (optional fuer SWR-Ratio).
                measurementRow(label: "Schulterumfang (cm)", value: $shoulderCm, field: .shoulder)
                fieldHint("Es sollte an der breitesten Stelle abgenommen werden.")
            }
        } footer: {
            Text(profile.profile == .female
                 ? "Gewicht, Hals, Taille und Hüfte werden für die Navy-KFA-Berechnung benötigt."
                 : "Gewicht, Hals und Taille werden für die Navy-KFA-Berechnung benötigt. Schulter optional für das Schulter-zu-Taillen-Verhältnis.")
        }
    }

    // MARK: - Sektion 3: Weitere Umfaenge (geschlechtsspezifische Reihenfolge)

    @ViewBuilder
    private func additionalMeasurementsSection(forProfile profile: UserBodyProfile) -> some View {
        DeltiqFormSection(header: "Weitere Umfänge") {
            if profile.profile == .male {
                // Maenner: Brust, Bizeps, Hüfte, Oberschenkel, Wade
                // (Schulter ist schon oben als Pflicht-optional)
                measurementRow(label: "Brust (cm)",        value: $chestCm,  field: .chest)
                measurementRow(label: "Bizeps (cm)",       value: $bicepsCm, field: .biceps)
                measurementRow(label: "Hüfte (cm)",        value: $hipCm,    field: .hip)
                measurementRow(label: "Oberschenkel (cm)", value: $thighCm,  field: .thigh)
                measurementRow(label: "Wade (cm)",         value: $calfCm,   field: .calf)
            } else {
                // Frauen: Schulter, Brust, Bizeps, Oberschenkel, Wade
                // (Hüfte ist schon oben als Pflicht)
                measurementRow(label: "Schulter (cm)",     value: $shoulderCm, field: .shoulder)
                if shoulderCm != nil {
                    fieldHint("Es sollte an der breitesten Stelle abgenommen werden.")
                }
                measurementRow(label: "Brust (cm)",        value: $chestCm,  field: .chest)
                measurementRow(label: "Bizeps (cm)",       value: $bicepsCm, field: .biceps)
                measurementRow(label: "Oberschenkel (cm)", value: $thighCm,  field: .thigh)
                measurementRow(label: "Wade (cm)",         value: $calfCm,   field: .calf)
            }
        } footer: {
            Text("Diese Werte fließen NICHT in die KFA/Navy-Berechnung — sie dienen deinem persönlichen Progress-Tracking.")
        }
    }

    // MARK: - Sektion 2: Auswertung

    @ViewBuilder
    private func derivedSection(forProfile profile: UserBodyProfile) -> some View {
        DeltiqFormSection(header: "Live-Auswertung") {
            if let derived = derivedMetrics(for: profile) {
                metricRow("BMI", value: derived.bmi)
                navyRow(derived.navyBodyFatPct, profileSex: profile.profile)
                metricRow("KFA Deurenberg", value: derived.deurenbergBodyFatPct, suffix: " %")
                metricRow("Fettfreie Masse", value: derived.fatFreeMassKg, suffix: " kg")
                metricRow("FFMI", value: derived.ffmi)
                metricRow("Norm. FFMI", value: derived.normalizedFfmi)
                metricRow("BMR", value: derived.bmr, suffix: " kcal")
            } else {
                DeltiqFormFullRow {
                    Text("Trage Gewicht ein, um die Auswertung zu sehen.")
                        .foregroundStyle(.secondary)
                }
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
                DeltiqFormSection(header: "Körper-Proportion") {
                    DeltiqFormFullRow {
                        ratioTile(
                            title: "WHR — Taille/Hüfte",
                            value: waist / hip,
                            label: whrLabel(waist / hip),
                            icon: "figure.dress.line.vertical.figure",
                            tint: .purple
                        )
                    }
                } footer: {
                    Text("WHR < 0,80 = gesundes Risikoprofil bei Frauen. > 0,85 = erhöhtes Risiko.")
                }
            }
        case .male:
            if let shoulder = shoulderCm, let waist = waistCm, shoulder > 0, waist > 0 {
                DeltiqFormSection(header: "Körper-Proportion") {
                    DeltiqFormFullRow {
                        ratioTile(
                            title: "SWR — Schulter/Taille",
                            value: shoulder / waist,
                            label: swrLabel(shoulder / waist),
                            icon: "figure.arms.open",
                            tint: Color.deltiqOrange
                        )
                    }
                } footer: {
                    Text("Goldener V-Schnitt ~ 1,618 (Schulter ≈ 1,6× Taille). SWR < 1,3 = wenig V-Form, > 1,5 = ausgeprägt.")
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
        DeltiqFormSection(header: "Apple Health") {
            if !healthKit.isAvailable {
                DeltiqFormFullRow {
                    Label("Apple Health auf diesem Gerät nicht verfügbar.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                switch healthKit.authorizationStatus {
                case .notDetermined:
                    DeltiqFormFullRow {
                        Button {
                            Task { await healthKit.requestAuthorization() }
                        } label: {
                            Label("Apple Health verbinden", systemImage: "heart.fill")
                        }
                    }
                case .sharingAuthorized:
                    DeltiqFormFullRow {
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
                    }
                    DeltiqFormFullRow {
                        Button {
                            Task { await pullLatestWeightFromHealth() }
                        } label: {
                            Label("Aktuelles Gewicht aus Apple Health", systemImage: "arrow.down.circle")
                        }
                    }
                case .sharingDenied:
                    DeltiqFormFullRow {
                        Label("Apple Health blockiert. Ändere die Berechtigung in den iOS-Einstellungen.",
                              systemImage: "heart.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                case .unavailable:
                    DeltiqFormFullRow {
                        Label("Apple Health nicht verfügbar.",
                              systemImage: "heart.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } footer: {
            if healthKit.authorizationStatus == .sharingAuthorized {
                Text("Bei Verbindung wird das aktuellste Waagen-Gewicht beim Öffnen vorausgefüllt. Beim Speichern werden Gewicht, KFA und FFM zurück nach Apple Health geschrieben.")
            } else {
                EmptyView()
            }
        }
    }

    /// DEL-034: Im Edit-Mode-Detail-View (fieldsEnabled=false) zeigen wir
    /// keine Save/Delete-Buttons — User muss erst "Bearbeiten" oben rechts
    /// tippen. Im New-Mode + im aktiven Edit-Mode beide Buttons sichtbar.
    @ViewBuilder
    private func actionsSection(forProfile profile: UserBodyProfile) -> some View {
        if fieldsEnabled {
            VStack(spacing: 12) {
                // DEL-106: Primary Save-Button auf dem Deltiq-Hero-Style.
                // Disabled-State erbt das visuelle Look-and-Feel von der
                // umgebenden Section — Tastatur-Dismiss-Toolbar bleibt drueber.
                Button {
                    save(profile: profile)
                } label: {
                    Label(isEditMode ? "Änderungen speichern" : "Messung speichern",
                          systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
                .opacity(canSave(profile: profile) ? 1.0 : 0.5)
                .disabled(!canSave(profile: profile))

                if isEditMode {
                    Button(role: .destructive) {
                        deleteCurrentMeasurement()
                    } label: {
                        Label("Messung löschen", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let lastSavedAt {
                    Text(isEditMode
                         ? "Zuletzt geändert: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))"
                         : "Zuletzt gespeichert: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !canSave(profile: profile) {
                    Text(missingFieldsHint(profile: profile))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        DeltiqFormSection(header: "Verlauf") {
            if historicalMeasurements.isEmpty {
                DeltiqFormFullRow {
                    Text("Noch keine Messungen — speichere oben deinen ersten Wert.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(historicalMeasurements.prefix(12))) { m in
                    DeltiqFormFullRow {
                        NavigationLink {
                            MeasurementView(editing: m)
                        } label: {
                            HStack {
                                HistoryRow(measurement: m)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } footer: {
            if historicalMeasurements.count > 12 {
                Text("Älteste \(historicalMeasurements.count - 12) Messungen ausgeblendet.")
            } else if !historicalMeasurements.isEmpty {
                Text("Tippe einen Eintrag an, um die Werte zu bearbeiten.")
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func metricRow(_ label: String, value: Double, suffix: String = "") -> some View {
        DeltiqFormRow(label: label) {
            Text(value.truncated(to: 2).formattedTwoDecimals + suffix)
                .foregroundStyle(.secondary)
                .fitnessNumberStyle()
        }
    }

    @ViewBuilder
    private func navyRow(_ navy: Double?, profileSex: BodyFormulaProfile) -> some View {
        DeltiqFormRow(label: "KFA Navy") {
            if let navy {
                Text(navy.truncated(to: 2).formattedTwoDecimals + " %")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
                    .fitnessNumberStyle()
            } else {
                Text(profileSex == .female
                     ? "Hals/Taille/Hüfte erforderlich"
                     : "Hals/Taille erforderlich")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// DEL-034 + DEL-106: TextField mit Decimal-Keyboard, an den FocusState
    /// gebunden und mit einer `.id` versehen, damit der ScrollViewReader
    /// die Zeile beim Fokus-Wechsel zentrieren kann.
    @ViewBuilder
    private func decimalField(
        _ label: String,
        value: Binding<Double?>,
        field: MeasurementField
    ) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(label))
            .decimalKeyboard()
            .disabled(!fieldsEnabled)
            .focused($focusedField, equals: field)
            .multilineTextAlignment(.trailing)
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    /// DEL-106: Decimal-Eingabe-Row im neuen DeltiqForm-Stil. Wrapped die
    /// TextField in eine `DeltiqFormRow` mit Label links + Input rechts;
    /// die outer `.id(field)` ist der Anker fuer ScrollViewReader.scrollTo.
    @ViewBuilder
    private func measurementRow(
        label: String,
        value: Binding<Double?>,
        field: MeasurementField
    ) -> some View {
        DeltiqFormRow(label: label) {
            decimalField(label, value: value, field: field)
        }
        .id(field)
    }

    /// DEL-106: Inline-Caption zwischen Form-Rows. Sitzt direkt im VStack
    /// des DeltiqFormSection-Containers; kein Divider, weil das Visual als
    /// "Hint zur vorigen Zeile" gelesen werden soll.
    @ViewBuilder
    private func fieldHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - DEL-106 Focus-Navigation (Keyboard-Toolbar)

    /// Geschlechtsspezifische Feldreihenfolge fuer Previous/Next-Navigation.
    /// Entspricht der visuellen Render-Reihenfolge im UI, damit der User
    /// den selben Pfad ueber die Toolbar laeuft wie mit dem Finger.
    private func fieldOrder(for profile: UserBodyProfile?) -> [MeasurementField] {
        // Pflichtfelder zuerst (in geschlechtsspezifischer Reihenfolge),
        // dann zusaetzliche Felder.
        if profile?.profile == .female {
            return [.weight, .neck, .waist, .hip, .shoulder, .chest, .biceps, .thigh, .calf]
        } else {
            return [.weight, .neck, .waist, .shoulder, .chest, .biceps, .hip, .thigh, .calf]
        }
    }

    /// Bewegt den Fokus um `delta` Schritte (+1 = naechstes Feld, -1 = vorheriges).
    private func moveFocus(by delta: Int) {
        guard let current = focusedField,
              let profile = profiles.first,
              let idx = fieldOrder(for: profile).firstIndex(of: current)
        else { return }
        let order = fieldOrder(for: profile)
        let nextIdx = idx + delta
        guard nextIdx >= 0, nextIdx < order.count else { return }
        focusedField = order[nextIdx]
    }

    /// True, wenn ein `moveFocus(by: delta)`-Aufruf den Fokus tatsaechlich
    /// verschieben wuerde — sonst disablen wir den Toolbar-Button, damit der
    /// User nicht ins Leere tippt.
    private func canMoveFocus(by delta: Int) -> Bool {
        guard let current = focusedField,
              let profile = profiles.first,
              let idx = fieldOrder(for: profile).firstIndex(of: current)
        else { return false }
        let nextIdx = idx + delta
        return nextIdx >= 0 && nextIdx < fieldOrder(for: profile).count
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
