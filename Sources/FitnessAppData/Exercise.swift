#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class Exercise {
    /// **System-Name** — der deutsche Library-Eintrag-Name beim Adopt
    /// (z.B. "Bankdrücken"). Wird intern fuer Library-Lookups verwendet
    /// (ExerciseLibraryData.first(where: $0.name == name) liefert die
    /// Belastungsfaktoren + localizationKey). Der User soll diesen Wert
    /// NIE direkt sehen — Display-Pfad geht ueber `displayName`-Extension,
    /// die `customName` zuerst checkt und sonst auf den lokalisierten
    /// Catalog-Eintrag faellt.
    public var name: String

    /// Settings-Epic Phase 6 (EXLIB-07/09): stabile Rueckreferenz auf die
    /// `ExerciseTemplate`, von der diese Plan-Uebung adoptiert wurde. Wird
    /// beim Adoptieren gesetzt (`DayEditorView.addExercise(from:)`,
    /// `ActiveWorkoutView.addAdHocExercise(from:)`) und bleibt stabil, auch
    /// wenn der User die Vorlage spaeter umbenennt — anders als `name`, das
    /// nur ein Snapshot zum Adopt-Zeitpunkt ist. `nil` fuer Alt-Eintraege vor
    /// diesem Feld (unkritisch: Lookups fallen dann auf den Namens-Snapshot
    /// zurueck, exakt das bisherige Verhalten) oder wenn die Vorlage seither
    /// geloescht wurde. Bewusst ein `UUID`-Scalar statt `@Relationship` —
    /// siehe `ExerciseTemplate.id`-Dokumentation fuer die Begruendung
    /// (Loeschen einer Vorlage darf Logs/PRs strukturell nie mitloeschen).
    public var exerciseTemplateID: UUID?

    /// DEL-125: User-Custom-Override des Anzeigenamens.
    /// Nil = User hat den Namen NICHT geaendert, Display zeigt den lokalisierten
    /// System-Namen (via `name` -> Library-Lookup -> Catalog-Key).
    /// Non-nil = User hat im Editor einen eigenen Namen getippt (z.B. "Mein
    /// Bankdruecken-Variant") — gewinnt vor dem System-Namen in jedem
    /// Display-Pfad.
    public var customName: String?

    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var restSeconds: Int
    public var notes: String?
    public var suggestedWeight: Double?
    public var orderIndex: Int
    public var targetRir: Float
    public var weightReducedNote: String?
    /// True for cardio finishers — UI shows duration/level instead of kg/reps (F153).
    public var isCardio: Bool
    /// True for isometric/time-based exercises (Plank, Wall Sit) — reps record seconds (F161).
    public var isTimeBased: Bool

    /// DEL-049: Urlaubs-Modus / Equipment-Wechsel Snapshot.
    /// True wenn diese Uebung NICHT mehr im aktiven Plan-Slot steht, sondern
    /// als Fallback aufgehoben wird, weil sie durch eine Alternative ersetzt
    /// wurde (z.B. Bankdruecken im Gym-Plan → Liegestuetze im BW-Modus).
    /// Views nutzen `TrainingDay.activeExercises` statt `day.exercises`, um
    /// archivierte Eintraege aus der UI auszublenden. Die ExerciseLog-
    /// Relationship bleibt erhalten — wir verlieren also KEINE Historie.
    public var isArchived: Bool = false

    /// DEL-049: Wenn diese Uebung als Ersatz fuer eine andere eingefuegt wurde
    /// (Top-Down-Migration), zeigt das Property auf das Original. Beim
    /// Rueckweg ("Urlaub zu Ende") liest der Migrator dieses Feld, hebt das
    /// Original wieder aktiv und entsorgt die Ersatz-Uebung — inklusive
    /// Restore des letzten bekannten Arbeitsgewichts via Original-Logs.
    public var swappedFromOriginal: Exercise?

    // MARK: - DEL-052/053 Smart Auto-Progression

    /// Toggle pro Uebung — schaltet die automatische Gewichts-Steigerung an.
    /// Default `true`, sodass neue Uebungen sofort von der Logik profitieren.
    /// User kann es per ExerciseEditor pro Uebung ausschalten (z.B. fuer
    /// Cardio-Finisher, die manuell kalibriert werden).
    public var smartProgressionEnabled: Bool = true

    /// Inkrement-Stufe in kg fuer "Ziel erreicht → naechstes Mal hoeher".
    /// Default 2.5 kg (klassischer Plate-Pair). User-UI bietet 1.25 / 2.5 /
    /// 5.0 als Quick-Picker, das Feld erlaubt aber prinzipiell beliebige
    /// Doubles (custom Fractional-Plate-Setups).
    public var progressionStep: Double = 2.5

    /// True fuer Compound-Lifts (Bankdruecken, Kniebeuge, Kreuzheben,
    /// Schulterdruecken, Rudern). Steuert die RIR-Schwelle im
    /// `ProgressionEvaluator` — Compounds duerfen mit groesserem Puffer
    /// progressen (RIR 3), Isolation muss naeher ans Versagen (RIR 1).
    /// Default `false`; wird beim Insert aus `ExerciseTemplate.isSystemCompound`
    /// geseedet (siehe `DayEditorView.addExercise(from:)`).
    public var isCompound: Bool = false

    // MARK: - DEL-058 Cardio-Targets

    /// DEL-058: Ziel-Distanz in km fuer Cardio-Uebungen (z.B. Easy Run 5 km).
    /// Nil bei Strength + Time-Based. Wird als Placeholder im CardioSetRow
    /// angezeigt; der User kann beliebig daneben loggen.
    public var targetDistanceKm: Double?

    /// DEL-058: Ziel-Dauer in Minuten — vor allem fuer Easy/Long-Runs ohne
    /// fixe Distanz ("30 Min Easy"). Nil bei Strength.
    public var targetDurationMinutes: Int?

    /// DEL-155: Gewaehltes Cardio-Equipment (Laufband / Fahrrad / Ergometer /
    /// Rudergeraet / kein Geraet). Persistiert als String-RawValue fuer
    /// Lightweight-Migration; `nil` = noch nicht gesetzt (Bestandsdaten +
    /// frisch angelegte Uebungen) → Computed Property liefert `.none`.
    /// Nur fuer `isCardio`-Uebungen sinnvoll; Strength-Uebungen ignorieren es.
    public var cardioEquipmentRaw: String? = nil

    /// Computed Convenience — UI + PR-/Trend-Logik nutzen das typisierte Enum.
    /// Setter schreibt den rawValue; `.none` wird explizit persistiert (nicht
    /// nil), damit "User hat bewusst 'kein Equipment' gewaehlt" von "nie
    /// gesetzt" unterscheidbar bleibt — beide rendern aber gleich (`.none`).
    public var cardioEquipment: CardioEquipment {
        get { cardioEquipmentRaw.flatMap(CardioEquipment.init(rawValue:)) ?? .none }
        set { cardioEquipmentRaw = newValue.rawValue }
    }

    /// Paket 2 (Sportart-Unterscheidung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
    /// nur fuer `isCardio`-Uebungen relevant, nur `.running`/`.cycling`
    /// gueltig. `nil` = nicht festgelegt - wird NIE automatisch aus `name`
    /// zurueckgeraten (anders als `cardioEquipment` nicht auf `.none`
    /// defaulted, da es hier keinen sinnvollen neutralen Wert gibt).
    public var enduranceSportKindRaw: String? = nil

    public var enduranceSportKind: TrainingTypeKind? {
        get { enduranceSportKindRaw.flatMap(TrainingTypeKind.init(rawValue:)) }
        set { enduranceSportKindRaw = newValue?.rawValue }
    }

    // MARK: - DEL-159 Custom-Exercise-Metadaten

    /// DEL-159: Primaer-Muskel-Override pro Uebung. Vorher lag der Muskel NUR
    /// auf `ExerciseTemplate` — Custom-Uebungen hatten keinen, sodass der
    /// DayAnalyzer (Muscle-Focus via Library-Namens-Lookup) sie nicht
    /// einordnen konnte. Wird beim Custom-Anlegen aus dem Erstell-Sheet
    /// gesetzt. `nil` = nicht gesetzt → Analyzer faellt auf den Library-Lookup
    /// zurueck (System-Uebungen). Persistiert als String-RawValue.
    public var primaryMuscleRaw: String? = nil

    /// Typisierter Accessor. `nil` wenn kein Override gesetzt ist.
    public var primaryMuscle: MuscleGroup? {
        get { primaryMuscleRaw.flatMap(MuscleGroup.init(rawValue:)) }
        set { primaryMuscleRaw = newValue?.rawValue }
    }

    /// DEL-159: Equipment-Override pro Uebung (analog `primaryMuscle`). Vorher
    /// nur auf dem Template. Treibt die Picker-Anzeige + spaetere Filter.
    /// `nil` = nicht gesetzt.
    public var equipmentRaw: String? = nil

    /// Typisierter Accessor. `nil` wenn kein Override gesetzt ist.
    public var equipment: Equipment? {
        get { equipmentRaw.flatMap(Equipment.init(rawValue:)) }
        set { equipmentRaw = newValue?.rawValue }
    }

    /// Audit-Fix (Lean): war identisch in `SetRow.swift` und
    /// `ExerciseCard.swift` dupliziert. DEL-159-Override gewinnt, sonst
    /// Library-Lookup ueber den System-Namen.
    public var isBarbellExercise: Bool {
        if let equipment {
            return equipment == .barbell
        }
        return ExerciseLibraryData.all.first { $0.name == name }?.equipment == .barbell
    }

    /// DEL-200: Snapshot des Arbeitsgewichts VOR einer Deload-Woche.
    /// Non-nil = Deload aktiv für diese Übung; `DeloadManager.endDeload`
    /// schreibt den Wert zurück nach `suggestedWeight` und nullt das Feld.
    /// Default nil → Lightweight-Migration für Bestand.
    public var deloadOriginalWeight: Double? = nil

    /// DEL-083: Superset-Gruppe. Uebungen mit der gleichen UUID werden im
    /// Workout abwechselnd ausgefuehrt (A1, B1, A2, B2 statt A1, A2, A3,
    /// B1, B2, B3). Plan-Editor setzt die UUID via Swipe-Action "Link"; nil
    /// = standalone-Uebung wie bisher.
    public var supersetId: UUID?

    /// DEL-087: Welche Rolle hat dieser Lift im Workout-Flow? Default
    /// `.workingSet` (Standard-Arbeitssatz). Warmup + Cooldown werden vom
    /// Progressions-Algorithmus (`ProgressionApplicator`) geskippt und im
    /// UI grau-abgeschwaecht gerendert. Persistiert als String (Codable
    /// rawValue), damit SwiftData-Lightweight-Migration funktioniert.
    public var roleRaw: String = ExerciseRole.workingSet.rawValue

    /// Computed Convenience — UI nutzt das, statt mit rawValue zu hantieren.
    /// Setter mapped via rawValue zurueck.
    public var role: ExerciseRole {
        get { ExerciseRole(rawValue: roleRaw) ?? .workingSet }
        set { roleRaw = newValue.rawValue }
    }

    // MARK: - DEL-098 Training-Intelligence-Metadaten
    //
    // Statische Belastungsfaktoren pro Uebung — siehe DEL-098 / DEL-099 fuer
    // den Scoring-Algorithmus. Werden vom Picker-Pick aus dem
    // `ExerciseTemplate` propagiert (DayEditor + ActiveWorkoutView Ad-Hoc).
    // Defaults entsprechen "moderate Isolationsuebung", sodass Lightweight-
    // Migration bestehender Plan-Uebungen nicht durchgaengig 0 liefert.
    public var systemicFatigueFactor: Double = 0.35
    public var localMuscleDamageFactor: Double = 0.35
    public var cnsDemandFactor: Double = 0.25
    public var axialLoadFactor: Double = 0.20
    public var technicalComplexityFactor: Double = 0.30
    /// Persistiert als String fuer Lightweight-Migration; Convenience via
    /// `recoveryClass` Computed Property.
    public var recoveryClassRaw: String = ExerciseRecoveryClass.medium.rawValue

    public var recoveryClass: ExerciseRecoveryClass {
        get { ExerciseRecoveryClass(rawValue: recoveryClassRaw) ?? .medium }
        set { recoveryClassRaw = newValue.rawValue }
    }

    public var day: TrainingDay?

    /// P8 Stufe-2 (Session-Inhaltsvertrag, Wiederaufnahme-Isolation):
    /// stabile Instanz-Identitaet DIESER EINEN Exercise-Zeile — unabhaengig
    /// von Position (`orderIndex`, aendert sich durch Umsortieren) oder
    /// Vorlage (`exerciseTemplateID`, von mehreren Instanzen geteilt, z. B.
    /// Hauptsatz + Finisher derselben Uebung). Einziger Zweck:
    /// `SessionContentResolver` kann eine `TrainingDayContentSnapshot.
    /// ExerciseEntry` nach einer EXTERNEN Umsortierung des Tages waehrend
    /// einer offenen Session trotzdem auf GENAU dieses Live-Objekt
    /// zurueckfuehren, statt sich auf den inzwischen verschobenen
    /// `orderIndex` zu verlassen. Immer frisch per `UUID()` im `init`
    /// erzeugt, nie vom Aufrufer gesetzt oder nachtraeglich veraendert.
    /// `nil` nur fuer Alt-Zeilen vor diesem Feld — `SessionContentResolver`
    /// faellt dort auf die bisherige `exerciseTemplateID`+`orderIndex`-
    /// Bestmoeglichkeit zurueck.
    public var instanceID: UUID?

    /// swiftui-pro-Review (Deltiq-Abnahme): stabile `ForEach`/`List`-Identitaet.
    /// `persistentModelID` ist NICHT ueber eine Objekt-Lebenszeit hinweg
    /// `==`-stabil (ein frisch inserierter, noch nicht gespeicherter
    /// Datensatz hat eine temporaere ID, die sich beim naechsten Save gegen
    /// eine permanente austauscht — empirisch bestaetigt, siehe
    /// `DayEditorPersistenceTests`-Typ-Doku). `instanceID` ist dagegen ab
    /// dem `init` fix und wird nie veraendert — exakt dafuer gebaut (siehe
    /// oben). Nur fuer Alt-Zeilen ohne `instanceID` faellt dies auf
    /// `persistentModelID` zurueck.
    public var forEachIdentity: AnyHashable {
        instanceID.map(AnyHashable.init) ?? AnyHashable(persistentModelID)
    }

    /// DEL-051: HEILIGE HISTORIE. Frueher `.cascade` — beim Loeschen einer
    /// Plan-Uebung (manuell oder via Day/Plan-Cascade) gingen die ExerciseLog-
    /// Eintraege gleich mit weg, was Bestleistungen vernichtet hat. Jetzt
    /// `.nullify`: die Logs verlieren nur ihren `exercise`-Backref-Pointer,
    /// behalten aber ihren Snapshot in `exerciseNameSnapshot` /
    /// `exerciseIsCardioSnapshot` / `exerciseIsTimeBasedSnapshot` und bleiben
    /// fuer PR-Detection, Trophy-Room, Compound-Trends und alle anderen
    /// Statistik-Surfaces voll auswertbar.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    public var logs: [ExerciseLog] = []

    public init(
        name: String,
        exerciseTemplateID: UUID? = nil,
        customName: String? = nil,
        sets: Int = 3,
        repsMin: Int = 8,
        repsMax: Int = 12,
        restSeconds: Int = 90,
        notes: String? = nil,
        suggestedWeight: Double? = nil,
        orderIndex: Int = 0,
        targetRir: Float = 2.0,
        weightReducedNote: String? = nil,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        isArchived: Bool = false,
        swappedFromOriginal: Exercise? = nil,
        smartProgressionEnabled: Bool = true,
        progressionStep: Double = 2.5,
        isCompound: Bool = false,
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Int? = nil,
        supersetId: UUID? = nil,
        role: ExerciseRole = .workingSet,
        // DEL-098: defensive Defaults — "moderate Isolation".
        systemicFatigueFactor: Double = 0.35,
        localMuscleDamageFactor: Double = 0.35,
        cnsDemandFactor: Double = 0.25,
        axialLoadFactor: Double = 0.20,
        technicalComplexityFactor: Double = 0.30,
        recoveryClass: ExerciseRecoveryClass = .medium,
        // DEL-159: optionale Custom-Metadaten-Overrides.
        primaryMuscle: MuscleGroup? = nil,
        equipment: Equipment? = nil,
        day: TrainingDay? = nil
    ) {
        self.name = name
        self.exerciseTemplateID = exerciseTemplateID
        self.customName = customName
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.notes = notes
        self.suggestedWeight = suggestedWeight
        self.orderIndex = orderIndex
        self.targetRir = targetRir
        self.weightReducedNote = weightReducedNote
        self.isCardio = isCardio
        self.isTimeBased = isTimeBased
        self.isArchived = isArchived
        self.swappedFromOriginal = swappedFromOriginal
        self.smartProgressionEnabled = smartProgressionEnabled
        self.progressionStep = progressionStep
        self.isCompound = isCompound
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMinutes = targetDurationMinutes
        self.supersetId = supersetId
        self.roleRaw = role.rawValue
        self.systemicFatigueFactor = systemicFatigueFactor
        self.localMuscleDamageFactor = localMuscleDamageFactor
        self.cnsDemandFactor = cnsDemandFactor
        self.axialLoadFactor = axialLoadFactor
        self.technicalComplexityFactor = technicalComplexityFactor
        self.recoveryClassRaw = recoveryClass.rawValue
        self.primaryMuscleRaw = primaryMuscle?.rawValue
        self.equipmentRaw = equipment?.rawValue
        self.day = day
        self.instanceID = UUID()
    }
}
#endif
