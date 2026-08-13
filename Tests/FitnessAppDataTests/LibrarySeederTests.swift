#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// README 2.35: `LibrarySeeder` selbst hatte bisher keine Tests - genau das
/// liess den Bug durchrutschen, den der Review vor dem Commit gefunden hat
/// (`seedIfNeeded` seedet nur ein komplett leeres Library-Set; neue
/// `ExerciseLibraryData.all`-Eintraege wie "Lauf-Intervall"/"Rad-Intervall"
/// waren fuer jeden Bestandsnutzer dauerhaft unsichtbar im Bibliotheks-
/// Picker, weil der ausschliesslich die persistierte `ExerciseTemplate`-
/// Tabelle abfragt, nicht `ExerciseLibraryData.all` direkt).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class LibrarySeederTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    private func systemTemplateNames() -> Set<String> {
        let descriptor = FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.isCustom == false })
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.name))
    }

    // MARK: - seedIfNeeded

    func testSeedIfNeededPopulatesEmptyLibrary() {
        XCTAssertTrue(LibrarySeeder.seedIfNeeded(in: context))
        XCTAssertEqual(systemTemplateNames(), Set(ExerciseLibraryData.all.map(\.name)))
    }

    func testSeedIfNeededIsNoOpWhenSystemTemplatesAlreadyExist() {
        XCTAssertTrue(LibrarySeeder.seedIfNeeded(in: context))
        XCTAssertFalse(LibrarySeeder.seedIfNeeded(in: context), "zweiter Aufruf darf nicht erneut seeden")
        XCTAssertEqual(systemTemplateNames().count, ExerciseLibraryData.all.count, "keine Duplikate durch doppeltes Seeden")
    }

    // MARK: - README 2.35: backfillNewLibraryEntriesIfNeeded

    /// Simuliert einen Bestandsnutzer: die persistierte Library wurde vor
    /// "Lauf-Intervall"/"Rad-Intervall" geseedet (beide Namen fehlen), der
    /// Rest ist wie gewohnt vorhanden. `seedIfNeeded` wuerde hier nichts tun
    /// (`existing > 0`) - genau der Bug, den der Backfill beheben muss.
    private func seedLibraryMissing(_ missingNames: Set<String>) {
        for spec in ExerciseLibraryData.all where !missingNames.contains(spec.name) {
            context.insert(ExerciseTemplate(
                name: spec.name,
                equipment: spec.equipment,
                primaryMuscle: spec.primaryMuscle,
                isCustom: false,
                difficultyLevel: spec.difficultyLevel,
                isSystemCompound: spec.isSystemCompound,
                isTimeBased: spec.isTimeBased,
                isCardio: spec.isCardio,
                localizationKey: spec.localizationKey,
                isSystemProvided: true
            ))
        }
    }

    func testBackfillAddsExerciseMissingSinceLastSeed() {
        seedLibraryMissing(["Lauf-Intervall", "Rad-Intervall"])
        XCTAssertFalse(systemTemplateNames().contains("Lauf-Intervall"))

        let updated = LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)

        XCTAssertEqual(updated, 2)
        XCTAssertEqual(systemTemplateNames(), Set(ExerciseLibraryData.all.map(\.name)), "Bestandsnutzer muss nach dem Backfill die volle aktuelle Library haben")
    }

    /// Regressionsschutz fuer den konkreten README-2.35-Fall: nicht nur der
    /// Name muss ankommen, sondern auch `isTimeBased`/`isCardio` - sonst
    /// zeigt `TimedWorkoutPlayerView` "Wdh." statt "Sek." fuer die neue
    /// wiederholte Cardio-Runde.
    func testBackfilledEntryCarriesIsTimeBasedAndIsCardioFlags() {
        seedLibraryMissing(["Lauf-Intervall"])
        LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)

        let descriptor = FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.name == "Lauf-Intervall" })
        let template = try? context.fetch(descriptor).first
        XCTAssertEqual(template?.isTimeBased, true)
        XCTAssertEqual(template?.isCardio, true)
    }

    func testBackfillIsIdempotent() {
        seedLibraryMissing(["Lauf-Intervall", "Rad-Intervall"])
        LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)
        let secondPassUpdated = LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)

        XCTAssertEqual(secondPassUpdated, 0, "zweiter Aufruf darf nichts mehr finden")
        XCTAssertEqual(systemTemplateNames().count, ExerciseLibraryData.all.count, "keine Duplikate durch doppelten Backfill")
    }

    func testBackfillIsNoOpRightAfterAFreshSeed() {
        LibrarySeeder.seedIfNeeded(in: context)
        let updated = LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)
        XCTAssertEqual(updated, 0, "frisch geseedete Library hat schon alle aktuellen Eintraege")
    }

    /// Custom-Uebungen (User-erstellt) duerfen den Backfill nicht
    /// beeinflussen - er filtert auf `isCustom == false` und arbeitet
    /// ausschliesslich gegen `ExerciseLibraryData.all`.
    func testBackfillDoesNotTouchCustomTemplates() {
        seedLibraryMissing(["Lauf-Intervall", "Rad-Intervall"])
        context.insert(ExerciseTemplate(name: "Meine eigene Uebung", equipment: .bodyweight, primaryMuscle: .core, isCustom: true))

        _ = LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: context)

        let customDescriptor = FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.isCustom == true })
        let customTemplates = (try? context.fetch(customDescriptor)) ?? []
        XCTAssertEqual(customTemplates.count, 1)
        XCTAssertEqual(customTemplates.first?.name, "Meine eigene Uebung")
    }
}
#endif
