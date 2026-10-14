#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Singleton-style profile entity. Only one row should exist per app install —
/// caller-side responsibility (SwiftData has no manual singleton constraint).
/// Mirrors the `user_body_profile` Room table.
@Model
public final class UserBodyProfile {
    public var birthDate: Date
    public var heightCm: Double
    public var profile: BodyFormulaProfile
    /// Target body weight entered during onboarding (Fat-Loss goal). Nil if not set (F153).
    public var goalWeightKg: Double?
    /// Training location chosen in onboarding — drives plan recommendations (F154).
    public var environment: EnvironmentType

    /// DEL-141: Optionaler Vorname für Personalisierung. Wird im Onboarding
    /// als "Wie dürfen wir dich nennen?"-Feld erfasst (User kann skippen).
    /// Dashboard-Greeting nutzt ihn falls vorhanden ("Guten Morgen, Atakan"),
    /// sonst Fallback auf generische Tageszeit-Begrüßung. Nie required —
    /// nil-Lightweight-Migration für pre-DEL-141-Profile.
    public var firstName: String?

    /// DEL-100: Persoenlicher Coaching-Stil. Persistiert als String, sodass
    /// pre-DEL-100-Bestand via Default-Wert lightweight migriert wird.
    public var coachingToneRaw: String = CoachingTone.analytical.rawValue

    /// DEL-100: Langfristiges Trainings-Hauptziel. Steuert zusammen mit
    /// `coachingTone` die Matrix-Lookup-Keys der Coaching-Engine.
    public var trainingGoalRaw: String = TrainingGoal.hybrid.rawValue

    /// DEL-109: Dashboard-Widget-Konfiguration. Speichert die rawValues
    /// aller AKTIVEN Widgets in der gewuenschten Render-Reihenfolge.
    /// Nicht enthaltene `DashboardWidgetType`-Cases sind versteckt.
    /// Default = `DashboardWidgetType.defaultOrder` (historische Layout-
    /// Reihenfolge) — Lightweight-Migration der pre-DEL-109-Profile
    /// erbt damit das volle Set, identisches Nutzer-Erlebnis ohne
    /// "wo sind meine Cards"-Panik.
    public var activeDashboardWidgetsRaw: [String] = DashboardWidgetType.defaultOrder.map { $0.rawValue }

    /// DEL-132 (Phase 1): Hero-Metric-Slots fuer die Top-Reihe des
    /// Dashboards. Length 0-3. Identisches Pattern wie
    /// `activeDashboardWidgetsRaw`: rawValues in Render-Reihenfolge,
    /// nicht-enthaltene Cases sind versteckt, Length-0 versteckt die
    /// ganze Hero-Reihe. Default = `HeroMetricType.defaultOrder`
    /// (Weight + BodyFat + FFMI) — pre-Phase-1-Profile bekommen via
    /// Lightweight-Migration das identische 3er-Set, kein visueller
    /// Bruch fuer Bestand.
    public var heroMetricSlotsRaw: [String] = HeroMetricType.defaultOrder.map { $0.rawValue }

    /// DEL-170: Equipment-Präferenzen des Users (Multi-Select). Steuert die
    /// Variant-Auswahl bei Templates mit `equipmentVariants` (z.B. Hybrid-
    /// Pläne in Barbell-/Dumbbell-Version). RawValues von `Equipment`.
    /// Default leer — Lightweight-Migration: pre-DEL-170-Profile kommen mit
    /// `[]` an. Plan-Matcher behandelt leeres Set wie "User hat das nicht
    /// gepflegt" und nutzt die Standard-Variante (template.days).
    public var equipmentPreferencesRaw: [String] = []

    /// Smart-Onboarding-Epic Phase 2 (PLAN_EQUIPMENT_MATCHING_AUDIT.md):
    /// dreiwertige Verfuegbarkeit je `EquipmentItem` (Zubehoer/Stationen,
    /// zusaetzlich zu den groben `equipmentPreferences` oben). Zwei
    /// getrennte RawValue-Listen statt einer einzelnen mit Status-Suffix —
    /// gleiches "flaches Feld-pro-Wert"-Prinzip wie bei den Baseline-Feldern
    /// unten, jedes unabhaengig CSV-exportierbar. Ein Item in KEINER der
    /// beiden Listen ist `.unknown` (siehe `equipmentProfile`-Accessor) —
    /// das deckt sowohl ein brandneues Item als auch ein komplett
    /// unberuehrtes Bestandsprofil (beide Listen leer) automatisch und
    /// korrekt ab: "eine leere alte Auswahl bleibt unbekannt". Absichtlich
    /// KEIN Backfill aus `equipmentPreferencesRaw`: dessen Eintraege konnten
    /// vor Phase 3 aus einer ungeprueften Environment-Vorbelegung stammen
    /// (Audit Abschnitt 5.1/5.2), eine Uebernahme in das neue Modell waere
    /// exakt die "falsche Sicherheit aus unvollstaendigen/fraglichen
    /// Altdaten", die diese Phase vermeiden soll.
    public var equipmentAvailableItemsRaw: [String] = []
    public var equipmentUnavailableItemsRaw: [String] = []

    /// Stueckzahl je `EquipmentItem`, nur fuer Items mit `supportsCount ==
    /// true` befuellt. Encoding `"itemRawValue:count"` statt eines
    /// `[String: Int]`-Feldes — konsistent mit dem Array-RawValue-Muster
    /// der uebrigen Felder hier, kein neuer Persistenz-Typ noetig. Ein
    /// fehlender Eintrag bedeutet "nicht erfasst", nicht "0".
    public var equipmentItemCountsRaw: [String] = []

    /// Smart-Onboarding-Epic Phase 3: ob die Equipment-Erfassung oben
    /// EXPLIZIT als vollstaendig bestaetigt wurde (ueber
    /// `confirmEquipmentProfileComplete()` oder "Nur Koerpergewicht").
    /// Default `false` — sowohl fuer ein brandneues Profil als auch fuer
    /// jedes Bestandsprofil vor dieser Phase (Lightweight-Migration).
    /// Steuert NICHT die Tri-State-Semantik selbst (die lebt rein in den
    /// drei Feldern oben, siehe `equipmentProfile`), sondern ob die aeltere
    /// `equipmentPreferences` (DEL-170) bereits aus dem neuen Modell
    /// synchronisiert werden darf — vor der ersten Bestaetigung bliebe eine
    /// Synchronisierung sonst eine verfruehte, moeglicherweise unvollstaendige
    /// Equipment-Aussage (siehe `confirmEquipmentProfileComplete`).
    public var equipmentProfileConfirmedComplete: Bool = false

    /// DEL-203: Wochenziel für den Trainings-Streak (1-7 Workouts/Woche).
    /// Der Kalender-Streak (DEL-197) zählt nur Wochen, die dieses Ziel
    /// erfüllen. Default 1 = altes "mindestens ein Workout"-Verhalten —
    /// Lightweight-Migration für Bestand.
    public var weeklyWorkoutGoal: Int = 1

    /// DEL-250: Master-Schalter fuer die Cardio-/Lauf-Ziel-Sektion im
    /// Profil-Editor. Default `false` — Bestandsnutzer (Update von einer
    /// Version ohne DEL-250) sehen die Sektion eingeklappt, keine der
    /// folgenden Felder wird angezeigt oder ausgewertet, bis der User aktiv
    /// zustimmt. Kein Coaching-Trigger liest dieses Feld aktuell (DEL-250
    /// ist bewusst auf den Profil-Editor beschraenkt) — rein UI-Zustand.
    public var cardioCoachingEnabled: Bool = false

    /// DEL-250: Lauf-Ziel-Kategorie. Persistiert als String, sodass
    /// pre-DEL-250-Bestand via Default-Wert lightweight migriert wird
    /// (identisches Muster wie `coachingToneRaw`/`trainingGoalRaw`).
    public var cardioGoalRaw: String = CardioGoal.generalFitness.rawValue

    /// DEL-250: Ziel-Renn-Datum. Echt optional (nicht jedes `cardioGoal`
    /// hat ein konkretes Renn-Datum, z.B. "Allgemeine Fitness") — nil heisst
    /// "kein Renn-Datum gesetzt", nicht "unbekannt/Fehler". Ergaenzt trotz
    /// Fehlens im urspruenglichen Ticket-Text: ohne dieses Feld bliebe der
    /// zurueckgestellte `cardioRaceWeek`-Coaching-Trigger dauerhaft unbaubar.
    public var cardioRaceDate: Date?

    /// DEL-250: Referenz-Zeit ueber 5 km in Sekunden — Grundlage fuer die
    /// abgeleiteten Pace-Zonen (`PaceZoneCalculator`). Bewusst eine
    /// ZEIT-ueber-Referenzdistanz statt einer direkt eingegebenen Pace:
    /// praeziser fuer eine spaetere `cardioProgressionEarned`-Verfeinerung.
    /// Nil = kein Referenzwert gepflegt (z.B. "Allgemeine Fitness"-Ziel
    /// ohne konkrete Zeitmessung).
    public var current5kReferenceSeconds: Int?

    /// DEL-250: "Start-Laufvolumen" (km/Woche) — optionale Metrik aus dem
    /// Ticket. Rein deskriptiv, aktuell kein Trigger-Verbraucher (der
    /// bestehende `cardioVolumeSpike`-Trigger misst tatsaechlich geloggte
    /// Wochen-KM, keinen statischen Profil-Wert).
    public var weeklyBaseVolumeKm: Double?

    /// DEL-250: Maximalpuls (bpm) — optionale Metrik aus dem Ticket. Rein
    /// deskriptiv, kein HR-basierter Coaching-Trigger existiert aktuell.
    public var maxHeartRateBpm: Int?

    /// Handoff "Lauf-Coaching - Machbarkeits-Check": Fingerprint aus
    /// Ziel+Renn-Datum+Wochenvolumen, fuer den die Vorschlags-Karte auf
    /// Profil/Dashboard/Plan-Tab NICHT mehr erscheinen soll — entweder weil
    /// der Nutzer sie explizit verworfen/das Ziel behalten hat, oder weil er
    /// den Vorschlag bereits angenommen hat (siehe
    /// `CardioFeasibilityCalculator.suppressionFingerprint`). Bewusst ein
    /// SwiftData-Feld statt `@AppStorage` — ein reiner `@AppStorage`-Key
    /// ueberlebt keine Neuinstallation/Restore (dieselbe Luecke, die
    /// `deload_until` frueher hatte, siehe DEL-238-Kommentar in
    /// `DashboardView`); dieses Feld wandert stattdessen normal im Backup mit.
    /// Nil = noch nie unterdrueckt worden.
    public var cardioFeasibilityDismissedFingerprint: String?

    /// Smart-Onboarding-Epic: verhaltens-/pausenbasierte Track-Einstufung
    /// (Einstieg/Wiedereinstieg/volle Automatik) — separat von
    /// `coachingTone`/`trainingGoal`. Nil = noch nicht hergeleitet (z. B.
    /// Bestandsnutzer vor diesem Update). `ExperienceTrackBackfill` befuellt
    /// es einmalig aus der Trainingshistorie; die Onboarding-Flow-Frage
    /// (spaetere Phase) ueberschreibt es danach mit einer expliziten Antwort.
    /// Bewusst `String?` statt eines defaulteten Strings wie bei
    /// `coachingToneRaw`: ein drittes, neutrales "nicht gesetzt"-Signal wird
    /// gebraucht, damit der Backfill genau einmal greift.
    public var experienceTrackRaw: String?

    // MARK: - Start-Check (optionaler Baseline-Check im Onboarding)
    //
    // Flaches Feld-pro-Wert-Muster (wie bei den Cardio-Feldern oben), nicht
    // ein JSON-Blob: das Projekt hat genau einen Blob-Praezedenzfall
    // (`TrainingPlan.generatorInputRaw`, ein einmal geschriebener/wieder
    // eingelesener Wizard-Input) — hier dagegen soll jedes Einzelfeld
    // unabhaengig CSV-exportierbar und `nil`-faehig sein, exakt wie bei den
    // Cardio-Feldern. Alle Felder bleiben unabhaengig optional — ein Check
    // darf teilweise ausgefuellt sein (z. B. nur Push-up getestet).
    // Bestandsnutzer ohne Check: alles `nil`, kein Backfill/Migration
    // erzwungen (Epic: "Alte Nutzer: keine Baseline = unknown").

    public var baselineDate: Date?
    public var baselineSourceRaw: String?
    public var baselineSafetyStatusRaw: String?
    public var baselineVersion: Int?

    public var baselinePushUpVariantRaw: String?
    public var baselinePushUpCleanReps: Int?

    public var baselineChairSquatCleanReps: Int?
    public var baselineChairSquatDurationSeconds: Int?

    public var baselinePullVariantRaw: String?
    public var baselinePullCleanReps: Int?
    public var baselinePullLoadKg: Double?
    public var baselinePullRir: Double?

    public var baselinePlankSeconds: Int?

    public var baselineCardioAnswerRaw: String?

    public var baselinePushSelfAssessmentRaw: String?
    public var baselineLegsSelfAssessmentRaw: String?
    public var baselinePullSelfAssessmentRaw: String?

    public var baselineDesiredFirstWeekIntensityRaw: String?

    /// Convenience-Accessor mit Default-Fallback, falls jemand einen
    /// invaliden String reinschreibt.
    public var cardioGoal: CardioGoal {
        get { CardioGoal(rawValue: cardioGoalRaw) ?? .generalFitness }
        set { cardioGoalRaw = newValue.rawValue }
    }

    /// Convenience-Accessor mit Default-Fallback, falls jemand einen
    /// invaliden String reinschreibt.
    public var coachingTone: CoachingTone {
        get { CoachingTone(rawValue: coachingToneRaw) ?? .analytical }
        set { coachingToneRaw = newValue.rawValue }
    }

    public var trainingGoal: TrainingGoal {
        get {
            // Smart-Onboarding-Epic: "fatloss" war kurzzeitig ein eigener
            // TrainingGoal-Fall auf diesem Branch, bevor er wieder mit
            // .weightLoss zusammengelegt wurde (doppelte Abnehmen-Semantik,
            // siehe TrainingGoal-Doc-Kommentar). Toleranter Fallback statt
            // stillem Sprung auf .hybrid, falls ein zwischenzeitlicher Build
            // den Rohwert bereits geschrieben oder exportiert hat.
            if trainingGoalRaw == "fatloss" { return .weightLoss }
            return TrainingGoal(rawValue: trainingGoalRaw) ?? .hybrid
        }
        set { trainingGoalRaw = newValue.rawValue }
    }

    /// `nil` bedeutet "noch nicht hergeleitet" (siehe `experienceTrackRaw`) —
    /// anders als die uebrigen Raw-Accessors hier daher KEIN Default-Fallback
    /// bei fehlendem Wert, nur bei einem ungueltigen (sollte nie vorkommen).
    public var experienceTrack: ExperienceTrack? {
        get { experienceTrackRaw.flatMap { ExperienceTrack(rawValue: $0) } }
        set { experienceTrackRaw = newValue?.rawValue }
    }

    /// Setzt/liest den kompletten Start-Check in einem Schritt, auf Basis
    /// der flachen Einzelfelder oben. `nil` heisst "noch nie durchgefuehrt"
    /// (Bestandsnutzer, oder Nutzer hat "Spaeter machen" gewaehlt und noch
    /// nicht nachgeholt) — die vier Pflichtfelder von `BaselineAssessment`
    /// (`date`/`source`/`safetyStatus`/`desiredFirstWeekIntensity`) muessen
    /// ALLE gueltig vorliegen, sonst gibt es keinen sinnvollen
    /// teil-rekonstruierten Check.
    public var baselineAssessment: BaselineAssessment? {
        get {
            guard let baselineDate,
                  let sourceRaw = baselineSourceRaw, let source = BaselineSource(rawValue: sourceRaw),
                  let safetyRaw = baselineSafetyStatusRaw, let safetyStatus = SafetyStatus(rawValue: safetyRaw),
                  let intensityRaw = baselineDesiredFirstWeekIntensityRaw,
                  let intensity = FirstWeekIntensity(rawValue: intensityRaw)
            else { return nil }

            let pushUp: PushUpAssessment? = baselinePushUpVariantRaw
                .flatMap(PushUpVariant.init(rawValue:))
                .flatMap { variant in baselinePushUpCleanReps.map { PushUpAssessment(variant: variant, cleanReps: $0) } }

            let chairSquat: ChairSquatAssessment? = baselineChairSquatCleanReps.flatMap { reps in
                baselineChairSquatDurationSeconds.map { ChairSquatAssessment(cleanReps: reps, durationSeconds: $0) }
            }

            let pull: PullAssessment? = baselinePullVariantRaw
                .flatMap(PullVariant.init(rawValue:))
                .flatMap { variant in
                    baselinePullCleanReps.map { reps in
                        PullAssessment(variant: variant, cleanReps: reps, loadKg: baselinePullLoadKg, rir: baselinePullRir)
                    }
                }

            let plank = baselinePlankSeconds.map { PlankAssessment(seconds: $0) }
            let cardio = baselineCardioAnswerRaw.flatMap(CardioBaselineAnswer.init(rawValue:)).map { CardioBaseline(answer: $0) }

            return BaselineAssessment(
                date: baselineDate,
                source: source,
                safetyStatus: safetyStatus,
                version: baselineVersion ?? BaselineAssessment.currentVersion,
                pushUp: pushUp,
                chairSquat: chairSquat,
                pull: pull,
                plank: plank,
                cardio: cardio,
                pushSelfAssessment: baselinePushSelfAssessmentRaw.flatMap(SelfAssessmentAnswer.init(rawValue:)),
                legsSelfAssessment: baselineLegsSelfAssessmentRaw.flatMap(SelfAssessmentAnswer.init(rawValue:)),
                pullSelfAssessment: baselinePullSelfAssessmentRaw.flatMap(SelfAssessmentAnswer.init(rawValue:)),
                desiredFirstWeekIntensity: intensity
            )
        }
        set {
            baselineDate = newValue?.date
            baselineSourceRaw = newValue?.source.rawValue
            baselineSafetyStatusRaw = newValue?.safetyStatus.rawValue
            baselineVersion = newValue?.version
            baselineDesiredFirstWeekIntensityRaw = newValue?.desiredFirstWeekIntensity.rawValue

            baselinePushUpVariantRaw = newValue?.pushUp?.variant.rawValue
            baselinePushUpCleanReps = newValue?.pushUp?.cleanReps

            baselineChairSquatCleanReps = newValue?.chairSquat?.cleanReps
            baselineChairSquatDurationSeconds = newValue?.chairSquat?.durationSeconds

            baselinePullVariantRaw = newValue?.pull?.variant.rawValue
            baselinePullCleanReps = newValue?.pull?.cleanReps
            baselinePullLoadKg = newValue?.pull?.loadKg
            baselinePullRir = newValue?.pull?.rir

            baselinePlankSeconds = newValue?.plank?.seconds
            baselineCardioAnswerRaw = newValue?.cardio?.answer.rawValue

            baselinePushSelfAssessmentRaw = newValue?.pushSelfAssessment?.rawValue
            baselineLegsSelfAssessmentRaw = newValue?.legsSelfAssessment?.rawValue
            baselinePullSelfAssessmentRaw = newValue?.pullSelfAssessment?.rawValue
        }
    }

    /// DEL-109: Typed Convenience-Accessor auf die Widget-Liste. Filtered
    /// stille raw-Strings raus, die keinem aktuellen Enum-Case mehr
    /// entsprechen (z.B. nach einem Rename / Delete eines Widgets in einer
    /// Zukunfts-Welle) — verhindert dass die UI auf einem "Ghost"-Widget
    /// stehen bleibt.
    public var activeDashboardWidgets: [DashboardWidgetType] {
        get { activeDashboardWidgetsRaw.compactMap { DashboardWidgetType(rawValue: $0) } }
        set { activeDashboardWidgetsRaw = newValue.map { $0.rawValue } }
    }

    /// DEL-132 (Phase 1): Typed Accessor fuer Hero-Slots. Setter clampt
    /// auf `HeroMetricType.maxSlots` (3) — wenn die UI versehentlich mehr
    /// Slots schreiben wollte, ueberlebt das Layout. Stale rawStrings
    /// werden beim Lesen rausgefiltert (gleicher Robustness-Pattern wie
    /// activeDashboardWidgets).
    public var heroMetricSlots: [HeroMetricType] {
        get { heroMetricSlotsRaw.compactMap { HeroMetricType(rawValue: $0) } }
        set {
            let clamped = Array(newValue.prefix(HeroMetricType.maxSlots))
            heroMetricSlotsRaw = clamped.map { $0.rawValue }
        }
    }

    /// DEL-170: Typed Accessor für Equipment-Präferenzen. Set-basiert
    /// (Reihenfolge irrelevant). Stale rawStrings (Enum-Cases existieren
    /// nicht mehr) werden beim Lesen rausgefiltert.
    public var equipmentPreferences: Set<Equipment> {
        get { Set(equipmentPreferencesRaw.compactMap { Equipment(rawValue: $0) }) }
        set { equipmentPreferencesRaw = newValue.map(\.rawValue).sorted() }
    }

    /// Smart-Onboarding-Epic Phase 2: Typed Accessor fuer die neue,
    /// dreiwertige Equipment-Erfassung. Stale rawStrings (Enum-Cases
    /// existieren nicht mehr) werden beim Lesen rausgefiltert — gleicher
    /// Robustness-Pattern wie `equipmentPreferences`/`activeDashboardWidgets`.
    /// Ein Item darf nie gleichzeitig in beiden Rohlisten stehen; der Setter
    /// stellt das her, indem er aus EINER Quelle (`UserEquipmentProfile.
    /// availability`) beide Listen disjunkt neu schreibt.
    public var equipmentProfile: UserEquipmentProfile {
        get {
            var availability: [EquipmentItem: EquipmentAvailability] = [:]
            for raw in equipmentAvailableItemsRaw {
                guard let item = EquipmentItem(rawValue: raw) else { continue }
                availability[item] = .available
            }
            for raw in equipmentUnavailableItemsRaw {
                guard let item = EquipmentItem(rawValue: raw) else { continue }
                availability[item] = .unavailable
            }
            var counts: [EquipmentItem: Int] = [:]
            for pair in equipmentItemCountsRaw {
                let parts = pair.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, let item = EquipmentItem(rawValue: String(parts[0])),
                      let count = Int(parts[1]) else { continue }
                counts[item] = count
            }
            return UserEquipmentProfile(availability: availability, counts: counts)
        }
        set {
            equipmentAvailableItemsRaw = newValue.availability
                .compactMap { item, availability in availability == .available ? item.rawValue : nil }
                .sorted()
            equipmentUnavailableItemsRaw = newValue.availability
                .compactMap { item, availability in availability == .unavailable ? item.rawValue : nil }
                .sorted()
            equipmentItemCountsRaw = newValue.counts
                .map { "\($0.key.rawValue):\($0.value)" }
                .sorted()
        }
    }

    /// Smart-Onboarding-Epic Phase 3: die "vollstaendige Bestaetigung" fuer
    /// ein lebendes, bereits inserted `UserBodyProfile` (Profil-Editor —
    /// Onboarding hat noch kein Profil und ruft stattdessen direkt
    /// `UserEquipmentProfile.confirmRemainingAsUnavailable()` auf einem
    /// lokalen `@State`-Wert auf). Alles bisher nicht ausgewaehlte Item wird
    /// jetzt explizit `.unavailable`; danach ist die Erfassung abgeschlossen
    /// und die aeltere `equipmentPreferences` (DEL-170) wird EINMALIG aus
    /// dem neuen, reicheren Modell synchronisiert — die einzige Schreibstelle
    /// dafuer seit Phase 3 die alte Checkbox-UI ersetzt hat (keine zweite,
    /// unabhaengig editierbare Equipment-Quelle mehr).
    public func confirmEquipmentProfileComplete() {
        var current = equipmentProfile
        current.confirmRemainingAsUnavailable()
        equipmentProfile = current
        equipmentProfileConfirmedComplete = true
        equipmentPreferences = current.legacyEquipmentPreferences
    }

    /// "Nur Koerpergewicht" (Audit-Vorgabe: muss ausdruecklich bestaetigt
    /// werden, nicht nur aus einer leeren Auswahl erschlossen). Setzt JEDES
    /// Item auf `.unavailable` — verwirft dabei bewusst eine eventuell
    /// zuvor begonnene Teil-Auswahl, da "nur Koerpergewicht" ihr sonst
    /// widersprechen wuerde.
    public func confirmBodyweightOnly() {
        equipmentProfile = UserEquipmentProfile()
        confirmEquipmentProfileComplete()
    }

    /// Smart-Onboarding-Epic Phase 3: setzt Verfuegbarkeit (und optional
    /// Stueckzahl) GENAU EINES Items und haelt `equipmentPreferences`
    /// automatisch im Sync — aber NUR wenn die Erfassung bereits bestaetigt
    /// wurde (siehe `confirmEquipmentProfileComplete`). Vor der ersten
    /// Bestaetigung bleibt die aeltere Spalte unberuehrt, damit kein
    /// Zwischenstand sie verfrueht mit einer unvollstaendigen Aussage
    /// ueberschreibt. `availability: nil` entfernt den Eintrag wieder
    /// (zurueck zu `.unknown`) — das ist, was ein erneutes Abwaehlen VOR der
    /// Bestaetigung tut, nie ein explizites `.unavailable`.
    public func setEquipmentAvailability(_ availability: EquipmentAvailability?, for item: EquipmentItem, count: Int? = nil) {
        var current = equipmentProfile
        if let availability {
            current.availability[item] = availability
        } else {
            current.availability.removeValue(forKey: item)
        }
        if let count {
            current.counts[item] = count
        } else {
            current.counts.removeValue(forKey: item)
        }
        equipmentProfile = current
        if equipmentProfileConfirmedComplete {
            equipmentPreferences = current.legacyEquipmentPreferences
        }
    }

    public init(
        birthDate: Date,
        heightCm: Double,
        profile: BodyFormulaProfile,
        firstName: String? = nil,
        goalWeightKg: Double? = nil,
        environment: EnvironmentType = .gym,
        coachingTone: CoachingTone = .analytical,
        trainingGoal: TrainingGoal = .hybrid,
        // DEL-170: optionale Equipment-Präferenzen. Default leer — der Matcher
        // behandelt das wie "nicht gepflegt" und nimmt die Standard-Variante.
        equipmentPreferences: Set<Equipment> = [],
        // DEL-250: Cardio-Ziele. Default = ausgeschaltet/leer, identisch zum
        // Lightweight-Migration-Default fuer Bestand (siehe Property-Docs).
        cardioCoachingEnabled: Bool = false,
        cardioGoal: CardioGoal = .generalFitness,
        cardioRaceDate: Date? = nil,
        current5kReferenceSeconds: Int? = nil,
        weeklyBaseVolumeKm: Double? = nil,
        maxHeartRateBpm: Int? = nil,
        cardioFeasibilityDismissedFingerprint: String? = nil
    ) {
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.profile = profile
        self.firstName = firstName
        self.goalWeightKg = goalWeightKg
        self.environment = environment
        self.coachingToneRaw = coachingTone.rawValue
        self.trainingGoalRaw = trainingGoal.rawValue
        self.equipmentPreferencesRaw = equipmentPreferences.map(\.rawValue).sorted()
        self.cardioCoachingEnabled = cardioCoachingEnabled
        self.cardioGoalRaw = cardioGoal.rawValue
        self.cardioRaceDate = cardioRaceDate
        self.current5kReferenceSeconds = current5kReferenceSeconds
        self.weeklyBaseVolumeKm = weeklyBaseVolumeKm
        self.maxHeartRateBpm = maxHeartRateBpm
        self.cardioFeasibilityDismissedFingerprint = cardioFeasibilityDismissedFingerprint
    }
}
#endif
