import Foundation

extension Double {
    /// Truncate (NOT round) to `decimals` decimal places.
    ///
    /// Body-composition values are floored so calculated metrics aren't cosmetically
    /// rounded up (15.86 stays "15.86" rather than jumping to "15.9"). Floor-rounding
    /// is the right call for fitness tracking — overstating progress destroys trust
    /// the moment the user spot-checks the math.
    ///
    /// Mirrors `Double.truncateTo(decimals: Int)` in `BodyCalculations.kt` (uses `floor`).
    public func truncated(to decimals: Int) -> Double {
        precondition(decimals >= 0, "decimals must be non-negative")
        let factor = pow(10.0, Double(decimals))
        return (self * factor).rounded(.down) / factor
    }

    /// Formats to a fixed number of decimals, locale-aware via `Locale.current`.
    /// Signature-Geruest 2.16: der Nachkommastellen-Bedarf ist nicht mehr fuer
    /// jeden Wert gleich (Gewicht/Koerperfett/Differenzen brauchen eine Stelle,
    /// Volumen/Kalorien keine, nur echte Praezisions-Messungen wie Scheiben-
    /// gewichte oder Distanzen zwei) - `formattedTwoDecimals` bleibt der
    /// unveraenderte Default fuer alle bestehenden Aufrufstellen.
    ///
    /// CI-Fix: `String(format:locale:)` mit `%f` uebernimmt je nach OS-/ICU-
    /// Version auch die Tausender-GRUPPIERUNG der Locale, nicht nur das
    /// Dezimaltrennzeichen (auf dieser CI-Maschine z.B. "1250" -> "1,250").
    /// "Locale-aware" ist hier aber explizit nur als Dezimaltrennzeichen
    /// gemeint (siehe Kommentar oben) - Trainingsvolumen/Kalorien-Werte
    /// sollen nie eine Tausendergruppierung zeigen. Entfernt sie deshalb
    /// gezielt nach der Formatierung, ohne das Rundungsverhalten von `%f`
    /// selbst anzufassen.
    public func formatted(decimals: Int) -> String {
        precondition(decimals >= 0, "decimals must be non-negative")
        let raw = String(format: "%.\(decimals)f", locale: Locale.current, self)
        guard let groupingSeparator = Locale.current.groupingSeparator, !groupingSeparator.isEmpty else {
            return raw
        }
        return raw.replacingOccurrences(of: groupingSeparator, with: "")
    }

    /// App-wide standard for numeric display — ALWAYS 2 decimals.
    ///
    /// Forces trailing zeros (80.0 -> "80,00") for a uniform typographic look across
    /// dashboards, cards, and calculator results. Locale-aware via `Locale.current`,
    /// so DE users see the comma separator ("80,00") and EN/TR users see the dot.
    ///
    /// Where it matters, apply `truncated(to: 2)` BEFORE formatting so values aren't
    /// rounded up:  `value.truncated(to: 2).formattedTwoDecimals`.
    public var formattedTwoDecimals: String { formatted(decimals: 2) }

    /// Signature-Geruest 2.16: eine Nachkommastelle - Koerpergewicht,
    /// Koerperfett-Prozent, Gewichts-Differenzen und aehnliche Kennzahlen mit
    /// Personenwaagen-Aufloesung (100 g).
    public var formattedOneDecimal: String { formatted(decimals: 1) }

    /// Signature-Geruest 2.16: keine Nachkommastelle - diskrete Groessen wie
    /// Trainingsvolumen oder Kalorien, bei denen "0,00" nur erfundene
    /// Praezision vortaeuscht.
    public var formattedNoDecimals: String { formatted(decimals: 0) }
}

extension Float {
    /// Signature-Geruest 2.18: RIR wie ein Trainingsgewicht formatieren -
    /// ganze Zahlen ohne Nachkommastelle, sonst lokalisiert (Komma in DE).
    /// Ersetzt das bisherige `String(format: "%.1f", rir)` ohne Locale, das
    /// im deutschen Satz einen Punkt erzwang ("47,5 kg" neben "RIR 0.5").
    /// Gemeinsamer Helfer fuer SetRow.swift und WorkoutSummaryView.swift.
    public var formattedRIR: String {
        let value = Double(self)
        return value == value.rounded() ? "\(Int(value))" : value.formattedOneDecimal
    }
}
