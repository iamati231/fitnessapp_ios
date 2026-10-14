#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Smart-Onboarding-Epic Phase 5.4 (PLAN_SUBSTITUTION_ENGINE.md Abschnitt 4),
/// Apple-Layer-Tests 18, 21, 22 der Vorgabe (19/20/24 sind reine UI-/
/// Verhaltens-Fragen ohne sinnvollen SwiftData-Test, siehe Abschlussbericht;
/// 23 entfaellt — es werden bewusst KEINE neuen Herkunfts-/Regel-Versions-
/// Felder persistiert, siehe PLAN_SUBSTITUTION_ENGINE.md).
///
/// Linux-Hinweis: wie jeder `FitnessAppDataTests`-Test in diesem Projekt nur
/// kompiliert, nicht lokal ausgefuehrt — laeuft auf dem naechsten Codemagic-
/// Build (macOS).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ResolvedPlanSelectionInstantiationTests: XCTestCase {

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

    private func fullyConfirmedProfile(available: [EquipmentItem: Int?] = [:]) -> UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        for (item, count) in available {
            profile.availability[item] = .available
            if let count { profile.counts[item] = count }
        }
        profile.confirmRemainingAsUnavailable()
        return profile
    }

    /// Test 18: die akzeptierte Vorschau-Auswahl (inkl. tatsaechlich
    /// angewandter Substitutionen) landet EXAKT so im gespeicherten Plan —
    /// keine erneute, abweichende Herleitung durch den Instantiator.
    func testAcceptedAdaptedSelectionIsMaterializedExactlyAsPreviewed() throws {
        // Dumbbell-Variante: "Bankdrücken (KH)" braucht eine Bank, die hier
        // fehlt -> wird ueber R2-aehnliche Logik NICHT ersetzt (keine Regel
        // fuer Bankdruecken), bleibt also absichtlich eine offene Luecke.
        // Fuer einen sauberen "alles aufgeloest"-Fall nehmen wir stattdessen
        // ein Profil, das die Kettlebell-Variante vollstaendig unveraendert
        // erfuellt (Phase 4, kein Substitutions-Pfad noetig) UND zusaetzlich
        // pruefen wir separat die Instanziierung einer ECHTEN Substitution
        // ueber ein synthetisches Template unten.
        let profile = fullyConfirmedProfile(available: [.kettlebell: nil])
        let context = SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        let selection = PlanSelectionResolver.resolve(template: hybridBalanced, profile: profile, context: context)
        XCTAssertFalse(selection.isAdapted, "Vorbedingung: Kettlebell-Variante passt bereits ohne Substitution (Phase 4)")

        let plan = ProgramInstantiator.instantiate(hybridBalanced, in: context, resolvedSelection: selection)
        let materializedNames = Set(plan.days.flatMap { $0.exercises.map(\.name) })
        let expectedNames = Set(selection.days.flatMap { $0.exercises.map(\.name) })
        XCTAssertEqual(materializedNames, expectedNames)
    }

    /// Test 18 (Substitutions-Fall): ein synthetisches Template mit einer
    /// ECHTEN, vollstaendig geloesten Substitution — der gespeicherte Plan
    /// muss die ERSETZTE Uebung enthalten, nicht die urspruengliche, UND
    /// alle Zirkel-Metadaten eines unberuehrten Tages exakt erhalten.
    func testAdaptedSubstitutionIsMaterializedAndUntouchedCircuitMetadataIsPreserved() throws {
        let strengthDay = DaySpec(
            name: "Strength", type: .fullBody, sequenceIndex: 1,
            exercises: [ExerciseSpec(name: "Bulgarische Kniebeuge (KH)", sets: 3, repsMin: 8, repsMax: 12)]
        )
        let circuitDay = DaySpec(
            name: "Circuit", type: .fullBody, sequenceIndex: 2,
            exercises: [ExerciseSpec(name: "Plank", sets: 3, repsMin: 30, repsMax: 45)],
            timeFormat: .circuit, timeCapMinutes: 15, circuitRounds: 4, circuitRestSeconds: 20, circuitMode: .toFailure
        )
        let template = ProgramTemplate(
            id: "test_adapted_instantiation", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 2, days: [strengthDay, circuitDay]
        )
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2]) // Bank fehlt -> R3 greift
        let context = SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        let selection = PlanSelectionResolver.resolve(template: template, profile: profile, context: context)
        XCTAssertTrue(selection.isAdapted)
        XCTAssertEqual(selection.appliedAdaptation?.replacements.first?.replacementName, "Ausfallschritte (KH)")

        let plan = ProgramInstantiator.instantiate(template, in: context, resolvedSelection: selection)

        let strengthPlanDay = plan.days.first { $0.name == "Strength" }
        XCTAssertEqual(strengthPlanDay?.exercises.map(\.name), ["Ausfallschritte (KH)"], "Die ERSETZTE Uebung wird gespeichert, nicht die urspruengliche")

        let circuitPlanDay = plan.days.first { $0.name == "Circuit" }
        XCTAssertEqual(circuitPlanDay?.timeCapMinutes, 15)
        XCTAssertEqual(circuitPlanDay?.circuitRounds, 4)
        XCTAssertEqual(circuitPlanDay?.circuitRestSeconds, 20)
    }

    /// Test 21: eine bestehende, bereits instanziierte Plan-Historie bleibt
    /// unberuehrt, wenn danach ein zweiter (adaptierter) Plan instanziiert
    /// wird — der bestehende Plan wird nur deaktiviert (isActive = false,
    /// bestehendes Verhalten), seine Uebungen/Inhalte aendern sich nicht.
    func testExistingPlanContentIsUnchangedWhenANewAdaptedPlanIsInstantiated() throws {
        let firstProfile = fullyConfirmedProfile(available: [.kettlebell: nil])
        let firstSelection = PlanSelectionResolver.resolve(
            template: hybridBalanced, profile: firstProfile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        )
        let firstPlan = ProgramInstantiator.instantiate(hybridBalanced, in: context, resolvedSelection: firstSelection)
        let firstPlanExerciseNamesBefore = Set(firstPlan.days.flatMap { $0.exercises.map(\.name) })

        let secondTemplate = ProgramTemplate(
            id: "test_second_plan", name: "Zweiter Plan", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: [DaySpec(name: "Tag", type: .fullBody, sequenceIndex: 1, exercises: [ExerciseSpec(name: "Plank", sets: 3, repsMin: 30, repsMax: 45)])]
        )
        _ = ProgramInstantiator.instantiate(secondTemplate, in: context, userEquipmentProfile: firstProfile)

        XCTAssertFalse(firstPlan.isActive, "Alter Plan wird korrekt deaktiviert (bestehendes Verhalten)")
        let firstPlanExerciseNamesAfter = Set(firstPlan.days.flatMap { $0.exercises.map(\.name) })
        XCTAssertEqual(firstPlanExerciseNamesBefore, firstPlanExerciseNamesAfter, "Der INHALT des alten Plans bleibt unveraendert")
    }

    /// Test 22: eine durch Substitution eingefuegte Uebung startet OHNE
    /// jeden uebernommenen Gewichts-/Progressions-Wert aus der Quell-Uebung
    /// — by construction, da `ProgramInstantiator.makeExercise` weder
    /// `suggestedWeight` noch `progressionStep` je aus einem Spec uebernimmt.
    func testSubstitutedExerciseStartsWithoutAnyCopiedWorkingWeightOrProgressionStep() throws {
        let day = DaySpec(name: "Tag", type: .fullBody, sequenceIndex: 1, exercises: [ExerciseSpec(name: "Bulgarische Kniebeuge (KH)", sets: 3, repsMin: 8, repsMax: 12)])
        let template = ProgramTemplate(id: "test_no_copied_weight", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test", daysPerWeek: 1, days: [day])
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2])
        let selection = PlanSelectionResolver.resolve(
            template: template, profile: profile, context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        )
        XCTAssertTrue(selection.isAdapted)

        let plan = ProgramInstantiator.instantiate(template, in: context, resolvedSelection: selection)
        let substituted = try XCTUnwrap(plan.days.first?.exercises.first { $0.name == "Ausfallschritte (KH)" })
        XCTAssertNil(substituted.suggestedWeight, "Keine uebernommene Quell-Last")
        XCTAssertEqual(substituted.progressionStep, 2.5, "Der neutrale Standardwert, nicht aus der Quell-Uebung abgeleitet")
    }
}
#endif
