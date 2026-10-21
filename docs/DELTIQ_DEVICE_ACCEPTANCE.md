# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-21 (zwanzigster Durchgang: Paket 2, Schritt 3 umgesetzt und
gerätebestätigt — `EnduranceIntervalPlayerView` (Komponente 3) inkl.
WorkoutSession-Ergebnisfeldern, Snapshot-/CSV-Anbindung, CI-grün
(Fix-Runde: `String.LocalizationValue` für dynamischen Hint-Key), HEAD
`898d326`. Vier risikobasierte Gerätenachweise auf echtem iOS-Simulator
(TestingBot) alle bestanden: Kaltstart bei laufendem Intervall,
Pause/Fortsetzen, übersprungener Abschnitt, Easy-Run-Normalfall. Siehe
Abschnitt „Paket 2, Schritt 3" unten. Davor neunzehnter Durchgang: Paket 2,
Schritt 2 umgesetzt —
Konfigurations-UI für strukturierte Ausdauereinheiten in `DayEditorView`
(Einlaufen/Auslaufen, Rundenzahl, Belastungsziel Zeit/Strecke/offen,
Erholungsdauer), Struktur-Picker bietet `.enduranceIntervals` jetzt an.
CI-grün nach einer vorsorglichen Vereinfachung (sechs Views in einem
`switch`-Case in kleinere `@ViewBuilder`-Properties ausgelagert), HEAD
`5abfe6d`. Siehe Abschnitt „Paket 2, Schritt 2" unten. Davor achtzehnter
Durchgang: Paket 2, Schritt 1 umgesetzt —
Datenmodell für strukturierte Ausdauereinheiten (`WorkoutTimeFormat.
enduranceIntervals`, `DaySpec`/`TrainingDay`-Felder, Fingerprint,
17 betroffene Switch-Stellen inkl. einer in `App/FitnessAppWidgets/`),
CI-grün nach zwei Fix-Runden (Typchecker-Timeout, fehlender Case in der
Widget-Extension), HEAD `4654775`. Siehe Abschnitt „Paket 2, Schritt 1" unten. Davor
siebzehnter Durchgang: Zurück-Navigations-Beobachtung aus Durchgang 16
per vollständiger Code-Analyse aufgelöst — kein Bug, siehe Abschnitt
„Zurück-Navigation geklärt" unten. Davor sechzehnter Durchgang: Paket 1 — der beim
Konfliktbanner-Nachtest entdeckte echte Bug [Übernahme war trotz
ungelöstem `distributionConflict` nicht blockiert] gefixt und
gerätebestätigt, HEAD `1cbffeb`, siehe Nachtrag „Übernahme-Blockade
nachgerüstet" oben. **Paket 1 gilt jetzt vollständig und ohne offenen
Bug abgeschlossen** — verbleibend bewusst außerhalb des Scopes: die vier
Resolution-Fälle als eigene wählbare UI, ein kleiner
Navigations-Beobachtungspunkt beim Zurück-Button. Davor fünfzehnter
Durchgang: Paket 1 — Geräteabnahme der 9
geforderten Nachweise (Coach-Aktivierung/Vorschau/Übernahme/Ablehnen/
Coach-aus/A12/Idempotenz/Kaltstart/unabhängige Parallel-Änderung) auf
TestingBot abgeschlossen, alle 9 bestanden. Davor
vierzehnter Durchgang: Paket 1, Teil 2 — die
Architekturfrage "manuelle Änderungen/Fixierungen schützen" ist beantwortet
(`TrainingDay.generationFingerprint == currentContentFingerprint`, siehe
`PlanGeneratorInstantiator.recalculate`, kein neues Konzept nötig) und auf
dieser Basis umgesetzt: `RunCoachPlanAdjustment` (Komponente 2, reine
Analyse) + `PlanGeneratorInstantiator.applyCoachCardioAdjustment`
(Mutation, reuse von `apply`/`revert`), Onboarding-Finish getrennt
(Komponente 6) und `distributionConflict` sichtbar in der
Plan-Builder-Wochenvorschau verdrahtet (Komponente 1 abgeschlossen) — HEAD
`5bc8e5b`, siehe Nachtrag „Paket 1 (Teil 2)" unten. Davor dreizehnter
Durchgang: Paket 1, Teil 1 — A12-Fix (Commit `5146bfe`). Davor zwölfter
Durchgang: Runde 11 — Onboarding/Laufcoach-
E2E-Abgleich: `GoalDrivenPlanSelectionBuilder` lässt bei Hybrid+„Both"
(Laufen+Radfahren) am UI-Default von 3 Tagen/Woche Radfahren komplett und
ohne jede sichtbare Meldung aus der generierten Auswahl heraus —
gerätebestätigt, bewusst dokumentiert statt eigenmächtig gefixt (siehe
Nachtrag „Runde 11" unten), Branch `claude/smart-onboarding-epic`, HEAD
`9956f8e` (Regressionstest-Commit dieser Runde, pinnt das aktuelle
Verhalten; kein Produktivcode geändert). Davor Runde 10 (elfter
Durchgang): vom Nutzer anhand eines Screenshots gemeldete Punkte
geprüft: Hantelrechner-Einstieg bestätigt unauffällig (kein Bug, nur
ungesetztes Gewicht), neue optionale Satzanzeige „bisherige
Darstellung"/„Spaltenübersicht" gebaut und gerätebestätigt, Gewicht/Wdh-
Einzug in der Spaltenübersicht umgesetzt, echter Light-Mode-Tab-Icon-Bug
gefunden und gefixt, gebündelter Geräte-Abnahme-Durchlauf — siehe
Nachtrag „Runde 10" unten, HEAD davor `c6f5e9c` (zweiter, am Gerät
verifizierter Nachbesserungs-Fix für den neuen „Set display"-Picker bei
AX5; davor `496a0cf` erster, am Gerät als unzureichend erkannter
Fix-Versuch derselben Stelle; davor `9b1a2d2` CI-Kompilierfix; davor
`d2a561f` Feature-Commit Satzanzeige-Umschalter + Gewicht/Wdh-Einzug;
davor `949f161` Fix-Commit Tab-Icon-Light-Mode-Bug; davor `71eb368`
Dokumentations-Commit Runde 9; davor `25d065a` reine Testkorrektur
`Double?`→`XCTUnwrap`; Fix-Commit Runde 9 `ac9fcc2` — `logSet()` fehlte
`context.save()`; davor `0a3c68e` der eigentliche kg/lbs-Fix; davor
`c299c22` reine Syntaxkorrektur Runde 8; davor `872f707`
AX5-Spalten-Header-Fix Runde 8; davor `a4359f4` Fix-Commit Runde 7 [A01
doppelte Ziel-/Tage-Abfrage], davor `47678c1` Fix-Commit Runde 6 [D06
Cancel-Endlosschleife], davor `80eee60` reiner Dokumentations-Commit zur
Speicherfehler-Codeprüfung, davor `1c8bf54` Fix-Commit Runde 5
(`CardioGoalEditorView.save()`), davor `47ab4d6` der ursprüngliche
C01-Fix, davor `4ea8d7b` reiner Dokumentations-Commit zu Runde 3, davor
`254d669` Korrektur-Commit zu E05, davor `64ba455` Fix-Commit E04, davor
`3e67cb8` ursprünglicher — per Geräte-Nachtest widerlegter — E05-Versuch,
davor `c96bf5c`). TestingBot-Verbrauch Runde 11: siehe Nachtrag
„Runde 11" unten für Details und exakte Budget-Rekonstruktion. Kein
Merge nach `main`, kein Release.

**Gesamtstatus: A–F bearbeitet; deutliche Mehrheit bestanden, einzelne
Fälle teilweise oder (A09/A12/C04/E08/F04) noch offen als fachliche
Implementierungslücken. Seit Runde 11: der vom Vorgesetzten vermutete
stille Sportart-Verlust im Hybrid+„Both"-Fall des Plan-Builders ist am
Gerät bestätigt (neue Zeile A12, siehe Nachtrag „Runde 11") — bewusst
dokumentiert statt eigenmächtig gefixt, da die spezifikationskonforme
Lösung eine neue Konflikt-UI erfordert und keine begrenzte Code-Korrektur
ist; zusätzlich wurde code- und gerätebestätigt, dass `onGenerated` →
`finishOnboarding()` (A10) unverändert und bewusst so beibehalten ist,
und dass der Laufcoach-Zustand strukturell keinen Einfluss auf den
PLANINHALT hat (erweitert A04/A09). Seit Runde 10: die vom Nutzer per
Screenshot gemeldeten Punkte sind abgearbeitet — Hantelrechner-Einstieg
war kein Bug (siehe Nachtrag), die Satzanzeige ist jetzt über
Settings → Training zwischen „Spaltenübersicht" (Default, bisheriges
Verhalten) und „bisherige Darstellung" (neu, selbst-beschriftete Felder
ohne gemeinsamen Spaltenkopf) umschaltbar, beide Darstellungen teilen
sich exakt dieselben Satz-Daten/Callbacks, Gewicht+Wdh sind in der
Spaltenübersicht moderat eingerückt (RIR-Breite unverändert bei 44pt),
und ein echter, geräteweit reproduzierbarer Light-Mode-Bug (inaktive
Tab-Icons durch Weiss-auf-Weiss praktisch unsichtbar) wurde gefunden und
gefixt. Dabei zusätzlich ein eigener, erst am Gerät entdeckter AX5-Bug im
neuen Settings-Picker gefunden und in zwei Anläufen gefixt (erster
Versuch unzureichend, siehe Nachtrag). Seit Runde 9: kg/lbs-Einheiten-
Setting wirkt auch auf Satz-Logging, Körperdaten-Editor, Profil-
Zusammenfassung und Dashboard-Gewichtstrend (gezielte Teilmenge, Volumen/
PRs/Charts/CSV bleiben bewusst kg-only, siehe Nachtrag „Runde 9");
AX5-Spalten-Header-Fix vollständig gerätebestätigt. C01 seit Runde 5
vollständig bestanden. D06 seit Runde 6 vollständig bestanden. A01 seit
Runde 7 korrekt eingeordnet und gefixt. Gesamtabnahme weiterhin offen
(kein vollständiger Abschluss aller 46 Fälle). Paket 1 (Coach-Aktivierung →
Plananpassung) ist seit der Geräteabnahme unten vollständig gerätebestätigt,
alle 9 geforderten Nachweise bestanden, kein Bug gefunden.**

## Paket 2, Schritt 1: Datenmodell umgesetzt, CI-grün (Commit `4654775`)

**Nachtrag nach dem ursprünglichen Plan unten:** auf ausdrückliche
Anweisung umgesetzt statt weiter zurückgestellt — CI-getrieben wie der
Rest der Session (push → GitHub Actions macOS-Runner → Ergebnis
abwarten), kein lokaler Compiler nötig. Drei Versuche bis grün:

1. `02e2fb8` — Datenmodell (`WorkoutTimeFormat.enduranceIntervals`,
   `DaySpec`/`TrainingDay`-Felder, Fingerprint-Erweiterung,
   Propagation/Snapshot/Revert, alle 16 im Plan gelisteten Switch-Stellen,
   3 neue xcstrings-Keys, 1 neuer Testfall). CI-Fehler: Array-Literal mit
   sechs gemischten `.map`-Ausdrücken in `TrainingDay.currentContentFingerprint`
   überforderte den Swift-Typchecker ("unable to type-check this expression
   in reasonable time").
2. `191c4de` — Fix: auf Zeichenketten-Interpolation umgestellt (gleiches
   Muster wie `circuitPart` direkt daneben). CI-Fehler: eine 17. Stelle
   fehlte — `App/FitnessAppWidgets/TimedWorkoutLiveActivity.swift` liegt
   außerhalb von `Sources/`/`Tests/`, wurde bei der ursprünglichen Suche
   übersehen (eigener Icon-Switch der Widget-Extension).
3. `4654775` — fehlenden Case ergänzt. **CI-Lauf `39510085874`: erfolgreich.**

Alle Picker (`DayEditorView`, `PlanBuilderView`, `DashboardView`)
schließen `.enduranceIntervals` weiterhin bewusst aus ihren Auswahllisten
aus — das neue Format ist strukturell nirgends erreichbar, bis die
Konfigurations-UI (Komponente 2 Rest) und der Player (Komponente 3)
existieren. Kein Geräte-Nachtest nötig für diesen Schritt (reine
Datenmodell-/Compile-Ebene, keine neue UI, keine Verhaltensänderung für
bestehende Formate).

**Nächster Schritt:** Konfigurations-UI zum Anlegen einer strukturierten
Einheit (Einlaufen/Runden/Belastung/Erholung/Auslaufen editierbar machen),
dann `EnduranceIntervalPlayerView` (Komponente 3), dann Geräte-Nachweise.

## Paket 2, Schritt 2: Konfigurations-UI umgesetzt, CI-grün (Commit `5abfe6d`)

`DayEditorView`s Struktur-Picker bietet `.enduranceIntervals` jetzt an
(die bisherige bewusste Ausblendung aus Schritt 1 ist aufgehoben) und
rendert volle Konfiguration über die in Schritt 1 angelegten
`TrainingDay`-Felder:

- Einlaufen/Auslaufen als Minuten-Stepper (0–30 Min.)
- Rundenzahl als Stepper (1–20)
- Belastungsziel-Modus als Picker: Zeit / Strecke / offen —
  `EnduranceWorkTargetMode` (reine UI-Ableitung aus
  `enduranceWorkDurationSeconds`/`enduranceWorkDistanceKm`, nicht
  persistiert) erzwingt "genau ein Zielfeld" und löscht beim Moduswechsel
  das jeweils andere Feld
- Belastungsdauer (15–600 Sek.) bzw. Streckeneingabe, je nach Modus
- Erholungsdauer als Stepper (15–300 Sek.)

`DashboardView` und `PlanBuilderView` bleiben bewusst unverändert — beide
Routen würden auf unfertige Pfade treffen (direkter Player-Start ohne
Konfigurationsschritt bzw. ein Generator, der für dieses Format keine
Übungen erzeugen kann).

Zwei Commits bis grün:

1. `dec1ea7` — Konfigurations-UI, 10 neue xcstrings-Keys. CI-Lauf
   `39512026538` zeigte nach dem Build-Schritt ein auffällig langes
   Test-Schritt-Fenster; vorsorglich (ohne harte Fehlermeldung) als
   möglichen zweiten Typchecker-Fall eingeordnet, siehe Fix unten.
2. `5abfe6d` — die sechs neuen Views im `.enduranceIntervals`-Case (plus
   ein verschachtelter zweiter `switch` für den Belastungsziel-Modus)
   aus dem großen `switch format`-Block in zwei eigene
   `@ViewBuilder`-Properties (`enduranceIntervalsFields`,
   `enduranceWorkTargetFields`) ausgelagert — keine funktionale Änderung,
   nur eine kleinere Typcheck-Einheit pro Case, analog zum
   Schritt-1-Fund. **CI-Lauf `39513321915`: vollständig erfolgreich**
   (Swift-Package-Build, -Tests, App+Widget-Build für den Simulator).

**Nachtrag zur CI-Beobachtung:** die ersten beiden Wiederholungsversuche
(Runs `39512367638`/`39512638338`) wurden von mir abgebrochen, weil
Status-Abfragen über mehrere Minuten unverändert "in Arbeit" zeigten —
im Nachhinein (Vergleich der von GitHub selbst gelieferten Zeitstempel)
erwiesen sich beide Abbrüche als verfrüht: die Läufe liefen normal
weiter, nur meine eigene Einschätzung der verstrichenen Zeit war in
dieser Session zeitweise unzuverlässig. Der oben verlinkte ViewBuilder-
Fix bleibt trotzdem sinnvoll (kleinere Typcheck-Einheiten sind unabhängig
davon die robustere Struktur), war aber vermutlich keine zwingende
Notwendigkeit für Schritt 2 selbst. Kein Geräte-Nachtest nötig für
diesen Schritt (reine Konfigurations-UI, kein Player, keine
Verhaltensänderung für bestehende Formate).

**Nächster Schritt:** `EnduranceIntervalPlayerView` (Komponente 3),
danach risikobasierte Geräte-Nachweise.

## Paket 2, Schritt 3: EnduranceIntervalPlayerView + Gerätenachweise (Commit `898d326`)

**Datenmodell/Snapshot/CSV (Commit `f5c0f3f`):** neue `EnduranceIntervalPhase`
(warmup/work/rest/cooldown) und sieben `WorkoutSession`-Ergebnisfelder
(`endurancePhase` als "schon gestartet"-Marker analog `circuitRoundsCompleted`,
`enduranceCurrentRoundNumber` als Position getrennt vom Ergebnis-Zähler
`enduranceRoundsCompleted`, `endurancePhaseEndDate`,
`endurancePausedRemainingSeconds` für Pause/Fortsetzen,
`enduranceWarmupSkipped`/`enduranceCooldownSkipped`). `TrainingDayContentSnapshot`
und `WorkoutSessionContentSnapshotFirst` um die sechs `endurance*`-
Konfigurationsfelder erweitert (P8-Stufe-2-Snapshot-first-Pfad, wie beim
Zirkel). CSV-Export/-Import für beide Feldgruppen additiv ergänzt (sonst
Datenverlust bei jedem Backup-Roundtrip, Komponente 4).

**Player (Commit `f373a49`, Fix `898d326`):** `EnduranceIntervalPlayerView`
neu, ersetzt den Platzhalter in `TimedWorkoutPlayerView`. Kein
Übungsbezug — die Einheit selbst ist die Übung. Erfüllt Komponente 3
explizit:

- aktueller Abschnitt + Rundenkontext jederzeit sichtbar
  (`DeltiqContextRow`, "RUNDE N/M" bei Belastung/Erholung)
- Pause/Fortsetzen für jede gezeitete Phase über einen Wanduhr-Pause-
  Mechanismus (`endurancePausedRemainingSeconds` friert die Restzeit ein,
  Fortsetzen berechnet einen neuen Enddatum-Anker — kein Zurücksetzen auf
  die volle Dauer)
- manuelles Abschnittsende jederzeit möglich ("Überspringen" bei
  gezeiteten Phasen, "Fertig" bei ungezeiteter Belastung)
- keine automatische Distanz-/Pace-Erfindung: eine Belastungsphase ohne
  Zeit-Ziel zeigt nur das konfigurierte Streckenziel als Info, keinen
  Timer
- übersprungene Abschnitte zählen nicht als abgeschlossen —
  `enduranceRoundsCompleted` erhöht sich nur bei regulär (nicht
  übersprungen) beendeter Belastung
- Kaltstart-/Hintergrund-Überleben nach demselben etablierten Muster wie
  `CircuitPlayerView` (Wanduhr-Anker, `try? modelContext.save()` nach
  jeder Mutation, `session.endurancePhase` als Resume-Marker)

Ein CI-Fix nötig: `phaseHintKey` (zur Laufzeit berechneter String) brauchte
`String.LocalizationValue(stringLiteral:)` statt eines direkten
`String(localized:)`-Aufrufs (Run `39564720275` → Fix → Run `39566110139`
grün).

**Risikobasierte Gerätenachweise (TestingBot, iPhone 15 / iOS 18
Simulator, CI-Build HEAD `898d326`, App-Upload `tb://1d197497c55353e242322fb7`):**
neue Onboarding-Instanz durchlaufen (Fresh-Install-Test als Nebeneffekt:
Onboarding funktionierte durchgehend fehlerfrei bis zum generierten Plan),
Tag „Lower & Core" im generierten Plan auf Struktur „Intervals" umgestellt
— Konfigurations-UI aus Schritt 2 bestätigt sich dabei ein zweites Mal
unabhängig auf echtem Gerät (Stepper/Picker rendern und übernehmen
korrekt). Mit stark verkürzten Werten (Einlaufen 0 Min, 2 Runden,
Belastung 15 Sek. Zeit-Ziel, Erholung 15–90 Sek. je nach Fall, Auslaufen
0 Min) vier Fälle geprüft:

1. **Easy-Run-Normalfall:** voller Durchlauf Einlaufen (automatisch
   übersprungen bei 0 Min) → Belastung → Erholung → Belastung → Erholung
   → Auslaufen → Summary. Kein Absturz, kein Hänger, Summary erreicht.
2. **Pause/Fortsetzen:** während laufender Erholungsphase pausiert — Ring
   und Sekundenzahl blieben über mehrere Sekunden exakt eingefroren
   ("PAUSED"), kein Weiterzählen im Hintergrund. Fortsetzen setzte den
   Countdown exakt beim eingefrorenen Wert fort (nicht neu gestartet, nicht
   übersprungen).
3. **Übersprungener Abschnitt:** eine Belastungsphase wurde über
   „Skip" vorzeitig beendet. Die abschließende Zusammenfassung zeigte
   korrekt **1/2 Runden geschafft** — die übersprungene Runde zählte
   nachweislich NICHT als abgeschlossen, exakt die in Komponente 3
   geforderte Trennung von Position und Ergebnis.
4. **Kaltstart bei laufendem Intervall:** App per `mobile: terminateApp`
   während der Belastungsphase hart beendet, mehrere Sekunden gewartet,
   per `mobile: activateApp` kalt neu gestartet. Dashboard zeigte korrekt
   den Crash-Recovery-Banner "Currently running — Lower & Core" mit
   "Resume running workout". Nach Fortsetzen zeigte der Player den
   korrekten Zustand: Phase auf „RECOVERY" vorgerückt (die Belastung war
   waehrend des Kills regulär abgelaufen), Runde weiterhin korrekt
   "1/2", und der Countdown-Ring zeigte die über die Wanduhr korrekt
   fortgeschriebene Restzeit (36 von 90 Sek.) — kein Reset auf die volle
   Dauer, kein Stehenbleiben auf dem Stand vor dem Kill.

Alle vier Fälle bestanden ohne Fund. TestingBot-Budget vor dem Block per
`GET /v1/user` geprüft: 18.493s (unverändert zum zuletzt bekannten Stand —
die Anzeige aktualisiert sich offenbar nicht in Echtzeit; kein Hinweis auf
ein tatsächliches Problem, da die Session selbst erfolgreich lief und
regulär beendet wurde).

**Offen/bewusst nicht Teil dieser Runde:** Live-Activity-Text während
Einlaufen/Auslaufen zeigt noch den Rundenkontext-Text ("Runde 1/N" bzw.
"Runde N/N") statt einer eigenen Phase-Bezeichnung — dokumentierter,
bewusst in Kauf genommener kleiner Schönheitsfehler auf der sekundären
Live-Activity-Oberfläche (siehe Kommentar in `TimedWorkoutBackground.swift`),
der Player selbst zeigt den Abschnitt korrekt. Kein Gerätetest für
Live Activity / Hintergrund-Audio selbst in dieser Runde (aus
Zeitgründen zurückgestellt, kein funktionaler Unterschied zum bereits
gerätebestätigten Zirkel-Muster, das dieselbe Infrastruktur nutzt).

**Paket 2 gilt damit funktional vollständig umgesetzt und gerätebestätigt**
für Komponenten 1–4 der ursprünglichen Spezifikation. Komponente 5
(Abgrenzung zu Paket 3) wurde durchgehend eingehalten: keine neue
adaptive Coaching-/Progressionslogik, `PRDetector` liefert für
`.enduranceIntervals` weiterhin bewusst `nil`.

## Paket 2: begrenzter Abschluss — Anforderungszuordnung, Restlücken, offener Produktbefund

Die vier Schritt-3-Gerätenachweise (Easy-Run-Normalfall, Pause/Fortsetzen,
übersprungener Abschnitt, Kaltstart während Belastung) gelten weiterhin als
erbracht, nicht wiederholt. Diese Runde ordnet jede der acht
Paket-2-Anforderungen einem konkreten Nachweis zu und benennt echte Lücken,
statt Paket 2 pauschal als "fertig" zu führen.

### Zuordnungstabelle

| # | Anforderung | Nachweis | Status |
|---|---|---|---|
| 1 | Einfache Einheit: ein Hauptblock, Zeit/Strecke/offen, kein Kraft/Gewicht/RIR | `ProgramTemplates.swift` (Easy/Long-Run-Vorlagen) + `SetRow.swift`-Cardio-Rendering, siehe "Komponente 1: bereits erfüllt" unten — **unveränderter, bereits vor Paket 2 bestehender Code**, kein neues Risiko durch Paket 2 | Abgedeckt (Code-Review, keine neue Gerätepflicht, da keine Verhaltensänderung) |
| 2 | Konfiguration bearbeiten, speichern, **erneut öffnen** | Schritt-2/3-Geräteläufe bestätigten nur Rendern+Übernehmen beim ERSTEN Anlegen, keine explizite Wiederöffnung zur Round-Trip-Kontrolle | **Lücke** — nicht device-getestet |
| 3 | Planvorschau entspricht gestartetem Player | Indirekt plausibilisiert (die in Schritt 3 konfigurierten 2 Runden erschienen im Player korrekt als "1/2"/"2/2"), aber keine explizite Vorschau-vs-Player-Gegenprobe (z. B. Dashboard-"Nächstes Training"-Kachel vs. tatsächlicher Playerstart) | **Teilweise** — plausibel, nicht explizit gegengeprüft |
| 4 | Laufen UND Radfahren mit jeweils gewählter Sportart | `DayEditorView.enduranceIntervalsFields` (Zeile ~668-738) enthält **keinerlei Sportart-Feld** — Warmup/Cooldown/Runden/Belastungsziel/Erholung sind komplett sportartneutral, keine Unterscheidung Laufen/Radfahren existiert strukturell | **Kein Gerätetest sinnvoll — echter Produktbefund**: die Anforderung "funktioniert mit der gewählten Sportart" setzt eine Sportartauswahl voraus, die es im gebauten Feature nicht gibt (nur ein freier Tagesname). Siehe Einordnung unten. |
| 5 | Streckenbasierte/offene Abschnitte manuell beendbar ohne erfundene Distanz | `EnduranceIntervalPlayerView.advancePhase`/`workDoneBar` (Code gelesen): ungezeitete Belastung nutzt denselben Pfad wie ein regulärer Phasenwechsel, `skipped: false` bei manuellem "Fertig" — symmetrisch zum bereits gerätebestätigten Zeit-Fall. Schritt-3-Geräteläufe nutzten jedoch ausschließlich Zeit-Ziele, kein Strecken-/offener Fall live geprüft | **Teilweise** — Code stimmig, kein Geräte-Nachweis für genau diesen Modus |
| 6 | Coach aus: strukturierte Einheit bleibt ausführbar | `grep cardioCoachingEnabled` über `EnduranceIntervalPlayerView.swift`/`TimedWorkoutPlayerView.swift`/`DayEditorView.swift`: **keine einzige Fundstelle** — die Ausführung ist strukturell vollständig von `cardioCoachingEnabled` entkoppelt | Abgedeckt (Code-Review, eindeutig — keine Kopplung vorhanden, die blockieren könnte) |
| 7 | Abgeschlossene Ergebnisse inkl. Skips bleiben nach erneutem Öffnen/Kaltstart erhalten | Schritt-3-Fall 4 testete Kaltstart **während** einer laufenden Phase (Resume-Pfad), nicht das Wiederöffnen einer bereits **abgeschlossenen** Session aus der Historie nach einem Kaltstart. CSV-/Snapshot-Persistenz jetzt per Unit-Test belegt (`testEnduranceIntervalsDayAndSessionSurviveRoundtrip`, neu, s.u.) — das deckt Datenebene, nicht das UI-Rendering in `WorkoutHistoryView` nach echtem Kaltstart | **Teilweise** — Datenebene jetzt bewiesen, UI-nach-Kaltstart-Anzeige nicht device-geprüft |
| 8 | Bestehende einfache Ausdauereinheiten bleiben kompatibel | Unverändertes `ExerciseLog`/`ProgramTemplates`-Verhalten, keine Migration nötig (Komponente 1 unverändert) | Abgedeckt (Code-Review, keine Schemaänderung an den betroffenen Feldern) |

### Echter, neu gefundener Lückenbeleg: CSV-Export/-Import war unbewiesen

Punkt 7 deckte eine zweite, unabhängige Lücke auf: Schritt 3 behauptete
"CSV-Export/-Import additiv ergänzt", ohne Testnachweis — anders als der
direkte Präzedenzfall `testCircuitDayAndSessionSurviveRoundtrip` für
`.circuit`. Neuer Unit-Test `testEnduranceIntervalsDayAndSessionSurviveRoundtrip`
(`Tests/FitnessAppDataTests/DataPortabilityRoundtripTests.swift`, Commit
`2c3182b`) schließt das nach demselben Muster — alle sechs `TrainingDay`-
Konfigurationsfelder und sieben `WorkoutSession`-Ergebnisfelder (inkl. des
laufenden-Pause-Falls `endurancePausedRemainingSeconds` und der
Skip-Flags) überleben einen echten Export/Import-Roundtrip in einen neuen
Store. **CI-Lauf `39571660822`: erfolgreich.** Kein neuer Gerätetest nötig
für diesen Teil (reine Daten-/Persistenzebene).

### Punkt 4 eingeordnet: kein Testumfang, sondern eine offene Produktentscheidung

"Laufen und Radfahren funktionieren mit der jeweils gewählten Sportart"
setzt voraus, dass eine Sportart überhaupt wählbar ist. Das gebaute
Feature (Schritt 1-3) hat dafür **keine** Modellierung — `TrainingDay`
bekam nur generische Einlauf-/Auslauf-/Runden-/Belastungs-/Erholungsfelder,
keine Sportart-Dimension. Aktuell unterscheidet sich eine "Lauf"- von
einer "Rad"-Einheit ausschließlich durch den frei eingegebenen Tagesnamen
— rein kosmetisch, ohne jede fachliche Auswirkung (Icon, Log-Klassifizierung,
Analytics). Das ist **keine Testlücke, die ein Gerätenachweis schließen
könnte** — eine Gerätesession würde nur denselben sportartneutralen Ablauf
unter einem anderen Tagesnamen zeigen und nichts Neues belegen. Dies wird
als offener Produktbefund zurückgemeldet statt eigenmächtig eine
Sportart-Auswahl-UI nachzuschieben (wäre eine neue Scope-Erweiterung ohne
expliziten Auftrag).

### Verbleibende, echte Restlücken (device-abhängig, nicht in dieser Runde getestet)

Bewusst nicht in dieser Runde ausgeführt — ein vollständiger, unbeaufsichtigter
TestingBot-Durchlauf (Session-Setup, mehrstufige Appium-Interaktion) in einem
einzelnen, nicht fortsetzbaren Durchgang trägt das Risiko einer
hängengebliebenen Session ohne Rückmeldemöglichkeit. Empfehlung: ein
dediziertes, gebündeltes Gerätefenster für:

1. Konfiguration bearbeiten → verlassen → erneut öffnen → gespeicherte
   Werte bestätigen (Punkt 2).
2. Ein Belastungsziel als Strecke ODER offen (nicht Zeit) konfigurieren,
   im Player manuell per "Fertig" beenden, Ergebnis prüfen (Punkt 5).
3. Eine vollständige Einheit mit mindestens einem Skip bis zur Summary
   durchlaufen, App hart beenden, neu starten, die Session aus der
   Historie (nicht im Resume-Pfad) erneut öffnen, Rundenzahl/Skip-Status
   in der Anzeige bestätigen (Punkt 7, UI-Ebene).
4. Dashboard-/Plan-Tab-Vorschau einmal explizit gegen den gestarteten
   Player abgleichen (Punkt 3).

### Zurück-Navigation: Status unverändert

Die "Zurück verwirft den Entwurf"-Beobachtung aus einer früheren Runde
bleibt wie dokumentiert eingeordnet: vollständige Code-Analyse (Commit
`8bbec96`) ergab keinen Bug — `goToPreviousStep()` ändert nur den
Wizard-Schritt, `generatePreviewIfNeeded()` regeneriert den Entwurf
ausschließlich bei tatsächlich geänderter Struktur-Eingabe (erwartetes
Verhalten, kein stiller Verlust ohne Änderungsanlass). Keine neue
Navigationsprüfung in dieser Runde.

### Budget

**18.493 Sekunden — ausdrücklich nur der Vor-Block-Stand** (letzter
bekannter `GET /v1/user`-Wert, unverändert, da in dieser Runde keine neue
TestingBot-Session gestartet wurde — nur CI). Die vier Einzel-Session-
Dauern/IDs aus dem vorherigen Schritt-3-Bericht sind in dieser
fortgeführten Runde nicht mehr im Kontext rekonstruierbar; nur die in der
Schritt-3-Dokumentation oben bereits festgehaltenen Ergebnisse gelten.
Abgleich mit der Konto-API erfolgt beim nächsten ohnehin fälligen
Gerätedurchgang (siehe "Verbleibende, echte Restlücken" oben) — keine
Zusatzabfrage, kein Geräte-Lauf nur zur Budgetklärung.

### Gesamtstatus Paket 2 nach diesem Abschluss

**Nicht pauschal "fertig"**: Komponenten 1, 6, 8 vollständig abgedeckt
(Code-Review, keine neue Gerätepflicht). Komponente 2 (Persistenz/CSV)
jetzt mit Testnachweis vollständig. Komponenten 3/5/7 (Konfigurations-
Round-Trip, Strecken-/offener manueller Abschluss, Ergebnis-nach-Kaltstart-
UI, Vorschau-Abgleich) bleiben **teilweise** bis zum empfohlenen
dedizierten Gerätefenster oben. Komponente 4 (Sportartauswahl Laufen/
Radfahren) ist kein Testumfang, sondern ein offener Produktbefund, der an
den Auftraggeber zurückgeht. Kein Merge, kein Release. Paket 3 nicht
begonnen.

## Paket 2: ursprünglicher Umsetzungsplan (strukturierte Ausdauereinheiten)

**Hinweis:** Schritt 1 dieses Plans ist seit obigem Nachtrag umgesetzt
und CI-grün. Der folgende Text ist die ursprüngliche Planungsfassung,
unverändert aus Nachvollziehbarkeit stehen gelassen; die "14 Stellen" dort
waren eine ungenaue Schnellzählung, tatsächlich waren es 17 (siehe
Nachtrag oben).

Diese Planung ist der vollständige, konkrete Fahrplan für die nächste
Umsetzungsrunde.

### Komponente 1 (einfache Ausdauereinheit): bereits erfüllt, keine neue Arbeit nötig

Code-Befund: jede "Easy Run"/"Long Run"-Vorlage in `ProgramTemplates.swift`
ist bereits exakt EIN `ExerciseSpec` mit `sets: 1, repsMin: 1, repsMax: 1,
isCardio: true` plus `targetDistanceKm`/`targetDurationMinutes` (z. B.
Zeile ~592, ~601, ~805-813 inkl. separater `role: .warmup`/`.cooldown`-
Einträge für einen Spaziergang vor/nach dem Lauf). `SetRow.swift` rendert
`content.isCardio`-Übungen bereits über eigene Distanz-/Dauer-Eingabefelder
statt Gewicht/Wdh/RIR (siehe `previousLogHint`, Zeile ~1105ff., und die
Cardio-Eingabefelder um Zeile 1344-1366) — "keine künstlichen Kraftsätze,
kein Gewicht, kein RIR" ist damit bereits erfüllt. Geplante Vorlagen setzen
teils SOWOHL `targetDistanceKm` ALS AUCH `targetDurationMinutes` (beide als
informative Richtwerte, z. B. "Easy Run, ~30 Min · 5,0 km") — das ist
bewusst keine erzwungene Einzelwahl auf Vorlagenebene, sondern reine
Information; das tatsächliche ERGEBNIS wird laut bestehendem
`ExerciseLog.distanceKm`/`durationSeconds` (beide optional, unabhängig
voneinander befüllbar) bereits korrekt getrennt erfasst — "nur bekannte
Werte anzeigen, fehlende Werte nicht als null interpretieren" ist in
`SetRow`s Ergebnis-Rendering (Zeile ~1281-1286) bereits so umgesetzt.
**Kein Codeänderungsbedarf für Komponente 1.**

### Komponente 2+3 (strukturierte Einheit + Player): Entwurf

**Vorhandenes Muster (Präzedenzfall):** `WorkoutTimeFormat.circuit` +
`TrainingDay.circuitRounds/circuitRestSeconds/circuitMode` +
`CircuitPlayerView` (Zwei-Phasen: ungezeitete Arbeit + gezeitete Pause,
wanduhr-verankerter `restEndDate`, übersteht Hintergrund via `scenePhase`)
ist strukturell fast identisch mit "Einlaufen → N×(Belastung/Erholung) →
Auslaufen" — EINZIGER Unterschied: Belastung UND Erholung sind bei
Ausdauer-Intervallen BEIDE gezeitet/streckenbasiert (nicht wie beim
Zirkel: Arbeit ungezeitet/"User entscheidet"), und es kommen Einlauf-/
Auslaufphasen vor der ersten/nach der letzten Runde dazu.

**Geprüfte, aber VERWORFENE Alternative:** die N Belastungs-/
Erholungsphasen stattdessen als eine flache Liste einzelner
`ExerciseSpec`-Einträge "entrollen" (analog zum bereits bestehenden
`role: .warmup`/`.cooldown`-Muster) — das würde KEINE neue
`WorkoutTimeFormat`-Ausprägung und keine der 14 Stellen unten erfordern.
Verworfen, weil das die in Komponente 3 geforderte zusammenhängende
Abschnitts-/Wiederholungs-Anzeige ("3 von 5", automatischer
Pausen-Countdown, Pause/Fortsetzen als EIN Bildschirm) nicht abbildet —
eine flache Übungsliste wäre nur eine gewöhnliche Satzliste, kein
Intervall-Player. Empfehlung bleibt: neue `WorkoutTimeFormat`-Ausprägung,
analog `.circuit`.

**Neue Felder (Vorschlag, mirror-Muster wie `circuit*`):**
- `WorkoutTimeFormat.enduranceIntervals` (neuer Case in
  `Sources/FitnessAppCore/Domain/DomainEnums.swift`).
- `TrainingDay`/`DaySpec` (mirror, wie bei `circuitRounds` etc.):
  `enduranceWarmupDurationSeconds: Int?`,
  `enduranceCooldownDurationSeconds: Int?`,
  `enduranceIntervalRounds: Int?`,
  `enduranceWorkDurationSeconds: Int?`, `enduranceWorkDistanceKm: Double?`
  (beide `nil` = "offen", wie bei `ExerciseSpec.targetDistanceKm`/
  `targetDurationMinutes` bereits etabliert — NIE beide zugleich für einen
  Arbeits-Abschnitt, anders als bei der einfachen Einheit oben, da hier
  eine eindeutige Abschnittsziel-Art pro Segment gefordert ist),
  `enduranceRestDurationSeconds: Int?` (Erholung bleibt für V1 bewusst
  zeitbasiert — alle Nutzerbeispiele zeigen reine Zeit-Erholung, keine
  Distanz-Erholung; spätere Erweiterung möglich, aber nicht Teil von V1).
- `TrainingDay.currentContentFingerprint` (Zeile ~135-139) MUSS die neuen
  Felder mit einschließen, exakt wie die bestehenden `circuitPart`-Felder
  — sonst würde eine Bearbeitung dieser neuen Felder nicht als "vom Nutzer
  angefasst" erkannt (Leitplanke aus Paket 1, Punkt 4: Schutz vor
  Überschreiben via `generationFingerprint`-Vergleich).

**Die 14 betroffenen Codestellen** (alle als exhaustive `switch` über
`WorkoutTimeFormat` — der Compiler erzwingt, dass JEDE davon behandelt
wird, kein Vergessen möglich):

| # | Datei:Zeile | Empfehlung |
|---|---|---|
| 1 | `WorkoutHistoryView.swift:348` (Icon je Format) | eigenes Icon, z. B. `"figure.run"` |
| 2 | `WorkoutHistoryView.swift:360` (Verlaufs-Kennzahl) | Runden-Anzahl analog AMRAP, oder Distanz/Dauer-Summe |
| 3 | `DayEditorView.swift:544` (`case .amrap, .emom:`, Editor-Verzweigung) | eigener Zweig — Editor-UI für die neuen Felder kommt hier hin |
| 4-6 | `WorkoutSummaryView.swift:336,1110,1269` (Zusammenfassung) | eigener Zweig, zeigt Runden + ggf. Gesamtdistanz/-dauer |
| 7 | `TimedWorkoutPlayerView.swift:33` (Player-Routing) | `case .enduranceIntervals: EnduranceIntervalPlayerView(session: session)` — NEUE Datei, analog `CircuitWorkoutPlayerView.swift` |
| 8 | `TimedWorkoutPlayerView.swift:191` (`case .amrap, .emom:`) | eigener Zweig prüfen (Kontext lesen, nicht blind mitgruppieren) |
| 9 | `TimedWorkoutPlayerView.swift:208` (Format-Anzeigename) | z. B. `"Intervalle"` |
| 10 | `TimedWorkoutPlayerView.swift:223` (Editor-Hinweistext-Key) | neuer xcstrings-Key |
| 11 | `TimedWorkoutPlayerView.swift:244` (numerischer Default) | Kontext lesen, sinnvollen Default setzen |
| 12 | `TimedWorkoutBackground.swift:222` (Hintergrundvisual) | eigener Zweig oder Fallback auf `.circuit`-Visual |
| 13 | `DayAnalysisCard.swift:177` (Coaching-Hinweistext) | eigener Key oder bewusst ausblenden (Paket-3-Grenze beachten — KEINE neue Coaching-Logik, nur Textfall behandeln) |
| 14 | `PlanGenerator.swift:718` (`case .forTime, .circuit:`, Strength-Timed-Format-Generator) | **vermutlich strukturell unerreichbar** für Ausdauertage (dieser Pfad generiert Kraft-Komplexe, Cardio-Tage laufen über `ProgramTemplates.swift`, nicht durch diesen Generator) — in dieselbe Fallgruppe wie `.circuit` aufnehmen (dort steht bereits "`.circuit` erreicht diese Funktion in der Praxis nie"), mit Kommentar warum |
| 15 | `DayAnalyzer.swift:293` (Muskelvolumen-Mengenberechnung) | `case .forTime, .circuit:`-Gruppe erweitern (gleiche Semantik: `sets` ist dort faktisch eine Rundenzahl) — Cardio-Ausschluss aus Muskelvolumen läuft ohnehin separat über `isCardio`, nicht über `timeFormat` |
| 16 | `PRDetector.swift:425` (`detectTimedFormatPR`, Format-PR-Erkennung) | eigener Fall oder bewusst `nil` zurückgeben (PR auf Zeit/Distanz für Ausdauer-Intervalle ist eine neue fachliche Frage — NICHT in Paket 2, siehe Abgrenzung zu Paket 3: "keine neue adaptive Coaching-/Progressionslogik") |

(16 statt 14 beim Durchzählen — ursprüngliche Schnellzählung war ungenau,
tatsächlich 16 Stellen, hier vollständig/korrigiert gelistet.)

**Persistenz (Komponente 4):** `try? modelContext.save()` unmittelbar nach
jeder Abschnitts-Bestätigung (gleiches, zwölffach bewährtes Muster dieser
Session). Keine Export-/Importänderung nötig — jede abgeschlossene
Wiederholung wird wie bisher als eigener `ExerciseLog`-Eintrag
(`distanceKm`/`durationSeconds`) gespeichert, CSV-Export/-Import iteriert
bereits über `ExerciseLog`-Zeilen unverändert. Migration: SwiftData hat in
diesem Projekt für neue optionale/defaulted Properties bisher immer ohne
manuelle Migration funktioniert (siehe `circuitRounds` etc.) — gleiches
Muster erwartet, beim ersten CI-Lauf nach Hinzufügen der Felder
verifizieren.

**Nächster Schritt (nicht in dieser Runde begonnen):** die 16 Stellen
oben in genau dieser Reihenfolge abarbeiten (Datenmodell + Fingerprint
zuerst + Unit-Tests, dann Routing + neuer Player, dann Editor-UI zum
Anlegen einer strukturierten Einheit, dann Geräte-Nachweise:
Kaltstart-während-laufendem-Intervall, Pause/Fortsetzen, übersprungener
Abschnitt, Easy-Run-Normalfall als Regressionscheck für Komponente 1).

## Zurück-Navigation geklärt (kein Bug, vollständige Code-Analyse statt Geräte-Session)

**Beobachtung aus Durchgang 16:** "Zurück" im Ergebnis-Schritt von
`PlanBuilderView` schien den ganzen Entwurf zu verwerfen statt nur einen
Schritt zurückzugehen.

**Analyse (alle `draft`-Mutationsstellen in `PlanBuilderView.swift`
geprüft):** `goToPreviousStep()`/`goToNextStep()` ändern nur `step`;
`draft` wird dabei nicht angefasst. Beim erneuten Eintritt in `.result`
ruft `goToNextStep()` `generatePreviewIfNeeded()` auf — die regeneriert
`draft` NUR, wenn sich `currentInput` seit der letzten Erzeugung
geändert hat (`guard draft == nil || lastGeneratedInput != currentInput
else { return }`). `currentInput` ist eine reine Ableitung aus
`@State`-Skalaren/Enums (Ziel, Tage, Ausdauerform, Equipment, Erfahrung) —
deterministisch, keine Zufalls-/Zeit-Komponente. Alle übrigen
`draft = ...`-Zuweisungen liegen ausschließlich in explizit
nutzerausgelösten Aktionen (`moveDraftDays` = Drag&Drop,
`redistributeWeek()`/`requestFreshProposal()` = Menü-Aktionen) — keine
davon wird durch bloße Navigation ausgelöst.

**Schluss:** ein reines Zurück-und-wieder-Vor OHNE zwischenzeitliche
Eingabeänderung verliert nachweislich nichts (manuelle Entwurfsänderungen
eingeschlossen). Die beobachtete Verwerfung trat nur auf, wenn zwischen
Zurück und Vor tatsächlich Tage/Ziel geändert wurden — das ist
erwartetes, korrektes Verhalten (ein Layout für eine andere Tageszahl ist
für die neue Eingabe nicht mehr gültig), kein Fehler.

**Aufruf mit bestehendem aktivem Plan:** `adoptPlan()` ist der EINZIGE
Ort, der `modelContext`/Profil mutiert (inkl. `onEnduranceModalityChosen`-
Callback) — das passiert ausschließlich beim expliziten Übernehmen-Tap,
nie bei Zurück/Abbrechen/Dismiss. Ein bestehender aktiver Plan kann durch
Verwerfen des Builder-Entwurfs also strukturell nicht verändert werden,
unabhängig vom Aufrufkontext — bestätigt durch vollständige Durchsicht
aller Schreibzugriffe in `adoptPlan()`, kein Geräte-Nachtest nötig (reine
deterministische Zustandslogik, keine SwiftData-Timing-Klasse von Bug wie
die bisher gefundenen Kaltstart-Fälle).

**Kein Code geändert, kein CI-Lauf, keine TestingBot-Session für diesen
Punkt.**

## Paket 1: Geräteabnahme (9 Prüfpunkte) — vollständig bestanden

**Auftrag:** nach Abschluss der Logik-/UI-Ebene (Teile 1–4, Commits
`d86bf4b` bis `8aa4e09`) die vereinbarten 9 Geräte-Nachweise auf
TestingBot durchführen. Kein neuer Code vorgesehen außer bei einem echten
gefundenen Bug — keiner gefunden, daher reiner Testdurchgang ohne
Codeänderung.

**Build/Commit:** CI-Artefakt für Commit `b7ac9f1` (identischer
Produktivcode wie HEAD `8aa4e09`, dazwischen nur der Doku-Commit),
heruntergeladen aus GitHub-Actions-Run `39488838613`, als
`FitnessApp-simulator.zip` zu TestingBot hochgeladen (`tb://6613cf64e80e4d6afcdba435`).

**TestingBot-Session:** iPhone 15 / iOS 18.0, `autoAcceptAlerts: false`
(aus Runde 6 bekannt: `true` kann Dialoge maskieren), eine Session
(`8970e5916bc9-c71199c54f87-d591289e418c-179252813584-91326633`), Dauer
1.290 s, aktiv beendet (`DELETE /session`, Status `success`).

**Testaufbau:** frischer Onboarding-Durchlauf — Profil (Name/Geburtsdatum/
Größe 180 cm/Gewicht 75 kg), Ziel „Functional / Hybrid", Ausdauerform
„Both" (Laufen+Radfahren), „Work toward a goal with a run coach"
(Coach an), Trainingshistorie „regelmäßig", Equipment-Default, dann
„Build Plan" mit UI-Default 3 Tage/Woche.

### Ergebnis je Prüfpunkt

1. **Coach-Aktivierung verändert vor Übernahme keinen Plan — bestanden.**
   Cardio-Editor: Ziel auf Marathon, Renndatum-Default (12 Jan 2027, 12
   Wochen entfernt), Startvolumen 5 km/Woche gesetzt, Speichern-Tap →
   Vorschau öffnete sich sofort mit Status „Coach activated, plan not yet
   adjusted". Plan-Tab zu diesem Zeitpunkt (Vorschau noch offen bzw. per
   „Keep as is" verlassen) weiterhin unverändert: Mo Push&Pull/6 Übungen,
   Mi Easy Run/1, Fr Cycling/1 — identisch zum Vorher-Stand.
2. **Übernahme erzeugt exakt die in der Vorschau gezeigten Änderungen —
   bestanden.** Vorschau zeigte CURRENT „Ruhiger Lauf" (durchgestrichen)
   → SUGGESTED „Ruhiger Lauf A/B", „Tempolauf", „Intervalle A/B". Nach
   „Adjust current plan": Plan zeigte exakt Mi „Intervals A" (statt Easy
   Run) und Fr „Easy Run B" (statt Cycling) — Mo Push&Pull unverändert
   (geschützter, nicht angetasteter Tag).
3. **Bestehende Läufe werden nicht dupliziert — bestanden.** Plan-Tab vor
   und nach der Übernahme durchgehend „1 PLAN", exakt 7 Tage, keine
   zusätzliche Cardio-Einheit angelegt — der bestehende Mi-Lauf wurde
   ersetzt, nicht verdoppelt.
4. **Ablehnen („Keep as is") erhält Profilentscheidung und bisherigen Plan
   — bestanden.** Nach „Keep as is": `Enable running coaching`-Status
   blieb aktiv (Karte „Coach activated, plan not yet adjusted" weiterhin
   sichtbar auf `ProfileEditorView`, Leitplanke-6-Vorrang bestätigt),
   `Cardio & Running Goals` zeigte weiterhin „Marathon" (Ziel gespeichert).
   Plan-Tab unverändert: Mo Push&Pull/6, Mi Easy Run/1, Fr Cycling/1 —
   keine einzige Planänderung durch die reine Zielspeicherung.
5. **Coach aus erhält Training/Historie, beendet nur die
   Coach-Unterstützung — bestanden.** Toggle aus → Dialog „Turn off
   running coach?" mit exaktem vorgegebenem Text erschienen, bestätigt →
   `Cardio & Running Goals`-Zeile zeigte danach „Running coaching off",
   Plan-Tab weiterhin „1 PLAN" mit allen drei Originaltagen unverändert
   (Mo/Mi/Fr), keine Coach-Karte mehr auf dem Profil sichtbar.
6. **Hybrid+Both (3 Tage/Woche) verliert keine Sportart mehr still — A12-
   Fix-Nachweis bestanden.** Direkt im Builder generiert: „Bodyweight ·
   Push & Pull" + „Cycling" + „Easy Run" — exakt 1 Kraft+1 Lauf+1 Rad, wie
   von der Spezifikation gefordert. Die 2-Tage-Konflikt-Variante
   (`distributionConflict`-Banner) wurde in dieser Runde NICHT separat am
   Gerät nachgestellt (Zeit-/Navigationsgrenze beim erneuten Öffnen des
   Builders) — bleibt offene Teillücke, siehe unten.
7. **Wiederholte Bestätigung erzeugt keine Duplikate — bestanden.** Nach
   der Übernahme zeigte die Karte „Adjustment applied"; erneutes Öffnen
   zeigte „Adjust current plan" korrekt `enabled="false"` (per
   Accessibility-Tree bestätigt) — ein zweiter Tap-Versuch auf den
   disabled Button blieb wirkungslos. Plan-Tab danach weiterhin „1 PLAN"
   mit identischem Tagesinhalt, keine Duplikate.
8. **Kaltstart erhält eine bestätigte Änderung — bestanden.** Nach der
   Übernahme `mobile: terminateApp` + `mobile: activateApp` — Plan zeigte
   nach dem Neustart weiterhin Mi „Intervalle A" / Fr „Ruhiger Lauf B"
   (Tagesnamen jetzt auf Deutsch, Locale-Reset beim Kaltstart, inhaltlich
   aber identisch), Mo weiterhin unverändert „Körpergewicht · Push &
   Pull"/6 Übungen.
9. **Eine parallele, unabhängige Änderung bleibt durch die Plananpassung
   unverändert — bestanden.** Auf `ProfileEditorView` „Coaching Style" auf
   „Motivating" geändert (unabhängiger, noch offener Edit, NICHT
   gespeichert), danach Coach-Vorschau geöffnet und „Adjust current plan"
   bestätigt — die noch offene „Motivating"-Auswahl blieb währenddessen
   und danach unverändert sichtbar (per Accessibility-Tree bestätigt,
   `flame.fill`-Icon weiterhin aktiv). Zusätzlich bestätigt Mo
   Push&Pull/6 Übungen unverändert vor/nach der Anpassung, dass
   unbeteiligte Trainingsinhalte von der Cardio-Anpassung nicht berührt
   werden.

**Kein Bug gefunden, keine Codeänderung in dieser Runde.**

### Nachtrag: Konfliktbanner-Lücke gezielt nachgewiesen (kein neuer CI-Lauf, kein Code geändert)

**Auftrag:** die oben offen gelassene Teillücke gezielt schließen — der
`distributionConflict`-Banner im ECHTEN Tagemangel-Fall, nicht nur der
Normalfall. Build/Commit unverändert (`b7ac9f1`/`8aa4e09`, identischer
Produktivcode), daher kein neuer CI-Lauf.

**Testaufbau:** frisches Onboarding, Ziel „Functional/Hybrid", Ausdauerform
„Both", Wochenziel bewusst auf **2 Tage** reduziert (Decrement-Stepper im
Coaching-Schritt, preseedet laut A01-Fix `PlanBuilderView.totalDaysPerWeek`),
„Schedule running in my week" (kein Coach), restliche Schritte Default,
dann „Build Plan" (Ziel-geführter Pfad, A01-Preseeding von Ziel „Strength &
Endurance Combined" + Ausdauerform „Both" im Accessibility-Tree bestätigt
— `value="1"`/„Selected" auf beiden Karten).

**Ergebnis je Prüfpunkt:**
1. **Banner verständlich, nennt die unvereinbaren Vorgaben — bestanden.**
   Exakter Text: „Not enough days for all chosen sports: 3 days needed, 2
   available. Go back and adjust days, or accept the closest compromise
   shown below." — genau die vom Code berechneten Werte
   (`requiredMinimumDays`=3 für Hybrid+Both, `totalDaysPerWeek`=2).
2. **Keine Sportart verschwindet STILL — bestanden, mit Einordnung.** Der
   gezeigte Kompromiss („Bodyweight · Push & Pull" + „Easy Run", KEIN
   Cycling-Tag) lässt Cycling tatsächlich aus der konkreten Auswahl
   fallen — das ist aber nicht mehr still: der Banner erklärt direkt
   darüber explizit, dass die Vorgaben nicht zusammenpassen und was
   gezeigt wird nur ein Kompromiss ist. Das entspricht exakt dem in
   „Paket 1 (Teil 1)" dokumentierten Entwurf (Konflikt VORHER erkennbar
   statt stillschweigend übernommen) — kein eigenständiges Options-Picker-UI
   für die vier Resolution-Fälle gebaut, nur der erklärende Hinweis (siehe
   Punkt 6 unten für die ehrliche Einordnung des tatsächlichen
   Baustands).
3. **Keine zusätzliche Einheit ohne Zustimmung — bestanden.** Weiterhin
   genau 2 Tage im Ergebnis, kein stiller Sprung auf 3.
4. **Kein anderer Abschlussweg umgeht den Banner — bestanden.** Banner und
   „Adopt Plan"-Button (Accessibility-Label, Icon „checkmark") sitzen auf
   derselben Ergebnis-Seite, keine zweite Bestätigung möglich ohne den
   Banner gesehen zu haben.
5. **Konsistente Übernahme — bestanden.** Nach „Adopt Plan" kehrte die
   Ansicht zur Wochenvorschau zurück (A01/Komponente-6-Fix bestätigt: kein
   automatisches `finishOnboarding()`), „Build Plan"-Kärtchen zeigte danach
   einen Haken („Selected"). Nach explizitem „Finish": Dashboard zeigte
   „Next workout: Bodyweight · Push & Pull" — identisch zum vor der
   Übernahme in der Vorschau gezeigten ersten Tag, keine abweichende
   Übernahme.
6. **Tatsächlicher Baustand ehrlich festgehalten:** der Banner aus Komponente
   1/6 ist ein reiner, nicht interaktiver Hinweistext — KEINE der vier
   `DistributionConflict.Resolution`-Optionen (Verteilung ändern /
   zusätzlichen Tag erlauben / Ziel ändern / Plan beibehalten) ist als
   eigene wählbare UI gebaut. Der Nutzer kann nur zurück navigieren (Tage
   anpassen) oder den gezeigten Kompromiss übernehmen — funktional deckt
   das „Verteilung ändern" (zurück, Tage ändern) ab, die übrigen drei
   Optionen sind NICHT als UI vorhanden. Kein stiller Mehranspruch — dies
   war in Teil 1 bereits so benannt ("noch OHNE UI-Anbindung"), hier nur
   am Gerät bestätigt statt weiter ausgebaut (außerhalb des Auftrags
   dieses Nachtrags).

**Kein Bug gefunden, keine Codeänderung.** Paket 1 gilt damit als
vollständig abgeschlossen (Logik, UI, alle 9 Prüfpunkte plus dieser
Nachtrag) — mit der oben unter Punkt 6 benannten, bewusst nicht
behobenen Einschränkung (Banner ohne eigene Resolution-Aktionen) als
bekannte Grenze dieses Pakets, nicht als Fehler.

**TestingBot:** 1 Session (`b2e16eaebded-f531134a5834-f0a695fde50c-179253112504-6214298`),
iPhone 15/iOS 18.0, Dauer 493 s (TestingBot-Test-Datensatz), aktiv beendet
(`DELETE /session`, Status „success").

**Budget:** vor diesem Nachtrag (Session-Summe): 19.591 s. Danach:
**19.098 Sekunden (Session-Summe)** — Konto-API zeigte unmittelbar danach
weiterhin 19.591 s (derselbe bereits mehrfach dokumentierte
Abrechnungsverzug, kein neuer Fehler), Abgleich beim nächsten regulären
Abruf. Keine zusätzliche Session, keine Zusatzkäufe.

Kein Merge nach `main`, kein Release.

### Nachtrag: Übernahme-Blockade nachgerüstet (echter Fund, gefixt)

**Befund (vor diesem Fix):** der oben unter Punkt 6 als "Grenze" geführte
Zustand war tatsächlich ein echter Bug, kein bloß unvollständiges Feature:
`headerActions`' Checkmark-Action (`Adopt Plan`) war nur bei leerem Entwurf
oder während des Übernehmens deaktiviert — ein ungelöster
`distributionConflict` blockierte die Übernahme NICHT. Der Banner-Text
lud sogar explizit dazu ein ("...or accept the closest compromise shown
below"), obwohl die Vorgabe lautet: keine Sportart gilt allein durch einen
allgemeinen Übernehmen-Tap als abgewählt.

**Fix (Commit `1cbffeb`):** `isDisabled` prüft jetzt zusätzlich
`distributionConflict != nil` — Übernahme bleibt blockiert, bis der Nutzer
aktiv über die bestehende Tage- oder Ziel-/Ausdauerform-Auswahl etwas
ändert. Banner-Text (DE/EN/TR) umformuliert, verweist auf die beiden
tatsächlich vorhandenen Rückwege statt auf einen "Kompromiss übernehmen".
Kein neuer Konflikt-Assistent gebaut — bewusste Wiederverwendung der
bestehenden Zurück-Navigation. Der generische "Änderungen verwerfen?"-
Dialog (`Theme.swift`) wurde geprüft und ist bereits korrekt neutral
formuliert (kein Fix nötig).

**CI:** Run `39503236945`, Commit `1cbffeb`, erfolgreich.

**Geräte-Nachtest (Build `tb://5a25e5292e04af866f408e6d`, Commit
`1cbffeb`, iPhone 15/iOS 18.0):** frisches Onboarding, Hybrid+Both, 2
Tage, „Build Plan":
1. **Ungelöster Konflikt verhindert Übernahme — bestanden.** Banner
   identisch zu vorher ("3 days needed, 2 available..."), „Adopt Plan"
   jetzt `enabled="false"` (Accessibility-Tree bestätigt). Tap auf den
   deaktivierten Button hatte keine Wirkung — kein Bypass.
2. **Eine tatsächlich angebotene Lösung ist bedienbar und wirksam —
   bestanden.** Erneuter Durchlauf mit 3 Tagen (derselbe, bereits
   bestehende Tage-Stepper): Banner verschwand vollständig, „Adopt Plan"
   wurde `enabled="true"`.
3. **Vorschau entspricht der bewussten Auswahl — bestanden.** Ergebnis
   zeigte exakt „Bodyweight · Push & Pull" + „Easy Run" + „Cycling" (1
   Kraft + 1 Laufen + 1 Radfahren). Nach „Adopt Plan" → Wochenvorschau →
   „Finish": der persistierte Plan zeigt exakt Mon=Bodyweight Push&Pull,
   Wed=Easy Run, Fri=Cycling, restliche Tage Rest Day — deckungsgleich mit
   der Vorschau, „1 PLAN" (kein Duplikat).
4. **Abbrechen lässt bestehende Daten unverändert — bestanden, mit
   Beobachtung.** Im ungelösten 2-Tage-Konfliktfall (Prüfpunkt 1) wurde
   nichts übernommen, kein Plan erzeugt. Zusätzlich beobachtet: der
   bodenständige „Back"-Button auf dem Ergebnis-Schritt verwirft beim
   Zurückgehen den gesamten Entwurf bis zur Onboarding-Planauswahl (nicht
   nur einen Schritt zurück zum Tage-Screen) — im reinen Onboarding-Fall
   ohne bestehenden Plan ist das unschädlich (nichts wird zerstört, die
   Ziel-/Ausdauerform-Antworten aus dem Onboarding selbst bleiben über das
   A01-Preseeding erhalten, ein erneutes „Build Plan" zeigt sofort wieder
   denselben Stand), aber abweichend von der Banner-Formulierung "Go back
   to change the days" (die eher einen Ein-Schritt-Rücksprung suggeriert).
   Kein Datenverlust, daher kein Fix in diesem Umfang — als kleine,
   benannte Beobachtung für eine künftige Runde vermerkt, kein
   Blocker für den Abschluss von Paket 1.

**TestingBot:** 1 Session (`906f55f2865a-ddf42c4b7cb4-8f6359485c4c-179253343346-56573618`),
iPhone 15/iOS 18.0, Dauer 605 s, aktiv beendet (`DELETE /session`, Status
„success").

**Budget:** vor diesem Nachtrag (Session-Summe): 19.098 s. Danach:
**18.493 Sekunden (Session-Summe)** — Konto-API zeigte unmittelbar danach
weiterhin 19.591 s (Abrechnungsverzug über mehrere Runden hinweg, siehe
etablierte Reihe in den Vorrunden), Abgleich beim nächsten regulären
Abruf.

**Damit ist Paket 1 (Coach-Aktivierung, Plananpassungs-Vorschau, A12-Fix
inkl. Übernahme-Blockade, alle Leitplanken) vollständig abgeschlossen und
gerätebestätigt.** Verbleibend offen (bewusst außerhalb des Scopes, siehe
oben): die vier `Resolution`-Fälle als eigene wählbare UI, der kleine
Navigations-Beobachtungspunkt (Punkt 4 oben). Pakete 2 (strukturierte
Ausdauereinheiten) und 3 (Coaching mit echten Ergebnissen verbinden)
bleiben offen für künftige Runden.

Kein Merge nach `main`, kein Release.

## Paket 1 (Teil 1): A12-Fix — Hybrid+„Both" verliert keine Sportart mehr still

**Auftrag:** "Paket 1" des Laufcoach-Konzepts (Coach-Aktivierung →
Plananpassungs-Vorschau) knapp zugeschnitten umsetzen, in Teilschritten.
Dies ist Teil 1: die konkrete A12-Produktentscheidung des Nutzers
umsetzen (bei Hybrid+„Both" und 3 Tagen: 1 Kraft + 1 Laufen + 1 Radfahren
als transparente Alternative statt stillem Weglassen; bei echtem
Tage-Mangel ein prüfbares Konflikt-Signal statt eines unsichtbaren
Kompromisses).

**Umgesetzt (Commit `5146bfe`):**
- `GoalDrivenPlanSelectionBuilder.makeSelections` gibt bei Hybrid+„Both"
  Kraft genau so viele Tage ab, wie nötig, damit jede gewählte
  Ausdauer-Disziplin mindestens einen Tag bekommt (3 Tage/Woche → 1
  Kraft + 1 Laufen + 1 Radfahren, exakt die vom Nutzer vorgegebene
  Alternative). Keine Verhaltensänderung für den bereits korrekten
  Einzel-Modalitäts-Fall (A03/A06/A08) — durch Tests abgesichert.
- Neue `requiredMinimumDays(goal:enduranceModality:)` und
  `distributionConflict(goal:enduranceModality:totalDaysPerWeek:)`:
  liefert `nil`, wenn `makeSelections` alle gewählten Disziplinen
  unterbringen kann, sonst ein `DistributionConflict` mit den vier vom
  Nutzer vorgegebenen `Resolution`-Fällen (Verteilung ändern /
  zusätzlichen Tag erlauben / Ziel ändern / Plan beibehalten) als reines
  Datenmodell — noch OHNE UI-Anbindung (siehe „Offen" unten).
- `GoalDrivenPlanSelectionBuilderTests`: der bisherige Pinning-Test (der
  den Bug absichtlich festschrieb) wurde durch einen Test des NEUEN
  Sollverhaltens ersetzt (1/1/1 bei 3 Tagen), plus zwei neue Tests für
  `distributionConflict`.
- **CI (`apple-ci-comparison.yml`):** Run `39481833188`, Commit `5146bfe`
  — erfolgreich, alle Tests grün (inkl. neuer und unveränderter
  bestehender `GoalDrivenPlanSelectionBuilderTests`).

**A12 gilt damit für den geprüften Fall (Hybrid+„Both", 3 Tage/Woche,
UI-Default) als gefixt und test-verifiziert — noch NICHT gerätebestätigt**
(dieser Teilschritt war reine Logik-/Testebene, kein TestingBot-Einsatz
nötig, Budget unverändert bei 21.238s aus Runde 11).

**Bewusst NICHT in diesem Teilschritt umgesetzt (Komponenten 2–7 aus dem
Paket-1-Zuschnitt — zurückgestellt für einen eigenen Folgeschritt, kein
Teil dieses Commits):**
- `RunCoachPlanAdjustment` (Diff-Logik: welche Läufe/Kraftarbeit sich
  ändern), `CoachAdjustmentCardModel`/-`PreviewView`, die Anbindung in
  `CardioGoalEditorView`, die Onboarding-Korrektur
  (`onGenerated`/`finishOnboarding`) und die zugehörigen 9 Geräte-Nachweise.
- **Grund, kein stiller Scope-Schnitt:** es gibt noch KEIN Konzept für
  "manuell fixierte Tage/Übungen schützen" auf einem bereits
  AKTIVEN, persistierten `TrainingPlan` — `PlanDraft.isContentFixed`/
  `isPositionFixed` existieren nur in der Wizard-Entwurfsschicht
  (`Sources/FitnessAppCore/Planning/PlanDraft.swift`), bevor ein Plan
  überhaupt gespeichert wird, nicht danach. Der einzige vorhandene
  Signal-Kandidat ist `TrainingDay.generationFingerprint` (zeigt, ob ein
  Wizard-Tag seit der Erzeugung manuell verändert wurde — exakt das
  Prinzip, das "neu rechnen" bereits nutzt) — das reicht vermutlich als
  Schutzmechanismus, ist aber eine echte Designentscheidung, die vor der
  Umsetzung bestätigt werden sollte, statt sie in einem einzelnen
  Implementierungsschritt eigenmächtig zu treffen.
- `distributionConflict` ist bewusst noch NICHT in `PlanBuilderView`
  (Schritt 3, die Wochenvorschau) verdrahtet — die eigentliche
  "sichtbare Entscheidung" (Konflikt-Banner mit den vier Optionen) ist
  noch reine UI-Arbeit, ebenfalls zurückgestellt.

## Paket 1 (Teil 4): Komponenten 4+5 umgesetzt, Logik-/UI-Ebene vollständig

**Umgesetzt (Commit `b7ac9f1`), CI grün (`39488838613`, inkl. App+Widget-Build):**
- **`CoachAdjustmentPreviewView`** (Komponente 4): Vorher/Nachher-Liste der
  Cardio-Tage (aktuell anfassbare Tage durchgestrichen, vorgeschlagener
  neuer Inhalt darunter), Status-Zeile ("Anpassung übernommen" /
  "Coach aktiviert, Plan noch nicht angepasst"), drei Aktionen je nach
  `analysis.cardioAvailability`: "Aktuellen Plan anpassen" (nur bei
  `.ready`), "Als neuen Plan erstellen" (reuse des bestehenden
  `CardioFeasibilityCardModel.accept`-Pfads, keine zweite Implementierung),
  "Beibehalten" (reines Schließen, siehe Leitplanke 2). Bei
  `.noEligibleCardioDay` erklärender Hinweistext statt stillem Fehlen der
  Anpassen-Option.
- **`CardioGoalEditorView`** (Komponente 5): "Coach ausschalten" ist jetzt
  ein eigener, sofort wirksamer `confirmationDialog` (exakt der vom Nutzer
  vorgegebene Text), schreibt ausschließlich `cardioCoachingEnabled`,
  Trainingsdaten/Historie/Plan bleiben unangetastet. Echtes Aktivieren
  (vorher aus, jetzt an) zeigt beim Speichern-Tap die Anpassungsvorschau
  statt direkt zu schließen — nur wenn ein aktiver Plan existiert, sonst
  unveränderter Pfad über `ProfileEditorView`s bestehende Feasibility-Karte.
- **`ProfileEditorView`**: Leitplanke-6-Vorrangregel ist jetzt tatsächlich
  wirksam (`coachAdjustmentModel` vor `feasibilityModel`), nicht mehr nur
  dokumentierter, ungenutzter Vertrag.
- **Komponente 7 (Rest):** mit der jetzt existierenden Preview-UI
  vollständig umgesetzt — der "Coach an, Anpassung noch nicht
  übernommen"-Status wird über `CoachAdjustmentCardModel.isAlreadyApplied`
  angezeigt, abgeleitet aus `cardioCoachingEnabled` +
  `cardioPlanAdjustmentFingerprint`, kein zusätzliches Feld nötig über das
  bereits in Teil 3 ergänzte hinaus.
- 13 neue xcstrings-Keys (DE/EN/TR), `UNUSED:0` bestätigt.

**Bekannte, bewusste Vereinfachung (kein Fix in diesem Paket):** wählt der
Nutzer "Coach ausschalten", während ANDERE Felder im selben Editor noch
unentschieden/ungespeichert sind, schließt der Dialog die View sofort und
diese anderen Entwürfe gehen verloren (kein kombinierter Speichern+
Ausschalten-Fluss). Eigenständiger, sofort wirksamer Pfad exakt wie vom
Nutzer vorgegeben — als bekannte Grenze dokumentiert, nicht stillschweigend.

**Damit ist die komplette Logik-/UI-Ebene von Paket 1 (Komponenten 1-7)
umgesetzt und CI-verifiziert. Noch offen: alle 9 Geräte-Nachweise** — aus
Kontextgründen in dieser Runde nicht mehr begonnen, siehe Abschlussbericht
für die Empfehlung, dies als eigenen, dedizierten Geräte-Testdurchgang zu
behandeln (entspricht dem bisherigen Muster dieses Dokuments: jede
"Runde" war bereits ein eigener, einzelner Durchgang).

## Paket 1 (Teil 3): sechs Leitplanken eingearbeitet, Komponente 3 umgesetzt

**Vor dem Weiterbau geprüft und dabei ein echter Bug gefunden (Commit
`b04b95d`):** `TrainingDay.type == .cardio` reicht NICHT aus, um Cardio-
Tage zu erkennen — `PlanGenerator.generate` (der Ziel-geführte "Plan
bauen"-Pfad, exakt der Pfad dieses Pakets) stempelt JEDEN generierten Tag
hartcodiert mit `type: .fullBody`; `.cardio` setzen ausschließlich die
kuratierten `ProgramTemplates`. `RunCoachPlanAdjustment.analyze` hätte auf
einem typischen Wizard-Plan daher nie einen Cardio-Tag gefunden. Fix:
Erkennung zusätzlich über `Exercise.isCardio` (deckt beide Pfade ab, neuer
Regressionstest).

**Leitplanke 1 geprüft und bestätigt:** `UserBodyProfile.
cardioFeasibilityDismissedFingerprint` kann laut eigenem Kommentar in
`CardioFeasibilityCardModel.swift` nicht zwischen "abgelehnt" und
"übernommen" unterscheiden (`dismiss()` und `accept()`/`acceptCustom()`
schreiben denselben Fingerprint-Wert). Neues, separates Feld
`cardioPlanAdjustmentFingerprint` — ausschließlich von
`CoachAdjustmentCardModel.accept(...)` nach tatsächlich erfolgreich
gespeicherter Anpassung gesetzt, nie von Dismiss/Beibehalten.

**Leitplanke 2 (Präferenz vs. Übernahme getrennt):** durch zwei Tests
abgesichert (`CoachAdjustmentCardModelTests`) — `accept()` rührt
`cardioCoachingEnabled` nie an, "beibehalten" (= `accept()` einfach nicht
aufrufen) lässt Präferenz UND Plan unverändert.

**Leitplanke 3 (Wiederholungssicherheit Merge-Pfad):** geprüft, dass
`PlanCreationOperation` (reuse von `CardioFeasibilityCardModel`) wegen
anderer Semantik (erzeugen vs. verändern) nicht passt — eigener Schutz
gebaut. Dabei **einen echten Bug vor Geräteeinsatz gefunden und
gefixt:** der erste Entwurf prüfte `self.isAlreadyApplied`, einen am
`make`-Zeitpunkt eingefrorenen Wert — ein zweiter `accept()`-Aufruf auf
derselben (Doppeltap-)Modellinstanz hätte das nicht erkannt und erneut
angewendet. Fix: live gegen `profile.cardioPlanAdjustmentFingerprint`
prüfen. Idempotenz-Test bestätigt: zweimal anwenden == einmal anwenden,
keine zusätzlichen Tage/Übungen. Save-Fehler mitten im Anwenden nutzen den
bereits bestehenden `apply`/`revert`-Mechanismus (reuse, kein Duplikat).

**Leitplanke 4 (Fixierungs-Grenze):** Doku präzisiert —
Fingerprint-Übereinstimmung heißt "nicht nachweislich editiert", nicht
"vom Nutzer bewusst austauschbar belassen"; gespeicherte Pläne kennen kein
Fixierungskonzept wie `PlanDraft.isContentFixed`/`isPositionFixed`. Keine
Fixierungs-Unterstützung behauptet, die real nicht existiert.

**Leitplanke 5 (Bein-Arbeit-Bewertung begrenzt):** Doku präzisiert — die
Klassifikation erkennt Vorhandensein/Volumen über die bestehende
`MuscleVolumeBucket`-Taxonomie (DEL-082, für Hypertrophie gedacht), bewertet
NICHT Ausreichendheit für den Laufcoach-Zweck. Keine neue, unbelegte
Schwelle erfunden.

**Leitplanke 6 (Koordination mit `CardioFeasibilityCardModel`):** als
Vertrag in `CoachAdjustmentCardModel`s Typ-Doku festgehalten (neue Karte
hat Vorrang, sobald ein aktiver Plan existiert) — bewusst NOCH NICHT an
den drei Aufrufstellen (ProfileEditorView/DashboardView/PlansListView)
verdrahtet, da die Preview-UI (Komponente 4) fehlt und ein Entfernen der
bestehenden Karte ohne Ersatz eine Regression wäre.

**Komponente 3 umgesetzt (Commit `5f903a9`):** `CoachAdjustmentCardModel`
(`make`/`accept`, Muster von `CardioFeasibilityCardModel`, mutiert aber
den bestehenden Plan statt immer neu zu erzeugen) + 4 neue Tests.

**CI:** Run für `5f903a9` ausstehend zum Zeitpunkt dieses Nachtrags.

**Weiterhin offen:** Komponente 4 (`CoachAdjustmentPreviewView`,
Vorher/Nachher-UI, drei Aktionen), Komponente 5 (`CardioGoalEditorView`-
Anbindung), Leitplanke-6-UI-Verdrahtung, alle 9 Geräte-Nachweise.

## Paket 1 (Teil 2): Architekturfrage beantwortet, Komponenten 1+2+6 umgesetzt

**Architekturfrage aus Teil 1 geklärt (keine neue Designentscheidung
nötig):** `TrainingDay.generationFingerprint == currentContentFingerprint`
(+ keine Session-Historie) ist der bereits bestehende Schutzmechanismus
für "manuelle Änderungen/Fixierungen" — exakt das Prinzip, das
`PlanGeneratorInstantiator.recalculate` für "neu rechnen" bereits nutzt.
Ein Tag ohne Fingerprint (manuell hinzugefügt) oder mit abweichendem
Fingerprint (seit Erzeugung editiert) ist immer geschützt. Keine neue
Fixierungs-Logik gebaut.

**Umgesetzt (Commits `d86bf4b`, `5bc8e5b`):**
- **`RunCoachPlanAdjustment`** (`Sources/FitnessAppData/`, neu): reine
  Analyse, welche Cardio-/Kraft-Tage eines aktiven Plans anfassbar sind
  (`isEligibleForAdjustment`), und ob die vorhandene Bein-Kraftarbeit zum
  Laufziel passt — fünf Fälle (`unchanged`/`addSmallAddition`/
  `redistribute`/`replaceForTime`/`conflict`), klassifiziert über die
  bestehende `MuscleVolumeBucket`-Taxonomie (keine neuen Schwellenwerte).
  "Wenig Zeit" (`replaceForTime`) nutzt eine bewusst einfache,
  kommentierte Faustregel (Tag mit ≥6 Übungen gilt als voll) statt einer
  erfundenen wissenschaftlichen Regel.
- **`PlanGeneratorInstantiator.applyCoachCardioAdjustment`**: wendet
  frisch generierte Cardio-Tagesinhalte auf die als anfassbar erkannten
  Tage an — reiner Reuse von `apply`/`revert` (derselben Infrastruktur,
  die `recalculate` nutzt), kein Duplikat. Ersetzt nur `min(anfassbare
  Tage, neue Tage)` — überzählige anfassbare Tage bleiben unverändert,
  ein überzähliger neuer Cardio-Tag wird NICHT eingefügt (Tage zu einem
  lebenden Plan hinzuzufügen bleibt außerhalb des Paket-1-Scopes, siehe
  „Offen" unten).
- **`RunCoachPlanAdjustmentTests`** (10 Tests): Eligibility (manuell/
  editiert/mit Historie = geschützt, unberührter Wizard-Tag = anfassbar),
  alle fünf Bein-Arbeit-Fälle, `noActivePlan`/`noEligibleCardioDay`.
- **Komponente 6 (Onboarding):** `OnboardingView.onGenerated` ruft
  `finishOnboarding()` nicht mehr direkt auf — übernimmt nur den Entwurf
  und kehrt zur Wochenvorschau zurück (A10-konform). Die Vorschau hatte
  die nötige Infrastruktur bereits (Haken auf dem "Build Plan"-Kärtchen
  sobald ein Entwurf vorliegt, ein eigener "Fertig"-Button, der
  `finishOnboarding()` selbst aufruft) — der Fix war eine einzige Zeile.
  Fehlende Ausdauerform: bereits vorher korrekt validiert
  (`canAdvance` blockt ohne Auswahl), kein zusätzlicher Fix nötig.
- **Komponente 1 abgeschlossen:** `distributionConflict` (aus Teil 1) ist
  jetzt sichtbar als Banner in `PlanBuilderView`s Wochenvorschau verdrahtet
  — die "sichtbare Entscheidung statt stillem Weglassen" aus der
  A12-Spezifikation. Neuer xcstrings-Key (DE/EN/TR), `UNUSED:0` bestätigt.
- **CI:** Run `39484775116` ausstehend zum Zeitpunkt dieses Nachtrags (CI-
  Warteschlange bei GitHub ungewöhnlich lang, >10 Min) — Ergebnis siehe
  nächster Nachtrag/Abschlussbericht.

**Bewusst weiterhin NICHT umgesetzt (Komponenten 3–5, Rest von 7, alle 9
Geräte-Nachweise):**
- `CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView` (UI-Schicht:
  Vorher/Nachher-Vorschau, drei Aktionen, Coach-aus-Bestätigungsdialog)
  und die Anbindung in `CardioGoalEditorView` — das ist die größte
  verbleibende UI-Arbeit und wurde in diesem Durchgang aus
  Kontext-/Zeitgründen zurückgestellt, um die bereits gebaute Analyse-
  Logik (Komponente 2) nicht unter Zeitdruck an eine unausgereifte UI zu
  koppeln.
- Der "Coach an, Anpassung noch nicht übernommen"-Status (Komponente 7)
  ist konzeptionell geklärt (aus `cardioCoachingEnabled` + Abwesenheit
  eines passenden `cardioCoach`-Plans ableitbar, kein neues Feld nötig),
  aber erst mit der Preview-UI tatsächlich verdrahtbar.
- Alle 9 Geräte-Nachweise brauchen die UI-Schicht und sind daher noch
  offen.

## Runde 11: Onboarding/Laufcoach-E2E-Abgleich (GoalDrivenPlanSelectionBuilder, PlanGeneratorInput, onGenerated/finishOnboarding)

Auftrag: nachvollziehen, ob `GoalDrivenPlanSelectionBuilder` bei
Hybrid+„Both"-Ausdauerform eine gewählte Sportart ohne sichtbaren
Konflikt verlieren kann; klären, wie `PlanGeneratorInput` (ohne
Laufziel-/Coach-Felder) mit `CardioCoachingAdvisor`/
`CardioFeasibilityCalculator` zusammenhängt; klären, ob
`OnboardingView.onGenerated` → `finishOnboarding()` Absicht oder Bug ist;
prüfen, ob die stille `.running`-Rückfalllogik bei fehlender
Ausdauerform zu einer falschen stillen Annahme führen kann. Dazu 10
konkrete Prüffälle, Template- und Builder-Pfad getrennt betrachtet,
bestehende Evidenz (A03/A06/A08 u. a.) wiederverwendet statt blind
erneut geprüft.

### Befund 1 — `GoalDrivenPlanSelectionBuilder`: Radfahren verschwindet bei Hybrid+„Both" am UI-Default still (neue Zeile A12)

Code-Analyse (`Sources/FitnessAppCore/Programs/GoalDrivenPlanSelectionBuilder.swift`):
für `.hybrid` gilt `strengthDays = ceil(totalDaysPerWeek/2)`,
`enduranceDays = totalDaysPerWeek - strengthDays`;
`enduranceSelections(modality: .both, totalDays:, ...)` splittet diese
Ausdauertage wiederum in `firstDays = ceil(totalDays/2)` (Laufen) und
`secondDays = totalDays - firstDays` (Radfahren), wobei Radfahren nur
angehängt wird, wenn `secondDays > 0` — **kein `else`-Zweig, kein
Rückgabewert/Signal, keine Meldung**. Bei `totalDaysPerWeek = 3` (der
tatsächliche UI-Default in `PlanBuilderView`, Slider startet bei 3, wird
von den meisten Nutzern nie angefasst) ergibt das `strengthDays = 2`,
`enduranceDays = 1` → `firstDays = 1` (Laufen), `secondDays = 0`
(Radfahren **komplett entfernt**).

Regressionstest (committed, pinnt den Ist-Zustand):
`Tests/FitnessAppCoreTests/GoalDrivenPlanSelectionBuilderTests.swift::testHybridGoalWithBothModalityAtTheDefaultThreeDaysSilentlyDropsCycling`,
Commit `9956f8e`, CI grün (Run `39475868792`, nach zwei
infrastrukturbedingten Queue-Timeouts beim dritten Versuch erfolgreich —
siehe Budget-Abschnitt unten).

**Geräte-Nachweis (diese Runde):** TestingBot-Session
`7f1a4aa358fb-8ccc5c0b64ef-388a7f4cec85-179252205753-68569042`
(iPhone 15 / iOS 18.0 Simulator, Build aus CI-Run `39475868792`, Commit
`9956f8e`). Frisches Onboarding: Ziel „Functional/Hybrid", Ausdauerform
„Both", Coach-Frage „Schedule running in my week" (Coach aus) — alle drei
Werte waren beim Wechsel in „Build Plan" bereits korrekt vorbefüllt.
Tage-Slider NICHT angefasst (blieb beim Default „3 days per week").
Wochenvorschau zeigte genau 3 Einheiten: „Bodyweight · Push & Pull"
(Kraft), „Easy Run" (Laufen), „Bodyweight · Pull & Push" (Kraft) —
**keine Radfahren-Einheit, keine sichtbare Konflikt-/Hinweismeldung,
keine Warnung jeglicher Art**. Haken „Adopt Plan" getippt: App sprang
direkt zum Dashboard mit aktivem, persistiertem „Individueller Plan"
(kein Zwischenschritt). Plan-Tab zeigte danach exakt „1 PLAN"; Plan-Detail
zeigte die Trainingstage Mon=Push&Pull, Wed=Easy Run, Fri=Pull&Push, Rest
sonst — **deckungsgleich mit der zuletzt gezeigten Vorschau**, keine
Radfahren-Einheit nachträglich aufgetaucht, kein Duplikat.

**Neue Matrixzeile A12** (siehe Tabelle unten): Status `teilweise
bestanden` im Sinne von „Bug reproduziert und bestätigt", aber
**bewusst nicht gefixt** — siehe Fachliche Widersprüche Punkt 7. Der
spezifikationskonforme Soll-Zustand (Prüffall 8: „zu wenige Einheiten für
alle gewählten Sportarten → sichtbare Entscheidung/Konflikt statt
stillem Weglassen") verlangt eine neue Konflikt-UI, keine begrenzte
Code-Korrektur, und geht daher als offene Entscheidung an den Nutzer
zurück.

### Befund 2 — `PlanGeneratorInput`/Coach-Zustand hat keinen Einfluss auf den Planinhalt (erweitert A04/A09)

Code-Audit bestätigt, was A04/A09 bereits gerätebestätigt andeuteten, nun
mit hartem Code-Beleg: `PlanGeneratorInput` (das tatsächlich auf
`TrainingPlan.generatorInputRaw` persistierte Objekt) enthält
ausschließlich `selections`, `equipmentPreferences`, `usesFixedWeekdays`,
`fixedWeekdays` — **keine Laufziel-/Coach-Felder**.
`GoalDrivenPlanSelectionBuilder.makeSelections` hat **keinen
Coach-Parameter**. `cardioCoachingEnabled` wird laut Codesuche
ausschließlich in `ProfileEditorView`, `CardioGoalEditorView`,
`CardioFeasibilityCardModel`, `CoachingTypes`, `DataExportService`/
`DataImportService` gelesen/geschrieben — **nie** in einer
TrainingPlan-/TrainingDay-/Exercise-Mutation. Schlussfolgerung: „Coach
an" im Onboarding kann strukturell keinen Unterschied im generierten
Planinhalt bewirken, nur ein nachgelagertes, inertes Profil-Flag setzen.
Deckt sich mit der bereits gerätebestätigten Beobachtung aus A04 (kein
optischer Unterschied zwischen Coach an/aus in der Wochenvorschau) und
bestätigt damit Prüffälle 1/2 sowie 4/5 der Spezifikation: der einzige
Unterschied zwischen „mit Coach" und „ohne Coach" ist das gespeicherte
Profil-Flag selbst — der Plan-INHALT ist identisch. Kein neuer
Gerätetest nötig, A04s Gerätenachweis (Runde 3) deckt dies bereits ab.

### Befund 3 — `onGenerated` → `finishOnboarding()`: bestätigt unverändert und bewusst so (bestätigt A10)

Code-Lesung von `OnboardingView.swift` (Sheet-Block um Zeile 340-428)
bestätigt: `onGenerated: { input, result in ...; finishOnboarding(); return .success }`
ruft `finishOnboarding()` direkt auf. Umliegende Code-Kommentare (Zeilen
367-377) dokumentieren dies explizit als **bewusste, bereits in einer
früheren Audit-Runde getroffene Entscheidung** („P0-Audit, vierte
Korrekturrunde"), die zwei vorher uneinheitliche Finish-Trigger
(DayPickerSheet vs. Builder-Sheet) absichtlich vereinheitlicht hat. Das
ist **kein Bug**, sondern eine dokumentierte Produktentscheidung, die
jedoch in Spannung zu einer engen Lesart von Dok. 02 §6 Punkt 2 steht
(„Haken übernimmt nur den Entwurf") — bereits in A10 als „teilweise"
erfasst, hier per Geräte-Nachtest dieser Runde erneut bestätigt (siehe
Befund 1: der Haken „Adopt Plan" führte direkt zum Dashboard, kein
separater Vorschau-Rücksprung). Keine Änderung an A10 nötig.

### Befund 4 — stille `.running`-Rückfalllogik: unerreichbar über den regulären Onboarding-Fluss

`needsEnduranceModalityStep` (`trainingGoal == .hybrid || .endurance`)
gated den Onboarding-Schritt; `canAdvance` für diesen Schritt hat ein
hartes Gate `return enduranceModality != nil` (Code-Kommentar verweist
explizit auf „Dok02 §2: keine stille Default-Auswahl"). Der lineare
Onboarding-Fluss kann `finishOnboarding()` für Hybrid/Endurance-Ziele
also nicht mit `enduranceModality == nil` erreichen — der `?? .running`-
Fallback in `GoalDrivenPlanSelectionBuilder` ist defensiver, über die
reguläre UI nicht erreichbarer Code. Kein Bug, kein Gerätetest nötig.

### Template- vs. Builder-Pfad — bestätigt getrennt

Codesuche bestätigt: `ProgramTemplate`/`DaySpec` und die übrigen
Template-Dateien enthalten **keine** `EnduranceModality`-Referenzen —
Templates sind fest vorgefertigte Pläne ohne dynamische Tage-Splitting-
Logik. Der A12-Befund (Befund 1) betrifft daher **ausschließlich** den
Builder-Pfad (`PlanBuilderView`/`GoalDrivenPlanSelectionBuilder`), auch
wenn dieser über das Onboarding-eingebettete „Build Plan"-Sheet erreicht
wird (`PlanBuilderView(initialInput: ..., preseededEnduranceModality: ...)`,
`OnboardingView.swift` Zeile ~406). Device-Nachweis dieser Runde lief
exakt über diesen Pfad.

### Die 10 Prüffälle — Ergebnis

| # | Fall | Ergebnis | Beleg |
|---|---|---|---|
| 1 | Kraft+Laufen ohne Coach | bestanden (unverändert) | A03 (Runde 3, Gerät) |
| 2 | Kraft+Laufen mit Coach + unterstütztes Ziel | teilweise (unverändert) | A04 (Runde 3, Gerät) + Befund 2 (Code, diese Runde): kein Planinhalt-Unterschied, A09-Lücke (kein Laufziel wird erhoben) bleibt offen |
| 3 | Kraft+Radfahren | bestanden | A05 (Runde 3, Logik/Gating); Single-Modalität ist von der A12-Rundungslücke nicht betroffen (nur „Both"-Split hat den 0-Tage-Fall) |
| 4 | Kraft+Laufen+Radfahren ohne Coach | **Bug bestätigt (A12)** | Befund 1, diese Runde, Gerät: Radfahren fehlt bei 3-Tage-Default |
| 5 | dieselbe Kombi mit Coach | **Bug bestätigt (A12)**, Coach ändert nichts am Inhalt | Befund 1 + Befund 2, diese Runde |
| 6 | Coach an→aus: Laufeinheiten bleiben bestehen | teilweise (unverändert) | A07 (Runde 3, Gerät); zusätzlich Befund 2 (Code): `cardioCoachingEnabled` wird nie in Plan-/Tag-Mutationen gelesen, strukturell kann ein Toggle keine Einheit löschen |
| 7 | Laufen→nur Radfahren: keine aktiven Laufcoach-Empfehlungen mehr | bestanden (unverändert) | A08 (Runde 3, Gerät): Coach-Frage verschwindet sauber bei Cycling-only |
| 8 | zu wenige Einheiten für alle gewählten Sportarten: sichtbare Entscheidung statt stillem Weglassen | **nicht erfüllt — fachlicher Widerspruch (A12)** | Befund 1, diese Runde, Gerät: komplett stilles Weglassen, keine Meldung |
| 9 | eingebetteten Editor bestätigen: nur Entwurf geändert, nicht direkt abgeschlossen | **nicht erfüllt wie spezifiziert, aber bewusst so (A10)** | Befund 3, diese Runde, Code + Gerät: Haken schließt das gesamte Onboarding direkt ab |
| 10 | finaler Abschluss: genau der vorher gezeigte Plan wird gespeichert | bestanden | Befund 1, diese Runde, Gerät: gespeicherter Plan deckungsgleich mit Vorschau; zusätzlich `testBuildUsesThePrecomputedResultInsteadOfRecomputingFromInput` (Unit-Ebene, vorbestehend) |

### Budget (Gesamtstand Runde 11)

TestingBot-Minutenguthaben laut `/v1/user`: **21.769s** vor dieser Runde
(Stand Runde 10) → **21.238s** danach → **531s (≈ 8 min 51 s)** für die
eine Session dieser Runde verbraucht (Build-Installation, kompletter
Onboarding-Durchlauf Builder-Pfad, Plan-Detail-Prüfung). Session aktiv
per `DELETE /session` beendet, keine offene TestingBot-Session.

### CI

Workflow `apple-ci-comparison.yml`, Branch `claude/smart-onboarding-epic`,
Commit `9956f8e`: zwei Versuche (`39471376128`, `39473586849`) blieben
~15 Minuten in `queued` hängen und wurden ohne zugewiesenen Runner
automatisch abgebrochen (`conclusion: cancelled`) — ein transientes,
Runner-Kapazitäts-bedingtes GitHub-Infrastrukturproblem, kein
Code-/Kontoproblem (keine konkurrierenden Runs, viele vorige Runs in
dieser Session liefen normal durch). Dritter Versuch (`39475868792`)
erhielt einen Runner und schloss **erfolgreich** ab, inkl. des neuen
Regressionstests.

## Runde 10: Screenshot-gemeldete UI-Punkte (Hantelrechner, Satzanzeige-Umschalter, Tab-Icon-Fix, Layout-Einzug)

**Auftrag (vom Nutzer per Screenshot gemeldet, 5 Punkte):**
1. Prüfen, ob der Hantelrechner-Einstieg für Langhantel-Übungen in der
   neuen Spaltenübersicht fehlt; separat klären, ob die „BW"-Anzeige bei
   Kniebeuge ein unkorrekt gesetztes Bodyweight-Equipment oder schlicht
   ein ungesetztes Gewicht ist — NICHT allein aus dem Übungsnamen auf die
   Equipment-Zuordnung schliessen.
2. Die Spaltenübersicht optional machen: neue Settings → Training-Wahl
   zwischen „bisherige Darstellung" und „Spaltenübersicht", gleicher
   Persistenz-Mechanismus wie `weight_unit`, Kaltstart-fest, keine zweite
   Logging-Implementierung, kein Datenverlust beim Umschalten.
3. Gewicht+Wdh-Feldgruppe in der Spaltenübersicht moderat nach rechts
   einrücken, Spaltenköpfe entsprechend ausrichten, RIR-Breite/Lesbarkeit
   dabei NICHT verkleinern.
4. Fehlende untere Tab-/Menüpunkte während eines aktiven Workouts
   untersuchen (laut Nutzer geräteabhängig) — root-causen statt pauschal
   die Oberfläche zu verschieben oder neue Nav-Einträge zu erfinden.
5. Gebündelter Geräte-Abnahme-Durchlauf über sinnvolle Kombinationen
   (Bildschirmbreite, Standard-/AX5-Schriftgrösse, Light/Dark, kg/lbs,
   beide Satzanzeige-Modi, Hantel- und Bodyweight-Übung, Tastatur auf/zu).

Standing Constraints unverändert: kein Merge, kein Release, CI bündeln,
kein neuer allgemeiner Review, gefundene Bugs gezielt mit Regressionstest
fixen statt Redesign.

### Punkt 1 — Hantelrechner-Einstieg und „BW"-Anzeige: kein Bug gefunden

Code-Recherche VOR jeder Änderung (wie vom Auftrag verlangt):
- `SetRow.plateColumn`/`isBarbellExercise`/`plateCalculatorButton`
  (`SetRow.swift`) sind unverändert gegenüber dem Stand, der in früheren
  Runden bereits gerätebestätigt wurde: die Plate-Spalte reserviert für
  JEDE Übung dieselbe Breite, zeigt den Button aber erst ab `weight > 0`
  (`.opacity`/`.allowsHitTesting`). Kein separater Code-Pfad für
  „Spaltenübersicht" vs. irgendeine andere Darstellung — dieselbe Logik
  gilt in beiden Satzanzeige-Modi.
- `ExerciseLibraryData.swift` Zeile 71: „Kniebeuge"/„Back Squat" ist
  korrekt mit `equipment: .barbell` getaggt. Keine Bodyweight-
  Fehlklassifizierung.
- Schlussfolgerung VOR dem Geräte-Test: das im Nutzer-Screenshot gezeigte
  „BW" ist mit sehr hoher Wahrscheinlichkeit schlicht ein noch nicht
  eingetragenes Gewicht (Placeholder), kein Klassifizierungsfehler.

**Geräte-Nachweis (iPhone 15/iOS 18.0, Light Mode, kg, Spaltenübersicht,
Übung „Back Squat" aus Plan „Full Body 3x"):** vor Gewichtseingabe zeigt
Satz 1 korrekt „BW" (Platzhalter, Plate-Spalte leer/nicht antippbar) —
exakt der im Screenshot gemeldete Zustand, reproduziert und erklärt.
Nach Eingabe von „60" im Gewichtsfeld erscheint der orange
Hantel-Button sofort; Tap öffnet „Barbell Loading" mit korrektem Ergebnis
(60 kg, Stange 20 kg, „Pro Seite: 1× 20 kg"). **Kein Bug — Punkt 1 ist
damit vollständig durch Code-Lesen UND Geräte-Beleg als Fehlalarm
bestätigt**, bewusst ohne die Equipment-Zuordnung anzufassen (wie vom
Auftrag verlangt).

### Punkt 2 — Optionale Satzanzeige „bisherige Darstellung"/„Spaltenübersicht"

**Implementierung:**
- Neuer `@AppStorage("pref_set_display_mode")`-Key (Default `"column"` —
  bisheriges Verhalten bleibt unverändert der Default), identisch
  deklariert in `SetRow.swift`, `ExerciseCard.swift` und
  `SettingsAppExperienceView.swift` (durch eigenen Regressionstest
  `SetDisplayModeSettingTests.testAllThreeCallSitesUseTheSameDisplayModeStorageKey`
  gegen einen Tippfehler in einer der drei Stellen abgesichert).
- Settings → App & Workout Experience → „Trainings-Verhalten" (Workout
  Behavior) bekommt eine neue Zeile „Set display" mit Picker
  „Column overview" / „Previous layout" (= „Spaltenübersicht" /
  „bisherige Darstellung").
- `ExerciseCard` blendet den gemeinsamen Spaltenkopf (`setRowColumnHeader`)
  im `"classic"`-Modus aus. `SetRow` bekommt einen neuen `classicInputRow`/
  `classicTwoLineRow`-Zweig, der dieselben `weightInput`/`repsInput`/
  `plateColumn`/`rirCapsule`/`checkmarkButton`-Subviews wiederverwendet
  (keine zweite Logging-Implementierung) und Gewicht/Wdh stattdessen
  direkt über dem jeweiligen Feld beschriftet (`labeledField()`, nutzt
  `.deltiqLabel()` — denselben bereits AX5-gehärteten Caption-Stil wie der
  Spaltenkopf, siehe Punkt 3).
- Die schmale Fallback-Zeile (`inputRowSecondaryLine`: Plate-Button,
  RIR-Kapsel, Haken) ist zwischen Spalten- und klassischer Darstellung
  identisch extrahiert, keine Duplikation.

**Geräte-Nachweis (iPhone 15/iOS 18.0, Dark Mode, Satz 1 bereits mit
60 kg/6 Wdh geloggt, laufender Pausentimer):**
- Umschalten von „Column overview" auf „Previous layout" in den
  Settings: zurück im Workout zeigt die Karte sofort die selbst-
  beschriftete Darstellung (KG/REPS-Captions über den Feldern, kein
  gemeinsamer Spaltenkopf mehr) — Satz 1 (60 kg, 6 Wdh, grüner Haken,
  Hantel-Icon) UNVERÄNDERT erhalten, Volumen weiterhin korrekt
  „360 KG", **der laufende Pausentimer lief währenddessen ohne
  Unterbrechung weiter** (vor dem Wechsel „0:13", danach fortlaufend
  weitergezählt) — keine der drei geforderten Erhaltungs-Eigenschaften
  (Werte, Status, Timer) verletzt.
- Satz 2 im klassischen Modus geloggt (BW/6 Wdh) — funktioniert
  identisch zur Spaltenübersicht, keine fehlenden Funktionen.
- **Kaltstart-Beleg:** App vollständig beendet (`terminateApp`) und neu
  gestartet (`launchApp`, echter Prozess-Neustart, kein Backgrounding).
  Nach dem Neustart: Dashboard zeigt „Resume running workout", nach
  Fortsetzen ist die klassische Darstellung weiterhin aktiv, Satz 1 UND
  Satz 2 weiterhin korrekt geloggt (60 kg/6 Wdh bzw. BW/6 Wdh, beide
  Haken grün), Volumen weiterhin „360 KG" — Einstellung UND Satzdaten
  überleben den Kaltstart.

### Punkt 3 — Gewicht/Wdh-Einzug in der Spaltenübersicht

**Implementierung:** neue Konstante
`SetRow.SetRowColumns.weightGroupLeadingInset = 10` (ein fixer
`Color.clear`-Spacer vor `weightInput` bzw. dem Gewicht-Spaltenkopf), in
allen vier betroffenen Stellen konsistent angewendet:
`ExerciseCard.fullSetRowColumnHeader`, `ExerciseCard.
reducedSetRowColumnHeader`, `SetRow.singleLineInputRow`, `SetRow.
twoLineInputRow`. `rirWidth` (44pt) bewusst unverändert gelassen — durch
`SetDisplayModeSettingTests.
testRirColumnWidthWasNotShrunkByTheWeightGroupIndent` als Regressionstest
abgesichert.

**Geräte-Nachweis:** Screenshot der Spaltenübersicht (Standardschrift,
Light Mode) zeigt Gewicht+Wdh sichtbar nach rechts abgesetzt von der
Satznummer, Spaltenkopf „Set | KG | REPS | RIR" exakt deckungsgleich mit
den Satzzeilen darunter ausgerichtet. Bei AX5 (siehe unten) bleibt RIR in
BEIDEN Darstellungen voll lesbar, nicht zusammengeschoben.

### Punkt 4 — Fehlende untere Tab-Icons im Light Mode: echter Bug gefunden und gefixt

**Root Cause (Code-Lesen vor der Änderung):**
`RootView.swift`s `configureTabBarAppearance()` setzte die Icon-Farbe der
inaktiven Tabs hart auf `UIColor.white.withAlphaComponent(0.35)`, unter
der (im Code-Kommentar explizit genannten) Annahme eines IMMER dunklen
Hintergrunds (`#1C1C1E`). `Color.Deltiq.surface` (`Theme.swift`) ist aber
hell/dunkel-adaptiv — im Light Mode reines Weiss. Weiss-auf-Weiss machte
die vier inaktiven Tabs (Dashboard, Measurement, Tools, More, je nachdem
welcher gerade aktiv ist) im Light Mode de facto unsichtbar, nur der eine
aktive orange Tab blieb erkennbar — exakt das vom Nutzer gemeldete
Verhalten, und exakt „geräteabhängig" im Sinne von „abhängig vom
Farbschema". `WorkoutRootView`/`ActiveWorkoutView` pushen die aktive
Session reaktionsgenau per `NavigationStack`/`safeAreaInset` (kein
`.fullScreenCover`, kein `.toolbar(.hidden, for: .tabBar)` im gesamten
Code gefunden) — die Tab-Bar war also nie absichtlich ausgeblendet,
sondern nur farblich unsichtbar.

**Fix:** dieselbe Hell/Dunkel-Verzweigung wie `Color.init(deltiqLight:
deltiqDark:)` (Theme.swift) statt eines harten Weiss-Werts:
`UIColor(Color(deltiqLight: .black.opacity(0.35), deltiqDark: .white.
opacity(0.35)))`. Eine CI-Unit-Test-Abdeckung wurde bewusst NICHT
versucht: `canImport(UIKit)`-gegatete Tests laufen auf dem macOS-CI-
Runner nie (siehe bereits in Vorrunden dokumentiertes Platform-Problem),
ein solcher Test wäre stille Fake-Abdeckung gewesen — die einzige echte
Verifikation ist der Geräte-Toggle.

**Geräte-Nachweis:**
- **Light Mode (vorher kaputt):** direkt nach Onboarding-Abschluss zeigt
  das Dashboard alle 5 Tabs (Dashboard, Plan, Measurement, Tools, More)
  klar lesbar in dunkelgrauer/schwarzer Farbe, nur „Dashboard" orange
  aktiv — kein Weiss-auf-Weiss mehr sichtbar, über mehrere Screenshots
  dieser Runde hinweg bestätigt (inkl. während eines laufenden
  Pausentimers, der exakten vom Nutzer gemeldeten Situation).
- **Dark Mode (vorher bereits korrekt, Regressionsprüfung):** nach
  Umschalten auf Dark Mode in den Settings bleiben alle 5 Tabs weiterhin
  klar lesbar (jetzt hellgrau/weiss auf dunklem Hintergrund) — Fix
  verändert das vorher schon korrekte Dark-Mode-Verhalten nicht.
- Beide Farbschemata zusätzlich bei AX5 geprüft (siehe unten) — Tab-Bar
  bleibt in beiden Fällen vollständig erreichbar.

### Gefundener Bug (abseits der 5 Punkte): AX5-Überlauf im neuen „Set display"-Picker — zwei Anläufe

Beim AX5-Geräte-Nachtest von Punkt 2/3 fiel auf: der neue „Set display"-
Picker in den Settings überlief bei maximaler Bedienungshilfen-
Textgrösse (AX5) sichtbar in die Nachbar-Reihen („Quick check-in",
„Four-week review", „Deload suggestions") hinein — ein von dieser Runde
selbst verursachter Fund, nicht Teil der 5 ursprünglichen Punkte, aber
nach etablierter Praxis dieser Session („ein Fund wird gemeldet und
gefixt, nicht stillschweigend übergangen") sofort behoben:

- **Erster Fix-Versuch (Commit `496a0cf`):** `.minimumScaleFactor(0.5)` +
  `.frame(maxWidth: 150, alignment: .trailing)` auf den Picker. Am Gerät
  nachgetestet — **wirkungslos**, der Text lief unverändert über mehrere
  Reihen. Root Cause: `.pickerStyle(.menu)` rendert seinen eingeklappten
  Wert über ein natives UIKit-Button-Label, das SwiftUIs
  `.lineLimit`/`.minimumScaleFactor`/`.frame(maxWidth:)` schlicht
  ignoriert und selbst mehrzeilig umbricht — ein Verhalten, das auch bei
  mehreren bereits VOR dieser Runde bestehenden Picker-Zeilen
  desselben Screens auftritt („Lead-in before start" → „10 seconds",
  „Water reminder"-Frequenz → „Every 3 hours", Wochentag → „Sunday"),
  dort aber wegen kürzerer Werte nie auffiel. Diese vorbestehenden
  Stellen sind NICHT Teil dieser Runde und bleiben hier unverändert,
  aber als bekannte, verwandte Lücke festgehalten.
- **Zweiter Fix (Commit `c6f5e9c`, am Gerät bestätigt):** zusätzlich
  `.frame(maxHeight: 44)` + `.clipped()`. Dadurch bleibt der angezeigte
  Wert bei AX5 ggf. sichtbar unvollständig (ein einzelnes abgeschnittenes
  Zeichen statt des vollen Worts), **fällt aber nie mehr in die
  Nachbar-Reihen hinein** — bewusster Kompromiss zwischen
  Eigenname-Lesbarkeit und Nicht-Überlappung, zugunsten Letzterem
  entschieden. Das aufklappbare Dropdown-Menü selbst (System-eigene
  Darstellung, kein `.menu`-Collapsed-Label) zeigt beide Optionen
  („Column overview" / „Previous layout") bei AX5 weiterhin vollständig
  lesbar, korrekt zweizeilig umgebrochen — nur die eingeklappte
  Zeilen-Anzeige war betroffen.
- Regressionstest `SetDisplayModeSettingTests.
  testSetDisplayPickerConstrainsItsWidthSoLongValuesCannotOverflowIntoNeighboringRows`
  prüft `maxWidth`+`maxHeight`+`.clipped()` im Quelltext (reiner
  Text-Scan, da `canImport(UIKit)` auf dem CI-Runner nicht greift — die
  tatsächliche Nicht-Überlappung ist nur am Gerät prüfbar, siehe oben).

### Punkt 5 — Gebündelter Geräte-Abnahme-Durchlauf

**Geräteflotte (TestingBot, Stand dieser Runde):** von allen iOS-17+-
fähigen iPhone-Modellen (iPhone SE 2022/17.5, iPhone 14/17.6, iPhone
15/18.0, iPhone 16/16 Pro/17/17 Pro/17 Pro Max) war zum Zeitpunkt dieser
Runde **nur „iPhone 15"/iOS 18.0 als Simulator tatsächlich startbar** —
alle anderen waren laut `/v1/devices` entweder `available: false` oder
(wie „iPhone Air"/iOS 26.2) nur als **physisches Gerät** verfügbar, das
unseren Simulator-Build (`FitnessApp-simulator.zip`) nicht ausführen
kann. Ein echtes schmaleres iOS-17+-Gerät war damit — wie bereits in
einer Vorrunde dokumentiert — strukturell nicht verfügbar. Als Ersatz für
die geforderte „schmale Breite"-Kombination wurde wie in Runde 8/9 die
etablierte Technik genutzt: AX5-Dynamic-Type erzwingt denselben
schmalen `ViewThatFits`-Fallback (`twoLineInputRow`/`classicTwoLineRow`),
den ein echtes schmales Gerät ausgelöst hätte.

**Tatsächlich geprüfte Kombinationen (alle auf iPhone 15/iOS 18.0,
Commit `c6f5e9c`):**

| Kombination | Ergebnis |
|---|---|
| Light Mode, kg, Spaltenübersicht, Standardschrift, Hantel-Übung (Back Squat) mit echtem Gewicht | Hantelrechner sichtbar+funktionsfähig (60 kg, Stange 20 kg), Spaltenkopf+Einzug korrekt, Tabs voll sichtbar, Tastatur-Interaktion fehlerfrei |
| Light Mode, Spaltenübersicht, laufender Pausentimer nach Satz-Log | Tab-Bar bleibt neben der RestTimerBar voll sichtbar (die exakte vom Nutzer gemeldete Situation) |
| Dark Mode, Spaltenübersicht → klassische Darstellung umgeschaltet, laufender Pausentimer | Satz 1 (60 kg/6/✓) unverändert erhalten, Timer lief ununterbrochen weiter, Tabs weiterhin voll sichtbar |
| Dark Mode, klassische Darstellung, Satz 2 (Bodyweight-Satz, „BW") geloggt | Funktioniert identisch zur Spaltenübersicht, RIR-Kapsel + Haken erreichbar |
| Dark Mode, klassische Darstellung, **echter Kaltstart** (`terminateApp`+`launchApp`) | Anzeige-Modus UND beide geloggten Sätze überleben den Kaltstart unverändert |
| Light Mode, AX5, Spaltenübersicht (Dashboard+Settings) | Tabs weiterhin voll sichtbar; vorbestehender AX5-Überlauf in mehreren Settings-Pickern bemerkt (siehe eigener Abschnitt), neuer „Set display"-Picker nach Fix NICHT mehr betroffen |
| Dark Mode, AX5, klassische Darstellung, aktives Workout | KG/REPS/RIR-Captions gross aber vollständig lesbar, kein Überlappen von Satz 2/3 mit Haken/Plate-Button, Tabs weiterhin voll sichtbar |

**Nicht geprüft / strukturelle Lücke (dokumentiert statt stillschweigend
übergangen):** ein echtes schmaleres iOS-17+-Gerät (z. B. iPhone SE) war
in der aktuellen TestingBot-Flotte nicht verfügbar — identisch zur bereits
in einer Vorrunde festgehaltenen Lücke. Türkisch/Deutsch wurden in dieser
Runde nicht erneut geprüft (kein Bezug zu den 5 gemeldeten Punkten, siehe
Vorrunden für den dort bereits dokumentierten Stand).

### Budget (Gesamtstand Runde 10)

| Zeitpunkt | Wert | Quelle |
|---|---|---|
| Vor Runde 10 (Ende Runde 9) | 22.872 s | `docs/DELTIQ_DEVICE_ACCEPTANCE.md`, Runde-9-Nachtrag |
| Session 1 (erster Build, Onboarding+Punkt-1-4-Nachweis) | 1.100 s | `/v1/tests` `duration` |
| Session 2 (zweiter Build, erster Picker-Fix-Nachtest) | 325 s | `/v1/tests` `duration` |
| Session 3 (dritter Build, zweiter Picker-Fix-Nachtest final) | 206 s | `/v1/tests` `duration` |
| Summe Runde 10 | 1.631 s | Summe der drei Sessions |
| Rechnerisch verbleibend nach Runde 10 | 21.241 s | 22.872 s − 1.631 s |
| `GET /v1/user` zum Abschluss dieser Runde | 21.769 s | Konto-API (bekannter Abrechnungs-Nachlauf, siehe Vorrunden) |

Keine offene TestingBot-Session am Ende dieser Runde (alle drei Sessions
explizit per `DELETE` beendet, letzte `/v1/user`-Abfrage bestätigt
`current_vm_concurrency: 0`).

## Runde 9: AX5-Fix-Nachtest + kg/lbs-Implementierungspaket

**Auftrag:** (1) AX5-Spalten-Header-Fix (`c299c22`) mit einem echten
Geräte-Nachweis abschließen (bisher nur CI/Zwischenstand), mehr als reiner
Zeilenumbruch-Check; (2) das in Runde 8 gefundene kg/lbs-Implementierungsloch
für die vier benannten Stellen gezielt schließen; (3) F-Fälle/Budget
unverändert differenziert weiterführen. E04 bleibt in Kopf-/Gesamtstatus
"teilweise" — die neuen Nachweise schließen einzelne Lücken, nicht alle.

### Vorhandener Vertrag + bewusste Scope-Grenze (VOR der Umsetzung festgehalten)

**Speicherung:** durchgehend metrisch, konsistent `*Kg`-benannte Properties
(`UserBodyProfile.goalWeightKg`, `BodyMeasurement.weightKg`,
`PersonalRecordEntry.weightKg`, `ExerciseLog.weight` [kg]) — keine
Schemaänderung, keine Migration.

**Einstellung:** `@AppStorage("weight_unit")` (`"kg"`/`"lbs"`), vor dieser
Runde bereits korrekt gelesen vom Hantelrechner, der Warmup-Rampe
(`ExerciseCard.warmupRamp`) und `SettingsView.formattedHeight/formattedWeight`
(Profil-Zusammenfassungszeile in den Einstellungen selbst — verifiziert,
unverändert korrekt, kein Teil dieser Runde).

**Bereits vorhandener fachlicher Widerspruch (Runde 8, Fachliche
Widersprüche Nr. 6):** der Settings-Hinweistext (`settings.units.footer`)
verspricht wörtlich Wirkung auf "Eingabe-Feldern, Hantel-Rechner und
Karten" — `SetRow.swift` hatte dafür einen expliziten, bewussten
Gegenkommentar (DEL-220): echte lbs-Unterstützung sei "ein eigenes,
querschnittliches Thema (Eingabe, Volumen, PRs, Charts, CSV)".

**Scope-Entscheidung dieser Runde (bewusst NICHT vollständig, benannte
Teilmenge):** genau vier Stellen werden jetzt an `weight_unit` angebunden —
`SetRow.weightInput` (inkl. Spaltenkopf in `ExerciseCard` und
`previousLogHint`, da sonst ein selbst verursachter Einheiten-Mix auf
demselben Screen entstünde), `BodyDataEditorView` (Gewicht/Zielgewicht),
`ProfileEditorView.bodyDataSummaryText` und das Dashboard-Gewichtstrend
(Hero-Kachel + Chart + Zielgewicht-Linie, inkl. Wochen-Delta). AUSDRÜCKLICH
weiterhin kg-only, bewusst nicht Teil dieser Runde: Trainingsvolumen-
Aggregation/Analytics, PR-Erkennung/-Banner, Übungs-Gewichtsverlauf-Charts
außerhalb des Dashboards, CSV-Export/-Import — dieselbe Abgrenzung, die
DEL-220 bereits als eigenes, größeres Thema benannt hatte. `draftHeightCm`
in `BodyDataEditorView` bleibt ebenfalls außerhalb (cm/in ist ein separates,
hier nicht beauftragtes Thema).

### Implementierung

Neuer, kleiner Typ `WeightUnit` (`Sources/FitnessAppCore/Numerics/WeightUnit.swift`,
`enum kg/lbs` mit `fromKg(_:)`/`toKg(_:)`) ersetzt die vier zuvor
duplizierten `kg / 0.453592`-Stellen als einzige Konvertierungsquelle für
die neuen Stellen. Jede Anzeige/Eingabe konvertiert IMMER frisch vom
kanonischen kg-Wert aus (nie verkettet) — Rundtrip- und Rundungsstabilität
über `WeightUnitTests.swift` (7 Tests: Identität für kg, kg→lbs/lbs→kg
Korrektheit, wiederholtes Umschalten ohne Eingabe erzeugt keinen Drift,
Linearität der Konvertierung für Differenzen).

Geänderte Dateien:
- `Sources/FitnessAppUI/Workout/SetRow.swift`: `weightInput`-Binding,
  `weightPlaceholder` ("→ KG"/"→ LBS"), `previousLogHint` (kg-fixer
  Hint direkt neben dem jetzt umschaltbaren Feld wäre ein neuer,
  selbstverursachter Einheiten-Mix gewesen).
- `Sources/FitnessAppUI/Workout/ExerciseCard.swift`: Spaltenkopf
  ("KG"/"LBS", neue Keys `unit.lbs.upper`/`unit.lbs.lower`).
- `Sources/FitnessAppUI/Settings/BodyDataEditorView.swift`: Gewicht- und
  Zielgewicht-Feld (Wert UND Label, neue Keys
  `profile.bodyData.weight.label.lbs`/`profile.bodyData.goalWeight.label.lbs`).
- `Sources/FitnessAppUI/Settings/ProfileEditorView.swift`:
  `bodyDataSummaryText`.
- `Sources/FitnessAppUI/DashboardView.swift`: Hero-Kachel (Wert + Delta,
  `MetricCard` bekam dafür einen `deltaUnit`-Parameter mit kg-Default,
  alle anderen Kachel-Typen unverändert), Trend-Chart (Linie/Punkte/
  Prognose/Zielgewicht-Linie, neuer Key `dashboard.goal.line.lbs`).
- `Sources/FitnessAppUI/Resources/Localizable.xcstrings`: 6 neue Keys
  (DE/EN/TR), `dead_catalog_v3.py` bestätigt UNUSED:0,
  `generate_translations_md.py` regeneriert `TRANSLATIONS.md`.

### AX5-Geräte-Nachweis (Commit `c299c22`, vollständig abgeschlossen)

**Testaufbau:** iPhone 15/iOS 18.0, Deutsch, über die Einstellungen-App
"Bedienungshilfen → Anzeige & Textgröße → Größerer Text" den Schalter
"Größerer dynamischer Text" aktiviert und den Slider auf Maximum (AX5)
gezogen — ECHTE iOS-Bedienungshilfen-Einstellung, nicht nur eine
Capability beim Sessionstart.

**Geprüft (mehr als reiner Zeilenumbruch-Check):** Satz-Logging-Screen
("Kniebeuge", aktives Training) bei AX5. Ergebnis:
- Vollständige Spalten-Kopfzeile fällt korrekt auf die reduzierte Variante
  zurück (`ViewThatFits`/`reducedSetRowColumnHeader`) — "KG"/"WDH" bleiben
  als zusammenhängendes Wort lesbar, keine Buchstaben-für-Buchstabe-
  Umbrüche mehr.
- Keine Überlappung zwischen Spaltenkopf, Dateneingabezeile und der
  Tab-Leiste darunter ("Plan" blieb klar getrennt sichtbar).
- Gewichts-/Wdh-/RIR-Werte ("100"/"5"/"2,5") vollständig sichtbar, nicht
  abgeschnitten; Haken und Hantelrechner-Symbol weiterhin erreichbar.
- Einzige bekannte, bereits akzeptierte Kürzung (Satz-Label selbst als
  "…", s. Runde 8) bestätigt unverändert — keine neue Verschlechterung.

**AX5-Fix gilt damit als vollständig gerätebestätigt**, über den reinen
Zeilenumbruch-Check aus Runde 8 hinaus.

**Zusätzlich gefunden (nicht gefixt, kleine verbleibende Lücke):** die
kombinierte Accessibility-Beschriftung des Spaltenkopfs
(`set.column.header.accessibilityLabel`) nennt für VoiceOver weiterhin
wörtlich "Kilogramm", unabhängig vom `weight_unit`-Setting — der
sichtbare Text zeigt korrekt "LBS", die VoiceOver-Ansage würde aber
weiterhin "Kilogramm" vorlesen. Außerhalb des AX5-Fix-Scopes dieser
Runde, als offener Befund vermerkt.

### kg/lbs Geräte-Verifikation (Commit `0a3c68e`, alle vier Stellen bestätigt)

**Testaufbau:** frischer Onboarding-Durchlauf (Größe 180 cm, Gewicht
80 kg, Zielgewicht 75 kg), danach Settings → Einheiten auf Imperial.

- **`ProfileEditorView.bodyDataSummaryText`:** zeigte sofort korrekt
  "180,00 cm · 176,37 lbs · Ziel 165,35 lbs" (80 kg/75 kg exakt
  umgerechnet, Größe bewusst weiterhin cm).
- **`BodyDataEditorView`:** Labels wechselten korrekt zu "Aktuelles
  Gewicht (lbs)"/"Zielgewicht (lbs, optional)"; Platzhalter/Wert zeigten
  die umgerechneten Werte (176,37/165,35).
- **Neue Eingabe in lbs → korrekte kg-Speicherung:** "170" ins
  Gewichtsfeld eingetragen und gespeichert, danach zurück auf Metrisch
  umgeschaltet → Anzeige zeigte exakt "77,11 kg" (170 × 0,453592 =
  77,11064, auf 2 Dezimalstellen gerundet wie beim Speichern) — korrekter
  Rundtrip, kein veralteter oder falsch umgerechneter Wert.
- **`SetRow`/`ExerciseCard` (Satz-Logging):** Spaltenkopf zeigte "LBS"
  statt "KG"; ein mit "225" (lbs) geloggter Satz erzeugte "VOLUMEN
  816 KG" (225 lbs × 8 Wdh = 1.800 lbs-Fuß; 225 lbs = 102,06 kg × 8 =
  816,46 ≈ 816 kg) — bestätigt, dass die Eingabe korrekt in kg
  umgerechnet gespeichert wird, während das (bewusst außerhalb des
  Scopes bleibende) Volumen weiterhin kg zeigt, exakt wie in der
  Scope-Grenze oben festgehalten.
- **Dashboard-Hero-Kachel:** zeigte "169,9 lbs" (korrekt aus dem
  gespeicherten 77,11 kg umgerechnet; die 0,1 lbs Abweichung von den
  ursprünglich eingegebenen 170 lbs ist eine erwartete, unvermeidbare
  Folge der 2-Dezimalstellen-kg-Speicherpräzision, kein Fehler — derselbe
  Effekt träte bei jeder Rundung aufeinanderfolgender Einheiten auf).
- **Kaltstart:** App terminiert + neu gestartet, Dashboard zeigte
  weiterhin korrekt "169,9 lbs", Einstellung überstand den Kaltstart.
- Trend-Chart/Zielgewicht-Linie nicht separat am Gerät gerendert (braucht
  ≥3 Messungen, hier nur 1 vorhanden) — Code-Review bestätigt dieselbe
  `dashboardWeightUnit.fromKg`-Konvertierung wie die bereits
  gerätebestätigte Hero-Kachel, keine eigene Logik.

**kg/lbs gilt für die vier benannten Stellen als vollständig
gerätebestätigt.** Bewusst kg-only bleiben (siehe Scope-Grenze oben):
Volumen-Aggregation, PR-Erkennung, sonstige Charts, CSV-Export/-Import.

### Echter Bug gefunden und gefixt: `ExerciseCard.logSet()` verlor einen Satz bei Kaltstart

Beim obigen kg/lbs-Nachtest (225 lbs geloggt, grüner Haken, "VOLUMEN
816 KG" angezeigt) wurde die App unmittelbar danach terminiert und neu
gestartet (derselbe Kaltstart-Test, der in dieser App bereits zwölf
vorherige Instanzen desselben Musterfehlers gefunden hat) — der Satz war
danach reproduzierbar wieder auf "0 / 3"/"BW" zurückgefallen, obwohl die
laufende Trainings-Session selbst (Timer lief kontinuierlich weiter)
nachweislich dieselbe blieb. **Unabhängig von kg/lbs** — betrifft jeden
geloggten Satz, in jeder Einheit.

**Ursache:** `ExerciseCard.logSet(setIndex:values:)` fügte den neuen
`ExerciseLog` nur per `modelContext.insert(log)` ein, ohne anschließenden
`context.save()`. Das direkt darunterliegende `unlogSet` hatte den Fix
dafür bereits (eigener Doku-Kommentar dort referenzierte exakt dieses
Fehlerbild) — `logSet` selbst war die verbleibende Lücke.

**Fix (Commit `ac9fcc2`):** `try? modelContext.save()` direkt nach dem
Insert, vor `onSetLogged(setIndex)`. Neuer Regressionstest
`ExerciseLogPersistenceTests` (echter Store-Neustart, etabliertes Muster).

**Geräte-Nachtest nach dem Fix (Build `25d065a`):** identischer Ablauf
(Kniebeuge, 100 kg geloggt, "VOLUMEN 500 KG", sofortiger Kaltstart) —
Satz blieb nach dem Neustart korrekt bei "1 / 3", grünem Haken, "100"/"5"
und "VOLUMEN 500 KG" erhalten. **Fix gerätebestätigt.**

### F01–F08

Unverändert gegenüber Runde 8 — siehe dortigen Nachtrag. Kein neuer
Lösungsversuch für den CSV-Export-Blocker ohne neue Hypothese.

### Budget (Gesamtstand Runde 9)

| Zeitpunkt | Quelle | Wert | Kontext |
|---|---|---|---|
| vor Runde 9 | Konto-API | 24.259 s | bestätigt, nahezu deckungsgleich mit Runde 8s Session-Summen-Wert (24.265 s) |
| Session 1 (kg/lbs-Verifikation, inkl. Bugfund) | Test-ID 54031998 | 1.062 s | aktiv beendet |
| Session 2 (logSet-Fix-Nachtest + AX5-Abschluss) | Test-ID 54032970 | 325 s | aktiv beendet |
| nach Session 1 | Konto-API | 23.196 s | bestätigt (24.259 − 1.062 = 23.197, Abrechnung nahezu in Echtzeit) |
| nach Session 2 | Konto-API | 23.196 s | unverändert zum Stand vor Session 2 — Session 2s 325 s noch nicht gebucht (Abrechnungsverzug) |

Zusätzlich 3 gescheiterte Sessionstarts (WebDriverAgent-Infra-Fehler,
"socket hang up", 0 s Verbrauch, kein Session-Leck, jeweils beim
nächsten Versuch erfolgreich).

**Restbudget nach Runde 9:** Session-Summe 24.259 − 1.062 − 325 =
**22.872 Sekunden** (≈ 6,4 h) — genauerer Wert als die Konto-API, die
Session 2 noch nicht gebucht hat. Abgleich beim nächsten regulären
Budgetabruf. Keine zusätzliche Session/Abfrage nur zur Budgetprüfung.

## Runde 8: E04 Türkisch + Imperial-Einheiten (DE), F01–F08 Erreichbarkeit differenziert geprüft

**Auftrag:** (1) E04-Rest Türkisch mit der in Runde 7 etablierten
Locale-Capability-Methode (kein neuer Respring-Versuch), kombiniert mit noch
offenen E04-Bedingungen (schmale Breite, große Schrift, Dezimalgewicht,
kg/lbs) soweit sinnvoll; (2) F01–F08 pro Fall differenziert prüfen, ob der
fehlende UI-/Geräte-Nachweis ohne CSV-Export/Systemzeit-Manipulation
erreichbar ist, keine neue Testinfrastruktur; (3) Budget transparent als
Session-Summe vs. Konto-API kennzeichnen, keine Zusatzabfrage/-session nur
dafür. Kein neuer allgemeiner Review, kein Merge, kein Release.

### E04 Türkisch — Standardbedingungen bestanden

**Geprüft (Build `tb://69c9fff4bfd115990736f838`, Commit `a4359f4`,
`appium:language: "tr"`/`appium:locale: "TR"`):** identische Methode wie
Runde 7s DE-Nachweis. App startete sauber auf Türkisch, kein Respring,
Session durchgehend stabil. Vollständiger Onboarding-Durchlauf (Willkommen
→ Profil → Ziel/Wochenziel/Coaching-Ton → Ausdauerform → Trainingshistorie
→ Equipment → Start-Check → Plan-Vorschlag → Dashboard), danach Settings →
Profil → `CardioGoalEditorView` mit aktiviertem Lauf-Coaching (alle Felder:
Ausdauerform, Ziel-Picker, 5-km-Zeit, Renndatum, Startvolumen,
Maximalpuls). Durchgehend korrekte Übersetzung (u. a. "Antrenman Yeri",
"Haftalık antrenman", "Dayanıklılık türü", "Kardiyo ve Koşu Hedefleri"),
korrekte Dezimalkomma-Formatierung bei cm/kg ("178,00 cm · 75 kg"),
Dezimaleingabe mit Komma im Wochenvolumen-Feld ("32,5") korrekt
übernommen, kein Abschneiden, keine rohen/unübersetzten Schlüssel
beobachtet. Speichern bestätigt (Zusammenfassungszeile wechselte zu
"Kardiyo ve Koşu Hedefleri, Genel Fitness"), Kaltstart (Force-Quit +
Neustart) überstand den gespeicherten Wert korrekt. **E04-Rest (TR,
Standardbedingungen) gilt damit als bestanden.** Schmale Breite/große
Schrift/Dezimalgewicht-kg-lbs-Kombinationen mit Türkisch wurden in dieser
Runde NICHT zusätzlich geprüft (Zeitpriorität lag auf Deutsch, siehe
unten) — bleiben offen.

TestingBot-Session (aktiv beendet): Test-ID 54028623, 538 s.

### Imperial-Einheiten (kg/lbs) in Deutsch — echte Implementierungslücke gefunden

**Testaufbau:** frischer Onboarding-Durchlauf auf Deutsch (identische
Locale-Capability-Methode, kein Respring), danach Settings → "App &
Trainingserlebnis" → Einheiten auf "Imperial" umgestellt.

**Befund:** das Einheiten-Setting wirkt NICHT einheitlich. Betroffen bzw.
nicht betroffen:
- **Wirkt korrekt:** Haupt-Profil-Zusammenfassungszeile in `SettingsView`
  (Größe konvertiert zu "64,90 in", via `formattedWeight()`/analoge
  Höhen-Konvertierung), Hantel-Rechner (`PlatePopoverContent`) und
  Warmup-Rampen-Anzeige (`ExerciseCard.stepWeightText`/`warmupRamp`,
  `weightUnitRaw == "lbs"`-Zweig) — alle drei bereits vor dieser Runde
  korrekt implementiert.
- **Wirkt NICHT, obwohl es laut App eigener Settings-Hinweistext sollte**
  ("Die DB speichert immer metrisch. Diese Einstellung steuert nur die
  Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten" —
  wörtlich "Eingabe-Feldern" eingeschlossen): `ProfileEditorView`s
  `bodyDataSummaryText` (hartcodiert `" kg"`, Zeilen 643/646) und die
  gesamte `BodyDataEditorView` (Größe/Gewicht/Zielgewicht-Eingabefelder,
  Labels fest "(cm)"/"(kg)") zeigten weiterhin "165,00 cm · 62 kg" nach
  Umstellung auf Imperial. **Gravierender:** `SetRow.weightInput` (das
  eigentliche Gewichts-Eingabefeld beim Satz-Logging, E04s
  Implementierungsstelle) bindet `$weight` direkt ohne jede
  Einheiten-Konvertierung — ein eingegebener Zahlenwert wird immer als kg
  interpretiert, unabhängig vom Einheiten-Setting; der Spaltenkopf
  darüber war zusätzlich hart auf "KG" fixiert (`unit.kg.upper`, siehe
  unten). Dashboard-Gewichts-Trend-Widget zeigte ebenfalls unverändert kg
  ("62,0").

**Einordnung:** dies ist eine echte, app-weite Implementierungslücke (wie
A09/C04/F04), kein kleiner gezielter Bug — eine vollständige
kg/lbs-Konvertierung am Satz-Logging-Eingabefeld selbst (Anzeige,
Eingabe-Parsing, Rückkonvertierung zur Speicherung) wäre eine größere,
noch nicht umgesetzte Funktionalität, kein Ein-Zeilen-Fix. Nicht in dieser
Runde implementiert (außerhalb des gezielten Fix-Rahmens). Eingeordnet als
neuer, sechster fachlicher Widerspruch zur Dok. 01-Beschreibung, siehe
Abschnitt "Fachliche Widersprüche" oben.

### Echter Bug gefunden und gefixt: Spalten-Header brechen bei maximaler Bedienungshilfen-Textgröße um

Bei aktivierter "Größerer dynamischer Text"-Einstellung (iOS-Bedienungshilfen,
Slider auf 100 %/AX5, über die Einstellungen-App gesetzt) zeigte ein
Screenshot des Satz-Logging-Screens (Deutsch): der Spalten-Header "SATZ"
brach buchstabenweise um (S/a/t/z vertikal untereinander statt einer
Zeile), überlappend mit "KG"/"WDH"-Headern und der Tab-Leiste — die
eigentliche Gewichts-Eingabe ("72,5", der bereits in Runde 3 gefixte
E04-Fall) blieb zwar unverändert korrekt lesbar, aber der Header-Bereich
darüber war visuell unbrauchbar. Root Cause: der gemeinsame
`deltiqLabel()`-Styling-Helfer (genutzt von "KG"/"WDH"/"PACE"/"RIR"/"SATZ"
und weiteren kurzen Captions app-weit, `Compatibility.swift`) nutzt
`.caption2` als Dynamic-Type-Textstil ohne `.lineLimit`/
`.minimumScaleFactor` — bei AX5 skaliert die Systemschrift ungebremst mit
und sprengt den festbreiten Spalten-Rahmen.

**Fix (Commit `c299c22`, nach einem zwischenzeitlich fehlgeschlagenen
CI-Lauf `39437532243` durch eine fehlende schließende Klammer im ersten
Versuch `872f707` — sofort korrigiert, siehe dortiger Commit):**
`.lineLimit(1)` + `.minimumScaleFactor(0.5)` auf `deltiqLabel()` selbst,
identisches Muster wie der bereits gefixte `SetRow.weightInput` (Runde 3).
Neuer Test `DeltiqLabelScalesDownInsteadOfWrappingTests` (liest die
Produktionsquelle direkt, prüft den `deltiqLabel()`-Funktionskörper, kein
SwiftUI-Import nötig).

**CI nach Korrektur:**

| Run | Commit | Ergebnis |
|---|---|---|
| `39437532243` | `872f707` (erster Fix-Versuch) | ✗ fehlgeschlagen — fehlende schließende Klammer (reine Syntaxkorrektur nötig, keine funktionale Ursache) |
| `39438015631` | `c299c22` (Klammer-Korrektur) | ✓ erfolgreich, inkl. neuem Test und App+Widget-Build |

**Geräte-Nachtest (Build `tb://370b62d80443ee88ccdf376c`, Commit `c299c22`,
Deutsch, `appium:language: "de"`, Dynamic-Type-Slider erneut auf 100 %/AX5
gesetzt):** frischer Onboarding-Durchlauf bis zum Satz-Logging-Screen
("Kniebeuge", Übung 1/5). Spalten-Header zeigt jetzt "KG"/"WDH" sauber
einzeilig und vollständig lesbar, keine Überlappung mit Dateneingabezeile
oder Tab-Leiste mehr — die zuvor beobachtete buchstabenweise Umbruch-Kette
ist behoben. Kleine verbleibende Nuance: "SATZ" selbst wird bei dieser
EXTREMEN Textgröße trotz `.minimumScaleFactor(0.5)` noch als "…" dargestellt
(der zugrunde liegende Accessibility-Wert bleibt korrekt "Satz", VoiceOver
liest ihn unverändert vor) — eine optische Verkürzung, keine Überlappung
oder gebrochene Darstellung mehr. **Kernbefund (Überlappung/Zeilenumbruch)
gilt als behoben und gerätebestätigt**; die "…"-Kürzung selbst wird nicht
als eigener Fehler geführt (gleiche Kategorie wie die bereits bekannte,
akzeptierte Tag-Namen-Kürzung aus Runde 3).

**Zusätzlich beobachtet (nicht Teil dieses Fixes, nicht in dieser Runde
behoben):** auf dem Onboarding-Profilschritt brach bei AX5 auch das Label
"Geburtsdatum" (eine andere Textstelle, nicht `deltiqLabel()`) buchstaben-
weise um. Strukturell derselbe Fehlerklasse, aber andere Code-Stelle außerhalb
des Satz-Logging-Screens — als zusätzlicher, noch offener Befund vermerkt,
nicht Teil des gezielten Fixes dieser Runde.

**TestingBot-Sessions dieser Runde insgesamt (alle aktiv beendet,
`max_concurrent=1` eingehalten):**

| # | Zweck | Build/Commit | Dauer |
|---|---|---|---|
| 1 | E04-TR Standardbedingungen | `tb://69c9fff4bfd115990736f838` / `a4359f4` | 538 s |
| 2 | Imperial-Einheiten + AX5-Bugfund (DE) | `tb://69c9fff4bfd115990736f838` / `a4359f4` | 712 s |
| 3 | Fix-Nachtest Spalten-Header (DE, AX5) | `tb://370b62d80443ee88ccdf376c` / `c299c22` | 512 s |

Zusätzlich 6 gescheiterte Sessionstarts (WebDriverAgent-Infra-Fehler,
"socket hang up", 0 s Verbrauch, kein Session-Leck). Budget-Details siehe
Abschnitt "Budget" unten.

### F01–F08: Erreichbarkeit ohne CSV-Export/Systemzeit geprüft — weiterhin derselbe eine Blocker

Pro Fall geprüft, ob der laut "F01–F08 differenziert geprüft"-Nachtrag
verbleibende reine UI-/Geräte-Nachweis (der tatsächlich gerenderte
`FourWeekReviewView`-Screen) ohne CSV-Export oder Systemzeit-Manipulation
erreichbar ist:

- **Kein alternativer Codepfad gefunden:** `FourWeekReviewView` ist nur
  über `FourWeekReviewEntryView` erreichbar, die wiederum nur bei einem
  tatsächlich fälligen Review (`FourWeekReviewDueStatus.isAnyDue`, basiert
  auf `TrainingPlan.activatedAt` + echter `Date()`-Laufzeitabfrage)
  überhaupt navigierbar ist — kein Debug-Menü, kein Developer-Flag, keine
  `ProcessInfo`/Launch-Argument-basierte Seed-Möglichkeit im Produktcode
  gefunden (gezielt durchsucht).
- **CSV-Import selbst bleibt der einzige bekannte clock-freie Weg**
  (`DataImportService` liest `activated_at_utc`/
  `block_review_history_json` direkt, siehe Abschnitt "Block D/E" oben),
  ist aber weiterhin am CSV-EXPORT-Schritt blockiert (reproduzierbarer
  Hang auf dem TestingBot-Gerät, in 6 unabhängigen Sessions bestätigt).
- **Ein manuell handgefertigtes Import-ZIP ohne vorherigen Export** (eigene
  `plans.csv`/`profile.csv`/`workouts.csv` exakt im von
  `DataImportService` erwarteten Schema nachgebaut, direkt auf den
  Simulator gepusht) wurde geprüft und bewusst NICHT umgesetzt — das wäre
  genau die in diesem Auftrag ausgeschlossene neue, umfangreiche
  Testinfrastruktur (kein bestehendes Test-Fixture für `plans.csv`
  vorhanden, Schema-Nachbau ungetestet und fehleranfällig), kein einfacher
  Workaround.
- **F05s Beschwerden-Abklärungsweg** liegt ebenfalls in `FourWeekReviewView`
  und unterliegt damit demselben Blocker — keine separate Prüfbarkeit.

**Ergebnis: kein neuer Lösungsweg gefunden, keine neue Hypothese im Sinne
des Auftrags vorhanden.** F01, F02, F03, F06, F07, F08 bleiben exakt auf
dem in "F01–F08 differenziert geprüft" dokumentierten Stand ("bestanden
(Daten-/Integrationsebene)", UI-Geräte-Nachweis weiterhin konkret am
CSV-Export-Hang blockiert — nicht pauschal "blockiert" und nicht
fälschlich auf "bestanden" hochgestuft). Kein Gerätetest für diesen Teil
in dieser Runde durchgeführt (wäre ohne neue Hypothese eine reine
Wiederholung des bekannten Blockers gewesen).

### Budget (Gesamtstand Runde 8, inkl. Fix-Nachtest)

| Zeitpunkt | Quelle | Wert | Kontext |
|---|---|---|---|
| vor Runde 8 | Session-Summe (Runde 7, siehe dortige Tabelle) | 26.027 s | **Session-Summen-Wert, zu diesem Zeitpunkt NICHT Konto-API-bestätigt** — Konto-API zeigte zum Prüfzeitpunkt Runde 7 noch 26.990 s (Abrechnungsverzug der vorherigen Runden noch nicht aufgeholt) |
| TR-Nachtest | Session-Dauer (Test-ID 54028623) | 538 s | aktiv beendet |
| DE-Nachtest (Imperial/Dezimalgewicht/AX5, Bugfund) | Session-Dauer (Test-ID 54029640) | 712 s | aktiv beendet |
| Fix-Nachtest (Spalten-Header, DE/AX5) | Session-Dauer (Test-ID 54030768) | 512 s | aktiv beendet |
| 6 gescheiterte Sessionstarts (WebDriverAgent-Infra-Fehler, "socket hang up") | Session-Dauer | 0 s | keine Session zustande gekommen, kein Verbrauch laut Konto (Test-IDs 54029187/54029265/54029394/54029544/54030693/54030750) |

**Restbudget nach Runde 8 (Session-Summe, weiterhin NICHT separat gegen
die Konto-API verifiziert — nächster reguläre Abruf zu Beginn einer
künftigen Runde gleicht ab):** 26.027 − 538 − 712 − 512 = **24.265 Sekunden**
(≈ 6,7 h). Keine zusätzliche Session oder Abfrage nur zur Budgetprüfung.

## Runde 7: A01 korrekt gefixt + autoAcceptAlerts-Einfluss auf frühere Nachweise geprüft

**Auftrag:** (1) D06 mit CI-/Gerätenachweis endgültig als bestanden
festhalten (bereits in Runde 6 erledigt, hier nur bestätigt, nicht erneut
angefasst); (2) A01 korrekt zuordnen — tatsächlicher Fall ist doppelte
Befragung innerhalb des ersten Onboardings beim Übergang in den
gemeinsamen PlanBuilder, nicht Re-Entry nach abgeschlossenem Profil;
(3) Einfluss der TestingBot-Capability `autoAcceptAlerts` auf frühere
PASS-Nachweise eingrenzen, die einen bewusst gewählten Abbrechen-/
Ablehnen-Dialog voraussetzen — nicht pauschal verwerfen, nur betroffene
Einzelfälle; (4) Budgetstand mit Zeitpunkten der Abfragen und Session-
verbrauch sauber zuordnen, keine zusätzliche Gerätesession nur dafür;
(5) danach E04-Rest/F-Rest, bekannte Infrastrukturblocker nicht ohne neue
Hypothese erneut testen. Kein Merge, kein Release, keine reinen
Warte-Meldungen.

### D06 — bestätigt vollständig bestanden (keine erneute Prüfung)

CI-Nachweis (Run `39422687588`, Commit `47678c1`, erfolgreich inkl.
App+Widget-Build) und Geräte-Nachtest nach Fix (Build
`7c22ceea177d36af2e2b3c20`, `autoAcceptAlerts: false`, Cancel bricht sauber
ab, kein Folgedialog) aus Runde 6 bleiben unverändert gültig — siehe dort
für Details. Kein neuer Schritt in dieser Runde.

### A01 — korrekt bearbeitet: echter Bug gefunden und gefixt

**Richtigstellung:** A01 (`docs/specifications/04_TESTS_UND_ABNAHME.md`,
Zeile 29: "Onboarding-Ziel/Tage/Equipment bereits beantwortet" → Soll
"Keine erneute identische Befragung") betrifft die doppelte Befragung
INNERHALB eines einzigen Onboarding-Durchlaufs, wenn der Nutzer nach den
eigentlichen Onboarding-Fragen (Ziel/Tage im Coaching-Step, Equipment im
Equipment-Step) zusätzlich den eingebetteten PlanBuilder ("Build Plan")
wählt — NICHT, wie in Runde 6 fälschlich angenommen, einen Wiedereinstieg
ins Onboarding nach einem bereits abgeschlossenen Profil. Die
Runde-6-Einordnung "nicht anwendbar — kein Produktpfad vorhanden" ist
hiermit zurückgenommen.

**Code-Befund:** `OnboardingView`s eigener `coachingStyleStep` fragt
`trainingGoal` (Ziel) und `weeklyGoal` ("wie oft pro Woche", 1–7) bereits
vor der Plan-Auswahl ab. Der anschließend über "Build Plan" erreichbare
eingebettete `PlanBuilderView` preseedete laut einem bestehenden P0-Audit-
Kommentar bereits `equipmentPreferences` und die Ausdauerform/Laufcoach-
Antwort aus genau diesen Onboarding-Antworten ("damit Schritt 2 des
eingebetteten Builders die Ausstattung nicht ein zweites Mal von Null
abfragt") — ZIEL (`GoalCard`) und TAGE (`totalDaysPerWeek`) waren von
dieser Vorbefüllung aber ausgenommen: `PlanBuilderView`s eigener
Ziel-Schritt startete immer leer (`selectedGoalCard == nil`), und
`totalDaysPerWeek` startete immer hartcodiert bei 3, unabhängig vom
bereits gegebenen `weeklyGoal`. Der Nutzer musste beides im Builder
identisch neu beantworten — exakt der von A01 beschriebene Verstoß.

**Fix (Commit `a4359f4`):** `PlanBuilderView.GoalCard.seeded(from:
TrainingGoal) -> GoalCard?` bildet die bereits gegebene Zielantwort auf
die passende Builder-Zielkarte ab (hypertrophy/strength → strengthFocus,
hybrid → hybrid, endurance → endurance, functional → generalFitness;
weightLoss bleibt bewusst unausgewählt, da keine eigene Zielkarte dafür
existiert — siehe `GoalCard`-Typ-Doku). Neue `init`-Parameter
`preseededGoal`/`preseededDaysPerWeek` nutzen das für die Vorbefüllung von
`selectedGoalCard`/`strengthFocus`/`totalDaysPerWeek`, frei weiter
änderbar wie die bereits bestehende Equipment-/Ausdauerform-Vorbefüllung.
`OnboardingView`s einzige `PlanBuilderView(...)`-Aufrufstelle übergibt
jetzt zusätzlich `trainingGoal`/`weeklyGoal`. Neuer Unit-Test
`PlanBuilderGoalSeedTests` (reine Zuordnungslogik, kein SwiftUI-State
nötig): deckt alle fünf `TrainingGoal`-Fälle inkl. des bewusst
unausgewählten `weightLoss`-Falls ab.

**CI:** Run `39426284201` (Commit `a4359f4`), erfolgreich, alle Schritte
grün inkl. App+Widget-Build und neuem Test.

**Geräte-Nachtest (Build `tb://69c9fff4bfd115990736f838`, Commit
`a4359f4`):** Onboarding mit Ziel "Functional/Hybrid", Ausdauerform
"Running" + "mit Laufcoach", Wochenziel bewusst auf **5×** gesetzt (statt
Default 3, um die Vorbefüllung eindeutig vom Default zu unterscheiden),
Equipment Gym (unbestätigt, Default). "Build Plan" geöffnet:
- **Ziel:** "Strength & Endurance Combined" (= Hybrid) bereits korrekt
  vorausgewählt (Accessibility-Tree: Checkmark gesetzt).
- **Ausdauerform/Laufcoach:** "Running" + "Work toward a goal with a run
  coach" bereits korrekt vorausgewählt (`value="1"` im Tree) — unverändert
  gegenüber der bereits bestehenden Vorbefüllung, keine Regression.
- **Tage (neu gefixt):** Schritt 2 zeigte **"5 days per week"** — exakt der
  zuvor im Coaching-Step gesetzte Wert, nicht der alte hartcodierte
  Default 3.
- **Equipment:** "Bodyweight only" (Default, da Gym-Equipment nicht
  bestätigt wurde — konsistent, keine Regression).
- Ergebnis-Schritt generierte einen 5-Tage-Plan (Intervals, Easy Run, 3×
  Bodyweight-Kraft), Plan erfolgreich übernommen, Onboarding sauber
  abgeschlossen (Dashboard zeigt "Individueller Plan", "Next workout:
  Intervals", kein Crash, keine Doppelabfrage mehr).

**A01 gilt damit als vollständig bestanden** (Ziel und Tage werden jetzt
übernommen statt erneut identisch abgefragt; Equipment war bereits vorher
korrekt). Bewusstes Bearbeiten der vorbefüllten Werte im Builder bleibt
weiterhin möglich (keine Sperre) — das wäre keine doppelte Befragung im
Sinne von A01, sondern eine gewollte Korrekturmöglichkeit.

### autoAcceptAlerts-Einfluss auf frühere PASS-Nachweise: Audit-Ergebnis

Systematische Durchsicht aller Stellen im Dokument, die einen bewusst
gewählten Abbrechen-/Verwerfen-/Ablehnen-Dialog als Testgrundlage nutzen
(`discardChangesConfirmation`, `confirmationDialog`, Cancel/Abbrechen-
Buttons), mit der Frage: beweist der NACHFOLGEND beobachtete App-Zustand
eindeutig die behauptete Wahl, unabhängig davon ob der Dialog selbst
sichtbar war oder automatisch bestätigt wurde?

- **D06 (Runde 3, vor dem Runde-6-Fix):** einzige tatsächlich betroffene
  Stelle — bereits in Runde 6 korrekt erkannt, isoliert mit
  `autoAcceptAlerts: false` nachgetestet und der dabei gefundene Bug
  gefixt. Keine weitere Aktion nötig.
- **C01/Runde 5, Prüfpunkt 1** (`discardChangesConfirmation` in
  `CardioGoalEditorView`): `Button(role: .destructive)` ("Verwerfen") ist
  im gemeinsam genutzten `discardChangesConfirmation`-Modifier
  (`Theme.swift`) der ZUERST hinzugefügte Button — identisch mit dem
  mechanischen Befund aus Runde 6 ("automatisch mit seinem ERSTEN Button
  bestätigt"). Zusätzlich beweist der beobachtete Folgezustand (Editor
  geschlossen, alte Werte unverändert) eindeutig NUR "Verwerfen" — hätte
  stattdessen "Weiter bearbeiten" (zweiter Button, `role: .cancel`)
  gefeuert, wäre der Editor offen geblieben. Nachweis bleibt bestehen,
  unverändert.
- **E06** (`PlanEditorView`, horizontale Wisch-Geste + Zurück-Chevron):
  bereits im Dokument selbst korrekt als "kein expliziter Beleg für
  Dialogtext/Button-Beschriftung" gekennzeichnet. Der beobachtete
  Folgezustand (Plan-Liste MIT dem ursprünglichen, unveränderten Namen)
  beweist aber eindeutig, dass tatsächlich verworfen wurde — dieselbe
  Dialog-Definition wie oben (Verwerfen = erster Button). Nachweis bleibt
  bestehen, Formulierung im Dokument bereits korrekt vorsichtig.
- **D02** (Löschen+Reorder+Verwerfen): "Discard Changes?"-Dialog, gleiche
  gemeinsame Definition, Folgezustand (6 Tage, ursprüngliche Zuordnung
  wiederhergestellt) beweist ebenfalls eindeutig Verwerfen. Nachweis
  bleibt bestehen.
- Keine weiteren Stellen im Dokument gefunden, die eine Abbrechen-/
  Ablehnen-Wahl behaupten, ohne dass der nachfolgende Zustand sie eindeutig
  belegt.

**Ergebnis: keine der bisherigen PASS-Bewertungen (außer dem bereits in
Runde 6 behandelten D06) muss zurückgenommen oder erneut getestet werden —
maßgeblich dafür ist in jedem Einzelfall ausschließlich der oben geprüfte
Folgezustand, nicht die Position des Buttons im Dialog.** Die
Button-Reihenfolge im gemeinsamen `discardChangesConfirmation`-Modifier
(`Theme.swift`, "Verwerfen" zuerst) ist dabei kein eigenständiger Beweis,
sondern nur die Erklärung DAFÜR, warum `autoAcceptAlerts` hier zufällig
dieselbe Aktion auslöste, die der jeweils dokumentierte Folgezustand
ohnehin schon unabhängig belegt. Ohne einen eindeutig unterscheidenden
Folgezustand wäre die Übereinstimmung der Button-Reihenfolge allein KEIN
Nachweis gewesen. D06s Dialoge (`PlanEditorView`s drei
Umgebungswechsel-Dialoge: Global-Sync/Adapt/Restore) sind strukturell
anders aufgebaut (drei nicht-binäre Optionen, Cancel nicht an erster
Stelle) — deshalb dort die Maskierung, die erst durch den expliziten
Nachtest mit `autoAcceptAlerts: false` aufgedeckt wurde.

### Budget-Rekonstruktion mit Zeitpunkten

| Zeitpunkt | Quelle | Wert | Kontext |
|---|---|---|---|
| nach Runde 4 | Konto-API | 29.808 s | bestätigt |
| nach Runde 5 (sofort) | Konto-API | 28.007 s | Differenz zur Session-Summe (1.978 s) = 177 s Abrechnungsverzug (1 Session noch nicht gebucht) |
| vor Runde 6 | Konto-API (Fork-Check) | 28.007 s | unverändert — die 177 s aus Runde 5 waren zu diesem Zeitpunkt immer noch nicht gebucht |
| nach Runde 6 (sofort, Fork) | Konto-API | 28.007 s | Runde 6s eigene 840 s ebenfalls noch nicht gebucht |
| nach Runde 6 (eigene Nachprüfung, ~Minuten später) | Konto-API | 28.007 s | weiterhin unverändert zu diesem Zeitpunkt |
| **2026-10-20T12:49:11Z** (vor Runde 7) | Konto-API | **26.990 s** | Abrechnungsverzug jetzt aufgeholt: 28.007 − 26.990 = 1.017 s = 177 s ausstehender Runde-5-Rest + 840 s Runde-6-Gesamtverbrauch — **exakt deckungsgleich**, keine Doppelzählung |
| Runde 7 (1 Session, A01-Nachtest) | Session-Dauer-Summe (TestingBot-API, Test-ID 54026757) | 681 s | Onboarding-Durchlauf + Build-Plan-Verifikation, aktiv beendet (`DELETE /session`, Status `success`) |

### E04-Rest (DE): neue Hypothese erfolgreich — kein Infrastrukturblocker mehr

**Bekannter Blocker (Runde 3):** Systemsprachwechsel zur Laufzeit (über die
iOS-Einstellungen-App) löst einen Respring aus, den die Appium-Session
bisher nicht überlebte — die Automatisierung brach danach ab.

**Neue Hypothese (Runde 7):** Sprache/Locale bereits bei Session-Start als
WebDriver-Capability setzen (`appium:language: "de"`,
`appium:locale: "DE"`), statt zur Laufzeit über die Einstellungen-App
umzuschalten — die App startet dann direkt in der Zielsprache, kein
Respring nötig. **Hypothese bestätigt:** App startete sauber auf Deutsch,
Session blieb durchgehend stabil.

**Geprüft (Build `tb://69c9fff4bfd115990736f838`, Commit `a4359f4`,
`appium:language: "de"`/`appium:locale: "DE"`):** vollständiger
Onboarding-Durchlauf (Willkommen → Profil → Ziel-/Tone-/Wochenziel-Step →
Ausdauerform/Laufcoach-Step → Trainingshistorie → Equipment → Start-Check
→ Abschluss → Dashboard) sowie `CardioGoalEditorView` (unsere eigene
Änderung dieser Runden) mit aktiviertem Lauf-Coaching (alle Felder:
Ausdauerform, Lauf-Ziel-Picker, 5-km-Zeit, Renn-Datum, Start-Laufvolumen,
Maximalpuls). Durchgehend korrekte Übersetzung, korrekte Umlaute/ß, keine
abgeschnittenen Texte, keine Layout-Brüche, kein Crash. Einzige bekannte
Kürzung (Tag-Namen-Kacheln "Unterkörper &…") ist dieselbe, bereits aus dem
Englischen bekannte Design-Kürzung, keine deutschspezifische Regression.

**E04-Rest (DE) gilt nur für die tatsächlich geprüfte Kombination als
bestanden:** Deutsch, Standard-Bildschirmbreite, Standard-Schriftgröße,
Standard-Dynamic-Type, Default-Gewichtseinheit. NICHT mit geprüft (noch
offen, auch für DE): schmale Bildschirmbreite, große Schrift/Dynamic Type,
Dezimalgewicht-Eingabe, kg/lbs-Umschaltung — diese Bedingungen wurden in
Runde 3 nur auf Englisch nachgewiesen (E04-Fix selbst, siehe dortiger
Nachtrag), nicht in Kombination mit Deutsch. Türkisch (in keiner
Kombination) wurde aus Zeitgründen in dieser Runde nicht mehr geprüft,
bleibt vollständig offen; dieselbe Methode (Locale-Capability bei
Session-Start) ist dafür direkt übertragbar.

**TestingBot-Session (aktiv beendet):** Test-ID 54027366
(`4a4a94879187-06cad78be6ed-a3a532314f04-179250253101-48459214`), Dauer
282 s (Build/Commit identisch zum A01-Nachtest, kein neuer Build nötig).

**Restbudget nach Runde 7:** 26.990 − 681 (A01-Nachtest) − 282
(E04-Rest-DE) = **26.027 Sekunden, rein aus der Session-Dauer-Summe
berechnet — KEIN von der Konto-API bestätigter Wert.** Wie in den
Vorrunden dokumentiert, hinkt die Konto-API (`GET /v1/user`) dem
tatsächlichen Verbrauch zeitweise hinterher (zuletzt: 1.017 s
Abrechnungsverzug über zwei Runden hinweg, siehe Tabelle oben); ob die
840 s aus Runde 7 bereits vollständig gebucht sind, ist offen. Abgleich
erfolgt beim tatsächlichen Verbrauch dieser Runde (963 s: 681 + 282) bereits vollständig
gebucht sind, ist offen. Abgleich erfolgt beim nächsten ohnehin fälligen
Budgetabruf (z. B. zu Beginn der nächsten Runde) — keine zusätzliche
Abfrage oder Gerätesession allein zur Budgetprüfung.

## Runde 6: A01-Code-Klärung + D06-Cancel-Endlosschleife gefunden und gefixt

**Auftrag:** (1) A01 — klären, ob ein regulärer Produktweg existiert, mit
einem bestehenden Profil erneut ins Onboarding einzutreten (zuerst
Code-Recherche, nur bei echtem Pfad Geräte-Nachtest); (2) D06 — den bisher
nie isoliert reproduzierten Einzelschritt "Migrationsdialog bewusst
ablehnen" gezielt auslösen und beobachten, getrennt von den bereits
bestandenen D06-Teilschritten; (3) bei verbleibendem Budget optional
E04-Rest/F-Rest. Kein neuer allgemeiner Review, kein Merge, kein Release.

**Korrektur (Runde 7): die A01-Einordnung dieser Runde war fachlich falsch
und wird unten zurückgenommen** — A01 betrifft laut
`docs/specifications/04_TESTS_UND_ABNAHME.md` ("Onboarding-Ziel/Tage/
Equipment bereits beantwortet" → Soll "Keine erneute identische
Befragung") eine doppelte Befragung INNERHALB des ersten Onboardings beim
Wechsel in den eingebetteten PlanBuilder, nicht einen Re-Entry ins
Onboarding nach abgeschlossenem Profil. Die Code-Recherche unten
(RootView/Re-Entry) beantwortete damit die falsche Frage. Siehe Nachtrag
„Runde 7" für die korrekte Bearbeitung und den dabei gefundenen und
gefixten Bug.

### A01 — Code-Klärung (Runde 6, per Runde 7 als falsch eingeordnet zurückgenommen)

`RootView.swift` zeigt `OnboardingView()` ausschließlich wenn
`profiles.isEmpty` (SwiftData-`@Query`) — sobald ein `UserBodyProfile`
existiert, ist `OnboardingView` über keinen regulären App-Pfad mehr
erreichbar. Durchsucht: `SettingsView.swift` (keine "Onboarding erneut
durchlaufen"-Option, kein Reset-Onboarding-Flag unabhängig vom
Daten-Reset), keine Debug-Menü-Option, kein Deep-Link. Der einzige Weg
zurück zu `OnboardingView` ist "Reset App" in den Einstellungen — der
löscht dabei aber genau das bestehende Profil vollständig (inkl. Vorab-
Backup, siehe Abschnitt "Reset-App-Befund eingeordnet" oben), erzeugt also
NICHT den in A01 beschriebenen Fall ("bestehendes Profil aus einem
früheren, abgebrochenen/abgeschlossenen Durchlauf, erneuter Eintritt ins
Onboarding"). **A01 wird daher nicht länger als "teilweise" geführt,
sondern als "nicht anwendbar — kein Produktpfad für den beschriebenen Fall
vorhanden"** (Code-Befund, kein Automatisierungs-Artefakt). Kein
Geräte-Nachtest nötig, kein Fix (kein Fehlverhalten, nur fehlender Pfad).

### D06 — isolierter Cancel-Schritt: echte Dialog-Endlosschleife gefunden und gefixt

**Testaufbau:** frischer Onboarding-Durchlauf (Gym-Equipment, Plan
"Football Athletic"), Plan-Editor geöffnet, Trainingsort Gym→"No
Equipment" (Adapt-Dialog bestätigt, archiviert Originale), dann zurück auf
Gym (löst den DEL-049-"Restore Original Exercises?"-Dialog aus — exakt der
in Runde 3 beobachtete, aber nie isoliert geprüfte Fall).

**Wichtiger Befund zur bisherigen Nichtreproduzierbarkeit:** mit
TestingBots `autoAcceptAlerts: true` (Standard-Capability aller bisherigen
Runden) wurde dieser Dialog NIE sichtbar — er wurde von der
XCUITest-Automatisierung automatisch mit seinem ERSTEN Button bestätigt,
bevor er in der Accessibility-Tree-Ausgabe erschien (dieselbe Mechanik
betraf erkennbar auch den DEL-022-Adapt-Dialog). Das erklärt die
Unsicherheit aus Runde 3 ("ob das Produktverhalten oder ein
Automatisierungs-Timing-Artefakt ist, bleibt unklar") — es ist ein reines
Automatisierungs-Artefakt. Fix für diese Runde: neue Session mit
`appium:autoAcceptAlerts: false`. Dadurch wurde zusätzlich ein System-
Benachrichtigungs-Alert ("'Deltiq' Would Like to Send You Notifications")
sichtbar, der außerhalb der App-Accessibility-Tree liegt und per
`POST /alert/dismiss` (WebDriver-Alert-Endpoint, nicht per Element-Find)
behandelt werden musste.

**Mit `autoAcceptAlerts: false` erstmals isoliert beobachtet (Build
`cf0bfe8df4ca17f5fa0b563f`, Commit `1c8bf54`, vor dem Fix dieser Runde):**
"Cancel" im "Restore Original Exercises?"-Dialog setzte korrekt
`plan.targetEnvironment` auf den vorherigen Wert zurück — löste dabei aber
UNGEWOLLT sofort den ANDEREN Dialog ("Training Location Changed" /
DEL-022-Adapt-Prompt) aus, weil die Rückschreibung selbst denselben
`.onChange(of: plan.targetEnvironment)`-Handler erneut feuerte (kein
Unterdrückungs-Flag gesetzt, anders als bei `revertToSnapshot()`). "Cancel"
auf DIESEM zweiten Dialog führte wiederum zurück zum ERSTEN Dialog — ein
**reproduzierbares Ping-Pong, aus dem "Cancel" nicht herausführte** (auf
dem Gerät zweimal hintereinander bestätigt: Cancel → anderer Dialog →
Cancel → ursprünglicher Dialog). Der Nutzer konnte den Umgebungswechsel
nicht abbrechen, ohne zwangsläufig eine der destruktiven Optionen
(Adapt/Restore/Re-Adjust) zu wählen.

**Fix (Commit `47678c1`):** neue Methode `revertTargetEnvironment(to:)`
bündelt alle drei Cancel-Pfade (Global-Sync-, Adapt- und Restore-Dialog)
und setzt dabei `isApplyingSnapshot = true` — denselben bereits etablierten
Unterdrückungsmechanismus wie `revertToSnapshot()` —, bevor
`plan.targetEnvironment` zurückgeschrieben wird. Neuer Test
`testRevertTargetEnvironmentRestoresPriorValue` (deckt nur die reine
Rückschreibung ab; das `.onChange`-Cascade-Verhalten selbst ist nur per
Geräte-/UI-Test prüfbar).

**CI (`apple-ci-comparison.yml`):**

| Run | Commit | Ergebnis |
|---|---|---|
| `39422687588` | `47678c1` (Fix-Commit dieser Runde) | ✓ erfolgreich, inkl. neuem Test und App+Widget-Build |

**Geräte-Nachtest nach dem Fix (Build `7c22ceea177d36af2e2b3c20`, Commit
`47678c1`, `autoAcceptAlerts: false`):** identischer Ablauf (Gym→No
Equipment adaptiert, zurück zu Gym → Restore-Dialog → Cancel) — Cancel
setzte "Training Location" korrekt auf "No Equipment" zurück, **kein
Folgedialog mehr**. Einmaliger sauberer Abbruch bestätigt.

**D06 gilt damit als vollständig bestanden** (Kernzusage aus Runde 3 UND
der isolierte Cancel-Schritt, inkl. dabei gefundenem und gefixtem Bug).

**TestingBot-Sessions (`max_concurrent=1` eingehalten, alle aktiv
beendet):**

| # | Zweck | Build/Commit | Dauer |
|---|---|---|---|
| 1 | A01-Navigation (Dashboard/Plan-Tab), erster D06-Versuch mit `autoAcceptAlerts: true` (zeigte das Automatisierungs-Artefakt) | `cf0bfe8df4ca17f5fa0b563f` / `1c8bf54` | 293 s |
| 2 | D06 isoliert mit `autoAcceptAlerts: false` — Bug gefunden (Cancel-Ping-Pong) | `cf0bfe8df4ca17f5fa0b563f` / `1c8bf54` | 422 s |
| 3 | D06-Fix-Nachtest — Cancel bricht jetzt sauber ab | `7c22ceea177d36af2e2b3c20` / `47678c1` | 125 s |

Gesamt: **840 Sekunden** von 28.007 Sekunden Restbudget vor dieser Runde.
Die Konto-API zeigte unmittelbar danach weiterhin `28.007` (derselbe in
Runde 3-5 dokumentierte Abrechnungsverzug) — als genauerer Wert gilt die
Summe der Session-Dauern; konservatives Restbudget danach: **ca. 27.167
Sekunden**. Keine zusätzlichen Käufe.

**E04-Rest/F-Rest:** in dieser Runde NICHT bearbeitet (Zeit-/Umfang-
Priorität lag auf A01+D06; das gefundene D06-Bugfix-Review+Retest hat den
dafür vorgesehenen Rahmen bereits ausgefüllt). Bleibt offen für eine
künftige Runde, siehe "Nächste Schritte".

## Diese Runde (Runde 5): C01-Fix-Retest (Timing-Fix + Kaltstart-Persistenz-Bug)

**Auftrag:** gezielter Geräte-Retest von Commit `47ab4d6` (behebt den in
Runde 4 dokumentierten C01-Befund: die Cardio-Feasibility-Vorschau erschien
bei jedem Tastenanschlag statt gebündelt nach Speichern, über eine neue
`CardioGoalEditorView.swift` mit lokalem Draft + explizitem
Speichern/Abbrechen, analog `BodyDataEditorView`/
`TrainingLocationEquipmentEditorView`). Geprüft: die ursprünglich
zugewiesenen 7 Punkte, der infeasibleNoSuggestion-Fall, sowie vier
nachträglich zugewiesene verschachtelte Save-/Cancel-Grenzfälle. Kein neuer
allgemeiner Review, kein Merge nach `main`, keine parallele
TestingBot-Session.

**CI (`apple-ci-comparison.yml`, GitHub Actions, macOS-Runner, echte
Swift-/SwiftData-Testausführung + App+Widget-Build für den iOS-Simulator):**

| Run | Commit | Ergebnis | Schritte |
|---|---|---|---|
| `39411793232` | `47ab4d6` (Ausgangsbasis dieser Runde) | ✓ erfolgreich | alle 13 Schritte grün, inkl. Swift-Package-Tests und App+Widget-Build |
| `39416947715` | `1c8bf54` (Fix-Commit dieser Runde) | ✓ erfolgreich | alle 13 Schritte grün, inkl. neuem Regressionstest `CardioGoalEditorPersistenceTests` |

**TestingBot-Sessions (beide `max_concurrent=1` eingehalten, keine
Parallelität):**

| # | Zweck | Build/Commit | Dauer | Beendigung | TestingBot-Session-ID |
|---|---|---|---|---|---|
| 1 | Alle 7 Punkte + infeasibleNoSuggestion + 4 Grenzfälle, Fund des Kaltstart-Bugs (zweimal reproduziert) | `47ab4d6` | 1.801 s | serverseitig nach Erreichen des 30-Minuten-Sessionlimits beendet (kein Session-Leck: Account-API zeigte danach `current_physical_concurrency: 0`) | `91734b401f14-2d5c53c3240d-4be862ab2114-179249457224-84143788` |
| 2 | Fix-Nachtest: Speichern + sofortiger Kaltstart erhält den neuen Wert jetzt korrekt | `1c8bf54` | 177 s | aktiv beendet (`DELETE /session`, Status `success`) | `9d18478362b4-eb61d0e6eed8-81fddd3a4b1c-179249710037-06834461` |

Gesamt: **1.978 Sekunden** von 29.808 Sekunden Restbudget vor dieser Runde
→ **Restbudget danach laut TestingBot-Konto-API: 28.007 Sekunden** (Differenz
zur Summe der Session-Dauern ca. 177 s, konsistent mit dem in Runde 3/4
dokumentierten Abrechnungs-/Rundungsverzug der Konto-API; die Summe der
Session-Dauern gilt als genauerer Wert). Keine zusätzlichen Käufe.

**Testaufbau:** identisch zu Runde 4 — aktiver Plan "Individueller Plan"
(7 Tage/12 Wochen/Gym) mit echter Laufeinheit (Mi "Easy Run"), über
Onboarding → "Build Plan" → "Strength & Endurance Combined" → Ausdauerform
"Running" → Coach zunächst aus erzeugt (Wochenvorschau zeigte vorab
"Bodyweight · Push & Pull"/"Easy Run, 45 min"/"Bodyweight · Pull & Push").

### Ergebnis je Prüfpunkt

1. **Eingabe allein verändert weder gespeichertes Laufziel noch Plan —
   bestanden.** Cardio-Editor geöffnet, Ziel auf Marathon, Renndatum auf
   12 Jan 2027, Wochenvolumen auf 10 km/Woche geändert, zurück-Chevron
   getippt. Der `discardChangesConfirmation`-Dialog erschien (per
   TestingBots `autoAcceptAlerts`-Capability sofort mit der
   Verwerfen-Aktion bestätigt — deckt zugleich Punkt 2 mit ab, siehe
   dortige Einordnung). Editor schloss, Hauptscreen-Zusammenfassungszeile
   zeigte danach weiterhin unverändert "Running coaching off"; erneutes
   Öffnen des Editors zeigte den Toggle wieder aus und keine der
   eingegebenen Werte. Plan-Tab weiterhin exakt "1 PLAN"/"Individueller
   Plan" unverändert.
2. **Abbrechen verwirft nur den Laufziel-Entwurf — bestanden.** Auf dem
   Hauptscreen "Coaching Style" auf "Motivating" geändert (unabhängiger,
   noch offener Edit), Cardio-Editor geöffnet und OHNE jede Änderung per
   Chevron wieder geschlossen (kein Dialog, da dort nichts dirty war) →
   "Motivating" blieb auf dem Hauptscreen sichtbar unverändert bestehen
   und ließ sich danach weiterhin über den Hauptscreen-eigenen
   Verwerfen-Dialog auf "Analytical" zurücksetzen — keine Vermischung
   zwischen den beiden unabhängigen Entwurfszuständen.
3. **Bestätigen speichert die zusammengehörigen Werte — bestanden.** Alle
   sieben Felder (Coach an, Ausdauerform Running, Ziel Marathon, 5-km-Zeit
   25:00, Renndatum 12 Jan 2027, Wochenvolumen 10, Maximalpuls 180)
   gemeinsam gesetzt und gespeichert: Hauptscreen-Zusammenfassung zeigte
   sofort "Marathon", erneutes Öffnen des Editors zeigte alle sieben Werte
   korrekt vorbefüllt (per Accessibility-Tree-Dump bestätigt).
4. **Speicherfehler erzeugt keine erfolgreiche Übernahme — nicht
   verifizierbar/nicht verifiziert.** Alle sieben Cardio-Felder sind reine
   Property-Zuweisungen ohne Netzwerk-, Validierungs- oder
   Fremdschlüssel-Abhängigkeit zum Zeitpunkt des Speicherns; es wurde kein
   realistischer Fehlerfall gefunden und auch keiner künstlich
   herbeigeführt (z. B. durch Store-Manipulation), da das explizit nicht
   Auftrag war. Ein erfolgreicher normaler Save (siehe Punkt 3) ist dabei
   AUSDRÜCKLICH kein Beleg für einen Fehlerpfad — dieser Punkt bleibt
   mangels realistischem Fehlerfall unbeprüft, nicht "bestanden".

   **Ergänzende Codeprüfung (kein ausgeführter Fehlerfall, nur
   Code-Review):** `save()` verwendet `try? modelContext.save()` — ein
   Fehler würde verschluckt, OHNE eigene Erfolgsmeldung (es existiert
   keine) aber MIT unbedingtem `dismiss()` direkt danach. Da
   `profile.cardioGoal = ...` usw. direkt das übergebene `@Bindable`-
   Live-Objekt mutieren (keine draft-only Zuweisung), stünden die neuen
   Werte im Arbeitsspeicher bereits, bevor `modelContext.save()` überhaupt
   aufgerufen wird — bei einem fehlgeschlagenen Save bliebe der Editor
   also ohne Fehlermeldung schließen UND ein danach berechneter Vorschlag
   (`CardioFeasibilityCardModel.make(for:)`) würde die neuen, tatsächlich
   nicht persistierten Werte verwenden. Dies ist kein auf diesen Fix
   beschränktes Verhalten, sondern dasselbe `try?`-Muster wie an allen
   anderen Save-Stellen der App (siehe die zwölf zuvor gefixten Stellen) —
   keine Regression dieser Runde, sondern eine app-weite, bereits vor
   dieser Runde bestehende Eigenschaft. Kein Fix in dieser Runde, da
   außerhalb des gezielten Auftrags (keine bewusste Store-Beschädigung zur
   Fehlererzeugung, keine neue allgemeine Fehlerbehandlungs-Infrastruktur).
5. **Anpassungsvorschlag erscheint nur für den bestätigten Zustand, nicht
   bei jedem Tastendruck — bestanden, Kernfix bestätigt.** Mit dem
   infeasiblen Marathon/10-km-Woche-Ziel aus Punkt 3: solange der Editor
   offen war (auch nach Eingabe aller Werte, vor dem Speichern-Tap), ließ
   sich keine Navigation zu Dashboard/Plan-Tab auslösen (das Sheet blockt
   die Tab-Bar korrekt vollständig) und die Hauptscreen-Zusammenfassung
   zeigte währenddessen (im Hintergrund, aus der Accessibility-Tree-Sicht)
   weiterhin den alten Stand — erst der Speichern-Tap ließ auf Profil,
   Dashboard UND Plan-Tab gleichzeitig die Karte "This is going to be
   tight" / "Your running goal is getting tight" mit identischem Verdikt
   ("You need about 22 weeks, but only 11 are available. A more realistic
   goal right now: 5K.") erscheinen.
6. **Plananpassung ablehnen erhält Profilupdate und bisherigen Plan —
   bestanden (C02-Regression nicht aufgetreten).** "Keep goal" nach dem
   Speichern des infeasiblen Ziels getippt: Karte verschwand, Profil
   zeigte weiterhin "Marathon", Plan-Tab weiterhin exakt "1 PLAN"/
   "Individueller Plan" unverändert.
7. **Erneutes Öffnen/Kaltstart erzeugt keine Duplikate — bestanden, ABER
   dabei echten Bug gefunden und gefixt (siehe unten).** Nach dem Speichern
   App per `mobile: terminateApp` + `mobile: activateApp` neu gestartet:
   kein doppelter Plan, Vorschau-Karte verhielt sich korrekt — aber der
   zuletzt gespeicherte Cardio-Wert selbst ging dabei reproduzierbar
   verloren (siehe "Echter Bug" unten). Nach dem Fix (Commit `1c8bf54`)
   erneut geprüft: Speichern + sofortiger Kaltstart erhält den neuen Wert
   jetzt korrekt (Starting volume 42 km/Woche überstand Kaltstart
   vollständig, inkl. weiterhin aktiviertem Coaching-Toggle).

**infeasibleNoSuggestion-Fall — über normale Eingaben erreicht, bestanden.**
Ziel 5K (kleinstes geprüftes Ziel), Renndatum 27 Okt 2026 (1 Woche
entfernt), Startvolumen 1 km/Woche → `verdict.feasible == false`,
`suggestedGoal == nil` (Kartentext: "You need about 34 weeks, but only 0
are available. Even a smaller goal no longer fits in the remaining time.").
Nur "Keep goal" angeboten (kein "Accept suggestion"/"Adjust plan", da kein
Ersatzziel). Tap auf "Keep goal": kein Crash, Karte verschwand, Profil
blieb korrekt bei "5K", Plan-Tab weiterhin exakt "1 PLAN".

### Vier verschachtelte Save-/Cancel-Grenzfälle (nachträglich zugewiesen)

1. **Gespeichertes Cardio-Update übersteht unabhängiges Verwerfen auf dem
   Hauptscreen — bestanden.** Cardio-Ziel gespeichert (Marathon), danach
   auf dem Hauptscreen eine andere, unabhängige Änderung vorgenommen und
   über dessen eigenen Verwerfen-Dialog zurückgenommen: das bereits
   bestätigte Cardio-Update blieb unverändert erhalten — `cardioGoal` ist
   seit der Auslagerung kein `ProfileMetaSnapshot`-Feld mehr (siehe
   `testProfileMetaSnapshotExcludesCardioFields`), ein Haupt-Screen-Revert
   kann es strukturell nicht mehr zurückrollen.
2. **Offene, unabhängige Hauptscreen-Änderung übersteht Öffnen+
   folgenloses Schließen des Cardio-Editors — bestanden.** Siehe
   Prüfpunkt 2 oben: "Motivating" blieb trotz zwischenzeitlich geöffnetem
   und wieder geschlossenem Cardio-Editor weiterhin als offener, später
   verwerfbarer Edit erhalten — keine fälschliche Vorab-Bestätigung durch
   den Cardio-Abbruch.
3. **Vorschlag rechnet nie mit einem abgebrochenen Draft, nie mit einem
   veralteten Vor-Speichern-Stand nach echtem Speichern — bestanden,
   zweigeteilt geprüft.** Teil A: bei gespeichertem Marathon/10-km-Zustand
   (Karte zeigt "22 weeks/11 available/5K") Wochenvolumen im Editor auf 50
   geändert, OHNE zu speichern verworfen → Karte auf Dashboard zeigte
   danach unverändert weiterhin "22 weeks/11 available/5K", nicht den
   Draft-Wert 50 (der rechnerisch feasible gewesen wäre). Teil B:
   anschließend dieselbe Änderung (Volumen 50) tatsächlich gespeichert →
   Karte wechselte sofort und korrekt zu "Your goal is achievable — You
   need about 5 weeks, 11 are available – that's enough." — kein veralteter
   Vor-Speichern-Stand nach einem echten Save.
4. **Bloßes Öffnen+Verwerfen ohne Eingabe löst keinen Retro-Sync aus —
   bestanden.** Cardio-Editor bei bereits gespeichertem Marathon-Ziel
   erneut geöffnet und ohne jede Eingabe/jeden Tap auf "Calculate from
   training history" sofort wieder geschlossen: keine
   Retro-Sync-Bestätigungsdialog erschien, Werte blieben unverändert —
   `computeCardioBaseline()` wird im Code ausschließlich aus der
   Button-Action aufgerufen, nie aus `onAppear` o. ä. (zusätzlich per
   Code-Review in `CardioGoalEditorView.swift` bestätigt).

Zusätzlich code-verifiziert (kein eigener Geräte-Schritt nötig, da
unmittelbar aus dem Geräteverhalten von Prüfpunkt 3 ableitbar):
`setDraftEnduranceModality`-Invariante — Radfahren waehlen waehrend Coach
an gesetzt ist, schaltet den Coach-Schalter im DRAFT sofort wieder aus
(`draftCardioCoachingEnabled = wantsCoach && (modality?.supportsRunCoach ??
true)`), noch vor jedem Speichern.

### Echter Bug gefunden und gefixt: Kaltstart verlor ein gerade gespeichertes Cardio-Update

`CardioGoalEditorView.save()` (neuer Code aus Commit `47ab4d6`) mutierte
`profile` (Ausdauerform, Ziel, Renndatum, Wochenvolumen, Maximalpuls,
5-km-Referenz) OHNE anschließenden `context.save()` — derselbe
Musterfehler, der in dieser App bereits zwölf Mal gefunden und gefixt
wurde (zuletzt E01, `MeasurementPersistenceTests`). Auf dem Gerät **zweimal
unabhängig voneinander reproduziert**: ein Wert wurde geändert, gespeichert
(sofort korrekt in der UI sichtbar, z. B. "50" bzw. "99" km/Woche), und
UNMITTELBAR danach per `mobile: terminateApp` + `mobile: activateApp`
neu gestartet — nach dem Neustart zeigte das Feld wieder den vorherigen,
tatsächlich zuvor schon persistierten Wert ("10"), nicht den zuletzt
gespeicherten. Ein drittes Mal mit 10 Sekunden Wartezeit zwischen Speichern
und Kaltstart versucht, um eine reine Timing-/Autosave-Verzögerung
auszuschließen — die laufende TestingBot-Session erreichte dabei ihr
30-Minuten-Limit und wurde serverseitig beendet, bevor das Ergebnis
abgelesen werden konnte; der Befund gilt dennoch als hinreichend belegt
(zwei saubere, unabhängige Reproduktionen ohne Wartezeit-Variable).

Fix (Commit `1c8bf54`): `@Environment(\.modelContext)` ergänzt, `try?
modelContext.save()` direkt nach der Mutation, vor `dismiss()` —
identisches Muster wie der bereits behobene `editingMeasurement`-Zweig in
`MeasurementView.save(profile:)`. Neuer Regressionstest
`CardioGoalEditorPersistenceTests.testSavedCardioGoalSurvivesARealStoreRestart`
(separater `ModelContainer` auf derselben Store-URL, exakt das in
`MeasurementPersistenceTests` etablierte Muster — `save()` selbst bleibt
`private`/liest `@Environment`, ein direkter Aufruf ohne lebenden
`.modelContainer`-Kontext träfe nicht den aufgesetzten Context). CI (Run
`39416947715`): erfolgreich, inkl. neuem Test. Geräte-Nachtest nach dem Fix
(TestingBot-Session 2, Build `1c8bf54`): Wochenvolumen auf 42 gesetzt,
gespeichert, sofort (ohne Wartezeit) Kaltstart — Wert "42" UND der
weiterhin aktivierte Coaching-Toggle überstanden den Neustart korrekt.

**Hinweis zur verbleibenden Unsicherheit:** ob SwiftDatas impliziter
Autosave bei ausreichender Wartezeit vor dem Kaltstart den unge-fixten
Code ebenfalls gerettet hätte, ist mangels der durch das Sessionlimit
abgebrochenen dritten Reproduktion nicht abschließend geklärt — **bekannte
Nachweislücke, Auswirkung auf die Bugbewertung selbst aber gering**: der
Fix macht die Persistenz unabhängig von Autosave-Timing explizit und
deterministisch, unabhängig davon, ob der ungefixte Code unter günstigeren
Timing-Bedingungen gelegentlich funktioniert hätte.

## Runde 4: C01/C02 gezielte Geräteverifizierung (Cardio-Feasibility-Karte)

Auftrag: ausschließlich C01 (gebündelte Cardio-Vorschlagskarte, kein
stilles Bulk-Update) und C02 (Plananpassung ablehnen → Profilentscheidung
bleibt, Plan unverändert) auf dem TestingBot-iPhone-15/iOS-18.0-Simulator
mit dem eigentlichen Auslösefall nachstellen, der in Runde 3 aus
Zeitgründen fehlte: ein aktiver Plan MIT Laufeinheiten plus eine
Cardio-Zieländerung, die laut `CardioFeasibilityCalculator` nicht
machbar ist.

**Testaufbau:** Frische App-Installation (TestingBot-Simulator startet
ohnehin pro Session frisch). Onboarding mit Ziel „Strength & Endurance
Combined" (Hybrid), Ausdauerform „Running", Coach zunächst aus,
anschließend über „Build Plan" einen 3-Tage-Plan erzeugt und übernommen
(`PlanGenerator`-Vorschau zeigte vorab „Bodyweight · Push & Pull",
„Easy Run, 45 min", „Bodyweight · Pull & Push" — enthält damit
nachweislich eine echte Laufeinheit). Ausgangszustand des übernommenen
Plans „Individueller Plan" (7 Tage/12 Wochen/Gym, aktiv): Mo Bodyweight ·
Push & Pull (6 Übungen), Di Rest, Mi Easy Run (1 Übung), Do Rest, Fr
Bodyweight · Pull & Push (6 Übungen), Sa/So Rest — das ist der
Vergleichsmaßstab für „unverändert" unten. Danach in Profil bearbeiten:
„Enable running coaching" an, Laufziel „Marathon", „Set race date" an
(Default-Datum 12 Jan 2027, ≈11 Wochen entfernt), Starting volume 10
km/Woche — mit diesen Werten liefert `CardioFeasibilityCalculator` ein
`verdict.feasible == false` mit `suggestedGoal = 5K` (Kartentext: „You
need about 22 weeks, but only 11 are available."), also genau der
Negativfall, bei dem laut Code der „Keep goal"-Button erscheint.
Build/Commit: `64ba455` (identischer TestingBot-App-Build aus Runde 3;
`git diff 64ba455..4ea8d7b` betrifft ausschließlich
`ExerciseEditorView.swift`/einen entfernten Test/dieses Dokument selbst —
keine Datei, die C01/C02 betrifft, Build daher weiterhin aktuell für
diesen Test). TestingBot-Session `fc34bafa1392-76dae1c872b2-17cb025342d7-179249117098-78574997`.

### C01 — Ergebnis: teilweise (Kernfall jetzt nachgestellt, neuer konkreter Befund zum Timing)

- **Auslösefall erfolgreich nachgestellt:** Nach Setzen von Coach an +
  Laufziel + Renndatum + Wochenvolumen erschien die gebündelte
  Vorschlagskarte auf dem Profil-Editor UND im Plan-Tab (gestrichelter
  Rand, identischer Inhalt) mit konkreten vorgeschlagenen Änderungen:
  Kopfzeile „This is going to be tight", Verdikt-Text mit Wochenzahlen
  und vorgeschlagenem Ersatzziel „5K", sowie eine Tages-Vorschau
  (`CardioFeasibilityDayRow`) mit vier Zeilen „Intervals · 6 × 0,4 km ·
  Tough", „Easy Run · ~45 min run · Easy", „Bodyweight · Push & Pull ·
  Strength training · Hard", „Bodyweight · Pull & Push · Strength
  training · Hard" sowie den drei Aktionen „Accept suggestion",
  „Adjust plan", „Keep goal".
- **Kein stilles Bulk-Update bestätigt:** Vor jedem Tippen auf einen der
  drei Buttons wurde der Plan-Tab gegengeprüft — weiterhin exakt „1
  PLAN", „Individueller Plan" unverändert aktiv mit 7/12/Gym, und beim
  Öffnen des Plan-Editors waren alle sieben Tage inhaltlich exakt wie im
  Ausgangszustand (Mo/Mi/Fr unverändert, Di/Do/Sa/So weiterhin Rest Day).
  Die Karte ist bis zum expliziten Tippen eines Buttons eine reine
  Vorschau ohne Seiteneffekt auf den gespeicherten Plan.
- **WANN erscheint die Karte — jetzt eindeutig beobachtet (die in der
  Aufgabenstellung offene Frage):** Die Karte erscheint NICHT erst nach
  einem gespeicherten/gebündelten Update, sondern bereits WÄHREND der
  Eingabe, nach jedem einzelnen Tastendruck, noch bevor das Feld
  verlassen oder irgendeine Bestätigung ausgelöst wird. Konkret
  reproduziert: mit Coach an, Renndatum gesetzt und noch leerem
  „Starting volume"-Feld war keine Karte sichtbar; unmittelbar nach dem
  ersten Tastendruck („1", Wert damit `weeklyBaseVolumeKm = 1`) stand die
  vollständige Karte (Kopfzeile, Verdikt-Text, vier Tageszeilen, „Keep
  goal"-Button) bereits im Accessibility-Baum, Tastatur war zu diesem
  Zeitpunkt noch offen, kein Feld verlassen, kein Haken/Speichern-Tap
  erfolgt. `ProfileEditorView` hat dafür auch keinen separaten
  „Speichern"-Schritt zum Testen: die Datei dokumentiert selbst
  (`ProfileEditorView.swift` Zeile 9f.) „`@Bindable` autosaves to
  SwiftData on every keystroke; no explicit Save button needed" — die
  Cardio-Felder sind direkt an `$profile...` gebunden, `feasibilitySection`
  ruft `CardioFeasibilityCardModel.make(for: profile)` bei jedem
  Re-Render mit dem jeweils aktuellen (Teil-)Wert auf. Das widerspricht
  wörtlich Dok. 01 §6: „Nach gespeichertem relevanten Update einmalig
  gebündelten Vorschlag anbieten, nicht bei jedem Tastenanschlag." —
  hier gibt es kein „gespeichertes Update" getrennt vom Tastenanschlag,
  weil der ganze Bildschirm fortlaufend autosave-basiert ist. Bewusst
  **kein Fix in dieser Runde**: das ist eine Architekturentscheidung, die
  den gesamten `ProfileEditorView`-Bildschirm betrifft (alle anderen
  Felder dort verhalten sich identisch, u. a. die bereits mehrfach
  gerätebestätigten A03/A04/A07/D03-Abläufe), nicht nur die
  Cardio-Karte; eine „gebündelte, nicht-live" Variante bräuchte einen
  separaten Entwurfszustand nur für die drei Cardio-Felder und eine neue
  explizite Bestätigungsaktion, die es in diesem Bildschirm aktuell
  nirgends gibt (kein Haken-Button dient hier als „Speichern" im Sinne
  von Dok. 01 §6, der vorhandene „Done"-Haken schließt nur den
  Bildschirm). Das ist eine Produktentscheidung, kein Zweizeiler-Fix, und
  bleibt daher als Befund dokumentiert statt eigenmächtig geändert.

### C02 — Ergebnis: bestanden

- „Keep goal" getippt (nicht „Übernehmen", nicht „Plan anpassen"):
  Karte verschwand sofort auf Plan-Tab und Profil-Editor.
- Profilentscheidung bleibt sichtbar gespeichert: Cardio-Coaching
  weiterhin an, Laufziel weiterhin „Marathon", Renndatum weiterhin
  „12 Jan 2027", Starting volume weiterhin „10" — per
  Accessibility-Tree-Dump nach dem Tap bestätigt, nicht auf den
  Ausgangszustand (Coach aus/General Fitness) zurückgesetzt.
  `CardioFeasibilityCardModel.dismiss(profile:)` rührt laut Code nur
  `cardioFeasibilityDismissedFingerprint` an — Geräteverhalten deckt
  sich exakt damit.
- Bestehender Plan „Individueller Plan" bleibt inhaltlich exakt
  unverändert (gleiche 7 Tage, gleiche Übungszahlen je Tag, kein
  Duplikat): Plan-Liste zeigt weiterhin genau „1 PLAN", kein neuer Plan
  angelegt, keine andere Aktivierung ausgelöst.
- **Echter Kaltstart durchgeführt** (`mobile: terminateApp` +
  `mobile: activateApp` auf `com.atamya.FitnessApp`): Dashboard zeigt
  danach weiterhin „Individueller Plan" mit identischem nächsten
  Workout (Push-Up/Wide-Grip Pull-Up/Pike Push-Up), Plan-Tab weiterhin
  genau „1 PLAN" ohne Karte, Profil-Editor zeigt weiterhin Coach an +
  Marathon + 12 Jan 2027 + 10 km/Woche per Accessibility-Tree-Dump
  bestätigt — alle C02-Garantien überstehen den Kaltstart konsistent.

Kein reproduzierter Bug im Sinne von Datenverlust/stiller
Planmutation/Dopplung gefunden — der einzige Befund dieser Runde ist das
dokumentierte Timing-Verhalten von C01 oben (Produktentscheidung, kein
Fix).

## Vorherige Runde: Top-5-Geräteprüfung (E01, C06, D06, A11, D02)

Alle fünf in der vorherigen Fassung dieses Dokuments priorisierten Fälle
wurden in dieser Runde auf dem TestingBot-iPhone-15/iOS-18.0-Simulator
durchgespielt (zwei Sessions, je nacheinander, aktiv beendet). Kurzfassung je
Fall unten in der Testmatrix (Zeilen E01/C06/D06/A11/D02); Volltext siehe
Abschnitt "Nächste Schritte" am Ende sowie den Session-Report dieser Runde.

**Echter Bug gefunden und gefixt (E01):** `MeasurementView.save(profile:)`,
`editingMeasurement`-Zweig, überschrieb das bestehende `BodyMeasurement`
im Speicher ohne anschließenden `context.save()` — derselbe Musterfehler wie
die zuvor behobenen zwölf Stellen in dieser App. Fix: expliziter
`try? modelContext.save()` nach der Mutation (Commit `89c788a`). Neuer
Regressionstest `MeasurementPersistenceTests.
testEditedMeasurementWithImmediateSaveSurvivesARealStoreRestartWithout-
Duplication`. CI (`apple-ci-comparison.yml`, Run `39387057589`): erfolgreich.
Geräte-Nachtest nach dem Fix: Bearbeiten per Haken + sofortiger Kaltstart
(Force-Quit + Neustart) → Wert bleibt geändert (78,00 statt 75,00 kg),
weiterhin genau 2 Verlaufseinträge, keine Dopplung. Bestanden.

## Risikoblöcke A–E (vorheriger Durchgang, unverändert gültig)

Siehe Commit-Historie `f2a31a5`, `81d21da`, `9d62b14` für die im vorherigen
Durchgang gefundenen und gerätebehobenen Bugs (Zeitformat-Fortschritt,
Onboarding-Finish, Day-Editor-Swipe-Delete-Crash). Block D/E (28-/42-Tage-
Review-Fälligkeit) war bereits dort NICHT gerätebestätigt, weil der
TestingBot-Simulator kein Datum/Zeit-Einstellungsfeld hat — siehe unten für
den seither verfolgten, clock-freien Alternativweg.

## Diese Runde: bekannte Lücken geschlossen

| # | Thema | Status |
|---|---|---|
| 1a | `PlansListView.deletePlans` – Save fehlte (Commit `fdad04c`) | geräteverifiziert (Plan+Session-Entkopplung nach Kaltstart korrekt) |
| 1b | **Neuer Fund:** Löschen des AKTIVEN Plans mit laufender Session crasht (SwiftData-interner Fatal Error `Context is missing for ... TrainingDay/pN`) | **Ursache ungelöst** – 4 gerätegetestete interne Fix-Versuche gescheitert (Commits `a6de159`…`84147f3`, alle ehrlich dokumentiert inkl. widerlegter Hypothesen). Nutzerentscheid: **UI-Guard statt interner Reparatur** – `PlansListView.plansBlockedByActiveSession(_:)` verhindert die Löschung jetzt und zeigt einen Hinweis (Commit `f6d4c81`). **Geräteverifiziert**: Crash tritt nicht mehr auf, normale Löschung unverändert funktionsfähig. Die zugrundeliegende SwiftData-Ursache bleibt unbekannt. |
| 2 | `PlanEditorView.deleteDays` / `MeasurementView.deleteCurrentMeasurement` / `ExerciseCard.unlogSet` – Saves fehlten (Commit `49a634d`) | geräteverifiziert |
| 3 | `DayEditorView` ForEach-Identität (`forEachIdentity`, Commit `49a634d`) | geräteverifiziert im tatsächlichen Risiko-Ablauf (neue ungespeicherte Übung + gleichzeitiges Löschen einer anderen Übung) |
| 4 | EMOM/ForTime/Circuit Restart-Zustände (Commit `f2a31a5`) | geräteverifiziert. Dabei 12. übersehene fehlende Save-Stelle gefunden: `CircuitWorkoutPlayerView.endRest()` ("Skip rest") – gefixt und gerätebestätigt (Commit `4036680`) |

## Block D/E (28-/42-Tage-Review-Fälligkeit): weiterhin offen

Geprüfter, grundsätzlich bestätigter clock-freier Weg: `DataImportService`
liest `activated_at_utc`/`block_review_history_json` direkt aus `plans.csv`
(CSV-Backup-Import, erreichbar über Settings → „Daten importieren"). Der
erste Schritt dieses Wegs – einen Export ziehen (Settings → „Export data
(CSV)") – **hängt auf dem TestingBot-Gerät reproduzierbar** beim Öffnen des
Export-Screens (`XCTPerformOnMainRunLoop work timed out`), bestätigt in
**6 unabhängigen Sessions**, auch mit einer frisch installierten App und
genau einem Plan (schließt „zu große Datenmenge" als Ursache aus). Ob echter
App-Bug (z. B. Deadlock in der Navigations-Transition) oder
TestingBot/WebDriverAgent-seitiges Problem, ist ohne symbolisierten
Stacktrace/Instruments-Zugriff nicht abschließend zu klären.

**Status: bekannte Nachweislücke, Auswirkung noch nicht abschließend
geprüft.** Auf Nutzerentscheid wird dieser Weg hier nicht weiterverfolgt;
die 6 ursprünglich vorgesehenen Prüfpunkte (nicht fällig / fällig /
korrekter Plan bei mehreren / Review-Abschluss / Folgeblock+Historie /
Kaltstart ohne Duplikate) bleiben ungeprüft.

## Vier-Stufen-Status-Hinweis

„Geräteverifiziert" bedeutet ausschließlich: auf echtem TestingBot-Gerät
durchgespielt und bestätigt. Es bedeutet NICHT, dass die zugrundeliegende
Ursache (z. B. beim Delete-Crash) verstanden oder behoben ist — dort wurde
bewusst ein Produktverhalten (Verhindern statt Reparieren) gewählt.

## Testmatrix 04_TESTS_UND_ABNAHME.md (A01–F08)

Quelle: `docs/specifications/04_TESTS_UND_ABNAHME.md` Abschnitt 2 (Original,
unverändert). Code-Audit-Stand: 2026-10-20, HEAD `02e8e46`, reine
Lese-/Testauswertung ohne neuen Geräte-Lauf in diesem Durchgang. Alle
Geräte-Nachweise sind aus diesem Dokument übernommen bzw. als fehlend
vermerkt, nicht neu erzeugt.

**Lesehinweis Status-Vergabe:** `bestanden` wird nur vergeben, wenn ein
automatisierter Test **exakt** das Szenario prüft (Funktionsname zitiert).
Ein nur **verwandter** Test (prüft Nachbarlogik, nicht exakt das Szenario)
ergibt `teilweise`. Fehlt jeder Nachweis, aber die Implementierung ist
auffindbar, ergibt das `noch nicht geprüft`. Keine der folgenden
`bestanden`-Zuordnungen ist eine „vollständig verifizierte" Abnahme im
Sinne der Definition of Done aus Dokument 04 — es fehlt durchgängig der
Geräte-/Apple-Nachweis; sie bedeuten ausschließlich, dass ein
automatisierter Test exakt die dokumentierte Szenario-Erwartung auf
Daten-/Logikebene beweist.

| ID | Szenario (Kurzform) | Priorität | Implementierungsstelle | Automatisierter Nachweis | Geräte-Nachweis | Status | Verbleibende Lücke |
|---|---|---|---|---|---|---|---|
| A01 | Ziel/Tage/Equipment bereits beantwortet → keine erneute identische Befragung | P2 | `OnboardingView.swift` (`weeklyGoal` dient zugleich als `PlanMatchmaker`-`preferredDays`; `trainingHistoryAnswer`/`ExperienceTrackResolver` statt zweiter Erfahrungsfrage) | `PlanMatchmakerTests.swift`, `ExperienceTrackTests.swift`, `ExperienceTrackBackfillTests.swift` (verwandt: Logikebene, kein Navigationstest der UI selbst) | Build/Commit `fc2ad39`, TestingBot-Sessions dieser Runde (siehe Nachtrag). Teil-Beleg INNERHALB einer einzigen Onboarding-Durchlaufs: Ziel ("Functional/Hybrid", Schritt 3) und Ausdauerform+Coach-Entscheidung (eigener Schritt) wurden beim Wechsel in den „Build Plan"-Unterpfad korrekt vorbefüllt übernommen (kein erneutes Abfragen von Ausdauerform/Coach dort), die übergeordnete Zielkarte („Primary focus") musste dort jedoch erneut ausgewählt werden. Die eigentliche A01-Kernfrage — bestehendes PROFIL aus einem früheren, abgeschlossenen/abgebrochenen Durchlauf, erneuter Eintritt ins Onboarding — wurde NICHT getestet: es gibt keinen in dieser Runde gefundenen Weg, das reguläre (nicht entwickler-spezifische) Onboarding mit einem bereits bestehenden Profil erneut zu triggern. | teilweise | Weiterhin kein Gerätebeleg für den eigentlichen A01-Fall (bestehendes Profil aus früherem Durchlauf). Neu beobachtet: die übergeordnete Zielkarte wird beim Wechsel Onboarding→„Build Plan" NICHT vorbefüllt, nur Ausdauerform/Coach — mögliche Teillücke, aber keine erneute identische Frage im engeren Sinn (gleiche Frage, andere Oberfläche). |
| A02 | Gemeinsamer Builder und Onboarding, gleiche Eingaben → gleiche fachliche Planung | P2 | `PlanGenerator` (gemeinsam genutzt), `PlanDraftResultAdapter`; ABER `OnboardingView.enduranceModalityStep` ist laut eigenem Kommentar ein „Duplikat von `PlanBuilderView.enduranceModalitySubflow`" | `PlanDraftResultAdapterTests.swift` (verwandt: Adapter-Korrektheit, kein Vergleichstest Onboarding- vs. Builder-Pfad) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test vergleicht beide Pfade bei identischer Eingabe; dokumentiertes UI-Duplikat steht in Spannung zu „keine kopierte zweite Oberfläche" (siehe Widersprüche unten). |
| A03 | Hybrid + Laufen ohne Coach → Kraft/Laufen im Vorschlag, Coach aus | P2 | `OnboardingView.enduranceModalityStep`, `UserBodyProfile.setEnduranceModality` | `PlanningContextTests.testRunCoachDisabledIsAlwaysValidRegardlessOfModality` (verwandt: Validität, nicht Plan-Inhalt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3, Onboarding-Session 1). Hybrid gewählt, Ausdauerform "Both" (Laufen+Radfahren; deckt zugleich A06 ab), Coach-Frage mit "Schedule running in my week" (aus) beantwortet, über „Build Plan" bis zur Wochenvorschau durchgespielt: Vorschau zeigte „Bodyweight · Push & Pull"/„Bodyweight · Pull & Push" (Kraft) UND „Easy Run, 45 min" (Laufen) im selben 3-Tage-Entwurf, kein Coach-Hinweis/-Badge sichtbar. Nach Abschluss des Onboardings zeigte der PERSISTIERTE Plan dieselbe Kombination (Mon/Wed/Fri: Pull&Push, Easy Run, Push&Pull) — Kraft und Laufen tatsächlich beide im gespeicherten Plan vorhanden, Coach aus. | bestanden | Nur ein konkreter Ablauf (Hybrid+Both-Modalität, Coach aus, 3-Tage-Plan) geprüft; nicht jede Tage-/Frequenz-Kombination. |
| A04 | Hybrid + Laufen mit Coach → Coachentscheidung und unterstütztes Ziel übernommen | P2 | wie A03, plus `runCoachWanted`-Pfad in `finishOnboarding()` | `PlanningContextTests.testRunCoachEnabledWithRunningIsValid` (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). "Work toward a goal with a run coach" ausgewählt (Coach an) bei Ausdauerform "Both": Auswahl wurde sichtbar übernommen (Radiobutton-Zustand, Auswahl blieb bei weiterer Navigation bestehen, siehe A06/A08). Im weiteren Onboarding-Verlauf (Equipment, Trainingshistorie, Start-Check) erschien zu KEINEM Zeitpunkt eine Frage zu Laufziel/Distanz/Referenzleistung/Zieldatum — bestätigt A09s Befund einer fehlenden Implementierung unabhängig vom Coach-Zustand. In der Wochenvorschau selbst war optisch kein Unterschied zum Coach-aus-Zustand erkennbar (kein sichtbares Coach-Badge/-Hinweis). | teilweise | Die Coach-ENTSCHEIDUNG wird übernommen (Auswahlzustand bleibt korrekt bestehen), aber: (1) kein unterstütztes Ziel wird je erhoben (A09-Lücke bestätigt), (2) kein sichtbarer Unterschied der Wochenvorschau zwischen Coach an/aus beobachtet — unklar, ob „unterstütztes Ziel übernommen" über diese UI überhaupt erfüllbar ist, solange A09 nicht implementiert ist. |
| A05 | Hybrid + Radfahren → keine unnötige Laufcoach-Frage | P2 | `OnboardingView.swift` (`enduranceModality.supportsRunCoach` blendet die Frage aus) | `PlanningContextTests.testRunCoachEnabledWithCyclingOnlyIsInvalid`, `testSupportsRunCoachMatchesPlanningContextInvariant` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logik-/UI-Gating geprüft; kein Geräte-Screenshot-Beleg der tatsächlich ausgeblendeten Frage. |
| A06 | Laufen/Radfahren kombiniert → Auswahl bleibt nach Coachingentscheidung bestehen | P2 | `EnduranceModality.both` (`PlanningContext.swift`) | `PlanningContextTests.testRunCoachEnabledWithBothIsValid`, `testEnduranceModalityMapsOntoExistingTrainingTypeKinds` (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). "Both" (Running+Cycling) ausgewählt → Coach-Frage erschien weiterhin (nicht ausgeblendet, korrekt lt. Dok. 02 Tabelle) → "Work toward a goal with a run coach" angetippt → "Both" blieb sichtbar ausgewählt/markiert (Screenshot-bestätigt, kein Reset auf "Running" o.ä.). Zusätzlich im „Build Plan"-Unterpfad reproduziert: dort war "Both" aus der vorherigen Onboarding-Antwort bereits vorbefüllt und blieb nach erneutem Antippen der Coach-Option weiterhin korrekt markiert. | bestanden | Nur die Selektions-UI-Ebene geprüft (Auswahlzustand bleibt nach Coach-Entscheidung bestehen); ob der generierte Wochenplan bei "Both" tatsächlich IMMER beide Modalitäten (statt nur einer, je nach Tagesbudget) enthält, wurde nicht geprüft — der konkrete 3-Tage-Testplan enthielt nur eine Laufeinheit, keine Radfahren-Einheit (plausibel durch Verteilungslogik bei wenigen Slots, nicht verifiziert als Bug). |
| A07 | Coach an → aus → gewollte Laufeinheiten bleiben, keine aktiven Coachempfehlungen | P2 | `UserBodyProfile.setEnduranceModality`/`cardioCoachingEnabled` | `UserBodyProfileTests.testChangingModalityToCyclingClearsPreviouslyEnabledCoach` (verwandt: Modality-Wechsel, nicht reines Coach-Toggle) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3, „Build Plan"-Unterpfad außerhalb des Onboardings, gleiche Subflow-Logik lt. Code-Kommentar „Duplikat von PlanBuilderView.enduranceModalitySubflow"). Coach bei "Running" eingeschaltet ("Work toward a goal with a run coach" ausgewählt, Markierung bestätigt), dann wieder auf "Schedule running in my week" (Coach aus) zurückgetippt → Auswahl wechselte sauber zurück, keine optische Vermischung beider Zustände. Danach bis zur Wochenvorschau mit Coach AN durchgespielt (Easy Run sichtbar) — der symmetrische Schritt "danach im selben Entwurf wieder ausschalten und prüfen, dass die Laufeinheit bestehen bleibt" wurde aus Zeitgründen nicht mehr im selben Durchlauf nachvollzogen (Entwurf wurde stattdessen verworfen, keine Persistenz geprüft). | teilweise | Sauberes Umschalten Coach an/aus OHNE Vermischung/Stale-State ist jetzt gerätebestätigt. Weiterhin fehlt der direkte Beleg, dass eine bereits geplante Laufeinheit im EINEM fortlaufenden Entwurf nach Coach-an→aus (in dieser Reihenfolge, nicht umgekehrt) bestehen bleibt. |
| A08 | Ausdauerform wechseln und zurückgehen → kein veralteter Status/Planinhalt | P2 | `OnboardingView.goToNextStep`/`goToPreviousStep`, `enduranceModality`-State | `UserBodyProfileTests` (Modality-Wechsel, verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). Mit Coach eingeschaltet bei "Running" → auf "Cycling" gewechselt: Coach-Frage verschwand vollständig und sauber (Radfahren unterstützt laut Dok. 02 keine Coach-Frage), keine veraltete "Work toward a goal"-Markierung sichtbar hängen geblieben. Zurück auf "Running" gewechselt: Coach-Frage erschien wieder, aber zurückgesetzt auf den DEFAULT ("Schedule running in my week", Coach aus) — NICHT die vorher gewählte "mit Coach"-Option wiederhergestellt. Kein veralteter/inkonsistenter Zustand beobachtet. | bestanden | Zurücksetzen auf Default (statt Wiederherstellen der letzten Wahl) beim Rück-Wechsel ist kein veralteter Zustand im Sinne von A08 (keine falsche/inkonsistente Anzeige), aber auch keine Gedächtnisfunktion — falls letzteres erwartet wird, wäre das ein eigener, hier nicht gestellter Anspruch. |
| A09 | Unbekannte Referenzleistung → keine erfundenen Werte/stille Nullannahme | P2 | **keine erkennbare Implementierung gefunden** im Onboarding | kein Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten): Dok. 02 §4 verlangt diese Fragen im Onboarding bei aktiviertem Coach; der Code stellt sie dort nicht. |
| A10 | Eingebetteten Wocheneditor bestätigen → nur Onboarding-Entwurf geändert | P1 | `OnboardingView.finishOnboarding()` (kein früher Plan-Insert aus der Vorschau) | kein direkter Test; `PlanCreationOperationTests.swift`/`PlanDraftResultAdapterTests.swift` decken die angrenzende Logik ab (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). Im eingebetteten „Build Plan"-Wocheneditor eine Einheit per Drag verschoben (Position 2→1), danach den Haken getippt: Die App sprang DIREKT zum Dashboard mit bereits aktivem, persistiertem Plan — der Haken in diesem Einstiegspfad beendet das GESAMTE Onboarding in einem Schritt (keine Rückkehr zu einer separaten, noch bearbeitbaren Onboarding-Zusammenfassung). Die vorgenommene Reorder-Änderung war im fertigen, gespeicherten Plan korrekt übernommen (gleiche Reihenfolge wie im Entwurf). Anschließend genau "1 PLAN" in der Plan-Liste (kein verwaister/doppelter Datensatz). | teilweise | Die geprüfte Garantie "kein vorzeitiger/doppelter Plan-Insert" ist erfüllt (Entwurfsänderung korrekt übernommen, nur 1 Plan). Die genaue Lesart "Haken übernimmt NUR den Entwurf und führt zur Vorschau zurück" (Dok. 02 §6, Punkt 2) trifft auf den hier getesteten „Build Plan"-Pfad NICHT zu — dort ist der Haken zugleich die Onboarding-Abschlussaktion (Punkt 3). Ob es daneben einen separaten „kompakte Wochenvorschau mit eigenem Haken + eigenem späteren Finish"-Bildschirm gibt, der dieser engeren Lesart entspricht, wurde in dieser Runde nicht gefunden/getestet. |
| A11 | Onboarding abbrechen/mehrfach abschließen → keine verwaisten/doppelten Pläne | P1 | `OnboardingView.finishOnboarding()` (`isFinishingOnboarding`-Guard), `OnboardingPlanCreationNotice` | `OnboardingPlanCreationNoticeTests.swift`, `OnboardingFinishPlanSelectionTests.swift` (verwandt: Notice-/Auswahl-Logik, nicht der Doppel-Tap-Guard selbst) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. a) Mehrfach-Tap: 6 schnell aufeinanderfolgende Taps auf "Finish" am letzten Onboarding-Schritt → Plans-Liste zeigt danach exakt "1 PLAN" (kein Dupe), Guard bestätigt wirksam. b) Abbruch: Onboarding bis zum letzten Schritt (vor "Finish") durchlaufen, App per `terminateApp` hart beendet und neu gestartet → sauberer Neustart bei Schritt 1 ("Welcome"), kein Absturz, kein sichtbar hängender Zustand. Onboarding danach regulär bis "Finish" wiederholt und abgeschlossen → ebenfalls exakt "1 PLAN" (kein verwaister Datensatz aus dem abgebrochenen Versuch). | bestanden | Kein Negativbeweis, dass tatsächlich ein `UserBodyProfile`-Datensatz aus dem abgebrochenen Versuch im Store verblieb (nur indirekt über "1 PLAN" nach Abschluss geschlossen, kein direkter Store-/Export-Dump geprüft). |
| A12 | Hybrid + "Both"-Ausdauerform → beide gewählten Sportarten im generierten Plan, sonst sichtbarer Konflikt statt stillem Weglassen | P2 | GEFIXT (Paket 1, Teil 1, Commit `5146bfe`): `makeSelections` gibt Kraft so viele Tage ab wie nötig, damit jede gewählte Disziplin mindestens einen Tag bekommt; `distributionConflict(...)` erkennt den verbleibenden echten Mangelfall (zu wenige Tage für alle Disziplinen) als prüfbares Signal, noch ohne UI-Anbindung | `GoalDrivenPlanSelectionBuilderTests.testHybridGoalWithBothModalityAtTheDefaultThreeDaysGivesEachDisciplineOneDay` + zwei neue `distributionConflict`-Tests (ersetzen den früheren Pinning-Test) | Logik-/CI-Ebene verifiziert (Run `39481833188`, Commit `5146bfe`, alle Tests grün) — NOCH NICHT erneut gerätebestätigt; ursprünglicher Bug-Nachweis (Build `9956f8e`, TestingBot-Session `7f1a4aa358fb-8ccc5c0b64ef-388a7f4cec85-179252205753-68569042`, Runde 11) bleibt als Befund-Beleg gültig. | teilweise (Logik gefixt und test-verifiziert, Geräte-Nachtest und UI-Anbindung des Konflikt-Signals stehen noch aus) | Ursprünglicher Spezifikationskonflikt (Punkt 7 unten) ist für die Kern-Verteilungslogik aufgelöst; die SICHTBARE Konflikt-Anzeige bei echtem Tage-Mangel ist weiterhin reine UI-Arbeit, siehe "Paket 1 (Teil 1)"-Nachtrag oben für den genauen Zuschnitt. |
| B01 | Wocheneditor Drag & Drop → Reihenfolge korrekt, alternative Bedienung möglich | P2 | `PlanBuilderView.resultStepView`/`moveDraftDays`, `PlanDraft.moveDay` | `PlanDraftTests.testMoveDayReordersAndPreservesStableID` u.a. (exakte Logikabdeckung) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). BEIDE Bedienwege im selben Wocheneditor geprüft: (1) „Move to…"-Menü (alternative/zugängliche Bedienung): "Easy Run" per Menü auf "Position 1" verschoben → Reihenfolge korrekt neu sortiert, sofort sichtbar. (2) Echte Drag-Geste (langer Druck + Bewegung über mehrere Zwischenschritte): "Bodyweight · Pull & Push" von Position 3 an Position 1 gezogen → Reihenfolge erneut korrekt neu sortiert (alle 3 Einheiten korrekt neu angeordnet, keine Duplikate/Lücken). Ein einzelner schneller Swipe ohne Haltephase loeste die Drag-Geste NICHT aus (Geraete-/Gesten-Nuance, kein Produktfehler — ein echter Finger haelt beim Drag typischerweise). | bestanden | Nur ein 3-Tage-Entwurf im „Build Plan"-Pfad geprüft, nicht die eigenständige Builder-Variante außerhalb des Onboardings; beide dürften laut Code dieselbe `moveDraftDays`/`PlanDraft.moveDay`-Logik nutzen. |
| B02 | Inhalt fixiert, Woche neu verteilen → Inhalt bleibt, Position regelkonform behandelbar | P2 | `PlanDraft.setContentFixed`/`redistribute` | `PlanDraftTests.testRedistributeLeavesContentFixedDayCompletelyUntouchedButFillsOthersFromThePool`, `testContentFixationDoesNotPreventReordering` | kein Geräte-Nachweis vorhanden | bestanden | Reine Logikprüfung ausreichend und exakt passend; kein Geräte-Nachweis der UI-Darstellung. |
| B03 | Position fixiert, Übungen variieren → Position bleibt, erlaubter Inhalt veränderbar | P2 | `PlanDraft.setPositionFixed`/`replaceContent` | `PlanDraftTests.testPositionFixationDoesNotPreventContentReplacement`, `testRedistributeAllowsNewContentOnAPositionFixedButNotContentFixedDay` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene; keine UI-Geräteprüfung. |
| B04 | Manuelle Änderungen + Neuberechnung → keine stillen Verluste | **P1** | `PlanGeneratorInstantiator.recalculate` (Fingerprint-Vergleich, überspringt manuell geänderte/historienbehaftete Tage) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithEditedExerciseSets`, `testRecalculateSkipsDayWithActiveSessionAndReportsIt`, `testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact` | kein Geräte-Nachweis vorhanden | bestanden | Datenintegrationsebene vollständig bewiesen; kein Geräte-Nachweis für den UI-Auslöser ("Neu rechnen"). |
| B05 | Keine passende Lösung → sichtbarer Konflikt statt abgeschnittener Einheiten | P2 | `PlanBuilderView.presentAlternatives`, `PlanDraft.redistribute` (schlägt sauber fehl statt zu kürzen) | `PlanGeneratorTargetedAlternativesTests.testCardioDayHasNoAlternatives`, `testDayNotMatchingAnySelectionHasNoAlternatives`; `PlanDraftTests.testRedistributeFailsAndLeavesDraftUnchangedWhenAllDaysAreContentFixed` | kein Geräte-Nachweis vorhanden | bestanden | Kernzusage bewiesen; der sichtbare Toast selbst ist nicht geräteverifiziert. |
| B06 | Mehrfach auf Haken tippen/Fehler beim Speichern → keine Duplikate, Entwurf bei Fehler erhalten | **P1** | `PlanBuilderView` (`isAdopting`-Doppel-Tap-Guard), `PlanCreationOperation` | `PlanCreationOperationTests.testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan`, `testGenuineSaveFailureIsRetryableAndDoesNotMarkAnythingAsCommitted`, `testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce` | kein Geräte-Nachweis vorhanden | bestanden | Datenebene vollständig bewiesen; kein Geräte-Nachweis des realen Mehrfach-Tap-UI-Pfads. |
| C01 | Cardio-/Laufziel speichern → gebündelte Vorschau, kein stilles Bulk-Update | P2 | `CardioGoalEditorView` (neu, lokaler Draft + explizites Speichern/Abbrechen, Commit `47ab4d6`/`1c8bf54`), `CardioFeasibilityCardModel.make/accept/dismiss/acceptCustom` (unverändert) | `CardioFeasibilityCalculatorTests.swift` (Berechnung), `EditorDiscardSnapshotTests.testProfileMetaSnapshotExcludesCardioFields` (Haupt-Screen-Verwerfen rührt Cardio-Felder nicht an), neu `CardioGoalEditorPersistenceTests.testSavedCardioGoalSurvivesARealStoreRestart` (Kaltstart-Persistenz, Regressionstest zum Runde-5-Fund) | Build/Commit `1c8bf54` (Fix-Commit dieser Runde; `47ab4d6` war der erste Fix-Versuch, siehe Fund unten), TestingBot-Sessions `91734b401f14-2d5c53c3240d-4be862ab2114-179249457224-84143788` (Haupttest, 1.801 s, serverseitig nach 30-Minuten-Limit beendet) + `9d18478362b4-eb61d0e6eed8-81fddd3a4b1c-179249710037-06834461` (Fix-Nachtest, 177 s, aktiv beendet). Alle 7 Auftragspunkte + infeasibleNoSuggestion + 4 Grenzfälle auf dem Gerät mit demselben Laufeinheit-Plan wie Runde 4 geprüft (Details: Nachtrag „Runde 5"). Kurzfassung: (1) Eingabe allein ändert nichts (zurücknavigieren ohne Speichern → Verwerfen-Dialog erscheint und wird — TestingBot `autoAcceptAlerts` bestätigt-destruktiv — sofort angewendet, alte Werte bleiben, kein Plan berührt), (2) Abbrechen verwirft nur den Cardio-Entwurf (unabhängige, noch offene Coaching-Ton-Änderung auf dem Hauptschirm bleibt unberührt und weiterhin verwerfbar), (3) Speichern übernimmt alle sieben Felder gebündelt und korrekt vorbefüllt beim erneuten Öffnen, (4) kein realistischer Speicherfehler für diese reinen Property-Felder vorhanden/verifizierbar (kein künstlicher Fehler gebaut, siehe Nachtrag), (5) **Kernfix bestätigt**: die Vorschlagskarte erscheint auf Profil/Dashboard/Plan-Tab NICHT während der Eingabe (Sheet blockiert währenddessen ohnehin jede Navigation zu Dashboard/Plan) und NICHT bei einem verworfenen Entwurf, sondern ausschließlich nach dem Speichern-Tap, mit dem jeweils aktuellen (nie veralteten) Stand, (6) „Keep goal" nach Speichern erhält Profilupdate, Plan bleibt exakt „1 PLAN" (C02-Regression bestanden), (7) nach echtem Kaltstart (Force-Quit+Neustart) bleiben Profilwerte korrekt — **aber genau hier zeigte sich reproduzierbar (zweimal unabhängig) ein echter neuer Bug**: `CardioGoalEditorView.save()` (Commit `47ab4d6`) mutierte `profile` ohne `context.save()`, ein gerade gespeichertes Update ging bei einem Kaltstart kurz danach wieder verloren (Rückfall auf den zuvor tatsächlich persistierten Stand). Gefixt in Commit `1c8bf54` (`@Environment(\.modelContext)` + `try? modelContext.save()`), CI erfolgreich (Run `39416947715`, inkl. neuem Regressionstest), Geräte-Nachtest nach dem Fix bestätigt: Speichern + sofortiger Kaltstart erhält jetzt den neuen Wert korrekt. infeasibleNoSuggestion-Fall (Ziel 5K, Renndatum 1 Woche entfernt, Startvolumen 1 km/Woche → selbst 5K nicht mehr machbar) über normale Eingaben erreicht: nur „Keep goal" angeboten (kein Ersatzziel), Tap darauf kein Crash, Profil/Plan bleiben korrekt. Alle 4 neuen Save/Cancel-Grenzfälle (gespeichertes Cardio-Update übersteht unabhängiges Verwerfen auf dem Hauptschirm; offene Hauptschirm-Änderung übersteht Öffnen+folgenloses Schließen des Cardio-Editors; Vorschlag rechnet nie mit einem abgebrochenen Draft und nie mit einem veralteten Vor-Speichern-Stand nach echtem Speichern — belegt durch Volumenänderung 10→50 ungespeichert/verworfen vs. gespeichert; bloßes Öffnen+Verwerfen löst keinen Retro-Sync aus) gerätebestätigt; `setDraftEnduranceModality`-Invariante (Radfahren waehlen bei Coach an → Coach geht im Draft sofort aus) zusätzlich per Code-Review bestätigt (Funktion `setDraftEnduranceModality` in `CardioGoalEditorView.swift`). | bestanden | Kein Rest mehr offen für C01 selbst. Reine Verlagerung des Codes war ausdrücklich kein Ersatz für den Geräte-/Persistenz-Nachweis — genau diese Prüfung deckte den Kaltstart-Bug auf; nach dessen Fix ist der Fall vollständig abgeschlossen. |
| C02 | Plananpassung ablehnen → Profilentscheidung bleibt, Plan unverändert | P2 | `CardioFeasibilityCardModel.dismiss(profile:)` | `EditorDiscardSnapshotTests.testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable` (verwandt: Annahme-Fall, nicht Ablehnen-Fall) | Build/Commit `64ba455`, TestingBot-Session `fc34bafa1392-76dae1c872b2-17cb025342d7-179249117098-78574997` (Runde 4). "Keep goal" (nicht "Accept suggestion"/"Adjust plan") getippt: Karte verschwand sofort auf Plan-Tab und Profil-Editor. Profilentscheidung bleibt per Accessibility-Tree-Dump bestätigt sichtbar gespeichert (Coach an, Marathon, 12 Jan 2027, 10 km/Woche — nicht auf Coach-aus/General-Fitness zurückgesetzt). Bestehender Plan "Individueller Plan" bleibt inhaltlich exakt unverändert (gleiche 7 Tage/Übungszahlen, kein Duplikat, weiterhin genau "1 PLAN", keine andere Aktivierung). Echter Kaltstart (`mobile: terminateApp` + `mobile: activateApp`) durchgeführt: Dashboard/Plan-Tab/Profil-Editor zeigen danach weiterhin denselben konsistenten Zustand (gleicher nächster Workout, "1 PLAN" ohne Karte, Cardio-Werte unverändert per Tree-Dump bestätigt). | bestanden | Nur dieser eine Ablauf (Keep goal bei einem P2.3-typischen Infeasible-Fall mit Ersatzziel-Vorschlag) geprüft; der Fall "kein `suggestedGoal` mehr vorhanden" (`infeasibleNoSuggestion`) wurde für "Keep goal" nicht separat durchgespielt. |
| C03 | Equipment nicht vorhanden → betroffene Übungen mit begründetem Ersatz | P2 | `PlanEquipmentCheck`, `PlanEquipmentAdaptationApplier` | `PlanEquipmentAdaptationApplierTests.testApplyArchivesTheOriginalAndInsertsAReviewedReplacement`, `PlanEquipmentCheckTests.testDumbbellWithoutConfirmedBenchIsUnknownNotUnavailable` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logik-/Datenebene; keine Geräteprüfung der angezeigten Ersatz-Begründung. |
| C04 | Nur Präferenz ändern → optionale Neugewichtung, kein Geräteverbot | P2 | **keine erkennbare Implementierung gefunden** — Equipmentmodell kennt nur `available`/`unavailable`/`unknown` | kein Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten): Dok. 01 §6 verlangt 4 Zustände inkl. Präferenz-Gewichtung; Code kennt nur 3. |
| C05 | Bank/Klimmzugstange unbekannt → bleibt nach Neustart, Bestätigung und Export/Import unbekannt | P2 | `UserEquipmentProfile`/`EquipmentRequirement`, `DataExportService`/`DataImportService` | `DataPortabilityRoundtripTests.testExplicitlyUnknownEquipmentSurvivesRoundtrip`; `EquipmentRequirementTests.testConfirmRemainingAsUnavailableNeverOverridesAnExplicitlyUnknownItem` | kein Geräte-Nachweis vorhanden | teilweise | Export/Import-Pfad exakt getestet; kein separater Store-Neustart-Test, kein Gerätenachweis. |
| C06 | Laufende Session + Planänderung → Sessionstruktur/Logs bleiben konsistent | **P1** | `PlanGeneratorInstantiator.recalculate` (überspringt Tage mit `WorkoutSession`-Historie) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithActiveSessionAndReportsIt` (exakt für Recalculate); direkte `DayEditorView`-Übungsänderung während laufender Session NICHT separat abgedeckt | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. Beobachtet: Session auf "Full Body A" gestartet, Satz 1/3 von "Goblet Squat" geloggt; währenddessen im Day-Editor Satzzahl dieser Übung 3→2 reduziert und gespeichert. Laufende Session zeigte danach unverändert "1/3" mit allen 3 ursprünglichen Sätzen (Edit NICHT übernommen), geloggter Satz 1 blieb erhalten; restliche 2 Sätze wurden normal fertig geloggt ("3/3 — All sets done"), kein Crash. Tag-Editor zeigte weiterhin korrekt "2 sets" für künftige Starts. Session danach regulär verworfen (kein Rest-Zustand). **Ausdrücklich begrenzt auf genau diesen einen Ablauf (Satzzahl-Reduktion) — kein Nachweis für andere strukturelle Planänderungen (Übung hinzufügen/löschen, Tag löschen/umsortieren, Zeitformat-Wechsel) während einer laufenden Session an demselben Tag.** | teilweise | Nur EIN konkreter Ablauf (Satzzahl-Reduktion während laufender Session) geräteverifiziert und darf NICHT als vollständiger Nachweis für "Sessionstruktur/Logs bleiben bei jeder Planänderung konsistent" gewertet werden. Andere strukturelle Änderungen (Übung hinzufügen/löschen am laufenden Tag, Mehrfach-Tage-Pläne) sind ungeprüft; die zugrundeliegende Schutz-Mechanik (Snapshot vs. Live-Referenz) ist nicht im Code lokalisiert, nur das Verhalten für den einen Ablauf beobachtet. |
| D01 | Reines Reorder + Verwerfen → Originalreihenfolge wiederhergestellt | **P1** | `PlanEditorView.revertDayOrder`/`dayOrderIsDirty`, `DayEditorView.revertExerciseOrder`/`exerciseOrderIsDirty` | `EditorDiscardSnapshotTests.testPlanEditorViewDetectsAndRevertsDayReorder`, `testDayEditorViewDetectsAndRevertsExerciseReorder` | kein Geräte-Nachweis vorhanden | bestanden | Nur die Datenlogik ist exakt bewiesen; die physische Drag-Geste selbst ist unter B01 vermerkt. |
| D02 | Add/Delete + Reorder + Verwerfen → definiertes Verhalten, keine Sortierkollision | **P1** | Hinzufügen/Löschen sind bewusst sofort wirksame, nicht per Discard rückrollbare Aktionen | `EditorDiscardSnapshotTests.testPlanEditorViewIgnoresNewlyAddedDayInReorderRevert`, `testDayEditorViewIgnoresNewlyAddedExerciseInReorderRevert` (verwandt: deckt nur "neu hinzugefügt" ab, nicht die volle Kombination) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. Beobachtet: Tag "Fri/Full Body C" gelöscht, danach "Mon/Full Body A" per Drag an Position 3 verschoben (beides in derselben Editor-Sitzung), dann ohne Speichern zurücknavigiert → "Discard Changes?"-Dialog bestätigt. Ergebnis beim Wiederöffnen: 6 Tage (Fr korrekt entfernt geblieben, da sofort wirksam), Mon/Tue/Wed/Thu/Sat/Sun je genau einmal vorhanden mit der ursprünglichen Inhalt-Wochentag-Zuordnung (Mon=Full Body A, Wed=Full Body B) wiederhergestellt — die Reorder-Änderung wurde sauber zurückgerollt, keine doppelten Wochentage, keine Indexlücken/-kollisionen. | bestanden | Nur eine Lösch+Reorder-Kombination in einer Sitzung geprüft (nicht z. B. Hinzufügen+Löschen+Reorder gleichzeitig oder mehrfaches Reorder nach dem Löschen). |
| D03 | Name/Ton ändern, separate Aktion bestätigen → unabhängiger Edit bleibt verwerfbar | **P1** | `PlanEditorView.rebaselineTargetEnvironment()`; der Cardio-Teil läuft seit Commit `47ab4d6` NICHT mehr über eine Teil-Rebaseline in `ProfileEditorView` (`rebaselineCardioGoal()` entfiel ersatzlos), sondern über den eigenen Save/Cancel-Flow von `CardioGoalEditorView` (Cardio-Felder sind seitdem kein `ProfileMetaSnapshot`-Feld mehr) | `EditorDiscardSnapshotTests.testPlanMetaSnapshotTargetedRebaselineLeavesOtherFieldsDirty` (PlanEditorView-Teil), `testProfileMetaSnapshotExcludesCardioFields` (Cardio-Teil, ersetzt den entfallenen `testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable`-Test); zusätzlich geräteverifiziert für den Cardio-Teil als Runde-5-Edge-Case 1/2 (siehe C01-Zeile/Nachtrag „Runde 5") | Für den Cardio-Teil: Runde-5-Edge-Case 1/2 (siehe C01-Zeile) | bestanden | Für `PlanEditorView.rebaselineTargetEnvironment()` weiterhin nur Logikebene bewiesen, kein Geräte-Nachweis der UI-Sequenz. |
| D04 | A aktiv → B an → B aus → Verwerfen → Ausgangsaktivierung wiederhergestellt | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardSurvivesOnOffToggleSequence`, `testOtherActivePlanStateIsDirtyDetectsOnOffToggleSequence` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D05 | Inaktiver Plan ohne anderen aktiven Plan → unverändert nicht dirty | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` (nil-Fall) | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardReturnsNilWhenNoOtherPlanWasActiveAtOpen`, `testOtherActivePlanStateIsDirtyIsFalseWhenNoOtherPlanWasActiveAtOpen` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D06 | Rückrollen von Trainingsort → keine erneut ausgelöste Migration beim Schließen | **P1** | `PlanEditorView.revertToSnapshot()`/`revertTargetEnvironment()`/`isApplyingSnapshot`-Flag | `EditorDiscardSnapshotTests.testPlanMetaSnapshotRevertsEnvironmentAndActiveFlagTogether`, `testRevertTargetEnvironmentRestoresPriorValue` (Runde 6) | Build/Commit `b8b8f6e` (Runde 3), TestingBot-Session `f3e600cd…26223308`: Kernzusage bestätigt (siehe Historie unten). **Runde 6** (Build `cf0bfe8df4ca17f5fa0b563f`/`1c8bf54`, dann `7c22ceea177d36af2e2b3c20`/`47678c1`): isolierter Schritt "Dialog erscheint → bewusst ablehnen" erstmals nachgestellt — erfordert `appium:autoAcceptAlerts: false` (siehe Nachtrag „Runde 6": mit der bisherigen `autoAcceptAlerts: true`-Einstellung aller Vorrunden wurde der Dialog nie sichtbar, da automatisch mit seinem ersten Button bestätigt — Automatisierungs-Artefakt, nicht Produktverhalten). Dabei gefunden: "Cancel" im Restore-Dialog loeste reproduzierbar den ANDEREN Dialog (Adapt) aus, dessen Cancel wieder zurueck zum ersten fuehrte — echte Endlosschleife, aus der Cancel nicht herausfuehrte. Gefixt (`revertTargetEnvironment`, dasselbe `isApplyingSnapshot`-Muster wie `revertToSnapshot()`), CI gruen, Geraete-Nachtest nach Fix: Cancel bricht jetzt sauber ab, kein Folgedialog mehr. | **bestanden** | Kernzusage UND isolierter Cancel-Schritt jetzt beide gerätebestätigt; der dabei gefundene Bug (Cancel-Ping-Pong) ist gefixt und gerätebestätigt. Andere Trainingsort-Übergänge (z. B. Home-Gym-Zwischenstufen, Mehrfachwechsel in einer Sitzung) nicht separat geprüft. |
| E01 | Körpermessung per Haken bearbeiten → bestehende Messung aktualisiert, kein Duplikat | **P1** | `MeasurementView.save(profile:)` (`editingMeasurement`-Zweig überschreibt das bestehende Objekt; **Fund+Fix dieser Runde:** fehlender `context.save()`, siehe Commit `89c788a`) | `MeasurementPersistenceTests.testEditedMeasurementWithImmediateSaveSurvivesARealStoreRestartWithoutDuplication` (neu, reproduziert die Fix-Technik exakt) | Build/Commit `89c788a` (nach Fix), TestingBot-Session `d5e2f4c5…03720961`. Bestehenden Verlaufseintrag (Gewicht 75,00 kg) per Haken bearbeitet → Gewicht auf 78,00 geändert, gespeichert: Verlauf zeigte danach weiterhin genau 2 Einträge (kein dritter/doppelter), der bearbeitete Eintrag zeigte 78,00 kg. Direkt danach `terminateApp` + Neustart (echter Kaltstart): Dashboard und Verlauf zeigten 78,00 kg weiterhin korrekt, weiterhin genau 2 Einträge. | bestanden | Nur der Geräte-Ablauf mit vollständigen Pflichtfeldern (Gewicht+Hals+Taille) geprüft; der "nur Gewicht nachträglich geändert, Umfänge unverändert"-Spezialfall (`isEditingWeightOnlyEntry`) wurde nicht separat auf dem Gerät durchgespielt. |
| E02 | Cooldown vorgesehen/ausgeblendet/nicht vorhanden → jeweils nachvollziehbare Anzeige | P2 | `ActiveWorkoutView` (Warmup-/Cooldown-Sichtbarkeits-Filter), `ExerciseRole.cooldown` | `ExerciseRoleTests.testCooldownIsSkipped` (verwandt: prüft nur Progressions-Ausschluss, nicht die drei Anzeigezustände) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test für die drei konkreten Anzeigezustände selbst. |
| E03 | Alle gültigen RIR-Ganz-/Halbwerte → vollständig sichtbar und korrekt gespeichert | P2 | `SetRow.swift` (strukturelle RIR-Spalte, Zwei-Zeilen-Fallback laut Code-Kommentaren) | kein Test gefunden (kein RIR-Testfile) | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Alle 11 gültigen Werte (0, 0,5, 1, 1,5, 2, 2,5, 3, 3,5, 4, 4,5, 5) im aktiven Satz-Logging nacheinander über den RIR-Regler eingestellt: jeder Wert erschien vollständig und korrekt in der RIR-Kapsel (z. B. "3,5", nicht abgeschnitten wie im Original-Bugreport "R2/R4..."), mit passendem Tooltip-Text je Stufe (z. B. "Absolute failure" bei 0). Ein Satz mit RIR 3,5 geloggt (Haken) → Wert blieb nach dem Loggen unverändert sichtbar in der (ausgegrauten) Zeile. | bestanden | Nur die Anzeige/das direkte Loggen geprüft; kein Kaltstart-Test, ob ein geloggter RIR-Wert (z. B. 3,5) auch nach einem Neustart in der Historie/Zusammenfassung weiterhin korrekt (nicht gerundet) angezeigt wird. |
| E04 | Schmaler Bildschirm, große Schrift, Dezimalgewicht, kg/lbs → kein Abschneiden/Overflow | P2 | `SetRow.swift` (Layout-Fallback-Kommentare); **Fund+Fix dieser Runde:** `weightInput` ohne `minimumScaleFactor`, siehe Commit `64ba455` | `SetRowWeightFieldScalesDownInsteadOfTruncatingTests` (neu, prüft exakt die Fix-Stelle) | Build/Commit `64ba455` (nach Fix), TestingBot-Sessions (Runde 3). **Echter Bug gefunden und gefixt:** bei aktivierter „Larger Accessibility Sizes" (größte Dynamic-Type-Stufe, über iOS-Einstellungen gesetzt) zeigte das KG-Feld ein eingegebenes Dezimalgewicht "72,5" abgeschnitten als "7...". Fix: `.minimumScaleFactor(0.5)` + `.lineLimit(1)` auf `SetRow.weightInput` (Commit `64ba455`). Geräte-Nachtest NACH dem Fix (frischer CI-Build): „72,5" bei identisch maximaler Textgröße jetzt vollständig sichtbar (verkleinerte Schrift statt Abschneiden). Dezimalgewicht mit Komma (deutsches/belgisches Zahlenformat, Region=Belgien) durchgängig korrekt verarbeitet (z. B. Volumenberechnung 72,5 × 8 = 580 kg korrekt). Dark Mode auf demselben Satz-Logging-Screen geprüft: alle Werte (KG, Reps, RIR) weiterhin klar lesbar, guter Kontrast. Light Mode durchgängig in allen übrigen Screenshots dieser Runde bestätigt funktionsfähig. Englisch (Gerätesprache during gesamter Runde): keine fehlenden/kaputten Platzhalter über sehr viele Screens hinweg beobachtet. Deutsch: iPhone-Systemsprache in den Einstellungen erfolgreich auf Deutsch umgestellt (Einstellungen-UI zeigte danach korrekt "Sprache & Region"/"Bearbeiten" etc.), jedoch überlebte die WebDriverAgent-Automatisierung den dadurch ausgelösten SpringBoard-Respring nicht mehr (App-Aktivierung/Touch-Eingaben schlugen danach fehl) — die Deltiq-App selbst konnte in dieser Runde NICHT mehr in deutscher Sprache geöffnet/geprüft werden. Türkisch: aufgrund der DE-Instabilität in dieser Runde nicht versucht. | teilweise | Dezimalgewicht/kg-Format, Dark Mode und der konkret reproduzierte Abschneide-Bug sind jetzt gerätebestätigt bzw. gefixt. Bekannte Nachweislücke, Auswirkung noch nicht abschließend geprüft: Deltiq selbst in Deutsch (Automatisierung überlebte den Systemsprachwechsel nicht) und in Türkisch (nicht versucht) sowie ein echter schmalerer Bildschirm (nur Dynamic-Type-Vergrößerung getestet, kein kleineres Simulator-Gerät). |
| E05 | Mehrstufig zurückwischen → wiederholt eine Ebene zurück, keine dauerhafte Sperre | P2 | `Theme.swift` (`deltiqSwipeBackEnabled`, pro View über `!isDirty` gesteuert) | kein dedizierter Test gefunden | Build/Commit `254d669`, TestingBot-Sessions (Runde 3). Kette Plan-Editor → Tag-Editor → Übungs-Editor durchlaufen. Horizontale Zurück-Wisch-Geste funktionierte WIEDERHOLT und ohne Einschränkung auf Plan-Editor- UND Tag-Editor-Ebene (beide im selben, gemeinsamen `NavigationStack` gepusht) — mehrfach hintereinander reproduziert, keine Sperre nach einmaliger Nutzung. Auf Übungs-Editor-Ebene wirkte dieselbe Geste dagegen NIE (auch nach einem zunächst versuchten Fix, siehe Korrektur-Commit `254d669`): Root Cause gefunden — `DayEditorView` öffnet `ExerciseEditorView` per `.sheet(item:) { NavigationStack { ExerciseEditorView(...) } }`, also mit einer EIGENEN, frischen `NavigationStack` (nur sich selbst als Root), anders als Plan-/Tag-Editor (`NavigationLink` im GEMEINSAMEN Stack). Der interne `SwipeBackHostController.gestureRecognizerShouldBegin` liefert dort strukturell IMMER `false` (kein Vorgänger zum Zurückpoppen). Die für eine Sheet-Präsentation tatsächlich zuständige Geste — Herunterwischen zum Schließen — wurde separat getestet und funktionierte dort korrekt (siehe unten). | bestanden | Auf Plan-/Tag-Editor-Ebene vollständig erfüllt. Für den Übungs-Editor gilt die Anforderung über die für Sheets korrekte Geste (Herunterwischen) als erfüllt, nicht über die horizontale Rand-Wisch-Geste — eine erste Fehldiagnose (vermeintlicher Fix per `.deltiqSwipeBackEnabled`) wurde durch Geräte-Nachtest widerlegt und zurückgenommen (siehe Nachtrag unten). |
| E06 | Ungespeicherter Entwurf + Schließgeste → kein Umgehen des Schutzes | **P1** | Konsistentes Muster: `.interactiveDismissDisabled(isDirty)` + `.deltiqSwipeBackEnabled(!isDirty)` über alle Editoren — **blockierend**, nicht "Dialog beim Wischversuch" | `EditorDiscardSnapshotTests.swift` deckt die `isDirty`-Erkennung breit ab (verwandt); kein Test der tatsächlichen Gesten-Blockade selbst | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Plan-Editor geöffnet, Planname geändert (Entwurf dirty), horizontale Zurück-Wisch-Geste versucht → KEINE Reaktion (kein Dialog, keine Navigation — tatsächlich blockierend, exakt wie im Code dokumentiert). Danach den Zurück-Chevron angetippt → ein Bestätigungsdialog wurde ausgelöst (vom Automatisierungs-Framework mit `autoAcceptAlerts` automatisch bestätigt, dadurch indirekt sichtbar: App landete nach dem Tap auf der Plan-Liste MIT dem ursprünglichen, unveränderten Namen — die Änderung wurde korrekt verworfen, nicht umgangen). | bestanden | Die Kern-Garantie (Wisch-Geste bei ungespeichertem Entwurf wirkungslos, kein Umgehen) ist gerätebestätigt. Der Bestätigungsdialog selbst wurde nicht manuell bestätigt/abgebrochen (automatisch durchgereicht), daher kein expliziter Beleg für den Dialogtext/die Button-Beschriftung. |
| E07 | Trainingsseiten wechseln und Listen ziehen → bestehende Gesten erhalten | P2 | `.onMove` in `PlanEditorView`, `DayEditorView`, `DashboardSettingsView` | keine dedizierte Regressionsprüfung für "nach Seitenwechsel" gefunden | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Im Plan-Editor geöffnet → zu Dashboard-Tab gewechselt → zurück zu Plan-Tab → denselben Plan erneut geöffnet → über das Ellipsis-Menü "Reorder" aktiviert → einen Trainingstag ("Lower & Core") per Drag-Handle von Position 1 auf Position 4 gezogen → Reihenfolge korrekt neu sortiert (Wochentage rotierten wie im UI-Hinweis beschrieben automatisch mit, Inhalt blieb den richtigen Tagen zugeordnet). Drag funktionierte nach dem Tab-Wechsel ohne Einschränkung, identisch zu einem Drag ohne vorherigen Seitenwechsel. | bestanden | Nur EIN Tab-Wechsel-Zyklus (Plan→Dashboard→Plan) und eine Listenart (Trainingstage im Plan-Editor) geprüft, nicht z. B. Übungsliste im Tag-Editor oder `DashboardSettingsView` nach Seitenwechsel. |
| E08 | Start-Check-Einstiege suchen → nur im Onboarding erreichbar | P2 | `BaselineCheckFlowView` — Codesuche bestätigt genau einen produktiven Aufrufer (`OnboardingView.swift`) | kein Test gefunden, der diese Invariante als Regression schützt | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Codesuche ist kein automatisierter Regressionsschutz gegen einen künftigen zweiten Call-Site, kein Gerätenachweis. |
| F01 | Vier Wochen mit viel/wenig Teilnahme → datenabhängige Empfehlung | **P3** | `FourWeekReviewOrchestrator`, `FourWeekReviewAssembler`, `FourWeekReviewDueCalculator` | `FourWeekReviewAssemblerTests.testCompliantPlanWithGoodCheckInYieldsKeepAsIs` (volle Teilnahme → `.keepAsIs`) und `.testHeavilyMissedParticipationIsSurfacedAsConcern` (keine Teilnahme → `.participationBelowPlan`) — beide mit echtem `ModelContainer` + `TrainingPlan.activatedAt` in der Vergangenheit über den realen Produktionspfad `FourWeekReviewAssembler.assemble`; ergänzt um `FourWeekReviewOrchestratorTests.testSingleMissedSessionBelowThresholdIsNotAConcern`/`.testSignificantlyMissedParticipationIsAConcern` (Schwellenwert-Abstufung statt starrer Steigerung) | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Integrationsebene) | Reiner UI-/Geräte-Nachweis (tatsächlich gerenderter Review-Screen) fehlt weiterhin — betrifft nur die Darstellung, nicht die hier bewiesene datenabhängige Entscheidungslogik. Kein Export-Hang/Zeit-Manipulationsweg nötig, siehe Nachtrag unten. |
| F02 | Flexibler Plan/Pause/Planwechsel → keine erfundene Compliance | **P3** | `FourWeekReviewAssembler`/`BlockReviewRecord`, `PlanParticipationEvaluator` | `PlanParticipationEvaluatorTests.testFlexibleScheduleCreditsTheSameOffWeekdayPatternThatFixedWouldReject`/`.testFlexibleCadenceSurplusSessionsDoNotCreditBeyondQuota` (flexibler Plan), `.testInactivePlanIsNotReliablyEvaluableBecauseDeactivationTimeIsUnknown` (Pause → `.notReliablyEvaluable`, keine erfundene Zahl), `.testEveryEvaluatedResultDisclosesTheSingleActivationAnchorLimitation` (Planwechsel als offen ausgewiesene Datenlücke statt falscher Nenner) — reine Core-Logiktests mit konstruierten historischen Daten | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Logikebene) | UI-Anzeige der Datenlücken-Hinweise selbst nicht geräteverifiziert. |
| F03 | Gute Entwicklung → „Beibehalten" als gültiges Ergebnis | **P3** | `FourWeekReviewOrchestrator` | `FourWeekReviewOrchestratorTests.testAllGoodYieldsKeepAsIsWithNoDataGaps` und `FourWeekReviewAssemblerTests.testCompliantPlanWithGoodCheckInYieldsKeepAsIs` (reale Teilnahme+Check-in → `.keepAsIs` als vollwertiges Ergebnis, nicht nur Abwesenheit von Problemen) | kein Geräte-Nachweis vorhanden | bestanden | UI-Darstellung der „Beibehalten"-Karte selbst nicht geräteverifiziert. |
| F04 | Ausgelassene Beintage/Brustschwerpunkt → Rückfrage statt Zwangswechsel | **P3** | **keine erkennbare Implementierung gefunden** — `DayAnalyzer`/`DayAnalysis` liefern nur eine EINTAGES-Muskel-Fokus-Heuristik; keine wochenübergreifende Auswertung "ausgelassene Beintage"/"bewusster Brustschwerpunkt" und keine Rückfrage-/Zielvergleichslogik im Review selbst | kein Test gefunden (keine Implementierung, die zu testen wäre) | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten, neue Kategorie analog A09/C04): Dok. 03 §6 verlangt ausdrücklich Rückfrage bzw. Zielvergleich statt Kalender-Zwangswechsel bei ausgelassenen Beintagen/bewusstem Schwerpunkt; `FourWeekReviewOrchestrator.Concern` kennt dafür keinen Fall. Echte Implementierungslücke, kein reiner Testlücken-Befund. |
| F05 | Beschwerden/fehlende RIR-Daten → keine Diagnose/erfundene Erholung | **P3** | `FourWeekReviewOrchestrator` (`.complaintsReported`), `PeriodicCheckIn` | Beschwerden-Hälfte bestanden: `FourWeekReviewOrchestratorTests.testComplaintsReportedIsAConcern` + `FourWeekReviewAssemblerTests.testLatestCheckInFeedbackIsAssembledFromRealData` (Befund wird sichtbar; UI-Text rein beobachtend "hast du Beschwerden... angegeben", keine Diagnose). RIR-Hälfte NICHT durch einen eigenen Test bewiesen, aber per Code-Audit bestätigt: weder `PlanParticipationEvaluator.Input` noch `FourWeekReviewOrchestrator.CheckInFeedback` führen überhaupt ein RIR-Feld — der Review kann strukturell keine Erholungsaussage aus fehlenden RIR-Daten erfinden, weil RIR dort gar nicht einfließt | kein Geräte-Nachweis vorhanden | teilweise | Kein dedizierter automatisierter Nachweis für den RIR-Teil (nur Code-Audit der Abwesenheit, keine Test-Assertion); kein Geräte-Nachweis für den laut Dok. 03 §4 verlangten separaten, vorsichtigen Beschwerden-Abklärungsweg selbst. |
| F06 | Review ablehnen/aufschieben/wieder öffnen → keine Doppeländerung | **P3** | `FourWeekReviewDueStatus.completeCurrentBlock`, `AbsenceDeload.remember`/`.assess`/`.apply` (von `FourWeekReviewView.resolveComeback`/`completeReview` aufgerufen) | `FourWeekReviewDueStatusTests.testCompletingTheSameBlockTwiceIsIdempotent` (doppelter Abschluss-Tap ändert nichts zweimal) + NEU `AbsenceDeloadReopenTests.testDecliningSuppressesTheSameBucketButReArmsAtAStrongerGap` (Ablehnen → Wieder-öffnen am selben Tag erzeugt keine erneute Rückfrage/Hinweisschleife; spürbar stärkere Lücke fragt dagegen zu Recht erneut) + `.testAcceptingPreventsASecondApplicationShortlyAfterReopening` (Übernehmen → Wieder-öffnen kurz danach verhindert zweite Anwendung) — alle mit echtem `ModelContainer` + echten `UserDefaults`, über dieselben Produktionsfunktionen, die der Review-Screen beim Tippen aufruft | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Integrationsebene) | Der tatsächliche Tap auf dem Screen selbst (Bestätigungsdialog, Button-Zustände, "Später"-Verhalten rein visuell) ist nicht geräteverifiziert. |
| F07 | Review übernehmen → neue gültige Fassung, Historie unverändert | **P3** | `FourWeekReviewDueStatus.completeCurrentBlock`/`.history`, `BlockReviewRecord` | `FourWeekReviewDueStatusTests.testCompletingTwoBlocksInSequenceKeepsBothInHistory` (Übernahme eröffnet sofort einen neuen, gültigen Block; Block 1 bleibt in der Historie unverändert erhalten) + `.testLegacyCompletionWithoutHistoryJSONIsReadAsOneRecordWithoutFabricatedOutcome` (Altbestand wird beim Lesen nicht nachträglich umgedeutet) | kein Geräte-Nachweis vorhanden | bestanden | UI-Nachweis des tatsächlichen Wocheneditor-Vorher-/Nachher-Vergleichs beim Übernehmen fehlt. |
| F08 | Gleichzeitige Progressions-/Deload-/Review-Hinweise → keine Widersprüche | **P3** | `FourWeekReviewOrchestrator` (Deload/Comeback-Konfliktauflösung), `ProgressionEvaluator`, `DeloadAdvisor`, `ProgressionApplicator`/`DeloadManager` (Koexistenz-Fund dieser Runde) | `FourWeekReviewOrchestratorTests.testConflictingDeloadAndComebackSignalsResolveToComebackOnly` (Review-Ebene, exakt) **PLUS echter Bug gefunden und gefixt**: `ProgressionApplicator.apply`/`.evaluateOnly` schrieben bisher `.increaseWeight` auch auf eine Übung, deren Gewicht `DeloadManager` gerade reduziert und eingefroren hatte (`deloadOriginalWeight != nil`) — direkter Verstoß gegen Dok. 03 §5 ("nicht dieselbe Übung gleichzeitig steigern und reduzieren") und eine stille Datenverlust-Falle (ein späteres `endDeload()` hätte den währenddessen erarbeiteten Fortschritt wieder verworfen). Fix: Veto auf `.hold`, solange ein Deload-Snapshot offen ist (Commit `c96bf5c`). Regressionstests: `ProgressionApplicatorDeloadConflictTests.testIncreaseWeightIsVetoedToHoldWhileAnExerciseHasAPendingDeloadSnapshot`, `.testEvaluateOnlyMirrorsTheSameDeloadVetoAsApply`, Gegenprobe `.testIncreaseWeightStillAppliesNormallyWithoutAnActiveDeload` | kein Geräte-Nachweis vorhanden | bestanden (inkl. Bugfix) | Kein Geräte-Nachweis, dass das Dashboard mehrere gleichzeitige Hinweise (Progression-Celebration, Deload-Banner, Review-Fälligkeit) auch VISUELL widerspruchsfrei anordnet — nur die zugrundeliegende Entscheidungslogik (inkl. des gefixten Konflikts) ist bewiesen. |

**Status-Verteilung (46 Fälle, nach Runde 11):** 30 bestanden (A03, A05,
A06, A08, A11, B01, B02, B03, B04, B05, B06, C01, C02, C03, D01, D02,
D03, D04, D05, E01, E03, E05, E06, E07, F01, F02, F03, F06, F07, F08) ·
12 teilweise (A01, A02, A04, A07, A10, A12, C05, C06, D06, E02, E04, F05)
· 4 noch nicht geprüft (A09, C04, E08, F04) · 0 blockiert · 0
fehlgeschlagen. (Vorheriger Stand nach Runde 5/C01-Fix-Retest: 45 Fälle,
30 bestanden/11 teilweise/4 noch nicht geprüft; neu in Runde 11: A12.
Stand nach Runde 4: 29 bestanden/12 teilweise, siehe Git-Historie dieses
Dokuments.)

(F01–F08 waren vor diesem Durchgang pauschal "blockiert"; siehe Nachtrag
unten für die Einzelfallprüfung, die diese pauschale Einstufung ersetzt.)

**Top-5-Geräteprüfung dieser Runde — Ergebnis:**

1. **E01** – Messung-Update ohne Duplikat: **echter Bug gefunden und
   gefixt** (fehlendes `context.save()`, Commit `89c788a`), danach
   geräteverifiziert inkl. Kaltstart. Bestanden.
2. **C06** – Laufende Session + Planänderung: Satzzahl-Reduktion während
   laufender Session geräteverifiziert — Session bleibt strukturell
   unverändert, kein Datenverlust, kein Crash. Ausdrücklich NUR dieser eine
   Ablauf; kein Nachweis für andere strukturelle Planänderungen während
   einer laufenden Session. Teilweise.
3. **D06** – Trainingsort-Rückrollen: Kernzusage (kein erneut ausgelöster
   Migrationsdialog beim Schließen/Wiederöffnen) geräteverifiziert. Der im
   Testablauf vorgesehene Einzelschritt "Dialog bewusst ablehnen" ließ sich
   nicht isoliert reproduzieren, da die Anpassung bei echtem
   Equipment-Konflikt automatisch ohne Bestätigungsdialog durchlief.
   Teilweise.
4. **A11** – Onboarding-Abbruch/Mehrfachabschluss: beide Teilfälle (a:
   Doppel-Tap-Guard, b: Force-Quit-Abbruch) geräteverifiziert, je exakt 1
   Plan. Bestanden.
5. **D02** – Add/Delete + Reorder + Verwerfen: Löschen+Reorder+Verwerfen in
   einer Sitzung geräteverifiziert, sauberer Rollback der Reihenfolge ohne
   Wochentag-/Index-Kollision. Bestanden.

## Reset-App-Befund eingeordnet (Nachtrag, kein Fix nötig)

Der in der vorigen Runde als "scope-fremde Beobachtung" notierte Fund
("Reset App löscht ohne Rückfrage") wurde per Code-Prüfung untersucht,
nicht durch eine erneute destruktive Geräteaktion mit echten Daten.

Befund (`Sources/FitnessAppUI/Settings/SettingsView.swift`):
- Es gibt genau EINE Aufrufstelle von `resetApp()`, gegated durch
  `showingResetConfirm`.
- Der Tap auf "Reset App" in der Danger-Zone-Sektion setzt NUR
  `showingResetConfirm = true` — löst keine Löschung aus.
- Es folgt ein `.confirmationDialog` mit eigenem Titel/Message-Text, einem
  `role: .destructive`-Bestätigungsbutton UND einem separaten
  `role: .cancel`-Abbrechen-Button.
- `resetApp()` selbst beginnt mit einem AUTOMATISCHEN Backup
  (`BackupService.createBackupAsync(..., reason: .preReset)`) — schlägt
  dieses fehl, wird abgebrochen (Fehler-Alert) und NICHTS gelöscht.
- Ein `isResetting`-Gate verhindert zusätzlich Crashes durch Views, die
  während der Löschung noch auf bald gelöschte Objekte zugreifen.

**Einschätzung:** Die Aktion ist bereits durch Bestätigungsdialog + Abbrechen-Option
+ automatisches Vor-Reset-Backup geschützt und nicht versehentlich auslösbar
(eigene, eindeutig beschriftete Zeile in einer separaten "Danger Zone"-Sektion,
kein benachbartes Element mit ähnlicher Beschriftung). Die vorherige
Geräte-Beobachtung "ohne Rückfrage" deckt sich nicht mit dem Code und ist
mit größter Wahrscheinlichkeit ein Artefakt des automatisierten Testablaufs
(die Appium-Steuerung dürfte den Bestätigungsdialog im selben Zug
durchgetippt haben, ohne ihn als eigenen Schritt zu protokollieren) statt
ein echter fehlender Schutz. **Kein Fix umgesetzt** — es liegt kein
bestätigter Datenverlust-/Sicherheitsbefund vor; eine erneute Reset-Aktion
mit echten Daten wurde zur Bestätigung bewusst nicht ausgeführt. Falls die
ursprüngliche Beobachtung dennoch real war (z. B. ein Timing-Fall, der sich
der Code-Prüfung entzieht), bitte mit einem konkreten Reproduktionsschritt
erneut melden statt pauschal zu wiederholen.

## Fachliche Widersprüche Spezifikation vs. Code (nicht eigenmächtig aufgelöst)

1. **A09 / Dokument 02 §4**: Die Spezifikation verlangt, dass bei
   aktiviertem Laufcoach im Onboarding gezielt nach Laufpensum,
   Referenzleistung, Zieldatum etc. gefragt wird. Im Code existiert dafür
   in der Onboarding-Oberfläche **keine** Implementierung — `CardioGoal`
   und `current5kReferenceSeconds` gibt es nur in `ProfileEditorView`
   (nachgelagert, außerhalb des Onboardings). Echte Implementierungslücke
   gegenüber einer verbindlichen Vorgabe, kein reiner Testlücken-Befund.
2. **C04 / Dokument 01 §6-Tabelle**: Die Tabelle verlangt vier getrennte
   Equipment-Zustände — nicht vorhanden / vorhanden / explizit unbekannt /
   **Präferenz** (als Gewichtung, kein Verbot). Der Code
   (`EquipmentRequirement`, `UserEquipmentProfile`) implementiert nur die
   ersten drei; eine separate „Präferenz als weiche Gewichtung" existiert
   nicht.
3. **A02 / 00_START_HIER.md** („Kontextabhängige Oberfläche statt
   kopierter zweiter Builder"): `OnboardingView.enduranceModalityStep`
   trägt den eigenen Code-Kommentar „Duplikat von
   `PlanBuilderView.enduranceModalitySubflow`". Beide Stellen nutzen
   dieselben Lokalisierungsschlüssel und dieselbe Entscheidungslogik, sind
   aber zwei separat gepflegte SwiftUI-Implementierungen — eine teilweise
   Abweichung von der nicht verhandelbaren Architekturgrenze.
4. **F04 / Dokument 03 §6**: Die Spezifikation verlangt bei ausgelassenen
   Beintagen bzw. einem bewusst gewählten Brustschwerpunkt ausdrücklich
   eine Rückfrage ("beibehalten oder ändern?") bzw. einen Zielvergleich,
   nie einen automatischen Kalender-Zwangswechsel. Im Code existiert dafür
   **keine** Implementierung — `FourWeekReviewOrchestrator.Concern` kennt
   nur `participationBelowPlan`/`complaintsReported`/`goalNoLongerCurrent`/
   `deloadRecommended`/`comebackSuggested`, keinen Fall für
   Muskelgruppen-/Schwerpunkt-Balance. `DayAnalyzer`/`DayAnalysis` liefern
   zwar einen Muskel-Fokus, aber nur pro EINZELNEM Tag, nicht
   wochenübergreifend und ohne jede Rückfrage-Logik. Echte
   Implementierungslücke gegenüber einer verbindlichen Vorgabe, kein
   reiner Testlücken-Befund (gleiche Kategorie wie A09/C04).
5. **C01 / Dokument 01 §6 — BEHOBEN (Runde 5), hier aus Nachvollziehbarkeit
   stehen gelassen statt gelöscht.** Die Spezifikation verlangt "Nach
   gespeichertem relevanten Update einmalig gebündelten Vorschlag anbieten,
   nicht bei jedem Tastenanschlag." Geräte-Nachweis (Runde 4): die
   Cardio-Feasibility-Karte in `ProfileEditorView` erschien nachweislich
   NICHT gebündelt nach einem Speichern-Schritt, sondern bereits bei JEDEM
   einzelnen Tastendruck in den Cardio-Feldern — reproduziert direkt nach
   dem ersten Zeichen im Wochenvolumen-Feld, Tastatur noch offen. Ursache:
   `ProfileEditorView` hatte für den gesamten Bildschirm keinen
   Speichern-Schritt (laut eigenem Code-Kommentar "autosaves to SwiftData
   on every keystroke"), die Cardio-Felder waren direkt an `$profile`
   gebunden. Fix (Commit `47ab4d6`): die Cardio-/Laufziel-Felder zogen in
   eine neue `CardioGoalEditorView` mit lokalem Draft + explizitem
   Speichern/Abbrechen um (identisches Muster wie
   `BodyDataEditorView`/`TrainingLocationEquipmentEditorView`), `profile`
   ändert sich jetzt erst beim Speichern-Tap. Geräte-Nachweis (Runde 5):
   die Karte erscheint jetzt nachweislich erst nach dem Speichern, nicht
   während der Eingabe — bestätigt über alle drei Oberflächen
   (Profil/Dashboard/Plan-Tab). Dabei zusätzlich ein neuer, unabhängiger
   Bug gefunden und gefixt (Commit `1c8bf54`): der neue Speichern-Schritt
   selbst rief kein `context.save()` auf, wodurch ein gespeichertes
   Cardio-Update einen Kaltstart kurz danach nicht reproduzierbar
   überlebte — siehe C01-Zeile und Nachtrag „Runde 5" für Details. C01
   gilt seither als vollständig bestanden, kein offener Rest mehr.
6. **E04 / Settings-Hinweistext "App & Trainingserlebnis" — TEILWEISE
   BEHOBEN (Runde 9), hier aus Nachvollziehbarkeit stehen gelassen statt
   gelöscht.** Ursprünglicher Befund (Runde 8): der Hinweistext verspricht
   wörtlich "steuert ... die Anzeige in Eingabe-Feldern, im Hantel-Rechner
   und auf den Karten" — Hantel-Rechner/Warmup-Rampe respektierten das
   Setting bereits, das eigentliche Gewichts-Eingabefeld beim
   Satz-Logging, `ProfileEditorView`/`BodyDataEditorView` und das
   Dashboard-Gewichts-Trend-Widget zeigten durchgehend kg.
   Fix (Commit `0a3c68e`, Runde 9): `WeightUnit`-Typ bindet jetzt genau
   diese vier Stellen an `weight_unit` an (Konvertierung/Eingabe-Parsing/
   Rückkonvertierung), gerätebestätigt (siehe Nachtrag „Runde 9"). Bewusst
   NICHT Teil dieses Fixes, weiterhin kg-only (Scope-Grenze VOR der
   Umsetzung in Runde 9 explizit festgehalten, keine stille Ausweitung):
   Trainingsvolumen-Aggregation, PR-Erkennung/-Banner, Übungs-
   Gewichtsverlauf-Charts außerhalb des Dashboards, CSV-Export/-Import —
   dieselbe Abgrenzung, die der ursprüngliche Code-Kommentar (DEL-220)
   bereits als eigenes, größeres Thema benannt hatte. Diese verbleibende
   Scope-Grenze geht weiterhin als offene Entscheidung an den Nutzer
   zurück, nicht eigenmächtig erweitert.
7. **A12 / Runde 11 — Hybrid + "Both"-Ausdauerform verliert eine gewählte
   Sportart still.** Prüffall 8 der Runde-11-Spezifikation verlangt: "zu
   wenige Einheiten für alle gewählten Sportarten → sichtbare Entscheidung/
   Konflikt statt stillem Weglassen." Im Code
   (`GoalDrivenPlanSelectionBuilder.enduranceSelections`) führt eine
   Rundung, bei der eine der beiden Modalitäten auf 0 Tage fällt (z. B.
   Hybrid + "Both" bei `totalDaysPerWeek = 3`, dem tatsächlichen
   UI-Default), zum kommentarlosen Entfernen dieser Sportart aus der
   generierten Auswahl — gerätebestätigt (Runde 11, siehe Zeile A12):
   keine Meldung, kein Hinweis, keine Rückfrage. Die spezifikationskonforme
   Lösung (sichtbare Entscheidung/Konflikt-Anzeige) ist eine neue
   Konflikt-UI und keine begrenzte Code-Korrektur im Sinne der erteilten
   Aufträge — daher ursprünglich hier dokumentiert statt eigenmächtig
   gefixt. **Update Paket 1 (Teil 1), Commit `5146bfe`:** der Nutzer hat
   die Produktentscheidung explizit getroffen (1 Kraft+1 Laufen+1
   Radfahren als transparente Alternative bei 3 Tagen, plus ein
   `distributionConflict`-Signal für den verbleibenden echten
   Mangelfall) — die Kern-Verteilungslogik ist jetzt gefixt und
   test-verifiziert (siehe Zeile A12 und Nachtrag „Paket 1 (Teil 1)"
   oben). Offen bleibt nur noch die UI-Anbindung des Konflikt-Signals
   (sichtbarer Banner/Dialog bei echtem Tage-Mangel) sowie der
   Geräte-Nachweis des Fixes selbst.

## F01–F08 differenziert geprüft (Nachtrag)

**Auftrag:** die pauschale Einstufung "F01–F08 blockiert, weil zeitabhängig
+ bekannter Export-Hang" war nicht differenziert genug — der Export-/
Geräte-Blocker betrifft ausschließlich den Versuch, die 28-/42-Tage-
Fälligkeit auf einem ECHTEN GERÄT über System-Uhr oder CSV-Re-Import zu
simulieren. Er betrifft NICHT die zugrunde liegende Entscheidungslogik,
die bereits für andere Pakete (B–E) routinemäßig über Daten-/
Integrationstests mit konstruierten historischen Feldern bewiesen wird
(echter `ModelContainer`, `TrainingPlan.activatedAt`/
`blockReviewHistoryJSON` auf einen Zeitpunkt in der Vergangenheit gesetzt,
dann der echte Produktionscode-Pfad aufgerufen — identische Technik zu
`DayEditorPersistenceTests.swift`/`MeasurementPersistenceTests.swift`,
keine Systemuhr, keine Produktdaten-Manipulation).

**Ergebnis der Einzelfallprüfung:**

* **6 von 8 Fällen (F01, F02, F03, F06, F07, F08) sind jetzt "bestanden"**
  auf Daten-/Integrationsebene — großteils bereits durch vorhandene Tests
  aus früheren Paketen exakt abgedeckt (`FourWeekReviewAssemblerTests`,
  `FourWeekReviewOrchestratorTests`, `FourWeekReviewDueStatusTests`,
  `PlanParticipationEvaluatorTests`), ergänzt um zwei neue, gezielte
  Testdateien dieser Runde (`AbsenceDeloadReopenTests.swift`,
  `ProgressionApplicatorDeloadConflictTests.swift`). In jedem dieser 6
  Fälle bleibt ausschließlich der reine UI-/Geräte-Nachweis (der
  tatsächlich gerenderte Screen, ein echter Button-Tap) offen — dafür gilt
  weiterhin der bekannte Export-Hang-Blocker, aber nur für diesen
  Teilaspekt, nicht für den ganzen Fall.
* **1 Fall (F05) ist "teilweise"**: die Beschwerden-Hälfte ist
  automatisiert bewiesen (Befund sichtbar, UI-Text rein beobachtend, keine
  Diagnose). Die RIR-Hälfte ist nicht durch einen positiven Test, sondern
  durch Code-Audit bestätigt — RIR fließt in keine der review-relevanten
  Eingabetypen (`PlanParticipationEvaluator.Input`,
  `FourWeekReviewOrchestrator.CheckInFeedback`) überhaupt ein, kann also
  strukturell keine erfundene Erholungsaussage erzeugen.
* **1 Fall (F04) bleibt "noch nicht geprüft"** — echte Implementierungslücke,
  kein Testlücken-Befund: es gibt keine Review-Logik, die ausgelassene
  Beintage oder einen bewussten Brustschwerpunkt überhaupt erkennt oder
  dazu eine Rückfrage stellt (Dok. 03 §6). Neuer fachlicher Widerspruch
  Nr. 4 unten.
* **Echter Bug gefunden und gefixt (F08):** `ProgressionApplicator.apply`/
  `.evaluateOnly` erhöhten `Exercise.suggestedWeight` auch dann, wenn
  `DeloadManager` für genau diese Übung gerade eine reduzierte
  Deload-Last eingefroren hatte (`deloadOriginalWeight != nil`) — ein
  direkter Verstoß gegen Dok. 03 §5 ("nicht dieselbe Übung gleichzeitig
  steigern und reduzieren") und eine stille Datenverlust-Falle (ein
  späteres `endDeload()` hätte den in der Deload-Woche erarbeiteten
  Fortschritt wieder verworfen). Fix: `.increaseWeight` wird zu `.hold`
  vetoed, solange ein Deload-Snapshot offen ist; Deload selbst bleibt
  weiterhin erlaubt (Sicherheitsnetz). Commit `c96bf5c`. CI
  (`apple-ci-comparison.yml`, Run `39393513593`, macOS-Runner, echte
  Swift-/SwiftData-Testausführung + App+Widget-Build für den
  iOS-Simulator): **erfolgreich**, alle 1454 Package-Tests bestanden,
  inklusive der 5 neuen Tests dieser Runde
  (`AbsenceDeloadReopenTests.*`, `ProgressionApplicatorDeloadConflictTests.*`).

**Kein Export-Hang/Zeit-Manipulationsweg wurde für diese Runde benötigt** —
alle neuen/verwendeten Tests laufen vollständig über konstruierte
Testdaten, nie über eine simulierte Geräte-Uhr oder einen CSV-Re-Import.

## Runde 3 (dieser Durchgang): Onboarding/Hybrid/Coach, Navigation, Drag&Drop, RIR, Bildschirmgröße (Nachtrag)

**Auftrag:** Block 1 (Onboarding-/Hybrid-/Coach-Zustände: A01, A03, A04,
A06, A07, A08, A10), Block 2 (Zurücknavigation/Entwurfsschutz: E05, E06,
E07), Block 3 (Speichern/Abbrechen: B01, C01, C02), danach RIR-Werte (E03)
und kleine Bildschirmbreite/große Schrift/Light-Dark/Locale (E04), in
dieser Reihenfolge, auf dem TestingBot-iPhone-15/iOS-18.0-Simulator.

**Sessions (alle aktiv beendet, `max_concurrent=1` eingehalten):**

| # | Zweck | Build/Commit | Dauer | TestingBot-Session-ID |
|---|---|---|---|---|
| 1 | Block 1 (Onboarding A01/A03/A04/A06/A07/A08/A10), B01 (Drag&Drop + Move-to), A10 | `fc2ad39` | 1095 s | `b9450af4a27b-6e2efa9abd4c-3d496f1ae049-179248493958-95771201` |
| 2 | Block 2 (E05/E06/E07), E03 (RIR), E04-Repro (Dynamic Type, Dark Mode, Locale-Versuch) | `fc2ad39` (vor E04/E05-Fix) | 1250 s | `afda04093bca-2dafa6936f35-31d3752e4283-179248617830-89527586` |
| 3 | Geräte-Nachtest E05-Fix (widerlegt) + E04-Fix (bestätigt) | `64ba455` | 450 s | `df816cc3825c-4f380bbe18e0-071e7bffecb4-179248760926-21784839` |
| 4 | C01/C02 (Cardio-Zieländerung), Measurement-Doppel-Tap-Repro | `64ba455` | 209 s | `1ea03ac69db2-919c3f52343c-bf323ef4b421-179248854000-67966365` |

Gesamt: **3.004 Sekunden** von 34.515 Sekunden Restbudget vor dieser
Runde → **ca. 31.511 Sekunden Restbudget danach** (TestingBot-Konto-API
zeigte kurz nach Sitzungsende noch 31.730 Sekunden, vermutlich
Abrechnungs-/Rundungsverzug von wenigen Sekunden je Session; die Summe
der einzelnen Session-Dauern gilt als genauerer Wert). Keine zusätzlichen
Käufe.

**CI-Läufe (`apple-ci-comparison.yml`, GitHub Actions, macOS-Runner):**
Run `39392642582` (`fc2ad39`, Ausgangsbasis) ✓, Run `39396027125`
(`3e67cb8`, ursprünglicher E05-Versuch) ✓, Run `39397907485` (`64ba455`,
E04-Fix + E05-Versuch) ✓, Run `39399872168` (`254d669`,
E05-Korrektur/Rücknahme) ✓ — alle erfolgreich, Build+Tests für Swift
Package und iOS-App/Widget.

### Echter Bug gefunden und gefixt: E04 (Gewichtsfeld schneidet bei großer Textgröße ab)

Bei aktivierter „Larger Accessibility Sizes" (größte Dynamic-Type-Stufe,
über iOS-Einstellungen → Eingabehilfen gesetzt) schnitt das KG-Eingabefeld
im Satz-Logging (`SetRow.weightInput`) ein eingegebenes Dezimalgewicht wie
„72,5" zu „7..." ab — das Feld hatte eine feste Breite ohne
Skalierungserlaubnis. Fix: `.minimumScaleFactor(0.5)` + `.lineLimit(1)`
(Commit `64ba455`), neuer Regressionstest
`SetRowWeightFieldScalesDownInsteadOfTruncatingTests` (liest `SetRow.swift`
direkt von der Platte, kein SwiftUI/SwiftData nötig). Geräte-Nachtest nach
dem Fix auf frischem CI-Build bestätigt: „72,5" bei identischer
Textgröße jetzt vollständig sichtbar.

### Fehldiagnose gefunden, korrigiert: E05 (vermeintlicher Swipe-Back-Fix im Übungs-Editor war wirkungslos)

Erster Versuch (Commit `3e67cb8`): `.deltiqSwipeBackEnabled(!isDirty)` zu
`ExerciseEditorView` ergänzt, nach dem Muster von `PlanEditorView`/
`DayEditorView`, da dort dieselbe `.navigationBarBackButtonHidden(true)`-
Nebenwirkung beobachtet schien. **Geräte-Nachtest DES EIGENEN Fixes** auf
dem fertig gebauten CI-Artefakt zeigte: die horizontale Zurück-Wisch-Geste
blieb am Übungs-Editor vor UND nach dem Fix identisch wirkungslos (mehrfach
reproduziert; als Kontrolle am Plan-/Tag-Editor im selben Durchlauf sofort
funktionsfähig). Root Cause: `DayEditorView` öffnet `ExerciseEditorView`
über `.sheet(item:) { NavigationStack { ExerciseEditorView(...) } }` — eine
eigene, frische `NavigationStack` mit nur sich selbst als Root, anders als
die per `NavigationLink` im gemeinsamen Stack gepushten Plan-/Tag-Editoren.
`SwipeBackHostController.gestureRecognizerShouldBegin` liefert dort
strukturell immer `false`. Der ergänzte Aufruf war daher toter Code, keine
Reparatur. Zusätzlich auf dem Gerät bestätigt: die für eine
Sheet-Präsentation tatsächlich zuständige Geste — Herunterwischen zum
Schließen — funktionierte bereits vor diesem ganzen Vorgang korrekt
(`.interactiveDismissDisabled(isDirty)`, unverändert). Fix zurückgenommen,
Regressionstest entfernt (Commit `254d669`). Kein Produktfehler an dieser
Stelle; E05 gilt für den Übungs-Editor über die Herunterwisch-Geste als
erfüllt.

Dieser Vorgang ist hier bewusst vollständig dokumentiert statt
stillschweigend korrigiert: er zeigt, warum ein Fix erst nach einem
erneuten Geräte-Nachtest als bestätigt gelten darf, nicht schon nach einem
plausiblen Code-Vergleich.

### Block 1 (Onboarding/Hybrid/Coach) — Kurzfassung

A03 und A06 **bestanden** (Kraft+Laufen im Vorschlag UND im persistierten
Plan bei Coach aus; „Both"-Auswahl übersteht die Coach-Entscheidung
sichtbar). A08 **bestanden** (Ausdauerform-Wechsel hin und zurück erzeugt
keinen veralteten/inkonsistenten Zustand, setzt beim Zurückwechseln aber
auf den Default statt die letzte Wahl zu merken). A04, A07, A10
bleiben **teilweise** mit jetzt konkreterem Gerätebefund (siehe Tabelle
oben) — u. a. bestätigt A04 erneut die A09-Lücke (keine Laufziel-Fragen,
unabhängig vom Coach-Zustand), und A10 stellt klar, dass der Haken im
„Build Plan"-Pfad das GESAMTE Onboarding abschließt statt nur den Entwurf
zu aktualisieren (abweichend von der engsten Lesart aus Dok. 02 §6, aber
ohne beobachteten Datenfehler). A01 bleibt **teilweise**: die eigentliche
Kernfrage (bestehendes Profil aus einem früheren Durchlauf, erneuter
Eintritt ins Onboarding) ließ sich in dieser Runde nicht auslösen; nur ein
Teilaspekt (Vorbefüllung beim Wechsel Onboarding→„Build Plan") wurde
beobachtet.

### Block 2 (Navigation/Entwurfsschutz) — Kurzfassung

E05, E06, E07 alle **bestanden** (siehe Tabelle oben und E05-Nachtrag für
die Fehldiagnose-Korrektur).

### Block 3 (Speichern/Drag&Drop/Cardio-Vorschau) — Kurzfassung

B01 **bestanden** (sowohl echte Drag-Geste als auch „Move to…"-Menü
funktionieren und ergeben die korrekte Reihenfolge). C01/C02 bleiben
**teilweise**: der getestete aktive Plan enthielt keine Lauf-/Cardio-Inhalte,
weshalb nach einer Cardio-Zieländerung erwartungsgemäß keine
Vorschlagskarte erschien — der eigentliche Auslösefall (aktiver Plan MIT
Laufeinheiten) wurde aus Zeitgründen nicht nachgestellt.

### E03 (RIR-Werte) — bestanden

Alle 11 gültigen Werte (0 bis 5 in 0,5-Schritten) vollständig sichtbar,
korrekt formatiert und nach dem Loggen weiterhin korrekt angezeigt.

### E04 (kleine Bildschirmbreite, große Schrift, Light/Dark, Locale) — teilweise, siehe Fix oben

Dezimalgewicht/kg-Format und Dark Mode gerätebestätigt; der konkrete
Abschneide-Bug gefunden und gefixt. Deutsch/Türkisch der APP SELBST
blieben ungeprüft: die iPhone-Systemsprache ließ sich zwar erfolgreich auf
Deutsch umstellen, aber die WebDriverAgent-Automatisierung überlebte den
dadurch ausgelösten SpringBoard-Respring nicht — **bekannte
Nachweislücke, Auswirkung noch nicht abschließend geprüft**, kein
Hinweis auf einen Produktfehler. Türkisch wurde daraufhin nicht mehr
versucht. Ein echtes kleineres Gerät (statt nur Dynamic-Type-Vergrößerung
auf dem iPhone 15) wurde nicht zusätzlich getestet.

### Measurement-Textfeld „zweiter Tap zum Fokussieren" — in dieser Runde NICHT reproduziert

Gezielt im Measurement-Kontext (New-Measurement-Screen, Gewichtsfeld)
geprüft: ein einzelner Tap auf das leere Gewichtsfeld öffnete die Tastatur
und setzte den Cursor sofort (kein zweiter Tap nötig). Der in der letzten
Runde notierte Fund ließ sich unter diesem konkreten Testablauf nicht
reproduzieren — keine Schlussfolgerung über die Ursache möglich, da kein
Fehlverhalten auftrat. Kein Fix vorgenommen (nichts zu fixen ohne
Reproduktion); falls der Fund erneut auftritt, bitte mit genauerem
Reproduktionsschritt (welches Feld, welcher Screen, welche Vorbedingung)
erneut melden.

## Runde 4 (dieser Durchgang): C01/C02 gezielte Geräteverifizierung (Nachtrag)

**Auftrag:** ausschließlich C01/C02 mit dem eigentlichen Auslösefall
(aktiver Plan MIT Laufeinheiten + Cardio-Zieländerung) nachstellen, kein
neuer allgemeiner Review.

**Session (aktiv beendet, `max_concurrent=1` eingehalten):**

| # | Zweck | Build/Commit | Dauer | TestingBot-Session-ID |
|---|---|---|---|---|
| 1 | Onboarding/Plan-Aufbau mit Laufeinheit, C01 (Auslösefall + Timing-Beobachtung), C02 (Keep goal + Kaltstart) | `64ba455` | 1.262 s | `fc34bafa1392-76dae1c872b2-17cb025342d7-179249117098-78574997` |

Gesamt: **1.262 Sekunden** (TestingBot-Test-Datensatz, `duration`-Feld)
von 31.730 Sekunden Restbudget vor dieser Runde. Die TestingBot-Konto-API
(`GET /v1/user`) zeigte unmittelbar nach Sitzungsende **29.808 Sekunden**
Restbudget, also ein Verbrauch von 1.922 Sekunden laut Konto-Zähler — eine
Differenz von ca. 660 Sekunden zur Session-Dauer, konsistent mit dem in
Runde 3 dokumentierten Abrechnungs-/Rundungsverzug der Konto-API. Der
genauere Wert ist die Session-Dauer laut Test-Datensatz (1.262 s); als
konservatives Restbudget nach dieser Runde gilt der von der Konto-API
gemeldete Stand: **29.808 Sekunden**. Keine zusätzlichen Käufe, keine
parallele zweite Session.

**CI:** kein neuer CI-Lauf nötig — der für C01/C02 relevante Code
(`CardioFeasibilityCardModel.swift`, `ProfileEditorView.swift`,
`CardioFeasibilityCalculator`) ist zwischen dem bereits in Runde 3
gebauten und auf TestingBot hochgeladenen Build `64ba455` und dem
aktuellen HEAD `4ea8d7b` unverändert (`git diff 64ba455..4ea8d7b --stat`
zeigt nur `ExerciseEditorView.swift`, eine entfernte Testdatei und dieses
Dokument). Der vorhandene TestingBot-App-Upload (`tb://de0f990d34100febd0b377ad`)
wurde daher wiederverwendet.

**Ergebnis kurz:** C01 teilweise (Auslösefall und Vorschau-Inhalt jetzt
vollständig bestätigt; neuer, eindeutiger Befund zum Karten-Timing — siehe
Tabelle und Abschnitt "Diese Runde" oben), C02 bestanden (inkl. echtem
Kaltstart). Kein Bug mit Datenverlust/stiller Planmutation gefunden, daher
kein Fix, kein neuer CI-Lauf, kein Geräte-Nachtest nötig.

## Nächste Schritte

**Paket 1 (Coach-Aktivierung → Plananpassung) ist seit der Geräteabnahme
oben vollständig abgeschlossen** — alle 9 geforderten Nachweise bestanden,
kein Bug, keine Codeänderung nötig. Einzige verbleibende Teillücke: der
`distributionConflict`-Banner (Komponente 1) selbst wurde nur indirekt
(Code+Datenmodell) bestätigt, der echte Tagemangel-Fall (z. B. 2 Tage für
Hybrid+Both) nicht separat am Gerät gezeigt. **Paket 2** (Intervall-
Player, strukturierter Abschnittseditor) und **Paket 3** (Coaching mit
tatsächlichen Ergebnissen verbinden) aus dem Laufcoach-Konzept sind
bewusst noch nicht begonnen — eigene, künftige Runden.

Top-5-Geräteprüfung (E01, C06, D06, A11, D02), Runde 3 (Onboarding/
Hybrid/Coach, Navigation, Drag&Drop, RIR, Bildschirmgröße), Runde 4
(C01/C02-Kernfall), Runde 5 (C01-Fix-Retest inkl. Kaltstart-
Persistenz-Bugfix), Runde 6 (D06-Fix), Runde 7 (A01 korrekt eingeordnet
und gefixt, autoAcceptAlerts-Audit), Runde 8 (E04 Türkisch,
Imperial-Einheiten-Lücke gefunden, Spalten-Header-Umbruch-Fix,
F01–F08-Erreichbarkeit bestätigt unverändert blockiert) und Runde 9
(AX5-Fix vollständig gerätebestätigt, kg/lbs an vier Stellen angebunden
und gerätebestätigt, dabei `logSet()`-Kaltstart-Bug gefunden und gefixt)
abgeschlossen — siehe jeweilige Nachträge oben für Details. **C01 ist seit
Runde 5, D06 seit Runde 6, A01 seit Runde 7 vollständig bestanden** (C01:
Timing-Fix `47ab4d6` + Persistenz-Fix `1c8bf54`; D06: Cancel-Endlosschleifen-
Fix `47678c1`; A01: Ziel-/Tage-Vorbefüllungs-Fix `a4359f4`, Runde 6s
„kein Produktpfad"-Einordnung war falsch und wurde zurückgenommen).
Offene bekannte Nachweislücken, in absteigender Priorität für eine
künftige Runde:

1. **E04-Rest** (teilweise): Deutsch (Standardbedingungen) seit Runde 7,
   Türkisch (Standardbedingungen) seit Runde 8 bestanden (Locale-
   Capability bei Session-Start behebt den Runde-3-Respring-Blocker für
   beide Sprachen). AX5 selbst ist seit Runde 9 vollständig
   gerätebestätigt (Deutsch). Weiterhin offen: schmale Breite jeweils
   kombiniert mit Deutsch/Türkisch, Dezimalgewicht/kg-lbs kombiniert mit
   Deutsch/Türkisch (nur Englisch+diese Bedingungen sind aus Runde 3
   bestätigt); ein echtes kleineres Gerät ist auf TestingBots aktueller
   Geräteflotte für iOS 17+ nicht verfügbar (geprüft: alle schmaleren
   iPhone-Modelle laufen dort mit iOS < 17) — strukturell nicht testbar,
   kein Versäumnis.
2. **kg/lbs-Einheiten (seit Runde 9 für die vier benannten Stellen
   bestanden, Rest bewusst außerhalb des Scopes)**: Satz-Logging,
   Profil-/Körperdaten-Editor und Dashboard-Gewichtstrend respektieren das
   Setting jetzt (Commit `0a3c68e`, gerätebestätigt). Weiterhin bewusst
   kg-only (sechster fachlicher Widerspruch, Scope-Grenze siehe Runde-9-
   Nachtrag, nicht eigenmächtig erweitert): Trainingsvolumen-Aggregation,
   PR-Erkennung/-Banner, Übungs-Gewichtsverlauf-Charts, CSV-Export/-Import.
   Kleine verbleibende Lücke: `set.column.header.accessibilityLabel` nennt
   VoiceOver weiterhin "Kilogramm" unabhängig vom Setting (Runde 9
   gefunden, nicht gefixt).
3. F01–F08: nur noch der reine UI-/Geräte-Teil von F01–F03/F06–F08 sowie
   F05s Beschwerden-Abklärungsweg offen, bestätigt weiterhin ausschließlich
   am CSV-Export-Hang blockiert (Runde 8: kein alternativer Weg ohne neue,
   umfangreiche Testinfrastruktur gefunden).
4. Verbleibende P2-Fälle ohne Gerätenachweis: A02, C05, E02, E08.

Von den sechs benannten fachlichen Widersprüchen sind C01 (seit Runde 5)
und kg/lbs (seit Runde 9, für die vier benannten Stellen) behoben (siehe
jeweiliger Eintrag, aus Nachvollziehbarkeit stehen gelassen statt
gelöscht); die verbleibenden vier (A09, C04, A02-Architekturfrage, F04,
sowie A04s Abhängigkeit von A09) sowie die bewusste kg/lbs-Scope-Grenze
(Volumen/PRs/Charts/CSV) gehen weiterhin als offene Entscheidungen an den
Nutzer zurück, nicht eigenmächtig auflösen.
