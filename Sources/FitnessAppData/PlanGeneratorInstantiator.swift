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
    @discardableResult
    public static func build(
        from input: PlanGeneratorInput,
        in context: ModelContext,
        result precomputed: PlanGenerator.Result? = nil,
        generationSource: GenerationSource = .manual
    ) -> TrainingPlan? {
        let result = precomputed ?? PlanGenerator.generate(from: input)
        guard !result.days.isEmpty else { return nil }
        let template = makeTemplate(from: result)

        let plan = ProgramInstantiator.instantiate(
            template,
            in: context,
            selectedWeekdays: resolvedWeekdays(from: input),
            userEquipment: input.equipmentPreferences
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
    private static func makeTemplate(from result: PlanGenerator.Result) -> ProgramTemplate {
        ProgramTemplate(
            id: "planBuilder.generated",
            name: "Individueller Plan",
            tagline: "",
            descriptionText: "",
            focus: "",
            daysPerWeek: result.days.count,
            days: result.days.map(\.spec),
            targetEnvironment: .gym,
            iconSystemName: "wand.and.stars"
        )
    }
}
#endif
