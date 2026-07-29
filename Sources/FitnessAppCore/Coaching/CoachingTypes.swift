import Foundation

/// DEL-100: Persoenlicher Kommunikations-Stil. Steuert den Tonfall, in dem
/// die App Insights, Recovery-Hinweise und Plateau-Warnungen kommuniziert.
///
///   * `.analytical` — Fakten, Zahlen, neutrales Reporting. Fuer Datenmenschen.
///   * `.motivating` — Positiv-bestaerkend. Fokussiert auf Erfolge + Erholung.
///   * `.strict` — Direkt, fordernd, unbequem. Klartext bei Plan-Abweichungen.
///
/// Persistiert als String (rawValue) auf `UserBodyProfile`, sodass Lightweight-
/// Migration der pre-DEL-100-Daten ohne Schema-Bruch funktioniert.
public enum CoachingTone: String, Codable, Sendable, CaseIterable {
    case analytical
    case motivating
    case strict

    public var label: String {
        switch self {
        case .analytical: return "Analytisch"
        case .motivating: return "Motivierend"
        case .strict:     return "Streng"
        }
    }

    public var symbol: String {
        switch self {
        case .analytical: return "chart.bar.fill"
        case .motivating: return "flame.fill"
        case .strict:     return "bolt.fill"
        }
    }

    public var blurb: String {
        switch self {
        case .analytical: return "Fakten & Daten. Neutrales Feedback zu Load und Progression."
        case .motivating: return "Positiv & bestärkend. Fokus auf Erfolge und Erholung."
        case .strict:     return "Direkt & fordernd. Klartext, wenn du vom Plan abweichst."
        }
    }
}

/// DEL-100: Trainings-Hauptziel fuer die Coaching-Engine. **Separat** vom
/// `GoalType` aus DEL-090 (Onboarding-Quiz fuer Plan-Matching), weil das
/// hier eine LANGFRISTIGE Praeferenz ist — der Quiz-Goal kann pro Cycle
/// abweichen (z.B. Bodybuilder, der vor einem Meet auf Strength umstellt).
public enum TrainingGoal: String, Codable, Sendable, CaseIterable {
    case hypertrophy
    case strength
    case hybrid
    /// DEL-206: Abnehmen/Fettabbau als eigenständige Coaching-Achse. Die
    /// Goal-Matrix gibt Weight-Loss-Usern andere Tages-Empfehlungen
    /// (z.B. "häng noch Cardio dran") als Aufbau-Usern ("ruh dich aus").
    /// RawValue-Stabilität: neue Cases NUR anhängen, nie umbenennen —
    /// der String persistiert in UserBodyProfile.trainingGoalRaw.
    case weightLoss

    public var label: String {
        switch self {
        case .hypertrophy: return "Muskelaufbau"
        case .strength:    return "Maximalkraft"
        case .hybrid:      return "Funktionell / Hybrid"
        case .weightLoss:  return "Abnehmen / Fettabbau"
        }
    }

    public var symbol: String {
        switch self {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength:    return "scalemass.fill"
        case .hybrid:      return "figure.mixed.cardio"
        case .weightLoss:  return "flame.fill"
        }
    }

    public var blurb: String {
        switch self {
        case .hypertrophy: return "Volumen, Pump, sichtbares Muskelwachstum."
        case .strength:    return "Maximales 1RM, niedrige Reps, schwere Hauptlifts."
        case .hybrid:      return "Kraft + Ausdauer + Mobilität — alles fließt zusammen."
        case .weightLoss:  return "Kaloriendefizit, Muskelerhalt, Alltagsbewegung."
        }
    }
}

/// DEL-100: Coaching-Kontext, in dem die App eine Insight-Message ausgeben
/// will. Wird vom Caller anhand der Trainings-Analyse (DEL-099 Recovery-
/// Scores etc.) gewaehlt. RawValue wird in den Localization-Key fuer die
/// Matrix `coaching.{context}.{tone}.{goal}` eingesetzt.
public enum CoachingContext: String, Sendable {
    /// Heutiger Plan-Tag ist ein Ruhetag.
    case restDay
    /// CNS-Score ueber Schwelle — schwere Compounds sind heute keine
    /// gute Idee.
    case cnsOverloaded
    /// Frische Bestleistung im letzten Workout.
    ///
    /// **DEL-242 — NICHT loeschen, obwohl kein Emitter existiert.** Keiner der
    /// drei Kontext-Waehler in `DashboardView` liefert diesen Case; die
    /// Auswahl passiert in `activeCoachingContext`. Es liegen aber je acht
    /// Catalog-Keys (`coaching.newPR.*` bzw. `coaching.plateauDetected.*`)
    /// dreisprachig fertig im Catalog und warten nur auf den Trigger.
    ///
    /// Wichtig: `dead_catalog_v3.py` wuerde diese Keys nach einem Loeschen
    /// NICHT als unbenutzt melden — sein Interpolations-Muster matcht nur das
    /// Praefix `coaching.`. Es gibt hier also kein Sicherheitsnetz, das den
    /// Fehler auffangen wuerde.
    ///
    /// Die Datenquelle fuer `newPR` liegt mit `PersonalRecordSync.recordPRs`
    /// bereits vor — Verdrahten ist die bessere Option als Loeschen.
    case newPR
    /// Stagnation ueber mehrere Wochen erkannt. Siehe `newPR`: kein Emitter,
    /// aber fertige Catalog-Keys und kein Audit-Netz.
    case plateauDetected

    // MARK: - DEL-206 Goal-Based Daily Coaching (Matrix-Kontexte)
    //
    // Tagesaktuelle Empfehlungen, die den Workout-State (heute/gestern)
    // mit dem TrainingGoal kreuzen. Goal-Matrix-Keys wie die P1-Warnungen:
    // `coaching.{context}.{tone}.{goal}` — ein Kraft-Morgen löst bei
    // Weight-Loss "häng Cardio dran" aus, bei Muscle-Gain "ruh dich aus".

    /// Heute vor 13:00 bereits ein Kraft-Workout abgeschlossen.
    case morningStrengthDone
    /// Heute vor 13:00 bereits ein reines Cardio-Workout abgeschlossen.
    case morningCardioDone
    /// Gestern hohes Volumen (>= 20 Sätze oder > 90 Min) — Recovery-Tag.
    case highFatigueYesterday

    // MARK: - DEL-167 Soft-Coaching (Plauder-Modus)
    //
    // Sekundäre Prioritätsstufe — werden nur ausgewertet, wenn KEINE der
    // P1-Warnungen oben greift. Liefern wohlwollende, kontextuelle
    // Kommentare zum jüngsten Training. Catalog-Keys folgen dem Schema
    // `coaching.soft.{context}.{tone}` (ohne Goal-Achse, weil die Soft-
    // Insights goal-agnostisch sind).

    /// Gestrige Session hatte eine signifikante Cardio-Distanz.
    case postCardio
    /// Gestrige Session hatte ein hohes Strength-Volumen.
    case postVolume
    /// Hohe Trainings-Frequenz in den letzten 7 Tagen (Konsistenz-Streak).
    case streak
    /// Heute steht ein geplantes (kein Rest-)Training an.
    case planPreview
    /// Länger nicht trainiert — sanfter Wiedereinstiegs-Hinweis.
    case reEntry

    /// DEL-211: Gestern trainiert (BELIEBIGE reale Session, auch spontane
    /// Workouts unterhalb der postVolume-/postCardio-Schwellen). Schließt
    /// die Lücke "User trainierte gestern moderat, Coach tut als wäre
    /// nichts gewesen und ruft den Plan-Tag aus". Rangiert vor planPreview.
    case trainedYesterday

    /// DEL-177: Länger als 30 Tage kein CSV-Export erstellt (oder noch nie,
    /// obwohl der User schon eine Weile trainiert). Niedrigste Priorität —
    /// nur P2-Fallback, wenn keine der Trainings-Insights greift. Catalog
    /// folgt dem gleichen Soft-Schema `coaching.soft.backupOverdue.{tone}`.
    case backupOverdue

    /// DEL-196: Overreaching-Muster erkannt — drei Wochen steigende
    /// Trainings-Last (>= +20%) PLUS mindestens zwei subjektiv harte
    /// Sessions (Feeling >= 4) in den letzten 14 Tagen. Höchste Soft-
    /// Priorität: eine Deload-Empfehlung ist gesundheitsrelevanter als
    /// jedes Post-Workout-Kompliment. Entscheidung via `DeloadAdvisor`.
    case deloadRecommended

    // MARK: - DEL-198 Coach-Ausbau (mehr Dialog-Anlässe)

    /// Die letzte VOLLE Trainingswoche war die volumenstärkste der
    /// gesamten Historie (>= 4 Wochen Daten). Positiver Meilenstein —
    /// rangiert vor den generischen Post-Workout-Komplimenten.
    case volumeRecord
    /// Letzte Körpermessung > 14 Tage her, obwohl der User das Feature
    /// aktiv nutzt (>= 2 Messungen vorhanden). Sanfter Mess-Reminder.
    case measurementOverdue
    /// User trackt aktiv Wasser (Einträge in den letzten 7 Tagen), hat
    /// gestern aber < 1,5 l geloggt. Sanfter Hydrations-Hinweis.
    case hydrationLow
}
