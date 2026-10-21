import Foundation

/// Sprachneutraler Inhalt der Live Activity (Sperrbildschirm, Dynamic Island)
/// eines laufenden Zeitformats: AMRAP, EMOM, Auf Zeit oder Zirkel.
///
/// Eine Live Activity bekommt keine Sekunden-Updates. Was sich pro Sekunde
/// aendert, zaehlt das System selbst (`Text(timerInterval:)`, `Text(_, style:
/// .timer)`) - dafuer braucht es nur feste Anker. Alles andere (aktuelle Minute,
/// Runde, Pause) schickt die App bei jedem Zustandswechsel als neuen Inhalt.
/// Diese Struktur haelt deshalb nur Anker und Zaehler, nie eine laufende
/// Sekundenzahl: Zwei Berechnungen aus demselben Zustand sind gleich (`==`), und
/// nur ein echter Zustandswechsel loest ein Update aus.
///
/// Texte stehen hier nicht drin: Der Widget-Prozess hat keinen String-Katalog,
/// die App schickt die fertig uebersetzten Texte separat mit
/// (`TimedWorkoutLiveTexts` in `FitnessAppActivities`).
///
/// Die Rechnung folgt den Playern (`TimedWorkoutPlayerView`,
/// `CircuitPlayerView`) Zeile fuer Zeile: Wanduhr statt Tick-Zaehler, ganze
/// Sekunden ABGERUNDET, der Anker ist `session.startTime` NACH dem Vorlauf.
public struct TimedLiveContent: Codable, Hashable, Sendable {

    /// Ab wann ein Inhalt als veraltet gilt, wenn das erwartete Update ausbleibt
    /// (App im Hintergrund beendet, Hintergrund-Audio aus): Wanduhr-Ende plus diese
    /// Toleranz. Ein gesundes Update kommt innerhalb einer Sekunde nach dem Ende -
    /// ohne die Toleranz blitzte beim Minutenwechsel kurz die veraltete Ansicht auf.
    public static let staleMargin: TimeInterval = 4

    public enum Phase: String, Codable, Hashable, Sendable {
        /// Die Uhr laeuft, es wird trainiert.
        case running
        /// Nur Zirkel: gezeitete Pause zwischen zwei Runden.
        case rest
        /// Zeit abgelaufen bzw. Pensum geschafft - die Uhr steht.
        case finished
    }

    /// Welche Uhr das System zeichnet. Nur Anker, nie ein Zwischenstand.
    public enum Clock: Codable, Hashable, Sendable {
        /// Zaehlt von `start` bis `end` runter (der Anfang bleibt fest, damit ein
        /// Fortschrittsbalken die echte Position zeigt).
        case countdown(start: Date, end: Date)
        /// Zaehlt ab `since` hoch.
        case countUp(since: Date)
        /// Steht still und zeigt diese Sekunden an.
        case frozen(seconds: Int)

        /// Die Zeitspanne eines Countdowns - IMMER gueltig: `ClosedRange` bricht ab,
        /// wenn die untere Grenze ueber der oberen liegt, und im Widget-Prozess
        /// waere das ein Absturz statt eines Schoenheitsfehlers.
        public var countdownRange: ClosedRange<Date>? {
            guard case let .countdown(start, end) = self else { return nil }
            return start...max(start, end)
        }
    }

    public let phase: Phase
    /// Die grosse Uhr.
    public let clock: Clock
    /// Anker des ganzen Laufs (`session.startTime` nach dem Vorlauf).
    public let runStart: Date
    /// Ende des ganzen Laufs, wenn das Format eines hat (AMRAP, EMOM, Auf Zeit mit
    /// Deckel). Das System zaehlt diese Zeitspanne auch ohne jedes Update richtig
    /// weiter - die Rueckfall-Anzeige, wenn der Inhalt veraltet ist.
    public let runEnd: Date?
    /// AMRAP: geschaffte Runden. EMOM: laufende Minute. Auf Zeit: abgehakte
    /// Kaesten. Zirkel: laufende (Arbeit) bzw. zuletzt beendete Runde (Pause).
    public let counter: Int
    /// Gegenstueck zu `counter`: Minuten, Kaesten oder Runden insgesamt. `nil`, wo
    /// es kein festes Ende gibt (AMRAP).
    public let counterTotal: Int?
    /// EMOM: die Uebung der laufenden Minute.
    public let currentExercise: String?
    /// EMOM: die Uebung der naechsten Minute (`nil` in der letzten).
    public let nextExercise: String?
    /// Siehe `staleMargin`. `nil`: der Inhalt veraltet nie von selbst.
    public let staleDate: Date?

    public init(
        phase: Phase,
        clock: Clock,
        runStart: Date,
        runEnd: Date? = nil,
        counter: Int,
        counterTotal: Int? = nil,
        currentExercise: String? = nil,
        nextExercise: String? = nil,
        staleDate: Date? = nil
    ) {
        self.phase = phase
        self.clock = clock
        self.runStart = runStart
        self.runEnd = runEnd
        self.counter = counter
        self.counterTotal = counterTotal
        self.currentExercise = currentExercise
        self.nextExercise = nextExercise
        self.staleDate = staleDate
    }

    /// Die ganze Laufzeit als Zeitspanne (siehe `runEnd`), immer gueltig.
    public var overallRange: ClosedRange<Date>? {
        guard let runEnd else { return nil }
        return runStart...max(runStart, runEnd)
    }

    /// "m:ss" bzw. "h:mm:ss" fuer eine stehende Uhr. Anders als
    /// `PaceCalculator.formatDuration` (null = "—", ein FEHLENDER Wert) zeigt die
    /// Null hier "0:00": Eine abgelaufene Uhr ist ein echter Wert. Sekunden werden
    /// nie gerundet, sondern abgeschnitten (negativ gilt als null).
    public static func clockText(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%d:%02d", minutes, rest)
    }

    // MARK: - AMRAP

    /// Countdown ueber den ganzen Deckel, dazu die geschafften Runden.
    public static func amrap(
        anchor: Date,
        capSeconds: Int,
        roundsCompleted: Int,
        now: Date
    ) -> TimedLiveContent {
        let end = anchor.addingTimeInterval(TimeInterval(max(1, capSeconds)))
        let rounds = max(0, roundsCompleted)
        guard now < end else {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: 0),
                runStart: anchor,
                runEnd: end,
                counter: rounds
            )
        }
        return TimedLiveContent(
            phase: .running,
            clock: .countdown(start: anchor, end: end),
            runStart: anchor,
            runEnd: end,
            counter: rounds,
            staleDate: end.addingTimeInterval(staleMargin)
        )
    }

    // MARK: - EMOM

    /// Countdown der LAUFENDEN Minute mit deren Uebung und der naechsten. Bei mehr
    /// Minuten als Uebungen wiederholt sich der Zirkel (wie im Player).
    public static func emom(
        anchor: Date,
        totalMinutes: Int,
        exerciseNames: [String],
        now: Date
    ) -> TimedLiveContent {
        let total = max(1, totalMinutes)
        let end = anchor.addingTimeInterval(TimeInterval(total * 60))
        guard now < end else {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: 0),
                runStart: anchor,
                runEnd: end,
                counter: total,
                counterTotal: total
            )
        }
        let elapsed = max(0, Int(now.timeIntervalSince(anchor)))
        let minute = min(elapsed / 60 + 1, total)
        let minuteStart = anchor.addingTimeInterval(TimeInterval((minute - 1) * 60))
        let minuteEnd = anchor.addingTimeInterval(TimeInterval(minute * 60))
        let current = exerciseNames.isEmpty ? nil : exerciseNames[(minute - 1) % exerciseNames.count]
        let next = (exerciseNames.isEmpty || minute >= total) ? nil : exerciseNames[minute % exerciseNames.count]
        return TimedLiveContent(
            phase: .running,
            clock: .countdown(start: minuteStart, end: minuteEnd),
            runStart: anchor,
            runEnd: end,
            counter: minute,
            counterTotal: total,
            currentExercise: current,
            nextExercise: next,
            staleDate: minuteEnd.addingTimeInterval(staleMargin)
        )
    }

    // MARK: - Auf Zeit

    /// Hochzaehlende Uhr (wie die Hero-Zahl im Player), dazu die abgehakten
    /// Kaesten. `finishedElapsedSeconds` ist der eingefrorene Stand des Players
    /// (alle Kaesten abgehakt oder Deckel erreicht) - `nil`, solange der Lauf noch
    /// laeuft. Ein optionaler Deckel setzt das Ende des Laufs.
    public static func forTime(
        anchor: Date,
        capSeconds: Int?,
        checkedBoxes: Int,
        totalBoxes: Int,
        finishedElapsedSeconds: Int?,
        now: Date
    ) -> TimedLiveContent {
        let cap = capSeconds.map { max(1, $0) }
        let end = cap.map { anchor.addingTimeInterval(TimeInterval($0)) }
        let checked = max(0, checkedBoxes)
        let total = max(0, totalBoxes)
        if let finishedElapsedSeconds {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: max(0, finishedElapsedSeconds)),
                runStart: anchor,
                runEnd: end,
                counter: checked,
                counterTotal: total
            )
        }
        if let cap, let end, now >= end {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: cap),
                runStart: anchor,
                runEnd: end,
                counter: checked,
                counterTotal: total
            )
        }
        return TimedLiveContent(
            phase: .running,
            clock: .countUp(since: anchor),
            runStart: anchor,
            runEnd: end,
            counter: checked,
            counterTotal: total,
            staleDate: end.map { $0.addingTimeInterval(staleMargin) }
        )
    }

    // MARK: - Zirkel

    /// Pause: Countdown bis `restEnd`. Arbeit: die Gesamtzeit hochzaehlend (der
    /// Player zeigt waehrend der Arbeit keine Uhr - auf dem Sperrbildschirm ist
    /// die Trainingszeit die nuetzliche Zahl). `restEnd` in der Vergangenheit
    /// zaehlt als Arbeit: der Tick des Players beendet die Pause in derselben
    /// Sekunde.
    public static func circuit(
        anchor: Date,
        restEnd: Date?,
        restSeconds: Int,
        roundsCompleted: Int,
        totalRounds: Int,
        isFinished: Bool,
        now: Date
    ) -> TimedLiveContent {
        let total = max(1, totalRounds)
        let rounds = max(0, roundsCompleted)
        if isFinished {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: max(0, Int(now.timeIntervalSince(anchor)))),
                runStart: anchor,
                counter: min(rounds, total),
                counterTotal: total
            )
        }
        if let restEnd, restEnd > now {
            let length = TimeInterval(max(1, restSeconds))
            return TimedLiveContent(
                phase: .rest,
                clock: .countdown(start: restEnd.addingTimeInterval(-length), end: restEnd),
                runStart: anchor,
                counter: min(rounds, total),
                counterTotal: total,
                staleDate: restEnd.addingTimeInterval(staleMargin)
            )
        }
        return TimedLiveContent(
            phase: .running,
            clock: .countUp(since: anchor),
            runStart: anchor,
            counter: min(rounds + 1, total),
            counterTotal: total
        )
    }

    // MARK: - Ausdauer-Intervalle (Paket 2)

    /// Einlaufen/Erholung/Auslaufen und eine GEZEITETE Belastung zeigen
    /// einen Countdown; eine UNGEZEITETE Belastung (Strecke/offen) zaehlt
    /// die GESAMTE Laufzeit hoch (`anchor` = `session.startTime`, nicht der
    /// Rundenstart) - gleiches Prinzip wie die Zirkel-Arbeitsphase oben
    /// ("der Player zeigt waehrend der Arbeit keine Uhr - auf dem
    /// Sperrbildschirm ist die Trainingszeit die nuetzliche Zahl"). Eine
    /// manuelle Pause friert die Anzeige auf den verbleibenden Sekunden ein,
    /// statt stillschweigend weiterzuzaehlen.
    public static func enduranceIntervals(
        anchor: Date,
        currentPhase: EnduranceIntervalPhase,
        phaseEndDate: Date?,
        pausedRemainingSeconds: Int?,
        phaseDurationSeconds: Int,
        roundNumber: Int,
        totalRounds: Int,
        isFinished: Bool,
        now: Date
    ) -> TimedLiveContent {
        let total = max(1, totalRounds)
        let round = min(max(1, roundNumber), total)
        let livePhase: Phase = currentPhase == .rest ? .rest : .running
        if isFinished {
            return TimedLiveContent(
                phase: .finished,
                clock: .frozen(seconds: max(0, Int(now.timeIntervalSince(anchor)))),
                runStart: anchor,
                counter: round,
                counterTotal: total
            )
        }
        if let pausedRemainingSeconds {
            return TimedLiveContent(
                phase: livePhase,
                clock: .frozen(seconds: max(0, pausedRemainingSeconds)),
                runStart: anchor,
                counter: round,
                counterTotal: total
            )
        }
        if let phaseEndDate {
            let length = TimeInterval(max(1, phaseDurationSeconds))
            return TimedLiveContent(
                phase: livePhase,
                clock: .countdown(start: phaseEndDate.addingTimeInterval(-length), end: phaseEndDate),
                runStart: anchor,
                runEnd: phaseEndDate,
                counter: round,
                counterTotal: total,
                staleDate: phaseEndDate.addingTimeInterval(staleMargin)
            )
        }
        return TimedLiveContent(
            phase: .running,
            clock: .countUp(since: anchor),
            runStart: anchor,
            counter: round,
            counterTotal: total
        )
    }
}

// MARK: - Hintergrund-Audio

extension TimedLiveContent {

    /// Ob in dieser Lage ein HOERBARES Signal faellig werden kann, waehrend der
    /// Bildschirm gesperrt ist - nur dann braucht die App ihr stilles
    /// Hintergrund-Audio (`BackgroundAudioKeepAlive`, App Review 2.5.4: Audio im
    /// Hintergrund nur fuer hoerbare Signale, und Akku schonen).
    ///
    ///   * AMRAP, EMOM und Auf Zeit mit Limit haben ein Ende, das ein Ton
    ///     ankuendigt (EMOM zusaetzlich jede Minute) -> ja, solange sie laufen.
    ///   * Die Zirkel-Pause hat ihre Piepser und den Endton -> ja.
    ///   * Auf Zeit ohne Limit und die Zirkel-Arbeitsphase signalisieren nichts von
    ///     selbst: Es geht nur durch Eingaben in der App weiter, die Uhr der Live
    ///     Activity zaehlt das System -> nein.
    ///   * Nach dem Ende gibt es nichts mehr zu signalisieren -> nein.
    public var needsAudioInBackground: Bool {
        switch phase {
        case .rest:     return true
        case .running:  return runEnd != nil
        case .finished: return false
        }
    }
}
