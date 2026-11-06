# AI Running Coach — Phase 1: Lokale, deterministische Datengrundlage (Design)

**Status:** Entwurf, wartet auf Freigabe.

## Ziel

Deltiq bekommt langfristig einen KI-gestützten Laufcoach, der kontinuierlich
beurteilt, ob der Nutzer auf Kurs für sein Wettkampfziel ist, und dabei
Trainingsbelastung/Regeneration als unterstützende Faktoren heranzieht. Das
Gesamtfeature wird in 4 Phasen gebaut (Analysegrundlage → KI-Integration →
Planoptimierung → Hintergrund/Dashboard). Dieses Dokument deckt **nur Phase
1** ab: eine rein lokale, deterministische Datengrundlage, ohne KI, ohne
Netzwerk, ohne Backend.

Priorität laut Nutzer-Entscheidung:
1. **Primär:** "Bin ich auf Kurs für mein Wettkampfziel?" — Umfangsentwicklung,
   Realismus des aktuellen Plans, nötige Strategieänderungen.
2. **Sekundär (fliesst in #1 ein):** "Trainiere ich zu viel/zu wenig?" —
   Belastungssteigerung, Regeneration, Lauf/Kraft-Verhältnis.

Bei einer Zieländerung (z. B. Halbmarathon → Marathon) muss die **gesamte
verfügbare Trainingshistorie** neu gegen das neue Ziel bewertet werden, nicht
nur der aktuelle Plan isoliert (siehe Abschnitt "Neubewertung bei
Zieländerung").

Ausgabe-Stil: konkrete Zahlen und Begründung, kein pauschaler Motivationstext.
Beispiel (Wortlaut des Nutzers): „Dein aktueller Umfang entwickelt sich
Richtung Marathon-Ziel, aber deine Wochenbelastung ist in den letzten drei
Wochen um 28 % gestiegen. Eine ruhigere Woche wird empfohlen." — **Phase 1
liefert die Zahlen und die strukturierte Einstufung dafür (28 %,
"Belastungsanstieg", "Empfehlung: Umfang reduzieren"), nicht den Fliesstext
selbst** (das ist Phase 2, KI formuliert aus den strukturierten Fakten).

## Nicht-Ziele (explizit ausserhalb Phase 1)

- Keine KI-Anbindung, kein Netzwerkzugriff, kein Backend.
- Keine Hintergrund-Tasks (`BGTaskScheduler`) — das ist Phase 4. Phase 1
  prüft nur "ist eine Neuanalyse fällig", die Ausführung passiert beim
  App-Öffnen bzw. direkt nach einem auslösenden Ereignis (neue Einheit,
  Zieländerung) im Vordergrund.
- Keine neue Plan-Mutationslogik. Die bestehende
  `RunCoachPlanAdjustment`/`CoachAdjustmentCardModel`-Pipette bleibt
  unverändert zuständig für tatsächliche Planänderungen (Phase 3 verdrahtet
  Phase 1s Befund mit dieser bestehenden Pipeline).
- Keine neue Datenerfassung (Herzfrequenz pro Lauf, RPE pro Lauf,
  Schlafdaten) — diese Felder existieren heute nicht (siehe Architektur-
  Recherche unten) und werden nicht in Phase 1 nachgerüstet. Sie bleiben
  durchgehend als "unbekannt" markiert.
- Keine Backend-Technologie-Entscheidung/-Umsetzung — nur eine dokumentierte
  Optionsübersicht (siehe eigener Abschnitt unten), wie vom Nutzer verlangt.

## Anti-Ziele (würden das Feature scheitern lassen, auch wenn es technisch läuft)

- Irgendeine Zahl oder Aussage erfinden, die sich nicht aus echten Daten
  ableiten lässt.
- Eine zweite, parallele Trainingsplan-/Coaching-Architektur neben der
  bestehenden (`TrainingPlan`/`RunCoachPlanAdjustment`/`CoachAdjustmentCardModel`).
- Irgendeine Planänderung automatisch anwenden, ohne Nutzerbestätigung.
- Eine Zieländerung wie einen weiteren Punkt-Snapshot behandeln statt die
  komplette Historie neu zu bewerten.

## Bereits vorhandene Architektur (Recherche-Ergebnis)

Vor der Implementierung wurde die bestehende Architektur systematisch
durchsucht. Zusammenfassung (Details: exakte Datei:Zeile folgen im
Implementierungsplan):

**Direkt wiederverwendbar:**
- `PlanParticipationEvaluator` — absolvierte/ausgefallene/teilweise
  absolvierte Einheiten, mit explizitem `DataGap`/`CountingRule` statt
  Rateln bei fehlenden Daten. Liefert einen Kernbaustein direkt.
- `FourWeekReviewOrchestrator` — das architektonische Vorbild: reine
  Funktion, die bereits berechnete Signale zu `Concern`/`DataGap`/`Outcome`-
  Enums verdichtet (`.keepAsIs`/`.concernsFound([Concern])`), **maschinen-
  lesbar, kein Fliesstext aus `DeltiqCore`** — genau das Muster, das Phase 1
  für den neuen Orchestrator kopieren soll.
- `FourWeekReviewDueCalculator`/`FourWeekReviewDueStatus` — das Vorbild für
  "ist eine Neuanalyse fällig": reiner `due(since:)`/`notYetDue(dueAt:)`-
  Zustand, persistierte Historie, idempotent, "kein Push, keine garantierte
  Ausführungszeit, rein passive Anzeige" — exakt die Eigenschaften, die der
  Nutzer für die Trigger-Logik verlangt hat.
- `VolumeOverTimeAggregator` — wochenweises, lückenfüllendes Bucketing,
  bisher nur für Krafttraining (`!log.isCardio` wird explizit ausgeschlossen).
  Das Muster wird für eine Cardio-Variante kopiert, die bestehende Funktion
  bleibt für die Krafttrainings-Kennzahl unverändert im Einsatz.
- `CardioBaselineCalculator` — liefert einen Baustein für die
  Wochenvolumen-Einstufung und die 5K-Referenzpace.
- `CardioFeasibilityCalculator` — die bestehende 10-%-Rampenregel
  (`maxWeeklyRampPercent`) wird als Schwelle für "Belastung steigt zu
  schnell" wiederverwendet, statt eine neue Zahl zu erfinden.
- `CoachAdjustmentCardModel`s Fingerprint-gesteuertes
  Bestätigen/Verwerfen-Muster — Vorbild für die neue Karte (siehe unten).
- `DashboardView`s bestehendes Karten-Schema (Headline + Detail +
  Review/Dismiss-Buttons, gated auf ein Dismissed-Fingerprint-Feld).

**Fehlt vollständig und muss neu gebaut werden:**
- Ein Cardio-Pendant zu `VolumeOverTimeAggregator` (Wochenserie: Umfang,
  Häufigkeit, Intensitätsmix, Long-Run-Entwicklung, Pace-Trend).
- Jegliche "Trend über N Wochen"/Wochen-zu-Wochen-Delta-Berechnung — heute
  existiert nur Punkt-Snapshots.
- Ein laufspezifisches Belastungs-/Regenerations-Signal (`DeloadAdvisor`
  ist explizit kraft-/CNS-spezifisch und schliesst Cardio-Last aus).
- Der neue Orchestrator selbst (Wettkampf-Fortschritt + Belastung
  kombiniert).
- Die Fällig-Trigger-Verdrahtung für dieses neue Feature (eigenes
  persistiertes Anker-Feld, nach demselben Muster wie
  `FourWeekReviewDueCalculator`).
- Dashboard-Karte + Detailansicht.

**Bestätigte Datenlücken (bleiben in Phase 1 unverändert "unbekannt"):**
- Keine Herzfrequenz pro Lauf irgendwo im Modell (`ExerciseLog` hat nur
  `distanceKm`/`durationSeconds`). `HealthKitService` liest nur
  Ruhepuls + Schrittzahl, keine Workout-HF.
- Keine Schlafdaten irgendwo.
- Keine RPE pro Lauf — nur `WorkoutSession.sessionFeeling` (RPE 1–5) auf
  Session-Ebene, nicht lauf-spezifisch.
- Kein generisches "Pending-Proposal"-Konzept — jedes Feature legt sein
  eigenes `String?`-Dismissed-Fingerprint-Feld auf `UserBodyProfile` an
  (4 bestehende Beispiele). Phase 1 folgt dieser Konvention mit einem
  weiteren Feld, statt ein generisches System einzuführen (YAGNI an dieser
  Stelle — vier Ad-hoc-Felder sind etabliert, ein fünftes ist konsistent;
  eine generische Abstraktion für fünf Fälle wäre verfrüht).

## Architektur Phase 1

### Neues Modul/Dateien (Namen vorläufig, Details im Implementierungsplan)

Bleibt in der bestehenden Zwei-Schichten-Trennung (`DeltiqCore` = reine
Funktionen ohne SwiftData, `DeltiqData` = SwiftData-Glue), exakt wie
`RunCoachPlanAdjustment`/`CardioFeasibilityCalculator` es bereits vormachen:

- **`DeltiqData/CardioVolumeOverTimeAggregator.swift`** — wochenweise,
  lückenfüllende Aggregation aus `ExerciseLog`/`WorkoutSession` für Lauf-
  Einheiten: Distanz, Anzahl Einheiten, längster Lauf der Woche
  (Long-Run-Proxy), Pace (wo ableitbar), Intensitätsmix (falls über
  bestehende Lauf-Zweck-Kennzeichnung ableitbar, sonst "unbekannt" statt
  geraten). Liegt in `DeltiqData`, weil es SwiftData-Modelle liest —
  dieselbe Begründung wie bei `RunCoachPlanAdjustment`.
- **`DeltiqCore/Analytics/RaceProgressAssessment.swift`** — reine
  Orchestrator-Funktion (Vorbild `FourWeekReviewOrchestrator`): nimmt die
  bereits berechnete Wochenserie + Ziel/Renndatum/`cardioCoachingEnabledAt`/
  bestehendes `CardioFeasibilityCalculator.Result` entgegen, liefert ein strukturiertes
  Ergebnis (Outcome: `onTrack`/`attentionNeeded`/`offTrack` + Liste von
  `Concern`s [Belastungsanstieg, fehlende Regeneration, Plateau,
  unrealistisches Ziel, ...] + Liste von `DataGap`s [keine HF, zu wenig
  Wochen Historie, ...]). Jede auffällige Woche bekommt einen von sechs
  disjunkten, nie geratenen Gründen (`.beforeCoachingObservationPeriod`/
  `.strengthOnlyWeek`/`.crossTrainingOnlyWeek`/`.ambiguousActivityWeek`/
  `.genuineGap`/`.insufficientHistory`, siehe Abschnitte
  "`cardioCoachingEnabledAt`"/"Laufen vs. andere Cardio-Art" oben) — eine
  Lauf-Plateau-/Inaktivitäts-Warnung entsteht NUR für `.genuineGap`.
  **Keine Fliesstext-Erzeugung in `DeltiqCore`** —
  das bleibt der UI/Phase 2 vorbehalten, damit die Logik ohne KI testbar
  bleibt und später 1:1 von der KI (Phase 2) konsumiert werden kann.
- **`DeltiqData/RaceProgressDueCalculator.swift`** — Kopie des
  `FourWeekReviewDueCalculator`-Musters: fällig bei neuer abgeschlossener
  Laufeinheit, Zieländerung, Renndatum-Änderung, signifikanter
  Umfangsänderung, oder nach N Tagen seit letzter Analyse. Reine
  Zustandsprüfung, kein Scheduling (das ist Phase 4).
- **`UserBodyProfile`**: drei neue Felder. `cardioCoachingEnabledAt:
  Date?` (siehe eigener Abschnitt oben — Beobachtungszeitraum, nie
  rückwirkend erfunden) sowie ein Feld-Paar nach bestehendem Muster, z. B.
  `raceProgressLastAnalyzedAt: Date?` + `raceProgressDismissedFingerprint:
  String?` (exakte Namen im Implementierungsplan) — persistiert Zeitpunkt
  und Verwerfen-Zustand der letzten Analyse, analog den 4 bestehenden
  Fingerprint-Feldern.
- **UI:** neue Dashboard-Karte (wiederverwendet das bestehende Karten-
  Schema aus `DashboardView`) + neue Detailansicht (analog
  `CardioCoachDetailView`s Struktur), zeigt die strukturierten Befunde als
  lesbaren Text **mit konkreten Zahlen**, inklusive sichtbarer
  "Daten nicht verfügbar"-Hinweise für HF/Schlaf/RPE pro Lauf statt sie
  wegzulassen oder zu übergehen.

### Geklärte Entscheidungen aus dem Builder-Check

Ein Review vor Freigabe hat vier offene Fragen aufgeworfen. Drei lassen
sich direkt aus den bereits im Ticket/diesem Dokument festgelegten
Prinzipien beantworten und sind hiermit entschieden; die vierte bleibt dem
Nutzer vorbehalten (siehe unten).

1. **Laufen vs. andere Cardio-Art in der Historie** (verfeinert nach
   Nutzer-Rückmeldung — KEIN pauschaler DataGap für jede Nicht-Lauf-
   Aktivität): `Exercise.enduranceSportKind` unterscheidet Laufen von
   anderem Cardio, defaultet auf `nil`, wird NIE aus dem Namen geraten.
   Drei disjunkte Fälle, nie vermischt:
   - `enduranceSportKind == .running` → zählt in Lauf-Umfang,
     Long-Run-Entwicklung, Pace/HF-Trend, Wettkampf-Bereitschaft.
   - `enduranceSportKind == .cycling` (oder weitere bekannte,
     nicht-laufende Ausdauerarten) → bekannte Aktivität, KEIN DataGap.
     Zählt NIE in Lauf-Umfang/Long-Run/Pace, fliesst aber als
     Cross-Training-Kontext in die Belastungs-/Regenerations-Bewertung
     ein (Signal 2, sekundär) — gleiche Rolle wie Krafttraining dort.
   - `enduranceSportKind == nil` auf einer als Cardio erkannten Einheit
     (`Exercise.isCardio == true`, aber Sportart unbekannt) → ECHTE
     Mehrdeutigkeit, wird NIE als Laufen angenommen. Erzeugt einen
     expliziten `.ambiguousActivityWeek`-Befund/DataGap ("N Cardio-
     Einheiten ohne eindeutige Sportart"), fliesst in KEINE der drei
     obigen Kategorien ein.
2. **Woher kommt der Wert für die 10-%-Rampenregel?** `CardioFeasibilityCalculator.
   evaluate` nimmt `weeklyBaseVolumeKm` bereits als einfachen Parameter
   entgegen (keine interne Kopplung an `UserBodyProfile`). Der bisher
   einzige Aufrufer (`CardioCoachDetailView`) uebergibt dafuer
   `profile.weeklyBaseVolumeKm` - einen einmalig beim Onboarding
   eingetragenen Wert, der laut eigener Doku "nie mit der tatsächlichen
   Historie synchronisiert" wird. Entscheidung (folgt aus dem
   Kernversprechen "arbeitet mit tatsächlichen Trainingsdaten"): Phase 1
   berechnet den aktuellen Wochenumfang aus der NEUEN, echten Wochenserie
   (`CardioVolumeOverTimeAggregator`, z. B. Mittel der letzten paar
   Wochen) und übergibt DIESEN Wert an `CardioFeasibilityCalculator.
   evaluate` — die stale Onboarding-Zahl wird für diese Bewertung nicht
   mehr verwendet. Da die Funktionssignatur bereits einen reinen Parameter
   nimmt, ist das keine Erweiterung des Funktionsumfangs, nur eine andere
   Aufrufer-Berechnung.
3. **Lauf/Kraft-Verhältnis:** Lauf-Umfang (km) und Kraft-Umfang (kg) sind
   keine vergleichbaren Einheiten für eine Quote. Entscheidung: der
   Vergleich läuft über Trainingshäufigkeit (Anzahl Lauf-Einheiten/Woche
   vs. Anzahl Kraft-Einheiten/Woche), nicht über rohe Volumen-Grössen.

### Entschieden: `cardioCoachingEnabledAt` markiert den Beobachtungs-Zeitraum, nicht die Datengrenze

Nutzer-Entscheidung (verfeinert gegenüber der ursprünglichen (a)/(b)-Frage):
`UserBodyProfile` bekommt `cardioCoachingEnabledAt: Date?`, aber dieses
Feld schneidet **nicht** die Laufhistorie ab — es markiert nur, ab wann
"Coaching war aktiv beobachtet" für bestimmte Warnungs-Arten gilt. Konkrete
Regeln:

1. **Laufhistorie für Trend-/Fortschritts-Metriken (Wochenumfang,
   Konsistenz, Long-Run-Entwicklung, Pace/HF-Trend, Wettkampf-Bereitschaft):**
   immer die GESAMTE verfügbare, gültige Laufhistorie verwenden — auch
   Läufe von VOR der Coaching-Aktivierung. Echte vergangene Leistung ist
   echte Evidenz und wird nicht verworfen.
2. **Coaching-Beobachtungszeitraum:** `cardioCoachingEnabledAt` grenzt
   NUR ein, für welchen Zeitraum `RaceProgressAssessment`
   Plateau-/Inaktivitäts-/Konsistenz-WARNUNGEN ausspricht. Für Wochen VOR
   diesem Datum wird keine solche Warnung erzeugt (der Nutzer hatte dort
   schlicht noch kein aktives Laufcoaching, "keine Aktivität" dort ist
   kein Befund).
3. **Reine Kraft-Wochen:** eine Woche ohne Lauf-, aber mit Kraft-Einheiten
   ist NIE ein Lauf-"Gap"/"Plateau" — sie fliesst nur in die
   Belastungs-/Regenerations-Bewertung (Signal 2, sekundär) ein, nie in
   eine Lauf-Inaktivitäts-Warnung.
4. **Zieländerung:** reine Neubewertung der kompletten relevanten
   Laufhistorie gegen das neue Ziel (siehe eigener Abschnitt unten) — das
   Vorhandensein von `cardioCoachingEnabledAt` ändert daran nichts, die
   Historie wird dabei nie verworfen.
5. **Unterscheidung Lücke vs. fehlende Daten vs. "vor Aktivierung" vs.
   bekannte Nicht-Lauf-Aktivität:** `RaceProgressAssessment` liefert für
   jede auffällige Woche einen von sechs disjunkten Gründen, nie geraten:
   - `.beforeCoachingObservationPeriod` (vor `cardioCoachingEnabledAt`,
     falls bekannt)
   - `.strengthOnlyWeek` (nur Krafttraining geloggt)
   - `.crossTrainingOnlyWeek` (nur bekannte Nicht-Lauf-Ausdauer, z. B.
     Radfahren, geloggt — KEIN Lauf-Gap)
   - `.ambiguousActivityWeek` (Cardio geloggt, Sportart unbekannt —
     echte Mehrdeutigkeit, nie als Laufen angenommen)
   - `.genuineGap` (nach Aktivierung, weder Lauf- noch Kraft- noch
     Cross-Training-Log)
   - `.insufficientHistory` (zu wenige Wochen Historie insgesamt,
     unabhängig vom Grund)

   Eine Lauf-Plateau-/Inaktivitäts-WARNUNG entsteht ausschliesslich für
   `.genuineGap`. Alle anderen Gründe werden dem Nutzer zwar angezeigt
   (Transparenz, Abschnitt 9 des Tickets), lösen aber nie eine
   "du bist inaktiv"-Warnung aus. Fehlende/mehrdeutige Daten werden nie
   als Inaktivitäts-Beweis interpretiert.

**Migration/Default für Bestandsnutzer (kein erfundenes Datum):**
`cardioCoachingEnabledAt` ist `nil`, solange es nicht bekannt ist — es wird
NIE rückwirkend geraten. Zwei Fälle:

- **Neu-Aktivierung** (Coach wird ab jetzt erstmals eingeschaltet, laufender
  Betrieb): `cardioCoachingEnabledAt = Date()` wird beim Umschalten genauso
  gesetzt wie jedes andere "ab jetzt aktiv"-Datum im Code (gleiches Muster
  wie `TrainingPlan.activatedAt`).
- **Bestandsnutzer, die den Coach schon vor diesem Feld aktiv hatten**
  (`cardioCoachingEnabled == true`, `cardioCoachingEnabledAt == nil` beim
  ersten Lauf von Phase 1 auf einem bestehenden Profil): wir können das
  echte historische Aktivierungsdatum nicht rekonstruieren, also wird KEIN
  Datum in die Vergangenheit erfunden. Stattdessen wird
  `cardioCoachingEnabledAt` einmalig auf den Zeitpunkt gesetzt, an dem
  diese Auswertung zum ersten Mal läuft ("Beobachtung beginnt jetzt
  nachweislich" ist eine wahre Aussage, "Coaching begann historisch an
  Datum X" wäre geraten). Bis dahin (und auch danach für die bereits
  vergangene Zeit) gilt für diesen Nutzer: alle Wochen vor diesem
  Erst-Lauf-Zeitpunkt sind automatisch
  `.beforeCoachingObservationPeriod` — korrekt, da wir für den
  Bestandsnutzer ohnehin nicht wissen wollen, ob "Coaching-Lücken" davor
  sinnvoll sind; die Trend-/Fortschritts-Metriken (Regel 1) sind davon
  unberührt, sie nutzen weiterhin die komplette Historie.

### Neubewertung bei Zieländerung

`RaceProgressAssessment` nimmt immer die **gesamte verfügbare
Wochenserie** von `CardioVolumeOverTimeAggregator` entgegen (nicht nur die
letzten N Wochen) und bewertet sie gegen das AKTUELLE `profile.cardioGoal`.
Ändert der Nutzer das Ziel, wird bei der nächsten fälligen Analyse (siehe
`RaceProgressDueCalculator`, "Zieländerung" ist einer der Fälligkeits-
Gründe) automatisch die komplette Historie gegen das NEUE Ziel neu
durchgerechnet — es gibt keinen separaten "Nur-Delta"-Pfad, der die
Historie ignoriert. Das Ergebnis fliesst NICHT automatisch in eine
Planänderung — es wird angezeigt, und falls eine Planänderung sinnvoll
erscheint, verweist die Detailansicht auf die bestehende
`CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView`-Pipeline (Phase 3
verdrahtet das; Phase 1 zeigt nur die Einschätzung).

### Bestätigungspflicht

Phase 1 ändert nie selbstständig etwas am aktiven Plan — es gibt in Phase 1
schlicht keinen Schreibpfad auf `TrainingPlan`/`TrainingDay`. Die
Einschätzung ist reine Anzeige mit Review/Dismiss, exakt wie die
bestehenden Dashboard-Karten.

## Datenschutz/Offline (Phase 1)

Da Phase 1 komplett lokal und ohne Netzwerk arbeitet, sind die
Datenschutz-Anforderungen aus dem Ticket (keine Daten an externe Dienste,
Offline-first) in Phase 1 automatisch erfüllt — es gibt schlicht keinen
Netzwerkcode. Die Schnittstelle zwischen `RaceProgressAssessment` (Phase 1)
und einer künftigen KI-Schicht (Phase 2) wird bewusst als reiner,
serialisierbarer Werttyp gestaltet (Enums/Structs, `Codable`), damit Phase 2
diesen Typ unverändert als Eingabe für eine spätere, abgesicherte
KI-Anbindung verwenden kann, ohne Phase 1 anzufassen.

## Backend-Optionen für Phase 2 (nur Dokumentation, keine Umsetzung)

Phase 2 braucht einen serverseitigen Proxy, damit kein API-Key in der App
liegt. Deltiq hat aktuell keine Backend-Komponente. Optionen im Vergleich
(Bewertung grob, auf Basis der Projektgrösse: ein Solo-/Kleinteam-Produkt
ohne bestehende Cloud-Infrastruktur):

| Option | Kosten | Privacy | Sicherheit | Wartung | Offline-Verhalten |
|---|---|---|---|---|---|
| **Supabase Edge Function** (Deno, verwaltet) | Kostenlose Stufe reicht für geringes Volumen, danach nutzungsbasiert, planbar | Daten verlassen die EU je nach Region-Wahl konfigurierbar; Supabase selbst sieht die aggregierten Anfrage-Daten | Secrets im Supabase-Vault, nicht im Client; TLS automatisch | Gering — kein eigener Server, Deploy über CLI/Git | App funktioniert unverändert offline (Phase 1 läuft komplett lokal), KI-Anfrage schlägt einfach fehl/wird zurückgestellt |
| **Cloudflare Worker** | Sehr günstig/kostenlos im kleinen Volumen | Gleiche grundsätzliche Lage wie oben: Anbieter sieht Anfragen | Secrets über Wrangler/Workers-KV, nicht im Client | Gering, aber eigenes Deploy-Tooling (Wrangler) zusätzlich zum bestehenden Xcode/SwiftPM-Setup | Gleich wie oben |
| **AWS Lambda + API Gateway** | Kostenlose Stufe grosszügig, aber mehr Konfigurationsaufwand (IAM, API Gateway) treibt eher Zeit- als Geldkosten | Volle Kontrolle über Region/Logging | Secrets Manager, aber deutlich mehr Angriffsfläche durch Breite der AWS-Konsole | Deutlich höher — IAM-Rollen, API-Gateway-Konfiguration, separates Monitoring | Gleich wie oben |
| **Eigener Server (z. B. kleine VM + eigenes Framework)** | Laufende Fixkosten (VM), unabhängig vom Traffic | Volle Kontrolle, aber volle eigene Verantwortung für Compliance | Volle eigene Verantwortung (Patches, TLS-Zertifikate, Firewall) | Am höchsten — eigener Betrieb, eigenes Monitoring/Alerting | Gleich wie oben |
| **Apple-eigene Lösung (CloudKit + Server-to-Server Notifications)** | In Apple-Developer-Programm enthalten | Daten bleiben im Apple-Ökosystem, aber CloudKit ist kein generischer "KI-Proxy" — würde zusätzlich eine echte Compute-Funktion brauchen (CloudKit selbst kann keinen externen API-Call machen) | — (löst das eigentliche Problem nicht allein) | — | — |

**Vorläufige Tendenz (nicht final, nur zur Diskussion):** Supabase Edge
Function oder Cloudflare Worker sind für dieses Projektprofil (kleines
Team, variable/geringe Last, kein bestehender Cloud-Vertrag) die
pragmatischsten Startpunkte — minimaler Betriebsaufwand, Kosten skalieren
mit tatsächlicher Nutzung, und beide bieten einen verwalteten
Secret-Speicher für den KI-API-Key. Eine endgültige Entscheidung wird erst
zu Beginn von Phase 2 getroffen, mit aktuellen Preisen/Limits zum
tatsächlichen Umsetzungszeitpunkt erneut geprüft (dieses Dokument ist auf
dem Stand 2026-11-06).

## Was dem Implementierungsplan überlassen bleibt

- Exakte Typnamen/Signaturen für `CardioVolumeOverTimeAggregator`,
  `RaceProgressAssessment`, `RaceProgressDueCalculator`.
- Exakte Schwellenwerte für "attentionNeeded" vs. "onTrack" — Ankerpunkt ist
  die bestehende 10-%-Rampenregel aus `CardioFeasibilityCalculator`, keine
  neue Zahl.
- Exakte Feldnamen auf `UserBodyProfile`.
- Vollständige Testliste je Szenario aus dem Ticket (15 Fälle,
  Mock-Daten-basiert, rein lokal — keine KI-Mocks nötig, da Phase 1 keine
  KI enthält).
- UI-Detailgestaltung der neuen Karte/Detailansicht.
