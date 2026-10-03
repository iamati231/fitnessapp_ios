#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// One persisted workout session.
///
/// A row is created at workout *start* with `isCompleted=false` and `durationMinutes=0` (F63).
/// The final "Save" on the Summary screen does an UPDATE that fills stats and flips
/// `isCompleted=true`. Rows with `isCompleted=false` are surfaced as crash-recovery
/// banners on the Home screen (F72).
@Model
public final class WorkoutSession {
    public var startTime: Date
    public var endTime: Date
    public var durationMinutes: Int
    public var exerciseCount: Int
    public var totalSets: Int
    public var totalVolumeKg: Double
    public var notes: String?
    public var isCompleted: Bool

    /// True when this session is a "Ruhetag uebersprungen"-marker rather than
    /// a real workout. The session lives in the store with `isCompleted=true`
    /// so the `PlanNavigator` advances its pointer past the rest-day, but the
    /// History/Dashboard/Trophy-Room surfaces filter these out so the user
    /// never sees empty "phantom" sessions. Persists as an explicit flag
    /// (default false) so a missed-write doesn't accidentally hide real
    /// sessions.
    public var isRestDay: Bool = false

    /// DEL-096: True wenn diese Session als "Spontanes Workout" gestartet
    /// wurde — kein Plan, kein Tag-Template, der User picked seine Uebungen
    /// in der ActiveWorkoutView selber. Steuert:
    ///   * Empty-State-Branch in der ActiveWorkoutView ("Uebung hinzufuegen"-
    ///     CTA statt "Diese Session hat keine Uebungen"-Hinweis)
    ///   * In-Workout "+Uebung"-Toolbar-Button, damit der User wachsen kann
    ///   * Discard-Sweep: leere Ad-Hoc-Sessions ohne Logs werden beim
    ///     Beenden geloescht statt persistiert (kein Schrott in History)
    /// Default `false` damit Lightweight-Migration die Bestandsdaten korrekt
    /// als Plan-Sessions markiert.
    public var isAdHoc: Bool = false

    /// Snapshotted day name at session start — keeps history readable even after
    /// the source `TrainingDay` is renamed or deleted (F123 Bug #2).
    public var dayName: String?

    // MARK: - Zeitformat-Ergebnisse (AMRAP/EMOM/Auf Zeit/Zirkel)
    //
    // Nur die Ergebnis-Groessen des jeweiligen Formats sind je Session
    // gesetzt, je nach `timeFormatSnapshot`. Bei einer normalen
    // Krafttrainings-Session bleiben alle diese Felder `nil`.

    /// Snapshot von `day.timeFormat` bei Session-Start — gleiches Muster
    /// wie `dayName`: ueberlebt einen spaeteren Format- oder Tag-Wechsel,
    /// damit Zusammenfassung und Verlauf weiterhin wissen, wie diese
    /// konkrete Session zu lesen ist.
    public var timeFormatSnapshot: WorkoutTimeFormat?
    /// AMRAP: Anzahl vollstaendig abgeschlossener Runden.
    public var roundsCompleted: Int?
    /// AMRAP: Wiederholungen in die angebrochene, nicht mehr vollstaendige Runde hinein.
    public var partialReps: Int?
    /// AMRAP: Name-Snapshot der Uebung, auf die sich `partialReps` bezieht
    /// (README 2.15/23d) - "7" allein sagt nicht, ob sieben Liegestuetze
    /// oder sieben Kniebeugen. Gleiches Snapshot-Muster wie `dayName`: ein
    /// Index auf die Uebungsliste wuerde brechen, sobald der Tag spaeter
    /// bearbeitet wird. `nil` wenn `partialReps` 0 ist (nichts zuzuordnen)
    /// oder bei Sessions von vor diesem Feature.
    public var partialRepsExerciseName: String?
    /// Auf Zeit: Gesamtzeit bis zum letzten Haekchen, in Sekunden.
    public var finishTimeSeconds: Int?
    /// Auf Zeit: Zwischenstand der pro Uebung abgehakten Runden, damit
    /// "Training fortsetzen" (eine neue View-Instanz fuer dieselbe Session,
    /// siehe `ForTimePlayerView.init`) den Fortschritt nicht verliert -
    /// gleiches Problem wie bei `roundsCompleted`/`completedMinuteCount`,
    /// aber ohne einen einzelnen Int als Signal: es braucht eine Zuordnung
    /// PRO Uebung. `PersistentIdentifier` selbst laesst sich nicht als
    /// SwiftData-Attribut speichern, daher ein kompaktes eigenes Format
    /// ueber die (pro Tag eindeutige) `Exercise.orderIndex`:
    /// "orderIndex=Anzahl" Paare, kommagetrennt, z.B. "0=3,2=1". `nil` heisst
    /// "Vorlauf noch nicht durchlaufen", der Platzhalter "-" heisst
    /// "gestartet, noch nichts abgehakt" (bewusst NICHT der leere String -
    /// der CSV-Reader normalisiert ein leeres Feld beim Roundtrip wieder zu
    /// `nil`, siehe `CSVRow.optionalString`, was genau diese Unterscheidung
    /// nach einem Backup/Restore wieder zerstoert haette) - siehe
    /// `ForTimePlayerView`.
    public var forTimeCheckedRoundsRaw: String?
    /// EMOM: Anzahl der Minuten, in denen das Pensum geschafft wurde (von `day.timeCapMinutes`).
    public var completedMinuteCount: Int?
    /// Zirkel: Anzahl vollstaendig abgeschlossener Runden (von
    /// `day.circuitRounds`). `nil` bis zum allerersten echten Start nach
    /// dem Vorlauf — gleiches Muster wie `roundsCompleted`.
    public var circuitRoundsCompleted: Int?
    /// Zirkel: Ende der aktuell laufenden Pause zwischen zwei Runden, `nil`
    /// wenn gerade eine Runde laeuft (nicht pausiert wird). Wanduhr-Anker
    /// statt Sekunden-Zaehler — ueberlebt Hintergrund/Resume wie
    /// `session.startTime` bei den anderen drei Formaten.
    public var circuitRestEndDate: Date?
    /// Zirkel (`.fixedReps`): Zwischenstand der in der LAUFENDEN Runde
    /// abgehakten Uebungen — anders als `forTimeCheckedRoundsRaw` (kumulativ
    /// ueber die ganze Session) wird dieser Wert bei jedem Rundenwechsel
    /// wieder auf den "-"-Platzhalter zurueckgesetzt. Gleiches
    /// "orderIndex=Anzahl"-Format wie bei Auf Zeit, siehe dortigen
    /// Kommentar. `nil` bei `.toFailure`-Tagen (keine Checkboxen).
    public var circuitCurrentRoundCheckedRaw: String?
    /// True nur bei regulaerem Ende (Zeit-Deckel erreicht bzw. bei Auf Zeit
    /// alle Runden abgehakt), false beim vorzeitigen manuellen "Speichern"
    /// aus dem Punkte-Menue (README 2.10/19e). Vorbedingung dafuer, dass
    /// `PersonalRecordSync.recordTimedFormatPR` bei Auf Zeit einen frueh
    /// abgebrochenen (kuerzeren) Lauf nicht als Bestzeit werten kann. Default
    /// `false` — Lightweight-Migration markiert Bestandsdaten damit korrekt
    /// als "nicht verifiziert vollstaendig" statt faelschlich als komplett.
    public var completedTarget: Bool = false

    /// Name der Quell-App, wenn diese Session automatisch aus einem externen
    /// HealthKit-Workout importiert wurde (z.B. "Adidas Running"). `nil` fuer
    /// jede nativ in der App erfasste Session — das ist der einzige Provenienz-
    /// Marker, den es gibt (siehe `isAdHoc` fuer "kein Plan", was etwas anderes
    /// ist). Wird als Badge in der History angezeigt.
    public var importSourceName: String?
    /// `HKWorkout.uuid` des Quell-Samples, wenn importiert. Dient ausschliesslich
    /// der Re-Sync-Idempotenz (verhindert, dass derselbe externe Workout bei
    /// einem spaeteren Sync ein zweites Mal importiert wird) — kein UI-Feld.
    public var healthKitSampleUUID: String?

    /// Zeitpunkt, zu dem dieses Training als "behandelt" gilt: nach dem Beenden
    /// bestaetigt nach Health geschrieben, vom Export geschrieben ODER dort schon
    /// vorhanden (eigene Live-Writes, andere App). Maßgeblich: Eine markierte
    /// Session wird nie wieder exportiert, auch wenn ihr Eintrag in Health
    /// spaeter geloescht wird (ein Doppel in Health ist schwerer zu beheben als
    /// ein fehlender Eintrag). Nur lokal — geht der Marker verloren (Reset,
    /// Backup-Restore), faengt der Abgleich mit Health das ab. Deshalb bewusst
    /// NICHT in `workouts.csv` und nicht portabel. Nicht dasselbe wie
    /// `healthKitSampleUUID` (= importiert AUS Health). `nil` fuer jede
    /// Bestands-Session (Lightweight-Migration).
    public var healthKitExportedAt: Date?

    /// DEL-057: Vom User auf der Finish-Half-Sheet gewaehltes Session-Gefuehl.
    /// 1 = Grossartig, 2 = Gut, 3 = Okay, 4 = Sehr schwer, 5 = Zerstoert.
    /// Wird vom `ProgressionApplicator` ausgewertet: bei 4/5 wird jede
    /// `.increaseWeight`-Action zwingend auf `.hold` ueberschrieben
    /// (Erschoepfungs-Veto). Optional, weil bestehende Sessions vor DEL-057
    /// kein Gefuehl tragen und auch nicht muessen.
    public var sessionFeeling: Int?

    /// DEL-084: Auf welchem Gear (Schuh / Bike) wurde diese Session
    /// gemacht? `.nullify` damit ein geloeschtes Gear die Session-Historie
    /// nicht mit sich reisst. Nil bei reinen Strength-Sessions oder wenn
    /// der User kein Gear gepflegt hat.
    @Relationship(deleteRule: .nullify)
    public var gear: Gear?

    @Relationship(deleteRule: .nullify)
    public var day: TrainingDay?

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.session)
    public var logs: [ExerciseLog] = []

    public init(
        startTime: Date = Date(),
        endTime: Date = Date(),
        durationMinutes: Int = 0,
        exerciseCount: Int = 0,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0.0,
        notes: String? = nil,
        isCompleted: Bool = false,
        isRestDay: Bool = false,
        isAdHoc: Bool = false,
        dayName: String? = nil,
        day: TrainingDay? = nil,
        timeFormatSnapshot: WorkoutTimeFormat? = nil,
        roundsCompleted: Int? = nil,
        partialReps: Int? = nil,
        partialRepsExerciseName: String? = nil,
        finishTimeSeconds: Int? = nil,
        forTimeCheckedRoundsRaw: String? = nil,
        completedMinuteCount: Int? = nil,
        circuitRoundsCompleted: Int? = nil,
        circuitRestEndDate: Date? = nil,
        circuitCurrentRoundCheckedRaw: String? = nil,
        completedTarget: Bool = false,
        importSourceName: String? = nil,
        healthKitSampleUUID: String? = nil,
        healthKitExportedAt: Date? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.notes = notes
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.isAdHoc = isAdHoc
        self.dayName = dayName
        self.day = day
        self.timeFormatSnapshot = timeFormatSnapshot
        self.roundsCompleted = roundsCompleted
        self.partialReps = partialReps
        self.partialRepsExerciseName = partialRepsExerciseName
        self.finishTimeSeconds = finishTimeSeconds
        self.forTimeCheckedRoundsRaw = forTimeCheckedRoundsRaw
        self.completedMinuteCount = completedMinuteCount
        self.circuitRoundsCompleted = circuitRoundsCompleted
        self.circuitRestEndDate = circuitRestEndDate
        self.circuitCurrentRoundCheckedRaw = circuitCurrentRoundCheckedRaw
        self.completedTarget = completedTarget
        self.importSourceName = importSourceName
        self.healthKitSampleUUID = healthKitSampleUUID
        self.healthKitExportedAt = healthKitExportedAt
    }

    /// True when this is a finished, non-rest-day session — i.e., a real
    /// trainings-session that should be visible in History/Trophy-Room and
    /// counted in PR-Detection and analytics. Use this everywhere instead of
    /// `isCompleted` alone, otherwise rest-day-marker rows leak into UI.
    public var isRealWorkout: Bool {
        isCompleted && !isRestDay
    }

    /// DEL-081: Drei-State-Kategorisierung der Session aus den geloggten
    /// Saetzen. UI-Surfaces (HistorySessionRow, WorkoutSummary, ActiveWorkout-
    /// Header) lesen das hier und schalten ihre Stats-Zeile entsprechend.
    /// DEL-093: Cardio-Detection beruecksichtigt auch `durationSeconds` —
    /// ein Ad-Hoc-Laufband ohne km-Eingabe gilt jetzt korrekt als Cardio.
    public var sessionCategory: SessionCategory {
        SessionCategory.evaluate(logs: logs.map {
            (isCardio: $0.resolvedIsCardio,
             distanceKm: $0.distanceKm,
             durationSeconds: $0.durationSeconds)
        })
    }

    /// DEL-081 Convenience — Summe `log.distanceKm` ueber alle Logs der
    /// Session. Strength-Logs tragen nil → 0 bei.
    public var totalDistanceKm: Double {
        logs.compactMap(\.distanceKm).reduce(0.0, +)
    }

    /// DEL-081 Convenience — Summe `log.durationSeconds` ueber alle Cardio-
    /// Logs. Wird fuer Average-Pace genutzt.
    public var totalCardioDurationSeconds: Int {
        logs.filter { $0.resolvedIsCardio }
            .compactMap(\.durationSeconds)
            .reduce(0, +)
    }

    // MARK: - DEL-099 Session-weite Recovery-Aggregation

    /// Summe der CNS-Belastung aller geloggten Saetze dieser Session.
    /// Cardio-/Time-Based-Logs fliessen mit ihrem dauerbasierten Score ein,
    /// Strength-Logs mit gewicht-/RIR-skaliertem Set-Load.
    public var totalSessionCNSLoad: Double {
        logs.reduce(0.0) { $0 + $1.cnsFatigueScore }
    }

    /// Summe der lokalen Muskel-Belastung aller geloggten Saetze.
    public var totalSessionMuscleDamage: Double {
        logs.reduce(0.0) { $0 + $1.localMuscleDamageScore }
    }

    /// Kuerzer-Alias auf `totalSessionCNSLoad` — neuer Code-Sites
    /// nutzen vorzugsweise diese Schreibweise (kompakter, matcht das
    /// Ticket-Vokabular DEL-099/DEL-100). Beide bleiben verfuegbar,
    /// damit Bestands-Aufrufer (DEL-099-Pre-Welle 16) nicht brechen.
    public var totalCNSLoad: Double { totalSessionCNSLoad }

    /// Kuerzer-Alias auf `totalSessionMuscleDamage`.
    public var totalMuscleDamage: Double { totalSessionMuscleDamage }

    /// DEL-099 + DEL-100 Bruecke: True wenn die Session den
    /// CNS-Overload-Schwellwert (300 Punkte = oberster Recovery-Bucket,
    /// 72h+) erreicht oder ueberschritten hat. Wird von der
    /// `CoachingMessageProvider`-Pipeline gelesen, um die
    /// `.cnsOverloaded`-Coaching-Message auf dem Dashboard zu zuenden.
    ///
    /// Schwelle entspricht dem default-bucket in
    /// `ExerciseScoring.estimatedRecoveryHours`. Wenn jemand die Schwelle
    /// tuned, BITTE beide Stellen aktualisieren.
    public var isCNSOverloaded: Bool {
        totalCNSLoad >= 300.0
    }

    /// Geschaetzte Erholungs-Stunden auf Basis der **groesseren** der
    /// beiden Last-Pools — wenn ZNS gegrillt ist, hilft Bein-Recovery
    /// nicht und umgekehrt. Caller (Dashboard, Live-Activity) zeigt das
    /// 1:1 als "Recovery: 48h" o.ae.
    public var estimatedRecoveryTimeHours: Int {
        ExerciseScoring.estimatedRecoveryHours(
            maxLoad: max(totalSessionCNSLoad, totalSessionMuscleDamage)
        )
    }
}
#endif
