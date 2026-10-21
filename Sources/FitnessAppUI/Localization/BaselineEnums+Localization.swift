#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// Localized display strings for the optional Start-Check's domain enums
/// (`FitnessAppCore/Baseline`). Eigene Datei statt Erweiterung von
/// `DomainEnums+Localization.swift` — die Baseline-Typen bilden einen
/// inhaltlich geschlossenen Block, analog zu `CoachConstants` als eigener
/// Datei fuer die zugehoerigen Schwellenwerte.

public extension PushUpVariant {
    var localizedName: LocalizedStringResource {
        switch self {
        case .standard:   LocalizedStringResource("baseline.push.variant.standard",   bundle: .fitnessAppUI)
        case .knees:      LocalizedStringResource("baseline.push.variant.knees",      bundle: .fitnessAppUI)
        case .incline:    LocalizedStringResource("baseline.push.variant.incline",    bundle: .fitnessAppUI)
        case .noCleanRep: LocalizedStringResource("baseline.push.variant.noCleanRep", bundle: .fitnessAppUI)
        }
    }
}

public extension PullVariant {
    var localizedName: LocalizedStringResource {
        switch self {
        case .pullUp:         LocalizedStringResource("baseline.pull.variant.pullUp",         bundle: .fitnessAppUI)
        case .assistedPullUp: LocalizedStringResource("baseline.pull.variant.assistedPullUp", bundle: .fitnessAppUI)
        case .latPulldown:    LocalizedStringResource("baseline.pull.variant.latPulldown",    bundle: .fitnessAppUI)
        }
    }
}

public extension CardioBaselineAnswer {
    var localizedName: LocalizedStringResource {
        switch self {
        case .canWalkBriskly10Min: LocalizedStringResource("baseline.cardio.answer.canWalkBriskly10Min", bundle: .fitnessAppUI)
        case .canJogEasy10Min:     LocalizedStringResource("baseline.cardio.answer.canJogEasy10Min",     bundle: .fitnessAppUI)
        case .runsRegularly:       LocalizedStringResource("baseline.cardio.answer.runsRegularly",       bundle: .fitnessAppUI)
        case .unsure:              LocalizedStringResource("baseline.cardio.answer.unsure",              bundle: .fitnessAppUI)
        }
    }
}

public extension SelfAssessmentAnswer {
    var localizedName: LocalizedStringResource {
        switch self {
        case .easy:             LocalizedStringResource("baseline.selfAssess.answer.easy",             bundle: .fitnessAppUI)
        case .canButStrenuous:  LocalizedStringResource("baseline.selfAssess.answer.canButStrenuous",  bundle: .fitnessAppUI)
        case .unsureNoCleanRep: LocalizedStringResource("baseline.selfAssess.answer.unsureNoCleanRep", bundle: .fitnessAppUI)
        case .skipped:          LocalizedStringResource("baseline.selfAssess.answer.skipped",          bundle: .fitnessAppUI)
        }
    }
}

public extension FirstWeekIntensity {
    var localizedName: LocalizedStringResource {
        switch self {
        case .veryEasy:              LocalizedStringResource("baseline.intensity.veryEasy.label",              bundle: .fitnessAppUI)
        case .comfortablyChallenging: LocalizedStringResource("baseline.intensity.comfortablyChallenging.label", bundle: .fitnessAppUI)
        case .knowMyBody:            LocalizedStringResource("baseline.intensity.knowMyBody.label",             bundle: .fitnessAppUI)
        }
    }

    var localizedBlurb: LocalizedStringResource {
        switch self {
        case .veryEasy:              LocalizedStringResource("baseline.intensity.veryEasy.blurb",              bundle: .fitnessAppUI)
        case .comfortablyChallenging: LocalizedStringResource("baseline.intensity.comfortablyChallenging.blurb", bundle: .fitnessAppUI)
        case .knowMyBody:            LocalizedStringResource("baseline.intensity.knowMyBody.blurb",             bundle: .fitnessAppUI)
        }
    }
}
#endif
