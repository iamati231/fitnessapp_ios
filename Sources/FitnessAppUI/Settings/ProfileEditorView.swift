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

    /// DEL-250: MM:SS-Eingabepuffer fuer die 5-km-Referenzzeit. Bewusst ein
    /// eigenstaendiger `@State`-String statt einer Binding<String> ueber
    /// `profile.current5kReferenceSeconds` (Review-Fund): eine computed
    /// Binding wuerde nach jedem Tastenanschlag sofort aus dem geparsten
    /// Sekundenwert zurueckformatieren und das Feld dabei ueberschreiben
    /// (z.B. "2" -> sofort "2:00"), bevor die zweite Ziffer ankommt - exakt
    /// das Problem, das `SetRow.cardioDurationText` mit einem eigenen Puffer
    /// vermeidet. Wird in `init` aus dem Modell vorbefuellt, geschrieben wird
    /// nur per `.onChange` (Modell folgt der Eingabe, nicht umgekehrt).
    @State private var fiveKReferenceText: String = ""

    // DEL-047: aktive Plaene laden, damit wir bei einer Trainingsort-Aenderung
    // einen Sync-Prompt anbieten koennen. Wir laden alle Plaene (auch
    // inaktive) — der User-Erwartung nach soll sich "mein Trainingsort" auch
    // auf seine Programm-Bibliothek auswirken, nicht nur den aktuell aktiven
    // Plan.
    @Query(sort: \TrainingPlan.name)
    private var allPlans: [TrainingPlan]

    /// DEL-251: Grundlage fuer den Cardio-Retro-Sync (Wochenvolumen +
    /// Referenzpace aus bereits geloggten Laeufen). Gleiches Query-Muster
    /// wie `DashboardView.completedSessions`.
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.startTime, order: .reverse)
    private var completedSessions: [WorkoutSession]

    /// DEL-251: Ergebnis eines Retro-Sync-Laufs, wartet auf Bestaetigung.
    /// Non-nil zeigt den confirmationDialog; beide Dialog-Aktionen setzen
    /// das Feld wieder auf nil zurueck (identisches Pattern wie
    /// `pendingProfileEnvSwap`).
    @State private var pendingCardioBaseline: CardioBaselineCalculator.Result?

    /// DEL-251: true fuer einen kurzen Hinweis, wenn Retro-Sync keine
    /// verwertbaren Laeufe findet (kein geloggter Cardio-Log ueberhaupt,
    /// oder keiner erfuellt die Mindest-Schwellen).
    @State private var retroSyncEmptyNoticeVisible: Bool = false
    /// Nachtrag "Plan anpassen": `PlanBuilderView` als Sheet, vorbefuellt
    /// mit dem aktuellen Machbarkeits-Vorschlag.
    @State private var showingPlanAdjustSheet: Bool = false

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

    public init(profile: UserBodyProfile) {
        self.profile = profile
        _fiveKReferenceText = State(
            initialValue: profile.current5kReferenceSeconds.map(PaceCalculator.formatDuration) ?? ""
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // BackupListView/GearListView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "profile.editor.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                personCard
                bodyCard
                goalCard
                cardioCard
                weeklyGoalCard
                equipmentCard
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
        .deltiqSwipeBackEnabled()
        .keyboardDismissToolbar()
        // DEL-047 + DEL-049 + DEL-050: Trainingsort-Aenderung im Profil
        // triggert zwei sequentielle Schritte:
        //
        //   * SCHRITT 1 (DEL-050 Top-Down-Sync): Plan-Metadaten unbedingt
        //     mit-aktualisieren, BEVOR der User die "anpassen?"-Frage
        //     beantwortet. Sonst koennte er "Nein, so lassen" sagen und es
        //     entstuende ein Mismatch (Profil = BW, Plan = Gym). Dies passiert
        //     ohne Prompt — Profil ist die Source of Truth fuer alle Plaene.
        //
        //   * SCHRITT 2 (DEL-047/049): Adapt- oder Restore-Prompt
        //     ueber die Uebungen. Adapt bei "frischer" Aenderung, Restore wenn
        //     irgendein Plan archivierte Originale hat, die im neuen Env wieder
        //     passen.
        .onChange(of: profile.environment) { oldValue, newValue in
            guard oldValue != newValue else { return }

            // ── SCHRITT 1: DEL-050 Top-Down-Sync (immer, ohne Prompt). ──
            for plan in allPlans where plan.targetEnvironment != newValue {
                plan.targetEnvironment = newValue
            }

            // ── SCHRITT 2: Adapt-oder-Restore-Frage (nur wenn relevant). ──
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
        // DEL-251: Retro-Sync-Bestaetigung — leichtgewichtiges
        // confirmationDialog analog envSwap/envRestore oben, statt eines
        // vollen Sheets (Nutzer-Entscheidung: nur zwei berechnete Werte,
        // kein Review einzelner zugrunde liegender Laeufe in dieser Runde).
        .confirmationDialog(
            Text("profile.cardio.retroSync.title", bundle: .module),
            isPresented: Binding(
                get: { pendingCardioBaseline != nil },
                set: { if !$0 { pendingCardioBaseline = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingCardioBaseline
        ) { result in
            Button {
                applyCardioBaseline(result)
                pendingCardioBaseline = nil
            } label: {
                Text("profile.cardio.retroSync.apply", bundle: .module)
            }
            Button(role: .cancel) {
                pendingCardioBaseline = nil
            } label: {
                Text("profile.cardio.retroSync.discard", bundle: .module)
            }
        } message: { result in
            Text(cardioBaselineMessage(result))
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
                        Task { await pullProfileFromHealthKit() }
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
                                await pullProfileFromHealthKit()
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

    private func pullProfileFromHealthKit() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()
        var filled: Set<String> = []

        // Der Pull ist eine explizite Nutzer-Aktion ("Aus Apple Health
        // uebernehmen") und ersetzt die aktuellen Werte - nur, was Health
        // tatsaechlich liefert (nicht gesetzte Felder bleiben unberuehrt).
        // `profile.health.footer` beschreibt genau das.
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

    private var bodyCard: some View {
        DeltiqSection(String(localized: "profile.section.body", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "onboarding.field.heightCm", bundle: .module), showsDivider: false) {
                decimalField(
                    String(localized: "onboarding.field.heightCm", bundle: .module),
                    value: $profile.heightCm,
                    placeholder: String(localized: "profile.body.heightPlaceholder", bundle: .module)
                )
            }
            if !Self.heightRange.contains(profile.heightCm) {
                let template = String(localized: "profile.body.plausible", bundle: .module)
                hintRow(
                    template
                        .replacingOccurrences(of: "%1$lld", with: "\(Int(Self.heightRange.lowerBound))")
                        .replacingOccurrences(of: "%2$lld", with: "\(Int(Self.heightRange.upperBound))"),
                    color: Color.Deltiq.error
                )
            } else {
                hintRow(String(localized: "profile.body.footerOk", bundle: .module))
            }
        }
    }

    private var goalCard: some View {
        DeltiqSection(String(localized: "onboarding.section.goals", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "onboarding.field.goalWeightKg", bundle: .module)) {
                decimalField(
                    String(localized: "onboarding.field.goalWeightKg", bundle: .module),
                    value: $profile.goalWeightKg,
                    placeholder: String(localized: "profile.goal.weightPlaceholder", bundle: .module),
                    roundsToWeightPrecision: true
                )
            }
            DeltiqControlRow(label: String(localized: "onboarding.field.environment", bundle: .module), showsDivider: false) {
                Picker(selection: $profile.environment) {
                    Text("environment.gym", bundle: .module).tag(EnvironmentType.gym)
                    Text("environment.home_gym", bundle: .module).tag(EnvironmentType.homeGym)
                    Text("environment.no_equipment", bundle: .module).tag(EnvironmentType.noEquipment)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
            }
            hintRow(String(localized: "profile.goal.footer", bundle: .module))
        }
    }

    /// DEL-250: Cardio-/Lauf-Ziele nachtraeglich editierbar (Post-Onboarding).
    /// Umfang bewusst auf den Profil-Editor beschraenkt — kein neuer
    /// Onboarding-Schritt in dieser Runde, keine neue Coaching-Trigger-
    /// Verdrahtung (CardioCoachingAdvisor/DashboardView/PlanGenerator
    /// unveraendert). Toggle-blendet-Sektion-Pattern analog
    /// `SettingsView.waterReminderEnabled`; Referenzzeit statt direkter
    /// Pace-Eingabe (praeziser fuer eine spaetere
    /// `cardioProgressionEarned`-Verfeinerung, siehe `PaceZoneCalculator`).
    private var cardioCard: some View {
        DeltiqSection(String(localized: "profile.section.cardio", bundle: .module).uppercased()) {
            DeltiqControlRow(
                icon: "figure.run",
                label: String(localized: "profile.cardio.enable", bundle: .module),
                showsDivider: profile.cardioCoachingEnabled
            ) {
                Toggle("", isOn: $profile.cardioCoachingEnabled)
                    .labelsHidden()
                    .tint(Color.deltiqOrange)
            }
            if profile.cardioCoachingEnabled {
                // DEL-251: Retro-Sync — berechnet Wochenvolumen + Referenzpace
                // aus bereits in Deltiq geloggten Laeufen, statt der Felder
                // unten mit 0 zu starten. Bewusst NUR In-App-Daten diese
                // Runde (siehe Doc-Kommentar auf `CardioBaselineCalculator`) -
                // kein HealthKit-Permission-Dialog fuer Bestandsnutzer, die
                // das Feature nie nutzen.
                Button {
                    let result = computeCardioBaseline()
                    if result.isEmpty {
                        retroSyncEmptyNoticeVisible = true
                    } else {
                        retroSyncEmptyNoticeVisible = false
                        pendingCardioBaseline = result
                    }
                } label: {
                    HStack {
                        Label {
                            Text("profile.cardio.retroSync.button", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
                if retroSyncEmptyNoticeVisible {
                    hintRow(String(localized: "profile.cardio.retroSync.empty", bundle: .module))
                }
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
                DeltiqControlRow(label: String(localized: "profile.cardio.goal", bundle: .module)) {
                    Picker(selection: Binding(
                        get: { profile.cardioGoal },
                        set: { profile.cardioGoal = $0 }
                    )) {
                        ForEach(CardioGoal.allCases, id: \.self) { goal in
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
                DeltiqControlRow(label: String(localized: "profile.cardio.fiveKReference", bundle: .module)) {
                    TextField("MM:SS", text: $fiveKReferenceText, prompt: Text("MM:SS"))
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15))
                        .fitnessNumberStyle()
                        .frame(maxWidth: 90)
                        .onChange(of: fiveKReferenceText) { _, newValue in
                            profile.current5kReferenceSeconds = PaceCalculator.parseDurationToSeconds(newValue)
                        }
                }
                if let zonesSummary {
                    hintRow(zonesSummary)
                }
                DeltiqControlRow(
                    label: String(localized: "profile.cardio.raceDateToggle", bundle: .module),
                    showsDivider: profile.cardioRaceDate != nil
                ) {
                    Toggle("", isOn: cardioRaceDateToggleBinding)
                        .labelsHidden()
                        .tint(Color.deltiqOrange)
                }
                if profile.cardioRaceDate != nil {
                    DeltiqControlRow(label: String(localized: "profile.cardio.raceDateValue", bundle: .module)) {
                        DatePicker(
                            selection: Binding(
                                get: { profile.cardioRaceDate ?? Self.defaultRaceDate },
                                set: { profile.cardioRaceDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }
                DeltiqControlRow(label: String(localized: "profile.cardio.weeklyVolume", bundle: .module)) {
                    decimalField(
                        String(localized: "profile.cardio.weeklyVolume", bundle: .module),
                        value: $profile.weeklyBaseVolumeKm,
                        placeholder: String(localized: "profile.cardio.weeklyVolumePlaceholder", bundle: .module)
                    )
                }
                DeltiqControlRow(label: String(localized: "profile.cardio.maxHeartRate", bundle: .module), showsDivider: feasibilityModel != nil) {
                    intField(
                        String(localized: "profile.cardio.maxHeartRate", bundle: .module),
                        value: $profile.maxHeartRateBpm,
                        placeholder: String(localized: "profile.cardio.maxHeartRatePlaceholder", bundle: .module)
                    )
                }
                if let model = feasibilityModel {
                    feasibilitySection(model)
                }
            }
            hintRow(String(localized: "profile.cardio.footer", bundle: .module))
        }
    }

    /// Formatierter Hinweistext mit den aus der Referenzzeit abgeleiteten
    /// Pace-Zonen. Nil solange keine Referenzzeit gepflegt ist.
    private var zonesSummary: String? {
        guard let seconds = profile.current5kReferenceSeconds,
              let easy = PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: seconds),
              let tempo = PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: seconds)
        else { return nil }
        let template = String(localized: "profile.cardio.paceZones", bundle: .module)
        return String(format: template, PaceCalculator.formatPace(easy), PaceCalculator.formatPace(tempo))
    }

    /// An/Aus-Bruecke fuers Renn-Datum: An setzt (falls noch keins gepflegt)
    /// ein plausibles Default-Datum, Aus loescht auf nil zurueck — echtes
    /// "kein Datum gesetzt" statt eines Platzhalter-Datums.
    private var cardioRaceDateToggleBinding: Binding<Bool> {
        Binding(
            get: { profile.cardioRaceDate != nil },
            set: { isOn in
                profile.cardioRaceDate = isOn ? (profile.cardioRaceDate ?? Self.defaultRaceDate) : nil
            }
        )
    }

    /// Plausibler Default beim erstmaligen Aktivieren des Renn-Datums —
    /// 12 Wochen im Voraus, ein gaengiger Trainings-Zyklus-Horizont.
    private static var defaultRaceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    }

    // MARK: - DEL-251 Retro-Sync

    /// Geloggte Cardio-Logs der letzten `days` Tage — identische Filter-
    /// Kette wie `DashboardView.isCardioVolumeSpikeActive`s
    /// `cardioKm(weeksAgo:)`: erst auf Session-Ebene nach echten,
    /// abgeschlossenen Workouts im Zeitfenster filtern, DANN erst auf die
    /// einzelnen Logs herunterbrechen und die Nicht-Cardio-Logs raus.
    private func cardioLogs(sinceDaysAgo days: Int) -> [ExerciseLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return completedSessions
            .filter { $0.isRealWorkout && $0.startTime >= cutoff }
            .flatMap(\.logs)
            .filter(\.resolvedIsCardio)
    }

    /// Aggregiert die Rohdaten und ruft `CardioBaselineCalculator` fuer die
    /// eigentliche Berechnung — DashboardView/ProfileEditorView liefern nur
    /// die SwiftData-Abfrage, die Kern-Logik bleibt in Core testbar.
    private func computeCardioBaseline() -> CardioBaselineCalculator.Result {
        let volumeDistancesKm = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.weeklyVolumeWindowDays)
            .compactMap(\.distanceKm)
        let referenceRuns = cardioLogs(sinceDaysAgo: CardioBaselineCalculator.referenceWindowDays)
            .compactMap { log -> CardioBaselineCalculator.RunSample? in
                guard let distanceKm = log.distanceKm, let durationSeconds = log.durationSeconds else { return nil }
                return CardioBaselineCalculator.RunSample(distanceKm: distanceKm, durationSeconds: durationSeconds)
            }
        return CardioBaselineCalculator.Result(
            weeklyVolumeKm: CardioBaselineCalculator.weeklyVolumeKm(distancesKm: volumeDistancesKm),
            referenceSeconds: CardioBaselineCalculator.fastestReferenceSeconds(from: referenceRuns)
        )
    }

    /// Schreibt einen bestaetigten Retro-Sync in `UserBodyProfile` — nur die
    /// Felder, fuer die tatsaechlich ein Wert ermittelt wurde; ein `nil`-Feld
    /// im Ergebnis laesst den bestehenden Profil-Wert unangetastet, statt ihn
    /// zu leeren. `current5kReferenceSeconds` schreibt zusaetzlich in den
    /// MM:SS-Eingabepuffer, sonst zeigt das Textfeld den alten Wert weiter.
    private func applyCardioBaseline(_ result: CardioBaselineCalculator.Result) {
        if let weeklyVolumeKm = result.weeklyVolumeKm {
            profile.weeklyBaseVolumeKm = weeklyVolumeKm
        }
        if let referenceSeconds = result.referenceSeconds {
            profile.current5kReferenceSeconds = referenceSeconds
            fiveKReferenceText = PaceCalculator.formatDuration(referenceSeconds)
        }
    }

    /// Baut den Dialog-Text passend zur tatsaechlich verfuegbaren
    /// Kombination (beide Werte / nur Volumen / nur Pace) — der Aufrufer
    /// zeigt den Dialog ohnehin nur, wenn `!result.isEmpty`.
    private func cardioBaselineMessage(_ result: CardioBaselineCalculator.Result) -> String {
        let volumeText = result.weeklyVolumeKm.map(\.formattedOneDecimal)
        let paceText = result.referenceSeconds
            .flatMap(PaceZoneCalculator.racePaceMinutesPerKm)
            .map(PaceCalculator.formatPace)
        switch (volumeText, paceText) {
        case let (.some(v), .some(p)):
            return String(format: String(localized: "profile.cardio.retroSync.messageBoth", bundle: .module), v, p)
        case let (.some(v), nil):
            return String(format: String(localized: "profile.cardio.retroSync.messageVolumeOnly", bundle: .module), v)
        case let (nil, .some(p)):
            return String(format: String(localized: "profile.cardio.retroSync.messagePaceOnly", bundle: .module), p)
        case (nil, nil):
            return ""
        }
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
                    withAnimation { _ = model.accept(profile: profile, in: modelContext) }
                } label: {
                    Text(model.verdict.feasible
                         ? String(localized: "profile.cardio.feasibility.apply", bundle: .module)
                         : String(localized: "profile.cardio.feasibility.acceptSuggestion", bundle: .module))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
            }
            HStack(spacing: 20) {
                if model.hasPlan {
                    Button {
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
                    _ = model.acceptCustom(input: adjustedInput, result: adjustedResult, profile: profile, in: modelContext)
                }
            }
        }
    }

    /// DEL-170: Equipment-Präferenzen (Multi-Select). Steuert die Auswahl
    /// von `EquipmentVariant` bei Templates mit mehreren Implement-Varianten
    /// (z.B. Hybrid-Pläne: Barbell-Gym vs. Dumbbell-Only). Default leer →
    /// Plan-Matcher behandelt das wie "nicht gepflegt" und nimmt die
    /// Standard-Variante; sobald der User mindestens eine Box ankreuzt,
    /// wirken die Präferenzen sofort beim nächsten Plan-Adopt.
    private var equipmentCard: some View {
        DeltiqSection(String(localized: "profile.equipment.header", bundle: .module).uppercased()) {
            ForEach(Equipment.allCases, id: \.self) { equip in
                DeltiqControlRow(
                    icon: equipmentIcon(equip),
                    label: String(localized: equip.localizedName),
                    showsDivider: equip != Equipment.allCases.last
                ) {
                    Toggle("", isOn: equipmentBinding(for: equip))
                        .labelsHidden()
                        .tint(Color.deltiqOrange)
                }
            }
            hintRow(String(localized: "profile.equipment.footer", bundle: .module))
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

    private func equipmentBinding(for equipment: Equipment) -> Binding<Bool> {
        Binding(
            get: { profile.equipmentPreferences.contains(equipment) },
            set: { isOn in
                var current = profile.equipmentPreferences
                if isOn { current.insert(equipment) } else { current.remove(equipment) }
                profile.equipmentPreferences = current
            }
        )
    }

    /// Spiegelung von `ExercisePickerView.equipmentIcon` für visuelle
    /// Konsistenz mit dem Picker (gleiche SF-Symbole).
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

    /// DEL-101: Nachträgliche Bearbeitung des Coaching-Stils. Bind direkt
    /// auf die Computed-Properties von `UserBodyProfile` (die sich um das
    /// rawValue-Mapping kuemmern). Picker-Style "menu" damit beide Werte
    /// kompakt in eine Zeile passen.
    private var coachingCard: some View {
        DeltiqSection(String(localized: "profile.section.coach", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "profile.coaching.goal", bundle: .module)) {
                Picker(selection: Binding(
                    get: { profile.trainingGoal },
                    set: { profile.trainingGoal = $0 }
                )) {
                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
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

    /// DEL-106-Muster (siehe MeasurementView.decimalField): TextField mit Decimal-
    /// Keyboard, rechtsbuendig, `fitnessNumberStyle()`. Zwei Overloads (optional/
    /// nicht-optional), weil `UserBodyProfile.heightCm` non-optional ist,
    /// `goalWeightKg` aber `Double?`.
    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    /// Fix "70,050003"-Bug: `roundsToWeightPrecision` ist NUR fuer das
    /// Zielgewicht `true` (die andere Aufrufstelle, Wochen-Laufvolumen in
    /// km, bleibt unveraendert). Rundet den geschriebenen Wert sofort auf 2
    /// Nachkommastellen statt nur kosmetisch anzuzeigen.
    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String, roundsToWeightPrecision: Bool = false) -> some View {
        let displayValue: Binding<Double?> = roundsToWeightPrecision
            ? Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0?.rounded(toDecimals: 2) })
            : value
        let style: FloatingPointFormatStyle<Double> = roundsToWeightPrecision
            ? .number.precision(.fractionLength(0...2))
            : .number
        TextField(label, value: displayValue, format: style, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    /// DEL-250: Int?-Variante von `decimalField` (Maximalpuls). Kein
    /// Dezimal-Keyboard noetig — ganzzahlige bpm-Eingabe.
    @ViewBuilder
    private func intField(_ label: String, value: Binding<Int?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

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

    private static let heightRange: ClosedRange<Double> = 100...250

    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
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
