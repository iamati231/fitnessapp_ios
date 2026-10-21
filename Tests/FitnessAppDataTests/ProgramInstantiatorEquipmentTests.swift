#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md Abschnitt
/// 13), Punkt 6: beweist END-TO-END (echter `ModelContext`), dass
/// `ProgramInstantiator.instantiate(..., userEquipmentProfile:)` GENAU die
/// Tage materialisiert, die `ProgramTemplate.bestEquipmentCheckedVariant`
/// zuvor als die "geprueft passende" Variante ausgegeben hat — exakt
/// dieselbe Funktion, die auch `TemplatePreviewView` fuer die Vorschau
/// aufruft. Keine zweite, potenziell abweichende Auswahl-Logik beim
/// tatsaechlichen Instanziieren.
///
/// Linux-Hinweis: wie jeder `FitnessAppDataTests`-Test (SwiftData) in diesem
/// Projekt nur kompiliert, nicht lokal ausgefuehrt (siehe README) — laeuft
/// auf dem naechsten Codemagic-Build (macOS).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ProgramInstantiatorEquipmentTests: XCTestCase {

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

    private var hybridBalanced: ProgramTemplate {
        ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
    }

    /// Szenario "Nur Kettlebells": die instanziierte Variante muss exakt die
    /// Kettlebell-Tage enthalten — nie die Basis (Langhantel) oder Dumbbell.
    func testInstantiateWithKettlebellOnlyProfileUsesTheSameVariantAsBestEquipmentCheckedVariant() throws {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let expected = hybridBalanced.bestEquipmentCheckedVariant(against: profile)
        XCTAssertEqual(expected.profile, .kettlebellOnly, "Vorbedingung des Tests: die Kettlebell-Variante muss ausgewaehlt werden")

        let plan = ProgramInstantiator.instantiate(hybridBalanced, in: context, userEquipmentProfile: profile)
        let materializedNames = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        let expectedNames = Set(expected.days.flatMap { $0.exercises.map(\.name) })

        XCTAssertEqual(materializedNames, expectedNames)
        XCTAssertTrue(materializedNames.contains("Kettlebell Floor Press"))
        XCTAssertFalse(materializedNames.contains("Bankdrücken (KH)"), "Keine Dumbbell-Uebung darf durchrutschen")
        XCTAssertFalse(materializedNames.contains("Bankdrücken"), "Keine Langhantel-Basis-Uebung darf durchrutschen")
    }

    /// Szenario "Nur Koerpergewicht": keine Variante passt — der Instantiator
    /// darf NICHT stillschweigend eine andere (nicht passende) Variante oder
    /// gar ein anderes Template materialisieren. Er zeigt transparent dieselbe
    /// (nicht passende) Basis-Variante, die auch die Vorschau zeigen wuerde
    /// (Punkt 7/8 — keine stille Ersatzloesung, kein erfundener Fix).
    func testInstantiateWithBodyweightOnlyProfileStillMaterializesTheTransparentBaseVariant() throws {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()

        let expected = hybridBalanced.bestEquipmentCheckedVariant(against: profile)
        XCTAssertNil(expected.profile)
        XCTAssertTrue(expected.equipmentStatus.isUnavailable)

        let plan = ProgramInstantiator.instantiate(hybridBalanced, in: context, userEquipmentProfile: profile)
        let materializedNames = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        let expectedNames = Set(expected.days.flatMap { $0.exercises.map(\.name) })
        XCTAssertEqual(materializedNames, expectedNames, "Instanziierung und Vorschau muessen identisch sein, auch wenn die Variante selbst nicht passt")
    }

    /// Ohne `userEquipmentProfile` (Legacy-Aufrufer, z.B. `PlanGeneratorInstantiator`s
    /// synthetisches Template ohne `equipmentVariants`) bleibt das alte
    /// Verhalten ueber `userEquipment`/`resolvedDays` unveraendert.
    func testInstantiateWithoutProfileFallsBackToLegacyResolvedDays() throws {
        let plan = ProgramInstantiator.instantiate(hybridBalanced, in: context, userEquipment: [])
        let materializedNames = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        let legacyExpected = Set(hybridBalanced.resolvedDays(forUserEquipment: []).flatMap { $0.exercises.map(\.name) })
        XCTAssertEqual(materializedNames, legacyExpected)
    }
}
#endif
