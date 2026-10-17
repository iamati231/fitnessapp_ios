#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md): kombinierter
/// Trainingsort+Ausstattung-Editor — ersetzt die getrennten `goalCard`-
/// Umgebungs-Picker-Zeile und `equipmentCard`-Sheet in `ProfileEditorView`.
/// Reiner Profil-Editor: Speichern aendert ausschliesslich `profile.environment`/
/// `equipmentProfile`/`equipmentProfileConfirmedComplete` — NIE bestehende
/// Plaene direkt. Die Plan-Anpassung (`PlanEnvironmentMigrator` ueber die
/// `envSwap`/`envRestore`-Dialoge) bleibt vollstaendig unveraendert in
/// `ProfileEditorView.onChange(of: profile.environment)`: die feuert
/// weiterhin genau einmal, sobald `save()` unten `profile.environment`
/// tatsaechlich schreibt — eine separate, ausdruecklich vom User bestaetigte
/// Aktion, keine neue Bulk-Logik in diesem Editor.
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

    init(profile: UserBodyProfile) {
        self.profile = profile
        _draftEnvironment = State(initialValue: profile.environment)
        _draftEquipmentProfile = State(initialValue: profile.equipmentProfile)
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
                            accessibilityLabel: String(localized: "common.save", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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
            .interactiveDismissDisabled(isDirty)
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
                    set: { if !$0 { pendingEquipmentAdaptation = nil; dismiss() } }
                )
            ) {
                Button {
                    if let newProfile = pendingEquipmentAdaptation {
                        applyEquipmentAdaptations(against: newProfile)
                    }
                    pendingEquipmentAdaptation = nil
                    dismiss()
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
            ))
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
        // P5.1: VOR dem Schreiben erfassen — danach ist `profile.equipmentProfile`
        // bereits der neue Wert und ein Vergleich waere immer `false`.
        let equipmentChanged = draftEquipmentProfile != profile.equipmentProfile

        profile.environment = draftEnvironment
        profile.equipmentProfile = draftEquipmentProfile
        if equipmentTouched {
            profile.confirmEquipmentProfileComplete()
        }

        // Nur ein tatsaechlich GEAENDERTES Equipment-Profil (nicht jeder
        // Trainingsort-Wechsel — der hat seinen eigenen, unveraenderten
        // `envSwap`-Pfad in `ProfileEditorView`) kann hier ueberhaupt eine
        // neue Luecke erzeugen. `hasAnyPlanWithEquipmentGap` prueft gezielt
        // GEGEN das neue Profil, nicht gegen eine blosse Aenderung — ein
        // Equipment-Upgrade (nur Items hinzugefuegt) loest den Dialog also
        // korrekt NICHT aus.
        if equipmentChanged, hasAnyPlanWithEquipmentGap(against: draftEquipmentProfile) {
            pendingEquipmentAdaptation = draftEquipmentProfile
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

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}
#endif
