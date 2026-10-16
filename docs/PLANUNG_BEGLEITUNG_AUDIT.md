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

## 2. Profil/Equipment — getrennt nach Ausführbarkeit und Präferenz

Equipment hat im Code zwei fachlich und technisch **unterschiedliche** Dimensionen, die bisher
zusammen referiert wurden. Hier getrennt mit je eigenem Datenfluss und eigener Lücke.

### 2a. Verfügbarkeit (Ausführbarkeit) — „kann diese Übung überhaupt ausgeführt werden?"

**Bestehender Datenfluss (vollständig, nur bei Plan-ERSTELLUNG verdrahtet):**
`UserBodyProfile.equipmentProfile` (3-Zustand `available`/`unavailable`/`unknown` pro `EquipmentItem`,
`EquipmentRequirement.swift:77–147`) → `ExerciseRequirement.evaluate(against:)` (dreiwertige
Kleene-Logik, `EquipmentRequirement.swift:204–279`) → `PlanEquipmentChecker.check`/`fullReport`
(aggregiert pro Tag/Plan, `PlanEquipmentCheck.swift:140–178`) → `ProgramTemplate.
bestEquipmentCheckedVariant` wählt die beste `EquipmentVariant` (`PlanEquipmentCheck.swift:229–240`)
→ `ExerciseSubstitutionEngine.adapt` ersetzt NUR bestätigt fehlendes Equipment über freigegebene
`ReviewedSubstitutionRule`s (`ExerciseSubstitutionEngine.swift:95–174`) → `PlanSelectionResolver.
resolve`/`ResolvedPlanSelection` bündelt das Ergebnis (`ResolvedPlanSelection.swift:67–130`).
Dreiwertige Semantik ("unbekannt" ≠ "bestätigt leer") ist dabei korrekt durchgehalten.

**Fehlende Anbindung an gespeicherte Pläne (verifiziert, nicht nur vermutet):** Dieser gesamte Pfad
läuft ausschließlich auf Core-`DaySpec`/`ExerciseSpec` (Template-Ebene) und wird nur von
`ProgramTemplatePickerView.swift:141–177,331–336` und `OnboardingView.swift:1900–1910` aufgerufen —
beides reine Vorschau-/Neuerstellungs-Pfade. Gegen einen bereits persistierten `TrainingPlan`/
`TrainingDay` (SwiftData) läuft er nie. Konkreter Beleg: `grep -rn "onChange(of: profile\." Sources/
FitnessAppUI` liefert **genau einen** Treffer im gesamten Modul —
`ProfileEditorView.swift:190` für `profile.environment`. Für `profile.equipmentProfile` existiert
keinerlei Reaktion. Ändert ein Nutzer z. B. die Bank von „vorhanden" auf „nicht vorhanden", bleibt
jeder bestehende Plan unverändert und ungeprüft, bis er manuell einen neuen Plan baut.

### 2b. Präferenz (Gewichtung) — „welches von mehreren vorhandenen Geräten wird bevorzugt?"

**Bestehender Datenfluss:** `UserBodyProfile.equipmentPreferences` (`Set<Equipment>`, das ALTE grobe
Enum, nicht `EquipmentItem`) wird ausschließlich als **Projektion** geschrieben — nie eigenständig
editiert — in `confirmEquipmentProfileComplete()`/`setEquipmentAvailability()`
(`UserBodyProfile.swift:432–438,459–475`), abgeleitet aus `equipmentProfile.legacyEquipmentPreferences`.
Genutzt wird es an zwei Stellen, **beide als Hart-Filter, nie als Gewichtung**:
(1) `PlanMatchmaker.equipmentMatches` (`PlanMatchmaker.swift:279–290`) — im Legacy-Pfad ohne
`UserEquipmentProfile` ein K.-o.-Teilmengen-Check, der Templates komplett ausschließt;
(2) `EquipmentVariant.bestMatch`/`priority` (`EquipmentVariant.swift:35–42,64–71`) — eine **fixe,
vom Entwickler festgelegte** Rangfolge (`barbellGym`=40 > `dumbbellOnly`=30 > `kettlebellOnly`=20 >
`machineGym`=10), nicht vom Nutzer einstellbar. `PlanMatchmaker.rankPlansDetailed`
(`PlanMatchmaker.swift:128–160`) hat **keinen** Equipment-Gewichtungsterm im Scoring.

**Fazit:** Eine echte Nutzer-Präferenz ("habe beides, bevorzuge Kurzhantel") existiert heute **nicht**.
`equipmentPreferences` ist trotz des Namens ein zweiter, veralteter Verfügbarkeits-Spiegel.

**Fehlende Anbindung an gespeicherte Pläne:** identisch zu 2a — auch dieser Pfad läuft nur bei
Template-Erstellung (`EquipmentVariant.bestMatch` wird von `ProgramInstantiator`/
`PlanGeneratorInstantiator` zum Insert-Zeitpunkt aufgerufen, nie danach erneut).

### Gemeinsame Punkte

- **Zwei parallele, unverbundene Kompatibilitätssysteme**: (a) altes grobes `Equipment`/
  `EnvironmentType` + `PlanEnvironmentMigrator` (wirkt auf echte Pläne, reaktiv, aber grob) vs.
  (b) neues `UserEquipmentProfile`-System aus 2a/2b (präzise, nur bei Plan-Erstellung). Siehe Konflikt 2.
- Unknown-Persistenz über Export/Import/Neustart ist verifiziert korrekt (V5, bestätigt).
- P5 (Profiländerung → bestätigte Plananpassung) muss **beide** Dimensionen bedienen: 2a als
  Ausführbarkeits-Prüfung (Übung ersetzen/warnen), 2b nur als zukünftig zu bauende, bisher nicht
  existierende weiche Gewichtung — nicht verwechseln, da unterschiedliche UI-Konsequenz
  (Pflicht-Hinweis vs. optionale Neugewichtung, siehe Dokument 01 §6-Tabelle).

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

**Präzisierung**: „Ausdauerform existiert nirgends" war zu pauschal. Der bestehende Plan-Builder
KENNT Laufen/Radfahren bereits als Generator-Bausteine — nur Onboarding, Profilmodell und der (noch
nicht existierende) gemeinsame Planungskontext haben keine Entsprechung. Aufgeschlüsselt:

| Ebene | Ist-Stand |
|---|---|
| **Generator (Core)** | `TrainingTypeKind.running`/`.cycling` existiert vollständig (`PlanGeneratorInput.swift:9–19`, `isCardio`-Flag Zeile 17–19). `PlanGenerator.cardioCandidates(for:)` (`PlanGenerator.swift:500–569`) erzeugt daraus echte Lauf-/Rad-Tage mit eigenen Titeln ("Laufen"/"Radfahren", Zeile 347–348). `PlanGeneratorInput.selections` ist ein Array — Laufen UND Radfahren können **schon heute gleichzeitig** mit je eigenen `daysPerWeek`/`sessionDurationMinutes` gewählt werden (Grundlage für Dok02-Zustand "Laufen/Radfahren kombiniert"). **Reusable.** |
| **Builder-UI** | `PlanBuilderView`s Schritt 1 bietet `TrainingTypeKind` als eine von 6 gleichrangigen Mehrfachauswahl-Optionen (`barbell/dumbbell/kettlebell/bodyweight/running/cycling`) — funktional vorhanden, aber **nicht** die vom Auftrag verlangte dedizierte, zielabhängige Ausdauerform-Frage mit Laufcoach-Folgefrage. Kein Bezug zu `TrainingGoal`, keine Coaching-Verzweigung. |
| **Onboarding** | `OnboardingView` bindet `PlanBuilderView` optional für den "eigenen Plan"-Pfad ein (`OnboardingView.swift:326–332`) — d. h. die generische Builder-Auswahl ist über diesen Umweg theoretisch erreichbar, aber es gibt **keine** eigene, immer gezeigte Ausdauerform-Frage, **keine** Laufcoach-Entscheidung, **keine** zielabhängige Verzweigung nach Hybrid. `cardioCoachingEnabled` wird im gesamten Onboarding-Code **an keiner Stelle gesetzt** (bleibt Default `false`). **Komplett neu zu bauen**, nicht umzubauen — der in Dokument 02 befürchtete „Hybrid schaltet Coach automatisch an"-Bug existiert nicht, weil die Verdrahtung schlicht fehlt. |
| **Profilmodell** | `UserBodyProfile` hat kein persistiertes Feld für eine dauerhafte "bevorzugte Ausdauerform" (Laufen/Radfahren/beides) — `TrainingTypeKind`-Auswahl im Builder ist reiner `@State`, nie in `UserBodyProfile` geschrieben. **Neues Feld nötig**, additiv (Pattern wie `equipmentUnknownItemsRaw`). |
| **Gemeinsamer Planungskontext (P2)** | Existiert noch nicht — soll beim Bau direkt auf `TrainingTypeKind`/`PlanGeneratorInput.selections` aufsetzen statt neue Cardio-Typen zu erfinden. |

### Explizite Abgrenzung: kein Radcoach in diesem Auftrag

- Laufen UND Radfahren werden als **Planbestandteile** unterstützt (siehe Tabelle — Generator kann das
  bereits). Das ist unabhängig von jeder Coaching-Funktion.
- Der **Laufcoach** (`cardioCoachingEnabled`/`CardioGoal`/`CardioFeasibilityCardModel`) bleibt
  **ausdrücklich optional und strukturell getrennt** von „Laufeinheiten im Plan" — dieser Schalter
  betrifft NUR Zielverfolgung/Pace/Volumen-Empfehlungen für Laufen, nie Radfahren.
  `CardioGoal` (`CardioProfile.swift:8–14`) ist und bleibt reine Lauf-Distanz (`fiveK`/`tenK`/
  `halfMarathon`/`marathon`/`generalFitness`) — **wird in diesem Auftrag nicht auf Radfahren
  erweitert**, kein neues Rad-Pendant wird gebaut. Bei „Hybrid nur mit Radfahren" entfällt die
  Laufcoach-Frage komplett (Dok02 §3-Tabelle), nicht nur die Vorbefüllung.
- Einziger bestehender Präzedenzfall eines „Hybrid schaltet Cardio-Frage frei":
  `BaselineCheckFlowView.showsCardioStep` (optionale Selbsteinschätzung, nicht an
  `cardioCoachingEnabled`/`CardioGoal` gekoppelt) — bleibt unverändert, kein Umbau in diesem Auftrag.

### Start-Check — unveränderliche Grenze

- **Start-Check-Isolation verifiziert korrekt**: genau ein lebendiger Einstieg
  (`OnboardingView.swift:337–347`), vollständig im Onboarding (V6-Fix hält, keine Reste in
  ProfileEditorView/Dashboard/Settings — alle drei gezielt gegengeprüft).
  **Muss in jeder P1–P6-Aufgabe erhalten bleiben.**
- Der in Dokument 03 §4 geforderte spätere, kurze Alltags-/Belastungs-Rückblick existiert nicht und
  ist komplett neu zu bauen — **ausdrücklich NICHT** als zweiter Start-Check, als Erweiterung von
  `BaselineCheckFlowView` oder mit Leistungstest-Fragen. Eigene, schlanke UI mit den 5 Fragen aus
  Dok03 §4 (Häufigkeit/Dauer/Belastung/Beschwerden/Ziel-noch-aktuell), jede überspringbar.

Deaktivieren des (aktuell nur im Profil-Editor existierenden) Coach-Toggles löscht nichts, blendet nur
aus — unverändert als Produktentscheidung zu bestätigen, keine Lösch-Logik vorhanden.

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

## Phasenplan — sechs Schritte in Abhängigkeitsreihenfolge

Reihenfolge wie vorgegeben: Fehler absichern → gemeinsamer Planungskontext → Builder+Onboarding daran
anbinden → Profiländerung↔Plananpassung → Versionierung/Datenqualität → erst dann Rückblicke.
**Start-Check-Isolation (ein Einstieg, nur Onboarding) ist in JEDER Phase eine unveränderliche
Nebenbedingung, keine eigene Aufgabe.**

Testplattform-Hinweis gilt durchgehend: Dateien unter `#if canImport(SwiftUI)`/`canImport(SwiftData)`
kompilieren auf Linux zu leeren Einheiten (verifiziert, s. frühere Audits). „Linux" unten heißt echte
Verifikation; „Apple-CI" heißt nur Kompilierbarkeit (kein Testlauf-Beweis für UI-Verhalten); „Gerät"
heißt Simulator/Hardware, aus dieser Session nicht durchführbar.

### P1 — Bestehende Fehler und Regressionen absichern

**P1.1 Vier bereits behobene Bugs als Regressionsschutz fixieren**
Komponenten: `PlanEditorView.swift`, `DayEditorView.swift`, `UserBodyProfile.swift`,
`MeasurementView.swift`, `Theme.swift`. Abhängigkeiten: keine. Abnahme: D01–D05, C05, E01, E05 bleiben
grün bei jedem folgenden Merge. Datenmodell: keine Änderung. Testplattform: Apple-CI/Gerät (Tests in
`EditorDiscardSnapshotTests.swift` sind SwiftUI/SwiftData-gegated, auf Linux nicht kompiliert).

**P1.2 RIR strukturelle Spalten-Neugestaltung**
Komponenten: `SetRow.swift` (`compactSetRow`, `rirCapsule`, `weightInput`, `rirSliderRow`),
`ExerciseCard.swift` (neue Header-Zeile), `Localizable.xcstrings` (neue Keys für Spaltenlabels).
Abhängigkeiten: keine, in sich geschlossen. Abnahme: E03 (alle RIR-Werte 0–5 in 0,5-Schritten
vollständig sichtbar), E04 (schmaler Bildschirm/große Schrift ohne Abschneiden/Überdeckung),
Reglerposition bleibt beim Öffnen stabil, Plate-Button überdeckt keine Zahlen/Touch-Flächen.
Datenmodell: keine. Testplattform: Apple-CI baut den Code; visuelle Korrektheit NUR auf
Gerät/Simulator (iPhone SE + größte Dynamic-Type-Stufe) prüfbar — aus dieser Session nicht
durchführbar, bleibt offen zu melden.

### P2 — Gemeinsamen Planungskontext und Wochenentwurf herstellen

**P2.0 Datenvertrag für Planungskontext und Wochenentwurf (eigener Task, vor P2.1–P2.4)**
Komponenten: neue reine Werttypen in FitnessAppCore (kein `ModelContext`-Bezug). Skizze:

```swift
public struct PlanningContext {
    public var goal: TrainingGoal
    public var enduranceModality: EnduranceModality?   // nil wenn goal nicht ausdauerrelevant
    public var runCoachEnabled: Bool                    // nur gueltig bei .running/.both, siehe Invariante
    public var daysPerWeek: Int
    public var sessionDurationMinutes: Int
    public var scheduling: SchedulingMode               // .fixedWeekdays([Int]) | .flexibleOrder
    public var environment: EnvironmentType
    public var equipmentProfile: UserEquipmentProfile
}
public enum PlanningMode { case onboarding, standaloneBuilder(editing: TrainingPlan?) }
public struct PlanDraft {
    public var days: [DraftDay]              // wertbasiert, KEIN TrainingDay/ModelContext
    public var fixedDayIDs: Set<DraftDay.ID> // Inhalt fixiert
    public var fixedPositionIndices: Set<Int> // Position fixiert
}
```
Abhängigkeiten: keine. Abnahme (Validierungsregeln, je als Test): `runCoachEnabled == true` ist
**ungültig**, wenn `enduranceModality` nicht `.running`/`.both` ist (harte Invariante, direkte
Umsetzung der Dok02-Zustandstabelle — verhindert exakt den eingangs befürchteten, aktuell nicht
existierenden Auto-Kopplungs-Fehler strukturell statt per Konvention); `scheduling ==
.fixedWeekdays(x)` erfordert `x.count == daysPerWeek`; `environment == .gym` mit leerem
`equipmentProfile` ohne `confirmEquipmentProfileComplete` löst die bestehende Gym-Annahme aus, nie
stille Lücke. `PlanDraft` ist bewusst NICHT `TrainingDay` — siehe P3.2. Datenmodell: keine
SwiftData-Änderung, reine Core-Werttypen. Testplattform: **Linux-testbar** (kein SwiftUI/SwiftData-
Bezug) — dies ist der erste Core-Baustein von P2 und sollte vor jeder UI-Arbeit stehen.

**P2.1 `targetEnvironment`-Hardcode-Bug beheben**
Komponenten: `PlanGeneratorInstantiator.swift` (`makeTemplate`). Abhängigkeiten: keine. Abnahme: ein
über den Builder mit Home-Gym-Equipment erzeugter Plan bekommt ein zur Equipment-Auswahl passendes
`targetEnvironment`, `EquipmentVariant`/`ResolvedPlanSelection` greifen auch für Builder-Pläne.
Datenmodell: keine. Testplattform: Datei liegt in FitnessAppData (SwiftData-gegated) → Apple-CI/Gerät;
reiner Auswahl-Algorithmus ließe sich als Core-Funktion extrahieren und wäre dann Linux-testbar
(Empfehlung bei Umsetzung).

**P2.2 `TrainingGoal.endurance` anhängen (entschiedenes Mapping)**
Komponenten: `CoachingTypes.swift`. Abhängigkeiten: keine. Abnahme: neuer Fall kompiliert, bestehende
RawValues/Profile unverändert lesbar, bestehender Test „jedes TrainingGoal hat mindestens ein
Template" liefert für `.endurance` ein Ergebnis statt zu crashen. Datenmodell:
`TrainingGoal`-RawRepresentable bekommt 6. Fall, rein additiv, keine Migration. Testplattform:
FitnessAppCore, kein SwiftUI/SwiftData-Bezug → **echter Linux-Unit-Test möglich**.

**P2.3 Gemeinsamer Adopt-Pfad statt vier getrennter Commit-Implementierungen**
Komponenten: neuer Service in FitnessAppData, ersetzt Teile von `OnboardingView.finishOnboarding`,
`CardioFeasibilityCardModel.accept`/`.acceptCustom`, `PlanBuilderView.adoptPlan()`. Abhängigkeiten:
P2.1. Abnahme: A11 (kein doppeltes/verwaistes Anlegen), B06 (Mehrfach-Tap-Schutz), alle vier
Call-Sites nutzen denselben Pfad. Datenmodell: keine (reine Konsolidierung). Testplattform:
Apple-CI/Gerät (SwiftData-Insert-Pfad).

**P2.4 Fixierungs-Flag im Builder-Draft**
Komponenten: `PlanBuilderView.swift` (neuer Draft-State), ggf. `GeneratedDay`-Erweiterung (Core).
Abhängigkeiten: P2.3. Abnahme: B02/B03 (Inhalt/Position getrennt fixierbar, bleibt bei Neuberechnung
erhalten). Datenmodell: **ausdrücklich kein persistiertes Feld** — reiner Draft-Zustand, verschwindet
nach Übernahme (Dok00: „Vorschau/Entwurf erzeugt keine persistierten Pläne"). Testplattform:
Core-Anteil ggf. Linux-testbar, Builder-UI-Anbindung Apple-CI/Gerät.

### P3 — A+B-Builder und Onboarding daran anbinden

**P3.1 Ziel-Schritt im Builder (vier Zielkarten)**
Komponenten: `PlanBuilderView.swift` (neuer `BuilderStep.goal`), `PlanGeneratorInput.swift`
(`TrainingGoal`-Feld). Abhängigkeiten: P2.2, P2.3. Abnahme: A02 (gleiche Eingaben → gleicher
fachlicher Vorschlag), Kartenauswahl setzt `TrainingGoal` korrekt inkl. Unterfrage
`.hypertrophy`/`.strength` bei „Kraft & Muskelaufbau". Datenmodell: `PlanGeneratorInput` bekommt
optionales `goal`-Feld (additiv, kein SwiftData-Schema betroffen). Testplattform: Core-Erweiterung
Linux-testbar, Builder-UI Apple-CI/Gerät.

**P3.2 Wochenübersicht-UI + Drag&Drop + „Verschieben nach…" — zuerst an Entwurfsdaten gebunden**
Komponenten: neue View (Wochenübersicht), löst `PlanEditorView.daysSection`s reine List ab/ergänzt sie.
Abhängigkeiten: P2.4, P2.0. Abnahme: B01 (Drag&Drop + zugängliche Alternative). **Verbindlich**: die
View bindet ausschließlich an `PlanDraft` (P2.0) — auch im Modus „bestehenden Plan bearbeiten"
(`PlanningMode.standaloneBuilder(editing: plan)`) wird der Plan beim Öffnen EINMALIG in einen
`PlanDraft` kopiert, alle Interaktionen (Reorder/Fixieren/Alternative) mutieren nur die Kopie. Kein
Control der View ist direkt an ein lebendes `TrainingDay`/`Exercise`-Objekt gebunden — das
unterscheidet sie bewusst vom bestehenden `PlanEditorView`, der live auf SwiftData bindet. Schreiben
in den `ModelContext` passiert ausschließlich über den P2.3-Adopt-Pfad beim expliziten Bestätigen,
nie während der Vorschau/Bearbeitung selbst (Dok00: „Vorschau/Entwurf erzeugt keine persistierten
Pläne" gilt damit auch für den Editier-, nicht nur den Erstellungsfall). Datenmodell: keine.
Testplattform: `PlanDraft`-Mutationslogik (Reorder/Fixieren) als reine Core-Funktionen
**Linux-testbar**; die View selbst 0 auf Linux — nur Apple-CI (Build) + Gerät (Gesten/VoiceOver).

**P3.3 Gezielte Alternativen statt globalem Shuffle**
Komponenten: `PlanGenerator.swift` (neue gezielte Ersatzfunktion statt `shuffle: true`),
`PlanBuilderView.swift` (3 Optionen statt „Neu rechnen"). Abhängigkeiten: P2.4, P3.2. Abnahme: B04
(keine stillen Verluste bei manuellen Änderungen + Neuberechnung), B05 (sichtbarer Konflikt statt
abgeschnittener Einheiten). Datenmodell: keine. Testplattform: Core-Teil Linux-testbar, UI-Anbindung
Apple-CI/Gerät.

**P3.4 Onboarding: Ausdauerform-Frage + Laufcoach-Entscheidung**
Komponenten: `OnboardingView.swift` (neuer Step, nutzt `TrainingTypeKind.running`/`.cycling` aus dem
Generator weiter, siehe Abschnitt 5-Tabelle), neues Feld in `UserBodyProfile` für die dauerhafte
Ausdauerform-Präferenz. Abhängigkeiten: P3.1. Abnahme: A03–A09 (volle Zustandstabelle Dok02 §3),
Start-Check-Isolation unverändert. Datenmodell: `UserBodyProfile` neues additives Feld
(Ausdauerform-Präferenz) + `cardioCoachingEnabled` wird erstmals im Onboarding beschrieben (kein neuer
Typ, nur neuer Schreibpfad). **Kein neues `CardioGoal`-Pendant für Radfahren** (siehe Abschnitt 5).
Testplattform: Enum/Kernlogik Linux-testbar, Onboarding-Flow Apple-CI/Gerät.

### P4 — Profiländerungen mit bestätigter Plananpassung verbinden

**P4.1 Equipment-Change-Trigger**
Komponenten: `ProfileEditorView.swift` (`.onChange(of: profile.equipmentProfile)`, analog Zeile 190
für `environment`). Abhängigkeiten: P2. Abnahme: Änderung löst überhaupt erstmals eine Reaktion aus
(Vorbedingung für C03/C05). Datenmodell: keine. Testplattform: Apple-CI/Gerät.

**P4.2 Equipment-Impact-Analyse gegen Bestandspläne**
Komponenten: neue Brücke in FitnessAppData — wendet `PlanEquipmentChecker`/`ExerciseRequirement`
(bisher nur gegen Core-`DaySpec`/`ExerciseSpec`) auf echte persistierte `TrainingDay`/`Exercise` an.
Abhängigkeiten: P4.1, Konfliktlösung 2 (präzises Modell statt `PlanEnvironmentMigrator`). Abnahme: C03
(betroffene Übung erkannt + begründeter Ersatz), C04 (Präferenz = optionale Neugewichtung, kein
Geräteverbot — **neu zu bauen**, siehe Abschnitt 2b, existiert heute gar nicht). Datenmodell: keine
zwingend (reine Abfrage), ggf. Transport-Struktur ohne Persistenz. Testplattform: Brücken-Logik ggf.
Linux-testbar falls rein formuliert, SwiftData-Anbindung Apple-CI/Gerät.

**P4.3 3-Wege-Entscheidung (anpassen/neu/behalten), gemeinsam für Cardio UND Equipment**
Komponenten: neue gemeinsame UI-Komponente, `CardioFeasibilityCardModel` (Refactor zur
Wiederverwendung durch Equipment-Pfad). Abhängigkeiten: P4.2, P2.3 (Adopt-Pfad). Abnahme: C01, C02,
C06. Datenmodell: keine. Testplattform: Apple-CI/Gerät.

**P4.4 Echte Equipment-Präferenz (Gewichtung) — eigener Task, kein Nebensatz von P4.2**
Heute existiert keine echte Präferenz (Abschnitt 2b) — `equipmentPreferences` ist ein veralteter
Verfügbarkeits-Spiegel, kein Gewichtungssystem. Vier eigenständige Teile:
- **UI**: neue Oberfläche, in der ein Nutzer mit MEHREREN vorhandenen Geräten eines bevorzugen kann
  (z. B. „habe Langhantel UND Kurzhanteln, bevorzuge Kurzhanteln") — bewusst getrennt von der
  Verfügbarkeits-Erfassung in `EquipmentProfileEditor`, da andere Fragestellung („was bevorzugst du"
  vs. „was hast du").
- **Persistenz**: neues, eindeutig benanntes Feld auf `UserBodyProfile` (NICHT `equipmentPreferences`
  wiederverwenden — der Name ist bereits doppelt belegt, siehe Abschnitt 2b; Vorschlag
  `preferredEquipmentRaw`), additiv.
- **Weiche Gewichtung**: neuer Scoring-Term in `PlanMatchmaker.rankPlansDetailed`
  (`PlanMatchmaker.swift:128–160`, aktuell 0 Equipment-Gewichtung) bzw. in der Varianten-/
  Substitutionswahl — bevorzugtes Gerät wird höher gerankt, andere Geräte bleiben weiterhin erlaubt
  (Dok01 §6: „andere Geräte nicht pauschal verbieten").
- **Anpassungsvorschau**: eigener, bewusst weicherer Ton als P4.2s Verfügbarkeits-Warnung — „diese
  Übung würde zu X, weil du Y bevorzugst" statt „diese Übung geht nicht ohne X".
Komponenten: `EquipmentProfileEditor.swift`/neue Präferenz-UI, `UserBodyProfile.swift`,
`PlanMatchmaker.swift`, `EquipmentVariant.swift`. Abhängigkeiten: P2, unabhängig von P4.1–P4.3 (kann
parallel geplant werden). Abnahme: C04 (optionale Neugewichtung, kein Geräteverbot). Datenmodell:
neues additives Feld (s. o.). Testplattform: Scoring-Term-Logik **Linux-testbar** (reine
`PlanMatchmaker`-Erweiterung), UI/Persistenz Apple-CI/Gerät.

### P5 — Versionierung/Datenqualität für spätere Rückblicke sichern

**P5.1 `TrainingPlan.activatedAt` (Zeitanker) — kein erfundenes historisches Datum**
Komponenten: `TrainingPlan.swift`, Lightweight-Backfill, `DataExportService`/`DataImportService`
(additive CSV-Spalte, Pattern wie `equipment_unknown_items`). Abhängigkeiten: keine (kann parallel zu
P3/P4 laufen). **Verbindlich**: `activatedAt: Date?` bleibt für JEDEN Bestandsplan ohne bekanntes
Datum **`nil`** — kein Backfill rät ein Datum (nicht Erstellungsdatum, nicht erste Session, nicht
„heute"). Der P6.1-Orchestrator behandelt `nil` als eigenen, expliziten Zustand „unbekannt → neue
Beobachtungsphase ab jetzt" (Beobachtungsfenster beginnt am Tag des ersten Reviews/der Migration,
NIE als vorgetäuschte Historie dargestellt — der Review-Text muss das offen benennen, z. B. „noch
keine ausreichende Datengrundlage" statt einer erfundenen Wochenzahl). Abnahme: Migrationstest —
Bestandsspeicher ohne Feld öffnen ergibt `activatedAt == nil` (nicht irgendein Default-Datum); ein
Review-Lauf auf einem `nil`-Plan meldet ausdrücklich „neue Beobachtungsphase", niemals eine erfundene
Laufzeit; CSV-Roundtrip mit und ohne das neue Feld. Datenmodell: `TrainingPlan` + `activatedAt:
Date?` (additiv, `nil` ist ein gültiger Dauerzustand, kein Platzhalter); Export +
`plan_activated_at`-Spalte (leer bei `nil`). Testplattform: SwiftData-Modell Apple-CI/Gerät;
CSV-Parsing-Anteil (reine String-Logik in `CSVReader`/`CSVWriter`, FitnessAppCore) sowie die
„`nil` → neue Beobachtungsphase"-Entscheidungslogik selbst (reine Funktion, kein SwiftData-Bezug)
Linux-testbar.

**P5.2 Inhalts-Snapshot pro `TrainingDay`-Fassung (Konfliktlösung 3)**
Komponenten: neue persistierte Snapshot-Struktur (Namenskollision mit den bestehenden UI-Discard-
Snapshots wie `PlanMetaSnapshot` vermeiden — eigener Name, z. B. `TrainingDayContentRecord`),
Verknüpfung zu `WorkoutSession`. Abhängigkeiten: P5.1. Abnahme: F07 (Review-Übernahme verändert
Historie nicht); ein nachträglich umsortierter `TrainingDay` verändert die inhaltliche Darstellung
einer bereits geloggten `WorkoutSession` nicht mehr. **Bewusst enger Scope**: nur der Tagesinhalt
(Übungen/Reihenfolge) wird eingefroren — die bestehende, bewusste Live-Lese-Ausnahme für einzelne
Korrekturfaktoren (`cnsFatigueScore` u. ä.) bleibt unverändert bestehen (Konfliktlösung 3).
Datenmodell: neues SwiftData-Modell oder JSON-Snapshot-Feld auf `WorkoutSession`; Migration nötig
(Bestandssessions ohne Snapshot werden explizit als „kein Snapshot verfügbar" markiert, keine
rückwirkende Fantasie-Rekonstruktion). Testplattform: SwiftData, nur Apple-CI/Gerät.

### P6 — Vier-Wochen-Rückblick und spätere Plan-Checks (ausdrücklich erst nach P1–P5)

**P6.1 Soll-Ist-Orchestrator**
Komponenten: neue dünne Core-Schicht, bündelt `DeloadAdvisor`/`ComebackAdvisor`/
`CardioCoachingAdvisor`/`TrainingCalendarAggregator`/`VolumeOverTimeAggregator` unverändert, ergänzt
nur den fehlenden „geplant vs. absolviert"-Vergleich. Abhängigkeiten: P5.1 (Zeitanker zwingend
erforderlich — ohne `activatedAt` keine Kalenderfrist berechenbar). Abnahme: F01–F03, F08 (keine
widersprüchlichen Vorschläge verschiedener Advisors). Datenmodell: additiver Review-Zustand
(„zuletzt reviewed am"/„nächstes fällig am", Pattern wie `AbsenceDeload`s Cooldown-Timestamp).
Testplattform: reine Funktionslogik mit injizierten Daten → **Linux-testbar**.

**P6.2 Review-UI — ausdrücklich kein Start-Check**
Komponenten: neue eigenständige View „Dein Plan-Check", Anbindung an die P3.2-Wochenübersicht für
„Änderungen ansehen". Abhängigkeiten: P6.1, P3.2, P5.2 (Vorher/Nachher-Vergleich braucht den
Inhalts-Snapshot). Abnahme: F06/F07; **Start-Check-Isolation bleibt unverändert** — kein neuer Pfad zu
`BaselineCheckFlowView`, keine Leistungstest-Fragen, eigene schlanke UI mit den 5 Fragen aus Dok03 §4.
Datenmodell: keine zusätzlich zu P6.1. Testplattform: Apple-CI/Gerät.

**P6.3 Block-Reviews + `plateauDetected`-Emitter**
Komponenten: `CoachingTypes.swift` (`plateauDetected` bekommt erstmals einen Emitter),
Progression-Outcome-Historie (neu persistiert, bisher sammelt `ProgressionApplicator` `.hold`-Fälle
nirgends). Abhängigkeiten: P6.1, P6.2. Abnahme: F04/F05. Datenmodell: neues Feld/Modell für den
Progression-Outcome-Verlauf (additiv). Testplattform: Core-Emitter-Logik Linux-testbar, Persistenz
Apple-CI/Gerät.

### P7 — Verifikation, Regression, Dokumentation (laufend + Abschluss je Paket)

Komponenten: alle. Abhängigkeiten: begleitet jede Phase, Abschlussbericht nach jedem P-Schritt gemäß
Dokument-04-Vorlage. Abnahme: implementiert/teilweise/offen klar getrennt benannt, DE/EN/TR,
Light/Dark, kleine Displays geprüft wo zutreffend. Datenmodell: keine eigenen. Testplattform: wie in
der jeweiligen Teilaufgabe oben einzeln vermerkt — keine pauschale „alles grün"-Aussage.

## Nächste Aufgabe

P1.2 (RIR-Redesign) — einziger offener Punkt aus dem Fehler-Paket, in sich geschlossen, ohne
Abhängigkeit zu den Konfliktfragen oder zu P2–P6. Wird als nächstes umgesetzt, sobald dieser
präzisierte Bericht akzeptiert ist.

## P1-Abschlussbericht

```
Paket: P1 — Bestehende Fehler und Regressionen absichern
Implementiert: P1.2 RIR strukturelle Spalten-Neugestaltung vollständig umgesetzt.
Noch nicht implementiert: nichts innerhalb P1 — P1.1 war bereits in P0 verifiziert.
Geänderte Komponenten:
  - Sources/FitnessAppUI/Workout/SetRow.swift: neues `SetRowColumns`-Enum (geteilte
    Spaltenmetriken), `compactSetRow` auf `ViewThatFits(singleLineInputRow, twoLineInputRow)`
    umgestellt, `rirCapsule` entkompaktiert (kein "R"-Präfix, `.fixedSize()`, feste Spaltenbreite,
    bleibt bei aufgeklapptem Regler an fester Position), `weightInput`-Overlay entfernt, neue
    `plateColumn` (eigene Spalte statt Overlay), `rirSliderRow` ohne eingebettete Kapsel.
  - Sources/FitnessAppUI/Workout/ExerciseCard.swift: neue `setRowColumnHeader`-Zeile (Satz/kg/
    Wdh/RIR, einmal pro Übung, nur für Strength/Bodyweight), nutzt dieselben `SetRow.
    SetRowColumns`-Breiten wie die Satzzeilen.
  - Sources/FitnessAppUI/Resources/Localizable.xcstrings: 3 neue Keys (`set.column.setLabel`,
    `set.column.rirLabel`, `set.column.header.accessibilityLabel`), DE/EN/TR vollständig, mit
    bestehendem `deltiqLabel()`-Stil (identisch zu KG/WDH/PACE) statt eigenem Styling.
Neue/geänderte Datenfelder: keine (reines UI, kein SwiftData-Schema berührt).
Tests hinzugefügt: keine neuen automatisierten Tests — reine Layout-/Darstellungsänderung ohne
  neue Linux-testbare Logik (bestehende Pure-Logic-Tests in EditorDiscardSnapshotTests.swift sind
  von dieser Änderung nicht betroffen).
Tests tatsächlich ausgeführt: `swift build` + `swift test --parallel` auf Linux, grün, 979/979
  unverändert. Diese Datei-Paar ist `#if canImport(SwiftUI)`-gegated — der Linux-Lauf bestätigt
  NUR, dass der Rest des Pakets weiterhin kompiliert, NICHT die Syntax-/Typkorrektheit von
  `ViewThatFits`/den neuen Views selbst (die kompilieren auf Linux zu einer leeren Einheit). Den
  gesamten Diff deshalb zusätzlich manuell Zeile für Zeile gegengelesen (Klammerbilanz, API-Namen,
  Typkonsistenz, keine verwaisten Referenzen auf entfernten Code).
Apple-Build/CI: nicht verifiziert — diese Session hat keinen Codemagic-Zugriff. Der Push löst die
  Workflows automatisch aus; ein erster echter Compiler-Lauf (der z. B. `ViewThatFits`-Verwendung
  oder Tippfehler tatsächlich prüfen würde) liegt außerhalb dieser Session und wird erst bei einem
  geteilten Log sichtbar (wie zuvor bei Finding 1 in dieser Epik).
UI-/Geräteprüfung: NICHT durchgeführt, kein Simulator-/Geräte-Zugriff aus dieser Session. Explizit
  offen: Spaltenausrichtung Header/Satzzeilen auf echtem Gerät, RIR-Wert-Lesbarkeit bei allen 11
  gültigen Werten (0 bis 5 in 0,5-Schritten) auf iPhone SE, Reglerposition beim Öffnen/Schließen
  über mehrere Sätze hinweg, Plate-Popover-Anker nach Spalten-Umzug, Zwei-Zeilen-Fallback bei
  größter Dynamic-Type-Stufe, Regressionsprüfung der in diesem Paket laut Vorgabe unverändert zu
  haltenden Funktionen (Trainingsseiten-Swipes, Drag & Drop, Eingaben, Logging, Timer) — diese
  wurden im Diff bewusst nicht berührt (siehe Komponentenliste oben, Swipe-/Reorder-/Timer-Code
  liegt in anderen Dateien und war an keiner Stelle Teil dieses Edits), eine Geräte-Gegenprobe
  bleibt aber trotzdem ausständig.
Bekannte Grenzen/Risiken: der Spalten-Header selbst ist nicht an `ViewThatFits`s Fallback-
  Entscheidung gekoppelt — fällt `SetRow` auf sein zweizeiliges Layout zurück, bleibt der Header
  einzeilig stehen und "RIR" steht dann nicht mehr exakt über der (auf Zeile 2 gewanderten) Kapsel.
  Bewusst nicht in dieser Runde behoben, siehe Doc-Kommentar an `setRowColumnHeader`. Alle
  Breitenwerte (`SetRowColumns`) sind Schriftmetrik-Berechnungen, keine Geräte-Messungen.
Branch/Commit: claude/smart-onboarding-epic (gespiegelt auf claude/neue-views-entwicklung-ahsg90).
  Commit e3407a3 = diese RIR-Implementierung. Commit b68d5e4 = rein redaktionelle Folgeänderung
  (SHA-Ergänzung in diesem Dokument selbst), enthält keinen Code dieses Pakets.
Nächste Aufgabe: P2.0 — Datenvertrag für Planungskontext/Wochenentwurf (Core, Linux-testbar).
```

## P1-Nachbesserung (vor Abnahme korrigiert)

Review-Rückmeldung nach dem ersten P1-Bericht fand drei konkrete, berechtigte Lücken. Alle behoben,
P1 gilt erst mit dieser Nachbesserung als code-seitig vollständig — Apple-Build/UI-Prüfung bleiben
unverändert offen (siehe unten).

**1. Äußere Spaltenbreiten.** `weightInput`/`repsInput` setzen `.frame(width:)` VOR ihrem eigenen
`.padding(.horizontal, 8)` — die sichtbare Box ist dadurch 16pt breiter als die reine Feldbreite
(72/64pt statt 56/48pt). Der Header reservierte vorher nur die schmalere Feldbreite. **Fix:**
`SetRowColumns.weightWidth`/`repsWidth` sind jetzt explizit als `weightFieldWidth/repsFieldWidth +
2 × fieldHorizontalPadding` definiert (die tatsächliche äußere Breite); `weightInput`/`repsInput`
selbst nutzen die neuen `*FieldWidth`-Konstanten für ihr `.frame()`, unverändert in der Optik. Header
und `ViewThatFits`-Breitenvergleich nutzen ausschließlich die korrigierten `weightWidth`/`repsWidth`.

**2. Header/Zwei-Zeilen-Fallback-Konsistenz.** Der Header war starr einzeilig; bei `SetRow`s
zweizeiligem Fallback hätte „RIR" über leerem Platz gestanden. **Fix:** Der Header hat jetzt selbst
einen `ViewThatFits(fullSetRowColumnHeader, reducedSetRowColumnHeader)`. Die reduzierte Variante zeigt
nur noch Satz/kg/Wdh (exakt Zeile 1 von `twoLineInputRow`) und nutzt dieselben Spaltenbreiten wie die
Satzzeile, wodurch beide `ViewThatFits`-Entscheidungen bei gleicher verfügbarer Breite zusammenfallen
— kein eigenständig gepflegter Breitenwert, der hätte abweichen können. Zusätzlich bekommt
`twoLineInputRow`s zweite Zeile ein eigenes Inline-„RIR"-Label direkt neben der Kapsel, sodass die
Bedeutung in BEIDEN Fällen eindeutig ist (Vorgabe „gemeinsame Layoutentscheidung" UND „eindeutige
lokale Beschriftung im Fallback" beide umgesetzt, nicht nur eine Option). Kein neuer Overflow-Pfad:
der reduzierte Header hat strukturell weniger Inhalt als der volle, kann also nicht breiter sein.

**3. Dynamic Type.** Checkmark-Spalte nutzte einen statischen `28`-Platzhalter, obwohl das echte Icon
über `@ScaledMetric` skaliert — bei großen Schriftstufen hätte das auseinanderlaufen können. RIR-Spalte
im Header nutzte eigenes Styling statt der Kapsel-Vorgabe. **Fix:** `ExerciseCard` deklariert dieselbe
`@ScaledMetric(relativeTo: .title2)`-Property (gleiche Basis 28) wie `SetRow.checkmarkIconSize` —
beide im selben Environment ausgewertet, garantiert identischer Wert, statt einer behaupteten
Gleichheit zweier unabhängiger Zahlen. Neuer `SetRow.RIRValueTextStyle`-`ViewModifier` (Font/
FixedSize/Padding/MinWidth) wird von `rirCapsule` UND dem Header-RIR-Label GEMEINSAM angewendet —
Breitengleichheit durch identischen Code, nicht durch zwei manuell synchron gehaltene Werte.

Geänderte Komponenten zusätzlich zum ersten P1-Commit: `SetRow.swift` (`SetRowColumns` korrigiert,
neuer `RIRValueTextStyle`, `weightInput`/`repsInput` umgestellt, `rirCapsule` nutzt den Modifier,
`twoLineInputRow` mit Inline-RIR-Label), `ExerciseCard.swift` (`setRowColumnHeader` jetzt
`ViewThatFits` mit `fullSetRowColumnHeader`/`reducedSetRowColumnHeader`, neue `@ScaledMetric`-Property),
`Localizable.xcstrings` (+1 Key `set.column.header.reducedAccessibilityLabel`, DE/EN/TR).

Tests ausgeführt: Linux Build+Test grün, 979/979 unverändert — gleiche Einschränkung wie beim ersten
P1-Commit (SwiftUI-gegated, beweist nur Restpaket-Kompatibilität). Gesamten Diff erneut manuell
gegengelesen (Klammerbilanz, `ViewModifier`-Konformität, `@ScaledMetric`-Deklarationssyntax,
Referenz-Konsistenz zwischen den neuen Konstanten).

**Weiterhin ausdrücklich offen, nicht „erledigt":** Apple-Build/CI — nicht verifizierbar aus dieser
Session, erster echter Compiler-Lauf passiert erst bei einem geteilten Codemagic-Log. UI-/
Geräteprüfung — nicht durchgeführt: ob Header und Satzzeilen auf einem echten Gerät bei jeder
Dynamic-Type-Stufe tatsächlich pixelgenau fluchten, ob `ViewThatFits` in beiden Stellen wirklich
synchron kippt, und ob die berechneten (nicht gemessenen) Breitenwerte (`rirWidth`, ScaledMetric-Basis
28) in der Praxis ausreichen, ist ohne Simulator/Gerät nicht feststellbar. P1 bleibt bis zu einer
solchen Prüfung "implementiert, nicht abgenommen".

## P2.0-Abschlussbericht (Datenvertrag Planungskontext/Wochenentwurf)

**Paket:** P2.0 — fachlicher Datenvertragsentwurf für `PlanningContext`/`PlanDraft` (reine
Core-Werttypen, parallel zu P1 autorisiert, ausdrücklich ohne breite UI- oder
Persistenzumstellung).

**Implementiert:**
- `Sources/FitnessAppCore/Planning/PlanningContext.swift`: `EnduranceModality` (`.running/.cycling/.both`,
  mit `trainingTypeKinds`-Brücke zu den bestehenden `TrainingTypeKind`-Cardio-Fällen — kein
  Parallel-Vokabular), `SchedulingMode` (`.fixedWeekdays([Int])/.flexibleOrder`, spiegelt
  `PlanGeneratorInput.usesFixedWeekdays/fixedWeekdays` 1:1), `PlanningMode`
  (`.onboarding/.builderCreate/.builderEdit/.profileAdaptation`), `PlanningContext` selbst
  sowie `PlanningContextIssue` + die berechnete `issues`/`isValid`-Validierung und
  `effectiveEquipment` (delegiert an den bestehenden `EquipmentPlanningResolver`).
- `Sources/FitnessAppCore/Planning/PlanDraft.swift`: `DraftDayID`/`DraftExerciseID` (UUID-basierte
  stabile Identitäten), `DraftExercise`, `DraftDay` (mit `isContentFixed`/`isPositionFixed` je Tag),
  `PlanDraft` mit `init(generated:)`, `resolvedDaySpecs`, `moveDay`, `replaceContent`,
  `setContentFixed`/`setPositionFixed`.
- Alle drei in der Audit-Abnahme benannten Invarianten sind als Code + Test umgesetzt:
  `runCoachEnabled` erfordert `.running`/`.both`; `fixedWeekdays.count == daysPerWeek` (plus
  Range- und Eindeutigkeits-Prüfung, über die Abnahme hinaus); Gym-Umgebung ohne Bestätigung
  löst nachweislich die bestehende Gym-Annahme aus, nie eine stille Lücke.
- **Drei bewusste Korrekturen gegenüber der Skizze im P2.0-Abschnitt dieses Dokuments** (beim
  Umsetzen in echten Code gefunden, nicht Teil der ursprünglich gebilligten Skizze):
  1. `PlanningMode.standaloneBuilder(editing: TrainingPlan?)` hätte nicht kompiliert —
     `TrainingPlan` ist ein SwiftData-`@Model` (FitnessAppData/FitnessAppUI), Core ist
     ausdrücklich SwiftData-frei (siehe `DaySpec.swift`-Dateikommentar). `PlanningMode` trägt
     jetzt keine Plan-Referenz mehr, nur die Betriebsart; welcher Plan bearbeitet wird, hält
     ausschließlich der Aufrufer. Zugleich ergänzt um den in der Vorgabe genannten, in der
     Skizze aber fehlenden dritten Fall `.profileAdaptation` (P4).
  2. `PlanDraft.fixedDayIDs: Set<DraftDay.ID>` / `fixedPositionIndices: Set<Int>` aus der Skizze
     ersetzt durch zwei Bool-Felder direkt auf `DraftDay` (`isContentFixed`/`isPositionFixed`) —
     ein `Set<Int>` über Positionen bricht still, sobald ein ANDERER Tag verschoben/entfernt wird;
     die Vorgabe „stabile Identitäten statt volatiler Indizes" gilt damit auch für die Fixierung
     selbst.
  3. `PlanningContext.equipmentProfile` allein hätte die in der Abnahme geforderte
     Gym-Annahme-Prüfung nicht ausdrücken können — ergänzt um
     `equipmentProfileConfirmedComplete: Bool`, damit `effectiveEquipment` den bestehenden
     `EquipmentPlanningResolver` (Smart-Onboarding-Epic Phase 6) tatsächlich aufrufen kann,
     statt eine zweite Equipment-Auflösung einzuführen.

**Noch nicht implementiert (bewusst außerhalb von P2.0):** jede Verdrahtung in Onboarding/
Builder-UI/`ModelContext` (das ist P2.1–P2.4 und P3) — `PlanningContext`/`PlanDraft` werden
aktuell von keinem Aufrufer referenziert. Keine Bridge-Funktion `PlanningContext ->
PlanGeneratorInput`: die Abnahme-Kriterien dieses Dokuments verlangen nur den Datenvertrag + die
drei Invarianten, nicht die Generator-Anbindung — eine goal-basierte Erzeugungslogik würde ohne
mit dem User abgestimmte Richtlinie (Goal -> TrainingTypeKind/Template) vorgreifen und ist
deshalb bewusst offengelassen für P3. `TrainingGoal.endurance` existiert weiterhin nicht
(P2.2, separat).

**Geänderte Komponenten:** zwei neue Dateien (`PlanningContext.swift`, `PlanDraft.swift`) in
neuem Ordner `Sources/FitnessAppCore/Planning/`. Keine bestehende Datei verändert — `DaySpec`/
`ExerciseSpec`/`EquipmentPlanningContext`/`PlanGeneratorInput` bleiben exakt unangetastet.

**Neue/geänderte Datenfelder:** keine SwiftData-/Persistenzänderung. Alle neuen Typen sind reine
In-Memory-Werttypen ohne `Codable` (bewusst konsistent mit `DaySpec`/`ExerciseSpec`, die ebenfalls
nicht `Codable` sind — nichts verlangt aktuell Serialisierung).

**Tests hinzugefügt:** `Tests/FitnessAppCoreTests/PlanningContextTests.swift` (16 Tests: alle drei
Invarianten je mit Positiv-/Negativ-Fall, `EnduranceModality`-Brücke, Vollständig-gültig-Fall) und
`Tests/FitnessAppCoreTests/PlanDraftTests.swift` (12 Tests: Sortierung/ID-Vergabe bei
`init(generated:)`, `sequenceIndex`-Neuvergabe aus Array-Position, vollständiger Feld-Rundtrip,
Reorder inkl. Clamping, beide Fixierungen inkl. ihrer wechselseitigen Unabhängigkeit, unbekannte ID).

**Tests tatsächlich ausgeführt:** Plattform Linux (Swift 6.0.3, `swift test`). Gezielt
`swift test --filter "PlanningContextTests|PlanDraftTests"` — 38 Tests (inkl. der mitgefilterten
`EquipmentPlanningContextTests`), 0 Fehlschläge. Danach vollständiger Lauf `swift test` ohne
Filter — **1007 Tests, 0 Fehlschläge** (keine Regression im Restpaket). Dies ist der erste
tatsächlich auf Linux kompilierte und getestete Baustein dieses Epics — anders als P1 (SwiftUI-
gegated) ist hier „Linux grün" eine echte, vollständige Korrektheitsprüfung, kein Teil-Nachweis.

**Apple-Build/CI:** nicht zutreffend — reiner Core-Code ohne `canImport(SwiftUI/SwiftData/UIKit)`-
Gates, kompiliert identisch auf jeder Plattform. Kein separater Apple-Nachweis nötig.

**UI-/Geräteprüfung:** nicht zutreffend — keine UI in diesem Paket.

**Bekannte Grenzen/Risiken:** (1) Der Datenvertrag ist noch ungenutzt — ob er für P3s
tatsächliche Builder-/Onboarding-Anforderungen ausreicht, zeigt sich erst bei der Anbindung;
denkbar, dass P3 zusätzliche Felder braucht (z.B. `experienceTrack`, falls der Builder ihn
direkt aus dem Kontext statt separat lesen soll). (2) Die fehlende `PlanningContext ->
PlanGeneratorInput`-Brücke bedeutet, dass die Goal-zu-Generierung-Richtlinie noch absichtlich
unentschieden ist — das ist eine echte offene Design-Frage für P3, keine vergessene Arbeit.
(3) `DraftDayID`/`DraftExerciseID` sind bewusst nicht `Codable` — sobald P3.2 den Editor-State
z.B. bei App-Hintergrund sichern will, braucht es dafür eine separate Entscheidung.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag (gemeinsam committet, siehe Git-Log).

**Nächste Aufgabe:** P2.1 (`targetEnvironment`-Hardcode-Bug beheben) — unabhängig von P2.0,
kann parallel zu P3 begonnen werden. P2.2 (`TrainingGoal.endurance`) ist ebenfalls unabhängig
und Linux-testbar. P2.3/P2.4 hängen von P2.1 ab (siehe Phasenplan oben).
