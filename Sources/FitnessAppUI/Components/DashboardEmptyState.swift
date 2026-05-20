#if canImport(SwiftUI)
import SwiftUI

/// UX-201 — Re-usable premium-Empty-State for Dashboard widgets.
///
/// Pre-UX-201 hatten die Dashboard-Karten heterogene Empty-States:
///   * Trophy Room + History: 1-Zeilen-Text in `.secondary`-Farbe — visuell
///     leer und ohne Handlungsanleitung.
///   * Compound Lifts + Recent Workouts: 3-teilig (Icon + Title + Hint),
///     aber ohne CTA — User wusste nicht, was er tun soll.
///   * Weight Trend: 2-teiliger Label-Renderer (`EmptyTrendCard`) ohne
///     getrennten Title-Body.
///
/// Diese Komponente vereinheitlicht das auf das Spec-Schema aus UX-201:
///   1. Icon (SF Symbol, hierarchical, brand-orange, reduzierte Opacity)
///   2. Headline (kurz, motivierend)
///   3. Erklärung (was als nächstes passiert)
///   4. CTA-Button (führt direkt zur Action, brand-orange-Gradient)
///
/// CTA ist optional — falls keine sinnvolle Folge-Action existiert (z.B.
/// CoachingInsight zeigt nur einen Hinweis), kann sie weggelassen werden;
/// das Layout faellt dann auf 3-teilig zurueck.
///
/// Wird IN die Bento-Card eingebettet (die outer `.deltiqCardStyle()`-Surface
/// bleibt beim Caller). Diese Komponente kuemmert sich nur um das Innen-
/// Layout, sodass sie unter beiden Branches (empty vs. data) dasselbe
/// vertikale Padding-Rhythmus traegt.
///
/// xcstrings-Naming-Konvention: `.emptyTitle` / `.emptyDescription` (camelCase
/// statt `.empty.title` / `.empty.description`). Grund: das alte parent-
/// Key-Schema kollidiert mit Xcode-26.4.1's `GenerateStringSymbols`-Step,
/// wenn der Parent (`.empty`) als Leaf-Value existiert (siehe DEL-121-
/// Build-Saga). camelCase-Sibling-Keys umgehen das vollstaendig.
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardEmptyState: View {

    public let icon: String
    public let title: LocalizedStringKey
    public let description: LocalizedStringKey
    public let ctaTitle: LocalizedStringKey?
    public let ctaAction: (() -> Void)?

    public init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        ctaTitle: LocalizedStringKey? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.ctaTitle = ctaTitle
        self.ctaAction = ctaAction
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Icon mit hierarchical rendering + brand-orange-Akzent. Reduzierte
            // Opacity laesst die Card nicht zu laut wirken trotz prominentem
            // Symbol. font.system(48,.semibold,.rounded) matched die Hero-Stat-
            // Typografie aus DEL-103 — visuelle Konsistenz mit den Data-States.
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.deltiqOrange.opacity(0.85))
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text(title, bundle: .module)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                Text(description, bundle: .module)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let ctaTitle, let ctaAction {
                Button(action: ctaAction) {
                    Text(ctaTitle, bundle: .module)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.deltiqOrange.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Empty State — mit CTA") {
    DashboardEmptyState(
        icon: "trophy.fill",
        title: "Noch keine PRs",
        description: "Schließe ein Training ab, um deinen ersten Rekord zu setzen.",
        ctaTitle: "Training starten",
        ctaAction: {}
    )
    .deltiqCardStyle()
    .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Empty State — ohne CTA") {
    DashboardEmptyState(
        icon: "chart.xyaxis.line",
        title: "Noch keine Trend-Daten",
        description: "Erfasse mindestens zwei Messungen, um die Kurve zu sehen."
    )
    .deltiqCardStyle()
    .padding()
}
#endif
#endif
