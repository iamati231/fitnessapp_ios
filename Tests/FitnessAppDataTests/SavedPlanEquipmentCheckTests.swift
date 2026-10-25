#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Equipment-Vielfalt Phase 1 Task 4, Step 6/sechste Review-Runde,
/// Praezisierung 4: deckt alle vier dort genannten Anforderungen an
/// `SavedPlanEquipmentCheck.report(for:against:)` ab.
///
/// Linux-Hinweis: wie jeder `FitnessAppDataTests`-Test in diesem Projekt nur
/// kompiliert, nicht lokal ausgefuehrt — laeuft auf dem naechsten Codemagic-
/// Build (macOS). Auf diesem Windows-Rechner blockiert bereits das Bauen von
/// `FitnessAppData` selbst durch das projektweit bekannte ZIPFoundation/
/// CZlib-Problem (siehe Task-4-Report) — rein hand-nachvollzogen gegen die
/// gelesenen Signaturen von `PlanEquipmentChecker`/`TrainingDay`/`Exercise`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class SavedPlanEquipmentCheckTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDownWithError() throws {
        container = nil
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

    @discardableResult
    private func makePlan(exerciseNames: [String], name: String = "Plan") -> TrainingPlan {
        let plan = TrainingPlan(name: name, weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let day = TrainingDay(name: "Tag", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        for exerciseName in exerciseNames {
            let exercise = Exercise(name: exerciseName, day: day)
            context.insert(exercise)
            day.exercises.append(exercise)
        }
        plan.days.append(day)
        return plan
    }

    // MARK: - (1) Identische missing/uncertain-Klassifikation wie PlanEquipmentChecker

    func test_report_matchesPlanEquipmentCheckerExactly_forEquivalentDaySpec() throws {
        let profile = fullyConfirmedProfile() // Nichts verfuegbar -> "Kniebeuge" fehlt definitiv
        let plan = makePlan(exerciseNames: ["Kniebeuge", "Plank"])

        let report = SavedPlanEquipmentCheck.report(for: plan, against: profile)

        let equivalentDays = [DaySpec(name: "Tag", type: .fullBody, sequenceIndex: 1, exercises: [
            ExerciseSpec(name: "Kniebeuge", sets: 1, repsMin: 1, repsMax: 1),
            ExerciseSpec(name: "Plank", sets: 1, repsMin: 1, repsMax: 1)
        ])]
        let expected = PlanEquipmentChecker.fullReport(days: equivalentDays, against: profile)

        XCTAssertEqual(report, expected)
        XCTAssertFalse(report.missing.isEmpty, "Vorbedingung: 'Kniebeuge' muss tatsaechlich fehlen, sonst beweist der Test nichts")
    }

    // MARK: - (2) Reine Neuberechnung bei jedem Aufruf — kein Caching

    func test_report_recomputesPurely_noCachingAcrossCalls() {
        let plan = makePlan(exerciseNames: ["Kniebeuge"])

        let bodyweightOnly = fullyConfirmedProfile()
        let fullBarbell = fullyConfirmedProfile(available: [.barbell: nil, .rack: nil])

        let firstReport = SavedPlanEquipmentCheck.report(for: plan, against: bodyweightOnly)
        let secondReport = SavedPlanEquipmentCheck.report(for: plan, against: fullBarbell)

        XCTAssertFalse(firstReport.isFullyAvailable, "Ohne Langhantel fehlt 'Kniebeuge' definitiv")
        XCTAssertTrue(secondReport.isFullyAvailable, "Mit Langhantel+Rack ist 'Kniebeuge' erfuellt — ZWEI verschiedene Ergebnisse fuer denselben, unveraenderten Plan beweisen, dass nichts zwischengespeichert wird")
    }

    // MARK: - (3) Ignoriert die Uebungen anderer Plaene

    func test_report_ignoresOtherPlansExercises() {
        let profile = fullyConfirmedProfile()
        let planWithGap = makePlan(exerciseNames: ["Kniebeuge"], name: "Mit Luecke")
        let planWithoutGap = makePlan(exerciseNames: ["Plank"], name: "Ohne Luecke")

        let reportWithGap = SavedPlanEquipmentCheck.report(for: planWithGap, against: profile)
        let reportWithoutGap = SavedPlanEquipmentCheck.report(for: planWithoutGap, against: profile)

        XCTAssertFalse(reportWithGap.isFullyAvailable)
        XCTAssertTrue(reportWithoutGap.isFullyAvailable, "Der luecken-freie Plan darf NIE die Luecke des anderen Plans zeigen")
    }

    // MARK: - (4) Leerer Plan (nur Rest-Tage) ist isFullyAvailable

    func test_report_emptyPlan_isFullyAvailable() {
        let plan = TrainingPlan(name: "Leerer Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let restDay = TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan)
        context.insert(restDay)
        plan.days.append(restDay)

        let report = SavedPlanEquipmentCheck.report(for: plan, against: fullyConfirmedProfile())
        XCTAssertTrue(report.isFullyAvailable, "Ein Plan ganz ohne aktive Uebungen hat per Definition keine Luecke")
    }

    // MARK: - Archivierte Uebungen (Urlaubs-Modus-Snapshots) zaehlen nicht mit

    func test_report_excludesArchivedExercises() {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let day = TrainingDay(name: "Tag", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        let archived = Exercise(name: "Kniebeuge", isArchived: true, day: day)
        context.insert(archived)
        day.exercises.append(archived)
        plan.days.append(day)

        let report = SavedPlanEquipmentCheck.report(for: plan, against: fullyConfirmedProfile())
        XCTAssertTrue(report.isFullyAvailable, "`activeExercises` filtert Archiviertes raus — gleiche Regel wie ueberall sonst im Editor")
    }
}
#endif
