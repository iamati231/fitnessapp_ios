# P8, Stufe 3 — erster späterer Block-Rückblick: Vorbereitung

Reine Recherche- und Planungsphase. Kein Code geändert, kein Build
getriggert, kein TestingBot verwendet. Grundlage: vorhandene
Audit-Docs, `docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`, aktueller Code.

## 0. Quellenlage (Auftragspunkt 1)

**Stufe 3 ist kein neuer Begriff, sondern explizit zurückgestellt
worden.** Original-Zitat, `docs/NEUE_SPEZIFIKATION_P0_AUDIT.md:1346`:

> "P8 — Spätere Block-Reviews, Stufe 3 — zurückgestellt bis P7 +
> vollständige Stufe-2-Versionierung stehen."

Damit ist die Stufeneinteilung bestätigt: Stufe 1 = P8-Datenvertrag
(Plan-Snapshot bei Session-Start), Stufe 2 = Session-Inhaltsvertrag
(soeben abgeschlossen), **Stufe 3 = der jetzt beauftragte erste
spätere Block-Rückblick.** Beide Vorbedingungen (P7, Stufe 2) sind
jetzt erfüllt.

**Der exakte Übergabepunkt** steht im Code selbst, als "vom Nutzer
ausdrücklich festgelegt" markiert
(`Sources/FitnessAppCore/Analytics/FourWeekReviewDueCalculator.swift:7-19`):

> "Genau EIN Fälligkeitspunkt, der ERSTE Rückblick, `dueIntervalDays`
> (28 Tage, [...] eine festgelegte PRODUKTREGEL, keine wissenschaftliche
> Grenze) nach dem Zeitanker. Kein automatischer wiederkehrender Zyklus
> nach Abschluss — **spätere Block-Reviews bleiben P8**."

Und im `State`-Enum: "Für diesen Zyklus bereits abgeschlossen — kein
erneuter Zyklus in dieser Stufe (P8-Thema), bleibt dauerhaft
`completed`." Das ist die technische Lücke, die Stufe 3 schließt.

### Fehlende Originalvorgaben (explizit benannt, nicht geraten)

- **Die vier Original-Spezifikationsdokumente liegen nicht im Repo** —
  bereits in `docs/NEUE_SPEZIFIKATION_P0_AUDIT.md:1351` als Quellenlücke
  vermerkt: "die vier Original-Spezifikationsdokumente liegen nicht im
  Repo." Nur Zitate/Paraphrasen zweiter Hand sind verfügbar.
- **Blockdauer nach dem ersten Review:** einzige Erwähnung,
  `docs/PLANUNG_BEGLEITUNG_AUDIT.md:101`: "Grundvoraussetzung für den
  4-Wochen- und 6–8-Wochen-Rhythmus aus Dokument 03" — ohne weitere
  Details (ob 6–8 Wochen fix den Folgeblock meint, ob variabel, welche
  Regel dahintersteht). Keine weitere Fundstelle.
- **Dok03 §4** beschreibt den bereits gebauten periodischen
  Kurz-Check-in (`PeriodicCheckIn`, P6.3/#209/#214) — NICHT den
  Block-Review selbst. Nicht verwechseln.
- **Review-Fragen für spätere Blöcke:** keine Quelle über die
  bestehenden `PeriodicCheckIn`-Fragen hinaus.
- **`plateauDetected`-Emitter + Progression-Outcome-Historie:** eine
  frühe P6.3-Beschreibung (`PLANUNG_BEGLEITUNG_AUDIT.md:468-475`)
  erwähnte beides, keine spätere Bestätigung oder Verwerfung auffindbar,
  ob das Teil von Stufe 3 sein soll.
- **Kein eigenständiges P8-Gesamt-Roadmap-Dokument** außer
  `P8_STUFE2_VERSIONIERUNG_PLAN.md` (nur Stufe 2; Abschnitte 7/8 dort
  enthalten nichts zu Stufe 3).

## 1. Datenbasis gegen aktuellen Code geprüft (Auftragspunkt 2)

### Teilnahme (Soll-Ist) — real, aber lebenslaufbezogen, nicht blockbezogen

`PlanParticipationEvaluator` (Core, P6.2) ist zuverlässig und bereits
produktiv. Sein `Input.activatedAt` ist technisch nur ein
"Periodenstart"-Parameter, keine zwingende echte Plan-Aktivierung —
wiederverwendbar für einen Block-Zeitraum, OHNE den Evaluator selbst zu
ändern. Der heutige Aufrufer (`FourWeekReviewAssembler
.participationInput`) reicht aber hart `plan.activatedAt` durch —
misst also IMMER seit Plan-Aktivierung, nie "seit diesem Block". Für
Stufe 3 muss der Aufrufer einen anderen Anker übergeben können, nicht
der Evaluator neu gebaut werden.

Bereits dokumentierte, unveränderte Grenze: `DataGap
.planStructureChangesDuringPeriodNotTracked` — Planänderungen WÄHREND
der Beobachtungsperiode werden nicht erkannt. Gilt für jeden Block
gleichermaßen, durch Stufe 3 weder verschlechtert noch verbessert.

### Absolvierte Trainings — real vorhanden, zwei unabhängige Quellen

Pro abgeschlossener Session liegt der TATSÄCHLICH geloggte Inhalt
(`ExerciseLog`) dauerhaft vor — unabhängig vom P8-Content-Snapshot, der
nur einfriert, WAS BEI SESSION-START geplant war. Zusätzlich real und
nicht snapshot-basiert: `VolumeOverTimeAggregator` (wochenweises
Strength-Volumen direkt aus Logs) und `PersonalRecordEntry` (dauerhafte
PR-Historie). Beide sind heute NICHT in den Review-Orchestrator
verdrahtet — bewusst als vorhandenes, aber ungenutztes Material
vermerkt, nicht als Paket vorgeschlagen (siehe Abschnitt 5).

### Nutzerfeedback — real, aber nicht block-gescoped

`PeriodicCheckIn` speichert echte Antworten (Häufigkeit/Dauer/
Beschwerden/Ziel/Belastung). Der heutige Abruf
(`FourWeekReviewAssembler.latestCheckInFeedback`) holt immer den
GLOBAL letzten Eintrag — kein Zeitfenster-, kein Plan-Bezug. Für Block
2 ungeklärt: zählt ein Check-in aus Block 1 noch, oder nur einer SEIT
Block-2-Start? (siehe Entscheidung 4, Abschnitt 4).

### Historische Inhalte / Progressions- oder Plateau-Historie — NICHT vorhanden

**Wichtigste Einschränkung, wie vom Auftrag verlangt nicht mit
Snapshots verwechselt:** Content-Snapshots (P8 Stufe 1/2) belegen
AUSSCHLIESSLICH, was bei Session-Start geplant war. Sie sind kein
Nachweis für eine gespeicherte Progressions- oder Plateau-Historie —
eine solche existiert im Code schlicht nicht:

- `plateauDetected` (`Sources/FitnessAppCore/Coaching/CoachingTypes.swift:198`)
  hat bis heute **keinen einzigen Emitter** — nur Lokalisierungstext.
- `ProgressionApplicator` verwirft `.hold`-Ausgänge explizit (drei
  Code-Stellen, `if case .hold = action { continue }`), statt sie zu
  speichern.

Eine Aussage wie "diese Übung stagniert seit X Wochen" ist mit dem
heutigen Datenmodell **nicht zuverlässig möglich** — das wäre eine neue
Persistenzanforderung (Schreibpfad für Progressions-Ausgänge über
Zeit), kein Lesezugriff auf Bestehendes, und damit außerhalb eines
minimalen Stufe-3-Umfangs (siehe Entscheidung 6).

## 2. Vorschlag: minimaler vollständiger Block-Review (Auftragspunkt 3)

Alle sechs geforderten Eigenschaften lassen sich durch Wiederverwendung
erfüllen, ohne neue Engine:

- **Planbezogener Beobachtungszeitraum:** [Zeitanker Block N,
  Auswertungsdatum]. Block 1 unverändert `activatedAt`. Block 2+:
  Vorschlag als Standardannahme (siehe Entscheidung 2) —
  `reviewCompletedAt` des vorigen Zyklus, weil das ohne neues Datenfeld
  auskommt und am engsten am Begriff "Review GENAU dieses Blocks"
  bleibt, nicht der gesamten Plan-Historie.
- **Nachvollziehbare Auswertung:** identischer
  `FourWeekReviewOrchestrator`-Vertrag wie Stufe 1 — `.keepAsIs`
  vollwertig, `concernsFound` priorisiert, `dataGaps` immer
  mitgeliefert, keine Konflikt-Logik-Änderung nötig (F08 bleibt
  gültig).
- **Sichtbare Datenlücken:** bestehende `DataGap`-Fälle bleiben gültig;
  genau ein möglicher neuer Fall, falls Entscheidung 4
  (Check-in-Scoping) das verlangt ("kein Check-in seit Block-Start",
  abgrenzbar von "noch nie ein Check-in").
- **Bestehende Advisors wiederverwenden:** `DeloadAdvisor`/
  `ComebackAdvisor` bleiben wie bisher GLOBAL (personen-, nicht
  blockbezogen) — laut Audit eine eigenständige, bereits getroffene
  Produktentscheidung ("Erschöpfung/CNS-Last ist personen-, nicht
  planbezogen"), keine Lücke, keine Änderung nötig.
- **Beibehalten als vollwertiges Ergebnis:** `.keepAsIs` ist bereits
  exakt so implementiert — unverändert übernehmbar.
- **Änderungen nur nach separater Bestätigung:** der Orchestrator hat
  bewusst KEINE `apply`-Methode — dieses Muster bleibt für Stufe 3
  identisch.

## 3. Betroffene Schreib-/Lesepfade (grob — Pakete in Abschnitt 5 konkretisieren)

- `TrainingPlan.reviewCompletedAt`/`.reviewDecisionRaw`: heutige
  Semantik ist "einmalig, für immer". Für einen wiederkehrenden Zyklus
  muss geklärt werden, ob diese Felder bei Block 2 einfach überschrieben
  werden (Block-1-Entscheidung geht verloren) oder eine Mini-Historie
  ergänzt wird (siehe Entscheidung 3).
- `FourWeekReviewDueCalculator.State` / `.state(...)`: `.completed` darf
  nicht mehr terminal sein — muss nach `dueIntervalDays` (oder einem
  anderen, zu entscheidenden Intervall) wieder `due` werden können.
- `FourWeekReviewAssembler.participationInput`: braucht einen
  Periodenstart-Parameter statt des hart codierten `plan.activatedAt`.
- `FourWeekReviewOrchestrator`/`Review`: optionale Erweiterung um eine
  Block-Kennzeichnung (z. B. "zweiter Block"), falls die UI das anzeigen
  soll — reine Zusatzinformation, kein Eingriff in die bestehende
  Konfliktlogik.

## 4. Ausdrücklich offene Produktentscheidungen (Auftragspunkt 4 — keine Fristen/Schwellen erfunden)

1. **Blockdauer Folgeblock:** wieder 28 Tage (`dueIntervalDays`
   unverändert) oder die erwähnten "6–8 Wochen" aus Dokument 03 — und
   falls Letzteres: welcher genaue Wert, oder ein Bereich mit eigener
   Regel? Keine Annahme getroffen, nur die einzige vorhandene
   Quellenangabe benannt.
2. **Zeitanker Folgeblock:** `reviewCompletedAt` des vorigen Zyklus
   (mein Vorschlag in Abschnitt 2, weil ohne neues Feld umsetzbar) ODER
   ein eigener, separat gesetzter "Block-Start"-Zeitpunkt (z. B. durch
   eine ausdrückliche Nutzeraktion "neuen Block beginnen", getrennt vom
   Review-Abschluss selbst)? Beeinflusst, ob ein abgeschlossener
   Rückblick automatisch den nächsten Block eröffnet oder das ein
   eigener, bewusster Schritt bleibt.
3. **Block-1-Historie behalten oder nicht:** reicht "nur der aktuelle/
   letzte Block" für diese Stufe (bestehende Felder einfach
   weiterverwenden, Block-1-Ergebnis geht beim Abschluss von Block 2
   verloren), oder soll die Entscheidung/der Zeitpunkt von Block 1
   sichtbar erhalten bleiben (kleines zusätzliches Verlaufsfeld nötig)?
4. **Check-in-Scoping:** zählt für Block 2 nur ein Check-in SEIT
   Block-2-Start, oder bleibt "letzter Check-in überhaupt" (heutiges
   Verhalten, auch über Blockgrenzen hinweg) ausreichend?
5. **Review-Fragen für den späteren Block:** bleiben es dieselben vier/
   fünf `PeriodicCheckIn`-Fragen, oder sollen spätere Blöcke
   zusätzliche/andere Fragen bekommen (z. B. zur bereits getroffenen
   Block-1-Entscheidung: "hat die Umstellung geholfen?")? Keine Quelle
   dazu auffindbar.
6. **`plateauDetected`/Progression-Outcome-Historie:** ausdrücklich Teil
   von Stufe 3, oder bewusst zurückgestellt? Das wäre laut Abschnitt 1
   NEUE Persistenz-Infrastruktur (ein Schreibpfad für Progressions-
   Ausgänge über Zeit), kein Wiederverwenden von Bestehendem — eine
   andere Größenordnung als die übrigen Pakete.

## 5. Vorgeschlagene Implementierungspakete (Auftragspunkt 5 — nach obigen Entscheidungen final zuschneidbar)

Kein neues Planungs-/Empfehlungs-Engine, keine allgemeine
Architektur-Neugestaltung — jedes Paket erweitert eine bereits
bestehende, reine Funktion additiv.

**Paket A — Wiederkehrender Fälligkeits-/Abschluss-Zyklus (Core).**
`FourWeekReviewDueCalculator` generalisieren: `.completed` liefert
einen Folge-Fälligkeitspunkt statt terminal zu bleiben (Parameter nach
Entscheidung 1/2). Abnahmekriterium: reiner Core-Test (kein
`Date()`/`Calendar.current` im Pfad, Linux-testbar) zeigt
`completed(Block 1)` → `notYetDue(Block 2)` → `due(Block 2)` korrekt.

**Paket B — Block-bezogener Soll-Ist-Zeitraum.**
`FourWeekReviewAssembler.participationInput`/`assemble` bekommt einen
Periodenstart-Parameter statt hartem `plan.activatedAt`. Abnahme-
kriterium: Apple-CI-Test zeigt, Block-2-Teilnahme zählt nur
Gelegenheiten seit dem Block-2-Anker, nicht seit Plan-Aktivierung.

**Paket C — Persistenz der Block-Historie** (Umfang hängt direkt von
Entscheidung 3 ab): entweder Wiederverwendung bestehender Felder (kein
Schema-Change) oder additive neue Felder für eine Mini-Historie.
Abnahmekriterium abhängig von gewählter Option — wird nach der
Entscheidung konkretisiert.

**Paket D — UI/Text-Anpassung** (`FourWeekReviewView` o. ä.): Block-
Kennzeichnung in der Anzeige (z. B. "Dein zweiter Block" statt fix
"deine ersten vier Wochen"), neuer DataGap-Text falls Entscheidung 4
das verlangt. Abnahmekriterium: DE/EN/TR lokalisiert, Apple-CI grün.

**Paket E — Regressionstests + Doku + ein gebündelter Apple-CI-Lauf**,
nach demselben Vorgehen wie in diesem gesamten Epos etabliert.

**Explizit NICHT Teil dieser Pakete:** kein Plateau-Detektor, keine
neue Progressions-Engine (Entscheidung 6 klärt erst, ob das überhaupt
gewollt ist), keine Day-Editor-Änderungen, keine Verdrahtung von
`VolumeOverTimeAggregator`/PR-Historie in den Orchestrator (vorhanden,
aber ungefragt — kein Teil dieses Vorschlags).

## 6. Die zwei bekannten Day-Editor-Persistenzbugs — Einordnung

Beide Befunde (Swipe-Delete persistiert nicht, Tag-Level-Stepper/Picker
persistieren nicht — `task_3edd265e`, `task_0d82cbba`) betreffen das
BEARBEITEN einer Tagesstruktur über `DayEditorView`. Stufe 3 LIEST nur
bereits bestehende Plan-/Session-/Feedbackdaten (`nonRestDayCount`,
`activatedAt`, Logs, Check-ins) und bietet selbst **keine eigene
Bearbeitungsoberfläche** für Tage — keines der Pakete A–E oben berührt
`DayEditorView`.

Einzige indirekte Berührung: `PlanParticipationEvaluator`s bereits
dokumentierte Grenze "Planänderungen während der Periode nicht
erkannt" bleibt unverändert bestehen, unabhängig davon, ob die beiden
Bugs behoben sind — der Evaluator liest ohnehin nur den AKTUELLEN Stand
von `plan.days`, nie eine Historie. Ob eine Tagesänderung durch den Bug
verloren geht oder nie vorgenommen wurde, macht für die Auswertung
keinen Unterschied.

**Einordnung:** Beide Bugs beeinträchtigen den vorgesehenen P8-Ablauf
NICHT unmittelbar. Kein begrenzter Vorlauf nötig — sie bleiben
eigenständige, separate Tasks.

## 7. Zusammenfassung für den Auftraggeber

Ein umsetzbarer Vorschlag liegt vor (Abschnitte 2, 3, 5). Er braucht
vor der Umsetzung Antworten auf genau 6 Fragen (Abschnitt 4) — keine
davon wurde von mir vorentschieden oder mit einer erfundenen Frist/
einem erfundenen Schwellenwert gefüllt.
