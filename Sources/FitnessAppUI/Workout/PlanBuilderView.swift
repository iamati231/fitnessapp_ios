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
///
/// DEL-243: `onGenerated` ist der EINZIGE Weg,
/// dieses Verhalten zu ueberschreiben - `OnboardingView` kann den fertig
/// gerechneten Plan nicht sofort selbst instanziieren (adoptieren wuerde
/// sonst eine verwaiste `TrainingPlan`-Zeile anlegen, BEVOR das
/// `UserBodyProfile` existiert, und `RootView`s Query-basierter Onboarding-
/// Abschluss haengt exakt an diesem Insert, nicht an der Plan-Erzeugung).
/// Ist `onGenerated` gesetzt, liefert `adoptPlan()` `PlanGeneratorInput` +
/// `PlanGenerator.Result` stattdessen nur nach oben durch - der Aufrufer
/// entscheidet selbst, wann/ob `PlanGeneratorInstantiator.build(...)`
/// laeuft (bei `OnboardingView` erst zusammen mit dem Profil in
/// `finishOnboarding()`). `nil` (Default) erhaelt das bisherige, sich
/// selbst adoptierende Verhalten fuer `PlansListView` unveraendert.
@available(iOS 17.0, macOS 14.0, *)
public struct PlanBuilderView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    private let onGenerated: ((PlanGeneratorInput, PlanGenerator.Result) -> Void)?

    public init(onGenerated: ((PlanGeneratorInput, PlanGenerator.Result) -> Void)? = nil) {
        self.onGenerated = onGenerated
    }

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

    /// `shuffle`: Bugfix (Nutzer-Feedback) - der erste Aufruf beim Betreten
    /// von Schritt 3 (`goToNextStep`/`.onAppear`) bleibt bewusst
    /// deterministisch (Default `false`), nur der explizite "Neu rechnen"-
    /// Tap fordert eine Variante an (siehe `resultStepView`).
    private func recalculatePreview(shuffle: Bool = false) {
        result = PlanGenerator.generate(from: currentInput, shuffle: shuffle)
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
                        // Bugfix (Nutzer-Feedback): "Neu rechnen" fordert
                        // jetzt explizit eine gemischte Variante an (statt
                        // denselben `currentInput` deterministisch erneut zu
                        // rechnen und exakt dasselbe Ergebnis zu zeigen).
                        // `withAnimation` gibt sichtbares Feedback (Kapsel-
                        // Farbwechsel, Erklaerungstext-Ein-/Ausblenden,
                        // Zeilenhoehen), selbst wenn sich die gewaehlten
                        // Uebungen im Einzelfall kaum unterscheiden.
                        withAnimation(.easeInOut(duration: 0.3)) {
                            recalculatePreview(shuffle: true)
                        }
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
                // DEL-247: `displayName` statt `.name` - loest den seit
                // DEL-247 gesetzten `localizationKey` auf, damit die
                // Wizard-Vorschau selbst schon in EN/TR korrekt anzeigt statt
                // erst nach dem Adopt (wo `TrainingDay.displayName` das
                // ohnehin schon tat).
                Text(day.spec.displayName)
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
        // Bugfix (Nutzer-Feedback, "Neu rechnen"-Shuffle): das bereits in
        // Schritt 3 angezeigte `result` wird durchgereicht statt neu zu
        // rechnen (und damit wieder deterministisch, ohne Shuffle) - sonst
        // wuerde ein zuvor per "Neu rechnen" gefundener, dem User
        // zusagender Plan beim Uebernehmen durch die urspruengliche
        // Variante ersetzt. Der Knopf ist disabled, solange `result` leer/
        // nil ist (siehe `navigationBar`), das `guard` hier ist die
        // gemeinsame Absicherung fuer BEIDE Pfade unten.
        guard let result else { return }

        // DEL-243: siehe Typ-Doku - `onGenerated`
        // uebernimmt hier NICHT das Instanziieren, sondern reicht Input +
        // Ergebnis nur nach oben durch. Der Aufrufer schliesst den Sheet
        // selbst nicht extra an - `dismiss()` unten laeuft in JEDEM Fall.
        if let onGenerated {
            onGenerated(currentInput, result)
            dismiss()
            return
        }

        guard let plan = PlanGeneratorInstantiator.build(from: currentInput, in: modelContext, result: result, generationSource: .planBuilder) else { return }
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
