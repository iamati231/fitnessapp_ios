import Foundation

/// Smart-Onboarding-Epic Phase 5 (PLAN_SUBSTITUTION_ENGINE.md): Kontext, den
/// eine `ReviewedSubstitutionRule` fuer ihr eigenes Gating braucht — bewusst
/// knapp gehalten (nur was die freigegebenen Regeln tatsaechlich pruefen),
/// kein genereller "alles mitgeben"-Container.
public struct SubstitutionContext: Sendable {
    public let goal: TrainingGoal
    public let experienceTrack: ExperienceTrack?

    public init(goal: TrainingGoal, experienceTrack: ExperienceTrack?) {
        self.goal = goal
        self.experienceTrack = experienceTrack
    }
}

/// Smart-Onboarding-Epic Phase 5: eine EINZELNE, manuell geprüfte
/// Katalog-zu-Katalog-Ersatzregel. Gerichtet (A -> B impliziert NICHT B -> A)
/// — siehe PLAN_SUBSTITUTION_ENGINE.md Abschnitt 1 fuer die Review-Matrix.
///
/// `buildPrescription` liefert `nil`, wenn die Regel in diesem Kontext NICHT
/// gilt (z.B. Kraft-Ziel bei einer Kraft-Anker-Uebung) — das ist eine
/// bewusste Ablehnung, kein Fehler. Liefert sie einen Wert, ist das die
/// VOLLSTAENDIGE neue `ExerciseSpec`; die Funktion entscheidet selbst, was
/// sie uebernimmt (Vorgabe: "No universal rep multiplier" — jede Regel
/// spezifiziert ihre eigene, review-te Vorschrift statt einer generischen
/// Transformation).
public struct ReviewedSubstitutionRule: Sendable {
    public let id: String
    public let sourceExerciseName: String
    public let targetExerciseName: String
    /// Niedrigere Werte = bevorzugt, wenn mehrere Regeln fuer dieselbe Quelle
    /// existieren (aktuell hat jede Quelle hoechstens eine Regel, Feld ist
    /// zukunftsoffen fuer spaetere mehrfache Kandidaten pro Quelle).
    public let priority: Int
    /// Smart-Onboarding-Epic Phase 5.3: manuell eingeschaetzte Staerke der
    /// Stimulus-/Technik-Abweichung (1 = gering, 2 = spuerbar) — Tie-Breaker
    /// bei der Varianten-Auswahl ("prefer fewer substitutions, then lower
    /// reviewed deviation cost"). Kein berechneter Wert, eine bewusste
    /// Review-Einschaetzung pro Regel.
    public let deviationCost: Int
    public let reasonKey: String
    public let buildPrescription: @Sendable (ExerciseSpec, SubstitutionContext) -> ExerciseSpec?

    public init(
        id: String,
        sourceExerciseName: String,
        targetExerciseName: String,
        priority: Int = 0,
        deviationCost: Int = 1,
        reasonKey: String,
        buildPrescription: @escaping @Sendable (ExerciseSpec, SubstitutionContext) -> ExerciseSpec?
    ) {
        self.id = id
        self.sourceExerciseName = sourceExerciseName
        self.targetExerciseName = targetExerciseName
        self.priority = priority
        self.deviationCost = deviationCost
        self.reasonKey = reasonKey
        self.buildPrescription = buildPrescription
    }
}

/// Smart-Onboarding-Epic Phase 5: die aktuell freigegebene Regel-Menge
/// (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 1). NUR diese 5 Regeln — die
/// Vorgabe nennt 7 Kandidaten, 2 davon sind nach Pruefung bewusst NICHT
/// umgesetzt (siehe Dokument): Kurzhantel-Bankdruecken -> "Kurzhantel-Floor-
/// Press" (Ziel existiert nicht im Katalog) und Doppel-Kettlebell-Push-Press
/// -> einarmig (unilaterale Satz-Semantik nicht implementiert).
public enum ReviewedSubstitutionCatalog {

    /// Stabile Version der aktuell freigegebenen Regel-Menge — Teil von
    /// `ResolvedPlanSelection` (Phase 5.3), damit eine spaetere
    /// Regel-Aenderung eine bereits gezeigte/gespeicherte Auswahl als
    /// veraltet erkennbar macht.
    public static let version = "substitution-rules-v1"

    public static let all: [ReviewedSubstitutionRule] = [

        // R2: Kniebeuge -> Goblet Squat. Nur bei moderatem/hohem Rep-Bereich
        // UND ausserhalb eines Kraft-Ziels — ein Goblet Squat kann die
        // Lastkapazitaet eines schweren Low-Rep-Backsquats nicht ersetzen.
        // Kosten 2: Freihantel-Compound -> Einzelimplement-Squat ist eine
        // spuerbare Stimulus-/Lastkapazitaets-Aenderung.
        ReviewedSubstitutionRule(
            id: "squat_to_goblet_squat_v1",
            sourceExerciseName: "Kniebeuge",
            targetExerciseName: "Goblet Squat",
            deviationCost: 2,
            reasonKey: "substitution.reason.squatToGobletSquat"
        ) { original, context in
            guard context.goal != .strength else { return nil }
            guard original.repsMax >= 10 else { return nil }
            return ExerciseSpec(
                name: "Goblet Squat",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        },

        // R3: Bulgarische Kniebeuge (KH) -> Ausfallschritte (KH). Gleiche
        // Equipment-Klasse, kein Kraft-Anker — Vorschrift unveraendert
        // uebernommen.
        ReviewedSubstitutionRule(
            id: "bulgarian_split_squat_to_lunge_v1",
            sourceExerciseName: "Bulgarische Kniebeuge (KH)",
            targetExerciseName: "Ausfallschritte (KH)",
            deviationCost: 1,
            reasonKey: "substitution.reason.bulgarianSplitSquatToLunge"
        ) { original, _ in
            ExerciseSpec(
                name: "Ausfallschritte (KH)",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        },

        // R4: Rudern vorgebeugt (Langhantel, Kraft-Anker) -> Chest Supported
        // Row (KH). NUR die beidarmige unterstuetzte Variante — "Rudern
        // einarmig (KH)" hat andere Satz-Semantik pro Seite und ist bewusst
        // NICHT Ziel dieser Regel.
        ReviewedSubstitutionRule(
            id: "barbell_row_to_chest_supported_row_v1",
            sourceExerciseName: "Rudern vorgebeugt",
            targetExerciseName: "Chest Supported Row (KH)",
            deviationCost: 2,
            reasonKey: "substitution.reason.barbellRowToChestSupportedRow"
        ) { original, context in
            guard context.goal != .strength else { return nil }
            return ExerciseSpec(
                name: "Chest Supported Row (KH)",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        },

        // R5: Klimmzüge (beide Griff-Varianten) -> Latzug (neutraler Griff).
        // Kollabiert bewusst auf EIN Ziel statt eine nicht verifizierbare
        // Griffbreiten-Unterscheidung zu behaupten.
        ReviewedSubstitutionRule(
            id: "pullup_to_cable_lat_pulldown_v1",
            sourceExerciseName: "Klimmzüge",
            targetExerciseName: "Latzug (neutraler Griff)",
            deviationCost: 2,
            reasonKey: "substitution.reason.pullupToCableLatPulldown"
        ) { original, _ in
            ExerciseSpec(
                name: "Latzug (neutraler Griff)",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        },
        ReviewedSubstitutionRule(
            id: "wide_pullup_to_cable_lat_pulldown_v1",
            sourceExerciseName: "Klimmzüge (weit)",
            targetExerciseName: "Latzug (neutraler Griff)",
            deviationCost: 2,
            reasonKey: "substitution.reason.pullupToCableLatPulldown"
        ) { original, _ in
            ExerciseSpec(
                name: "Latzug (neutraler Griff)",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        },

        // R6: Chest Supported Row (KH) -> Kabelrudern sitzend. Mehr Rumpf-
        // Stabilisation als die unterstuetzte Variante -> fuer Starter
        // ausgeschlossen ("no harder replacement merely to satisfy equipment").
        ReviewedSubstitutionRule(
            id: "chest_supported_row_to_seated_cable_row_v1",
            sourceExerciseName: "Chest Supported Row (KH)",
            targetExerciseName: "Kabelrudern sitzend",
            deviationCost: 1,
            reasonKey: "substitution.reason.chestSupportedRowToSeatedCableRow"
        ) { original, context in
            guard context.experienceTrack != .starter else { return nil }
            return ExerciseSpec(
                name: "Kabelrudern sitzend",
                sets: original.sets,
                repsMin: original.repsMin,
                repsMax: original.repsMax,
                restSeconds: original.restSeconds,
                targetRir: original.targetRir,
                role: original.role
            )
        }
    ]

    /// Schnell-Lookup: Regeln gruppiert nach Quellname, nach `priority`
    /// sortiert (niedrigster Wert zuerst = bevorzugt).
    public static let bySourceName: [String: [ReviewedSubstitutionRule]] = {
        Dictionary(grouping: all, by: \.sourceExerciseName)
            .mapValues { $0.sorted { $0.priority < $1.priority } }
    }()
}
