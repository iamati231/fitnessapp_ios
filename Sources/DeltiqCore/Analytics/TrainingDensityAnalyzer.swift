import Foundation

/// AI-Running-Coach Phase 2, Work Package 2C: deterministische
/// Trainingsbelastungs- und Erholungsdichte-Bewertung auf der Grundlage
/// von `[TrainingActivity]` (tägliche Granularität aus 2A) und
/// `TrainingLoadTrend` (Wochentrendanalyse aus 2B).
///
/// **Bewusste Grenzen:**
///   - Kein medizinisches Urteil, keine Verletzungsprognose.
///   - Keine zweite Deload-Engine: der `deloadIsActive`-Parameter wird
///     vom Aufrufer gereicht (aus AppStorage "deload_until"), nie selbst
///     berechnet. Vgl. `FourWeekReviewOrchestrator`-Muster.
///   - Keine neuen SwiftData-Felder: alle Eingaben kommen aus bereits
///     existierenden Typen (TrainingActivity, TrainingLoadTrend, Bool).
///   - `sessionFeelingUnavailable` ist immer ein DataGap, weil
///     `TrainingActivity` keine RPE/Befindlichkeitsdaten trägt — das ist
///     eine bewusste, dokumentierte Modellgrenze, kein Bug.
public enum TrainingDensityAnalyzer {

    // MARK: - Produktregeln (dokumentiert, nicht medizinisch)

    /// Ab dieser Anzahl Trainingstage in Folge gilt die Dichte als
    /// auffällig hoch — Produktregel, kein medizinischer Schwellenwert.
    public static let highConsecutiveDaysThreshold = 5
    /// 6+ Trainingstage in einem 7-Tage-Rollfenster gilt als dicht.
    public static let denseWeekThreshold = 6
    /// Unter 18 Stunden Abstand zwischen zwei Laufeinheiten gilt als eng.
    public static let closeRunningGapHoursThreshold: Double = 18
    /// Mindestanzahl Aktivitäten für eine Aussage.
    public static let minimumActivityCount = 3
    /// Mindestspanne in Tagen für eine Aussage.
    public static let minimumSpanDays = 7
    /// Mindestspanne für "balanced" (volle Aussagekraft).
    public static let sufficientHistoryDays = 14

    // MARK: - Concern

    /// Erkannte Belastungsauffälligkeiten — kein medizinisches Urteil.
    public enum Concern: Sendable, Equatable {
        /// Mindestens `days` aufeinanderfolgende Trainingstage ohne Ruhetag.
        case highConsecutiveTrainingDays(days: Int)
        /// Mindestens `days` Trainingstage im 7-Tage-Rollfenster.
        case sixPlusTrainingDaysInWeek(days: Int)
        /// Zwischen zwei Laufeinheiten lagen weniger als 18 Stunden.
        case closelySpacedRunningSessions(minimumGapHours: Double)
        /// Das bestehende `DeloadAdvisor`-System empfiehlt aktuell einen Deload.
        case deloadIndicatedByExistingSystem
    }

    // MARK: - DataGap

    /// Datenlücken, die eine vollständige Bewertung einschränken.
    public enum DataGap: Sendable, Equatable {
        /// Weniger als 14 Tage Trainingshistorie vorhanden.
        case insufficientHistory(daysAvailable: Int)
        /// `TrainingActivity` trägt kein RPE/Befindlichkeits-Signal —
        /// immer vorhanden, da diese Dimension im Modell fehlt.
        case sessionFeelingUnavailable
        /// Keine Laufeinheit mit bekannter Dauer — Intensitätseinschätzung
        /// via Herzfrequenz nicht möglich.
        case noMeasuredIntensityData
    }

    // MARK: - Outcome

    /// Gesamtbewertung der Trainingsbelastungsdichte.
    public enum Outcome: Sendable, Equatable {
        /// Dichte unauffällig, Trend stabil oder rückläufig, ≥ 14 Tage Historie.
        case balanced
        /// Bestehende Deload-Empfehlung aktiv oder signifikanter Belastungsanstieg.
        case increasingLoad
        /// Hohe Trainingsdichte erkannt (Folgetage oder dichte Woche).
        case highTrainingDensity
        /// Genug Aktivitätsdaten, aber Erholungsqualität nicht beurteilbar.
        case insufficientRecoveryEvidence
        /// Zu wenig Aktivitätsdaten für eine Aussage.
        case insufficientData
    }

    // MARK: - Assessment

    public struct Assessment: Sendable, Equatable {
        /// Maximale ununterbrochene Folge von Trainingstagen.
        public let consecutiveTrainingDays: Int
        /// Distinct Trainingstage im 7-Tage-Rollfenster bis `now`.
        public let trainingDaysLast7: Int
        /// Distinct Trainingstage im 14-Tage-Rollfenster bis `now`.
        public let trainingDaysLast14: Int
        /// Kürzester zeitlicher Abstand zwischen zwei Laufeinheiten.
        /// `nil`, wenn weniger als 2 Laufeinheiten im Datensatz.
        public let minimumRunningGapHours: Double?
        /// Kürzester zeitlicher Abstand zwischen zwei Kraft-Einheiten.
        /// `nil`, wenn weniger als 2 Kraft-Einheiten im Datensatz.
        public let minimumStrengthGapHours: Double?
        public let concerns: [Concern]
        public let dataGaps: [DataGap]
        public let outcome: Outcome
        /// Spanne der ältesten bis neuesten Aktivität in Tagen.
        public let analyzedPeriodDays: Int
        public let analyzedActivityCount: Int
    }

    // MARK: - Input

    public struct Input: Sendable, Equatable {
        /// Rohe Aktivitätsliste (tägliche Granularität aus 2A), Reihenfolge egal.
        public let activities: [TrainingActivity]
        /// Wochentrendanalyse aus 2B — wird NICHT neu berechnet.
        public let trend: TrainingLoadTrend
        /// Ergebnis des bestehenden `DeloadAdvisor` — wird NICHT neu berechnet.
        /// Aufrufer liest `deloadUntil` aus AppStorage und gibt `deloadUntil > now.timeIntervalSince1970` herein.
        public let deloadIsActive: Bool
        public let now: Date
        public let calendar: Calendar

        public init(
            activities: [TrainingActivity],
            trend: TrainingLoadTrend,
            deloadIsActive: Bool,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            self.activities = activities
            self.trend = trend
            self.deloadIsActive = deloadIsActive
            self.now = now
            self.calendar = calendar
        }
    }

    // MARK: - Eintrittspunkt

    /// Deterministische Bewertung der Trainingsbelastungsdichte.
    /// Reine Funktion: kein State, kein SwiftData, kein `Date()`/`Calendar.current`.
    public static func analyze(input: Input) -> Assessment {
        let sorted = input.activities.sorted { $0.date < $1.date }

        // Mindestdatenprüfung
        guard sorted.count >= minimumActivityCount,
              let oldest = sorted.first?.date else {
            return insufficientDataAssessment(activityCount: sorted.count)
        }

        let spanDays = max(1, Int(input.now.timeIntervalSince(oldest) / 86_400))
        guard spanDays >= minimumSpanDays else {
            return insufficientDataAssessment(activityCount: sorted.count)
        }

        // Distinct Trainingstage (Kalender-Tage mit mindestens einer Aktivität)
        let trainingDays: [Date] = Array(
            Set(sorted.map { input.calendar.startOfDay(for: $0.date) })
        ).sorted()

        let consecutive = maxConsecutiveDays(trainingDays, calendar: input.calendar)
        let last7 = trainingDaysInWindow(trainingDays, days: 7, now: input.now, calendar: input.calendar)
        let last14 = trainingDaysInWindow(trainingDays, days: 14, now: input.now, calendar: input.calendar)

        let runActivities = sorted.filter(\.isRunning)
        let minRunGap = minimumGapHours(between: runActivities.map(\.date))
        let strengthActivities = sorted.filter(\.hasStrengthActivity)
        let minStrengthGap = minimumGapHours(between: strengthActivities.map(\.date))

        // Concerns
        var concerns: [Concern] = []
        if consecutive >= highConsecutiveDaysThreshold {
            concerns.append(.highConsecutiveTrainingDays(days: consecutive))
        }
        if last7 >= denseWeekThreshold {
            concerns.append(.sixPlusTrainingDaysInWeek(days: last7))
        }
        if let gap = minRunGap, gap < closeRunningGapHoursThreshold {
            concerns.append(.closelySpacedRunningSessions(minimumGapHours: gap))
        }
        if input.deloadIsActive {
            concerns.append(.deloadIndicatedByExistingSystem)
        }

        // DataGaps
        var dataGaps: [DataGap] = [.sessionFeelingUnavailable]
        if spanDays < sufficientHistoryDays {
            dataGaps.append(.insufficientHistory(daysAvailable: spanDays))
        }
        let hasRunDuration = runActivities.contains { $0.runningDurationSeconds != nil }
        if !hasRunDuration {
            dataGaps.append(.noMeasuredIntensityData)
        }

        // Outcome
        let outcome = determineOutcome(
            concerns: concerns,
            trend: input.trend,
            spanDays: spanDays
        )

        return Assessment(
            consecutiveTrainingDays: consecutive,
            trainingDaysLast7: last7,
            trainingDaysLast14: last14,
            minimumRunningGapHours: minRunGap,
            minimumStrengthGapHours: minStrengthGap,
            concerns: concerns,
            dataGaps: dataGaps,
            outcome: outcome,
            analyzedPeriodDays: spanDays,
            analyzedActivityCount: sorted.count
        )
    }

    // MARK: - Hilfsfunktionen (intern)

    private static func insufficientDataAssessment(activityCount: Int) -> Assessment {
        Assessment(
            consecutiveTrainingDays: 0,
            trainingDaysLast7: 0,
            trainingDaysLast14: 0,
            minimumRunningGapHours: nil,
            minimumStrengthGapHours: nil,
            concerns: [],
            dataGaps: [.sessionFeelingUnavailable, .insufficientHistory(daysAvailable: 0)],
            outcome: .insufficientData,
            analyzedPeriodDays: 0,
            analyzedActivityCount: activityCount
        )
    }

    /// Maximale Anzahl aufeinanderfolgender Trainingstage im sortierten Array.
    static func maxConsecutiveDays(_ days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var maxStreak = 1
        var currentStreak = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if diff == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        return maxStreak
    }

    /// Anzahl distinct Trainingstage im Rollfenster `[now - days, now]`.
    static func trainingDaysInWindow(_ sortedDays: [Date], days: Int, now: Date, calendar: Calendar) -> Int {
        let windowStart = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        return sortedDays.filter { $0 >= windowStart && $0 <= now }.count
    }

    /// Kürzester Abstand (in Stunden) zwischen aufeinanderfolgenden Daten.
    /// `nil` wenn weniger als 2 Daten vorhanden.
    static func minimumGapHours(between dates: [Date]) -> Double? {
        guard dates.count >= 2 else { return nil }
        var minGap = Double.infinity
        for i in 1..<dates.count {
            let gap = dates[i].timeIntervalSince(dates[i - 1]) / 3_600
            if gap > 0 { minGap = min(minGap, gap) }
        }
        return minGap == .infinity ? nil : minGap
    }

    private static func determineOutcome(
        concerns: [Concern],
        trend: TrainingLoadTrend,
        spanDays: Int
    ) -> Outcome {
        let hasHighDensity = concerns.contains {
            switch $0 {
            case .highConsecutiveTrainingDays, .sixPlusTrainingDaysInWeek: return true
            default: return false
            }
        }
        let hasDeload = concerns.contains { $0 == .deloadIndicatedByExistingSystem }
        let isSignificantIncrease: Bool
        if case .significantIncrease = trend.loadDevelopment { isSignificantIncrease = true }
        else { isSignificantIncrease = false }

        if hasDeload || isSignificantIncrease {
            return .increasingLoad
        }
        if hasHighDensity {
            return .highTrainingDensity
        }
        if spanDays < sufficientHistoryDays {
            return .insufficientRecoveryEvidence
        }
        switch trend.loadDevelopment {
        case .stable, .declining:
            return .balanced
        default:
            // moderate increase, variable, or insufficientData — can't confirm recovery
            return .insufficientRecoveryEvidence
        }
    }
}
