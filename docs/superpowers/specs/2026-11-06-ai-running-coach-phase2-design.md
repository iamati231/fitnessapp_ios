# AI Running Coach – Phase 2: Trainingsbelastung, Regeneration und Belastungssteuerung

Design-Dokument zum Ticket "Phase 2 – Trainingsbelastung, Regeneration und
Belastungssteuerung". Baut auf Phase 1 auf (`CardioVolumeOverTimeAggregator`,
`CardioHistoryExtractor`, `RaceProgressAssessment`, `RaceProgressCardModel`,
`HeartRateZoneCalculator`, `HeartRateZoneContextBuilder`,
`UserBodyProfile.maxHeartRateBpm`/`cardioCoachingEnabledAt`).

## 0. Audit-Ergebnis (Teil A)

Vor jeder Designentscheidung: was ist tatsächlich schon da.

### 0.1 Lauftraining

Unverändert gegenüber Phase 1 — vollständig vorhanden und bereits korrekt
verdrahtet:

* `ExerciseLog.distanceKm`/`durationSeconds`, snapshot-first über
  `resolvedEnduranceSportKind` (Migrations-Fix aus dem Dashboard-Ticket
  bereits angewendet).
* `CardioHistoryExtractor.loggedSessions(from:)` klassifiziert
  `isRunning`/`isCrossTrainingOnly`/`hasAmbiguousCardio`/`hasStrengthActivity`
  pro Session.
* `CardioVolumeOverTimeAggregator.aggregate(...)` liefert lückenlose
  Wochen-Buckets (`CardioVolumeOverTimePoint`: Laufkilometer, Laufanzahl,
  längster Lauf, Pace, `averageHeartRateBpm` — Phase 1 immer `nil`, da keine
  Messquelle existiert).
* `cardioCoachingEnabledAt` begrenzt NUR Beobachtungsmerkmale
  (`RaceProgressAssessment.WeeklyFlag.beforeCoachingObservationPeriod`),
  niemals die historische Datenbasis selbst.
* Herzfrequenzzonen: `HeartRateZoneCalculator`/`HeartRateZoneContextBuilder`
  — deterministisch, kein Messwert vorhanden, HFmax ist rein manuell.

**Nichts hier wird in Phase 2 neu gebaut.** Phase 2 konsumiert
`CardioVolumeOverTimePoint` als fertige Lauf-Zeitreihe.

### 0.2 Krafttraining — bereits deutlich mehr vorhanden als das Ticket vermuten lässt

* `ExerciseLog` trägt `weight`, `reps`, `rpe: Double`, `rir: Float` als feste
  Felder. `rir` ist das einzige davon, das durchgängig im Workout-Flow
  erfasst wird (Pflichtfeld im Init, kein Optional); `rpe` liegt als `Double`
  mit Default `0.0` vor, wird aber — soweit im Audit sichtbar — nicht an
  einer prominenten Logging-UI-Stelle regelmäßig vom Nutzer gepflegt wie
  `rir`. **Ruling:** Phase 2 behandelt `rpe` NICHT als zuverlässig vorhanden
  (siehe Teil A-Vorgabe "keine RPE-Werte erfinden" — ein nie wirklich
  gepflegtes Default-`0.0` als "RPE 0" in eine Intensitätsaussage zu
  übernehmen wäre genau das). `rir` dagegen ist ein zuverlässiges Signal und
  fließt (wie in Phase 1 bereits über `cnsFatigueScore`/
  `localMuscleDamageScore`) ein.
* **`WorkoutSession.sessionFeeling: Int?`** (DEL-057-Skala, 1–5, "Sehr
  leicht" … "Zerstört") ist die EINZIGE echte subjektive Belastungsangabe im
  Datenmodell — pro Session, optional, vom Nutzer beim Beenden des Workouts
  gesetzt (`ActiveWorkoutView.swift`). Das deckt Teil A's "vorhandene
  subjektive Belastungsangaben, falls vorhanden" bereits ab — **kein neues
  Feld nötig.**
* **`SessionAggregator`** (DeltiqCore, reine Funktion) berechnet
  `totalSets`/`totalVolumeKg` bereits korrekt: Bodyweight-Sätze
  (`weightKg == 0`) zählen als Satz, tragen aber 0 zum Volumen bei (keine
  erfundene Gewichtsannahme — exakt die Ticket-Vorgabe 4.2 ist bereits
  erfüllt). Negative Werte werden auf 0 geklemmt, zählen aber als Satz.
  `WorkoutSession.recomputeTotals()` ist der einzige Schreibpfad dafür.
* **`VolumeOverTimeAggregator`** (DeltiqCore) aggregiert Kraft-Volumen
  (Gewicht × Reps, Cardio/TimeBased ausgeschlossen) bereits wochenweise,
  lückenlos, lokalesensitiv — grundsätzlich dieselbe Kennzahl, die Teil
  B/4.2 verlangt. **Korrektur nach Architekturprüfung (siehe unten):**
  Phase 2 erweitert diesen Aggregator NICHT. Er operiert auf rohen
  Einzel-Logs über das gesamte Zeitfenster hinweg (keine Session-Gruppierung)
  und liefert keine Satzanzahl — für das Session-granulare
  `TrainingActivity`-Modell (ein Eintrag pro Session, siehe Abschnitt 1)
  wird stattdessen **`SessionAggregator.totals`** (dieselbe kanonische
  Formel, die auch `WorkoutSession.recomputeTotals()` nutzt) auf den
  Kraft-Anteil JEDER Session einzeln angewendet. `VolumeOverTimeAggregator`
  bleibt unverändert für seinen bestehenden Zweck (Dashboard-Chart) im
  Einsatz; Phase 2 dupliziert weder seine Formel noch seine
  Wochen-Bucketing-Logik, nutzt aber ein anderes, genauer passendes
  Bestandsbauteil.
* **`DeloadAdvisor.strengthCNSLoad`** filtert Cardio bereits aus der
  CNS-Last heraus (`isCardio` als einziges Ausschlusskriterium,
  TimeBased-Übungen zählen als Kraftarbeit mit) — das ist bereits die
  "Krafttraining als eigenständiger Belastungsbereich"-Trennung aus Teil B.
* **Kettlebell/Bodyweight:** nicht über `TrainingTypeKind` (das trägt
  `.barbell`/`.dumbbell`/`.kettlebell`/`.machine`/`.bodyweight`/`.running`/
  `.cycling` als EIN gemeinsames Enum für Plan-Generator-Input, nicht direkt
  als Ausrüstungs-Tag am `Exercise`), sondern über `Exercise.equipment:
  Equipment?` (separates Enum, siehe `ExerciseLibraryData.swift`).
  Kettlebell-/Bodyweight-Übungen sind damit bereits eindeutig markiert —
  Phase 2 muss nichts Neues einführen, nur `exercise.equipment` beim
  Aufbau der vereinheitlichten Trainingshistorie mitführen (rein
  informativ, fließt NICHT in eine erfundene Belastungszahl ein).
* **`containsStrengthWork`** (`WorkoutSession`-Extension in
  `SessionAggregation.swift`) ist bereits exakt die Session-Klassifikation,
  die Teil F/7.1 braucht ("ausschließlich Krafttraining" vs. Lauf).

**Fazit Krafttraining:** Phase 2 braucht **kein einziges neues
SwiftData-Feld**. Alles Nötige (Volumen, Satzanzahl, subjektives Gefühl,
CNS-Last, Equipment-Klassifikation) existiert bereits und ist bereits
korrekt gegen erfundene Werte abgesichert.

### 0.3 Andere Ausdaueraktivitäten

`TrainingTypeKind` kennt für Ausdauer ausschließlich `.running`/`.cycling`
(bestätigt — kein `.swimming`/`.rowing`/etc.). Das Ticket verlangt
"weitere bekannte Ausdaueraktivitäten" nur dort zu berücksichtigen, "soweit
bekannt" — da keine dritte Sportart im Datenmodell existiert, bleibt die
bestehende Dreiteilung `isRunning` / `isCrossTrainingOnly` (= Radfahren) /
`hasAmbiguousCardio` (= unbekannt) unverändert die vollständige
Klassifikation. **Kein neues Feld, keine neue Sportart erfunden.**

### 0.4 Deload-/Comeback-Logik (nicht duplizieren, Teil G)

Drei bestehende, zusammenspielende Komponenten:

1. **`DeloadAdvisor.shouldRecommendDeload(weeklyLoads:hardSessionCount:)`** —
   reine Funktion: ≥3 Wochen streng steigende `strengthCNSLoad`-Summe
   (≥20 % von Woche 1 zu Woche 3) UND ≥2 Sessions mit `sessionFeeling >= 4`
   in 14 Tagen. Liefert `Bool`, keine Anwendung.
2. **`DeloadManager`** (DeltiqData, `@MainActor`) — der tatsächliche
   Schreibpfad: halbiert `Exercise.suggestedWeight` im aktiven Plan,
   sichert Originale, idempotent. Nur per explizitem Nutzer-Tap.
3. **`AbsenceDeload`** — separater Pfad für Rückkehr nach Trainingspause
   (`ComebackAdvisor`), unabhängiger Reduktionsmechanismus ohne Timer/
   Snapshot.
4. **`FourWeekReviewOrchestrator`** — kombiniert `DeloadAdvisor`-Ergebnis,
   `ComebackSignal` und Teilnahme-/Check-in-Daten zu EINER
   widerspruchsfreien `Concern`-Liste (Deload und Comeback schließen sich
   gegenseitig aus, Comeback gewinnt bei Konflikt). Ist bereits das exakte
   Vorbild für den Teil-H-Bewertungstyp dieses Tickets (Concern/DataGap/
   Outcome, KEINE `apply`-Methode, pure function).

**Ruling:** Phase 2 ruft `DeloadAdvisor.shouldRecommendDeload` als
FERTIGES Signal ab (wie `FourWeekReviewOrchestrator` es mit
`deloadRecommended: Bool` bereits tut) und reicht es unverändert in die
neue `TrainingLoadAssessment` durch. Phase 2 berechnet NIE selbst, ob ein
Deload fällig ist — das bleibt `DeloadAdvisor`s alleinige Zuständigkeit.
Phase 2 ruft auch nie `DeloadManager`/`AbsenceDeload` selbst auf (keine
automatische Anwendung, Ticket-Vorgabe).

### 0.5 Dashboard-Widget-Architektur

Unverändert seit dem Dashboard-Fix-Ticket: `DashboardWidgetType` (Enum,
`CaseIterable`, `localizationKey`, `defaultOrder`), neue Cases werden ans
Ende angehängt, Aktivierung von Cardio-Coaching schiebt
`[.runCoachCard, .raceProgressCard]` an Position 0
(`UserBodyProfile.setEnduranceModality`/Init). `.trainingLoadCard` folgt
demselben Muster, braucht aber eine EIGENE Aktivierungsbedingung (siehe
0.6) statt an `cardioCoachingEnabled` zu hängen.

### 0.6 Aktivierungs-Gating — Ruling

`cardioCoachingEnabled`/`cardioCoachingEnabledAt` sind explizit
lauf-/wettkampf-bezogen (Name, Doku, `CardioGoal`-Kopplung). Die
Phase-2-Frage "ist meine Trainingsbelastung sinnvoll" ist aber explizit
für Kraft- UND Ausdauertraining gemeinsam gedacht (Teil F) und gilt auch
für jemanden, der nie Cardio-Coaching aktiviert hat (reiner
Kraft-Trainierender). Das Ticket selbst verlangt NICHT, die Karte hinter
`cardioCoachingEnabled` zu verstecken.

**Ruling:** `.trainingLoadCard` bekommt KEINE Abhängigkeit von
`cardioCoachingEnabled`. Sie erscheint wie jedes andere Widget im
`defaultOrder` (ans Ende angehängt, kein automatisches Nach-oben-Schieben)
und wird unabhängig ein-/ausgeschaltet. Es wird **kein neues
"strengthCoachingEnabled"-Flag** eingeführt — das Ticket verlangt
ausdrücklich keine neuen Opt-in-Schalter, nur eine neue, unabhängig
konfigurierbare Karte. Ein Nutzer ohne jegliche Trainingshistorie sieht
schlicht `insufficientData`.

### 0.7 TrainingPlan/TrainingDay — Plan-Tagestyp bekannt, aber Teil F/G nutzen ihn nicht direkt

`TrainingDay.type` (siehe `PlanGenerator`/`DaySpec`) kodiert bereits, ob ein
Plantag ein Ruhetag ist. Für Phase 2 ist das aber NICHT die maßgebliche
Quelle: die ticket-geforderte "Dichte anspruchsvoller Einheiten" bewertet
TATSÄCHLICH ABSOLVIERTE Sessions (`WorkoutSession`), nicht den Plan-Soll-
Zustand — ein Plan-Ruhetag, an dem der Nutzer trotzdem trainiert hat, zählt
für die Belastungsrechnung, nicht der Plan. **Ruling:** Phase 2 liest
`TrainingDay`/`TrainingPlan` NICHT. Die Belastungsrechnung basiert
ausschließlich auf geloggten `WorkoutSession`s — konsistent mit
`CardioHistoryExtractor`s Prinzip ("reale Historie, nicht Plan-Soll").

## Architekturprüfung der offenen Punkte (vor Work Package 2A)

Angefordert vor Beginn der Implementierung. Ergebnis: Dokumente waren an
drei Stellen unpräzise/widersprüchlich gegenüber dem tatsächlichen
Datenmodell — korrigiert, siehe Abschnitte 1/2 oben/unten. Diese Prüfung
selbst betrifft ausschließlich 2A/2C-Design, keine Implementierung über
2A hinaus.

### Architekturprüfung Teil 1 — Widerspruch bei SwiftData-Feldern

Das Audit ("No new SwiftData fields needed") bezog sich ausschließlich
auf TRAININGSDATEN (Lauf/Kraft/Ausdauer) — dort stimmt die Aussage
weiterhin uneingeschränkt. Die drei in Abschnitt 8 (Work Package 2C)
geplanten `UserBodyProfile`-Felder sind eine ANDERE Kategorie: reiner
Interaktions-/Anzeigezustand, kein Trainingsdatum, nicht aus
Workout-Historie ableitbar. Jedes einzeln geprüft:

**`trainingLoadLastAnalyzedAt: Date?`**
1. Löst: "wurde dem Nutzer diese Bewertung schon gezeigt, und wann?" —
   Grundlage für `TrainingLoadDueCalculator`s `.periodicIntervalElapsed`.
2. Bestehende Daten reichen nicht: das ist ein UI-Interaktions-Zeitpunkt,
   kein Trainingswert — es gibt in `WorkoutSession`/`ExerciseLog` nichts,
   woraus sich "wann hat der Nutzer die Karte zuletzt gesehen" ableiten
   ließe.
3. Weder Konfiguration noch berechenbarer Zustand — es ist
   Interaktions-HISTORIE, die nirgendwo sonst existiert.
4. Muss dauerhaft gespeichert werden: ja, muss einen App-Neustart
   überleben (identisches, bereits akzeptiertes Muster:
   `raceProgressLastAnalyzedAt`, Phase 1).
5. Migration: additiv, `nil`-Default, keine Auswirkung auf Bestandsnutzer
   (identisch zu allen bisherigen Phase-1-Feldern dieser Art).
   **Ergebnis: BEIBEHALTEN.**

**`trainingLoadLastAnalyzedConfigurationFingerprint: String?`**
1. Löst: erkennt, ob sich seit der letzten Analyse etwas geändert hat, das
   eine erneute Anzeige rechtfertigt, OHNE bei jeder neuen Session sofort
   erneut zu triggern (das übernimmt bereits `.newActivitySinceLastAnalysis`).
2. **Korrektur:** der ursprüngliche Entwurf kopierte Phase 1s
   Fingerprint-Zweck (Ziel/Renndatum) unreflektiert — Phase 2 hat aber
   KEIN Ziel/Renndatum (Testfall 32 fordert explizit Unabhängigkeit davon).
   Der tatsächliche Zweck hier ist ein ANDERER: `maxHeartRateBpm`-Änderungen
   beeinflussen `HeartRateZoneContextBuilder`s Ergebnis (Abschnitt 4) und
   sollten die Karte erneut als "zu prüfen" markieren, auch ohne neue
   Trainingsdaten. Fingerprint = Hash über `maxHeartRateBpm` (einziger
   Phase-2-relevanter, nutzergesteuerter Konfigurationswert).
3. Nutzerspezifische Konfiguration (mittelbar, über `maxHeartRateBpm`) —
   kein berechenbarer Trainingswert.
4. Muss gespeichert werden: ja, aus demselben Grund wie oben.
5. Migration: additiv, `nil`-Default, keine Auswirkung.
   **Ergebnis: BEIBEHALTEN, Zweck präzisiert (s.o.) — ohne diese
   Korrektur wäre das Feld tatsächlich ein unbegründetes "einfach
   kopiertes" Feld gewesen, genau wovor die Entscheidungskriterien warnen.**

**`trainingLoadDismissedFingerprint: String?`**
1. Löst: "Nicht jetzt" darf nicht bei jedem App-Start erneut nerven,
   solange sich das zugrunde liegende Ergebnis nicht ändert.
2. Bestehende Daten reichen nicht: identisch zu Punkt 1 oben — reiner
   Interaktionszustand.
3. Weder Konfiguration noch berechenbarer Trainingswert — Interaktions-Historie.
4. Muss gespeichert werden: ja (identisches, bereits akzeptiertes Muster:
   `raceProgressDismissedFingerprint`).
5. Migration: additiv, `nil`-Default, keine Auswirkung.
   **Ergebnis: BEIBEHALTEN.**

**Gesamtergebnis Teil 1:** Keine der drei Feld ist redundant oder aus
Workout-Daten ableitbar. Alle drei gehören zu Work Package 2C (NICHT 2A) —
2A legt keine neuen `UserBodyProfile`-Felder an und fasst `UserBodyProfile`
überhaupt nicht an.

### Architekturprüfung Teil 2 — Datenfluss ExerciseLog/WorkoutSession

Vollständiger Fluss für Work Package 2A:

```
WorkoutSession (isRealWorkout-gefiltert)
  │
  ├─► CardioHistoryExtractor.loggedSessions(from:)   [Phase 1, UNVERAENDERT]
  │     → CardioVolumeOverTimeAggregator.LoggedSession pro Session
  │       (isRunning/isCrossTrainingOnly/hasAmbiguousCardio/hasStrengthActivity)
  │
  └─► session.loggedSets.filter { !$0.resolvedIsCardio }
        → SessionAggregator.LoggedSet(weightKg:, reps:)
          → SessionAggregator.totals(for:)            [Bestandsformel, UNVERAENDERT]
            → (setCount, volumeKg) NUR fuer den Kraft-Anteil dieser Session

  beide Ergebnisse (gleiche Session, gleicher Index) → TrainingActivity
    → TrainingLoadAggregator.aggregate(...) → [TrainingLoadWeek]
```

Antworten auf die gestellten Prüffragen:

* **Eindeutige Zuordnung:** ja — `TrainingActivityExtractor` iteriert
  `sessions.filter(\.isRealWorkout)` EINMAL und erzeugt `CardioHistoryExtractor`-
  Resultate über dieselbe gefilterte Liste (identischer interner Filter,
  identische Reihenfolge) — per-Index-Zip ist sicher, keine
  Log-zu-Session-Mehrdeutigkeit möglich.
* **Keine Doppelzählung:** `session.totalVolumeKg`/`totalSets` (vom
  bestehenden `recomputeTotals()`-Pfad gepflegt) werden vom Extractor
  NICHT gelesen — er berechnet seinen Kraft-Wert unabhängig direkt aus
  den gefilterten Logs. **Wichtiger Fund:** `session.totalSets` selbst
  wäre für Phase 2 ungeeignet gewesen, auch OHNE Doppelzählungsrisiko —
  es zählt Cardio-"Sätze" (ein Lauf-Log ist nach DEL-223-Konvention
  ebenfalls ein "Satz") in dieselbe Zahl wie Kraft-Sätze hinein. Eine
  reine Laufwoche hätte darüber fälschlich `totalSets > 0` als
  Krafttrainings-Signal ausgesehen. `session.totalVolumeKg` wäre dagegen
  zufällig korrekt gewesen (Cardio-Logs haben immer `weight == 0`, tragen
  arithmetisch nie zum Volumen bei) — aber sich auf diesen Zufall zu
  verlassen wäre fragil. Deshalb: eigene, auf den Kraft-Anteil gefilterte
  Berechnung statt (teilweise zufällig richtiger) Wiederverwendung der
  Session-Aggregate.
* **Mehrere Logs derselben Übung:** `SessionAggregator.totals` summiert
  über ALLE übergebenen Sätze unabhängig von der Übungsidentität — zwei
  Sätze Kniebeuge zählen korrekt als zwei Einträge in `strengthSetCount`
  und addieren sich im Volumen.
* **Gelöschte/geänderte Exercises:** `resolvedIsCardio` (snapshot-first,
  siehe `ExerciseLog`-Doku) entscheidet den Kraft/Cardio-Filter — überlebt
  Exercise-Löschung unverändert (Phase-1-Fix bereits angewendet).
  `resolvedEnduranceSportKind` ebenso für die Cardio-Seite.
* **Snapshot-Werte:** `exerciseIsCardioSnapshot`/
  `exerciseEnduranceSportKindSnapshot` (beide seit den Dashboard-Fixes
  korrekt snapshot-first mit Live-Fallback) sind die einzigen zuverlässig
  verfügbaren historischen Werte; `weight`/`reps` selbst sind nie
  Snapshots (sie SIND der Log, nicht abgeleitet).
* **Bodyweight:** `weight == 0` bei `reps > 0` zählt als Satz
  (`SessionAggregator.isPlaceholder`), trägt 0 zum Volumen bei — keine
  erfundene Gewichtsannahme.
* **Kettlebell/Equipment-Übungen:** `Exercise.equipment` beeinflusst die
  Aggregation nicht (bewusst — Equipment ist Darstellungs-Metadatum, keine
  Belastungs-Dimension); Kettlebell-Sätze werden identisch zu jedem
  anderen Gewichts-Satz behandelt.
* **`rir`/`sessionFeeling`/`totalSets`/`totalVolumeKg`:** `rir` ist nur
  auf Kraft-Logs bedeutungsvoll (bei Cardio/Zeitbasiert fest auf `0`
  hartkodiert, siehe `SetRow.swift` — niemals als "RIR 0 = Maximalanstrengung"
  fehlinterpretierbar, da 2A `rir` ohnehin gar nicht liest).
  `sessionFeeling` bleibt für 2C reserviert (s.o.). `totalSets`/
  `totalVolumeKg` werden von 2A, wie oben begründet, bewusst NICHT
  gelesen.
* **`rpe` vollständig ausgeschlossen:** ja — `TrainingActivity` hat kein
  `rpe`-Feld, 2A liest `ExerciseLog.rpe` nirgends.
* **Fehlende Werte = unbekannt, nicht 0:** `runningDistanceKm`/
  `runningDurationSeconds` bleiben `nil`, wenn nicht bekannt (ererbt von
  Phase 1). Krafttrainings-Zahlen kennen diese Unterscheidung nicht
  separat, weil sie es nicht brauchen: `strengthSetCount == 0` bedeutet
  eindeutig "keine Kraft-Logs in dieser Session", niemals "unbekannt" (die
  Satzliste selbst ist immer vollständig bekannt, sobald die Session
  geladen ist — anders als bei Cardio-Distanz, die auch bei bekannter
  Session fehlen kann).

### Architekturprüfung Teil 3 — Acute:Chronic Workload Ratio

Siehe Abschnitt 3 unten (im Fluss der ursprünglichen Gliederung belassen,
da dort bereits der fachliche Kontext steht).

## 1. Vereinheitlichtes Aktivitätsmodell (Teil B/4.4)

Reiner Werttyp, DeltiqCore, keine SwiftData-Abhängigkeit:

```swift
public struct TrainingActivity: Sendable, Equatable {
    public let date: Date

    // Cardio - identische Feldnamen/Semantik wie
    // CardioVolumeOverTimeAggregator.LoggedSession (Phase 1, unveraendert).
    public let runningDistanceKm: Double?
    public let runningDurationSeconds: Int?
    public let isRunning: Bool
    public let isCrossTrainingOnly: Bool
    public let hasAmbiguousCardio: Bool

    // Kraft (neu in Phase 2).
    public let hasStrengthActivity: Bool
    public let strengthSetCount: Int
    public let strengthVolumeKg: Double
}
```

**Korrektur nach Architekturprüfung — KEIN `Kind`-Enum mit exklusiver
Zuordnung** (Abweichung vom ursprünglichen Entwurf dieses Dokuments):
`isRunning`/`isCrossTrainingOnly`/`hasAmbiguousCardio`/
`hasStrengthActivity` sind **unabhängige** Flags, exakt wie in
`CardioVolumeOverTimeAggregator.LoggedSession` bereits dokumentiert
("Running hat Vorrang nur für die Umfangs-/Pace-ZAHLEN, nicht für die
Sichtbarkeit von Cross-Training"). Ein ursprünglich geplantes `Kind`-Enum
hätte eine gemischte Lauf+Kraft-Session ("Brick") künstlich auf EINE
Haupt-Klassifikation zwingen müssen — genau das Muster, das Phase 1 für
Cross-Training bereits bewusst vermieden hat. `TrainingActivity` ist EIN
Eintrag pro Session (nicht pro Log/Satz, Teil B.4.4 verlangt Tages-/
Wochenansicht, keine Satz-Ebene); eine gemischte Session trägt beide
Signale gleichzeitig.

`sessionFeelingRaw`/Intensitäts-Flags aus dem ursprünglichen Entwurf
wurden **entfernt und auf Work Package 2C verschoben**: Teil 6 der
Beauftragung schließt "neue Regenerations- oder Deload-Empfehlungen" für
diesen Auftrag ausdrücklich aus, und eine Einheit anhand von
`sessionFeeling` als "hart" einzustufen ist bereits Intensitäts-/
Dichte-Klassifikation (Teil E/F), nicht Teil A/B's reine Aggregation.
2A liefert nur die Rohzahlen; `SessionDensityFlag`/`TrainingLoadAssessment`
(Work Package 2C, Abschnitt 5/8 unten) lesen `WorkoutSession.sessionFeeling`
bei Bedarf direkt.

"Datenherkunft"/"Klassifikationssicherheit" aus Teil 4.4 werden NICHT als
eigene Felder modelliert: `hasAmbiguousCardio` IST die
Klassifikationsunsicherheit, `nil` bei `runningDistanceKm`/
`runningDurationSeconds` IST die Datenvollständigkeits-Information — ein
separates Herkunfts-Enum (HealthKit vs. manuell) liefert keinen
zusätzlichen Coaching-Nutzen, den das Ticket einfordert, und wird deshalb
NICHT gebaut (Ticket: "keine unnötigen Architektur-Refactorings").

**`TrainingActivityExtractor`** (DeltiqData) baut `[TrainingActivity]` aus
`[WorkoutSession]`: ruft `CardioHistoryExtractor.loggedSessions(from:)`
unverändert für die Cardio-Klassifikation auf (Teil 2 der
Architekturprüfung unten erklärt, warum keine zweite Klassifikationslogik
entsteht) und ergänzt pro Session die Kraft-Kennzahlen über
`SessionAggregator.totals` auf den gefilterten
(`!resolvedIsCardio`) `loggedSets`.

## 2. Belastungsaggregation (Teil C)

**Ruling — Lauf-/Kraft-Belastung nebeneinander, nie zusammengelegt**
(Ticket-Vorgabe). `running` wird als VOLLSTÄNDIGER
`CardioVolumeOverTimePoint` eingebettet (nicht feldweise kopiert) — das
macht die Wiederverwendung von `CardioVolumeOverTimeAggregator` auch am
Typ selbst sichtbar und erhält "sonstige Ausdauer" (`crossTrainingSessionCount`)
sowie "unbekannte Sportart" (`ambiguousCardioSessionCount`) als dessen
bereits vorhandene Felder, ohne sie zu duplizieren:

```swift
public struct TrainingLoadWeek: Sendable, Equatable, Identifiable {
    public let weekStart: Date
    public let running: CardioVolumeOverTimePoint   // Phase 1, unveraendert

    // Kraft (neu in Phase 2).
    public let strengthSessionCount: Int
    public let strengthSetCount: Int
    public let strengthVolumeKg: Double

    public var id: Date { weekStart }
}
```

`hardStrengthSessionCount` (ursprünglich hier geplant) ist entfernt — wie
in Abschnitt 1 begründet, ist "hart" eine 2C-Intensitätsklassifikation,
kein 2A-Rohwert.

`TrainingLoadAggregator.aggregate(activities:windowStart:now:calendar:)`
(DeltiqCore): ruft `CardioVolumeOverTimeAggregator.aggregate` UNVERÄNDERT
auf (jede `TrainingActivity` projiziert verlustfrei auf
`CardioVolumeOverTimeAggregator.LoggedSession`) und bucket't NUR die
Kraft-Zahlen zusätzlich, mit dem exakt gleichen
`Calendar.dateInterval(of: .weekOfYear, for:)`-Prinzip. **Korrektur nach
Architekturprüfung:** die Wochengrenzen-Formel selbst (`weekStartFor`,
eine Zeile) ist in `CardioVolumeOverTimeAggregator`/
`VolumeOverTimeAggregator` `private` und wird hier dupliziert — das ist
reine Kalenderarithmetik ohne Fachlogik, kein "redundantes
Belastungsmodell"; die eigentliche Aggregations-FACHLOGIK (welche Session
zählt wie) entsteht an keiner Stelle doppelt. Das Lücken-Füllen für das
Gesamtergebnis kommt automatisch aus `CardioVolumeOverTimeAggregator.aggregate`s
bereits lückenlosem Ergebnis, über das `TrainingLoadAggregator` nur noch
mapt — keine zweite Lücken-Füll-Implementierung.

## 3. Belastungstrends und -anstiege (Teil C.5) — Work Package 2B, IMPLEMENTIERT

**Status: implementiert als `TrainingLoadTrendAnalyzer`** (nicht
`TrainingLoadTrendCalculator`, siehe Implementierungsplan 2B-Abschnitt fuer
die vollstaendige, tatsaechliche Typdefinition inkl. `WeeklyMetricTrend`,
`MetricChange`, `MetricTrendClassification`, `LoadDevelopment`,
`TrainingLoadDataCompleteness`). Die zentralen Konstanten sind dieselben wie
urspruenglich geplant, um eine vierte Kategorie ("stark schwankend")
ergaenzt:

```swift
public enum TrainingLoadTrendAnalyzer {
    public static let comparisonWindowWeeks = 5
    /// Bewusst identisch zu RaceProgressAssessment.loadIncreaseThreshold -
    /// keine neu erfundene Zahl fuer denselben Sachverhalt.
    public static let moderateIncreaseThreshold = 0.25
    /// Konsistent mit dem Ticket-Beispiel (18km -> 27km = +50%).
    public static let significantIncreaseThreshold = 0.50
    /// NEU - fuer "stark schwankend" (Ticket Teil 4) existiert in Phase 1
    /// kein Vorbild-Schwellenwert.
    public static let variabilityCoefficientThreshold = 0.30
    public static let minimumCompleteWeeksForTrend = 3
    public static let acuteChronicChronicWindowWeeks = 4
}
```

**Wichtiger, waehrend der eigenen Testerstellung gefundener und behobener
Entwurfsfehler:** die Vergleichsbasis fuer "aktuelle Woche gegen Durchschnitt
der vorherigen Wochen" muss die aktuelle Woche STRUKTURELL ausschliessen
(`weeks.dropLast()`), nicht ueber eine reine Kalendervollstaendigkeits-
Filterung des gesamten Arrays - sonst koennte eine bereits abgeschlossene
"aktuelle" Woche in ihre eigene Vergleichsbasis einfliessen und den
berechneten Prozentwert verfaelschen. Siehe Implementierungsplan fuer die
vollstaendige Herleitung.

**Acute:Chronic (Teil C.5.3) — Architekturprüfung Teil 3, Ergebnis: BEIBEHALTEN,
ein Punkt präzisiert.** Vor der Entscheidung wurde geprüft, ob der
Indikator mangels Aussagekraft ganz entfallen sollte (das Ticket erlaubt
das ausdrücklich: "Wenn die Datenbasis... nicht ausreicht, soll der
Indikator zunächst entfallen"). Ergebnis: die bereits geplanten Leitplanken
erfüllen die Ticket-Vorgaben bereits vollständig —

* Keine Verletzungsprognose/medizinische Aussage: der Name "Acute:Chronic"
  erscheint nirgends in der UI, nur als interne Kennzahl.
* Keine automatische Plananpassung: reiner Lesewert, kein Schreibpfad.
* Keine alleinige Grundlage für Deload/Regeneration: fließt NIE direkt in
  einen `Concern` ein, sondern höchstens als Begründungszahl eines
  bereits anderweitig (durch die unabhängige Ramp-Prozent-Regel) ausgelösten
  Befunds.
* Keine Berechnung bei unzureichender Historie: `nil` wenn weniger als 28
  Tage Historie vorliegen.
* Belastungsbewertung funktioniert ohne ihn: `loadIncreasedTooFast`
  entsteht bereits vollständig aus `volumeIncreaseThreshold` (Abschnitt
  oben), unabhängig vom ACR-Wert.

**Präzisierung (fehlte im ursprünglichen Entwurf):** "Fehlende
Trainingswochen dürfen nicht stillschweigend als 0-Belastungswochen
interpretiert werden" (Ticket-Vorgabe). Da `TrainingLoadWeek`-Lücken
innerhalb des Aggregationsfensters technisch als `0` geführt werden
(identisches Prinzip wie Phase 1, "ehrliche Null" statt fehlendem Eintrag),
MUSS das 28-Tage-ACR-Fenster vollständig innerhalb
`windowStart...now` liegen (`windowStart` = frühestes geloggtes
Aktivitätsdatum, wie überall in Phase 1/2) — eine Woche VOR dem frühesten
bekannten Trainingsdatum wird vom Aggregator nie erzeugt und kann daher
nie fälschlich als "0 trainiert" in die 28-Tage-Summe einfließen. Reicht
die verfügbare Historie nicht für ein vollständiges 28-Tage-Fenster
INNERHALB des Beobachtungszeitraums, ist das Ergebnis `nil` (identisch zum
bereits bestehenden "< 28 Tage"-Fall) statt einer aus Teilhistorie
hochgerechneten Zahl. Formel: 7-Tage-Summe ÷ (28-Tage-Summe / 4),
`acuteChronicRatio: Double?` auf einem internen Trend-Typ.

## 4. Intensität/Herzfrequenz (Teil D)

**Keine neue Logik** — `HeartRateZoneCalculator`/
`HeartRateZoneContextBuilder` werden unverändert wiederverwendet, exakt wie
in `RaceProgressCardModel`. `TrainingLoadAssessment` bekommt KEIN eigenes
HF-Modell; es referenziert denselben `HeartRateZoneDisplayState`, den
`RaceProgressCardModel` bereits berechnet (Parameter-Übergabe, keine
Neuberechnung — "keine redundanten Belastungsmodelle").

"Zeit in Zonen" (Teil D.6.2) bleibt dauerhaft nicht ausweisbar (keine
Zeitreihen-Datenquelle) — Teil-A-Audit bestätigt das, keine neue
Datenquelle wird dafür gebaut (explizites Nicht-Ziel).

## 5. Trainingsverteilung und Regeneration (Teil E/F)

```swift
public enum SessionDensityFlag: Sendable, Equatable {
    case restDay
    case easyOrAmbiguousDay       // keine verlaessliche Intensitaetsaussage moeglich
    case hardRunDay                // Lauf, sessionFeeling >= 4 ODER Teil eines Lastanstiegs
    case strengthDay
    case otherEnduranceDay
    case mixedHardDay              // Kraft + anspruchsvoller Lauf am selben Tag
}
```

**Ruling — "anspruchsvoll" braucht ein Signal, nie eine Vermutung:** eine
Lauf- oder Kraft-Einheit gilt NUR dann als "anspruchsvoll", wenn
`sessionFeeling >= 4` vorliegt (identische Schwelle wie
`DeloadAdvisor.hardFeelingThreshold`, bewusst wiederverwendet statt neu
erfunden) ODER die Einheit Teil eines bereits erkannten
Lastanstiegs ist (Abschnitt 3). Fehlt `sessionFeeling` UND liegt kein
Lastanstieg vor, ist die Intensität **unbekannt** — Tag wird als
`.easyOrAmbiguousDay` geführt, nie automatisch als hart eingestuft
(exakte Ticket-Vorgabe 7.1/Testfall 22).

**Erholungsabstand:** Tage zwischen zwei als "anspruchsvoll" markierten
Tagen (beliebiger Kind). `< 1` Tag (= Rücken an Rücken) bei ≥2
Vorkommen in 14 Tagen → `Concern.insufficientRecoverySpacing`.

**Fehlende Daten (Teil 7.3):** `DataGap`-Fall pro Woche ohne jegliches
Log, UNTERSCHIEDEN nach: vor `cardioCoachingEnabledAt` (nur relevant, wenn
überhaupt Cardio-Coaching aktiv ist — sonst entfällt dieser Fall schlicht),
reine Kraftwoche (`strengthSessionCount > 0`, kein Lauf — niemals als
Lauf-Lücke gewertet, identisches Prinzip wie Phase 1s
`.strengthOnlyWeek`), reine Cross-Training-Woche
(`running.crossTrainingSessionCount > 0`, Feld aus dem eingebetteten
`CardioVolumeOverTimePoint`, siehe Abschnitt 2), echte Lücke (gar keine
Aktivität).

## 6. Lauf+Kraft gemeinsam (Teil F)

`Concern.trainingDensityAcrossDisciplines(runCount:strengthCount:
backToBackHardDays:)` — nur erzeugt, wenn in derselben Woche sowohl
`running.runningSessionCount > 0` als auch `strengthSessionCount > 0`
UND mindestens ein `mixedHardDay`/Rücken-an-Rücken-Fall (Abschnitt 5)
vorliegt. Liefert die Zahlen für die Ticket-Beispielaussage direkt als
Payload (`runCount`, `strengthCount`, `backToBackHardDays`) — die UI baut
daraus Satz 1–2 des Beispiels wörtlich nach; **keine pauschale
"Krafttraining streichen"-Formulierung existiert im Vokabular.**

## 7. Deload-Integration (Teil G)

`TrainingLoadAssessment.deloadSignal: DeloadAdvisor-Ergebnis` (Bool,
durchgereicht) + optionaler `ComebackSignal` (wie
`FourWeekReviewOrchestrator.Input`) — Konfliktregel identisch zu dort
(Comeback schlägt Deload). Phase 2 fügt dem bestehenden Signal **einen
weiteren, eigenständigen Grund** hinzu, den `DeloadAdvisor` heute nicht
kennt: hohe cross-disciplinäre Dichte (Abschnitt 6) — als eigener
`Concern.restWeekSuggested(reasons: [RestWeekReason])`, NIE eine zweite
Deload-Engine, sondern ein zusätzlicher, textlich konkret begründeter
Hinweis neben dem bestehenden `deloadRecommended`-Signal.

## 8. `TrainingLoadAssessment` (Teil H)

```swift
public enum TrainingLoadAssessment {
    public struct Input: Sendable, Equatable {
        public let weeks: [TrainingLoadWeek]              // aelteste zuerst
        public let heartRateZoneContext: HeartRateZoneDisplayState
        public let coachingObservationStart: Date?         // cardioCoachingEnabledAt, optional
        public let deloadRecommended: Bool                 // von DeloadAdvisor
        public let comebackSignal: FourWeekReviewOrchestrator.ComebackSignal?
        public let now: Date
    }

    public enum Concern: Sendable, Equatable {
        case loadIncreasedTooFast(discipline: Discipline, percentOverLastNWeeks: Double, weeks: Int)
        case insufficientRecoverySpacing(backToBackCount: Int)
        case trainingDensityAcrossDisciplines(runCount: Int, strengthCount: Int, backToBackHardDays: Int)
        case restWeekSuggested(reasons: [RestWeekReason])
        case deloadRecommended   // 1:1 DeloadAdvisor
        case comebackSuggested(ComebackAdvisor.Prescription)
    }

    public enum Discipline: Sendable, Equatable { case running, strength }
    public enum RestWeekReason: Sendable, Equatable {
        case volumeRamp, highDensity, crossDisciplineOverlap, prolongedElevatedLoad
    }

    public enum DataGap: Sendable, Equatable {
        case insufficientHistory(weeksAvailable: Int, weeksNeeded: Int)
        case geniuneGapWeeks(count: Int)          // s. Abschnitt 5
        case ambiguousActivityPresent(weekCount: Int)
        case noIntensityDataForSomeSessions(count: Int)  // kein sessionFeeling
    }

    public enum Outcome: Sendable, Equatable {
        case balanced
        case increasingLoad([Concern])
        case highTrainingDensity([Concern])
        case insufficientRecoveryEvidence([Concern])
        case insufficientData
    }

    public struct Assessment: Sendable, Equatable {
        public let outcome: Outcome
        public let dataGaps: [DataGap]
        public let weeklyFlags: [SessionDensityFlag]  // Begruendungsgrundlage
    }

    public static func assess(_ input: Input) -> Assessment { ... }
}
```

Reine Funktion, keine `apply`-Methode (identisch `RaceProgressAssessment`/
`FourWeekReviewOrchestrator`). Outcome-Priorität bei mehreren zutreffenden
Fällen: `highTrainingDensity` > `increasingLoad` >
`insufficientRecoveryEvidence` > `balanced` (dichte/akute Befunde zuerst,
analog zur Offtrack-Priorität in `RaceProgressAssessment`).

**Due-Calculator:** `TrainingLoadDueCalculator` (DeltiqData), identisches
Muster zu `RaceProgressDueCalculator`/`FourWeekReviewDueCalculator` —
eigene Felder auf `UserBodyProfile`:
`trainingLoadLastAnalyzedAt: Date?`,
`trainingLoadLastAnalyzedConfigurationFingerprint: String?`,
`trainingLoadDismissedFingerprint: String?`. Fingerprint hier ist NICHT
ziel-/renndatumbasiert (Phase 2 ist zielunabhängig), sondern ein simpler
Hash über `weeks.count`/letztes Aktivitätsdatum — "neue Daten seit letzter
Analyse" ist der einzige relevante Auslöser.

## 9. Dashboard-Integration (Teil I)

Neues `DashboardWidgetType.trainingLoadCard` (ans Ende angehängt). KEIN
automatisches Nach-oben-Schieben bei irgendeiner Aktivierung (Abschnitt
0.6) — Nutzer fügt es bewusst über die Einstellungen hinzu, oder es
erscheint ab Werk weiter unten in `defaultOrder` für Neuinstallationen.

`TrainingLoadCardModel.make(for:allSessions:now:)` (DeltiqUI) — Vorbild
`RaceProgressCardModel`. Kompakte Karte zeigt: `outcome`-Kopfzeile,
aktuelle Laufkilometer, Trainingseinheiten gesamt, Krafttrainingseinheiten,
wichtigster `Concern` als ein Satz, "Details"-Button zu
`TrainingLoadDetailView` (Vorbild `RaceProgressDetailView`): Sections exakt
den 9 Punkten aus Teil I entsprechend.

## 10. Datenvollständigkeit (Teil J)

`Assessment.outcome == .insufficientData` plus die vier `DataGap`-Fälle
sind die einzige Vertrauens-Mechanik — **kein separates
"Confidence"-Enum** (vollständig/teilweise/unzureichend): die Ticket-
Vorgabe "unvollständige Datenlage muss die Sicherheit der Bewertung
reduzieren" wird dadurch erfüllt, dass JEDE Datenlücke explizit als
`DataGap` sichtbar bleibt UND bei zu dünner Historie das gesamte Outcome
auf `.insufficientData` kippt (identisches Prinzip wie
`RaceProgressAssessment.Outcome.insufficientData`) — ein zusätzliches,
drittes Vokabular dafür wäre redundant.

## Offene, bewusst dem Implementierungsplan überlassene Details

* Exakte Schwellenwerte für `insufficientRecoverySpacing`/
  `highTrainingDensity` (Anzahl Rücken-an-Rücken-Tage) — als zentrale
  Konstanten in `TrainingLoadAssessment` dokumentiert, Default-Vorschlag:
  ≥2 Vorkommen in 14 Tagen (konsistent mit `DeloadAdvisor.
  minimumHardSessions`).
* ~~Ob `TrainingActivity` als eigener Typ oder als reine Erweiterung von
  `CardioVolumeOverTimePoint`/`VolumeWeekPoint` umgesetzt wird~~ —
  **entschieden (2A implementiert):** eigener Typ, siehe Abschnitt 1.

---

## Work Package 2C: TrainingDensityAnalyzer (implementiert 2026-11-07)

### Bewusste Modellgrenze: Kein Rolling-7-Day-Cross-Week-Vergleich

Die ursprüngliche Idee eines rollenden 7-Tage-Vergleichs über Wochengrenzen
hinweg ist mit der bestehenden Datenarchitektur **nicht ohne eine neue parallele
Aggregation** umsetzbar:

* `TrainingLoadWeek` hat Wochen-Granularität — kein Zugriff auf einzelne Tage.
* Ein echter Rolling-7-Day-Vergleich würde tägliche Bucket-Aggregation
  erfordern (neue parallele Aggregation), was explizit verboten ist.
* `TrainingActivity.date` bietet aber Tages-Granularität — daher nutzt 2C
  genau das für die Dichte-Analyse (tägliche Distinct-Training-Days, maximale
  Folgetage, Laufabstände in Stunden).

**Konsequenz:** Die Trainingsbelastungs-Karte vergleicht KEINE Belastungswerte
wochenwechselübergreifend. Sie analysiert stattdessen die tägliche
Trainingsstruktur der gesamten verfügbaren Aktivitätsliste. Das ist die
umfassendere Aussage.

### TrainingDensityAnalyzer: Design

Reine Funktion nach FourWeekReviewOrchestrator-Muster:

* **Input:** `[TrainingActivity]` + `TrainingLoadTrend` + `deloadIsActive: Bool`
* **Output:** `Assessment` (Concern/DataGap/Outcome-Tripel)
* Kein SwiftData, kein `Date()`, kein `Calendar.current` — alle zeitlichen
  Bezugspunkte injiziert (testfreundlich).

**deloadIsActive** wird vom Aufrufer aus AppStorage `deload_until >
now.timeIntervalSince1970` berechnet — `TrainingDensityAnalyzer` berechnet
ihn nie selbst (Ticket-Leitplanke: "Keine zweite Deload-Engine").

**Schwellenwerte:**
| Konstante | Wert | Bedeutung |
|-----------|------|-----------|
| `highConsecutiveDaysThreshold` | 5 | Aufeinanderfolgende Trainingstage |
| `denseWeekThreshold` | 6 | Trainingstage in 7-Tage-Rollfenster |
| `closeRunningGapHoursThreshold` | 18h | Mindestabstand zwischen Läufen |
| `minimumActivityCount` | 3 | Mindest-Aktivitäten |
| `minimumSpanDays` | 7 | Mindestspanne |
| `sufficientHistoryDays` | 14 | Volle Aussagekraft |

**Outcome-Priorität:**
1. `deloadIsActive` ODER `significantIncrease` → `.increasingLoad`
2. High-Density-Concern → `.highTrainingDensity`
3. Span < 14 Tage → `.insufficientRecoveryEvidence`
4. Trend `.stable`/`.declining` → `.balanced`
5. Sonst → `.insufficientRecoveryEvidence`

**DataGaps:** `sessionFeelingUnavailable` ist immer vorhanden (TrainingActivity
trägt kein RPE — bewusste Modellgrenze). `noMeasuredIntensityData` wenn kein
Lauf mit bekannter Dauer. `insufficientHistory` wenn Spanne < 14 Tage.

---

## Work Package 2D: Dashboard-Karte (implementiert 2026-11-07)

### DashboardWidgetType.trainingLoadCard

Neuer Widget-Typ, an **letzter Stelle** in `defaultOrder` angehängt
(Migration-sicher, erscheint für bestehende User in der Inactive-Section).
**UNABHÄNGIG von `cardioCoachingEnabled`** — Ticket-Leitplanke explizit.

### Datenpipeline (DashboardView)

```
completedSessions
  → TrainingActivityExtractor.extract(from:)      // DeltiqData
  → TrainingLoadAggregator.aggregate(...)          // 12-Wochen-Fenster
  → TrainingLoadTrendAnalyzer.analyze(...)         // 2B
  → TrainingDensityAnalyzer.analyze(input:)        // 2C
  → Assessment → cachedDensityAssessment
```

Caching: `@State private var cachedDensityAssessment` +
`.onChange(of: completedSessions, initial: true)` — identisches Muster wie
`cachedPlateauFinding`.

### TrainingLoadDetailView

9-sektionige Detailansicht (`NavigationStack` + `List`):
1. Bewertung (Outcome-Icon + Label)
2. Belastungsentwicklung (vereinfacht, da Assessment kein raw-Trend trägt)
3. Trainingstage letzte 7 Tage (ProgressView)
4. Trainingstage letzte 14 Tage (ProgressView)
5. Maximale Folgetage (ProgressView, orange ab Schwellenwert)
6. Kürzester Laufabstand (Stunden, Warnung wenn < 18h)
7. Kürzester Kraft-Abstand (Stunden)
8. Erkannte Auffälligkeiten (Concerns)
9. Fehlende Daten (DataGaps)

**Shortcut (dokumentiert):** `loadDevelopmentLabel` leitet sich aus dem
Outcome ab statt aus dem rohen `TrainingLoadTrend`, weil `Assessment` den
Trend-Objekt nicht mitführt. Upgrade: Trend durch Detail-View-Init
weiterreichen.

### Lokalisierung

36 neue xcstrings-Keys (DE/EN/TR), idempotent via
`.scripts/training_density_phase2c_keys.py` eingespielt.
