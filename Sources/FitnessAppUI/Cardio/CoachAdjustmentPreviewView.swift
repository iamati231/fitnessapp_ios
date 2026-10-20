#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Paket 1, Komponente 4 (Laufcoach-Plananpassung,
/// docs/DELTIQ_DEVICE_ACCEPTANCE.md): Vorher/Nachher-Vorschau für
/// `CoachAdjustmentCardModel`, mit den drei vorgegebenen Aktionen.
///
/// Nur erreichbar, wenn bereits ein aktiver Plan existiert (siehe
/// `ProfileEditorView.coachAdjustmentModel` — der "kein aktiver Plan"-Fall
/// bleibt bewusst bei der bestehenden `CardioFeasibilityCardModel`/
/// `feasibilitySection` (Leitplanke 6), die ihre eigene
/// "vorbefüllte Neuerstellung" bereits beherrscht).
@available(iOS 17.0, macOS 14.0, *)
struct CoachAdjustmentPreviewView: View {
    @Bindable var profile: UserBodyProfile
    let activePlan: TrainingPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isApplying = false
    @State private var isCreatingNewPlan = false
    @State private var createNewPlanOperation = PlanCreationOperation()
    @State private var errorMessage: String?

    private var model: CoachAdjustmentCardModel? {
        CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan)
    }

    private var newCardioDays: [DaySpec] {
        CoachAdjustmentCardModel.cardioOnlyDaySpecs(for: profile.cardioGoal)
    }

    var body: some View {
        NavigationStack {
            List {
                if let model {
                    statusSection(model)
                    beforeAfterSection(model)
                }
            }
            .navigationTitle(Text("profile.cardio.adjustment.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // "Bestehenden Plan beibehalten": reines Schliessen,
                        // keinerlei Zustandsaenderung (Leitplanke 2 - weder
                        // cardioCoachingEnabled noch der Plan werden hier
                        // angefasst). cardioCoachingEnabled bleibt an, die
                        // Vorschau zeigt das bereits ehrlich ueber
                        // `statusSection`.
                        dismiss()
                    } label: {
                        Text("profile.cardio.adjustment.keep", bundle: .module)
                    }
                }
                #endif
            }
            .alert(
                Text("profile.cardio.adjustment.applyError.title", bundle: .module),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func statusSection(_ model: CoachAdjustmentCardModel) -> some View {
        Section {
            Text(model.isAlreadyApplied
                 ? String(localized: "profile.cardio.adjustment.applied", bundle: .module)
                 : String(localized: "profile.cardio.adjustment.pending", bundle: .module))
                .font(.subheadline.weight(.semibold))
            Text(model.verdict.feasible
                 ? String(localized: "profile.cardio.feasibility.feasibleHeadline", bundle: .module)
                 : String(localized: "profile.cardio.feasibility.infeasibleHeadline", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func beforeAfterSection(_ model: CoachAdjustmentCardModel) -> some View {
        switch model.analysis.cardioAvailability {
        case .ready(let ids):
            Section {
                ForEach(Array(activePlan.days.filter { ids.contains($0.persistentModelID) }), id: \.persistentModelID) { day in
                    Text(day.name)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(newCardioDays.enumerated()), id: \.offset) { _, spec in
                    Text(spec.name)
                }
            } header: {
                Text("profile.cardio.adjustment.before", bundle: .module)
            } footer: {
                Text("profile.cardio.adjustment.after", bundle: .module)
            }
            actionButtons(model)
        case .noEligibleCardioDay:
            Section {
                Text("profile.cardio.adjustment.noEligibleDay", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            createNewPlanButton(model)
        case .noActivePlan:
            EmptyView()
        }
    }

    @ViewBuilder
    private func actionButtons(_ model: CoachAdjustmentCardModel) -> some View {
        Section {
            Button {
                guard !isApplying else { return }
                isApplying = true
                do {
                    try model.accept(plan: activePlan, profile: profile, in: modelContext)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isApplying = false
            } label: {
                Text("profile.cardio.adjustment.applyToCurrentPlan", bundle: .module)
            }
            .disabled(isApplying || model.isAlreadyApplied)
        }
        createNewPlanButton(model)
    }

    /// "Als neuen Plan erstellen": reuse des bereits bestehenden, geprüften
    /// `CardioFeasibilityCardModel.accept`-Pfads statt einer zweiten
    /// Implementierung - exakt derselbe Mechanismus wie in
    /// `ProfileEditorView.feasibilitySection`.
    @ViewBuilder
    private func createNewPlanButton(_ model: CoachAdjustmentCardModel) -> some View {
        if let feasibilityModel = CardioFeasibilityCardModel.make(for: profile) {
            Section {
                Button {
                    guard !isCreatingNewPlan else { return }
                    isCreatingNewPlan = true
                    _ = feasibilityModel.accept(profile: profile, in: modelContext, using: createNewPlanOperation)
                    isCreatingNewPlan = false
                    dismiss()
                } label: {
                    Text("profile.cardio.adjustment.createNewPlan", bundle: .module)
                }
                .disabled(isCreatingNewPlan)
            }
        }
    }
}
#endif
