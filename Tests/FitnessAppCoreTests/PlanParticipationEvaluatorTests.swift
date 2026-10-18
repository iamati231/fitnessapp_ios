import XCTest
@testable import FitnessAppCore

/// P6.2 — deckt die acht vom Gesamtmandat verbindlich benannten Faelle ab.
/// Alles laeuft gegen einen festen UTC-Gregorian-Calendar und explizite
/// Daten, nie `Date()`/`Calendar.current` — deterministisch auf jeder
/// Plattform, inkl. Linux.
final class PlanParticipationEvaluatorTests: XCTestCase {

    // MARK: - Fixtures

    /// UTC vermeidet jede Host-Zeitzonen-/DST-Abhaengigkeit.
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// 2024-01-01 ist ein Montag (Apple-Konvention: weekday 2).
    private func d(_ month: Int, _ day: Int, year: Int = 2024) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func occ(_ date: Date, _ outcome: PlanParticipationEvaluator.SessionOccurrence.Outcome) -> PlanParticipationEvaluator.SessionOccurrence {
        .init(date: date, outcome: outcome)
    }

    private func fixedInput(
        activatedAt: Date?,
        isActive: Bool = true,
        occurrences: [PlanParticipationEvaluator.SessionOccurrence] = [],
        weekdays: Set<Int>,
        usesFixedWeekdays: Bool? = true,
        hasUnattributableSessionsExcluded: Bool = false
    ) -> PlanParticipationEvaluator.Input {
        .init(
            activatedAt: activatedAt,
            isActive: isActive,
            occurrences: occurrences,
            nonRestDayCount: weekdays.count,
            nonRestWeekdays: weekdays,
            usesFixedWeekdays: usesFixedWeekdays,
            hasUnattributableSessionsExcluded: hasUnattributableSessionsExcluded,
            calendar: utc
        )
    }

    private func flexibleInput(
        activatedAt: Date?,
        isActive: Bool = true,
        occurrences: [PlanParticipationEvaluator.SessionOccurrence] = [],
        sessionsPerWeek: Int,
        usesFixedWeekdays: Bool? = false,
        hasUnattributableSessionsExcluded: Bool = false
    ) -> PlanParticipationEvaluator.Input {
        .init(
            activatedAt: activatedAt,
            isActive: isActive,
            occurrences: occurrences,
            nonRestDayCount: sessionsPerWeek,
            nonRestWeekdays: [],
            usesFixedWeekdays: usesFixedWeekdays,
            hasUnattributableSessionsExcluded: hasUnattributableSessionsExcluded,
            calendar: utc
        )
    }

    private func requireSummary(_ result: PlanParticipationEvaluator.Result, file: StaticString = #filePath, line: UInt = #line) -> PlanParticipationEvaluator.Summary {
        guard case .evaluated(let summary) = result else {
            XCTFail("expected .evaluated, got \(result)", file: file, line: line)
            return PlanParticipationEvaluator.Summary(
                periodStart: Date(), periodEnd: Date(), scheduleKindUsed: .flexibleWeeklyCadence(sessionsPerWeek: 0),
                plannedCount: 0, completedCount: 0, partialCount: 0, startedOnlyCount: 0, missedCount: 0,
                extraOccurrenceCount: 0, countingRules: [], dataGaps: []
            )
        }
        return summary
    }

    // MARK: - Outcome ordering (Comparable)

    func testOutcomeRankingCompletedBeatsPartialBeatsStartedOnly() {
        XCTAssertTrue(PlanParticipationEvaluator.SessionOccurrence.Outcome.startedOnly < .partial)
        XCTAssertTrue(PlanParticipationEvaluator.SessionOccurrence.Outcome.partial < .completed)
    }

    // MARK: - Regel 2: abgeschlossen / teilweise / nur gestartet getrennt

    func testCompletedPartialAndStartedOnlyAreCountedSeparately() {
        // Mon(2)/Wed(4)/Fri(6) plan, week of 2024-01-01 (Mon) ... 2024-01-05 (Fri).
        let input = fixedInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 1), .completed),   // Monday
                occ(d(1, 3), .partial),     // Wednesday
                occ(d(1, 5), .startedOnly)  // Friday
            ],
            weekdays: [2, 4, 6]
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 5)))
        XCTAssertEqual(summary.plannedCount, 3)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.partialCount, 1)
        XCTAssertEqual(summary.startedOnlyCount, 1)
        XCTAssertEqual(summary.missedCount, 0)
    }

    // MARK: - Regel 3: eine doppelt absolvierte Einheit gleicht keine fehlende aus

    func testDoubleSessionOnOneDayDoesNotOffsetAMissingDay() {
        let input = fixedInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 1), .completed),
                occ(d(1, 1), .completed) // zweite Session selber Tag — darf nicht doppelt zaehlen
                // Wednesday (1,3) und Friday (1,5) fehlen komplett.
            ],
            weekdays: [2, 4, 6]
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 5)))
        XCTAssertEqual(summary.plannedCount, 3)
        XCTAssertEqual(summary.completedCount, 1, "zwei Sessions am selben Tag sind weiterhin nur EIN erfuellter Termin")
        XCTAssertEqual(summary.missedCount, 2, "Mittwoch und Freitag bleiben versaeumt, egal wie oft Montag trainiert wurde")
    }

    func testFlexibleCadenceSurplusSessionsDoNotCreditBeyondQuota() {
        // 2 Einheiten/Woche, genau 1 Woche verstrichen -> plannedCount = 2.
        // User trainiert an 4 verschiedenen Tagen -> nur die ersten 2 (chronologisch) zaehlen.
        let input = flexibleInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 1), .completed),
                occ(d(1, 2), .completed),
                occ(d(1, 3), .completed),
                occ(d(1, 4), .completed)
            ],
            sessionsPerWeek: 2
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 7)))
        XCTAssertEqual(summary.plannedCount, 2)
        XCTAssertEqual(summary.completedCount, 2, "Ueberschuss darf den Soll-Zaehler nicht sprengen")
        XCTAssertEqual(summary.extraOccurrenceCount, 2)
        XCTAssertTrue(summary.countingRules.contains(.occurrencesBeyondCadenceNotCredited))
    }

    func testRepeatedSameDaySessionsInFlexibleModeCountAsOneDistinctDay() {
        // 3 Einheiten in Wirklichkeit, aber nur an EINEM Kalendertag -> darf
        // nicht so aussehen, als waere die Wochenkadenz erfuellt.
        let input = flexibleInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 1), .completed),
                occ(d(1, 1), .completed),
                occ(d(1, 1), .completed)
            ],
            sessionsPerWeek: 3
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 7)))
        XCTAssertEqual(summary.plannedCount, 3)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.missedCount, 2)
    }

    // MARK: - Regel 4: feste Wochentage vs. flexible Reihenfolge unterschiedlich behandeln

    func testFixedWeekdaysPenalizesOffScheduleTrainingAsExtraNotAsCredit() {
        // Plan ist Mon/Wed/Fri, User trainiert stattdessen Dienstag+Donnerstag.
        let input = fixedInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 2), .completed), // Tuesday - nicht geplant
                occ(d(1, 4), .completed)  // Thursday - nicht geplant
            ],
            weekdays: [2, 4, 6]
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 5)))
        XCTAssertEqual(summary.plannedCount, 3) // Mon, Wed, Fri faellig
        XCTAssertEqual(summary.completedCount, 0, "Training an Nicht-Plantagen erfuellt keinen Plantermin")
        XCTAssertEqual(summary.missedCount, 3)
        XCTAssertEqual(summary.extraOccurrenceCount, 2)
        XCTAssertTrue(summary.countingRules.contains(.offScheduleOccurrencesNotCredited))
    }

    func testFlexibleScheduleCreditsTheSameOffWeekdayPatternThatFixedWouldReject() {
        // Exakt dieselben Trainingstage (Di+Do) wie oben, aber als flexible
        // Kadenz (2/Woche) -> hier zaehlen sie normal, weil es keine festen
        // Wochentage gibt.
        let input = flexibleInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 2), .completed),
                occ(d(1, 4), .completed)
            ],
            sessionsPerWeek: 2
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 5)))
        // 5 Tage verstrichen (1.-5.1., inklusive) * 2/7 = 1.43 -> floor = 1.
        XCTAssertEqual(summary.plannedCount, 1)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.extraOccurrenceCount, 1)
    }

    func testScheduleKindUsedReflectsTheInputKind() {
        let fixed = requireSummary(PlanParticipationEvaluator.evaluate(
            fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6]), asOf: d(1, 1)
        ))
        XCTAssertEqual(fixed.scheduleKindUsed, .fixedWeekdays([2, 4, 6]))

        let flexible = requireSummary(PlanParticipationEvaluator.evaluate(
            flexibleInput(activatedAt: d(1, 1), sessionsPerWeek: 3), asOf: d(1, 7)
        ))
        XCTAssertEqual(flexible.scheduleKindUsed, .flexibleWeeklyCadence(sessionsPerWeek: 3))
    }

    // MARK: - Regel 5: nicht faellige Einheiten nicht als versaeumt zaehlen

    func testNotYetDueOpportunitiesAreExcludedNotCountedAsMissed() {
        // Mon/Wed/Fri-Plan, Auswertung am Dienstag -> nur Montag ist faellig,
        // Mittwoch/Freitag duerfen NICHT als versaeumt auftauchen.
        let input = fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6])
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 2)))
        XCTAssertEqual(summary.plannedCount, 1)
        XCTAssertEqual(summary.missedCount, 1, "nur der bereits verstrichene Montag zaehlt als versaeumt")
    }

    func testEvaluatingOnTheActivationDayItselfCountsThatDayIfDue() {
        let input = fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6]) // Monday is a plan day
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 1)))
        XCTAssertEqual(summary.plannedCount, 1)
    }

    // MARK: - Regel 6/8: unbekanntes activatedAt / unzureichende Datengrundlage

    func testUnknownActivatedAtIsNotReliablyEvaluable() {
        let input = fixedInput(activatedAt: nil, weekdays: [2, 4, 6])
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(input, asOf: d(1, 10)),
            .notReliablyEvaluable(.activationStartUnknown)
        )
    }

    func testNoOpportunityDueYetIsNotReliablyEvaluableNotAFalseZero() {
        // Aktiviert an einem Dienstag, Plan ist Mon/Wed/Fri, Auswertung noch
        // am selben Dienstag -> noch kein einziger Termin faellig.
        let input = fixedInput(activatedAt: d(1, 2), weekdays: [2, 4, 6])
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(input, asOf: d(1, 2)),
            .notReliablyEvaluable(.noOpportunityDueYet)
        )
    }

    func testPlanWithNoTrainingDaysIsNotReliablyEvaluable() {
        let fixedEmpty = fixedInput(activatedAt: d(1, 1), weekdays: [])
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(fixedEmpty, asOf: d(1, 10)),
            .notReliablyEvaluable(.planHasNoTrainingDays)
        )
        let flexibleEmpty = flexibleInput(activatedAt: d(1, 1), sessionsPerWeek: 0)
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(flexibleEmpty, asOf: d(1, 10)),
            .notReliablyEvaluable(.planHasNoTrainingDays)
        )
    }

    func testEvaluationDateBeforeActivationIsNotReliablyEvaluable() {
        let input = fixedInput(activatedAt: d(1, 10), weekdays: [2, 4, 6])
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(input, asOf: d(1, 1)),
            .notReliablyEvaluable(.evaluationBeforeActivation)
        )
    }

    func testOccurrencesOutsideThePeriodAreIgnored() {
        let input = fixedInput(
            activatedAt: d(1, 1),
            occurrences: [
                occ(d(1, 1).addingTimeInterval(-86_400), .completed), // Tag vor Aktivierung
                occ(d(1, 10), .completed) // nach dem Auswertungsdatum
            ],
            weekdays: [2, 4, 6]
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 1)))
        XCTAssertEqual(summary.completedCount, 0, "Sessions ausserhalb [periodStart, periodEnd] zaehlen nicht mit")
    }

    // MARK: - Regel 7: Aktivierungswechsel/Planaenderungen — ein activatedAt ist keine volle Historie

    func testInactivePlanIsNotReliablyEvaluableBecauseDeactivationTimeIsUnknown() {
        let input = fixedInput(activatedAt: d(1, 1), isActive: false, weekdays: [2, 4, 6])
        XCTAssertEqual(
            PlanParticipationEvaluator.evaluate(input, asOf: d(1, 10)),
            .notReliablyEvaluable(.planNotCurrentlyActive)
        )
    }

    func testEveryEvaluatedResultDisclosesTheSingleActivationAnchorLimitation() {
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(
            fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6]), asOf: d(1, 5)
        ))
        XCTAssertTrue(summary.dataGaps.contains(.singleActivationAnchorOnly))
        XCTAssertTrue(summary.dataGaps.contains(.planStructureChangesDuringPeriodNotTracked))
    }

    func testUnknownSchedulingIntentIsAssumedFlexibleAndFlaggedAsADataGap() {
        let input = fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6], usesFixedWeekdays: nil)
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 7)))
        // nonRestDayCount wurde in fixedInput() auf weekdays.count gesetzt (3),
        // also flexibleWeeklyCadence(3) statt fixedWeekdays(...).
        XCTAssertEqual(summary.scheduleKindUsed, .flexibleWeeklyCadence(sessionsPerWeek: 3))
        XCTAssertTrue(summary.dataGaps.contains(.scheduleKindUnknownAssumedFlexible))
    }

    /// Der Aufrufer (`FourWeekReviewAssembler`) entscheidet, OB Sessions
    /// unattributierbar ausgeschlossen wurden, und meldet das hier nur noch
    /// durch — dieser Test deckt ausschliesslich die Durchreichung als
    /// sichtbaren `DataGap` ab, nicht die Zuordnungslogik selbst (die liegt
    /// in `FitnessAppData`, SwiftData-abhaengig, siehe
    /// `FourWeekReviewAssemblerTests`).
    func testUnattributableSessionsExcludedFlagSurfacesAsDataGap() {
        let withExclusion = fixedInput(
            activatedAt: d(1, 1), weekdays: [2, 4, 6], hasUnattributableSessionsExcluded: true
        )
        let summary = requireSummary(PlanParticipationEvaluator.evaluate(withExclusion, asOf: d(1, 5)))
        XCTAssertTrue(summary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))

        let withoutExclusion = fixedInput(activatedAt: d(1, 1), weekdays: [2, 4, 6])
        let cleanSummary = requireSummary(PlanParticipationEvaluator.evaluate(withoutExclusion, asOf: d(1, 5)))
        XCTAssertFalse(cleanSummary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))
    }

    // MARK: - Regel 1: mehrere aktive Plaene getrennt, ohne gegenseitige Beeinflussung

    func testTwoPlansEvaluatedSeparatelyNeverMixOccurrences() {
        let planA = fixedInput(
            activatedAt: d(1, 1),
            occurrences: [occ(d(1, 1), .completed)],
            weekdays: [2, 4, 6]
        )
        let planB = flexibleInput(
            activatedAt: d(1, 1),
            occurrences: [occ(d(1, 2), .completed), occ(d(1, 3), .completed)],
            sessionsPerWeek: 5
        )
        let summaryA = requireSummary(PlanParticipationEvaluator.evaluate(planA, asOf: d(1, 5)))
        let summaryB = requireSummary(PlanParticipationEvaluator.evaluate(planB, asOf: d(1, 5)))

        XCTAssertEqual(summaryA.scheduleKindUsed, .fixedWeekdays([2, 4, 6]))
        XCTAssertEqual(summaryA.completedCount, 1)
        XCTAssertEqual(summaryA.plannedCount, 3)

        XCTAssertEqual(summaryB.scheduleKindUsed, .flexibleWeeklyCadence(sessionsPerWeek: 5))
        XCTAssertEqual(summaryB.completedCount, 2, "Plan Bs zwei Sessions duerfen nicht mit Plan As einzelner Session vermischt werden")
    }

    // MARK: - Invariante: plannedCount == completed + partial + startedOnly + missed

    func testPlannedCountAlwaysEqualsTheSumOfAllFourBuckets() {
        let scenarios: [PlanParticipationEvaluator.Input] = [
            fixedInput(activatedAt: d(1, 1), occurrences: [occ(d(1, 1), .completed)], weekdays: [2, 4, 6]),
            fixedInput(activatedAt: d(1, 1), occurrences: [occ(d(1, 1), .partial), occ(d(1, 3), .startedOnly)], weekdays: [2, 4, 6]),
            flexibleInput(activatedAt: d(1, 1), occurrences: [occ(d(1, 1), .completed), occ(d(1, 2), .partial)], sessionsPerWeek: 4)
        ]
        for input in scenarios {
            let summary = requireSummary(PlanParticipationEvaluator.evaluate(input, asOf: d(1, 10)))
            XCTAssertEqual(
                summary.plannedCount,
                summary.completedCount + summary.partialCount + summary.startedOnlyCount + summary.missedCount
            )
        }
    }
}
