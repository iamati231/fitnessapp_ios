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

    /// P9 (Mehrplan-Bedienablauf): expliziter Plan, falls dieser Screen über
    /// `FourWeekReviewEntryView`s Planauswahl erreicht wurde. `nil` behält
    /// die bisherige Rückwärtskompatibilität — `reload()` fällt dann auf
    /// `FourWeekReviewAssembler`s "erster aktiver Plan nach Name"-
    /// Vereinfachung zurück (unverändertes Verhalten für den
    /// Ein-Plan-Fall, der bei weitem häufigste Fall).
    private let explicitPlan: TrainingPlan?

    /// P7.3: der Plan, dessen Fälligkeit/Abschluss dieser Screen anzeigt und
    /// speichert — bei explizitem `explicitPlan` exakt dieser, sonst
    /// derselbe, den `FourWeekReviewAssembler` für den Review-INHALT
    /// bewertet (`primaryPlanForReview`) — nie eine zweite, abweichende
    /// Auswahl.
    @State private var reviewedPlan: TrainingPlan?
    @State private var dueState: FourWeekReviewDueCalculator.State?
    /// P8 Stufe 3: Beginn des AKTUELL offenen Blocks, zum Ladezeitpunkt
    /// ermittelt — wird beim Abschluss unverändert zurückgereicht
    /// (`completeReview`), damit `completeCurrentBlock` einen inzwischen
    /// bereits verarbeiteten Doppeltipp sicher erkennt (siehe dessen
    /// Dokumentation).
    @State private var currentBlockStart: Date?
    /// P8 Stufe 3: bereits abgeschlossene Blöcke dieses Plans — `isEmpty`
    /// entscheidet Titel/Intervall (erster Block vs. späterer Block), der
    /// letzte Eintrag liefert den "zuletzt abgeschlossen am"-Hinweis.
    @State private var blockHistory: [BlockReviewRecord] = []
    /// Wird `true`, sobald innerhalb DIESER Sitzung tatsächlich eine Aktion
    /// (Deload/Comeback) angewendet wurde — bestimmt die gespeicherte
    /// `reviewDecision` beim Abschluss. Startet bei jedem `reload()` neu,
    /// bewusst NICHT aus gespeicherten Daten rekonstruiert.
    @State private var actionTakenThisSession = false

    public init(plan: TrainingPlan? = nil) {
        self.explicitPlan = plan
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("fourWeekReview.header.eyebrow"),
                title: reviewTitle,
                onBack: { dismiss() },
                actions: completeAction.map { [$0] } ?? []
            )
            ScrollView {
                VStack(spacing: 14) {
                    if let review {
                        if !contextItems.isEmpty {
                            DeltiqContextRow(contextItems)
                        }
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
        // Bug-fix: .navigationBarBackButtonHidden(true) also disables the swipe-back
        // gesture; re-enable it. See deltiqSwipeBackEnabled() in Theme.swift.
        .deltiqSwipeBackEnabled()
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
        review = FourWeekReviewAssembler.assemble(in: modelContext, for: explicitPlan)
        let plan = explicitPlan ?? FourWeekReviewAssembler.primaryPlanForReview(in: modelContext)
        reviewedPlan = plan
        dueState = plan.map { FourWeekReviewDueStatus.state(for: $0, in: modelContext) }
        currentBlockStart = plan.flatMap { FourWeekReviewDueStatus.currentBlockStart(for: $0) }
        blockHistory = plan.map { FourWeekReviewDueStatus.history(for: $0) } ?? []
    }

    // MARK: - P7.3/P8 Stufe 3: Fälligkeit/Abschluss

    /// P8 Stufe 3: "Deine ersten vier Wochen" nur für den allerersten Block
    /// (noch keine Historie) — jeder spätere Block bekommt einen
    /// generischen, block-neutralen Titel statt der (dann falschen)
    /// Zeitangabe "vier Wochen"/"erste".
    private var reviewTitle: String {
        blockHistory.isEmpty ? loc("fourWeekReview.title") : loc("fourWeekReview.title.laterBlock")
    }

    /// Header-Checkmark "Rückblick abschließen" — nur sichtbar, solange ein
    /// Plan bewertet wurde. Bloßes Öffnen/Verlassen dieses Screens löst das
    /// NIE automatisch aus (siehe `FourWeekReviewDueCalculator`-
    /// Dokumentation) — nur dieser ausdrückliche Tap. Anders als vor P8
    /// Stufe 3 NICHT mehr vom Fälligkeitsstatus abhängig: ein Abschluss ist
    /// jederzeit möglich (auch vor der eigentlichen Fälligkeit, unverändert
    /// seit P7) und eröffnet sofort den nächsten Block — der Schutz gegen
    /// Doppeltippen liegt jetzt in `completeCurrentBlock` selbst
    /// (`expectedBlockStart`), nicht mehr im Ausblenden dieses Buttons.
    private var completeAction: DeltiqHeaderAction? {
        guard reviewedPlan != nil else { return nil }
        return DeltiqHeaderAction(
            systemImage: "checkmark",
            accessibilityLabel: loc("fourWeekReview.complete.action")
        ) {
            completeReview()
        }
    }

    /// Rein passive Anzeige (kein Snooze/Benachrichtigung in dieser Stufe,
    /// siehe `FourWeekReviewDueCalculator`-Dokumentation) — zeigt, solange
    /// offen, dass der aktuelle Block fällig ist.
    private var dueBadgeText: String? {
        fourWeekReviewDueBadgeText(for: dueState)
    }

    /// P8 Stufe 3: letzter bekannter Abschluss (beliebiger vorheriger
    /// Block) — bleibt sichtbar, auch während der nächste Block bereits
    /// läuft, weil ein Abschluss jetzt kein Dauerzustand mehr ist, der die
    /// Fälligkeitsanzeige ersetzt, sondern ein zusätzlicher, erhaltener
    /// Historienpunkt.
    private var lastCompletedText: String? {
        guard let lastCompletedAt = blockHistory.last?.completedAt else { return nil }
        return String(
            format: loc("fourWeekReview.status.completed"),
            lastCompletedAt.formatted(date: .abbreviated, time: .omitted)
        ).uppercased()
    }

    /// P9 (Mehrplan-Bedienablauf): zeigt den Plannamen NUR, wenn dieser
    /// Screen über eine explizite Auswahl erreicht wurde
    /// (`FourWeekReviewEntryView`s Planliste) — im bei weitem häufigsten
    /// Ein-Plan-Fall bleibt die Zeile unverändert wie vor P9, da dort keine
    /// Verwechslungsgefahr besteht.
    private var contextItems: [DeltiqContextItem] {
        var items: [DeltiqContextItem] = []
        if let explicitPlan {
            items.append(DeltiqContextItem(explicitPlan.displayName.uppercased(), style: .accent))
        }
        if let dueBadgeText {
            items.append(DeltiqContextItem(dueBadgeText, style: .neutral))
        }
        if let lastCompletedText {
            items.append(DeltiqContextItem(lastCompletedText, style: .neutral))
        }
        return items
    }

    /// Schließt den aktuell offenen Block ab (siehe
    /// `FourWeekReviewDueStatus.completeCurrentBlock`-Dokumentation für die
    /// Idempotenz-/Einfrier-Garantien) und lädt danach neu — der nächste
    /// Block ist damit sofort sichtbar fällig/nicht-fällig, kein separater
    /// Schritt nötig.
    private func completeReview() {
        guard let reviewedPlan, let review else { return }
        FourWeekReviewDueStatus.completeCurrentBlock(
            for: reviewedPlan,
            expectedBlockStart: currentBlockStart,
            decision: actionTakenThisSession ? .actionTaken : .keptAsIs,
            shownReview: review,
            in: modelContext
        )
        actionTakenThisSession = false
        reload()
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
        case .participationHistoryPartiallyUnattributed:
            return loc("fourWeekReview.dataGap.participation.partiallyUnattributed")
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
            case .underlyingDataFetchFailed:
                return loc("fourWeekReview.dataGap.participation.dataUnavailable")
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
        actionTakenThisSession = true
        reload()
    }

    private func resolveComeback(factor: Double?) {
        guard let assessment = comebackAssessment else { return }
        comebackAssessment = nil
        if let factor {
            try? AbsenceDeload.apply(in: modelContext, factor: factor)
            actionTakenThisSession = true
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

/// P9: geteilte Formatierung zwischen `FourWeekReviewView` (eigener Status)
/// und `FourWeekReviewEntryView`s Planliste (Status PRO Zeile) — eine
/// einzige Quelle der Wahrheit für den Badge-Text, statt zweier
/// unabhängiger `switch`-Anweisungen, die auseinanderlaufen könnten.
@available(iOS 17.0, macOS 14.0, *)
func fourWeekReviewDueBadgeText(for dueState: FourWeekReviewDueCalculator.State?) -> String? {
    guard let dueState else { return nil }
    switch dueState {
    case .due:
        return String(localized: "fourWeekReview.status.due", bundle: .module).uppercased()
    case .notYetDue, .unknown:
        return nil
    }
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
