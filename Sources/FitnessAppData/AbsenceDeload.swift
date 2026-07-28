#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// DEL-239: Absenz-getriggerter Deload — die Rueckfrage beim Trainingsstart.
///
/// **Warum das NICHT `DeloadManager.startDeload` benutzt.** Der Overreaching-
/// Deload sichert Originale in `Exercise.deloadOriginalWeight` und stellt sie
/// nach einer Woche zurueck. Fuer eine Rueckkehr nach Wochen Pause ist das
/// falsch:
///
///   * Das Original ist zwei Monate alt und nachweislich nicht hebbar. Es nach
///     sieben Tagen bedingungslos wieder zu verordnen (`endDeload` schreibt
///     ohne Pruefung, `DeloadManager.swift:77`) wuerde den einzigen frischen
///     Kraftmesswert wegwerfen — und dabei auch jede manuelle Korrektur, die
///     der Nutzer in der Zwischenzeit vorgenommen hat.
///   * `startDeload` ueberspringt Uebungen, deren Snapshot schon belegt ist.
///     Laeuft bereits ein Deload, waere das Ergebnis `adjusted == 0`: die App
///     wuerde eine bestaetigte Rueckfrage stumm ignorieren.
///
/// Deshalb ist die Reduktion hier der NEUE STAND, ohne Snapshot und ohne
/// Timer. Nach oben tragen die Gewichte die normale Progression
/// (`ProgressionApplicator` nach jedem Workout) — genau die Rampe ueber
/// absolvierte Sessions, die `ComebackAdvisor` beschreibt. Damit entfaellt der
/// Streit um den einen Snapshot-Slot vollstaendig.
///
/// Der Preis: es gibt keinen "laeuft"-Zustand, also auch keinen strukturellen
/// Schutz gegen doppeltes Anwenden. Den uebernehmen ein Zeitstempel
/// (`lastAppliedKey`) und die Zahlen-Vorschau in der Rueckfrage.
public enum AbsenceDeload {

    /// Letzte angewendete Absenz-Reduktion (Unix-Zeit). Datenzustand, kein
    /// Preference: gehoert NICHT in die `SettingsPortability`-Whitelist, aber
    /// in die `resetApp`-Loeschliste.
    public static let lastAppliedKey = "deload.absence.lastAppliedAt"

    /// Luecke, bei der der Nutzer zuletzt abgelehnt hat. Verhindert
    /// Nachbohren; erneut gefragt wird erst bei deutlich laengerer Pause.
    public static let suppressedUntilGapKey = "deload.absence.suppressedUntilGapDays"

    /// Mindestabstand zwischen zwei Anwendungen. Ohne das koennte der Nutzer
    /// am selben Tag zwei Sessions starten und 0,85 x 0,85 = 0,72 kassieren.
    public static let reapplyCooldownDays = 14

    // MARK: - Bewertung

    /// `Identifiable` fuer `sheet(item:)` — die Luecke identifiziert die
    /// Bewertung eindeutig genug, es gibt nie zwei gleichzeitig.
    public struct Assessment: Sendable, Equatable, Identifiable {
        public var id: Int { gapDays }
        /// Tage seit dem letzten Training MIT Kraftanteil.
        public let gapDays: Int
        /// Empfohlener Faktor fuer Verbund-Uebungen (0,85 = minus 15 %).
        public let recommendedFactor: Double
        /// Ab einem halben Jahr Pause empfiehlt der Advisor einen Wiedertest
        /// statt einer geschaetzten Reduktion.
        public let needsRetest: Bool
    }

    /// Soll beim Trainingsstart gefragt werden — und mit welcher Empfehlung?
    ///
    /// `nil` = nicht fragen. Gruende dafuer, alle absichtlich:
    ///   * Luecke unter der Schwelle (14 Tage, bzw. persoenlich hoeher).
    ///   * Weniger als drei Kraft-Sessions vor der Pause: ohne etablierte Last
    ///     gibt es nichts, wovon man reduzieren koennte.
    ///   * Es laeuft schon ein Deload (Overreaching-Pfad) — dann waere eine
    ///     zweite Reduktion eine Verdopplung.
    ///   * In den letzten 14 Tagen wurde schon eine Absenz-Reduktion
    ///     angewendet.
    ///   * Der Nutzer hat bei dieser oder einer laengeren Luecke abgelehnt.
    /// `@MainActor`, weil diese Funktion `DeloadManager.isActive(in:)` aufruft
    /// und `DeloadManager` main-actor-isoliert ist — von aussen waere der
    /// Aufruf implizit asynchron und damit hier ein Fehler.
    ///
    /// Bewusst nur diese Funktion und nicht der ganze Typ: eine Annotation am
    /// Enum wuerde auch das verschachtelte `Assessment` isolieren, das als
    /// `Sendable` in SwiftUI-`@State` liegt und ueber eine Sheet-Grenze
    /// gereicht wird. `preview`, `apply` und `remember` brauchen die Isolation
    /// nicht: sie rufen nichts Isoliertes auf.
    @MainActor
    public static func assess(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> Assessment? {
        // Ein laufender Overreaching-Deload hat Vorrang: die Gewichte sind
        // schon reduziert.
        guard !DeloadManager.isActive(in: context) else { return nil }

        let storedApplied = defaults.double(forKey: lastAppliedKey)
        if storedApplied > 0 {
            let applied = Date(timeIntervalSince1970: storedApplied)
            let days = calendar.dateComponents([.day], from: applied, to: now).day ?? 0
            // Negative Werte (Uhr verstellt) gelten als "gerade erst" — lieber
            // eine Frage zu wenig als eine doppelte Reduktion.
            if days < reapplyCooldownDays { return nil }
        }

        let sessions = allRealSessions(in: context)
        let strengthSessions = sessions
            .filter(\.containsStrengthWork)
            .sorted { $0.endTime < $1.endTime }
        guard let last = strengthSessions.last else { return nil }

        let gapDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last.endTime),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        // Persoenliche Norm: Median-Abstand der letzten Kraft-Sessions.
        let median = medianGapDays(of: strengthSessions, calendar: calendar)

        // Fenster endet an der LETZTEN Session, nicht heute — sonst waere es
        // bei langen Pausen zwangslaeufig leer.
        let windowStart = calendar.date(byAdding: .day, value: -28, to: last.endTime) ?? .distantPast
        let sessionsBeforeGap = strengthSessions.filter {
            $0.endTime >= windowStart && $0.endTime <= last.endTime
        }.count

        let suppressedRaw = defaults.integer(forKey: suppressedUntilGapKey)
        let suppressed = suppressedRaw > 0 ? suppressedRaw : nil

        guard ComebackAdvisor.shouldSuggest(
            gapDays: gapDays,
            medianGap: median,
            sessionsBeforeGap: sessionsBeforeGap,
            suppressedUntilGapDays: suppressed
        ) else { return nil }

        let prescription = ComebackAdvisor.prescription(forGapDays: gapDays)
        return Assessment(
            gapDays: gapDays,
            recommendedFactor: prescription.compoundFactor,
            needsRetest: prescription.needsRetest
        )
    }

    // MARK: - Anwenden

    /// Vorschau: welche Uebungen aendern sich, und wie?
    ///
    /// Die Rueckfrage zeigt echte Zahlen statt einer Prozentangabe. Das ist der
    /// Ersatz fuer den fehlenden "laeuft"-Zustand: der Nutzer sieht, ob die
    /// Reduktion ueberhaupt greift, und erkennt eine versehentliche
    /// Doppelanwendung an den Zahlen.
    public struct Change: Sendable, Equatable {
        public let exerciseName: String
        public let from: Double
        public let to: Double
    }

    public static func preview(in context: ModelContext, factor: Double) -> [Change] {
        adjustableExercises(in: context).compactMap { exercise in
            guard let current = exercise.suggestedWeight, current > 0 else { return nil }
            let reduced = ComebackAdvisor.reducedWeight(
                current: current,
                factor: factor,
                increment: increment(for: exercise)
            )
            guard reduced < current else { return nil }
            return Change(exerciseName: exercise.name, from: current, to: reduced)
        }
    }

    /// Wendet die Reduktion an. Liefert die Anzahl geaenderter Uebungen.
    ///
    /// Schreibt bewusst NICHT `deloadOriginalWeight` und setzt keinen Timer —
    /// siehe Typ-Doku. Der Zeitstempel verhindert die Doppelanwendung.
    @discardableResult
    public static func apply(
        in context: ModelContext,
        factor: Double,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) throws -> Int {
        guard factor < 1.0 else { return 0 }
        var changed = 0
        for exercise in adjustableExercises(in: context) {
            guard let current = exercise.suggestedWeight, current > 0 else { continue }
            let reduced = ComebackAdvisor.reducedWeight(
                current: current,
                factor: factor,
                increment: increment(for: exercise)
            )
            guard reduced < current else { continue }
            exercise.suggestedWeight = reduced
            changed += 1
        }
        if changed > 0 {
            try context.save()
            defaults.set(now.timeIntervalSince1970, forKey: lastAppliedKey)
            // Eine angenommene Reduktion loescht eine fruehere Ablehnung —
            // sonst blockiert sie den naechsten Fall mit.
            defaults.removeObject(forKey: suppressedUntilGapKey)
        }
        return changed
    }

    /// Merkt die Ablehnung. Erneut gefragt wird erst bei deutlich laengerer
    /// Pause (`ComebackAdvisor.shouldSuggest` vergleicht dagegen).
    public static func remember(
        declinedAtGapDays gapDays: Int,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(gapDays, forKey: suppressedUntilGapKey)
    }

    // MARK: - Intern

    /// Dieselben Filter wie `DeloadManager.startDeload`: nur Arbeitssaetze des
    /// aktiven Plans, kein Cardio, kein TimeBased.
    private static func adjustableExercises(in context: ModelContext) -> [Exercise] {
        let plans = (try? context.fetch(
            FetchDescriptor<TrainingPlan>(predicate: #Predicate { $0.isActive == true })
        )) ?? []
        return plans.flatMap(\.days).flatMap(\.activeExercises).filter {
            !$0.isCardio && !$0.isTimeBased && $0.role == .workingSet
        }
    }

    /// Scheiben-Schrittweite der Uebung. `progressionStep` ist das, was der
    /// Nutzer beim Steigern zulegt — dieselbe Rasterung beim Reduzieren ist
    /// konsistent und plattengerecht. Fallback 2,5 kg.
    private static func increment(for exercise: Exercise) -> Double {
        exercise.progressionStep > 0 ? exercise.progressionStep : 2.5
    }

    private static func allRealSessions(in context: ModelContext) -> [WorkoutSession] {
        let all = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return all.filter { $0.isCompleted && !$0.isRestDay }
    }

    /// Median-Abstand zwischen aufeinanderfolgenden Kraft-Sessions, ueber die
    /// letzten acht. `nil` bei weniger als zwei Sessions.
    private static func medianGapDays(
        of sorted: [WorkoutSession],
        calendar: Calendar
    ) -> Double? {
        let recent = Array(sorted.suffix(9))
        guard recent.count >= 2 else { return nil }
        var gaps: [Double] = []
        for (a, b) in zip(recent, recent.dropFirst()) {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: a.endTime),
                to: calendar.startOfDay(for: b.endTime)
            ).day ?? 0
            if days > 0 { gaps.append(Double(days)) }
        }
        guard !gaps.isEmpty else { return nil }
        gaps.sort()
        let mid = gaps.count / 2
        return gaps.count.isMultiple(of: 2) ? (gaps[mid - 1] + gaps[mid]) / 2 : gaps[mid]
    }
}
#endif
