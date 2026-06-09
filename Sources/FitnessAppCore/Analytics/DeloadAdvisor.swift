// DEL-196: Auto-Deload-Empfehlung.
//
// Kombiniert zwei Signale, die das DEL-098/099-Scoring bereits liefert:
//   1. **Steigende Wochen-Last** — die summierte CNS-Load der letzten drei
//      Kalenderwochen steigt monoton UND um mindestens 20% von Woche 1 zu
//      Woche 3. Ein einzelner harter Tag triggert also nichts; es braucht
//      einen echten Aufwärts-Trend.
//   2. **Subjektive Erschöpfung** — mindestens zwei Sessions in den letzten
//      14 Tagen mit `sessionFeeling >= 4` ("Sehr schwer" / "Zerstört",
//      DEL-057-Skala).
//
// Beides zusammen = klassisches Overreaching-Muster → Deload empfehlen.
// Nur EIN Signal allein reicht nicht: steigende Last bei gutem Gefühl ist
// gewollte Progression; schlechtes Gefühl ohne Last-Trend ist eher Schlaf/
// Stress/Krankheit — dafür gibt es andere Coaching-Hinweise.
//
// Pure function — Dashboard aggregiert die Wochen-Loads aus den Sessions
// und ruft hier nur noch die Entscheidung ab.

import Foundation

public enum DeloadAdvisor {

    /// Mindest-Anstieg von der ältesten zur jüngsten Woche (Faktor).
    /// 1.2 = +20% — darunter ist es normales Wochen-Rauschen.
    public static let minimumRampFactor: Double = 1.2

    /// Wieviele harte Sessions (Feeling >= 4) in den letzten 14 Tagen
    /// mindestens nötig sind.
    public static let minimumHardSessions: Int = 2

    /// Session-Feeling-Schwelle, ab der eine Session als "hart" zählt
    /// (DEL-057-Skala: 4 = Sehr schwer, 5 = Zerstört).
    public static let hardFeelingThreshold: Int = 4

    /// Entscheidet, ob eine Deload-Woche empfohlen werden soll.
    ///
    /// - Parameter weeklyLoads: Summierte Trainings-Last (z.B. CNS-Load)
    ///   pro Kalenderwoche, älteste zuerst. Es werden die letzten drei
    ///   Einträge betrachtet; weniger als drei → nie eine Empfehlung
    ///   (Stichprobe zu klein).
    /// - Parameter hardSessionCount: Anzahl Sessions mit Feeling >=
    ///   `hardFeelingThreshold` in den letzten 14 Tagen.
    public static func shouldRecommendDeload(
        weeklyLoads: [Double],
        hardSessionCount: Int
    ) -> Bool {
        guard hardSessionCount >= minimumHardSessions else { return false }
        let recent = Array(weeklyLoads.suffix(3))
        guard recent.count == 3 else { return false }
        let (w1, w2, w3) = (recent[0], recent[1], recent[2])
        // Monoton steigend — strikt, damit eine flache Woche den Trend bricht.
        guard w3 > w2, w2 > w1 else { return false }
        // Null-Last-Schutz: ohne Basis-Woche keine Ratio-Aussage.
        guard w1 > 0 else { return false }
        return w3 >= w1 * minimumRampFactor
    }
}
