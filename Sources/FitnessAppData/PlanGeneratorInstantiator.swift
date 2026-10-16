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
/// Operation. Keiner von ihnen schliesst ein Sheet, navigiert oder trifft
/// eine Aktivierungs-Entscheidung UEBER das hinaus, was `ProgramInstantiator.
/// instantiate` schon immer tut (Alt-Plaene deaktivieren, neuen Plan aktiv
/// anlegen — unveraendertes, bestehendes Verhalten, keine neue Policy durch
/// P2.3). Schliessen/Navigieren/Fehleranzeige bleiben Aufgabe des jeweiligen
/// Aufrufers — der kennt seinen eigenen UI-Kontext (Sheet vs. Onboarding-
/// Flow vs. Settings-Screen), diese Datei nicht.
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
    @discardableResult
    public static func build(
        from input: PlanGeneratorInput,
        in context: ModelContext,
        environment: EnvironmentType,
        equipmentProfile: UserEquipmentProfile,
        result precomputed: PlanGenerator.Result? = nil,
        generationSource: GenerationSource = .manual
    ) -> TrainingPlan? {
        let result = precomputed ?? PlanGenerator.generate(from: input)
        guard !result.days.isEmpty else { return nil }
        let template = makeTemplate(from: result, environment: environment)

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
    ) -> TrainingPlan? {
        let effectiveProfile = EquipmentPlanningResolver.resolve(
            environment: profile.environment,
            individualProfile: profile.equipmentProfile,
            confirmedComplete: profile.equipmentProfileConfirmedComplete
        ).effectiveProfile
        return build(
            from: input, in: context,
            environment: profile.environment, equipmentProfile: effectiveProfile,
            result: precomputed, generationSource: generationSource
        )
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
    /// Kein-Op (Rueckgabe 0), wenn der Plan gar keinen `generatorInput`
    /// traegt (nicht ueber den Assistenten entstanden).
    ///
    /// Rueckgabe: Anzahl der tatsaechlich neu geschriebenen Tage.
    @discardableResult
    public static func recalculate(_ plan: TrainingPlan, in context: ModelContext) -> Int {
        guard let input = plan.generatorInput else { return 0 }
        let result = PlanGenerator.generate(from: input)
        let generatedBySequenceIndex = Dictionary(
            uniqueKeysWithValues: result.days.map { ($0.spec.sequenceIndex, $0.spec) }
        )

        let (timeBasedNames, compoundNames) = ProgramInstantiator.libraryLookupNames()
        let specByName = ProgramInstantiator.libraryLookupSpecs()

        var rewritten = 0
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
            // Nachbesserung (P2.3, Abnahme "keine Veraenderung laufender
            // Sessions"): Starten/Durchfuehren eines Workouts aendert weder
            // `generationFingerprint` noch `currentContentFingerprint` (beide
            // beschreiben nur die PLAN-STRUKTUR, nicht geloggte Saetze) — ein
            // Tag mit einer gerade LAUFENDEN Session wuerde die obige Pruefung
            // also unveraendert passieren. `apply(...)` loescht dann aber
            // `day.activeExercises` und legt sie neu an; da
            // `WorkoutSession.day` KEIN Inverse auf eine `TrainingDay.sessions`-
            // Collection hat, kann eine aktive Session diese Neuanlage nicht
            // selbst bemerken und wuerde mit verwaisten/ausgetauschten
            // Exercise-Referenzen weiterlaufen. Deshalb hier zusaetzlich
            // explizit uebersprungen, bis der Nutzer die Session beendet hat.
            guard !hasActiveSession(for: day, in: context) else { continue }
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
        return rewritten
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
    /// Nachbesserung (P2.3): simple, erprobte Abfrage-Form — EIN proven-
    /// safe `#Predicate` (identische Form wie `DashboardView.openSessions`/
    /// `DayEditorView.openSessions`), der Day-Abgleich laeuft bewusst als
    /// simpler Swift-`contains`-Filter IM SPEICHER statt als Relationship-
    /// Vergleich INNERHALB des Predicate-Makros — letzteres laesst sich auf
    /// diesem Linux-Toolchain nicht kompilieren/pruefen (SwiftData fehlt
    /// komplett), ein moeglicher Makro-Fehler wuerde also erst im
    /// Apple-Build auffallen. Diese Form haelt das Risiko auf den bereits
    /// anderswo bewaehrten Predicate-Ausschnitt begrenzt.
    private static func hasActiveSession(for day: TrainingDay, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == false }
        )
        let openSessions = (try? context.fetch(descriptor)) ?? []
        return openSessions.contains { $0.day?.persistentModelID == day.persistentModelID }
    }

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
