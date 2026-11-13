#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData
import DeltiqHealth

/// Edits the singleton `UserBodyProfile` — same fields the user filled in onboarding,
/// just under user-controlled re-edit. `@Bindable` autosaves to SwiftData on every
/// keystroke; no explicit "Save" button needed.
///
/// **HealthKit-Pull** (DEL-011): wenn der User Apple Health verbunden hat, gibt
/// es einen "Aus Apple Health uebernehmen"-Button, der DOB/Geschlecht/Groesse
/// in einem Rutsch nachzieht — analog zum Onboarding.
@available(iOS 17.0, macOS 14.0, *)
public struct ProfileEditorView: View {

    @Bindable public var profile: UserBodyProfile
    @Environment(HealthKitController.self) private var healthKit
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var healthKitFetchInProgress: Bool = false
    @State private var healthKitFilledFields: Set<String> = []

    /// Settings-Epic Phase 4 (docs/SETTINGS_UX_AUDIT.md, Befund PE-H1):
    /// haelt den geladenen, noch UNBESTAETIGTEN Health-Snapshot. Non-nil
    /// zeigt die Bestaetigungs-Frage; vor dem Bestaetigen findet KEINE
    /// Profil-Mutation statt (reiner Lese-Fetch in `requestHealthPull()`).
    @State private var pendingHealthPull: OnboardingHealthSnapshot?
    /// Kurzlebiger Hinweis, wenn Health verbunden ist, aber kein einziges der
    /// drei Felder (Geburtsdatum/Geschlecht/Groesse) liefert — dann gibt es
    /// nichts zu bestaetigen, aber auch keinen stillen No-Op ohne Rueckmeldung.
    @State private var healthPullFoundNothing = false

    /// Settings-Epic Phase 3: Re-Entry-Punkte fuer die kombinierten
    /// Koerperdaten-/Trainingsort-Editoren (siehe `bodyDataCard`/
    /// `trainingLocationCard`).
    @State private var showingBodyDataEditor = false
    @State private var showingTrainingLocationEditor = false

    /// Settings-Epic Phase 3: fuer die Gewicht-mit-Datum-Zeile in
    /// `bodyDataCard`s Zusammenfassung — derselbe Query wie in
    /// `BodyDataEditorView`.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var bodyMeasurements: [BodyMeasurement]

    /// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs):
    /// `bodyDataSummaryText` zeigte Gewicht/Zielgewicht hart als " kg", auch
    /// nach Umstellung auf Imperial.
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): Zustand der
    /// einfachen, lokalen Profil-Felder beim Oeffnen — siehe
    @State private var snapshot: ProfileMetaSnapshot

    public init(profile: UserBodyProfile) {
        self.profile = profile
        _snapshot = State(initialValue: ProfileMetaSnapshot.capture(from: profile))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // BackupListView/GearListView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "profile.editor.title", bundle: .module),
                onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                actions: [saveAction]
            )

            VStack(alignment: .leading, spacing: 18) {
                personCard
                bodyDataCard
                trainingLocationCard
                weeklyGoalCard
                coachingCard
                healthCard
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        // UI-Refactor (Korrektur, Punkt 4): bei Aenderungen bleibt die Geste
        // bewusst AUS — ein ungesicherter Verlassen-Weg wuerde am Discard-
        // Dialog vorbei. Ohne Aenderungen funktioniert sie weiter normal.
        .deltiqSwipeBackEnabled(!isDirty)
        .keyboardDismissToolbar()
        .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
            revertToSnapshot()
            dismiss()
        }
        // Settings-Epic Phase 4 (Befund PE-H1): zeigt NUR die tatsaechlich
        // verfuegbaren Felder mit ihrem konkreten Wert, bevor Geburtsdatum/
        // Geschlecht/Groesse ueberschrieben werden. "Abbrechen" (bzw. Wegtippen)
        // verwirft den geladenen Snapshot vollstaendig — keine Mutation.
        .confirmationDialog(
            Text("profile.health.pullConfirm.title", bundle: .module),
            isPresented: Binding(
                get: { pendingHealthPull != nil },
                set: { if !$0 { pendingHealthPull = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingHealthPull
        ) { snapshot in
            Button {
                applyHealthPull(snapshot)
                pendingHealthPull = nil
            } label: {
                Text("profile.health.pullConfirm.apply", bundle: .module)
            }
            Button(role: .cancel) {
                pendingHealthPull = nil
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: { snapshot in
            Text(healthPullPreviewMessage(snapshot))
        }
    }

    // MARK: - UI-Refactor (DeltiqHeader-Muster)

    /// Vergleich gegen `ProfileMetaSnapshot` vom Oeffnen des Sheets — siehe
    /// dessen Scope-Begruendung bei `snapshot` oben.
    private var isDirty: Bool {
        snapshot != ProfileMetaSnapshot.capture(from: profile)
    }

    /// Autosave-Screen (siehe `ExerciseEditorView`) — kein echter Speicher-
    /// Schritt, reines "Fertig". Kein Validitaets-Gate auf diesem Screen →
    /// kein `isDisabled`.
    private var saveAction: DeltiqHeaderAction {
        DeltiqHeaderAction(
            systemImage: "checkmark",
            accessibilityLabel: String(localized: "common.done", bundle: .module)
        ) {
            dismiss()
        }
    }

    /// Schreibt die Snapshot-Felder zurueck — `internal` (statt `private`)
    /// macht die Funktion direkt per `ProfileEditorView(profile:)`-
    /// Konstruktion testbar (siehe Tests/DeltiqUITests) — beruehrt kein
    /// `@Environment`/`@Query`.
    internal func revertToSnapshot() {
        snapshot.apply(to: profile)
    }

    // MARK: - Health

    @ViewBuilder
    private var healthCard: some View {
        DeltiqSection(String(localized: "profile.section.health", bundle: .module).uppercased()) {
            if !healthKit.isAvailable {
                HStack {
                    Label {
                        Text("onboarding.health.unavailable", bundle: .module)
                    } icon: {
                        Image(systemName: "heart.slash")
                    }
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                switch healthKit.authorizationStatus {
                case .sharingAuthorized:
                    Button {
                        Task { await requestHealthPull() }
                    } label: {
                        HStack {
                            if healthKitFetchInProgress {
                                ProgressView()
                                Text("onboarding.health.loading", bundle: .module)
                            } else {
                                Label {
                                    Text("profile.health.pull", bundle: .module)
                                } icon: {
                                    Image(systemName: "arrow.down.circle")
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.deltiqOrange)
                    .disabled(healthKitFetchInProgress)

                    if healthPullFoundNothing {
                        hintRow(String(localized: "profile.health.pullConfirm.nothingFound", bundle: .module))
                    }
                    if !healthKitFilledFields.isEmpty {
                        HStack {
                            Label {
                                Text(String(format: String(localized: "profile.health.pulled", bundle: .module), healthKitFilledFields.sorted().joined(separator: ", ")))
                            } icon: {
                                Image(systemName: "heart.fill")
                            }
                            Spacer()
                        }
                        // Handoff-Ausnahme: echter Apple-Health-Bezug (Daten
                        // wurden von dort uebernommen) - Color.Deltiq.health
                        // statt Akzent-Orange, siehe .pink-Regel im Handoff.
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.health)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                case .notDetermined:
                    Button {
                        Task {
                            await healthKit.requestAuthorization()
                            if healthKit.authorizationStatus == .sharingAuthorized {
                                await requestHealthPull()
                            }
                        }
                    } label: {
                        HStack {
                            Label {
                                Text("onboarding.health.title", bundle: .module)
                            } icon: {
                                Image(systemName: "heart.fill")
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.deltiqOrange)
                case .sharingDenied:
                    HStack {
                        Label {
                            Text("profile.health.denied", bundle: .module)
                        } icon: {
                            Image(systemName: "heart.slash")
                        }
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.deltiqOrange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                case .unavailable:
                    EmptyView()
                }
            }
            hintRow(String(localized: "profile.health.footer", bundle: .module))
        }
    }

    /// Settings-Epic Phase 4 (Befund PE-H1): reiner Lese-Schritt — holt den
    /// Snapshot und zeigt ihn zur Bestaetigung, OHNE das Profil anzufassen.
    /// Die eigentliche Mutation passiert ausschliesslich in
    /// `applyHealthPull(_:)`, ausgeloest durch den expliziten "Uebernehmen"-
    /// Tap im `confirmationDialog` unten.
    private func requestHealthPull() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()
        guard snapshot.hasApplicableProfileFields else {
            healthPullFoundNothing = true
            return
        }
        healthPullFoundNothing = false
        pendingHealthPull = snapshot
    }

    /// Mutiert das Profil — nur mit den Feldern, die der Snapshot tatsaechlich
    /// liefert. Fehlende Health-Werte bleiben unberuehrt (keine Loeschung
    /// vorhandener Profilwerte); Gewicht wird bewusst NIE gelesen (lebt
    /// ausschliesslich in `BodyMeasurement`, siehe `BodyDataEditorView`).
    private func applyHealthPull(_ snapshot: OnboardingHealthSnapshot) {
        var filled: Set<String> = []
        if let dob = snapshot.dateOfBirth {
            profile.birthDate = dob
            filled.insert(String(localized: "profile.health.field.birthday", bundle: .module))
        }
        switch snapshot.sex {
        case .male:
            profile.profile = .male
            filled.insert(String(localized: "profile.health.field.gender", bundle: .module))
        case .female:
            profile.profile = .female
            filled.insert(String(localized: "profile.health.field.gender", bundle: .module))
        case .other, .notSet:
            break
        }
        if let h = snapshot.heightCm, h > 0 {
            profile.heightCm = h
            filled.insert(String(localized: "profile.health.field.height", bundle: .module))
        }
        healthKitFilledFields = filled
    }

    /// Baut die Vorschau-Nachricht fuer den Bestaetigungsdialog — zeigt NUR
    /// die Felder, die tatsaechlich verfuegbar sind, mit ihrem konkreten Wert.
    private func healthPullPreviewMessage(_ snapshot: OnboardingHealthSnapshot) -> String {
        var lines: [String] = []
        if let dob = snapshot.dateOfBirth {
            lines.append(String(
                format: String(localized: "profile.health.pullConfirm.fieldBirthdate", bundle: .module),
                dob.formatted(date: .abbreviated, time: .omitted)
            ))
        }
        let sexLabel: String?
        switch snapshot.sex {
        case .male:   sexLabel = String(localized: "sex.male", bundle: .module)
        case .female: sexLabel = String(localized: "sex.female", bundle: .module)
        case .other, .notSet: sexLabel = nil
        }
        if let sexLabel {
            lines.append(String(
                format: String(localized: "profile.health.pullConfirm.fieldSex", bundle: .module),
                sexLabel
            ))
        }
        if let h = snapshot.heightCm, h > 0 {
            lines.append(String(
                format: String(localized: "profile.health.pullConfirm.fieldHeight", bundle: .module),
                h.formattedTwoDecimals
            ))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Sections

    private var personCard: some View {
        DeltiqSection(String(localized: "profile.section.person", bundle: .module).uppercased()) {
            DeltiqSegmentedPicker(
                options: [
                    DeltiqSegmentedOption(BodyFormulaProfile.male, label: String(localized: "sex.male", bundle: .module)),
                    DeltiqSegmentedOption(BodyFormulaProfile.female, label: String(localized: "sex.female", bundle: .module))
                ],
                selection: $profile.profile
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.Deltiq.divider)
                .frame(height: 1)

            DeltiqControlRow(label: String(localized: "onboarding.field.birthdate", bundle: .module), showsDivider: false) {
                DatePicker(
                    selection: $profile.birthDate,
                    in: Self.minBirthDate ... Date(),
                    displayedComponents: .date
                ) {
                    EmptyView()
                }
                .labelsHidden()
            }
            hintRow(String(localized: "profile.person.footer", bundle: .module))
        }
    }

    /// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Befunde `PE-B1`/
    /// `PE-G1`): kombinierte Koerperdaten-Zeile — Groesse, aktuelles Gewicht
    /// (mit Datum) und Zielgewicht an einem Ort statt auf `bodyCard`/
    /// `goalCard` verteilt. Oeffnet `BodyDataEditorView` als Draft-Sheet mit
    /// explizitem Speichern/Abbrechen; die Zeile selbst zeigt nur den
    /// aktuellen Stand, nie editierbar direkt hier.
    private var bodyDataCard: some View {
        DeltiqSection(String(localized: "profile.bodyData.title", bundle: .module).uppercased()) {
            DeltiqRow(
                icon: "ruler",
                label: String(localized: "profile.bodyData.title", bundle: .module),
                value: bodyDataSummaryText,
                showsChevron: true,
                showsDivider: false
            ) {
                showingBodyDataEditor = true
            }
            hintRow(String(localized: "profile.bodyData.summary.footer", bundle: .module))
        }
        .sheet(isPresented: $showingBodyDataEditor) {
            BodyDataEditorView(profile: profile)
        }
    }

    private var bodyDataSummaryText: String {
        let unit = WeightUnit(rawSetting: weightUnitRaw)
        let unitLabel = weightUnitRaw == "lbs" ? "lbs" : "kg"
        var parts = [unit.fromCm(profile.heightCm).formattedTwoDecimals + " \(unit.heightLabel)"]
        if let latest = bodyMeasurements.first {
            parts.append(unit.fromKg(latest.weightKg).formattedWeightInput() + " \(unitLabel)")
        }
        if let goal = profile.goalWeightKg {
            parts.append(String(format: String(localized: "settings.profile.goal", bundle: .module), unit.fromKg(goal).formattedWeightInput() + " \(unitLabel)"))
        }
        return parts.joined(separator: " · ")
    }

    /// Settings-Epic Phase 3: kombinierter Trainingsort+Ausstattung-Editor
    /// ersetzt die getrennte Umgebungs-Picker-Zeile (vormals in `goalCard`)
    /// und das eigenstaendige `equipmentCard`-Sheet. Oeffnet
    /// `TrainingLocationEquipmentEditorView` als Draft-Sheet — Details dort.
    private var trainingLocationCard: some View {
        DeltiqSection(String(localized: "profile.trainingLocation.title", bundle: .module).uppercased()) {
            DeltiqRow(
                icon: "dumbbell",
                label: String(localized: "profile.trainingLocation.title", bundle: .module),
                value: "\(environmentLabel(profile.environment)) · \(equipmentStatusText)",
                showsChevron: true,
                showsDivider: false
            ) {
                showingTrainingLocationEditor = true
            }
            hintRow(String(localized: "profile.equipment.footer", bundle: .module))
        }
        .sheet(isPresented: $showingTrainingLocationEditor) {
            TrainingLocationEquipmentEditorView(profile: profile)
        }
    }

    // DEL-118: same helper as SettingsView — routes through .localizedName.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §1): ein nicht individuell eingerichtetes Gym-Profil zeigt NIE
    /// "nicht erfasst" — dort gilt die Standard-Gym-Planungsannahme
    /// (`EquipmentPlanningContext`), kein echtes "noch nichts angegeben".
    private var equipmentStatusText: String {
        guard profile.equipmentProfileConfirmedComplete else {
            let hasAnySelection = EquipmentItem.allCases.contains { profile.equipmentProfile.availability(for: $0) == .available }
            if hasAnySelection {
                return String(localized: "profile.equipment.status.inProgress", bundle: .module)
            }
            if profile.environment == .gym {
                return String(localized: "profile.equipment.status.gymAssumption", bundle: .module)
            }
            return String(localized: "profile.equipment.status.notSet", bundle: .module)
        }
        let isBodyweightOnly = EquipmentItem.allCases.allSatisfy { profile.equipmentProfile.availability(for: $0) == .unavailable }
        return String(localized: isBodyweightOnly ? "profile.equipment.status.bodyweightOnly" : "profile.equipment.status.confirmed", bundle: .module)
    }

    /// DEL-203: Wochenziel für den Trainings-Streak. Stepper 1-7 —
    /// der Kalender-Streak zählt nur Wochen, die das Ziel erfüllen.
    private var weeklyGoalCard: some View {
        DeltiqSection(String(localized: "profile.weeklyGoal.header", bundle: .module).uppercased()) {
            DeltiqControlRow(
                icon: "flame",
                label: String(localized: "profile.weeklyGoal.label", bundle: .module),
                showsDivider: false
            ) {
                Stepper(value: Binding(
                    get: { profile.weeklyWorkoutGoal },
                    set: { profile.weeklyWorkoutGoal = min(7, max(1, $0)) }
                ), in: 1...7) {
                    Text("\(profile.weeklyWorkoutGoal)×")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .fitnessNumberStyle()
                }
            }
            hintRow(String(localized: "profile.weeklyGoal.footer", bundle: .module))
        }
    }

    /// DEL-101: Nachträgliche Bearbeitung des Coaching-Stils. Bind direkt
    /// auf die Computed-Properties von `UserBodyProfile` (die sich um das
    /// rawValue-Mapping kuemmern). Picker-Style "menu" damit beide Werte
    /// kompakt in eine Zeile passen.
    ///
    /// Korrektur V6: der Start-Check-Wiedereinstieg (UX-Fix P3 §6) wurde aus
    /// diesem Screen entfernt ("Profil bearbeiten" ausserhalb des
    /// Onboardings). `profile.baselineAssessment` selbst und sein Flow im
    /// Onboarding (`OnboardingView.baselineCheckStep`/`BaselineCheckFlowView`)
    /// sind davon unberuehrt — nur dieser zusaetzliche Re-Entry-Punkt faellt
    /// weg.
    private var coachingCard: some View {
        DeltiqSection(String(localized: "profile.section.coach", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "profile.coaching.goal", bundle: .module)) {
                Picker(selection: Binding(
                    get: { profile.trainingGoal },
                    set: { profile.trainingGoal = $0 }
                )) {
                    // Nachbesserung (P2.3-Review): `selectableInUI(current:)`
                    // statt `currentlySelectableInUI` — ein bereits
                    // gespeichertes `.endurance` (P2.2-Zwischenstand) bleibt
                    // sichtbar/erhalten, auch wenn es fuer eine NEUE Auswahl
                    // gesperrt ist. Siehe Kommentar dort.
                    ForEach(TrainingGoal.selectableInUI(current: profile.trainingGoal), id: \.self) { goal in
                        Label {
                            Text(goal.localizedName)
                        } icon: {
                            Image(systemName: goal.symbol)
                        }
                        .tag(goal)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
            }
            DeltiqControlRow(label: String(localized: "profile.coaching.tone", bundle: .module), showsDivider: false) {
                Picker(selection: Binding(
                    get: { profile.coachingTone },
                    set: { profile.coachingTone = $0 }
                )) {
                    ForEach(CoachingTone.allCases, id: \.self) { tone in
                        Label {
                            Text(tone.localizedName)
                        } icon: {
                            Image(systemName: tone.symbol)
                        }
                        .tag(tone)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
            }
            hintRow(String(localized: "profile.coaching.footer", bundle: .module))
        }
    }

    // MARK: - Row helpers

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
    }
}

/// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): `UserBodyProfile`
/// ist `@Bindable` und autosaved direkt in SwiftData. Haelt bewusst NUR die
/// einfachen, rein lokalen Profil-Felder fest — siehe die Scope-Begruendung
/// bei `ProfileEditorView.snapshot`. `internal` statt `private`, damit
/// gezielte Tests (siehe `Tests/DeltiqUITests`) die Capture/Apply-Logik
/// per `@testable import` direkt pruefen koennen.
@available(iOS 17.0, macOS 14.0, *)
struct ProfileMetaSnapshot: Equatable {
    var profile: BodyFormulaProfile
    var birthDate: Date
    var weeklyWorkoutGoal: Int
    var trainingGoal: TrainingGoal
    var coachingTone: CoachingTone

    static func capture(from profile: UserBodyProfile) -> ProfileMetaSnapshot {
        ProfileMetaSnapshot(
            profile: profile.profile,
            birthDate: profile.birthDate,
            weeklyWorkoutGoal: profile.weeklyWorkoutGoal,
            trainingGoal: profile.trainingGoal,
            coachingTone: profile.coachingTone
        )
    }

    func apply(to profile: UserBodyProfile) {
        profile.profile = self.profile
        profile.birthDate = birthDate
        profile.weeklyWorkoutGoal = weeklyWorkoutGoal
        profile.trainingGoal = trainingGoal
        profile.coachingTone = coachingTone
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    ProfileEditorPreviewWrapper()
        .modelContainer(PreviewSeed.maleProfileContainer)
        .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
private struct ProfileEditorPreviewWrapper: View {
    @Query private var profiles: [UserBodyProfile]

    var body: some View {
        if let profile = profiles.first {
            NavigationStack {
                ProfileEditorView(profile: profile)
            }
        } else {
            Text("Kein Profil im Preview-Container")
        }
    }
}
#endif
#endif
