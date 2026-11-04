#if canImport(SwiftData)
import Foundation
import SwiftData

/// DEL-200: Ein-Tap-Deload-Woche.
///
/// Macht aus der DEL-196-Empfehlung eine Handlung: `startDeload` halbiert
/// die Arbeitsgewichte aller Strength-Übungen des aktiven Plans und sichert
/// die Originale in `Exercise.deloadOriginalWeight`. `endDeload` stellt sie
/// wieder her — manuell per Button oder automatisch nach Ablauf (das
/// Ablaufdatum verwaltet die UI via `@AppStorage("deload_until")`).
///
/// **Was reduziert wird:** nur Working-Sets mit gesetztem `suggestedWeight`,
/// kein Cardio, kein Time-Based, keine Warmup-/Cooldown-Übungen, keine
/// archivierten Snapshots. Übungen, die bereits einen Deload-Snapshot
/// tragen, werden übersprungen (doppeltes `startDeload` ist idempotent —
/// sonst würde ein zweiter Tap die Gewichte auf 25% drücken).
///
/// **Rundung:** auf 2,5 kg (kleinstes Plate-Paar), Minimum 20 kg (leere
/// Stange) — ein 30-kg-Curl-Deload auf 15 kg ist okay, aber Barbell-Lifts
/// unter Stangengewicht sind sinnlos. Wir runden simpel und lassen das
/// Minimum bei 2,5, weil wir hier nicht wissen, ob Barbell oder Kurzhantel.
@MainActor
public enum DeloadManager {

    /// Standard-Reduktion: 50% — mittig im evidenzbasierten Deload-Band
    /// (40-60% Last bei gleichbleibender Bewegung).
    public static let defaultFactor: Double = 0.5

    /// Standard-Dauer einer Deload-Woche in Tagen.
    public static let defaultDurationDays: Int = 7

    /// DEL-238: Laeuft gerade ein Deload — aus Sicht der DATEN, nicht des
    /// Timers?
    ///
    /// Bisher war `@AppStorage("deload_until")` in der DashboardView die
    /// einzige Wahrheit darueber. Das hat zwei Loecher: der Key ist nicht
    /// portabel (Neuinstallation, Restore aus Backup) und er lebt in einer
    /// View, die andere Startpfade nicht kennt. Geht er verloren, bleiben die
    /// Gewichte reduziert, das Banner verschwindet — und damit der einzige
    /// UI-Pfad zu `endDeload`. Diese Nutzer sitzen dauerhaft auf halbierten
    /// Gewichten fest.
    ///
    /// `deloadOriginalWeight != nil` ist dagegen die belastbare Wahrheit: es
    /// wandert im Backup mit und ist genau dann gesetzt, wenn ein Original
    /// gesichert wurde und darauf wartet, zurueckgestellt zu werden.
    public static func isActive(in context: ModelContext) -> Bool {
        pendingCount(in: context) > 0
    }

    /// Wie viele Uebungen warten auf ihre Original-Gewichte? Fuer die
    /// Beschriftung des Beenden-Buttons ("N Uebungen").
    public static func pendingCount(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.deloadOriginalWeight != nil }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Reduziert die Gewichte des aktiven Plans. Liefert die Anzahl der
    /// angepassten Übungen (0 = es gab nichts zu reduzieren — UI sollte
    /// dann gar nicht erst in den Deload-Zustand wechseln).
    @discardableResult
    public static func startDeload(
        in context: ModelContext,
        factor: Double = defaultFactor
    ) throws -> Int {
        // Spiegelt den Guard aus `AbsenceDeload.apply` — kein stilles Erhoehen
        // von Gewichten bei factor >= 1, kein NaN/Inf.
        guard factor.isFinite, factor > 0, factor < 1.0 else { return 0 }
        let plans = try context.fetch(
            FetchDescriptor<TrainingPlan>(predicate: #Predicate { $0.isActive == true })
        )
        var adjusted = 0
        for plan in plans {
            for day in plan.days {
                for exercise in day.activeExercises {
                    guard !exercise.isCardio,
                          !exercise.isTimeBased,
                          exercise.role == .workingSet,
                          exercise.deloadOriginalWeight == nil,
                          let original = exercise.suggestedWeight,
                          original > 0 else { continue }
                    exercise.deloadOriginalWeight = original
                    let reduced = (original * factor / 2.5).rounded() * 2.5
                    exercise.suggestedWeight = max(reduced, 2.5)
                    adjusted += 1
                }
            }
        }
        if adjusted > 0 {
            try context.save()
        }
        return adjusted
    }

    /// Stellt alle Deload-Snapshots wieder her (planübergreifend — falls
    /// der User mitten im Deload den Plan gewechselt hat, sollen die alten
    /// Übungen trotzdem ihre Originale zurückbekommen). Liefert die Anzahl
    /// der restaurierten Übungen.
    @discardableResult
    public static func endDeload(in context: ModelContext) throws -> Int {
        let pending = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.deloadOriginalWeight != nil })
        )
        for exercise in pending {
            exercise.suggestedWeight = exercise.deloadOriginalWeight
            exercise.deloadOriginalWeight = nil
        }
        if !pending.isEmpty {
            try context.save()
        }
        return pending.count
    }
}
#endif
