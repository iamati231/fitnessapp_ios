import Foundation

/// Fertig uebersetzte Texte der Live Activity eines Zeitformats.
///
/// Der Widget-Prozess hat keinen String-Katalog (die Texte der Rest-Timer-Activity
/// sind deshalb fest deutsch). Hier uebersetzt die App und schickt das Ergebnis
/// mit jedem Update mit - der Widget-Code zeigt nur an. Reine Daten, damit auch
/// Nicht-iOS-Builds (Tests) diese Schicht uebersetzen.
public struct TimedWorkoutLiveTexts: Codable, Hashable, Sendable {

    /// Zustandswort: "LÄUFT", "PAUSE" oder "Geschafft!".
    public let phase: String
    /// Der Zaehler als Satz: "3 Runden", "Minute 3 / 12", "4 / 10 erledigt",
    /// "RUNDE 2/5".
    public let status: String
    /// Beschriftung der naechsten Uebung ("Naechste Minute"), nur beim EMOM
    /// gefuellt - sonst leer.
    public let nextLabel: String

    public init(phase: String, status: String, nextLabel: String = "") {
        self.phase = phase
        self.status = status
        self.nextLabel = nextLabel
    }
}
