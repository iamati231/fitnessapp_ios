import Foundation

/// DEL-251: berechnet eine realistische Cardio-Baseline (Wochenvolumen +
/// Referenzpace) aus bereits in Deltiq geloggten Laeufen — der "Retro-Sync"
/// aus dem Ticket, diese Runde bewusst NUR mit In-App-Daten
/// (`ExerciseLog.distanceKm`/`.durationSeconds` via `resolvedIsCardio`).
/// Der Ticket-Vorschlag, stattdessen HealthKit-Workout-Historie zu lesen,
/// wurde zurueckgestellt: Das Lesen von `HKObjectType.workoutType()` dient
/// bisher nur dem Workout-Import und dem Abgleich beim Export (siehe
/// `HealthKitService.requestAuthorization()`, wo der Typ seit der
/// Trainings-Freigabe in `toShare` UND `toRead` steht). Eine Baseline aus der
/// HealthKit-Historie braucht eine eigene Produktentscheidung - und fuer
/// Bestandsnutzer, die den Typ nur zum Schreiben freigegeben haben, laesst sich
/// das Lesen nicht mehr nachfragen. Kann ein spaeteres Ticket nachziehen.
///
/// Pure functions — `ProfileEditorView` aggregiert die Rohdaten (geloggte
/// Cardio-Distanzen/-Dauern der letzten `weeklyVolumeWindowDays` bzw.
/// `referenceWindowDays` Tage) und ruft hier nur die Berechnung ab.
/// Gleiches Prinzip wie `DeloadAdvisor`/`CardioCoachingAdvisor`.
public enum CardioBaselineCalculator {

    /// Ergebnis eines Retro-Sync-Laufs. `nil`-Felder bedeuten "zu wenig
    /// Daten fuer diese Metrik", nicht "Wert ist Null".
    public struct Result: Equatable {
        public let weeklyVolumeKm: Double?
        /// Herkunft des `weeklyVolumeKm`-Werts — fuer nutzerseitige Erklaerung
        /// im Bestaetigungs-Dialog. `nil` wenn `weeklyVolumeKm == nil`.
        public let volumeCategory: VolumeCategory?
        public let referenceSeconds: Int?
        /// Phase F: Median aus tatsaechlich absolvierten ~5-km-Laeufen (90-Tage-
        /// Fenster). `nil` wenn < `minimumFiveKmSamples` gueltige Laeufe
        /// vorliegen. Wird in `applyCardioBaseline` dem extrapolierten
        /// `referenceSeconds` vorgezogen — echte 5-km-Median-Daten sind
        /// repraesentativer als ein aus dem schnellsten >3-km-Lauf
        /// hochgerechneter Wert.
        public let median5kSeconds: Int?

        public init(weeklyVolumeKm: Double?, volumeCategory: VolumeCategory? = nil, referenceSeconds: Int?, median5kSeconds: Int? = nil) {
            self.weeklyVolumeKm = weeklyVolumeKm
            self.volumeCategory = volumeCategory
            self.referenceSeconds = referenceSeconds
            self.median5kSeconds = median5kSeconds
        }

        /// Kein einziger Wert konnte ermittelt werden — der Aufrufer sollte
        /// in diesem Fall gar keinen Bestaetigungs-Dialog zeigen.
        public var isEmpty: Bool { weeklyVolumeKm == nil && referenceSeconds == nil }
    }

    /// Klassifizierung des Trainingsstatus — bestimmt Herkunft und Berechnung
    /// des vorgeschlagenen Startvolumens.
    public enum VolumeCategory: Equatable, Sendable {
        /// Regelmaessig laufend innerhalb der letzten `pauseThresholdDays` Tage.
        case activeRunner
        /// Laufhistorie vorhanden, aber laengere Pause erkannt.
        /// `pauseWeeks`: Anzahl Wochen seit dem letzten Lauf.
        case returningRunner(pauseWeeks: Int)
        /// Keine verwertbare Laufhistorie — Anfaenger-Einstieg.
        case beginner
        /// Zu wenige Daten fuer eine belastbare Klassifizierung.
        case insufficientData
    }

    /// Einzelner Laufeintrag mit Zeitstempel — Eingabe fuer `classifyWeeklyVolume`.
    public struct TimestampedEntry: Sendable {
        public let date: Date
        public let distanceKm: Double
        public init(date: Date, distanceKm: Double) {
            self.date = date
            self.distanceKm = distanceKm
        }
    }

    /// Ein einzelner geloggter Lauf (Distanz + Dauer) — Eingabe fuer die
    /// Referenzpace-Auswahl.
    public struct RunSample {
        public let distanceKm: Double
        public let durationSeconds: Int

        public init(distanceKm: Double, durationSeconds: Int) {
            self.distanceKm = distanceKm
            self.durationSeconds = durationSeconds
        }
    }

    /// Zeitfenster fuer die Volumen-Klassifizierung (8–13 Wochen Horizont,
    /// gleich `fiveKmMedianWindowDays`): lang genug, um eine Trainingspause
    /// sicher zu erkennen und historisches Volumen abzuschaetzen.
    public static let classificationWindowDays: Int = 90

    /// Ab dieser Pausenlaenge (Tage ohne Lauf) gilt ein User als Wiedereinstieg.
    /// 6 Wochen ohne Training reduzieren die Laufbelastbarkeit sichtbar.
    public static let pauseThresholdDays: Int = 42

    /// Konservativer Anfaenger-Einstieg (km/Woche) wenn keine Laufhistorie
    /// vorliegt: ~3 Einheiten × 10–15 Min ≈ 3 km — kein Bezug zum Laufziel.
    public static let beginnerDefaultKm: Double = 3.0

    /// Zeitfenster fuer die Wochenvolumen-Berechnung (Ticket-Vorgabe: "die
    /// letzten 4 Wochen").
    public static let weeklyVolumeWindowDays: Int = 28
    public static let weeklyVolumeWeeks: Int = 4

    /// Zeitfenster fuer die Referenzpace-Suche (Ticket-Vorgabe: "letzten 60
    /// Tage").
    public static let referenceWindowDays: Int = 60

    /// Laeufe unter dieser Dauer zaehlen nicht als Referenz-Kandidat -
    /// filtert fehlgestartete Uhren/Dateneingabe-Ausreisser raus (Ticket-
    /// Tech-Note). Bei einem qualifizierenden Lauf ab
    /// `minimumReferenceRunDistanceKm` waere eine derart kurze Dauer ohnehin
    /// physiologisch unplausibel - reine Verteidigungslinie gegen
    /// Fehleingaben, kein realistischer Ausschluss echter Laeufe.
    public static let minimumQualifyingDurationSeconds: Int = 300

    /// Nur Laeufe AB dieser Distanz zaehlen als "Referenz-wuerdig" fuer die
    /// `current5kReferenceSeconds`-Ableitung (Ticket-Vorgabe: > 3 km).
    public static let minimumReferenceRunDistanceKm: Double = 3.0

    /// Durchschnittliches Wochenvolumen. `distancesKm` ist bereits vom
    /// Aufrufer auf `weeklyVolumeWindowDays` vorgefiltert - diese Funktion
    /// summiert nur und teilt durch `weeklyVolumeWeeks`. Alle Laeufe zaehlen
    /// (kein Mindest-Distanz-/Dauer-Filter) - anders als bei der
    /// Referenzpace geht es hier um trainiertes VOLUMEN, ein kurzer
    /// Erholungslauf zaehlt genauso.
    public static func weeklyVolumeKm(distancesKm: [Double]) -> Double? {
        guard !distancesKm.isEmpty else { return nil }
        return distancesKm.reduce(0, +) / Double(weeklyVolumeWeeks)
    }

    /// Klassifiziert das Wochenvolumen anhand zeitgestempelter Laufeintraege.
    ///
    /// Klassifizierungslogik:
    ///   A. Aktiver Laeuer (letzter Lauf ≤ `pauseThresholdDays`, ≥ 2 aktive
    ///      Wochen der letzten 4): Median der 4 letzten Wochenvolumen.
    ///   B. Wiedereinstieg (letzter Lauf > `pauseThresholdDays`): Median der
    ///      4 Wochen vor der Pause × Reduktionsfaktor nach Pausenlaenge.
    ///   C. Kein Eintraege im Fenster → Anfaenger, `beginnerDefaultKm`.
    ///   D. Nur 1 aktive Woche der letzten 4 → `insufficientData`.
    ///
    /// Der `referenceDate`-Parameter dient als Test-Injection-Punkt (Default: heute).
    public static func classifyWeeklyVolume(
        entries: [TimestampedEntry],
        referenceDate: Date = Date()
    ) -> (category: VolumeCategory, suggestedKm: Double) {
        let cal = Calendar.current
        let windowStart = cal.date(byAdding: .day, value: -classificationWindowDays, to: referenceDate) ?? .distantPast
        let windowEntries = entries.filter { $0.date >= windowStart }

        guard let lastRunDate = windowEntries.map(\.date).max() else {
            return (.beginner, beginnerDefaultKm)
        }

        let daysSinceLast = cal.dateComponents([.day], from: lastRunDate, to: referenceDate).day ?? 0

        if daysSinceLast > pauseThresholdDays {
            let pauseWeeks = max(1, daysSinceLast / 7)

            // Median der 4 Wochen direkt vor der Pause als historisches Volumen
            var preWeeklyKm = [Double](repeating: 0.0, count: 4)
            for entry in windowEntries {
                let daysFromLast = max(0, cal.dateComponents([.day], from: entry.date, to: lastRunDate).day ?? 0)
                guard daysFromLast < 28 else { continue }
                let bucket = min(daysFromLast / 7, 3)
                preWeeklyKm[bucket] += entry.distanceKm
            }
            let preSorted = preWeeklyKm.sorted()
            // Bei ≥ 2 aktiven Wochen: Median; sonst Mittelwert aller Eintraege / 4
            let preActive = preWeeklyKm.filter { $0 > 0 }.count
            let historicalKm: Double
            if preActive >= 2 {
                historicalKm = (preSorted[1] + preSorted[2]) / 2.0
            } else {
                historicalKm = windowEntries.reduce(0.0) { $0 + $1.distanceKm } / 4.0
            }

            let factor: Double
            if pauseWeeks <= 4 { factor = 0.80 }
            else if pauseWeeks <= 8 { factor = 0.60 }
            else { factor = 0.40 }

            return (.returningRunner(pauseWeeks: pauseWeeks), max(historicalKm * factor, beginnerDefaultKm))
        }

        // Aktiver Laeuer: 4 Wochenbuckets der letzten 28 Tage
        let fourWeekStart = cal.date(byAdding: .day, value: -28, to: referenceDate) ?? .distantPast
        var weeklyKm = [Double](repeating: 0.0, count: 4)
        for entry in windowEntries where entry.date >= fourWeekStart {
            let daysAgo = max(0, cal.dateComponents([.day], from: entry.date, to: referenceDate).day ?? 0)
            let bucket = min(daysAgo / 7, 3)
            weeklyKm[bucket] += entry.distanceKm
        }

        let activeWeeks = weeklyKm.filter { $0 > 0 }.count
        if activeWeeks < 2 {
            let mean = weeklyKm.reduce(0.0, +) / 4.0
            return (.insufficientData, max(mean, beginnerDefaultKm))
        }

        // Median aus 4 Wochenvolumen (robust gegen Ausreisser-Wochen)
        let sorted = weeklyKm.sorted()
        let median = (sorted[1] + sorted[2]) / 2.0
        return (.activeRunner, max(median, beginnerDefaultKm))
    }

    /// Leitet eine 5-km-Referenzzeit aus dem schnellsten qualifizierenden
    /// Lauf ab (Ticket-Vorgabe, woertlich: "schnellster Lauf >3km"). Skaliert
    /// dessen Pace auf 5 km — die Umkehrung von
    /// `PaceZoneCalculator.racePaceMinutesPerKm` (das aus einer Referenzzeit
    /// eine Pace macht, hier laeuft die Rechnung andersrum). Nil wenn kein
    /// Lauf die Schwellwerte erfuellt.
    public static func fastestReferenceSeconds(from runs: [RunSample]) -> Int? {
        let qualifying = runs.filter {
            $0.distanceKm >= minimumReferenceRunDistanceKm &&
            $0.durationSeconds >= minimumQualifyingDurationSeconds
        }
        let paces = qualifying.compactMap {
            PaceCalculator.minutesPerKm(distanceKm: $0.distanceKm, durationSeconds: $0.durationSeconds)
        }
        guard let fastestPace = paces.min() else { return nil }
        return Int((fastestPace * 5.0 * 60.0).rounded())
    }

    // MARK: - Phase F: Median-5-km-Baseline

    /// Distanz-Toleranz fuer "echte 5-km-Laeufe" — GPS-Abweichung und
    /// geplante 5-km-Runden fallen typisch auf 4,5–5,5 km. Ausserhalb davon
    /// ist die Einheit kein 5-km-Lauf und darf nicht einfliesssen.
    public static let fiveKmDistanceRangeLow: Double = 4.5
    public static let fiveKmDistanceRangeHigh: Double = 5.5

    /// Mindestanzahl gueltiger 5-km-Laeufe fuer eine stabile Median-Baseline.
    /// Unter diesem Wert haengt der Median zu stark an einer einzigen Messung.
    public static let minimumFiveKmSamples: Int = 3

    /// Beobachtungsfenster in Tagen. Laenger als `referenceWindowDays` (60 d),
    /// weil echte 5-km-Laeufe im Trainingsalltag seltener vorkommen als
    /// beliebige Referenzlaeufe (> 3 km) — ein engeres Fenster liefert sonst
    /// zu selten genueg Daten. Der Aufrufer filtert nach diesem Wert,
    /// identisches Muster wie bei `weeklyVolumeKm`/`fastestReferenceSeconds`.
    public static let fiveKmMedianWindowDays: Int = 90

    // Plausibilitaetsgrenzen fuer die berechnete 5-km-Aequivalent-Zeit —
    // identisch mit `PaceCalculator.parseFiveKReferenceSeconds` (600 s = 10:00,
    // 5400 s = 90:00), damit manuelle Eingabe und abgeleiteter Wert dieselbe
    // Pruefung durchlaufen.
    private static let fiveKmPlausibleMinSeconds: Int = 600
    private static let fiveKmPlausibleMaxSeconds: Int = 5400

    /// Berechnet eine 5-km-Median-Baseline aus tatsaechlich absolvierten
    /// ~5-km-Laeufen. Verwendet ausschliesslich echte Distanz-/Zeitdaten,
    /// schaetzt keine 5-km-Zeit aus laengeren oder kuerzeren Laeufen.
    ///
    /// Filter (alle muessen erfuellt sein):
    ///   1. Distanz in [`fiveKmDistanceRangeLow`, `fiveKmDistanceRangeHigh`]
    ///   2. Dauer >= `minimumQualifyingDurationSeconds` (fehlgestartete Uhren)
    ///   3. Berechnetes 5-km-Aequivalent im Bereich [`fiveKmPlausibleMinSeconds`,
    ///      `fiveKmPlausibleMaxSeconds`] (implausible Ausreisser)
    ///
    /// Median-Definition: bei gerader Anzahl Mittelwert der zwei Mittelwerte.
    /// Pace wird aus den Rohdaten berechnet (kein Vorrunden), auf 5 km
    /// skaliert und abschliessend gerundet.
    ///
    /// Liefert `nil` wenn < `minimumFiveKmSamples` gueltige Laeufe vorliegen.
    /// Der Aufrufer ist verantwortlich, `runs` auf `fiveKmMedianWindowDays`
    /// vorzufiltern (gleiche Konvention wie `weeklyVolumeKm`).
    public static func medianFiveKmSeconds(from runs: [RunSample]) -> Int? {
        let paces: [Double] = runs.compactMap { sample in
            guard sample.distanceKm >= fiveKmDistanceRangeLow,
                  sample.distanceKm <= fiveKmDistanceRangeHigh,
                  sample.durationSeconds >= minimumQualifyingDurationSeconds,
                  let pace = PaceCalculator.minutesPerKm(
                      distanceKm: sample.distanceKm,
                      durationSeconds: sample.durationSeconds
                  )
            else { return nil }
            let fiveKmEquivalent = Int((pace * 5.0 * 60.0).rounded())
            guard fiveKmEquivalent >= fiveKmPlausibleMinSeconds,
                  fiveKmEquivalent <= fiveKmPlausibleMaxSeconds
            else { return nil }
            return pace
        }
        guard paces.count >= minimumFiveKmSamples else { return nil }
        let sorted = paces.sorted()
        let mid = sorted.count / 2
        let medianPace = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2.0
            : sorted[mid]
        return Int((medianPace * 5.0 * 60.0).rounded())
    }
}
