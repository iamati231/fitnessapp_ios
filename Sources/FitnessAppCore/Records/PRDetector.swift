import Foundation

/// Detects personal records inside a workout session against historical attempts.
///
/// **Algorithm contract:**
///   1. Strict greater-than only — ties don't count as PRs (avoids spamming on
///      consistent lifters who hit the same numbers session after session).
///   2. At most one PR per (exercise, kind) per session — the BEST attempt
///      is the one credited (e.g., three new heaviest sets in a row → one PR).
///   3. **Per-exercise categorization** — each exercise is classified once based
///      on the union of session + history attempts:
///        - `.timeBased` if ANY attempt has `isTimeBased == true`
///        - `.cardio` (DEL-064) if ANY attempt has `isCardio == true`
///        - `.weighted` if ANY attempt has `weightKg > 0`
///        - `.bodyweight` if all attempts have `weightKg == 0` and reps > 0
///      Cardio takes precedence over weighted so a weighted-vest run still uses
///      cardio PRs (distance/pace), not weight-based ones.
///   4. An exercise with no historical attempts in `history` produces no PRs
///      (first session establishes a baseline; you can't beat nothing).
public enum PRDetector {

    /// DEL-064: Minimum-Distanz in km, ab der ein Pace-PR ueberhaupt
    /// betrachtet wird. Verhindert, dass ein 100m-Sprint mit absurder Pace
    /// die echte 5K-/10K-Pace eines Users uebersteuert.
    public static let minDistanceForPacePRKm: Double = 1.0

    /// Returns the personal records achieved by `sessionLifts` against `history`.
    /// Sorted by exercise name, then by display priority within an exercise.
    public static func detectPRs(
        sessionLifts: [LiftAttempt],
        history: [LiftAttempt]
    ) -> [PersonalRecord] {
        // DEL-156: Composite-Gruppierung nach (Identitaet, Cardio-Equipment).
        // Bei Strength/Bodyweight/TimeBased ist `cardioEquipment` immer
        // `.none`, sodass deren Gruppierung unveraendert "nur nach Identitaet"
        // bleibt. Bei Cardio splittet der Key Laufband- vs. Fahrrad- vs.
        // Rudergeraet-Versuche in eigene PR-Reihen.
        //
        // Settings-Epic Phase 6 (EXLIB-07/09): Identitaet ist bevorzugt die
        // stabile `exerciseTemplateID` (ueberlebt ein Umbenennen der
        // Uebung); nur Attempts ohne aufloesbare ID (Alt-Daten ohne
        // Backfill-Treffer) gruppieren weiterhin per Name wie bisher — das
        // ist reines Beibehalten des bestehenden Verhaltens fuer diese
        // Faelle, kein neues Rate-Verfahren.
        let bySessionExercise = Dictionary(grouping: sessionLifts, by: GroupKey.init)
        var records: [PersonalRecord] = []

        for (key, sessionAttempts) in bySessionExercise {
            // Jeder Attempt in diesem Bucket teilt per Konstruktion dieselbe
            // Identitaet (GroupKey.init) — der erste Attempt liefert also den
            // repraesentativen Namen/ID fuer die Ausgabe.
            let exerciseName = sessionAttempts.first?.exerciseName ?? ""
            let exerciseTemplateID = sessionAttempts.first?.exerciseTemplateID
            let exerciseHistory = history.filter { GroupKey($0) == key }
            guard !exerciseHistory.isEmpty else { continue }    // Need a baseline.

            // Categorize the exercise using session AND history together — a single
            // cardio attempt anywhere flips the category to cardio, so a user
            // adding distance-tracking to an existing strength exercise still
            // gets cardio PRs.
            let category = categorize(attempts: sessionAttempts + exerciseHistory)

            switch category {
            case .cardio:
                records.append(contentsOf: detectCardioPRs(
                    sessionAttempts: sessionAttempts,
                    exerciseHistory: exerciseHistory,
                    exerciseName: exerciseName,
                    exerciseTemplateID: exerciseTemplateID,
                    equipment: key.equipment
                ))

            case .weighted:
                records.append(contentsOf: detectWeightedPRs(
                    sessionAttempts: sessionAttempts,
                    exerciseHistory: exerciseHistory,
                    exerciseName: exerciseName,
                    exerciseTemplateID: exerciseTemplateID
                ))

            case .bodyweight:
                if let pr = maxRepsPR(
                    in: sessionAttempts,
                    history: exerciseHistory,
                    exerciseName: exerciseName,
                    exerciseTemplateID: exerciseTemplateID
                ) {
                    records.append(pr)
                }

            case .timeBased:
                if let pr = maxHoldSecondsPR(
                    in: sessionAttempts,
                    history: exerciseHistory,
                    exerciseName: exerciseName,
                    exerciseTemplateID: exerciseTemplateID
                ) {
                    records.append(pr)
                }

            case .invalid:
                continue
            }
        }

        return records.sorted { lhs, rhs in
            if lhs.exerciseName != rhs.exerciseName {
                return lhs.exerciseName < rhs.exerciseName
            }
            return kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }
    }

    // MARK: Grouping

    /// DEL-156 / Settings-Epic Phase 6 (EXLIB-07/09): Gruppierungs-Schluessel.
    /// Trennt Cardio-PRs nach Equipment; fuer Non-Cardio ist `equipment`
    /// stets `.none`. Identitaet ist ID-first: ein Attempt mit aufloesbarer
    /// `exerciseTemplateID` gruppiert darueber (ueberlebt Umbenennen), ein
    /// Attempt ohne ID gruppiert weiterhin per Name (unveraendertes
    /// Alt-Verhalten) — niemals beides gemischt, damit ein zufaelliger
    /// Namens-Treffer nie zwei verschiedene Uebungen zusammenlegt.
    private struct GroupKey: Hashable {
        enum Identity: Hashable {
            case id(UUID)
            case name(String)
        }
        let identity: Identity
        let equipment: CardioEquipment

        init(_ lift: LiftAttempt) {
            identity = lift.exerciseTemplateID.map(Identity.id) ?? .name(lift.exerciseName)
            equipment = lift.cardioEquipment
        }
    }

    // MARK: Categorization

    private enum ExerciseCategory {
        case cardio
        case weighted
        case bodyweight
        case timeBased
        case invalid
    }

    /// Order of priority: cardio → timeBased → weighted → bodyweight → invalid.
    /// Cardio takes precedence (DEL-064): wenn IRGENDEIN Versuch als Cardio
    /// markiert ist, behandeln wir die Uebung als Lauf-/Bike-PR-Kandidat.
    private static func categorize(attempts: [LiftAttempt]) -> ExerciseCategory {
        if attempts.isEmpty { return .invalid }
        if attempts.contains(where: { $0.isCardio }) { return .cardio }
        if attempts.contains(where: { $0.isTimeBased }) { return .timeBased }
        if attempts.contains(where: { $0.weightKg > 0 }) { return .weighted }
        if attempts.contains(where: { $0.reps > 0 }) { return .bodyweight }
        return .invalid
    }

    // MARK: - DEL-064 Cardio PRs

    /// Detektiert Cardio-PRs fuer eine Uebung. Zwei Kinds:
    ///   * `.longestDistance` — neue Best-Distance (km) im Session-Aggregat.
    ///   * `.fastestPace` — neue Best-Pace (min/km, lower = better). NUR
    ///     valide wenn `distanceKm >= minDistanceForPacePRKm` (Sprint-Guard).
    private static func detectCardioPRs(
        sessionAttempts: [LiftAttempt],
        exerciseHistory: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?,
        equipment: CardioEquipment
    ) -> [PersonalRecord] {
        // Cardio-Logs gruppieren per (Date-Day) zu Session-Aggregaten, falls
        // ein Lauf je theoretisch in mehrere Sets aufgeteilt waere. In der
        // Praxis ist Cardio bei uns 1 Set pro Session — but Aggregat ist die
        // mathematisch-saubere Variante.
        let sessionAgg = aggregateCardio(sessionAttempts)
        let historyAggs = Dictionary(grouping: exerciseHistory) {
            Calendar.current.startOfDay(for: $0.date)
        }.values.compactMap { aggregateCardio(Array($0)) }

        var records: [PersonalRecord] = []
        guard let now = sessionAgg, now.distanceKm > 0 else { return [] }

        // Longest-Distance PR
        let prevBestKm = historyAggs.map(\.distanceKm).max() ?? 0
        if now.distanceKm > prevBestKm {
            records.append(PersonalRecord(
                kind: .longestDistance,
                exerciseName: exerciseName,
                exerciseTemplateID: exerciseTemplateID,
                weightKg: 0,
                reps: 0,
                previousValue: prevBestKm,
                newValue: now.distanceKm,
                achievedAt: now.date,
                cardioEquipment: equipment
            ))
        }

        // Fastest-Pace PR — guarded gegen Sprint-Outlier.
        if now.distanceKm >= minDistanceForPacePRKm, let nowPace = now.paceMinPerKm {
            let qualifyingHistory = historyAggs.filter { $0.distanceKm >= minDistanceForPacePRKm }
            // niedrigere Pace = besser. Best = min.
            let prevBestPace = qualifyingHistory.compactMap(\.paceMinPerKm).min() ?? Double.infinity
            if nowPace < prevBestPace, prevBestPace.isFinite {
                records.append(PersonalRecord(
                    kind: .fastestPace,
                    exerciseName: exerciseName,
                    exerciseTemplateID: exerciseTemplateID,
                    weightKg: 0,
                    reps: 0,
                    previousValue: prevBestPace,
                    newValue: nowPace,
                    achievedAt: now.date,
                    cardioEquipment: equipment
                ))
            }
        }

        return records
    }

    /// Aggregat-Struct fuer Cardio-Session: Summe km + Summe Sekunden +
    /// daraus berechnete Pace.
    private struct CardioAggregate {
        let distanceKm: Double
        let durationSeconds: Int
        let date: Date
        var paceMinPerKm: Double? {
            guard distanceKm > 0, durationSeconds > 0 else { return nil }
            return Double(durationSeconds) / 60.0 / distanceKm
        }
    }

    private static func aggregateCardio(_ lifts: [LiftAttempt]) -> CardioAggregate? {
        let cardio = lifts.filter { $0.isCardio }
        guard !cardio.isEmpty else { return nil }
        let totalKm = cardio.compactMap(\.distanceKm).reduce(0.0, +)
        let totalSec = cardio.compactMap(\.durationSeconds).reduce(0, +)
        guard totalKm > 0 || totalSec > 0 else { return nil }
        let latest = cardio.map(\.date).max() ?? Date()
        return CardioAggregate(
            distanceKm: totalKm,
            durationSeconds: totalSec,
            date: latest
        )
    }

    // MARK: Weighted (3 kinds)

    private static func detectWeightedPRs(
        sessionAttempts: [LiftAttempt],
        exerciseHistory: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> [PersonalRecord] {
        let weighted = sessionAttempts.filter {
            $0.weightKg > 0 && $0.reps > 0 && !$0.isTimeBased
        }
        let weightedHistory = exerciseHistory.filter {
            $0.weightKg > 0 && $0.reps > 0 && !$0.isTimeBased
        }
        guard !weighted.isEmpty else { return [] }

        var records: [PersonalRecord] = []
        if let pr = heaviestWeightPR(in: weighted, history: weightedHistory, exerciseName: exerciseName, exerciseTemplateID: exerciseTemplateID) {
            records.append(pr)
        }
        if let pr = bestSetPR(in: weighted, history: weightedHistory, exerciseName: exerciseName, exerciseTemplateID: exerciseTemplateID) {
            records.append(pr)
        }
        if let pr = estimated1RMPR(in: weighted, history: weightedHistory, exerciseName: exerciseName, exerciseTemplateID: exerciseTemplateID) {
            records.append(pr)
        }
        return records
    }

    private static func heaviestWeightPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> PersonalRecord? {
        let prevBest = history.map(\.weightKg).max() ?? 0
        guard let bestNow = attempts.max(by: { $0.weightKg < $1.weightKg }) else { return nil }
        guard bestNow.weightKg > prevBest else { return nil }
        return PersonalRecord(
            kind: .heaviestWeight,
            exerciseName: exerciseName,
            exerciseTemplateID: exerciseTemplateID,
            weightKg: bestNow.weightKg,
            reps: bestNow.reps,
            previousValue: prevBest,
            newValue: bestNow.weightKg,
            achievedAt: bestNow.date
        )
    }

    private static func bestSetPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> PersonalRecord? {
        let prevBest = history.map(\.volume).max() ?? 0
        guard let bestNow = attempts.max(by: { $0.volume < $1.volume }) else { return nil }
        guard bestNow.volume > prevBest else { return nil }
        return PersonalRecord(
            kind: .bestSet,
            exerciseName: exerciseName,
            exerciseTemplateID: exerciseTemplateID,
            weightKg: bestNow.weightKg,
            reps: bestNow.reps,
            previousValue: prevBest,
            newValue: bestNow.volume,
            achievedAt: bestNow.date
        )
    }

    private static func estimated1RMPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> PersonalRecord? {
        let prevBest = history.compactMap(estimated1RM).max() ?? 0
        let nowCandidates = attempts.compactMap { lift -> (LiftAttempt, Double)? in
            guard let oneRM = estimated1RM(lift) else { return nil }
            return (lift, oneRM)
        }
        guard let bestNow = nowCandidates.max(by: { $0.1 < $1.1 }) else { return nil }
        guard bestNow.1 > prevBest else { return nil }
        return PersonalRecord(
            kind: .estimated1RM,
            exerciseName: exerciseName,
            exerciseTemplateID: exerciseTemplateID,
            weightKg: bestNow.0.weightKg,
            reps: bestNow.0.reps,
            previousValue: prevBest,
            newValue: bestNow.1,
            achievedAt: bestNow.0.date
        )
    }

    // MARK: Bodyweight (max-reps)

    private static func maxRepsPR(
        in sessionAttempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> PersonalRecord? {
        let valid = sessionAttempts.filter {
            $0.weightKg == 0 && $0.reps > 0 && !$0.isTimeBased
        }
        let validHistory = history.filter {
            $0.weightKg == 0 && $0.reps > 0 && !$0.isTimeBased
        }
        guard !valid.isEmpty, !validHistory.isEmpty else { return nil }

        let prevBestReps = validHistory.map(\.reps).max() ?? 0
        guard let bestNow = valid.max(by: { $0.reps < $1.reps }) else { return nil }
        guard bestNow.reps > prevBestReps else { return nil }
        return PersonalRecord(
            kind: .maxReps,
            exerciseName: exerciseName,
            exerciseTemplateID: exerciseTemplateID,
            weightKg: 0,
            reps: bestNow.reps,
            previousValue: Double(prevBestReps),
            newValue: Double(bestNow.reps),
            achievedAt: bestNow.date
        )
    }

    // MARK: Time-based (max-hold-seconds)

    private static func maxHoldSecondsPR(
        in sessionAttempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String,
        exerciseTemplateID: UUID?
    ) -> PersonalRecord? {
        // For time-based: `reps` carries seconds. Weight is ignored even if > 0.
        let valid = sessionAttempts.filter { $0.isTimeBased && $0.reps > 0 }
        let validHistory = history.filter { $0.isTimeBased && $0.reps > 0 }
        guard !valid.isEmpty, !validHistory.isEmpty else { return nil }

        let prevBestSeconds = validHistory.map(\.reps).max() ?? 0
        guard let bestNow = valid.max(by: { $0.reps < $1.reps }) else { return nil }
        guard bestNow.reps > prevBestSeconds else { return nil }
        return PersonalRecord(
            kind: .maxHoldSeconds,
            exerciseName: exerciseName,
            exerciseTemplateID: exerciseTemplateID,
            weightKg: bestNow.weightKg,        // preserved for display, not for PR-math
            reps: bestNow.reps,
            previousValue: Double(prevBestSeconds),
            newValue: Double(bestNow.reps),
            achievedAt: bestNow.date
        )
    }

    // MARK: - Zeitformate (README 2.9: AMRAP/EMOM/Auf Zeit)

    /// Erkennt einen `.mostRounds`- oder `.fastestTime`-PR fuer einen
    /// WOD-Versuch gegen die Historie DESSELBEN WODs (gleicher `wodName` +
    /// `format`). Getrennt von `detectPRs`, weil die Ergebnis-Form pro
    /// Session (Runden/Zeit) nicht auf das Set-basierte `LiftAttempt`-Modell
    /// passt. Gleicher Grundsatz wie oben: strikt besser, keine Ties, erste
    /// Session etabliert nur die Baseline.
    ///
    /// EMOM liefert bewusst nie einen PR — "alle Minuten geschafft" ist
    /// pass/fail, kein maximierbarer Wert wie Runden oder Zeit.
    public static func detectTimedFormatPR(
        session: TimedWorkoutAttempt,
        history: [TimedWorkoutAttempt]
    ) -> PersonalRecord? {
        let priorAttempts = history.filter {
            $0.wodName == session.wodName && $0.format == session.format
        }
        guard !priorAttempts.isEmpty else { return nil }

        switch session.format {
        case .amrap:
            guard let rounds = session.roundsCompleted else { return nil }
            let prevBest = priorAttempts.compactMap(\.roundsCompleted).max() ?? 0
            guard rounds > prevBest else { return nil }
            return PersonalRecord(
                kind: .mostRounds,
                exerciseName: session.wodName,
                weightKg: 0,
                reps: session.partialReps ?? 0,
                previousValue: Double(prevBest),
                newValue: Double(rounds),
                achievedAt: session.date
            )

        case .forTime:
            // README 2.10/19e: eine frueh gespeicherte (und dadurch kuerzere)
            // Session darf weder selbst als Bestzeit gelten noch als
            // schlagbare Baseline fuer spaetere Laeufe zaehlen - sonst
            // gewinnt strukturell immer der kuerzeste, nicht der schnellste
            // vollstaendige Lauf.
            guard session.completedTarget, let time = session.finishTimeSeconds else { return nil }
            let completedPriorAttempts = priorAttempts.filter(\.completedTarget)
            guard let prevBest = completedPriorAttempts.compactMap(\.finishTimeSeconds).min() else { return nil }
            guard time < prevBest else { return nil }   // Schneller = kleiner = besser.
            return PersonalRecord(
                kind: .fastestTime,
                exerciseName: session.wodName,
                weightKg: 0,
                reps: 0,
                previousValue: Double(prevBest),
                newValue: Double(time),
                achievedAt: session.date
            )

        case .emom:
            return nil

        case .circuit:
            // Die Rundenzahl ist durch den Tag fest vorgegeben
            // (`TrainingDay.circuitRounds`), keine variable Groesse wie bei
            // AMRAP (Zeit fix, Runden variabel) oder Auf Zeit (Pensum fix,
            // Zeit variabel) - es gibt nichts, worauf sich ein Bestwert
            // beziehen koennte.
            return nil

        case .enduranceIntervals:
            // Paket 2 (docs/DELTIQ_DEVICE_ACCEPTANCE.md): PR-Erkennung fuer
            // Ausdauer-Intervalle waere eine neue fachliche Frage (schnellste
            // Belastungszeit? laengste Strecke?) - explizit ausserhalb des
            // Paket-2-Scopes ("keine neue adaptive Coaching-/
            // Progressionslogik"). Bewusst kein PR, wie bei EMOM/Zirkel.
            return nil
        }
    }

    // MARK: Helpers

    private static func estimated1RM(_ lift: LiftAttempt) -> Double? {
        ExerciseCalculations.estimate1RMAverage(weightKg: lift.weightKg, reps: lift.reps)
    }

    /// Display-priority within an exercise. 1RM is the most "wow" weighted PR;
    /// time + reps PRs come last because they're typically standalone categories
    /// (a time-based exercise can't also produce 1RM).
    ///
    /// DEL-218: delegiert an `PersonalRecord.Kind.displayPriority` — die
    /// Reihenfolge lag vorher in vier unabhaengigen Kopien, von denen zwei die
    /// Cardio-Kinds vergessen hatten.
    private static func kindOrder(_ kind: PersonalRecord.Kind) -> Int {
        kind.displayPriority
    }
}
