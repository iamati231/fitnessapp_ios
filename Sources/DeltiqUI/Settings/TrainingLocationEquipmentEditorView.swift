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
    /// Snapshots der drei Equipment-Felder vor dem letzten save() —
    /// damit envSwap/envRestore-Abbrechen alle vier Felder wiederherstellt,
    /// nicht nur profile.environment.
    @State private var preSaveEquipmentProfile: UserEquipmentProfile? = nil
    @State private var preSaveEquipmentConfirmed: Bool? = nil
    @State private var preSaveEquipmentPreferences: Set<Equipment>? = nil
    /// Vollständige Vorschau-Daten für EquipmentAdaptationPreviewSheet.
    @State private var adaptationDrafts: [(planName: String, replacements: [(original: String, replacement: String)], unresolved: [String])] = []
    /// Env-Swap/Restore-Previews — vor Mutation berechnet (Issue #11, P1).
    @State private var envSwapPreviews: [EnvSwapPlanPreview] = []
    @State private var envRestorePreviews: [EnvSwapPlanPreview] = []

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
            // Vollständiges Preview-Sheet vor der Bestätigung (Issue #11):
            // zeigt konkrete Ersetzungen und zu archivierende Übungen je Plan.
            .sheet(isPresented: Binding(
                get: { pendingEquipmentAdaptation != nil },
                set: { if !$0 { pendingEquipmentAdaptation = nil } }
            )) {
                EquipmentAdaptationPreviewSheet(
                    drafts: adaptationDrafts,
                    onConfirm: {
                        let archived: [String]
                        if let newProfile = pendingEquipmentAdaptation {
                            archived = applyEquipmentAdaptations(against: newProfile)
                        } else {
                            archived = []
                        }
                        pendingEquipmentAdaptation = nil
                        do {
                            try modelContext.save()
                            if archived.isEmpty {
                                dismiss()
                            } else {
                                saveErrorMessage = String(localized: "profile.equipmentAdaptation.conflict", bundle: .module)
                                    + " " + archived.joined(separator: ", ")
                            }
                        } catch {
                            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                        }
                    },
                    onCancel: {
                        pendingEquipmentAdaptation = nil
                        dismiss()
                    }
                )
            }
            // Issue #11 P1: Env-Swap zeigt vollständige Vorschau VOR jeder Mutation.
            // Issue #11 P3: checkAndHandleEquipmentGap() nur nach erfolgreichem save().
            .sheet(isPresented: Binding(
                get: { pendingEnvSwap != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    // Button-Handler nullen pendingEnvSwap vor dem Dismiss;
                    // non-nil hier ⟹ Swipe-Dismiss ohne Auswahl → rollback.
                    if let swap = pendingEnvSwap { rollbackEnvChange(to: swap.oldEnv) }
                    pendingEnvSwap = nil
                }
            )) {
                if let swap = pendingEnvSwap {
                    EnvChangePreviewSheet(
                        newEnv: swap.newEnv,
                        previews: envSwapPreviews,
                        mode: .swap,
                        onConfirm: {
                            applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                            pendingEnvSwap = nil
                            do {
                                try modelContext.save()
                                checkAndHandleEquipmentGap()
                            } catch {
                                saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                            }
                        },
                        onSecondary: {
                            pendingEnvSwap = nil
                            checkAndHandleEquipmentGap()
                        },
                        onCancel: {
                            let oldEnv = swap.oldEnv
                            pendingEnvSwap = nil  // Sheet schließen; Binding.set findet nil → kein Rollback
                            rollbackEnvChange(to: oldEnv)
                        }
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingEnvRestore != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    if let swap = pendingEnvRestore { rollbackEnvChange(to: swap.oldEnv) }
                    pendingEnvRestore = nil
                }
            )) {
                if let swap = pendingEnvRestore {
                    EnvChangePreviewSheet(
                        newEnv: swap.newEnv,
                        previews: envRestorePreviews,
                        mode: .restore,
                        onConfirm: {
                            applyEnvironmentRestoreToAllPlans(newEnv: swap.newEnv)
                            pendingEnvRestore = nil
                            do {
                                try modelContext.save()
                                checkAndHandleEquipmentGap()
                            } catch {
                                saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                            }
                        },
                        onSecondary: {
                            applyEnvironmentSwapToAllPlans(newEnv: swap.newEnv)
                            pendingEnvRestore = nil
                            do {
                                try modelContext.save()
                                checkAndHandleEquipmentGap()
                            } catch {
                                saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
                            }
                        },
                        onCancel: {
                            let oldEnv = swap.oldEnv
                            pendingEnvRestore = nil  // Sheet schließen; Binding.set findet nil → kein Rollback
                            rollbackEnvChange(to: oldEnv)
                        }
                    )
                }
            }
        }
    }

    /// UI-Refactor (DeltiqHeader-Muster): `UserEquipmentProfile`/`EnvironmentType`
    /// sind beide `Equatable` — reiner Wertevergleich gegen den Ausgangszustand.
    /// Gemeinsamer Rollback für Swipe-Dismiss und Cancel-Button beider EnvChange-Sheets.
    /// Stellt alle vier Profil-Felder und Draft-State auf oldEnv zurück, speichert und
    /// dismisst den Editor nur bei erfolgreichem Save — kein stiller Zustandsbruch.
    private func rollbackEnvChange(to oldEnv: EnvironmentType) {
        profile.environment = oldEnv
        draftEnvironment = oldEnv
        if let ep = preSaveEquipmentProfile {
            profile.equipmentProfile = ep
            draftEquipmentProfile = ep
        }
        if let ec = preSaveEquipmentConfirmed { profile.equipmentProfileConfirmedComplete = ec }
        if let prefs = preSaveEquipmentPreferences { profile.equipmentPreferences = prefs }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
        }
    }

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

        // Vor der Mutation snapshot für env-Dialog-Cancel-Handler.
        preSaveEquipmentProfile = originalEquipmentProfile
        preSaveEquipmentConfirmed = originalEquipmentProfileConfirmedComplete
        preSaveEquipmentPreferences = originalEquipmentPreferences

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
                envRestorePreviews = PlanEnvironmentMigrator.previewRestoreAll(plans: plans, toEnvironment: draftEnvironment)
                pendingEnvRestore = pending
            } else {
                envSwapPreviews = PlanEnvironmentMigrator.previewMigrateAll(plans: plans, toEnvironment: draftEnvironment)
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
        if equipmentChanged {
            if computeAdaptationPreview(against: resolvedProfile) {
                pendingEquipmentAdaptation = resolvedProfile
                // Fix-Runde 1 (Befund 1): dieser Zweig dismisst NICHT -- der
                // `confirmationDialog` unten kann durch Wegtippen (ausserhalb,
                // ohne Confirm/Cancel-Button) geschlossen werden, ohne dass
                // `dismiss()` je aufgerufen wird. Ohne dieses Reset bliebe der
                // Speichern-Haken dann fuer immer deaktiviert.
                isSaving = false
                return
            }
        }
        dismiss()
    }

    /// Pre-compute adaptation drafts für das Preview-Sheet — keine Mutation.
    /// Gibt `true` zurück, wenn mindestens ein Plan eine Equipment-Lücke hat.
    @discardableResult
    private func computeAdaptationPreview(against newProfile: UserEquipmentProfile) -> Bool {
        let context = SubstitutionContext(goal: profile.trainingGoal, experienceTrack: profile.experienceTrack)
        var haGap = false
        var newDrafts: [(planName: String, replacements: [(original: String, replacement: String)], unresolved: [String])] = []
        for plan in plans where plan.days.contains(where: { !$0.activeExercises.isEmpty }) {
            guard !PlanEquipmentAdaptationApplier.check(plan: plan, against: newProfile).isAvailable else { continue }
            haGap = true
            let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: newProfile, context: context)
            newDrafts.append((
                planName: plan.name,
                replacements: draft.replacements.map { ($0.originalName, $0.replacementName) },
                unresolved: draft.unresolved.map { $0.exerciseName }
            ))
        }
        adaptationDrafts = newDrafts
        return haGap
    }

    /// Nach einem Env-Dialog: Equipment-Gap-Prüfung, die `save()` wegen des
    /// frühen Returns nicht mehr erreicht hat.
    private func checkAndHandleEquipmentGap() {
        guard equipmentChangedOnSave else { dismiss(); return }
        let resolvedProfile = profile.equipmentProfile
        if computeAdaptationPreview(against: resolvedProfile) {
            pendingEquipmentAdaptation = resolvedProfile
        } else {
            dismiss()
        }
    }

    /// `profile.trainingGoal`/`.experienceTrack` beschreiben DIESEN User,
    /// nicht einen frei erfundenen Plan-Kontext — derselbe Wert, den
    /// `ProgramTemplatePickerView.instantiate`s eigener Veraltungs-Resolve-
    /// Pfad bereits nutzt (kein neu eingefuehrtes Muster).
    ///
    /// Gibt die Namen archivierter Uebungen zurueck (`.noApprovedSubstitute`),
    /// damit die UI einen Konflikt-Hinweis zeigen kann statt still zu dismissen.
    @discardableResult
    private func applyEquipmentAdaptations(against newProfile: UserEquipmentProfile) -> [String] {
        let context = SubstitutionContext(goal: profile.trainingGoal, experienceTrack: profile.experienceTrack)
        var allArchived: [String] = []
        for plan in plans where plan.days.contains(where: { !$0.activeExercises.isEmpty }) {
            let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: newProfile, context: context)
            if !draft.replacements.isEmpty {
                PlanEquipmentAdaptationApplier.apply(plan: plan, draft: draft, modelContext: modelContext)
            }
            let archived = PlanEquipmentAdaptationApplier.archiveUnresolved(plan: plan, draft: draft, modelContext: modelContext)
            allArchived.append(contentsOf: archived)
        }
        return allArchived
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

// MARK: - Preview-Sheet

@available(iOS 17.0, macOS 14.0, *)
private struct EquipmentAdaptationPreviewSheet: View {
    let drafts: [(planName: String, replacements: [(original: String, replacement: String)], unresolved: [String])]
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(drafts.indices, id: \.self) { i in
                    let d = drafts[i]
                    Section(d.planName) {
                        ForEach(d.replacements.indices, id: \.self) { j in
                            let r = d.replacements[j]
                            HStack(spacing: 6) {
                                Text(r.original).foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                Text(r.replacement)
                            }
                            .font(.subheadline)
                        }
                        ForEach(d.unresolved, id: \.self) { name in
                            Label(name, systemImage: "archivebox")
                                .font(.subheadline)
                                .foregroundStyle(Color.Deltiq.error)
                        }
                    }
                }
            }
            .navigationTitle(Text("profile.equipmentSwap.title", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: onCancel) {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onConfirm) {
                        Text("profile.envSwap.confirm", bundle: .module)
                    }
                }
            }
        }
    }
}

// MARK: - Env-Change Preview-Sheet (Issue #11 P1)

@available(iOS 17.0, macOS 14.0, *)
private struct EnvChangePreviewSheet: View {
    enum Mode { case swap, restore }

    let newEnv: EnvironmentType
    let previews: [EnvSwapPlanPreview]
    let mode: Mode
    var onConfirm: () -> Void
    var onSecondary: () -> Void
    var onCancel: () -> Void

    private var confirmKey: LocalizedStringKey {
        mode == .swap ? "profile.envSwap.confirm" : "profile.envRestore.confirm"
    }
    private var secondaryKey: LocalizedStringKey {
        mode == .swap ? "profile.envSwap.keep" : "profile.envRestore.adjustNew"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(previews) { preview in
                    Section(preview.planName) {
                        ForEach(preview.swaps, id: \.original) { swap in
                            HStack(spacing: 6) {
                                Text(swap.original).foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                Text(swap.replacement)
                            }
                            .font(.subheadline)
                        }
                        ForEach(preview.archived, id: \.self) { name in
                            Label(name, systemImage: "archivebox")
                                .font(.subheadline)
                                .foregroundStyle(Color.Deltiq.error)
                        }
                        // Issue #12: .keep-archivierte Exercises, die beim Restore reaktiviert werden.
                        ForEach(preview.restored, id: \.self) { name in
                            Label(name, systemImage: "arrow.uturn.backward.circle")
                                .font(.subheadline)
                                .foregroundStyle(Color.Deltiq.success)
                        }
                    }
                }
            }
            .navigationTitle(mode == .swap
                ? Text("profile.envSwap.title", bundle: .module)
                : Text("profile.envRestore.title", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: onCancel) {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onConfirm) {
                        Text(confirmKey, bundle: .module)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onSecondary) {
                    Text(secondaryKey, bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding()
            }
        }
    }
}
#endif
