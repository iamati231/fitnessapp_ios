# Planung, Builder & Trainingsbegleitung — Audit (Phase 0)

Bezieht sich auf die vier Spezifikationen `00_START_HIER.md` / `01_PLANUNG_BUILDER_UND_FIXES.md` /
`02_ONBOARDING_HYBRID_LAUFCOACH.md` / `03_TRAININGSBEGLEITUNG_PLAN_CHECKS.md` (User-Upload, nicht im
Repo). Branch `claude/smart-onboarding-epic`, HEAD `5e9e3e7`, sauberer Arbeitsbaum, kein `CLAUDE.md`
im Repo. Reine Bestandsaufnahme — sechs parallele Code-Audits, alle Aussagen datei-/zeilenbelegt.

## 1. Planung/Builder/Generator

- `PlanBuilderView` (3 Schritte: types/equipment/result) ist ein generischer Trainingsart-Wizard,
  **kein zielorientierter Einstieg** — weder `TrainingGoal` noch `targetEnvironment` kommen dort vor.
- `PlanGeneratorInput` hat kein Ziel-Feld. „Flexible Reihenfolge vs. feste Wochentage" ist bereits
  vollständig unterstützt (`usesFixedWeekdays`/`fixedWeekdays`).
- **Kein Draft-Zustand**: `ProgramInstantiator.instantiate`/`PlanGeneratorInstantiator.build` inserten
  sofort in den `ModelContext`. Der einzige Zwischenstand ist das `PlanGenerator.Result`-Struct im
  `@State` der View vor dem Tap auf „Übernehmen".
- **Keine Wochenübersicht/Fixierung**: `PlanEditorView.daysSection` ist eine normale, reorderbare
  `List` ohne Grid/Fixierungs-Markierung. `DaySpec`/`TrainingDay` kennen kein „fixiert"-Flag.
- „Neu rechnen" mischt über `shuffle: true` den **gesamten** Kandidaten-Pool neu — keine gezielte
  Einzel-Alternative.
- **Vier uneinheitliche Commit-Pfade** statt eines gemeinsamen: `OnboardingView.finishOnboarding`,
  `CardioFeasibilityCardModel.accept`/`.acceptCustom` (2 Call-Sites), `PlanBuilderView.adoptPlan()`.
- **Bug/Lücke, nicht nur Stil**: `PlanGeneratorInstantiator.makeTemplate` setzt `targetEnvironment:
  .gym` **hardcodiert**, unabhängig von der Equipment-Auswahl in Schritt 2 — Builder-Pläne umgehen
  damit komplett die `EquipmentVariant`/`ResolvedPlanSelection`-Logik, die der Template-Pfad nutzt.
- `TrainingGoal` hat 5 Fälle (`hypertrophy/strength/hybrid/weightLoss/functional`) — deckt die vier
  geforderten Zielkarten nicht 1:1 ab (siehe Konflikt 1).
- `PlanEnvironmentMigrator` arbeitet nur auf bereits persistierten Objekten — für einen Builder-Schritt
  vor dem Insert nicht direkt nutzbar.

## 2. Profil/Equipment

- Feingranulares Modell ist **vollständig und sauber** für die Plan-Erstellung: `EquipmentItem`/
  `EquipmentAvailability`/`UserEquipmentProfile` (3-Zustand inkl. `equipmentUnknownItemsRaw`),
  `ExerciseRequirement`/`RequirementStatus` (dreiwertige Kleene-Logik), `EquipmentVariant`,
  `PlanEquipmentChecker`, `ExerciseSubstitutionEngine`/`PlanAdaptationValidator`,
  `ReviewedSubstitutionRule`, `ResolvedPlanSelection`/`PlanSelectionResolver`.
- **Kritische Lücke**: Equipment-Änderung in `ProfileEditorView`/`TrainingLocationEquipmentEditorView`
  hat **keinerlei Wirkung auf bestehende Pläne** — es gibt `.onChange(of: profile.environment)`, aber
  kein Äquivalent für `profile.equipmentProfile`. Kein „Änderung → Auswirkung → Vorschau → Übernahme"-
  Ablauf existiert für Equipment (nur für Environment, binär, altes grobes Modell).
  `docs/PLAN_EQUIPMENT_MATCHING_AUDIT.md:887–890` dokumentiert diesen Scope-Cut bereits explizit.
- **Zwei parallele, unverbundene Kompatibilitätssysteme**: (a) altes grobes `Equipment`/
  `EnvironmentType` + `PlanEnvironmentMigrator` (wirkt auf echte Pläne, reaktiv) vs. (b) neues
  `UserEquipmentProfile`-System (präzise, nur bei Plan-Erstellung). Siehe Konflikt 2.
- `equipmentPreferences` ist trotz des Namens **kein weiches Gewichtungskriterium**, sondern ein
  Hart-Filter/Legacy-Duplikat der Verfügbarkeit. Scoring in `PlanMatchmaker` hat keinen
  Equipment-Gewichtungsterm.
- Unknown-Persistenz über Export/Import/Neustart ist verifiziert korrekt (V5, bestätigt).

## 3. Progression/Deload/Comeback/Cardio-Coaching

- `ProgressionEvaluator`/`ProgressionApplicator`, `DeloadAdvisor`/`DeloadManager`,
  `ComebackAdvisor`/`AbsenceDeload` sind **solide, fertige, bewusst getrennte Mechaniken**
  (Overreaching-Deload hat Vorrang vor Absenz-Reduktion). Kein Neubau nötig, nur Wiederverwendung.
- `CardioCoachingAdvisor` hat 3 reine Wochen-Trigger; `isJunkMiles` hat aktuell **keinen Aufrufer**.
- **Kein periodischer Review/Block-Check existiert irgendwo** (exhaustiv gegrept). `CoachingContext.
  plateauDetected` hat fertige Lokalisierung, aber **keinen Emitter** — toter Code.
- **Blockierender struktureller Fund**: `TrainingPlan` hat **kein Datumsfeld** (kein `createdAt`/
  `activatedAt`). Ohne das ist „seit wann läuft dieser Plan" nicht berechenbar — das ist die
  Grundvoraussetzung für den 4-Wochen- und 6–8-Wochen-Rhythmus aus Dokument 03 und muss vor P7/P8
  gelöst werden (gehört sachlich zu P6).
- Keiner der vier Aggregatoren (`TrainingCalendarAggregator`, `SessionAggregation`, `WorkoutAnalytics`,
  `VolumeOverTimeAggregator`) vergleicht geplante gegen absolvierte Einheiten — `PlanNavigator` rotiert
  rein sequenziell, nicht kalenderbasiert. `weeklyWorkoutGoal` ist eine freie Zahl ohne Tagesstruktur.
- Keine Historie der Progression-Outcomes (`.hold` wird nirgends gesammelt) — ein Block-Review „wie
  lief die Progression" ist aus Bestandsdaten nicht rekonstruierbar, ohne künftig mitzuschreiben.
- Zeitbudget-Feedback existiert nicht; `SessionFeeling` deckt nur Belastung ab.

## 4. RIR-Layout/Warmup/Cooldown

- Der frühere Fix (130f2e8) war eine **Kompression** (Text kürzen, Badge verkleinern) — die neue
  Vorgabe verlangt ausdrücklich eine **Spalten-Struktur mit Header**, keine weitere Kompression.
- `SetRow.compactSetRow`: „KG"/„WDH" werden pro Zeile gerendert, kein Header existiert.
  `rirCapsule` hat ein geschätztes `minWidth: 32`, **keine** Messung am längsten gültigen Wert
  („X,Y", 3 Zeichen + „R"-Präfix = 4). Kein `ViewThatFits`/`GeometryReader`/`dynamicTypeSize`-Handling
  in der ganzen Datei.
- **RIR-Reglerposition ist nicht stabil**: Öffnen des Sliders lässt die Capsule vom rechten Zeilenrand
  auf eine neue Zeile darunter springen (Inline-Akkordeon-Neuplatzierung, nicht Overlay/Popover) —
  verletzt die Vorgabe „Position beim Öffnen stabil".
- Plate-Calculator-Badge **überlappt** die Gewichtseingabe (`.overlay(.topTrailing)` auf `weightInput`)
  — verletzt „erreichbar, aber keine Überdeckung".
- `Float.formattedRIR` (lokalisierte Komma-Formatierung) ist bereits korrekt und wiederverwendbar.
- **Cooldown**: Infrastruktur ist **vollständig verdrahtet** (`ExerciseRole.cooldown`, Persistenz,
  „COOL-DOWN"-Pille, graue Checkmark-Farbe, Ausschluss aus Dauer/Progression/Deload/Substitution,
  Enum-Test, CSV-Roundtrip, Settings-Text) — aber **0 Templates** nutzen `role: .cooldown` und
  **kein Editor-UI** kann eine Übung je manuell so markieren. Reine Erweiterung nötig, kein Neubau:
  Template-Inhalt + Rollen-Picker in `ExerciseEditorView`. Eine Cooldown-Rampe (Pendant zu
  `WarmupRampCalculator`) existiert nicht, ist laut Auftrag auch nicht verlangt.

## 5. Onboarding/ExperienceTrack/Hybrid/Start-Check

- Onboarding-Schrittablauf ist **strikt linear** (`Step.rawValue ± 1`), keine zielabhängige
  Verzweigung. Hybrid-Auswahl löst **nichts** aus — geht direkt zum generischen nächsten Schritt.
- **„Ausdauerform" (Laufen/Radfahren) existiert nirgends** — komplett neu zu bauen, kein Umbau.
- `cardioCoachingEnabled` wird im Onboarding **an keiner Stelle berührt** (bleibt beim Klassen-Default
  `false`). Der in Dokument 02 befürchtete „Hybrid schaltet Coach automatisch an"-Bug existiert in
  dieser Form nicht — weil die Verdrahtung schlicht komplett fehlt. P4 ist also „neu bauen", nicht
  „falsche Kopplung lösen".
- Einziger bestehender Präzedenzfall eines „Hybrid schaltet Cardio-Frage frei": `BaselineCheckFlow
  View.showsCardioStep` (optionale Selbsteinschätzung, nicht an `cardioCoachingEnabled`/`CardioGoal`
  gekoppelt) — bei Neuimplementierung zu berücksichtigen, ob dieser Schalter mitwandert.
- `CardioGoal` ist reine Lauf-Distanzen (keine Rad-Dimension) — siehe Konflikt 1.
- Deaktivieren des (aktuell nur im Profil-Editor existierenden) Coach-Toggles löscht nichts, blendet
  nur aus — unverändert als Produktentscheidung zu bestätigen, keine Lösch-Logik vorhanden.
- **Start-Check-Isolation verifiziert korrekt**: genau ein lebendiger Einstieg, vollständig im
  Onboarding (V6-Fix hält, keine Reste in ProfileEditorView/Dashboard/Settings).
- Kein späterer kurzer Alltags-/Belastungs-Rückblick (Dokument 03 §4) existiert — komplett neu.

## 6. Plan-Versionierung/Session-Historie/Export-Import

- **Keine Versionierung/Snapshot für Pläne existiert** (exhaustiv gegrept — nur CSV-`formatVersion`,
  Baseline-Fragebogen-Version und Substitutions-Regel-Version, nichts davon planbezogen).
- `WorkoutSession.day: TrainingDay?` ist eine **direkte, lebende Objektreferenz** — keine lose
  Namens-/Datumsbindung. Wird ein `TrainingDay` später strukturell geändert (Übungen getauscht/
  umsortiert), liefert jeder Code, der `session.day.exercises` liest, den **aktuellen**, nicht den
  historischen Stand (breite Nutzung bestätigt in `ActiveWorkoutView`/`CircuitWorkoutPlayerView`/
  `TimedWorkoutPlayerView`/`WorkoutSummaryView`).
- Konkret bestätigte, **bewusste** Drift-Stellen: `ExerciseLog.cnsFatigueScore`/
  `localMuscleDamageScore` lesen live `exercise.cnsDemandFactor`; `resolvedCardioEquipment` ist laut
  eigenem Kommentar bewusst „live-first". Siehe Konflikt 3.
- Export/Import-Muster ist nachweislich additiv-sicher (`equipment_unknown_items` als Vorbild) — ein
  neues `plan_version`/`valid_from`/`valid_to`-Feld würde ohne Format-Version-Bump funktionieren.
- **Cross-Check der 4 bereits gemeldeten P1-Bugs — alle im aktuellen Code bestätigt:**
  Reorder-Discard (`PlanEditorView`/`DayEditorView`), Equipment-Unknown-Persistenz
  (`equipmentUnknownItemsRaw`), Messung-Speichern (`MeasurementView.save(profile:)`), Swipe-Back
  (`Theme.swift` `SwipeBackHostController.viewWillAppear`).

## Bereits erledigt vs. noch offen (Dokument 01 §„aktuelle Fehler")

| Bug | Status |
|---|---|
| Messung per Haken speichern | **erledigt** (V4, verifiziert) |
| Bank/Klimmzugstange „Weiß ich nicht" | **erledigt** (V5, verifiziert) |
| Discard (Reorder/Rebaseline/Reaktivierung) | **erledigt** (V1–V3 + Finding 2/3, verifiziert) |
| Navigation (Swipe-Back mehrstufig) | **erledigt** (V7, verifiziert) |
| RIR | **offen** — struktureller Umbau nötig, bisheriger Fix war nur Kompression |

Vier von fünf gemeldeten P1-Punkten sind bereits erledigt und unabhängig verifiziert. Nur RIR braucht
noch echte Arbeit.

## Fachliche Konflikte mit Lösungsvorschlag

**1. `TrainingGoal` deckt die vier Zielkarten nicht ab. — ENTSCHIEDEN.**
„Kraft & Muskelaufbau" verteilt sich auf `.hypertrophy`+`.strength`; „Laufen & Ausdauer" hat keine
Entsprechung; „Allgemeine Fitness" ist nicht eindeutig `.functional` oder `.weightLoss`. `TrainingGoal
Raw` ist persistiert mit Stabilitätszwang (nur anhängen, nie umbenennen). **User-Entscheidung**: neuer
Fall `.endurance` wird rein angehängt (keine Migration bestehender Profile). Zielkarten-Mapping:
„Kraft & Muskelaufbau" wählt intern zwischen `.hypertrophy`/`.strength` (Default `.hypertrophy`),
„Laufen & Ausdauer" → `.endurance` (neu), „Kraft & Ausdauer kombinieren" → `.hybrid` (unverändert),
„Allgemeine Fitness" → `.functional`. Gilt für P2.2/P3.1.

**2. Zwei parallele Equipment-Kompatibilitätssysteme.**
Altes grobes System (`PlanEnvironmentMigrator`, wirkt auf Bestandspläne) vs. neues präzises System
(`UserEquipmentProfile`/`PlanEquipmentChecker`, nur bei Neuerstellung). **Vorschlag**: die neue
Equipment-Impact-Analyse (P5) auf dem präzisen Modell aufbauen; `PlanEnvironmentMigrator` bleibt als
schmaler Sonderfall für reine Orts-/Umgebungswechsel bestehen (dafür weiterhin ausreichend), wird aber
NICHT auf Einzelgeräte-Änderungen erweitert. Technische Entscheidung, keine Nutzer-Taxonomie — wird so
umgesetzt, sofern kein Widerspruch kommt.

**3. „Keine nachträgliche Umdeutung alter Sessions" vs. bestehendes bewusstes Live-Verhalten.**
`ExerciseLog.resolvedCardioEquipment`/`cnsFatigueScore` lesen absichtlich live vom `Exercise`, damit
eine Korrektur rückwirkend PR-/Recovery-Auswertungen aktualisiert — das ist created-by-design
rückwirkende Umdeutung, nur in sehr engem Rahmen (Datenkorrektur eines Tags/Faktors, keine
Planinhalts-Änderung). **Vorschlag**: diesen enge, bestehende Ausnahme unverändert lassen (Korrektur
einzelner Attribute ≠ Planänderung), aber für die NEUE Versionierung (P6) explizit `TrainingDay`-
Inhalt (welche Übungen/Reihenfolge an diesem Tag) einfrieren — nur der Inhalts-Snapshot wird
versioniert, nicht jedes Einzelattribut. Wird so umgesetzt, sofern kein Widerspruch kommt.

**4. Generator-Pläne mit hardcodiertem `targetEnvironment: .gym`.**
Kein Konflikt, sondern ein Bug — wird als eigenständiger, in sich geschlossener Fix an den Anfang von
P2 gezogen (Voraussetzung dafür, dass der neue Builder überhaupt equipment-korrekte Pläne erzeugt).

## Phasenplan — kleine Aufgaben mit Abnahmekriterien

**P1 — Rest-Bugfix (nur RIR offen)**
- P1.1 Header-Zeile (Satz/kg/Wdh/RIR) einmalig in `ExerciseCard`, Pro-Zeile-Labels aus `SetRow`
  entfernen. *Abnahme: Label erscheint einmal pro Übung, nicht pro Satz.*
- P1.2 `rirCapsule` entkompaktieren, Breite am längsten gültigen Wert bemessen, kein Abschneiden bei
  keinem gültigen Wert 0–5 in 0,5-Schritten. *Abnahme: E03.*
- P1.3 Reglerposition beim Öffnen stabil (Overlay/Popover statt Zeilen-Neuplatzierung).
  *Abnahme: D-analog, kein Zeilensprung beim Tap.*
- P1.4 Plate-Button in eigene schmale Spalte, keine Überlappung mit Zahlen/Touch-Flächen.
- P1.5 Schmale-Display-/Großschrift-Fallback (zweizeilig). *Abnahme: E04.*
- P1.6 Tests + Linux-Build, Geräteprüfung dokumentiert als offen (kein Simulator-Zugriff).

**P2 — Gemeinsamer Planungskontext**
- P2.1 Bugfix: `targetEnvironment` aus tatsächlicher Equipment-Auswahl ableiten statt hardcoden.
- P2.2 `TrainingGoal`-Erweiterung gemäß Konfliktlösung 1 (nach Rückfrage).
- P2.3 Gemeinsamer Adopt-Pfad (`PlanAdoptionService` o.ä.) statt 4 getrennter Commit-Implementierungen.
- P2.4 Fixierungs-Flag im Builder-Draft-State (reines UI-/Draft-Feld, nicht persistiert vor Übernahme).
- *Abnahme: A02, B06.*

**P3 — Zielorientierter Builder + Wocheneditor** (braucht P2)
- P3.1 Ziel-Schritt in `PlanBuilderView`. P3.2 Wochenübersicht-UI. P3.3 Drag&Drop + „Verschieben
  nach…". P3.4 Fixierung Inhalt/Position getrennt. P3.5 Gezielte Alternativen statt globalem Shuffle.
- *Abnahme: B01–B06.*

**P4 — Onboarding Hybrid/Laufcoach** (braucht P2, P3)
- P4.1 Ausdauerform-Frage (neu). P4.2 Laufcoach-Entscheidung (neu). P4.3 `cardioCoachingEnabled`
  erstmals im Onboarding verdrahten. P4.4 Zustandstabelle Dok02 §3 vollständig umsetzen.
- *Abnahme: A03–A09.*

**P5 — Profiländerung → Plananpassung** (braucht P2, P3)
- P5.1 Equipment-Change-Trigger (`.onChange` analog Environment). P5.2 Impact-Analyse auf dem
  präzisen Modell (Konfliktlösung 2). P5.3 3-Wege-Entscheidung (anpassen/neu/behalten), wiederverwendet
  für Cardio UND Equipment.
- *Abnahme: C01–C06.*

**P6 — Plan-Versionierung & Datenqualität** (braucht P0, P2)
- P6.1 `TrainingPlan.activatedAt`/`createdAt` (additive Migration). P6.2 Inhalts-Snapshot pro
  `TrainingDay`-Fassung (Konfliktlösung 3). P6.3 Additive CSV-Erweiterung.
- *Blockiert P7/P8 — ohne Zeitanker keine Kalenderfrist berechenbar.*

**P7 — Erster Vier-Wochen-Rückblick** (braucht P6)
- Dünne Orchestrator-Schicht über bestehende Advisors + neuer Soll-Ist-Vergleich (geplante vs.
  absolvierte Einheiten). Kein neues Fachwissen, nur Bündelung. *Abnahme: F01–F03, F06–F08.*

**P8 — Block-Reviews + gezielte Vorschläge** (braucht P3, P5, P7)
- `plateauDetected`-Emitter aktivieren, Progression-Outcome-Historie persistieren, Schwerpunktwechsel-
  Regeln aus Dok03 §6. *Abnahme: F04–F05.*

**P9 — Verifikation, Regression, Doku** — laufend + Abschluss je Paket nach Dokument 04.

## Nächste Aufgabe

P1 (RIR-Redesign) — einziger offener Punkt aus dem Fehler-Paket, in sich geschlossen, ohne
Abhängigkeit zu den Konfliktfragen. Wird als nächstes umgesetzt.
