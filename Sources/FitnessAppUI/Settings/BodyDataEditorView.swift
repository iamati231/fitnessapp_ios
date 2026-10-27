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

    /// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs):
    /// `draftWeightKg`/`draftGoalWeightKg` bleiben kanonisch kg (Speicherung,
    /// `isDirty`, `canSave`, `save()` unveraendert) - nur Anzeige/Eingabe der
    /// beiden Gewichtsfelder konvertiert hier in die gewaehlte Einheit.
    /// `draftHeightCm` bleibt bewusst AUSSERHALB dieses Scopes (nicht Teil
    /// des Settings-Hinweistexts "Eingabe-Feldern ... Hantel-Rechner ...
    /// Karten" fuer GEWICHT; Groesse/cm-in ist ein separates, hier nicht
    /// beauftragtes Thema).
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var draftHeightCm: Double
    @State private var draftGoalWeightKg: Double?
    @State private var draftWeightKg: Double?
    @State private var weightTouched = false
    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false
    /// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): Doppeltap-
    /// Schutz — `save()` legt bei gesetztem `weightTouched` eine neue
    /// `BodyMeasurement` an; ohne Guard koennten zwei schnell aufeinander-
    /// folgende Taps auf den Haekchen-Button zwei Zeilen anlegen.
    @State private var isSaving = false
    /// Task 5: sichtbare Fehlermeldung statt eines verschluckten Fehlers —
    /// bisher gab es hier GAR keinen `modelContext.save()`-Aufruf, ein
    /// fehlgeschlagener Save sah fuer den Nutzer wie Erfolg aus.
    @State private var saveErrorMessage: String?

    init(profile: UserBodyProfile) {
        self.profile = profile
        _draftHeightCm = State(initialValue: profile.heightCm)
        _draftGoalWeightKg = State(initialValue: profile.goalWeightKg)
        _draftWeightKg = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UI-Refactor (DeltiqHeader-Muster fuer Editoren): ersetzt
                // natives Cancel/Save-Toolbar. Speichern sitzt jetzt als
                // Checkmark oben rechts (deaktiviert bei `!canSave`), der
                // Chevron oben links fragt bei Aenderungen nach statt sofort
                // zu schliessen (reiner Draft-Screen — bei Discard wurde
                // noch nichts persistiert, `dismiss()` reicht).
                DeltiqHeader(
                    eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                    title: String(localized: "profile.bodyData.title", bundle: .module),
                    onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                    actions: [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            isDisabled: !canSave || isSaving,
                            accessibilityLabel: String(localized: "common.save", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let saveErrorMessage {
                            errorRow(saveErrorMessage)
                        }
                        heightSection
                        weightSection
                        goalSection
                    }
                    .padding()
                }
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            .keyboardDismissToolbar()
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            // UI-Refactor (Korrektur, Punkt 4): interaktives Wegziehen des
            // Sheets ist sonst ein ungesicherter Verlassen-Weg am Discard-
            // Dialog vorbei. Ohne Aenderungen (`!isDirty`) bleibt es normal
            // moeglich (direktes Schliessen).
            .interactiveDismissDisabled(isDirty)
        }
    }

    /// UI-Refactor (DeltiqHeader-Muster): true sobald sich mind. ein Feld
    /// vom Ausgangszustand unterscheidet. Ein beruehrtes, aber wieder auf
    /// "kein Wert"/0 zurueckgesetztes Gewichtsfeld zaehlt bewusst NICHT als
    /// Aenderung — `canSave`/`save()` behandeln einen solchen Zustand
    /// ebenfalls als "kein neuer Eintrag" (siehe dort).
    private var isDirty: Bool {
        draftHeightCm != profile.heightCm
            || draftGoalWeightKg != profile.goalWeightKg
            || (weightTouched && (draftWeightKg ?? 0) > 0)
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
            DeltiqControlRow(label: weightFieldLabel, showsDivider: false) {
                TextField(
                    weightFieldLabel,
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
            DeltiqControlRow(label: goalWeightFieldLabel, showsDivider: false) {
                let unit = WeightUnit(rawSetting: weightUnitRaw)
                let displayValue = Binding<Double?>(
                    get: { draftGoalWeightKg.map(unit.fromKg) },
                    set: { draftGoalWeightKg = $0.map { unit.toKg($0).rounded(toDecimals: 2) } }
                )
                TextField(
                    goalWeightFieldLabel,
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
    /// `draftWeightKg` bleibt kanonisch kg - Konvertierung nur fuer die
    /// Anzeige/Eingabe-Seite dieses Bindings (siehe `WeightUnit`-Doku).
    private var weightFieldBinding: Binding<Double?> {
        let unit = WeightUnit(rawSetting: weightUnitRaw)
        return Binding(
            get: { draftWeightKg.map(unit.fromKg) },
            set: { newValue in
                draftWeightKg = newValue.map { unit.toKg($0).rounded(toDecimals: 2) }
                weightTouched = true
            }
        )
    }

    private var weightPlaceholder: String {
        guard let latest = measurements.first else {
            return String(localized: "profile.bodyData.weight.placeholderEmpty", bundle: .module)
        }
        return WeightUnit(rawSetting: weightUnitRaw).fromKg(latest.weightKg).formattedWeightInput()
    }

    private var weightFieldLabel: String {
        weightUnitRaw == "lbs"
            ? String(localized: "profile.bodyData.weight.label.lbs", bundle: .module)
            : String(localized: "profile.bodyData.weight.label", bundle: .module)
    }

    private var goalWeightFieldLabel: String {
        weightUnitRaw == "lbs"
            ? String(localized: "profile.bodyData.goalWeight.label.lbs", bundle: .module)
            : String(localized: "onboarding.field.goalWeightKg", bundle: .module)
    }

    private var canSave: Bool {
        guard Self.heightRange.contains(draftHeightCm) else { return false }
        if weightTouched, let w = draftWeightKg { return w > 0 }
        return true
    }

    private static let heightRange: ClosedRange<Double> = 100...250

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        // Audit-Fund (Rollback bei fehlgeschlagenem Save): Schnappschuss der beiden
        // Felder, die gleich auf das bereits lebende `profile` mutiert werden - ohne
        // das bliebe `profile` nach einem fehlgeschlagenen `context.save()` mit den nie
        // bestaetigten Entwurfswerten stehen, und ein spaeterer, unabhaengiger Save
        // irgendwo sonst in der App wuerde sie versehentlich mitpersistieren. Identisches
        // Prinzip wie `CardioGoalEditorView.save()` (Commit 8bdb416).
        let originalHeightCm = profile.heightCm
        let originalGoalWeightKg = profile.goalWeightKg

        profile.heightCm = draftHeightCm
        profile.goalWeightKg = draftGoalWeightKg
        // Groesse/Zielgewicht allein (oder ein nie angefasstes Gewichtsfeld)
        // legen bewusst KEINEN neuen Gewichtseintrag an — nur eine
        // tatsaechliche Eingabe tut das, auch wenn sie zufaellig dem letzten
        // bekannten Wert entspricht (Pflicht-Vorgabe).
        var insertedMeasurement: BodyMeasurement?
        if weightTouched, let weightKg = draftWeightKg, weightKg > 0 {
            let ageYears = Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
            let measurement = BodyMeasurement.makeWeightOnly(
                ageYears: ageYears,
                weightKg: weightKg,
                heightCm: draftHeightCm,
                profile: profile.profile
            )
            modelContext.insert(measurement)
            insertedMeasurement = measurement
        }

        // Task 5: vorher GAR kein `context.save()` hier — Groesse/Zielgewicht
        // (per `@Bindable` bereits mutiert) UND ein frisch eingefuegter
        // Gewichtseintrag haengten komplett an SwiftDatas implizitem
        // Autosave, der einen Kaltstart kurz danach nicht zuverlaessig
        // ueberstehen muss (derselbe Musterfehler wie `DayEditorView.
        // saveAndDismiss()`). Ein fehlgeschlagener Save dismisst jetzt NICHT
        // mehr, der frisch eingefuegte Eintrag wird zurueckgerollt.
        do {
            try modelContext.save()
        } catch {
            if let insertedMeasurement {
                modelContext.delete(insertedMeasurement)
            }
            // KEIN `modelContext.rollback()` - das wuerde auch andere, unabhaengige,
            // noch ausstehende Aenderungen im (typischerweise app-weit geteilten)
            // Context verwerfen. Gezielte Feld-Wiederherstellung aus dem Schnappschuss.
            profile.heightCm = originalHeightCm
            profile.goalWeightKg = originalGoalWeightKg
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            isSaving = false
            return
        }
        dismiss()
    }

    /// Task 5: identisches Inline-Fehler-Muster wie `GearListView.gearCard`s
    /// `deleteErrorMessage` — kein neuer Toast/Alert-Mechanismus noetig.
    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.Deltiq.error)
    }
}
#endif
