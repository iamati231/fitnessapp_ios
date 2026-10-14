import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 5.3 (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 3):
/// Core-Tests 15-16 der Vorgabe (Varianten-uebergreifende Auswahl) — Tests
/// 1-14 + 17 (Engine selbst) leben in `ExerciseSubstitutionEngineTests`.
final class PlanSelectionResolverTests: XCTestCase {

    private func spec(_ name: String, repsMin: Int = 8, repsMax: Int = 12) -> ExerciseSpec {
        ExerciseSpec(name: name, sets: 3, repsMin: repsMin, repsMax: repsMax)
    }

    private func day(_ exercises: [ExerciseSpec]) -> DaySpec {
        DaySpec(name: "Tag", type: .fullBody, sequenceIndex: 1, exercises: exercises)
    }

    private var hypertrophyContext: SubstitutionContext { SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced) }

    private func fullyConfirmedProfile(available: [EquipmentItem: Int?] = [:]) -> UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        for (item, count) in available {
            profile.availability[item] = .available
            if let count { profile.counts[item] = count }
        }
        profile.confirmRemainingAsUnavailable()
        return profile
    }

    // MARK: - 15. Vollstaendig passende Variante wird einer adaptierten vorgezogen

    func testFullyAvailableVariantIsUsedWithoutAnyAdaptationAttempt() {
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: hypertrophyContext)

        XCTAssertEqual(selection.variantProfile, .kettlebellOnly)
        XCTAssertEqual(selection.equipmentStatus, .available)
        XCTAssertNil(selection.appliedAdaptation, "Eine bereits vollstaendig passende Variante darf nie durch einen Adaptionsversuch ersetzt werden")
        XCTAssertFalse(selection.isAdapted)
    }

    // MARK: - 16. Mehrere Quell-Varianten -> deterministisch die mit minimaler Aenderung

    func testResolverPrefersTheSourceVariantNeedingFewerSubstitutions() {
        // Synthetisches Template: Basis braucht ZWEI Substitutionen,
        // die explizite Variante nur EINE — obwohl die Basis die hoehere
        // Prioritaet haette (barbellGym-aequivalent schlaegt dumbbellOnly),
        // muss die Variante mit WENIGER Substitutionen gewinnen.
        let base = [day([spec("Kniebeuge"), spec("Rudern vorgebeugt")])]
        // "Schulterdrücken (KH)" statt z.B. "Goblet Squat" als zweite
        // Uebung, damit die Substitution von "Kniebeuge" -> "Goblet Squat"
        // keine neue Namens-Dopplung erzeugt (haette sonst den
        // Validator-Kollisions-Check ausgeloest, siehe ExerciseSubstitution-
        // EngineTests.testTwoSubstitutionsCollidingOnTheSameTargetWithin...).
        let dumbbellVariant = [day([spec("Kniebeuge"), spec("Schulterdrücken (KH)")])]
        let template = ProgramTemplate(
            id: "test_multi_variant", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: base,
            equipmentVariants: [EquipmentVariant(profile: .dumbbellOnly, days: dumbbellVariant)]
        )
        // 2 Kurzhanteln + verstellbare Bank bestaetigt, Langhantel/Rack fehlen.
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2, .adjustableBench: nil])

        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: hypertrophyContext)

        XCTAssertEqual(selection.variantProfile, .dumbbellOnly, "Nur 1 statt 2 Substitutionen noetig — gewinnt trotz niedrigerer Basis-Prioritaet")
        XCTAssertEqual(selection.appliedAdaptation?.replacements.count, 1)
        XCTAssertEqual(selection.equipmentStatus, .available)
    }

    func testResolverFallsBackTransparentlyWhenNoVariantFullyResolves() {
        let template = ProgramTemplate(
            id: "test_nothing_resolves", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: [day([spec("Front Squat")])] // keine Regel registriert
        )
        let profile = fullyConfirmedProfile()
        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: hypertrophyContext)

        XCTAssertNil(selection.appliedAdaptation)
        XCTAssertEqual(selection.days, template.days, "Transparenter Basis-Fallback, keine stillschweigende Teil-Anpassung")
        XCTAssertTrue(selection.equipmentStatus.isUnavailable)
        XCTAssertFalse(selection.consideredButUnresolvedAdaptations.isEmpty, "Der Versuch bleibt informativ erhalten")
    }

    func testResolvedPlanSelectionCarriesRuleSetVersionAndEquipmentSnapshot() {
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        let profile = fullyConfirmedProfile(available: [.kettlebell: nil])
        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: hypertrophyContext)

        XCTAssertEqual(selection.ruleSetVersion, ReviewedSubstitutionCatalog.version)
        XCTAssertEqual(selection.equipmentSnapshot, profile)
    }
}
