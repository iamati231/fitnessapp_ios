import Foundation

/// One page of `OnlineFoodSearching.search` results. `hasMore` is derived
/// from the Search-a-licious API's own `page_count` metadata when present
/// and reliable (`page < page_count`); when that metadata is missing or
/// unusable, the client falls back to "this page was full, so there might
/// be more" — see `OpenFoodFactsSearchClient` for the exact rule. Either way
/// this type is the single source of truth for "can the caller load more?",
/// so UI/controller code never has to re-derive it from candidate counts.
public struct OnlineFoodSearchPage: Sendable, Equatable {
    public let candidates: [OnlineFoodCandidate]
    public let page: Int
    public let hasMore: Bool

    public init(candidates: [OnlineFoodCandidate], page: Int, hasMore: Bool) {
        self.candidates = candidates
        self.page = page
        self.hasMore = hasMore
    }
}
