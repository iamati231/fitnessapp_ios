#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Day-Editor-Persistenzbugs (Swipe-Loeschen + Tag-Level-Stepper/Picker):
/// `DayEditorView.deleteExercises(at:)` und die "Fertig"-Checkmark-Aktion
/// (jetzt `saveAndDismiss()`) nutzten bislang KEIN explizites
/// `context.save()` — die Typ-Doku nannte `TrainingDay`/`Exercise`
/// faelschlich "autosaved direkt in SwiftData" ueber `@Bindable`. Tatsaechlich
/// mutiert `@Bindable` nur den Live-Objektgraphen im Speicher; die
/// tatsaechliche Persistenz haengt an SwiftDatas implizitem Context-Autosave,
/// der nach einem App-Kaltstart kurz nach der Aenderung nicht zuverlaessig
/// schon gelaufen sein muss — exakt der bereits an anderer Stelle dieser
/// App per TestingBot bestaetigte Musterfehler (siehe
/// `TrainingDayContentSnapshotWriterTests.testCapturePersistsWithoutAny-
/// AdditionalCallerSave`).
///
/// `deleteExercises`/`saveAndDismiss` sind bewusst WEITERHIN `private` und
/// lesen `self.modelContext` aus `@Environment` — direktes Aufrufen ueber
/// eine ohne lebenden SwiftUI-/`.modelContainer`-Kontext konstruierte
/// `DayEditorView`-Instanz wuerde NICHT den in diesem Test aufgesetzten
/// Context treffen (siehe `EditorDiscardSnapshotTests`-Typ-Dokumentation:
/// "nie `@Environment`-rueckgebundene Properties"). Ein echter
/// View-/UI-Test-Harness fehlt in diesem Repo (siehe dort). Dieser Test
/// beweist deshalb NICHT die beiden Funktionen selbst, sondern die
/// zugrundeliegende Fix-Technik, die beide jetzt anwenden: ein explizites
/// `context.save()` UNMITTELBAR nach der Mutation, OHNE jede weitere
/// UI-Interaktion, uebersteht einen echten Store-Neustart — waehrend
/// dieselbe Mutation OHNE diesen Save (der vorherige Zustand) das nicht
/// garantiert tut. Die tatsaechliche Verdrahtung in `DayEditorView` bleibt
/// per sorgfaeltiger manueller Durchsicht verifiziert (siehe Kommentare an
/// `deleteExercises`/`saveAndDismiss`) und per Geraete-/TestingBot-Kaltstart
/// noch zu bestaetigen — in dieser Session nicht durchfuehrbar (kein
/// TestingBot-Zugriff), ehrlich offen ausgewiesen.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DayEditorPersistenceTests: XCTestCase {

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Reproduziert die Fix-Technik fuer Bug 1 (Swipe-Loeschen): Loeschen +
    /// SOFORTIGER `context.save()`, Container-Ende OHNE jede weitere
    /// Interaktion, dann Store-Neuoeffnung — genau die Sequenz, die ein
    /// App-Kaltstart kurz nach dem Swipe nachbildet.
    func testExerciseDeletionWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-editor-delete-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        var keptExerciseInstanceID: UUID!
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Push A", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
            context.insert(day)
            let toDelete = Exercise(name: "Bankdrücken", exerciseTemplateID: UUID(), orderIndex: 0, day: day)
            context.insert(toDelete)
            let toKeep = Exercise(name: "Kurzhantel-Rudern", exerciseTemplateID: UUID(), orderIndex: 1, day: day)
            context.insert(toKeep)
            try context.save()
            // `PersistentIdentifier` ist NICHT ueber einen Container-Neustart
            // hinweg `==`-stabil (auf Apple-CI empirisch bestaetigt: derselbe
            // Core-Data-Datensatz bekam nach Neuoeffnung einen anders
            // vergleichenden Identifier) - fuer einen echten
            // Identitaetsnachweis ueber den Neustart hinweg stattdessen die
            // eigene, dafuer gebaute stabile `instanceID` verwenden (P8
            // Stufe-2, siehe `Exercise.instanceID`-Dokumentation).
            keptExerciseInstanceID = toKeep.instanceID

            // Exakt die Sequenz aus `deleteExercises(at:)` nach dem Fix:
            // Loeschen, Re-Indizierung, SOFORT `context.save()` — kein
            // weiterer Schritt, der SwiftDatas impliziten Autosave haette
            // ausloesen koennen.
            context.delete(toDelete)
            toKeep.orderIndex = 0
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let exercises = try reopened.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["Kurzhantel-Rudern"], "die Loeschung muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(exercises.first?.instanceID, keptExerciseInstanceID)
        XCTAssertEqual(exercises.first?.orderIndex, 0)
    }

    /// Reproduziert die Fix-Technik fuer Bug 2 (Tag-Level-Stepper/Picker):
    /// Aenderung an `timeFormat`/`circuitRounds`/`circuitRestSeconds` +
    /// SOFORTIGER `context.save()` (wie jetzt in `saveAndDismiss()`),
    /// Container-Ende, Store-Neuoeffnung.
    func testCircuitFieldChangesWithImmediateSaveSurviveARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-editor-circuit-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Zirkel-Tag", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Zirkel", weekday: 2, type: .custom, plan: plan)
            context.insert(day)
            try context.save()

            // Exakt die Sequenz aus `saveAndDismiss()` nach dem Fix: Felder
            // am `@Bindable`-Tag direkt mutieren (wie der Stepper/Picker es
            // tut), SOFORT `context.save()` — kein `dismiss()`-Aufruf noetig,
            // der ist fuer die Persistenz selbst irrelevant.
            day.timeFormat = .circuit
            day.circuitRounds = 5
            day.circuitRestSeconds = 45
            day.circuitMode = .fixedReps
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let days = try reopened.mainContext.fetch(FetchDescriptor<TrainingDay>())
        guard let day = days.first else {
            return XCTFail("der Tag muss einen echten Store-Neustart ueberstehen")
        }
        XCTAssertEqual(day.timeFormat, .circuit)
        XCTAssertEqual(day.circuitRounds, 5)
        XCTAssertEqual(day.circuitRestSeconds, 45)
        XCTAssertEqual(day.circuitMode, .fixedReps)
    }

    /// TestingBot-Regressionscheck (Block A, Deltiq-Abnahme): derselbe
    /// Musterfehler wie oben, diesmal in `PlansListView.deletePlans(at:)`.
    /// Reproduziert auf echtem Geraet: Plan mit laufender (nicht
    /// abgeschlossener) Session loeschen, sofort Force-Quit + Kaltstart —
    /// Plan UND Session waren danach wieder da, die Loeschung war nie auf
    /// der Store-Datei angekommen.
    ///
    /// Nachtrag (Deltiq-Abnahme, Geraete-Nachtest desselben Fixes) — EHRLICH
    /// OFFENER STATUS, NICHT behoben: der urspruengliche Fix (Loeschen +
    /// sofort `context.save()`, sonst nichts) loeste auf echtem Geraet einen
    /// ZWEITEN, bis dahin unentdeckten Absturz aus, reproduzierbar beim
    /// Loeschen des Plans, der die laufende Session besitzt (ein
    /// SwiftData-interner, nicht fangbarer Fatal-Error: `SwiftData/
    /// BackingData.swift:296: Fatal error: Context is missing for ...
    /// TrainingDay/pN`). VIER verschiedene, jeweils auf dem Geraet
    /// gegengeprueftete Fix-Versuche haben das NICHT geloest:
    ///   1. Save per `DispatchQueue.main.async` verzoegern.
    ///   2. `session.day` vorab explizit nullen.
    ///   3. Jeden Tag einzeln statt per Plan-Cascade loeschen, aber noch im
    ///      selben `save()` wie der Plan.
    ///   4. Tag- und Plan-Loeschung in zwei GETRENNTE Saves aufteilen
    ///      (das bildet dieser Test unten nach) — Geraetelog zeigt bei
    ///      diesem Versuch zwei abgeschlossene, separate "CoreData:
    ///      Executing write request"-Bloecke VOR dem Fatal Error; der Crash
    ///      passiert also NACH beiden erfolgreichen Saves, nicht waehrend
    ///      einer SwiftData-Kaskade selbst.
    /// Bekannter, gegengeprueft sicherer Vergleichsfall: derselbe Tag,
    /// dieselbe Session, direkt ueber `PlanEditorView.deleteDays` geloescht
    /// (ohne `PlansListView`s `activeSessions`-@Query/`ActiveSessionBanner`
    /// auf demselben Screen) — crasht NICHT. Die tatsaechliche Ursache liegt
    /// vermutlich in der Interaktion zwischen dieser Kaskade und der auf
    /// demselben Screen aktiven Live-Query, ist aber mit den hier
    /// verfuegbaren Mitteln (kein symbolisierter Crash-Stacktrace) nicht
    /// abschliessend lokalisiert. Weitere Fix-Versuche wurden bewusst nicht
    /// unternommen, um nicht in unbegruendetes Raten zu verfallen.
    ///
    /// Dieser Test beweist weiterhin nur die Persistenz-Technik (Session
    /// entkoppelt + Plan weg nach echtem Store-Neustart) — NICHT, dass der
    /// SwiftUI-/SwiftData-Crash behoben ist (er ist es NICHT, siehe oben).
    /// Fuer den Crash selbst fehlt in diesem Repo ein UI-Test-Harness (siehe
    /// Typ-Doku oben); der TestingBot-Geraete-Nachtest (Swipe-Delete auf den
    /// aktiven Plan mit laufender Session) bleibt der einzige Nachweis und
    /// zeigt den Crash aktuell weiterhin.
    func testPlanDeletionWithOpenSessionAndImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("plans-list-delete-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let planToDelete = TrainingPlan(name: "Full Body 3x", programType: "custom", isActive: true)
            context.insert(planToDelete)
            let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: planToDelete)
            context.insert(day)
            // Offene (nicht abgeschlossene) Session auf diesem Tag — genau
            // die Konstellation aus dem TestingBot-Fund.
            let openSession = WorkoutSession(isCompleted: false, day: day)
            context.insert(openSession)

            let planToKeep = TrainingPlan(name: "Home Gym Hero", programType: "custom", isActive: true)
            context.insert(planToKeep)
            try context.save()

            // Exakt die Sequenz aus `deletePlans(at:)` nach dem Fix: den Tag
            // loeschen und committen, ERST DANACH den jetzt tage-losen Plan
            // in einem ZWEITEN, getrennten Save loeschen.
            context.delete(day)
            try context.save()
            context.delete(planToDelete)
            try context.save()
        }

        // `PersistentIdentifier` ist NICHT ueber einen Container-Neustart
        // hinweg `==`-stabil (siehe die Tests oben) — deshalb hier bewusst
        // KEIN Identitaets-Vergleich, nur der Namens-/Inhalts-Nachweis.
        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let plans = try reopened.mainContext.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(plans.map(\.name), ["Home Gym Hero"],
                        "die Plan-Loeschung muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")

        // Die nullify-Inverse (TrainingDay.sessions -> WorkoutSession.day)
        // darf die Session nicht mit-loeschen, muss `day` aber auf nil
        // setzen — kein dangelnder Fremdbezug auf den geloeschten Tag.
        let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNil(sessions.first?.day)
    }

    /// TestingBot-Regressionscheck (Block B, Deltiq-Abnahme): derselbe
    /// Musterfehler wie oben, diesmal in den vier Zeitformat-Playern
    /// (AMRAP/EMOM/Auf-Zeit in `TimedWorkoutPlayerView.swift`, Circuit in
    /// `CircuitWorkoutPlayerView.swift`). Reproduziert auf echtem Geraet:
    /// AMRAP gestartet, eine Runde per "+1 Runde" geloggt, ~16s gelaufen,
    /// Force-Quit + Kaltstart — statt der 1 Runde + verstrichener Zeit
    /// erschien wieder der Vorlauf-Countdown, danach "0 ROUNDS" und ein
    /// frischer Zeit-Deckel. Root Cause: `completeRound()` (und die
    /// analogen Live-Fortschritts-Schreibstellen `doneBar`/`toggleRound`/
    /// `toggleExerciseChecked`) mutieren `session.roundsCompleted` zwar
    /// SOFORT (das loest das in den dortigen Kommentaren beschriebene
    /// "Training fortsetzen faellt auf alten Stand zurueck"-Problem),
    /// speichern aber nie explizit — identisch zum bereits an fuenf
    /// anderen Stellen gefundenen und behobenen Muster (siehe
    /// `testPlanDeletionWithOpenSessionAndImmediateSaveSurvivesARealStore-
    /// Restart` oben). `init(session:)` liest `session.roundsCompleted`
    /// als Marker "Vorlauf schon durchlaufen" (nil = noch nicht) — ohne
    /// explizites Save faellt der Wert nach einem echten Kaltstart auf
    /// `nil` zurueck, der Vorlauf startet faelschlich neu UND die bereits
    /// gezaehlte Runde ist weg. Exakt die Sequenz aus `completeRound()`
    /// nach dem Fix: Runde zaehlen, SOFORT `context.save()`.
    func testTimedWorkoutRoundProgressWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timed-workout-round-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Spontanes Training", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "AMRAP", weekday: 2, type: .custom, plan: plan, timeFormat: .amrap, timeCapMinutes: 15)
            context.insert(day)
            let session = WorkoutSession(isCompleted: false, day: day)
            context.insert(session)
            try context.save()

            // Exakt die Sequenz aus `finishPreroll()` (Vorlauf -> echter
            // Lauf) + `completeRound()` nach dem Fix: beide schreiben
            // SOFORT, kein Sammeln bis `saveNow()`.
            session.startTime = Date()
            session.roundsCompleted = 0
            try context.save()

            session.roundsCompleted = 1
            try context.save()
        }

        // `init(session:)` liest genau dieses Feld, um Vorlauf vs. Resume
        // zu entscheiden — ein echter Store-Neustart muss den gezaehlten
        // Stand zeigen, nicht auf `nil` (erneuter Vorlauf) zurueckfallen.
        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.roundsCompleted, 1,
                        "die gezaehlte Runde muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
    }

    /// TestingBot-Geraetebefund (Deltiq-Abnahme, Punkt 4): `beginRest()` in
    /// `CircuitWorkoutPlayerView` speichert den neuen Pausen-Anker explizit
    /// (siehe Test oben), `endRest()` (Pausenablauf UND "Skip rest") hatte
    /// denselben Sofort-Save bisher NICHT, obwohl f2a31a5 ausdruecklich "an
    /// allen elf Fundstellen" behoben haben wollte — eine zwoelfte wurde
    /// uebersehen. Auf echtem Geraet reproduziert: Circuit-Runde 1
    /// abgeschlossen (Pause beginnt, korrekt gespeichert), "Skip rest"
    /// getippt (Runde 2 aktiv, 0 abgehakt), sofort Force-Quit + Kaltstart —
    /// die App zeigte nach dem Neustart wieder die (laengst beendete) Pause
    /// fuer Runde 1, weil `circuitRestEndDate` auf der Store-Datei nie auf
    /// `nil` gesetzt wurde. Exakt die Sequenz aus `endRest()` nach dem Fix:
    /// `circuitRestEndDate` auf `nil` setzen, SOFORT `context.save()`.
    func testCircuitEndRestWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("circuit-endrest-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Zirkel-Training", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Zirkel", weekday: 2, type: .custom, plan: plan, timeFormat: .circuit, circuitRounds: 5, circuitRestSeconds: 60)
            context.insert(day)
            let session = WorkoutSession(isCompleted: false, day: day)
            context.insert(session)
            try context.save()

            // Exakt die Sequenz aus `completeCurrentRound()` ->
            // `beginRest()` -> `endRest()` ("Skip rest") nach dem Fix: jede
            // Mutation speichert sofort, keine wartet bis `saveNow()`.
            session.circuitRoundsCompleted = 1
            try context.save()

            session.circuitRestEndDate = Date().addingTimeInterval(60)
            try context.save()

            // "Skip rest": Pausen-Anker weg, SOFORT Save.
            session.circuitRestEndDate = nil
            try context.save()
        }

        // `init(session:)` liest `circuitRestEndDate`, um zu entscheiden, ob
        // gerade eine Pause laeuft — ein echter Store-Neustart muss `nil`
        // zeigen (Runde 2 aktiv), nicht den laengst beendeten Pausen-Anker
        // aus Runde 1.
        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.circuitRoundsCompleted, 1)
        XCTAssertNil(sessions.first?.circuitRestEndDate,
                      "das Pausenende muss einen echten Store-Neustart als nil ueberstehen, nicht als stehengebliebener alter Anker")
    }
}
#endif
