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

**Korrigiert (P9, Priorität 2) — der exakte Commit ist jetzt belegt, nicht
nur ein Zeitfenster.** Die ursprüngliche Einschätzung unten ("exaktere
Eingrenzung nicht möglich") war zu vorsichtig: der Codemagic-`testflight`-
Workflow protokolliert die ermittelte Build-Nummer UND den dafür
ausgecheckten Commit direkt im Build selbst, lesend über die Codemagic-API
abrufbar (keine neue Build-Serie nötig).

- Codemagic-`testflight`-Build `6ad4dd8d7550aed8108fdaef`, Schritt
  "Determine build number from App Store Connect":
  `Found build number 163 from TestFlight version 0.1.0` /
  `Using build number: 164` — **diese eine Zahl ist das belegte Build 164**.
- Dieser Build war fuer Commit `600212d6d7682d0839c8482812c9d1a41f8c943e`
  ("docs(P9-Nachbesserung): Apple-CI-Ergebnis fuer Session-Zuordnungs-Fix
  eingetragen") ausgecheckt.
- Die "App Store Connect distribution"-Aufgabe dieses Builds ist als
  `failed` markiert — ABER erst NACH erfolgreichem Upload: "App Store
  Connect finished processing build
  06158838-7cdf-4329-91cd-0408fbf66cbf", danach schlug ausschliesslich die
  Zuordnung zur internen Beta-Gruppe fehl ("Cannot add internal group to a
  build"). Das Binary mit Build-Nummer 164 existiert damit nachweislich bei
  Apple; wie es den berichtenden Tester konkret erreichte (manuelle
  Gruppen-Korrektur, Einzel-Tester-Zuordnung o.ä.), ist von hier aus nicht
  einsehbar — ehrlich offen ausgewiesen. Da Apple Build-Nummern pro App
  eindeutig und aufsteigend vergibt und dieser Upload erfolgreich verarbeitet
  wurde, kann aber KEIN anderer Build ebenfalls die Nummer 164 tragen.
- Gegenprobe: `Sources/FitnessAppUI/DashboardView.swift` bei exakt diesem
  Commit enthaelt `nextScheduledDay(in:)` an Zeile 1848 und den im
  Crash-Report zitierten Code `$0.day?.plan?.persistentModelID == ...` an
  exakt Zeile 1850/1851 — identisch zu den im Originalbericht genannten
  Zeilennummern. Zwei unabhaengige Belege (Build-Log + Zeilenabgleich),
  dieselbe Antwort.

**Wichtige Korrektur gegenueber der ersten Einschaetzung:** `600212d6` liegt
NICHT bei/nach `c24ee7e`, sondern deutlich DAVOR (`c24ee7e` ist kein
Vorfahre von `600212d6`; umgekehrt schon). Die ursprüngliche Analyse hatte
den naheliegenderen, aber falschen Schluss gezogen ("juengster Build vor
dem Crash-Zeitstempel") — siehe Abschnitt 2 fuer die daraus folgende,
wichtigere Korrektur am eigentlichen Mechanismus.

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

`TrainingDay.swift` traegt einen fruehen Fund zu genau diesem
Beziehungspaar (Commit `4e656eb9976788bce0796db30220637c7f81d053`,
2026-10-18 18:50 UTC):

> P8-Fund: ohne diese explizite inverse Relationship wendet SwiftData den
> `.nullify`-Delete-Rule auf `WorkoutSession.day` nicht zuverlaessig an — ein
> bereits im Speicher gehaltenes `WorkoutSession`-Objekt behielt auf
> Apple-CI nach `context.delete(day)` weiterhin seine `day`-Referenz.

**Korrigiert (P9, Priorität 2) — die ursprüngliche zeitliche Einordnung war
falsch herum.** Mit dem jetzt belegten exakten Build-164-Commit
`600212d6` (siehe Abschnitt 1) direkt geprueft: `TrainingDay.swift` bei
`600212d6` enthaelt die `sessions`-Relationship mit ihrer Nullify-Inverse
**ueberhaupt noch nicht** (`git show 600212d6:.../TrainingDay.swift` zeigt
nur die unabhaengige `Exercise.day`-Cascade-Relationship, keine `sessions`-
Deklaration). `600212d6` ist nachweislich ein Vorfahre von `4e656eb9`, nicht
umgekehrt — Build 164 wurde also VOR dem Nullify-Inverse-Fix gebaut, nicht
danach, wie zuvor (aufgrund der damals falsch eingegrenzten Commit-Position)
angenommen.

Das vereinfacht die Erklaerung, statt sie zu verkomplizieren: ein noch
AELTERER Vorgaenger-Build muss nicht mehr postuliert werden. Build 164
SELBST (oder jeder Build davor) konnte beim Loeschen eines `TrainingDay`
`WorkoutSession.day` nicht zuverlaessig nullifizieren — die Alt-Datenbank
des berichtenden Testgeraets traegt seitdem einen dauerhaft verwaisten,
nicht-nil `WorkoutSession.day`-Fremdschluessel auf eine Zeile, die es in der
SQLite-Datei nicht mehr gibt. Dass der Crash erst spaeter, "waehrend des
ERSTEN Dashboard-Aufbaus" mit "vorhandener Datenbank" (User-Formulierung)
auftrat, passt dazu: der fehlerhafte Schreibzugriff (Tag loeschen) und der
fatale Lesezugriff (`nextScheduledDay` beim naechsten Kaltstart) muessen
nicht derselbe Moment gewesen sein. Jeder KUeNFTIGE Lesezugriff auf
`.day.plan` dieser einen Session — unabhaengig vom installierten Build —
loest `_InvalidFutureBackingData` aus, weil SwiftDatas "Future" (verzoegerter
Fault) beim Aufloesen feststellt, dass die referenzierte Zeile nicht
existiert. Das ist KEIN abfangbarer Fehler (`try?`/optionales Verketten
helfen nicht) — es ist ein `_assertionFailure` (fataler Abbruch).

Gepruefte Loeschpfade fuer `TrainingDay` im Repo (alle sanktioniert, alle
nutzen auf dem AKTUELLEN Stand dieselbe, korrekt deklarierte
Nullify-Inverse — seit `4e656eb9`, NACH Build 164):
`ActiveWorkoutView.swift:1094/1241`, `DayEditorView.swift:1188`,
`TimedWorkoutPlayerView.swift:134`, `PlanEditorView.swift:937`,
`PlansListView.swift:584` (Plan-Komplettloeschung, kaskadiert ueber
`TrainingPlan.days` `.cascade` auf alle Tage des Plans). CSV-Import
(`DataImportService.swift:1364`) verknuepft `WorkoutSession.day` nur bei
tatsaechlichem Treffer in der Import-ID-Map — kein zusaetzlicher
Verwaisungs-Pfad.

**Nicht breit geaendert:** die Nullify-Inverse-Deklaration selbst (seit
`4e656eb9` korrekt, also NACH Build 164 hinzugefuegt) wird hier nicht
nochmal anders gemacht (kein "pauschaler Relationship-Umbau"). Fuer NEUE
Loeschungen auf dem aktuellen Stand ist der Schreibpfad bereits korrekt;
offen bleibt ausschliesslich das Lesen potenziell bereits lange bestehender,
aelterer Sessions aus einer Zeit vor diesem Fix ungeschuetzt ueber ihre
Rueckreferenz.

**Wichtige Praezisierung (P9, Priorität 2, Punkt 3) zu den Regressionstests
in Abschnitt 5 und in `docs/TASK_252_DAY_PLAN_AUDIT.md`:** diese Tests
loeschen einen Plan/Tag auf dem AKTUELLEN Schema — das heisst, die
Nullify-Inverse IST dort bereits korrekt deklariert, und die betroffene
`WorkoutSession.day`-Referenz wird beim Test-Delete aller Voraussicht nach
sauber auf `nil` gesetzt (die Tests pruefen das bewusst NICHT explizit —
genau deshalb sind sie unabhaengig vom tatsaechlichen Nullify-Ausgang
aussagekraeftig, siehe naechster Absatz). Eine auf dem AKTUELLEN Schema
durchgefuehrte Loeschung ist damit AUSDRUECKLICH KEINE exakte Reproduktion
der historischen, echten `_InvalidFutureBackingData`-ausloesenden
Referenz aus Build 164 (die entstand, weil die Nullify-Inverse zu dieser
Zeit schlicht NICHT existierte) — eine solche Referenz liesse sich aus der
App heraus auf dem aktuellen Schema gar nicht mehr erzeugen, ohne SwiftData
zu umgehen (z. B. rohen SQLite-Zugriff), was hier bewusst nicht gemacht
wird. Was die Tests tatsaechlich beweisen: der NEUE, vorwaertsgerichtete
Lesepfad (`plan.days` -> `day.sessions`) beruehrt `session.day`/`day.plan`
fuer eine Session, deren urspruenglicher Plan geloescht wurde, UEBERHAUPT
NICHT — unabhaengig davon, ob die Nullifizierung im konkreten Testlauf
tatsaechlich griff (Referenz wurde `nil`) oder nicht (Referenz waere
dangling geblieben). Das ist eine STAERKERE, schema-unabhaengige
Eigenschaft als eine blosse Reproduktion des historischen Einzelfalls — sie
wird hier bewusst nicht als Letzteres ausgegeben.

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
- **Die acht weiteren, strukturell gleich riskanten `.day?.plan`-Lesestellen
  wurden in einer separaten Folgeaufgabe (Task #252) einzeln geprueft** —
  siehe `docs/TASK_252_DAY_PLAN_AUDIT.md` fuer die vollstaendige
  Einzelfall-Analyse (Herkunft, Verwaisungsrisiko, tatsaechlich gelesene
  Beziehung, Fix-Entscheidung je Stelle) sowie die dortige Zaehlungskorrektur
  (P9 Prioritaet 3: Assembler 1 + Dashboard 3 + Summary 1 + Editor 1 +
  Progression 2 = 8, vorher faelschlich als "sieben" benannt). Kurzfassung:
  5 Stellen (`FourWeekReviewAssembler` 1, `DashboardView` 3, `WorkoutSummaryView`
  1) waren ueber eine app-weite, ungefilterte Session-/Tag-Query erreichbar
  (gleiche Risikoklasse wie dieser Fund) und wurden auf dasselbe
  Vorwaerts-Traversal-Muster umgestellt; 3 Stellen (`ExerciseEditorView`,
  `ProgressionApplicator` x2) sind durch eine durchgaengige Cascade-Delete-Kette
  strukturell sicher und blieben unveraendert.
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
- **Korrigiert (P9, Priorität 2):** die genaue Commit-SHA von Build 164 ist
  jetzt belegt (`600212d6d7682d0839c8482812c9d1a41f8c943e`, siehe Abschnitt
  1) — per Codemagic-Build-Log, nicht nur per Zeitfenster. Dabei stellte
  sich zusaetzlich heraus, dass die urspruengliche zeitliche Einordnung
  ("liegt zeitlich vor `c24ee7e`") falsch herum war — siehe die Korrektur
  in Abschnitt 2 zum tatsaechlichen Mechanismus.
- **Beantwortet (P9, Priorität 2):** ob die Nullify-Inverse-Korrektur
  (`4e656eb9`) AUCH fuer kaskadierte Plan-Loeschungen (nicht nur direkte
  Tag-Loeschungen) zuverlaessig greift, wird jetzt direkt durch eine neue
  Assertion in `testOrphanedSessionFromADeletedPlanNeverAffectsAn-
  UnrelatedLivePlan` geprueft (`XCTAssertNil(allSessions.first?.day, ...)`
  nach kaskadierter Plan-Loeschung + echtem Store-Neustart) — im selben
  gebuendelten Apple-CI-Lauf wie alle anderen P9-Aenderungen, bewusst OHNE
  dafuer einen eigenen, isolierten Lauf anzufordern (der urspruengliche
  Relationship-Fix `4e656eb9` hatte ebenfalls keinen eigenen isolierten
  Lauf). Das Lesen von `session.day` selbst ist dabei sicher (siehe
  Abschnitt 2/3) — nur eine gespeicherte Eigenschaft AUF dem Ziel waere
  riskant, nicht das Erhalten der Referenz.
