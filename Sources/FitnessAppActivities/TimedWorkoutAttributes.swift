#if os(iOS)
import Foundation
import ActivityKit
import FitnessAppCore

/// Live Activity fuer einen laufenden Zeitformat-Lauf (AMRAP, EMOM, Auf Zeit,
/// Zirkel) - Sperrbildschirm und Dynamic Island, waehrend die App im Hintergrund
/// arbeitet. Das Widget-Extension-Target rendert diesen Typ ueber
/// `ActivityConfiguration(for:)`, siehe `TimedWorkoutLiveActivity`.
///
/// Was sich pro Sekunde aendert, zaehlt das System selbst (Anker in
/// `TimedLiveContent`); die App schickt nur bei Zustandswechseln ein Update.
public struct TimedWorkoutAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// Uhr, Phase und Zaehler (sprachneutral, Logik in Core).
        public let content: TimedLiveContent
        /// Die dazu passenden, schon uebersetzten Texte.
        public let texts: TimedWorkoutLiveTexts

        public init(content: TimedLiveContent, texts: TimedWorkoutLiveTexts) {
            self.content = content
            self.texts = texts
        }
    }

    /// Wiedererkennung desselben Laufs ueber ein neues View hinweg ("Training
    /// fortsetzen" baut den Player neu auf) - dann wird die vorhandene Activity
    /// aktualisiert statt eine zweite anzulegen.
    public let sessionKey: String
    public let format: WorkoutTimeFormat
    /// Anzeigename des Formats in der Sprache der App ("AMRAP", "Auf Zeit", ...).
    public let formatName: String
    public let dayName: String

    public init(sessionKey: String, format: WorkoutTimeFormat, formatName: String, dayName: String) {
        self.sessionKey = sessionKey
        self.format = format
        self.formatName = formatName
        self.dayName = dayName
    }
}
#endif
