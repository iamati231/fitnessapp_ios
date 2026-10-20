#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

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
    /// Deltiq-Geräteabnahme (C01): gleiches Re-Entry-Muster fuer die
    /// Cardio-/Laufziel-Felder, siehe `cardioCard`/`CardioGoalEditorView`.
    @State private var showingCardioGoalEditor = false

    /// Settings-Epic Phase 3: fuer die Gewicht-mit-Datum-Zeile in
    /// `bodyDataCard`s Zusammenfassung — derselbe Query wie in
    /// `BodyDataEditorView`.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var bodyMeasurements: [BodyMeasurement]

    // DEL-047: aktive Plaene laden, damit wir bei einer Trainingsort-Aenderung
    // einen Sync-Prompt anbieten koennen. Wir laden alle Plaene (auch
    // inaktive) — der User-Erwartung nach soll sich "mein Trainingsort" auch
    // auf seine Programm-Bibliothek auswirken, nicht nur den aktuell aktiven
    // Plan.
    @Query(sort: \TrainingPlan.name)
    private var allPlans: [TrainingPlan]

    /// Nachtrag "Plan anpassen": `PlanBuilderView` als Sheet, vorbefuellt
    /// mit dem aktuellen Machbarkeits-Vorschlag.
    @State private var showingPlanAdjustSheet: Bool = false

    /// Nachbesserung (P2.3, Abnahme "keine Duplikate bei mehrfacher
    /// Bestaetigung"): schuetzt NUR den direkten "Uebernehmen"-Button in
    /// `feasibilitySection` — der Pfad ueber `PlanBuilderView` ("Plan
    /// anpassen") ist bereits durch dessen eigenen `isAdopting`-Schutz
    /// abgedeckt. Gleiches Muster wie `PlansListView.isAcceptingCardioFeasibility`.
    @State private var isAcceptingCardioFeasibility = false

    /// Nachbesserung (Task #197, zweite Runde): gleiches Muster wie
    /// `PlansListView.cardioAcceptErrorMessage` — ein Speicherfehler von
    /// `accept`/`acceptCustom` wird sichtbar gemacht statt (wie vorher) in
    /// einem `_ = ...`-Discard vollstaendig zu verschwinden.
    @State private var cardioAcceptErrorMessage: String?

    /// Nachbesserung (zweite Korrekturrunde, Punkt B): gleiches Muster wie
    /// `PlansListView.cardioAcceptErrorIsCreatedButUnresolved` — steuert den Alert-Titel, wenn
    /// `accept` nach einem ERFOLGREICHEN Speichervorgang nur an der Rueckbindung scheitert.
    @State private var cardioAcceptErrorIsCreatedButUnresolved = false

    /// Nachbesserung (Task #197, dritte Korrekturrunde): gleiches Muster wie
    /// `PlansListView.acceptOperation`/`.acceptCustomOperation` — der tatsaechliche
    /// Operationszustand, der verhindert, dass ein erneuter Tap nach `.committedButUnresolved`
    /// jemals ein zweites Mal `model.accept`/`.acceptCustom` aufruft (siehe
    /// `PlanCreationOperation`-Typ-Doku). `acceptCustomOperation` wird beim OEFFNEN des "Plan
    /// anpassen"-Sheets bewusst neu erzeugt (siehe Aufrufstelle unten).
    @State private var acceptOperation = PlanCreationOperation()
    @State private var acceptCustomOperation = PlanCreationOperation()
    /// Task #197 (Verifikationsrunde): gleiches Muster wie
    /// `PlansListView.acceptOperationFingerprint` — `acceptOperation` ist laut ihrer eigenen
    /// Typ-Doku PERMANENT fuer ihre Lebensdauer committed, braucht also bei jeder ANDEREN
    /// Ziel/Renndatum/Volumen-Kombination (`CardioFeasibilityCardModel.fingerprint`) eine
    /// frische Instanz — sonst zeigt eine spaetere, unabhaengige Cardio-Karte faelschlich
    /// "Erneut versuchen" und ein Tap darauf wuerde nur den laengst aufgeloesten alten Plan
    /// erneut aufzuloesen versuchen statt den neuen Vorschlag anzulegen (auf echtem Geraet in
    /// `PlansListView` reproduziert; dieselbe Stelle hier war strukturell identisch betroffen).
    @State private var acceptOperationFingerprint: String?

    /// DEL-047: gehaltete `oldEnv`-Referenz fuer den Confirmation-Dialog. Wenn
    /// non-nil, wird der Dialog angezeigt; alle drei Dialog-Aktionen setzen
    /// das Feld wieder auf nil zurueck.
    @State private var pendingProfileEnvSwap: PendingProfileEnvSwap?

    /// DEL-049: Urlaubs-Modus-Restore-Dialog. Separat vom adapt-Pfad, weil
    /// das UI-Wording grundlegend anders ist ("wiederherstellen?" vs.
    /// "anpassen?").
    @State private var pendingProfileEnvRestore: PendingProfileEnvSwap?

    /// Optionaler Ergebnis-Toast nach erfolgreichem Bulk-Sync, analog zum
    /// PlanEditor-Toast. Nil = nichts anzeigen.
    @State private var profileSwapToast: String?

    private struct PendingProfileEnvSwap: Equatable {
        let oldEnv: EnvironmentType
        let newEnv: EnvironmentType
    }

    /// UI-Refactor (DeltiqHeader-Muster): zeigt den Verwerfen-Dialog, wenn
    /// der Zurueck-Chevron bei vorhandenen Aenderungen (`isDirty`) angetippt
    /// wird, statt sofort zu schliessen.
    @State private var showingDiscardConfirm = false

    /// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): Zustand der
    /// einfachen, lokalen Profil-Felder beim Oeffnen — siehe
    /// `ProfileMetaSnapshot`. Bewusst NICHT Teil davon: `heightCm`/
    /// `goalWeightKg`/Gewichtsmessungen (eigener Save/Cancel-Flow in
    /// `BodyDataEditorView`), `environment`/`equipmentProfile` (eigener Flow
    /// in `TrainingLocationEquipmentEditorView`), `cardioCoachingEnabled`/
    /// `cardioGoal`/`cardioRaceDate`/`weeklyBaseVolumeKm`/`maxHeartRateBpm`/
    /// `current5kReferenceSeconds`/`enduranceModality` (eigener Save/Cancel-
    /// Flow in `CardioGoalEditorView`, Deltiq-Geräteabnahme C01 — siehe
    /// dessen Typ-Doku), sowie alles, was `feasibilitySection`s
    /// accept/dismiss/acceptCustom anfasst (eigene, bereits explizit
    /// bestaetigte Aktionen mit Seiteneffekten auf andere Plaene/Tage,
    /// analog `targetEnvironment` in `PlanEditorView`).
    /// `baselineAssessment` selbst bleibt unangetastet — nur der Wieder-
    /// Einstieg DAFUER aus diesem Screen wurde entfernt (Korrektur V6), der
    /// gespeicherte Wert und sein `BaselineCheckFlowView`-Flow im Onboarding
    /// existieren unveraendert weiter.
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
                cardioCard
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
        // DEL-047 + DEL-049: Trainingsort-Aenderung im Profil triggert einen
        // Adapt- oder Restore-Prompt ueber die Uebungen. Adapt bei "frischer"
        // Aenderung, Restore wenn irgendein Plan archivierte Originale hat,
        // die im neuen Env wieder passen.
        //
        // Settings-Epic Phase 2 (docs/SETTINGS_UX_AUDIT.md, Befund PE-G2):
        // es gab hier zusaetzlich einen unbedingten, promptlosen
        // "Top-Down-Sync" (DEL-050), der `targetEnvironment` auf JEDEM Plan —
        // auch archivierten, auch ohne jede Uebung — sofort umschrieb, noch
        // bevor der User die Frage unten ueberhaupt sieht. Effekt: "Nein, so
        // lassen" stellte den Ursprungszustand NICHT wieder her, es gab
        // keinen Undo-Pfad. Entfernt wie von der Vorgabe verlangt — die
        // Uebungs-Anpassung unten bleibt die einzige Stelle, die
        // `targetEnvironment` tatsaechlich aendert, und tut das nur nach
        // expliziter Bestaetigung.
        .onChange(of: profile.environment) { oldValue, newValue in
            guard oldValue != newValue else { return }

            guard allPlans.contains(where: { plan in
                plan.days.contains(where: { !$0.activeExercises.isEmpty })
            }) else { return }
            let pending = PendingProfileEnvSwap(oldEnv: oldValue, newEnv: newValue)
            if PlanEnvironmentMigrator.hasAnyRestorableOriginals(
                plans: allPlans, forEnvironment: newValue
            ) {
                pendingProfileEnvRestore = pending
            } else {
                pendingProfileEnvSwap = pending
            }
        }
        .confirmationDialog(
            Text("profile.envSwap.title", bundle: .module),
            isPresented: Binding(
                get: { pendingProfileEnvSwap != nil },
                set: { if !$0 { pendingProfileEnvSwap = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingProfileEnvSwap
        ) { swap in
            Button {
                applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvSwap = nil
            } label: {
                Text("profile.envSwap.confirm", bundle: .module)
            }
            Button {
                pendingProfileEnvSwap = nil
            } label: {
                Text("profile.envSwap.keep", bundle: .module)
            }
        } message: { swap in
            Text(String(format: String(localized: "profile.envSwap.message", bundle: .module), environmentLabel(swap.newEnv)))
        }
        // DEL-049 "Urlaub zu Ende": ein anderer Dialog, weil der User
        // gespeicherte Gym-Originale aus dem Urlaubs-Modus zurueckholen will.
        .confirmationDialog(
            Text("profile.envRestore.title", bundle: .module),
            isPresented: Binding(
                get: { pendingProfileEnvRestore != nil },
                set: { if !$0 { pendingProfileEnvRestore = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingProfileEnvRestore
        ) { swap in
            Button {
                applyEnvironmentRestoreToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvRestore = nil
            } label: {
                Text("profile.envRestore.confirm", bundle: .module)
            }
            Button {
                applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvRestore = nil
            } label: {
                Text("profile.envRestore.adjustNew", bundle: .module)
            }
        } message: { swap in
            Text("profile.envRestore.message", bundle: .module)
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
        // Nachbesserung (Task #197, zweite Runde): sichtbarer Fehler statt
        // stillem Discard, siehe `cardioAcceptErrorMessage`-Doku.
        // Nachbesserung (zweite Korrekturrunde, Punkt B): Titel haengt vom Fehlerfall ab, siehe
        // `cardioAcceptErrorIsCreatedButUnresolved`-Doku.
        .alert(
            Text(cardioAcceptErrorIsCreatedButUnresolved
                 ? "cardioFeasibility.error.createdButUnresolved.title"
                 : "cardioFeasibility.error.saveFailed.title", bundle: .module),
            isPresented: Binding(
                get: { cardioAcceptErrorMessage != nil },
                set: { if !$0 { cardioAcceptErrorMessage = nil } }
            )
        ) {
            Button("OK") { cardioAcceptErrorMessage = nil }
        } message: {
            Text(cardioAcceptErrorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let msg = profileSwapToast {
                Label(msg, systemImage: "checkmark.seal.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// DEL-047: bulk-migration ueber den `PlanEnvironmentMigrator`. Setzt jedem
    /// Plan das neue `targetEnvironment` und ersetzt Uebungen, die im neuen
    /// Env nicht gehen, durch die Alternative-Liste. Ergebnis-Toast zeigt
    /// die Aggregat-Counts.
    private func applyEnvironmentSwapToAllPlans(newEnv: EnvironmentType) {
        let outcome = PlanEnvironmentMigrator.migrateAll(
            plans: allPlans,
            toEnvironment: newEnv,
            modelContext: modelContext
        )
        showAggregateToast(plansTouched: outcome.plansTouched, result: outcome.result)
    }

    /// DEL-049: gegen-Operation. Restored alle Urlaubs-Modus-Originale ueber
    /// alle Plaene. Plaene ohne Originale werden trotzdem auf `targetEnvironment`
    /// gesetzt, sodass der User nicht hinterher noch eine Inkonsistenz hat.
    private func applyEnvironmentRestoreToAllPlans(newEnv: EnvironmentType) {
        let outcome = PlanEnvironmentMigrator.restoreAll(
            plans: allPlans,
            toEnvironment: newEnv,
            modelContext: modelContext
        )
        showAggregateToast(plansTouched: outcome.plansTouched, result: outcome.result)
    }

    private func showAggregateToast(plansTouched: Int, result r: PlanEnvironmentSwapResult) {
        var parts: [String] = []
        parts.append("\(plansTouched) Plan\(plansTouched == 1 ? "" : "e")")
        if r.restored > 0   { parts.append("\(r.restored) wiederhergestellt") }
        if r.swapped > 0    { parts.append("\(r.swapped) ersetzt") }
        if r.kept > 0       { parts.append("\(r.kept) ohne Alternative") }
        if r.compatible > 0 { parts.append("\(r.compatible) unverändert") }
        let message = parts.joined(separator: " · ")

        withAnimation(.easeOut(duration: 0.2)) {
            profileSwapToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                profileSwapToast = nil
            }
        }
    }

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
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
    /// Konstruktion testbar (siehe Tests/FitnessAppUITests) — beruehrt kein
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
            filled.insert("Geburtsdatum")
        }
        switch snapshot.sex {
        case .male:
            profile.profile = .male
            filled.insert("Geschlecht")
        case .female:
            profile.profile = .female
            filled.insert("Geschlecht")
        case .other, .notSet:
            break
        }
        if let h = snapshot.heightCm, h > 0 {
            profile.heightCm = h
            filled.insert("Größe")
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
        var parts = [profile.heightCm.formattedTwoDecimals + " cm"]
        if let latest = bodyMeasurements.first {
            parts.append(latest.weightKg.formattedWeightInput() + " kg")
        }
        if let goal = profile.goalWeightKg {
            parts.append(String(format: String(localized: "settings.profile.goal", bundle: .module), goal.formattedWeightInput() + " kg"))
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

    /// DEL-250: Cardio-/Lauf-Ziele nachtraeglich editierbar (Post-Onboarding).
    /// Deltiq-Geräteabnahme (C01): die Felder lagen frueher direkt hier,
    /// live an `profile` gebunden — die gebuendelte Anpassungsvorschau
    /// (`feasibilitySection` unten) erschien dadurch nachweislich bei JEDEM
    /// Tastenanschlag statt wie von Dok. 01 §6 gefordert "einmalig gebuendelt
    /// nach einem gespeicherten Update" (siehe docs/DELTIQ_DEVICE_ACCEPTANCE.md,
    /// C01). Fix: gleiches Re-Entry-Muster wie `bodyDataCard`/
    /// `trainingLocationCard` — nur eine Zusammenfassungs-Zeile hier, die
    /// eigentlichen Felder (inkl. Retro-Sync) leben jetzt mit eigenem
    /// lokalem Draft + explizitem Speichern in `CardioGoalEditorView`.
    /// `feasibilitySection` bleibt unveraendert an das live `profile`
    /// gebunden und aendert sich darum erst, NACHDEM dort gespeichert wurde.
    private var cardioCard: some View {
        DeltiqSection(String(localized: "profile.section.cardio", bundle: .module).uppercased()) {
            DeltiqRow(
                icon: "figure.run",
                label: String(localized: "profile.section.cardio", bundle: .module),
                value: cardioGoalSummaryText,
                showsChevron: true,
                showsDivider: false
            ) {
                showingCardioGoalEditor = true
            }
            if let model = feasibilityModel {
                feasibilitySection(model)
            }
            hintRow(String(localized: "profile.cardio.footer", bundle: .module))
        }
        .sheet(isPresented: $showingCardioGoalEditor) {
            CardioGoalEditorView(profile: profile)
        }
    }

    private var cardioGoalSummaryText: String {
        guard profile.cardioCoachingEnabled else {
            return String(localized: "profile.cardioGoal.summary.off", bundle: .module)
        }
        return String(localized: profile.cardioGoal.localizedName)
    }

    // MARK: - Handoff "Lauf-Coaching - Machbarkeits-Check"

    /// Live gerechnet bei jedem Render - keine gespeicherte "ausstehende
    /// Empfehlung" (2.30): Profil, Dashboard und Plan-Tab rufen alle
    /// denselben `CardioFeasibilityCardModel.make(for:)` auf.
    private var feasibilityModel: CardioFeasibilityCardModel? {
        CardioFeasibilityCardModel.make(for: profile)
    }

    @ViewBuilder
    private func feasibilitySection(_ model: CardioFeasibilityCardModel) -> some View {
        Rectangle()
            .fill(Color.Deltiq.divider)
            .frame(height: 1)
        VStack(alignment: .leading, spacing: 8) {
            Text(model.verdict.feasible
                 ? String(localized: "profile.cardio.feasibility.feasibleHeadline", bundle: .module)
                 : String(localized: "profile.cardio.feasibility.infeasibleHeadline", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(model.detailText)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.hasPlan, let days = model.planResult?.days {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        CardioFeasibilityDayRow(day: day)
                    }
                }
            }
            // Nachtrag "Plan anpassen", Layout-Hinweis: die primaere Aktion
            // steht allein in voller Staerke, "Plan anpassen" und "Ziel
            // behalten" folgen als gleichrangiges, leiseres Paar darunter -
            // drei Text-Knoepfe in einer Zeile waeren auf Kartenbreite eng.
            if model.hasPlan {
                Button {
                    // `cardioGoal` ist seit der Cardio-Editor-Auslagerung
                    // (siehe `CardioGoalEditorView`) kein `ProfileMetaSnapshot`-
                    // Feld mehr — ein Rebaseline nach `accept` ist darum nicht
                    // mehr noetig, der Haupt-Screen bleibt davon unberuehrt.
                    guard !isAcceptingCardioFeasibility else { return }
                    // Siehe `acceptOperationFingerprint`-Doku: eine Karte fuer eine ANDERE
                    // Kombination als die, fuer die `acceptOperation` zuletzt stand, braucht
                    // zwingend eine frische Instanz.
                    if acceptOperationFingerprint != model.fingerprint {
                        acceptOperation = PlanCreationOperation()
                        acceptOperationFingerprint = model.fingerprint
                    }
                    isAcceptingCardioFeasibility = true
                    // `nil` bedeutet, dass bereits `accept`s eigene
                    // Vorbedingungen (z.B. `hasPlan`) nicht erfuellt sind.
                    withAnimation {
                        switch model.accept(profile: profile, in: modelContext, using: acceptOperation) {
                        case .success:
                            // Geraete-Fund (TestingBot, Task #197 UI-Pruefumfang, identisches Muster
                            // wie PlansListView): ohne dieses Zuruecksetzen blieb der Button nach
                            // JEDEM erfolgreichen Uebernehmen fuer den Rest der View-Lebensdauer
                            // dauerhaft deaktiviert.
                            isAcceptingCardioFeasibility = false
                        case nil:
                            isAcceptingCardioFeasibility = false
                        case .nothingToCreate:
                            isAcceptingCardioFeasibility = false
                        case .committedButUnresolved:
                            // Der Plan WURDE bereits gespeichert - "Speicherfehler" waere falsch,
                            // Button zeigt ab jetzt "Erneut versuchen" (siehe Label unten).
                            isAcceptingCardioFeasibility = false
                            cardioAcceptErrorIsCreatedButUnresolved = true
                            cardioAcceptErrorMessage = String(localized: "cardioFeasibility.error.createdButUnresolved.message", bundle: .module)
                        case .failedBeforeCommit:
                            isAcceptingCardioFeasibility = false
                            cardioAcceptErrorIsCreatedButUnresolved = false
                            cardioAcceptErrorMessage = String(localized: "cardioFeasibility.error.saveFailed.message", bundle: .module)
                        }
                    }
                } label: {
                    // Nachbesserung (dritte Korrekturrunde, Punkt 5): im "bereits erstellt, nur
                    // nicht aufgeloest"-Zustand kein irrefuehrendes erneutes "Uebernehmen".
                    Text((acceptOperation.committedPlanID != nil && acceptOperationFingerprint == model.fingerprint)
                         ? String(localized: "profile.cardio.feasibility.retryResolve", bundle: .module)
                         : (model.verdict.feasible
                            ? String(localized: "profile.cardio.feasibility.apply", bundle: .module)
                            : String(localized: "profile.cardio.feasibility.acceptSuggestion", bundle: .module)))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
                .disabled(isAcceptingCardioFeasibility)
            }
            HStack(spacing: 20) {
                if model.hasPlan {
                    Button {
                        // Nachbesserung (Task #197, dritte Korrekturrunde): frische Instanz pro
                        // Bearbeitungssitzung, siehe `acceptCustomOperation`-Doku.
                        acceptCustomOperation = PlanCreationOperation()
                        showingPlanAdjustSheet = true
                    } label: {
                        Text("profile.cardio.feasibility.adjustPlan", bundle: .module)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
                if !model.verdict.feasible {
                    Button {
                        // `dismiss` aendert nur `cardioFeasibilityDismissed-
                        // Fingerprint`, kein Snapshot-Feld — kein Rebaseline
                        // noetig, ein offener Coaching-Ton-Edit muss per
                        // "Verwerfen" weiterhin ruecknehmbar bleiben.
                        withAnimation { model.dismiss(profile: profile) }
                    } label: {
                        Text("profile.cardio.feasibility.keepGoal", bundle: .module)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingPlanAdjustSheet) {
            if let input = model.planInput {
                PlanBuilderView(initialInput: input) { adjustedInput, adjustedResult in
                    // `acceptCustom` aendert ebenfalls nur `cardioFeasibility-
                    // DismissedFingerprint`, nicht `cardioGoal`.
                    // Keine Navigation bei Erfolg: dieser Screen haelt (anders
                    // als `PlansListView`) gar keine `AppNavigation`-Referenz,
                    // der direkte "Uebernehmen"-Button oben navigiert aus
                    // demselben Grund ebenfalls nicht.
                    //
                    // Nachbesserung (Task #197, dritte Korrekturrunde): `acceptCustomOperation`
                    // (frisch pro Sheet-Oeffnung, siehe Aufrufstelle oben) ersetzt das vorherige
                    // direkte `do/catch` - einmal `.committedButUnresolved`, ruft diese Instanz
                    // `model.acceptCustom(...)` NIE WIEDER auf. `PlanBuilderView` leitet ihre
                    // eigene lokalisierte Nachricht selbst aus dem zurueckgegebenen
                    // `PlanBuilderHandoffOutcome` ab - hier wird kein fertiger Text mehr
                    // uebergeben.
                    switch model.acceptCustom(
                        input: adjustedInput, result: adjustedResult, profile: profile,
                        in: modelContext, using: acceptCustomOperation
                    ) {
                    case .success, .nothingToCreate:
                        return .success
                    case nil:
                        return .success
                    case .committedButUnresolved:
                        return .committedButUnresolved
                    case .failedBeforeCommit:
                        return .failedBeforeCommit
                    }
                }
            }
        }
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
    private func hintRow(_ text: String, color: Color = Color.Deltiq.textSecondary) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
    }
}

/// UI-Refactor (DeltiqHeader-Muster fuer Autosave-Screens): `UserBodyProfile`
/// ist `@Bindable` und autosaved direkt in SwiftData. Haelt bewusst NUR die
/// einfachen, rein lokalen Profil-Felder fest — siehe die Scope-Begruendung
/// bei `ProfileEditorView.snapshot`. `internal` statt `private`, damit
/// gezielte Tests (siehe `Tests/FitnessAppUITests`) die Capture/Apply-Logik
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
