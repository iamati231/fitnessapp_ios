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

/// DEL-100: Trainings-Hauptziel fuer die Coaching-Engine UND (seit dem
/// Smart-Onboarding-Epic) fuer das Quiz-/Template-Matching
/// (`ProgramTemplate.targetGoals`, `QuizAnswers.goal`). Bis dahin gab es
/// hier zwei getrennte Enums (`TrainingGoal` + `GoalType` aus DEL-090) mit
/// einem verlustbehafteten Mapper dazwischen (`OnboardingView.mappedQuizGoal`,
/// jetzt entfernt) — konsolidiert auf dieses eine Enum.
///
/// **Abnehmen hat genau EINEN Fall: `.weightLoss`.** Eine erste Phase-2-
/// Fassung hatte zusaetzlich ein `.fatloss` (ehemals `GoalType.fatloss`)
/// als vermeintlich eigenstaendige Intensitaets-Achse angelegt — das
/// erzeugte zwei konkurrierende "Abnehmen"-Bedeutungen nebeneinander: alle
/// 20 Templates taggten `.fatloss`, aber Quiz-Auswahl/Persistenz nutzten
/// `.weightLoss`, wodurch Abnehmen-Nutzer nie einen Ziel-Matchbonus
/// bekamen. `.fatloss` wurde deshalb wieder entfernt, BEVOR es uebers
/// Quiz waehlbar war — betrifft also nur Template-Tags, nicht
/// `UserBodyProfile.trainingGoalRaw`. Trotzdem toleriert der Getter dort
/// den alten Rohwert "fatloss" (siehe Kommentar an `trainingGoal`), falls
/// ein bereits auf diesem Branch gelaufener Build ihn doch geschrieben hat.
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
    /// Smart-Onboarding-Epic: ehemals `GoalType.functional`, hierher
    /// konsolidiert.
    case functional
    /// Planung-&-Trainingsbegleitung-Epic, P2.2 (docs/PLANUNG_BEGLEITUNG_AUDIT.md,
    /// Konflikt 1, ENTSCHIEDEN) als eigenständige Zielkarte — unabhängig vom
    /// optionalen Laufcoach (`cardioCoachingEnabled`/`CardioGoal`) und von
    /// reinen Laufeinheiten im Plan (`TrainingTypeKind.running`/`.cycling`,
    /// bereits bestehend). Additiv ans Ende angehängt (RawValue-Stabilität,
    /// siehe Dateikommentar oben) — KEINE Migration, bestehende
    /// `trainingGoalRaw`-Werte bleiben unverändert lesbar.
    ///
    /// Review-Korrektur nach P2.2: `label`/`blurb` nennen bewusst WEDER
    /// "Laufen" NOCH "Radfahren" — welche Ausdauerform (Laufen/Radfahren/
    /// beides, `EnduranceModality` in `PlanningContext.swift`) gilt, ist
    /// eine eigene, spätere Entscheidung (Audit §5-Zustandstabelle), die
    /// dieses Ziel nicht vorwegnehmen darf. Ebenso KEINE automatische
    /// Kopplung an den Laufcoach — dieser Fall bleibt ausdrücklich optional
    /// und getrennt.
    ///
    /// Zusätzlich: diese Zielkarte ist aktuell NUR im Core/in Tests
    /// vorhanden — `DomainEnums+Localization.swift` blendet sie bewusst aus
    /// `TrainingGoal.currentlySelectableInUI` aus, bis ein tragfähiger
    /// Ziel→Plan-Pfad existiert (siehe dortiger Kommentar).
    case endurance

    public var label: String {
        switch self {
        case .hypertrophy: return "Muskelaufbau"
        case .strength:    return "Maximalkraft"
        case .hybrid:      return "Funktionell / Hybrid"
        case .weightLoss:  return "Abnehmen / Fettabbau"
        case .functional:  return "Funktionelle Fitness"
        case .endurance:   return "Ausdauer"
        }
    }

    public var symbol: String {
        switch self {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength:    return "scalemass.fill"
        case .hybrid:      return "figure.mixed.cardio"
        case .weightLoss:  return "flame.fill"
        case .functional:  return "figure.cooldown"
        case .endurance:   return "figure.run"
        }
    }

    public var blurb: String {
        switch self {
        case .hypertrophy: return "Volumen, Pump, sichtbares Muskelwachstum."
        case .strength:    return "Maximales 1RM, niedrige Reps, schwere Hauptlifts."
        case .hybrid:      return "Kraft + Ausdauer + Mobilität — alles fließt zusammen."
        case .weightLoss:  return "Kaloriendefizit, Muskelerhalt, Alltagsbewegung."
        case .functional:  return "Alltagstaugliche Bewegungsmuster, Mobilität, kein reiner Kraft- oder Muskelfokus."
        case .endurance:   return "Aerobe Leistungsfähigkeit und Grundlagenausdauer steigern, lange ruhige Einheiten plus gezielte Tempoarbeit."
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

    // MARK: - DEL-248 (Phase 4): Cardio-Coaching-Trigger

    /// Lauf-Kilometer dieser Woche > 120% der Vorwoche — direktes
    /// Cardio-Pendant zu `deloadRecommended` (dort bewusst nur Kraft,
    /// Laufvolumen braucht eine eigene Rechnung). Rangiert seit DEL-249 VOR
    /// `deloadRecommended`, nicht danach: anders als `reEntry`/
    /// `deloadRecommended` (die sich durch ihre Bedingungen praktisch
    /// gegenseitig ausschliessen) koennen beide bei einem Hybrid-Athleten
    /// gleichzeitig zutreffen - struktureller Schaden durch zu schnell
    /// gesteigertes Laufvolumen (Sehnen/Baender) braucht Wochen zum Heilen,
    /// ZNS-Ermuedung durch Krafttraining nur 1-2 Tage. Entscheidung via
    /// `CardioCoachingAdvisor.isVolumeSpike`.
    case cardioVolumeSpike

    // MARK: - DEL-198 Coach-Ausbau (mehr Dialog-Anlässe)

    /// Die letzte VOLLE Trainingswoche war die volumenstärkste der
    /// gesamten Historie (>= 4 Wochen Daten). Positiver Meilenstein —
    /// rangiert vor den generischen Post-Workout-Komplimenten.
    case volumeRecord

    /// Der Plan sieht einen langen Lauf vor, aber in den letzten 7 Tagen
    /// wurde keiner geloggt. Rangiert vor den generischen Post-Workout-
    /// Komplimenten. Entscheidung via `CardioCoachingAdvisor.isLongRunOverdue`.
    case cardioMissedLongRun
    /// Letzter lockerer Lauf war deutlich schneller als seine Zielpace
    /// (Tages-Ziel, nicht Profil-weit). Entscheidung via
    /// `CardioCoachingAdvisor.isJunkMiles`.
    ///
    /// **NICHT loeschen, obwohl aktuell kein Emitter existiert** (Review-
    /// Fund nach dem initialen DEL-248-Phase-4-Ship, analog zu `newPR`/
    /// `plateauDetected` oben): `PlanGenerator.cardioCandidates` setzt fuer
    /// Easy-/Tempo-Zonen nur `targetDurationMinutes`, nie `targetDistanceKm`
    /// - ohne Zieldistanz gibt es keine Zielpace zum Vergleich, der Trigger
    /// haette bei generierten Plaenen also praktisch nie eine Grundlage.
    /// Bewusst aus der Prioritaetskette entfernt statt mit einer pauschalen
    /// Pace-Annahme im Generator "gefixt" - das waere die falsche Abkuerzung.
    /// Die drei Catalog-Keys (`coaching.soft.cardioJunkMiles.*`) bleiben
    /// dreisprachig fertig liegen. Wieder verdrahten, sobald Phase 1
    /// (`current5kReferenceSeconds` + Pace-Zonen) echte, personalisierte
    /// Pace-Daten liefert.
    case cardioJunkMiles

    /// Letzte Körpermessung > 14 Tage her, obwohl der User das Feature
    /// aktiv nutzt (>= 2 Messungen vorhanden). Sanfter Mess-Reminder.
    case measurementOverdue
    /// User trackt aktiv Wasser (Einträge in den letzten 7 Tagen), hat
    /// gestern aber < 1,5 l geloggt. Sanfter Hydrations-Hinweis.
    case hydrationLow
}
