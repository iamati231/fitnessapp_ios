#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Bridges the value-type `PRDetector` (Core) to the persistent
/// `PersonalRecordEntry` table. Two flavors:
///
///   - **`recordPRs(for:in:)`** — incremental, called from
///     `ActiveWorkoutView.finishWorkout()`. Detects PRs for a single just-
///     completed session against all earlier completed sessions and inserts
///     `PersonalRecordEntry` rows.
///
///   - **`rebuild(in:)`** — destructive, manual one-shot. Wipes all existing
///     `PersonalRecordEntry` rows and walks every completed session in
///     chronological order, re-running detection. Powers the "Aus History
///     neu berechnen" toolbar button in `PRHistoryView` and the implicit
///     first-time backfill (Trophy Room is empty + history isn't).
///
/// Both helpers DO NOT call `save()` — the caller's modelContext save policy
/// (autosave or explicit) decides when changes hit disk.
public enum PersonalRecordSync {

    /// Sentinel fuer die `exerciseTemplateIDSnapshot`-Vorfilterung in
    /// `fetchHistoricalLifts`: ein Platzhalter, den kein echtes
    /// `Exercise.exerciseTemplateID` je annimmt. Macht aus
    /// `optionalField == capturedValue` ein reines `??`-dann-Gleichheits-
    /// Predicate (`(field ?? sentinel) == id`) — bewusst KEIN direkter
    /// Optional-zu-Nicht-Optional-Vergleich und KEIN Force-Unwrap innerhalb
    /// eines `#Predicate` (beides in diesem Modul bislang ungetestet).
    private static let nilTemplateIDSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    // MARK: - Incremental (forward-save from finishWorkout)

    /// Detects PRs for `session` against all OTHER completed sessions in the
    /// store and inserts a `PersonalRecordEntry` per detected record. No-op if
    /// the session isn't yet marked completed (defensive — caller controls
    /// ordering, but a misuse here would silently produce nothing).
    ///
    /// History is fetched via `FetchDescriptor` so this works without a
    /// `@Query` host view (we're called from `finishWorkout`, not a body).
    ///
    /// Returns the detected PRs as value-types so callers can drive UI
    /// celebrations (notifications, live-activity headlines) without re-fetching.
    @discardableResult
    public static func recordPRs(
        for session: WorkoutSession,
        in context: ModelContext
    ) -> [PersonalRecord] {
        guard session.isCompleted else { return [] }

        let sessionLifts = liftAttempts(from: session.logs)
        let history = fetchHistoricalLifts(for: sessionLifts, excluding: session, in: context)

        let prs = PRDetector.detectPRs(sessionLifts: sessionLifts, history: history)
        for record in prs {
            let entry = PersonalRecordEntry(record: record, session: session)
            context.insert(entry)
        }
        return prs
    }

    // MARK: - Zeitformate (README 2.9: AMRAP/EMOM/Auf Zeit)

    /// Analog zu `recordPRs(for:in:)`, aber fuer den Session-weiten
    /// AMRAP/Auf-Zeit-Ergebnispfad statt Set-basierter `ExerciseLog`s.
    /// Kein-op fuer EMOM-Sessions (kein PR-Kind, siehe `PRDetector`) oder
    /// wenn `session.timeFormatSnapshot == nil` (normale Krafteinheit).
    @discardableResult
    public static func recordTimedFormatPR(
        for session: WorkoutSession,
        in context: ModelContext
    ) -> PersonalRecord? {
        guard session.isCompleted,
              let format = session.timeFormatSnapshot,
              let wodName = session.dayName
        else { return nil }

        let attempt = TimedWorkoutAttempt(
            wodName: wodName,
            format: format,
            date: session.startTime,
            roundsCompleted: session.roundsCompleted,
            partialReps: session.partialReps,
            finishTimeSeconds: session.finishTimeSeconds,
            completedTarget: session.completedTarget
        )
        let history = fetchHistoricalTimedAttempts(excluding: session, in: context)

        guard let record = PRDetector.detectTimedFormatPR(session: attempt, history: history) else {
            return nil
        }
        context.insert(PersonalRecordEntry(record: record, session: session))
        return record
    }

    /// Pullt alle ANDEREN abgeschlossenen Sessions mit einem Zeitformat-
    /// Ergebnis. Breiter Fetch + In-Memory-Filter (gleiches Muster wie
    /// `fetchHistoricalLifts`) statt eines `#Predicate` auf dem optionalen
    /// Enum-Feld — SwiftData-Predicates auf optionalen Codable-RawValue-
    /// Enums sind unzuverlaessig.
    private static func fetchHistoricalTimedAttempts(
        excluding session: WorkoutSession,
        in context: ModelContext
    ) -> [TimedWorkoutAttempt] {
        let thisID = session.persistentModelID
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.compactMap { other -> TimedWorkoutAttempt? in
            guard other.persistentModelID != thisID,
                  let format = other.timeFormatSnapshot,
                  let wodName = other.dayName
            else { return nil }
            return TimedWorkoutAttempt(
                wodName: wodName,
                format: format,
                date: other.startTime,
                roundsCompleted: other.roundsCompleted,
                partialReps: other.partialReps,
                finishTimeSeconds: other.finishTimeSeconds,
                completedTarget: other.completedTarget
            )
        }
    }

    // MARK: - Full rebuild (Trophy-Room manual button + first-run backfill)

    /// Wipes every `PersonalRecordEntry` in the store and re-detects PRs for
    /// every completed session in chronological order. Each session sees only
    /// the sessions BEFORE it as history, matching the live save-hook semantics.
    ///
    /// Use this for:
    ///   - First-launch backfill when the user already has completed sessions
    ///     from before this feature shipped.
    ///   - Manual "neu berechnen" after the user deleted/edited sessions.
    ///
    /// Returns the number of PR rows produced (useful for a confirmation toast).
    @discardableResult
    public static func rebuild(in context: ModelContext) -> Int {
        // 1) Wipe existing PRE rows.
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecordEntry>())) ?? []
        for row in existing { context.delete(row) }

        // 2) Pull every REAL completed session (no rest-day-markers), oldest-first.
        var sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        sessionDescriptor.relationshipKeyPathsForPrefetching = [\.logs]
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        // 3) Walk chronologically, accumulating history-as-we-go.
        var historyLifts: [LiftAttempt] = []
        // Bugfix (Audit): Zeitformat-Sessions (AMRAP/EMOM/Auf Zeit) schreiben
        // nie `ExerciseLog`s, `sessionLifts` ist fuer sie also immer leer -
        // ohne diesen zweiten Akkumulator erkannte ein Rebuild ihre PRs nie
        // erneut, waehrend Schritt 1) oben alle bestehenden Zeilen (auch die
        // bereits korrekt erkannten WOD-Bestleistungen) zuerst geloescht hat.
        // "Aus History neu berechnen" hat also jede WOD-PR unwiderruflich
        // vernichtet. Paralleler Erkennungspfad, analog zu
        // `recordTimedFormatPR`/`fetchHistoricalTimedAttempts` oben.
        var historyTimedAttempts: [TimedWorkoutAttempt] = []
        var inserted = 0

        for session in sessions {
            let sessionLifts = liftAttempts(from: session.logs)
            let prs = PRDetector.detectPRs(sessionLifts: sessionLifts, history: historyLifts)
            for record in prs {
                let entry = PersonalRecordEntry(record: record, session: session)
                context.insert(entry)
                inserted += 1
            }
            // Append AFTER detection — the current session shouldn't be its
            // own history (matches the strict-greater-than contract).
            historyLifts.append(contentsOf: sessionLifts)

            if let format = session.timeFormatSnapshot, let wodName = session.dayName {
                let attempt = TimedWorkoutAttempt(
                    wodName: wodName,
                    format: format,
                    date: session.startTime,
                    roundsCompleted: session.roundsCompleted,
                    partialReps: session.partialReps,
                    finishTimeSeconds: session.finishTimeSeconds,
                    completedTarget: session.completedTarget
                )
                if let record = PRDetector.detectTimedFormatPR(session: attempt, history: historyTimedAttempts) {
                    context.insert(PersonalRecordEntry(record: record, session: session))
                    inserted += 1
                }
                historyTimedAttempts.append(attempt)
            }
        }
        return inserted
    }

    // MARK: - Internals

    /// DEL-051: Maps `ExerciseLog` to `LiftAttempt`, snapshot-first. Logs
    /// ohne Snapshot UND ohne Live-Exercise (sehr alte Orphans) werden
    /// uebersprungen, sonst nutzen wir entweder den persistierten Snapshot
    /// oder fallbacken auf die noch-lebende Exercise-Referenz.
    private static func liftAttempts(from logs: [ExerciseLog]) -> [LiftAttempt] {
        logs.compactMap { log -> LiftAttempt? in
            guard let name = log.resolvedExerciseName else { return nil }
            return LiftAttempt(
                exerciseName: name,
                // Settings-Epic Phase 6 (EXLIB-07/09): stabile ID durchreichen,
                // damit PRDetector ueber Umbenennen hinweg korrekt gruppiert.
                exerciseTemplateID: log.resolvedExerciseTemplateID,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: log.resolvedIsCardio,
                isTimeBased: log.resolvedIsTimeBased,
                // DEL-064: Cardio-Felder mit-mappen, sodass der PRDetector
                // distance/pace-PRs detecten kann.
                distanceKm: log.distanceKm,
                durationSeconds: log.durationSeconds,
                // DEL-156: Equipment fuer die PR-Gruppierung pro Modalitaet.
                cardioEquipment: log.resolvedCardioEquipment
            )
        }
    }

    /// DEL-051: Pulls every log from completed sessions BEFORE `session`.
    /// Wichtig: vorher hatte ein `.cascade`-Delete der Plan-Uebung den
    /// `log.exercise`-Pointer mit-genommen → Historie verschwand aus PR-
    /// Detection. Jetzt nutzen wir die Snapshot-Felder, sodass auch
    /// orphan-Logs (Plan-Uebung geloescht) als historische Lifts in die
    /// PR-Berechnung eingehen.
    ///
    /// Bugfix (Audit): filterte vorher nur die ID der aktuellen Session raus,
    /// nicht das Datum — jede andere abgeschlossene Session zaehlte als
    /// "Historie", auch eine mit SPAETEREM `startTime` (z.B. nachtraeglich
    /// rueckdatierter Workout-Log). `rebuild(in:)` lief chronologisch und sah
    /// pro Session nur Lifts STRIKT DAVOR — bei rueckdatierten Sessions
    /// konnten die beiden Pfade dadurch unterschiedliche PRs erkennen. Der
    /// `startTime`-Vergleich macht `recordPRs` und `rebuild` deckungsgleich.
    ///
    /// Perf (Audit): fetchte vorher JEDEN `ExerciseLog` im Store — bei
    /// mehrjaehriger Nutzung zehntausende Zeilen bei JEDEM `finishWorkout()`,
    /// obwohl `PRDetector.detectPRs` History-Eintraege ohnehin sofort wieder
    /// per `GroupKey` (Identitaet) wegfiltert: ein Log, dessen Identitaet in
    /// keinem `sessionLifts`-Eintrag vorkommt, wird dort NIE gelesen (siehe
    /// `history.filter { GroupKey($0) == key }` in PRDetector.swift). Diese
    /// Vorfilterung liefert deshalb nachweislich dieselben PRs, nur ohne den
    /// Rest der Historie erst zu laden.
    ///
    /// Bewusst KEIN `#Predicate` mit Set-`contains`/Force-Unwrap (in diesem
    /// Modul bislang nirgends verwendet, SwiftData-Predicates auf optionalen
    /// Feldern sind laut bestehenden Kommentaren hier unzuverlaessig) —
    /// stattdessen pro relevanter Identitaet ein einzelner, einfacher
    /// Gleichheits-Fetch (`== name` / `== id`), exakt das bereits an anderer
    /// Stelle (`ExternalWorkoutImportService`, `ExerciseEditorView`)
    /// verwendete Predicate-Muster. Zusaetzlich ein Fetch fuer
    /// `exerciseNameSnapshot == nil` als Sicherheitsnetz fuer Alt-Logs von
    /// vor diesem Snapshot-Feld, deren Identitaet sich nicht vorab anhand
    /// des gespeicherten Felds bestimmen laesst (sie werden wie zuvor
    /// ungefiltert durchgereicht). Ergebnis wird am Ende nach Datum
    /// sortiert, um die vorherige Reihenfolge exakt zu erhalten.
    private static func fetchHistoricalLifts(
        for sessionLifts: [LiftAttempt],
        excluding session: WorkoutSession,
        in context: ModelContext
    ) -> [LiftAttempt] {
        guard !sessionLifts.isEmpty else { return [] }
        let sessionStart = session.startTime

        let relevantNames = Set(sessionLifts.map(\.exerciseName))
        let relevantTemplateIDs = Set(sessionLifts.compactMap(\.exerciseTemplateID))

        var seenIDs = Set<PersistentIdentifier>()
        var logs: [ExerciseLog] = []
        func appendUnique(_ fetched: [ExerciseLog]) {
            for log in fetched where seenIDs.insert(log.persistentModelID).inserted {
                logs.append(log)
            }
        }

        for name in relevantNames {
            let descriptor = FetchDescriptor<ExerciseLog>(
                predicate: #Predicate<ExerciseLog> { ($0.exerciseNameSnapshot ?? "") == name }
            )
            appendUnique((try? context.fetch(descriptor)) ?? [])
        }
        for id in relevantTemplateIDs {
            let sentinel = Self.nilTemplateIDSentinel
            let descriptor = FetchDescriptor<ExerciseLog>(
                predicate: #Predicate<ExerciseLog> { ($0.exerciseTemplateIDSnapshot ?? sentinel) == id }
            )
            appendUnique((try? context.fetch(descriptor)) ?? [])
        }
        let legacyDescriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { $0.exerciseNameSnapshot == nil }
        )
        appendUnique((try? context.fetch(legacyDescriptor)) ?? [])

        return logs
            .sorted { $0.date < $1.date }
            .compactMap { log -> LiftAttempt? in
                guard let name = log.resolvedExerciseName,
                      let logSession = log.session,
                      logSession.isCompleted,
                      logSession.startTime < sessionStart
                else { return nil }
                return LiftAttempt(
                    exerciseName: name,
                    exerciseTemplateID: log.resolvedExerciseTemplateID,
                    weightKg: log.weight,
                    reps: log.reps,
                    date: log.date,
                    isCardio: log.resolvedIsCardio,
                    isTimeBased: log.resolvedIsTimeBased,
                    distanceKm: log.distanceKm,
                    durationSeconds: log.durationSeconds,
                    // DEL-156: Equipment fuer die PR-Gruppierung pro Modalitaet.
                    cardioEquipment: log.resolvedCardioEquipment
                )
            }
    }
}
#endif
