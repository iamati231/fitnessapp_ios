# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-20 (achter Durchgang: Runde 7 — A01 korrekt neu eingeordnet
und gefixt [doppelte Ziel-/Tage-Abfrage im eingebetteten PlanBuilder],
autoAcceptAlerts-Einfluss auf frühere Geräte-Nachweise systematisch
geprüft, siehe Nachtrag „Runde 7" unten), Branch `claude/smart-onboarding-
epic`, HEAD `a4359f4` (Fix-Commit dieser Runde: `PlanBuilderView`
preseedet jetzt auch Ziel und Tage aus den bereits gegebenen Onboarding-
Antworten; davor `47678c1` Fix-Commit Runde 6 [D06 Cancel-Endlosschleife],
davor `80eee60` reiner Dokumentations-Commit zur Speicherfehler-
Codeprüfung, davor `1c8bf54` Fix-Commit Runde 5
(`CardioGoalEditorView.save()`), davor `47ab4d6` der ursprüngliche C01-Fix,
davor `4ea8d7b` reiner Dokumentations-Commit zu Runde 3, davor `254d669`
Korrektur-Commit zu E05, davor `64ba455` Fix-Commit E04, davor `3e67cb8`
ursprünglicher — per Geräte-Nachtest widerlegter — E05-Versuch, davor
`c96bf5c`). TestingBot-Verbrauch Runde 7: siehe Nachtrag „Runde 7" unten
für Details und exakte Budget-Rekonstruktion. Kein Merge nach `main`, kein
Release.

**Gesamtstatus: A–F bearbeitet; deutliche Mehrheit bestanden, einzelne
Fälle teilweise oder (A09/C04/E08/F04) noch offen als fachliche
Implementierungslücken. C01 seit Runde 5 vollständig bestanden. D06 seit
Runde 6 vollständig bestanden (isolierter Cancel-Schritt gerätebestätigt;
dabei gefundene Dialog-Endlosschleife gefixt und gerätebestätigt). A01 seit
Runde 7 korrekt eingeordnet und gefixt (doppelte Ziel-/Tage-Abfrage beim
Wechsel vom Onboarding in den eingebetteten PlanBuilder, siehe dortiger
Nachtrag für die in Runde 6 fälschlich geführte „kein Produktpfad"-
Einordnung und ihre Rücknahme). Gesamtabnahme weiterhin offen (kein
vollständiger Abschluss aller 45 Fälle).**

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
Runde 6 behandelten D06) muss zurückgenommen oder erneut getestet werden.**
Der Grund: der gemeinsame `discardChangesConfirmation`-Modifier
(`Theme.swift`) hat "Verwerfen" immer als ERSTEN Button — genau das von
`autoAcceptAlerts` automatisch gewählte Verhalten deckt sich hier mit der
jeweils behaupteten Aktion. D06s Dialoge (`PlanEditorView`s drei
Umgebungswechsel-Dialoge: Global-Sync/Adapt/Restore) sind strukturell
anders aufgebaut (drei nicht-binäre Optionen, Cancel nicht an erster
Stelle) — deshalb dort die Maskierung, hier nicht.

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

**Restbudget nach Runde 7 (Session-Summe, genauerer Wert als die ggf. noch
nicht aufgeholte Konto-API):** 26.990 − 681 = **26.309 Sekunden** (≈ 7,3 h). Keine
zusätzliche Session wurde nur zur Budgetprüfung gestartet — die
26.990-Sekunden-Messung war die ohnehin fällige Vor-Runde-Prüfung, keine
Zusatzabfrage.

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

**Status-Verteilung (45 Fälle, nach Runde 5/C01-Fix-Retest):** 30
bestanden (A03, A05, A06, A08, A11, B01, B02, B03, B04, B05, B06, C01,
C02, C03, D01, D02, D03, D04, D05, E01, E03, E05, E06, E07, F01, F02,
F03, F06, F07, F08) · 11 teilweise (A01, A02, A04, A07, A10, C05, C06,
D06, E02, E04, F05) · 4 noch nicht geprüft (A09, C04, E08, F04) · 0
blockiert · 0 fehlgeschlagen. (Vorheriger Stand nach Runde 4: 29
bestanden/12 teilweise, siehe Git-Historie dieses Dokuments.)

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

Top-5-Geräteprüfung (E01, C06, D06, A11, D02), Runde 3 (Onboarding/
Hybrid/Coach, Navigation, Drag&Drop, RIR, Bildschirmgröße), Runde 4
(C01/C02-Kernfall), Runde 5 (C01-Fix-Retest inkl. Kaltstart-
Persistenz-Bugfix), Runde 6 (D06-Fix) und Runde 7 (A01 korrekt
eingeordnet und gefixt, autoAcceptAlerts-Audit) abgeschlossen — siehe
jeweilige Nachträge oben für Details. **C01 ist seit Runde 5, D06 seit
Runde 6, A01 seit Runde 7 vollständig bestanden** (C01: Timing-Fix
`47ab4d6` + Persistenz-Fix `1c8bf54`; D06: Cancel-Endlosschleifen-Fix
`47678c1`; A01: Ziel-/Tage-Vorbefüllungs-Fix `a4359f4`, Runde 6s
„kein Produktpfad"-Einordnung war falsch und wurde zurückgenommen).
Offene bekannte Nachweislücken, in absteigender Priorität für eine
künftige Runde:

1. **E04-Rest** (teilweise): Deltiq selbst in Deutsch (Automatisierung
   überlebte den Systemsprachwechsel in dieser Runde nicht) und in
   Türkisch (nicht versucht) bleiben ungeprüft; ein echtes kleineres
   Gerät wurde nicht zusätzlich zur Dynamic-Type-Vergrößerung getestet.
   In Runde 6 und 7 aus Zeit-/Umfangsgründen zurückgestellt, nicht erneut
   versucht.
2. F01–F08: nur noch der reine UI-/Geräte-Teil von F01–F03/F06–F08 sowie
   F05s Beschwerden-Abklärungsweg offen — kein genereller Blocker mehr.
3. Verbleibende P2-Fälle ohne Gerätenachweis: A02, C05, E02, E08.

Von den fünf ursprünglich benannten fachlichen Widersprüchen ist C01 seit
Runde 5 behoben (siehe dortiger Eintrag, aus Nachvollziehbarkeit stehen
gelassen statt gelöscht); die verbleibenden vier (A09, C04,
A02-Architekturfrage, F04, sowie A04s Abhängigkeit von A09) gehen
weiterhin als offene Entscheidungen an den Nutzer zurück, nicht
eigenmächtig auflösen.
