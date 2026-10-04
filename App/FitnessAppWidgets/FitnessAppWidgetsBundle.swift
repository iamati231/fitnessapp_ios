import WidgetKit
import SwiftUI

/// Widget extension entry-point. Lists every Widget / LiveActivity that this
/// extension target ships. Adding a new Home-Screen widget = adding a line here.
@main
struct FitnessAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        // Zeitformate (AMRAP/EMOM/Auf Zeit/Zirkel) im Hintergrund.
        TimedWorkoutLiveActivity()
        // DEL-216: Interaktives Wasser-Widget (Home Screen, systemSmall/Medium).
        WaterTrackerWidget()
        // Future Home-Screen widgets ("Naechstes Training", "Letzte Messung")
        // slot in here.
    }
}
