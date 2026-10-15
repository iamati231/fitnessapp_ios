#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
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

    @State private var draftEnvironment: EnvironmentType
    @State private var draftEquipmentProfile: UserEquipmentProfile
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
        profile.environment = draftEnvironment
        profile.equipmentProfile = draftEquipmentProfile
        if equipmentTouched {
            profile.confirmEquipmentProfileComplete()
        }
        dismiss()
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
