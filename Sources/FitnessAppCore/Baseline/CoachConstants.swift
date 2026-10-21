import Foundation

/// Zentrale Schwellenwerte fuer den optionalen Start-Check
/// (`BaselineAssessmentEvaluator`). Bewusst an einer Stelle gesammelt, statt
/// wie sonst in diesem Projekt ueblich direkt im jeweiligen Typ (siehe z.B.
/// `ComebackAdvisor.minimumGapDays`, `CardioFeasibilityCalculator.taperWeeks`)
/// — der Epic verlangt das hier explizit, weil mehrere, unabhaengig
/// voneinander kalibrierte Bewegungsfamilien denselben Evaluator
/// durchlaufen und die Zahlen als Gruppe ueberprueft werden sollen.
///
/// **Wichtig:** anders als z.B. `ComebackAdvisor.minimumGapDays` (aus einer
/// im Code dokumentierten, bewussten Kalibrierungsentscheidung hergeleitet)
/// sind diese Schwellen mangels eigener Studie neu gesetzte, plausible
/// Startwerte — grob an gaengigen Fitness-Assessment-Konventionen wie dem
/// 30-Sekunden-Stuhl-Test orientiert, aber keine klinisch validierten
/// Normwerte. Reine Richtgroessen fuer ein Coaching-Tool ohne
/// Gesundheitsfreigabe-Anspruch, explizit zur Ueberpruefung durch
/// Product/Coaching vorgesehen, nicht in Stein gemeisselt.
public enum CoachConstants {

    // MARK: Push-up (Liegestuetz-Varianten, alle gleich behandelt — die
    // Variantenwahl selbst ist bereits eine Vorab-Schwierigkeitsauswahl)

    /// `cleanReps <= 0` ODER Variante `.noCleanRep` -> immer `.veryLow`.
    public static let pushUpVeryLowMaxReps = 0
    public static let pushUpLowMaxReps = 4
    public static let pushUpModerateMaxReps = 14
    // > pushUpModerateMaxReps => .high

    // MARK: Stuhl-Kniebeuge (30 Sekunden, saubere Wiederholungen)

    public static let chairSquatVeryLowMaxReps = 2
    public static let chairSquatLowMaxReps = 7
    public static let chairSquatModerateMaxReps = 14
    // > chairSquatModerateMaxReps => .high

    // MARK: Plank (Sekunden, Deckel bei 60)

    public static let plankVeryLowMaxSeconds = 9
    public static let plankLowMaxSeconds = 19
    public static let plankModerateMaxSeconds = 39
    // > plankModerateMaxSeconds (bis 60) => .high

    // MARK: Ziehen — Klimmzug-Varianten (Wiederholungen)

    public static let pullUpVeryLowMaxReps = 0
    public static let pullUpLowMaxReps = 2
    public static let pullUpModerateMaxReps = 7
    // > pullUpModerateMaxReps => .high

    // MARK: Ziehen — Latzug (RIR als relatives Signal)
    //
    // Ohne 1RM/Koerpergewichts-Normalisierung sagt das absolute Testgewicht
    // nichts ueber die Staerke aus (Epic: "Tests duerfen keine Lasten
    // erfinden"). RIR nach den geforderten 8-12 Wiederholungen ist das
    // einzige last-unabhaengige Signal, das der Test liefert — nie
    // `.veryLow`, da der Test per Definition 8-12 Wiederholungen voraussetzt.
    public static let latPulldownLowMaxRir = 1.0
    public static let latPulldownModerateMaxRir = 3.0
    // > latPulldownModerateMaxRir => .high
}
