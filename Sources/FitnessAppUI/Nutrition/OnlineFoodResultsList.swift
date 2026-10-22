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
@available(iOS 17.0, macOS 14.0, *)
struct OnlineFoodResultsList: View {
    let candidates: [OnlineFoodCandidate]
    let onSelect: (OnlineFoodCandidate) -> Void

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
    }
}
#endif
