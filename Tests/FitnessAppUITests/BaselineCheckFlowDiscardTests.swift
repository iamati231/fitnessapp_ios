#if canImport(SwiftUI)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): `BaselineCheckFlowView`'s
/// "Schliessen"-Button (`common.close`) rief bisher unbedingt `onFinish(nil);
/// dismiss()` auf -- Audit-Vorgabe "bereits bearbeitete Bewegungsfamilie" als
/// Entwurfs-Signal. `BaselineCheckFlowView.isDirty`/`familyStatus`/die
/// `FamilyMode`/`FamilyStatus`-Enums sind alle `private` (gleiches Muster wie
/// `NewCustomExerciseSheet.isDirty`), deshalb reproduziert dieser Test die
/// EXAKTE Formel aus der Produktionsdatei (`isDirty`, `familyStatus`, `status`)
/// gegen reine Werte mit lokal gespiegelten Enum-Faellen -- derselbe Ansatz wie
/// `MeasurementDoubleTapGuardTests`/`NewCustomExerciseSheetDiscardTests` fuer
/// dasselbe Problem (kein lebender SwiftUI-Graph fuer @State-Mutationen in
/// diesem Test-Setup, siehe `EditorDiscardSnapshotTests`-Dateikopf).
@available(iOS 17.0, macOS 14.0, *)
final class BaselineCheckFlowDiscardTests: XCTestCase {

    /// Spiegelt `BaselineCheckFlowView.FamilyMode` (push/legs/pull).
    private enum MirrorFamilyMode { case test, selfAssess, skip }
    /// Spiegelt `BaselineCheckFlowView.FamilyStatus`.
    private enum MirrorFamilyStatus: Equatable { case open, recorded, skipped }

    /// Reproduziert `BaselineCheckFlowView.status(mode:confirmed:selfAssess:)`.
    private func status(mode: MirrorFamilyMode, confirmed: Bool, selfAssess: SelfAssessmentAnswer?) -> MirrorFamilyStatus {
        switch mode {
        case .skip:       return .skipped
        case .test:       return confirmed ? .recorded : .open
        case .selfAssess: return selfAssess != nil ? .recorded : .open
        }
    }

    /// Reproduziert `BaselineCheckFlowView.isDirty`.
    private func isDirtyFormula(
        safetyStatus: SafetyStatus?,
        pushMode: MirrorFamilyMode, pushConfirmed: Bool, pushSelfAssess: SelfAssessmentAnswer?,
        legsMode: MirrorFamilyMode, legsConfirmed: Bool, legsSelfAssess: SelfAssessmentAnswer?,
        pullMode: MirrorFamilyMode, pullConfirmed: Bool, pullSelfAssess: SelfAssessmentAnswer?,
        coreSkipped: Bool, coreSecondsIsSet: Bool,
        cardioSkipped: Bool, cardioAnswerIsSet: Bool,
        intensity: FirstWeekIntensity
    ) -> Bool {
        let pushStatus = status(mode: pushMode, confirmed: pushConfirmed, selfAssess: pushSelfAssess)
        let legsStatus = status(mode: legsMode, confirmed: legsConfirmed, selfAssess: legsSelfAssess)
        let pullStatus = status(mode: pullMode, confirmed: pullConfirmed, selfAssess: pullSelfAssess)
        let coreStatus: MirrorFamilyStatus = coreSkipped ? .skipped : (coreSecondsIsSet ? .recorded : .open)
        let cardioStatus: MirrorFamilyStatus = cardioSkipped ? .skipped : (cardioAnswerIsSet ? .recorded : .open)

        return safetyStatus != nil
            || pushStatus != .open
            || legsStatus != .open
            || pullStatus != .open
            || coreStatus != .open
            || cardioStatus != .open
            || intensity != .comfortablyChallenging
    }

    private func defaults(
        safetyStatus: SafetyStatus? = nil,
        pushMode: MirrorFamilyMode = .test, pushConfirmed: Bool = false, pushSelfAssess: SelfAssessmentAnswer? = nil,
        legsMode: MirrorFamilyMode = .test, legsConfirmed: Bool = false, legsSelfAssess: SelfAssessmentAnswer? = nil,
        pullMode: MirrorFamilyMode = .test, pullConfirmed: Bool = false, pullSelfAssess: SelfAssessmentAnswer? = nil,
        coreSkipped: Bool = false, coreSecondsIsSet: Bool = false,
        cardioSkipped: Bool = false, cardioAnswerIsSet: Bool = false,
        intensity: FirstWeekIntensity = .comfortablyChallenging
    ) -> Bool {
        isDirtyFormula(
            safetyStatus: safetyStatus,
            pushMode: pushMode, pushConfirmed: pushConfirmed, pushSelfAssess: pushSelfAssess,
            legsMode: legsMode, legsConfirmed: legsConfirmed, legsSelfAssess: legsSelfAssess,
            pullMode: pullMode, pullConfirmed: pullConfirmed, pullSelfAssess: pullSelfAssess,
            coreSkipped: coreSkipped, coreSecondsIsSet: coreSecondsIsSet,
            cardioSkipped: cardioSkipped, cardioAnswerIsSet: cardioAnswerIsSet,
            intensity: intensity
        )
    }

    func testFreshFlowWithNothingRecordedIsNotDirty() {
        // (b) aus dem Brief: frisch geoeffnet, nichts beantwortet/getestet/
        // uebersprungen -> "Schliessen" dismisst direkt ohne Rueckfrage.
        XCTAssertFalse(defaults())
    }

    func testNavigatingAloneWithoutEnteringDataIsNotDirty() {
        // Epic-Vorgabe "nie ein Gate": reines Hin-und-Herklicken durch die
        // Uebersicht (hier simuliert durch exakt den Pristine-Zustand, da
        // `path` selbst NICHT Teil von `isDirty` ist) loest keine Rueckfrage
        // aus.
        XCTAssertFalse(defaults())
    }

    func testAnsweredSafetyGateAloneIsDirty() {
        XCTAssertTrue(defaults(safetyStatus: .clear))
    }

    func testConfirmedPushTestIsDirty() {
        // (a) aus dem Brief: eine bereits bearbeitete Bewegungsfamilie (hier:
        // Push-Test bestaetigt) macht dirty.
        XCTAssertTrue(defaults(pushMode: .test, pushConfirmed: true))
    }

    func testPushSelfAssessmentAnsweredIsDirty() {
        XCTAssertTrue(defaults(pushMode: .selfAssess, pushSelfAssess: .easy))
    }

    func testSkippedPullIsDirty() {
        XCTAssertTrue(defaults(pullMode: .skip))
    }

    func testRecordedCoreIsDirty() {
        XCTAssertTrue(defaults(coreSecondsIsSet: true))
    }

    func testSkippedCardioIsDirty() {
        XCTAssertTrue(defaults(cardioSkipped: true))
    }

    func testChangedIntensityAloneIsDirty() {
        XCTAssertTrue(defaults(intensity: .veryEasy))
    }

    func testModeSwitchedWithoutAnAnswerYetIsNotDirty() {
        // Ein blosser Wechsel auf "Selbst einschaetzen" OHNE tatsaechlich
        // ausgewaehlte Antwort ist noch keine erfasste Aenderung (`status`
        // bleibt `.open`) -- konsistent mit der "nie ein Gate"-Vorgabe.
        XCTAssertFalse(defaults(pushMode: .selfAssess, pushSelfAssess: nil))
    }
}
#endif
