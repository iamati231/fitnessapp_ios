import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Privacy: prompts and model output may contain nutrition data — never print or
// log them anywhere in this module.

public enum NutritionAIError: Error, Sendable, Equatable {
    /// The request was refused before touching the model.
    case unavailable(NutritionAIAvailability)
    /// The model was called but produced no usable result (guardrail, refusal,
    /// unsupported language, rate limit, …). The underlying Foundation Models
    /// error is deliberately not exposed outside `FitnessAppAI`.
    case generationFailed
}

/// The raw on-device model call, without any availability gating. Injectable so
/// tests can spy on whether the model was asked at all.
public protocol NutritionAITextGenerating: Sendable {
    func generateText(instructions: String, prompt: String) async throws -> String
}

/// Real backend: one fresh `LanguageModelSession` per request (no shared
/// transcript between unrelated requests).
public struct FoundationModelsTextGenerator: NutritionAITextGenerating {
    public init() {}

    public func generateText(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                return try await session.respond(to: prompt).content
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw NutritionAIError.generationFailed
            }
        }
        #endif
        throw NutritionAIError.unavailable(.deviceNotSupported)
    }
}

/// Entry point for app code: checks availability first and only then calls the
/// model, so unsupported devices/locales never reach Foundation Models.
public struct NutritionAIService: Sendable {
    private let availabilityChecker: any NutritionAIAvailabilityChecking
    private let generator: any NutritionAITextGenerating
    private let locale: Locale

    public init(
        availabilityChecker: any NutritionAIAvailabilityChecking = SystemNutritionAIAvailabilityChecker(),
        generator: any NutritionAITextGenerating = FoundationModelsTextGenerator(),
        locale: Locale = .current
    ) {
        self.availabilityChecker = availabilityChecker
        self.generator = generator
        self.locale = locale
    }

    public func availability() -> NutritionAIAvailability {
        availabilityChecker.availability(for: locale)
    }

    /// Throws `NutritionAIError.unavailable(_)` without calling the model when
    /// `availability()` isn't `.available`.
    public func generateText(instructions: String, prompt: String) async throws -> String {
        let status = availability()
        guard status == .available else { throw NutritionAIError.unavailable(status) }
        return try await generator.generateText(instructions: instructions, prompt: prompt)
    }
}
