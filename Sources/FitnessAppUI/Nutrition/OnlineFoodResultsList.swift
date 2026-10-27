#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppFoodLookup

/// Task 4/5 reusable component: one tappable row per Open-Food-Facts hit.
/// Meant to be used directly inside a `Form`/`List` `Section` builder (like
/// `AddMealView.searchSection`'s existing `filteredEntries` `ForEach`) — NOT
/// nested inside another row's `VStack`, so every candidate gets its own
/// Form row instead of several buttons sharing one (the C1 bug class from
/// the final review of the previous plan). `.buttonStyle(.borderless)` is
/// applied per row from the start per the Task 4 brief, even though a lone
/// Button per `ForEach`-at-Section-level row doesn't exhibit that bug on its
/// own (see `filteredEntries`) — belt and suspenders for a list Task 5 reuses
/// from a second call site.
///
/// Settings-Restructure-Task (2026-10-23), Teil C2: Open Food Facts verlangt
/// Attribution auf JEDER Seite/jedem Screen, der ihre Daten zeigt — nicht nur
/// auf der dedizierten Credits-Seite (`OnlineFoodLookupCreditsView`). Dieser
/// `attributionRow` haengt hier statt an jedem der zwei `AddMealView`-
/// Aufrufer, damit beide Einstiegspunkte (manuelle Suche + AI-Kandidat) ihn
/// automatisch bekommen. Nur sichtbar, wenn `candidates` tatsaechlich etwas
/// zeigt (nicht beim leeren/noch-nicht-ausgefuehrten Suchzustand) — eigene
/// Zeile, reiner Text, kein Tap-Target (kein C1-Risiko).
@available(iOS 17.0, macOS 14.0, *)
struct OnlineFoodResultsList: View {
    let candidates: [OnlineFoodCandidate]
    let onSelect: (OnlineFoodCandidate) -> Void
    /// Pagination (Task: Ernährungssuche erweitern): whether the API has
    /// more pages for the CURRENT search — the only signal that decides
    /// whether the "load more" row renders at all.
    var hasMore: Bool = false
    var isLoadingMore: Bool = false
    var onLoadMore: () -> Void = {}

    var body: some View {
        ForEach(candidates) { candidate in
            Button {
                // Captures THIS iteration's `candidate` by value — never an
                // index into `candidates` — so the tapped row is always the
                // one that gets selected.
                onSelect(candidate)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .foregroundStyle(Color.primary)
                    if let brand = candidate.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.Deltiq.surface)
        }
        if hasMore {
            Button {
                onLoadMore()
            } label: {
                HStack {
                    if isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("nutrition.addMeal.onlineSearch.loadMore", bundle: .module)
                }
            }
            .buttonStyle(.borderless)
            // Double-tap protection lives in `OnlineFoodSearchController
            // .loadMore` itself (guard against a concurrent request); this
            // disables the row purely so a tap mid-request doesn't feel
            // like a no-op.
            .disabled(isLoadingMore)
            .listRowBackground(Color.Deltiq.surface)
        }
        if !candidates.isEmpty {
            Text("nutrition.addMeal.onlineSearch.attribution", bundle: .module)
                .font(.system(size: 11))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .listRowBackground(Color.Deltiq.surface)
        }
    }
}
#endif
