import Foundation

/// Reine, deterministische Herleitung von `BaselineBands` aus einer
/// `BaselineAssessment`. Keine Seiteneffekte, keine Persistenz, kein
/// Plan-Zugriff — die Anwendung auf einen echten Plan folgt erst, wenn ein
/// PlanAdapter existiert (Epic-Vorgehen Schritt 5, Stand heute: existiert
/// nicht). Bis dahin wird das Ergebnis nur gespeichert und erklaerend
/// angezeigt.
///
/// Erfindet NIE eine Last, NIE einen 1RM, NIE eine Fitnessnote und
/// veraendert NIE `ExperienceTrack` — die Rueckgabe ist ausschliesslich
/// `BaselineBands`, ein rein-informativer Typ ohne Gewichts- oder
/// Track-Feld.
public enum BaselineAssessmentEvaluator {

    /// Leitet fuer jede Bewegungsfamilie unabhaengig ein Band her.
    ///
    /// Sicherheitsabfrage zuerst: bei `safetyStatus == .flagged` lief kein
    /// Belastungstest (Epic: "Ja/Unsicher -> keinen Belastungstest, direkt
    /// zur Selbsteinschaetzung und konservativem Plan") — alle fuenf Baender
    /// fallen dann auf `.veryLow`, UNABHAENGIG von eventuell trotzdem
    /// vorhandenen Testwerten. Die UI soll bei `flagged` ohnehin keinen Test
    /// anbieten, der Evaluator verlaesst sich darauf aber nicht selbst.
    public static func evaluate(_ assessment: BaselineAssessment) -> BaselineBands {
        guard assessment.safetyStatus != .flagged else {
            return BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow, core: .veryLow, cardio: .veryLow)
        }
        return BaselineBands(
            push: evaluatePush(assessment),
            legs: evaluateLegs(assessment),
            pull: evaluatePull(assessment),
            core: evaluateCore(assessment),
            cardio: evaluateCardio(assessment)
        )
    }

    // MARK: - A. Push

    static func evaluatePush(_ assessment: BaselineAssessment) -> BaselineBand {
        guard let pushUp = assessment.pushUp else {
            return band(forSelfAssessment: assessment.pushSelfAssessment)
        }
        if pushUp.variant == .noCleanRep || pushUp.cleanReps <= CoachConstants.pushUpVeryLowMaxReps {
            return .veryLow
        }
        if pushUp.cleanReps <= CoachConstants.pushUpLowMaxReps { return .low }
        if pushUp.cleanReps <= CoachConstants.pushUpModerateMaxReps { return .moderate }
        return .high
    }

    // MARK: - B. Legs

    static func evaluateLegs(_ assessment: BaselineAssessment) -> BaselineBand {
        guard let chairSquat = assessment.chairSquat else {
            return band(forSelfAssessment: assessment.legsSelfAssessment)
        }
        if chairSquat.cleanReps <= CoachConstants.chairSquatVeryLowMaxReps { return .veryLow }
        if chairSquat.cleanReps <= CoachConstants.chairSquatLowMaxReps { return .low }
        if chairSquat.cleanReps <= CoachConstants.chairSquatModerateMaxReps { return .moderate }
        return .high
    }

    // MARK: - C. Pull

    /// Einzige Familie mit zwei unabhaengigen Test-Pfaden (Klimmzug-
    /// Varianten vs. Latzug) — ansonsten identisch zu den anderen Familien:
    /// fehlt ein Test, zaehlt nur die Selbsteinschaetzung.
    static func evaluatePull(_ assessment: BaselineAssessment) -> BaselineBand {
        guard let pull = assessment.pull else {
            return band(forSelfAssessment: assessment.pullSelfAssessment)
        }
        switch pull.variant {
        case .pullUp, .assistedPullUp:
            if pull.cleanReps <= CoachConstants.pullUpVeryLowMaxReps { return .veryLow }
            if pull.cleanReps <= CoachConstants.pullUpLowMaxReps { return .low }
            if pull.cleanReps <= CoachConstants.pullUpModerateMaxReps { return .moderate }
            return .high
        case .latPulldown:
            guard let rir = pull.rir else { return .unknown }
            if rir <= CoachConstants.latPulldownLowMaxRir { return .low }
            if rir <= CoachConstants.latPulldownModerateMaxRir { return .moderate }
            return .high
        }
    }

    // MARK: - D. Core (informativ, nie Vorbedingung fuer einen Plan)

    static func evaluateCore(_ assessment: BaselineAssessment) -> BaselineBand {
        guard let plank = assessment.plank else { return .unknown }
        if plank.seconds <= CoachConstants.plankVeryLowMaxSeconds { return .veryLow }
        if plank.seconds <= CoachConstants.plankLowMaxSeconds { return .low }
        if plank.seconds <= CoachConstants.plankModerateMaxSeconds { return .moderate }
        return .high
    }

    // MARK: - E. Cardio

    static func evaluateCardio(_ assessment: BaselineAssessment) -> BaselineBand {
        guard let cardio = assessment.cardio else { return .unknown }
        switch cardio.answer {
        case .unsure: return .unknown
        case .canWalkBriskly10Min: return .veryLow
        case .canJogEasy10Min: return .moderate
        case .runsRegularly: return .high
        }
    }

    // MARK: - Gemeinsamer Selbsteinschaetzungs-Mapper

    private static func band(forSelfAssessment answer: SelfAssessmentAnswer?) -> BaselineBand {
        guard let answer else { return .unknown }
        switch answer {
        case .easy: return .high
        case .canButStrenuous: return .moderate
        case .unsureNoCleanRep: return .veryLow
        case .skipped: return .unknown
        }
    }
}
