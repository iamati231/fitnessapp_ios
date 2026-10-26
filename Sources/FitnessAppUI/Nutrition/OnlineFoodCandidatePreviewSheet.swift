#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppFoodLookup

/// Bestaetigte Werte aus `OnlineFoodCandidatePreviewSheet` — der Aufrufer
/// (z. B. `AddMealView.confirmOnlineImport`) mapped sie direkt auf
/// `FoodCatalogEntry(displayName:source:category:...)`.
/// Bewusst NICHT `OnlineFoodCandidate` selbst: Der Nutzer kann die
/// vorbelegten Werte vor dem Bestaetigen aendern.
///
/// **OFF-01 (docs/AUDIT_2026-10-23_DELTIQ.md):** Ein fehlender Naehrwert ist
/// **unbekannt und nicht null**. Open Food Facts ist eine Community-Datenbank,
/// einzelne Makros fehlen dort regelmaessig. Frueher verlangte dieser Typ
/// alle vier Werte — ein Treffer mit einem fehlenden Makro liess sich damit
/// gar nicht uebernehmen (Sackgasse, ohne Begruendung). Jetzt:
/// - Name nicht leer, jeder gesetzte Wert `>= 0`.
/// - Mindestens EIN Naehrwert muss bekannt sein — ein Eintrag ganz ohne
///   Werte traegt keine Information und wird nicht uebernommen.
/// - Fehlende Werte bleiben `nil` und werden als unbekannt gespeichert
///   (`FoodCatalogEntry`/`MealItem` unterscheiden das ueber eine additive
///   Bitzmaske, siehe dort) — **nie** als erfundene 0.
struct OnlineFoodImportValues: Equatable {
    let name: String
    let kcalPer100g: Double?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?

    /// Alle vier Werte bekannt (Normalfall bei manuell angelegten und
    /// vollstaendigen Online-Eintraegen).
    var isComplete: Bool {
        [kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g].allSatisfy { $0 != nil }
    }

    /// `true`, sobald mindestens ein Wert fehlt — die Oberflaeche sagt das
    /// ausdruecklich an (Text + Hinweis, dass die Tagesbilanz dadurch
    /// unvollstaendig ist).
    var hasUnknownValues: Bool { !isComplete }

    /// Die einzige Stelle, die `OnlineFoodImportValues` erzeugt: `nil`, wenn
    /// der Name leer ist, ein gesetzter Wert negativ ist, oder **kein**
    /// Naehrwert bekannt ist. Ein negativer Wert ist ein Eingabefehler, kein
    /// „unbekannt" — sonst wuerde ein Tippfehler stillschweigend zu einer
    /// Luecke.
    init?(name: String, kcalPer100g: Double?, proteinPer100g: Double?, carbsPer100g: Double?, fatPer100g: Double?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let values = [kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g]
        guard values.allSatisfy({ ($0 ?? 0) >= 0 }) else { return nil }
        guard values.contains(where: { $0 != nil }) else { return nil }
        self.name = trimmedName
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
    }
}

/// Task 4/5 reusable component: preview + confirm/cancel for one tapped
/// `OnlineFoodCandidate`, before any `FoodCatalogEntry` is created.
/// Name + Makros/100 g, editierbar, vorbelegt aus dem Treffer; fehlende
/// Felder bleiben LEER (nie „0", damit nichts wie echte Daten aussieht, die
/// Open Food Facts nicht geliefert hat) und sind als unbekannt markiert.
/// Bestaetigen hier beruehrt `ModelContext`/`MealDraft` NICHT — das ist
/// Aufgabe des Aufrufers ueber `onConfirm`, der danach denselben
/// `addItem`-Pfad wie bei einer manuellen Katalogauswahl nutzt.
@available(iOS 17.0, macOS 14.0, *)
struct OnlineFoodCandidatePreviewSheet: View {
    let onConfirm: (OnlineFoodImportValues) -> Void
    let onCancel: () -> Void
    /// OFF-01: Weg aus der Sackgasse — oeffnet das manuelle Anlegen eines
    /// eigenen Lebensmittels, vorausgefuellt mit dem Treffer-Namen. Wird vom
    /// Aufrufer (`AddMealView`) an `showingCustomFoodEntry` gehaengt.
    let onCreateManually: (String) -> Void

    @State private var name: String
    @State private var kcalPer100g: Double?
    @State private var proteinPer100g: Double?
    @State private var carbsPer100g: Double?
    @State private var fatPer100g: Double?

    init(
        candidate: OnlineFoodCandidate,
        onConfirm: @escaping (OnlineFoodImportValues) -> Void,
        onCancel: @escaping () -> Void,
        onCreateManually: @escaping (String) -> Void
    ) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onCreateManually = onCreateManually
        _name = State(initialValue: candidate.name)
        _kcalPer100g = State(initialValue: candidate.kcalPer100g)
        _proteinPer100g = State(initialValue: candidate.proteinPer100g)
        _carbsPer100g = State(initialValue: candidate.carbsPer100g)
        _fatPer100g = State(initialValue: candidate.fatPer100g)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "nutrition.onlineImport.nameLabel", bundle: .module), text: $name)
                }
                Section {
                    macroRow("nutrition.onlineImport.kcalLabel", value: $kcalPer100g, accessibilityKey: "nutrition.onlineImport.kcalLabel")
                    macroRow("nutrition.onlineImport.proteinLabel", value: $proteinPer100g, accessibilityKey: "nutrition.onlineImport.proteinLabel")
                    macroRow("nutrition.onlineImport.carbsLabel", value: $carbsPer100g, accessibilityKey: "nutrition.onlineImport.carbsLabel")
                    macroRow("nutrition.onlineImport.fatLabel", value: $fatPer100g, accessibilityKey: "nutrition.onlineImport.fatLabel")
                } footer: {
                    if pendingValues?.hasUnknownValues == true {
                        // OFF-01: Genaud die Stelle, an der frueher ein
                        // grauer „Hinzufuegen"-Button ohne Begruendung stand.
                        Text("nutrition.onlineImport.incomplete.hint", bundle: .module)
                    }
                }
                Section {
                    Button {
                        onCreateManually(name)
                    } label: {
                        HStack {
                            Text("nutrition.onlineImport.createManually", bundle: .module)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.deltiqOrange)
                }
            }
            .navigationTitle(Text("nutrition.onlineImport.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirm()
                    } label: {
                        Text("common.add", bundle: .module)
                    }
                    // OFF-01: nicht mehr „alle vier Pflicht", sondern „Name
                    // gesetzt, kein negativer Wert, mindestens ein Wert
                    // bekannt" — der Grund fuer eine Sperre steht als Footer
                    // direkt darueber.
                    .disabled(pendingValues == nil)
                }
            }
        }
    }

    /// „70" bzw. „unbekannt" — nie „0", wenn nichts geliefert wurde.
    private func accessibilityValueText(for value: Double?) -> Text {
        if let value { return Text("\(value)") }
        return Text("nutrition.onlineImport.unknown", bundle: .module)
    }

    private func macroRow(_ labelKey: String, value: Binding<Double?>, accessibilityKey: String) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey), bundle: .module)
            Spacer()
            // Leer bei `nil` (fehlender Open-Food-Facts-Wert) statt „0" —
            // globale Vorgabe: niemals einen Naehrwert erfinden. Ein leer
            // gebliebenes Feld wird unbekannt gespeichert, nicht als 0.
            TextField("", value: value, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                // OFF-01: VoiceOver soll den Unterschied zwischen „leer, weil
                // unbekannt" und „0 eingegeben" hoeren.
                .accessibilityLabel(Text(LocalizedStringKey(accessibilityKey), bundle: .module))
                .accessibilityValue(accessibilityValueText(for: value.wrappedValue))
        }
    }

    /// `nil`, solange der Name leer ist, ein Wert negativ ist oder gar kein
    /// Wert bekannt ist — die einzige Quelle fuer den Button-Zustand UND fuer
    /// `confirm()`, damit beide nie auseinanderlaufen koennen.
    private var pendingValues: OnlineFoodImportValues? {
        OnlineFoodImportValues(
            name: name,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g
        )
    }

    private func confirm() {
        guard let values = pendingValues else { return }
        onConfirm(values)
    }
}
#endif
