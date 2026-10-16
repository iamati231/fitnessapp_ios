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
/// (siehe Operations-/Fehlervertrag unten) — nicht mehr die reine Autosave-Abhaengigkeit von
/// vorher. Das ist AUSDRUECKLICH NICHT dasselbe wie die obige „nur speichern" vs. „aktivieren"-
/// Unterscheidung: diese bleibt offen und wird erst relevant, sobald eine finale
/// Wocheneditor-Uebernahmefunktion TATSAECHLICH existiert (P3) — diese Datei legt heute weiterhin
/// nur neue Plaene an bzw. aktualisiert bestehende, baut aber selbst keine neue
/// „nur speichern ohne zu aktivieren"-Operation.
///
/// # Operations-/Fehlervertrag (Nachbesserung, Review nach Task #197)
///
/// **1. Save-Reichweite ist NICHT operation-begrenzt.** `context.save()` committet IMMER den
/// GESAMTEN `ModelContext`, auf dem es aufgerufen wird — jede unabhaengige, zu diesem Zeitpunkt
/// im SELBEN Context bereits offene Aenderung wuerde MIT committet. Das ist eine Eigenschaft von
/// SwiftData selbst, keine Besonderheit dieser Datei (jeder andere `save()`-Aufruf in der App hat
/// dieselbe Reichweite). Diese Datei trifft deshalb fuer ihre beiden schreibenden Funktionen zwei
/// EXPLIZIT UNTERSCHIEDLICHE Entscheidungen, je nachdem, ob eine Isolation ueberhaupt gefahrlos
/// moeglich ist:
///
///   - **`build`/`createPlan` — isolierte Operation.** Arbeitet auf einem eigenen, gleichrangigen
///     `ModelContext` (`ModelContext(context.container)` — SwiftData kennt keine Eltern-/
///     Kind-Contexts, nur gleichrangige auf demselben Container/Store). Scheitert der Save, wird
///     NICHTS im Aufrufer-Context beruehrt — der Scratch-Context wird einfach verworfen, es gibt
///     nichts zurueckzubauen (siehe Punkt 3). Gelingt er, wird das Ergebnis ueber
///     `context.model(for:)` im AUFRUFER-Context aufgeloest (SwiftData-Modelle sind an ihren
///     Context gebunden, nur die `persistentModelID` ist Context-uebergreifend gueltig) und DORT
///     zurueckgegeben. Der Aufrufer hatte vor diesem Aufruf ohnehin keine eigene Referenz auf den
///     (noch nicht existierenden) Plan — die Rueckbindung ist also kein Verhaltensbruch, sondern
///     genau das, was der Aufrufer ohnehin erst NACH dem Aufruf braucht.
///   - **`recalculate` — bewusst gemeinsam verantworteter Abschluss, NICHT isoliert.** Anders als
///     `build` bearbeitet `recalculate` einen BEREITS EXISTIERENDEN `TrainingPlan`, den der
///     Aufrufer (z.B. `PlanEditorView`) typischerweise selbst per `@Query`/`@Bindable` haelt und
///     UNMITTELBAR nach dem Aufruf weiter anzeigt. Eine Isolation ueber einen zweiten Context
///     wuerde genau DAS kaputt machen: der Aufrufer saehe nach einem erfolgreichen `recalculate`
///     fuer einen Moment weiterhin den ALTEN Tagesinhalt, weil sein eigener Context eine Aenderung
///     aus einem FREMDEN Context nicht synchron uebernimmt — ein neuer, schwerer nachvollziehbarer
///     Fehler anstelle des bestehenden, genau verstandenen Risikos (Punkt 3). Deshalb bewusst
///     NICHT isoliert: eine unabhaengige, zufaellig im selben Context offene Aenderung KANN hier
///     mit gespeichert werden, wenn `recalculate`s eigener Save erfolgreich ist — das ist eine
///     bewusst akzeptierte Eigenschaft von SwiftDatas Save-Modell, keine unbeabsichtigte
///     Nebenwirkung dieser Funktion.
///
/// **2. Zustandspruefungen vor jeder Mutation.** Jede Pruefung, deren Ergebnis eine nachfolgende
/// Mutation erst rechtfertigt (`build`: welche Plaene sind gerade aktiv; `recalculate`: welche Tage
/// haben Sessions), MUSS bei einem EIGENEN Fehler die GESAMTE Operation VOR jeder Mutation
/// abbrechen. NIEMALS `(try? ...) ?? []` — ein Fetch-Fehler bedeutet "wir wissen es nicht", nicht
/// "nichts gefunden".
///
/// **3. Rueckbau-Reichweite bei einem Save-Fehler ist auf DIESE Operation begrenzt — nie ein
/// `context.rollback()`.** Ein Rollback wirkt auf den GESAMTEN Context und wuerde unabhaengige, an
/// anderer Stelle bereits bestaetigte Aenderungen (z.B. ein offenes Edit auf einem anderen Screen)
/// mit zerstoeren.
///   - `build`: siehe Punkt 1 — der Scratch-Context wird bei einem Fehler einfach verworfen, es
///     gibt dort nichts rueckgaengig zu machen.
///   - `recalculate`: `apply` ARCHIVIERT alte Uebungen (`isArchived = true`, dieselbe Technik wie
///     `PlanEnvironmentMigrator`s Urlaubs-Modus-Swap) statt sie hart zu loeschen — eine reine
///     Attribut-Aenderung, sicher revertierbar durch Zuruecksetzen. Neu eingefuegte Uebungen sind
///     bis zu einem erfolgreichen Save NIE gespeichert und duerfen deshalb gefahrlos per
///     `context.delete(...)` entfernt werden. Scheitert der Save, macht `revert(...)` GENAU das:
///     alte Uebungen reaktivieren, neue loeschen, Tagesfelder + Fingerprint auf den vor dem Aufruf
///     gesicherten Stand zuruecksetzen — der Context landet exakt im Zustand von VOR dem Aufruf,
///     keine haengenden strukturellen Aenderungen, die ein spaeterer, unabhaengiger Save unbemerkt
///     mitnehmen koennte. Bekannter, bewusst akzeptierter Kompromiss: archivierte, durch
///     `recalculate` ersetzte Uebungen werden NIE hart geloescht und sammeln sich bei
///     wiederholtem "Neu rechnen" auf demselben Tag an (Speicherplatz, keine Korrektheitsfrage) —
///     verifiziert unschaedlich fuer `PlanEnvironmentMigrator.restoreOriginals`, das
///     ausschliesslich ueber `swappedFromOriginal` sucht (von `recalculate` nie gesetzt), nie ueber
///     `isArchived` allein. Ein Aufraeumen dieser archivierten Altlasten braucht ein eigenes,
///     sorgfaeltig geschnittenes Zeitfenster (z.B. nur nach einem bereits erfolgreichen Save) und
///     ist bewusst NICHT Teil dieser Runde.
///
/// **4. Fehlerpropagation ist Aufrufer-Pflicht.** Jeder Aufrufer MUSS einen geworfenen Fehler
/// sichtbar behandeln — kein leeres `catch {}`, kein stilles `try?`, das einen echten Speicherfehler
/// ununterscheidbar von "strukturell nichts zu tun" macht. Siehe `CardioFeasibilityCardModel`
/// (sichtbarer Alert + Retry auf beiden Oberflaechen) und `OnboardingView.finishOnboarding` (kein
/// Alert dort selbst moeglich, da die View zu diesem Zeitpunkt schon verlassen sein kann —
/// stattdessen ein persistiertes Signal, das die naechste Oberflaeche sichtbar aufgreift).
///
/// Jeder andere Pfad in dieser Datei (`makeTemplate`, `apply` fuer sich genommen) ruft weiterhin
/// KEIN `context.save()` auf — das bleibt Verantwortung der beiden oeffentlichen Einstiegspunkte,
/// nicht jeder internen Hilfsfunktion.
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
    /// Nachbesserung (Review nach Task #197): arbeitet auf einem eigenen, isolierten
    /// `ModelContext` — siehe Typ-Doku "Operations-/Fehlervertrag" Punkt 1. Wirft
    /// `PlanCreationError.activePlanCheckFailed`, wenn die Zustandspruefung vor der Aktivierung
    /// selbst scheitert (KEINE Mutation in diesem Fall), und `.saveFailed`, wenn der abschliessende
    /// Save fehlschlaegt (der isolierte Scratch-Context wird dann einfach verworfen).
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

        // Nachbesserung (Review nach Task #197): ein eigener, gleichrangiger Context auf
        // demselben Store/Container - KEIN Kind-Context (SwiftData kennt das Konzept nicht), aber
        // vollstaendig unabhaengig von den Pending Changes des Aufrufer-Context. Schlaegt der Save
        // unten fehl, wird einfach dieser Context verworfen - der Aufrufer-Context wurde nie
        // angefasst, es gibt dort nichts zurueckzubauen. Siehe Typ-Doku Punkt 1 fuer die
        // Begruendung, warum `recalculate` das NICHT ebenso macht.
        let scratchContext = ModelContext(context.container)

        // Nachbesserung (Review nach Task #197, Punkt 3 der Vorgabe): kein
        // `(try? ...) ?? []` mehr - scheitert diese Pruefung, wissen wir NICHT, welche Plaene
        // aktiv waren, und duerfen deshalb GAR NICHT erst mutieren (gleiches Prinzip wie der
        // Session-Fetch in `recalculate`). Laeuft bewusst gegen `scratchContext`, nicht gegen
        // `context`: die gesamte Operation soll gegen EINE konsistente Sicht auf den Store
        // arbeiten, nicht eine Mischung aus zwei Contexts.
        let previouslyActivePlans: [TrainingPlan]
        do {
            previouslyActivePlans = try fetchActivePlans(in: scratchContext)
        } catch {
            throw PlanCreationError.activePlanCheckFailed
        }

        let plan = ProgramInstantiator.instantiate(
            template,
            in: scratchContext,
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
            try save(scratchContext)
        } catch {
            // Nachbesserung (Review nach Task #197): kein Rueckbau noetig - `scratchContext` wird
            // mit dieser Funktion verworfen, der Aufrufer-`context` wurde nie veraendert.
            throw PlanCreationError.saveFailed
        }

        // Nachbesserung (Review nach Task #197): das Ergebnis lebt im `scratchContext` - fuer den
        // Aufrufer (der seinen eigenen `context` fuer Navigation/@Query nutzt) muss es im
        // UEBERGEBENEN Context aufgeloest werden. SwiftData-Modelle sind an ihren Context gebunden;
        // Context-uebergreifend gueltig ist nur die `persistentModelID` (siehe Typ-Doku Punkt 1).
        // Strukturell sollte das nach einem erfolgreichen Save direkt danach nie fehlschlagen
        // (derselbe Store, dieselbe ID, keine Nebenlaeufigkeit auf `@MainActor`) - trotzdem kein
        // Force-Unwrap/Crash, sondern ein benannter, catchbarer Fehler.
        guard let reboundPlan = context.model(for: plan.persistentModelID) as? TrainingPlan else {
            throw PlanCreationError.saveFailed
        }
        return reboundPlan
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

    /// Nachbesserung (Review nach Task #197): typisierte Fehler fuer `build`/`createPlan` — siehe
    /// Typ-Doku "Operations-/Fehlervertrag".
    public enum PlanCreationError: Error, Equatable {
        /// Die Pruefung, welche Plaene gerade aktiv sind (VOR jeder Mutation), ist selbst
        /// fehlgeschlagen — keine Mutation hat stattgefunden.
        case activePlanCheckFailed
        /// Der abschliessende Save des isolierten Scratch-Context ist fehlgeschlagen.
        case saveFailed
    }

    /// Nachbesserung (Review nach Task #197): DI-Seam fuer die Aktivplan-Pruefung in `build`, analog
    /// `fetchAllSessionsOverrideForTesting`. `nil` (Default) aendert nichts.
    static var fetchActivePlansOverrideForTesting: (() throws -> [TrainingPlan])?

    private static func fetchActivePlans(in context: ModelContext) throws -> [TrainingPlan] {
        if let fetchActivePlansOverrideForTesting {
            return try fetchActivePlansOverrideForTesting()
        }
        return try context.fetch(FetchDescriptor<TrainingPlan>(predicate: #Predicate { $0.isActive == true }))
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
        // Nachbesserung (Review nach Task #197): Snapshots der tatsaechlich angewandten
        // Aenderungen - einzige Grundlage fuer `revert(...)`, falls der Save unten fehlschlaegt.
        var snapshots: [DayMutationSnapshot] = []
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
            snapshots.append(apply(
                generatedSpec,
                to: day,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                specByName: specByName,
                in: context
            ))
            rewritten += 1
        }

        // Nachbesserung (Review nach Task #197): echte Fehlerbehandlung statt reiner
        // Autosave-Abhaengigkeit. Nur speichern, wenn tatsaechlich etwas geaendert wurde
        // (begrenzter Commit-Scope, gleiches Muster wie `DeloadManager.startDeload`/`endDeload`) -
        // reines Ueberspringen allein loest keinen Save aus. Siehe Typ-Doku
        // "Operations-/Fehlervertrag" Punkt 3: schlaegt der Save fehl, macht `revert(...)` ALLE
        // Aenderungen dieses Aufrufs rueckgaengig (alte Uebungen reaktivieren, neu eingefuegte
        // loeschen, Tagesfelder zuruecksetzen) - der Context landet exakt im Zustand von VOR
        // diesem Aufruf, keine haengenden strukturellen Aenderungen.
        if rewritten > 0 {
            do {
                try save(context)
            } catch {
                revert(snapshots, in: context)
                throw RecalculateError.saveFailed
            }
        }

        return RecalculateSummary(rewrittenCount: rewritten, skippedDueToHistoryCount: skippedDueToHistory)
    }

    /// Nachbesserung (Review nach Task #197): alles, was `apply` an EINEM Tag veraendert hat -
    /// einzige Grundlage fuer `revert(...)`. Haelt bewusst nur die alten Feldwerte (einfache,
    /// sicher rueckschreibbare Zuweisungen) plus die betroffenen Uebungen selbst (keine Kopien
    /// ihrer Felder - `archivedExercises`/`insertedExercises` sind die echten Objekte, ihr
    /// Rueckbau ist jeweils eine einzelne Zuweisung/ein Delete, siehe `revert`).
    private struct DayMutationSnapshot {
        let day: TrainingDay
        let archivedExercises: [Exercise]
        let insertedExercises: [Exercise]
        let oldName: String
        let oldLocalizationKey: String?
        let oldTimeFormat: WorkoutTimeFormat?
        let oldTimeCapMinutes: Int?
        let oldCircuitRounds: Int?
        let oldCircuitRestSeconds: Int?
        let oldCircuitMode: CircuitRoundMode?
        let oldGenerationFingerprint: String?
    }

    /// Ersetzt Name + Zeitformat + Uebungen eines Tages durch einen frisch
    /// generierten `DaySpec` und schreibt den neuen Fingerprint fest -
    /// gleiche Exercise-Anreicherung wie beim ersten Erzeugen
    /// (`ProgramInstantiator.makeExercise`), keine Zweit-Implementierung.
    ///
    /// Nachbesserung (Review nach Task #197): ARCHIVIERT alte Uebungen (`isArchived = true`)
    /// statt sie hart zu loeschen - siehe Typ-Doku "Operations-/Fehlervertrag" Punkt 3. Das ist
    /// zufaellig GENAU der Mechanismus, den `currentContentFingerprint`/`activeExercises` ohnehin
    /// schon fuer den Urlaubs-Modus-Swap respektieren (beide filtern `isArchived` konsequent aus) -
    /// eine archivierte alte Uebung aendert den Fingerprint also nicht anders, als ein Hard-Delete
    /// es getan haette. Verifiziert unschaedlich fuer
    /// `PlanEnvironmentMigrator.restoreOriginals`: das sucht ausschliesslich ueber
    /// `current.swappedFromOriginal` (gesetzt NUR beim Urlaubs-Swap) nach archivierten Originalen -
    /// die hier neu eingefuegten Uebungen setzen `swappedFromOriginal` nie, koennen also nie
    /// faelschlich ein `recalculate`-archiviertes Original "wiederherstellen".
    private static func apply(
        _ spec: DaySpec,
        to day: TrainingDay,
        timeBasedNames: Set<String>,
        compoundNames: Set<String>,
        specByName: [String: ExerciseTemplateSpec],
        in context: ModelContext
    ) -> DayMutationSnapshot {
        let oldExercises = day.activeExercises
        for exercise in oldExercises {
            exercise.isArchived = true
        }

        let oldName = day.name
        let oldLocalizationKey = day.localizationKey
        let oldTimeFormat = day.timeFormat
        let oldTimeCapMinutes = day.timeCapMinutes
        let oldCircuitRounds = day.circuitRounds
        let oldCircuitRestSeconds = day.circuitRestSeconds
        let oldCircuitMode = day.circuitMode
        let oldGenerationFingerprint = day.generationFingerprint

        day.name = spec.name
        // `customName` wird nicht snapshotted/zurueckgesetzt: es ist Teil von
        // `currentContentFingerprint` (siehe dort) - die Eligibility-Pruefung in `recalculate`
        // (Fingerprint-Gleichheit) hat VOR diesem Aufruf bereits sichergestellt, dass
        // `customName` noch exakt dem Erzeugungs-Stand entspricht (immer `nil` fuer einen
        // Wizard-generierten Tag - jede User-Vergabe eines Namens haette die Fingerprints
        // auseinanderlaufen lassen und den Tag bereits oben uebersprungen). Diese Zeile ist
        // in jedem erreichbaren Fall ein Aufschreiben von `nil` auf bereits `nil`.
        day.customName = nil
        day.localizationKey = spec.localizationKey
        day.timeFormat = spec.timeFormat
        day.timeCapMinutes = spec.timeCapMinutes
        day.circuitRounds = spec.circuitRounds
        day.circuitRestSeconds = spec.circuitRestSeconds
        day.circuitMode = spec.circuitMode

        var insertedExercises: [Exercise] = []
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
            insertedExercises.append(exercise)
        }

        day.generationFingerprint = day.currentContentFingerprint

        return DayMutationSnapshot(
            day: day,
            archivedExercises: oldExercises,
            insertedExercises: insertedExercises,
            oldName: oldName,
            oldLocalizationKey: oldLocalizationKey,
            oldTimeFormat: oldTimeFormat,
            oldTimeCapMinutes: oldTimeCapMinutes,
            oldCircuitRounds: oldCircuitRounds,
            oldCircuitRestSeconds: oldCircuitRestSeconds,
            oldCircuitMode: oldCircuitMode,
            oldGenerationFingerprint: oldGenerationFingerprint
        )
    }

    /// Nachbesserung (Review nach Task #197): macht `apply(...)` fuer genau die Tage rueckgaengig,
    /// die diese `recalculate`-Ausfuehrung selbst veraendert hat - siehe Typ-Doku
    /// "Operations-/Fehlervertrag" Punkt 3. Reine Zuweisungen/Deletes frisch eingefuegter,
    /// NIE gespeicherter Objekte - keine der drei verwendeten Operationen (Attribut zuruecksetzen,
    /// Attribut auf `false`, Delete eines eigenen frischen Inserts) kann fehlschlagen oder einen
    /// weiteren Save-Versuch noetig machen.
    private static func revert(_ snapshots: [DayMutationSnapshot], in context: ModelContext) {
        for snapshot in snapshots {
            for exercise in snapshot.insertedExercises {
                context.delete(exercise)
            }
            for exercise in snapshot.archivedExercises {
                exercise.isArchived = false
            }
            let day = snapshot.day
            day.name = snapshot.oldName
            day.localizationKey = snapshot.oldLocalizationKey
            day.timeFormat = snapshot.oldTimeFormat
            day.timeCapMinutes = snapshot.oldTimeCapMinutes
            day.circuitRounds = snapshot.oldCircuitRounds
            day.circuitRestSeconds = snapshot.oldCircuitRestSeconds
            day.circuitMode = snapshot.oldCircuitMode
            day.generationFingerprint = snapshot.oldGenerationFingerprint
        }
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
