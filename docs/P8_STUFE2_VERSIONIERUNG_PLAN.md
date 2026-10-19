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

**KORRIGIERT gegenüber einer früheren Planungsfassung dieses Abschnitts
(Meilenstein "Snapshots produktiv nutzbar machen", Lebenszyklus-
Widerspruch):** die frühere Fassung sah einen letzten `capture`-Aufruf
unmittelbar VOR `isCompleted = true` vor. `capture` liest dabei IMMER den
Live-Tag komplett neu — das hätte eine zwischenzeitliche EXTERNE Änderung
(DayEditorView, Equipment-Anpassung) am selben Tag unbemerkt in den
"finalen" Snapshot übernommen, obwohl die Produktregel genau das
verbietet. Tatsächlich umgesetzt in `TrainingDayContentSnapshotWriter`
(siehe dort für die volle Begründung):

1. **Bei Session-Erzeugung**: `capture(for:in:)` liest den Live-Tag EIN
   EINZIGES MAL — korrekt, weil es noch keinen eigenen Stand gibt. Guard
   `contentSnapshotJSON == nil` macht jeden weiteren Aufruf (z. B.
   versehentlich bei Wiederaufnahme) zu einem garantierten No-Op, nicht zu
   einem Überschreiben.
2. **Während die Session offen ist**: explizite In-Session-Änderungen
   (Ad-hoc-Übung hinzufügen/entfernen, `ActiveWorkoutView.addAdHocExercise`/
   `deleteAdHocExercise`) rufen `recordAdHocExerciseAdded`/
   `-Removed` auf — diese hängen GEZIELT einen Snapshot-Eintrag an bzw.
   entfernen ihn, OHNE den Live-Tag erneut vollständig zu lesen. Dadurch
   können sie strukturell keine externe Änderung aufnehmen, auch nicht
   versehentlich. Nur für Ad-hoc-Sessions zugelassen (eigenes, ephemeres
   Tag ohne externen Mutationspfad).
3. **Bei Session-Abschluss**: AUSDRÜCKLICH KEIN erneuter `capture`-Aufruf
   mehr. Der zuletzt vorhandene Stand (aus 1. + ggf. 2.) wird eingefroren,
   nicht neu erzeugt. Alle drei produktiven Abschluss-Stellen
   (`ActiveWorkoutView.finishWorkout`, `DayEditorView.
   completeOpenSessionAndStartNew`, `TimedWorkoutPlayerView.
   finishTimedSession`) tragen dazu einen Kommentar, der das als Absicht
   dokumentiert.

**"Nur für Summary" wäre keine vollständige Lösung" — geprüft, Ergebnis
enger als befürchtet:** `ActiveWorkoutView`/`TimedWorkoutPlayerView`/
`CircuitWorkoutPlayerView` zeigen strukturell NIE eine bereits
abgeschlossene Session — `WorkoutRootView` routet ausschließlich über
`ActiveSessionRoute`, die von jedem produktiven Aufrufer nur für
`isCompleted == false`-Sessions gebaut wird; beim Abschluss wird sofort auf
`SummaryRoute` umgeroutet. `WorkoutSummaryView` ist damit tatsächlich die
EINZIGE View, die historische Session-Inhalte zeigt — Paket E (siehe
"Ergebnis Paket C/D/E" unten) musste dort ansetzen, nicht zusätzlich in den
drei Playern.

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

**Bestätigter Befund (kontrolliertes A/B-Experiment, Apple-CI-Build
`6ad510f9fea826065828844a`):** die Container-Lifetime-Hypothese ist die
Ursache. Ein einzelner, minimaler Diagnosetest
(`testMinimalInsertWithRetainedContainer`, `ModelContainer` explizit per
`withExtendedLifetime` gehalten) lief im selben CI-Lauf fehlerfrei durch,
während alle acht `TrainingDayContentSnapshotWriterTests` (altes Muster,
`try makeContainer().mainContext` als anonymer Ausdruck) weiterhin
abstürzten — reiner A/B-Vergleich innerhalb eines Laufs, keine
Zusatzvariable. `try makeContainer().mainContext` haelt den
`ModelContainer` selbst nicht; ARC deallozierte ihn, waehrend der daraus
gezogene `ModelContext` noch in Benutzung war, was in SwiftData einen
internen Precondition-Trap ausloeste (`_SD_get_current_context_tsd` lieferte
`nil`). Die Aussagen "jede neue Testmethode betroffen, unabhängig vom
Inhalt" und "durch Quelltextänderungen unlösbar" waren verfrüht und sind
hiermit widerlegt — die Ursache lag in den Test-Fixtures, nicht im
Modelldesign und nicht in Apples Toolchain/Runner.

**Fix angewendet:** alle acht Tests in `TrainingDayContentSnapshotWriterTests`
halten den `ModelContainer` jetzt durchgehend in einer benannten `let`-
Variable (`Fixture.container`-Feld bzw. direkt im Testkörper) für die
gesamte Testlaufzeit — identisches Muster wie die bereits bestehenden,
nie abgestürzten Tests in `FourWeekReviewAssemblerTests`.

**Zweiter, unabhängiger Fund nach dem Container-Lifetime-Fix (Apple-CI-Build
`6ad5130f097e8eb91225a313`):** mit dem Fix lief die Suite crashfrei durch,
aber `testDeletingTheDayLeavesTheSnapshotFullyReadableWithNoGuessedPlanLink`
schlug mit einem echten `XCTAssertNil`-Fehler fehl —
`session.day` war nach `context.delete(day)` + `save()` NICHT nil.
Ursache: `WorkoutSession.day`/`.gear` hatten `deleteRule: .nullify`, aber
keine deklarierte inverse Relationship; `TrainingDay`/`Gear` hatten keine
Rückreferenz. Ohne inverse Relationship kann SwiftData den Objektgraphen
beim Löschen nicht konsistent halten (Standardverhalten laut Apple-
Dokumentation zu Core-Data-/SwiftData-Relationships) — ein vorbestehender,
bis dahin ungetesteter Zustand, von dem bereits `FourWeekReviewAssembler.swift:197`
abhängt (`session.day == nil`-Prüfung). Gezielt behoben (vom User
freigegeben): `TrainingDay.sessions`/`Gear.sessions` als neue,
inverse-deklarierende Relationships ergänzt (Muster identisch zu
`TrainingDay.exercises` ↔ `Exercise.day`), `WorkoutSession.day`/`.gear`
dafür auf plaine Properties ohne eigenes `@Relationship` zurückgebaut.

**Finaler Apple-CI-Stand (`ios-app` + `swift-package`, Build
`6ad514f44fc62c1058e502a3` / `6ad5162c7c9acec0cd18e2ef`):** beide Workflows
GRÜN. `swift-package`: alle 1379 Tests (inkl. aller acht
`TrainingDayContentSnapshotWriterTests`) ohne Fehler, kein Crash.
`ios-app`: App + Widget bauen fehlerfrei mit den geänderten Relationships.
Linux bleibt bei 1123/1123 grün (Paket B weiterhin `#if canImport(SwiftData)`-
gegated, 0 Tests auf Linux ausgeführt, nur kompiliert).

**Verbleibende Grenze:** die inverse-Relationship-Korrektur wurde nur für
`day`/`gear` auf `WorkoutSession` umgesetzt (die beiden von Paket B direkt
berührten bzw. aufgedeckten Fälle). Ob weitere `@Relationship`-Properties
im Datenmodell denselben fehlenden-inverse-Zustand haben, wurde NICHT
systematisch auditiert — das war nicht Teil dieses Auftrags.

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

## 9. Ergebnis Paket C/D/E (Meilenstein "Snapshots produktiv nutzbar machen")

**Lebenszyklus-Widerspruch (Auftragspunkt 1) behoben:** siehe Abschnitt 2.3
oben — `capture` ist jetzt strikt einmalig (Guard `contentSnapshotJSON ==
nil`), explizite In-Session-Änderungen laufen über zwei neue, gezielte
Funktionen (`recordAdHocExerciseAdded`/`-Removed`), die nie den ganzen
Live-Tag neu lesen, und es gibt keinen Re-Capture mehr vor Abschluss.

**Paket C — produktiv verdrahtet:** Initial-`capture` an allen drei
Erzeugungsstellen mit echtem Tag (`DashboardView.actuallyStartNewWorkout`/
`startAdHocWorkout`, `DayEditorView.actuallyStartNewSession`). Rest-Tag-
Marker (`markRestDaySkipped`, zwei Stellen) und HealthKit-Import
(`ExternalWorkoutImportService`) bewusst NICHT verdrahtet — `capture` wäre
dort ohnehin ein No-Op (`isCompleted` bereits `true` bzw. `day == nil`).
`ActiveWorkoutView.addAdHocExercise`/`addAdHocCustomExercise`/
`deleteAdHocExercise` rufen die neuen `recordAdHocExercise*`-Funktionen
auf. Alle drei Abschluss-Stellen (`ActiveWorkoutView.finishWorkout`,
`DayEditorView.completeOpenSessionAndStartNew`,
`TimedWorkoutPlayerView.finishTimedSession` für alle vier Zeitformate)
tragen einen Kommentar, der den bewusst fehlenden Re-Capture dokumentiert.

**Paket D — Export/Import additiv:** zwei neue CSV-Spalten in
`workouts.csv` (`content_snapshot_json`, `content_snapshot_captured_at_utc`),
angehängt nach etabliertem Muster. Import übernimmt beide Felder 1:1 NACH
der Session-Konstruktion (wie `session_feeling`) — ruft bewusst NICHT
`TrainingDayContentSnapshotWriter.capture` auf, das würde den damaligen
Stand durch den heutigen Stand des per `idMap` verknüpften Tages ersetzen.
Fehlende Spalte (Altbackup) ergibt über den bestehenden
`CSVRow`-Rückwärtskompatibilitätspfad `nil` — kein nachträglich erfundener
Startzustand. `formatVersion` bewusst NICHT erhöht (etablierte Praxis
dieses Codebases: additive Spalten erhöhen die Version nicht, nur der
Major-Teil wird beim Import geprüft). Backup/Restore nutzt denselben
Export/Import-Pfad, ist also automatisch mitgesichert.

**Paket E — Leser umgestellt, enger als befürchtet — KORRIGIERT, siehe
Abschnitt 10:** Recherche VOR der Verdrahtung (wie im Auftrag gefordert)
ergab: `ActiveWorkoutView`/`TimedWorkoutPlayerView`/
`CircuitWorkoutPlayerView` zeigen strukturell NIE eine bereits
abgeschlossene Session (`WorkoutRootView` routet ausschließlich über
`ActiveSessionRoute`, die nur `isCompleted == false`-Sessions bekommt;
beim Abschluss wird sofort auf `SummaryRoute` umgeroutet). **Diese
Begründung wurde vom Auftrag zu Recht als unzureichend zurückgewiesen:**
sie deckt nicht ab, dass der Session-Inhaltsvertrag ausdrücklich auch für
eine noch OFFENE, WIEDERAUFGENOMMENE Session gilt — genau diese drei
Player lasen bei jedem (Wieder-)Rendern weiterhin direkt den Live-Tag.
Abschnitt 10 dokumentiert die Nachbesserung. `WorkoutSummaryView` bleibt
die einzige View für bereits ABGESCHLOSSENE Sessions — dort wurde wie
folgt umgestellt:
- `timedFormatCircuitSection` (AMRAP/EMOM/Auf-Zeit/Zirkel-Referenzliste)
  und die zugehörigen Zielwert-Stats (Minuten-Deckel, Zirkel-Rundenziel,
  Zirkel-Pause, Hero-Stat, Edit-Mode-Stepper-Obergrenzen) lesen jetzt
  snapshot-first. `.notCaptured` (Altbestand vor P8) fällt weiterhin auf
  den Live-Tag zurück, zeigt dabei aber jetzt sichtbar den Hinweis
  "Zeigt den aktuellen Planstand – kein überprüfter historischer
  Schnappschuss" (`summary.content.noHistoricalSnapshot`). `.unreadable`
  zeigt explizit "Trainingsdetails nicht lesbar"
  (`summary.content.unreadable`) statt stillschweigend auf den Live-Tag
  auszuweichen.
- **Zweiter, unabhängig gefundener Bug** (nicht Teil des ursprünglichen
  Auftrags, aber direkt im Weg): `exercisesWithLogs` verwarf jedes Log
  komplett, dessen `Exercise` inzwischen gelöscht wurde (z. B. nach
  Tag-Löschung) — der Satz blieb in `session.totalSets` mitgezählt, war in
  der Aufschlüsselung aber unsichtbar. Behoben über die neue, öffentliche
  `ExerciseLogGrouping.group(_:)` (FitnessAppData, Apple-CI-testbar):
  orphane Logs werden jetzt separat gruppiert (`ExerciseLogGroup.orphaned`,
  Schlüssel ist das neue `ExerciseLog.exerciseOrderIndexSnapshot` —
  NICHT der Name, sonst würden zwei gleichnamige, gelöschte Übungen wie
  Hauptsatz + Finisher fälschlich verschmolzen) und read-only angezeigt
  (`orphanedExerciseSection`). Bewusste, dokumentierte Einschränkung:
  orphane Einträge sind nicht editierbar (kein Delete/Add-Satz/Cardio-
  Picker ohne lebendes Objekt) — dieser Auftrag deckt die KORREKTE
  Zuordnung/Anzeige ab, nicht ihre nachträgliche Editierbarkeit.
- `SetSummaryRow`/`formatSetSummary` brauchen keine live `Exercise` mehr —
  `log.resolvedIsCardio`/`resolvedIsTimeBased` (DEL-051, snapshot-first)
  ersetzen `exercise.isCardio`/`isTimeBased` 1:1 für den lebenden Fall und
  funktionieren zusätzlich für orphane Logs.

**Tests (neu, alle auf Apple-CI bestätigt grün — Build
`6ad51efb1b9734c49d90a5c2` (`swift-package`) + `6ad51efc85dd782c6a8a446b`
(`ios-app`), 1392/1392 Tests, 0 Fehler; der Store-Neuöffnungs-Test kam
danach dazu und wurde separat in Build `6ad521ae5b4fec0b065a9209`
bestätigt, 1393/1393 Tests, 0 Fehler):**
- 6 neue `TrainingDayContentSnapshotWriterTests`: kein Überschreiben bei
  Wiederaufnahme trotz externer Tag-Änderung, Ad-hoc-Add/-Remove nimmt
  keine externe Änderung mit, Ad-hoc-Remove trennt gleichnamige Einträge
  korrekt, Ablehnung bei Nicht-Ad-hoc/fehlendem Vor-Snapshot/nach
  Abschluss.
- 1 neuer Persistenz-Test: echter dateibasierter Store, Container
  komplett geschlossen und mit neuem Container auf dieselbe Datei wieder
  geöffnet — trennt echte Persistenz von bloßer In-Memory-Retention
  innerhalb eines Tests (Auftragspunkt 5).
- 3 neue `DataPortabilityRoundtripTests`: nie erfasst/gültig leer/gültig
  gefüllt in einem Test, beschädigte Payload und nicht unterstützte
  Schema-Version je einzeln — alle überleben den Export/Import-Roundtrip
  unverändert.
- 4 neue `ExerciseLogGroupingTests`: Gruppierung lebender Übungen nach
  Objektidentität, der explizit geforderte Gefahrenfall (zwei gleichnamige
  GELÖSCHTE Übungen bleiben getrennt), die Kernregression (ein verwaistes
  Log verschwindet nicht mehr), Namens-Fallback für Alt-Logs ohne
  `exerciseOrderIndexSnapshot`.
- Zwei Sessions beeinflussen einander nicht: bereits durch
  `testTwoSessionsGetIndependentSnapshotsNeitherAffectsTheOther` (Paket
  A+B) abgedeckt, unverändert gültig.

**Migrationsprüflücke, ehrlich ausgewiesen (Auftragspunkt 5):** die neuen
additiven Felder (`contentSnapshotJSON`/`-CapturedAt` aus Paket A+B,
`ExerciseLog.exerciseOrderIndexSnapshot` aus diesem Paket) folgen demselben
Muster wie Dutzende bereits bestehender optionaler Felder in diesem Modell
(`dayName`, `sessionFeeling`, `timeFormatSnapshot`, …) — alle mit `nil`-
Default, lightweight-migrationsfähig. Eine dedizierte Lightweight-
Migrationsprüfung GEGEN EINE ECHTE, VOR DIESEM FELD ERSTELLTE
`.store`-Datei (nicht nur ein frischer In-Memory-Container) wurde NICHT
durchgeführt — es gibt dafür keine eingecheckte Alt-Fixture in diesem
Repository, und das Nachbauen einer solchen Fixture wäre selbst nur eine
Behauptung ohne echten Alt-Bestand. Das ist dieselbe, bereits in Paket A+B
offen ausgewiesene Grenze, keine neue.

**TestingBot-Verifikation: NICHT durchgeführt.** Diese Session hat keinen
Zugriff auf ein TestingBot-Werkzeug oder eine vergleichbare Geräte-Test-
Infrastruktur — eine Suche nach entsprechender Tooling-Anbindung in dieser
Umgebung blieb erfolglos. Statt einer unbegründeten Wiederholungsserie
folgt eine konkrete manuelle Prüfanweisung für den neuen historischen
Bedienablauf:
1. Plan-Tag mit ≥2 Übungen (davon eine doppelt, z. B. Bankdrücken als
   Haupt- und Finisher-Satz) trainieren und abschließen.
2. Im laufenden DayEditor denselben Tag bearbeiten: eine Übung löschen,
   zwei weitere umsortieren, den Tag selbst löschen.
3. Die abgeschlossene Session in der Historie (`WorkoutHistoryView` →
   `WorkoutSummaryView`) erneut öffnen: Übungen/Reihenfolge/Ziele müssen
   dem Stand von Schritt 1 entsprechen, NICHT dem jetzt geänderten/
   gelöschten Tag. Die Sätze der doppelt vorkommenden Übung müssen
   korrekt den beiden ursprünglichen Vorkommen zugeordnet bleiben (nicht
   vermischt).
4. Einen AMRAP/EMOM/Zirkel-Tag trainieren, danach denselben
   Löschen/Umsortieren-Schritt wiederholen, Summary erneut öffnen: Die
   Referenzliste + Zielwerte (Minuten-Deckel/Zirkel-Pause/Rundenziel)
   müssen dem historischen Stand entsprechen.
5. Export erzeugen, alle Daten löschen (Reset), importieren: die
   historischen Sessions aus 1./4. müssen ihre Snapshots unverändert
   zurückbekommen.
6. Eine Ad-hoc-Session mit zwei Übungen starten, eine davon während der
   Session wieder entfernen, abschließen: die entfernte Übung darf im
   Summary nicht auftauchen, die verbleibende muss korrekt sein.

**Umfang bewusst begrenzt (Auftragspunkt 6):** kein allgemeiner
Relationship-Umbau — die einzige in C/D/E tatsächlich berührte Beziehung
ist die bereits vorhandene, korrekt deklarierte `Exercise.logs`-Relation
(`.nullify`, inverse bereits vorhanden, siehe Paket-B-Fund zu `day`/`gear`
oben — dieser war unabhängig und ist bereits behoben). Kein Block-Review-
Screen, keine Blocklänge, kein neuer Coaching-Algorithmus. Due-Badge- und
sonstige bisherige Restprüfungen bleiben separat offen.

**Ist der historische Inhalts-Schutz jetzt durchgängig produktiv
nutzbar?** Für ABGESCHLOSSENE Sessions (`WorkoutSummaryView`): ja, mit zwei
dokumentierten, bewussten Grenzen: (1) orphane Log-Einträge (Übung
nachträglich gelöscht) sind sichtbar und korrekt zugeordnet, aber nicht
editierbar; (2) die Migrationsprüflücke oben bleibt offen. Für eine noch
OFFENE/wiederaufgenommene Session galt das zum Zeitpunkt dieses Pakets
NICHT — siehe Abschnitt 10 für die Nachbesserung und das aktualisierte
Gesamturteil. Alle sieben vom Auftrag genannten Regressionsszenarien für
den historischen Fall sind durch automatisierte Tests abgedeckt (Punkt 5
der Vorgabe), bis auf die reinen UI-Interaktions-Schritte, für die die
manuelle Prüfanweisung oben gilt. Beide Apple-CI-Workflows waren für
diesen Stand grün (s. o.).

## 10. Nachbesserung: Wiederaufnahme-Isolation (Resume-Fall)

**Auslöser:** Nutzer-Korrektur nach Paket C/D/E — die Begründung "Player
zeigen keine abgeschlossenen Sessions" ist für die Resume-Frage irrelevant;
der Vertrag ("eine laufende Session behält ihren eigenen Inhaltsstand")
gilt explizit AUCH für eine noch offene, wiederaufgenommene Session, nicht
nur für abgeschlossene. Vorgegebene Reproduktionsschritte: Session starten
→ verlassen (offen lassen) → denselben Tag extern ändern (Übung
hinzufügen/entfernen/umsortieren, Zielwerte ändern) → wiederaufnehmen →
prüfen, was Player/Satzvorgaben/Logging TATSÄCHLICH verwenden (nicht nur,
ob das Snapshot-JSON unverändert blieb) → abschließen und mit Summary
vergleichen. Dasselbe Prinzip zusätzlich für Zeitformat/Zirkel. Zusätzlich
gefordert: prüfen, ob der Ad-hoc-Übungseditor (nicht nur Add/Remove)
korrekt in den Snapshot einfließt.

### 10.1 Rechercheergebnis (vor jeder Code-Änderung erhoben)

- **Reichweite bestätigt:** `DayEditorView` ist navigierbar, während für
  denselben Tag eine offene Session existiert — kein Lock verhindert das;
  `DayEditorView.openSessionForCurrentDay` (DEL-127) existiert sogar
  eigens, um diesen Zustand zu erkennen (zeigt dann einen Resume-Button
  statt "Training starten", blockiert aber nicht den Editor selbst).
- **`ActiveWorkoutView.orderedExercises(in:)`** las bei JEDEM (Wieder-)
  Rendern `day.activeExercises` live — Liste, Reihenfolge UND der
  Warmup-Filter. `ExerciseCard`/`SetRow` lasen alle Satzvorgaben
  (Sets/Reps/Pause/RIR/Cardio-Distanz/-Dauer/Rolle/Cardio-Zeitbasiert-
  Klassifikation) direkt von der Live-`Exercise`. `logSet` band jeden neuen
  `ExerciseLog` an genau die `Exercise`-Instanz, die der Live-Tag gerade
  an dieser Position lieferte — nach einer externen Umsortierung also
  potenziell die FALSCHE Übung. `finishWorkout`s `exerciseCount` und
  `isSupersetRoundComplete`s Partner-Erkennung lasen ebenfalls live.
- **`TimedWorkoutPlayerView`** (AMRAP/EMOM/Auf-Zeit) und
  `CircuitWorkoutPlayerView`: `day?.timeCapMinutes`/`circuitRounds`/
  `circuitRestSeconds`/`circuitMode` steuerten die TATSÄCHLICHE Timer-/
  Rundenlogik (Deckel-Erkennung, EMOM-Minutenrotation `exercises[(minute-1)
  % exercises.count]`, Zirkel-Rundenabschluss `.toFailure` vs.
  `.fixedReps`), nicht nur die Anzeige. `ForTimePlayerView.totalBoxes`/
  `exerciseRoundsRow` lasen `exercise.sets` live für die Checkbox-Anzahl.
  Zusätzlicher, unabhängig gefundener Fund: `ForTimePlayerView`/
  `CircuitPlayerView` persistieren den Haken-Fortschritt
  (`forTimeCheckedRoundsRaw`/`circuitCurrentRoundCheckedRaw`) als
  `orderIndex=Anzahl`-Paare und lasen beim Decode gegen den LIVEN
  `exercise.orderIndex` zurück — nach einer externen Umsortierung hätte
  das bei Wiederaufnahme den Fortschritt der FALSCHEN Übung zugeordnet.
- **Ad-hoc-Übungseditor-Lücke bestätigt:** `ExerciseEditorView` (voll
  editierbar für `day.plan == nil`) wird aus `ActiveWorkoutView` NUR für
  `session.isAdHoc` geöffnet (`onEdit`-Gate) — dieser Pfad hatte keine
  Rückkopplung zum Snapshot. Zusätzlich, über den ursprünglichen Fund
  hinaus: `ExerciseCard.addSet()`/`removeSet(at:)` (die "+ Satz"-Aktion
  direkt auf der Karte) mutieren `exercise.sets` live für JEDE Session
  (nicht nur Ad-hoc) und hatten ebenfalls keine Rückkopplung.
- **Keine stabile Instanz-Identität:** `Exercise` hatte keine vom
  `orderIndex` (ändert sich bei Umsortierung) oder `exerciseTemplateID`
  (von mehreren Instanzen geteilt) unabhängige, stabile ID — eine
  Kernvoraussetzung, um einen Snapshot-Eintrag nach einer externen
  Umsortierung zuverlässig auf sein ursprüngliches Live-Objekt
  zurückzuführen, fehlte bislang komplett.

### 10.2 Umsetzung

- **`Exercise.instanceID: UUID?`** (neu, `FitnessAppData/Exercise.swift`):
  immer frisch per `UUID()` im `init` erzeugt, nie nachträglich gesetzt.
  `nil` nur für Alt-Zeilen vor diesem Feld (lightweight-migrationsfähig,
  gleiches Muster wie alle bisherigen optionalen Felder in diesem Modell).
- **`TrainingDayContentSnapshot.ExerciseEntry.instanceID: UUID?`** (neu,
  Core): Snapshot des obigen Felds. Additiv, `schemaVersion` NICHT erhöht —
  ein Alt-JSON ohne diesen Key dekodiert dank Codables
  `Optional`-Synthese automatisch zu `nil` (Linux-verifiziert, siehe
  `testExerciseEntryWithoutInstanceIDKeyDecodesAsNilNotAsCorrupted`).
- **`SessionContentResolver`** (neu, `FitnessAppData`): einzige Stelle, die
  einen Snapshot gegen den aktuellen Live-Tag auflöst. Matching PRIMÄR über
  `instanceID` (übersteht externe Umsortierung), Fallback
  `exerciseTemplateID`+`orderIndex` für Alt-Snapshots ohne `instanceID`
  (bestmöglich, nicht schlechter als der Zustand vorher). Liefert pro
  Snapshot-Eintrag `.live(entry, exercise)` oder `.removedFromLiveDay(entry)`
  — ein extern gelöschtes Live-Objekt verschwindet nie still, eine extern
  HINZUGEFÜGTE Live-Übung taucht nie auf (allein durch Konstruktion: es
  wird über `snapshot.exercises` iteriert, nie über `liveExercises`).
- **`recordAdHocExerciseEdited`** (neu, `TrainingDayContentSnapshotWriter`):
  deckt den Ad-hoc-Editor-Schreibpfad ab — "ausdrücklich innerhalb der
  Session vorgenommene Änderung", nur aus `ActiveWorkoutView`s
  `exerciseToEdit`-Sheet (`.onDisappear`) aufgerufen, NIE aus
  `DayEditorView`. Gleiche Guards wie `recordAdHocExerciseAdded`
  (`!isCompleted`, `isAdHoc`, `.available`).
- **`recordSetCountChange`** (neu, `TrainingDayContentSnapshotWriter`):
  deckt die "+ Satz"-Karten-Aktion ab — bewusst OHNE `isAdHoc`-Guard (gilt
  für JEDE Session, da dieses Steuerelement nur innerhalb der laufenden
  Session selbst existiert, nie "extern"). Aktualisiert chirurgisch NUR
  `sets`, nicht per vollem Rebuild — ein zwischenzeitlich auf einem ANDEREN
  Weg (DayEditorView) geändertes Feld derselben Übung darf nicht huckepack
  mit einsickern (eigener Regressionstest:
  `testRecordSetCountChangeDoesNotAbsorbOtherFieldsChangedExternallyInTheMeantime`).
- **`ActiveWorkoutView`**: `orderedExercises(in:)` liefert nur noch die
  Fallback-Basis für Alt-Sessions; die neue `resolvedExercises`-Property
  (snapshot-first über `SessionContentResolver`, Warmup-Filter auf dem
  aufgelösten Ergebnis) ist jetzt die EINZIGE Quelle für Liste/Reihenfolge
  in `paginatedBody`/`dayCategory`/`isCardioSession`/`activeContextRow`/
  `isSupersetRoundComplete`/`finishWorkout`/`deleteAdHocExercise`.
  `.removedFromLiveDay`-Einträge rendern als neue, read-only
  `RemovedExerciseCard` (sichtbarer Hinweis, kein neues Logging möglich —
  bewusste, dokumentierte Einschränkung, analog zu orphanen Logs in der
  Historie). `ExerciseCard`/`SetRow` bekommen zusätzlich `content:
  TrainingDayContentSnapshot.ExerciseEntry` und lesen ALLE Satzvorgaben
  (Sets/Reps/Pause/RIR/Cardio-Distanz/-Dauer/Rolle/Cardio-Zeitbasiert)
  daraus statt von der Live-Übung; `exercise` bleibt ausschließlich für
  Logging-Identität und bewusst außerhalb des Snapshot-Vertrags belassene
  Felder (Equipment/Barbell-Erkennung, `suggestedWeight`,
  Name-Lookup fürs GIF) maßgeblich — diese Felder waren schon im
  ursprünglichen Schnappschuss-Datenvertrag (Abschnitt 2) bewusst NICHT
  aufgenommen (Coaching-/Metadaten-Konzepte, keine "was wurde trainiert"-
  Satzvorgabe) und werden hier nicht nachträglich ergänzt.
- **`TimedWorkoutPlayerView` (AMRAP/EMOM/Auf-Zeit) +
  `CircuitWorkoutPlayerView`**: neue `WorkoutSession`-Extension
  `contentSnapshotFirst`/`contentSnapshotTimeCapMinutes`/
  `contentSnapshotCircuitRounds`/`-RestSeconds`/`-Mode`
  (`FitnessAppData/WorkoutSessionContentSnapshotFirst.swift`, aus
  `WorkoutSummaryView`s bisher privater, dupliziertem Helfer extrahiert und
  dort durch Aufrufe auf `session.` ersetzt) ersetzt alle `day?.`-Lesungen,
  die bislang echte Timer-/Rundenlogik trieben. Jeder der drei Player-
  Typen bekommt sein eigenes `resolvedExercises`
  (Instanz-Property + statische Variante für `init`, da `self` dort noch
  nicht erreichbar ist) nach demselben Resolver-Muster.
  `ForTimePlayerView`/`CircuitPlayerView`s `encodeCheckedRounds`/
  `decodeCheckedRounds`/`encodeCheckedInRound`/`decodeCheckedInRound`
  matchen jetzt gegen den eingefrorenen `entry.orderIndex`, nicht mehr
  gegen den live verschiebbaren `exercise.orderIndex`.
  `finishTimedSession`s `exerciseCount` zählt den aufgelösten
  (`.live`-)Bestand, nicht mehr `day.activeExercises.count`.

### 10.3 Bewusst nicht angefasst (keine breite Player-Neugestaltung)

- **Top-Level-Routing** (`TimedWorkoutPlayerView.body`s `switch
  session.day?.timeFormat`, welcher der vier Player-Typen überhaupt
  gerendert wird): bleibt live. Ein externes Ändern des GESAMTEN
  Zeitformats einer bereits laufenden Session (AMRAP → EMOM o. ä.) ist ein
  erheblich drastischerer, seltenerer Edit als Übung/Reihenfolge/Zielwert-
  Änderungen und hätte eine Änderung der View-Auswahl-Architektur selbst
  erfordert — bewusste, dokumentierte Grenze, kein übersehener Fall.
- **Equipment/`primaryMuscle`/`notes`/`suggestedWeight`/
  `smartProgressionEnabled`/`progressionStep`**: bleiben live für ALLE
  Leser (Player wie Summary) — waren schon in Abschnitt 2 bewusst nicht
  Teil des Snapshot-Datenvertrags (Coaching-/Metadaten-Konzepte, keine
  Trainings-Satzvorgabe). Entsprechend liest z. B. die Aufwärm-Rampen-
  Erkennung (`ExerciseCard.isBarbellExercise`/`referenceWeightKg`) weiterhin
  live — keine Erweiterung des Schnappschuss-Schemas für dieses Paket.
- **`.removedFromLiveDay`-Einträge bleiben read-only ohne neue
  Logging-Möglichkeit** — konsistent mit der bereits in Paket E getroffenen
  Entscheidung für orphane Historien-Logs.

### 10.4 Neue Regressionstests (vor dem Fix geschrieben, reproduzieren die Lücke)

- **`SessionContentResolverTests`** (neu, `FitnessAppDataTests`): die
  Kernregression — externe Umsortierung zweier Übungen während die Session
  offen ist, danach muss jeder Snapshot-Eintrag weiterhin auf SEIN eigenes
  Live-Objekt zeigen (`===`-Identitätsprüfung), nicht auf das Objekt, das
  zufällig an der alten Position steht. Dazu: extern hinzugefügte Übung
  bleibt unsichtbar, extern gelöschte Übung wird `.removedFromLiveDay`
  (nicht still fallengelassen), Zielwerte bleiben trotz externer Live-Edits
  eingefroren, Legacy-Fallback ohne `instanceID`.
- **`TrainingDayContentSnapshotWriterTests`** (erweitert): `
  recordSetCountChange` (Erfolg auch für reguläre Nicht-Ad-hoc-Session,
  chirurgisch — andere Felder sickern nicht mit ein, Ablehnung nach
  Abschluss/ohne Vor-Snapshot), `recordAdHocExerciseEdited` (Erfolg,
  Ablehnung für Nicht-Ad-hoc, Ablehnung nach Abschluss).
- **`TrainingDayContentSnapshotTests`** (Core, Linux-verifiziert, 12/12
  grün): `instanceID` übersteht Encode/Decode-Roundtrip; ein Alt-JSON ohne
  den `instanceID`-Key dekodiert zu `nil`, nicht zu `.unreadable`.
- Alle 1125 Linux-ausführbaren Tests (Core + die beiden ungegateten
  Export-Service-Dateien) bleiben grün — siehe Build-Protokoll dieser
  Session.

### 10.5 Verifikationsstatus

Ein gebündelter Apple-CI-Lauf (`ios-app` + `swift-package`), plus ein
einziger notwendiger Nachlauf nach einem reinen Test-Code-Tippfehler
(kein Diagnose-Serienverbrauch):

| Workflow | Build-ID | Ergebnis |
|---|---|---|
| `ios-app` | `6ad52fde4ac5864d3de15029` | **grün** (erster Versuch) |
| `swift-package` | `6ad52fdad69f6dd511d4dab5` | rot — `Build (debug)` bereits grün, `Run unit tests` schlug am Testziel-Compile fehl: 3 `Exercise(...)`-Testaufrufe hatten `orderIndex:` vor `sets:` geschrieben; Swift verlangt Aufrufreihenfolge = Deklarationsreihenfolge. Kein Produktionscode betroffen. |
| Fix | Commit `a4fff0b` | Argumentreihenfolge an den 3 Stellen korrigiert |
| `swift-package` | `6ad5318ef5c0969964373dbc` | **grün** (zweiter Versuch) — alle Build-Schritte `success`, Testlauf erreichte `[1407/1407]`, keine echte Fehlzeile im Log (nur Testnamen, die zufällig "Failed" enthalten, z. B. `testMarkFailedThenConsumeReturnsTrueOnce`) |

Damit sind `ios-app` und `swift-package` auf dem finalen Stand
(Commits `b1f7b43`…`a4fff0b`) beide grün. TestingBot wurde für diese
Nachbesserung nicht eingesetzt: es gab keine konkrete, über die
automatisierten Regressionstests und die zwei grünen Apple-CI-Läufe
hinausgehende Prüffrage (UI-Rendering, Device-spezifisches Verhalten),
die eine manuelle/Device-Verifikation gerechtfertigt hätte.

### 10.6 Gesamturteil (ersetzt das Urteil in Abschnitt 9 für den Resume-Fall)

Die vom Auftrag benannte Lücke war real: `ActiveWorkoutView` und alle
Player (Standard, Timed: AMRAP/EMOM/ForTime, Circuit) lasen bei
Wiederaufnahme ausschließlich den Live-Tag, nie den beim Session-Start
eingefrorenen Snapshot — der Vertrag war für den Wiederaufnahme-Fall
faktisch nicht erfüllt, obwohl das Snapshot-JSON selbst unverändert
blieb. Das ist jetzt behoben, mit Regressionstests reproduziert und
Apple-CI-verifiziert:

- Stabile Instanz-Identität (`Exercise.instanceID`,
  `ExerciseEntry.instanceID`, additiv/rückwärtskompatibel) löst externe
  Umsortierung korrekt auf — vorher hätte eine Umsortierung während
  offener Session Sätze still gegen die falsche Übung geloggt.
- `SessionContentResolver` ist jetzt die einzige Stelle, die Snapshot
  gegen Live-Tag auflöst; extern hinzugefügte Übungen bleiben unsichtbar,
  extern gelöschte erscheinen als `.removedFromLiveDay` (nie still
  fallengelassen), Zielwerte bleiben trotz externer Live-Edits
  eingefroren.
- Beide bisher unadressierten Schreibpfade sind jetzt erfasst: der
  Ad-hoc-Übungseditor (`recordAdHocExerciseEdited`, nur für Ad-hoc-
  Sessions) und die "+ Satz"-Kartenaktion (`recordSetCountChange`, für
  jede Session, chirurgisch auf das Satz-Feld begrenzt).
- Snapshot-first-Verdrahtung zieht sich durch `ActiveWorkoutView`,
  `ExerciseCard`, `SetRow` sowie alle Zeitformat-/Zirkel-Player; dabei
  wurde ein zweiter, unabhängig gefundener Bug mitbehoben: die
  Fortschritts-Persistenz (`encodeCheckedRounds`/`decodeCheckedRounds`,
  `encodeCheckedInRound`/`decodeCheckedInRound`) war über den LIVE
  `orderIndex` statt den eingefrorenen `entry.orderIndex` verschlüsselt
  und hätte nach externer Umsortierung Fortschritt falsch zugeordnet.
- Bewusst nicht angefasst (siehe 10.3): Top-Level-Zeitformat-Routing
  bleibt live (zu drastische/seltene Änderung für einen
  Architekturwechsel), Coaching-/Metadatenfelder
  (Equipment/Notizen/Progression) bleiben außerhalb des Snapshot-
  Vertrags, `.removedFromLiveDay`-Einträge bleiben rein lesend ohne
  neues Logging. Keine Snapshot-Einträge wurden zu editierbaren
  Live-Planobjekten umgedeutet, keine nachträgliche Vermischung mit
  externen Änderungen eingeführt.

**Status-Update gegenüber der eigenen Zwischenbilanz:** "Wiederaufnahme-
Isolation noch nicht vollständig nachgewiesen" ist damit erledigt —
implementiert, mit gezielten Regressionstests nachgewiesen und durch
einen gebündelten, am Ende grünen Apple-CI-Lauf (`ios-app` +
`swift-package`) bestätigt. Historische Summary und Snapshot-Sicherung
waren bereits vorher implementiert und automatisiert geprüft.
Offen bleiben wie dokumentiert: **Geräteabnahme** (manuelle
Device-/Simulator-Prüfung der UI, insbesondere der neuen
`RemovedExerciseCard`-Anzeige) und **Bestandsmigration** (Verhalten
für echte Alt-Sessions aus der Produktionsdatenbank ohne
`instanceID`/`contentSnapshotJSON`, über den Unit-Test-Fallback
hinaus).

## 11. Stufe-2-Abnahme (dieser Meilenstein)

Schließt die beiden in 10.6 offen benannten Punkte (Geräteabnahme,
Bestandsmigration) gezielt ab, ohne neuen Block-Review und ohne
allgemeine Architekturrunde.

### 11.1 Stand (geprüfter Commit, Build-IDs, Artefakt)

Kein neuer Code seit Abschnitt 10 — es wird ausschließlich der bereits
grün geprüfte Stand verwendet, kein unveränderter Code erneut gebaut:

- **Branch:** `claude/smart-onboarding-epic`, HEAD `e1bc52d`.
- **Produktionscode-Stand:** identisch zu Commit `d0d01f4` — verifiziert
  per `git diff --stat d0d01f4..e1bc52d -- Sources/` (leer); seit
  `d0d01f4` wurden ausschließlich Testdateien (`a4fff0b`) und Doku
  (`1a3a07d`, `e1bc52d`) geändert.
- **Apple-CI:** `ios-app`-Build `6ad52fde4ac5864d3de15029` (Commit
  `d0d01f4`, alle Schritte `success`) und `swift-package`-Build
  `6ad5318ef5c0969964373dbc` (Commit `a4fff0b`, alle Schritte
  `success`, 1407/1407 Tests) — beide bereits in 10.5 dokumentiert,
  hier wiederverwendet statt erneut gebaut.
- **App-Artefakt:** `FitnessApp.app.zip` aus Build
  `6ad52fde4ac5864d3de15029`, 39.219.328 Bytes, Bundle-ID
  `com.atamya.FitnessApp`, Version `0.1.0`, `MinimumOSVersion 17.0`,
  nur Simulator-Plattform (`iPhoneSimulator`). Dieses Artefakt wird für
  die Geräte-/Simulator-Abnahme unten verwendet.

### 11.2 Geräte-/Simulator-Abnahme (TestingBot, echter Simulator)

Echter Appium-Durchlauf gegen einen iOS-Simulator (iPhone 15 / iOS 18.0),
nicht nur Code-Review. Build-Identität vor Testbeginn per SHA256
verifiziert: lokal von Codemagic heruntergeladenes Artefakt (Build
`6ad52fde4ac5864d3de15029`, Commit `d0d01f4`) und die bei TestingBot
hinterlegte Kopie (`tb://c8d911abfd829a5fc9c6b5bc`,
`FitnessApp_d0d01f4_resumeisolation.zip`) sind BYTE-IDENTISCH
(`f4b7bc2e...4fc6f6a`). TestingBot-Session:
`c450bc6b40ad-ceed206b8cd1-db5a5071b4a8-179235816557-36254547`.

**Block A — Standardtraining-Wiederaufnahme: BESTANDEN.** Tag mit zwei
Vorkommen derselben Übung (Back Squat) und bewusst unterschiedlichen
Zielwerten angelegt, je einen Satz auf beiden geloggt, Session offen
verlassen. Extern: Reihenfolge verändert, Zielwerte einer anderen Übung
geändert, Löschversuch einer dritten Übung. App vollständig terminiert
und neu gestartet, Session fortgesetzt.
- Reihenfolge/Zielwerte bleiben beim Stand von Session-Start — bestanden.
- Vor dem Verlassen geloggte Sätze sind nach Kaltstart noch da — bestanden.
- Ein neuer Satz auf der einen Back-Squat-Instanz verändert die andere
  nicht (Kern-Regressionsfall) — bestanden.
- Entfernte Übung verständlich markiert: nicht belegbar, siehe Befund
  unten (unabhängiger Day-Editor-Bug, Swipe-Delete persistiert nicht —
  die Übung existierte nach Kaltstart extern unverändert weiter).
- Abschluss/Summary: zwei getrennte "Back Squat"-Blöcke (1 bzw. 2 Sätze)
  werden trotz identischen Namens nicht vermischt, Summary entspricht dem
  tatsächlich Trainierten — bestanden.

**Block B — Zirkel-Wiederaufnahme: BESTANDEN.** Zirkel-Tag (3 Runden)
gestartet ("ROUND 1/3"), eine Übung in Runde 1 abgehakt, Session offen
verlassen, externe Rounds-Änderung (3→5) versucht, Kaltstart. Nach
Wiederaufnahme weiterhin "ROUND 1/3" (nicht 5) UND die abgehakte Übung
bleibt markiert — eingefrorene Rundenzahl und Fortschritt überleben den
Kaltstart korrekt.

**Block C — Ad-hoc-Editor: ECHTER BEFUND, inzwischen behoben.** Nachgeholt
in einer zweiten, gezielten TestingBot-Session
(`9890bb32e69d-7b5ef5ea0a7e-300b8e3e1935-179236085339-69843410`,
derselbe verifizierte Build, kein erneuter Upload nötig). Spontanes
Workout gestartet, eine Übung über den Ad-hoc-Editor bearbeitet (Reps-
min 8→11, live bestätigt: "3 × 11-12 reps"), zusätzlich "+ Satz"
verwendet (live bestätigt: "4 × 11-12 reps"). App vollständig
terminiert und neu gestartet.
- **FAIL:** nach Wiederaufnahme zeigte die Karte wieder den
  URSPRÜNGLICHEN Stand ("3 × 8-12 reps", "0/3") — beide Ad-hoc-Edits
  waren spurlos verloren, obwohl sie vor dem Kill live bestätigt waren.
  Abschluss-Sheet und fertige Summary bestätigten denselben Verlust
  ("Sets: 3" statt der editierten Werte).
- **Root Cause (durch den Gerätetest selbst lokalisiert, nicht nur
  vermutet):** keine der fünf Funktionen in
  `TrainingDayContentSnapshotWriter` rief nach dem Setzen von
  `contentSnapshotJSON`/`.contentSnapshotCapturedAt` explizit
  `context.save()` auf — anders als die meisten übrigen Schreibstellen
  in `FitnessAppData` (z. B. `DeloadManager`, `FourWeekReviewDueStatus`,
  die beide `try context.save()` direkt nach der Mutation aufrufen). Ein
  Prozess-Kill kurz nach der Mutation, bevor SwiftDatas impliziter
  Autosave greift, verliert die Änderung — reproduzierbar bis in die
  historische Summary.
- **Fix (Commit `e95bf6f`):** `try? context.save()` in allen fünf
  Funktionen (`capture`, `recordAdHocExerciseAdded/Removed/Edited`,
  `recordSetCountChange`) ergänzt — dieselbe, bereits im Rest der
  Codebase etablierte Konvention.
- **Verifikation:** drei neue Regressionstests schreiben in einen
  echten dateibasierten Store OHNE zusätzlichen Aufrufer-Save nach dem
  jeweiligen Writer-Aufruf (der bisherige Store-Neuöffnungstest hatte
  den Bug durch einen eigenen Save direkt danach unabsichtlich
  maskiert) und öffnen anschließend einen komplett neuen Container auf
  dieselbe Datei — exakt dieselbe Lücke wie im Gerätetest, nur
  deterministisch statt timing-abhängig. Apple-CI für Commit `e95bf6f`:
  `ios-app`-Build `6ad5453168658dfa50608121` und `swift-package`-Build
  `6ad5453083b3c37d71581e44`, beide alle Schritte `success`, 1413/1413
  Tests erreicht, keine echte Fehlzeile. Keine dritte TestingBot-Runde
  zur erneuten Geräte-Bestätigung dieses Fixes — Regressionstest (der
  den Mechanismus direkt prüft, nicht nur eine zufällige Beobachtung)
  plus grüne Apple-CI entsprechen demselben Nachweisstandard, der in
  diesem Epic durchgängig für Code-Fixes dieser Art verwendet wird
  (siehe Block D), und vermeiden zusätzlichen, hier nicht
  erforderlichen TestingBot-Verbrauch.

**Zwei unabhängige Befunde, NICHT Teil des Resume-Isolation-Vertrags**
(als eigene Tasks gemeldet, hier nur zur Einordnung): Swipe-Delete einer
Übung im Tageseditor persistiert nicht (zweimal reproduziert, auch ohne
offene Session — allgemeiner Autosave-Bug), ebenso persistieren Tag-
Level-Stepper/Picker (Circuit-Rounds, Zeitformat-Picker) nicht
zuverlässig, während Reorder und verschachtelte Exercise-Editor-Felder
zuverlässig speichern. Beide als eigenständige Tasks dokumentiert
(`task_3edd265e`, `task_0d82cbba`) — explizit AUSSERHALB dieses
Meilensteins, keine Vermischung mit dem Snapshot-Vertrag.

### 11.3 Live-Zeitformat-Routing bei externem Wechsel (Block D)

**Befund (Code, nicht nur vermutet):** `WorkoutRootView.swift` routete
anhand `route.session.day?.timeFormat != nil` zwischen
`TimedWorkoutPlayerView` und `ActiveWorkoutView`;
`TimedWorkoutPlayerView.swift` switchte intern ERNEUT auf das live
`session.day?.timeFormat` (AMRAP/EMOM/Auf-Zeit/Zirkel) — beide lasen den
LIVE Tag, nicht den beim Session-Start eingefrorenen Snapshot, obwohl
der Snapshot `timeFormat` bereits mitführt. Eine Live-Demonstration
dieser Lücke am Gerät war durch den oben genannten Day-Editor-Bug
(Structure-Picker persistiert nicht) nicht auslösbar — der Code-Befund
selbst ist davon unabhängig und eindeutig.

**Bewertung:** eine konkrete Vertragslücke, nicht nur ein theoretisches
Risiko — exakt der in 10.3 benannte, bewusst live gelassene Punkt. Die
Lösung erfordert KEINE neue Produktentscheidung: beide Stellen folgen
jetzt demselben bereits etablierten Snapshot-first/Live-Fallback-Muster
wie `contentSnapshotCircuitRounds`/`.../RestSeconds`/`.../CircuitMode`
(`WorkoutSession.contentSnapshotTimeFormat`, Commit `07b917b`). Live-
Fallback bleibt für `.notCaptured`/`.unreadable` erhalten (Alt-Sessions,
beschädigte Snapshots) — dieselbe Politik wie
`ActiveWorkoutView.resolvedExercises`, damit eine Routing-Entscheidung
nie ins Leere läuft.

**Verifikation:** 3 neue Regressionstests
(`WorkoutSessionContentSnapshotFirstTests`) reproduzieren die Lücke vor
dem Fix (externer Formatwechsel bleibt wirkungslos, Legacy-Fallback für
nie aufgenommene Snapshots, Standardtag ohne Zeitformat). Apple-CI für
Commit `07b917b`: `ios-app`-Build `6ad5413a95dc34f946a46e40` und
`swift-package`-Build `6ad54139b1b5e298265ee45c`, beide alle Schritte
`success`, 1410/1410 Tests erreicht, keine echte Fehlzeile. Keine
weitere Geräteverifikation dieses einzelnen Fixes — der Day-Editor-Bug
verhindert eine saubere Live-Demonstration ohnehin, und Code-Fix +
gezielter Regressionstest + grüne Apple-CI entsprechen dem in diesem
Epic durchgängig verwendeten Nachweisstandard für Fixes dieser Größe.

### 11.4 Bestandsmigration (separat geprüft)

**Befund:** Es existiert weder ein echter Alt-Bestand (reale
Produktionsdatenbank eines Nutzers) noch eine im Repository
hinterlegte synthetische Alt-Schema-Fixture. Eine Suche nach
`*.sqlite*`/`*.store`/`*fixture*` im gesamten Repository ergab keinen
Treffer; es gibt kein Skript, das eine solche Fixture erzeugt.

**Korrektur einer bisherigen Annahme (Abschnitt 4):** Dort wurde ein
echter On-Disk-Migrationstest als "gegenstandslos" bzw. "entfällt
ersatzlos" eingestuft, mit der Begründung, eine alte `WorkoutSession`
ohne die neuen Felder lasse sich im aktuellen Binary nicht mehr
instanziieren. Das stimmt nur für In-Process-Konstruktion, beantwortet
aber nicht die eigentliche Praxisfrage: Ein echtes Altgerät hat eine
tatsächliche SQLite-Store-Datei, die von einem ALTEN Build geschrieben
wurde, und die App-Store-Aktualisierung öffnet genau diese Datei mit
dem NEUEN Binary — das ist unabhängig davon, ob der alte Typ im neuen
Binary instanziierbar ist. Dieser Fall ist grundsätzlich testbar, nur
nicht ohne eine echte Alt-Store-Datei. Da keine vorliegt, bleibt er
offen — das wird hier explizit benannt statt stillschweigend als
"bereits erledigt" behandelt.

**Konkrete Voraussetzung:** eine SwiftData-Store-Datei (SQLite +
`-wal`/`-shm`), geschrieben von einem Build VOR der jeweils zu
prüfenden Schema-Erweiterung, mit realistischem Inhalt (aktiver Plan,
mehrere Tage, Übungen — darunter mindestens zwei Vorkommen derselben
Vorlage —, abgeschlossene Sessions mit Logs, mindestens eine noch
offene Session). Zwei sinnvolle Cutoffs, je nach Prüftiefe:
- `155a414` (letzter Commit vor `842028a`, der
  `contentSnapshotJSON`/`contentSnapshotCapturedAt` einführte) — für
  die volle P8-Stufe-2-Snapshot-Funktion.
- jeder Commit vor `b1f7b43` (führte `instanceID` ein) — enger gefasst,
  nur für die in Abschnitt 10 behobene Resume-Isolation.

**Sichere Beschaffungs-/Prüfanweisung (keine Verwendung einer echten
Produktiv-Datenbank, immer nur eine Kopie):**
1. Den gewählten Alt-Commit auf einem Mac/Simulator bauen und
   installieren (z. B. über denselben Codemagic-`ios-app`-Workflow wie
   oben, nur für diesen einen Commit). In der laufenden App über die
   normale UI (oder einen eigenen, dateibasierten statt
   In-Memory-`ModelConfiguration`-Testaufbau) den oben beschriebenen
   realistischen Inhalt anlegen.
2. Die resultierenden Store-Dateien aus dem App-Container
   herauskopieren (z. B. `xcrun simctl get_app_container` auf einem
   echten Mac, oder die entsprechende TestingBot-Dateizugriffsfunktion)
   und eindeutig mit dem Quell-Commit-Hash benennen — NIE das Original
   verändern, immer mit der Kopie weiterarbeiten.
3. Diese Kopie in den App-Container einer FRISCHEN Installation des
   AKTUELLEN Builds (`6ad52fde4ac5864d3de15029` bzw. dessen Nachfolger)
   einsetzen, bevor die App dort zum ersten Mal startet, dann starten.
4. Prüfen: bestehende Pläne/Tage/Übungen/Sessions/Logs bleiben
   vollständig und korrekt verknüpft; neue optionale Felder
   (`instanceID`, `contentSnapshotJSON`, `contentSnapshotCapturedAt` u.
   a.) lesen als `nil`/fehlend, ohne Absturz; keine Historie wird
   rückwirkend erfunden (fehlende Felder bleiben leer/`.notCaptured`,
   werden nicht mit geratenen Werten aufgefüllt); eine noch offene
   Alt-Session lässt sich öffnen und — über den bereits unit-getesteten
   Legacy-Fallback (`exerciseTemplateID`+`orderIndex`,
   `testLegacySnapshotWithoutInstanceIDFallsBackToTemplateAndOrderIndexMatching`)
   — auch tatsächlich fortsetzen.

**Keine Ersatzlösung ohne diese Fixture:** Ein Alt-Backup-Import ist
laut Auftrag kein Ersatz für eine echte Store-Migration (anderer
Codepfad, andere Fehlerklasse). Diese Session hat weder Zugriff auf
echten Nutzer-Altbestand noch die Mittel, auf diesem (SwiftData-losen)
Linux-Unterbau selbst eine Store-Datei zu erzeugen oder zu öffnen — ein
Workaround dafür wurde bewusst NICHT versucht, um keine unbelegte
Verifikation zu behaupten. **Bestandsmigration bleibt damit explizit
offen**, mit der oben genannten einen konkreten Voraussetzung als
nächstem Schritt, falls/wenn eine Fixture beschafft wird.

### 11.5 Gesamturteil Stufe 2

**Status:** Session-Inhaltsvertrag (historische Summary, Snapshot-
Sicherung, Wiederaufnahme-Isolation inkl. Zeitformat/Zirkel und Ad-hoc)
implementiert und gemäß dokumentierten Prüfungen abgenommen. Die
Migration bestehender Datenbanken ist noch nicht bestätigt (siehe
11.4) — das ist eine separate, eigenständig offene Lücke, keine
Einschränkung der obigen Abnahme.

Im Einzelnen, nicht mehr nur codegelesen oder nur unit-getestet,
sondern mit dokumentierten Geräte-/Simulator-Belegen UND grüner
Apple-CI:

- Standardtraining-Wiederaufnahme (Block A) und Zirkel-Wiederaufnahme
  (Block B): auf echtem Simulator bestanden, Build-Identität per SHA256
  nachgewiesen.
- Zeitformat-Routing (Block D): echter Code-Befund, minimal behoben
  (`contentSnapshotTimeFormat`, Commit `07b917b`), Regressionstests +
  Apple-CI grün.
- Ad-hoc-Editor (Block C): echter Gerätebefund (Edit + "+Satz" gingen
  nach Kaltstart verloren), Root Cause lokalisiert, minimal behoben
  (expliziter Save, Commit `e95bf6f`), Regressionstests + Apple-CI grün.

Damit ist die eigene Zwischenbilanz aus dem vorigen Auftrag — "Historische
Summary und Snapshot-Sicherung implementiert und automatisiert geprüft.
Wiederaufnahme-Isolation noch nicht vollständig nachgewiesen." —
vollständig eingelöst: Wiederaufnahme-Isolation ist jetzt sowohl
implementiert als auch mit echten Gerätebelegen nachgewiesen, und zwei
zusätzliche, bei dieser Abnahme erst sichtbar gewordene reale Lücken
(Zeitformat-Routing, Ad-hoc-Persistenz) sind behoben, nicht nur
dokumentiert.

**Was EXPLIZIT noch fehlt — keine Vollabnahme der gesamten App:**

- **Bestandsmigration** (siehe 11.4): keine echte oder synthetische
  Alt-Store-Fixture verfügbar. Konkrete Voraussetzung benannt (Store-
  Datei aus einem Commit vor `842028a`/`b1f7b43`), sichere
  Beschaffungs-/Prüfanweisung gegeben. Bleibt offen, bis eine solche
  Fixture vorliegt — keine Vermutung, keine Ersatzverifikation.
- **Zwei unabhängige Day-Editor-Persistenzbefunde** (Swipe-Delete,
  Tag-Level-Stepper/Picker): echt, reproduziert, aber AUSSERHALB des
  Session-Inhaltsvertrags. Bleiben als eigene, offene Tasks bestehen
  (`task_3edd265e`, `task_0d82cbba`) — nicht Teil dieser Abnahme und
  nicht durch sie abgedeckt.
- **Ad-hoc-Fix `e95bf6f` (Block C) — Geräte-Kaltstartnachtest nach dem
  Fix:** NEIN, nicht durchgeführt. Fix durch Regressionstests
  (`TrainingDayContentSnapshotWriterTests`, drei neue Fälle, siehe 11.2)
  und Apple-CI bestätigt (`ios-app` `6ad5453168658dfa50608121`,
  `swift-package` `6ad5453083b3c37d71581e44`, beide Commit `e95bf6f`,
  1413/1413 Tests); ein erneuter Geräte-Kaltstarttest NACH diesem Fix
  ist noch offen.
- **Zeitformat-Routing-Fix `07b917b` (Block D) — dieselbe Lage:** kein
  Geräte-Kaltstarttest nach dem Fix. Durch Regressionstests
  (`WorkoutSessionContentSnapshotFirstTests`) und Apple-CI bestätigt
  (`ios-app` `6ad5413a95dc34f946a46e40`, `swift-package`
  `6ad54139b1b5e298265ee45c`, beide Commit `07b917b`, 1410/1410 Tests);
  Geräte-Kaltstartnachtest nach Fix ebenfalls noch offen.

**Kosten/Umfang:** ein TestingBot-Account-Check (kostenlos) + zwei
TestingBot-Sessions (~55-60 Min. + ~7 Min., sauber beendet) innerhalb
des bereits verfügbaren Budgets; vier Apple-CI-Läufe insgesamt in
dieser Abnahme (zwei gebündelte Paare, je eines pro notwendiger
Code-Änderung — keine Diagnoseserie); kein Merge nach `main`, kein
Release.
