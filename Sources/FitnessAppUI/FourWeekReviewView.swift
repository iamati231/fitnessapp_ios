#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// P7.2: "Deine ersten vier Wochen" — zeigt das Ergebnis von
/// `FourWeekReviewOrchestrator` (P7.1), zusammengestellt aus realen Daten
/// über `FourWeekReviewAssembler`.
///
/// Nachbesserung aus dem P6.3-Blocker übernommen: **bewusst KEIN `@Query`**
/// auf dieser View — die zugrundeliegende `@Query`-Endlosschleife in
/// `PeriodicCheckInView` entstand genau dadurch, dass eine solche View als
/// `NavigationLink`-Destination bei jeder Eltern-Neubewertung neu
/// konstruiert wurde. Stattdessen wird die Auswertung einmalig in `.task`
/// über `FourWeekReviewAssembler.assemble(in:)` geladen.
///
/// **Vorschläge werden nie automatisch angewendet**: Deload und
/// Comeback-Anpassung laufen jeweils über eine eigene, bewusste
/// Bestätigung — Deload über einen Bestätigungsdialog, Comeback über das
/// bereits bestehende, produktiv genutzte `ComebackPromptSheet` (dieselbe
/// Komponente, die auch beim Trainingsstart erscheint). Beide rufen
/// ausschließlich die bereits bestehenden Apply-Funktionen
/// (`DeloadManager.startDeload`/`AbsenceDeload.apply`) auf — keine neue,
/// zweite Progressions-/Deload-Mechanik.
@available(iOS 17.0, macOS 14.0, *)
public struct FourWeekReviewView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("deload_until") private var deloadUntil: Double = 0

    @State private var review: FourWeekReviewOrchestrator.Review?
    @State private var comebackAssessment: AbsenceDeload.Assessment?
    @State private var showingDeloadConfirm = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("fourWeekReview.header.eyebrow"),
                title: loc("fourWeekReview.title"),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 14) {
                    if let review {
                        reviewContent(review)
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .task { reload() }
        .sheet(item: $comebackAssessment) { assessment in
            ComebackPromptSheet(assessment: assessment) { factor in
                resolveComeback(factor: factor)
            }
        }
        .confirmationDialog(
            loc("fourWeekReview.deload.confirm.title"),
            isPresented: $showingDeloadConfirm,
            titleVisibility: .visible
        ) {
            Button(loc("fourWeekReview.deload.confirm.apply")) { applyDeload() }
            Button(loc("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Laden (kein @Query, siehe Typ-Dokumentation)

    private func reload() {
        review = FourWeekReviewAssembler.assemble(in: modelContext)
    }

    // MARK: - Inhalt

    @ViewBuilder
    private func reviewContent(_ review: FourWeekReviewOrchestrator.Review) -> some View {
        switch review.outcome {
        case .keepAsIs:
            keepAsIsCard
        case .concernsFound(let concerns):
            ForEach(Array(concerns.enumerated()), id: \.offset) { _, concern in
                concernCard(concern)
            }
        }
        if case .evaluated(let summary) = review.participation {
            participationCard(summary)
        }
        if !review.dataGaps.isEmpty {
            dataGapCard(review.dataGaps)
        }
    }

    /// "Plan passt – beibehalten": ein vollwertiges, positives Ergebnis,
    /// keine blosse Abwesenheit von Problemen.
    private var keepAsIsCard: some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(loc("fourWeekReview.keepAsIs.title")).font(.headline)
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.Deltiq.success)
                }
                Text(loc("fourWeekReview.keepAsIs.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func concernCard(_ concern: FourWeekReviewOrchestrator.Concern) -> some View {
        switch concern {
        case .deloadRecommended:
            DeltiqCard(accentEdge: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("fourWeekReview.concern.deload.title")).font(.headline)
                    Text(loc("fourWeekReview.concern.deload.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    Button(loc("fourWeekReview.concern.deload.action")) {
                        showingDeloadConfirm = true
                    }
                    .modifier(DeltiqSecondaryButtonModifier())
                }
            }
        case .comebackSuggested(let prescription):
            DeltiqCard(accentEdge: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("fourWeekReview.concern.comeback.title")).font(.headline)
                    Text(String(
                        format: loc("fourWeekReview.concern.comeback.subtitle"),
                        Int(((1.0 - prescription.compoundFactor) * 100).rounded())
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    Button(loc("fourWeekReview.concern.comeback.action")) {
                        // Frisch neu ermitteln statt das Orchestrator-Signal
                        // weiterzureichen: `ComebackPromptSheet` braucht die
                        // vollstaendige `AbsenceDeload.Assessment` fuer seine
                        // eigene Live-Vorschau, nicht nur gapDays/Prescription.
                        comebackAssessment = AbsenceDeload.assess(in: modelContext)
                    }
                    .modifier(DeltiqSecondaryButtonModifier())
                }
            }
        case .participationBelowPlan(let missedCount, let plannedCount):
            DeltiqCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("fourWeekReview.concern.participation.title")).font(.headline)
                    Text(String(
                        format: loc("fourWeekReview.concern.participation.subtitle"),
                        missedCount, plannedCount
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        case .complaintsReported:
            DeltiqCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("fourWeekReview.concern.complaints.title")).font(.headline)
                    Text(loc("fourWeekReview.concern.complaints.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        case .goalNoLongerCurrent:
            DeltiqCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("fourWeekReview.concern.goal.title")).font(.headline)
                    Text(loc("fourWeekReview.concern.goal.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
        }
    }

    private func participationCard(_ summary: PlanParticipationEvaluator.Summary) -> some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc("fourWeekReview.participation.title"))
                    .font(.subheadline.weight(.semibold))
                Text(String(
                    format: loc("fourWeekReview.participation.summary"),
                    summary.completedCount, summary.plannedCount
                ))
                .font(.subheadline)
                .foregroundStyle(Color.Deltiq.textSecondary)
                if summary.partialCount > 0 || summary.startedOnlyCount > 0 {
                    Text(String(
                        format: loc("fourWeekReview.participation.partial"),
                        summary.partialCount, summary.startedOnlyCount
                    ))
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textTertiary)
                }
            }
        }
    }

    private func dataGapCard(_ gaps: [FourWeekReviewOrchestrator.DataGap]) -> some View {
        DeltiqCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("fourWeekReview.dataGap.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                ForEach(Array(gaps.enumerated()), id: \.offset) { _, gap in
                    Text(text(for: gap))
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textTertiary)
                }
            }
        }
    }

    private func text(for gap: FourWeekReviewOrchestrator.DataGap) -> String {
        switch gap {
        case .noCheckInYet:
            return loc("fourWeekReview.dataGap.noCheckIn")
        case .participationNotReliablyEvaluable(let reason):
            switch reason {
            case .activationStartUnknown:
                return loc("fourWeekReview.dataGap.participation.activationUnknown")
            case .planNotCurrentlyActive:
                return loc("fourWeekReview.dataGap.participation.noActivePlan")
            case .evaluationBeforeActivation:
                return loc("fourWeekReview.dataGap.participation.beforeActivation")
            case .planHasNoTrainingDays:
                return loc("fourWeekReview.dataGap.participation.noTrainingDays")
            case .noOpportunityDueYet:
                return loc("fourWeekReview.dataGap.participation.tooEarly")
            }
        }
    }

    // MARK: - Aktionen (jeweils eigene, bewusste Bestätigung)

    private func applyDeload() {
        let adjusted = (try? DeloadManager.startDeload(in: modelContext)) ?? 0
        guard adjusted > 0 else { return }
        deloadUntil = Date()
            .addingTimeInterval(TimeInterval(DeloadManager.defaultDurationDays * 24 * 3600))
            .timeIntervalSince1970
        reload()
    }

    private func resolveComeback(factor: Double?) {
        guard let assessment = comebackAssessment else { return }
        comebackAssessment = nil
        if let factor {
            try? AbsenceDeload.apply(in: modelContext, factor: factor)
        } else {
            AbsenceDeload.remember(declinedAtGapDays: assessment.gapDays)
        }
        reload()
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Vier-Wochen-Rückblick") {
    NavigationStack {
        FourWeekReviewView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}
#endif
#endif
