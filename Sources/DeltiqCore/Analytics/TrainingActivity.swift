import Foundation

/// AI-Running-Coach Phase 2 (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase2-implementation.md, Work Package 2A):
/// eine bereits aus einer `WorkoutSession` extrahierte, klassifizierte
/// Trainingseinheit - vereinigt die Phase-1-Cardio-Klassifikation
/// (`CardioVolumeOverTimeAggregator.LoggedSession`, dort unveraendert
/// wiederverwendet) mit den Krafttrainings-Kennzahlen dieser Session.
///
/// Reine Werttyp, keine SwiftData-Abhaengigkeit - die SwiftData-Glue (echte
/// `WorkoutSession`/`ExerciseLog` -> `TrainingActivity`) lebt in
/// `DeltiqData/TrainingActivityExtractor.swift`.
///
/// Die drei Cardio-Klassifikations-Flags (`isRunning`/`isCrossTrainingOnly`/
/// `hasAmbiguousCardio`) sind UNABHAENGIG voneinander, identisches Prinzip
/// wie in `CardioVolumeOverTimeAggregator.LoggedSession` - dieser Typ
/// re-deriviert ihre Prioritaet nicht selbst.
public struct TrainingActivity: Sendable, Equatable {
    public let date: Date

    /// Summe der Lauf-Distanz dieser Session (nur `.running`-Logs). `nil`,
    /// wenn keine Lauf-Distanz bekannt ist (nicht dasselbe wie 0 - Teil J:
    /// fehlende Werte sind unbekannt, nicht null).
    public let runningDistanceKm: Double?
    public let runningDurationSeconds: Int?
    public let isRunning: Bool
    /// Radfahren (oder ein anderer bekannter Nicht-Lauf-Ausdauersport).
    /// Niemals zu `runningDistanceKm` addiert (Ticket Teil 4.3).
    public let isCrossTrainingOnly: Bool
    /// Cardio mit unbekannter Sportart - nie automatisch als Laufen
    /// gezaehlt (Ticket Teil 4.3/J).
    public let hasAmbiguousCardio: Bool

    /// Enthielt diese Session ueberhaupt Kraftarbeit? Identische Definition
    /// wie `WorkoutSession.containsStrengthWork` (Time-Based-Haltearbeit
    /// zaehlt mit, nur `resolvedIsCardio` schliesst aus).
    public let hasStrengthActivity: Bool
    /// Anzahl geloggter Kraft-/Haltearbeits-Saetze (Platzhalter-Zeilen
    /// bereits ausgeschlossen, siehe `WorkoutSession.loggedSets`). 0, wenn
    /// keine Kraftarbeit vorlag - UNTERSCHEIDET sich von "unbekannt", das
    /// es hier nicht gibt: eine Session ohne Kraft-Logs hat schlicht 0.
    public let strengthSetCount: Int
    /// Summe Gewicht x Wiederholungen ueber alle Kraft-Saetze dieser
    /// Session (`SessionAggregator.totals`, identische Formel wie ueberall
    /// sonst im Produkt). Bodyweight-Saetze tragen 0 bei, zaehlen aber in
    /// `strengthSetCount` - niemals ein erfundenes Gewicht.
    public let strengthVolumeKg: Double

    public init(
        date: Date,
        runningDistanceKm: Double?,
        runningDurationSeconds: Int?,
        isRunning: Bool,
        isCrossTrainingOnly: Bool,
        hasAmbiguousCardio: Bool,
        hasStrengthActivity: Bool,
        strengthSetCount: Int,
        strengthVolumeKg: Double
    ) {
        self.date = date
        self.runningDistanceKm = runningDistanceKm
        self.runningDurationSeconds = runningDurationSeconds
        self.isRunning = isRunning
        self.isCrossTrainingOnly = isCrossTrainingOnly
        self.hasAmbiguousCardio = hasAmbiguousCardio
        self.hasStrengthActivity = hasStrengthActivity
        self.strengthSetCount = strengthSetCount
        self.strengthVolumeKg = strengthVolumeKg
    }

    /// Verlustfreie Projektion auf den Phase-1-Typ - einzige Stelle, die
    /// beide Welten verbindet, damit `TrainingLoadAggregator` die
    /// bestehende `CardioVolumeOverTimeAggregator.aggregate`-Logik
    /// unveraendert wiederverwenden kann statt sie zu duplizieren.
    var asCardioLoggedSession: CardioVolumeOverTimeAggregator.LoggedSession {
        .init(
            date: date,
            runningDistanceKm: runningDistanceKm,
            runningDurationSeconds: runningDurationSeconds,
            isRunning: isRunning,
            isCrossTrainingOnly: isCrossTrainingOnly,
            hasAmbiguousCardio: hasAmbiguousCardio,
            hasStrengthActivity: hasStrengthActivity
        )
    }
}
