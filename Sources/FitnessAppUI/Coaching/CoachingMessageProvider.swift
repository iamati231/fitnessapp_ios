#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// DEL-100: Resolved den richtigen Localization-Key fuer eine
/// `(CoachingContext, CoachingTone, TrainingGoal)`-Kombination aus
/// `Localizable.xcstrings`. Lebt im UI-Modul, weil nur das Modul-Bundle
/// die `.xcstrings`-Resources kennt.
///
/// **Fallback-Kette:**
///   1. Voll-spezifischer Key `coaching.{context}.{tone}.{goal}`
///   2. Wenn kein Treffer (xcstrings liefert den Key 1:1 zurueck statt
///      einer Uebersetzung): Tone-Fallback auf `.analytical` mit gleichem
///      Goal → `coaching.{context}.analytical.{goal}`
///   3. Wenn weiterhin nichts: Goal-Fallback auf `.hybrid` →
///      `coaching.{context}.analytical.hybrid`
///   4. Wenn immer noch nichts: leerer String (Caller muss UI-seitig
///      degraden, z.B. die Insight-Card komplett verstecken).
///
/// Die Kette erlaubt uns, mit ~10-12 starken Basis-Saetzen zu starten und
/// die Matrix iterativ auszubauen, ohne dass Holes im UI auftauchen.
public enum CoachingMessageProvider {

    /// Holt die lokalisierte Coaching-Message. Bei Localization-Key-Match
    /// kommt der DE-/EN-/TR-Text; bei Miss greift die Fallback-Kette.
    public static func message(
        for context: CoachingContext,
        tone: CoachingTone,
        goal: TrainingGoal
    ) -> String {
        // Primaerer Key.
        let primaryKey = key(context: context, tone: tone, goal: goal)
        if let resolved = resolve(key: primaryKey) {
            return resolved
        }

        // Tone-Fallback auf .analytical (neutralster Ton).
        if tone != .analytical {
            let toneFallback = key(context: context, tone: .analytical, goal: goal)
            if let resolved = resolve(key: toneFallback) {
                return resolved
            }
        }

        // Goal-Fallback auf .hybrid (am breitesten anwendbar).
        if goal != .hybrid {
            let goalFallback = key(context: context, tone: .analytical, goal: .hybrid)
            if let resolved = resolve(key: goalFallback) {
                return resolved
            }
        }

        // Caller-Verantwortung: leerer String → UI hat zu degraden.
        return ""
    }

    /// DEL-167: Soft-Coaching-Variante. Resolved den Schlüssel
    /// `coaching.soft.{context}.{tone}` (ohne Goal-Achse — Soft-Insights sind
    /// goal-agnostisch). Fallback-Kette:
    ///   1. Voll-spezifischer Key mit dem gewünschten Ton.
    ///   2. Tone-Fallback auf `.analytical` (neutralster Ton).
    ///   3. Leerer String → Caller (Dashboard) erkennt das und rendert
    ///      stattdessen den Empty-State.
    public static func softMessage(
        for context: CoachingContext,
        tone: CoachingTone
    ) -> String {
        let primaryKey = softKey(context: context, tone: tone)
        if let resolved = resolve(key: primaryKey) {
            return resolved
        }
        if tone != .analytical {
            let toneFallback = softKey(context: context, tone: .analytical)
            if let resolved = resolve(key: toneFallback) {
                return resolved
            }
        }
        return ""
    }

    // MARK: - Internals

    /// Baut den dotted Localization-Key fuer eine Matrix-Position.
    private static func key(
        context: CoachingContext,
        tone: CoachingTone,
        goal: TrainingGoal
    ) -> String {
        "coaching.\(context.rawValue).\(tone.rawValue).\(goal.rawValue)"
    }

    /// DEL-167: Schlüssel-Schema für Soft-Coaching (keine Goal-Achse).
    private static func softKey(context: CoachingContext, tone: CoachingTone) -> String {
        "coaching.soft.\(context.rawValue).\(tone.rawValue)"
    }

    /// Versucht, einen Key aufzuloesen. Liefert nil zurueck, wenn die
    /// xcstrings den Key NICHT uebersetzt haben (Apple-Default: 1:1-Echo
    /// des Keys). Damit kann der Caller eine Fallback-Stufe weiterspringen.
    private static func resolve(key: String) -> String? {
        let resource = String.LocalizationValue(key)
        let resolved = String(localized: resource, bundle: .module)
        return resolved == key ? nil : resolved
    }
}
#endif
