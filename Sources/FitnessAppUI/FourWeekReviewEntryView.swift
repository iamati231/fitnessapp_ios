#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// P9 (Mehrplan-Bedienablauf, docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): der
/// tatsächliche `NavigationLink`-Zielscreen für "Four-week review" aus den
/// Einstellungen — ersetzt das vorherige direkte `FourWeekReviewView()`.
///
/// **Gefundene Lücke (vor diesem Commit):** die Settings-Fälligkeits-
/// Anzeige aggregierte bereits korrekt über ALLE aktiven Pläne
/// (`FourWeekReviewDueStatus.isAnyDue`), aber `FourWeekReviewView` zeigte
/// immer nur den nach Name ERSTEN aktiven Plan
/// (`FourWeekReviewAssembler`s dokumentierte "ein Plan"-Vereinfachung für
/// den Review-INHALT). Bei zwei aktiven Plänen, von denen nur der ZWEITE
/// fällig war, landete ein Tap auf die "Fällig"-Zeile immer beim ERSTEN
/// Plan — dessen Abschluss änderte nichts an der weiterhin bestehenden
/// Fälligkeit des zweiten, und es gab KEINEN Weg, ihn über die Oberfläche
/// zu erreichen. Ein echter Bedienablauf-Fehler, keine bloße
/// Berechnungsfrage (siehe Audit-Abschnitt P9 für den vollständigen Fund).
///
/// **Fix:** bei genau 0 oder 1 aktiven Plänen bleibt das Verhalten exakt
/// wie zuvor (direkt `FourWeekReviewView(plan:)`, keine zusätzliche
/// Zwischenseite — der weit häufigste Fall bleibt unverändert). Bei 2+
/// aktiven Plänen zeigt dieser Screen zuerst eine einfache Auswahlliste;
/// jede Zeile trägt ihren eigenen Fälligkeits-/Abschluss-Status und
/// navigiert zu GENAU DEM gewählten Plan.
///
/// **Bewusst KEIN `@Query`** — identische Begründung wie bei
/// `FourWeekReviewView`: diese View ist selbst eine `NavigationLink`-
/// Destination in einer bereits zwei Ebenen tiefen Navigation
/// (Settings → SettingsAppExperienceView → hier) — exakt die Kategorie, die
/// P6.3/P7.2 bereits zu einer Render-Endlosschleife führte. Ein einmaliger
/// `.task`-Fetch genügt, dieser Screen muss nicht live beobachten.
@available(iOS 17.0, macOS 14.0, *)
public struct FourWeekReviewEntryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var activePlans: [TrainingPlan]?

    public init() {}

    public var body: some View {
        Group {
            if let activePlans {
                if activePlans.count > 1 {
                    planListContent(activePlans)
                } else {
                    // Unveraendertes Verhalten fuer 0/1 aktive Plaene: direkt
                    // der Review-Inhalt, keine zusaetzliche Zwischenseite.
                    FourWeekReviewView(plan: activePlans.first)
                }
            } else {
                loadingContent
            }
        }
        .task {
            // Einmalig VOR dem Lesen mutieren (siehe
            // `FourWeekReviewDueStatus`-Dokumentation) — niemals aus einer
            // body-Auswertung heraus. Idempotent: `SettingsAppExperienceView`
            // (eine Ebene hoeher) ruft dasselbe bereits auf; dieser Aufruf
            // ist nur eine defensive Absicherung, falls dieser Screen jemals
            // auf einem anderen Weg erreicht wird.
            FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: modelContext)
            activePlans = FourWeekReviewAssembler.allActivePlans(in: modelContext)
        }
    }

    private var loadingContent: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("fourWeekReview.header.eyebrow"),
                title: loc("fourWeekReview.title"),
                onBack: { dismiss() }
            )
            ProgressView().padding(.top, 60)
            Spacer()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
    }

    /// Einfache Auswahlliste — jede Zeile ein eigenständiger, gleichartiger
    /// `NavigationLink` zum selben Zieltyp (`FourWeekReviewView`), keine
    /// unterschiedlichen Ziel-Typen als Siblings (siehe Typ-Dokumentation,
    /// P6.3/P7.2-Lehre).
    @ViewBuilder
    private func planListContent(_ plans: [TrainingPlan]) -> some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: loc("fourWeekReview.header.eyebrow"),
                title: loc("fourWeekReview.choosePlan.title"),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 14) {
                    DeltiqSection(loc("fourWeekReview.choosePlan.section")) {
                        ForEach(plans) { plan in
                            NavigationLink {
                                FourWeekReviewView(plan: plan)
                            } label: {
                                DeltiqRow(
                                    label: plan.displayName,
                                    value: dueValueText(for: plan),
                                    showsChevron: true
                                )
                            }
                        }
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
    }

    /// Reiner Lesezugriff auf bereits geladene Felder — KEINE Mutation
    /// (der Beobachtungs-Fallback wurde bereits im `.task` oben einmalig
    /// angelegt), sicher aus der Zeilen-Darstellung heraus aufrufbar.
    private func dueValueText(for plan: TrainingPlan) -> String? {
        // Bewusst NICHT `FourWeekReviewDueStatus.state(for:in:)` (mutiert ggf.
        // den Beobachtungs-Fallback) — reiner Lesezugriff über
        // `currentBlockStart`/`intervalDays` (beide seiteneffektfrei), siehe
        // Funktionsdokumentation.
        let state = FourWeekReviewDueCalculator.state(
            blockStart: FourWeekReviewDueStatus.currentBlockStart(for: plan),
            intervalDays: FourWeekReviewDueStatus.intervalDays(for: plan),
            now: Date()
        )
        return fourWeekReviewDueBadgeText(for: state)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func loc(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Vier-Wochen-Rückblick — Einstieg") {
    NavigationStack {
        FourWeekReviewEntryView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}
#endif
#endif
