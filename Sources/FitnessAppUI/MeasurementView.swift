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

/// DEL-107: Convenience-Wrapper auf `String(localized:bundle:)` mit
/// hartem `Bundle.module`-Lookup. Spart Tipparbeit und macht Call-Sites
/// gegen versehentliches `Bundle.main`-Drift robust.
@available(iOS 17.0, macOS 14.0, *)
fileprivate func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

@available(iOS 17.0, macOS 14.0, *)
public struct MeasurementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

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

    /// DEL-219: Snapshot der beim Edit-Prefill eingesetzten Arm-/Bein-Werte.
    /// Dieses Formular kennt nur EIN Feld pro Koerperteil, waehrend das Model
    /// zusaetzlich Links/Rechts fuehren kann (DEL-016). Beim Prefill werden
    /// L/R zu einem Mittelwert zusammengefasst; beim Speichern muss deshalb
    /// unterschieden werden, ob der User den Wert tatsaechlich angefasst hat:
    ///   * unveraendert → L/R bleiben erhalten (der Mittelwert war nur Anzeige)
    ///   * veraendert   → L/R sind ueberholt und werden verworfen
    /// Vorher wurden L/R bei JEDEM Edit geloescht — wer nur sein Gewicht
    /// korrigierte, verlor die Seiten-Messungen unwiederbringlich.
    @State private var prefilledBicepsCm: Double?
    @State private var prefilledThighCm: Double?

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
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: Eyebrow MESSUNG, Titel folgt dem
            // bestehenden new/detail/edit-Mapping. Der Bearbeiten/Fertig-
            // Text-Button wird zu einem Icon (Stift/Haken) - DeltiqHeader
            // hat keinen Text-Aktions-Slot, nur 32x32-Icon-Quadrate.
            DeltiqHeader(
                eyebrow: loc("measurement.header.eyebrow"),
                title: navTitle,
                onBack: { dismiss() },
                actions: isEditMode ? [
                    DeltiqHeaderAction(
                        systemImage: isEditingEnabled ? "checkmark" : "pencil",
                        isHighlighted: isEditingEnabled
                    ) {
                        isEditingEnabled.toggle()
                    }
                ] : []
            )

            // DEL-106: ScrollViewReader hostet die Auto-Scroll-Choreografie,
            // wenn der fokussierte Field-State wechselt. ScrollView ersetzt
            // das Apple-Form — Side-Effect: wir verlieren das auto-Scroll-
            // auf-Tastatur-Behavior, und holen es hier explizit zurueck.
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 18) {
                        if let profile = profiles.first {
                            // Signature-Geruest 1.3: Kontextzeile mit letztem
                            // Eintrag (neutral) + fehlenden Pflichtfeldern
                            // (Marke, verschwindet bei 0).
                            measurementContextRow(profile: profile)
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
                                loc("measurement.empty.title"),
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text("measurement.empty.description", bundle: .module)
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // DEL-106: Bottom-Padding fuer die Tastatur — verhindert,
                    // dass die letzten Felder unter der Tastatur "stecken" bleiben.
                    .padding(.bottom, focusedField == nil ? 100 : 140)
                }
                .scrollContentBackground(.hidden)
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
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        // Bug-Fix: der zentrale Aktionsknopf lebte vorher als EIN Overlay
        // auf der aeusseren TabView (MainTabView) und schwebte dadurch ueber
        // JEDEM gepushten Screen UND ueber der Tastatur. Dieser View wird
        // sowohl als Tab-Root (New-Mode) als auch gepusht (Edit-Mode fuer
        // eine historische Messung, `historyRow`) instanziiert - deshalb
        // zusaetzlich zum ueblichen "nur am Root zeichnen"-Fix (siehe
        // Theme.swift/DeltiqCentralActionButton) noch zwei eigene
        // Bedingungen: `!isEditMode` (Edit-Mode-Instanz blendet ihn ganz
        // aus) und `focusedField == nil` (Root-Instanz hat selbst
        // Root-Level-Tastaturfelder, im Gegensatz zu den anderen drei
        // Tab-Roots).
        .overlay(alignment: .bottom) {
            if !isEditMode && focusedField == nil {
                DeltiqCentralActionButton {
                    navigation.startOrResumeWorkout(modelContext: modelContext)
                }
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
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

                Button {
                    focusedField = nil
                } label: {
                    Text("measurement.action.done", bundle: .module)
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

    /// Handoff 2.5: "LETZTE: 29. JULI" (neutral) + "3 PFLICHTFELDER" (Marke,
    /// verschwindet wenn ausgefuellt). Nur im New-Mode sinnvoll - im
    /// Edit-Mode ist "letzte" der gerade angezeigte Eintrag selbst.
    @ViewBuilder
    private func measurementContextRow(profile: UserBodyProfile) -> some View {
        if !isEditMode {
            let missing = missingRequiredCount(profile: profile)
            // @ViewBuilder transformiert JEDE Nicht-Deklarations-Anweisung im
            // Funktionskoerper - das vorherige `items.append(...)` (Void-
            // Aufruf) scheiterte an buildExpression ("type '()' cannot
            // conform to 'View'"). compactMap-Array-Literal (wie
            // DashboardView.dashboardContextRow) nutzt nur `let`-Bindings,
            // die vom Builder-Transform ausgenommen sind.
            //
            // `lastDate` zuerst als eigenes Optional materialisieren, dann
            // separat `.map` aufrufen - `historicalMeasurements.first?.date
            // .map { }` in EINER Kette waere `?.` ueber die GESAMTE Kette
            // inkl. `.map` gewesen, wodurch `.map` auf dem entpackten `Date`
            // (kein `.map`-Member) statt auf `Date?` aufgerufen wird.
            let lastDate = historicalMeasurements.first?.date
            let lastItem = lastDate.map { last in
                DeltiqContextItem(
                    String(format: loc("measurement.context.last"), last.formatted(date: .abbreviated, time: .omitted)).uppercased(),
                    style: .neutral
                )
            }
            let missingItem: DeltiqContextItem? = missing > 0
                ? DeltiqContextItem(
                    String(
                        format: missing == 1 ? loc("measurement.context.missing.one") : loc("measurement.context.missing.many"),
                        missing
                    ).uppercased(),
                    style: .accent
                  )
                : nil
            let items = [lastItem, missingItem].compactMap { $0 }
            if !items.isEmpty {
                DeltiqContextRow(items)
            }
        }
    }

    /// Gleiche Bedingungen wie `missingFieldsHint`, nur als Zaehler statt
    /// als zusammengesetzter Satz - fuer die Kontextzeile.
    private func missingRequiredCount(profile: UserBodyProfile) -> Int {
        var count = 0
        if (weightKg ?? 0) <= 0 { count += 1 }
        if (neckCm ?? 0)   <= 0 { count += 1 }
        if (waistCm ?? 0)  <= 0 { count += 1 }
        if profile.profile == .female, (hipCm ?? 0) <= 0 {
            count += 1
        }
        return count
    }

    /// Titel-Mapping: New-Mode → "measurement.title.new", Edit-Mode wechselt
    /// zwischen "measurement.title.detail" und "measurement.title.edit" je
    /// nach Editing-Toggle (DEL-107).
    private var navTitle: String {
        if isEditMode {
            return isEditingEnabled ? loc("measurement.title.edit") : loc("measurement.title.detail")
        }
        return loc("measurement.title.new")
    }

    // MARK: - Profile-Section (Single-Source-of-Truth)

    @ViewBuilder
    private func profileSection(_ profile: UserBodyProfile) -> some View {
        // DEL-107: Einheiten "kg" / "cm" / "%" bleiben unlokalisiert —
        // identisch in DE/EN/TR. Nur "Jahre"/"Years"/"Yıl" wandert in den
        // Catalog. String-Interpolation klebt Wert + Unit zusammen.
        DeltiqSection(loc("measurement.section.profile").uppercased()) {
            DeltiqControlRow(label: loc("measurement.profile.height")) {
                valueText(profile.heightCm.formattedTwoDecimals + " cm")
            }
            DeltiqControlRow(label: loc("measurement.profile.age.label")) {
                valueText("\(ageYears(for: profile)) \(loc("measurement.profile.age.unit"))")
            }
            DeltiqControlRow(
                label: loc("measurement.profile.sex.label"),
                showsDivider: profile.goalWeightKg != nil
            ) {
                valueText(profile.profile == .male
                     ? loc("measurement.profile.sex.male")
                     : loc("measurement.profile.sex.female"))
            }
            if let goal = profile.goalWeightKg {
                DeltiqControlRow(label: loc("measurement.profile.goalWeight"), showsDivider: false) {
                    valueText(goal.formattedTwoDecimals + " kg")
                }
            }
        }
    }

    /// Signature-Geruest 1.6: "Wert rechts 15pt, Weiss 60%; Zahlen
    /// zusaetzlich fitnessNumberStyle()".
    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .fitnessNumberStyle()
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
        // Signature-Geruest 1.4: die Pflichtwerte-Karte traegt die
        // Hauptaussage des Screens - die eine erlaubte Orange-Kante.
        DeltiqSection(loc("measurement.section.core.title").uppercased(), accentEdge: true) {
            // Gewicht (immer Pflicht)
            measurementRow(label: loc("measurement.field.weight"), value: $weightKg, field: .weight)
                .onChange(of: weightKg) { _, newValue in
                    if weightCameFromHealth, newValue != lastHealthFilledWeight {
                        weightCameFromHealth = false
                        lastHealthFilledWeight = nil
                    }
                }
            if weightCameFromHealth, weightKg != nil {
                HStack {
                    Label {
                        Text("measurement.healthkit.fromHealth", bundle: .module)
                    } icon: {
                        Image(systemName: "heart.fill")
                    }
                    .font(.system(size: 12))
                    // Handoff 2.5: Apple-Health-Hinweis bleibt in Health-Rot -
                    // Fremdmarke, keine Deltiq-Farbe, darf abweichen.
                    .foregroundStyle(Color.Deltiq.health)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            // Hals (immer Pflicht)
            measurementRow(label: loc("measurement.field.neck"), value: $neckCm, field: .neck)
            fieldHint(loc("measurement.hint.neck"))

            // Taille (immer Pflicht, sex-spezifischer Hint)
            measurementRow(label: loc("measurement.field.waist"), value: $waistCm, field: .waist)
            fieldHint(profile.profile == .male
                      ? loc("measurement.hint.waist.male")
                      : loc("measurement.hint.waist.female"))

            // Hüfte: Pflicht bei Frauen, optional/anders gruppiert bei Maennern
            if profile.profile == .female {
                measurementRow(label: loc("measurement.field.hip"), value: $hipCm, field: .hip, showsDivider: false)
                fieldHint(loc("measurement.hint.broadest"))
            } else {
                // Männer: Schulter direkt in Pflicht-Section (optional fuer SWR-Ratio).
                measurementRow(label: loc("measurement.field.shoulder.full"), value: $shoulderCm, field: .shoulder, showsDivider: false)
                fieldHint(loc("measurement.hint.broadest"))
            }
            hintRow(profile.profile == .female
                 ? loc("measurement.section.core.footer.female")
                 : loc("measurement.section.core.footer.male"))
        }
    }

    /// Abschnitt 1.6: Hinweistext (12pt, sekundaer) als letzte Zeile in der
    /// Karte statt als Footer darunter.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Sektion 3: Weitere Umfaenge (geschlechtsspezifische Reihenfolge)

    @ViewBuilder
    private func additionalMeasurementsSection(forProfile profile: UserBodyProfile) -> some View {
        DeltiqSection(loc("measurement.section.additional.title").uppercased()) {
            if profile.profile == .male {
                // Maenner: Brust, Bizeps, Hüfte, Oberschenkel, Wade
                // (Schulter ist schon oben als Pflicht-optional)
                measurementRow(label: loc("measurement.field.chest"),  value: $chestCm,  field: .chest)
                measurementRow(label: loc("measurement.field.biceps"), value: $bicepsCm, field: .biceps)
                measurementRow(label: loc("measurement.field.hip"),    value: $hipCm,    field: .hip)
                measurementRow(label: loc("measurement.field.thigh"),  value: $thighCm,  field: .thigh)
                measurementRow(label: loc("measurement.field.calf"),   value: $calfCm,   field: .calf, showsDivider: false)
            } else {
                // Frauen: Schulter, Brust, Bizeps, Oberschenkel, Wade
                // (Hüfte ist schon oben als Pflicht)
                measurementRow(label: loc("measurement.field.shoulder.label"), value: $shoulderCm, field: .shoulder)
                if shoulderCm != nil {
                    fieldHint(loc("measurement.hint.broadest"))
                }
                measurementRow(label: loc("measurement.field.chest"),  value: $chestCm,  field: .chest)
                measurementRow(label: loc("measurement.field.biceps"), value: $bicepsCm, field: .biceps)
                measurementRow(label: loc("measurement.field.thigh"),  value: $thighCm,  field: .thigh)
                measurementRow(label: loc("measurement.field.calf"),   value: $calfCm,   field: .calf, showsDivider: false)
            }
            hintRow(loc("measurement.section.additional.footer"))
        }
    }

    // MARK: - Sektion 2: Auswertung

    @ViewBuilder
    private func derivedSection(forProfile profile: UserBodyProfile) -> some View {
        DeltiqSection(loc("measurement.section.derived").uppercased()) {
            if let derived = derivedMetrics(for: profile) {
                metricRow(loc("measurement.derived.bmi"),         value: derived.bmi)
                navyRow(derived.navyBodyFatPct, profileSex: profile.profile)
                metricRow(loc("measurement.derived.deurenberg"),  value: derived.deurenbergBodyFatPct, suffix: " %")
                metricRow(loc("measurement.derived.fatfree"),     value: derived.fatFreeMassKg, suffix: " kg")
                metricRow(loc("measurement.derived.ffmi"),        value: derived.ffmi)
                metricRow(loc("measurement.derived.ffmiNorm"),    value: derived.normalizedFfmi)
                metricRow(loc("measurement.derived.bmr"),         value: derived.bmr, suffix: " kcal")
            } else {
                DeltiqRow(
                    label: String(localized: "measurement.derived.empty", bundle: .module),
                    showsDivider: false
                )
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
                DeltiqSection(loc("measurement.section.ratios").uppercased()) {
                    ratioTile(
                        title: loc("measurement.ratio.whr.title"),
                        value: waist / hip,
                        label: whrLabel(waist / hip),
                        icon: "figure.dress.line.vertical.figure"
                    )
                    hintRow(loc("measurement.ratio.whr.footer"))
                }
            }
        case .male:
            if let shoulder = shoulderCm, let waist = waistCm, shoulder > 0, waist > 0 {
                DeltiqSection(loc("measurement.section.ratios").uppercased()) {
                    ratioTile(
                        title: loc("measurement.ratio.swr.title"),
                        value: shoulder / waist,
                        label: swrLabel(shoulder / waist),
                        icon: "figure.arms.open"
                    )
                    hintRow(loc("measurement.ratio.swr.footer"))
                }
            }
        }
    }

    /// Handoff 1.7: beide Ratio-Kacheln (WHR fuer Frauen, SWR fuer Maenner)
    /// waren bisher Lila bzw. Orange getont - Lila ist nach der neuen Regel
    /// nicht mehr erlaubt, beide werden einheitlich Orange.
    private func ratioTile(title: String, value: Double, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .deltiqAccentIcon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Text(value.truncated(to: 2).formattedTwoDecimals)
                    .font(.system(size: 22, weight: .heavy))
                    .fitnessNumberStyle()
            }
            Spacer()
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
    }

    private func whrLabel(_ ratio: Double) -> String {
        switch ratio {
        case ..<0.80: return loc("measurement.ratio.whr.healthy")
        case ..<0.85: return loc("measurement.ratio.whr.borderline")
        default:      return loc("measurement.ratio.whr.elevated")
        }
    }

    private func swrLabel(_ ratio: Double) -> String {
        switch ratio {
        case ..<1.30: return loc("measurement.ratio.swr.narrow")
        case ..<1.50: return loc("measurement.ratio.swr.medium")
        case ..<1.62: return loc("measurement.ratio.swr.pronounced")
        default:      return loc("measurement.ratio.swr.vshape")
        }
    }

    // MARK: - HealthKit + Actions + History sections (unveraendert vs. DEL-025)

    @ViewBuilder
    private var healthKitSection: some View {
        DeltiqSection(loc("measurement.section.healthkit").uppercased()) {
            if !healthKit.isAvailable {
                DeltiqRow(icon: "heart.slash", label: loc("measurement.healthkit.unavailable"), showsDivider: false)
            } else {
                switch healthKit.authorizationStatus {
                case .notDetermined:
                    DeltiqRow(
                        icon: "heart.fill",
                        label: loc("measurement.healthkit.connect"),
                        showsDivider: false,
                        action: { Task { await healthKit.requestAuthorization() } }
                    )
                case .sharingAuthorized:
                    DeltiqControlRow(icon: "heart.fill", label: loc("measurement.healthkit.connected")) {
                        if let lastSync = healthKit.lastSyncDate {
                            Text("Sync \(lastSync.formatted(.relative(presentation: .named)))")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                    }
                    DeltiqRow(
                        icon: "arrow.down.circle",
                        label: loc("measurement.healthkit.pullWeight"),
                        showsDivider: false,
                        action: { Task { await pullLatestWeightFromHealth() } }
                    )
                    hintRow(loc("measurement.healthkit.footer"))
                case .sharingDenied:
                    DeltiqRow(icon: "heart.slash", label: loc("measurement.healthkit.blocked"), showsDivider: false)
                case .unavailable:
                    DeltiqRow(icon: "heart.slash", label: loc("measurement.healthkit.unavailable"), showsDivider: false)
                }
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
                    Label {
                        Text(isEditMode
                             ? "measurement.action.saveEdit"
                             : "measurement.action.save",
                             bundle: .module)
                    } icon: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
                .opacity(canSave(profile: profile) ? 1.0 : 0.5)
                .disabled(!canSave(profile: profile))

                if isEditMode {
                    // Signature-Geruest 1.9: Destruktiv = Text 15pt in
                    // #FF453A, kein Hintergrund - statt des bisherigen
                    // .bordered-System-Buttons.
                    Button(role: .destructive) {
                        deleteCurrentMeasurement()
                    } label: {
                        Label {
                            Text("measurement.action.delete", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(Color.Deltiq.error)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                if let lastSavedAt {
                    // DEL-107: %@-Placeholder fuer das formatierte Datum.
                    let stamp = lastSavedAt.formatted(date: .abbreviated, time: .shortened)
                    Text(isEditMode
                         ? String(localized: "measurement.lastSaved.edit", bundle: .module).replacingOccurrences(of: "%@", with: stamp)
                         : String(localized: "measurement.lastSaved.new", bundle: .module).replacingOccurrences(of: "%@", with: stamp))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }

                if !canSave(profile: profile) {
                    Text(missingFieldsHint(profile: profile))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        DeltiqSection(loc("measurement.section.history").uppercased()) {
            if historicalMeasurements.isEmpty {
                DeltiqRow(label: loc("measurement.history.empty"), showsDivider: false)
            } else {
                let recent = Array(historicalMeasurements.prefix(12))
                ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { idx, m in
                    historyRow(m, showsDivider: idx < recent.count - 1)
                }
                if historicalMeasurements.count > 12 {
                    // DEL-107: %lld-Placeholder fuer Integer-Count.
                    hintRow(
                        String(localized: "measurement.history.older", bundle: .module)
                            .replacingOccurrences(of: "%lld", with: "\(historicalMeasurements.count - 12)")
                    )
                } else {
                    hintRow(loc("measurement.history.hint"))
                }
            }
        }
    }

    /// Handoff 1.6: `HistoryRow`s zweispaltiger Inhalt (Datum+KFA links,
    /// Gewicht+Bizeps rechts) passt in keinen der festen `DeltiqRow`-Slots
    /// (nur ein `value`-Text) - deshalb hier von Hand die gleiche Zeilen-
    /// Chrome (Padding 14/12, Trennlinie, Chevron) nachgebaut statt
    /// `DeltiqRow` zu erzwingen. Vgl. `ratioTile` fuer das gleiche Muster.
    private func historyRow(_ measurement: BodyMeasurement, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                MeasurementView(editing: measurement)
            } label: {
                HStack(spacing: 12) {
                    HistoryRow(measurement: measurement)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Deltiq.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func metricRow(_ label: String, value: Double, suffix: String = "") -> some View {
        DeltiqControlRow(label: label) {
            valueText(value.truncated(to: 2).formattedTwoDecimals + suffix)
        }
    }

    @ViewBuilder
    private func navyRow(_ navy: Double?, profileSex: BodyFormulaProfile) -> some View {
        DeltiqControlRow(label: loc("measurement.derived.navy.label")) {
            if let navy {
                Text(navy.truncated(to: 2).formattedTwoDecimals + " %")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .fitnessNumberStyle()
            } else {
                // Handoff 2.5: leere Werte als "—" statt "0,00" - hier gibt
                // es zwar schon einen Fallback-Satz statt einer nackten
                // Zahl, aber auch der wird auf den knappen Gedankenstrich
                // reduziert, damit er sich optisch wie die anderen leeren
                // Pflichtwerte verhaelt statt wie ein ganzer Satz zu wirken.
                Text("—")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Deltiq.textTertiary)
                    .accessibilityLabel(Text(profileSex == .female
                         ? "measurement.derived.navy.fallback.female"
                         : "measurement.derived.navy.fallback.male",
                         bundle: .module))
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
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    /// DEL-106: Decimal-Eingabe-Row im Signature-Geruest. Wrapped die
    /// TextField in eine `DeltiqControlRow` mit Label links + Input rechts;
    /// die outer `.id(field)` ist der Anker fuer ScrollViewReader.scrollTo.
    @ViewBuilder
    private func measurementRow(
        label: String,
        value: Binding<Double?>,
        field: MeasurementField,
        showsDivider: Bool = true
    ) -> some View {
        DeltiqControlRow(label: label, showsDivider: showsDivider) {
            decimalField(label, value: value, field: field)
        }
        .id(field)
    }

    /// DEL-106: Inline-Caption zwischen Form-Rows. Sitzt direkt im VStack
    /// des DeltiqSection-Containers; kein Divider, weil das Visual als
    /// "Hint zur vorigen Zeile" gelesen werden soll.
    @ViewBuilder
    private func fieldHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
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
        // DEL-219: Prefill-Stand merken, um beim Speichern "unveraendert" von
        // "vom User neu gesetzt" unterscheiden zu koennen.
        prefilledBicepsCm = bicepsCm
        prefilledThighCm  = thighCm
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
    /// DEL-107: einzelne Feldnamen + Singular/Plural-Frame komplett
    /// lokalisiert, sodass der Hint auch auf EN/TR konsistent klingt.
    private func missingFieldsHint(profile: UserBodyProfile) -> String {
        var missing: [String] = []
        if (weightKg ?? 0) <= 0 { missing.append(loc("measurement.validation.field.weight")) }
        if (neckCm ?? 0)   <= 0 { missing.append(loc("measurement.validation.field.neck")) }
        if (waistCm ?? 0)  <= 0 { missing.append(loc("measurement.validation.field.waist")) }
        if profile.profile == .female, (hipCm ?? 0) <= 0 {
            missing.append(loc("measurement.validation.field.hip"))
        }
        let joined = missing.joined(separator: ", ")
        let template = missing.count == 1
            ? String(localized: "measurement.validation.missing.one", bundle: .module)
            : String(localized: "measurement.validation.missing.many", bundle: .module)
        return template.replacingOccurrences(of: "%@", with: joined)
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
            existing.calfCm = recomputed.calfCm
            // DEL-219: Arm und Bein nur anfassen, wenn der User den
            // zusammengefassten Wert wirklich geaendert hat — dann sind die
            // Seiten-Werte ueberholt und werden verworfen. Bleibt das Feld
            // unangetastet (typischer Fall: es sollte nur das Gewicht
            // korrigiert werden), bleibt die Original-Aufteilung komplett
            // stehen. Wichtig ist auch, den Einzelwert dann NICHT zu
            // schreiben: sonst wuerde der beim Prefill gebildete Mittelwert
            // persistiert und die Seiten-Werte in der Anzeige dauerhaft
            // maskieren (`bicepsDisplay` bevorzugt den Einzelwert).
            if bicepsCm != prefilledBicepsCm {
                existing.upperArmCm = recomputed.upperArmCm
                existing.upperArmLeftCm = nil
                existing.upperArmRightCm = nil
            }
            if thighCm != prefilledThighCm {
                existing.thighCm = recomputed.thighCm
                existing.thighLeftCm = nil
                existing.thighRightCm = nil
            }
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                if let kfa = bestBodyFatPct {
                    Text("KFA \(kfa.truncated(to: 1).formattedTwoDecimals) %")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(measurement.weightKg.truncated(to: 2).formattedTwoDecimals) kg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .fitnessNumberStyle()
                if let bicepsAvg = bicepsDisplay {
                    Text("Bizeps \(bicepsAvg.truncated(to: 1).formattedTwoDecimals) cm")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .fitnessNumberStyle()
                }
            }
        }
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
