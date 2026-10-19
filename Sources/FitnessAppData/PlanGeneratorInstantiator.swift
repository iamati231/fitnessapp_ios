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
/// **Aktivierungsvertrag (korrigiert — vorheriger Stand war veraltet):**
/// alle drei schreibenden Pfade (`createPlan`, Template-Adopt) aktivieren
/// HEUTE automatisch ueber `ProgramInstantiator.instantiate`: ein neu
/// uebernommener Plan wird aktiviert; bereits aktive Plaene werden dabei
/// NICHT automatisch deaktiviert. Mehrere gleichzeitig aktive Plaene sind
/// erlaubt (siehe `ProgramInstantiator`-Typ-Doku, User-Entscheidung im
/// P0-Audit neue Spezifikation).
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
///
/// # Nachbesserung, zweite Korrekturrunde — drei eng begrenzte Vertragsluecken
///
/// **A. `recalculate` auf dem geteilten Context: ein ERFOLGREICHER Save kann weiterhin fremde,
/// unabhaengige offene Aenderungen mitspeichern** (Punkt 1 der obigen Save-Reichweiten-Erklaerung
/// war als Risiko benannt, aber nicht als Produktverhalten akzeptiert). Echte Operationsgrenze ist
/// auf dem geteilten Context nicht moeglich, ohne dieselbe Context-Isolation einzufuehren, die fuer
/// `recalculate` oben bereits explizit ausgeschlossen wurde (Live-Bindungs-Desync). Deshalb stattdessen
/// die vom Auftrag sanktionierte Alternative: `recalculate` prueft VOR jeder eigenen Mutation, ob der
/// Context bereits etwas AUSSERHALB des eigenen Plan-Objektgraphen (Plan selbst + seine Tage + deren
/// Uebungen) offen haelt, und bricht in diesem Fall mit `RecalculateError.independentChangesPending`
/// ab — kein Save versucht, keine Mutation. BEWUSST NICHT per simplem `context.hasChanges` (das
/// waere zu grob): `TrainingPlan` ist ein `@Bindable`-Autosave-Screen
/// (`PlanEditorView`/`PlanMetaSnapshot`) — ein noch nicht automatisch gespeichertes Feld AM
/// SELBEN Plan (z.B. ein gerade editierter `customName`) ist kein "fremder" Zustand, sondern
/// derselbe Bearbeitungsvorgang, und darf `recalculate` nicht blockieren. Die Pruefung nutzt
/// stattdessen `ModelContext.insertedModelsArray`/`.changedModelsArray`/`.deletedModelsArray`
/// (echte, oeffentliche SwiftData-API seit iOS 17.0/macOS 14.0) und vergleicht jedes dort gelistete
/// Objekt per `persistentModelID` gegen die Menge aus `plan`, `plan.days` und deren `exercises`
/// (aktive UND archivierte) — nur ein Objekt AUSSERHALB dieser Menge gilt als "fremd". Da die
/// Funktion synchron auf `@MainActor` laeuft (kein `await` zwischen dieser Pruefung und dem
/// spaeteren `save()`), kann zwischen Pruefung und eigenem Save nichts Fremdes mehr dazukommen —
/// die Pruefung ist fuer die Dauer dieses Aufrufs verlaesslich. Kein `context.rollback()` —
/// unveraendert ausgeschlossen (siehe Punkt 3 oben).
///
/// **B. Erfolgreicher Commit vs. fehlgeschlagene Rueckbindung.** Der bisherige Code warf nach einem
/// ERFOLGREICHEN `save(scratchContext)` denselben `PlanCreationError.saveFailed` wie bei einem
/// echten Speicherfehler, falls NUR die anschliessende `context.model(for:)`-Rueckbindung in den
/// Aufrufer-Context scheiterte — "Es wurde nichts geaendert" waere in diesem Fall FALSCH: der Plan
/// EXISTIERT bereits persistiert, nur die lokale Referenz fehlt. Neuer, eigener Fall
/// `PlanCreationError.createdButRebindFailed(planID:)` traegt die bereits persistierte
/// `PersistentIdentifier` weiter. `createPlan` (der tatsaechlich von allen vier Aufrufern genutzte
/// Einstiegspunkt) faengt diesen Fall sofort ab und versucht GENAU EINMAL erneut aufzuloesen
/// (`resolveCreatedPlan`, derselbe interne `rebind`-Pfad wie `build`s eigener erster Versuch) —
/// gelingt das, kehrt `createPlan` ganz normal mit dem Plan zurueck, ohne dass der Aufrufer je etwas
/// davon bemerkt. Schlaegt auch dieser interne Wiederholungsversuch fehl, wird derselbe
/// `createdButRebindFailed(planID:)` an den Aufrufer weitergereicht — der kann (muss aber nicht
/// zwingend) spaeter ERNEUT `PlanGeneratorInstantiator.resolveCreatedPlan(id:in:)` mit derselben ID
/// aufrufen, OHNE dass dabei jemals ein zweiter Plan entsteht (diese Funktion loest nur auf, sie
/// erzeugt nichts).
///
/// **C. `onGenerated`-Uebergabe (`PlanBuilderView`) muss Erfolg/Fehler zurückmelden.** Betrifft NICHT
/// diese Datei direkt, aber denselben Fehlervertrag: ein `acceptCustom`/`createPlan`-Fehler, der
/// innerhalb der `onGenerated`-Closure auftritt (Cardio-"Plan anpassen"-Pfad), darf das Sheet nicht
/// mehr unbedingt schliessen — siehe `PlanBuilderView.onGenerated`-Typ-Doku fuer den neuen
/// `String?`-Rueckgabewert-Vertrag. Die Onboarding-Entwurfsuebergabe (reines Zwischenspeichern in
/// `@State`, keine Persistenz) bleibt davon unberuehrt — sie liefert immer `nil` (= Erfolg).
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
    /// P5.2 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): seit P3.1
    /// (`GoalDrivenPlanSelectionBuilder`) liefert `PlanBuilderView`s
    /// zielorientierter Einstieg ein ECHTES `TrainingGoal` fuer DIESE
    /// Generierung — die Voraussetzung, die die P2.1-Korrektur oben als
    /// fehlend benannte ("ein dafuer erfundener Wert waere genau der
    /// versteckte Default, den diese Korrektur vermeiden soll"). `nil`
    /// (Default, alle drei anderen Aufrufer unveraendert) behaelt exakt das
    /// bisherige Verhalten (`userEquipmentProfile:` an `instantiate`, reine
    /// Legacy-Variantenwahl ueber `bestEquipmentCheckedVariant`, NIE eine
    /// Substitution). Gesetzt, laeuft stattdessen derselbe
    /// `PlanSelectionResolver.resolve`-Pfad wie `TemplatePreviewView`
    /// (per-Uebung-Substitution via `ExerciseSubstitutionEngine`, nicht nur
    /// Varianten-Auswahl — der synthetische Wegwerf-Template hat zwar nie
    /// `equipmentVariants`, `resolve` substituiert aber bereits INNERHALB der
    /// einen Basis-Variante, das ist unabhaengig von zusaetzlichen
    /// Varianten) — `resolvedSelection:` ist laut `ProgramInstantiator.
    /// instantiate`-Doku bereits die "EINZIGE Quelle der Wahrheit sobald
    /// gesetzt", exakt das hier benoetigte Verhalten.
    @discardableResult
    public static func build(
        from input: PlanGeneratorInput,
        in context: ModelContext,
        environment: EnvironmentType,
        equipmentProfile: UserEquipmentProfile,
        result precomputed: PlanGenerator.Result? = nil,
        generationSource: GenerationSource = .manual,
        generatorGoal: TrainingGoal? = nil,
        experienceTrack: ExperienceTrack? = nil
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

        let plan: TrainingPlan
        if let generatorGoal {
            let resolvedSelection = PlanSelectionResolver.resolve(
                template: template,
                profile: equipmentProfile,
                context: SubstitutionContext(goal: generatorGoal, experienceTrack: experienceTrack)
            )
            plan = ProgramInstantiator.instantiate(
                template,
                in: scratchContext,
                selectedWeekdays: resolvedWeekdays(from: input),
                resolvedSelection: resolvedSelection
            )
        } else {
            plan = ProgramInstantiator.instantiate(
                template,
                in: scratchContext,
                selectedWeekdays: resolvedWeekdays(from: input),
                userEquipmentProfile: equipmentProfile
            )
        }
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
        //
        // Nachbesserung (zweite Korrekturrunde, Punkt B): DER SAVE OBEN IST BEREITS ERFOLGREICH
        // DURCHGELAUFEN - ein Scheitern HIER ist kein Speicherfehler, sondern eine reine
        // Aufloesungs-Luecke. `.saveFailed` waere hier eine falsche Zustandsbeschreibung ("nichts
        // geaendert"); `createdButRebindFailed` traegt stattdessen die bereits persistierte ID
        // weiter, damit der Aufrufer (ueber `createPlan`s internen Retry oder spaeter selbst via
        // `resolveCreatedPlan`) ohne einen zweiten Plan anzulegen wiederaufnehmen kann.
        guard let reboundPlan = rebind(id: plan.persistentModelID, in: context) else {
            throw PlanCreationError.createdButRebindFailed(planID: plan.persistentModelID)
        }
        return reboundPlan
    }

    /// Nachbesserung (zweite Korrekturrunde, Punkt B): DI-Seam fuer die Rueckbindungs-Aufloesung,
    /// analog `fetchActivePlansOverrideForTesting`. `nil` (Default) aendert nichts.
    static var rebindOverrideForTesting: ((PersistentIdentifier, ModelContext) -> TrainingPlan?)?

    private static func rebind(id: PersistentIdentifier, in context: ModelContext) -> TrainingPlan? {
        if let rebindOverrideForTesting {
            return rebindOverrideForTesting(id, context)
        }
        return context.model(for: id) as? TrainingPlan
    }

    /// Nachbesserung (zweite Korrekturrunde, Punkt B): oeffentliche Wiederaufnahme fuer
    /// `PlanCreationError.createdButRebindFailed` — der Plan WURDE bereits erfolgreich angelegt und
    /// gespeichert, nur die Rueckbindung in `context` ist gescheitert (auch nach `createPlan`s
    /// eigenem internen Versuch). Ruft denselben `rebind`-Pfad auf wie `build`/`createPlan` selbst —
    /// ein Aufrufer, der das hier erneut versucht (z.B. nach einem Tipp auf "Erneut versuchen"),
    /// LEGT NIEMALS einen zweiten Plan an: es wird nur aufgeloest, nichts erzeugt.
    @MainActor
    public static func resolveCreatedPlan(id: PersistentIdentifier, in context: ModelContext) -> TrainingPlan? {
        rebind(id: id, in: context)
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
        in context: ModelContext,
        // P5.2: siehe `build(...)`-Doku. `experienceTrack` kommt immer vom
        // echten, uebergebenen Profil (beschreibt den USER, nicht den Plan —
        // anders als `generatorGoal` kein "erfundener" Wert, egal welcher
        // Aufrufer), `generatorGoal` bleibt `nil` fuer alle Aufrufer ausser
        // `PlanBuilderView`s zielorientiertem Einstieg.
        generatorGoal: TrainingGoal? = nil
    ) throws -> TrainingPlan? {
        let effectiveProfile = EquipmentPlanningResolver.resolve(
            environment: profile.environment,
            individualProfile: profile.equipmentProfile,
            confirmedComplete: profile.equipmentProfileConfirmedComplete
        ).effectiveProfile
        // Nachbesserung (zweite Korrekturrunde, Punkt B): EIN automatischer Wiederholungsversuch
        // fuer genau den Fall "Save war erfolgreich, nur die Rueckbindung ist gescheitert" - bevor
        // der Fehler ueberhaupt den Aufrufer erreicht. Ruft dafuer NIE erneut `build` auf (das
        // wuerde einen zweiten Plan anlegen), nur `resolveCreatedPlan` (reine Aufloesung). Jeder der
        // vier Aufrufer dieser Funktion bekommt diese Behandlung dadurch automatisch, ohne sie
        // selbst duplizieren zu muessen.
        do {
            return try build(
                from: input, in: context,
                environment: profile.environment, equipmentProfile: effectiveProfile,
                result: precomputed, generationSource: generationSource,
                generatorGoal: generatorGoal, experienceTrack: profile.experienceTrack
            )
        } catch PlanCreationError.createdButRebindFailed(let planID) {
            if let resolved = resolveCreatedPlan(id: planID, in: context) {
                return resolved
            }
            throw PlanCreationError.createdButRebindFailed(planID: planID)
        }
    }

    /// Nachbesserung (Review nach Task #197): typisierte Fehler fuer `build`/`createPlan` — siehe
    /// Typ-Doku "Operations-/Fehlervertrag".
    public enum PlanCreationError: Error, Equatable {
        /// Die Pruefung, welche Plaene gerade aktiv sind (VOR jeder Mutation), ist selbst
        /// fehlgeschlagen — keine Mutation hat stattgefunden.
        case activePlanCheckFailed
        /// Der abschliessende Save des isolierten Scratch-Context ist fehlgeschlagen. Es wurde
        /// NICHTS geaendert/persistiert — anders als `createdButRebindFailed` unten.
        case saveFailed
        /// Nachbesserung (zweite Korrekturrunde, Punkt B): der Save war ERFOLGREICH — der Plan
        /// EXISTIERT bereits persistiert unter `planID` — nur die anschliessende Rueckbindung in
        /// den Aufrufer-Context ist (auch nach einem internen Wiederholungsversuch in `createPlan`)
        /// gescheitert. NIE als "nichts geaendert" behandeln; ein Aufrufer darf hierauf NIE erneut
        /// `build`/`createPlan` aufrufen (das wuerde einen zweiten Plan anlegen) — nur
        /// `resolveCreatedPlan(id:in:)` mit genau dieser ID ist sicher wiederholbar.
        case createdButRebindFailed(planID: PersistentIdentifier)
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
        /// Nachbesserung (zweite Korrekturrunde, Punkt A): der geteilte Context hatte bereits VOR
        /// diesem Aufruf unabhaengige, nicht gespeicherte Aenderungen — ein Save hier wuerde die
        /// MIT committen (siehe Typ-Doku "Nachbesserung, zweite Korrekturrunde" Punkt A). KEINE
        /// Mutation hat stattgefunden.
        case independentChangesPending
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

    /// Nachbesserung (zweite Korrekturrunde, Punkt A): `true`, wenn `context` ein Objekt
    /// AUSSERHALB des Objektgraphen von `plan` (der Plan selbst, seine Tage, deren Uebungen -
    /// aktive UND archivierte) als ausstehende Aenderung haelt. Nutzt `insertedModelsArray`/
    /// `changedModelsArray`/`deletedModelsArray` (oeffentliche SwiftData-API seit iOS 17.0/
    /// macOS 14.0) statt des groben `hasChanges` - siehe Typ-Doku "Nachbesserung, zweite
    /// Korrekturrunde" Punkt A fuer die Begruendung (ein `@Bindable`-Autosave-Feld AM SELBEN Plan
    /// ist kein "fremder" Zustand). `context.hasChanges` wird trotzdem zuerst geprueft - ein
    /// Billig-Check, der im ueblichen Fall (gar nichts ausstehend) die drei Array-Zugriffe spart.
    ///
    /// Apple-CI-Fund (vierte Korrekturrunde, Nachlauf): eine pendente `WorkoutSession`/ein
    /// pendenter `ExerciseLog`, der sich auf einen Tag/eine Uebung DIESES Plans bezieht, zaehlt
    /// ebenfalls NICHT als "fremd" - `recalculate` fragt genau diese Historie selbst aktiv ab (um
    /// betroffene Tage zu ueberspringen statt sie zu ersetzen), ein pendentes, noch ungespeichertes
    /// Exemplar davon ist also erwarteter, kein unabhaengiger Zustand. Reale, auf Apple-Hardware
    /// erstmals ausgefuehrte Tests (auf Linux syntax-only, da SwiftData dort nicht existiert) haben
    /// das Fehlen dieser Ausnahme als echten Regressions-Bug aufgedeckt (siehe Implementierung).
    private static func hasIndependentPendingChanges(relativeTo plan: TrainingPlan, in context: ModelContext) -> Bool {
        guard context.hasChanges else { return false }

        var ownIDs: Set<PersistentIdentifier> = [plan.persistentModelID]
        for day in plan.days {
            ownIDs.insert(day.persistentModelID)
            for exercise in day.exercises {
                ownIDs.insert(exercise.persistentModelID)
            }
        }

        let pendingObjects: [any PersistentModel] =
            context.insertedModelsArray + context.changedModelsArray + context.deletedModelsArray
        return pendingObjects.contains { object in
            if ownIDs.contains(object.persistentModelID) { return false }
            // Apple-CI-Fund (vierte Korrekturrunde, Nachlauf): eine pendente `WorkoutSession`/ein
            // pendenter `ExerciseLog`, der sich auf einen Tag/eine Uebung DIESES Plans bezieht, ist
            // KEINE unabhaengige Aenderung — es ist genau die Historie, die `recalculate` ein paar
            // Zeilen weiter unten selbst ueber `fetchAllSessions`/`daysWithAnySession` abfragt, um
            // betroffene Tage bewusst zu ueberspringen (siehe dortige Doku). Die urspruengliche
            // Fassung kannte nur `plan`/`days`/`exercises` als "eigen" und blockierte dadurch GENAU
            // die Session-/Log-Szenarien faelschlich, die dieser Schutz nicht treffen soll — real
            // reproduziert durch `testRecalculateSkipsDayWithActiveSessionAndReportsIt` und
            // Geschwister auf echter Hardware (auf Linux nie ausgefuehrt, da SwiftData dort gar
            // nicht existiert). Ein `ExerciseLog`, dessen Uebung bereits auf `nil` degradiert ist
            // (siehe `testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned`), bleibt ueber
            // seine `session`-Referenz trotzdem korrekt zuordenbar.
            if let session = object as? WorkoutSession {
                return !(session.day.map { ownIDs.contains($0.persistentModelID) } ?? false)
            }
            if let log = object as? ExerciseLog {
                let belongsViaExercise = log.exercise.map { ownIDs.contains($0.persistentModelID) } ?? false
                let belongsViaSession = log.session?.day.map { ownIDs.contains($0.persistentModelID) } ?? false
                return !(belongsViaExercise || belongsViaSession)
            }
            return true
        }
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

        // Nachbesserung (zweite Korrekturrunde, Punkt A): `recalculate` bleibt bewusst auf dem
        // geteilten Context (siehe Typ-Doku Punkt 1) - ein ERFOLGREICHER Save wuerde deshalb
        // unbemerkt jede unabhaengige, bereits VOR diesem Aufruf im selben Context offene Aenderung
        // mitnehmen. Das wurde nicht als Produktverhalten akzeptiert. Da eine echte
        // Operationsgrenze hier (anders als bei `build`) nicht gefahrlos moeglich ist, wird die
        // betroffene Schreiboperation stattdessen VOR jeder eigenen Mutation blockiert, wenn der
        // Context bereits etwas AUSSERHALB des Plans selbst offen haelt (siehe
        // `hasIndependentPendingChanges` - bewusst NICHT der grobe `context.hasChanges`, der auch
        // ein noch nicht autogespeichertes Feld AM SELBEN Plan faelschlich blockieren wuerde).
        // Synchron auf `@MainActor`, kein `await` bis zum eigenen `save()` unten - zwischen dieser
        // Pruefung und dem Save kann nichts Neues mehr von aussen dazukommen.
        guard !hasIndependentPendingChanges(relativeTo: plan, in: context) else {
            throw RecalculateError.independentChangesPending
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
            let day = snapshot.day
            for exercise in snapshot.insertedExercises {
                // Apple-CI-Fund (vierte Korrekturrunde, Nachlauf): `context.delete(...)` allein
                // reicht hier NICHT - bei einem frisch inserteten, NIE gespeicherten Objekt
                // (temporaere PersistentIdentifier) blieb `day.exercises` auf echter Hardware
                // (Xcode 26.6/iOS 18 SwiftData) nachweislich noch mit dem geloeschten Objekt
                // bestueckt, bis ein Save/Re-Fetch die Relationship-Array-Seite aktualisiert hat -
                // `day.activeExercises` zeigte direkt nach `revert(...)` 12 statt 6 Uebungen (die
                // urspruenglichen PLUS die eigentlich geloeschten). Auf Linux (SwiftData gar nicht
                // verfuegbar) und damit auch bisher nie real ausgefuehrt, konnte das nicht
                // auffallen. Die explizite Entfernung aus dem Array VOR dem Delete macht den
                // In-Memory-Zustand unabhaengig von dieser Relationship-Timing-Eigenheit korrekt.
                day.exercises.removeAll { $0.persistentModelID == exercise.persistentModelID }
                context.delete(exercise)
            }
            for exercise in snapshot.archivedExercises {
                exercise.isArchived = false
            }
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
