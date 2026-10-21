import Foundation

/// Qualitative Einstufung pro Bewegungsfamilie — NIE als Zahl oder Note an
/// den Nutzer ausgegeben ("keine Fitnessnote", siehe Epic). Nur intern fuer
/// die Plan-Kalibrierung (Komplexitaet, Satzzahl, Ziel-RIR).
public enum BaselineBand: String, Sendable, Codable, CaseIterable, Hashable {
    case veryLow
    case low
    case moderate
    case high
    /// Kein Test, keine Selbsteinschaetzung vorhanden — bewusst NICHT
    /// gleichbedeutend mit `veryLow`. Bestandsnutzer ohne Check und
    /// Nutzer, die eine einzelne Bewegungsfamilie uebersprungen haben,
    /// landen hier.
    case unknown
}

/// Eingestufte Baender je Bewegungsfamilie — vollstaendig unabhaengig
/// voneinander. Ein niedriger Pull-Wert senkt NICHT Push/Beine (Epic:
/// "Ein niedriger Klimmzugwert senkt nicht den gesamten Plan").
public struct BaselineBands: Sendable, Equatable {
    public let push: BaselineBand
    public let legs: BaselineBand
    public let pull: BaselineBand
    public let core: BaselineBand
    public let cardio: BaselineBand

    public init(push: BaselineBand, legs: BaselineBand, pull: BaselineBand, core: BaselineBand, cardio: BaselineBand) {
        self.push = push
        self.legs = legs
        self.pull = pull
        self.core = core
        self.cardio = cardio
    }
}
