import XCTest
@testable import FitnessAppAI

/// The gate in front of the on-device model: every non-`.available` status must
/// stop the request before Foundation Models is touched.
final class NutritionAIAvailabilityTests: XCTestCase {

    private struct FixedAvailability: NutritionAIAvailabilityChecking {
        let status: NutritionAIAvailability
        func availability(for locale: Locale) -> NutritionAIAvailability { status }
    }

    private actor SpyGenerator: NutritionAITextGenerating {
        private(set) var callCount = 0
        func generateText(instructions: String, prompt: String) async throws -> String {
            callCount += 1
            return "generated"
        }
    }

    private static let unavailableStates: [NutritionAIAvailability] = [
        .deviceNotSupported, .appleIntelligenceNotEnabled,
        .languageNotSupported, .temporarilyUnavailable
    ]

    private func service(_ status: NutritionAIAvailability, _ spy: SpyGenerator) -> NutritionAIService {
        NutritionAIService(availabilityChecker: FixedAvailability(status: status), generator: spy)
    }

    // MARK: AI-01 (Audit 2026-10-23) — jeder Grund nennt sich selbst

    /// AI-01: Die UI darf „nicht verfuegbar" nicht mehr als einen Satz fuer
    /// alle Faelle zeigen. Jeder Zustand hat einen eigenen Grund; nur
    /// `.available` hat keinen.
    func testEachUnavailableStateMapsToItsOwnReasonKey() {
        XCTAssertNil(NutritionAIAvailability.available.unavailableReasonKey)

        let keys = Self.unavailableStates.compactMap { $0.unavailableReasonKey?.captureHintLocalizationKey }
        XCTAssertEqual(keys.count, Self.unavailableStates.count, "jeder Zustand braucht einen Grund")
        XCTAssertEqual(Set(keys).count, keys.count, "die Gründe müssen sich unterscheiden")
    }

    func testUnavailableReasonKeysMatchTheCatalogContract() {
        XCTAssertEqual(
            NutritionAIAvailability.deviceNotSupported.unavailableReasonKey?.captureHintLocalizationKey,
            "nutrition.addMeal.aiDraft.unavailable.device"
        )
        XCTAssertEqual(
            NutritionAIAvailability.appleIntelligenceNotEnabled.unavailableReasonKey?.captureHintLocalizationKey,
            "nutrition.addMeal.aiDraft.unavailable.disabled"
        )
        XCTAssertEqual(
            NutritionAIAvailability.languageNotSupported.unavailableReasonKey?.captureHintLocalizationKey,
            "nutrition.addMeal.aiDraft.unavailable.language"
        )
        XCTAssertEqual(
            NutritionAIAvailability.temporarilyUnavailable.unavailableReasonKey?.captureHintLocalizationKey,
            "nutrition.addMeal.aiDraft.unavailable.pending"
        )
    }

    func testServiceReportsInjectedStatus() {
        for status in Self.unavailableStates + [.available] {
            XCTAssertEqual(service(status, SpyGenerator()).availability(), status)
        }
    }

    func testUnavailableStatesNeverCallTheModel() async throws {
        for status in Self.unavailableStates {
            let spy = SpyGenerator()
            do {
                _ = try await service(status, spy).generateText(instructions: "i", prompt: "p")
                XCTFail("expected unavailable error for \(status)")
            } catch let error as NutritionAIError {
                XCTAssertEqual(error, .unavailable(status))
            }
            let calls = await spy.callCount
            XCTAssertEqual(calls, 0, "model called despite \(status)")
        }
    }

    func testAvailableStatusCallsTheModelOnce() async throws {
        let spy = SpyGenerator()
        let text = try await service(.available, spy).generateText(instructions: "i", prompt: "p")
        XCTAssertEqual(text, "generated")
        let calls = await spy.callCount
        XCTAssertEqual(calls, 1)
    }

    func testCheckedLocaleIsPassedThrough() {
        struct OnlyGerman: NutritionAIAvailabilityChecking {
            func availability(for locale: Locale) -> NutritionAIAvailability {
                locale.language.languageCode == .german ? .available : .languageNotSupported
            }
        }
        let de = NutritionAIService(availabilityChecker: OnlyGerman(), generator: SpyGenerator(),
                                    locale: Locale(identifier: "de_DE"))
        let fr = NutritionAIService(availabilityChecker: OnlyGerman(), generator: SpyGenerator(),
                                    locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(de.availability(), .available)
        XCTAssertEqual(fr.availability(), .languageNotSupported)
    }

    /// Without Foundation Models (older OS, Linux/Windows) the real checker must
    /// answer "not supported" instead of failing; on a 26+ runner any status is fine.
    func testSystemCheckerAnswersWithoutCrashing() {
        let status = SystemNutritionAIAvailabilityChecker().availability(for: Locale(identifier: "en_US"))
        #if !canImport(FoundationModels)
        XCTAssertEqual(status, .deviceNotSupported)
        #else
        _ = status
        #endif
    }
}
