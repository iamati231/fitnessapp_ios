// ─────────────────────────────────────────────────────────────────────────────
// Research basis (checked 2026-10-21 against developer.apple.com, docs
// metadataVersion 0.1.0, which already lists the 26.0–26.3 / 26.4 / 27.0 model
// versions). Re-check here first if a newer Xcode on CI breaks this file.
//
// Framework: `FoundationModels` (module name), "Foundation Models framework".
// Minimum OS: iOS / iPadOS / macOS / visionOS 26.0 (watchOS 27.0 for the
//   session APIs). Our app targets iOS 17 / macOS 14, so every use sits behind
//   `#if canImport(FoundationModels)` AND `if #available(iOS 26.0, macOS 26.0, *)`.
// Availability check (runtime, synchronous property):
//   `SystemLanguageModel.default.availability` -> `SystemLanguageModel.Availability`
//     `.available`
//     `.unavailable(SystemLanguageModel.Availability.UnavailableReason)` with
//       `.deviceNotEligible`           – device can't run Apple Intelligence
//       `.appleIntelligenceNotEnabled` – user hasn't turned it on in Settings
//       `.modelNotReady`               – model downloading / other system reasons
//   Apple's own sample ends with `case .unavailable(let other)` as a catch-all
//   for reasons added in later OS versions.
//   (`isAvailable: Bool` also exists; we use the enum to keep the reason.)
// Languages: `SystemLanguageModel.default.supportsLocale(_ locale: Locale = .current)`
//   – Apple recommends it over `supportedLanguages: Set<Locale.Language>`
//   because it honours language fallbacks. The set depends on OS version and
//   region; Apple Intelligence gained Turkish with iOS 26.1 (German/English
//   since 26.0), so de/en/tr are not guaranteed on every 26.x device — always
//   ask at runtime, never hardcode the list.
// Starting a request: `let session = LanguageModelSession(instructions: "…")`,
//   then `try await session.respond(to: prompt)` -> `Response<String>`; text
//   is in `.content`. A session keeps a transcript; one request at a time
//   (a second concurrent `respond` throws `concurrentRequests`).
// Typed/structured output: annotate a Swift struct/enum with `@Generable`
//   (properties optionally with `@Guide(description:)`) and call
//   `session.respond(to: prompt, generating: MyType.self)` -> `Response<MyType>`.
// Errors: `LanguageModelSession.GenerationError` (deprecated in 27.0) with e.g.
//   `guardrailViolation`, `unsupportedLanguageOrLocale`, `rateLimited`,
//   `exceededContextWindowSize`. These FM types never leave this module.
// Sources: developer.apple.com/documentation/foundationmodels/
//   systemlanguagemodel, …/availability-swift.enum/unavailablereason,
//   …/systemlanguagemodel/supportslocale(_:), …/languagemodelsession,
//   …/languagemodelsession/response, …/generable,
//   …/languagemodelsession/generationerror; 9to5mac.com (2025-11-11) for the
//   iOS 26.1 language additions.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether the on-device nutrition AI can be used right now. Every case except
/// `.available` means: hide or disable AI entry points and keep the manual
/// flow (search, manual entry, daily overview) as the only path.
public enum NutritionAIAvailability: Sendable, Equatable {
    case available
    /// OS older than 26, framework missing, or hardware not eligible for
    /// Apple Intelligence. Permanent for this device/OS.
    case deviceNotSupported
    /// Eligible device, but the user hasn't enabled Apple Intelligence in Settings.
    case appleIntelligenceNotEnabled
    /// The model is ready but doesn't support the requested locale.
    case languageNotSupported
    /// Model still downloading or busy for system reasons; re-check later.
    case temporarilyUnavailable
}

/// Injectable source of `NutritionAIAvailability` — tests and unsupported
/// platforms use a fake instead of the real Foundation Models check.
public protocol NutritionAIAvailabilityChecking: Sendable {
    /// Current status for generating content in `locale`'s language.
    func availability(for locale: Locale) -> NutritionAIAvailability
}

/// AI-01 (Audit docs/AUDIT_2026-10-23_DELTIQ.md, P2): Was die UI sagen muss,
/// wenn die lokale KI gerade nicht arbeitet — EIN Grund pro Zustand statt
/// „Geraet nicht verfuegbar" fuer alles.
///
/// Der `.available`-Fall hat bewusst keinen Key: dann rendert die Section
/// gar keinen Hinweis, sondern den Entwurfs-Eingabebereich.
public enum NutritionAIUnavailableReasonKey: Sendable, Equatable {
    /// OS aelter als 26 / Framework fehlt / Hardware nicht berechtigt.
    case deviceNotSupported
    /// Geraet geeignet, Apple Intelligence ist in den Systemeinstellungen aus.
    case appleIntelligenceNotEnabled
    /// Modell unterstuetzt die AKTIVE App-Sprache nicht (z. B. TR vor
    /// iOS 26.1). Geraet und Einstellung sind in Ordnung.
    case languageNotSupported
    /// Modell laedt noch / voruebergehend nicht bereit.
    case temporarilyUnavailable

    /// xcstrings-Key fuer den Hinweistext in der Erfassung
    /// (`AddMealView.aiSection`).
    public var captureHintLocalizationKey: String {
        switch self {
        case .deviceNotSupported:
            return "nutrition.addMeal.aiDraft.unavailable.device"
        case .appleIntelligenceNotEnabled:
            return "nutrition.addMeal.aiDraft.unavailable.disabled"
        case .languageNotSupported:
            return "nutrition.addMeal.aiDraft.unavailable.language"
        case .temporarilyUnavailable:
            return "nutrition.addMeal.aiDraft.unavailable.pending"
        }
    }
}

public extension NutritionAIAvailability {
    /// `nil` bei `.available` — sonst der Grund, den die UI nennen soll.
    var unavailableReasonKey: NutritionAIUnavailableReasonKey? {
        switch self {
        case .available:
            return nil
        case .deviceNotSupported:
            return .deviceNotSupported
        case .appleIntelligenceNotEnabled:
            return .appleIntelligenceNotEnabled
        case .languageNotSupported:
            return .languageNotSupported
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        }
    }
}

/// Real check against `SystemLanguageModel.default`.
public struct SystemNutritionAIAvailabilityChecker: NutritionAIAvailabilityChecking {
    public init() {}

    public func availability(for locale: Locale) -> NutritionAIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return model.supportsLocale(locale) ? .available : .languageNotSupported
            case .unavailable(.deviceNotEligible):
                return .deviceNotSupported
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .temporarilyUnavailable
            case .unavailable:
                // Reasons added in future OS versions: treat as transient so a later re-check can recover.
                return .temporarilyUnavailable
            }
        }
        #endif
        return .deviceNotSupported
    }
}
