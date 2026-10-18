#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P6.3: Kurzer, überspringbarer Alltags-Rückblick (Dok03 §4) — ergänzt
/// `WorkoutSession.sessionFeeling` (deckt nur "Belastung" ab, pro Session) um
/// die vier fehlenden Fragen Häufigkeit/Dauer/Beschwerden/Ziel-noch-aktuell.
///
/// Bewusst EIGENSTÄNDIG und user-global, nicht an einen einzelnen
/// `TrainingPlan` gebunden: "Ist dein Ziel noch aktuell?" betrifft den
/// Nutzer, nicht eine einzelne Planinstanz, und mehrere gleichzeitig aktive
/// Pläne (Task #201/#202) hätten sonst keine eindeutige Zuordnung. Kein
/// zweiter Start-Check, keine Erweiterung von `BaselineCheckFlowView`.
///
/// Jede Antwort ist optional — `nil` heißt ausdrücklich "übersprungen", nie
/// "negativ beantwortet". `FrequencyFeedback`/`DurationFeedback` werden als
/// rawValue (`Int?`) gespeichert, analog zu `WorkoutSession.sessionFeeling`.
@Model
public final class PeriodicCheckIn {
    public var date: Date

    public var frequencyFeedbackRaw: Int?
    public var durationFeedbackRaw: Int?
    public var hadComplaints: Bool?
    public var complaintsNote: String?
    public var goalStillCurrent: Bool?
    /// Nachbesserung: periodenbezogene, echt überspringbare Belastungsfrage
    /// (siehe `ExertionFeedback`-Dokumentation) — additiv, ein Bestandseintrag
    /// ohne dieses Feld liest `nil` ("unbekannt"), nie einen erratenen Wert.
    public var exertionFeedbackRaw: Int?

    public init(
        date: Date = Date(),
        frequencyFeedback: FrequencyFeedback? = nil,
        durationFeedback: DurationFeedback? = nil,
        hadComplaints: Bool? = nil,
        complaintsNote: String? = nil,
        goalStillCurrent: Bool? = nil,
        exertionFeedback: ExertionFeedback? = nil
    ) {
        self.date = date
        self.frequencyFeedbackRaw = frequencyFeedback?.rawValue
        self.durationFeedbackRaw = durationFeedback?.rawValue
        self.hadComplaints = hadComplaints
        self.complaintsNote = complaintsNote
        self.goalStillCurrent = goalStillCurrent
        self.exertionFeedbackRaw = exertionFeedback?.rawValue
    }

    public var frequencyFeedback: FrequencyFeedback? {
        get { frequencyFeedbackRaw.flatMap(FrequencyFeedback.init(rawValue:)) }
        set { frequencyFeedbackRaw = newValue?.rawValue }
    }

    public var durationFeedback: DurationFeedback? {
        get { durationFeedbackRaw.flatMap(DurationFeedback.init(rawValue:)) }
        set { durationFeedbackRaw = newValue?.rawValue }
    }

    public var exertionFeedback: ExertionFeedback? {
        get { exertionFeedbackRaw.flatMap(ExertionFeedback.init(rawValue:)) }
        set { exertionFeedbackRaw = newValue?.rawValue }
    }
}
#endif
