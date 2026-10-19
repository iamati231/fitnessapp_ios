# Day-Editor-Persistenzbugs: Swipe-Löschen + Tag-Level-Stepper/Picker

**Status:** Beide Ursachen durch Codeanalyse bestätigt (gemeinsame Wurzel,
siehe unten), Fix implementiert, per neuen SwiftData-Tests (Apple-CI, nicht
Linux) abgesichert. **Kein Geräte-/TestingBot-Kaltstarttest in dieser Runde
durchgeführt** — in dieser Session steht kein TestingBot-Zugriff zur
Verfügung (ehrlich offen ausgewiesen, siehe Abschnitt "Grenzen").

## Gemeinsame Ursache (geprüft, nicht vorausgesetzt)

`DayEditorView`s Typ-Dokumentation behauptete bisher: "`TrainingDay` ist
`@Bindable` und autosaved direkt in SwiftData." Das ist **falsch** —
`@Bindable` mutiert nur den Live-Objektgraphen im Speicher (deshalb sehen
andere, gleichzeitig offene Views die Änderung sofort), ruft aber selbst
KEIN `context.save()` auf. Die tatsächliche Persistenz auf die Festplatte
hing bislang ausschließlich an SwiftDatas implizitem Context-Autosave.

Zwei bisherige Code-Pfade hatten dadurch dasselbe Loch:

- **`deleteExercises(at:)`** (Swipe-Löschen): löscht die Übung(en), ruft
  aber nirgends `save()` auf.
- **`saveAction`** (der "Fertig"-Checkmark, deckt u.a. `timeFormat`/
  `circuitRounds`/`circuitRestSeconds`/`circuitMode` ab): rief bisher nur
  `dismiss()` auf, ebenfalls ohne `save()`.

Das ist **kein hypothetisches** Risiko — exakt dasselbe Muster wurde in
diesem Repo bereits einmal real auf Apple-CI/TestingBot nachgewiesen (siehe
`TrainingDayContentSnapshotWriterTests.testCapturePersistsWithoutAny-
AdditionalCallerSave`, Kommentar: "Ein echter TestingBot-Gerätetest hat
gezeigt, dass ein App-Kaltstart kurz nach einem Ad-hoc-Edit die Änderung
verliert").

**Warum "Reorder" laut User-Angabe weiterhin funktioniert, obwohl es
architektonisch denselben fehlenden Save hat:** `moveExercises` (Drag&Drop)
mutiert ebenfalls nur `orderIndex` ohne eigenen `save()`. Das wurde in
dieser Runde NICHT verändert (nicht gemeldet, nicht Teil des Auftrags) —
bleibt als dieselbe, noch ungeprüfte Grundannahme (impliziter Autosave
reicht in der Praxis meistens aus, aber nicht garantiert) bestehen.

## Fix

### Bug 1 — Swipe-Löschen (`DayEditorView.deleteExercises(at:)`)

Expliziter `try modelContext.save()` direkt nach Löschung + Reindizierung.
Scheitert der Save: **kein automatischer Wiederaufbau** der gelöschten
Übung(en) — geprüft und bewusst verworfen:
- `context.rollback()` ist in dieser App grundsätzlich ausgeschlossen
  (wirkt auf den GESAMTEN, geteilten Context, siehe
  `PlanGeneratorInstantiator`-Typ-Doku — würde unabhängige, anderswo
  bereits bestätigte Änderungen mit zerstören).
- Eine manuell neu angelegte Ersatz-Übung wäre keine echte
  Wiederherstellung — sie bekäme eine neue `instanceID` und würde damit
  die über P8 Stufe-2 abgesicherte Resume-Identität einer eventuell
  offenen Session brechen.

Stattdessen: sichtbarer Fehlerhinweis über die bestehende
`swapResultToast`-Konvention (neuer gemeinsamer Helfer
`showTransientToast(_:)`), neuer Lokalisierungs-Key
`day.editor.exercise.delete.saveFailed`. Die Übung bleibt aus Nutzersicht
entfernt — genau wie jede andere Löschung ohne Undo-Funktion in diesem
Screen — und kann bei Bedarf über den Bibliotheks-Picker erneut
hinzugefügt werden.

### Bug 2 — Tag-Level-Stepper/Picker (`saveAction` → neue `saveAndDismiss()`)

Checkmark ruft jetzt `saveAndDismiss()` statt direkt `dismiss()` auf:
expliziter `try modelContext.save()`, **nur bei Erfolg** `dismiss()`.
Scheitert der Save, bleibt der Editor offen und zeigt denselben
Toast-Mechanismus (`day.editor.save.failed`) — der User soll nicht glauben,
seine Änderung sei gesichert, während sie es nicht ist.

Das deckt ALLE `metaSection`-Felder ab (nicht nur die im Bug-Report
genannten `timeFormat`/`circuitRounds`/`circuitRestSeconds`/`circuitMode`,
sondern auch `customName`/`weekday`/`type`/`nextIntensity`/
`timeCapMinutes`) — dieselbe Checkmark-Aktion speichert das gesamte Formular
als eine Einheit, keine künstliche Teil-Lösung nur für die im Bug genannten
Felder.

### Bewusst NICHT verändert

- **`revertToSnapshot()` (Verwerfen)**: setzt Felder im Speicher auf den
  Ausgangszustand zurück — braucht keinen eigenen Save, da dadurch nichts
  Neues gegenüber dem bereits persistierten Stand entsteht.
- **`moveExercises` (Reorder)**: laut Auftrag als funktionierend
  vorausgesetzt, nicht Teil dieser beiden gemeldeten Fehler.
- **Kein pauschales `save()` an anderen Stellen** dieser Datei oder anderer
  "Autosave-Screens" (`PlanEditorView`/`ProfileEditorView`/
  `ExerciseEditorView` haben strukturell denselben, hier nicht untersuchten
  Umstand) — nur die zwei konkret gemeldeten Fehler behoben.

## Session-Inhaltsvertrag (geprüft)

Eine bereits offene Session liest ihre Übungen/Struktur über den P8
Stufe-2-Snapshot-Mechanismus (`SessionContentResolver` +
`TrainingDayContentSnapshot`), NICHT live vom `TrainingDay`. Eine über den
Day-Editor extern gelöschte Übung erscheint dort bereits heute korrekt als
`RemovedExerciseCard` (`ActiveWorkoutView.swift`, Kommentar nennt explizit
"z. B. über `DayEditorView`, während diese Session offen blieb" als
vorgesehenen Fall) — unabhängig davon, ob/wann der Day-Editor seinerseits
speichert. Dieser Fix ändert daran nichts; er macht nur die Löschung/
Feldänderung selbst dauerhaft.

## Tests (neu, `Tests/FitnessAppUITests/DayEditorPersistenceTests.swift`)

`deleteExercises`/`saveAndDismiss` bleiben bewusst `private` und lesen
`self.modelContext` aus `@Environment` — eine ohne lebenden SwiftUI-/
`.modelContainer`-Kontext konstruierte `DayEditorView`-Instanz triffe NICHT
den in einem Test aufgesetzten Context (siehe `EditorDiscardSnapshotTests`-
Typ-Doku: "nie `@Environment`-rückgebundene Properties"). Ein echter
View-/UI-Test-Harness fehlt in diesem Repo. Die neuen Tests beweisen deshalb
nicht die beiden Funktionen wörtlich, sondern die zugrundeliegende
Fix-Technik, die beide jetzt anwenden:

- `testExerciseDeletionWithImmediateSaveSurvivesARealStoreRestart`: Löschen
  + sofortiger `save()`, Container-Ende ohne weitere Interaktion,
  Store-Neuöffnung — Löschung bleibt bestehen.
- `testCircuitFieldChangesWithImmediateSaveSurviveARealStoreRestart`:
  `timeFormat`/`circuitRounds`/`circuitRestSeconds`/`circuitMode` setzen +
  sofortiger `save()`, Store-Neuöffnung — alle vier Felder bleiben korrekt.

Beide datei-basiert (nicht In-Memory), Container explizit über die gesamte
Testlaufzeit gehalten (etablierte Konvention, siehe
`TrainingDayContentSnapshotWriterTests`-Typ-Doku).

## Grenzen (ehrlich offen ausgewiesen)

- **Kein echter Geräte-/TestingBot-Kaltstarttest** der tatsächlichen
  `DayEditorView`-UI (Swipe → Bestätigen → App-Neustart → Tag erneut
  öffnen) in dieser Runde — diese Session hat keinen TestingBot-Zugriff.
  Die Verifikation beruht auf (a) exakter Nachbildung der jetzt in
  `DayEditorView` verwendeten Sequenz in einem isolierten SwiftData-Test
  (siehe oben) und (b) sorgfältiger manueller Codedurchsicht.
- Reorder (`moveExercises`) hat strukturell denselben fehlenden Save,
  wurde aber laut Auftrag als funktionierend behandelt und nicht
  angefasst — bleibt eine ungeprüfte Annahme.
- Dieselbe fehlende explizite Save-Garantie besteht vermutlich auch in
  `PlanEditorView`/`ProfileEditorView`/`ExerciseEditorView` (dieselbe
  "Autosave-Screen"-Konvention) — nicht Teil dieses Fixes, nicht
  untersucht.
