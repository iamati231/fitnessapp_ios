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
    ///   1. Varianten-Pool des gewünschten Tons (Basis-Key + numerierte
    ///      Varianten, siehe unten).
    ///   2. Tone-Fallback auf `.analytical` (neutralster Ton).
    ///   3. Leerer String → Caller (Dashboard) erkennt das und rendert
    ///      stattdessen den Empty-State.
    ///
    /// **DEL-198 Varianten-Rotation:** Pro (Context, Tone) können neben dem
    /// Basis-Key `coaching.soft.{context}.{tone}` numerierte Varianten
    /// `...{tone}.1`, `...{tone}.2`, … im Catalog liegen. Der Provider
    /// sammelt den Pool und rotiert tag-stabil über den Tag-im-Jahr —
    /// gleiche Mechanik wie die Edu-Tipps (DEL-168): derselbe Spruch bleibt
    /// einen Kalendertag stehen, am nächsten Tag kommt der nächste. Ein
    /// täglich triggernder Kontext (Streak, Plan-Preview) liest sich damit
    /// nicht mehr wie ein eingefrorenes Template.
    public static func softMessage(
        for context: CoachingContext,
        tone: CoachingTone,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        var pool = softVariantPool(context: context, tone: tone)
        if pool.isEmpty && tone != .analytical {
            pool = softVariantPool(context: context, tone: .analytical)
        }
        guard !pool.isEmpty else { return "" }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        return pool[(dayOfYear - 1) % pool.count]
    }

    /// Sammelt alle aufgelösten Varianten für (Context, Tone): erst den
    /// Basis-Key, dann `.1`, `.2`, … bis zur ersten Lücke. Lückenlose
    /// Nummerierung ist Pflicht — Variante `.3` ohne `.2` wird nie gefunden.
    private static func softVariantPool(
        context: CoachingContext,
        tone: CoachingTone
    ) -> [String] {
        let base = softKey(context: context, tone: tone)
        var pool: [String] = []
        if let resolved = resolve(key: base) {
            pool.append(resolved)
        }
        var index = 1
        while let resolved = resolve(key: "\(base).\(index)") {
            pool.append(resolved)
            index += 1
        }
        return pool
    }

    /// DEL-168: Edu-Coaching-Tipp (P3-Fallback). Wird auf dem Dashboard
    /// gerendert, wenn weder eine P1-Warnung noch ein datengetriebener
    /// P2-Soft-Insight greift — die App ist nie stumm, sondern liefert
    /// jeden Tag einen kleinen Wissens-/Mindset-Snack passend zum
    /// Coach-Tonfall.
    ///
    /// **Tag-stabile Rotation:** Der Index leitet sich vom Tag-im-Jahr ab
    /// (`dayOfYear % tipCount`), sodass derselbe Tipp ueber einen ganzen
    /// Kalendertag stabil bleibt und Mitternachts wechselt.
    ///
    /// **Tone-Fallback:** Falls die Uebersetzung fuer den gewaehlten Ton
    /// im jeweiligen Index fehlt, faellt es auf `analytical` (neutralster
    /// Ton) zurueck. Leerer String, wenn auch das nicht aufloest — Caller
    /// hat dann den endgueltigen Empty-State zu rendern.
    public static func eduMessage(
        for tone: CoachingTone,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let index = ((dayOfYear - 1) % eduTipCount) + 1   // 1-indexed fuer Lesbarkeit
        let primaryKey = "coaching.edu.\(tone.rawValue).\(index)"
        if let resolved = resolve(key: primaryKey) {
            return resolved
        }
        if tone != .analytical {
            let toneFallback = "coaching.edu.analytical.\(index)"
            if let resolved = resolve(key: toneFallback) {
                return resolved
            }
        }
        return ""
    }

    /// DEL-168: Anzahl der gepflegten Edu-Tipps pro Tonfall. Wenn du neue
    /// Eintraege im Catalog ergaenzt (`coaching.edu.<tone>.<n>`), diesen
    /// Wert mit dem hoechsten neuen Index updaten.
    /// DEL-198: 15 → 21 (6 neue Tipps pro Ton).
    public static let eduTipCount: Int = 21

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
