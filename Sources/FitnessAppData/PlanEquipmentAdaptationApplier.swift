#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P5.1 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): bringt die praezise, per-Uebung
/// arbeitende Equipment-Substitutions-Engine (`PlanEquipmentChecker`/
/// `ExerciseSubstitutionEngine`, Smart-Onboarding-Epic Phase 5 — bisher nur VOR
/// der Instanziierung genutzt, in `TemplatePreviewView`/`PlanBuilderView`) auf
/// einen bereits EXISTIERENDEN, live gespeicherten `TrainingPlan` an.
///
/// **Warum ein eigener Typ statt `PlanEnvironmentMigrator` zu erweitern?**
/// `PlanEnvironmentMigrator` loest ausschliesslich gegen `EnvironmentType`
/// (grobe Orts-Kompatibilitaetstabelle, `ExerciseLibraryData.resolveAlternative`).
/// Diese Aufgabe hier loest gegen ein echtes `UserEquipmentProfile` (praezise
/// Pro-Item-Anforderungen) ueber die reviewte Regel-Engine — andere Eingabe,
/// andere Entscheidungslogik, gleiches Archive-statt-Delete-Prinzip. Ein
/// gemeinsamer Typ muesste beide Entscheidungswege ohnehin per Flag trennen;
/// getrennte Typen halten jede Datei auf genau eine Zustaendigkeit fokussiert
/// (gleiche Trennung wie `PlanEquipmentChecker`/`ExerciseSubstitutionEngine`
/// selbst in Core).
///
/// **Archive statt Delete:** identisches Prinzip wie `PlanEnvironmentMigrator`
/// (DEL-049) — die alte Uebung wird NICHT geloescht (das wuerde ihre
/// `ExerciseLog`-Historie per Cascade mitreissen), sondern `isArchived = true`
/// gesetzt; die neue Ersatz-Uebung traegt `swappedFromOriginal` auf das
/// archivierte Original. `TrainingDay.activeExercises` blendet archivierte
/// Eintraege aus der UI aus. Es gibt (anders als bei Environment-Swaps) noch
/// keinen Restore-Pfad hierfuer — ein Profil-Rollback auf das alte Equipment
/// wuerde beim naechsten `check(...)` einfach wieder `.available` ergeben,
/// ohne dass die zwischenzeitlich ersetzte Uebung automatisch zurueckspringt;
/// das deckt sich mit der Vorgabe (reine Vorschau/Ersatzvorschlag-Pflicht,
/// kein Restore-Vertrag gefordert).
///
/// **`@MainActor`:** `apply(...)` nutzt `ProgramInstantiator.makeExercise`/
/// `libraryLookupNames`/`libraryLookupSpecs` — `ProgramInstantiator` selbst
/// ist `@MainActor`-isoliert. Linux' Swift-Toolchain (ohne vollstaendige
/// Concurrency-Pruefung) hat den fehlenden Isolations-Abgleich beim ersten
/// Anlauf NICHT erkannt; Xcode (Apple-CI-Fund) zu Recht schon. Der einzige
/// Aufrufer (`TrainingLocationEquipmentEditorView`, eine SwiftUI-View) laeuft
/// ohnehin bereits auf dem Main-Actor.
@MainActor
public enum PlanEquipmentAdaptationApplier {

    /// Baut eine `DaySpec` aus den AKTIVEN (nicht archivierten) Uebungen eines
    /// `TrainingDay` — archivierte Eintraege ruehren wir nicht an, exakt wie
    /// `PlanEnvironmentMigrator.migrate`.
    private static func daySpec(for day: TrainingDay) -> DaySpec {
        let exercises = day.activeExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exercise in
                ExerciseSpec(
                    name: exercise.name,
                    sets: exercise.sets,
                    repsMin: exercise.repsMin,
                    repsMax: exercise.repsMax,
                    restSeconds: exercise.restSeconds,
                    targetRir: exercise.targetRir,
                    isCardio: exercise.isCardio,
                    targetDistanceKm: exercise.targetDistanceKm,
                    targetDurationMinutes: exercise.targetDurationMinutes,
                    role: exercise.role
                )
            }
        return DaySpec(
            name: day.name,
            localizationKey: day.localizationKey,
            type: day.type,
            sequenceIndex: day.generatorSequenceIndex ?? 0,
            exercises: exercises,
            timeFormat: day.timeFormat,
            timeCapMinutes: day.timeCapMinutes,
            circuitRounds: day.circuitRounds,
            circuitRestSeconds: day.circuitRestSeconds,
            circuitMode: day.circuitMode
        )
    }

    /// Dieselbe Reihenfolge wird fuer `daySpec(for:)` UND fuer `apply(...)`
    /// verwendet — `ExerciseSlot.dayIndex`/`.exerciseIndex` sind reine
    /// Array-Positionen und muessen fuer beide Seiten identisch sein.
    private static func trainingDays(of plan: TrainingPlan) -> [TrainingDay] {
        plan.days
            .filter { $0.type != .rest }
            .sorted { ($0.generatorSequenceIndex ?? 0) < ($1.generatorSequenceIndex ?? 0) }
    }

    /// Reine Statuspruefung — kein Vorschlag, keine Mutation. Grundlage fuer
    /// "muss ueberhaupt etwas angeboten werden?" ohne die (etwas teurere)
    /// Substitutions-Simulation anzustossen.
    public static func check(plan: TrainingPlan, against profile: UserEquipmentProfile) -> PlanEquipmentStatus {
        PlanEquipmentChecker.check(days: trainingDays(of: plan).map(daySpec(for:)), against: profile)
    }

    /// Simuliert eine Anpassung, OHNE zu speichern — fuer die Vorschau/
    /// Ersatzvorschlag-UI (Vorbild: `equipmentStatusBanner`/
    /// `adaptedEquipmentBanner` in `ProgramTemplatePickerView`, die denselben
    /// `PlanAdaptationDraft` fuer Templates VOR der Instanziierung anzeigen).
    public static func preview(
        plan: TrainingPlan,
        against profile: UserEquipmentProfile,
        context: SubstitutionContext,
        rules: [ReviewedSubstitutionRule] = ReviewedSubstitutionCatalog.all
    ) -> PlanAdaptationDraft {
        let days = trainingDays(of: plan).map(daySpec(for:))
        let variant = CheckedPlanVariant(
            profile: nil, days: days,
            equipmentStatus: PlanEquipmentChecker.check(days: days, against: profile)
        )
        return ExerciseSubstitutionEngine.adapt(variant: variant, rules: rules, context: context, profile: profile)
    }

    /// Materialisiert einen zuvor per `preview(...)` erzeugten (und vom User
    /// freigegebenen) Entwurf auf den LIVE-Plan. Nur die tatsaechlich in
    /// `draft.replacements` benannten Slots werden angefasst — jede andere
    /// Uebung (inkl. bereits individuell editierter Saetze/Gewichte) bleibt
    /// unberuehrt, exakt wie `PlanDraft.replaceContent` beim Builder-Pfad
    /// (P3.3) nur den gewaehlten Tag anfasst.
    ///
    /// Nutzt `ProgramInstantiator.makeExercise(...)` fuer die neue Uebung
    /// (DEL-098-Faktoren/`isCompound`/`isTimeBased` aus dem Katalog, statt
    /// defensiver Pauschal-Defaults) — dieselbe Konstruktions-Stelle, die auch
    /// frisch generierte/instanziierte Plaene nutzen.
    @discardableResult
    public static func apply(
        plan: TrainingPlan,
        draft: PlanAdaptationDraft,
        modelContext: ModelContext
    ) -> Int {
        let orderedDays = trainingDays(of: plan)
        let (timeBasedNames, compoundNames) = ProgramInstantiator.libraryLookupNames()
        let librarySpecByName = ProgramInstantiator.libraryLookupSpecs()
        var appliedCount = 0

        for replacement in draft.replacements {
            let dayIndex = replacement.slot.dayIndex
            guard orderedDays.indices.contains(dayIndex),
                  draft.adaptedDays.indices.contains(dayIndex)
            else { continue }

            let day = orderedDays[dayIndex]
            let activeSorted = day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
            let exerciseIndex = replacement.slot.exerciseIndex
            guard activeSorted.indices.contains(exerciseIndex),
                  draft.adaptedDays[dayIndex].exercises.indices.contains(exerciseIndex)
            else { continue }

            let original = activeSorted[exerciseIndex]
            // Defensive Konsistenz-Pruefung: der Slot muss noch dieselbe
            // Uebung treffen, gegen die der Entwurf berechnet wurde (der Plan
            // koennte sich zwischen `preview` und `apply` theoretisch
            // veraendert haben, z.B. durch eine parallele Bearbeitung).
            guard original.name == replacement.originalName else { continue }

            let newSpec = draft.adaptedDays[dayIndex].exercises[exerciseIndex]
            let originalOrderIndex = original.orderIndex
            original.isArchived = true

            let newExercise = ProgramInstantiator.makeExercise(
                from: newSpec,
                orderIndex: originalOrderIndex,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                librarySpecByName: librarySpecByName,
                day: day
            )
            newExercise.swappedFromOriginal = original
            modelContext.insert(newExercise)
            appliedCount += 1
        }

        return appliedCount
    }
}
#endif
