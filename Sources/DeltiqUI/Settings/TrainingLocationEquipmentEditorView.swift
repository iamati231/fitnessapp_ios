#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import DeltiqCore
import DeltiqData

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md): kombinierter
/// Trainingsort+Ausstattung-Editor — ersetzt die getrennten `goalCard`-
/// Umgebungs-Picker-Zeile und `equipmentCard`-Sheet in `ProfileEditorView`.
/// Reiner Profil-Editor: Speichern aendert ausschliesslich `profile.environment`/
/// `equipmentProfile`/`equipmentProfileConfirmedComplete` — NIE bestehende
/// Plaene direkt. Die Plan-Anpassung (`PlanEnvironmentMigrator` ueber die
/// `envSwap`/`envRestore`-Dialoge) lebt vollstaendig in DIESEM Editor: die
/// `pendingEnvSwap`/`pendingEnvRestore`-Dialoge unten werden in `save()` gesetzt,
/// sobald `profile.environment` tatsaechlich geschrieben wird — eine separate,
/// ausdruecklich vom User bestaetigte Aktion. `ProfileEditorView` haelt keinen
/// eigenen `onChange`-Handler mehr (waere ein Doppeltrigger desselben Dialogs).
///
/// Lokaler Draft mit explizitem Speichern/Abbrechen (Vorgabe Punkt 3). Die
/// bestehende `EquipmentProfileEditor`-Komponente (Phase 6, EINZIGE UI fuer
/// Equipment-Erfassung) wird unveraendert wiederverwendet — kein zweiter
/// Equipment-Editor.
@available(iOS 17.0, macOS 14.0, *)
struct TrainingLocationEquipmentEditorView: View {
    @Bindable var profile: UserBodyProfile

    @Environment(\.dismiss) private var dismiss
    /// P5.1 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): fuer den neuen Equipment-
    /// Aenderungs-Trigger unten — analog zum bestehenden `envSwap`-Dialog in
    /// `ProfileEditorView`, nur fuer ein geaendertes `UserEquipmentProfile`
    /// statt eines geaenderten `EnvironmentType`.
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [TrainingPlan]

    @State private var draftEnvironment: EnvironmentType
    @State private var draftEquipmentProfile: UserEquipmentProfile
    /// Non-nil zeigt den Equipment-Aenderungs-`confirmationDialog` unten —
    /// gesetzt NACH dem eigentlichen Profil-Save, wenn mindestens ein Plan
    /// gegen das NEUE Equipment nicht mehr `.available` ist.
    @State private var pendingEquipmentAdaptation: UserEquipmentProfile?
    /// Analog `BodyDataEditorView.weightTouched`: nur eine tatsaechliche
    /// Interaktion mit dem Equipment-Editor darf `confirmEquipmentProfileComplete()`
    /// ausloesen — ein reiner Trainingsort-Wechsel ohne Equipment-Beruehrung
    /// darf eine vorhandene Gym-Annahme nicht ungefragt in eine volle
    /// Bestaetigung umwandeln.
    @State private var equipmentTouched = false
    /// UI-Refactor (DeltiqHeader-Muster): siehe `BodyDataEditorView`.
    @State private var showingDiscardConfirm = false
    /// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): Doppeltap-
    /// Schutz fuer `save()`.
    @State private var isSaving = false
    /// Task 5: sichtbare Fehlermeldung — es gab bisher GAR keinen
    /// `modelContext.save()`-Aufruf (`profile` ist `@Bindable`, mutiert nur
    /// den Live-Objektgraphen). Besonders wichtig hier: `applyEquipment-
    /// Adaptations` (Plan-Uebungs-Tausch) darf erst feuern, NACHDEM dieser
    /// Save tatsaechlich bestaetigt ist — siehe `save()`.
    @State private var saveErrorMessage: String?
    /// Analog `ProfileEditorView.pendingProfileEnvSwap`: non-nil zeigt den
    /// Env-Wechsel-Dialog. Muss hier leben statt in `ProfileEditorView`,
    /// weil `dismiss()` und `confirmationDialog` nicht gleichzeitig korrekt
    /// funktionieren (Sheet-Dismiss-Animation blockiert neuen Dialog).
    @State private var pendingEnvSwap: PendingEnvSwap?
    @State private var pendingEnvRestore: PendingEnvSwap?
    /// Zwischengespeichertes Flag aus `save()` — nach dem env-frühen Return
    /// wissen die Dialog-Handler nicht mehr, ob Equipment auch geändert wurde.
    @State private var equipmentChangedOnSave = false

    private struct PendingEnvSwap: Equatable {
        let oldEnv: EnvironmentType
        let newEnv: EnvironmentType
    }

    init(profile: UserBodyProfile) {
        self.profile = profile
        _draftEnvironment = State(initialValue: profile.environment)
        // Gym ohne bestaetigtes Profil: direkt mit gymFull vorbefuellen,
        // damit der Nutzer beim Speichern automatisch alle Items bestaetigt.
        let initialEquipment = (profile.environment == .gym && !profile.equipmentProfileConfirmedComplete)
            ? UserEquipmentProfile.gymFull
            : profile.equipmentProfile
        _draftEquipmentProfile = State(initialValue: initialEquipment)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UI-Refactor (DeltiqHeader-Muster fuer Editoren): siehe
                // `BodyDataEditorView` fuer die ausfuehrliche Begruendung.
                DeltiqHeader(
                    eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                    title: String(localized: "profile.trainingLocation.title", bundle: .module),
                    onBack: { isDirty ? (showingDiscardConfirm = true) : dismiss() },
                    actions: [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            isDisabled: isSaving,
                            accessibilityLabel: String(localized: "common.save", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let saveErrorMessage {
                            errorRow(saveErrorMessage)
                        }
                        locationSection
                        equipmentSection
                    }
                    .padding()
                }
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            // UI-Refactor (Korrektur, Punkt 4): interaktives Wegziehen des
            // Sheets ist sonst ein ungesicherter Verlassen-Weg am Discard-
            // Dialog vorbei. Ohne Aenderungen (`!isDirty`) bleibt es normal
            // moeglich (direktes Schliessen).
            .interactiveDismissDisabled(isDirty || pendingEquipmentAdaptation != nil || pendingEnvSwap != nil || pendingEnvRestore != nil)
            .onAppear {
                if draftEnvironment == .gym, !profile.equipmentProfileConfirmedComplete {
                    equipmentTouched = true
                }
            }
            .onChange(of: draftEnvironment) { _, newValue in
                switch newValue {
                case .gym:
                    draftEquipmentProfile = .gymFull
                    equipmentTouched = true
                case .noEquipment:
                    var bodyweight = UserEquipmentProfile()
                    bodyweight.confirmRemainingAsUnavailable()
                    draftEquipmentProfile = bodyweight
                    equipmentTouched = true
                case .homeGym:
                    break
                }
            }
            // P5.1: analog `ProfileEditorView`s `envSwap`-Dialog (siehe
            // dortige Button-Texte, hier wiederverwendet — gleiche
            // Ja/Nein-Semantik, nur ein anderer Ausloeser). Erscheint ERST
            // nachdem `save()` das Profil bereits geschrieben hat — die
            // Equipment-Praeferenz selbst ist nie von dieser Entscheidung
            // abhaengig, nur die PLAN-Anpassung ist es.
            .confirmationDialog(
                Text("profile.equipmentSwap.title", bundle: .module),
                isPresented: Binding(
                    get: { pendingEquipmentAdaptation != nil },
                    // Task 5: `dismiss()` wanderte aus diesem Setter heraus
                    // in die beiden Buttons unten — sonst wuerde SwiftUIs
                    // eigenes "Dialog schliesst sich nach Button-Tap"-
                    // Verhalten den Editor IMMER verlassen, auch wenn der
                    // Confirm-Button-Handler unten gerade einen fehl-
                    // geschlagenen Save meldet (siehe dortiger Kommentar).
                    set: { if !$0 { pendingEquipmentAdaptation = nil } }
                )
            ) {
                Button {
                    if let newProfile = pendingEquipmentAdaptation {
                        applyEquipmentAdaptations(against: newProfile)
                    }
                    pendingEquipmentAdaptation = nil
                    // Task 5: `applyEquipmentAdaptations` mutiert/inserted
                    // direkt auf `modelContext`, ohne selbst zu speichern
                    // (`PlanEquipmentAdaptationApplier.apply` speichert
                    // nicht) — ohne diesen expliziten Save haengt der
                    // Uebungs-Tausch an SwiftDatas implizitem Autosave. Bei
                    // einem Fehler bleibt der Editor bewusst OFFEN (kein
                    // `dismiss()`) — der Nutzer soll nicht glauben, der
                    // Tausch sei uebernommen, waehrend er es nicht ist.
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                    }
                } label: {
                    Text("profile.envSwap.confirm", bundle: .module)
                }
                Button(role: .cancel) {
                    pendingEquipmentAdaptation = nil
                    dismiss()
                } label: {
                    Text("profile.envSwap.keep", bundle: .module)
                }
            } message: {
                Text("profile.equipmentSwap.message", bundle: .module)
            }
            .confirmationDialog(
                Text("profile.envSwap.title", bundle: .module),
                isPresented: Binding(
                    get: { pendingEnvSwap != nil },
                    set: { if !$0 { pendingEnvSwap = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingEnvSwap
            ) { swap in
                Button {
                    applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                    pendingEnvSwap = nil
                    checkAndHandleEquipmentGap()
                } label: {
                    Text("profile.envSwap.confirm", bundle: .module)
                }
                Button(role: .cancel) {
                    pendingEnvSwap = nil
                    checkAndHandleEquipmentGap()
                } label: {
                    Text("profile.envSwap.keep", bundle: .module)
                }
            } message: { swap in
                Text(String(format: String(localized: "profile.envSwap.message", bundle: .module), String(localized: swap.newEnv.localizedName)))
            }
            .confirmationDialog(
                Text("profile.envRestore.title", bundle: .module),
                isPresented: Binding(
                    get: { pendingEnvRestore != nil },
                    set: { if !$0 { pendingEnvRestore = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingEnvRestore
            ) { swap in
                Button {
                    applyEnvironmentRestoreToAllPlans(newEnv: swap.newEnv)
                    pendingEnvRestore = nil
                    checkAndHandleEquipmentGap()
                } label: {
                    Text("profile.envRestore.confirm", bundle: .module)
                }
                Button {
                    applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                    pendingEnvRestore = nil
                    checkAndHandleEquipmentGap()
                } label: {
                    Text("profile.envRestore.adjustNew", bundle: .module)
                }
            } message: { _ in
                Text("profile.envRestore.message", bundle: .module)
            }
        }
    }

    /// UI-Refactor (DeltiqHeader-Muster): `UserEquipmentProfile`/`EnvironmentType`
    /// sind beide `Equatable` — reiner Wertevergleich gegen den Ausgangszustand.
    private var isDirty: Bool {
        draftEnvironment != profile.environment || draftEquipmentProfile != profile.equipmentProfile
    }

    private var locationSection: some View {
        DeltiqSection(String(localized: "onboarding.field.environment", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "onboarding.field.environment", bundle: .module), showsDivider: false) {
                Picker(selection: $draftEnvironment) {
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

    private var equipmentSection: some View {
        DeltiqSection(String(localized: "profile.equipment.header", bundle: .module).uppercased()) {
            hintRow(equipmentStatusText)
            EquipmentProfileEditor(equipmentProfile: Binding(
                get: { draftEquipmentProfile },
                set: { draftEquipmentProfile = $0; equipmentTouched = true }
            ), showsCounts: draftEnvironment != .gym)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    /// Identische Logik zu `ProfileEditorView.equipmentStatusText`, auf den
    /// Draft-Werten statt dem live gebundenen Profil — ein nicht individuell
    /// eingerichtetes Gym zeigt nie "nicht erfasst" (`EquipmentPlanningContext`).
    private var equipmentStatusText: String {
        guard profile.equipmentProfileConfirmedComplete else {
            let hasAnySelection = EquipmentItem.allCases.contains { draftEquipmentProfile.availability(for: $0) == .available }
            if hasAnySelection {
                return String(localized: "profile.equipment.status.inProgress", bundle: .module)
            }
            if draftEnvironment == .gym {
                return String(localized: "profile.equipment.status.gymAssumption", bundle: .module)
            }
            return String(localized: "profile.equipment.status.notSet", bundle: .module)
        }
        let isBodyweightOnly = EquipmentItem.allCases.allSatisfy { draftEquipmentProfile.availability(for: $0) == .unavailable }
        return String(localized: isBodyweightOnly ? "profile.equipment.status.bodyweightOnly" : "profile.equipment.status.confirmed", bundle: .module)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        // P5.1: VOR dem Schreiben erfassen — danach ist `profile.equipmentProfile`
        // bereits der neue Wert und ein Vergleich waere immer `false`.
        let equipmentChanged = draftEquipmentProfile != profile.equipmentProfile

        // Audit-Fund (Laufcoaching-Folgeauftrag, gleicher Fehler wie Finding 3 in
        // `CardioGoalEditorView.save()`, Commit 8bdb416): Schnappschuss ALLER vier Felder, die
        // gleich mutiert werden - inklusive der drei, die `confirmEquipmentProfileComplete()`
        // selbst anfasst (siehe dortige Doku: `equipmentProfile`/`equipmentProfileConfirmedComplete`/
        // `equipmentPreferences` zusammen), nicht nur die zwei direkt sichtbaren Zeilen darunter.
        // Ohne das blieb `profile` nach einem fehlgeschlagenen `context.save()` mit den nie
        // bestaetigten Entwurfswerten stehen.
        let originalEnvironment = profile.environment
        let originalEquipmentProfile = profile.equipmentProfile
        let originalEquipmentProfileConfirmedComplete = profile.equipmentProfileConfirmedComplete
        let originalEquipmentPreferences = profile.equipmentPreferences

        profile.environment = draftEnvironment
        profile.equipmentProfile = draftEquipmentProfile
        if equipmentTouched {
            profile.confirmEquipmentProfileComplete()
        }

        // Task 5: vorher GAR kein `context.save()` — `profile` ist
        // `@Bindable` und mutiert nur den Live-Objektgraphen. Besonders
        // wichtig: der Equipment-Anpassungs-Dialog (und damit
        // `applyEquipmentAdaptations`) darf erst NACH einem bestaetigten
        // Save ueberhaupt in Betracht gezogen werden — sonst wuerde ein
        // fehlgeschlagener Profil-Save trotzdem einen Plan-Uebungs-Tausch
        // anbieten, der auf einem nie persistierten Profilstand basiert.
        do {
            try modelContext.save()
        } catch {
            // KEIN `modelContext.rollback()` - das wuerde auch andere, unabhaengige, noch
            // ausstehende Aenderungen im (typischerweise app-weit geteilten) Context verwerfen.
            profile.environment = originalEnvironment
            profile.equipmentProfile = originalEquipmentProfile
            profile.equipmentProfileConfirmedComplete = originalEquipmentProfileConfirmedComplete
            profile.equipmentPreferences = originalEquipmentPreferences
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            isSaving = false
            return
        }

        // Env-Wechsel-Dialog muss VOR dismiss() gezeigt werden — iOS kann
        // keinen neuen Dialog zeigen, waehrend das Sheet-Dismiss animiert.
        // Wenn der Env sich geaendert hat und es nicht-leere Plaene gibt,
        // zeigen wir den envSwap/envRestore-Dialog hier (nicht in
        // ProfileEditorView.onChange wie urspruenglich geplant).
        let environmentChanged = originalEnvironment != draftEnvironment
        if environmentChanged, plans.contains(where: { $0.days.contains(where: { !$0.activeExercises.isEmpty }) }) {
            let pending = PendingEnvSwap(oldEnv: originalEnvironment, newEnv: draftEnvironment)
            // Für die Dialog-Handler merken, ob Equipment ebenfalls geändert wurde —
            // nach dem frühen Return ist `equipmentChanged` aus dem Dialog nicht mehr zugänglich.
            equipmentChangedOnSave = equipmentChanged
            if PlanEnvironmentMigrator.hasAnyRestorableOriginals(plans: plans, forEnvironment: draftEnvironment) {
                pendingEnvRestore = pending
            } else {
                pendingEnvSwap = pending
            }
            isSaving = false
            return
        }

        // Ab hier IMMER `profile.equipmentProfile` verwenden, nie mehr den
        // lokalen `draftEquipmentProfile` — bei `equipmentTouched` hat
        // `confirmEquipmentProfileComplete()` oben jedes noch unberuehrte
        // Item von `.unknown` auf `.unavailable` gezogen (Pflicht-Test 6).
        // `PlanEquipmentChecker`/`ExerciseSubstitutionEngine` ersetzen aber
        // AUSSCHLIESSLICH definitiv `.unavailable` Luecken (`report.missing`)
        // — ein `.unknown`-Item zaehlt nur als "ungeklaert" und wuerde nie
        // ersetzt. Mit dem alten Draft haette der Dialog zwar erscheinen
        // koennen (`!isAvailable` ist fuer `.unknown` ebenfalls wahr), ein
        // Bestaetigen waere aber wirkungslos geblieben, weil `preview(...)`
        // dieselbe (noch unbestaetigte) Uebung erneut nur als "ungeklaert"
        // einstuft.
        let resolvedProfile = profile.equipmentProfile
        if equipmentChanged, hasAnyPlanWithEquipmentGap(against: resolvedProfile) {
            pendingEquipmentAdaptation = resolvedProfile
            // Fix-Runde 1 (Befund 1): dieser Zweig dismisst NICHT -- der
            // `confirmationDialog` unten kann durch Wegtippen (ausserhalb,
            // ohne Confirm/Cancel-Button) geschlossen werden, ohne dass
            // `dismiss()` je aufgerufen wird. Ohne dieses Reset bliebe der
            // Speichern-Haken dann fuer immer deaktiviert.
            isSaving = false
            return
        }
        dismiss()
    }

    /// Nur nicht-leere Plaene zaehlen — leere haben nichts anzupassen
    /// (identische Filterung wie `PlanEnvironmentMigrator.migrateAll`).
    private func hasAnyPlanWithEquipmentGap(against newProfile: UserEquipmentProfile) -> Bool {
        plans.contains { plan in
            guard plan.days.contains(where: { !$0.activeExercises.isEmpty }) else { return false }
            return !PlanEquipmentAdaptationApplier.check(plan: plan, against: newProfile).isAvailable
        }
    }

    /// Nach einem Env-Dialog: Equipment-Gap-Prüfung, die `save()` wegen des
    /// frühen Returns nicht mehr erreicht hat.
    private func checkAndHandleEquipmentGap() {
        let resolvedProfile = profile.equipmentProfile
        if equipmentChangedOnSave, hasAnyPlanWithEquipmentGap(against: resolvedProfile) {
            pendingEquipmentAdaptation = resolvedProfile
        } else {
            dismiss()
        }
    }

    /// `profile.trainingGoal`/`.experienceTrack` beschreiben DIESEN User,
    /// nicht einen frei erfundenen Plan-Kontext — derselbe Wert, den
    /// `ProgramTemplatePickerView.instantiate`s eigener Veraltungs-Resolve-
    /// Pfad bereits nutzt (kein neu eingefuehrtes Muster).
    private func applyEquipmentAdaptations(against newProfile: UserEquipmentProfile) {
        let context = SubstitutionContext(goal: profile.trainingGoal, experienceTrack: profile.experienceTrack)
        for plan in plans where plan.days.contains(where: { !$0.activeExercises.isEmpty }) {
            let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: newProfile, context: context)
            guard !draft.replacements.isEmpty else { continue }
            PlanEquipmentAdaptationApplier.apply(plan: plan, draft: draft, modelContext: modelContext)
        }
    }

    private func applyEnvironmentSwapToAllPlans(newEnv: EnvironmentType) {
        _ = PlanEnvironmentMigrator.migrateAll(plans: plans, toEnvironment: newEnv, modelContext: modelContext)
    }

    private func applyEnvironmentRestoreToAllPlans(newEnv: EnvironmentType) {
        _ = PlanEnvironmentMigrator.restoreAll(plans: plans, toEnvironment: newEnv, modelContext: modelContext)
    }

    /// Task 5: identisches Inline-Fehler-Muster wie `GearListView.gearCard`.
    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.Deltiq.error)
    }
}
#endif
