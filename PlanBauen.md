# Plan bauen

"Plan bauen" ist der 3-Schritte-Assistent, der aus mehreren gewählten
Trainingsarten (z. B. "3 Tage Kettlebell + 2 Tage Laufen") automatisch eine
berechnete Wochenstruktur erzeugt — im Unterschied zum klassischen Weg über
eine feste `ProgramTemplate`.

## Einstiegspunkt

`Sources/FitnessAppUI/Workout/PlansListView.swift`
Plus-Menü der Plan-Liste → `showingPlanBuilder = true` → `.sheet` präsentiert
`PlanBuilderView()`.

## Beteiligte Schichten

Der Assistent ist bewusst in drei Schichten aufgeteilt, damit die eigentliche
Rechenlogik ohne SwiftData/UI testbar bleibt:

```
PlansListView (Plus-Menü)
        │  Sheet
        ▼
PlanBuilderView.swift                 FitnessAppUI
  3-Schritte-Wizard: Trainingsarten → Ausrüstung → Ergebnis
        │  baut PlanGeneratorInput
        ▼
PlanGeneratorInput.swift              FitnessAppCore
  TrainingTypeKind, PlanGeneratorTypeSelection, PlanGeneratorInput
        │
        ▼
PlanGenerator.swift                   FitnessAppCore
  PlanGenerator.generate(from:) -> Result   (reine Funktion, kein SwiftData)
        │  Result.days: [GeneratedDay] (DaySpec + PlanLoadLevel)
        ▼
PlanGeneratorInstantiator.swift       FitnessAppData
  .build(from:in:)       -> neuer aktiver TrainingPlan
  .recalculate(_:in:)    -> "neu rechnen" für bestehenden Plan
```

## Persistenz für "neu rechnen"

- `TrainingPlan.generatorInputRaw: String?` — JSON-Snapshot von
  `PlanGeneratorInput`, ermöglicht spätere Neuberechnung.
- `TrainingDay.generatorSequenceIndex` / `.generationFingerprint` — verknüpfen
  einen erzeugten Tag mit seiner Position im letzten Rechenlauf und markieren,
  ob er seither manuell bearbeitet wurde.
- Additive CSV-Spalte `generator_input_raw` in Export/Import
  (`Sources/FitnessAppData/Export/Data{Export,Import}Service.swift`) sichert
  das für Backup/Restore.

## Lokalisierung

Alle sichtbaren Wizard-Texte über `planBuilder.*`-Keys in
`Sources/FitnessAppUI/Resources/Localizable.xcstrings` (DE/EN/TR).
`PlanGenerator` selbst liegt in `FitnessAppCore` (kein `Bundle.module` dort)
und erzeugt Tages-/Plan-Namen daher als hartcodierte deutsche Strings —
einzige echte Lokalisierung ist `Result.explanationKey`, ein Schlüssel-String,
den die Wizard-UI auflöst.

## Tests

- `Tests/FitnessAppCoreTests/PlanGeneratorTests.swift` — reine
  Generator-Logik (Kandidaten, Verteilung, Namensdisambiguierung, Kettlebell-
  EMOM-Finisher-Cap, ...), kein SwiftData nötig.
- `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift` —
  `build`/`recalculate` inkl. Fingerprint-Schutz und Wochentag-Zuordnung.

---

## Code

### 1. `Sources/FitnessAppUI/Workout/PlanBuilderView.swift`

Die UI selbst. Struktur folgt `OnboardingQuizView` (`NavigationStack`,
Fortschrittsbalken, `switch step`, Zurück/Weiter-Leiste). Schritte
(`BuilderStep`):

1. **`.types`** — Trainingsarten wählen + je Art Tage/Woche, Sessiondauer,
   Erfahrungslevel (`PlanGeneratorTypeSelection`).
2. **`.equipment`** — verfügbare Ausrüstung, optional feste Wochentage.
3. **`.result`** — Vorschau des berechneten `PlanGenerator.Result`, Übernahme
   erzeugt den Plan via `PlanGeneratorInstantiator.build`.

```swift
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// README 2.20 "Plan bauen": 3-Schritte-Assistent, der aus mehreren
/// Trainingsarten (z.B. "3 Tage Kettlebell + 2 Tage Laufen") eine berechnete
/// Wochen-Struktur erzeugt. Shown als Sheet aus `PlansListView`s Plus-Menue,
/// gleiches Muster wie `ProgramTemplatePickerView`: kein Callback-Parameter,
/// `@Environment(\.dismiss)` + `@Environment(AppNavigation.self)` erledigen
/// Sheet-Schluss + Navigation zum neuen Plan selbst.
///
/// Struktur folgt bewusst `OnboardingQuizView` (einziger existierender
/// Multi-Step-Assistent in dieser Codebase): `NavigationStack`, oberer
/// Fortschrittsbalken, `Group { switch step { ... } }`, untere
/// Zurueck/Weiter-Leiste.
@available(iOS 17.0, macOS 14.0, *)
public struct PlanBuilderView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    public init() {}

    enum BuilderStep: Int, CaseIterable {
        case types, equipment, result
    }

    @State private var step: BuilderStep = .types

    // Schritt 1
    @State private var selectedKinds: [TrainingTypeKind] = []
    @State private var configByKind: [TrainingTypeKind: PlanGeneratorTypeSelection] = [:]
    @State private var expandedKind: TrainingTypeKind?

    // Schritt 2
    @State private var equipmentPreferences: Set<Equipment> = []
    @State private var usesFixedWeekdays = false
    @State private var fixedWeekdays: Set<Int> = []

    // Schritt 3
    @State private var result: PlanGenerator.Result?

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider()
                Group {
                    switch step {
                    case .types:     typesStep
                    case .equipment: equipmentStep
                    case .result:    resultStepView
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)
                Divider()
                navigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(Text("planBuilder.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(BuilderStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.deltiqOrange : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Schritt 1: Trainingsarten und Tage

    private var unselectedKinds: [TrainingTypeKind] {
        TrainingTypeKind.allCases.filter { !selectedKinds.contains($0) }
    }

    private var totalSelectedDays: Int {
        configByKind.values.reduce(0) { $0 + $1.daysPerWeek }
    }

    private var typesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("planBuilder.types.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("planBuilder.types.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if totalSelectedDays > 0 {
                    DeltiqContextRow([
                        DeltiqContextItem(pluralizedCount("planBuilder.wizard.unitsCount", count: totalSelectedDays).uppercased(), style: .accent)
                    ])
                }

                ForEach(selectedKinds, id: \.self) { kind in
                    typeCard(kind)
                }

                if !unselectedKinds.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 8) {
                            ForEach(unselectedKinds, id: \.self) { kind in
                                FilterToggleRow(
                                    label: String(localized: kind.localizedName),
                                    isOn: Binding(
                                        get: { false },
                                        set: { newValue in if newValue { selectKind(kind) } }
                                    )
                                )
                                .disabled(!canAddMoreDays)
                                .opacity(canAddMoreDays ? 1.0 : 0.4)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("planBuilder.types.more", bundle: .module)
                            .font(.body.weight(.medium))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func typeCard(_ kind: TrainingTypeKind) -> some View {
        let isExpanded = expandedKind == kind
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                expandedKind = isExpanded ? nil : kind
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: trainingTypeIcon(kind))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.deltiqOrange.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.localizedName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isExpanded, let config = configByKind[kind] {
                            Text(collapsedSummary(for: config))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        removeKind(kind)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let config = configByKind[kind] {
                configControls(kind: kind, config: config)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                        lineWidth: isExpanded ? 1.5 : 1)
        )
    }

    private func configControls(kind: TrainingTypeKind, config: PlanGeneratorTypeSelection) -> some View {
        // README 2.20: Dauern aus Schritt 1 werden nicht verhandelt - aber
        // die SUMME aller Tage/Woche darf 7 nie ueberschreiten, sonst
        // verwirft `ProgramInstantiator.instantiate` ueberzaehlige Tage
        // stillschweigend (Wochentage sind endlich). Deckel gilt pro Karte:
        // 7 minus das, was die ANDEREN Arten bereits belegen.
        let otherDays = totalSelectedDays - config.daysPerWeek
        let maxDaysForThisKind = max(1, 7 - otherDays)

        return VStack(alignment: .leading, spacing: 14) {
            Divider()

            Stepper(
                pluralizedCount("planBuilder.wizard.daysPerWeek", count: config.daysPerWeek),
                value: Binding(
                    get: { config.daysPerWeek },
                    set: { updateConfig(kind, daysPerWeek: $0) }
                ),
                in: 1...maxDaysForThisKind
            )

            Stepper(
                String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), config.sessionDurationMinutes),
                value: Binding(
                    get: { config.sessionDurationMinutes },
                    set: { updateConfig(kind, sessionDurationMinutes: $0) }
                ),
                in: 15...120,
                step: 5
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("planBuilder.wizard.experience", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "",
                    selection: Binding(
                        get: { config.experience },
                        set: { updateConfig(kind, experience: $0) }
                    )
                ) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func collapsedSummary(for config: PlanGeneratorTypeSelection) -> String {
        let days = pluralizedCount("planBuilder.wizard.daysPerWeek", count: config.daysPerWeek)
        let minutes = String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), config.sessionDurationMinutes)
        let experience = String(localized: config.experience.localizedName)
        return [days, minutes, experience].joined(separator: " · ")
    }

    /// `configControls`s Deckel greift nur, wenn eine BEREITS ausgewaehlte
    /// Karte aufgeklappt und ihr eigener Stepper bewegt wird. Ohne diesen
    /// zweiten Check koennte `selectKind` selbst die Summe ueber 7 treiben
    /// (jede neu hinzugefuegte Art bekommt via `max(1, ...)` mindestens
    /// einen Tag, auch wenn schon alle 7 Wochentage vergeben sind) - mit
    /// genau der stillen Truncation, vor der `configControls` warnt.
    private var canAddMoreDays: Bool { totalSelectedDays < 7 }

    private func selectKind(_ kind: TrainingTypeKind) {
        guard !selectedKinds.contains(kind), canAddMoreDays else { return }
        selectedKinds.append(kind)
        // README 2.20 Beispiel: "3 Tage Kettlebell, 45 Min." - gleiche Zahlen
        // als sinnvoller Startwert fuer jede neu hinzugefuegte Art. `guard`
        // oben garantiert bereits totalSelectedDays < 7, also ist
        // 7 - totalSelectedDays hier immer >= 1.
        configByKind[kind] = PlanGeneratorTypeSelection(
            kind: kind,
            daysPerWeek: min(3, 7 - totalSelectedDays),
            sessionDurationMinutes: 45,
            experience: .intermediate
        )
        expandedKind = kind
    }

    private func removeKind(_ kind: TrainingTypeKind) {
        selectedKinds.removeAll { $0 == kind }
        configByKind[kind] = nil
        if expandedKind == kind { expandedKind = nil }
    }

    private func updateConfig(
        _ kind: TrainingTypeKind,
        daysPerWeek: Int? = nil,
        sessionDurationMinutes: Int? = nil,
        experience: DifficultyLevel? = nil
    ) {
        guard let current = configByKind[kind] else { return }
        configByKind[kind] = PlanGeneratorTypeSelection(
            kind: kind,
            daysPerWeek: daysPerWeek ?? current.daysPerWeek,
            sessionDurationMinutes: sessionDurationMinutes ?? current.sessionDurationMinutes,
            experience: experience ?? current.experience
        )
    }

    private func trainingTypeIcon(_ kind: TrainingTypeKind) -> String {
        switch kind {
        case .barbell:    return "figure.strengthtraining.traditional"
        case .dumbbell:   return "dumbbell"
        case .kettlebell: return "figure.strengthtraining.functional"
        case .bodyweight: return "figure.core.training"
        case .running:    return "figure.run"
        case .cycling:    return "bicycle"
        }
    }

    // MARK: - Schritt 2: Ausruestung und Rhythmus

    private var equipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.equipment.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("planBuilder.equipment.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
                        ForEach(Equipment.allCases, id: \.self) { equip in
                            FilterToggleRow(
                                label: String(localized: equip.localizedName),
                                isOn: Binding(
                                    get: { equipmentPreferences.contains(equip) },
                                    set: { newValue in
                                        if newValue { equipmentPreferences.insert(equip) }
                                        else        { equipmentPreferences.remove(equip) }
                                    }
                                )
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("planBuilder.rhythm.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("planBuilder.rhythm.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Picker("", selection: $usesFixedWeekdays) {
                        Text("planBuilder.rhythm.orderOnly", bundle: .module).tag(false)
                        Text("planBuilder.rhythm.fixedWeekdays", bundle: .module).tag(true)
                    }
                    .pickerStyle(.segmented)

                    // README 2.20 (29b): die Tagesauswahl steht sichtbar
                    // daneben statt hinter einer Einstellung versteckt zu
                    // sein - deshalb kein zusaetzliches Sheet, sondern
                    // inline sichtbar sobald "Feste Wochentage" gewaehlt ist.
                    if usesFixedWeekdays {
                        weekdayGrid
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Gleiches Muster wie `DayPickerSheet.dayGrid`/`dayRow` - Apple-Calendar-
    /// Wochentage (1=So...7=Sa), Mo-first angezeigt, Cap bei
    /// `totalSelectedDays`.
    private var weekdayGrid: some View {
        let calendar = Calendar.current
        let fullSymbols = calendar.standaloneWeekdaySymbols
        let shortSymbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdayLabels: [(weekday: Int, label: String, short: String)] = [2, 3, 4, 5, 6, 7, 1].map { wd in
            (weekday: wd, label: fullSymbols[wd - 1], short: shortSymbols[wd - 1])
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "dayPicker.prompt", bundle: .module), totalSelectedDays))
                .font(.caption)
                .foregroundStyle(fixedWeekdays.count == totalSelectedDays ? Color.deltiqOrange : Color.Deltiq.textSecondary)
            ForEach(weekdayLabels, id: \.weekday) { entry in
                weekdayRow(weekday: entry.weekday, label: entry.label, short: entry.short)
            }
        }
    }

    private func weekdayRow(weekday: Int, label: String, short: String) -> some View {
        let isSelected = fixedWeekdays.contains(weekday)
        let atCap = !isSelected && fixedWeekdays.count >= totalSelectedDays
        return Button {
            toggleWeekday(weekday)
        } label: {
            HStack(spacing: 12) {
                Text(short)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? Color.deltiqOrange : Color.Deltiq.fill))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.deltiqOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.deltiqOrange : Color.Deltiq.divider, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(atCap)
        .opacity(atCap ? 0.4 : 1.0)
    }

    private func toggleWeekday(_ weekday: Int) {
        if fixedWeekdays.contains(weekday) {
            fixedWeekdays.remove(weekday)
        } else {
            guard fixedWeekdays.count < totalSelectedDays else { return }
            fixedWeekdays.insert(weekday)
        }
    }

    // MARK: - Schritt 3: die gerechnete Woche

    private var currentInput: PlanGeneratorInput {
        PlanGeneratorInput(
            selections: selectedKinds.compactMap { configByKind[$0] },
            equipmentPreferences: equipmentPreferences,
            usesFixedWeekdays: usesFixedWeekdays,
            fixedWeekdays: Array(fixedWeekdays)
        )
    }

    private func recalculatePreview() {
        result = PlanGenerator.generate(from: currentInput)
    }

    private var resultStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let result, !result.days.isEmpty {
                    if let key = result.explanationKey {
                        Text(String(localized: String.LocalizationValue(key), bundle: .module))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(Color.deltiqOrange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    ForEach(Array(result.days.enumerated()), id: \.offset) { _, day in
                        resultDayRow(day)
                    }

                    Text(String(format: String(localized: "planBuilder.result.weeklyTotal", bundle: .module), weeklyTotalTimeLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        recalculatePreview()
                    } label: {
                        Label {
                            Text("planBuilder.result.recalculate", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    ContentUnavailableViewCompat(
                        title: String(localized: "planBuilder.result.empty.title", bundle: .module),
                        message: String(localized: "planBuilder.result.empty.message", bundle: .module)
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            if result == nil { recalculatePreview() }
        }
    }

    private func resultDayRow(_ day: PlanGenerator.Result.GeneratedDay) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.spec.name)
                    .font(.body.weight(.semibold))
                Text(scopeLine(for: day.spec))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(day.loadLevel.localizedName)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(loadLevelColor(day.loadLevel).opacity(0.16))
                .foregroundStyle(loadLevelColor(day.loadLevel))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadLevelColor(_ level: PlanLoadLevel) -> Color {
        switch level {
        case .easy:   return .green
        case .medium: return Color.deltiqOrange
        // README 2.21: System-`.orange` (#FF9500) lag fast auf `deltiqOrange`
        // (#FF9F0A) - vier Stufen, aber nur drei unterscheidbare Farben.
        // Eigener, deutlich dunklerer Brand-Ton statt System-Orange.
        case .hard:   return Color(red: 0.80, green: 0.35, blue: 0.05)
        case .tough:  return .red
        }
    }

    private func scopeLine(for spec: DaySpec) -> String {
        if let timeFormat = spec.timeFormat {
            let capText = spec.timeCapMinutes.map { String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), $0) } ?? ""
            return [timedFormatDisplayName(timeFormat), capText].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        if spec.exercises.count == 1, let exercise = spec.exercises.first, exercise.isCardio {
            if let duration = exercise.targetDurationMinutes {
                return String(format: String(localized: "planBuilder.wizard.minutesValue", bundle: .module), duration)
            }
            if let distance = exercise.targetDistanceKm {
                // README 2.21: "%.1f km" ohne Locale ("0.4 km" statt "0,4 km"
                // auf Deutsch) - gleiche Bug-Familie wie der RIR-Punkt aus
                // 2.18, fuenfte Fundstelle. `formattedOneDecimal` (locale-
                // aware) plus reiner Einheiten-String statt `String(format:)`.
                return "\(distance.formattedOneDecimal) km"
            }
        }
        return pluralizedCount("planBuilder.wizard.exerciseCount", count: spec.exercises.count)
    }

    private var weeklyTotalTimeLabel: String {
        let totalMinutes = selectedKinds.reduce(0) { sum, kind in
            guard let config = configByKind[kind] else { return sum }
            return sum + config.daysPerWeek * config.sessionDurationMinutes
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%lld:%02lld", hours, minutes)
    }

    // MARK: - Navigation

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step != .types {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("common.back", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if step == .result {
                Button {
                    adoptPlan()
                } label: {
                    Label {
                        Text("planBuilder.result.adopt", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(result?.days.isEmpty ?? true)
            } else {
                Button {
                    goToNextStep()
                } label: {
                    Label {
                        Text("planBuilder.nav.next", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .types && selectedKinds.isEmpty)
            }
        }
    }

    private func goToNextStep() {
        guard let next = BuilderStep(rawValue: step.rawValue + 1) else { return }
        if next == .result { recalculatePreview() }
        step = next
    }

    private func goToPreviousStep() {
        guard let prev = BuilderStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    private func adoptPlan() {
        guard let plan = PlanGeneratorInstantiator.build(from: currentInput, in: modelContext) else { return }
        dismiss()
        // Gleiches 0.3s-Defer-Muster wie `ProgramTemplatePickerView.instantiate`
        // - gibt der Sheet-Dismiss-Animation Zeit, bevor der Navigations-Stack
        // mutiert (sonst race zwischen dismiss + navigationDestination).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigation.workoutPath.append(plan)
        }
    }

    /// Gleiches manuelles .one/.other-Muster wie `PlansListView.pluralizedCount`.
    private func pluralizedCount(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }
}

/// Minimaler Ersatz fuer `ContentUnavailableView` (iOS 17+, aber ohne
/// SF-Symbol-Icon-Parameter-Komplexitaet) - README 2.20 Randfall, wenn der
/// Generator fuer eine Auswahl NICHTS in der Bibliothek findet (z.B.
/// Ausruestung/Schwierigkeit-Kombination ohne jeden Treffer).
@available(iOS 17.0, macOS 14.0, *)
private struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
#endif
```

### 2. `Sources/FitnessAppCore/Programs/PlanGeneratorInput.swift`

Reine Eingabe-Typen (kein SwiftData, `Codable` für die spätere Persistierung
als JSON): `TrainingTypeKind` (die 6 Wizard-Trainingsarten), eine Zeile aus
Schritt 1 (`PlanGeneratorTypeSelection`) und die gesammelten Antworten aus
Schritt 1+2 (`PlanGeneratorInput`).

```swift
import Foundation

/// README 2.20: "Trainingsart" fuer den Plan-Generator ("Plan bauen"). Kein
/// Feld in der Uebungsbibliothek - eine reine Wizard-Vokabel, die der
/// Generator auf Filterkriterien abbildet: die vier Kraft-Kinds mappen 1:1
/// auf `Equipment`-Faelle, die zwei Cardio-Kinds haben keine Entsprechung
/// in der Library (siehe `PlanGenerator.cardioCandidates`, das ueber
/// `isCardio` + Lauf-Zonen-Namen statt Equipment filtert).
public enum TrainingTypeKind: String, Codable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case kettlebell
    case bodyweight
    case running
    case cycling

    public var isCardio: Bool {
        self == .running || self == .cycling
    }

    /// `nil` fuer die beiden Cardio-Kinds - dort filtert der Generator
    /// stattdessen ueber `isCardio` + Namens-Zugehoerigkeit.
    public var equipmentFilter: Equipment? {
        switch self {
        case .barbell:    return .barbell
        case .dumbbell:   return .dumbbell
        case .kettlebell: return .kettlebell
        case .bodyweight: return .bodyweight
        case .running, .cycling: return nil
        }
    }

    /// Lokalisierungs-KEY fuer die Schritt-1-Auswahlzeile (nicht aufgeloester
    /// Text - `FitnessAppCore` hat kein `Bundle.module`, siehe
    /// `PlanGenerator`-Datei-Kommentar). Die Wizard-UI in FitnessAppUI loest
    /// das via `String(localized: String.LocalizationValue(kind.titleKey), bundle: .module)`
    /// auf. Getrennt von `PlanGenerator`s internen, hartcodiert-deutschen
    /// Tages-Titel-Woertern (`germanTypeLabel`) - dort geht es um bereits
    /// erzeugte Plan-Inhalte (System-Name-Konvention), hier um die
    /// UI-Auswahlliste selbst (soll wie jede andere Auswahlliste EN/TR
    /// zeigen).
    public var titleKey: String {
        switch self {
        case .barbell:    return "planBuilder.type.barbell"
        case .dumbbell:   return "planBuilder.type.dumbbell"
        case .kettlebell: return "planBuilder.type.kettlebell"
        case .bodyweight: return "planBuilder.type.bodyweight"
        case .running:    return "planBuilder.type.running"
        case .cycling:    return "planBuilder.type.cycling"
        }
    }
}

/// README 2.20: eine Trainingsart-Auswahl aus Schritt 1 des Assistenten -
/// "3 Tage Kettlebell, 45 Min., Geuebt".
public struct PlanGeneratorTypeSelection: Codable, Sendable, Hashable {
    public let kind: TrainingTypeKind
    public let daysPerWeek: Int
    public let sessionDurationMinutes: Int
    public let experience: DifficultyLevel

    public init(
        kind: TrainingTypeKind,
        daysPerWeek: Int,
        sessionDurationMinutes: Int,
        experience: DifficultyLevel
    ) {
        self.kind = kind
        self.daysPerWeek = daysPerWeek
        self.sessionDurationMinutes = sessionDurationMinutes
        self.experience = experience
    }
}

/// README 2.20: gesammelte Antworten aus Schritt 1+2 des "Plan bauen"-
/// Assistenten. Wird als JSON auf `TrainingPlan.generatorInputRaw`
/// gespeichert, damit "neu rechnen" spaeter weiss, wonach gerechnet wurde -
/// gleiches Prinzip wie die `*Snapshot`-Felder auf `WorkoutSession`/
/// `ExerciseLog` (JSON statt Struct-Relationship, weil SwiftData keine
/// Codable-Structs direkt als Attribut speichert).
public struct PlanGeneratorInput: Codable, Sendable, Hashable {
    public let selections: [PlanGeneratorTypeSelection]
    public let equipmentPreferences: Set<Equipment>
    public let usesFixedWeekdays: Bool
    /// Nur relevant wenn `usesFixedWeekdays == true`. Apple-Calendar-Schema
    /// (1 = Sonntag ... 7 = Samstag), gleiche Konvention wie
    /// `ProgramInstantiator.instantiate(selectedWeekdays:)`.
    public let fixedWeekdays: [Int]

    public init(
        selections: [PlanGeneratorTypeSelection],
        equipmentPreferences: Set<Equipment>,
        usesFixedWeekdays: Bool,
        fixedWeekdays: [Int] = []
    ) {
        self.selections = selections
        self.equipmentPreferences = equipmentPreferences
        self.usesFixedWeekdays = usesFixedWeekdays
        self.fixedWeekdays = fixedWeekdays
    }

    public var totalDaysPerWeek: Int {
        selections.reduce(0) { $0 + $1.daysPerWeek }
    }
}
```

### 3. `Sources/FitnessAppCore/Programs/PlanGenerator.swift`

Die eigentliche Rechenlogik, `PlanGenerator.generate(from:) -> Result`:
sammelt pro gewählter Trainingsart Kandidaten-Tage (`strengthCandidates`/
`cardioCandidates`), dedupliziert Namensdopplungen, verteilt sie nach
geschätzter Belastung über die Woche (`spreadByHardness`) und ordnet jedem
Tag ein relatives `PlanLoadLevel` (locker/mittel/schwer/hart) zu. Läuft
bewusst ohne SwiftData — dieselbe reine-Funktion-Philosophie wie
`PlanMatchmaker`.

```swift
import Foundation

/// README 2.20 "Plan bauen": rechnet aus mehreren Trainingsarten eine
/// Wochen-Struktur, statt sie aus einer festen `ProgramTemplate` zu
/// schneiden. Lebt bewusst in Core (kein SwiftData) - gleiches Prinzip wie
/// `PlanMatchmaker`: reine, ueberall testbare Logik, die erst am Ende
/// `[DaySpec]` ausgibt und von `ProgramInstantiator` materialisiert wird.
///
/// **Bewusste v1-Vereinfachung:** die Belastungs-Schaetzung orientiert sich
/// an denselben DEL-098-Faktoren, die `DayAnalyzer` fuer fertige Tage
/// verwendet, ist aber eine eigene, einfachere Rechnung - `DayAnalyzer`
/// selbst arbeitet auf persistierten `Exercise`-Objekten (SwiftData) und
/// laesst sich nicht ohne Weiteres auf noch nicht existierende Kandidaten-
/// Tage anwenden. Ziel hier ist "hart vs. leicht grob richtig einordnen",
/// nicht numerische Parität mit `DayAnalyzer`.
///
/// **`ExerciseSpec.name`-Werte sind bewusst die exakten Library-Strings**
/// ("Easy Run", "Intervalle", ...), keine eigenen Erfindungen - nur so
/// findet `ProgramInstantiator`s namensbasierter Library-Abgleich die
/// bereits getunten DEL-098-Faktoren wieder (sonst landen generische
/// Isolations-Defaults im Plan, siehe `ProgramInstantiator.swift`).
///
/// **Keine Lokalisierung in diesem Typ:** `FitnessAppCore` deklariert in
/// `Package.swift` keine `resources:` - es gibt hier gar kein
/// `Bundle.module`, jeder `String(localized:bundle: .module)`-Aufruf waere
/// ein Compile-Fehler. Erzeugte Tages-/Plan-Namen sind deshalb bewusst
/// hartcodierte deutsche Strings, exakt die gleiche Konvention wie jede
/// `DaySpec(name: "Push A", ...)` in `ProgramTemplates.swift` - Anzeige in
/// EN/TR faellt fuer generierte Tage auf diesen deutschen String zurueck
/// (kein `localizationKey`, da der Name dynamisch aus mehreren Teilen
/// zusammengesetzt ist, nicht ein fixer Katalog-Eintrag). Die einzige
/// echte Lokalisierung ist `Result.explanationKey` - eine KEY-STRING, die
/// FitnessAppUI (wo `.module` existiert) aufloest. Fuer Schritt-1 der
/// Wizard-UI (Trainingsart-AUSWAHL) siehe stattdessen
/// `TrainingTypeKind.titleKey` in `PlanGeneratorInput.swift`.
public enum PlanGenerator {

    public struct Result: Sendable {
        /// Ein platzierter Tag samt seiner Belastungs-Einordnung fuer die
        /// Step-3-Kapsel. `loadLevel` ist bewusst RELATIV zu dieser einen
        /// generierten Woche (siehe `loadLevels(for:)`) - Kraft- und Cardio-
        /// Haerte sind unterschiedlich skaliert (Kraft summiert ueber alle
        /// Uebungen eines Tages, Cardio ueber die Zonen-Basiswerte) und waeren
        /// als universeller Absolutwert nicht sinnvoll vergleichbar. Das
        /// passt zum README-2.20-Wortlaut: "die Belastung wird verteilt und
        /// die Verteilung erklaert" - es geht um die Position in DIESER
        /// Woche, nicht um einen App-weiten Massstab.
        public struct GeneratedDay: Sendable {
            public let spec: DaySpec
            public let loadLevel: PlanLoadLevel
        }
        public let days: [GeneratedDay]
        /// Lokalisierungs-KEY (nicht aufgeloester Text!) fuer den einen Satz,
        /// der die nicht-triviale Umordnungs-Entscheidung erklaert - `nil`
        /// wenn die Reihenfolge trivial ist (z.B. nur eine Trainingsart
        /// gewaehlt). Core kann den Key nicht selbst aufloesen (kein
        /// `Bundle.module` hier) - der Aufrufer (Wizard-UI in FitnessAppUI)
        /// macht `String(localized: String.LocalizationValue(key), bundle: .module)`.
        public let explanationKey: String?
    }

    /// Ein noch nicht platzierter, aber inhaltlich fertiger Tag samt
    /// geschaetzter Belastung fuer die Reihenfolge-Regel.
    private struct Candidate {
        var name: String
        let exercises: [ExerciseSpec]
        let timeFormat: WorkoutTimeFormat?
        let timeCapMinutes: Int?
        let hardness: Double
    }

    public static func generate(from input: PlanGeneratorInput) -> Result {
        var candidates: [Candidate] = []
        for selection in input.selections {
            if selection.kind.isCardio {
                candidates.append(contentsOf: cardioCandidates(for: selection))
            } else {
                candidates.append(contentsOf: strengthCandidates(for: selection))
            }
        }

        guard !candidates.isEmpty else {
            return Result(days: [], explanationKey: nil)
        }

        let ordered = spreadByHardness(candidates)
        let levels = loadLevels(for: ordered.map(\.hardness))
        let days = ordered.enumerated().map { index, candidate in
            Result.GeneratedDay(
                spec: DaySpec(
                    name: candidate.name,
                    type: .fullBody,
                    sequenceIndex: index + 1,
                    exercises: candidate.exercises,
                    timeFormat: candidate.timeFormat,
                    timeCapMinutes: candidate.timeCapMinutes
                ),
                loadLevel: levels[index]
            )
        }

        let explanationKey = input.selections.count > 1 && ordered.count > 2
            ? "planBuilder.result.explanation.spread"
            : nil

        return Result(days: days, explanationKey: explanationKey)
    }

    // MARK: - Strength candidates

    private static func strengthCandidates(for selection: PlanGeneratorTypeSelection) -> [Candidate] {
        guard let equipment = selection.kind.equipmentFilter else { return [] }
        let allowedDifficulties = difficultiesAtOrBelow(selection.experience)
        let pool = ExerciseLibraryData.all.filter {
            $0.equipment == equipment && !$0.isCardio && allowedDifficulties.contains($0.difficultyLevel)
        }
        guard !pool.isEmpty else { return [] }

        let byMuscle = Dictionary(grouping: pool, by: \.primaryMuscle)
        let muscleOrder = MuscleGroup.allCases
        let exerciseCount = max(3, min(7, selection.sessionDurationMinutes / 7))
        let (sets, repsMin, repsMax, restSeconds) = strengthVolume(for: selection.experience)
        let kindLabel = germanTypeLabel(selection.kind)

        var result: [Candidate] = []
        for dayIndex in 0..<selection.daysPerWeek {
            // README 2.20: letzter Tag einer >=3-taegigen Kettlebell-Auswahl
            // wird zum EMOM-Finisher - passt zum bereits gebauten CrossFit/
            // Kettlebell-Vorlagen-Stil (README 2.9) statt jede Trainingsart
            // gleich zu behandeln.
            if selection.kind == .kettlebell, selection.daysPerWeek >= 3, dayIndex == selection.daysPerWeek - 1 {
                result.append(kettlebellEmomCandidate(
                    pool: pool, muscleOrder: muscleOrder, kindLabel: kindLabel,
                    sessionDurationMinutes: selection.sessionDurationMinutes
                ))
                continue
            }

            var exercises: [ExerciseSpec] = []
            var pickedMuscles: [MuscleGroup] = []
            var hardness = 0.0
            var muscleCursor = dayIndex
            var guardCount = 0
            while exercises.count < exerciseCount, guardCount < muscleOrder.count * 3 {
                defer { guardCount += 1 }
                let muscle = muscleOrder[muscleCursor % muscleOrder.count]
                muscleCursor += 1
                guard let group = byMuscle[muscle], !group.isEmpty else { continue }
                let spec = group[dayIndex % group.count]
                if exercises.contains(where: { $0.name == spec.name }) { continue }
                exercises.append(ExerciseSpec(
                    name: spec.name,
                    sets: sets,
                    repsMin: repsMin,
                    repsMax: repsMax,
                    restSeconds: restSeconds
                ))
                pickedMuscles.append(muscle)
                hardness += strengthHardness(spec, sets: sets, experience: selection.experience)
            }

            result.append(Candidate(
                name: "\(kindLabel) · \(muscleFocusLabel(pickedMuscles, dayIndex: dayIndex))",
                exercises: exercises,
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: hardness
            ))
        }
        disambiguateDuplicateNames(&result)
        return result
    }

    /// README 2.21: bei mehreren Tagen derselben Trainingsart kann
    /// `muscleFocusLabel` denselben Titel liefern, obwohl sich die Uebungen
    /// unterscheiden - mit dem Kettlebell-Pool z.B. an zwei Tagen je "Push &
    /// Pull" (`group[dayIndex % group.count]` waehlt andere Uebungen, aber
    /// dieselben ERSTEN ZWEI Muskel-Kategorien). Haengt bei einer Kollision
    /// den Tages-Buchstaben an, exakt wie `ProgramTemplates` es mit
    /// "Ganzkoerper A"/"Ganzkoerper B" tut.
    private static func disambiguateDuplicateNames(_ candidates: inout [Candidate]) {
        var totalCounts: [String: Int] = [:]
        for candidate in candidates {
            totalCounts[candidate.name, default: 0] += 1
        }
        var nextLetterIndex: [String: Int] = [:]
        for index in candidates.indices {
            let baseName = candidates[index].name
            guard totalCounts[baseName, default: 0] > 1 else { continue }
            let letterIndex = nextLetterIndex[baseName, default: 0]
            nextLetterIndex[baseName] = letterIndex + 1
            candidates[index].name = "\(baseName) \(disambiguationSuffix(for: letterIndex))"
        }
    }

    /// A, B, C, ... Z, dann 27, 28, ... - kein Aufrufer erreicht heute mehr
    /// als 6 Duplikate desselben Namens (UI-Cap: max. 7 Tage/Woche insgesamt,
    /// siehe Audit-Notiz), aber `UInt8(65 + index)` wuerde ab Index 26
    /// entweder Muell-Zeichen liefern oder ueberlaufen und trapen - diese
    /// Grenze gehoert in die oeffentliche Core-API, nicht nur in die UI.
    private static func disambiguationSuffix(for index: Int) -> String {
        guard index < 26 else { return "\(index + 1)" }
        return String(UnicodeScalar(UInt8(65 + index)))
    }

    /// EMOM-Ganzkoerper-Finisher aus dem gleichen gefilterten Pool - vier
    /// Uebungen, je eine Minute. Deckel skaliert mit der vom User gewaehlten
    /// Session-Dauer (Bugfix, Audit - vorher fix 20 Minuten, ignorierte die
    /// Eingabe komplett), auf einen sinnvollen EMOM-Bereich geklemmt: unter
    /// 10 Minuten lohnt sich die Rotation kaum, ueber 30 waere ein
    /// "Finisher" kein Finisher mehr.
    private static func kettlebellEmomCandidate(
        pool: [ExerciseTemplateSpec],
        muscleOrder: [MuscleGroup],
        kindLabel: String,
        sessionDurationMinutes: Int
    ) -> Candidate {
        let byMuscle = Dictionary(grouping: pool, by: \.primaryMuscle)
        var exercises: [ExerciseSpec] = []
        var hardness = 0.0
        var muscleCursor = 0
        var guardCount = 0
        while exercises.count < 4, guardCount < muscleOrder.count * 2 {
            defer { guardCount += 1 }
            let muscle = muscleOrder[muscleCursor % muscleOrder.count]
            muscleCursor += 1
            guard let group = byMuscle[muscle], let spec = group.first else { continue }
            if exercises.contains(where: { $0.name == spec.name }) { continue }
            exercises.append(ExerciseSpec(name: spec.name, sets: 1, repsMin: 12, repsMax: 12))
            hardness += strengthHardness(spec, sets: 3, experience: .intermediate)
        }
        return Candidate(
            name: "\(kindLabel) · \(fullBodyGermanLabel)",
            exercises: exercises,
            timeFormat: .emom,
            timeCapMinutes: min(30, max(10, sessionDurationMinutes)),
            // README 2.18/DayAnalyzer-Konvention: EMOM wird gegenueber
            // reinen Kraft-Score-Punkten eine Stufe milder eingeordnet
            // (die Pause steckt in der Minute) - hier grob mit 0.85 nachgebildet.
            hardness: hardness * 0.85
        )
    }

    private static func strengthHardness(
        _ spec: ExerciseTemplateSpec,
        sets: Int,
        experience: DifficultyLevel
    ) -> Double {
        let intensity: Double
        switch experience {
        case .beginner:     intensity = 0.9
        case .intermediate: intensity = 1.0
        case .advanced:     intensity = 1.1
        }
        let perSet = spec.systemicFatigueFactor * 0.5 + spec.cnsDemandFactor * 0.3 + spec.axialLoadFactor * 0.2
        return Double(sets) * perSet * intensity * 10.0
    }

    private static func strengthVolume(for experience: DifficultyLevel) -> (sets: Int, repsMin: Int, repsMax: Int, restSeconds: Int) {
        switch experience {
        case .beginner:     return (3, 10, 12, 90)
        case .intermediate: return (3, 8, 12, 90)
        case .advanced:     return (4, 6, 10, 100)
        }
    }

    private static func difficultiesAtOrBelow(_ level: DifficultyLevel) -> Set<DifficultyLevel> {
        switch level {
        case .beginner:     return [.beginner]
        case .intermediate: return [.beginner, .intermediate]
        case .advanced:     return [.beginner, .intermediate, .advanced]
        }
    }

    /// Deutsches Anker-Wort fuer die Tages-Titel-Komposition - siehe
    /// Datei-Kommentar oben ("Keine Lokalisierung in diesem Typ"). Fuer die
    /// Wizard-Auswahl-Labels in Schritt 1 siehe stattdessen
    /// `TrainingTypeKind.titleKey` (`PlanGeneratorInput.swift`), das
    /// FitnessAppUI aufloest. "Koerpergewicht" statt "Eigengewicht", damit
    /// generierte Tages-Titel exakt denselben Begriff wie der
    /// Equipment-Picker verwenden (`equipment.bodyweight`s DE-Wert).
    private static func germanTypeLabel(_ kind: TrainingTypeKind) -> String {
        switch kind {
        case .barbell:    return "Langhantel"
        case .dumbbell:   return "Kurzhantel"
        case .kettlebell: return "Kettlebell"
        case .bodyweight: return "Körpergewicht"
        case .running:    return "Laufen"
        case .cycling:    return "Radfahren"
        }
    }

    /// Hartcodiertes "Ganzkörper" fuer die Tages-Titel-Komposition - exakt
    /// die gleiche Schreibweise wie jede `DaySpec(name: "Ganzkörper A", ...)`
    /// in `ProgramTemplates.swift`.
    private static let fullBodyGermanLabel = "Ganzkörper"

    /// Grobe, kurze Muskel-Kategorie fuer den Tages-Titel ("Kettlebell ·
    /// Beine & Core") - keine Praezisions-Klassifikation, nur Kosmetik.
    /// "Push"/"Pull"/"Core" sind im Deutschen dieser App bereits etablierte
    /// Gym-Fachbegriffe (siehe z.B. `DaySpec(name: "Push & Core", ...)` in
    /// `ProgramTemplates.swift` und den DE-Wert von `muscle.core`).
    private static func muscleCategoryGermanLabel(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest, .shoulders, .triceps: return "Push"
        case .back, .biceps:               return "Pull"
        case .quads, .hamstrings, .glutes, .calves: return "Beine"
        case .core:                        return "Core"
        }
    }

    /// Erste zwei UNTERSCHIEDLICHEN Muskel-Kategorien aus den tatsaechlich
    /// gewaehlten Uebungen, in Auftrittsreihenfolge. Faellt auf
    /// "Ganzkoerper" zurueck, wenn nichts Eindeutiges herauskommt (leerer
    /// Tag oder mehr als zwei Kategorien gleichmaessig vertreten).
    private static func muscleFocusLabel(_ muscles: [MuscleGroup], dayIndex: Int) -> String {
        var seen: [String] = []
        for muscle in muscles {
            let label = muscleCategoryGermanLabel(muscle)
            if !seen.contains(label) { seen.append(label) }
            if seen.count == 2 { break }
        }
        guard !seen.isEmpty else {
            return "\(fullBodyGermanLabel) \(dayIndex + 1)"
        }
        return seen.joined(separator: " & ")
    }

    // MARK: - Cardio candidates

    /// README 2.20: "der erste Baustein, der wirklich fehlt" - eine
    /// Typologie fuer Lauf-Einheiten. Bewusst nur intern in diesem
    /// Generator, keine neuen Felder auf `ExerciseSpec`/`Exercise`: eine
    /// Zone entscheidet lediglich Tages-Titel, welche existierende
    /// Library-Uebung ("Easy Run"/"Long Run"/"Intervalle") gewaehlt wird,
    /// Ziel-Dauer und Haerte zum Erzeugungs-Zeitpunkt - sie muss danach
    /// nirgendwo mehr gelesen werden. "Long Run" steht fuer die Tempo-
    /// Zone ein: die Library hat keine eigene Tempo-Lauf-Uebung, aber
    /// "Long Run"s DEL-098-Faktoren (0.70/0.35 systemisch/CNS) liegen
    /// bereits sinnvoll zwischen "Easy Run" (0.50/0.25) und "Intervalle"
    /// (0.75/0.55).
    private enum RunZone {
        case easy, tempo, interval

        var exerciseName: String {
            switch self {
            case .easy:     return "Easy Run"
            case .tempo:    return "Long Run"
            case .interval: return "Intervalle"
            }
        }

        /// Deutsches Anker-Wort fuer den Tages-Titel - README 2.20 benutzt
        /// selbst schon "ruhig / Tempo / Intervall" fuer die drei Zonen.
        var germanLabel: String {
            switch self {
            case .easy:     return "Ruhiger Lauf"
            case .tempo:    return "Tempolauf"
            case .interval: return "Intervalle"
            }
        }

        var baseHardness: Double {
            switch self {
            case .easy:     return 15
            case .tempo:    return 30
            case .interval: return 45
            }
        }
    }

    private static func cardioCandidates(for selection: PlanGeneratorTypeSelection) -> [Candidate] {
        let durationFactor = Double(selection.sessionDurationMinutes) / 30.0

        guard selection.kind == .running else {
            // Radfahren: das Dokument beschreibt die fehlende Typologie
            // explizit nur fuers Laufen - Radfahren bleibt bewusst eine
            // einzelne, gleichfoermige Cardio-Einheit ohne Zonen. Die
            // TITEL muessen trotzdem eindeutig sein (Bugfix, Audit) - sonst
            // stehen z.B. 3 identisch "Radfahren" benannte Tage
            // ununterscheidbar in der Plan-Uebersicht.
            let title = germanTypeLabel(.cycling)
            var result = (0..<selection.daysPerWeek).map { _ in
                Candidate(
                    name: title,
                    exercises: [ExerciseSpec(
                        name: "Radfahren (outdoor)",
                        sets: 1, repsMin: 0, repsMax: 0,
                        isCardio: true,
                        targetDurationMinutes: selection.sessionDurationMinutes
                    )],
                    timeFormat: nil,
                    timeCapMinutes: nil,
                    hardness: 20 * durationFactor
                )
            }
            disambiguateDuplicateNames(&result)
            return result
        }

        // README 2.18/2.20: Reihenfolge so gewaehlt, dass bei genau zwei
        // Tagen niemals zwei harte Einheiten (Tempo/Intervall) zusammen
        // herauskommen - "ruhig" deckt die Luecke.
        let cycle: [RunZone] = [.easy, .interval, .tempo]

        var result = (0..<selection.daysPerWeek).map { dayIndex in
            let zone = cycle[dayIndex % cycle.count]
            let title = zone.germanLabel
            let exercise: ExerciseSpec
            switch zone {
            case .interval:
                exercise = ExerciseSpec(
                    name: zone.exerciseName,
                    sets: 6, repsMin: 1, repsMax: 1,
                    restSeconds: 90,
                    isCardio: true,
                    targetDistanceKm: 0.4
                )
            case .easy, .tempo:
                exercise = ExerciseSpec(
                    name: zone.exerciseName,
                    sets: 1, repsMin: 0, repsMax: 0,
                    isCardio: true,
                    targetDurationMinutes: selection.sessionDurationMinutes
                )
            }
            return Candidate(
                name: title,
                exercises: [exercise],
                timeFormat: nil,
                timeCapMinutes: nil,
                hardness: zone.baseHardness * durationFactor
            )
        }
        // Bugfix (Audit): der 3-Zonen-Zyklus wiederholt sich ab Tag 4 (z.B.
        // 5x/Woche -> Tag 1 und 4 beide "Ruhiger Lauf") - ohne Disambiguierung
        // stehen dann zwei identisch benannte Lauf-Tage in der Uebersicht.
        disambiguateDuplicateNames(&result)
        return result
    }

    // MARK: - Ordering

    /// Sortiert absteigend nach Haerte, dann abwechselnd vom haertesten und
    /// leichtesten Ende genommen ("Zick-Zack-Merge") - verteilt die
    /// anstrengendsten Einheiten ueber die Woche, statt sie zu clustern.
    private static func spreadByHardness(_ candidates: [Candidate]) -> [Candidate] {
        let sorted = candidates.sorted { $0.hardness > $1.hardness }
        guard sorted.count > 2 else { return sorted }

        var result: [Candidate] = []
        var left = 0
        var right = sorted.count - 1
        var takeFromLeft = true
        while left <= right {
            if takeFromLeft {
                result.append(sorted[left])
                left += 1
            } else {
                result.append(sorted[right])
                right -= 1
            }
            takeFromLeft.toggle()
        }
        return result
    }

    /// Bildet jede Haerte auf ihre Position innerhalb der Spannweite DIESES
    /// Ergebnisses ab (0...1) und rastert in vier Viertel. Ohne Spannweite
    /// (0 oder 1 Kandidat, oder alle exakt gleich haart) gibt es nichts zu
    /// verteilen - dann bekommt jeder Tag `.medium` als neutralen Default,
    /// statt eine willkuerliche Grenze zu erfinden.
    private static func loadLevels(for hardnessValues: [Double]) -> [PlanLoadLevel] {
        guard let low = hardnessValues.min(), let high = hardnessValues.max(), high > low else {
            return hardnessValues.map { _ in .medium }
        }
        return hardnessValues.map { value in
            switch (value - low) / (high - low) {
            case ..<0.25: return .easy
            case ..<0.5:  return .medium
            case ..<0.75: return .hard
            default:      return .tough
            }
        }
    }
}

/// README 2.20 Step 3: die vier Belastungs-Kapsel-Stufen ("locker / mittel /
/// schwer / hart"). Siehe `PlanGenerator.Result.GeneratedDay` fuer die
/// bewusst relative (nicht absolute) Berechnung.
public enum PlanLoadLevel: String, Codable, Sendable, CaseIterable {
    case easy, medium, hard, tough

    public var titleKey: String {
        switch self {
        case .easy:   return "planBuilder.load.easy"
        case .medium: return "planBuilder.load.medium"
        case .hard:   return "planBuilder.load.hard"
        case .tough:  return "planBuilder.load.tough"
        }
    }
}
```

### 4. `Sources/FitnessAppData/PlanGeneratorInstantiator.swift`

Brücke zwischen dem reinen Generator-Ergebnis und der bestehenden
`ProgramInstantiator`-Materialisierung:
- `build(from:in:)` — rechnet einmal, baut eine wegwerfbare synthetische
  `ProgramTemplate`-Hülle und delegiert die eigentliche Insert-Arbeit an
  `ProgramInstantiator.instantiate` (kein Duplikat der Instanziierungslogik).
  Speichert zusätzlich `plan.generatorInput` (JSON-codiert) sowie pro Tag
  `generatorSequenceIndex`/`generationFingerprint`.
- `recalculate(_:in:)` — "neu rechnen" für einen bestehenden, über den
  Assistenten erzeugten Plan: rechnet `generatorInput` erneut aus und
  überschreibt nur Tage, die seit der Erzeugung unverändert geblieben sind
  (`generationFingerprint == currentContentFingerprint`), damit manuelle
  Anpassungen nicht verloren gehen.

```swift
#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// README 2.20 "Plan bauen": Bruecke zwischen dem reinen Core-Generator
/// (`PlanGenerator`, kein SwiftData) und der bestehenden
/// `ProgramInstantiator`-Materialisierung. Baut dafuer eine wegwerfbare
/// synthetische `ProgramTemplate`-Huelle aus dem generierten `[DaySpec]` und
/// delegiert die eigentliche Insert-Arbeit an `ProgramInstantiator.instantiate`,
/// statt sie zu duplizieren - so profitiert "Plan bauen" automatisch von
/// jeder kuenftigen Aenderung an der Instanziierungs-Logik.
@MainActor
public enum PlanGeneratorInstantiator {

    /// Rechnet `input` einmal aus, instanziiert das Ergebnis als neuen
    /// aktiven Plan (gleiche Side-Effects wie jeder andere Template-Adopt,
    /// siehe `ProgramInstantiator.instantiate`) und stempelt danach jeden
    /// Trainings-Tag mit seinem Erzeugungs-Fingerprint sowie den Plan mit
    /// dem JSON-codierten `input` - beides zusammen macht `recalculate`
    /// spaeter moeglich.
    ///
    /// Liefert `nil`, wenn der Generator fuer diese Auswahl NICHTS gefunden
    /// hat (z.B. eine Ausruestung/Schwierigkeit-Kombination ohne jeden
    /// Bibliotheks-Treffer) - die Wizard-UI sollte "Plan uebernehmen" zwar
    /// bereits vorher deaktivieren, wenn `PlanGenerator.generate` leer
    /// zurueckkommt, aber diese Funktion verlaesst sich nicht darauf: ein
    /// `daysPerWeek: 0`-Template wuerde `ProgramInstantiator.defaultWeekdays`
    /// in eine ungueltige Range (`2...1`) und damit einen Crash laufen lassen.
    @discardableResult
    public static func build(from input: PlanGeneratorInput, in context: ModelContext) -> TrainingPlan? {
        let result = PlanGenerator.generate(from: input)
        guard !result.days.isEmpty else { return nil }
        let template = makeTemplate(from: result)

        let plan = ProgramInstantiator.instantiate(
            template,
            in: context,
            selectedWeekdays: resolvedWeekdays(from: input),
            userEquipment: input.equipmentPreferences
        )
        plan.generatorInput = input

        // Genau JETZT - direkt nach `instantiate`, bevor irgendein Edit
        // stattfinden konnte - entspricht die Montag-first-sortierte
        // Position exakt dem `sequenceIndex`, mit dem `ProgramInstantiator`
        // gerade erst jeden Tag angelegt hat (siehe dortige
        // `sortedDays.enumerated()` + `normalized[idx]`-Zuordnung). Das ist
        // die EINZIGE Stelle, an der wir uns auf Listenposition statt auf
        // den gespeicherten `generatorSequenceIndex` verlassen duerfen -
        // `recalculate` tut das bewusst NICHT mehr (siehe dort).
        let orderedDays = PlanNavigator.sortByWeekdayMondayFirst(plan.days.filter { $0.type != .rest })
        for (day, generated) in zip(orderedDays, result.days) {
            day.generatorSequenceIndex = generated.spec.sequenceIndex
            day.generationFingerprint = day.currentContentFingerprint
        }
        return plan
    }

    /// README 2.20 "neu rechnen": rechnet den am Plan gespeicherten
    /// `generatorInput` neu und ersetzt NUR Tage, deren Inhalt seit der
    /// letzten (Neu-)Erzeugung unveraendert ist - "ueberschreiben, aber nur
    /// unangetastete Tage", das Dokument schlaegt diese Regel selbst vor.
    /// Ein Tag gilt als unangetastet, wenn sein gespeicherter
    /// `generationFingerprint` noch exakt seinem `currentContentFingerprint`
    /// entspricht; alles andere ist ein User-Edit und bleibt stehen.
    ///
    /// Matching generierter <-> bestehender Tage laeuft NICHT positional,
    /// sondern ueber den bei der Erzeugung gestempelten
    /// `TrainingDay.generatorSequenceIndex`. Ein frueherer Entwurf sortierte
    /// die Trainings-Tage Montag-first und griff per Listen-Index in
    /// `result.days` - das bricht, sobald der User ueber `DayEditorView`
    /// den Wochentag EINES Tages aendert oder einen Tag zum Ruhetag macht:
    /// die Montag-first-Position verschiebt sich fuer alle NACHFOLGENDEN
    /// Tage, obwohl die als unangetastet gelten und ueberschrieben werden
    /// sollten - mit dem Inhalt des FALSCHEN generierten Tages. Der
    /// `generatorSequenceIndex` bleibt dagegen stabil, ganz gleich wie oft
    /// Wochentag/Typ seither editiert wurden (beide sind zusaetzlich Teil
    /// von `currentContentFingerprint`, schuetzen einen so geaenderten Tag
    /// also ohnehin vor dem Ueberschreiben).
    ///
    /// Kein-Op (Rueckgabe 0), wenn der Plan gar keinen `generatorInput`
    /// traegt (nicht ueber den Assistenten entstanden).
    ///
    /// Rueckgabe: Anzahl der tatsaechlich neu geschriebenen Tage.
    @discardableResult
    public static func recalculate(_ plan: TrainingPlan, in context: ModelContext) -> Int {
        guard let input = plan.generatorInput else { return 0 }
        let result = PlanGenerator.generate(from: input)
        let generatedBySequenceIndex = Dictionary(
            uniqueKeysWithValues: result.days.map { ($0.spec.sequenceIndex, $0.spec) }
        )

        let (timeBasedNames, compoundNames) = ProgramInstantiator.libraryLookupNames()
        let specByName = ProgramInstantiator.libraryLookupSpecs()

        var rewritten = 0
        for day in plan.days {
            // `daysPerWeek` kann sich seit der Erzeugung veraendert haben
            // (andere `input`-Selektion nach erneutem Wizard-Durchlauf waere
            // ein Zukunfts-Feature - heute unveraendert, aber die Anzahl der
            // Tage kann trotzdem abweichen); ein `sequenceIndex`, den es im
            // frischen Ergebnis nicht mehr gibt, wird defensiv uebersprungen.
            guard let sequenceIndex = day.generatorSequenceIndex,
                  let generatedSpec = generatedBySequenceIndex[sequenceIndex] else { continue }
            guard day.generationFingerprint != nil,
                  day.generationFingerprint == day.currentContentFingerprint else { continue }
            apply(
                generatedSpec,
                to: day,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                specByName: specByName,
                in: context
            )
            rewritten += 1
        }
        return rewritten
    }

    /// Ersetzt Name + Zeitformat + Uebungen eines Tages durch einen frisch
    /// generierten `DaySpec` und schreibt den neuen Fingerprint fest -
    /// gleiche Exercise-Anreicherung wie beim ersten Erzeugen
    /// (`ProgramInstantiator.makeExercise`), keine Zweit-Implementierung.
    ///
    /// Loescht bewusst nur `activeExercises`, NICHT die volle `exercises`-
    /// Relationship: `currentContentFingerprint` ignoriert archivierte
    /// Eintraege absichtlich (ein automatischer Urlaubs-Modus-Swap soll
    /// "neu rechnen" nicht blockieren, siehe dortige Doku) - wuerden hier
    /// trotzdem ALLE Uebungen geloescht, riesse das genau die archivierten
    /// Originale mit, auf die `PlanEnvironmentMigrator.restoreOriginals`
    /// beim Verlassen des Urlaubs-Modus angewiesen ist.
    private static func apply(
        _ spec: DaySpec,
        to day: TrainingDay,
        timeBasedNames: Set<String>,
        compoundNames: Set<String>,
        specByName: [String: ExerciseTemplateSpec],
        in context: ModelContext
    ) {
        for exercise in day.activeExercises {
            context.delete(exercise)
        }

        day.name = spec.name
        day.customName = nil
        day.localizationKey = spec.localizationKey
        day.timeFormat = spec.timeFormat
        day.timeCapMinutes = spec.timeCapMinutes

        for (orderIndex, exerciseSpec) in spec.exercises.enumerated() {
            let exercise = ProgramInstantiator.makeExercise(
                from: exerciseSpec,
                orderIndex: orderIndex,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                librarySpecByName: specByName,
                day: day
            )
            context.insert(exercise)
        }

        day.generationFingerprint = day.currentContentFingerprint
    }

    /// `nil` (= `ProgramInstantiator` faellt auf `defaultWeekdays` zurueck)
    /// wenn Schritt 2 "Nur Reihenfolge" gewaehlt hat. Bei festen Wochentagen
    /// wird `input.fixedWeekdays` unveraendert durchgereicht - ein
    /// Anzahl-Mismatch faengt `ProgramInstantiator.instantiate` selbst
    /// defensiv ab (faellt dann seinerseits auf Defaults zurueck).
    private static func resolvedWeekdays(from input: PlanGeneratorInput) -> [Int]? {
        input.usesFixedWeekdays ? input.fixedWeekdays : nil
    }

    /// Wegwerf-Huelle, rein damit `ProgramInstantiator.instantiate`
    /// wiederverwendet werden kann. `id` ist absichtlich kein echter
    /// `ProgramTemplates.all`-Eintrag - jeder Code, der `programType` gegen
    /// die kuratierte Liste abgleicht (`LibrarySeeder`s Backfills), behandelt
    /// eine unbekannte ID bereits konservativ als "Custom-Plan ohne
    /// Template-Origin" (gleiche Kategorie wie ein manuell angelegter Plan).
    private static func makeTemplate(from result: PlanGenerator.Result) -> ProgramTemplate {
        ProgramTemplate(
            id: "planBuilder.generated",
            name: "Individueller Plan",
            tagline: "",
            descriptionText: "",
            focus: "",
            daysPerWeek: result.days.count,
            days: result.days.map(\.spec),
            targetEnvironment: .gym,
            iconSystemName: "wand.and.stars"
        )
    }
}
#endif
```
