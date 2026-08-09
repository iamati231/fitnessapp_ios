import Foundation

/// DEL-251: berechnet eine realistische Cardio-Baseline (Wochenvolumen +
/// Referenzpace) aus bereits in Deltiq geloggten Laeufen — der "Retro-Sync"
/// aus dem Ticket, diese Runde bewusst NUR mit In-App-Daten
/// (`ExerciseLog.distanceKm`/`.durationSeconds` via `resolvedIsCardio`).
/// Der Ticket-Vorschlag, stattdessen HealthKit-Workout-Historie zu lesen,
/// wurde zurueckgestellt: `HKObjectType.workoutType()` steht in
/// `HealthKitService.requestAuthorization()` aktuell NUR in `toShare`, nie
/// in `toRead` - eine neue Lese-Autorisierung wuerde bei JEDEM bereits
/// verbundenen Bestandsnutzer einen neuen iOS-Permission-Dialog ausloesen,
/// auch bei Usern, die Cardio-Coaching nie aktivieren. HealthKit-Historie
/// kann ein spaeteres Ticket nachziehen.
///
/// Pure functions — `ProfileEditorView` aggregiert die Rohdaten (geloggte
/// Cardio-Distanzen/-Dauern der letzten `weeklyVolumeWindowDays` bzw.
/// `referenceWindowDays` Tage) und ruft hier nur die Berechnung ab.
/// Gleiches Prinzip wie `DeloadAdvisor`/`CardioCoachingAdvisor`.
public enum CardioBaselineCalculator {

    /// Ergebnis eines Retro-Sync-Laufs. `nil`-Felder bedeuten "zu wenig
    /// Daten fuer diese Metrik", nicht "Wert ist Null" - ein User ohne
    /// geloggte Laeufe soll nicht faelschlich `weeklyVolumeKm == 0`
    /// bekommen (das waere ein falscher Befund, kein fehlender).
    public struct Result: Equatable {
        public let weeklyVolumeKm: Double?
        public let referenceSeconds: Int?

        public init(weeklyVolumeKm: Double?, referenceSeconds: Int?) {
            self.weeklyVolumeKm = weeklyVolumeKm
            self.referenceSeconds = referenceSeconds
        }

        /// Kein einziger Wert konnte ermittelt werden — der Aufrufer sollte
        /// in diesem Fall gar keinen Bestaetigungs-Dialog zeigen.
        public var isEmpty: Bool { weeklyVolumeKm == nil && referenceSeconds == nil }
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
}
