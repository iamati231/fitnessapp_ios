# P8-Vorbereitung — Stufe-2-Versionierung: Umsetzungsplan

Reine Planung. Kein Code geändert, kein `TestingBot`-Budget verwendet. Branch
`claude/smart-onboarding-epic`, HEAD zum Zeitpunkt dieser Planung `600212d`.
Baut auf dem bereits abgeschlossenen P9-Fund (`session.day?.plan` ist eine
reale, bei jeder echten Session-Erzeugung gesetzte Plan-Referenz — siehe
`docs/NEUE_SPEZIFIKATION_P0_AUDIT.md`, Commit `8076781`) auf, erweitert ihn
aber NICHT: P9 löste die Plan-**Zuordnung** einer Session; dieses Dokument
behandelt die davon unabhängige Frage, ob der **Inhalt** (Übungen/Reihenfolge)
eines Tages zum Zeitpunkt einer Session zuverlässig rekonstruierbar bleibt,
wenn der Tag später bearbeitet wird.

## 0. Quellenlage (Auftragspunkt 1)

**Konkrete Quellenlücke, offen benannt statt verschwiegen:** Die eigentlichen
Originalspezifikationen (`00_START_HIER.md`, `01_PLANUNG_BUILDER_UND_FIXES.md`,
`02_ONBOARDING_HYBRID_LAUFCOACH.md`, `03_TRAININGSBEGLEITUNG_PLAN_CHECKS.md`)
waren laut Kopfzeile von `docs/PLANUNG_BEGLEITUNG_AUDIT.md` ein User-Upload
**außerhalb des Repos** — sie liegen in diesem Arbeitskontext nicht vor und
konnten nicht erneut geprüft werden. Alles Folgende stützt sich stattdessen
auf zwei bereits im Repo vorhandene, aus jenen Dokumenten abgeleitete Audits,
die hier ausdrücklich als **Sekundärquellen/Paraphrasen**, nicht als
vollständige verbindliche Spezifikation, behandelt werden:

- `docs/PLANUNG_BEGLEITUNG_AUDIT.md` — die ursprüngliche Phase-0-Analyse
  (HEAD `5e9e3e7` zum Zeitpunkt ihrer Entstehung). Enthält unter "P5.2
  Inhalts-Snapshot pro `TrainingDay`-Fassung" (Zeile 438-448) bereits den
  Namen `TrainingDayContentRecord` und die Kernanforderung: "nur der
  Tagesinhalt (Übungen/Reihenfolge) wird eingefroren". Abschnitt 6 (Zeile
  174-191) und "Fachlicher Konflikt 3" (Zeile 225-232) dokumentieren den
  zugrundeliegenden Befund bereits korrekt: `WorkoutSession.day` ist "eine
  direkte, lebende Objektreferenz — keine lose Namens-/Datumsbindung".
- `docs/NEUE_SPEZIFIKATION_P0_AUDIT.md` — der laufende Statusbericht dieses
  Epics. Zeile 1346-1347 hält den aktuellen Stand fest: **"P8 — Spätere
  Block-Reviews, Stufe 3 — zurückgestellt bis P7 + vollständige
  Stufe-2-Versionierung stehen."** Zeile 974 und 1554-1555 bestätigen, dass
  weder `TrainingDayContentRecord` noch eine Eignungsprüfung von
  `generationFingerprint`/`currentContentFingerprint` für Stufe 2 je
  umgesetzt wurden ("bewusst nicht vertieft").

Beide Dokumente sind intern konsistent mit dem, was der Code tatsächlich tut
(unten mit Dateizeilen belegt) — sie werden deshalb als tragfähige Grundlage
behandelt, aber nicht als Ersatz für die fehlenden Originaldokumente
ausgegeben. Insbesondere die **5 Fragen für Block-Reviews** und jede
Block-Länge/Plateau-Schwelle stehen nur im (fehlenden) Dokument 03 — dazu
unten mehr unter "Nicht erfunden".

## 1. Ist-Stand, belegt

### 1.1 Was bereits existiert — und wofür es NICHT ausreicht

| Feld/Mechanismus | Datei:Zeile | Zweck | Reicht für Stufe 2? |
|---|---|---|---|
| `TrainingPlan.activatedAt: Date?` | `TrainingPlan.swift:50` | Zeitanker "seit wann aktiv" (P6.1) | Nein — Plan-Ebene, kein Tagesinhalt |
| `TrainingDay.generationFingerprint: String?` + `currentContentFingerprint` (computed) | `TrainingDay.swift:54`, `:109-127` | Dirty-Flag: hat der User seit der letzten Generierung etwas editiert? ("neu rechnen" darf nur unangetastete Tage überschreiben) | Nein — reiner Live-Vergleichswert, speichert selbst keinen Inhalt |
| `TrainingDay.generatorSequenceIndex: Int?` | `TrainingDay.swift:64` | Stabiler Tag-Anker NUR für `recalculate`-Matching, `nil` bei Nicht-Wizard-Tagen | Nein — keine Versionsidentität, nur Positions-Ersatz |
| `DraftDay.isContentFixed`/`.isPositionFixed` | `FitnessAppCore/Planning/PlanDraft.swift:56-69` | Schützt EINEN Entwurf (`PlanDraft`, noch nicht persistiert) vor Überschreiben bei "Woche anders verteilen"/"Vorschlag neu erstellen" | Nein — lebt nur im Builder-Entwurf, nie auf `TrainingDay` persistiert |
| `Exercise.exerciseTemplateID: UUID?` + `ExerciseLog.exerciseTemplateIDSnapshot`/`exerciseNameSnapshot` | `Exercise.swift:28`, `ExerciseLog.swift:40,49` | Stabile Katalog-Referenz + Namens-Snapshot, damit eine Übungs-Umbenennung die Verlaufsanzeige nicht bricht (Settings-Epic P6.1, EXLIB-07/09) | Teilweise wiederverwendbar als MUSTER (ID + Namens-Snapshot), deckt aber nur "welche Übung", nicht "in welcher Reihenfolge/mit welchen Zielwerten" |
| `WorkoutSession.dayName`/`timeFormatSnapshot`/`partialRepsExerciseName` | `WorkoutSession.swift:46,58,69` | Punktuelle Einzelwert-Snapshots (Tagesname, Zeitformat, EIN Übungsname für AMRAP-Teilrunden) | Nein — kein Snapshot der vollständigen, geordneten Übungsliste |

**Kernbefund, der die bisherige Einschätzung bestätigt statt widerlegt:**
`WorkoutSession.day: TrainingDay?` (`WorkoutSession.swift:154-155`) ist — anders
als die im P9-Fix korrigierte Behauptung zur PLAN-Referenz — für den
TAGESINHALT tatsächlich eine lebende, nicht eingefrorene Objektreferenz. Jeder
Code, der `session.day.exercises`/`.activeExercises` liest, bekommt den
**aktuellen**, nicht den historischen Stand. Konkret bestätigt, bereits heute
produktiv so lesend:
- `WorkoutSummaryView.swift:1391` — wird mit `isReadOnly: true` sowohl direkt
  nach Abschluss EINER Session als auch beim erneuten Öffnen einer
  BELIEBIGEN alten Session aus `WorkoutHistoryView.swift:77`,
  `PRHistoryView.swift:449` und `DashboardView.swift:3013,3330` verwendet —
  **das ist der konkrete, bereits heute bestehende Lesepfad, der nach einer
  nachträglichen Tagesbearbeitung die falsche (aktuelle statt historische)
  Übungsliste für eine alte Session anzeigen würde.**
- `CircuitWorkoutPlayerView.swift:86`, `TimedWorkoutPlayerView.swift:1540` —
  lesen ebenfalls `session.day?.activeExercises`; ob diese Player-Views je für
  eine BEREITS ABGESCHLOSSENE Session erneut geöffnet werden (vs. nur für eine
  laufende/wiederaufgenommene), wurde nicht verifiziert — als offener
  Prüfpunkt in Paket D unten vorgesehen, nicht als bestätigter Befund
  behauptet.

**Bereits existierender Schutz, der den Umfang des Problems verkleinert:**
`PlanGeneratorInstantiator.recalculate` überspringt JEDEN Tag, der
irgendeine `WorkoutSession` referenziert, bereits heute vollständig
(`guard ... !daysWithAnySession.contains(day.persistentModelID) ...`,
`PlanGeneratorInstantiator.swift:737-740`) — "neu rechnen" ist für Tage mit
Historie also schon jetzt kein Risiko. Übrig bleiben drei reale
Schreibpfade, die einen Tag MIT bereits vorhandener Session-Historie
trotzdem anfassen können, ohne jede Rücksicht auf diese Historie:
`DayEditorView`-Handbearbeitung (Hinzufügen/Entfernen/Umsortieren),
`PlanEquipmentAdaptationApplier`/`PlanEnvironmentMigrator` (automatischer
Geräte-/Orts-Tausch) und, als Sonderfall innerhalb DERSELBEN Session, die
Ad-hoc-Live-Bearbeitung in `ActiveWorkoutView`.

### 1.2 Was NICHT existiert (reale Lücken, nicht nur unvertieft)

- **Keine stabile `id: UUID` auf `TrainingPlan` oder `TrainingDay`.** Beide
  (`TrainingPlan.swift`, `TrainingDay.swift`, vollständig gelesen) haben kein
  eigenes Identitätsfeld — nur SwiftDatas `persistentModelID`, das beim
  Export/Import NICHT erhalten bleibt (`DataImportService.importPlans`/
  `importPlanDays` fügen beim Import ausnahmslos neue Objekte ein, ohne
  Abgleich gegen Bestehendes — `DataImportService.swift:1014,1259`, bestätigt
  durch den recherchierenden Agenten).
- **Kein `TrainingDayContentRecord` oder vergleichbarer Mechanismus** existiert
  im Code (exhaustiv gegrept, nur in Doku-Referenzen erwähnt).
- **Keine Reihenfolge-/Positions-Snapshot auf `ExerciseLog` oder
  `WorkoutSession`** — nur Einzelwerte (s. Tabelle oben). Die
  Zeitformat-Fortsetzungsfelder (`forTimeCheckedRoundsRaw` u. ä.) referenzieren
  `Exercise.orderIndex` sogar per lebendem Integer, nicht per Snapshot
  (`WorkoutSession.swift:79-86`).

## 2. Vorgeschlagener Datenvertrag

### 2.1 Stabile Identität — bewusst MINIMALER Eingriff, mit begründeter Abgrenzung

Für das in diesem Dokument behandelte Ziel ("eine bereits gestartete/
abgeschlossene Session zeigt dauerhaft ihren tatsächlichen historischen
Inhalt") ist **keine neue, cross-zeitliche Plan-/Tages-ID nötig**. Begründung:
Der Snapshot hängt direkt an der `WorkoutSession` (1:0..1-Beziehung, siehe
2.2) — er muss später nie "über eine Tag-ID gesucht" werden, er liegt bereits
am richtigen Objekt. Das deckt sich mit dem ursprünglich in P5.2 offen
gelassenen Vorschlag "JSON-Snapshot-Feld auf `WorkoutSession`".

**Ausdrücklich offene Frage, NICHT in diesem Schritt entschieden** (gehört zu
Auftragspunkt 2, erster Spiegelpunkt): Falls ein künftiger Block-Review-Screen
(Stufe 3) zusätzlich eine reine **Tages-Historie unabhängig von einzelnen
Sessions** zeigen soll (z. B. "dieser Tag wurde im Beobachtungszeitraum
zweimal inhaltlich geändert, auch an Tagen ohne Session"), würde das eine
echte, cross-zeitliche `TrainingDay`-Identität (neues additives `id: UUID`)
erfordern. Das lässt sich aus den hier verfügbaren Dokumenten NICHT
abschließend klären (Dokument 03 fehlt) — diese Erweiterung wird bewusst NICHT
vorweggenommen, sondern als mögliche Nacharbeit benannt, falls Stufe 3 sie
tatsächlich braucht.

### 2.2 Neues Datenmodell

**Core (`FitnessAppCore`, Linux-testbar — reine Codable-Struct, kein
SwiftData):**

```swift
/// Eingefrorener Tagesinhalt zum Zeitpunkt einer Session. Felder bewusst
/// deckungsgleich mit `TrainingDay.currentContentFingerprint`
/// (TrainingDay.swift:109-127) — dieselbe, bereits gepflegte Definition von
/// "was zählt als Tagesinhalt", nur materialisiert statt gehasht.
public struct TrainingDayContentSnapshot: Codable, Sendable, Equatable {
    public struct ExerciseEntry: Codable, Sendable, Equatable {
        public let orderIndex: Int
        public let exerciseTemplateID: UUID?       // wie Exercise.exerciseTemplateID
        public let nameSnapshot: String             // wie Exercise.name
        public let customNameSnapshot: String?
        public let sets: Int
        public let repsMin: Int
        public let repsMax: Int
        public let restSeconds: Int
        public let targetRir: Float                 // Typ an Exercise.targetRir angleichen
        public let targetDistanceKm: Double?
        public let targetDurationMinutes: Int?
    }
    public let dayDisplayNameSnapshot: String        // customName ?? lokalisierter Name
    public let timeFormatRaw: String?
    public let timeCapMinutes: Int?
    public let circuitRounds: Int?
    public let circuitRestSeconds: Int?
    public let circuitModeRaw: String?
    public let exercises: [ExerciseEntry]
}
```

**Data (`FitnessAppData`, SwiftData, additiv):**

```swift
@Model
public final class TrainingDayContentRecord {
    public var contentJSON: String   // JSON von TrainingDayContentSnapshot
    public var capturedAt: Date      // = session.startTime bei Erst-Anlage
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.contentRecord)
    public var session: WorkoutSession?
    // computed `content: TrainingDayContentSnapshot?` — identisches
    // Raw+Computed-Muster wie TrainingPlan.generatorInput (TrainingPlan.swift:130-142)
}
```

`WorkoutSession` bekommt additiv `contentRecord: TrainingDayContentRecord?`
(inverse oben). `deleteRule: .nullify` auf BEIDEN Seiten, nicht `.cascade` —
der Snapshot gehört fachlich zur Session, aber ein Datenmodell-Fehler soll nie
eine Session mitreißen; verwaiste Records ohne Session sind unschädlich und
könnten optional in einem Wartungslauf bereinigt werden (kein Blocker für
dieses Paket).

**Warum JSON-Payload statt eigenes `[Exercise]`-Submodell:** Der Snapshot ist
nach dem Einfrieren nie wieder editierbar — es gibt keinen Bedarf, einzelne
Zeilen relational zu queryn. Genau dieses Muster (JSON-Rohstring + typisierter
Computed-Zugriff) ist in diesem Codebase bereits etabliert
(`TrainingPlan.generatorInputRaw`/`.generatorInput`,
`UserBodyProfile.equipmentPreferencesRaw`) — kein neues Pattern, keine dritte
Kaskaden-Relationship, die migriert/exportiert werden müsste.

### 2.3 Wann ein neuer Stand entsteht (Auftragspunkt 2, Spiegelpunkt 3)

Lebenszyklus spiegelt bewusst den bereits etablierten Lebenszyklus von
`WorkoutSession` selbst: "Eine Zeile wird bei Workout-**Start** mit
`isCompleted=false` angelegt… Das finale 'Speichern' auf dem
Summary-Screen… setzt `isCompleted=true`" (`WorkoutSession.swift:8-11`,
F63/F72). Der Content-Record folgt demselben Muster:

1. **Bei Session-Erzeugung** (identisch zu den 5 produktiven
   `WorkoutSession(day:)`-Stellen, s. 3.1): Snapshot aus dem AKTUELLEN
   `day`/`day.activeExercises` bauen, `TrainingDayContentRecord` anlegen,
   `session.contentRecord` setzen.
2. **Während die Session offen ist** (`isCompleted == false`): der Record darf
   überschrieben werden — einziger produktiver Grund dafür ist die
   Ad-hoc-Live-Bearbeitung (`ActiveWorkoutView.addAdHocExercise`/
   `deleteAdHocExercise`, `ActiveWorkoutView.swift:1044-1143`): jede dieser
   Mutationen schreibt den Snapshot neu, exakt wie sie heute schon
   `session.exerciseCount` nachführen.
3. **Bei Session-Abschluss** (`isCompleted` wird `true`): letzter Schreibzugriff,
   danach GEFROREN — kein Schreibpfad außerhalb dieses einen Übergangs rührt
   den Record danach noch an. Eine Zeile mit `isCompleted == false` auf immer
   (Crash-Ruine, bereits heute als Recovery-Banner sichtbar) hat damit
   konsequent auch nie einen final eingefrorenen Snapshot — unproblematisch,
   da diese Zeilen ohnehin als unvollständig behandelt werden.

### 2.4 Welcher Stand beim Trainingsstart verbunden wird

Für reguläre Plan-/Ruhetag-Starts: der Stand von `day`/`day.activeExercises`
**zum Zeitpunkt des Starts**, bevor irgendeine Session-spezifische Mutation
passiert — identisch zur Quelle, die `currentContentFingerprint` ohnehin schon
live berechnet. Für Ad-hoc: der zu Beginn leere Stand, der sich über 2.3
Schritt 2 während der Session aufbaut.

### 2.5 Laufende Session + gleichzeitige Planbearbeitung — AUSDRÜCKLICH OFFEN

Es existiert heute kein Mechanismus, der eine Bearbeitung in
`DayEditorView`/`PlanEditorView` blockiert, während anderswo eine
`WorkoutSession` für denselben Tag läuft — die einzige vorhandene
Session-Prüfung (`DayEditorView.swift:42-47`, DEL-042) verhindert nur den
**Start** einer zweiten Session bei bereits offener erster, nicht das
gleichzeitige Editieren. Ob `DayEditorView` navigationstechnisch überhaupt
erreichbar ist, während `ActiveWorkoutView` für denselben Tag präsentiert
wird, wurde in dieser Untersuchung NICHT geprüft. **Das bleibt eine
ausdrücklich offene Produktentscheidung**, keine stillschweigende Annahme:
Soll ein Edit während offener Session (a) sofort blockiert werden, (b) den
bereits gezogenen Snapshot der offenen Session unberührt lassen (Default
dieses Vorschlags, da Punkt 2.3 den Record nur bei Erzeugung/Ad-hoc-Edit/
Abschluss schreibt — ein fremder `DayEditorView`-Edit löst keinen dieser drei
Trigger aus und bliebe damit von selbst folgenlos für die offene Session),
oder (c) etwas anderes tun? Vorschlag (b) ergibt sich bereits als Nebenprodukt
des oben beschriebenen Schreibvertrags, ohne dass eine explizite Sperre nötig
wäre — wird hier aber bewusst als Entscheidung benannt, nicht als Zufall
verschwiegen.

### 2.6 Löschen, Regenerieren, Equipment-Anpassung, Import

- **Tag löschen** (`PlanEditorView.deleteDays`, `:934-939`): `WorkoutSession.day`
  wird genullt (`deleteRule: .nullify`, bereits bestätigt), der
  `TrainingDayContentRecord` bleibt an der Session hängen, völlig unberührt —
  genau das ist der Zweck des Snapshots. Keine Änderung an diesem Verhalten
  nötig.
- **`recalculate`/"neu rechnen"**: bereits heute kein Risiko für Tage mit
  Historie (s. 1.1); für Tage OHNE Historie entsteht ohnehin noch keine
  Session, also auch kein Snapshot-Konflikt.
- **"Woche anders verteilen"/"Vorschlag neu erstellen"**: reine
  `PlanDraft`-Operationen ohne `ModelContext`-Zugriff (bestätigt,
  `PlanDraft.swift:120-125,274-283`) — berühren nie einen bereits
  persistierten Tag oder dessen Sessions. Eine `adoptPlan()` danach erzeugt
  einen VÖLLIG NEUEN `TrainingPlan` (s. 1a-Recherche) — Snapshots alter
  Sessions am alten Plan bleiben unangetastet.
- **Equipment-/Umgebungsanpassung** (`PlanEquipmentAdaptationApplier.apply`,
  `PlanEnvironmentMigrator.migrate`): beide mutieren den LIVE-Tag auch dann,
  wenn er bereits Session-Historie hat (kein äquivalentes
  `daysWithAnySession`-Gate wie bei `recalculate` gefunden) — **das ist der
  zweite reale Risikopfad** neben `DayEditorView`. Für bereits abgeschlossene
  Sessions ändert das nichts (ihr Record ist längst gefroren); für eine
  AKTUELL OFFENE Session an genau diesem Tag greift dieselbe offene Frage wie
  2.5.
- **Import**: ein Altbackup ohne die neue CSV-Spalte/Datei liefert für jede
  importierte Session `contentRecord == nil` — **"kein Snapshot verfügbar"**,
  niemals rückwirkend rekonstruiert oder erfunden (exakt die in P5.2 bereits
  festgelegte Regel). Ein NEUES Backup mit Snapshot-Daten reimportiert sie
  nach demselben bereits etablierten `idMap`-Muster, das `workouts.csv` schon
  für die `WorkoutSession`-Zuordnung nutzt (`DataImportService.swift:1344`;
  Import-Reihenfolge Pläne → Tage → Workouts → Übungen bleibt maßgeblich, der
  neue Import-Schritt für Snapshots müsste NACH `importWorkouts` laufen, da er
  `idMap[session-export-id]` braucht).

### 2.7 Historische Inhalte vs. bewusst weiterhin live ausgewertete Metadaten

Unverändert, nicht Teil dieses Snapshots (Konfliktlösung 3 aus
`PLANUNG_BEGLEITUNG_AUDIT.md`, Zeile 225-232, bleibt gültig): einzelne
Korrekturfaktoren wie `Exercise.cnsDemandFactor` (gelesen von
`ExerciseLog.cnsFatigueScore`) und `resolvedCardioEquipment` bleiben bewusst
LIVE — das ist eine Datenkorrektur, keine Planinhalts-Änderung. Ebenso
unverändert: die P9-Fix-Logik (`session.day?.plan`-basierte
Teilnahme-Zuordnung) und die bestehende Ad-hoc-Teilnahme-Anrechnung
("Ad-hoc-Sessions zählen bewusst MIT", `FourWeekReviewAssembler.swift:138`) —
dieser Plan fügt ausschließlich einen zusätzlichen, rein additiven
Inhalts-Snapshot hinzu und ändert an KEINER bestehenden
Teilnahme-/Zuordnungsregel etwas.

## 3. Betroffene Schreib-/Lesepfade (vollständig, mit Zitaten)

**Schreiben (neu, additiv):**
1. `DayEditorView.actuallyStartNewSession()` — `DayEditorView.swift:1150`
2. `DayEditorView.markRestDaySkipped()` — `DayEditorView.swift:1242`
3. `DashboardView.actuallyStartNewWorkout(plan:day:)` — `DashboardView.swift:2237`
4. `DashboardView.startAdHocWorkout()` — `DashboardView.swift:2282`
5. `DashboardView.markRestDaySkipped(plan:day:)` — `DashboardView.swift:2347`
6. `ExternalWorkoutImportService` (HealthKit-Import) — `ExternalWorkoutImportService.swift:150`:
   `day == nil`, Snapshot bleibt `nil` (kein Plan-Tag vorhanden — korrekt, kein
   Datenverlust, da es nie einen gab).
7. `ActiveWorkoutView.addAdHocExercise(from:)`/`.addAdHocCustomExercise(_:)`/
   `.deleteAdHocExercise(_:)` — `ActiveWorkoutView.swift:1044-1143` (Resync
   während offener Ad-hoc-Session).
8. Übergang `isCompleted → true` auf dem Summary-/Speichern-Pfad (dort, wo
   heute bereits `session.isCompleted = true` gesetzt wird) — Record einfrieren.

**Lesen (zu ändern, sobald der Record existiert — in diesem Planungsschritt
NICHT umgesetzt, nur identifiziert):**
- `WorkoutSummaryView.swift:1391` — bestätigter Lesepfad für ALTE Sessions
  (s. 1.1), müsste künftig `session.contentRecord?.content` bevorzugen und nur
  bei `nil` (Altbestand ohne Snapshot) ausdrücklich als Datenlücke auf
  `session.day?.activeExercises` zurückfallen — NIE stillschweigend, mit
  sichtbarem Hinweis "kein historischer Stand verfügbar".
- `CircuitWorkoutPlayerView.swift:86`, `TimedWorkoutPlayerView.swift:1540` —
  zu prüfen, ob sie je für abgeschlossene Sessions erneut geöffnet werden
  (offen, s. 1.1); falls ja, analog umzustellen.

**Export/Import:**
- Neue additive CSV (z. B. `workout_content_snapshots.csv`, FK `session_id`
  über das etablierte `idMap`-Export-Muster) ODER ein zusätzliches Feld direkt
  in `workouts.csv` (`content_snapshot_json`) — Entscheidung in Paket C, siehe
  unten; beide Varianten sind additiv und brechen kein bestehendes Format.

## 4. Migration

Lightweight-additiv, identisches Prinzip wie jedes bisherige neue Feld in
diesem Epic (`activatedAt`, `reviewCompletedAt` u. a.): neue Relationship
`WorkoutSession.contentRecord: TrainingDayContentRecord?`, Default `nil` für
JEDE Bestandszeile — kein Backfill, keine rückwirkende Rekonstruktion. Jeder
Lesepfad muss `nil` als eigenen, offen benannten Zustand behandeln ("kein
historischer Stand verfügbar"), nie als `0`/leere Liste interpretieren.

## 5. Implementierungspakete (klein, mit Tests und Abhängigkeiten)

**Paket A — Core-Struct + Encode/Decode (Linux-testbar, keine Abhängigkeit):**
`TrainingDayContentSnapshot` (+ `ExerciseEntry`) in `FitnessAppCore`. Tests:
JSON-Roundtrip, Gleichheit zweier Snapshots, Verhalten bei fehlenden
optionalen Feldern. Kein SwiftData-Bezug.

**Paket B — SwiftData-Modell (Apple-CI/Gerät, abhängig von A):**
`TrainingDayContentRecord` + `WorkoutSession.contentRecord`-Relationship,
Raw+Computed-Zugriff (wie `generatorInput`). Migrationstest: Bestandsdatenbank
ohne das Feld öffnen → `contentRecord == nil` für jede Zeile.

**Paket C — Verdrahtung an den 8 Schreibpfaden (Apple-CI/Gerät, abhängig von
B):** die 5 Session-Erzeugungsstellen + Ad-hoc-Resync + Freeze-bei-Abschluss.
Tests: die Abnahmefälle aus Abschnitt 6 unten, je als eigener
SwiftData-Regressionstest (Muster: `FourWeekReviewAssemblerTests.swift`).

**Paket D — Export/Import (Apple-CI/Gerät, abhängig von B, parallel zu C
möglich):** additive CSV-Spalte/-Datei, Import-Schritt nach `importWorkouts`.
Tests: Roundtrip mit Snapshot, Roundtrip OHNE Snapshot (Altbackup bleibt
importierbar, `contentRecord` bleibt `nil`, niemals nachträglich als
vollständig versioniert ausgegeben).

**Paket E — Lesepfad-Umstellung `WorkoutSummaryView` (Apple-CI/Gerät,
abhängig von B+C, NACH diesem Planungsschritt, nicht Teil der aktuellen
Freigabe):** `session.contentRecord?.content` bevorzugen, `nil`-Fall sichtbar
als Datenlücke kennzeichnen (nicht stillschweigend auf den Live-Stand
zurückfallen). Erst anfassen, wenn A-D abgenommen sind.

Reihenfolge: A → B → (C, D parallel) → E. Keines dieser Pakete baut den
Block-Review-Screen (Stufe 3/P8) selbst — das bleibt, wie vom Auftrag
verlangt, zurückgestellt.

## 6. Abnahmefälle (vor Implementierung festgelegt)

1. Session aus Plan A bleibt A zugeordnet, auch bei Namensänderung — bereits
   durch P9 (`session.day?.plan`) abgedeckt, hier nur bestätigt, nicht erneut
   gebaut.
2. Eine spätere Änderung von Übungen/Reihenfolge verändert den
   `TrainingDayContentRecord` einer bereits gestarteten/abgeschlossenen
   Session nicht — Regressionstest: Session anlegen, Snapshot lesen, Tag via
   `DayEditorView`-Äquivalent editieren, Snapshot erneut lesen → unverändert.
3. Plan B kann As Historie nicht beeinflussen — folgt direkt aus 1:0..1
   Session→Record, keine zusätzliche Prüfung über Pläne hinweg nötig.
4. Löschen/Regenerieren eines Tages zerstört die künftig gespeicherte
   historische Zuordnung nicht — Regressionstest: Tag löschen, Session +
   Record bleiben lesbar (`day == nil`, `contentRecord` unverändert vorhanden).
5. Vorschau und Verwerfen im Builder erzeugen keine übernommenen
   Planversionen — folgt aus 2.6 (`PlanDraft` hat keinen `ModelContext`-Zugriff),
   Regressionstest optional als Bestätigung, kein neuer Code nötig.
6. Export/Import erhält neue Identitäten (session-gebundene FK) und
   historische Inhalte — Paket D.
7. Altbackup ohne Versionsdaten bleibt importierbar, wird nicht nachträglich
   als vollständig versioniert ausgegeben — Paket D, Negativtest.
8. Fehlende Historie führt zu einer benannten Datenlücke, nicht zu einem
   erfundenen Progressions-/Plateau-Befund — Paket E (erst nach Freigabe von
   A-D), UI zeigt "kein historischer Stand verfügbar" statt einer Zahl.

## 7. Ausdrücklich offene Produktentscheidungen (nicht erraten, nicht entschieden)

- **2.5**: Verhalten bei gleichzeitiger Planbearbeitung während offener
  Session — Default (b) vorgeschlagen, nicht final entschieden.
- **2.1**: Ob Stufe 3 zusätzlich eine session-unabhängige Tages-Versionshistorie
  braucht (eigene `TrainingPlan`/`TrainingDay`-UUID) — hängt vom fehlenden
  Dokument 03 ab.
- **Export-Form** (Paket D): eigene CSV-Datei vs. zusätzliche Spalte in
  `workouts.csv` — technische, keine Produktfrage, aber bewusst offen gelassen
  bis Paket B steht.
- **CircuitWorkoutPlayerView/TimedWorkoutPlayerView**: ob sie je historische
  (abgeschlossene) Sessions erneut öffnen — zu verifizieren vor Paket E.

## 8. Nicht erfunden (Auftragspunkt 5, Leitplanken)

Keine Blocklänge, keine Wiederholungsfrist, keine Plateau-Schwelle in diesem
Dokument festgelegt — all das bleibt Stufe 3 (P8 selbst) und damit
außerhalb dieses Plans. Die 28-Tage-Regel aus P7
(`FourWeekReviewDueCalculator.dueIntervalDays`) gilt ausdrücklich NUR für den
ersten Rückblick (`NEUE_SPEZIFIKATION_P0_AUDIT.md:1230`) und wird hier NICHT
auf P8/Stufe 2 übertragen. Die bestehenden offenen Punkte — Due-Badge-
Geräteverifikation (P9 Priorität 2) und die dokumentierten
Accessibility-/Dynamic-Type-Nachprüfungen — bleiben unverändert eigenständig
offen; dieser Plan setzt sie weder als P8-Voraussetzung noch gibt er sie als
erledigt aus.
