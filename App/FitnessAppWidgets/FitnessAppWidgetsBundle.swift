import WidgetKit
import SwiftUI

/// Widget extension entry-point. Lists every Widget / LiveActivity that this
/// extension target ships. Adding a new Home-Screen widget = adding a line here.
@main
struct FitnessAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        // Future Home-Screen widgets ("Naechstes Training", "Heutiges Wasser",
        // "Letzte Messung") slot in here.
    }
}
