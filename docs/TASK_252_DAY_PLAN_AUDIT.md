# Task #252: Audit der sieben weiteren `.day?.plan`-Lesestellen

**Status:** alle acht Stellen (die bereits in Build 164 behobene plus die
sieben in `docs/TESTFLIGHT_CRASH_164.md` Abschnitt 6 gelisteten) einzeln
geprüft. Vier zusätzliche Stellen waren strukturell derselben Risikoklasse
zuzuordnen und wurden auf dasselbe Vorwärts-Traversal-Muster umgestellt;
drei Stellen sind durch eine durchgängige Cascade-Delete-Kette sicher und
blieben unverändert. Keine Stelle bleibt ungeklärt.

## Methodik (wie beauftragt)

Für jede Stelle wurde geprüft:
1. Woher stammt das Session-/TrainingDay-Objekt?
2. Kann die Referenz nach Löschen/Ersetzen/Restore verwaist sein?
3. Welche Beziehung wird tatsächlich dereferenziert?
4. Ist derselbe Fehlerpfad (wie Build 164) reproduzierbar?

Optional Chaining (`?.`) wurde dabei NICHT als Schutz behandelt — es
verhindert nur einen `nil`-Crash, nicht das `_InvalidFutureBackingData`-
`_assertionFailure`, das beim Lesen einer gespeicherten Eigenschaft auf
einem Objekt mit verwaister Backing-Row auftritt (siehe
`docs/TESTFLIGHT_CRASH_164.md` Abschnitt 2+3).

Der bereits in Build 164 bewiesene Fix-Ansatz (Vorwärts-Traversal von
einer garantiert lebenden Wurzel: `plan.days` → `day.sessions`, statt
rückwärts `session.day?.plan` oder `exercise.day?.plan`) wurde NUR dort
wiederverwendet, wo seine Voraussetzung (ein lebendes `TrainingPlan`-/
`TrainingDay`-Objekt als Startpunkt) tatsächlich vorlag — nicht pauschal
auf alle acht Stellen angewendet.

## Ergebnis je Stelle

### 1. `DashboardView.nextScheduledDay(in:)` — **betroffen und behoben**
Bereits vor dieser Aufgabe in Commit `de24e28` behoben (der ursprüngliche
Build-164-Fund). Herkunft: app-weite `completedSessions`-`@Query`.
Verwaisungsrisiko: bestätigt (siehe Crash-Report). Fix: `plan.days` →
`day.sessions` vorwärts. Siehe `docs/TESTFLIGHT_CRASH_164.md`.

### 2. `FourWeekReviewAssembler.realOccurrences` — **betroffen und behoben**
- **Herkunft:** app-weite `FetchDescriptor<WorkoutSession>`-Query (alle
  Nicht-Ruhetag-Sessions), identisch ungefiltert wie Fund 1.
- **Verwaisungsrisiko:** bestätigt — exakt dieselbe Risikoklasse.
- **Beziehung:** `session.day?.plan` (zweistufig rückwärts).
- **Fix:** Umgestellt auf drei vorwärts aus frisch gefetchten
  `TrainingPlan`/`TrainingDay`-Listen gebildete Session-ID-Mengen
  (`ownSessionIDs`, `otherPlanSessionIDs`, `anyDayOwnedSessionIDs`) —
  `session.day` wird dabei NIE mehr gelesen, nur noch `session.persistent-
  ModelID` (eine eigene, immer sichere Eigenschaft). Eine verwaiste
  Referenz landet automatisch im bereits bestehenden "nicht zuordenbar"-
  Fall (`.unattributableHistoryExcludedDueToMultipleActivePlans` bei
  mehreren aktiven Plänen, sonst wie echtes Ad-hoc-Training behandelt —
  unverändert ggü. der bisherigen Produktentscheidung für `day == nil`).
- **Regressionstests:** `testOrphanedSessionFromADeletedPlanCountsToward-
  TheSoleSurvivingActivePlanAfterARealStoreRestart` und
  `...IsExcludedAndDisclosedWithMultiplePlansActiveAfterARealStoreRestart`
  (`FourWeekReviewAssemblerTests.swift`) — datei-basierter Store, echte
  Plan-/Tag-Löschung, Container-Neuöffnung, je einmal mit einem und mit
  zwei aktiven Plänen.

### 3–5. `DashboardView` — drei offene-Session-Stellen — **betroffen und behoben**
(`resumeAnyOpenFromConflict`, `unrepresentedOpenSession`, `resumeOpenSession`)
- **Herkunft:** `openSessions`, eine app-weite `@Query` über ALLE nicht
  abgeschlossenen Sessions — strukturell derselbe ungefilterte Zugriff wie
  Fund 1, nur (laut bestehender DEL-215-Doku) mit kürzerer Lebensdauer.
  Das senkt das Risiko, schließt es aber nicht aus: eine liegengelassene
  offene Session (App im Hintergrund beendet, nie fortgesetzt) kann
  beliebig lange bestehen bleiben.
- **Verwaisungsrisiko:** nicht ausgeschlossen — dieselbe Risikoklasse wie
  Fund 1, da die Session rein zeitlich beliebig alt werden kann.
- **Beziehung:** `open.day?.plan` bzw. `session.day?.plan`.
- **Fix:** gemeinsamer, bewusst Environment-/Query-freier statischer
  Helfer `DashboardView.owningPlan(forSessionID:in:)` — sucht vorwärts
  über eine übergebene Plan-Liste (`plan.days` → `day.sessions`), genau
  wie `nextScheduledDay`. Alle drei Call-Sites nutzen ihn jetzt statt
  `.day?.plan` zu lesen.
- **Regressionstest:** `testOwningPlanNeverTouchesAnOrphanedSessionsDay-
  AfterARealStoreRestart` (`DashboardNextScheduledDayTests.swift`) —
  datei-basierter Store, echte Plan-/Tag-Löschung, Container-Neuöffnung,
  prüft den gemeinsamen Helfer direkt mit einer echten verwaisten UND
  einer echten lebenden offenen Session nebeneinander.
  **Einschränkung (ehrlich offen):** die drei `private`/`@Environment`-
  gebundenen View-Funktionen selbst sind — wie bereits bei
  `DayEditorPersistenceTests` dokumentiert — ohne echten View-/UI-Test-
  Harness nicht direkt aufrufbar (ein bar konstruiertes `DashboardView()`
  füllt `@Query`/`@Environment`-Properties nicht). Der Test beweist daher
  die zugrundeliegende, jetzt gemeinsam genutzte Fix-Technik, nicht die
  drei Funktionen selbst. Die tatsächliche Verdrahtung ist per sorgfältiger
  manueller Durchsicht verifiziert.

### 6. `WorkoutSummaryView` (ExerciseLibraryPickerSheet) — **betroffen und behoben**
- **Herkunft:** `session`, `@Bindable` von außen übergeben. Call-Sites:
  frisch beendete Session (sicher) UND `WorkoutHistoryView`/`PRHistoryView`
  (beliebige, ggf. Jahre alte Historien-Session — `isReadOnly: true`).
- **Verwaisungsrisiko:** bestätigt — der Add-Exercise-Picker ist über
  `isReadOnly && isEditingHistory` explizit auch im History-Edit-Modus
  erreichbar (Zeile ~1363 vor dieser Änderung), also genau für die
  potenziell alten, riskanten Sessions.
- **Beziehung:** `session.day?.plan?.targetEnvironment`.
- **Fix:** neuer privater Helfer `owningPlanTargetEnvironment(for:)`,
  nutzt denselben `DashboardView.owningPlan(forSessionID:in:)`.
- **Tests:** kein `WorkoutSummaryViewTests`-File im Repo vorhanden (nur
  manuell durchgesehen) — die zugrundeliegende Technik ist aber über denselben
  Helfer durch den Dashboard-Test oben abgedeckt.

### 7. `ExerciseEditorView.isReadOnly` — **geprüft und unter benannten Voraussetzungen sicher**
- **Herkunft:** `exercise`, `@Bindable` direkt von `DayEditorView`/
  `ActiveWorkoutView` übergeben (der gerade angetippte/bearbeitete
  Eintrag einer aktuell offenen Session bzw. eines aktuell offenen Tages).
- **Verwaisungsrisiko:** strukturell ausgeschlossen, SOLANGE die folgende
  Voraussetzung gilt: `TrainingDay.exercises` ist `deleteRule: .cascade`
  (nicht `.nullify`, siehe `TrainingDay.swift:66`) — eine `Exercise` kann
  deshalb NIE länger existieren als ihr `TrainingDay` (beide werden in
  derselben Löschoperation entfernt). Ebenso ist `TrainingPlan.days`
  `.cascade` (`TrainingPlan.swift:137`) — ein `TrainingDay` kann nie länger
  existieren als sein `TrainingPlan`. Die gesamte Kette `exercise → day →
  plan` ist damit durchgängig Cascade-geschützt, anders als die
  `WorkoutSession → day`-Kette (dort `.nullify`, das erlaubt genau das
  Auseinanderlaufen, das Build 164 verursacht hat). Für `TrainingDay.
  exercises` existiert — anders als für `WorkoutSession.day` (siehe
  `TrainingDay.swift`-Kommentar zum "P8-Fund") — kein Hinweis auf eine
  vergleichbare historische Nullify-Inverse-Lücke.
- **Beziehung:** `exercise.day?.plan?.isTemplate`.
- **Entscheidung:** NICHT verändert — eine Änderung böte unter der
  bestätigten Voraussetzung keinen Mehrwert und würde nur unnötig Code
  bewegen (Auftrag: "optional chaining alone must never be treated as
  protection" bezieht sich auf das BLINDE Vertrauen in `?.` ohne Prüfung
  der Beziehungsregeln — hier wurde die Regel explizit geprüft, nicht
  angenommen).

### 8. `ProgressionApplicator.apply`/`evaluateOnly` (2 Stellen) — **geprüft und unter benannten Voraussetzungen sicher**
- **Herkunft:** `exercise` stammt aus `day.activeExercises`, wobei `day =
  session.day` — `session` ist in BEIDEN Call-Sites (`ActiveWorkoutView.
  swift:1046` beim Beenden einer GERADE aktiven Session,
  `WorkoutSummaryView.swift:888` nur im `!isReadOnly`-Zweig, also nur für
  eine frisch beendete, nie für eine Historien-Session) immer eine frische,
  gerade aktive oder gerade abgeschlossene Session — nie aus einer
  app-weiten Historien-Query.
- **Verwaisungsrisiko:** doppelt abgesichert — (a) dieselbe Cascade-Kette
  wie Fund 7, UND (b) die Session selbst ist nie alt genug, um eine
  Alt-Datenbank-Verwaisung (vor dem Nullify-Inverse-Fix `4e656eb9`)
  getragen zu haben.
- **Beziehung:** `exercise.day?.plan?.progressionTargetRIROverride`.
- **Entscheidung:** NICHT verändert, aus denselben Gründen wie Fund 7.

## Bestandsdaten

Wie beauftragt: kein Store-Reset, keine automatische Löschung betroffener
Sessions, keine Entfernung historischer Logs. Alle vier Fixes (2–6) ändern
ausschließlich LESE-Pfade — eine zuvor verwaiste Session/Tag-Referenz wird
nach dem Fix genauso wenig geschrieben/gelöscht wie vorher, sie wird nur
nicht mehr fatal gelesen.

## Linux-Verifikationsgrenzen (ehrlich offen)

Entgegen der bisherigen Annahme in `docs/TESTFLIGHT_CRASH_164.md` ("nur
auf Apple-CI ausführbar, auf Linux ist `canImport(SwiftUI/SwiftData)`
false") wurde in dieser Session empirisch nachgewiesen (absichtlich
syntaktisch ungültiger Code innerhalb der `#if canImport(...)`-Blöcke löst
echte Compile-Fehler aus), dass BEIDE Bedingungen auf diesem Linux-
Toolchain (Swift 6.0.3) tatsächlich `true` sind — `DashboardView.swift`,
`WorkoutSummaryView.swift` und `FourWeekReviewAssembler.swift` wurden also
ECHT, vollständig semantisch von `swift build` geprüft, nicht nur als
leere `#if false`-Blöcke übersetzt. Trotzdem bleibt die TEST-AUSFÜHRUNG
(`swift test`) für `@MainActor @available(iOS 17.0, macOS 14.0, *)`
XCTestCase-Klassen auf Linux bei 0 entdeckten/ausgeführten Tests (sowohl
für neue als auch für alle bereits bestehenden gleich annotierten Tests)
— die Ursache dafür wurde nicht abschließend geklärt (vermutlich eine
Linux-spezifische Einschränkung der Testfall-Discovery für so annotierte
Klassen) und ist nicht Gegenstand dieser Aufgabe. Praktische Konsequenz:
der Quellcode ist auf Linux kompilier-geprüft, die neuen/angepassten
Tests sind es nicht — echte Testausführung bleibt wie bisher Apple-CI
vorbehalten.
