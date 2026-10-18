import Foundation

/// P6.3: Die beiden skalaren Antwortoptionen des kurzen, überspringbaren
/// Alltags-Rückblicks (Dok03 §4 — "Häufigkeit/Dauer/Belastung/Beschwerden/
/// Ziel-noch-aktuell"). `SessionFeeling` deckt "Belastung" bereits pro
/// Session ab; diese beiden Enums sind die subjektive Selbsteinschätzung zu
/// "Häufigkeit" und "Dauer" — bewusst ein grobes Drei-Stufen-Raster statt
/// einer Zahl, weil der Rückblick kurz bleiben soll. Sie ERGÄNZEN die
/// objektive `PlanParticipationEvaluator`-Zählung (P6.2), ersetzen sie nicht.
///
/// Reine Werttypen, keine Lokalisierung hier — Anzeige-Strings leben als
/// xcstrings-Keys in der UI-Schicht, analog zu allen anderen seit diesem
/// Refactor eingeführten Texten.
public enum FrequencyFeedback: Int, Sendable, Equatable, CaseIterable, Codable {
    case lessThanPlanned = 0
    case asPlanned = 1
    case moreThanPlanned = 2
}

/// Subjektives Empfinden der Einheiten-Dauer.
public enum DurationFeedback: Int, Sendable, Equatable, CaseIterable, Codable {
    case tooShort = 0
    case justRight = 1
    case tooLong = 2
}

/// Nachbesserung (Vier-Wochen-Rückblick-Runde): subjektives Belastungs-
/// empfinden über den GESAMTEN Rückblickzeitraum — bewusst eine eigene,
/// optionale Frage INNERHALB `PeriodicCheckIn`, keine Wiederverwendung von
/// `WorkoutSession.sessionFeeling`. `sessionFeeling` bewertet eine einzelne
/// Trainingseinheit und ist dort als nicht-optionaler Pflichtwert mit
/// vorbelegtem Default (`.okay`) modelliert (`FinishWorkoutSheet`) — für
/// eine periodenbezogene, echt überspringbare Frage ist das weder inhaltlich
/// (eine Session ist keine vier Wochen) noch technisch (kein Skip-Pfad, ein
/// übergangener Wert wäre nicht von einer bewussten "Okay"-Antwort zu
/// unterscheiden) geeignet. Der bestehende Trainingsabschluss bleibt dafür
/// unverändert.
public enum ExertionFeedback: Int, Sendable, Equatable, CaseIterable, Codable {
    case tooEasy = 0
    case appropriate = 1
    case tooHard = 2
}
