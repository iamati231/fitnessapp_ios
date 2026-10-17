#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities
import UniformTypeIdentifiers

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
    /// UX-Fix "Umbrueche und Badge-Saettigung": steuert, ob Plan-Zeilen bei
    /// grosser Schrift (Accessibility-Groessen) auf ein vertikales,
    /// fuehrend ausgerichtetes Layout umschalten statt Icon und Text in
    /// einer engen HStack zu quetschen.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Step: Int, CaseIterable {
        case healthConnect
        case personalInfo
        case coachingStyle           // DEL-101: Goal + Tone in einem Schritt
        case trainingHistory         // Fix "doppeltes Onboarding": ExperienceTrack-Herleitung
        case equipmentPreferences    // DEL-170b: Multi-Select Equipment
        case baselineCheck           // Start-Check-Epic: optionaler "Wo stehst du heute?"-Check
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

    /// DEL-207: Wochenziel (DEL-203) jetzt schon im Onboarding wählbar —
    /// der Kalender-Streak zählt ab Tag 1 gegen dieses Ziel. Default 3 =
    /// realistischer Median; der ProfileEditor kann es später ändern.
    ///
    /// Fix "doppeltes Onboarding": dient zusätzlich als `preferredDays` für
    /// `PlanMatchmaker` — eine zweite "wie oft willst du trainieren"-Frage
    /// nur für die Plan-Auswahl wäre exakt die Redundanz, die dieser Fix
    /// beseitigt.
    @State private var weeklyGoal: Int = 3

    // Fix "doppeltes Onboarding": Trainingshistorie-Schritt. Ersetzt die
    // bisherige, separate ExperienceLevel-Selbsteinschätzung im Quiz —
    // `ExperienceTrack` wird aus Verhalten/Pausenlänge hergeleitet statt
    // erfragt zu werden (siehe `ExperienceTrackResolver`).
    @State private var trainingHistoryAnswer: TrainingHistoryAnswer?
    @State private var pauseLength: PauseLength = .sixToTwelveWeeks
    @State private var priorExperienceDuration: PriorExperienceDuration = .underOneYear

    // Start-Check-Epic: optionaler "Wo stehst du heute?"-Check. `nil` =
    // weder getestet noch selbst eingeschaetzt noch bewusst uebersprungen —
    // `finishOnboarding()` schreibt nur bei einem Nicht-nil-Ergebnis in
    // `UserBodyProfile.baselineAssessment`, sonst bleibt es dort ebenfalls
    // `nil` (identisch zum Bestandsnutzer-Zustand, siehe Epic: "Alte Nutzer:
    // keine Baseline = unknown").
    @State private var baselineAssessmentResult: BaselineAssessment?
    @State private var showingBaselineCheck: Bool = false
    @State private var baselineEntryMode: BaselineCheckFlowView.EntryMode = .guidedTest

    // Smart-Onboarding-Epic Phase 3 (PLAN_EQUIPMENT_MATCHING_AUDIT.md):
    // dreiwertige Equipment-Erfassung. Bewusst OHNE Environment-Prefill —
    // "Ort ist nicht Ausstattung" (Audit 5.1): "Gym"/"Home-Gym" duerfen nie
    // automatisch Equipment als vorhanden markieren. Kein Profil existiert
    // hier noch, daher lokaler State statt direkt `UserBodyProfile` —
    // `finishOnboarding()` uebertraegt beides auf das neu angelegte Profil.
    @State private var equipmentProfile: UserEquipmentProfile = UserEquipmentProfile()
    @State private var equipmentProfileConfirmedComplete: Bool = false
    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1): steuert das optionale "Ausstattung anpassen"-Sheet im Gym-Pfad —
    /// dort gibt es KEINEN Pflichtschritt, der Editor ist nur bei Bedarf
    /// erreichbar.
    @State private var showingGymEquipmentSheet: Bool = false

    /// Rueckwaerts-Kompatibilitaets-Bruecke zur aelteren `Equipment`-Menge
    /// (DEL-170, weiterhin von `PlanMatchmaker`/`ProgramInstantiator`/
    /// `BaselineCheckFlowView` konsumiert). Liefert `[]` ("nicht gepflegt",
    /// bestehendes Verhalten) solange der Nutzer die Erfassung NICHT
    /// bestaetigt hat — sonst wuerde eine unvollstaendige Zwischenauswahl
    /// (z.B. "erst 2 von 10 Kategorien angetippt") den bestehenden
    /// Equipment-Hartfilter verfrueht scharf schalten, obwohl der Nutzer die
    /// Erfassung noch gar nicht abgeschlossen hat (Audit-Vorgabe: "kein
    /// pauschales 'Equipment passend' aus den neuen Angaben ableiten,
    /// solange Katalog-Erfassung und Planpruefung unvollstaendig sind").
    private var derivedLegacyEquipment: Set<Equipment> {
        equipmentProfileConfirmedComplete ? equipmentProfile.legacyEquipmentPreferences : []
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1/§4): EINE Berechnung des effektiven Planungskontexts — Vorschau
    /// (`previewingTemplate`-Sheet) UND `finishOnboarding()` verwenden
    /// exakt diesen, nie das rohe `equipmentProfile` direkt, sobald der Ort
    /// Gym ist und keine individuelle Erfassung abgeschlossen wurde.
    private var equipmentPlanningContext: EquipmentPlanningContext {
        EquipmentPlanningResolver.resolve(
            environment: environment, individualProfile: equipmentProfile,
            confirmedComplete: equipmentProfileConfirmedComplete
        )
    }

    // Step 4 — Präferenzen + Plan
    @State private var enableWaterReminder: Bool = true
    @State private var enableMeasurementReminder: Bool = true
    @State private var selectedTemplate: ProgramTemplate?

    /// Smart-Onboarding-Epic Phase 5.4 (PLAN_SUBSTITUTION_ENGINE.md Abschnitt
    /// 4): die exakte, in der Vorschau gezeigte Auswahl (Basis/Variante,
    /// ggf. mit Substitutionen) — `finishOnboarding()` instanziiert GENAU
    /// das hier, nie eine neu abgeleitete Variante.
    @State private var resolvedPlanSelection: ResolvedPlanSelection?

    /// DEL-056: Tap auf einen Template-Row oeffnet eine Detail-Vorschau in
    /// einem Sheet. Erst der "Diesen Plan waehlen"-Button im Detail finalisiert
    /// die Auswahl (`selectedTemplate = ...` + Onboarding-Finish).
    @State private var previewingTemplate: ProgramTemplate?

    // DEL-243: dritte Alternative
    // neben Template-Liste und Quiz. `PlanBuilderView(onGenerated:)`
    // liefert Input + Ergebnis nur zurueck, statt selbst zu instanziieren
    // (siehe dortige Typ-Doku) - `finishOnboarding()` baut den Plan dann
    // ZUSAMMEN mit dem UserBodyProfile, exakt wie beim Template-Pfad.
    // `selectedTemplate` und dieses Paar schliessen sich gegenseitig aus
    // (siehe `clearCustomPlan()`/`clearSelectedTemplate()`).
    @State private var showingPlanBuilder: Bool = false
    @State private var customPlanInput: PlanGeneratorInput?
    @State private var customPlanResult: PlanGenerator.Result?

    // DEL-088: Tag-Auswahl-Sheet, das nach Plan-Adopt erscheint. Sobald
    // `dayPickerTemplate != nil`, oeffnet sich das DayPickerSheet mit dem
    // dort hinterlegten Template. `onConfirm` setzt `selectedWeekdays` und
    // ruft finishOnboarding() auf.
    @State private var dayPickerTemplate: ProgramTemplate?

    /// DEL-088: Vom User gewaehlte Wochentage (Apple-Calendar-Index, Mo-first).
    /// Leeres Array = Caller hat noch keine Auswahl getroffen — Instantiator
    /// fallback'd auf seine Defaults (siehe `ProgramInstantiator.defaultWeekdays`).
    @State private var selectedWeekdays: [Int] = []

    // DEL-194: Backup-Import direkt aus dem Onboarding. Bestehende Deltiq-
    // Nutzer (neues Gerät / Neuinstallation) sollen ihr ZIP einspielen
    // können, ohne das komplette Onboarding manuell durchzuklicken. Nach
    // erfolgreichem Import (mit Profil) wechselt RootView automatisch zur
    // MainTabView, weil die @Query<UserBodyProfile> dann nicht mehr leer ist.
    @State private var showingBackupImporter = false
    @State private var backupImportError: String?
    @State private var backupImportRunning = false

    /// Settings-Epic Phase 4 (docs/SETTINGS_UX_AUDIT.md, Befund REM-02):
    /// seedet die Reminder-Toggles aus bereits gespeicherten Praeferenzen
    /// statt sie hart auf `true` zu setzen. Bei einem GENUINEN Erst-
    /// Onboarding liefert `ReminderPreferences.load()` exakt dieselben
    /// Vorgabewerte (keine Keys vorhanden) — unveraendertes Verhalten. Bei
    /// einem ERZWUNGENEN Re-Onboarding (z.B. nach "App zuruecksetzen", das
    /// diese Keys bewusst NICHT loescht) wuerde `finishOnboarding()` weiter
    /// unten sonst die erhaltene Praeferenz mit dem hartkodierten
    /// Vorgabewert ueberschreiben, sobald der User die Toggles hier
    /// unveraendert laesst — genau der Bruch, den die Reset-Zusage
    /// ausschliesst.
    public init() {
        let existingReminderPreferences = ReminderPreferences.load()
        _enableWaterReminder = State(initialValue: existingReminderPreferences.waterEnabled)
        _enableMeasurementReminder = State(initialValue: existingReminderPreferences.measurementEnabled)
    }

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
                    case .trainingHistory:      trainingHistoryStep
                    case .equipmentPreferences: equipmentPreferencesStep
                    case .baselineCheck:        baselineCheckStep
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
            // Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_
            // ONBOARDING.md §1, Abschnitt 4): bei einem Ortswechsel bleibt
            // `equipmentProfile` selbst unangetastet ("nicht automatisch
            // loeschen oder ueberschreiben" — bisherige Angaben bleiben
            // vorausgefuellt), aber eine bereits abgeschlossene Bestaetigung
            // gilt NICHT automatisch fuer den neuen Ort weiter ("klaeren, ob
            // diese auch am neuen Ort gelten") — der jeweilige Equipment-
            // Schritt (Gym-Hinweis/Home-Gym-Editor/Kein-Equipment-Kurzfrage)
            // verlangt dadurch eine frische Bestaetigung fuer den neuen Ort.
            .onChange(of: environment) { _, _ in
                equipmentProfileConfirmedComplete = false
            }
            // DEL-056: Plan-Detail-Sheet. Wird auf Step 3 geoeffnet, wenn der
            // User einen Template-Row antippt. Adopt-Button finalisiert die
            // Auswahl und triggert direkt das Onboarding-Finish — sonst
            // muesste der User noch ein zweites Mal auf "Fertig" tippen.
            .sheet(item: $previewingTemplate) { template in
                NavigationStack {
                    TemplatePreviewView(
                        template: template,
                        adoptButtonTitle: "Diesen Plan wählen",
                        userEquipmentProfile: equipmentPlanningContext.effectiveProfile,
                        goal: trainingGoal,
                        experienceTrack: resolvedExperienceTrack,
                        isEquipmentAssumption: equipmentPlanningContext.isAssumption
                    ) { selection in
                        // DEL-088: Adopt finalisiert die Plan-Wahl noch nicht
                        // direkt — stattdessen oeffnet sich der DayPicker,
                        // damit der User die Trainings-Wochentage festlegt.
                        // Smart-Onboarding-Epic Phase 5.4: die exakte
                        // Vorschau-Auswahl (ggf. substituiert) wird fuer
                        // `finishOnboarding()` gemerkt statt dort erneut
                        // hergeleitet (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 4).
                        selectedTemplate = template
                        resolvedPlanSelection = selection
                        previewingTemplate = nil
                        dayPickerTemplate = template
                        // DEL-243: ein
                        // zuvor gebauter Custom-Plan wird verworfen, sobald
                        // sich der User stattdessen fuer ein Template
                        // entscheidet - beide Wege schliessen sich aus.
                        clearCustomPlan()
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
            // DEL-243: dritte
            // Alternative zu Template-Liste/Quiz. `onGenerated` liefert
            // Input+Result nur zurueck (siehe Typ-Doku in PlanBuilderView) —
            // finishOnboarding() instanziiert den Plan zusammen mit dem
            // UserBodyProfile, kein DayPicker noetig (Step 2 des Builders
            // deckt Wochentage/Equipment bereits ab).
            //
            // P0-Audit (neue Spezifikation): vorher musste der User nach dem
            // Schliessen dieses Sheets zusaetzlich noch separat den Footer-
            // Button "Fertig" treffen — ein zweiter, uneinheitlicher
            // Finish-Trigger gegenueber `DayPickerSheet.onConfirm` (siehe
            // unten), das `finishOnboarding()` direkt in seinem `onConfirm`
            // aufruft. `finishOnboarding()` jetzt ebenso direkt HIER
            // aufzurufen vereinheitlicht beide Pfade auf eine Hauptaktion;
            // `heightCm`/`currentWeightKg` sind an dieser Stelle immer
            // gesetzt, da der Builder nur vom letzten Schritt
            // (`.preferencesAndPlan`) aus erreichbar ist, dessen Vorschritt
            // (`.personalInfo`) `canAdvance` bereits erzwungen hat.
            .sheet(isPresented: $showingPlanBuilder) {
                // Nachbesserung (dritte Korrekturrunde, Punkt 4): `onGenerated` liefert
                // `PlanBuilderHandoffOutcome` zurueck (siehe PlanBuilderView-Typ-Doku). Reines
                // `@State`-Zwischenspeichern kann strukturell nicht fehlschlagen - immer `.success`.
                //
                // Korrektur (vierte Korrekturrunde, Punkt 1): diese Aufrufstelle wurde beim
                // Wechsel von `String?` auf `PlanBuilderHandoffOutcome` uebersehen - `return nil`
                // kompiliert auf Linux trotzdem, weil die gesamte Datei hinter
                // `#if canImport(SwiftUI)` liegt (auf Linux `false`) und ein inaktiver `#if`-Zweig
                // dort nur noch syntaktisch, nie mehr semantisch/typgeprueft wird (empirisch
                // verifiziert, siehe Typ-Doku-Praezisierung in docs/PLANUNG_BEGLEITUNG_AUDIT.md).
                // Alle vier `PlanBuilderView(`-Aufrufstellen im Repo wurden daraufhin erneut
                // per Grep geprueft - dies war die einzige verbleibende.
                //
                // P0-Audit (neue Spezifikation, Dok02 §1 "kein eigener
                // Onboarding-Generator, keine doppelte Abfrage"): `selections`
                // bleibt leer (Onboarding fragt keine Trainingsarten/Tage/
                // Dauer ab - das bleibt Schritt 1 des Builders vorbehalten),
                // aber `equipmentPreferences` wird aus den bereits erfassten
                // Onboarding-Antworten vorbefuellt, damit Schritt 2 des
                // eingebetteten Builders die Ausstattung nicht ein zweites
                // Mal von Null abfragt.
                PlanBuilderView(initialInput: PlanGeneratorInput(
                    selections: [],
                    equipmentPreferences: derivedLegacyEquipment,
                    usesFixedWeekdays: false
                )) { input, result in
                    customPlanInput = input
                    customPlanResult = result
                    clearSelectedTemplate()
                    finishOnboarding()
                    return .success
                }
            }
            // Start-Check-Epic: Sheet fuer den optionalen "Wo stehst du
            // heute?"-Check. `onFinish(nil)` (Abbruch/Sheet weggewischt)
            // laesst ein vorhandenes `baselineAssessmentResult` bewusst
            // unangetastet statt es zu loeschen.
            .sheet(isPresented: $showingBaselineCheck) {
                BaselineCheckFlowView(
                    entryMode: baselineEntryMode,
                    goal: trainingGoal,
                    equipmentPreferences: derivedLegacyEquipment
                ) { result in
                    if let result {
                        baselineAssessmentResult = result
                    }
                }
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

                Spacer(minLength: 24)

                // DEL-194: Dezenter Backup-Import-Einstieg für bestehende
                // Nutzer. Bewusst unaufdringlich am unteren Rand — Neu-User
                // ignorieren es, Wiederkehrer finden ihren Shortcut.
                backupImportEntry

                Spacer(minLength: 16)
            }
            .padding(.horizontal)
        }
    }

    /// DEL-194: Backup-Import-Einstieg. Trennlinie + Hinweistext + Button,
    /// der den ZIP-Picker öffnet. Bei Erfolg wechselt RootView automatisch.
    @ViewBuilder
    private var backupImportEntry: some View {
        VStack(spacing: 10) {
            Divider()
            Text("onboarding.import.prompt", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if backupImportRunning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("onboarding.import.running", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showingBackupImporter = true
                } label: {
                    Label {
                        Text("onboarding.import.button", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(Color.deltiqOrange)
            }

            if let backupImportError {
                Text(backupImportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
        #if os(iOS)
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handleBackupImport(result)
        }
        #endif
    }

    /// DEL-194: Liest das gewählte ZIP, kopiert es Security-Scope-sicher in
    /// Caches und ruft den DataImportService im Append-Modus. Während des
    /// Onboardings ist die DB leer → alle Datensätze kommen frisch rein,
    /// kein Replace nötig. Nach erfolgreichem Profil-Import swappt RootView.
    private func handleBackupImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            backupImportError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let zipData = try Data(contentsOf: url)
                backupImportError = nil
                backupImportRunning = true
                let ctx = modelContext
                Task {
                    do {
                        // Library muss vor dem Import geseedet sein, damit
                        // FK-/Snapshot-Lookups greifen — RootView seedet beim
                        // Launch, hier defensiv nochmal anstoßen.
                        LibrarySeeder.seedIfNeeded(in: ctx)
                        // Settings-Epic Phase 5 (Befund DI-03/DI-09): der
                        // Service ist jetzt `async` — Entpacken/Parsen laeuft
                        // off-Main, die SwiftData-Schreibphase bleibt
                        // `@MainActor`.
                        let importResult = try await DataImportService.performImport(
                            zipData: zipData,
                            context: ctx,
                            strategy: .appendOnly
                        )
                        // Nachgetragene Laeufe aus einer Sicherung vor dem Dauer-Fix
                        // (1-2 Min statt der eingetragenen Laufzeit) nachziehen.
                        SessionDurationRepair.repairAfterImport(in: ctx)
                        // Kein expliziter Navigations-Schritt nötig:
                        // RootView.@Query<UserBodyProfile> ist nach dem
                        // Profil-Insert nicht mehr leer → MainTabView.
                        await MainActor.run { backupImportRunning = false }

                        // Die importierten Erinnerungs-Schalter (settings.csv)
                        // wirksam machen: wie am Ende des normalen Onboardings
                        // erst die Berechtigung klaeren, dann planen. Auf einem
                        // frisch installierten Geraet existieren die geplanten
                        // Benachrichtigungen des alten nicht mehr. Nur wenn das
                        // Backup ein Profil mitgebracht hat - sonst bleibt der
                        // Nutzer im Onboarding, und `finishOnboarding` plant
                        // nach seiner eigenen Auswahl (ein Berechtigungsdialog
                        // mitten in Schritt 1 waere dort fehl am Platz).
                        guard (importResult.imported["profile.csv"] ?? 0) > 0 else { return }
                        let reminders = ReminderPreferences.load()
                        if reminders.waterEnabled || reminders.measurementEnabled {
                            await prNotifications.requestAuthorization()
                        }
                        await ReminderPreferencesApplier.applyStoredSchedules()
                    } catch {
                        await MainActor.run {
                            backupImportRunning = false
                            backupImportError = error.localizedDescription
                        }
                    }
                }
            } catch {
                backupImportError = error.localizedDescription
            }
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
                decimalField(String(localized: "onboarding.field.weightCurrentKg", bundle: .module), value: $currentWeightKg, roundsToWeightPrecision: true)
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
                decimalField(String(localized: "onboarding.field.goalWeightKg", bundle: .module), value: $goalWeightKg, roundsToWeightPrecision: true)
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
                        // Review-Korrektur nach P2.2: `.endurance` ist noch
                        // nicht ueber die UI waehlbar, siehe
                        // `TrainingGoal.currentlySelectableInUI`.
                        ForEach(TrainingGoal.currentlySelectableInUI, id: \.self) { goal in
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

                // ──────────── DEL-207: Wochenziel ────────────
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("onboarding.weeklyGoal.title", bundle: .module)
                            .font(.title2.weight(.bold))
                        Text("onboarding.weeklyGoal.subtitle", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Stepper(value: $weeklyGoal, in: 1...7) {
                        HStack {
                            Label {
                                Text("profile.weeklyGoal.label", bundle: .module)
                            } icon: {
                                Image(systemName: "flame")
                                    .foregroundStyle(Color.deltiqOrange)
                            }
                            Spacer()
                            Text("\(weeklyGoal)×")
                                .font(.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Trainingshistorie (Fix "doppeltes Onboarding")

    /// Ersetzt die fruehere separate ExperienceLevel-Selbsteinschaetzung im
    /// entfernten Quiz: statt "wie erfahren bist du" (Technik-Selbstauskunft)
    /// fragt dieser Schritt nach Verhalten/Pausenlaenge — genau die Achse,
    /// die `ExperienceTrackResolver` in `ExperienceTrack` (starter/returner/
    /// experienced) uebersetzt. Diese Antwort speist sowohl den Coaching-
    /// Track (`UserBodyProfile.experienceTrack`) als auch, ueber
    /// `asExperienceLevel`, den Plan-Matching-Score — keine zweite, separate
    /// Erfahrungs-Frage mehr noetig.
    @ViewBuilder
    private var trainingHistoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.history.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.history.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    ForEach(TrainingHistoryAnswer.allCases, id: \.self) { answer in
                        coachingCard(
                            title: String(localized: answer.localizedName),
                            description: String(localized: answer.localizedBlurb),
                            iconName: answer.symbol,
                            isSelected: trainingHistoryAnswer == answer
                        ) {
                            trainingHistoryAnswer = answer
                        }
                    }
                }

                // Folgefrage A: nur bei "lange Pause" — kalibriert spaeter
                // die Wiedereinstiegs-Rampe (nicht Teil dieser Phase).
                if trainingHistoryAnswer == .longBreakAfterTraining {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("onboarding.history.pauseLength.title", bundle: .module)
                            .font(.headline)
                        Picker(selection: $pauseLength) {
                            ForEach(PauseLength.allCases, id: \.self) { length in
                                Text(length.localizedName).tag(length)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Folgefrage B: nur bei "unregelmaessig" — unterscheidet
                // "noch keine 3 Monate am Stueck geschafft" (eher Starter)
                // von "jahrelange Erfahrung, nur gerade unregelmaessig".
                if trainingHistoryAnswer == .trainingIrregularly {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("onboarding.history.priorExperience.title", bundle: .module)
                            .font(.headline)
                        Picker(selection: $priorExperienceDuration) {
                            ForEach(PriorExperienceDuration.allCases, id: \.self) { duration in
                                Text(duration.localizedName).tag(duration)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Hergeleiteter Coaching-Track aus der Trainingshistorie-Antwort. `nil`
    /// nur, solange der User die Hauptfrage noch nicht beantwortet hat
    /// (`canAdvance` blockt den Schritt dafuer) — ab dem Plan-Schritt also
    /// praktisch immer gesetzt.
    private var resolvedExperienceTrack: ExperienceTrack? {
        guard let trainingHistoryAnswer else { return nil }
        return ExperienceTrackResolver.track(for: trainingHistoryAnswer, priorExperience: priorExperienceDuration)
    }

    // MARK: - Step 4: Equipment-Erfassung (Smart-Onboarding-Epic Phase 3/6)

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1): der Inhalt dieses Schritts haengt jetzt vom gewaehlten
    /// Trainingsort ab — Gym bekommt KEINEN Pflichtschritt mehr (nur einen
    /// Hinweis + optionales Sheet), Home-Gym den vollen Editor, Kein
    /// Equipment eine kurze Frage. "Ort ist nicht Ausstattung" bleibt in
    /// allen drei Faellen gueltig: kein Pfad leitet aus dem Ort allein eine
    /// BESTAETIGTE Verfuegbarkeit her.
    @ViewBuilder
    private var equipmentPreferencesStep: some View {
        switch environment {
        case .gym:         gymEquipmentStep
        case .homeGym:      homeGymEquipmentStep
        case .noEquipment: noEquipmentQuickStep
        }
    }

    /// Kein Pflichtschritt: Hinweis auf die Standard-Gym-Planungsannahme
    /// (`EquipmentPlanningResolver`, PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §2/§4) + optionales Sheet mit dem vollen Editor. NIE "Equipment
    /// bestätigt" zeigen, solange `equipmentProfileConfirmedComplete ==
    /// false` — das waere eine vom Ort hergeleitete, nicht vom User
    /// bestaetigte Aussage.
    @ViewBuilder
    private var gymEquipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.equipment.gym.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.equipment.gym.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if equipmentProfileConfirmedComplete {
                    gymEquipmentConfirmedCard
                } else {
                    Button {
                        showingGymEquipmentSheet = true
                    } label: {
                        Label {
                            Text("onboarding.equipment.gym.adjustButton", bundle: .module)
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("onboarding.equipment.gym.footer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .sheet(isPresented: $showingGymEquipmentSheet) {
            gymEquipmentSheet
        }
    }

    /// Nach einer abgeschlossenen individuellen Erfassung (via Sheet) —
    /// identischer Stil zur bestehenden `baselineCapturedSummary` (Start-
    /// Check-Epic), damit "erfasst/bestaetigt"-Karten app-weit gleich aussehen.
    private var gymEquipmentConfirmedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("onboarding.equipment.gym.confirmedTitle", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.headline)
            .foregroundStyle(.green)

            Button {
                showingGymEquipmentSheet = true
            } label: {
                Text("onboarding.equipment.gym.editButton", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var gymEquipmentSheet: some View {
        NavigationStack {
            ScrollView {
                EquipmentProfileEditor(equipmentProfile: $equipmentProfile)
                    .padding()
            }
            .navigationTitle(String(localized: "onboarding.equipment.gym.sheetTitle", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close", bundle: .module)) {
                        showingGymEquipmentSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", bundle: .module)) {
                        confirmEquipmentStepIfNeeded()
                        showingGymEquipmentSheet = false
                    }
                }
            }
        }
    }

    /// Unveraendertes Phase-3-Verhalten: voller Editor, "Später
    /// einrichten"-Link laesst alles `.unknown`. Die "vollstaendige
    /// Bestaetigung" (nicht ausgewaehlte Items werden zu `.unavailable`)
    /// passiert NICHT hier, sondern wenn der User unten auf "Weiter" tippt
    /// (`handlePrimaryAction`).
    @ViewBuilder
    private var homeGymEquipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.equipment.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.equipment.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                EquipmentProfileEditor(equipmentProfile: $equipmentProfile)

                Text("onboarding.equipment.footer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                laterLinkButton
            }
            .padding()
        }
    }

    /// Smart-Onboarding-Epic Phase 6 §1: kurze Frage statt des vollen
    /// Editors — "Nein, nur Körpergewicht" bleibt Teil der Dateneingabe
    /// (`NoEquipmentQuickEquipmentPicker`), "Später entscheiden" bleibt eine
    /// Navigations-Entscheidung dieses Schritts (identisches Prinzip wie
    /// beim Home-Gym-Editor).
    @ViewBuilder
    private var noEquipmentQuickStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.equipment.noEquipment.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text("onboarding.equipment.noEquipment.subtitle", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                NoEquipmentQuickEquipmentPicker(equipmentProfile: $equipmentProfile)

                Text("onboarding.equipment.footer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                laterLinkButton
            }
            .padding()
        }
    }

    /// "Später einrichten"/"Später entscheiden" — identisch fuer Home-Gym
    /// und Kein-Equipment, ruft `goToNextStep()` bewusst DIREKT auf (siehe
    /// `confirmEquipmentStepIfNeeded` Dokumentation), damit die Erfassung
    /// wirklich `.unknown` bleibt statt stillschweigend bestaetigt zu werden.
    private var laterLinkButton: some View {
        Button {
            goToNextStep()
        } label: {
            Text("onboarding.equipment.laterLink", bundle: .module)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    /// Smart-Onboarding-Epic Phase 3: die "vollstaendige Bestaetigung" fuer
    /// den regulaeren "Weiter"-Pfad (siehe `handlePrimaryAction`) — alles,
    /// was der Nutzer nicht aktiv ausgewaehlt hat, wird jetzt explizit
    /// `.unavailable`. Der separate "Später einrichten"-Link im Step oben
    /// ruft das bewusst NICHT auf (`goToNextStep()` direkt), damit dort
    /// wirklich alles `.unknown` bleibt.
    private func confirmEquipmentStepIfNeeded() {
        equipmentProfile.confirmRemainingAsUnavailable()
        equipmentProfileConfirmedComplete = true
    }

    // MARK: - Start-Check (Optionaler "Wo stehst du heute?"-Check)

    /// Platzierung laut Epic: nach Trainingshistorie/Equipment, vor
    /// Zeitbudget/Plan-Ergebnis. Starter/Wiedereinsteiger sehen den vollen,
    /// gleichwertigen 3-Wege-Einstieg ("Kurz testen" / "Selbst einschaetzen" /
    /// "Spaeter entscheiden" — UX-Fix "Einladung statt Pruefung", keiner der
    /// drei Wege optisch hervorgehoben), Erfahrene nur einen kompakten
    /// optionalen Link OHNE gefuehrten
    /// Test-Track (Epic: Erfahrene bekommen keinen Test-Track vorgesetzt) —
    /// der Link oeffnet `BaselineCheckFlowView` direkt mit
    /// `entryMode: .selfAssessment`, derselben Weiche wie der "Selbst
    /// einschaetzen"-Pfad der Starter/Wiedereinsteiger. Nie ein Gate:
    /// `canAdvance` ist fuer diesen Schritt immer `true`.
    @ViewBuilder
    private var baselineCheckStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("baseline.step.title", bundle: .module)
                        .font(.title2.weight(.bold))
                    Text(isFullBaselineTrack ? "baseline.step.subtitle" : "baseline.step.subtitle.compact", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let baselineAssessmentResult {
                    baselineCapturedSummary(baselineAssessmentResult)
                } else if isFullBaselineTrack {
                    VStack(spacing: 10) {
                        baselineChoiceRow(
                            icon: "figure.strengthtraining.traditional",
                            title: String(localized: "baseline.step.cta.test", bundle: .module),
                            subtitle: String(localized: "baseline.step.cta.test.subtitle", bundle: .module)
                        ) {
                            baselineEntryMode = .guidedTest
                            showingBaselineCheck = true
                        }
                        baselineChoiceRow(
                            icon: "hand.point.up.left",
                            title: String(localized: "baseline.step.cta.selfAssess", bundle: .module),
                            subtitle: String(localized: "baseline.step.cta.selfAssess.subtitle", bundle: .module)
                        ) {
                            baselineEntryMode = .selfAssessment
                            showingBaselineCheck = true
                        }
                        baselineChoiceRow(
                            icon: "arrow.right.circle",
                            title: String(localized: "baseline.step.cta.later", bundle: .module),
                            subtitle: String(localized: "baseline.step.cta.later.subtitle", bundle: .module)
                        ) {
                            goToNextStep()
                        }
                    }
                } else {
                    Button {
                        baselineEntryMode = .selfAssessment
                        showingBaselineCheck = true
                    } label: {
                        Label {
                            Text("baseline.step.cta.compactLink", bundle: .module)
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("baseline.step.disclaimer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Starter/Wiedereinsteiger bekommen den vollen gefuehrten Test-Track
    /// angeboten; Erfahrene nur den kompakten Link (Epic-Vorgabe). Ohne
    /// Antwort auf dem Trainingshistorie-Schritt (sollte durch `canAdvance`
    /// dort praktisch nie vorkommen) faellt dies konservativ auf den vollen
    /// Track zurueck statt Erfahrenen-Verhalten zu unterstellen.
    private var isFullBaselineTrack: Bool {
        resolvedExperienceTrack != .experienced
    }

    @ViewBuilder
    private func baselineCapturedSummary(_ result: BaselineAssessment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("baseline.step.done.title", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.headline)
            .foregroundStyle(.green)

            Button {
                baselineEntryMode = isFullBaselineTrack ? .guidedTest : .selfAssessment
                showingBaselineCheck = true
            } label: {
                Text("baseline.step.done.redo", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Einmalige Action-Zeile im selben visuellen Stil wie `coachingCard`,
    /// aber ohne persistente Selektion — jeder Tap oeffnet direkt das Sheet
    /// bzw. springt weiter, es gibt keinen "ausgewaehlten" Zustand.
    /// UX-Fix "Einladung statt Pruefung": alle drei Einstiegswege sind
    /// gleichwertig (kein `prominent`-Flag mehr, das einen Weg optisch als
    /// Pflicht ueber die Alternativen stellen wuerde) — siehe
    /// `docs/BASELINE_CHECK_UX.md` §1.
    private func baselineChoiceRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

            // Fix "doppeltes Onboarding": EIN Flow. Die Onboarding-Antworten
            // (Ziel, Track, Tage, Ort, Equipment) gehen direkt in
            // PlanMatchmaker.rankPlans — kein zweites Quiz mehr. Top-Match
            // zuerst als grosse Karte, dann 2-3 Alternativen, der Rest
            // eingeklappt.
            if let top = rankedTemplates.first {
                Section {
                    recommendedPlanCard(top)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    // UX-Fix "Empfehlung wirkt immer gleich" Punkt 5: eine
                    // reine Fallback-Notloesung (Hard-Filter haben ALLES
                    // rausgefiltert, siehe `PlanMatchmaker.rankPlansDetailed`)
                    // heisst ehrlich "beste verfuegbare Option" statt sich
                    // als "Empfehlung" auszugeben.
                    Text(rankedPlanResult.isFallback ? "onboarding.plan.fallbackRecommended" : "onboarding.plan.recommended", bundle: .module)
                } footer: {
                    Text(rankedPlanResult.isFallback ? "onboarding.plan.fallbackRecommendedFootnote" : "onboarding.plan.recommendedFootnote", bundle: .module)
                        .font(.footnote)
                }
            }

            let alternatives = Array(rankedTemplates.dropFirst().prefix(3))
            if !alternatives.isEmpty {
                Section {
                    ForEach(alternatives) { template in
                        Button {
                            previewingTemplate = template
                        } label: {
                            templateRow(template)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("onboarding.plan.alternatives", bundle: .module)
                }
            }

            let morePlans = Array(rankedTemplates.dropFirst(1 + alternatives.count))
            if !morePlans.isEmpty {
                Section {
                    DisclosureGroup {
                        ForEach(morePlans) { template in
                            Button {
                                previewingTemplate = template
                            } label: {
                                templateRow(template)
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        Text("onboarding.plan.morePlans", bundle: .module)
                    }
                }
            }

            // DEL-243: dritte
            // Alternative - oeffnet denselben 3-Schritte-Wizard wie der
            // Plus-Button in PlansListView (siehe PlanBuilderView.onGenerated-
            // Doku). Eigene Section statt Teil von "Empfohlen" oben, weil
            // "bauen" bewusst kein Vorschlag ist, sondern der Gegenentwurf dazu.
            Section {
                Button {
                    showingPlanBuilder = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("onboarding.plan.builderCard.title", bundle: .module)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("onboarding.plan.builderCard.subtitle", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if customPlanInput != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("onboarding.plan.builderSection", bundle: .module)
            } footer: {
                Text("onboarding.plan.builderCard.footnote", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    /// Fix "doppeltes Onboarding": die Antworten, mit denen der
    /// Plan-Schritt direkt `PlanMatchmaker.rankPlans` aufruft — `weeklyGoal`
    /// dient zugleich als `preferredDays`, eine zweite "wie oft"-Frage nur
    /// fuers Matching gaebe es sonst doppelt.
    private var planMatchAnswers: QuizAnswers {
        QuizAnswers(
            goal: trainingGoal,
            experience: (resolvedExperienceTrack ?? .experienced).asExperienceLevel,
            preferredDays: weeklyGoal,
            environment: environment,
            equipmentPreferences: derivedLegacyEquipment,
            // Smart-Onboarding-Epic Phase 4: das volle, lebende Profil geht
            // IMMER mit — auch vor der vollstaendigen Bestaetigung. Eine
            // unvollstaendige Erfassung liefert dadurch korrekt `.unknown`
            // (siehe PlanEquipmentChecker), nie einen verfruehten Ausschluss
            // UND nie ein stillschweigendes "passt schon".
            equipmentProfile: equipmentProfile
        )
    }

    /// Komplettes Matcher-Ergebnis samt Fallback-Kennzeichnung (UX-Fix
    /// "Empfehlung wirkt immer gleich" Punkt 5) fuer die aktuellen
    /// Onboarding-Antworten. `experienceTrack` filtert zusaetzlich reine
    /// Expertenplaene fuer Starter/Wiedereinsteiger komplett raus (siehe
    /// `PlanMatchmaker`).
    private var rankedPlanResult: PlanMatchmaker.RankedPlanResult {
        PlanMatchmaker.rankPlansDetailed(
            for: planMatchAnswers,
            templates: ProgramTemplates.all,
            experienceTrack: resolvedExperienceTrack
        )
    }

    /// Nach Score sortierte Templates — reine Bequemlichkeits-Projektion auf
    /// `rankedPlanResult.templates` fuer die bestehenden Aufrufstellen.
    private var rankedTemplates: [ProgramTemplate] {
        rankedPlanResult.templates
    }

    /// Grosse Hero-Karte fuer den Top-Match: Name/Tagline + 2-3 einzelne
    /// Checkmark-Begruendungszeilen (UX-Fix "Umbrueche und Badge-Saettigung":
    /// vorher EINE kommagetrennte Zeile — jetzt klar lesbare Einzelzeilen
    /// statt eines langen Fliesstexts), tippbar wie jede andere Plan-Zeile.
    @ViewBuilder
    private func recommendedPlanCard(_ template: ProgramTemplate) -> some View {
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: planMatchAnswers)
        Button {
            previewingTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: template.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.deltiqOrange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(template.displayTagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if selectedTemplate?.id == template.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
                recommendationReasonLines(reasons, template: template)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.deltiqOrange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.deltiqOrange.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Bis zu 3 einzelne Checkmark-Zeilen aus den tatsaechlichen Treffern —
    /// nie pauschal, nie eine Zeile wenn nichts zutrifft. Reihenfolge
    /// Ziel/Tage/Level folgt dem Spec-Beispiel ("Passt zu deinem Ziel: ...",
    /// "3 Trainingstage pro Woche", "Geeignet fuer deinen Wiedereinstieg").
    @ViewBuilder
    private func recommendationReasonLines(_ reasons: PlanMatchReasons, template: ProgramTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if reasons.goalMatch {
                reasonLine(String(localized: "onboarding.plan.reason.goal", bundle: .module))
            }
            if reasons.daysMatch {
                reasonLine(String(format: String(localized: "onboarding.plan.reason.days", bundle: .module), template.daysPerWeek))
            }
            if reasons.levelMatch {
                reasonLine(String(localized: "onboarding.plan.reason.level", bundle: .module))
            }
        }
    }

    private func reasonLine(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.deltiqOrange)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Alternative-Zeile (UX-Fix "Umbrueche und Badge-Saettigung"): 48x48-
    /// Icon, Titel/Tagline je max. 2 Zeilen, eine kompakte Metadatenzeile
    /// ("3 Tage · Einsteiger") und hoechstens EIN Highlight-Badge statt der
    /// fruehen festen Vier-Chip-HStack. Bei grosser Schrift (Accessibility-
    /// Groessen) schaltet die Zeile auf ein vertikales, fuehrend
    /// ausgerichtetes Layout um, damit Icon und zweizeiliger Text nicht in
    /// eine zu schmale HStack gequetscht werden.
    @ViewBuilder
    private func templateRow(_ template: ProgramTemplate) -> some View {
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: planMatchAnswers)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    templateRowIcon(template)
                    Spacer(minLength: 0)
                    templateRowCheckmark(template)
                }
                templateRowTextBlock(template, reasons: reasons)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                templateRowIcon(template)
                templateRowTextBlock(template, reasons: reasons)
                Spacer(minLength: 0)
                templateRowCheckmark(template)
            }
        }
    }

    private func templateRowIcon(_ template: ProgramTemplate) -> some View {
        Image(systemName: template.iconSystemName)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Color.accentColor.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func templateRowCheckmark(_ template: ProgramTemplate) -> some View {
        if selectedTemplate?.id == template.id {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        }
    }

    @ViewBuilder
    private func templateRowTextBlock(_ template: ProgramTemplate, reasons: PlanMatchReasons) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.displayName)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            Text(template.displayTagline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(templateMetadataLine(template))
                .font(.caption)
                .foregroundStyle(.tertiary)
            // UX-Fix "Umbrueche und Badge-Saettigung": hoechstens EIN
            // Highlight-Badge statt vier gleichwertiger Chips — Prioritaet
            // Ziel > Level > Equipment > Tage (Epic-Vorgabe).
            if let reason = highlightReason(for: reasons) {
                matchBadge(highlightBadgeText(reason))
            }
        }
    }

    /// "3 Tage · Einsteiger" — Trainingstage + der niedrigste (am wenigsten
    /// voraussetzungsreiche) Erfahrungs-Tag des Templates, damit die Zeile
    /// ehrlich die am leichtesten erreichbare Einstiegshuerde zeigt statt
    /// pauschal den hoechsten Tag.
    private func templateMetadataLine(_ template: ProgramTemplate) -> String {
        let level: ExperienceLevel = template.targetExperience.contains(.beginner) ? .beginner
            : template.targetExperience.contains(.intermediate) ? .intermediate
            : .advanced
        let fmt = String(localized: "onboarding.plan.metadataLine", bundle: .module)
        return String(format: fmt, template.daysPerWeek, String(localized: level.localizedName))
    }

    private enum PlanHighlightReason {
        case goal, level, equipment, days
    }

    /// Die EINE staerkste zutreffende Begruendung, Prioritaet Ziel > Level >
    /// Equipment > Tage (Epic-Vorgabe) — `nil` wenn nichts zutrifft, dann
    /// zeigt die Zeile gar kein Badge.
    private func highlightReason(for reasons: PlanMatchReasons) -> PlanHighlightReason? {
        if reasons.goalMatch { return .goal }
        if reasons.levelMatch { return .level }
        if reasons.equipmentMatch { return .equipment }
        if reasons.daysMatch { return .days }
        return nil
    }

    private func highlightBadgeText(_ reason: PlanHighlightReason) -> Text {
        switch reason {
        case .goal:      Text("onboarding.plan.goalMatch", bundle: .module)
        case .level:     Text("onboarding.plan.levelMatch", bundle: .module)
        case .equipment: Text("onboarding.plan.equipmentMatch", bundle: .module)
        case .days:      Text("onboarding.plan.daysMatch", bundle: .module)
        }
    }

    private func matchBadge(_ text: Text) -> some View {
        text
            .font(.caption.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.deltiqOrange.opacity(0.15))
            .foregroundStyle(Color.deltiqOrange)
            .clipShape(Capsule())
    }

    // DEL-243: Template-Pfad und
    // Custom-Plan-Pfad schliessen sich gegenseitig aus - jede Bestaetigung
    // des einen Pfads verwirft den bereits begonnenen anderen Pfad.
    private func clearCustomPlan() {
        customPlanInput = nil
        customPlanResult = nil
    }

    private func clearSelectedTemplate() {
        selectedTemplate = nil
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
            .disabled(!canAdvance || isFinishingOnboarding)
        }
    }

    /// DEL-207: vorher hartcodiert deutsch ("Weiter"/"Fertig") — die
    /// einzige i18n-Lücke der App. EN/TR-User sahen im gesamten
    /// Onboarding deutsche Buttons.
    private var primaryActionTitle: String {
        step == .preferencesAndPlan
            ? String(localized: "onboarding.nav.finish", bundle: .module)
            : String(localized: "onboarding.nav.next", bundle: .module)
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
        case .trainingHistory:
            // Anders als Goal/Tone hat die Hauptfrage bewusst KEINEN
            // stillen Default — ohne eine Antwort gibt es kein sinnvolles
            // ExperienceTrack. Die beiden Folgefragen haben Defaults und
            // blockieren nicht zusaetzlich.
            return trainingHistoryAnswer != nil
        case .equipmentPreferences:
            // Phase 3: nie ein Gate — "Später einrichten" ist eine
            // gleichwertig gueltige Antwort, keine Luecke.
            return true
        case .baselineCheck:
            // Start-Check-Epic: "nie ein Gate" — Test, Selbsteinschaetzung
            // und "Spaeter" sind alle gleichwertig gueltige Abschluesse.
            return true
        case .preferencesAndPlan:
            // Plan + Reminder sind beide optional — immer fertig erlaubt.
            return true
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .equipmentPreferences:
            // Smart-Onboarding-Epic Phase 6: im Gym-Pfad gibt es keinen
            // Pflichtschritt — "Weiter" ohne das optionale Sheet darf NICHT
            // automatisch `equipmentProfileConfirmedComplete = true` setzen
            // (das waere eine vom Ort hergeleitete, nicht vom User
            // bestaetigte Aussage). Die Bestaetigung passiert dort
            // ausschliesslich ueber das Sheet selbst (`gymEquipmentSheet`).
            if environment != .gym {
                confirmEquipmentStepIfNeeded()
            }
            goToNextStep()
        case .healthConnect, .personalInfo, .coachingStyle, .trainingHistory, .baselineCheck:
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

    /// Nachbesserung (P2.3): Doppel-Tap-/Doppel-Ausloesung-Schutz fuer
    /// `finishOnboarding()`, siehe dortige Doku.
    @State private var isFinishingOnboarding = false

    private func finishOnboarding() {
        guard let heightCm, let currentWeightKg else { return }
        // Nachbesserung (P2.3, Abnahme "keine Duplikate bei mehrfacher
        // Bestaetigung"): `finishOnboarding()` ist synchron (Profil +
        // Messung + optionaler Plan, alles ohne `await`) und hat ZWEI
        // Ausloeser — den Haupt-Button (`handlePrimaryAction`, dort zusaetzlich
        // ueber `.disabled` gesperrt) UND `DayPickerSheet.onConfirm`. Der
        // Schutz sitzt deshalb HIER, nicht nur an einem der beiden Buttons,
        // damit wirklich jede doppelte Ausloesung abgefangen wird, egal
        // welcher Pfad sie ausloest.
        guard !isFinishingOnboarding else { return }
        isFinishingOnboarding = true
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
            // DEL-170b, ab Phase 3 aus `derivedLegacyEquipment` hergeleitet:
            // `[]` solange nicht bestaetigt (Backward-Compat-Pfad), sonst aus
            // dem neuen, reicheren Modell projiziert.
            equipmentPreferences: derivedLegacyEquipment
        )
        // Smart-Onboarding-Epic Phase 3: das reichere Modell wird UNABHAENGIG
        // vom Bestaetigungsstatus gespeichert — auch eine unvollstaendige
        // Teil-Auswahl ("später einrichten" nach 2 von 10 Kategorien) geht
        // nicht verloren, nur die aeltere `equipmentPreferences`-Spalte oben
        // bleibt bis zur Bestaetigung bewusst leer.
        profile.equipmentProfile = equipmentProfile
        profile.equipmentProfileConfirmedComplete = equipmentProfileConfirmedComplete
        // DEL-207: Wochenziel aus dem Coaching-Step — der Kalender-Streak
        // (DEL-203) zählt ab Tag 1 gegen dieses Ziel.
        profile.weeklyWorkoutGoal = weeklyGoal
        // Fix "doppeltes Onboarding": aus der Trainingshistorie-Antwort
        // hergeleiteter Coaching-Track. `canAdvance` erzwingt eine Antwort
        // auf dem Schritt, resolvedExperienceTrack ist hier also so gut wie
        // immer gesetzt — ein spaeterer echter Onboarding-Flow (dieser
        // Schritt IST bereits der echte Flow) ueberschreibt nichts, das
        // nicht aus genau dieser Antwort stammt.
        if let track = resolvedExperienceTrack {
            profile.experienceTrack = track
        }
        // Start-Check-Epic: nur bei echtem Ergebnis schreiben (Test,
        // Selbsteinschaetzung ODER bewusst "uebersprungen" mit Sicherheits-
        // Flag) — bei "Spaeter machen" bleibt `baselineAssessmentResult`
        // `nil` und damit `profile.baselineAssessment` ebenfalls `nil`,
        // identisch zum Bestandsnutzer-Zustand ohne Check.
        if let baselineAssessmentResult {
            profile.baselineAssessment = baselineAssessmentResult
        }
        modelContext.insert(profile)

        // 2) Initial BodyMeasurement — keeps the "first weight" visible in the
        //    Trend-Chart right after onboarding, instead of an empty dashboard
        //    until the user adds another measurement manually.
        //
        // Settings-Epic Phase 2 (docs/SETTINGS_UX_AUDIT.md, Befund PE-FFM):
        // Onboarding erfasst nie Umfaenge, daher `makeWeightOnly` statt
        // `makeDerived` — sonst erbt jede Tag-1-Messung einen erfundenen
        // KFA/FFM/FFMI-Wert aus dem BMI-Naeherungsfallback. FFMI/Lean-Mass
        // zeigen bis zur ersten echten Umfang-Messung bewusst "–" statt
        // eines Schaetzwerts.
        let measurement = BodyMeasurement.makeWeightOnly(
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
            // Smart-Onboarding-Epic Phase 5.4 (PLAN_SUBSTITUTION_ENGINE.md
            // Abschnitt 4): "Before saving, recheck against the current
            // equipment snapshot and reject stale/incompatible selection."
            // Zwischen Vorschau und hier liegt nur der DayPickerSheet (keine
            // Equipment-Aenderung moeglich) — die Pruefung ist defensiv,
            // nie beobachtet als erreichbarer Fall. Bei Veraltung (oder
            // fehlender Vorschau-Auswahl) wird still frisch aufgeloest statt
            // eine moeglicherweise falsche, veraltete Auswahl zu instanziieren.
            // Phase 6 (PLAN_LOCATION_EQUIPMENT_ONBOARDING.md §1/§4): Vergleich
            // UND eine eventuelle Neuaufloesung laufen gegen denselben
            // effektiven Planungskontext wie die gerade geschlossene Vorschau
            // — sonst wuerde eine reine Gym-Annahme hier faelschlich als
            // "veraltet" gelten (das rohe `equipmentProfile` enthaelt die
            // Annahme nicht, nur `equipmentPlanningContext.effectiveProfile`).
            let currentEffectiveProfile = equipmentPlanningContext.effectiveProfile
            let freshSelection: ResolvedPlanSelection
            if let resolvedPlanSelection, !resolvedPlanSelection.isStale(comparedTo: currentEffectiveProfile) {
                freshSelection = resolvedPlanSelection
            } else {
                freshSelection = PlanSelectionResolver.resolve(
                    template: template, profile: currentEffectiveProfile,
                    context: SubstitutionContext(goal: trainingGoal, experienceTrack: resolvedExperienceTrack)
                )
            }
            ProgramInstantiator.instantiate(
                template,
                in: modelContext,
                selectedWeekdays: selectedWeekdays.isEmpty ? nil : selectedWeekdays,
                resolvedSelection: freshSelection
            )
        } else if let customPlanInput, let customPlanResult {
            // DEL-243: der im Builder-
            // Sheet vorberechnete Result wird 1:1 uebernommen (nicht neu
            // gerechnet) — sonst wiche der instanziierte Plan von der im
            // Wizard zuletzt gezeigten Vorschau ab (siehe PlanGeneratorInstantiatorTests).
            // Nachbesserung (P2.3): `createPlan(for:)` statt der vorher hier
            // separat stehenden Resolve+Build-Sequenz. `profile` ist exakt
            // hier bereits mit `environment`/`equipmentProfile`/
            // `equipmentProfileConfirmedComplete` befuellt (siehe oben,
            // Schritt 1) — identische Werte wie das vorherige
            // `equipmentPlanningContext.effectiveProfile`, nur einmalig statt
            // separat aufgeloest.
            // Nachbesserung (Task #197): `createPlan` wirft jetzt bei einem
            // fehlgeschlagenen Speichervorgang. Profil + Messung (Schritt 1/2
            // oben) sind zu diesem Zeitpunkt bereits inserted und MUESSEN
            // den Onboarding-Abschluss unabhängig vom optionalen Plan
            // erreichen (`RootView`s Query auf `UserBodyProfile` haengt
            // ausschliesslich daran) - ein Plan ist an dieser Stelle schon
            // immer optional (siehe `if let`/`else if let` oben: ohne
            // Template/Builder-Ergebnis passiert hier ohnehin nichts). Ein
            // Speicherfehler wird deshalb bewusst NICHT blockierend
            // behandelt: der Nutzer landet mit Profil, aber ohne initialen
            // Plan, in der App - identisch zum bereits unterstuetzten "Fertig
            // ohne Plan"-Fall - und kann einen Plan jederzeit ueber
            // `PlansListView`s "+" nachholen.
            //
            // Nachbesserung (Task #197, zweite Runde): "Onboarding nicht mit
            // leerem catch abschliessen" - kein Alert HIER (siehe Begruendung
            // unten, unveraendert), aber auch kein stilles Verschwinden mehr.
            // `OnboardingPlanCreationNotice.markFailed()` ist reines
            // `UserDefaults`, unabhaengig von dieser View/ihrem Lebenszyklus -
            // `DashboardView` liest ihn beim naechsten Erscheinen aus und
            // erklaert die Situation im sichtbaren Folgekontext (statt
            // "konsistent abbrechen/erneut versuchen" - das wuerde bedeuten,
            // den bereits abgeschlossenen Profil-Insert wieder zu verwerfen,
            // nur weil der NACHGELAGERTE, optionale Plan-Schritt scheiterte).
            do {
                try PlanGeneratorInstantiator.createPlan(
                    from: customPlanInput, result: customPlanResult,
                    for: profile, generationSource: .planBuilder, in: modelContext
                )
            } catch {
                // Bewusst kein Alert HIER: der Profil-Insert oben hat
                // `RootView` moeglicherweise schon zur MainTabView
                // umschalten lassen, ein neuer Alert-State auf dieser View
                // koennte nie mehr sichtbar werden.
                OnboardingPlanCreationNotice.markFailed()
            }
        }

        // 4) Notification-Präferenzen persistieren. Permission wird angefordert,
        //    wenn mindestens einer der Toggles aktiv ist.
        UserDefaults.standard.set(enableWaterReminder, forKey: ReminderPreferences.waterEnabledKey)
        UserDefaults.standard.set(enableMeasurementReminder, forKey: ReminderPreferences.measurementEnabledKey)

        // Vor dem Task lesen: @State-Werte nicht aus der Task-Closure heraus anfassen.
        let asksForNotifications = enableWaterReminder || enableMeasurementReminder
        Task {
            if asksForNotifications {
                await prNotifications.requestAuthorization()
            }
            // Bugfix: Die Schalter wurden nur gespeichert, geplant wurde
            // nichts — Erinnerungen kamen erst, wenn der Nutzer in den
            // Einstellungen einen Schalter aus- und wieder anmachte. Erst
            // NACH der Berechtigungsabfrage planen (ohne Erlaubnis ist der
            // Scheduler ein No-Op). Immer abgleichen, auch wenn beide Schalter
            // aus sind: Nach "App zuruecksetzen" bleiben Einstellungen UND
            // geplante Benachrichtigungen im System stehen, die dann hier
            // abgeraeumt werden muessen.
            await ReminderPreferencesApplier.applyStoredSchedules()
        }

        // RootView's @Query auf [UserBodyProfile] beobachtet die Insert
        // und swappt automatisch auf MainTabView — kein Navigation-Push nötig.
    }

    // MARK: - Helpers + constants

    /// Fix "70,050003"-Bug: `roundsToWeightPrecision` ist NUR fuer die
    /// Gewichtsfelder `true` (Hoehe bleibt unveraendert). Rundet den
    /// geschriebenen Wert sofort auf 2 Nachkommastellen statt nur kosmetisch
    /// anzuzeigen, und zeigt nie unnoetige Nachkommastellen.
    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, roundsToWeightPrecision: Bool = false) -> some View {
        let displayValue: Binding<Double?> = roundsToWeightPrecision
            ? Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0?.rounded(toDecimals: 2) })
            : value
        let style: FloatingPointFormatStyle<Double> = roundsToWeightPrecision
            ? .number.precision(.fractionLength(0...2))
            : .number
        TextField(value: displayValue, format: style, prompt: Text(label)) {
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
