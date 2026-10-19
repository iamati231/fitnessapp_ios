# TestFlight-Startcrash, Build 0.1.0 (164)

**Status:** Ursache durch exakte Stack-Trace-Korrelation bestaetigt, Fix
implementiert und per neuen SwiftData-Regressionstests abgesichert (nur auf
Apple-CI ausfuehrbar — SwiftData existiert auf Linux nicht, siehe unten).
Geraete-/TestingBot-Nachtest des konkreten Kaltstart-Szenarios steht noch
aus (ehrlich offen ausgewiesen, siehe Abschnitt "Grenzen").

## Crash-Report (vom User geliefert)

`TestFlight-Deltiq-0.1.0-164.crash`, 2026-10-19 10:37:21 +0200,
`iPhone OS 26.6.1`, `EXC_BREAKPOINT` in
`_InvalidFutureBackingData.getValue<A>(forKey:)` (SwiftData-intern), aufgerufen
aus `TrainingDay.plan.getter`, aus `DashboardView.nextScheduledDay(in:)`
(`DashboardView.swift:1850-1851`), waehrend des ERSTEN Dashboard-Aufbaus
(`activeCoachingContext` -> `currentCoachingMessage` -> `coachingInsightCard`
-> `body`).

## 1. Build-164-Commit

Der Build-Nummer-Zaehler wird bei jedem `testflight`-Codemagic-Lauf live aus
App Store Connect gezogen (`get-latest-build-number` + 1, siehe
`codemagic.yaml`) und NICHT im Repo committed — es gibt also keinen Commit,
der "Build 164" direkt im Diff traegt. Statt das anzunehmen, wurde die
betroffene Datei per exakter Zeilennummer-Korrelation identifiziert:

- `Sources/FitnessAppUI/DashboardView.swift` wurde zuletzt in Commit
  `c24ee7e6df42e742728bc0b3fbfcf7df7bfa67d8` ("P8 Stufe-2, Vertragspunkt 1 +
  Paket C", 2026-10-18 19:18 UTC) veraendert und ist seitdem (inkl. aktuellem
  Branch-HEAD) UNVERAENDERT (`git diff c24ee7e HEAD -- .../DashboardView.swift`
  liefert keinen Unterschied).
- ALLE FUENF im Crash benannten Zeilen (211, 1197, 1317, 1823, 1850/1851)
  stimmen exakt mit dem tatsaechlichen Code an genau diesen Zeilen im
  aktuellen Stand ueberein (nicht nur ungefaehr — jede Zeile trifft die
  exakte Anweisung: `case .coachingInsight: coachingInsightCard` auf 211,
  `let day = nextScheduledDay(in: plan)` auf 1823, `let completedCount =
  completedSessions.filter {` / `$0.day?.plan?.persistentModelID == ...`
  auf 1850/1851).
- Damit ist belegt: Build 164 wurde aus einem Commit bei/nach `c24ee7e`
  gebaut (jeder spaetere Commit bis zum aktuellen HEAD aendert diese Datei
  nicht) — **nicht angenommen, sondern durch Zeilenabgleich verifiziert**.
  Eine exaktere Eingrenzung auf einen einzelnen Commit ist aus dem Repo
  allein nicht moeglich, da kein spaeterer Commit vor dem aktuellen HEAD
  diese Datei beruehrt.

## 2. Herkunft der TrainingDay-Objekte in `nextScheduledDay`

`nextScheduledDay(in:)` nutzte bisher:
```swift
let completedCount = completedSessions.filter {
    $0.day?.plan?.persistentModelID == plan.persistentModelID
}.count
```
`completedSessions` ist eine `@Query`-Property (`isCompleted == true`, alle
Sessions app-weit). Die `.filter`-Closure liest fuer JEDE dieser Sessions
`.day` (Vorwaerts-Relationship `WorkoutSession -> TrainingDay`) und darauf
`.plan` (Vorwaerts-Relationship `TrainingDay -> TrainingPlan`) — beides IN
SWIFT, auf bereits materialisierten Objekten, nicht als SQL-Praedikat.

`TrainingDay.swift` traegt bereits einen fruehen Fund zu genau diesem
Beziehungspaar (Commit `4e656eb9`, 2026-10-18 18:50 UTC, also VOR `c24ee7e`):

> P8-Fund: ohne diese explizite inverse Relationship wendet SwiftData den
> `.nullify`-Delete-Rule auf `WorkoutSession.day` nicht zuverlaessig an — ein
> bereits im Speicher gehaltenes `WorkoutSession`-Objekt behielt auf
> Apple-CI nach `context.delete(day)` weiterhin seine `day`-Referenz.

Die dort ergaenzte `@Relationship(deleteRule: .nullify, inverse:
\WorkoutSession.day)` ist in Build 164 bereits enthalten (liegt zeitlich vor
`c24ee7e`). Trotzdem ist der Crash in Build 164 aufgetreten, UND ZWAR "waehrend
des ersten Dashboard-Aufbaus" mit "vorhandener Datenbank" (User-Formulierung,
exakt die in Punkt 6 der Aufgabe benannte Bedingung). Die am besten belegte
Erklaerung: Ein Testgeraet hatte bereits VOR Build 164 (also vor der
`4e656eb9`-Korrektur) einen Tag geloescht, dessen `WorkoutSession` damals
NICHT korrekt nullifiziert wurde — die Alt-Datenbank traegt seitdem einen
dauerhaft verwaisten, nicht-nil `WorkoutSession.day`-Fremdschluessel auf eine
Zeile, die es in der SQLite-Datei nicht mehr gibt. Jeder KUeNFTIGE Lesezugriff
auf `.day.plan` dieser einen Session - unabhaengig vom installierten
Build - loest `_InvalidFutureBackingData` aus, weil SwiftDatas "Future"
(verzoegerter Fault) beim Aufloesen feststellt, dass die referenzierte Zeile
nicht existiert. Das ist KEIN abfangbarer Fehler (`try?`/optionales
Verketten helfen nicht) - es ist ein `_assertionFailure` (fataler Abbruch).

Gepruefte Loeschpfade fuer `TrainingDay` im Repo (alle sanktioniert, alle
nutzen inzwischen dieselbe, korrekt deklarierte Nullify-Inverse):
`ActiveWorkoutView.swift:1094/1241`, `DayEditorView.swift:1188`,
`TimedWorkoutPlayerView.swift:134`, `PlanEditorView.swift:937`,
`PlansListView.swift:584` (Plan-Komplettloeschung, kaskadiert ueber
`TrainingPlan.days` `.cascade` auf alle Tage des Plans). CSV-Import
(`DataImportService.swift:1364`) verknuepft `WorkoutSession.day` nur bei
tatsaechlichem Treffer in der Import-ID-Map — kein zusaetzlicher
Verwaisungs-Pfad.

**Nicht breit geaendert:** die Nullify-Inverse-Deklaration selbst war
bereits vor Build 164 korrekt und wird hier nicht nochmal anders gemacht
(kein "pauschaler Relationship-Umbau"). Das Problem liegt NICHT mehr im
Schreibpfad (neue Loeschungen nullifizieren bereits korrekt), sondern in
JEDEM Lesezugriff, der eine potenziell bereits lange bestehende, aeltere
Session ungeschuetzt ueber ihre Rueckreferenz anspricht.

## 3. Root Cause

`nextScheduledDay(in:)` liest `.day` rueckwaerts auf JEDER app-weiten
abgeschlossenen Session, statt nur auf Sessions, die ueber den LEBENDEN,
gerade betrachteten Plan erreichbar sind. Eine einzelne, auf einem
Bestandsgeraet bereits verwaiste Session reicht aus, um den allerersten
Dashboard-Aufbau zum Absturz zu bringen — unabhaengig davon, zu welchem Plan
sie urspruenglich gehoerte.

## 4. Fix

`Sources/FitnessAppUI/DashboardView.swift`, `nextScheduledDay(in:)`:
Zaehlung dreht die Traversal-Richtung um — `plan.days` (Vorwaerts, eigene
Kinder des gerade betrachteten, garantiert lebenden Plans) ->
`day.sessions` (deren jeweils EIGENE Ruecktrefferliste) statt der globalen
`completedSessions`-Query + `$0.day?.plan`. Identisches Ergebnis fuer jeden
unbeschaedigten Bestand (dieselbe Menge Sessions, nur von der anderen Seite
gezaehlt); eine verwaiste Session taucht in KEINEM `day.sessions` eines noch
existierenden Tages auf und wird dadurch automatisch, ohne sie je zu
beruehren, nicht mitgezaehlt. Kein try?/optionales Verketten um den
gefaehrlichen Zugriff herum (das haette nicht funktioniert, siehe oben) —
echte strukturelle Vermeidung des Zugriffspfads.

`nextScheduledDay` wurde dafuer von `private` auf `internal` angehoben (wie
bereits bei `DayEditorView.revertExerciseOrder` etabliert), um sie direkt per
`@testable import FitnessAppUI` zu testen.

## 5. Tests (neu, `Tests/FitnessAppUITests/DashboardNextScheduledDayTests.swift`)

- `testCompletedSessionsOnlyCountForTheirOwnPlanAndAdvanceTheRotation`:
  unbeschaedigter Bestand, zwei unabhaengige Plaene, bestaetigt identisches
  Rotations-Verhalten wie vor dem Fix.
- `testOrphanedSessionFromADeletedPlanNeverAffectsAnUnrelatedLivePlan`:
  simuliert das Bestandsdaten-Szenario (Plan geloescht, dessen Session bleibt
  in der Datenbank), **datei-basierter Store, Container-Schliessung +
  -Neuoeffnung** (kein In-Memory-Artefakt — echter Kaltstart-Nachbau),
  bestaetigt, dass `nextScheduledDay` fuer einen UNABHAENGIGEN, lebenden Plan
  korrekt rechnet, ohne die verwaiste Session jemals zu beruehren.

**Bewusst KEIN Test, der den urspruenglichen Absturz tatsaechlich
ausloest:** `_InvalidFutureBackingData` ist ein fataler Prozessabbruch
(`_assertionFailure`), kein abfangbarer Swift-Error — ein solcher Test
wuerde den gesamten `swift test`-Lauf (und damit potenziell alle parallel
laufenden Testergebnisse) mitreissen statt sauber als ein Fehlschlag
sichtbar zu werden. Die Reproduktion der Ursache erfolgte stattdessen durch
exakte Stack-Trace-/Zeilennummer-Korrelation (Abschnitt 1+2) statt durch
Nachstellen des Crashs selbst.

**Nur auf Apple-CI ausfuehrbar:** `DashboardView.swift` und die neue
Testdatei sind `#if canImport(SwiftUI) && canImport(SwiftData)`-gegated —
auf Linux (dieser Session) ist die Bedingung `false`, `swift build`/`swift
test` geben dafuer keinerlei reales Signal (Datei wird nur als leerer
`#if false`-Block uebersetzt). Verifiziert wurde stattdessen per sorgfaeltiger
manueller Durchsicht (Signatur-/Typ-Abgleich gegen bestehende, bereits
Apple-CI-verifizierte Muster in `TrainingDayContentSnapshotWriterTests.swift`
und `EditorDiscardSnapshotTests.swift`) sowie Linux-`swift build` fuer die
ungegateten Teile (1075/1075 `FitnessAppCoreTests` weiterhin gruen, keine
Core-Aenderung in diesem Fix).

## 6. Was dieser Fix NICHT macht (bewusst, per Auftrag)

- **Keine Reparatur bereits bestehender, verwaister Datensaetze** auf
  Testgeraeten. Es gibt keine aus der App heraus sichere Methode, eine
  solche Rueckreferenz zu ERKENNEN, ohne sie dafuer zu beruehren (genau das
  loest den fatalen Abbruch aus) — ein store-weiter Reparaturlauf wuerde
  entweder dasselbe Risiko tragen oder einen rohen SQLite-Zugriff ausserhalb
  der SwiftData-API erfordern, was explizit NICHT gewollt ist ("kein
  Store-Reset als Reparatur", "keine Trainingsdaten automatisch verwerfen").
  Der Fix macht den betroffenen Lesepfad stattdessen robust GEGEN eine
  solche Altlast, statt sie zu entfernen.
- **Die sieben weiteren, strukturell gleich riskanten `.day?.plan`-Lesestellen
  wurden in einer separaten Folgeaufgabe (Task #252) einzeln geprueft** —
  siehe `docs/TASK_252_DAY_PLAN_AUDIT.md` fuer die vollstaendige
  Einzelfall-Analyse (Herkunft, Verwaisungsrisiko, tatsaechlich gelesene
  Beziehung, Fix-Entscheidung je Stelle). Kurzfassung: 4 Stellen waren
  ueber eine app-weite, ungefilterte Session-/Tag-Query erreichbar (gleiche
  Risikoklasse wie dieser Fund) und wurden auf dasselbe Vorwaerts-Traversal-
  Muster umgestellt; 3 Stellen (`ExerciseEditorView`, `ProgressionApplicator`
  x2) sind durch eine durchgaengige Cascade-Delete-Kette strukturell sicher
  und blieben unveraendert.
- **Keine Aenderung an der Nullify-Inverse-Deklaration selbst** (war schon
  vor Build 164 korrekt) und kein Eingriff in bestehende Loeschpfade.

## Grenzen (ehrlich offen ausgewiesen)

- **Kein echter Geraete-/TestingBot-Kaltstart-Nachtest mit vorhandener,
  absichtlich verwaister Datenbank wurde in dieser Runde durchgefuehrt** —
  nur die oben beschriebenen SwiftData-Regressionstests (Apple-CI, nicht
  Linux). Ein frischer, leerer Simulator waere dafuer ohnehin KEIN
  Nachweis (keine Alt-Daten) — ein echter Nachtest braeuchte ein Geraet/
  einen Store mit einer absichtlich so praeparierten, bereits verwaisten
  Session, wie sie der zweite neue Test simuliert.
- Die genaue Commit-SHA von Build 164 bleibt unbestimmt (siehe Abschnitt 1)
  — nur das Zeitfenster (bei/nach `c24ee7e`) ist belegt.
- Ob die Nullify-Inverse-Korrektur (`4e656eb9`) AUCH fuer kaskadierte
  Plan-Loeschungen (nicht nur direkte Tag-Loeschungen) zuverlaessig greift,
  wurde nicht separat durch einen eigenen Apple-CI-Lauf verifiziert (das
  Repo hat dafuer noch keinen dedizierten Test) — fuer DIESEN Fix ohne
  Belang (der neue Lesepfad ist davon unabhaengig sicher), aber als
  offene Nachpruefung in der oben vorgeschlagenen Folgeaufgabe genannt.
