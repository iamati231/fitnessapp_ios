#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Exercise definition — system-seeded canonical lifts plus user-custom entries.
/// Backs the Exercise Library and the "swap exercise" flow.
@Model
public final class ExerciseTemplate {
    /// Settings-Epic Phase 6 (EXLIB-07/09): stabile Identitaet, unabhaengig
    /// vom (beim Custom-Template umbenennbaren) `name`. `Exercise`,
    /// `ExerciseLog` und `PersonalRecordEntry` referenzieren diese ID statt
    /// (nur) den Namen zu kopieren, damit ein Umbenennen Verlauf/PRs nicht
    /// mehr von der Bibliothek trennt. Bewusst ein einfacher `UUID`-Scalar,
    /// KEIN `@Relationship` — ein SwiftData-Relationship koennte eine
    /// Delete-Rule erzwingen; die harte Anforderung "Loeschen einer Vorlage
    /// darf niemals Logs/PRs mitloeschen" bleibt so strukturell garantiert,
    /// nicht nur per Konvention. Default-Literal `UUID()` sorgt dafuer, dass
    /// Lightweight-Migration jeder Bestandszeile ihre EIGENE, zufaellige ID
    /// zuweist (nicht allen dieselbe) — siehe `ExerciseTemplateIDBackfill`
    /// fuer den Ruecklink von Alt-Exercises/-Logs/-PRs auf diese IDs.
    public var id: UUID = UUID()
    public var name: String
    public var equipment: Equipment
    public var primaryMuscle: MuscleGroup
    public var isCustom: Bool
    public var difficultyLevel: DifficultyLevel
    /// True for the 5 canonical compound barbell lifts. Used by `CompoundLiftChart`
    /// to find logs via a flag-based join rather than a locale-dependent name (F137).
    public var isSystemCompound: Bool
    /// True for isometric/time-based exercises — reps records seconds held (F161).
    public var isTimeBased: Bool

    /// DEL-080: True fuer Cardio-Lifts. Wird vom DayEditor beim Picker-Pick
    /// auf `Exercise.isCardio` propagiert — sodass Ad-Hoc-Cardio-Einheiten
    /// (z.B. "Freier Lauf" am Ende eines Strength-Tags) automatisch korrekt
    /// klassifiziert sind. Default false → bestehende Library-Eintraege
    /// (Strength) bleiben unangetastet.
    public var isCardio: Bool = false

    /// DEL-111: i18n-Lookup-Key fuer den Anzeige-Namen. Optional. Wenn
    /// non-nil, soll `displayName` den Catalog-Eintrag dieses Keys
    /// rendern; sonst faellt es auf das rohe `name`-Feld zurueck. Custom-
    /// User-Uebungen tragen nil — wir lokalisieren keine Eigennamen.
    /// Format-Konvention: `exercise.name.{canonical}` (siehe xcstrings).
    public var localizationKey: String?

    /// DEL-111: True fuer Library-Seed-Eintraege; false fuer alle
    /// vom User selbst erstellten Custom-Uebungen. Erlaubt eine spaetere
    /// Locale-Switch-Migration, die nur die Library-Eintraege nachzieht.
    /// Default true ist defensiv: pre-DEL-111-Bestand vom LibrarySeeder
    /// wird damit korrekt als System-provided gekennzeichnet (Custom-
    /// User-Eintraege werden bei der LibrarySeeder-Erweiterung explizit
    /// mit `isSystemProvided: false` erzeugt).
    public var isSystemProvided: Bool = true

    // MARK: - DEL-098 Training-Intelligence-Metadaten
    //
    // Statische Belastungsfaktoren, die vom `LibrarySeeder` aus dem
    // `ExerciseTemplateSpec` propagiert und beim DayEditor-Picker-Pick
    // (`Exercise(from: template)`) auf die Plan-Uebung weitergereicht
    // werden. Defaults entsprechen "moderate Isolationsuebung" — damit
    // Lightweight-Migration der pre-DEL-098-Templates sinnvolle Startwerte
    // erhaelt, statt durchgaengig 0 zu liefern.
    public var systemicFatigueFactor: Double = 0.35
    public var localMuscleDamageFactor: Double = 0.35
    public var cnsDemandFactor: Double = 0.25
    public var axialLoadFactor: Double = 0.20
    public var technicalComplexityFactor: Double = 0.30
    /// Persistiert als String (rawValue), damit Lightweight-Migration auf
    /// pre-DEL-098-Daten funktioniert. Convenience-Accessor via `recoveryClass`.
    public var recoveryClassRaw: String = ExerciseRecoveryClass.medium.rawValue

    public var recoveryClass: ExerciseRecoveryClass {
        get { ExerciseRecoveryClass(rawValue: recoveryClassRaw) ?? .medium }
        set { recoveryClassRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        isCustom: Bool = false,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false,
        systemicFatigueFactor: Double = 0.35,
        localMuscleDamageFactor: Double = 0.35,
        cnsDemandFactor: Double = 0.25,
        axialLoadFactor: Double = 0.20,
        technicalComplexityFactor: Double = 0.30,
        recoveryClass: ExerciseRecoveryClass = .medium,
        localizationKey: String? = nil,
        isSystemProvided: Bool = true
    ) {
        self.id = id
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.isCustom = isCustom
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
        self.systemicFatigueFactor = systemicFatigueFactor
        self.localMuscleDamageFactor = localMuscleDamageFactor
        self.cnsDemandFactor = cnsDemandFactor
        self.axialLoadFactor = axialLoadFactor
        self.technicalComplexityFactor = technicalComplexityFactor
        self.recoveryClassRaw = recoveryClass.rawValue
        self.localizationKey = localizationKey
        self.isSystemProvided = isSystemProvided
    }
}
#endif
