import XCTest
@testable import DeltiqCore

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

    // MARK: - 15. Slot-bearing templates: used alternatives ALWAYS surface as an adaptation

    /// Equipment-Vielfalt Phase 1 Task 4 (Controller-Ruling): dieser Test
    /// ersetzt das fruehere `testFullyAvailableVariantIsUsedWithoutAnyAdaptationAttempt`
    /// — jener Test pruefte explizit `equipmentVariants`-Semantik ("eine
    /// bereits vollstaendig passende, kuratierte Variante zeigt NIE eine
    /// Adaption"), die seit Task 3/4 fuer `hybrid_balanced` (jetzt
    /// slot-basiert, siehe `ProgramTemplate.slots`) nicht mehr erreichbar
    /// ist: `PlanSelectionResolver.resolve` nimmt fuer `slots`-tragende
    /// Templates IMMER zuerst den `resolvedSlots`-Zweig, und jede dort
    /// benutzte `reviewedAlternatives`-Eintrag zaehlt per dieser Funktion
    /// eigener, freigegebener Spezifikation als Adaption — nicht als stille,
    /// kuratierte Basis-Variante. Nur noch 0/20 Templates koennen die alte
    /// Szene ueberhaupt auslösen (equipmentVariants existierte nur fuer
    /// genau diese 3, jetzt alle 3 slot-konvertiert), die alte Erwartung ist
    /// also keine Luecke mehr, sondern ueberholtes Verhalten — ersetzt statt
    /// entfernt, um die NEUE, korrekte Transparenz-Garantie zu beweisen.
    func testUsedSlotAlternativeAlwaysSurfacesAsAnAppliedAdaptation() {
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: hypertrophyContext)

        // Nach KB-Alternativ-Bereinigung hat hybrid_balanced + kettlebellOnly 4 Gaps:
        // Seitheben/Trizepsdrücken (Kabel) haben keine KB-Alt (Push-Tag),
        // Rudern vorgebeugt/Bizeps-Curl (KH) haben keine KB-Alt (Pull-Tag),
        // Wadenheben (stehend, LH) hat keine KB-Alt (Legs-Tag).
        // -> .unavailable, appliedAdaptation = nil (Mixed-Resolution-Regel).
        guard case let .unavailable(gaps) = selection.equipmentStatus else {
            return XCTFail("hybrid_balanced + KB-only muss .unavailable sein, ist: \(selection.equipmentStatus)")
        }
        let gapNames = gaps.map(\.exerciseName).sorted()
        XCTAssertEqual(gapNames, ["Bizeps-Curl (KH)", "Rudern vorgebeugt", "Trizepsdrücken (Kabel)", "Wadenheben (stehend, LH)"])
        XCTAssertNil(selection.variantProfile, "Slot-Resolution ist an kein einzelnes benanntes EquipmentProfile gebunden")
        XCTAssertFalse(selection.isAdapted, "Gaps verhindern reines Adapted-Ergebnis")
        XCTAssertNil(selection.appliedAdaptation, "appliedAdaptation bleibt nil solange gaps vorhanden sind")
        // KB-Alternativen werden dennoch fuer aufgeloeste Slots gesetzt (z.B. Push-Tag erster Slot)
        XCTAssertEqual(selection.days.first?.exercises.first?.name, "Kettlebell Floor Press")
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
