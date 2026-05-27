#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftUI
import FitnessAppData

/// DEL-129: Lokalisierter Display-Name für `WorkoutSession`.
///
/// Bug-Hintergrund: `WorkoutSession.dayName` ist ein Snapshot-Feld, das beim
/// Session-Start mit `day.name` (System-Default in Deutsch) belegt wird.
/// Wechselt der User danach die App-Sprache auf EN/TR, rendert das UI den
/// stale DE-String — z.B. erscheint auf einem türkisch konfigurierten
/// iPhone das Banner "Ganzkörper A" statt "Tüm Vücut A".
///
/// Fix-Pattern (parallel zu `TrainingPlan/Day/Exercise.displayName`):
///   1. Wenn die Session noch eine lebende Day-Reference hat, route durch
///      `day.displayName` — der wertet customName/localizationKey/name in
///      genau dieser Reihenfolge aus und liefert den korrekt lokalisierten
///      String.
///   2. Wenn `day == nil` (gelöschter Plan, Cleanup-Cascade noch nicht
///      durch, etc.) → Snapshot `dayName` als Fallback (deutsch ist immer
///      noch besser als nichts).
///   3. Wenn auch `dayName == nil` → generischer i18n-Fallback aus dem
///      Catalog (`history.session.fallback`).
extension WorkoutSession {

    /// Kanonischer Display-Name für UI-Rendering. Ersetzt direkte
    /// `session.dayName ?? "Training"` Patterns in allen Call-Sites.
    public var displayDayName: String {
        // DEL-164: Spontane (ad-hoc) Sessions IMMER über den lokalisierten
        // Key rendern — unabhängig vom (ggf. deutsch eingefrorenen) Day-Namen
        // bzw. Snapshot. Der frühere Weg über `day.localizationKey` (DEL-150)
        // griff nicht zuverlässig (Day nil, Key nicht gesetzt, Pre-DEL-150-
        // Bestand) → im Verlauf blieb "Spontanes Training/Workout" deutsch
        // stehen, obwohl die TR-Übersetzung existiert. `isAdHoc` ist der
        // stabile Marker (einziger Erzeugungspfad: startAdHocWorkout), plus
        // ein Name-Guard für ganz alten Bestand, dem das Flag evtl. fehlt.
        if isAdHoc || isLegacyAdHocName {
            return String(localized: "session.adHoc.dayName", bundle: .module)
        }
        if let day {
            return day.displayName
        }
        if let snapshot = dayName, !snapshot.isEmpty {
            return snapshot
        }
        return String(localized: "history.session.fallback", bundle: .module)
    }

    /// DEL-164: Fängt ganz alten Bestand ab, dessen `isAdHoc`-Flag evtl. nicht
    /// gesetzt ist, der aber den hartcodierten DE-Ad-hoc-Namen trägt.
    private var isLegacyAdHocName: Bool {
        let legacy: Set<String> = ["Spontanes Workout", "Spontanes Training"]
        if let n = day?.name, legacy.contains(n) { return true }
        if let n = dayName, legacy.contains(n) { return true }
        return false
    }
}
#endif
