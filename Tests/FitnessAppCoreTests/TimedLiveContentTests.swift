import XCTest
@testable import FitnessAppCore

final class TimedLiveContentTests: XCTestCase {

    private let anchor = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func at(_ seconds: Double) -> Date {
        anchor.addingTimeInterval(seconds)
    }

    private let margin = TimedLiveContent.staleMargin

    // MARK: - AMRAP

    func testAMRAPRunningCountsDownFromTheAnchorToTheCap() {
        let content = TimedLiveContent.amrap(anchor: anchor, capSeconds: 15 * 60, roundsCompleted: 3, now: at(10))
        XCTAssertEqual(content.phase, .running)
        XCTAssertEqual(content.clock, .countdown(start: anchor, end: at(900)))
        XCTAssertEqual(content.runStart, anchor)
        XCTAssertEqual(content.runEnd, at(900))
        XCTAssertEqual(content.counter, 3)
        XCTAssertNil(content.counterTotal)
        XCTAssertEqual(content.staleDate, at(900 + margin))
    }

    /// Das Update-Signal der App: dieselbe Lage zu zwei Zeitpunkten ergibt DENSELBEN
    /// Inhalt - sonst ginge jede Sekunde ein Update an die Live Activity.
    func testAMRAPContentIsStableWhileNothingChanges() {
        let early = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 2, now: at(1))
        let late = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 2, now: at(599.9))
        XCTAssertEqual(early, late)
    }

    func testAMRAPAnotherRoundChangesTheContent() {
        let before = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 2, now: at(30))
        let after = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 3, now: at(30))
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(after.counter, 3)
    }

    /// Der Player prueft `Int(Sekunden) >= Deckel` - ab genau dem Deckel ist es vorbei.
    func testAMRAPIsFinishedExactlyAtTheCap() {
        let justBefore = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 5, now: at(599.999))
        XCTAssertEqual(justBefore.phase, .running)
        let atCap = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 5, now: at(600))
        XCTAssertEqual(atCap.phase, .finished)
        XCTAssertEqual(atCap.clock, .frozen(seconds: 0))
        XCTAssertEqual(atCap.counter, 5)
        XCTAssertNil(atCap.staleDate)
        XCTAssertEqual(atCap.runEnd, at(600))
    }

    func testAMRAPStaysFinishedLongAfterTheCap() {
        let content = TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 5, now: at(5_000))
        XCTAssertEqual(content.phase, .finished)
    }

    func testAMRAPClampsNonsenseInput() {
        let content = TimedLiveContent.amrap(anchor: anchor, capSeconds: 0, roundsCompleted: -4, now: at(0))
        XCTAssertEqual(content.runEnd, at(1))
        XCTAssertEqual(content.counter, 0)
    }

    // MARK: - EMOM

    private let names = ["Liegestuetze", "Kniebeugen", "Burpees"]

    private func emom(minutes: Int = 12, names: [String]? = nil, now: Double) -> TimedLiveContent {
        TimedLiveContent.emom(anchor: anchor, totalMinutes: minutes, exerciseNames: names ?? self.names, now: at(now))
    }

    func testEMOMFirstMinuteShowsTheFirstAndTheNextExercise() {
        let content = emom(now: 0)
        XCTAssertEqual(content.phase, .running)
        XCTAssertEqual(content.clock, .countdown(start: anchor, end: at(60)))
        XCTAssertEqual(content.counter, 1)
        XCTAssertEqual(content.counterTotal, 12)
        XCTAssertEqual(content.currentExercise, "Liegestuetze")
        XCTAssertEqual(content.nextExercise, "Kniebeugen")
        XCTAssertEqual(content.runEnd, at(720))
        XCTAssertEqual(content.staleDate, at(60 + margin))
    }

    /// 59,9 s sind noch Minute 1: ganze Sekunden werden abgerundet wie im Player.
    func testEMOMMinuteChangesExactlyOnTheSixtiethSecond() {
        XCTAssertEqual(emom(now: 59.9).counter, 1)
        let second = emom(now: 60)
        XCTAssertEqual(second.counter, 2)
        XCTAssertEqual(second.clock, .countdown(start: at(60), end: at(120)))
        XCTAssertEqual(second.currentExercise, "Kniebeugen")
        XCTAssertEqual(second.nextExercise, "Burpees")
    }

    func testEMOMContentIsStableInsideAMinute() {
        XCTAssertEqual(emom(now: 10), emom(now: 59.5))
        XCTAssertNotEqual(emom(now: 59.5), emom(now: 60))
    }

    /// Bei mehr Minuten als Uebungen wiederholt sich der Zirkel (3 Uebungen, 12 Minuten).
    func testEMOMWrapsAroundTheExerciseList() {
        let fourth = emom(now: 3 * 60)
        XCTAssertEqual(fourth.counter, 4)
        XCTAssertEqual(fourth.currentExercise, "Liegestuetze")
        XCTAssertEqual(fourth.nextExercise, "Kniebeugen")
    }

    func testEMOMLastMinuteHasNoNextExercise() {
        let last = emom(now: 11 * 60 + 30)
        XCTAssertEqual(last.counter, 12)
        XCTAssertEqual(last.currentExercise, "Burpees")
        XCTAssertNil(last.nextExercise)
        XCTAssertEqual(last.clock, .countdown(start: at(660), end: at(720)))
    }

    func testEMOMIsFinishedAtTheEndOfTheLastMinute() {
        XCTAssertEqual(emom(now: 719.9).phase, .running)
        let done = emom(now: 720)
        XCTAssertEqual(done.phase, .finished)
        XCTAssertEqual(done.counter, 12)
        XCTAssertEqual(done.counterTotal, 12)
        XCTAssertEqual(done.clock, .frozen(seconds: 0))
        XCTAssertNil(done.currentExercise)
        XCTAssertNil(done.staleDate)
    }

    func testEMOMWithoutExercisesStillRuns() {
        let content = emom(names: [], now: 90)
        XCTAssertEqual(content.counter, 2)
        XCTAssertNil(content.currentExercise)
        XCTAssertNil(content.nextExercise)
    }

    /// Eine einzige Uebung ist in jeder Minute dieselbe (Zirkel aus einem Eintrag).
    func testEMOMWithASingleExerciseRepeatsIt() {
        let content = emom(minutes: 5, names: ["Klimmzuege"], now: 60)
        XCTAssertEqual(content.currentExercise, "Klimmzuege")
        XCTAssertEqual(content.nextExercise, "Klimmzuege")
    }

    func testEMOMClampsNonsenseMinutesToOne() {
        let content = emom(minutes: 0, now: 0)
        XCTAssertEqual(content.counterTotal, 1)
        XCTAssertNil(content.nextExercise)
        XCTAssertEqual(content.runEnd, at(60))
    }

    func testEMOMBeforeTheAnchorStaysInTheFirstMinute() {
        let content = emom(now: -5)
        XCTAssertEqual(content.counter, 1)
        XCTAssertEqual(content.clock, .countdown(start: anchor, end: at(60)))
    }

    // MARK: - Auf Zeit

    private func forTime(
        cap: Int? = nil,
        checked: Int = 0,
        total: Int = 10,
        finished: Int? = nil,
        now: Double
    ) -> TimedLiveContent {
        TimedLiveContent.forTime(
            anchor: anchor, capSeconds: cap, checkedBoxes: checked, totalBoxes: total,
            finishedElapsedSeconds: finished, now: at(now)
        )
    }

    func testForTimeWithoutCapCountsUpForever() {
        let content = forTime(checked: 4, now: 100_000)
        XCTAssertEqual(content.phase, .running)
        XCTAssertEqual(content.clock, .countUp(since: anchor))
        XCTAssertNil(content.runEnd)
        XCTAssertNil(content.overallRange)
        XCTAssertNil(content.staleDate)
        XCTAssertEqual(content.counter, 4)
        XCTAssertEqual(content.counterTotal, 10)
    }

    func testForTimeWithCapKnowsItsEnd() {
        let content = forTime(cap: 20 * 60, now: 30)
        XCTAssertEqual(content.phase, .running)
        XCTAssertEqual(content.runEnd, at(1_200))
        XCTAssertEqual(content.staleDate, at(1_200 + margin))
    }

    func testForTimeIsFinishedAtTheCapWithTheCapAsTime() {
        XCTAssertEqual(forTime(cap: 600, now: 599.9).phase, .running)
        let capped = forTime(cap: 600, checked: 7, now: 600)
        XCTAssertEqual(capped.phase, .finished)
        XCTAssertEqual(capped.clock, .frozen(seconds: 600))
        XCTAssertEqual(capped.counter, 7)
        XCTAssertNil(capped.staleDate)
    }

    /// Alle Kaesten abgehakt: Der Player friert die Zeit ein - die Live Activity
    /// zeigt genau diese Zeit, auch wenn die Wanduhr laengst weiterlaeuft.
    func testForTimeShowsTheFrozenResultOnceTheBoxesAreAllChecked() {
        let content = forTime(checked: 10, finished: 754, now: 9_000)
        XCTAssertEqual(content.phase, .finished)
        XCTAssertEqual(content.clock, .frozen(seconds: 754))
        XCTAssertEqual(content.counter, 10)
    }

    func testForTimeFrozenResultWinsOverTheRunningClockBeforeTheCap() {
        let content = forTime(cap: 3_600, checked: 10, finished: 120, now: 130)
        XCTAssertEqual(content.phase, .finished)
        XCTAssertEqual(content.clock, .frozen(seconds: 120))
    }

    /// Ein Haekchen wieder zurueck: `finishedElapsedSeconds` wird nil, die Uhr
    /// zaehlt vom selben Anker weiter - ohne Spruenge.
    func testForTimeResumesCountingFromTheSameAnchorAfterUnchecking() {
        let done = forTime(checked: 10, finished: 120, now: 130)
        let resumed = forTime(checked: 9, now: 140)
        XCTAssertEqual(done.phase, .finished)
        XCTAssertEqual(resumed.phase, .running)
        XCTAssertEqual(resumed.clock, .countUp(since: anchor))
    }

    func testForTimeClampsNonsenseInput() {
        let content = forTime(cap: 0, checked: -3, total: -1, finished: nil, now: 0)
        XCTAssertEqual(content.counter, 0)
        XCTAssertEqual(content.counterTotal, 0)
        XCTAssertEqual(content.runEnd, at(1))
        XCTAssertEqual(forTime(finished: -9, now: 0).clock, .frozen(seconds: 0))
    }

    // MARK: - Zirkel

    private func circuit(
        restEnd: Double? = nil,
        restSeconds: Int = 60,
        rounds: Int = 0,
        total: Int = 5,
        finished: Bool = false,
        now: Double
    ) -> TimedLiveContent {
        TimedLiveContent.circuit(
            anchor: anchor, restEnd: restEnd.map(at), restSeconds: restSeconds,
            roundsCompleted: rounds, totalRounds: total, isFinished: finished, now: at(now)
        )
    }

    func testCircuitWorkCountsTheTrainingTimeUpAndShowsTheRunningRound() {
        let first = circuit(rounds: 0, now: 25)
        XCTAssertEqual(first.phase, .running)
        XCTAssertEqual(first.clock, .countUp(since: anchor))
        XCTAssertEqual(first.counter, 1)
        XCTAssertEqual(first.counterTotal, 5)
        XCTAssertNil(first.runEnd)
        XCTAssertNil(first.staleDate)
        XCTAssertEqual(circuit(rounds: 3, now: 400).counter, 4)
    }

    func testCircuitWorkNeverShowsMoreThanTheTotalRounds() {
        XCTAssertEqual(circuit(rounds: 5, now: 10).counter, 5)
        XCTAssertEqual(circuit(rounds: 99, now: 10).counter, 5)
    }

    /// Waehrend der Pause steht die zuletzt BEENDETE Runde da (wie im Player).
    func testCircuitRestCountsDownToTheRestEnd() {
        let content = circuit(restEnd: 160, restSeconds: 60, rounds: 2, now: 110)
        XCTAssertEqual(content.phase, .rest)
        XCTAssertEqual(content.clock, .countdown(start: at(100), end: at(160)))
        XCTAssertEqual(content.counter, 2)
        XCTAssertEqual(content.counterTotal, 5)
        XCTAssertEqual(content.staleDate, at(160 + margin))
    }

    func testCircuitRestContentIsStableWhileItRuns() {
        XCTAssertEqual(
            circuit(restEnd: 160, rounds: 2, now: 101),
            circuit(restEnd: 160, rounds: 2, now: 159.9)
        )
    }

    func testCircuitRestThatIsOverCountsAsWork() {
        XCTAssertEqual(circuit(restEnd: 160, rounds: 2, now: 160).phase, .running)
        XCTAssertEqual(circuit(restEnd: 160, rounds: 2, now: 500).phase, .running)
    }

    func testCircuitFinishedFreezesTheTrainingTime() {
        let content = circuit(rounds: 5, finished: true, now: 1_234.9)
        XCTAssertEqual(content.phase, .finished)
        XCTAssertEqual(content.clock, .frozen(seconds: 1_234))
        XCTAssertEqual(content.counter, 5)
    }

    func testCircuitClampsNonsenseRestLengths() {
        let content = circuit(restEnd: 30, restSeconds: 0, rounds: 1, now: 10)
        XCTAssertEqual(content.clock, .countdown(start: at(29), end: at(30)))
    }

    // MARK: - Zeitspannen

    /// Eine verkehrte Spanne darf nie bis in `Text(timerInterval:)` gelangen:
    /// `ClosedRange` bricht bei lower > upper ab.
    func testCountdownRangeIsAlwaysValid() {
        let inverted = Clock.countdown(start: at(100), end: at(50))
        XCTAssertEqual(inverted.countdownRange, at(100)...at(100))
        let normal = Clock.countdown(start: at(0), end: at(60))
        XCTAssertEqual(normal.countdownRange, at(0)...at(60))
        XCTAssertNil(Clock.countUp(since: anchor).countdownRange)
        XCTAssertNil(Clock.frozen(seconds: 5).countdownRange)
    }

    func testOverallRangeIsAlwaysValid() {
        let inverted = TimedLiveContent(phase: .running, clock: .frozen(seconds: 0), runStart: at(10), runEnd: at(5), counter: 0)
        XCTAssertEqual(inverted.overallRange, at(10)...at(10))
        let amrap = TimedLiveContent.amrap(anchor: anchor, capSeconds: 300, roundsCompleted: 0, now: at(1))
        XCTAssertEqual(amrap.overallRange, anchor...at(300))
    }

    // MARK: - Anzeige einer stehenden Uhr

    func testClockTextShowsZeroAsARealValue() {
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 0), "0:00")
        XCTAssertEqual(TimedLiveContent.clockText(seconds: -7), "0:00")
    }

    func testClockTextFormatsMinutesAndHours() {
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 9), "0:09")
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 754), "12:34")
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 3_599), "59:59")
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 3_600), "1:00:00")
        XCTAssertEqual(TimedLiveContent.clockText(seconds: 3_723), "1:02:03")
    }

    // MARK: - Codable

    /// ActivityKit gibt den Inhalt als JSON an den Widget-Prozess weiter.
    func testEveryClockSurvivesAJSONRoundTrip() throws {
        let contents = [
            TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 2, now: at(5)),
            TimedLiveContent.emom(anchor: anchor, totalMinutes: 8, exerciseNames: names, now: at(70)),
            TimedLiveContent.forTime(anchor: anchor, capSeconds: nil, checkedBoxes: 1, totalBoxes: 4, finishedElapsedSeconds: nil, now: at(5)),
            TimedLiveContent.forTime(anchor: anchor, capSeconds: 600, checkedBoxes: 4, totalBoxes: 4, finishedElapsedSeconds: 321, now: at(500)),
            TimedLiveContent.circuit(anchor: anchor, restEnd: at(90), restSeconds: 60, roundsCompleted: 1, totalRounds: 3, isFinished: false, now: at(40))
        ]
        for content in contents {
            let data = try JSONEncoder().encode(content)
            let decoded = try JSONDecoder().decode(TimedLiveContent.self, from: data)
            XCTAssertEqual(decoded, content)
        }
    }

    func testContentStaysFarBelowTheActivityKitSizeLimit() throws {
        // ActivityKit nimmt hoechstens 4 KB fuer Attribute plus Inhalt.
        let longNames = (0..<2).map { "Uebung mit einem sehr langen Namen Nummer \($0) " + String(repeating: "x", count: 60) }
        let content = TimedLiveContent.emom(anchor: anchor, totalMinutes: 20, exerciseNames: longNames, now: at(5))
        let data = try JSONEncoder().encode(content)
        XCTAssertLessThan(data.count, 1_024)
    }

    private typealias Clock = TimedLiveContent.Clock
}

// MARK: - Hintergrund-Audio

final class TimedLiveContentBackgroundAudioTests: XCTestCase {

    private let anchor = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func at(_ seconds: Double) -> Date { anchor.addingTimeInterval(seconds) }

    func testAMRAPNeedsAudioWhileRunningButNotAfterTheEnd() {
        XCTAssertTrue(TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 0, now: at(5)).needsAudioInBackground)
        XCTAssertFalse(TimedLiveContent.amrap(anchor: anchor, capSeconds: 600, roundsCompleted: 4, now: at(600)).needsAudioInBackground)
    }

    func testEMOMNeedsAudioWhileRunningButNotAfterTheEnd() {
        let names = ["A", "B"]
        XCTAssertTrue(TimedLiveContent.emom(anchor: anchor, totalMinutes: 4, exerciseNames: names, now: at(100)).needsAudioInBackground)
        XCTAssertFalse(TimedLiveContent.emom(anchor: anchor, totalMinutes: 4, exerciseNames: names, now: at(240)).needsAudioInBackground)
    }

    /// Ohne Limit signalisiert Auf Zeit nichts von selbst; mit Limit kommt der Endton.
    func testForTimeNeedsAudioOnlyWithACap() {
        let noCap = TimedLiveContent.forTime(anchor: anchor, capSeconds: nil, checkedBoxes: 1, totalBoxes: 5, finishedElapsedSeconds: nil, now: at(60))
        let withCap = TimedLiveContent.forTime(anchor: anchor, capSeconds: 600, checkedBoxes: 1, totalBoxes: 5, finishedElapsedSeconds: nil, now: at(60))
        let done = TimedLiveContent.forTime(anchor: anchor, capSeconds: 600, checkedBoxes: 5, totalBoxes: 5, finishedElapsedSeconds: 120, now: at(130))
        XCTAssertFalse(noCap.needsAudioInBackground)
        XCTAssertTrue(withCap.needsAudioInBackground)
        XCTAssertFalse(done.needsAudioInBackground)
    }

    /// Nur die Pause des Zirkels hat Signale (Piepser + Endton); die Arbeitsphase
    /// geht nur durch Eingaben in der App weiter.
    func testCircuitNeedsAudioOnlyDuringTheRest() {
        let work = TimedLiveContent.circuit(anchor: anchor, restEnd: nil, restSeconds: 60, roundsCompleted: 1, totalRounds: 3, isFinished: false, now: at(30))
        let rest = TimedLiveContent.circuit(anchor: anchor, restEnd: at(90), restSeconds: 60, roundsCompleted: 1, totalRounds: 3, isFinished: false, now: at(40))
        let done = TimedLiveContent.circuit(anchor: anchor, restEnd: nil, restSeconds: 60, roundsCompleted: 3, totalRounds: 3, isFinished: true, now: at(300))
        XCTAssertFalse(work.needsAudioInBackground)
        XCTAssertTrue(rest.needsAudioInBackground)
        XCTAssertFalse(done.needsAudioInBackground)
    }
}
