// DEL-248 (Phase 4): drei Lauf-spezifische Coaching-Trigger, angelehnt an
// den "Hybrid-Athlete"-Blueprint - reduziert auf das, was ohne die dort
// vorausgesetzten (noch nicht existierenden) Profil-Felder (cardioRaceDate,
// cardioEventGoalRaw, current5kReferenceSeconds) bereits heute aus echten
// geloggten Daten berechenbar ist:
//   1. **Volumen-Spike** — Lauf-KM dieser Woche > 120% der Vorwoche. Direktes
//      Cardio-Pendant zu `DeloadAdvisor` (dort bewusst nur Kraft, siehe
//      dortiger DEL-236-Kommentar - Lauf-Ermuedung braucht eine eigene
//      Rechnung, keine gemeinsame mit Kraft-CNS-Last).
//   2. **Long-Run ueberfaellig** — der Plan sieht einen langen Lauf vor,
//      aber in den letzten 7 Tagen wurde keiner geloggt. Bewusst KEIN
//      Namens-/Key-Abgleich (z.B. "Long Run" ist im Generator tatsaechlich
//      der EXERCISE-Name der Tempo-Zone, nicht der Tages-Titel eines
//      Grundlagen-Laufs - Namensabgleich waere hier irrefuehrend), sondern
//      rein strukturell ueber die Ziel-Dauer.
//   3. **Junk Miles** — ein lockerer Lauf lief deutlich schneller als seine
//      Zielpace. Bewusst gegen die TAGES-Zielpace (aus `targetDistanceKm`/
//      `targetDurationMinutes` des jeweiligen Tages), nicht gegen ein
//      Profil-weites `paceEasy` - letzteres existiert noch nicht.
//      HINWEIS: aktuell OHNE Aufrufer in DashboardView (Review-Fund:
//      `PlanGenerator.cardioCandidates` setzt targetDistanceKm nie, siehe
//      Doc-Kommentar auf `CoachingContext.cardioJunkMiles`) - die Funktion
//      selbst bleibt korrekt und einsatzbereit fuer Phase 1.
//
// Pure functions — DashboardView aggregiert die Rohdaten (Wochen-KM,
// geloggte Lauf-Dauern, Plan-Struktur) und ruft hier nur die Entscheidung
// ab. Gleiches Prinzip wie `DeloadAdvisor`.

import Foundation

public enum CardioCoachingAdvisor {

    // MARK: - Volumen-Spike

    /// Mindest-Anstieg von Vorwoche zu dieser Woche (Faktor). 1.2 = +20%,
    /// identischer Schwellwert wie `DeloadAdvisor.minimumRampFactor` - beide
    /// Trigger warnen vor demselben Overreaching-Muster, nur fuer
    /// unterschiedliche Trainingsarten.
    public static let volumeSpikeRampFactor: Double = 1.2

    /// Entscheidet, ob die Lauf-Kilometer dieser Woche gefaehrlich schnell
    /// gestiegen sind. `previousWeekKm <= 0` (keine Vorwoche geloggt) liefert
    /// bewusst `false` statt eine Ratio gegen Null zu bilden - ohne
    /// Basis-Woche gibt es nichts, wovon ein "Anstieg" abweichen koennte.
    public static func isVolumeSpike(currentWeekKm: Double, previousWeekKm: Double) -> Bool {
        guard previousWeekKm > 0 else { return false }
        return currentWeekKm > previousWeekKm * volumeSpikeRampFactor
    }

    // MARK: - Long-Run ueberfaellig

    /// Ein geloggter Lauf zaehlt schon als "erledigt", wenn er mindestens
    /// diesen Anteil der Ziel-Dauer erreicht - siehe Coach-Text ("egal wie
    /// langsam"): der Punkt ist, die lange Einheit ueberhaupt anzugehen,
    /// nicht exakt die Ziel-Dauer zu treffen.
    public static let longRunCompletionTolerance: Double = 0.8

    /// Entscheidet, ob ein ueberfaelliger langer Lauf gemeldet werden soll.
    ///
    /// - Parameter planLongRunTargetMinutes: die Ziel-Dauer des laengsten
    ///   Cardio-Tages im aktiven Plan, `nil` wenn der Plan keinen erkennbar
    ///   LAENGEREN Cardio-Tag hat (Kraft-only-Plan, oder ein Lauf-Plan ohne
    ///   distinct lange Einheit - z.B. nur gleich lange Easy Runs). Bewusst
    ///   KEIN fixer globaler Minutenwert: ein Anfaenger-Template kann seinen
    ///   "langen Lauf" bei 50 Minuten ansetzen, ein Performance-Tier bei 85 -
    ///   ein einzelner globaler Schwellwert wuerde fuer die kuerzeren Tiers
    ///   nie greifen (siehe Audit-Fund: `hybrid_beginner`s 50-Minuten-Long-
    ///   Run wurde von einem frueheren festen 60-Minuten-Schwellwert nie
    ///   erfasst). Der Aufrufer bestimmt "laenger" relativ zum eigenen Plan.
    /// - Parameter recentRunDurationsMinutes: tatsaechlich geloggte
    ///   Lauf-Dauern (Minuten) im Betrachtungsfenster (typischerweise die
    ///   letzten 7 Tage) - der Aufrufer entscheidet das Fenster.
    public static func isLongRunOverdue(
        planLongRunTargetMinutes: Int?,
        recentRunDurationsMinutes: [Int]
    ) -> Bool {
        guard let target = planLongRunTargetMinutes, target > 0 else { return false }
        let requiredMinutes = Double(target) * longRunCompletionTolerance
        return !recentRunDurationsMinutes.contains { Double($0) >= requiredMinutes }
    }

    // MARK: - Junk Miles

    /// Mindest-Vorsprung (Minuten/km), ab dem ein lockerer Lauf als "zu
    /// schnell" zaehlt. Blueprint-Vorgabe war "> 20 Sekunden schneller" -
    /// `PaceCalculator` rechnet in Minuten/km, daher hier als Bruchteil.
    public static let junkMilesThresholdMinutesPerKm: Double = 20.0 / 60.0

    /// Entscheidet, ob ein Lauf deutlich schneller als seine Zielpace war.
    /// Beide Paces kommen bereits als Minuten/km herein (siehe
    /// `PaceCalculator.minutesPerKm`) - diese Funktion trifft nur die
    /// Schwellwert-Entscheidung, rechnet nicht selbst aus Distanz/Dauer.
    public static func isJunkMiles(actualPaceMinPerKm: Double, targetPaceMinPerKm: Double) -> Bool {
        actualPaceMinPerKm < targetPaceMinPerKm - junkMilesThresholdMinutesPerKm
    }
}
