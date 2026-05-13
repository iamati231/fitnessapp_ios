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
            healthKitSection
        }
        .navigationTitle("Profil bearbeiten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
        // DEL-047 + DEL-049: Trainingsort-Aenderung im Profil triggert
        // EINEN von zwei Dialogen je nach Situation:
        //  * Restore-Prompt (DEL-049 "Urlaub zu Ende"): wenn irgendein Plan
        //    aktive Ersatz-Uebungen mit `swappedFromOriginal` haelt, deren
        //    Originale im neuen Env wieder kompatibel waeren.
        //  * Adapt-Prompt (DEL-047 Standard): Top-Down-Anpassung wie bisher.
        // Pruefung erst NACH oldValue!=newValue UND nach dem
        // mind-ein-Plan-mit-Uebungen-Check, damit der initiale Profile-Set
        // im Onboarding NICHT nervt.
        .onChange(of: profile.environment) { oldValue, newValue in
            guard oldValue != newValue,
                  allPlans.contains(where: { plan in
                      plan.days.contains(where: { !$0.activeExercises.isEmpty })
                  })
            else { return }
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
            "Trainingsort geändert",
            isPresented: Binding(
                get: { pendingProfileEnvSwap != nil },
                set: { if !$0 { pendingProfileEnvSwap = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingProfileEnvSwap
        ) { swap in
            Button("Ja, Pläne anpassen") {
                applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvSwap = nil
            }
            Button("Nein, so lassen") {
                pendingProfileEnvSwap = nil
            }
        } message: { swap in
            Text("Du hast deinen Trainingsort auf \(environmentLabel(swap.newEnv)) geändert. Sollen deine bestehenden Trainingspläne automatisch an das dort verfügbare Equipment angepasst werden?")
        }
        // DEL-049 "Urlaub zu Ende": ein anderer Dialog, weil der User
        // gespeicherte Gym-Originale aus dem Urlaubs-Modus zurueckholen will.
        .confirmationDialog(
            "Ursprüngliche Übungen wiederherstellen?",
            isPresented: Binding(
                get: { pendingProfileEnvRestore != nil },
                set: { if !$0 { pendingProfileEnvRestore = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingProfileEnvRestore
        ) { swap in
            Button("Ja, wiederherstellen") {
                applyEnvironmentRestoreToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvRestore = nil
            }
            Button("Nein, neu anpassen") {
                applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                pendingProfileEnvRestore = nil
            }
        } message: { swap in
            Text("Wir haben Original-Übungen aus einem früheren Equipment-Wechsel gespeichert. Möchtest du diese in deinen Plänen wiederherstellen (inkl. der letzten Arbeitsgewichte)?")
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

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "ohne Equipment"
        }
    }

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            if !healthKit.isAvailable {
                Label("Apple Health nicht verfügbar.", systemImage: "heart.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                switch healthKit.authorizationStatus {
                case .sharingAuthorized:
                    Button {
                        Task { await pullProfileFromHealthKit() }
                    } label: {
                        if healthKitFetchInProgress {
                            HStack { ProgressView(); Text("Lade …") }
                        } else {
                            Label("Aus Apple Health übernehmen", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(healthKitFetchInProgress)
                    if !healthKitFilledFields.isEmpty {
                        Label("Aus Apple Health übernommen: \(healthKitFilledFields.sorted().joined(separator: ", "))",
                              systemImage: "heart.fill")
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
                        Label("Apple Health verbinden", systemImage: "heart.fill")
                    }
                case .sharingDenied:
                    Label("Berechtigung verweigert. Aktiviere sie in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .unavailable:
                    EmptyView()
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Pre-fill von Geburtsdatum, Geschlecht und Größe aus dem Apple-Health-Profil. Manuelle Eingaben werden NICHT überschrieben, wenn sie schon plausible Werte haben.")
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
                Text("Männlich").tag(BodyFormulaProfile.male)
                Text("Weiblich").tag(BodyFormulaProfile.female)
            } label: {
                Text("Geschlecht")
            }
            .pickerStyle(.segmented)

            DatePicker(
                selection: $profile.birthDate,
                in: Self.minBirthDate ... Date(),
                displayedComponents: .date
            ) {
                Text("Geburtsdatum")
            }
        } header: {
            Text("Person")
        } footer: {
            Text("Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein.")
                .font(.footnote)
        }
    }

    private var bodySection: some View {
        Section {
            TextField(value: $profile.heightCm, format: .number,
                      prompt: Text("z.B. 180")) {
                Text("Größe (cm)")
            }
            .decimalKeyboard()
        } header: {
            Text("Körpermasse")
        } footer: {
            if !Self.heightRange.contains(profile.heightCm) {
                Text("Plausibel: \(Int(Self.heightRange.lowerBound))–\(Int(Self.heightRange.upperBound)) cm.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Alle Berechnungen lesen Höhe metrisch aus dieser Quelle.")
                    .font(.footnote)
            }
        }
    }

    private var goalSection: some View {
        Section {
            TextField(value: $profile.goalWeightKg, format: .number,
                      prompt: Text("z.B. 75")) {
                Text("Zielgewicht (kg, optional)")
            }
            .decimalKeyboard()

            Picker(selection: $profile.environment) {
                Text("Gym").tag(EnvironmentType.gym)
                Text("Home-Gym").tag(EnvironmentType.homeGym)
                Text("Ohne Equipment").tag(EnvironmentType.noEquipment)
            } label: {
                Text("Trainingsort")
            }
        } header: {
            Text("Ziel & Training")
        } footer: {
            Text("Das Zielgewicht erscheint als grüne Linie im Dashboard-Trend-Chart. Trainingsort filtert später Plan-Empfehlungen.")
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
