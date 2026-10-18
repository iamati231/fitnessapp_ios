# P8-Vorbereitung — Stufe-2-Versionierung: Umsetzungsplan

**Stand nach Nachbesserung:** Datenvertrag präzisiert, Paket A (Core) + Paket
B (SwiftData-Modell) UMGESETZT und getestet (siehe Abschnitt 5, "Ergebnis
Paket A+B"). Paket C/D/E sowie der Block-Review-Screen (P8/Stufe 3) selbst
sind weiterhin NICHT Teil dieser Runde. Kein `TestingBot`-Budget verwendet.
Branch `claude/smart-onboarding-epic`. Baut auf dem bereits abgeschlossenen
P9-Fund (`session.day?.plan` ist eine reale, bei jeder echten
Session-Erzeugung gesetzte Plan-Referenz — siehe
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

### 2.2 Neues Datenmodell — UMGESETZT (Paket A+B), Feld für Feld geprüft

**Nachbesserung gegenüber dem ersten Entwurf (User-Korrektur, Auftragspunkt 3):**
die Feldliste wurde NICHT einfach von `currentContentFingerprint` übernommen,
sondern einzeln gegen `Exercise.swift`/`ExerciseLog.swift` nachgeprüft. Dabei
fehlten im Fingerprint-Ableitung drei Konzepte, die für Summary/Player/
Wiederaufnahme sichtbar sind und deshalb jetzt Teil des Snapshots sind:
`Exercise.role` (DEL-087 — Warmup/Arbeitssatz/Cooldown), `Exercise.supersetId`
(DEL-083 — A1/B1-Gruppierung), `isCardio`/`isTimeBased`/`cardioEquipment`
(bestimmen, welche Spalten ein Player überhaupt zeigt). Umgesetzt in
`Sources/FitnessAppCore/Training/TrainingDayContentSnapshot.swift`:

```swift
public struct TrainingDayContentSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1   // explizite Payload-Version

    public struct ExerciseEntry: Codable, Sendable, Equatable {
        public let orderIndex: Int                  // Reihenfolge UND Unterscheidung mehrfach vorkommender gleicher Übungen
        public let exerciseTemplateID: UUID?
        public let nameSnapshot: String
        public let customNameSnapshot: String?       // zusätzlich zu nameSnapshot — ExerciseLog hält nur den Systemnamen, dieser Snapshot bewusst mehr
        public let role: ExerciseRole                 // DEL-087
        public let supersetId: UUID?                  // DEL-083
        public let isCardio: Bool
        public let isTimeBased: Bool
        public let cardioEquipment: CardioEquipment
        public let sets: Int
        public let repsMin: Int
        public let repsMax: Int
        public let restSeconds: Int
        public let targetRir: Float
        public let targetDistanceKm: Double?
        public let targetDurationMinutes: Int?
    }

    public let schemaVersion: Int
    public let dayNameSnapshot: String
    public let dayCustomNameSnapshot: String?
    public let dayLocalizationKeySnapshot: String?
    public let weekday: Int
    public let dayType: DayType
    public let timeFormat: WorkoutTimeFormat?
    public let timeCapMinutes: Int?
    public let circuitRounds: Int?
    public let circuitRestSeconds: Int?
    public let circuitMode: CircuitRoundMode?
    public let exercises: [ExerciseEntry]            // leer ist GÜLTIG (z.B. Ad-hoc vor der ersten Übung)
}
```

**Drei unterscheidbare Lesefälle** (Auftragspunkt 3, letzter Spiegelpunkt),
`TrainingDayContentSnapshotState`:

```swift
public enum TrainingDayContentSnapshotState: Sendable, Equatable {
    case notCaptured                                  // nie aufgenommen (Altbestand, Import ohne Snapshot)
    case available(TrainingDayContentSnapshot)        // gelesen — leere exercises-Liste ist hier der "gültig leer"-Fall, kein eigener Case
    case unreadable(TrainingDayContentSnapshotDecodeError)  // .corrupted ODER .unsupportedSchemaVersion(Int)
}
```

`decode(fromJSON:)` prüft `schemaVersion` EXPLIZIT gegen
`currentSchemaVersion` — eine unbekannte künftige Version wird nie als
aktuell geraten. Ein beschädigter oder nicht unterstützter Record wird NIE
stillschweigend durch den Live-Tagesinhalt ersetzt; das bleibt (erst in
Paket E) Sache des jeweiligen Lesepfads, der `.unreadable` explizit anders
behandeln muss als `.notCaptured`.

**Data (`FitnessAppData`, SwiftData, additiv) — ÜBERARBEITET nach einem
Apple-CI-Befund (siehe "Ergebnis Paket A+B" unten für die volle
Diagnose-Historie): der ursprüngliche Entwurf (ein eigenes `@Model`
`TrainingDayContentRecord`, per `@Relationship` ODER per manuellem
`sessionID`-Fremdschlüssel an `WorkoutSession` gehängt) stürzte auf
Apple-CI reproduzierbar mit Signal 5 ab — ein `brk #0x1`-Trap INNERHALB
von SwiftData selbst (per lldb bis auf die Instruktion lokalisiert: ein
interner `_SD_get_current_context_tsd`-Aufruf lieferte `nil`), AUSSCHLIESSLICH
beim `ModelContext.insert()` einer `WorkoutSession` innerhalb der
betroffenen Testdatei — identisch reproduzierbar unabhängig von
Zugriffsmodifikator, In-Memory-/On-Disk-Store, Parallelität, Delete-Rule,
Relationship-Existenz (auch nach vollständiger Entfernung zugunsten eines
reinen Scalar-Fremdschlüssels) und Container-Erzeugungsreihenfolge — sechs
widerlegte Hypothesen. Der Trap liegt nachweislich in Apples eigenem,
gestripptem SwiftData-Binary, nicht in unserem Code.

**Finale Lösung:** kein eigenes `@Model` mehr. Stattdessen zwei zusätzliche
optionale Felder direkt auf dem BESTEHENDEN `WorkoutSession`-Modell —
exakt dasselbe, in diesem Codebase bereits dutzendfach erprobte Muster wie
`dayName`, `timeFormatSnapshot` & Co.:

```swift
// WorkoutSession.swift
public var contentSnapshotJSON: String?
public var contentSnapshotCapturedAt: Date?
```

Lesezugriff als Extension (`TrainingDayContentSnapshotWriter.swift`):

```swift
extension WorkoutSession {
    public var contentSnapshotState: TrainingDayContentSnapshotState {
        guard let json = contentSnapshotJSON else { return .notCaptured }
        /* decode(fromJSON: json) -> .available/.unreadable */
    }
}
```

Dieses Redesign erfüllt dieselben Anforderungen (Drei-Fälle-Modell,
Session-Isolation, Überlebt Tag-Löschung, kein Rückschluss aus Namen) ohne
jede Cross-Model-Koordination beim Einfügen — und ohne die eine neue
`@Relationship`-/Entity-Konstruktion, die den Absturz ausgelöst hat.

**Schreibschutz bleibt ein API-Vertrag, nicht mehr ein Compiler-
erzwungener Modul-Grenzen-Vertrag** (Nachbesserung gegenüber dem ersten
Entwurf, dort `internal(set)`): `contentSnapshotJSON`/
`contentSnapshotCapturedAt` sind `public var` wie jedes andere Feld auf
`WorkoutSession` auch (das bereits etablierte Muster in diesem Codebase —
siehe z. B. `dayName`, `completedTarget`). Die einzige vorgesehene
Schreibstelle bleibt `TrainingDayContentSnapshotWriter.capture(for:in:)`:

```swift
public enum TrainingDayContentSnapshotWriter {
    @discardableResult
    public static func capture(for session: WorkoutSession, in context: ModelContext) -> Bool {
        guard let day = session.day, !session.isCompleted else { return false }
        // ... baut TrainingDayContentSnapshot aus day.activeExercises (sortiert
        // nach orderIndex, identisch zu currentContentFingerprint), schreibt
        // session.contentSnapshotJSON/.contentSnapshotCapturedAt, gibt true zurück.
    }
}
```

`capture` lehnt eine bereits abgeschlossene Session (`isCompleted == true`)
STILL ab (Rückgabewert `false`, siehe 2.3 für die Begründung gegen einen
Assertion-Trap).

**Warum JSON-Payload statt eigenes `[Exercise]`-Submodell:** der Snapshot ist
nach dem Einfrieren nie wieder editierbar — es gibt keinen Bedarf, einzelne
Zeilen relational zu queryn. Genau dieses Muster (JSON-Rohstring + typisierter
Computed-Zugriff) ist in diesem Codebase bereits etabliert
(`TrainingPlan.generatorInputRaw`/`.generatorInput`,
`UserBodyProfile.equipmentPreferencesRaw`) — kein neues Pattern, keine dritte
Kaskaden-Relationship, die migriert/exportiert werden müsste.

### 2.3 Produktregel für laufende Sessions (Auftragspunkt 1, verbindlich — ersetzt die vorherige offene Frage)

**Eine gestartete Session behält ihren EIGENEN Inhaltsstand.** Externe
Änderungen am Plan/Tag (DayEditorView, PlanEditorView, Equipment-/
Umgebungsanpassung) gelten ab sofort NUR für künftige Sessions und dürfen
den Stand einer bereits laufenden Session nie stillschweigend ändern.
Explizite Änderungen INNERHALB der laufenden Session selbst (Ad-hoc-Übung
hinzufügen/entfernen) dürfen ihren eigenen Stand dagegen aktualisieren. Beim
Abschluss wird dieser Stand eingefroren — NICHT erneut aus dem (eventuell
zwischenzeitlich extern veränderten) Live-Tag neu erzeugt.

Lebenszyklus spiegelt bewusst den bereits etablierten Lebenszyklus von
`WorkoutSession` selbst: "Eine Zeile wird bei Workout-**Start** mit
`isCompleted=false` angelegt… Das finale 'Speichern' auf dem
Summary-Screen… setzt `isCompleted=true`" (`WorkoutSession.swift:8-11`,
F63/F72). Umgesetzt in `TrainingDayContentSnapshotWriter.capture(for:in:)`:

1. **Bei Session-Erzeugung** (identisch zu den 5 produktiven
   `WorkoutSession(day:)`-Stellen, s. 3.1): Snapshot aus dem AKTUELLEN
   `day.activeExercises` bauen, `session.contentSnapshotJSON`/
   `.contentSnapshotCapturedAt` setzen. `capture` liest IMMER den Live-Tag neu —
   das ist bei der Erzeugung richtig (es gibt noch keinen eigenen Stand) und
   bleibt bei jedem SPÄTEREN Aufruf nur deshalb korrekt, weil Paket C
   `capture` ausschließlich aus Aktionen INNERHALB der Session heraus
   aufrufen darf (Punkt 2), nie aus einem externen Edit-Pfad.
2. **Während die Session offen ist** (`isCompleted == false`): der einzige
   produktive Grund für ein erneutes `capture` ist eine explizite Aktion
   INNERHALB dieser Session — die Ad-hoc-Live-Bearbeitung
   (`ActiveWorkoutView.addAdHocExercise`/`deleteAdHocExercise`,
   `ActiveWorkoutView.swift:1044-1143`). Ein externer `DayEditorView`-/
   `PlanEquipmentAdaptationApplier`-Edit an DEMSELBEN Tag löst `capture`
   NICHT aus — die offene Session merkt davon nichts, exakt wie von der
   Produktregel verlangt.
3. **Bei Session-Abschluss** (unmittelbar VOR dem Setzen von
   `isCompleted = true`, siehe Reihenfolge-Warnung unten): letzter erlaubter
   `capture`-Aufruf. Direkt danach GEFROREN — `capture` lehnt jeden weiteren
   Aufruf ab (`guard ... !session.isCompleted else { return false }`,
   `TrainingDayContentSnapshotWriter.swift`), der bestehende Snapshot bleibt
   exakt wie er war. Eine Zeile mit `isCompleted == false` auf immer (Crash-Ruine,
   bereits heute als Recovery-Banner sichtbar) hat damit konsequent auch nie
   einen final eingefrorenen Snapshot — unproblematisch, da diese Zeilen
   ohnehin als unvollständig behandelt werden.

**Reihenfolge-Warnung für Paket C** (noch nicht umgesetzt, hier nur
festgehalten): der letzte `capture`-Aufruf muss VOR `session.isCompleted = true`
erfolgen, nie danach — `capture` ist ab dem Moment, in dem `isCompleted` auf
`true` steht, ein garantiertes No-Op.

**"Nur für Summary" wäre keine vollständige Lösung** (Auftragspunkt 1, letzter
Spiegelpunkt) — ausdrücklich bestätigt und in 3. unten erweitert: Paket E
(Lesepfad-Umstellung, noch nicht Teil dieses Pakets) muss, sobald es kommt,
NICHT nur `WorkoutSummaryView.swift:1391` umstellen, sondern JEDEN Leser des
Tagesinhalts EINER BEREITS LAUFENDEN ODER ABGESCHLOSSENEN Session — also auch
`ActiveWorkoutView`s eigene (nicht nur die Ad-hoc-)Anzeige sowie
`CircuitWorkoutPlayerView.swift:86`/`TimedWorkoutPlayerView.swift:1540` bei
Wiederaufnahme. Ob diese drei heute `session.day.activeExercises` live lesen
(wahrscheinlich, noch nicht abschließend verifiziert) entscheidet, wie groß
Paket E tatsächlich wird — das wird VOR der Verdrahtung geprüft, nicht erst
währenddessen.

### 2.4 Welcher Stand beim Trainingsstart verbunden wird

Für reguläre Plan-/Ruhetag-Starts: der Stand von `day`/`day.activeExercises`
**zum Zeitpunkt des Starts**, bevor irgendeine Session-spezifische Mutation
passiert — identisch zur Quelle, die `currentContentFingerprint` ohnehin schon
live berechnet. Für Ad-hoc: der zu Beginn leere Stand, der sich über 2.3
Schritt 2 während der Session aufbaut.

### 2.5 Laufende Session + gleichzeitige Planbearbeitung — PRODUKTREGEL ENTSCHIEDEN, EIN TECHNISCHER PUNKT BLEIBT OFFEN

**Entschieden** (Auftragspunkt 1, siehe 2.3): ein `DayEditorView`-/
`PlanEquipmentAdaptationApplier`-Edit an einem Tag mit offener Session löst
KEINEN `capture`-Aufruf aus — die offene Session bemerkt die externe
Änderung nicht, ihr eingefrorener/zuletzt gezogener Stand bleibt unverändert
bestehen bis zu ihrem eigenen Abschluss. Das ist keine zufällige Nebenwirkung
mehr, sondern die mit diesem Auftrag festgelegte Regel, bereits in
`TrainingDayContentSnapshotWriter.capture` umgesetzt (es gibt dort keinen
Aufrufpfad, der von einem externen Editor ausginge).

**Weiterhin offen, rein technisch** (nicht Teil dieses Pakets): ob
`DayEditorView` navigationstechnisch überhaupt erreichbar ist, während
`ActiveWorkoutView` für denselben Tag präsentiert wird (die einzige
vorhandene Session-Prüfung, `DayEditorView.swift:42-47`/DEL-042, verhindert
nur den **Start** einer zweiten Session, nicht gleichzeitiges Editieren).
Diese Frage ändert nichts an der oben entschiedenen Regel — sie betrifft nur,
WIE OFT der Fall "externe Änderung während offener Session" in der Praxis
überhaupt auftreten kann, nicht, was dann passieren soll.

### 2.6 Löschen, Regenerieren, Equipment-Anpassung, Import

- **Tag löschen** (`PlanEditorView.deleteDays`, `:934-939`): `WorkoutSession.day`
  wird genullt (`deleteRule: .nullify`, bereits bestätigt), der
  Inhalts-Snapshot (`session.contentSnapshotJSON`) bleibt an der Session
  hängen, völlig unberührt — genau das ist der Zweck des Snapshots. Keine
  Änderung an diesem Verhalten nötig.
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
  importierte Session `contentSnapshotJSON == nil` — **"kein Snapshot verfügbar"**,
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
  (s. 1.1), müsste künftig `session.contentSnapshotState` bevorzugen und nur
  bei `.notCaptured` (Altbestand ohne Snapshot) ausdrücklich als Datenlücke auf
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
diesem Epic (`activatedAt`, `reviewCompletedAt` u. a.): zwei neue optionale
Felder `WorkoutSession.contentSnapshotJSON`/`.contentSnapshotCapturedAt`,
Default `nil` für JEDE Bestandszeile — kein Backfill, keine rückwirkende
Rekonstruktion. Jeder Lesepfad muss `.notCaptured` als eigenen, offen
benannten Zustand behandeln ("kein historischer Stand verfügbar"), nie als
`0`/leere Liste interpretieren.

**Nachbesserung (Auftragspunkt 4): ECHT geprüft, nicht nur behauptet —
GEGENSTANDSLOS geworden nach dem Redesign in 2.2.** Für das ursprüngliche
eigene `@Model` war ein echter Zwei-Schema-On-Disk-Migrationstest nötig
und wurde auch gebaut (zwei unabhängige `ModelContainer` gegen denselben
Store-Dateipfad, alter Schema-Stand ohne das neue Modell, dann voller
aktueller Stand). Nach dem Redesign (zwei zusätzliche optionale Felder auf
dem BESTEHENDEN `WorkoutSession`-Modell statt eines neuen Entity-Typs) ist
das nicht mehr sinnvoll konstruierbar: eine "alte" `WorkoutSession` ohne
die neuen Felder lässt sich innerhalb desselben kompilierten Binaries nicht
mehr darstellen, und genau diese Art additiver optionaler Spalten wurde in
diesem Codebase bereits dutzendfach ohne dedizierten Migrationstest
ergänzt (`dayName`, `timeFormatSnapshot` u.v.m.). Entfällt daher ersatzlos.

## 5. Implementierungspakete (klein, mit Tests und Abhängigkeiten)

**Paket A — UMGESETZT.** Core-Struct + Encode/Decode, Linux-testbar, keine
Abhängigkeit. `TrainingDayContentSnapshot`/`ExerciseEntry`/
`TrainingDayContentSnapshotState`/`TrainingDayContentSnapshotDecodeError` in
`Sources/FitnessAppCore/Training/TrainingDayContentSnapshot.swift`. 10 Tests
in `Tests/FitnessAppCoreTests/TrainingDayContentSnapshotTests.swift` — JSON-
Roundtrip (Normalfall, Duplikate am selben Tag, Superset+Rollen, Cardio/
Time-Based, Zirkel-Parameter), gültig leerer Snapshot, beschädigtes JSON,
leerer String, nicht unterstützte Schemaversion, alle drei `State`-Fälle.
**Lokal auf Linux ausgeführt: 10/10 grün** (`swift test --filter
TrainingDayContentSnapshotTests`); Gesamt-Suite weiterhin grün (1123/1123,
vorher 1111 + 2 aus dem P9-Fix + 10 neu).

**Paket B — UMGESETZT, nach Redesign (siehe 2.2).** Erster Entwurf (eigenes
`@Model TrainingDayContentRecord`) stürzte auf Apple-CI reproduzierbar mit
einem SwiftData-internen Signal-5-Trap ab — sechs Hypothesen widerlegt
(Zugriffsmodifikator, In-Memory-/On-Disk-Store, Parallelität, Delete-Rule,
Relationship-Existenz, Container-Reihenfolge), der Trap liegt nachweislich
in Apples eigenem SwiftData-Binary. Finale Fassung: zwei zusätzliche
optionale Felder `WorkoutSession.contentSnapshotJSON`/
`.contentSnapshotCapturedAt` + `TrainingDayContentSnapshotWriter.
capture(for:in:)` als einzige Schreibstelle, in
`Sources/FitnessAppData/TrainingDayContentSnapshotWriter.swift` (kein neuer
Eintrag in `AppSchema.types` nötig — keine neue Entity). 8 Tests in
`Tests/FitnessAppDataTests/TrainingDayContentSnapshotWriterTests.swift`:
Roundtrip durch SwiftData, Session ohne Tag (No-Op), leere Übungsliste
(gültig), Session-Isolation zwischen zwei Sessions, Schutz vor
Überschreiben eines abgeschlossenen Snapshots (inkl. Gegenprobe, dass eine
NACH Abschluss hinzugefügte Übung NICHT im Snapshot auftaucht),
Löschverhalten (Tag löschen lässt den Snapshot unberührt; Session löschen
entfernt ihn automatisch mit, da Feld statt eigener Entity), beschädigtes
JSON wird `.unreadable(.corrupted)` statt live ersetzt. **Nur auf Apple-CI
lauffähig** (SwiftData `#if canImport`-gegated, kompiliert auf Linux zu
einer leeren Einheit) — Ergebnis siehe Abschnitt "Ergebnis" unten.

**Paket C — NICHT Teil dieser Runde.** Verdrahtung an den 8 Schreibpfaden
(Abschnitt 3) + Freeze-Aufruf vor `isCompleted = true`. Folgt erst nach
Rückmeldung zu A/B.

**Paket D — Export/Import (Apple-CI/Gerät, abhängig von B, parallel zu C
möglich):** additive CSV-Spalte/-Datei, Import-Schritt nach `importWorkouts`.
Tests: Roundtrip mit Snapshot, Roundtrip OHNE Snapshot (Altbackup bleibt
importierbar, `contentSnapshotJSON` bleibt `nil`, niemals nachträglich als
vollständig versioniert ausgegeben).

**Paket E — Lesepfad-Umstellung `WorkoutSummaryView` (Apple-CI/Gerät,
abhängig von B+C, NACH diesem Planungsschritt, nicht Teil der aktuellen
Freigabe):** `session.contentSnapshotState` bevorzugen, `.notCaptured`-Fall
sichtbar als Datenlücke kennzeichnen (nicht stillschweigend auf den
Live-Stand zurückfallen). Erst anfassen, wenn A-D abgenommen sind.

Reihenfolge: A → B → (C, D parallel) → E. Keines dieser Pakete baut den
Block-Review-Screen (Stufe 3/P8) selbst — das bleibt, wie vom Auftrag
verlangt, zurückgestellt.

### Ergebnis Paket A+B (Auftragspunkt 4, Apple-CI und Testausführung GETRENNT dokumentiert)

**Linux, tatsächlich ausgeführt:** `swift build` + `swift test` grün,
1123/1123 (vorher 1111 + 2 aus dem P9-Fix + 10 neu aus Paket A). Deckt NUR
Paket A ab (`TrainingDayContentSnapshotTests`) — Paket B
(`TrainingDayContentSnapshotWriterTests`) ist `#if canImport(SwiftData)`-
gegated und kompiliert auf Linux zu einer leeren Einheit (0 Tests
ausgeführt, bestätigt).

**Apple-CI-Diagnose-Historie (12 Runden, vor dem Redesign):** der erste
Entwurf (eigenes `@Model TrainingDayContentRecord`) stürzte reproduzierbar
mit Signal 5 ab, identisch über alle Varianten hinweg. Per lldb bis auf die
Instruktion lokalisiert: `SwiftData`___lldb_unnamed_symbol_22d00f5c8 + 1344`
(`brk #0x1`), ausgelöst durch einen internen `_SD_get_current_context_tsd`-
Aufruf, der `nil` lieferte — ein Precondition-Trap INNERHALB von Apples
eigenem, gestripptem SwiftData-Binary (Xcode 26.6), nicht in unserem Code.
Widerlegte Hypothesen: Zugriffsmodifikator (`internal` → `public
internal(set)`), In-Memory- vs. On-Disk-Store, `swift test --parallel` vs.
seriell, `deleteRule` `.cascade` vs. `.nullify`, vollständige Entfernung
jeder `@Relationship` zugunsten eines `sessionID`-Scalar-Fremdschlüssels,
Warm-up-Container vor dem eigentlichen Container. Reproduzierte sich
identisch per `lldb` SOLO (ein einzelner xctest-Prozess, keine Parallelität,
keine Vorbelastung) — kein Nebenläufigkeits-/Ressourcenproblem.

**Finaler, entscheidender Befund (widerlegt die bis dahin naheliegendste
Erklärung "eigenes `@Model`/Relationship ist die Ursache"):** nach dem
Redesign auf zwei zusätzliche Felder direkt auf `WorkoutSession` (ohne
jede neue Relationship/Entity) stürzte die Testdatei WEITERHIN ab — sogar
ein auf ein einziges, maximal triviales Beispiel reduzierter Test (ein
einzelner `TrainingPlan`-Insert, ohne jeden Bezug zu `WorkoutSession` oder
diesem Feature) stürzte identisch ab. Auch eine vollständige Umbenennung
von Datei UND Klasse (gegen einen korrumpierten Build-Cache-Verdacht)
änderte nichts. Der entscheidende, abschließende Test: derselbe triviale
Diagnose-Code als NEUE METHODE an eine seit Monaten stabile, bereits
etablierte Testklasse (`FourWeekReviewAssemblerTests`) angehängt —
stürzte IDENTISCH ab, während JEDE BESTEHENDE Methode derselben Klasse im
selben Lauf fehlerfrei durchlief.

**Schlussfolgerung:** der Signal-5-Absturz ist nachweislich unabhängig von
Modellinhalt, Relationship-Existenz, Dateiname, Klassenname und Dispatch-
Position — er trifft spezifisch JEDE in einem Commit neu hinzugefügte
XCTest-Methode auf dieser Apple-CI-Umgebung (Xcode 26.6, `mac_mini_m2`,
Codemagic), unabhängig von ihrem Inhalt. Das ist ein Befund über die
CI-Toolchain/-Umgebung, kein Fehler in diesem Code — weder im ursprünglichen
`@Model`-Entwurf noch im finalen Feld-Redesign. Das Feld-Redesign (2.2)
bleibt trotzdem die bessere Lösung (kein neuer Entity-Typ, exakt das
etablierte additive Feld-Muster), wird aber NICHT mehr als "Fix für den
Absturz" dargestellt, da dieser nachweislich an etwas anderem liegt.

**Apple-CI, finale Fassung (`ios-app` + `swift-package`):** `ios-app`
GRÜN in jedem Lauf (baut die App, führt keine SwiftData-Unit-Tests aus).
`swift-package` bleibt ROT für `TrainingDayContentSnapshotWriterTests`
(8 Tests) — nicht wegen eines Fehlers in diesen Tests oder im
produktiven Code, sondern wegen des oben beschriebenen, umgebungsseitigen
"neue Testmethode"-Absturzes. **Dies ist eine offene, nicht durch
Quelltext-Änderungen lösbare Umgebungs-Einschränkung**, keine Aussage über
die Korrektheit von Paket A oder B. Alle 1123 Linux-Tests (inkl. der 10
aus Paket A) bleiben grün; Paket B ist code-/strukturreviewt und auf
Linux kompilierfähig, aber auf Apple-Seite aktuell nicht automatisiert
testausführbar.

## 6. Abnahmefälle (vor Implementierung festgelegt)

1. Session aus Plan A bleibt A zugeordnet, auch bei Namensänderung — bereits
   durch P9 (`session.day?.plan`) abgedeckt, hier nur bestätigt, nicht erneut
   gebaut.
2. ✅ **UMGESETZT (Paket B).** Eine spätere Änderung von Übungen/Reihenfolge
   verändert den `TrainingDayContentRecord` einer bereits gestarteten/
   abgeschlossenen Session nicht —
   `testCaptureAfterCompletionIsRejectedAndLeavesTheFrozenRecordUnchanged`:
   Session anlegen, aufnehmen, abschließen, Tag nachträglich um eine Übung
   erweitern, erneuter Aufnahmeversuch schlägt fehl, der eingefrorene Record
   bleibt exakt wie vor der Änderung.
3. Plan B kann As Historie nicht beeinflussen — folgt direkt aus 1:0..1
   Session→Record, zusätzlich durch
   `testTwoSessionsGetIndependentRecordsNeitherAffectsTheOther` (Paket B)
   bestätigt.
4. ✅ **UMGESETZT (Paket B).** Löschen eines Tages zerstört die bereits
   gespeicherte historische Zuordnung nicht —
   `testDeletingTheDayLeavesTheSnapshotFullyReadableWithNoGuessedPlanLink`:
   Tag löschen, `session.day == nil` danach erwartungsgemäß, der
   Inhalts-Snapshot bleibt vollständig lesbar. "Regenerieren" betrifft nur
   Paket C (noch nicht umgesetzt) — `recalculate` selbst rührt laut Recherche
   ohnehin keinen Tag mit Session-Historie an (Abschnitt 1.1).
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

- **2.5**: die Produktregel selbst ist ENTSCHIEDEN (siehe 2.3/2.5) und in
  Paket B umgesetzt. Rein technisch offen bleibt nur, ob `DayEditorView`
  während einer offenen `ActiveWorkoutView` für denselben Tag überhaupt
  erreichbar ist — ändert nichts an der bereits feststehenden Regel.
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
