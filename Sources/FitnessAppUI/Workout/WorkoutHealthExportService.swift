#if canImport(SwiftData) && canImport(SwiftUI)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Export frueherer Trainings nach Apple Health, in zwei Phasen:
///
/// 1. `prepare` (Dry-Run, schreibt nichts): liest die Sessions, plant jede mit
///    `HealthWorkoutPlanner` und gleicht sie mit den in Health sichtbaren
///    Workouts ab. Ergebnis: wie viele wuerden geschrieben, wie viele stehen
///    schon in Health, wie viele sind nicht exportierbar.
/// 2. `execute`: schreibt die gewaehlten Kategorien nacheinander.
///
/// Idempotenz: `WorkoutSession.healthKitExportedAt` ("behandelt") ist
/// maßgeblich — eine markierte Session wird nie wieder angefasst, auch wenn der
/// Eintrag in Health inzwischen geloescht wurde (bewusst: ein Doppel in Health
/// ist schwerer zu beheben als ein fehlender Eintrag). Der Marker liegt nur
/// lokal; geht er verloren (Reset, Restore), fuehrt der naechste Lauf ueber den
/// Abgleich mit Health wieder zu "bereits in Health", nicht zu Doppelten —
/// solange die Abfrage die eigenen Workouts sieht. Live nach dem Beenden
/// geschriebene Trainings setzen den Marker nach bestaetigtem Schreiben
/// (`HealthWorkoutWriter.pushLive`).
///
/// Schutzmassnahmen:
/// - Die Abfrage der Health-Workouts WIRFT bei Fehlern (fail-closed): ein
///   Doppel in Health ist schwerer zu beheben als ein fehlender Eintrag.
/// - Sessions werden vor der Schleife als WERTE erfasst (`PlannedWorkout`); in
///   der Schleife wird nur ueber den Start-Zeitpunkt neu nachgeschlagen, ob die
///   Session noch existiert und noch nicht behandelt ist (sie kann in der
///   Zwischenzeit geloescht oder bereits exportiert worden sein) — sonst wird
///   sie uebersprungen.
/// - Fehlerklassen: Schreibrecht weg oder gesperrtes Geraet stoppen den Lauf,
///   ein von Health abgelehntes Training zaehlt als "nicht exportierbar" und
///   der Lauf geht weiter, nur unklassifizierte Fehler in Folge stoppen ihn.
/// - Der Marker wird nach JEDEM erfolgreichen Schreiben gespeichert
///   (Abbruch/Absturz verliert hoechstens das laufende Training).
/// - Neueste Trainings zuerst: ein dauerhaft unschreibbares aeltestes Training
///   blockiert die aktuellen nicht.
@MainActor
enum WorkoutHealthExportService {

    // MARK: Typen

    /// Ein zu schreibendes Training als reiner Wert.
    struct PlannedWorkout: Equatable {
        /// Schluessel zum Wiederfinden der Session (natuerlicher Schluessel wie
        /// beim CSV-Import).
        let startTime: Date
        let plan: HealthWorkoutPlan
    }

    struct Preparation: Equatable {
        /// Neueste zuerst.
        var toWrite: [PlannedWorkout] = []
        /// Start-Zeitpunkte der Sessions, die schon in Health stehen.
        var alreadyInHealth: [Date] = []
        /// Zu kurz/lang, in der Zukunft oder ohne Inhalt.
        var notExportable = 0
        /// Wie viele Workouts Health im geprueften Zeitraum sichtbar machte
        /// (Diagnose: bei 0 trotz frueherer Live-Writes ist der Abgleich blind).
        var visibleWorkouts = 0
        var visibleOwnWorkouts = 0

        func count(_ category: HealthWorkoutCategory) -> Int {
            toWrite.filter { $0.plan.category == category }.count
        }

        var isEmpty: Bool { toWrite.isEmpty && alreadyInHealth.isEmpty && notExportable == 0 }
    }

    enum StopReason: Equatable {
        case notAuthorized
        case deviceLocked
        case tooManyFailures
    }

    struct Outcome: Equatable {
        var written = 0
        /// `finishWorkout()` ohne Ergebnis und nicht pruefbar (z.B. gesperrt).
        var unverified = 0
        var alreadyInHealth = 0
        /// Von Health abgelehnt (z.B. ungueltige Daten).
        var notExportable = 0
        var failed = 0
        /// Laeufe mit Distanz, bei denen das Distanz-Sample nicht angehaengt wurde.
        var withoutDistance = 0
        var stopReason: StopReason?
        var wasCancelled = false
        /// Bearbeitete Trainings der Schreib-Warteschlange und deren Gesamtzahl.
        var processed = 0
        var total = 0
    }

    private static let maxConsecutiveFailures = 5

    // MARK: Phase 1 - Pruefen (Dry-Run)

    /// Plant alle noch nicht behandelten Trainings (beide Kategorien) und
    /// gleicht sie mit Health ab. Schreibt nichts. Wirft, wenn die Abfrage der
    /// Health-Workouts scheitert (z.B. Geraet gesperrt).
    static func prepare(
        healthKit: HealthKitController,
        context: ModelContext,
        now: Date = Date()
    ) async throws -> Preparation {
        let allCategories: Set<HealthWorkoutCategory> = [.strength, .cardio]

        // Bewusst nur das einfache Bool-Predicate wie im Import-Service; alles
        // andere (importiert, Marker, Inhalt, Zeitformat) entscheidet der Planer
        // im Speicher — Predicates auf Optionals/Enums/Relationships sind unter
        // iOS 17 fehleranfaellig.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let sessions = try context.fetch(descriptor)

        var preparation = Preparation()
        var eligible: [(candidate: HealthWorkoutCandidate, plan: HealthWorkoutPlan)] = []
        for session in sessions {
            let candidate = HealthWorkoutWriter.candidate(for: session)
            switch HealthWorkoutPlanner.decide(candidate, enabledCategories: allCategories, now: now) {
            case .write(let plan):
                eligible.append((candidate: candidate, plan: plan))
            case .skip(let reason):
                if reason.isNotExportable { preparation.notExportable += 1 }
            }
        }
        guard !eligible.isEmpty else { return preparation }

        // Eine Abfrage ueber den ganzen betroffenen Zeitraum (+/- 1 Tag).
        let earliest = eligible.map { $0.plan.start }.min() ?? now
        let latest = eligible.map { $0.plan.end }.max() ?? now
        let windows = try await healthKit.fetchWorkoutWindows(
            from: earliest.addingTimeInterval(-24 * 3600),
            to: latest.addingTimeInterval(24 * 3600)
        )
        preparation.visibleWorkouts = windows.count
        preparation.visibleOwnWorkouts = windows.filter { $0.isOwnSource }.count

        // Neueste zuerst. Gegen Health wird NUR mit den echten Health-Fenstern
        // abgeglichen: nur das heisst "bereits in Health" (und wird als behandelt
        // markiert). Zwei sich ueberlappende Sessions rutschen trotzdem nicht
        // beide durch — die zweite wird gegen die schon geplanten geprueft, dann
        // aber WEDER geschrieben NOCH markiert (der naechste Lauf entscheidet
        // erneut, wenn die erste inzwischen in Health steht).
        let healthWindows: [(start: Date, end: Date)] = windows.map {
            (start: $0.startDate, end: $0.endDate)
        }
        var planned: [(start: Date, end: Date)] = []
        for item in eligible {
            let decision = HealthWorkoutPlanner.decide(
                item.candidate,
                enabledCategories: allCategories,
                existingWindows: healthWindows,
                now: now
            )
            switch decision {
            case .write(let plan):
                if ExternalWorkoutDedup.overlapsExisting(
                    sampleStart: plan.start,
                    sampleEnd: plan.end,
                    existingWindows: planned
                ) {
                    continue
                }
                preparation.toWrite.append(PlannedWorkout(startTime: item.candidate.startTime, plan: plan))
                planned.append((start: plan.start, end: plan.end))
            case .skip(.alreadyInHealth):
                preparation.alreadyInHealth.append(item.candidate.startTime)
            case .skip:
                break
            }
        }
        return preparation
    }

    // MARK: Phase 2 - Schreiben

    /// Schreibt die Trainings der gewaehlten Kategorien. Laeuft im Aufrufer-
    /// Task; `Task.isCancelled` wird zwischen den Trainings geprueft (das
    /// laufende wird noch fertig geschrieben).
    static func execute(
        _ preparation: Preparation,
        categories: Set<HealthWorkoutCategory>,
        healthKit: HealthKitController,
        context: ModelContext,
        progress: (_ done: Int, _ total: Int) -> Void
    ) async -> Outcome {
        var outcome = Outcome()

        // In Health schon vorhandene Trainings als behandelt markieren.
        if !preparation.alreadyInHealth.isEmpty {
            for startTime in preparation.alreadyInHealth {
                markExported(startTime: startTime, in: context)
            }
            try? context.save()
            outcome.alreadyInHealth = preparation.alreadyInHealth.count
        }

        let queue = preparation.toWrite.filter { categories.contains($0.plan.category) }
        outcome.total = queue.count
        progress(0, queue.count)

        var consecutiveFailures = 0
        for (index, item) in queue.enumerated() {
            if Task.isCancelled {
                outcome.wasCancelled = true
                break
            }

            // Die Session kann seit der Vorschau geloescht (oder anderweitig
            // behandelt) worden sein: dann nichts schreiben.
            guard sessionNeedsExport(startTime: item.startTime, in: context) else {
                outcome.processed = index + 1
                progress(outcome.processed, queue.count)
                continue
            }

            let draft = HealthWorkoutWriter.draft(from: item.plan)
            do {
                let result = try await healthKit.saveWorkout(draft)
                switch result {
                case .written(let distanceAttached):
                    outcome.written += 1
                    if item.plan.distanceKm != nil && !distanceAttached { outcome.withoutDistance += 1 }
                    markExported(startTime: item.startTime, in: context)
                    try? context.save()
                    consecutiveFailures = 0
                case .unverified(let distanceAttached):
                    // `finishWorkout()` lieferte nil: nicht als Erfolg zaehlen,
                    // sondern in Health nachsehen.
                    switch await verifyWritten(item.plan, healthKit: healthKit) {
                    case .some(true):
                        outcome.written += 1
                        if item.plan.distanceKm != nil && !distanceAttached { outcome.withoutDistance += 1 }
                        markExported(startTime: item.startTime, in: context)
                        try? context.save()
                        consecutiveFailures = 0
                    case .some(false):
                        outcome.failed += 1
                        consecutiveFailures += 1
                    case .none:
                        // Nicht pruefbar (z.B. gesperrt): kein Marker, der naechste
                        // Lauf gleicht ueber Health ab.
                        outcome.unverified += 1
                    }
                }
            } catch let error as HealthKitError {
                switch error {
                case .writeNotAuthorized:
                    outcome.stopReason = .notAuthorized
                case .databaseInaccessible:
                    outcome.stopReason = .deviceLocked
                case .invalidWorkout:
                    outcome.notExportable += 1
                default:
                    outcome.failed += 1
                    consecutiveFailures += 1
                }
            } catch {
                outcome.failed += 1
                consecutiveFailures += 1
            }

            if outcome.stopReason != nil { break }
            outcome.processed = index + 1
            progress(outcome.processed, queue.count)
            if consecutiveFailures >= maxConsecutiveFailures {
                outcome.stopReason = .tooManyFailures
                break
            }
        }
        return outcome
    }

    // MARK: Hilfen

    /// Nach `finishWorkout() == nil`: Steht das Workout wirklich in Health?
    /// `true` = eigenes Workout im Fenster gefunden, `false` = Abfrage ok, aber
    /// nichts gefunden, `nil` = nicht pruefbar (gesperrt, Abfragefehler).
    private static func verifyWritten(_ plan: HealthWorkoutPlan, healthKit: HealthKitController) async -> Bool? {
        do {
            let windows = try await healthKit.fetchWorkoutWindows(
                from: plan.start.addingTimeInterval(-120),
                to: plan.end.addingTimeInterval(120)
            )
            let own: [(start: Date, end: Date)] = windows
                .filter { $0.isOwnSource }
                .map { (start: $0.startDate, end: $0.endDate) }
            return ExternalWorkoutDedup.overlapsExisting(
                sampleStart: plan.start,
                sampleEnd: plan.end,
                existingWindows: own
            )
        } catch {
            return nil
        }
    }

    /// Existiert die Session noch, und ist sie noch nicht als behandelt markiert?
    /// (Mehrere Sessions mit identischem Start — z.B. aus einem Import — gelten
    /// als eine: es wird einmal geschrieben und alle markiert.)
    private static func sessionNeedsExport(startTime: Date, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.startTime == startTime }
        )
        guard let sessions = try? context.fetch(descriptor), !sessions.isEmpty else { return false }
        return sessions.contains { $0.healthKitExportedAt == nil }
    }

    /// Setzt den Marker, falls die Session noch existiert (sie kann waehrend der
    /// Schleife geloescht worden sein; dann passiert nichts). Auch vom Live-Pfad
    /// (`HealthWorkoutWriter.pushLive`) nach bestaetigtem Schreiben genutzt;
    /// speichern muss der Aufrufer.
    static func markExported(startTime: Date, in context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.startTime == startTime }
        )
        guard let sessions = try? context.fetch(descriptor) else { return }
        let stamp = Date()
        for session in sessions where session.healthKitExportedAt == nil {
            session.healthKitExportedAt = stamp
        }
    }
}
#endif
