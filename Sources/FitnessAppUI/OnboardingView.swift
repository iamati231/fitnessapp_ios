#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities

/// First-launch profile setup as a three-step wizard:
///   1. **Apple Health verbinden** — optional Pre-Fill von Alter / Geschlecht /
///      Größe / Gewicht aus dem HK-Profil. User kann komplett überspringen.
///   2. **Persönliche Daten** — Sex / Geburtsdatum / Größe / aktuelles Gewicht
///      (Pflicht) / Zielgewicht / Trainingsort. Werte sind vorbefüllt aus
///      Schritt 1, soweit HealthKit was lieferte.
///   3. **Präferenzen + Startplan** — Toggle für Wasser- und Mess-Reminder
///      (opt-in für Local Notifications) und Auswahl eines Trainingsplan-
///      Templates (optional, "Später" möglich).
///
/// Am Ende:
///   - `UserBodyProfile` wird inserted
///   - Initial `BodyMeasurement` mit dem aktuellen Gewicht (+ derived metrics)
///   - Reminder-Präferenzen in `@AppStorage`; Notification-Permission wird
///     angefragt, wenn mindestens ein Toggle aktiv
///   - Wenn ein Plan gewählt: `ProgramInstantiator` materialisiert ihn als
///     aktiven `TrainingPlan`
///
/// `RootView`'s @Query auf UserBodyProfile löst beim Insert den Wechsel zu
/// MainTabView aus — keine explizite Navigation nach Onboarding-Finish nötig.
@available(iOS 17.0, macOS 14.0, *)
public struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications

    enum Step: Int, CaseIterable {
        case healthConnect
        case personalInfo
        case coachingStyle           // DEL-101: Goal + Tone in einem Schritt
        case equipmentPreferences    // DEL-170b: Multi-Select Equipment
        case preferencesAndPlan
    }

    @State private var step: Step = .healthConnect

    // Step 1 / 2 — Persönliche Daten
    @State private var profileSex: BodyFormulaProfile = .male
    @State private var birthDate: Date = Self.defaultBirthDate
    @State private var heightCm: Double?

    /// DEL-141: Optionaler Vorname. Default leer; bleibt leer wenn der
    /// User das Feld skippt — `finishOnboarding` normalisiert dann auf nil
    /// damit das Modell keine empty-string-Sentinels mit sich rumschleppt.
    @State private var firstName: String = ""
    @State private var currentWeightKg: Double?
    @State private var goalWeightKg: Double?
    @State private var environment: EnvironmentType = .gym

    // Step 1 — Tracking ob HealthKit-Snapshot schon angefordert wurde
    @State private var healthKitFetchInProgress: Bool = false
    @State private var healthKitDataLoaded: Bool = false

    /// Flag fuer den HealthKit-DOB-Auto-Fill-Pfad. Frueher haben wir
    /// `birthDate == Self.defaultBirthDate` als Gate benutzt, das aber durch
    /// die Date()-Komponente in defaultBirthDate jedes Mal neue Millisekunden
    /// produziert und damit nie wahr ist. Deswegen wurde HK's DOB nie ueber-
    /// nommen, obwohl die snapshot.dateOfBirth-Daten korrekt waren (DEL-024).
    @State private var birthDateWasEdited: Bool = false

    // DEL-101 — Coaching-Style Step
    @State private var trainingGoal: TrainingGoal = .hybrid
    @State private var coachingTone: CoachingTone = .analytical

    // DEL-170b — Equipment-Präferenzen (Multi-Select). Wird beim ersten
    // Betreten des Steps mit sinnvollen Defaults aus `environment` befüllt,
    // sodass der User direkt eine Vor-Auswahl sieht und nur korrigieren muss.
    @State private var equipmentPreferences: Set<Equipment> = []
    @State private var equipmentPrefilledForEnv: EnvironmentType? = nil

    // Step 4 — Präferenzen + Plan
    @State private var enableWaterReminder: Bool = true
    @State private var enableMeasurementReminder: Bool = true
    @State private var selectedTemplate: ProgramTemplate?

    /// DEL-056: Tap auf einen Template-Row oeffnet eine Detail-Vorschau in
    /// einem Sheet. Erst der "Diesen Plan waehlen"-Button im Detail finalisiert
    /// die Auswahl (`selectedTemplate = ...` + Onboarding-Finish).
    @State private var previewingTemplate: ProgramTemplate?

    // DEL-090: Smart Onboarding Quiz. Wenn aktiv, oeffnet sich der Quiz statt
    // der manuellen Plan-Liste. Quiz-Result fuehrt zum DayPicker.
    @State private var showingQuiz: Bool = false

    // DEL-088: Tag-Auswahl-Sheet, das nach Plan-Adopt erscheint. Sobald
    // `dayPickerTemplate != nil`, oeffnet sich das DayPickerSheet mit dem
    // dort hinterlegten Template. `onConfirm` setzt `selectedWeekdays` und
    // ruft finishOnboarding() auf.
    @State private var dayPickerTemplate: ProgramTemplate?

    /// DEL-088: Vom User gewaehlte Wochentage (Apple-Calendar-Index, Mo-first).
    /// Leeres Array = Caller hat noch keine Auswahl getroffen — Instantiator
    /// fallback'd auf seine Defaults (siehe `ProgramInstantiator.defaultWeekdays`).
    @State private var selectedWeekdays: [Int] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                Divider()

                Group {
                    switch step {
                    case .healthConnect:        healthConnectStep
                    case .personalInfo:         personalInfoStep
                    case .coachingStyle:        coachingStyleStep
                    case .equipmentPreferences: equipmentPreferencesStep
                    case .preferencesAndPlan:   preferencesAndPlanStep
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)

                Divider()

                stepNavigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(Text("onboarding.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .keyboardDismissToolbar()
            // DEL-056: Plan-Detail-Sheet. Wird auf Step 3 geoeffnet, wenn der
            // User einen Template-Row antippt. Adopt-Button finalisiert die
            // Auswahl und triggert direkt das Onboarding-Finish — sonst
            // muesste der User noch ein zweites Mal auf "Fertig" tippen.
            .sheet(item: $previewingTemplate) { template in
                NavigationStack {
                    TemplatePreviewView(
                        template: template,
                        adoptButtonTitle: "Diesen Plan wählen"
                    ) {
                        // DEL-088: Adopt finalisiert die Plan-Wahl noch nicht
                        // direkt — stattdessen oeffnet sich der DayPicker,
                        // damit der User die Trainings-Wochentage festlegt.
                        selectedTemplate = template
                        previewingTemplate = nil
                        dayPickerTemplate = template
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                previewingTemplate = nil
                            } label: {
                                Text("common.close", bundle: .module)
                            }
                        }
                    }
                }
            }
            // DEL-090: Smart Onboarding Quiz. Vier kompakte Fragen +
            // Result-Screen, der via `PlanMatchmaker` die 14 Templates ranked.
            .sheet(isPresented: $showingQuiz) {
                OnboardingQuizView(
                    preselectedEnvironment: environment,
                    onPlanSelected: { template in
                        selectedTemplate = template
                        showingQuiz = false
                        // Quiz-Result direkt weiter in den DayPicker — das
                        // ist der naechste Pflicht-Step im Wave-14-Flow.
                        dayPickerTemplate = template
                    },
                    onCancel: {
                        showingQuiz = false
                    }
                )
            }
            // DEL-088: DayPickerSheet — nach Plan-Wahl muss der User exakt
            // `template.daysPerWeek` Wochentage ankreuzen. Submit ruft direkt
            // `finishOnboarding()` mit den gewaehlten Weekdays auf.
            .sheet(item: $dayPickerTemplate) { template in
                DayPickerSheet(
                    requiredDayCount: template.daysPerWeek,
                    planName: template.displayName,
                    initialSelection: ProgramInstantiator.defaultWeekdays(for: template.daysPerWeek),
                    onConfirm: { weekdays in
                        selectedWeekdays = weekdays
                        dayPickerTemplate = nil
                        finishOnboarding()
                    },
                    onCancel: {
                        dayPickerTemplate = nil
                    }
                )
            }
        }
    }

    // MARK: - Progress indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: HealthKit-Connect

    @ViewBuilder
    private var healthConnectStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("onboarding.health.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.health.intro", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !healthKit.isAvailable {
                    Label {
                        Text("onboarding.health.unavailable", bundle: .module)
                    } icon: {
                        Image(systemName: "heart.slash")
                    }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    healthKitActionRow
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var healthKitActionRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("onboarding.health.connected", bundle: .module)
                } icon: {
                    Image(systemName: "heart.fill")
                }
                    .font(.headline)
                    .foregroundStyle(.pink)

                if healthKitDataLoaded {
                    Text("onboarding.health.pulled", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await pullHealthKitSnapshot() }
                    } label: {
                        if healthKitFetchInProgress {
                            HStack { ProgressView(); Text("onboarding.health.loading", bundle: .module) }
                        } else {
                            Label {
                                Text("onboarding.health.pull", bundle: .module)
                            } icon: {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(healthKitFetchInProgress)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pink.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .notDetermined:
            Button {
                Task {
                    await healthKit.requestAuthorization()
                    // Direkt nach der Authorization den Snapshot ziehen.
                    if healthKit.authorizationStatus == .sharingAuthorized {
                        await pullHealthKitSnapshot()
                    }
                }
            } label: {
                Label {
                    Text("onboarding.health.title", bundle: .module)
                } icon: {
                    Image(systemName: "heart.fill")
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .sharingDenied:
            Label {
                Text("onboarding.health.denied", bundle: .module)
            } icon: {
                Image(systemName: "heart.slash")
            }
                .font(.callout)
                .foregroundStyle(.orange)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))

        case .unavailable:
            EmptyView()
        }
    }

    // MARK: - Step 2: Persönliche Daten

    @ViewBuilder
    private var personalInfoStep: some View {
        Form {
            // DEL-141: Vorname-Section ZUERST. Bewusst eigene Section + ganz
            // oben — der Name macht das Onboarding persoenlicher, signal-
            // isiert dem User "wir sehen dich als Person, nicht als Datenset".
            // Optional: User kann das Feld leer lassen, Dashboard faellt
            // dann auf generische Tageszeit-Begruessung zurueck.
            Section {
                TextField(
                    text: $firstName,
                    prompt: Text("onboarding.field.firstNamePlaceholder", bundle: .module)
                ) {
                    Text("onboarding.field.firstName", bundle: .module)
                }
                .textContentType(.givenName)
                #if os(iOS)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                #endif
            } header: {
                Text("onboarding.section.name", bundle: .module)
            } footer: {
                Text("onboarding.field.firstNameFooter", bundle: .module)
                    .font(.footnote)
            }

            Section {
                Picker(selection: $profileSex) {
                    ForEach([BodyFormulaProfile.male, .female], id: \.self) { sex in
                        Text(sex.localizedName).tag(sex)
                    }
                } label: {
                    Text("onboarding.field.sex", bundle: .module)
                }
                .pickerStyle(.segmented)

                DatePicker(
                    selection: $birthDate,
                    in: Self.minBirthDate ... Date(),
                    displayedComponents: .date
                ) {
                    Text("onboarding.field.birthdate", bundle: .module)
                }
                .onChange(of: birthDate) { _, _ in
                    // Markiert das DOB als user-edited, damit ein spaeterer
                    // HealthKit-Pull NICHT mehr ueberschreibt (DEL-024).
                    birthDateWasEdited = true
                }
            } header: {
                Text("onboarding.section.profile", bundle: .module)
            }

            Section {
                decimalField(String(localized: "onboarding.field.heightCm", bundle: .module), value: $heightCm)
                decimalField(String(localized: "onboarding.field.weightCurrentKg", bundle: .module), value: $currentWeightKg)
            } header: {
                Text("onboarding.section.body", bundle: .module)
            } footer: {
                if let weight = currentWeightKg, weight <= 0 {
                    Text("onboarding.body.weightZero", bundle: .module)
                        .foregroundStyle(.red)
                } else if currentWeightKg == nil {
                    Text("onboarding.body.weightRequired", bundle: .module)
                        .font(.footnote)
                } else {
                    Text("onboarding.body.weightInitial", bundle: .module)
                        .font(.footnote)
                }
            }

            Section {
                decimalField(String(localized: "onboarding.field.goalWeightKg", bundle: .module), value: $goalWeightKg)
                Picker(selection: $environment) {
                    ForEach(EnvironmentType.allCases, id: \.self) { env in
                        Text(env.localizedName).tag(env)
                    }
                } label: {
                    Text("onboarding.field.environment", bundle: .module)
                }
            } header: {
                Text("onboarding.section.goals", bundle: .module)
            } footer: {
                // DEL-075: Hinweis fuer reine Cardio-/Hybrid-Athleten. Der
                // Trainingsort ist NICHT bindend — Hybrid-Plaene laufen
                // auf jedem Setting, und der User kann ihn in den
                // Einstellungen jederzeit aendern.
                VStack(alignment: .leading, spacing: 4) {
                    Text("onboarding.environment.footnote1", bundle: .module)
                    Text("onboarding.environment.footnote2", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Step 3: Coaching-Stil (DEL-101)

    /// Kombinierter Coaching-Style-Step: TrainingGoal oben, CoachingTone
    /// unten. Beide nutzen die selbe SelectableCard-Komponente (siehe
    /// `coachingCard(...)`). DeltiqOrange-Akzent + Checkmark-Icon auf der
    /// selektierten Karte. Bottom-CTA "Weiter" wird via stepNavigationBar
    /// (Universal-Footer) gerendert — wir schieben hier nichts extra ein.
    @ViewBuilder
    private var coachingStyleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // ──────────── Goal ────────────
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("onboarding.goal.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("onboarding.goal.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        ForEach(TrainingGoal.allCases, id: \.self) { goal in
                            coachingCard(
                                title: String(localized: goal.localizedName),
                                description: String(localized: goal.localizedBlurb),
                                iconName: goal.symbol,
                                isSelected: trainingGoal == goal
                            ) {
                                trainingGoal = goal
                            }
                        }
                    }
                }

                // ──────────── Tone ────────────
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("onboarding.tone.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("onboarding.tone.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        ForEach(CoachingTone.allCases, id: \.self) { tone in
                            coachingCard(
                                title: String(localized: tone.localizedName),
                                description: String(localized: tone.localizedBlurb),
                                iconName: tone.symbol,
                                isSelected: coachingTone == tone
                            ) {
                                coachingTone = tone
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Step 4: Equipment-Präferenzen (DEL-170b)

    /// Multi-Select-Step für Equipment. Defaults werden anhand der aus Step 2
    /// gewählten `environment` vor-befüllt — der User sieht eine sinnvolle
    /// Auswahl und kann nur korrigieren. Pflegt sich gegenseitig mit dem
    /// Profil-Editor (gleiches Datenmodell).
    @ViewBuilder
    private var equipmentPreferencesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.equipment.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.equipment.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(Equipment.allCases, id: \.self) { equip in
                        equipmentChoiceRow(equip)
                    }
                }

                Text("onboarding.equipment.footer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        // Beim ersten Betreten des Steps Defaults aus `environment` ziehen.
        // Gate über `equipmentPrefilledForEnv`: wenn der User in Step 2
        // nachträglich die Environment ändert, prefill'en wir erneut —
        // bestehende User-Auswahl überschreiben wir aber nicht, sondern
        // mergen die zusätzlichen Defaults (Union).
        .onAppear { prefillEquipmentIfNeeded() }
        .onChange(of: environment) { _, _ in
            // Neue Environment → neue Defaults vorschlagen (mergen).
            prefillEquipmentIfNeeded(force: true)
        }
    }

    @ViewBuilder
    private func equipmentChoiceRow(_ equip: Equipment) -> some View {
        let isSelected = equipmentPreferences.contains(equip)
        Button {
            if isSelected { equipmentPreferences.remove(equip) }
            else          { equipmentPreferences.insert(equip) }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: equipmentIcon(equip))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                    .frame(width: 32, height: 32)
                Text(equip.localizedName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.deltiqOrange.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Spiegelung der SF-Symbole aus dem Picker — visuelle Konsistenz.
    private func equipmentIcon(_ e: Equipment) -> String {
        switch e {
        case .barbell:     return "scalemass"
        case .dumbbell:    return "dumbbell"
        case .bodyweight:  return "figure.walk"
        case .machine:     return "gearshape"
        case .cable:       return "cable.connector"
        case .kettlebell:  return "circle.grid.cross"
        case .band:        return "infinity"
        }
    }

    /// Prefill-Logik: schlägt sinnvolle Defaults vor, basierend auf der
    /// gewählten Trainings-Umgebung (`environment`). Defaults werden nur
    /// einmal pro Environment-Wert vorgeschlagen (idempotent) und überschreiben
    /// keine vom User explizit getroffene Auswahl — `Set.formUnion` merged.
    private func prefillEquipmentIfNeeded(force: Bool = false) {
        if !force, equipmentPrefilledForEnv == environment { return }
        let suggestion = defaultEquipment(for: environment)
        equipmentPreferences.formUnion(suggestion)
        equipmentPrefilledForEnv = environment
    }

    /// Sinnvolle Equipment-Defaults pro Trainings-Umgebung. Gym = "hat alles";
    /// Home-Gym = freie Gewichte ohne Maschinen; No-Equipment = Body + Band.
    private func defaultEquipment(for env: EnvironmentType) -> Set<Equipment> {
        switch env {
        case .gym:         return [.barbell, .dumbbell, .machine, .cable, .kettlebell, .bodyweight]
        case .homeGym:     return [.dumbbell, .kettlebell, .band, .bodyweight]
        case .noEquipment: return [.bodyweight, .band]
        }
    }

    /// DEL-101: Reusable SelectableCard im Deltiq-Stil — DeltiqOrange-
    /// Stroke + Checkmark-Icon bei Selektion, sonst dezent gegraut.
    @ViewBuilder
    private func coachingCard(
        title: String,
        description: String,
        iconName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: iconName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.deltiqOrange)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(isSelected ? 0.10 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Step 4: Präferenzen + Plan

    @ViewBuilder
    private var preferencesAndPlanStep: some View {
        Form {
            Section {
                Toggle(isOn: $enableWaterReminder) {
                    Label {
                        Text("onboarding.notif.water", bundle: .module)
                    } icon: {
                        Image(systemName: "drop.fill")
                    }
                }
                Toggle(isOn: $enableMeasurementReminder) {
                    Label {
                        Text("onboarding.notif.measurement", bundle: .module)
                    } icon: {
                        Image(systemName: "scalemass.fill")
                    }
                }
            } header: {
                Text("onboarding.notif.section", bundle: .module)
            } footer: {
                Text("onboarding.notif.footnote", bundle: .module)
                    .font(.footnote)
            }

            // DEL-090: Hero-Card "Plan finden lassen" — startet den
            // Smart-Onboarding-Quiz, der die 14 Templates fuer den User
            // ranked, statt ihn manuell aus einer 14er-Liste raten zu lassen.
            Section {
                Button {
                    showingQuiz = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.deltiqOrange.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("onboarding.plan.quizCard.title", bundle: .module)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("onboarding.plan.quizCard.subtitle", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("onboarding.plan.recommended", bundle: .module)
            } footer: {
                Text("onboarding.plan.quizCard.footnote", bundle: .module)
                    .font(.footnote)
            }

            Section {
                if filteredTemplates.isEmpty {
                    Text(String(format: String(localized: "onboarding.plan.noTemplates", bundle: .module), environmentLabel))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredTemplates) { template in
                        Button {
                            // DEL-056: Tap oeffnet die Detail-Vorschau,
                            // KEIN stilles Selektieren mehr. Erst der Adopt-
                            // Button im Detail wahlt den Plan und triggert
                            // den DayPicker.
                            previewingTemplate = template
                        } label: {
                            templateRow(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(String(format: String(localized: "onboarding.plan.section", bundle: .module), environmentLabel))
            } footer: {
                Text(String(format: String(localized: "onboarding.plan.footnote", bundle: .module), environmentLabel))
                    .font(.footnote)
            }
        }
    }

    /// String-Repraesentation des aktuellen Environments fuer Section-Header/
    /// Footer-Interpolation. `LocalizedStringResource` direkt in einen
    /// String-Interpolation-Context zu stecken faellt auf macOS-strict
    /// Toolchain durch — `String(localized:)` ist der Cast.
    private var environmentLabel: String {
        String(localized: environment.localizedName)
    }

    /// Templates passend zum gewaehlten Trainingsort.
    ///   - `.gym`: alle Templates (Vollgym hat alles, was alle anderen brauchen)
    ///   - `.homeGym`: homeGym + noEquipment (Bodyweight-Sachen gehen ueberall)
    ///   - `.noEquipment`: strikt nur noEquipment-Templates (sonst landet der
    ///     User in einem Plan, fuer den ihm das Equipment fehlt)
    private var filteredTemplates: [ProgramTemplate] {
        ProgramTemplates.all.filter { template in
            switch environment {
            case .gym:
                return true
            case .homeGym:
                return template.targetEnvironment == .homeGym
                    || template.targetEnvironment == .noEquipment
            case .noEquipment:
                return template.targetEnvironment == .noEquipment
            }
        }
    }

    private func templateRow(_ template: ProgramTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconSystemName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayName)
                    .font(.body.weight(.semibold))
                Text(template.displayTagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedTemplate?.id == template.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
    }

    // MARK: - Navigation buttons

    @ViewBuilder
    private var stepNavigationBar: some View {
        HStack {
            if step != .healthConnect {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("common.back", bundle: .module)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                handlePrimaryAction()
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
        }
    }

    private var primaryActionTitle: String {
        switch step {
        case .healthConnect:        return "Weiter"
        case .personalInfo:         return "Weiter"
        case .coachingStyle:        return "Weiter"
        case .equipmentPreferences: return "Weiter"
        case .preferencesAndPlan:   return "Fertig"
        }
    }

    private var primaryActionIcon: String {
        step == .preferencesAndPlan ? "checkmark.circle.fill" : "arrow.right"
    }

    private var canAdvance: Bool {
        switch step {
        case .healthConnect:
            // HealthKit ist optional — immer weiter erlaubt.
            return true
        case .personalInfo:
            return validatePersonalInfo()
        case .coachingStyle:
            // Tone + Goal haben Defaults und Cards sind tap-stateful, also
            // nie wirklich "ungeloest" — immer weiter.
            return true
        case .equipmentPreferences:
            // DEL-170b: leer ist erlaubt (= "Standard-Variante" beim Plan-
            // Adopt). User darf bewusst skippen, deshalb keine Pflicht.
            return true
        case .preferencesAndPlan:
            // Plan + Reminder sind beide optional — immer fertig erlaubt.
            return true
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .healthConnect, .personalInfo, .coachingStyle, .equipmentPreferences:
            goToNextStep()
        case .preferencesAndPlan:
            finishOnboarding()
        }
    }

    private func goToNextStep() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func goToPreviousStep() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    // MARK: - Validation

    private func validatePersonalInfo() -> Bool {
        guard let heightCm, Self.heightRange.contains(heightCm) else { return false }
        guard let currentWeightKg, Self.weightRange.contains(currentWeightKg) else { return false }
        if let goalWeightKg, !Self.weightRange.contains(goalWeightKg) { return false }
        return true
    }

    // MARK: - HealthKit pre-fill

    private func pullHealthKitSnapshot() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()

        // Apply snapshot — only fill fields the user hasn't already touched.
        // We're still on step 1, fields haven't been visible yet, so they're
        // all empty defaults at this point. Defensive overwrite-only-if-empty
        // keeps the code safe if this is called multiple times.
        //
        // DEL-024: birthDate-Gate frueher per `== defaultBirthDate`-Equality
        // gemacht. Das schlug fehl, weil defaultBirthDate jedes Mal mit
        // frischem Date() berechnet wurde und um Millisekunden differiert.
        // Stattdessen: explizites `birthDateWasEdited`-Flag, das nur per
        // DatePicker-onChange auf true gesetzt wird.
        if let dob = snapshot.dateOfBirth, !birthDateWasEdited {
            birthDate = dob
        }
        switch snapshot.sex {
        case .male:    profileSex = .male
        case .female:  profileSex = .female
        case .other, .notSet: break
        }
        if heightCm == nil, let hc = snapshot.heightCm { heightCm = hc }
        if currentWeightKg == nil, let wk = snapshot.weightKg { currentWeightKg = wk }

        healthKitDataLoaded = true
    }

    // MARK: - Finish + save

    private func finishOnboarding() {
        guard let heightCm, let currentWeightKg else { return }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        // 1) UserBodyProfile. DEL-101: Coaching-Style + TrainingGoal werden
        //    aus den Onboarding-State-Vars persistiert; sind in der
        //    ProfileEditorView spaeter editierbar.
        // DEL-141: Vorname trimmen + auf nil normalisieren wenn leer.
        // Verhindert dass " " oder "" als sentinel im Model landet —
        // Dashboard-Greeting unterscheidet sauber nil vs. non-nil.
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameForProfile: String? = trimmedName.isEmpty ? nil : trimmedName

        let profile = UserBodyProfile(
            birthDate: birthDate,
            heightCm: heightCm,
            profile: profileSex,
            firstName: nameForProfile,
            goalWeightKg: goalWeightKg,
            environment: environment,
            coachingTone: coachingTone,
            trainingGoal: trainingGoal,
            // DEL-170b: User-Equipment aus dem Multi-Select-Step. Leer =
            // Standard-Variante beim ersten Plan-Adopt (Backward-Compat-Pfad).
            equipmentPreferences: equipmentPreferences
        )
        modelContext.insert(profile)

        // 2) Initial BodyMeasurement — keeps the "first weight" visible in the
        //    Trend-Chart right after onboarding, instead of an empty dashboard
        //    until the user adds another measurement manually.
        let measurement = BodyMeasurement.makeDerived(
            ageYears: age,
            weightKg: currentWeightKg,
            heightCm: heightCm,
            profile: profileSex
        )
        modelContext.insert(measurement)

        // 3) Plan-Template (optional). ProgramInstantiator deaktiviert
        //    automatisch andere Pläne — bei einem frischen Profil eh leer.
        // DEL-088: `selectedWeekdays` kommt aus dem DayPickerSheet. Wenn der
        //    User direkt "Fertig" ohne Plan drueckt, ist die Liste leer und
        //    der Instantiator nutzt seine Defaults (defaultWeekdays(for:)).
        if let template = selectedTemplate {
            // DEL-170b: User-Equipment direkt aus dem Onboarding-State —
            // greift sofort beim ersten Plan-Adopt (Hybrid → DB-Variante etc.).
            ProgramInstantiator.instantiate(
                template,
                in: modelContext,
                selectedWeekdays: selectedWeekdays.isEmpty ? nil : selectedWeekdays,
                userEquipment: equipmentPreferences
            )
        }

        // 4) Notification-Präferenzen persistieren. Permission wird angefordert,
        //    wenn mindestens einer der Toggles aktiv ist.
        UserDefaults.standard.set(enableWaterReminder, forKey: "pref_water_reminder")
        UserDefaults.standard.set(enableMeasurementReminder, forKey: "pref_measurement_reminder")

        if enableWaterReminder || enableMeasurementReminder {
            Task { await prNotifications.requestAuthorization() }
        }

        // RootView's @Query auf [UserBodyProfile] beobachtet die Insert
        // und swappt automatisch auf MainTabView — kein Navigation-Push nötig.
    }

    // MARK: - Helpers + constants

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>) -> some View {
        TextField(value: value, format: .number, prompt: Text(label)) {
            Text(label)
        }
        .decimalKeyboard()
    }

    private static let heightRange: ClosedRange<Double> = 100...250
    private static let weightRange: ClosedRange<Double> = 20...400

    /// Default to "30 years ago today" — sensibler Mid-point für unbekannten User.
    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    /// Plausibler Lower-Bound für den DatePicker (~125 Jahre).
    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Onboarding (leer)") {
    OnboardingView()
        .modelContainer(PreviewSeed.emptyContainer)
        .environment(HealthKitController())
        .environment(PRNotificationCenter())
}
#endif
#endif
