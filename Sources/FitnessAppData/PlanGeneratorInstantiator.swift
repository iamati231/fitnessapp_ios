#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// README 2.20 "Plan bauen": Bruecke zwischen dem reinen Core-Generator
/// (`PlanGenerator`, kein SwiftData) und der bestehenden
/// `ProgramInstantiator`-Materialisierung. Baut dafuer eine wegwerfbare
/// synthetische `ProgramTemplate`-Huelle aus dem generierten `[DaySpec]` und
/// delegiert die eigentliche Insert-Arbeit an `ProgramInstantiator.instantiate`,
/// statt sie zu duplizieren - so profitiert "Plan bauen" automatisch von
/// jeder kuenftigen Aenderung an der Instanziierungs-Logik.
///
/// **P2.3 — die VIER sanktionierten Pfade, mit denen ein generierter/
/// bestehender Plan die Datenbank beruehrt** (docs/PLANUNG_BEGLEITUNG_AUDIT.md):
///   1. **Onboarding-Entwurf**: `PlanBuilderView(onGenerated:)` liefert
///      `PlanGeneratorInput`/`PlanGenerator.Result` nur per Closure nach
///      oben durch — KEIN Aufruf dieser Datei, also keine Persistenz, bis
///      `OnboardingView.finishOnboarding()` tatsaechlich committet.
///   2. **Neuen Plan erstellen**: `createPlan(from:for:generationSource:in:)`
///      unten — EIN Einstiegspunkt fuer alle vier Aufrufer, die vorher je
///      eigenstaendig `EquipmentPlanningResolver.resolve(...)` + `build(...)`
///      kombiniert hatten (`OnboardingView.finishOnboarding`,
///      `CardioFeasibilityCardModel.accept`/`.acceptCustom`,
///      `PlanBuilderView.adoptPlan()`).
///   3. **Bestehenden Plan kontrolliert aktualisieren**: `recalculate(_:in:)`
///      unten — ersetzt NUR unangetastete Tage eines bereits persistierten
///      Plans, niemals den Plan selbst.
///   4. **Bewusst eine neue Kopie erstellen**: `PlansListView.duplicatePlan(_:)`
///      — Tiefkopie mit `isActive = false`, der Nutzer entscheidet bewusst
///      ueber die Umschaltung.
///
/// Alle vier Pfade speichern/instanziieren AUSSCHLIESSLICH die angefragte
/// Operation. Keiner von ihnen schliesst ein Sheet oder navigiert — das
/// bleibt Aufgabe des jeweiligen Aufrufers, der seinen eigenen UI-Kontext
/// kennt (Sheet vs. Onboarding-Flow vs. Settings-Screen), diese Datei nicht.
///
/// **Aktivierungsvertrag (Nachbesserung P2.3-Review, Punkt 5 — ehrlich
/// benannt, NICHT als geloest zu lesen):** alle drei schreibenden Pfade
/// (`createPlan`, Template-Adopt) aktivieren HEUTE automatisch ueber
/// `ProgramInstantiator.instantiate` (deaktiviert alle Alt-Plaene, legt den
/// neuen aktiv an) — das ist unveraendertes Bestandsverhalten, keine neue
/// Policy durch P2.3, und fuer das heutige Ein-aktiver-Plan-Modell
/// akzeptabel. Es ist AUSDRUECKLICH KEIN fuer alle Zukunft geklaerter
/// Vertrag.
///
/// **Verbindliche Anforderung (Nachbesserung, nicht nur offene Frage)**
/// fuer den geplanten Wocheneditor: eine finale Uebernahmefunktion dort MUSS
/// ausdruecklich zwischen „nur speichern" (Entwurf/Aenderungen am
/// `PlanDraft` persistieren, OHNE den aktiven Plan zu wechseln) und
/// „aktivieren" (zusaetzlich den bisherigen aktiven Plan ablösen)
/// unterscheiden — als zwei erkennbar getrennte Operationen/Entscheidungen,
/// NICHT als stille Uebernahme der heutigen impliziten
/// Alles-oder-nichts-Automatik dieser Datei. Diese Unterscheidung ist NICHT
/// getroffen und NICHT Teil von P2.3 — wird hier sichtbar offengehalten,
/// damit sie nicht spaeter als bereits entschieden gilt.
///
/// **Task #197 — Stand nach dieser Nachbesserung:** die Save-/Fehlerbehandlung fuer GENAU
/// `build`/`createPlan` (neuer Plan) und `recalculate` (bestehender Plan) ist jetzt real geklaert
/// (siehe Commit-/Speicherverantwortung unten) — nicht mehr die reine Autosave-Abhaengigkeit von
/// vorher. Das ist AUSDRUECKLICH NICHT dasselbe wie die obige „nur speichern" vs. „aktivieren"-
/// Unterscheidung: diese bleibt offen und wird erst relevant, sobald eine finale
/// Wocheneditor-Uebernahmefunktion TATSAECHLICH existiert (P3) — diese Datei legt heute weiterhin
/// nur neue Plaene an bzw. aktualisiert bestehende, baut aber selbst keine neue
/// „nur speichern ohne zu aktivieren"-Operation.
///
/// **Commit-/Speicherverantwortung (Nachbesserung, Task #197 — ersetzt den
/// vorherigen P2.3-Stand):** `build` UND `recalculate` rufen jetzt SELBST
/// `context.save()` auf — EIN Aufruf pro Funktion, direkt nach den eigenen
/// Mutationen, begrenzt auf genau diese eine Operation (kein Save, der auch
/// nur zufaellig etwas anderes mit festschreibt). Schlaegt der Save fehl,
/// wird das als typisierter, catchbarer Fehler nach oben geworfen
/// (`PlanCreationError.saveFailed` / `RecalculateError.saveFailed`) — statt
/// sich wie zuvor ausschliesslich auf SwiftDatas Autosave-Mechanik zu
/// verlassen, die weder Zeitpunkt noch Fehlerfall sichtbar macht.
///
/// `build` macht auf einem Save-Fehler einen GEZIELTEN, auf die eigenen
/// Aenderungen begrenzten Rueckbau: der gerade erst eingefuegte Plan wird
/// geloescht (cascadet automatisch auf seine Tage/Uebungen, siehe
/// `TrainingPlan.days`/`TrainingDay.exercises`, beide `deleteRule: .cascade`)
/// UND die `isActive`-Flags der zuvor aktiven Plaene — die
/// `ProgramInstantiator.instantiate` unconditional auf `false` gesetzt hatte
/// (dortiger Side-Effect 1) — werden wiederhergestellt. Der Context landet
/// exakt im Zustand von VOR diesem Aufruf: ein erneuter Versuch legt weder
/// einen doppelten Plan an, noch bleibt zwischenzeitlich kein Plan aktiv.
///
/// `recalculate` kann NICHT auf dieselbe Weise zurueckbauen: `apply` loescht
/// bereits bestehende, persistierte `Exercise`-Objekte — SwiftData bietet
/// keine sichere Operation, ein bereits angestossenes Delete ohne einen
/// Context-weiten `rollback()` wieder rueckgaengig zu machen. Trotzdem
/// sicher: `save()` ist atomar, bei einem Fehler landet NICHTS auf der
/// Platte; die haengengebliebenen Aenderungen werden vom naechsten
/// erfolgreichen Save (von hier oder anderswo) einfach nachgeholt, und ein
/// erneuter `recalculate`-Aufruf dupliziert dabei nichts — der gerade neu
/// geschriebene Fingerprint passt bereits zum neuen Inhalt, ein zweiter
/// Durchlauf ersetzt also wieder nur konsistent denselben Zielzustand.
///
/// Ausdruecklich NICHT eingebaut, in BEIDEN Funktionen: ein
/// `context.rollback()` bei einem Fehler — das wirkt auf den GESAMTEN
/// geteilten `ModelContext` und wuerde unabhaengige, an anderer Stelle
/// bereits bestaetigte Aenderungen (z.B. ein offenes Edit auf einem anderen
/// Screen, das denselben `modelContext` teilt) mit zerstoeren — ein klar
/// schlechteres Ergebnis als das Problem, das es loesen sollte.
///
/// Jeder andere Pfad in dieser Datei (`makeTemplate`, `apply` fuer sich
/// genommen) ruft weiterhin KEIN `context.save()` auf — das bleibt
/// Verantwortung der beiden oeffentlichen Einstiegspunkte, nicht jeder
/// internen Hilfsfunktion.
@MainActor
public enum PlanGeneratorInstantiator {

    /// Rechnet `input` einmal aus, instanziiert das Ergebnis als neuen
    /// aktiven Plan (gleiche Side-Effects wie jeder andere Template-Adopt,
    /// siehe `ProgramInstantiator.instantiate`) und stempelt danach jeden
    /// Trainings-Tag mit seinem Erzeugungs-Fingerprint sowie den Plan mit
    /// dem JSON-codierten `input` - beides zusammen macht `recalculate`
    /// spaeter moeglich.
    ///
    /// Liefert `nil`, wenn der Generator fuer diese Auswahl NICHTS gefunden
    /// hat (z.B. eine Ausruestung/Schwierigkeit-Kombination ohne jeden
    /// Bibliotheks-Treffer) - die Wizard-UI sollte "Plan uebernehmen" zwar
    /// bereits vorher deaktivieren, wenn `PlanGenerator.generate` leer
    /// zurueckkommt, aber diese Funktion verlaesst sich nicht darauf: ein
    /// `daysPerWeek: 0`-Template wuerde `ProgramInstantiator.defaultWeekdays`
    /// in eine ungueltige Range (`2...1`) und damit einen Crash laufen lassen.
    ///
    /// `precomputed`: Bugfix (Nutzer-Feedback, "Neu rechnen"-Shuffle) - ohne
    /// diesen Parameter wuerde `build` `input` intern IMMER frisch (und
    /// damit deterministisch, `shuffle: false`) neu rechnen. Hat der User im
    /// Wizard vorher mehrfach "Neu rechnen" getippt, um eine ihm zusagende
    /// Variante zu finden, und tippt dann "Plan uebernehmen", wuerde der
    /// instanziierte Plan NICHT der zuletzt angezeigten (gemischten)
    /// Vorschau entsprechen, sondern immer der ersten, deterministischen
    /// Variante - fuer den User nicht nachvollziehbar. `PlanBuilderView`
    /// reicht deshalb das bereits im Schritt-3-State gehaltene
    /// `PlanGenerator.Result` durch; jeder andere Aufrufer (`recalculate`
    /// unten, alle bestehenden Tests) laesst den Parameter weg und bekommt
    /// exakt das alte Verhalten.
    ///
    /// Audit-Korrektur P2.1 (docs/PLANUNG_BEGLEITUNG_AUDIT.md, Abschnitt 1
    /// "Bug/Luecke"): `environment`/`equipmentProfile` sind ABSICHTLICH
    /// PFLICHTPARAMETER OHNE DEFAULT — vorher setzte `makeTemplate`
    /// `targetEnvironment: .gym` hartcodiert, unabhaengig von der
    /// tatsaechlichen Equipment-/Orts-Wahl. Ein unauffaelliger Default (egal
    /// welcher Wert) haette denselben Fehler nur versteckter wiederholt;
    /// jeder Aufrufer MUSS jetzt explizit den schon vorhandenen,
    /// tatsaechlich gewaehlten Trainingsort liefern.
    ///   - `environment`: der EXPLIZITE Trainingsort (z.B.
    ///     `UserBodyProfile.environment`) — NICHT aus `equipmentProfile`
    ///     hergeleitet. Ort und Ausstattung sind zwei unabhaengige Angaben
    ///     (Audit §1/§2); Equipment ersetzt den Trainingsort nie.
    ///   - `equipmentProfile`: das EFFEKTIVE Profil, wie es
    ///     `EquipmentPlanningResolver.resolve(environment:individualProfile:
    ///     confirmedComplete:)` bereits an jeder bestehenden Aufrufstelle
    ///     liefert (`OnboardingView.equipmentPlanningContext`,
    ///     `ProgramTemplatePickerView.equipmentPlanningContext`) — der
    ///     Aufrufer loest EINMAL auf (Gym-Annahme/bestaetigt/unbestaetigt,
    ///     siehe dort) und reicht `.effectiveProfile` durch, statt hier eine
    ///     zweite, potenziell abweichende Aufloesung einzufuehren. Fliesst
    ///     als `userEquipmentProfile:` in `ProgramInstantiator.instantiate`
    ///     — dieselbe praezise Pro-Uebung-Pruefung
    ///     (`PlanEquipmentChecker`/`bestEquipmentCheckedVariant`), die der
    ///     Template-Pfad bereits nutzt, statt der bisherigen groben
    ///     `Set<Equipment>`-Legacy-Pruefung. Fehlende oder widerspruechliche
    ///     Angaben (z.B. unbestaetigtes Profil, Gym ohne individuelle
    ///     Einrichtung) werden dadurch genauso behandelt wie ueberall sonst
    ///     in der App — keine zusaetzliche, abweichende Fallback-Regel hier.
    ///
    /// Bekannte Grenze: Der synthetische Wegwerf-Template aus `makeTemplate`
    /// hat (anders als kuratierte Templates) nie `equipmentVariants` — die
    /// praezise Pruefung kann deshalb heute noch NICHTS substituieren
    /// (`bestEquipmentCheckedVariant` faellt mangels Alternativen immer auf
    /// `days` unveraendert zurueck). Die uebergebene `equipmentProfile`
    /// aendert den materialisierten Tagesinhalt eines Builder-Plans also
    /// (noch) nicht sichtbar — sie verhindert aber die bisherige, aktiv
    /// falsche `targetEnvironment`-Fixierung und macht den Pfad bereit fuer
    /// jede kuenftige Variant-/Substitutions-Erweiterung (P3+), ohne dass
    /// dafuer diese Stelle nochmal angefasst werden muesste. Der volle
    /// Phase-5-Substitutions-Pfad (`PlanSelectionResolver`/
    /// `ResolvedPlanSelection`, mit Ersatz-Uebungen) ist bewusst NICHT
    /// angebunden: er braucht einen `SubstitutionContext(goal:
    /// experienceTrack:)`, und ein ueber den Builder/Cardio-Coach erzeugter
    /// Plan hat kein eigenes `TrainingGoal` — ein dafuer erfundener Wert
    /// waere genau der versteckte Default, den diese Korrektur vermeiden
    /// soll. Bleibt offene Anschlussaufgabe, sobald der zielorientierte
    /// Builder (P3) ein echtes Ziel liefert.
    /// Nachbesserung (Task #197): wirft `PlanCreationError.saveFailed`, wenn der abschliessende
    /// `context.save()` fehlschlaegt — siehe Typ-Doku "Commit-/Speicherverantwortung" fuer den
    /// gezielten Rueckbau, der in diesem Fall ausgefuehrt wird.
    @discardableResult
    public static func build(
        from input: PlanGeneratorInput,
        in context: ModelContext,
        environment: EnvironmentType,
        equipmentProfile: UserEquipmentProfile,
        result precomputed: PlanGenerator.Result? = nil,
        generationSource: GenerationSource = .manual
    ) throws -> TrainingPlan? {
        let result = precomputed ?? PlanGenerator.generate(from: input)
        guard !result.days.isEmpty else { return nil }
        let template = makeTemplate(from: result, environment: environment)

        // Nachbesserung (Task #197): VOR `instantiate` merken, welche Plaene gerade aktiv waren -
        // `instantiate` deaktiviert sie unconditional (dortiger Side-Effect 1). Schlaegt der Save
        // unten fehl, muss GENAU das wiederhergestellt werden, sonst bliebe nach einem
        // gescheiterten Versuch kein Plan mehr aktiv.
        let previouslyActivePlans = (try? context.fetch(
            FetchDescriptor<TrainingPlan>(predicate: #Predicate { $0.isActive == true })
        )) ?? []

        let plan = ProgramInstantiator.instantiate(
            template,
            in: context,
            selectedWeekdays: resolvedWeekdays(from: input),
            userEquipmentProfile: equipmentProfile
        )
        plan.generatorInput = input
        plan.generationSource = generationSource

        // Genau JETZT - direkt nach `instantiate`, bevor irgendein Edit
        // stattfinden konnte - entspricht die Montag-first-sortierte
        // Position exakt dem `sequenceIndex`, mit dem `ProgramInstantiator`
        // gerade erst jeden Tag angelegt hat (siehe dortige
        // `sortedDays.enumerated()` + `normalized[idx]`-Zuordnung). Das ist
        // die EINZIGE Stelle, an der wir uns auf Listenposition statt auf
        // den gespeicherten `generatorSequenceIndex` verlassen duerfen -
        // `recalculate` tut das bewusst NICHT mehr (siehe dort).
        let orderedDays = PlanNavigator.sortByWeekdayMondayFirst(plan.days.filter { $0.type != .rest })
        for (day, generated) in zip(orderedDays, result.days) {
            day.generatorSequenceIndex = generated.spec.sequenceIndex
            day.generationFingerprint = day.currentContentFingerprint
        }

        do {
            try save(context)
        } catch {
            // Nachbesserung (Task #197): gezielter, auf diesen Aufruf begrenzter Rueckbau statt
            // `context.rollback()` - siehe Typ-Doku. Nur das rueckgaengig machen, was DIESER
            // Aufruf selbst veraendert hat: den gerade erst eingefuegten Plan (cascadet per
            // `deleteRule: .cascade` auf alle seine Tage/Uebungen) UND die `isActive`-Flags, die
            // `instantiate` oben umgeschaltet hat.
            context.delete(plan)
            for previouslyActive in previouslyActivePlans {
                previouslyActive.isActive = true
            }
            throw PlanCreationError.saveFailed
        }

        return plan
    }

    /// P2.3 — der EINE Einstiegspunkt fuer "neuen generierten Plan
    /// erstellen", der `EquipmentPlanningResolver.resolve(...)` + `build(...)`
    /// buendelt. Ersetzt vier vorher unabhaengige Kopien derselben zwei
    /// Zeilen in `OnboardingView.finishOnboarding`,
    /// `CardioFeasibilityCardModel.accept`/`.acceptCustom` und
    /// `PlanBuilderView.adoptPlan()` — genau die Kopien, die beim P2.1-Fix
    /// einzeln nachgezogen werden mussten, weil es noch keine gemeinsame
    /// Stelle dafuer gab.
    ///
    /// Nimmt bewusst ein komplettes `UserBodyProfile` statt vorab
    /// aufgeloester `environment`/`equipmentProfile`-Werte entgegen: alle
    /// vier Aufrufer haben an der Call-Site bereits ein konkretes Profil
    /// (Parameter, `@Query`, oder — bei `OnboardingView` — das gerade erst
    /// konstruierte, zu diesem Zeitpunkt schon vollstaendig befuellte
    /// Profil). Das Finden/Fehlen eines Profils bleibt dadurch explizit
    /// Verantwortung des Aufrufers (z.B. `PlanBuilderView`s eigener
    /// `missingProfileErrorMessage`-Alert) — diese Funktion verlangt ein
    /// gueltiges Profil als Voraussetzung, sie sucht/errät keins.
    ///
    /// Speichert/aktiviert NICHTS ueber `build(...)` (→ `ProgramInstantiator.
    /// instantiate`) hinaus und schliesst/navigiert nirgendwohin — siehe
    /// Typ-Dokumentation oben.
    @discardableResult
    public static func createPlan(
        from input: PlanGeneratorInput,
        result precomputed: PlanGenerator.Result? = nil,
        for profile: UserBodyProfile,
        generationSource: GenerationSource,
        in context: ModelContext
    ) throws -> TrainingPlan? {
        let effectiveProfile = EquipmentPlanningResolver.resolve(
            environment: profile.environment,
            individualProfile: profile.equipmentProfile,
            confirmedComplete: profile.equipmentProfileConfirmedComplete
        ).effectiveProfile
        return try build(
            from: input, in: context,
            environment: profile.environment, equipmentProfile: effectiveProfile,
            result: precomputed, generationSource: generationSource
        )
    }

    /// Nachbesserung (Task #197): typisierter Fehler fuer einen fehlgeschlagenen `context.save()`
    /// in `build`/`createPlan` — siehe Typ-Doku "Commit-/Speicherverantwortung".
    public enum PlanCreationError: Error, Equatable {
        case saveFailed
    }

    /// Nachbesserung (Task #197): DI-Seam fuer den Save-Fehlerpfad, analog
    /// `fetchAllSessionsOverrideForTesting`. `nil` (Default) aendert nichts - `build`/`recalculate`
    /// rufen weiterhin den echten `context.save()` auf. `@testable import FitnessAppData` kann
    /// hier eine werfende Closure setzen, um einen echten Speicherfehler deterministisch zu
    /// simulieren, ohne den SwiftData-Store selbst beschaedigen zu muessen.
    static var saveOverrideForTesting: ((ModelContext) throws -> Void)?

    private static func save(_ context: ModelContext) throws {
        if let saveOverrideForTesting {
            try saveOverrideForTesting(context)
            return
        }
        try context.save()
    }

    /// README 2.20 "neu rechnen": rechnet den am Plan gespeicherten
    /// `generatorInput` neu und ersetzt NUR Tage, deren Inhalt seit der
    /// letzten (Neu-)Erzeugung unveraendert ist - "ueberschreiben, aber nur
    /// unangetastete Tage", das Dokument schlaegt diese Regel selbst vor.
    /// Ein Tag gilt als unangetastet, wenn sein gespeicherter
    /// `generationFingerprint` noch exakt seinem `currentContentFingerprint`
    /// entspricht; alles andere ist ein User-Edit und bleibt stehen.
    ///
    /// Matching generierter <-> bestehender Tage laeuft NICHT positional,
    /// sondern ueber den bei der Erzeugung gestempelten
    /// `TrainingDay.generatorSequenceIndex`. Ein frueherer Entwurf sortierte
    /// die Trainings-Tage Montag-first und griff per Listen-Index in
    /// `result.days` - das bricht, sobald der User ueber `DayEditorView`
    /// den Wochentag EINES Tages aendert oder einen Tag zum Ruhetag macht:
    /// die Montag-first-Position verschiebt sich fuer alle NACHFOLGENDEN
    /// Tage, obwohl die als unangetastet gelten und ueberschrieben werden
    /// sollten - mit dem Inhalt des FALSCHEN generierten Tages. Der
    /// `generatorSequenceIndex` bleibt dagegen stabil, ganz gleich wie oft
    /// Wochentag/Typ seither editiert wurden (beide sind zusaetzlich Teil
    /// von `currentContentFingerprint`, schuetzen einen so geaenderten Tag
    /// also ohnehin vor dem Ueberschreiben).
    ///
    /// Nachbesserung (P2.3-Review): Fehlerfall fuer `recalculate` — die
    /// Sicherheitspruefung gegen Sessions konnte nicht durchgefuehrt werden
    /// (z.B. Fetch-Fehler). OHNE diese Pruefung darf KEINE Mutation
    /// stattfinden (Punkt 1 der Vorgabe) — der Aufrufer bekommt diesen
    /// Fehler geworfen, BEVOR irgendein Tag angefasst wurde, und muss einen
    /// verstaendlichen Fehlerzustand zeigen statt die Aenderung still
    /// ausfallen zu lassen.
    public enum RecalculateError: Error, Equatable {
        case sessionCheckFailed
        /// Nachbesserung (Task #197): der abschliessende `context.save()` ist fehlgeschlagen.
        /// KEIN Rueckbau der bereits angewandten Tagesersetzungen — siehe Typ-Doku
        /// "Commit-/Speicherverantwortung" fuer die Begruendung (kein sicheres Undelete ohne
        /// Context-weiten Rollback) und warum das trotzdem nichts verliert/dupliziert.
        case saveFailed
    }

    /// Nachbesserung (P2.3-Review): Rueckgabe von `recalculate` — getrennt
    /// nach tatsaechlich neu geschriebenen und wegen bestehender
    /// Trainingshistorie bewusst uebersprungenen Tagen (Punkt 2 der
    /// Vorgabe: "konservatives Ueberspringen ... sofern es sichtbar erklaert
    /// wird" — `PlanEditorView` liest `skippedDueToHistoryCount`, um das im
    /// Toast auch tatsaechlich zu erklaeren, statt es stillschweigend in der
    /// Gesamtzahl verschwinden zu lassen).
    public struct RecalculateSummary: Equatable {
        public let rewrittenCount: Int
        public let skippedDueToHistoryCount: Int
    }

    /// Nachbesserung (P2.3-Review): DI-Seam fuer den Fehlerpfad, analog
    /// `BackupService.backupsDirectoryOverride`. `nil` (Default) aendert
    /// nichts — `recalculate` fetcht weiterhin ueber den echten `context`.
    /// `@testable import FitnessAppData` kann hier eine werfende Closure
    /// setzen, um einen echten Fetch-Fehler deterministisch zu simulieren,
    /// ohne den SwiftData-Store selbst beschaedigen zu muessen.
    static var fetchAllSessionsOverrideForTesting: (() throws -> [WorkoutSession])?

    private static func fetchAllSessions(in context: ModelContext) throws -> [WorkoutSession] {
        if let fetchAllSessionsOverrideForTesting {
            return try fetchAllSessionsOverrideForTesting()
        }
        return try context.fetch(FetchDescriptor<WorkoutSession>())
    }

    /// Kein-Op (Rueckgabe `rewrittenCount: 0, skippedDueToHistoryCount: 0`),
    /// wenn der Plan gar keinen `generatorInput` traegt (nicht ueber den
    /// Assistenten entstanden).
    ///
    /// Wirft `RecalculateError.sessionCheckFailed`, wenn die
    /// Session-Sicherheitspruefung selbst fehlschlaegt — siehe dortige Doku
    /// UND die Typ-Doku oben zur Session-/Historien-Garantie. KEINE Mutation
    /// findet in diesem Fall statt.
    @discardableResult
    public static func recalculate(_ plan: TrainingPlan, in context: ModelContext) throws -> RecalculateSummary {
        guard let input = plan.generatorInput else {
            return RecalculateSummary(rewrittenCount: 0, skippedDueToHistoryCount: 0)
        }

        // Nachbesserung (P2.3-Review, Punkt 1): EINMAL, VOR jeder Mutation,
        // nicht mehr pro Tag innerhalb der Schleife. `try`, NIEMALS
        // `(try? ...) ?? []` — ein Fetch-Fehler bedeutet "wir wissen es
        // nicht", nicht "keine Session vorhanden". Ein `(try? ...) ?? []`
        // haette einen Fetch-Fehler STILL als sicher behandelt und waere
        // damit genau in den Fall gelaufen, den dieser Schutz verhindern
        // soll. Kein Tag wird angefasst, solange diese Zeile nicht
        // erfolgreich war.
        let allSessions: [WorkoutSession]
        do {
            allSessions = try fetchAllSessions(in: context)
        } catch {
            throw RecalculateError.sessionCheckFailed
        }

        // Nachbesserung (P2.3-Review, Punkt 2 — KONSERVATIVER als die
        // urspruengliche P2.3-Fassung): nicht mehr nur LAUFENDE Sessions.
        // `ExerciseLog` hat zwar Snapshot-Felder (`exerciseNameSnapshot` u.a.,
        // siehe dortige Typ-Doku), die Name/Cardio/TimeBased-Identitaet auch
        // nach einem Exercise-Delete korrekt wiederherstellen — ABER
        // `ExerciseLog.cnsFatigueScore`/`.localMuscleDamageScore` fallen auf
        // `0.0` zurueck, sobald `exercise == nil` ist (`guard let exercise
        // else { return 0.0 }`, verifiziert durch Lesen). Ein Tag, der auch
        // nur EINMAL trainiert wurde (abgeschlossen ODER laufend), verliert
        // durch "neu rechnen" also echte Auswertungs-Faehigkeit (Recovery-/
        // Fatigue-Scoring), nicht nur eine Code-Ebene-Zeile. Bis es eine
        // Inhalts-/Versionsabsicherung dafuer gibt (P5), wird ein solcher
        // Tag komplett uebersprungen statt die Uebungen zu ersetzen — siehe
        // `RecalculateSummary.skippedDueToHistoryCount` fuer die sichtbare
        // Erklaerung gegenueber dem Nutzer.
        //
        // VERBINDLICHES Exit-Kriterium fuer eine kuenftige Lockerung dieses
        // Schutzes (Nachbesserung): NICHT lockern, nur weil P5 irgendeine
        // Versionierung/Snapshot-Mechanik liefert — ausschliesslich dann,
        // wenn nachgewiesen ist, dass sie TATSAECHLICH saemtliche fuer die
        // Auswertung benoetigten Daten erhaelt (mindestens: CNS-/Muskel-
        // Belastungsfaktoren aequivalent zu `ExerciseLog.cnsFatigueScore`/
        // `.localMuscleDamageScore`, nicht nur Name/Cardio/TimeBased wie
        // die heutigen `ExerciseLog`-Snapshot-Felder). Eine Lockerung ohne
        // diesen Nachweis waere derselbe Fehler, den dieser Schutz gerade
        // behebt.
        let daysWithAnySession = Set(allSessions.compactMap { $0.day?.persistentModelID })

        let result = PlanGenerator.generate(from: input)
        let generatedBySequenceIndex = Dictionary(
            uniqueKeysWithValues: result.days.map { ($0.spec.sequenceIndex, $0.spec) }
        )

        let (timeBasedNames, compoundNames) = ProgramInstantiator.libraryLookupNames()
        let specByName = ProgramInstantiator.libraryLookupSpecs()

        var rewritten = 0
        var skippedDueToHistory = 0
        for day in plan.days {
            // `daysPerWeek` kann sich seit der Erzeugung veraendert haben
            // (andere `input`-Selektion nach erneutem Wizard-Durchlauf waere
            // ein Zukunfts-Feature - heute unveraendert, aber die Anzahl der
            // Tage kann trotzdem abweichen); ein `sequenceIndex`, den es im
            // frischen Ergebnis nicht mehr gibt, wird defensiv uebersprungen.
            guard let sequenceIndex = day.generatorSequenceIndex,
                  let generatedSpec = generatedBySequenceIndex[sequenceIndex] else { continue }
            guard day.generationFingerprint != nil,
                  day.generationFingerprint == day.currentContentFingerprint else { continue }
            if daysWithAnySession.contains(day.persistentModelID) {
                skippedDueToHistory += 1
                continue
            }
            apply(
                generatedSpec,
                to: day,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                specByName: specByName,
                in: context
            )
            rewritten += 1
        }

        // Nachbesserung (Task #197): echte Fehlerbehandlung statt reiner Autosave-Abhaengigkeit.
        // Nur speichern, wenn tatsaechlich etwas geaendert wurde (begrenzter Commit-Scope, gleiches
        // Muster wie `DeloadManager.startDeload`/`endDeload`) - reines Ueberspringen allein loest
        // keinen Save aus. Siehe Typ-Doku "Commit-/Speicherverantwortung": anders als `build` wird
        // hier NICHTS zurueckgebaut, falls der Save fehlschlaegt - das ist ehrlich benannt, kein
        // verschwiegener Kompromiss.
        if rewritten > 0 {
            do {
                try save(context)
            } catch {
                throw RecalculateError.saveFailed
            }
        }

        return RecalculateSummary(rewrittenCount: rewritten, skippedDueToHistoryCount: skippedDueToHistory)
    }

    /// Ersetzt Name + Zeitformat + Uebungen eines Tages durch einen frisch
    /// generierten `DaySpec` und schreibt den neuen Fingerprint fest -
    /// gleiche Exercise-Anreicherung wie beim ersten Erzeugen
    /// (`ProgramInstantiator.makeExercise`), keine Zweit-Implementierung.
    ///
    /// Loescht bewusst nur `activeExercises`, NICHT die volle `exercises`-
    /// Relationship: `currentContentFingerprint` ignoriert archivierte
    /// Eintraege absichtlich (ein automatischer Urlaubs-Modus-Swap soll
    /// "neu rechnen" nicht blockieren, siehe dortige Doku) - wuerden hier
    /// trotzdem ALLE Uebungen geloescht, riesse das genau die archivierten
    /// Originale mit, auf die `PlanEnvironmentMigrator.restoreOriginals`
    /// beim Verlassen des Urlaubs-Modus angewiesen ist.
    private static func apply(
        _ spec: DaySpec,
        to day: TrainingDay,
        timeBasedNames: Set<String>,
        compoundNames: Set<String>,
        specByName: [String: ExerciseTemplateSpec],
        in context: ModelContext
    ) {
        for exercise in day.activeExercises {
            context.delete(exercise)
        }

        day.name = spec.name
        day.customName = nil
        day.localizationKey = spec.localizationKey
        day.timeFormat = spec.timeFormat
        day.timeCapMinutes = spec.timeCapMinutes
        day.circuitRounds = spec.circuitRounds
        day.circuitRestSeconds = spec.circuitRestSeconds
        day.circuitMode = spec.circuitMode

        for (orderIndex, exerciseSpec) in spec.exercises.enumerated() {
            let exercise = ProgramInstantiator.makeExercise(
                from: exerciseSpec,
                orderIndex: orderIndex,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                librarySpecByName: specByName,
                day: day
            )
            context.insert(exercise)
        }

        day.generationFingerprint = day.currentContentFingerprint
    }

    /// `nil` (= `ProgramInstantiator` faellt auf `defaultWeekdays` zurueck)
    /// wenn Schritt 2 "Nur Reihenfolge" gewaehlt hat. Bei festen Wochentagen
    /// wird `input.fixedWeekdays` unveraendert durchgereicht - ein
    /// Anzahl-Mismatch faengt `ProgramInstantiator.instantiate` selbst
    /// defensiv ab (faellt dann seinerseits auf Defaults zurueck).
    private static func resolvedWeekdays(from input: PlanGeneratorInput) -> [Int]? {
        input.usesFixedWeekdays ? input.fixedWeekdays : nil
    }

    /// Wegwerf-Huelle, rein damit `ProgramInstantiator.instantiate`
    /// wiederverwendet werden kann. `id` ist absichtlich kein echter
    /// `ProgramTemplates.all`-Eintrag - jeder Code, der `programType` gegen
    /// die kuratierte Liste abgleicht (`LibrarySeeder`s Backfills), behandelt
    /// eine unbekannte ID bereits konservativ als "Custom-Plan ohne
    /// Template-Origin" (gleiche Kategorie wie ein manuell angelegter Plan).
    ///
    /// Audit-Korrektur P2.1: `targetEnvironment` war hier `.gym`
    /// hartcodiert — unabhaengig davon, was der Nutzer tatsaechlich als
    /// Trainingsort gewaehlt hatte. `environment` kommt jetzt vom Aufrufer
    /// (`build(environment:...)`), siehe dortige Dokumentation.
    private static func makeTemplate(from result: PlanGenerator.Result, environment: EnvironmentType) -> ProgramTemplate {
        ProgramTemplate(
            id: "planBuilder.generated",
            name: "Individueller Plan",
            tagline: "",
            descriptionText: "",
            focus: "",
            daysPerWeek: result.days.count,
            days: result.days.map(\.spec),
            targetEnvironment: environment,
            iconSystemName: "wand.and.stars"
        )
    }
}
#endif
