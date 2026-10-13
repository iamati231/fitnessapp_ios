import Foundation

// MARK: - Herkunft + Sicherheitsstatus

/// Wie der Einstieg in den optionalen Start-Check gewaehlt wurde (die
/// initiale 3-Wege-Wahl "Jetzt testen" / "Selbst einschaetzen" / "Spaeter").
/// Einzelne Bewegungsfamilien koennen davon unabhaengig unterschiedlich
/// befuellt sein — z.B. Push-up gefuehrt getestet, Pull nur per
/// Selbsteinschaetzung (kein Equipment zuhause) — siehe die optionalen
/// `...SelfAssessment`-Felder auf `BaselineAssessment`.
public enum BaselineSource: String, Sendable, Codable, CaseIterable, Hashable {
    case guidedTest
    case selfAssessment
    case skipped
}

/// Ergebnis der Sicherheitsabfrage VOR jedem Belastungstest ("Hast du
/// aktuell Schmerzen, Schwindel, Brustschmerz oder eine aerztliche
/// Einschraenkung fuer Sport?"). `flagged` sperrt jeden Belastungstest
/// (siehe `BaselineAssessmentEvaluator.evaluate`) — die Abfrage selbst ist
/// keine medizinische Diagnose, nur ein Sicherheits-Gate vor Tests bis zur
/// Erschoepfung.
public enum SafetyStatus: String, Sendable, Codable, CaseIterable, Hashable {
    case clear
    case flagged
}

// MARK: - A. Oberkoerper druecken

public enum PushUpVariant: String, Sendable, Codable, CaseIterable, Hashable {
    case standard
    case knees
    case incline
    /// "Noch keine saubere Wiederholung" — zaehlt immer als unterste Stufe,
    /// unabhaengig von `cleanReps` (das dann 0 ist).
    case noCleanRep
}

public struct PushUpAssessment: Sendable, Codable, Equatable {
    public var variant: PushUpVariant
    public var cleanReps: Int

    public init(variant: PushUpVariant, cleanReps: Int) {
        self.variant = variant
        self.cleanReps = cleanReps
    }
}

// MARK: - B. Beine

/// 30-Sekunden-Stuhlkniebeuge. `durationSeconds` ist Teil des Ergebnisses
/// (nicht hartcodiert 30), damit ein abweichender Testlauf (z.B. manuell
/// unterbrochen) ehrlich dokumentiert bleibt statt stillschweigend als
/// vollstaendige 30s gezaehlt zu werden.
public struct ChairSquatAssessment: Sendable, Codable, Equatable {
    public var cleanReps: Int
    public var durationSeconds: Int

    public init(cleanReps: Int, durationSeconds: Int) {
        self.cleanReps = cleanReps
        self.durationSeconds = durationSeconds
    }
}

// MARK: - C. Ziehen

public enum PullVariant: String, Sendable, Codable, CaseIterable, Hashable {
    case pullUp
    case assistedPullUp
    case latPulldown
}

public struct PullAssessment: Sendable, Codable, Equatable {
    public var variant: PullVariant
    public var cleanReps: Int
    /// Nur bei `.latPulldown` gesetzt.
    public var loadKg: Double?
    /// Nur bei `.latPulldown` gesetzt — RIR direkt nach dem Satz. Das
    /// Projekt verbietet erfundene 1RM-Werte; RIR ist das einzige last-
    /// unabhaengige Signal, das dieser Test liefert (siehe
    /// `BaselineAssessmentEvaluator.evaluatePull`).
    public var rir: Double?

    public init(variant: PullVariant, cleanReps: Int, loadKg: Double? = nil, rir: Double? = nil) {
        self.variant = variant
        self.cleanReps = cleanReps
        self.loadKg = loadKg
        self.rir = rir
    }
}

// MARK: - D. Rumpf (optional, nie Vorbedingung)

public struct PlankAssessment: Sendable, Codable, Equatable {
    public var seconds: Int

    public init(seconds: Int) {
        self.seconds = seconds
    }
}

// MARK: - E. Cardio (nur bei Lauf-/Hybrid-Ziel gezeigt)

public enum CardioBaselineAnswer: String, Sendable, Codable, CaseIterable, Hashable {
    case canWalkBriskly10Min
    case canJogEasy10Min
    case runsRegularly
    case unsure
}

/// Selbstberichtete Cardio-Ausgangslage aus dem Onboarding-Check. Bewusst
/// getrennt von `CardioBaselineCalculator` (`FitnessAppCore/Analytics`):
/// jener leitet Werte aus bereits GELOGGTEN Laeufen her, hier geht es um
/// eine einmalige Selbstauskunft, bevor ueberhaupt eine Session existiert.
/// Ein optionaler Health-Referenzwert laeuft NICHT hier mit, sondern ueber
/// das bereits bestehende `UserBodyProfile.current5kReferenceSeconds`.
public struct CardioBaseline: Sendable, Codable, Equatable {
    public var answer: CardioBaselineAnswer

    public init(answer: CardioBaselineAnswer) {
        self.answer = answer
    }
}

// MARK: - Selbsteinschaetzung (immer verfuegbare Alternative zum Test)

public enum SelfAssessmentAnswer: String, Sendable, Codable, CaseIterable, Hashable {
    case easy
    case canButStrenuous
    case unsureNoCleanRep
    case skipped
}

/// "Wie anstrengend darf die erste Woche sein?" — reiner Nutzerwunsch,
/// unabhaengig von gemessenen/selbst eingeschaetzten Werten.
public enum FirstWeekIntensity: String, Sendable, Codable, CaseIterable, Hashable {
    case veryEasy
    case comfortablyChallenging
    case knowMyBody
}

// MARK: - Gesamtergebnis

/// Ergebnis des optionalen Start-Checks "Wo stehst du heute?". ALLE Felder
/// ausser `date`/`source`/`safetyStatus`/`version`/`desiredFirstWeekIntensity`
/// sind optional — ein Ergebnis darf teilweise ausgefuellt sein (z.B. nur
/// Push-up getestet, Rest uebersprungen). Liefert NIE eine medizinische
/// Diagnose, keinen 1RM, keine Fitnessnote — nur Rohdaten fuer
/// `BaselineAssessmentEvaluator`.
///
/// `version` ist fuer kuenftige Schema-Aenderungen an den Unterwerten
/// gedacht (z.B. ein neuer Test-Typ) — die Persistenzschicht
/// (`UserBodyProfile`) traegt zusaetzlich ihre eigene, von SwiftData
/// unabhaengige Default/Backfill-Migration (kein `VersionedSchema` im
/// Projekt, siehe `ExperienceTrackBackfill` als Vorbild).
public struct BaselineAssessment: Sendable, Codable, Equatable {
    public static let currentVersion = 1

    public var date: Date
    public var source: BaselineSource
    public var safetyStatus: SafetyStatus
    public var version: Int

    public var pushUp: PushUpAssessment?
    public var chairSquat: ChairSquatAssessment?
    public var pull: PullAssessment?
    public var plank: PlankAssessment?
    public var cardio: CardioBaseline?

    /// Fallback-Selbsteinschaetzung pro Bewegungsfamilie, wenn fuer DIESE
    /// Familie kein gefuehrter Test vorliegt (z.B. Pull ohne Equipment
    /// zuhause -> nur Selbsteinschaetzung statt Test). Wird vom Evaluator
    /// nur herangezogen, wenn das jeweilige Test-Feld `nil` ist.
    public var pushSelfAssessment: SelfAssessmentAnswer?
    public var legsSelfAssessment: SelfAssessmentAnswer?
    public var pullSelfAssessment: SelfAssessmentAnswer?

    public var desiredFirstWeekIntensity: FirstWeekIntensity

    public init(
        date: Date,
        source: BaselineSource,
        safetyStatus: SafetyStatus,
        version: Int = BaselineAssessment.currentVersion,
        pushUp: PushUpAssessment? = nil,
        chairSquat: ChairSquatAssessment? = nil,
        pull: PullAssessment? = nil,
        plank: PlankAssessment? = nil,
        cardio: CardioBaseline? = nil,
        pushSelfAssessment: SelfAssessmentAnswer? = nil,
        legsSelfAssessment: SelfAssessmentAnswer? = nil,
        pullSelfAssessment: SelfAssessmentAnswer? = nil,
        desiredFirstWeekIntensity: FirstWeekIntensity = .comfortablyChallenging
    ) {
        self.date = date
        self.source = source
        self.safetyStatus = safetyStatus
        self.version = version
        self.pushUp = pushUp
        self.chairSquat = chairSquat
        self.pull = pull
        self.plank = plank
        self.cardio = cardio
        self.pushSelfAssessment = pushSelfAssessment
        self.legsSelfAssessment = legsSelfAssessment
        self.pullSelfAssessment = pullSelfAssessment
        self.desiredFirstWeekIntensity = desiredFirstWeekIntensity
    }
}
