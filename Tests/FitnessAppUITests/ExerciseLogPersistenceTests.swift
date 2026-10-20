#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs-
/// Nachtest): `ExerciseCard.logSet(setIndex:values:)` fuegte den neuen
/// `ExerciseLog` bisher nur ein, OHNE anschliessenden `context.save()` —
/// derselbe Musterfehler, der in dieser App bereits zwoelf Mal gefunden und
/// gefixt wurde (zuletzt `CardioGoalEditorView.save()`), diesmal im
/// eigentlichen Satz-Logging selbst. Auf dem Geraet reproduziert: ein gerade
/// geloggter Satz (gruener Haken, Volumen-Anzeige bereits aktualisiert)
/// ging bei einem Kaltstart kurz danach verloren — unabhaengig von kg/lbs,
/// das direkt darunterliegende `unlogSet` hat den Fix bereits (siehe dessen
/// eigener Doku-Kommentar). `logSet` selbst bleibt `private`; dieser Test
/// beweist daher dieselbe zugrundeliegende Fix-Technik: Insert + SOFORTIGER
/// `context.save()` uebersteht einen echten Store-Neustart.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExerciseLogPersistenceTests: XCTestCase {

    func testLoggedSetWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("exercise-log-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Unterkörper & Core", weekday: 2, type: .legs, plan: plan)
            context.insert(day)
            let squat = Exercise(name: "Bulgarische Kniebeuge (KH)", exerciseTemplateID: UUID(), orderIndex: 0, day: day)
            context.insert(squat)
            let session = WorkoutSession(startTime: Date(), isCompleted: false, day: day)
            context.insert(session)
            try context.save()

            // Exakt die Sequenz aus `ExerciseCard.logSet(setIndex:values:)`
            // nach dem Fix: neuen Log einfuegen (225 lbs == 102,06 kg, wie
            // am Geraet eingegeben), SOFORT `context.save()` — kein weiterer
            // Schritt, der SwiftDatas impliziten Autosave haette ausloesen
            // koennen.
            let log = ExerciseLog(setIndex: 0, weight: 102.06, reps: 8, rir: 2.5, exercise: squat, session: session)
            context.insert(log)
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let logs = try reopened.mainContext.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logs.count, 1, "muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(logs.first?.weight, 102.06, accuracy: 1e-9)
        XCTAssertEqual(logs.first?.reps, 8)
        XCTAssertEqual(logs.first?.setIndex, 0)
    }
}
#endif
