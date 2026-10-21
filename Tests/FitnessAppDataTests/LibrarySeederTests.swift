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

    // MARK: - Bugfix (Geraetetest): deduplicateTemplatesIfNeeded

    /// Kernszenario des gemeldeten Bugs: 5 identische System-Templates fuer
    /// "Bankdruecken" (entstanden durch den behobenen Fetch-Fehler-Bug, der
    /// `seedIfNeeded` bei jedem Start erneut seeden liess) muessen auf genau
    /// 1 reduziert werden.
    func testDeduplicateRemovesExcessSystemTemplateCopies() {
        for _ in 0..<5 {
            context.insert(ExerciseTemplate(
                name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest,
                isCustom: false, localizationKey: "exercise.name.benchpress"
            ))
        }

        let removed = LibrarySeeder.deduplicateTemplatesIfNeeded(in: context)

        XCTAssertEqual(removed, 4)
        let descriptor = FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.name == "Bankdrücken" })
        XCTAssertEqual(try context.fetchCount(descriptor), 1)
    }

    /// Ein Custom-Template mit zufaellig demselben Namen wie eine System-
    /// Uebung darf niemals geloescht werden — Nutzer duerfen bewusst eigene
    /// Uebungen gleich benennen wie eine Library-Uebung.
    func testDeduplicateNeverTouchesCustomTemplateWithSameName() {
        context.insert(ExerciseTemplate(name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest, isCustom: false))
        context.insert(ExerciseTemplate(name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest, isCustom: false))
        let custom = ExerciseTemplate(name: "Bankdrücken", equipment: .dumbbell, primaryMuscle: .chest, isCustom: true)
        context.insert(custom)

        let removed = LibrarySeeder.deduplicateTemplatesIfNeeded(in: context)

        XCTAssertEqual(removed, 1, "nur das ueberzaehlige System-Duplikat, nicht das Custom-Template")
        let customDescriptor = FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.isCustom == true })
        XCTAssertEqual(try context.fetchCount(customDescriptor), 1)
        XCTAssertEqual(try context.fetch(customDescriptor).first?.id, custom.id)
    }

    func testDeduplicateIsIdempotent() {
        for _ in 0..<3 {
            context.insert(ExerciseTemplate(name: "Kniebeuge", equipment: .barbell, primaryMuscle: .quads, isCustom: false))
        }
        _ = LibrarySeeder.deduplicateTemplatesIfNeeded(in: context)
        let secondPass = LibrarySeeder.deduplicateTemplatesIfNeeded(in: context)
        XCTAssertEqual(secondPass, 0, "zweiter Aufruf darf nichts mehr finden")
    }

    /// Mehrere unterschiedlich benannte Dubletten-Gruppen gleichzeitig —
    /// stellt sicher, dass die Gruppierung nicht uebergreifend verwechselt.
    func testDeduplicateHandlesMultipleNameGroupsIndependently() {
        for _ in 0..<3 {
            context.insert(ExerciseTemplate(name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest, isCustom: false))
        }
        for _ in 0..<2 {
            context.insert(ExerciseTemplate(name: "Kniebeuge", equipment: .barbell, primaryMuscle: .quads, isCustom: false))
        }
        context.insert(ExerciseTemplate(name: "Klimmzug", equipment: .bodyweight, primaryMuscle: .back, isCustom: false))

        let removed = LibrarySeeder.deduplicateTemplatesIfNeeded(in: context)

        XCTAssertEqual(removed, 3, "2 ueberzaehlige Bankdruecken + 1 ueberzaehlige Kniebeuge")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.name == "Bankdrücken" })), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.name == "Kniebeuge" })), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { $0.name == "Klimmzug" })), 1)
    }

    // MARK: - backfillCustomNamesIfNeeded (Plaene)

    /// Der frisch angelegte Leer-Plan ("Neuer Plan" + Katalog-Schluessel) ist
    /// kein Nutzer-Name. Ohne die Ausnahme im Backfill wuerde sein deutscher
    /// Name beim naechsten App-Start als `customName` festgeschrieben, und
    /// "New Plan"/"Yeni Plan" waere nie zu sehen.
    func testBackfillCustomNamesKeepsFreshBlankPlanUnnamed() {
        let plan = TrainingPlan(
            name: TrainingPlan.blankPlanName,
            localizationKey: TrainingPlan.blankPlanLocalizationKey
        )
        context.insert(plan)

        let updated = LibrarySeeder.backfillCustomNamesIfNeeded(in: context)

        XCTAssertEqual(updated, 0)
        XCTAssertNil(plan.customName)
    }

    /// Ein umbenannter Plan (Nutzer-Name im `name`-Feld, wie vor DEL-125)
    /// wird weiterhin als `customName` gesichert - auch wenn er noch den
    /// Katalog-Schluessel des Leer-Plans traegt.
    func testBackfillCustomNamesStillSecuresRenamedBlankPlan() {
        let plan = TrainingPlan(
            name: "Mein Push-Plan",
            localizationKey: TrainingPlan.blankPlanLocalizationKey
        )
        context.insert(plan)

        let updated = LibrarySeeder.backfillCustomNamesIfNeeded(in: context)

        XCTAssertEqual(updated, 1)
        XCTAssertEqual(plan.customName, "Mein Push-Plan")
    }

    /// Plaene ohne Schluessel (vor dieser Aenderung angelegt) behalten ihr
    /// bisheriges Verhalten: der Name gilt als Nutzer-Name.
    func testBackfillCustomNamesTreatsKeylessBlankPlanAsUserName() {
        let plan = TrainingPlan(name: TrainingPlan.blankPlanName)
        context.insert(plan)

        _ = LibrarySeeder.backfillCustomNamesIfNeeded(in: context)

        XCTAssertEqual(plan.customName, TrainingPlan.blankPlanName)
    }
}
#endif
