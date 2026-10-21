import Foundation

/// Fertig uebersetzte Texte der Rest-Timer-Live-Activity.
///
/// Bugfix (Audit): das Widget-Extension-Target hat keinen String-Katalog
/// (siehe `TimedWorkoutLiveTexts` fuer dasselbe Problem beim Zeitformat-
/// Lauf) — bisher zeigte `RestTimerLiveActivity` deshalb fest deutsche
/// Literale, egal welche Geraetesprache eingestellt war. Die App uebersetzt
/// jetzt hier und schickt das Ergebnis mit jedem Update mit; der Widget-Code
/// zeigt nur noch an. Reine Daten, damit auch Nicht-iOS-Builds (Tests) diese
/// Schicht uebersetzen koennen.
public struct RestTimerLiveTexts: Codable, Hashable, Sendable {

    /// "Satz 2 / 5" — Dynamic Island (beide Zahlen).
    public let setLabel: String
    /// "Satz 2" — Sperrbildschirm (nur die aktuelle Zahl).
    public let setLabelShort: String
    /// "PAUSE" bzw. lokalisiertes Aequivalent — laufender Pausen-Zustand.
    public let pauseRunning: String
    /// "PAUSE VORBEI" bzw. lokalisiertes Aequivalent — Pause abgelaufen.
    public let pauseOver: String
    /// "Personal Record!" — Ueberschrift der PR-Feier.
    public let personalRecordTitle: String
    /// "Im Trophy Room ansehen" — Call-to-Action der PR-Feier.
    public let viewInTrophyRoom: String

    public init(
        setLabel: String,
        setLabelShort: String,
        pauseRunning: String,
        pauseOver: String,
        personalRecordTitle: String,
        viewInTrophyRoom: String
    ) {
        self.setLabel = setLabel
        self.setLabelShort = setLabelShort
        self.pauseRunning = pauseRunning
        self.pauseOver = pauseOver
        self.personalRecordTitle = personalRecordTitle
        self.viewInTrophyRoom = viewInTrophyRoom
    }

    /// Defensive Fallback fuer den (praktisch nie erreichten) Fall, dass ein
    /// finaler ContentState gebaut wird, ohne dass eine vorige Activity mit
    /// echten uebersetzten Texten existierte. Englisch, da hart kodiert statt
    /// aus dem App-Katalog gelesen.
    public static let empty = RestTimerLiveTexts(
        setLabel: "Set", setLabelShort: "Set",
        pauseRunning: "REST", pauseOver: "REST OVER",
        personalRecordTitle: "Personal Record!", viewInTrophyRoom: "View in Trophy Room"
    )
}
