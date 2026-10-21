import Foundation

/// DEL-109: Konfigurierbarer Dashboard-Widget-Typ. Persistiert in
/// `UserBodyProfile.activeDashboardWidgetsRaw` als String-Array — die
/// Reihenfolge des Arrays bestimmt die Render-Reihenfolge auf dem
/// Dashboard, und nicht-enthaltene Cases sind versteckt.
///
/// **Was IST configurable:** alle dynamischen Cards unterhalb der
/// Hero-Metrics (Gewicht/KFA/FFMI). Reihenfolge per Drag&Drop in
/// `DashboardSettingsView`, Sichtbarkeit per Toggle.
///
/// **Was ist NICHT configurable:** die Hero-Metrics-Row oben. Die ist
/// zu zentral für den ersten App-Eindruck, und das Plus-Icon in der
/// Nav-Bar (neue Messung) lebt sowieso in der Toolbar.
///
/// **Neue Cases:** raw-Value ist Apple's Persistenz-Schlüssel —
/// rename = Storage-Migration. Neue Cases einfach am Ende anhängen,
/// dann erscheinen sie automatisch bei pre-DEL-109-Usern in der
/// Inactive-Section der Settings.
public enum DashboardWidgetType: String, Codable, Sendable, CaseIterable {
    case nextWorkout       // planDayCard — "Nächstes Training" / "Heute: Ruhetag"
    case coachingInsight   // coachingInsightCard — DEL-100 tone-aware Hints
    case trophyRoom        // PR-Teaser-Card
    case workoutHistory    // Trainingsverlauf-Nav-Link
    case weeklyVolume      // "Diese Woche" — Volumen + Distanz
    case muscleHeatmap     // Muskel-Heatmap-Grid
    case weightTrend       // Gewichts-Trend-Chart
    case compoundLifts     // Compound-Lift-1RM-Trend
    case cardioPace        // Cardio-Pace-Trend
    case recentWorkouts    // "Letzte Workouts"-Liste
    case volumeOverTime    // DEL-178: Wochen-Volume-Trend (BarMark)
    case trainingCalendar  // DEL-197: Monats-Kalender + Wochen-Streak
    case nutrition         // Task 9: Tagesuebersicht-Teaser + "Mahlzeit hinzufuegen"

    /// xcstrings-Lookup-Key: `widget.{rawValue}.name`.
    public var localizationKey: String {
        "widget.\(rawValue).name"
    }

    /// Default-Reihenfolge fuer Erst-User. Identisch zur historischen
    /// Layout-Reihenfolge in DashboardView — damit das Refactoring
    /// optisch zu 100% identisch beginnt.
    public static var defaultOrder: [DashboardWidgetType] {
        [
            .nextWorkout,
            .coachingInsight,
            .weeklyVolume,
            .muscleHeatmap,
            .trainingCalendar,
            .trophyRoom,
            .workoutHistory,
            .weightTrend,
            .compoundLifts,
            .volumeOverTime,
            .cardioPace,
            .recentWorkouts,
            .nutrition,
        ]
    }
}
