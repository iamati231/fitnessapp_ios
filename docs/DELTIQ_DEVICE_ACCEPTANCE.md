# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-20, Branch `claude/smart-onboarding-epic`, HEAD `f6d4c81`.
TestingBot-Restbudget zu diesem Zeitpunkt: ca. 36.048 Sekunden (~10 h) von
ursprünglich zugesagten ~15–16,7 h. Kein Merge nach `main`, kein Release.

**Gesamtstatus: A–E bearbeitet; teilweise bestanden, teilweise blockiert.
Gesamtabnahme weiterhin offen.**

## Risikoblöcke A–E (vorheriger Durchgang, unverändert gültig)

Siehe Commit-Historie `f2a31a5`, `81d21da`, `9d62b14` für die im vorherigen
Durchgang gefundenen und gerätebehobenen Bugs (Zeitformat-Fortschritt,
Onboarding-Finish, Day-Editor-Swipe-Delete-Crash). Block D/E (28-/42-Tage-
Review-Fälligkeit) war bereits dort NICHT gerätebestätigt, weil der
TestingBot-Simulator kein Datum/Zeit-Einstellungsfeld hat — siehe unten für
den seither verfolgten, clock-freien Alternativweg.

## Diese Runde: bekannte Lücken geschlossen

| # | Thema | Status |
|---|---|---|
| 1a | `PlansListView.deletePlans` – Save fehlte (Commit `fdad04c`) | geräteverifiziert (Plan+Session-Entkopplung nach Kaltstart korrekt) |
| 1b | **Neuer Fund:** Löschen des AKTIVEN Plans mit laufender Session crasht (SwiftData-interner Fatal Error `Context is missing for ... TrainingDay/pN`) | **Ursache ungelöst** – 4 gerätegetestete interne Fix-Versuche gescheitert (Commits `a6de159`…`84147f3`, alle ehrlich dokumentiert inkl. widerlegter Hypothesen). Nutzerentscheid: **UI-Guard statt interner Reparatur** – `PlansListView.plansBlockedByActiveSession(_:)` verhindert die Löschung jetzt und zeigt einen Hinweis (Commit `f6d4c81`). **Geräteverifiziert**: Crash tritt nicht mehr auf, normale Löschung unverändert funktionsfähig. Die zugrundeliegende SwiftData-Ursache bleibt unbekannt. |
| 2 | `PlanEditorView.deleteDays` / `MeasurementView.deleteCurrentMeasurement` / `ExerciseCard.unlogSet` – Saves fehlten (Commit `49a634d`) | geräteverifiziert |
| 3 | `DayEditorView` ForEach-Identität (`forEachIdentity`, Commit `49a634d`) | geräteverifiziert im tatsächlichen Risiko-Ablauf (neue ungespeicherte Übung + gleichzeitiges Löschen einer anderen Übung) |
| 4 | EMOM/ForTime/Circuit Restart-Zustände (Commit `f2a31a5`) | geräteverifiziert. Dabei 12. übersehene fehlende Save-Stelle gefunden: `CircuitWorkoutPlayerView.endRest()` ("Skip rest") – gefixt und gerätebestätigt (Commit `4036680`) |

## Block D/E (28-/42-Tage-Review-Fälligkeit): weiterhin offen

Geprüfter, grundsätzlich bestätigter clock-freier Weg: `DataImportService`
liest `activated_at_utc`/`block_review_history_json` direkt aus `plans.csv`
(CSV-Backup-Import, erreichbar über Settings → „Daten importieren"). Der
erste Schritt dieses Wegs – einen Export ziehen (Settings → „Export data
(CSV)") – **hängt auf dem TestingBot-Gerät reproduzierbar** beim Öffnen des
Export-Screens (`XCTPerformOnMainRunLoop work timed out`), bestätigt in
**6 unabhängigen Sessions**, auch mit einer frisch installierten App und
genau einem Plan (schließt „zu große Datenmenge" als Ursache aus). Ob echter
App-Bug (z. B. Deadlock in der Navigations-Transition) oder
TestingBot/WebDriverAgent-seitiges Problem, ist ohne symbolisierten
Stacktrace/Instruments-Zugriff nicht abschließend zu klären.

**Status: bekannte Nachweislücke, Auswirkung noch nicht abschließend
geprüft.** Auf Nutzerentscheid wird dieser Weg hier nicht weiterverfolgt;
die 6 ursprünglich vorgesehenen Prüfpunkte (nicht fällig / fällig /
korrekter Plan bei mehreren / Review-Abschluss / Folgeblock+Historie /
Kaltstart ohne Duplikate) bleiben ungeprüft.

## Vier-Stufen-Status-Hinweis

„Geräteverifiziert" bedeutet ausschließlich: auf echtem TestingBot-Gerät
durchgespielt und bestätigt. Es bedeutet NICHT, dass die zugrundeliegende
Ursache (z. B. beim Delete-Crash) verstanden oder behoben ist — dort wurde
bewusst ein Produktverhalten (Verhindern statt Reparieren) gewählt.

## Nächste Schritte

Aufgabenstellung sieht als nächstes das Abarbeiten der ursprünglichen
Testmatrix (Dokument `04_TESTS_UND_ABNAHME.md`, Fälle A01–F08) vor. Dieses
Dokument liegt nicht im Repository (ursprünglich als Chat-Anhang
bereitgestellt) und sein Inhalt ist in der aktuellen Sitzung nicht mehr
verfügbar — wird benötigt, um die Fälle korrekt abzuarbeiten, statt
Testfall-Inhalte zu erfinden.
