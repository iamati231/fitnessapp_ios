import XCTest

/// Fix-Runde 1 (docs/superpowers/sdd/2026-10-22-ui-consistency, finale
/// Review-Runde, Befund 1): der vorherige Inhalt dieser Datei rief
/// `save(profile:)`s Guard-Form ("guard !isSaving; isSaving = true; defer {
/// isSaving = false }") REENTRANT aus sich selbst heraus auf, um einen
/// "zweiten Tap waehrend des ersten Aufrufs" zu simulieren. Das beweist
/// nichts ueber den tatsaechlichen Bug: auf einem rein synchronen,
/// nie-suspendierenden Save-Pfad (wie in jedem der betroffenen Editoren)
/// kann ein echter zweiter Button-Tap ERST verarbeitet werden, NACHDEM der
/// erste Aufruf bereits vollstaendig zurueckgekehrt ist -- inklusive seines
/// `defer { isSaving = false }`. Der alte Test waere also auch OHNE jeden
/// Fix gruen geblieben; er testete ein Szenario, das ein Button nie erzeugen
/// kann.
///
/// Der tatsaechliche Fix: `defer { isSaving = false }` direkt nach
/// `isSaving = true` wurde aus jedem Editor entfernt, dessen `save()` bei
/// Erfolg `dismiss()` aufruft (oder auf einem Pfad landet, der zuverlaessig
/// dismisst) -- `isSaving` bleibt dort nach einem erfolgreichen Save bewusst
/// `true` (der Screen schliesst sich ohnehin), und wird NUR noch im
/// `catch`-Zweig (fehlgeschlagener Save) bzw. auf einem Erfolgspfad, der
/// NICHT dismisst (z.B. `MeasurementView`s New-Mode, das fuer den naechsten
/// Eintrag offen bleibt, oder `TrainingLocationEquipmentEditorView`s
/// Equipment-Anpassungs-Dialog, der ohne Dismiss weggewischt werden kann),
/// explizit zurueckgesetzt. `PeriodicCheckInView` (der im Review konkret
/// bestaetigte Bug: ein echter Doppeltap legte einen zweiten, komplett
/// leeren All-skip-Rueckblick an) dismisst nie und bekommt stattdessen eine
/// zusaetzliche `didJustSave && !isDirty`-Sperre am Speichern-Haken.
///
/// Da dieses Repo keinen echten SwiftUI-Render-Harness hat, der einen
/// physischen Doppeltap auf einen Button simulieren kann (siehe
/// `EditorDiscardSnapshotTests`-Dateikopf fuer dieselbe dokumentierte
/// Einschraenkung), pruefen diese Tests stattdessen strukturell auf
/// Quelltext-Ebene, dass das vacuous-Guard-Muster nicht wieder auftaucht und
/// dass jeder betroffene Fehlerpfad weiterhin ein explizites Reset behaelt.
final class MeasurementDoubleTapGuardTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Alle sieben von der Review-Runde genannten Editoren mit einem
    /// `isSaving`-Doppeltap-Schutz.
    private static let guardedEditorFiles = [
        "MeasurementView.swift",
        "Settings/BodyDataEditorView.swift",
        "Settings/ExerciseLibraryEditorSheet.swift",
        "Settings/GearListView.swift",
        "Settings/PeriodicCheckInView.swift",
        "Settings/TrainingLocationEquipmentEditorView.swift"
    ]

    func testNoGuardedEditorResetsIsSavingViaAnUnconditionalDefer() throws {
        // "defer { isSaving = false }" direkt nach "isSaving = true" feuert
        // IMMER, bevor ein zweiter Tap physisch eintreffen kann -- das macht
        // den gesamten Guard wirkungslos. Dieses Muster darf in keinem der
        // sieben Editoren wieder auftauchen.
        let vacuousGuardPattern = "defer { isSaving = false }"
        for relativePath in Self.guardedEditorFiles {
            let source = try contents(of: relativePath)
            XCTAssertFalse(
                source.contains(vacuousGuardPattern),
                "\(relativePath): \"\(vacuousGuardPattern)\" macht den Doppeltap-Schutz wirkungslos -- "
                    + "isSaving darf nur noch im catch-Zweig bzw. auf einem nicht-dismissenden "
                    + "Erfolgspfad explizit zurueckgesetzt werden."
            )
        }
    }

    func testEveryGuardedEditorStillResetsIsSavingOnItsFailurePath() throws {
        // Ohne den entfernten `defer` muss jede Datei mindestens ein
        // explizites "isSaving = false" behalten (im catch-Zweig ihres
        // save()), sonst bliebe der Speichern-Button nach einem
        // fehlgeschlagenen Save dauerhaft deaktiviert.
        for relativePath in Self.guardedEditorFiles {
            let source = try contents(of: relativePath)
            XCTAssertTrue(
                source.contains("isSaving = false"),
                "\(relativePath): nach Entfernen des defer muss mindestens der Fehlerpfad isSaving "
                    + "explizit zuruecksetzen, sonst bleibt der Speichern-Button nach einem "
                    + "fehlgeschlagenen Save dauerhaft deaktiviert."
            )
        }
    }

    func testPeriodicCheckInViewDisablesSaveAfterSuccessUntilDirtyAgain() throws {
        // Konkret bestaetigter Bug: PeriodicCheckInView dismisst NICHT bei
        // Erfolg (bleibt offen fuer den naechsten Rueckblick) -- `isSaving`
        // allein kann einen echten Doppeltap deshalb nie blocken, da ein
        // zweiter Tap erst verarbeitet wird, nachdem save() bereits
        // zurueckgekehrt ist. Die eigentliche Sperre muss zusaetzlich
        // `didJustSave && !isDirty` auswerten, damit ein zweiter Tap nach
        // einem erfolgreichen Save (alle Antworten wieder auf .skip) keinen
        // zweiten, leeren Eintrag anlegen kann.
        let source = try contents(of: "Settings/PeriodicCheckInView.swift")
        XCTAssertTrue(
            source.contains("isDisabled: isSaving || (didJustSave && !isDirty)"),
            "PeriodicCheckInViews Speichern-Haekchen muss zusaetzlich zu isSaving auch "
                + "\"didJustSave && !isDirty\" auswerten."
        )
    }

    func testTrainingLocationEquipmentEditorResetsIsSavingOnTheNonDismissingAdaptationBranch() throws {
        // Dieser Editor zeigt nach einem erfolgreichen Save manchmal einen
        // confirmationDialog (Equipment-Anpassung) STATT zu dismissen -- der
        // Dialog kann durch Wegtippen geschlossen werden, ohne dass
        // dismiss() je aufgerufen wird. Ohne ein explizites Reset in diesem
        // Zweig bliebe der Speichern-Haken dann fuer immer deaktiviert.
        let source = try contents(of: "Settings/TrainingLocationEquipmentEditorView.swift")
        guard let branchStart = source.range(of: "pendingEquipmentAdaptation = resolvedProfile") else {
            XCTFail("pendingEquipmentAdaptation-Zweig nicht gefunden -- hat sich save() strukturell geaendert?")
            return
        }
        guard let branchEnd = source[branchStart.upperBound...].range(of: "\n        }") else {
            XCTFail("Ende des pendingEquipmentAdaptation-Zweigs nicht gefunden")
            return
        }
        let branchBody = source[branchStart.upperBound..<branchEnd.lowerBound]
        XCTAssertTrue(
            branchBody.contains("isSaving = false"),
            "Der nicht-dismissende pendingEquipmentAdaptation-Zweig muss isSaving explizit "
                + "zuruecksetzen, sonst bleibt der Speichern-Haken nach Wegtippen des Dialogs "
                + "dauerhaft deaktiviert."
        )
    }

    func testSwipeDismissRollbackDismissesOnlyOnSuccessfulSave() throws {
        // Befund #2: Rollback für Swipe-Dismiss und Cancel ist in rollbackEnvChange(to:)
        // zentralisiert. dismiss() steht dort im do-Block — kein stiller Zustandsbruch
        // bei fehlgeschlagenem Rollback-Save. Beide EnvChange-Sheets müssen die Funktion
        // für Swipe (Binding.set) und Cancel (onCancel) verwenden.
        let source = try contents(of: "Settings/TrainingLocationEquipmentEditorView.swift")

        // 1. Die Funktion existiert genau einmal.
        XCTAssertTrue(
            source.contains("private func rollbackEnvChange(to oldEnv: EnvironmentType)"),
            "rollbackEnvChange(to:) muss als private func existieren"
        )

        // 2. Sie wird in beiden Binding.set-Closures aufgerufen (Swipe-Dismiss).
        let swipeCallCount = source.components(separatedBy: "rollbackEnvChange(to: swap.oldEnv)").count - 1
        XCTAssertGreaterThanOrEqual(swipeCallCount, 2,
            "rollbackEnvChange(to: swap.oldEnv) muss in beiden Binding.set-Closures aufgerufen werden (envSwap + envRestore)")

        // 3. Sie wird in beiden onCancel-Closures aufgerufen (Cancel-Button).
        // Die onCancel-Handler übergeben oldEnv als lokale Kopie, daher "to: oldEnv".
        let cancelCallCount = source.components(separatedBy: "rollbackEnvChange(to: oldEnv)").count - 1
        XCTAssertGreaterThanOrEqual(cancelCallCount, 2,
            "rollbackEnvChange(to: oldEnv) muss in beiden onCancel-Closures aufgerufen werden (envSwap + envRestore)")

        // 4. dismiss() steht INNERHALB der Funktion im do-Block, nicht nach dem catch.
        // Positiv: "try modelContext.save()\n            dismiss()" muss in der Funktion vorkommen.
        XCTAssertTrue(
            source.contains("try modelContext.save()\n            dismiss()"),
            "In rollbackEnvChange: dismiss() muss direkt nach try modelContext.save() im do-Block stehen"
        )

        // 5. Kein dismiss() direkt nach dem catch-Block der Funktion (schlechtes altes Muster).
        XCTAssertFalse(
            source.contains("saveErrorMessage = String(localized: \"day.editor.save.failed\", bundle: .module)\n        }\n        dismiss()"),
            "rollbackEnvChange: dismiss() darf nicht ausserhalb des do-Blocks stehen"
        )
    }
}
