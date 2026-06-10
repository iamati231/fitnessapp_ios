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

    @State private var healthKitFetchInProgress: Bool = false
    @State private var healthKitFilledFields: Set<String> = []

    // DEL-047: aktive Plaene laden, damit wir bei einer Trainingsort-Aenderung
    // einen Sync-Prompt anbieten koennen. Wir laden alle Plaene (auch
    // inaktive) — der User-Erwartung nach soll sich "mein Trainingsort" auch
    // auf seine Programm-Bibliothek auswirken, nicht nur den aktuell aktiven
    // Plan.
    @Query(sort: \TrainingPlan.name)
    private var allPlans: [TrainingPlan]

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
    }

    public var body: some View {
        Form {
            personSection
            bodySection
            goalSection
            weeklyGoalSection
            equipmentSection
            coachingSection
            healthKitSection
        }
        .navigationTitle("Profil bearbeiten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            if !healthKit.isAvailable {
                Label {
                    Text("onboarding.health.unavailable", bundle: .module)
                } icon: {
                    Image(systemName: "heart.slash")
                }
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                switch healthKit.authorizationStatus {
                case .sharingAuthorized:
                    Button {
                        Task { await pullProfileFromHealthKit() }
                    } label: {
                        if healthKitFetchInProgress {
                            HStack { ProgressView(); Text("onboarding.health.loading", bundle: .module) }
                        } else {
                            Label {
                                Text("profile.health.pull", bundle: .module)
                            } icon: {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                    }
                    .disabled(healthKitFetchInProgress)
                    if !healthKitFilledFields.isEmpty {
                        Label {
                            Text(String(format: String(localized: "profile.health.pulled", bundle: .module), healthKitFilledFields.sorted().joined(separator: ", ")))
                        } icon: {
                            Image(systemName: "heart.fill")
                        }
                            .font(.caption)
                            .foregroundStyle(.pink)
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
                        Label {
                            Text("onboarding.health.title", bundle: .module)
                        } icon: {
                            Image(systemName: "heart.fill")
                        }
                    }
                case .sharingDenied:
                    Label {
                        Text("profile.health.denied", bundle: .module)
                    } icon: {
                        Image(systemName: "heart.slash")
                    }
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .unavailable:
                    EmptyView()
                }
            }
        } header: {
            Text("profile.section.health", bundle: .module)
        } footer: {
            Text("profile.health.footer", bundle: .module)
                .font(.footnote)
        }
    }

    private func pullProfileFromHealthKit() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()
        var filled: Set<String> = []

        // Conservative: nur ersetzen, wenn der existierende Wert "default-haft"
        // aussieht (zB Geburtsdatum vor 1900 oder Höhe == 0). Andernfalls
        // koennte ein versehentlicher Pull die Manuelle-Eingabe ueberschreiben.
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

    private var personSection: some View {
        // All inner widgets use trailing-closure Label forms — same pattern as
        // OnboardingView. The positional `Picker(_ titleKey:)` / `DatePicker(_ titleKey:)` /
        // `TextField(_ titleKey:value:format:)` forms confuse the type checker on macOS
        // toolchains when nested inside Section + footer + multiple statements.
        Section {
            Picker(selection: $profile.profile) {
                Text("sex.male", bundle: .module).tag(BodyFormulaProfile.male)
                Text("sex.female", bundle: .module).tag(BodyFormulaProfile.female)
            } label: {
                Text("onboarding.field.sex", bundle: .module)
            }
            .pickerStyle(.segmented)

            DatePicker(
                selection: $profile.birthDate,
                in: Self.minBirthDate ... Date(),
                displayedComponents: .date
            ) {
                Text("onboarding.field.birthdate", bundle: .module)
            }
        } header: {
            Text("profile.section.person", bundle: .module)
        } footer: {
            Text("profile.person.footer", bundle: .module)
                .font(.footnote)
        }
    }

    private var bodySection: some View {
        Section {
            TextField(value: $profile.heightCm, format: .number,
                      prompt: Text("profile.body.heightPlaceholder", bundle: .module)) {
                Text("onboarding.field.heightCm", bundle: .module)
            }
            .decimalKeyboard()
        } header: {
            Text("profile.section.body", bundle: .module)
        } footer: {
            if !Self.heightRange.contains(profile.heightCm) {
                let template = String(localized: "profile.body.plausible", bundle: .module)
                Text(template
                    .replacingOccurrences(of: "%1$lld", with: "\(Int(Self.heightRange.lowerBound))")
                    .replacingOccurrences(of: "%2$lld", with: "\(Int(Self.heightRange.upperBound))"))
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("profile.body.footerOk", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    private var goalSection: some View {
        Section {
            TextField(value: $profile.goalWeightKg, format: .number,
                      prompt: Text("profile.goal.weightPlaceholder", bundle: .module)) {
                Text("onboarding.field.goalWeightKg", bundle: .module)
            }
            .decimalKeyboard()

            Picker(selection: $profile.environment) {
                Text("environment.gym", bundle: .module).tag(EnvironmentType.gym)
                Text("environment.home_gym", bundle: .module).tag(EnvironmentType.homeGym)
                Text("environment.no_equipment", bundle: .module).tag(EnvironmentType.noEquipment)
            } label: {
                Text("onboarding.field.environment", bundle: .module)
            }
        } header: {
            Text("onboarding.section.goals", bundle: .module)
        } footer: {
            Text("profile.goal.footer", bundle: .module)
                .font(.footnote)
        }
    }

    /// DEL-170: Equipment-Präferenzen (Multi-Select). Steuert die Auswahl
    /// von `EquipmentVariant` bei Templates mit mehreren Implement-Varianten
    /// (z.B. Hybrid-Pläne: Barbell-Gym vs. Dumbbell-Only). Default leer →
    /// Plan-Matcher behandelt das wie "nicht gepflegt" und nimmt die
    /// Standard-Variante; sobald der User mindestens eine Box ankreuzt,
    /// wirken die Präferenzen sofort beim nächsten Plan-Adopt.
    @ViewBuilder
    private var equipmentSection: some View {
        Section {
            ForEach(Equipment.allCases, id: \.self) { equip in
                Toggle(isOn: equipmentBinding(for: equip)) {
                    Label {
                        Text(equip.localizedName)
                    } icon: {
                        Image(systemName: equipmentIcon(equip))
                            .foregroundStyle(Color.deltiqOrange)
                    }
                }
            }
        } header: {
            Text("profile.equipment.header", bundle: .module)
        } footer: {
            Text("profile.equipment.footer", bundle: .module)
                .font(.footnote)
        }
    }

    /// DEL-203: Wochenziel für den Trainings-Streak. Stepper 1-7 —
    /// der Kalender-Streak zählt nur Wochen, die das Ziel erfüllen.
    @ViewBuilder
    private var weeklyGoalSection: some View {
        Section {
            Stepper(value: Binding(
                get: { profile.weeklyWorkoutGoal },
                set: { profile.weeklyWorkoutGoal = min(7, max(1, $0)) }
            ), in: 1...7) {
                HStack {
                    Label {
                        Text("profile.weeklyGoal.label", bundle: .module)
                    } icon: {
                        Image(systemName: "flame")
                            .foregroundStyle(Color.deltiqOrange)
                    }
                    Spacer()
                    Text("\(profile.weeklyWorkoutGoal)×")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("profile.weeklyGoal.header", bundle: .module)
        } footer: {
            Text("profile.weeklyGoal.footer", bundle: .module)
                .font(.footnote)
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
    @ViewBuilder
    private var coachingSection: some View {
        Section {
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
                Text("profile.coaching.goal", bundle: .module)
            }
            .pickerStyle(.menu)

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
                Text("profile.coaching.tone", bundle: .module)
            }
            .pickerStyle(.menu)
        } header: {
            Text("profile.section.coach", bundle: .module)
        } footer: {
            Text("profile.coaching.footer", bundle: .module)
                .font(.footnote)
        }
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
