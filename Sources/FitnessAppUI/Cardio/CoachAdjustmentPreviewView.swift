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

    /// Task 7 (Decision 3 Teil 2): die Vorschau muss dasselbe Ziel zeigen,
    /// das `accept()` tatsaechlich anwendet - `model.proposedGoal` statt des
    /// rohen, moeglicherweise nicht erreichbaren `profile.cardioGoal`
    /// (Fallback nur, wenn kein kleineres Ziel mehr erreichbar ist, siehe
    /// `CoachAdjustmentCardModel.proposedGoal`). `cardioRunProfile` wird
    /// hier aus denselben Profil-Feldern gebaut wie in `accept()`, damit die
    /// "Nachher"-Spalte ebenfalls eine Pace zeigt statt immer `nil`.
    private func newCardioDays(for model: CoachAdjustmentCardModel) -> [DaySpec] {
        let goal = model.proposedGoal ?? profile.cardioGoal
        return CoachAdjustmentCardModel.cardioOnlyDaySpecs(
            for: goal,
            cardioRunProfile: CardioRunProfile(
                goal: goal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )
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
            // Fix I-4 (Final-Review, Round 2): `verdict` ist optional, weil
            // `make` seit Task 6 auch ohne Renn-Datum/Wochenvolumen non-nil
            // liefert (keine Machbarkeits-Meinung moeglich). Ohne Verdikt
            // darf KEINE Machbarkeits-Aussage (weder feasible noch
            // infeasible) angezeigt werden (Decision 2: keine unbelegte
            // Praezisions-/Sicherheits-Behauptung) - die Zeile faellt dann
            // einfach weg, statt eine unerprobte "machbar" zu behaupten.
            if let verdict = model.verdict {
                Text(verdict.feasible
                     ? String(localized: "profile.cardio.feasibility.feasibleHeadline", bundle: .module)
                     : String(localized: "profile.cardio.feasibility.infeasibleHeadline", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                ForEach(Array(newCardioDays(for: model).enumerated()), id: \.offset) { _, spec in
                    Text(spec.name)
                }
            } header: {
                Text("profile.cardio.adjustment.before", bundle: .module)
            } footer: {
                Text("profile.cardio.adjustment.after", bundle: .module)
            }
            actionButtons(model)
        case .noEligibleCardioDay:
            // Task 7: Task 5/6s Einfuege-Pfad (Ruhetag -> Cardio-Tag) macht
            // diesen Fall nicht mehr zwangslaeufig zu einem reinen "nichts zu
            // tun" - ist mindestens ein Ruhetag einfuegbar, zeigt die Vorschau
            // dieselben Aktionen wie der `.ready`-Zweig (`actionButtons`,
            // dessen `model.accept` die Einfuegung selbst traegt), nur mit
            // einer Vorher/Nachher-Darstellung ohne "altes" Original (siehe
            // unten: `"— → <neuer Tag>"`, kein `.strikethrough()`, da kein
            // vorhandener Tag ersetzt wird).
            // Final-Review Fix 2: "mindestens ein einfuegbarer Ruhetag" reicht
            // nicht - `accept()`s Einfuege-Pfad verlangt GENUG davon fuer das
            // Ziel (`PlanGeneratorInstantiator.CardioInsertionError.
            // insufficientRestDays`, Task 6s eigene, korrekte Guard). Zu wenige
            // eignbare Tage wuerden sonst "Auf aktuellen Plan anwenden"
            // anbieten, das JEDEN Versuch mit der irrefuehrenden "Plan hat
            // sich geaendert"-Meldung abbricht, ohne je "Neuen Plan erstellen"
            // erreichbar zu machen.
            if model.analysis.insertableRestDays.count >= newCardioDays(for: model).count {
                Section {
                    ForEach(Array(newCardioDays(for: model).enumerated()), id: \.offset) { _, spec in
                        Text("— → \(spec.name)")
                    }
                } header: {
                    Text("profile.cardio.adjustment.before", bundle: .module)
                } footer: {
                    Text("profile.cardio.adjustment.after", bundle: .module)
                }
                actionButtons(model)
            } else {
                Section {
                    Text("profile.cardio.adjustment.noEligibleDay", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                createNewPlanButton(model)
            }
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
                } catch is PlanGeneratorInstantiator.CardioInsertionError {
                    // Task 7 (Entscheidung, nicht verhandelbar): `insertCoachCardioDays`s
                    // Re-Validierungsfehler (Plan hat sich seit der Vorschau
                    // geaendert) darf NICHT im generischen Catch-All unten
                    // verschwinden (dessen unleserliche "operation couldn't be
                    // completed"-Standardmeldung) - eigene, lesbare Botschaft
                    // statt eines stillen/unleserlichen Fehlschlags.
                    errorMessage = String(localized: "profile.cardio.adjustment.planChanged", bundle: .module)
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
    ///
    /// Task 7 (Review-Korrektur): `activePlan` wird HIER bewusst NICHT durchgereicht (anders als
    /// bei den beiden anderen Aufrufstellen). Diese Vorschau bietet DREI eigenstaendige,
    /// gleichrangige Aktionen (siehe Typ-Doku oben): "auf aktuellen Plan anwenden" (oben,
    /// `CoachAdjustmentCardModel.accept`), "als neuen Plan erstellen" (hier) und "Plan behalten"
    /// (Abbrechen). Der Nutzer hat mit dem Tap auf GENAU DIESEN Button bereits explizit einen
    /// separaten neuen Plan gewaehlt, als bewusste Alternative zur In-Place-Anpassung, die direkt
    /// darueber ebenfalls angeboten wird. Wuerde `activePlan` hier durchgereicht, wuerde
    /// `CardioFeasibilityCardModel.accept`s neue Weiche (siehe dortige Doku) diesen Tap bei einem
    /// anpassbaren Plan STILL in dieselbe In-Place-Anpassung umleiten - zwei bewusst
    /// unterschiedliche Nutzer-Entscheidungen wuerden ununterscheidbar. Diese Aufrufstelle bleibt
    /// daher bei `activePlan: nil` (Default), erzeugt also immer einen echten, separaten Plan -
    /// exakt das bisherige, unveraenderte Verhalten.
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
