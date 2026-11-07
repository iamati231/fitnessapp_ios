import Foundation

/// Running Coach - Herzfrequenz-Trainingszonen (Ticket "Running Coach -
/// Herzfrequenz-Trainingszonen und Nutzung der manuellen HFmax"). Rein
/// deterministisch und lokal, keine SwiftData-/HealthKit-Abhaengigkeit -
/// Vorbild `CardioFeasibilityCalculator` (reine Funktion + dokumentierte
/// "vorlaeufige Produktregeln"-Konstanten).
///
/// Diese Zonen sind eine VEREINFACHTE Orientierung anhand der manuell
/// hinterlegten HFmax (`UserBodyProfile.maxHeartRateBpm`) - KEINE individuell
/// gemessene Laktatschwelle, KEIN medizinisch validierter Trainingsbereich.
public enum HeartRateZoneCalculator {

    /// Plausibilitaetsgrenzen fuer eine manuell eingegebene HFmax -
    /// ausserhalb dieses Bereichs ist der Wert mit hoher Wahrscheinlichkeit
    /// ein Tippfehler (z.B. Koerpergewicht statt Puls), keine echte maximale
    /// Herzfrequenz. Vorlaeufige Produktregel, grosszuegig genug fuer
    /// Kinder/Senioren UND austrainierte Ausdauersportler.
    public static let minimumPlausibleMaxHeartRateBpm = 100
    public static let maximumPlausibleMaxHeartRateBpm = 230

    /// Prozentuale Grenzen der 5 Zonen in Reihenfolge Z1...Z5 (Ticket-
    /// Tabelle: 50-60-70-80-90-100% der HFmax).
    private static let zonePercentBreakpoints: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90, 1.00]

    public static func isPlausible(_ maxHeartRateBpm: Int) -> Bool {
        (minimumPlausibleMaxHeartRateBpm...maximumPlausibleMaxHeartRateBpm).contains(maxHeartRateBpm)
    }

    /// `nil` wenn `maxHeartRateBpm` fehlt oder unplausibel ist - niemals
    /// erfundene Zonen aus einem ungueltigen Wert.
    public static func zones(maxHeartRateBpm: Int?) -> [HeartRateZone]? {
        guard let maxHeartRateBpm, isPlausible(maxHeartRateBpm) else { return nil }
        // Einmalig gerundete Breakpoints (round-half-away-from-zero via
        // `.rounded()`) - jede Zonengrenze leitet sich aus DIESEM einen Array
        // ab, nie aus unabhaengig gerundeten Einzelwerten. Sonst koennten
        // benachbarte Zonen ueberlappen oder eine Luecke lassen.
        let breakpoints = zonePercentBreakpoints.map { Int((Double(maxHeartRateBpm) * $0).rounded()) }
        return (0..<5).map { i in
            HeartRateZone(
                index: i + 1,
                lowerBoundBpm: i == 0 ? breakpoints[0] : breakpoints[i] + 1,
                upperBoundBpm: breakpoints[i + 1]
            )
        }
    }

    /// Ordnet einen TATSAECHLICH GEMESSENEN Durchschnittspuls einer der
    /// berechneten Zonen zu - ausschliesslich fuer echte Messwerte gedacht,
    /// niemals fuer die HFmax selbst oder einen aus Pace/Profil abgeleiteten
    /// Wert (Ticket Teil 4: "keine Belastung ... als Messwert darstellen").
    /// `nil` wenn der Messwert ausserhalb jeder Zone liegt (z.B. unterhalb
    /// Z1 oder oberhalb der HFmax).
    public static func zone(forMeasuredBpm bpm: Int, in zones: [HeartRateZone]) -> HeartRateZone? {
        zones.first { ($0.lowerBoundBpm...$0.upperBoundBpm).contains(bpm) }
    }
}

public struct HeartRateZone: Sendable, Equatable, Identifiable {
    /// 1...5, Z1 = am lockersten/regenerativsten.
    public let index: Int
    public let lowerBoundBpm: Int
    public let upperBoundBpm: Int

    public var id: Int { index }

    /// xcstrings-Lookup-Keys, analog `DashboardWidgetType.localizationKey`.
    public var nameLocalizationKey: String { "heartRateZone.\(index).name" }
    public var descriptionLocalizationKey: String { "heartRateZone.\(index).description" }

    public init(index: Int, lowerBoundBpm: Int, upperBoundBpm: Int) {
        self.index = index
        self.lowerBoundBpm = lowerBoundBpm
        self.upperBoundBpm = upperBoundBpm
    }
}

/// Trennt sauber zwischen (a) aus der HFmax berechneten Zonen und (b)
/// tatsaechlich gemessener Trainingsherzfrequenz (Ticket Teil 4/5) - der
/// Aufrufer (`RaceProgressCardModel`) uebergibt beides getrennt, diese
/// Funktion erfindet nie einen Messwert und behandelt die HFmax nie als
/// Messwert.
public enum HeartRateZoneContextBuilder {

    /// Sehr weiter, rein physiologischer Plausibilitaetsrahmen fuer einen
    /// GEMESSENEN Durchschnittspuls (nicht zu verwechseln mit der engeren
    /// HFmax-Plausibilitaet oben) - ein Wert ausserhalb ist eher ein
    /// Sensor-/Messfehler als eine echte Trainingsherzfrequenz.
    public static let minimumPlausibleMeasuredBpm = 30
    public static let maximumPlausibleMeasuredBpm = 250

    public static func isValidMeasuredBpm(_ bpm: Int) -> Bool {
        (minimumPlausibleMeasuredBpm...maximumPlausibleMeasuredBpm).contains(bpm)
    }

    public static func make(maxHeartRateBpm: Int?, measuredAverageBpm: Int?) -> HeartRateZoneDisplayState {
        guard let maxHeartRateBpm, let zones = HeartRateZoneCalculator.zones(maxHeartRateBpm: maxHeartRateBpm) else {
            return .noMaxHeartRateConfigured
        }
        guard let measuredAverageBpm, isValidMeasuredBpm(measuredAverageBpm) else {
            return .zonesCalculatedNoMeasuredData(maxHeartRateBpm: maxHeartRateBpm, zones: zones)
        }
        return .zonesCalculatedWithMeasuredData(
            maxHeartRateBpm: maxHeartRateBpm, zones: zones,
            measuredAverageBpm: measuredAverageBpm,
            measuredZone: HeartRateZoneCalculator.zone(forMeasuredBpm: measuredAverageBpm, in: zones)
        )
    }
}

public enum HeartRateZoneDisplayState: Sendable, Equatable {
    /// Weder eine plausible HFmax noch Messdaten vorhanden.
    case noMaxHeartRateConfigured
    /// HFmax vorhanden, Zonen berechnet, aber (noch) keine gueltige
    /// gemessene Trainingsherzfrequenz.
    case zonesCalculatedNoMeasuredData(maxHeartRateBpm: Int, zones: [HeartRateZone])
    /// HFmax vorhanden UND mindestens ein gueltiger gemessener
    /// Durchschnittspuls liegt vor. `measuredZone` ist `nil`, wenn der
    /// Messwert ausserhalb aller 5 Zonen liegt.
    case zonesCalculatedWithMeasuredData(maxHeartRateBpm: Int, zones: [HeartRateZone], measuredAverageBpm: Int, measuredZone: HeartRateZone?)
}
