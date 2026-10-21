import XCTest
@testable import FitnessAppCore

final class OnboardingPlanCreationNoticeTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "OnboardingPlanCreationNoticeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testNothingPendingByDefault() {
        XCTAssertFalse(OnboardingPlanCreationNotice.consumeIfPending(in: makeDefaults()))
    }

    func testMarkFailedThenConsumeReturnsTrueOnce() {
        let defaults = makeDefaults()
        OnboardingPlanCreationNotice.markFailed(in: defaults)

        XCTAssertTrue(OnboardingPlanCreationNotice.consumeIfPending(in: defaults))
        // Zweiter Aufruf: der Hinweis wurde bereits konsumiert, der Dashboard-
        // Alert darf nicht ein zweites Mal erscheinen.
        XCTAssertFalse(OnboardingPlanCreationNotice.consumeIfPending(in: defaults))
    }

    func testMarkFailedIsIndependentPerDefaultsInstance() {
        let defaultsA = makeDefaults()
        let defaultsB = makeDefaults()
        OnboardingPlanCreationNotice.markFailed(in: defaultsA)

        XCTAssertTrue(OnboardingPlanCreationNotice.consumeIfPending(in: defaultsA))
        XCTAssertFalse(OnboardingPlanCreationNotice.consumeIfPending(in: defaultsB))
    }

    func testRepeatedMarkFailedStillConsumesOnlyOnce() {
        let defaults = makeDefaults()
        OnboardingPlanCreationNotice.markFailed(in: defaults)
        OnboardingPlanCreationNotice.markFailed(in: defaults)

        XCTAssertTrue(OnboardingPlanCreationNotice.consumeIfPending(in: defaults))
        XCTAssertFalse(OnboardingPlanCreationNotice.consumeIfPending(in: defaults))
    }
}
