#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Singleton-style profile entity. Only one row should exist per app install —
/// caller-side responsibility (SwiftData has no manual singleton constraint).
/// Mirrors the `user_body_profile` Room table.
@Model
public final class UserBodyProfile {
    public var birthDate: Date
    public var heightCm: Double
    public var profile: BodyFormulaProfile
    /// Target body weight entered during onboarding (Fat-Loss goal). Nil if not set (F153).
    public var goalWeightKg: Double?
    /// Training location chosen in onboarding — drives plan recommendations (F154).
    public var environment: EnvironmentType

    /// DEL-100: Persoenlicher Coaching-Stil. Persistiert als String, sodass
    /// pre-DEL-100-Bestand via Default-Wert lightweight migriert wird.
    public var coachingToneRaw: String = CoachingTone.analytical.rawValue

    /// DEL-100: Langfristiges Trainings-Hauptziel. Steuert zusammen mit
    /// `coachingTone` die Matrix-Lookup-Keys der Coaching-Engine.
    public var trainingGoalRaw: String = TrainingGoal.hybrid.rawValue

    /// DEL-109: Dashboard-Widget-Konfiguration. Speichert die rawValues
    /// aller AKTIVEN Widgets in der gewuenschten Render-Reihenfolge.
    /// Nicht enthaltene `DashboardWidgetType`-Cases sind versteckt.
    /// Default = `DashboardWidgetType.defaultOrder` (historische Layout-
    /// Reihenfolge) — Lightweight-Migration der pre-DEL-109-Profile
    /// erbt damit das volle Set, identisches Nutzer-Erlebnis ohne
    /// "wo sind meine Cards"-Panik.
    public var activeDashboardWidgetsRaw: [String] = DashboardWidgetType.defaultOrder.map { $0.rawValue }

    /// DEL-132 (Phase 1): Hero-Metric-Slots fuer die Top-Reihe des
    /// Dashboards. Length 0-3. Identisches Pattern wie
    /// `activeDashboardWidgetsRaw`: rawValues in Render-Reihenfolge,
    /// nicht-enthaltene Cases sind versteckt, Length-0 versteckt die
    /// ganze Hero-Reihe. Default = `HeroMetricType.defaultOrder`
    /// (Weight + BodyFat + FFMI) — pre-Phase-1-Profile bekommen via
    /// Lightweight-Migration das identische 3er-Set, kein visueller
    /// Bruch fuer Bestand.
    public var heroMetricSlotsRaw: [String] = HeroMetricType.defaultOrder.map { $0.rawValue }

    /// Convenience-Accessor mit Default-Fallback, falls jemand einen
    /// invaliden String reinschreibt.
    public var coachingTone: CoachingTone {
        get { CoachingTone(rawValue: coachingToneRaw) ?? .analytical }
        set { coachingToneRaw = newValue.rawValue }
    }

    public var trainingGoal: TrainingGoal {
        get { TrainingGoal(rawValue: trainingGoalRaw) ?? .hybrid }
        set { trainingGoalRaw = newValue.rawValue }
    }

    /// DEL-109: Typed Convenience-Accessor auf die Widget-Liste. Filtered
    /// stille raw-Strings raus, die keinem aktuellen Enum-Case mehr
    /// entsprechen (z.B. nach einem Rename / Delete eines Widgets in einer
    /// Zukunfts-Welle) — verhindert dass die UI auf einem "Ghost"-Widget
    /// stehen bleibt.
    public var activeDashboardWidgets: [DashboardWidgetType] {
        get { activeDashboardWidgetsRaw.compactMap { DashboardWidgetType(rawValue: $0) } }
        set { activeDashboardWidgetsRaw = newValue.map { $0.rawValue } }
    }

    /// DEL-132 (Phase 1): Typed Accessor fuer Hero-Slots. Setter clampt
    /// auf `HeroMetricType.maxSlots` (3) — wenn die UI versehentlich mehr
    /// Slots schreiben wollte, ueberlebt das Layout. Stale rawStrings
    /// werden beim Lesen rausgefiltert (gleicher Robustness-Pattern wie
    /// activeDashboardWidgets).
    public var heroMetricSlots: [HeroMetricType] {
        get { heroMetricSlotsRaw.compactMap { HeroMetricType(rawValue: $0) } }
        set {
            let clamped = Array(newValue.prefix(HeroMetricType.maxSlots))
            heroMetricSlotsRaw = clamped.map { $0.rawValue }
        }
    }

    public init(
        birthDate: Date,
        heightCm: Double,
        profile: BodyFormulaProfile,
        goalWeightKg: Double? = nil,
        environment: EnvironmentType = .gym,
        coachingTone: CoachingTone = .analytical,
        trainingGoal: TrainingGoal = .hybrid
    ) {
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.profile = profile
        self.goalWeightKg = goalWeightKg
        self.environment = environment
        self.coachingToneRaw = coachingTone.rawValue
        self.trainingGoalRaw = trainingGoal.rawValue
    }
}
#endif
