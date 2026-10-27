#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
#if canImport(Combine)
import Combine
#endif
import FitnessAppFoodLookup

/// Task 4/5 (docs/superpowers/sdd/2026-10-22-online-food-lookup): all
/// network-search state/logic for the online food lookup, kept OUT of
/// `AddMealView` itself so XCTest can drive it directly (this package has no
/// ViewInspector/XCUITest harness — `swift test` is the only thing CI runs —
/// so a plain `ObservableObject` is the only testable seam, same pattern as
/// `MealDraft`/`MealDraftTests`). Internal (not `public`): only consumed
/// from within `FitnessAppUI` itself and, via `@testable import`, its tests.
///
/// Two entry points share this controller (Task 4: manual search 0-Treffer;
/// Task 5: AI candidate with no catalog match) — neither touches
/// `ModelContext`/`MealDraft` itself, that stays the View's job via the
/// existing `addItem` path, exactly like `applyAICandidate` already does for
/// AI matches.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class OnlineFoodSearchController: ObservableObject {
    @Published private(set) var candidates: [OnlineFoodCandidate] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    /// `true` once a search succeeds and the API says further pages exist —
    /// the single source of truth the UI reads to decide whether to show a
    /// "load more" affordance at all. Never derived from `candidates.count`.
    @Published private(set) var hasMoreResults: Bool = false
    @Published private(set) var errorMessage: String?
    /// Non-nil while the preview/confirm sheet is open for a specific tapped
    /// candidate. `OnlineFoodCandidate` is already `Identifiable`, so this
    /// binds straight into `.sheet(item:)`.
    @Published var selectedCandidate: OnlineFoodCandidate?

    private let searcher: OnlineFoodSearching
    /// Query/locale/next-page state for `loadMore()` — set fresh by every
    /// `search()` call, so a "load more" tap always continues the CURRENT
    /// search, never a stale one.
    private var lastQuery: String = ""
    private var lastLocale: Locale = .current
    private var nextPage: Int = 1

    init(searcher: OnlineFoodSearching) {
        self.searcher = searcher
    }

    /// - Parameter errorText: maps each `OnlineFoodSearchError` case to an
    ///   already-localized string. Kept out of this type on purpose — only
    ///   `FitnessAppUI`'s callers have `Bundle.module`/`Localizable.xcstrings`
    ///   access, this module must stay free of localization concerns.
    func search(query: String, locale: Locale, errorText: (OnlineFoodSearchError) -> String) async {
        // Same double-tap discipline as `runAIExtraction`: a second call
        // while one is already in flight is a no-op, never a second request
        // (Open Food Facts' ~10/min rate limit).
        guard !isSearching else { return }
        isSearching = true
        errorMessage = nil
        candidates = []
        hasMoreResults = false
        lastQuery = query
        lastLocale = locale
        nextPage = 1
        defer { isSearching = false }
        do {
            let page = try await searcher.search(query: query, locale: locale, page: 1)
            candidates = page.candidates
            hasMoreResults = page.hasMore
            nextPage = page.page + 1
        } catch let error as OnlineFoodSearchError {
            errorMessage = errorText(error)
        } catch {
            errorMessage = errorText(.invalidResponse)
        }
    }

    /// Fetches the next page for the CURRENT search and appends it — never
    /// replaces `candidates`, so already-shown results stay visible even if
    /// this fails. A failure leaves `candidates`/`hasMoreResults` untouched
    /// (only `errorMessage` changes), so the same tap is retryable.
    /// Duplicate protection: `!isSearching`/`!isLoadingMore` rules out a
    /// concurrent request from a double tap, and appended candidates are
    /// filtered against already-known ids (Open Food Facts' stable product
    /// code) in case the same product resurfaces across pages.
    func loadMore(errorText: (OnlineFoodSearchError) -> String) async {
        guard hasMoreResults, !isSearching, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await searcher.search(query: lastQuery, locale: lastLocale, page: nextPage)
            errorMessage = nil
            let existingIDs = Set(candidates.map(\.id))
            candidates.append(contentsOf: page.candidates.filter { !existingIDs.contains($0.id) })
            hasMoreResults = page.hasMore
            nextPage = page.page + 1
        } catch let error as OnlineFoodSearchError {
            errorMessage = errorText(error)
        } catch {
            errorMessage = errorText(.invalidResponse)
        }
    }

    /// A tap on one specific result row. Takes the candidate VALUE itself —
    /// never an index into `candidates` — so a tap can never resolve to the
    /// wrong (e.g. last) row regardless of how the list is rendered. This is
    /// the regression guard against the C1 bug class (final review of the
    /// previous plan: several default-style buttons sharing one Form/List
    /// row collapse into a single tap target, so only the LAST button's
    /// action ever ran) — see `OnlineFoodLookupFlowTests
    /// .testSelectPicksExactlyTheTappedCandidateRegardlessOfOrder`.
    func select(_ candidate: OnlineFoodCandidate) {
        selectedCandidate = candidate
    }

    /// Cancel path: closes the preview sheet, creates nothing.
    func dismissPreview() {
        selectedCandidate = nil
    }

    /// Clears the results list/error after a successful import, so a
    /// re-opened "no results" state doesn't still show the just-imported
    /// candidate list.
    func reset() {
        candidates = []
        errorMessage = nil
        selectedCandidate = nil
        hasMoreResults = false
        nextPage = 1
    }
}
#endif
