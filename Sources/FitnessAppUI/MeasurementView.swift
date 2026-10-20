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

    /// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Befund "editierbar
    /// ohne Umfangspflicht"): gesetzt einmalig beim Edit-Prefill, wenn die zu
    /// bearbeitende Zeile ohne Umfaenge angelegt wurde (`makeWeightOnly`,
    /// erkennbar an `neckCm == nil` — kein vollstaendiger Eintrag kann das
    /// je haben, `canSave` verlangt es). Lockert `canSave` fuer GENAU diese
    /// Zeile, erzwingt aber nichts — fuellt der User beim Bearbeiten
    /// nachtraeglich alle Pflicht-Umfaenge aus, speichert `save()` trotzdem
    /// als vollen Eintrag (siehe dortige `hasFullCircumferences`-Pruefung).
    @State private var isEditingWeightOnlyEntry: Bool = false

    /// UI-Refactor (Korrektur V4): zeigt den Verwerfen-Dialog, wenn der
    /// Zurueck-Chevron im Edit-Mode bei vorhandenen Aenderungen (`isDirty`)
    /// angetippt wird, statt sofort zu schliessen. Im New-Mode ungenutzt
    /// (kein `onBack`, siehe `body` — Tab-Root).
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (Korrektur V4): Feldstand direkt nach dem Edit-Mode-
    /// Prefill (`applyExistingMeasurement`, siehe `.task` in `body`) —
    /// Vergleichsbasis fuer `isDirty`. Default (alle `nil`) ist im New-Mode
    /// irrelevant, da dort kein Zurueck-Chevron existiert.
    @State private var fieldsAtOpen = MeasurementFieldSnapshot()

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
                // Simulator-Befund (Light Mode, 5. August): New-Mode ist
                // Tab-Root (kein Push, nichts zum Zurueckgehen) - der
                // Chevron erschien trotzdem und tat nichts. Nur im
                // gepushten Edit-Mode (historyRow-NavigationLink) gibt es
                // etwas zum Dismissen.
                // UI-Refactor (Korrektur V4): Verwerfen-Schutz wie bei jedem
                // anderen Editor dieser Epic — ohne Aenderungen sofort
                // schliessen, sonst erst nach Bestaetigung.
                onBack: isEditMode ? { isDirty ? (showingDiscardConfirm = true) : dismiss() } : nil,
                actions: headerActions
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
                            actionsSection
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
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift. Am
        // Tab-Root (New-Mode) ein No-Op, weil dort nichts zum Zurueck-
        // wischen existiert.
        // UI-Refactor (Korrektur V4): im Edit-Mode bei Aenderungen bewusst
        // AUS — sonst waere die Wisch-Geste ein ungesicherter Verlassen-Weg
        // am Discard-Dialog vorbei.
        .deltiqSwipeBackEnabled(isEditMode ? !isDirty : true)
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            dismiss()
        }
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
                // UI-Refactor (Korrektur V4): Baseline fuer `isDirty` ERST
                // jetzt erfassen, nachdem der Prefill die Felder gefuellt
                // hat — sonst waere jede bestehende Messung beim Oeffnen
                // sofort faelschlich "dirty".
                fieldsAtOpen = currentFieldSnapshot
            }
            if !isEditMode {
                await healthKit.refreshAuthorizationStatus()
                await tryAutoFillFromHealthKit()
            }
        }
    }

    /// Handoff 2.5: "LETZTE: 29. JULI" (neutral) + Pflichtfeld-Marke,
    /// verschwindet wenn ausgefuellt. Nur im New-Mode sinnvoll - im
    /// Edit-Mode ist "letzte" der gerade angezeigte Eintrag selbst.
    ///
    /// Simulator-Befund (Light Mode, 5. August): die Marke zeigte nur eine
    /// Zahl ("2 Pflichtfelder"), ohne dass die Zeilen darunter erkennen
    /// liessen, WELCHE zwei gemeint waren. Sie nennt jetzt die Feldnamen
    /// direkt (dieselben Namen wie `missingRequiredFieldNames` liefert).
    @ViewBuilder
    private func measurementContextRow(profile: UserBodyProfile) -> some View {
        if !isEditMode {
            let missingNames = missingRequiredFieldNames(profile: profile)
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
            let missingItem: DeltiqContextItem? = missingNames.isEmpty
                ? nil
                : DeltiqContextItem(missingNames.joined(separator: ", ").uppercased(), style: .accent)
            let items = [lastItem, missingItem].compactMap { $0 }
            if !items.isEmpty {
                DeltiqContextRow(items)
            }
        }
    }

    /// Lokalisierte Namen der noch fehlenden Pflichtfelder, in Formular-
    /// Reihenfolge. Treibt die Kontextzeilen-Marke (New-Mode) sowie die
    /// per-Feld "erforderlich"-Markierungen (`requirementHint`).
    private func missingRequiredFieldNames(profile: UserBodyProfile) -> [String] {
        var missing: [String] = []
        if (weightKg ?? 0) <= 0 { missing.append(loc("measurement.validation.field.weight")) }
        // Settings-Epic Phase 3: eine urspruenglich ohne Umfaenge angelegte
        // Zeile verlangt beim Bearbeiten nur noch das Gewicht.
        guard !isEditingWeightOnlyEntry else { return missing }
        if (neckCm ?? 0)   <= 0 { missing.append(loc("measurement.validation.field.neck")) }
        if (waistCm ?? 0)  <= 0 { missing.append(loc("measurement.validation.field.waist")) }
        if profile.profile == .female, (hipCm ?? 0) <= 0 {
            missing.append(loc("measurement.validation.field.hip"))
        }
        return missing
    }

    /// Titel-Mapping: New-Mode → "measurement.title.new", Edit-Mode →
    /// "measurement.title.edit" (DEL-107). UI-Refactor (Korrektur V4): keine
    /// separate reine Detail-Ansicht mehr — eine bestehende Messung ist beim
    /// Oeffnen sofort editierbar, wie jeder andere Editor dieser Epic.
    private var navTitle: String {
        isEditMode ? loc("measurement.title.edit") : loc("measurement.title.new")
    }

    /// UI-Refactor (Korrektur V4): der Haken oben rechts ist jetzt die
    /// EINZIGE Speichern-Aktion (New- UND Edit-Mode) — ersetzt sowohl den
    /// alten Stift/Haken-Umschalter (der selbst nie speicherte, nur
    /// `isEditingEnabled` togglete — die eigentliche Ursache des gemeldeten
    /// Bugs: wer ihn antippte in der Erwartung, damit zu speichern, verlor
    /// seine Eingabe kommentarlos) als auch den separaten Speichern-Button
    /// unten in `actionsSection`. Ohne Profil (Empty-State) gibt es nichts
    /// zu speichern — dann zeigt der Header keine Aktion.
    private var headerActions: [DeltiqHeaderAction] {
        guard let profile = profiles.first else { return [] }
        return [
            DeltiqHeaderAction(
                systemImage: "checkmark",
                isDisabled: !canSave(profile: profile),
                accessibilityLabel: String(localized: "common.save", bundle: .module)
            ) {
                save(profile: profile)
            }
        ]
    }

    /// UI-Refactor (Korrektur V4): Vergleich gegen `fieldsAtOpen` — nur im
    /// Edit-Mode relevant (New-Mode hat keinen Zurueck-Chevron, der danach
    /// fragen koennte).
    private var isDirty: Bool {
        isEditMode && currentFieldSnapshot != fieldsAtOpen
    }

    private var currentFieldSnapshot: MeasurementFieldSnapshot {
        MeasurementFieldSnapshot(
            weightKg: weightKg, neckCm: neckCm, waistCm: waistCm, hipCm: hipCm,
            shoulderCm: shoulderCm, chestCm: chestCm, bicepsCm: bicepsCm,
            thighCm: thighCm, calfCm: calfCm
        )
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
            measurementRow(label: loc("measurement.field.weight"), value: $weightKg, field: .weight, roundsToWeightPrecision: true)
                .onChange(of: weightKg) { _, newValue in
                    if weightCameFromHealth, newValue != lastHealthFilledWeight {
                        weightCameFromHealth = false
                        lastHealthFilledWeight = nil
                    }
                }
            requirementHint(isRequired: true, isMissing: (weightKg ?? 0) <= 0)
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

            if isEditingWeightOnlyEntry {
                hintRow(loc("measurement.weightOnly.editHint"))
            }

            // Hals (Pflicht ausser bei einer urspruenglich umfangslosen Zeile)
            measurementRow(label: loc("measurement.field.neck"), value: $neckCm, field: .neck)
            requirementHint(isRequired: !isEditingWeightOnlyEntry, isMissing: !isEditingWeightOnlyEntry && (neckCm ?? 0) <= 0)
            fieldHint(loc("measurement.hint.neck"))

            // Taille (Pflicht ausser bei einer urspruenglich umfangslosen Zeile, sex-spezifischer Hint)
            measurementRow(label: loc("measurement.field.waist"), value: $waistCm, field: .waist)
            requirementHint(isRequired: !isEditingWeightOnlyEntry, isMissing: !isEditingWeightOnlyEntry && (waistCm ?? 0) <= 0)
            fieldHint(profile.profile == .male
                      ? loc("measurement.hint.waist.male")
                      : loc("measurement.hint.waist.female"))

            // Hüfte: Pflicht bei Frauen (ausser bei umfangsloser Zeile), optional/anders gruppiert bei Maennern
            if profile.profile == .female {
                measurementRow(label: loc("measurement.field.hip"), value: $hipCm, field: .hip, showsDivider: false)
                requirementHint(isRequired: !isEditingWeightOnlyEntry, isMissing: !isEditingWeightOnlyEntry && (hipCm ?? 0) <= 0)
                fieldHint(loc("measurement.hint.broadest"))
            } else {
                // Männer: Schulter direkt in Pflicht-Section (optional fuer SWR-Ratio).
                // Simulator-Befund (Light Mode, 5. August): stand optisch in
                // der Pflicht-Section, zaehlte aber nie zu canSave/
                // missingRequiredFieldNames - "optional" macht das jetzt
                // direkt an der Zeile sichtbar statt es zu erraten.
                measurementRow(label: loc("measurement.field.shoulder.full"), value: $shoulderCm, field: .shoulder, showsDivider: false)
                requirementHint(isRequired: false, isMissing: false)
                fieldHint(loc("measurement.hint.broadest"))
            }
            hintRow(profile.profile == .female
                 ? loc("measurement.section.core.footer.female")
                 : loc("measurement.section.core.footer.male"))
        }
    }

    /// Simulator-Befund (Light Mode, 5. August): "N Pflichtfelder" in der
    /// Kontextzeile liess nicht erkennen, WELCHE Zeilen unten gemeint waren
    /// - am staerksten sichtbar bei Maennern, wo "Schulter" optisch in der
    /// Pflicht-Section sitzt, aber (nur SWR-Ratio) nie zu den Pflichtfeldern
    /// zaehlt. Fehlende Pflichtfelder bekommen einen Akzent-Punkt +
    /// "erforderlich"; die eine tatsaechlich optionale Zeile in dieser
    /// Section (Schulter bei Maennern) bekommt "optional". Bereits
    /// ausgefuellte Pflichtfelder zeigen nichts mehr — der Hinweis geht
    /// ueber "was fehlt noch", nicht ueber Dauer-Etiketten.
    @ViewBuilder
    private func requirementHint(isRequired: Bool, isMissing: Bool) -> some View {
        if isRequired {
            if isMissing {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.deltiqOrange)
                        .frame(width: 5, height: 5)
                    Text("measurement.field.required", bundle: .module)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.deltiqOrange)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        } else {
            Text("measurement.field.optional", bundle: .module)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.Deltiq.textTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
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

    /// UI-Refactor (Korrektur V4): Speichern ist jetzt ausschliesslich der
    /// Haken oben rechts (`headerActions`) — hier unten bleibt nur noch
    /// Loeschen (Edit-Mode) + der "zuletzt gespeichert"-Hinweis, wie bei
    /// allen anderen Editoren dieser Epic ("Unten auf der Seite gibt es
    /// KEINEN zweiten Speichern-Button mehr"). Braucht kein Profil mehr
    /// (das steckte nur im entfernten Save-Button).
    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
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

    /// DEL-106: TextField mit Decimal-Keyboard, an den FocusState gebunden
    /// und mit einer `.id` versehen, damit der ScrollViewReader die Zeile
    /// beim Fokus-Wechsel zentrieren kann. UI-Refactor (Korrektur V4): immer
    /// editierbar — es gibt keine separate Nur-Lese-Ansicht mehr.
    ///
    /// Fix "70,050003"-Bug: `roundsToWeightPrecision` ist NUR fuer das
    /// Gewichtsfeld `true` — alle anderen Umfang-Felder behalten ihr
    /// bisheriges, unveraendertes Verhalten. Rundet den geschriebenen Wert
    /// sofort auf 2 Nachkommastellen (nicht nur kosmetisch die Anzeige) und
    /// zeigt nie unnoetige Nachkommastellen.
    @ViewBuilder
    private func decimalField(
        _ label: String,
        value: Binding<Double?>,
        field: MeasurementField,
        roundsToWeightPrecision: Bool = false
    ) -> some View {
        let displayValue: Binding<Double?> = roundsToWeightPrecision
            ? Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0?.rounded(toDecimals: 2) })
            : value
        let style: FloatingPointFormatStyle<Double> = roundsToWeightPrecision
            ? .number.precision(.fractionLength(0...2))
            : .number
        TextField(label, value: displayValue, format: style, prompt: Text(label))
            .decimalKeyboard()
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
        showsDivider: Bool = true,
        roundsToWeightPrecision: Bool = false
    ) -> some View {
        DeltiqControlRow(label: label, showsDivider: showsDivider) {
            decimalField(label, value: value, field: field, roundsToWeightPrecision: roundsToWeightPrecision)
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
        isEditingWeightOnlyEntry = (m.neckCm == nil)
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
        guard let w = weightKg, w > 0 else { return false }
        // Settings-Epic Phase 3: eine urspruenglich ohne Umfaenge angelegte
        // Zeile bleibt beim Bearbeiten ohne sie speicherbar — s.
        // `isEditingWeightOnlyEntry`-Dokumentation.
        if isEditingWeightOnlyEntry { return true }
        guard let n = neckCm, n > 0,
              let waist = waistCm, waist > 0
        else { return false }
        if profile.profile == .female {
            guard let h = hipCm, h > 0 else { return false }
        }
        return true
    }

    // MARK: - Save / Delete

    private func save(profile: UserBodyProfile) {
        guard let weightKg, canSave(profile: profile) else { return }

        if let existing = editingMeasurement {
            // Settings-Epic Phase 3: am tatsaechlichen Feldstand entscheiden,
            // nicht am Ausgangszustand — eine urspruenglich umfangslose Zeile
            // darf beim Bearbeiten nachtraeglich zu einer vollen werden, wenn
            // der User jetzt alle Pflicht-Umfaenge eintraegt (siehe
            // `isEditingWeightOnlyEntry`-Dokumentation). Umgekehrt bleibt eine
            // urspruenglich volle Zeile von dieser Bedingung unberuehrt: ihr
            // `canSave` verlangt die Umfaenge ohnehin schon, `save()` wird nie
            // mit leeren Pflichtfeldern erreicht.
            let hasFullCircumferences = (neckCm ?? 0) > 0 && (waistCm ?? 0) > 0
                && (profile.profile == .male || (hipCm ?? 0) > 0)
            // Edit-Mode: ueberschreibe existing Record.
            let recomputed = hasFullCircumferences
                ? BodyMeasurement.makeDerived(
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
                : BodyMeasurement.makeWeightOnly(
                    date: existing.date,
                    ageYears: existing.ageYearsAtMeasurement,
                    weightKg: weightKg,
                    heightCm: profile.heightCm,
                    profile: profile.profile
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
            //
            // Settings-Epic Phase 3: fehlen jetzt die Pflicht-Umfaenge
            // (`!hasFullCircumferences`), werden Arm/Bein IMMER genullt —
            // unabhaengig vom Prefill-Vergleich, sonst bliebe bei einer zur
            // Weight-only-Zeile zurueckgestuften Eingabe ein inkonsistenter
            // Rest aus Hals/Taille-losen, aber noch gesetzten Arm/Bein-Werten
            // stehen.
            if hasFullCircumferences {
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
            } else {
                existing.upperArmCm = nil
                existing.upperArmLeftCm = nil
                existing.upperArmRightCm = nil
                existing.thighCm = nil
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

            // TestingBot-Regressionscheck E01 (Deltiq-Abnahme, derselbe
            // Musterfehler wie `deleteCurrentMeasurement` unten und die
            // zwoelf in `docs/DELTIQ_DEVICE_ACCEPTANCE.md` dokumentierten
            // Faelle): ohne sofortigen `context.save()` haengt die
            // Persistenz dieser Bearbeitung an SwiftDatas implizitem
            // Autosave, der einen App-Kaltstart kurz danach nicht
            // zuverlaessig schon durchlaufen haben muss — die Aenderung
            // waere dann nach Neustart wieder auf dem alten Stand.
            try? modelContext.save()

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

    /// TestingBot-Regressionscheck (Block A, Deltiq-Abnahme, siehe
    /// `PlansListView.deletePlans`-Doku): ohne sofortigen `context.save()`
    /// verlaesst sich die Loeschung auf SwiftDatas impliziten Autosave und
    /// kann einen kurz danach folgenden Kaltstart nicht ueberstehen — die
    /// geloeschte Messung waere dann wieder da.
    private func deleteCurrentMeasurement() {
        guard let existing = editingMeasurement else { return }
        modelContext.delete(existing)
        try? modelContext.save()
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

/// UI-Refactor (Korrektur V4): Vergleichsbasis fuer `MeasurementView.isDirty`
/// — die neun Formularfelder, direkt nach dem Edit-Mode-Prefill erfasst
/// (siehe `fieldsAtOpen`). Kein `apply(to:)`: anders als die autosave-
/// Editoren dieser Epic schreibt `MeasurementView` Feldaenderungen NIE
/// direkt ins SwiftData-Model, sondern haelt sie als reinen Draft in
/// `@State` (wie `BodyDataEditorView`) — "Verwerfen" ist deshalb ein
/// einfaches `dismiss()`, das Model wurde nie angefasst. `internal` statt
/// `private`, damit gezielte Tests (siehe `Tests/FitnessAppUITests`) die
/// Equatable-Semantik direkt pruefen koennen.
@available(iOS 17.0, macOS 14.0, *)
struct MeasurementFieldSnapshot: Equatable {
    // Explizite `= nil`-Defaults (statt nur `Double?`): macht den
    // synthetisierten memberwise `init()` garantiert parameterlos aufrufbar
    // (`fieldsAtOpen`s Default-Init oben) statt von einer impliziten
    // Optional-Default-Regel abzuhaengen.
    var weightKg: Double? = nil
    var neckCm: Double? = nil
    var waistCm: Double? = nil
    var hipCm: Double? = nil
    var shoulderCm: Double? = nil
    var chestCm: Double? = nil
    var bicepsCm: Double? = nil
    var thighCm: Double? = nil
    var calfCm: Double? = nil
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
