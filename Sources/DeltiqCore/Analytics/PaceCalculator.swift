import Foundation

/// DEL-058: Pure-Logik fuer Cardio-Pace-Berechnung + Parsing der
/// User-Eingaben. Lebt in Core, damit das CardioSetRow-View den Wert pro
/// Tastenanschlag neu rechnen kann ohne SwiftData-Touch — und damit wir
/// die Berechnung 1:1 auf Windows-CI testen koennen.
public enum PaceCalculator {

    // MARK: - Pace

    /// Berechnet die Pace in min/km aus `distanceKm` und `durationSeconds`.
    /// Returns nil wenn Distanz <= 0 oder Dauer <= 0 (Division-Sicherheit).
    public static func minutesPerKm(distanceKm: Double, durationSeconds: Int) -> Double? {
        guard distanceKm > 0, durationSeconds > 0 else { return nil }
        let durationMinutes = Double(durationSeconds) / 60.0
        return durationMinutes / distanceKm
    }

    /// Formatiert eine min/km-Pace als "M:SS /km"-String. Nil → Platzhalter.
    public static func formatPace(_ minutesPerKm: Double?) -> String {
        guard let minutesPerKm, minutesPerKm.isFinite, minutesPerKm > 0 else {
            return "—:—— /km"
        }
        let totalSeconds = Int((minutesPerKm * 60.0).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    /// Convenience: berechnet + formatiert in einem Schritt. Wird vom
    /// CardioSetRow-View pro Tastenanschlag aufgerufen.
    public static func pace(
        distanceKm: Double?,
        durationSeconds: Int?
    ) -> String {
        guard let distanceKm, let durationSeconds else {
            return formatPace(nil)
        }
        return formatPace(minutesPerKm(distanceKm: distanceKm, durationSeconds: durationSeconds))
    }

    // MARK: - User-Input-Parser

    /// Parst eine Dauer-Eingabe in Sekunden. Akzeptiert mehrere Formate:
    ///   - "MM:SS"   z.B. "28:30" → 1710 s
    ///   - "H:MM:SS" z.B. "1:05:30" → 3930 s
    ///   - "MM"      z.B. "30" → 1800 s (reine Minuten als Integer)
    ///   - "MM.M"    z.B. "30.5" → 1830 s (Dezimal-Minuten — fuer Pace-Specs)
    ///   - Komma-Variante "30,5" wird auf Punkt normalisiert
    /// Returns nil wenn nichts davon greift oder Wert <= 0.
    public static func parseDurationToSeconds(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Variante A: enthaelt ":" → MM:SS oder H:MM:SS
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").map(String.init)
            switch parts.count {
            case 2:
                guard let m = Int(parts[0]), let s = Int(parts[1]),
                      m >= 0, s >= 0, s < 60
                else { return nil }
                let total = m * 60 + s
                return total > 0 ? total : nil
            case 3:
                guard let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]),
                      h >= 0, m >= 0, s >= 0, m < 60, s < 60
                else { return nil }
                let total = h * 3600 + m * 60 + s
                return total > 0 ? total : nil
            default:
                return nil
            }
        }

        // Variante B: rein numerisch (mit Komma/Punkt) → Minuten als Dezimal
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let minutes = Double(normalized), minutes > 0 else { return nil }
        return Int((minutes * 60.0).rounded())
    }

    /// Parst eine 5K-Referenzzeit-Eingabe speziell. Anders als
    /// `parseDurationToSeconds` faellt diese Variante NICHT auf "bare Zahl =
    /// Minuten" zurueck — eine Rennzeit muss als MM:SS oder H:MM:SS angegeben
    /// werden. Das entfernt genau die Mehrdeutigkeit, die ein bares "2500"
    /// als "2500 Minuten" (41+ Stunden) statt als ungueltig durchgehen liess.
    /// Begrenzt das Ergebnis zusaetzlich auf eine plausible 5K-Zeit
    /// (10:00-90:00 = 600-5400 s), damit auch ein Colon-formatierter, aber
    /// unplausibler Wert keine irrefuehrende abgeleitete Pace erzeugen kann.
    /// Returns nil bei leerer/unparsbarer/ausserhalb-des-Bereichs-Eingabe.
    public static func parseFiveKReferenceSeconds(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains(":") else { return nil }
        guard let seconds = parseDurationToSeconds(trimmed) else { return nil }
        let plausibleRange = 600...5400
        return plausibleRange.contains(seconds) ? seconds : nil
    }

    /// Parst eine Distanz-Eingabe in km. Komma → Punkt-Normalisierung.
    /// Returns nil bei <= 0 oder unparsable.
    public static func parseDistanceToKm(_ raw: String) -> Double? {
        let normalized = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              let km = Double(normalized),
              km > 0
        else { return nil }
        return km
    }

    /// Reverse-Direction Formatter — fuer Anzeige im History/Summary-View.
    /// Sekunden → "MM:SS" oder "H:MM:SS" je nach Groesse.
    public static func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
