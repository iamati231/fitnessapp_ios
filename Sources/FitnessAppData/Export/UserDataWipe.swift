// Settings-Epic Phase 5 (docs/SETTINGS_UX_AUDIT.md, Befund RS-03a): App-Reset
// (`SettingsView.resetApp`) und destruktiver Replace-Import
// (`DataImportService.wipeAllUserData`) loeschten denselben Satz von 10
// SwiftData-Typen in derselben Reihenfolge, gepflegt als zwei unabhaengige
// Kopien — das Repo-README warnte bereits vor genau diesem Drift-Risiko.
//
// `ExerciseTemplate` ist bewusst NICHT Teil dieser gemeinsamen Funktion:
// Reset loescht ALLE Templates (System eingeschlossen) und reseedet sie
// danach ueber den `LibrarySeeder`; ein Replace-Import loescht nur
// Custom-Templates und laesst die System-Library unberuehrt. Diese beiden
// Loeschumfaenge unterscheiden sich tatsaechlich — deshalb bleibt
// `ExerciseTemplate` an beiden Call-Sites separat behandelt, statt die
// Differenz ueber ein Flag/Closure in eine gemeinsame Funktion zu zwingen.

#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

public enum UserDataWipe {

    /// Loescht die User-Daten-Typen, deren Loeschumfang zwischen App-Reset
    /// und destruktivem Replace-Import identisch ist — Children-first
    /// ordering, per-instance-Delete (nicht `delete(model:)`/
    /// `NSBatchDeleteRequest`, das `@Relationship`-Cascade/Nullify-Regeln
    /// umgeht und "mandatory OTO nullify inverse"-Violations ausloest).
    ///
    /// Ruft `context.save()` NICHT selbst auf — der Aufrufer committet, meist
    /// zusammen mit weiteren Schritten (Reset: Library-Reseed danach;
    /// Replace-Import: der nachfolgende Merge), damit ein Abbruch dazwischen
    /// nicht einen halb geloeschten, halb gespeicherten Stand hinterlaesst.
    public static func deleteSharedUserData(in context: ModelContext) throws {
        try deleteEach(of: PersonalRecordEntry.self, in: context)
        try deleteEach(of: ExerciseLog.self,         in: context)
        try deleteEach(of: WorkoutSession.self,      in: context)
        try deleteEach(of: Exercise.self,            in: context)
        try deleteEach(of: TrainingDay.self,         in: context)
        try deleteEach(of: TrainingPlan.self,        in: context)
        try deleteEach(of: WaterEntry.self,          in: context)
        try deleteEach(of: BodyMeasurement.self,     in: context)
        try deleteEach(of: PeriodicCheckIn.self,     in: context)
        // MealItem vor MealEntry (dessen Parent), analog zu ExerciseLog vor
        // WorkoutSession oben — Children-first trotz .cascade-Regel.
        try deleteEach(of: MealItem.self,            in: context)
        try deleteEach(of: MealEntry.self,           in: context)
        // DEL-219: Gear muss NACH ExerciseLog/WorkoutSession stehen, damit
        // deren nullify-Relationship zu Gear schon aufgeloest ist, bevor
        // Gear selbst geloescht wird.
        try deleteEach(of: Gear.self,                in: context)
        try deleteEach(of: UserBodyProfile.self,     in: context)
        // Online-Food-Lookup: NUR online importierte/manuell angelegte
        // Katalogeintraege loeschen, niemals die ~100 geseedeten
        // Referenz-Eintraege (source == .seeded, kommen aus FoodCatalogSeeder
        // und werden nicht reseedet). In-memory gefiltert statt per
        // `#Predicate` — die Vergleichbarkeit eines Codable-Enums ueber die
        // Predicate-Macro-Maschinerie ist hier nicht zweifelsfrei genug fuer
        // einen destruktiven Loeschpfad, die Fetch-Groesse (~100 Zeilen) ist
        // fuer in-memory-Filterung irrelevant.
        for entry in try context.fetch(FetchDescriptor<FoodCatalogEntry>()) where entry.source != .seeded {
            context.delete(entry)
        }
    }

    /// Fetcht jede Instanz von `T` und loescht sie einzeln. Oeffentlich, damit
    /// Aufrufer die Typen, die sich zwischen Reset und Replace-Import
    /// unterscheiden (aktuell: `ExerciseTemplate`), mit genau demselben,
    /// cascade-sicheren Muster separat behandeln koennen.
    public static func deleteEach<T: PersistentModel>(of type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}
#endif
