import Foundation

/// Gemeinsamer Laufcoaching-Setup-Entwurf (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt):
/// dieselben Felder, die `CardioGoalEditorView` bisher als fuenf separate `@State`-Vars hielt,
/// als EIN Wert - damit Onboarding, PlanBuilder und Settings denselben Entwurf, dieselbe
/// Validierung und dieselbe UI (`CardioCoachSetupFields`, FitnessAppUI) teilen koennen, statt
/// drei getrennte Implementierungen desselben Sachverhalts zu pflegen. Bleibt SwiftData-frei
/// (Core-Layer) - jede Aufrufstelle baut ihn aus ihrer eigenen Quelle (gespeichertes Profil
/// oder noch nicht persistierter Entwurf). `fiveKReferenceText` bleibt bewusst der rohe
/// MM:SS-Text (nicht ein geparstes `Int?`), identisch zu `CardioGoalEditorView`s bisherigem
/// `draftFiveKReferenceText`: Validierung/Fehleranzeige/Pace-Zonen-Hinweis laufen ueberall
/// identisch ueber `PaceCalculator.parseFiveKReferenceSeconds`.
public struct CardioCoachSetupDraft: Sendable, Hashable, Codable {
    public let goal: CardioGoal
    public let raceDate: Date?
    public let weeklyBaseVolumeKm: Double?
    public let maxHeartRateBpm: Int?
    public let fiveKReferenceText: String

    public init(
        goal: CardioGoal,
        raceDate: Date?,
        weeklyBaseVolumeKm: Double?,
        maxHeartRateBpm: Int?,
        fiveKReferenceText: String
    ) {
        self.goal = goal
        self.raceDate = raceDate
        self.weeklyBaseVolumeKm = weeklyBaseVolumeKm
        self.maxHeartRateBpm = maxHeartRateBpm
        self.fiveKReferenceText = fiveKReferenceText
    }

    /// Kein gespeichertes Profil, kein zuvor erfasster Entwurf (Onboarding-Startzustand) -
    /// `goal: .generalFitness` ist derselbe Default, den `UserBodyProfile.cardioGoal` fuer ein
    /// frisches Profil ohnehin liefert (siehe dortige Doku).
    public static let empty = CardioCoachSetupDraft(
        goal: .generalFitness, raceDate: nil, weeklyBaseVolumeKm: nil, maxHeartRateBpm: nil, fiveKReferenceText: ""
    )

    /// Geparste Referenzzeit (nil = leer ODER ungueltig - siehe `PaceCalculator.
    /// parseFiveKReferenceSeconds`-Doku fuer den Unterschied, den `CardioCoachSetupFields`
    /// separat als Fehlermeldung anzeigt).
    public var current5kReferenceSeconds: Int? {
        PaceCalculator.parseFiveKReferenceSeconds(fiveKReferenceText)
    }
}
