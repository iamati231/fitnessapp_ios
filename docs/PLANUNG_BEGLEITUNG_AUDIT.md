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
(`PlanningMode.builderEdit`) wird der Plan beim Öffnen EINMALIG in einen `PlanDraft` kopiert, alle
Interaktionen (Reorder/Fixieren/Alternative) mutieren nur die Kopie. Kein Control der View ist direkt
an ein lebendes `TrainingDay`/`Exercise`-Objekt gebunden — das unterscheidet sie bewusst vom
bestehenden `PlanEditorView`, der live auf SwiftData bindet. Schreiben in den `ModelContext` passiert
ausschließlich über den P2.3-Adopt-Pfad beim expliziten Bestätigen, nie während der Vorschau/
Bearbeitung selbst (Dok00: „Vorschau/Entwurf erzeugt keine persistierten Pläne" gilt damit auch für
den Editier-, nicht nur den Erstellungsfall). **Verbindlich (Nachtrag P2.0-Nachbesserung)**:
`PlanDraft.reorder(to:)`/`moveDay` lehnen eine Verschiebung GANZ ab, sobald sie — und sei es nur
indirekt durch das Verschieben eines ANDEREN Tages — einen positionsfixierten Tag von seinem Platz
verdrängen würde (siehe dortige Tests). Die UI MUSS eine so abgelehnte Verschiebung dem Nutzer
verständlich anzeigen (z.B. der gezogene Tag springt sichtbar zurück, kein stilles No-Op) — ein
fixierter Tag darf sich dabei nie unbemerkt mitbewegen. Datenmodell: keine. Testplattform:
`PlanDraft`-Mutationslogik (Reorder/Fixieren) als reine Core-Funktionen **Linux-testbar**; die View
selbst 0 auf Linux — nur Apple-CI (Build) + Gerät (Gesten/VoiceOver, inkl. der Ablehnungs-Rückmeldung).

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

Stand nach P1/P1-Nachbesserung/P2.0 (siehe jeweilige Abschlussberichte unten): P2.1
(`targetEnvironment`-Hardcode-Bug) und P2.2 (`TrainingGoal.endurance`) sind beide unabhängig
voneinander und von P2.0 lösbar, keine Blocker. P2.3 hängt von P2.1 ab, P2.4 von P2.3. P3
(Builder/Onboarding-Anbindung) benötigt P2.0 (vorhanden) und sollte die in P2.0 bewusst
offengelassene Goal→Generierung-Richtlinie klären.

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
Satzzeile — SO AUSGELEGT, dass beide `ViewThatFits` bei gleicher verfügbarer Breite zum selben
Ergebnis kommen sollen. Das ist aber keine gemeinsame Layoutentscheidung: Header und Satzzeile sind
zwei unabhängig ausgewertete `ViewThatFits`, jede mit ihrer eigenen tatsächlich verfügbaren Breite an
ihrer Stelle im Layout — gleiche Konstanten verhindern nur ein eigenständig gepflegtes, abweichendes
Zahlenpaar, sie belegen nicht, dass beide auf einem echten Gerät wirklich synchron kippen (siehe
„Weiterhin ausdrücklich offen" unten). Zusätzlich bekommt
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
FixedSize/Padding/MinWidth) wird von `rirCapsule` UND dem Header-RIR-Label GEMEINSAM angewendet, damit
beide denselben `minWidth`-Mindestwert und dieselbe Schrift bekommen — statt zwei manuell synchron
gehaltener Werte, die hätten auseinanderlaufen können. Das beweist aber NOCH KEINE gleiche tatsächliche
Breite: `minWidth` ist ein Mindestwert, `.fixedSize()` lässt den Inhalt darüber hinauswachsen, und „RIR"
(drei Buchstaben) und ein formatierter RIR-Wert wie „2,5" oder „10" (Ziffern/Komma) sind unterschiedliche
Strings, die bei identischer Schrift unterschiedlich breit sein können — insbesondere bei großen
Dynamic-Type-Stufen, wo das ohne Gerät nicht abschätzbar ist. Identischer Code verhindert nur eine
versehentlich auseinanderlaufende Konfiguration, er ist kein Nachweis gleicher gerenderter Breite.

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
Filter — **1007 Tests, 0 Fehlschläge** (keine Regression im Restpaket). Das ist ein Testergebnis,
kein vollständiger Korrektheitsbeweis: es bestätigt, dass genau die hier formulierten Tests bestehen
und dass das Restpaket weiterhin kompiliert — nicht, dass der Code frei von Fehlern ist, die kein
Test abdeckt. Dieser Baustein ist zwar (anders als P1) frei von `canImport(SwiftUI/SwiftData/UIKit)`-
Gates und deshalb auf Linux tatsächlich mitkompiliert und mitgetestet, nicht nur toleriert — das
senkt das Risiko gegenüber P1, ersetzt aber nicht die Prüfung unten.

**Apple-Build/CI:** nicht durchgeführt — offen. Keine `canImport`-Gates bedeutet ein geringeres
Risiko als bei P1 (kein SwiftUI/SwiftData-Code, der auf Linux syntaktisch ungeprüft bliebe), aber
keinen Entfall der Prüfung: der Core-Code muss zusätzlich innerhalb des tatsächlichen,
mehrteiligen Apple-App-Builds (Xcode/Codemagic, zusammen mit FitnessAppData/FitnessAppUI und den
übrigen Targets) integriert kompilieren — das wurde aus dieser Session heraus nicht geprüft und
bleibt bis zu einem geteilten Codemagic-Log offen.

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

**Nächste Aufgabe:** siehe P2.0-Nachbesserung unten — zwei Vertragskorrekturen, vor P2.1 erledigt.

## P2.0-Nachbesserung (Positionsfixierung + Basisvalidierung)

Review-Rückmeldung fand zwei konkrete Vertragslücken, beide vor der weiteren Anbindung behoben.

**1. Indirekte Verschiebung fixierter Tage.** `moveDay` prüfte bisher nur, ob der VERSCHOBENE Tag
selbst positionsfixiert ist — nicht, ob das Verschieben eines ANDEREN Tages einen fixierten Tag
rechnerisch auf einen anderen Index schiebt. Konkret: bei `[A, B(fixiert), C]` verschob
`moveDay(A, toIndex: 2)` B unbemerkt von Index 1 auf 0, weil das Entfernen von A alle
nachfolgenden Tage nach vorne rückt. **Fix:** neuer gemeinsamer Pfad `PlanDraft.reorder(to:)`,
der die VOLLSTÄNDIGE vorgeschlagene Tagesreihenfolge gegen alle aktuell positionsfixierten Tage
prüft — jeder davon muss in der Kandidaten-Reihenfolge exakt seinen bisherigen Index behalten,
sonst wird die GESAMTE Operation verworfen (kein Teil-Erfolg, kein „B gerettet, Rest trotzdem
angewendet"). `moveDay` baut nur noch die Kandidaten-Reihenfolge und delegiert die eigentliche
Prüfung/Anwendung an `reorder(to:)` — EIN Prüfpfad für Drag & Drop UND jede künftige
Neuverteilung (z.B. P2.4s „bleibt bei Neuberechnung erhalten"), nicht zwei potenziell
abweichende. Bewusst NICHT umgesetzt: ein „intelligentes" Ausweichen auf eine alternative
Anordnung, wenn die gewünschte mit einer Fixierung kollidiert (z.B. C automatisch woanders
platzieren) — das wäre eine eigene UX-Entscheidung für P3/den visuellen Wochen-Editor, keine
Dateneigenschaft; hier wird die Operation stattdessen abgelehnt und das Ergebnis bleibt
unverändert, bis eine solche Richtlinie bewusst entschieden wird.

**2. `PlanningContext`-Basisvalidierung unvollständig.** `sessionDurationMinutes` hatte gar keine
Prüfung; `daysPerWeek` hatte nur eine Untergrenze (`> 0`), keine Obergrenze und keine dokumentierte
Bedeutung. **Fix:** `sessionDurationMinutes <= 0` ist jetzt ein Validierungsfehler
(`sessionDurationMinutesNotPositive`). `daysPerWeek` ist jetzt explizit als „Anzahl
UNTERSCHIEDLICHER Kalendertage mit Training, 1...7" dokumentiert und validiert
(`daysPerWeekOutOfRange`, ersetzt das bisherige `daysPerWeekNotPositive`) — eine Woche hat nur
sieben Tage, und dieser Vertrag kennt kein Konzept von „mehrere Einheiten an einem Tag"; ein Wert
außerhalb 1...7 wird als expliziter Validierungsfehler gemeldet, nie still auf 7 gekappt oder
stillschweigend als Mehrfacheinheiten-Wunsch interpretiert.

**Geänderte Komponenten:** `Sources/FitnessAppCore/Planning/PlanDraft.swift` (`reorder(to:)` neu,
`respectsPositionFixations` privat, `moveDay` auf `reorder(to:)` umgestellt, `DraftDay.
isPositionFixed`-Dokumentation ergänzt), `Sources/FitnessAppCore/Planning/PlanningContext.swift`
(`PlanningContextIssue.daysPerWeekOutOfRange` ersetzt `daysPerWeekNotPositive`, neuer Fall
`sessionDurationMinutesNotPositive`, `issues` erweitert, Feld-Dokumentation ergänzt).

**Neue/geänderte Datenfelder:** keine — reine Verhaltens-/Validierungskorrektur an denselben
Typen, keine neuen gespeicherten Felder, keine SwiftData-Änderung.

**Tests hinzugefügt:** 13 neue Tests. `PlanDraftTests.swift`: der exakte Audit-Fall
(`[A, B(fixiert), C]`, A ans Ende verschieben → verworfen, B bleibt bei Index 1, A bleibt
ebenfalls unverändert), dieselbe Invariante aus der Gegenrichtung (C nach vorne vor B), ein
Positiv-Fall (Verschiebung vollständig NACH dem fixierten Tag gelingt weiterhin), plus direkte
Tests für `reorder(to:)` (gültige Permutation mit erhaltenem Fixpunkt, Ablehnung bei
Fixpunkt-Verletzung, Ablehnung bei Nicht-Permutation: zu kurz/Duplikat/unbekannte ID).
`PlanningContextTests.swift`: `daysPerWeek` an beiden Grenzen (0, -1, 8 ungültig; 1, 7 gültig),
`sessionDurationMinutes` (0, -15 ungültig; 1 gültig).

**Tests tatsächlich ausgeführt:** Linux (Swift 6.0.3). Gezielt `swift test --filter
"PlanningContextTests|PlanDraftTests"` — 51 Tests, 0 Fehlschläge. Vollständiger Lauf `swift
test` ohne Filter — **1020 Tests, 0 Fehlschläge** (1007 + 13 neue, keine Regression). Wie beim
P2.0-Erstbericht: ein Testergebnis für die hier formulierten Fälle, kein Beweis der Abwesenheit
anderer Fehler, und kein Ersatz für den noch offenen Apple-Build (s.o.).

**Apple-Build/CI:** weiterhin nicht durchgeführt — offen, unverändert zum P2.0-Erstbericht.

**UI-/Geräteprüfung:** nicht zutreffend — keine UI in diesem Paket.

**Bekannte Grenzen/Risiken:** Die Entscheidung, bei einem Fixierungs-Konflikt die GESAMTE
Operation abzulehnen statt automatisch auszuweichen, ist bewusst konservativ — falls P3s
visueller Wochen-Editor stattdessen ein Ausweich-Verhalten für Drag & Drop erwartet (z.B. den
gezogenen Tag automatisch vor/hinter dem Fixpunkt einrasten zu lassen), ist das eine zusätzliche,
noch zu entscheidende UX-Schicht auf `reorder(to:)`, keine Änderung an der hier geprüften
Invariante selbst.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** P2.1 (`targetEnvironment`-Hardcode-Bug beheben) — unabhängig von P2.0,
kann parallel zu P3 begonnen werden. P2.2 (`TrainingGoal.endurance`) ist ebenfalls unabhängig
und Linux-testbar, kann parallel bearbeitet werden (beide Dateien überschneiden sich nicht:
`PlanGeneratorInstantiator.swift` vs. `CoachingTypes.swift`). P2.3/P2.4 hängen von P2.1 ab
(siehe Phasenplan oben). Vor P3: Goal→Generierung-Zuordnungsregeln für Hybrid/Ausdauer/Laufcoach
explizit festlegen (keine versteckten Defaults für diese Nutzerentscheidungen).

## P2.1-Abschlussbericht (targetEnvironment-Hardcode-Bug behoben)

**Paket:** P2.1 — `PlanGeneratorInstantiator.makeTemplate` setzte `targetEnvironment: .gym`
hartcodiert, unabhängig vom tatsächlichen Trainingsort. Jeder über Builder/Cardio-Coach/
Onboarding-Custom-Plan erzeugte Plan bekam dadurch IMMER `.gym`, auch bei Home-Gym/Kein-Equipment.

**Implementiert:**
- `PlanGeneratorInstantiator.build(from:in:...)` bekommt zwei neue, **absichtlich
  pflichtige, default-lose** Parameter: `environment: EnvironmentType` und `equipmentProfile:
  UserEquipmentProfile`. `makeTemplate` setzt `targetEnvironment` jetzt aus `environment` statt
  `.gym`. Kein Default, damit kein neuer stiller Fehler denselben Fehler nur versteckter wiederholt
  — jeder Aufrufer muss den Wert explizit liefern.
- `equipmentProfile` fließt als `userEquipmentProfile:` in `ProgramInstantiator.instantiate` —
  dieselbe präzise, pro-Übung-genaue `PlanEquipmentChecker`/`bestEquipmentCheckedVariant`-Prüfung
  (Smart-Onboarding-Epic Phase 4), die der Template-Pfad bereits nutzt, statt der bisherigen groben
  `Set<Equipment>`-Legacy-Prüfung (`input.equipmentPreferences` wird dafür nicht mehr übergeben —
  sie hatte ohnehin nie einen Effekt, siehe „Bekannte Grenzen").
- Alle drei echten Aufrufstellen liefern jetzt den tatsächlich vorhandenen, bereits aufgelösten
  Planungskontext statt eines erfundenen Werts:
  - `CardioFeasibilityCardModel.accept`/`.acceptCustom`: `profile.environment` +
    `EquipmentPlanningResolver.resolve(...).effectiveProfile` aus dem bereits übergebenen `profile`.
  - `OnboardingView.finishOnboarding` (Custom-Plan-Zweig): dieselben `environment`/
    `equipmentPlanningContext`, die der direkt daneben stehende Template-Zweig schon verwendet —
    vorher hatten beide Zweige unterschiedliches Verhalten, obwohl sie denselben Planungskontext
    im selben Onboarding-Durchlauf abbilden.
  - `PlanBuilderView.adoptPlan()`: neue `@Query private var profiles: [UserBodyProfile]` +
    `equipmentPlanningContext` (identisches Muster wie `ProgramTemplatePickerView`/`OnboardingView`
    — „EINE Berechnung", keine vierte, eigenständige Auflösung).
- Fehlende/widersprüchliche Angaben (Punkt 3 der Vorgabe): werden nicht durch eine neue,
  eigenständige Regel hier behandelt, sondern genau wie überall sonst in der App — durch
  Wiederverwendung des bestehenden `EquipmentPlanningResolver` (Gym-Annahme ohne Bestätigung,
  bestätigt gewinnt immer, unbestätigt bleibt roh). Einzige verbleibende Fallback-Stelle ist
  `profiles.first?.environment ?? .gym`/`?? UserEquipmentProfile()` in `PlanBuilderView` — NICHT
  für den behobenen Bug (ein routinemäßiges Überschreiben vorhandener Werte), sondern für den
  strukturell unerwarteten Fall „noch kein Profil vorhanden", identisches, bereits bestehendes
  Muster wie in `ProgramTemplatePickerView.equipmentPlanningContext`.
- Kein bestehender Plan wird rückwirkend verändert (Punkt 6): `build` instanziiert ausschließlich
  NEUE Pläne; nichts an `recalculate`/`apply` (die auf bereits persistierten Plänen arbeiten) wurde
  angefasst.

**Noch nicht implementiert (bewusst außerhalb von P2.1):** Der volle Phase-5-Substitutions-Pfad
(`PlanSelectionResolver`/`ResolvedPlanSelection`, mit tatsächlichem Ersatz fehlender Übungen) ist
NICHT angebunden — er bräuchte einen `SubstitutionContext(goal:experienceTrack:)`, und ein über
Builder/Cardio-Coach erzeugter Plan hat kein eigenes `TrainingGoal`. Ein dafür erfundener Wert wäre
exakt der versteckte Default, den diese Korrektur vermeiden soll. Offene Anschlussaufgabe für P3,
sobald der zielorientierte Builder ein echtes Ziel liefert.

**Nachtrag (P2.1/P2.2-Nachbesserung) — Korrektur der Berichtssprache:** Die obige
„Implementiert"-Formulierung („dieselbe präzise, pro-Übung-genaue Prüfung ... die der
Template-Pfad bereits nutzt") beschreibt ausschließlich die KONTEXT-WEITERGABE
(`environment`/`equipmentProfile` erreichen jetzt korrekt `ProgramInstantiator.instantiate`).
Sie ist NICHT als Beleg für tatsächliche equipment-basierte Übungsauswahl/Substitution bei
generierten Plänen zu lesen — die existiert für Builder-Pläne heute nicht (siehe „Bekannte
Grenzen" Punkt 1: der synthetische Template hat keine `equipmentVariants`, die geprüft werden
könnten). Die 6 neuen Tests in `PlanGeneratorInstantiatorTests.swift` belegen ausschließlich die
korrekte `targetEnvironment`-Weitergabe, UNABHÄNGIG vom Equipment-Inhalt — nicht mehr. Diese
Lücke ist ab sofort eine eigene, verbindlich nachverfolgte Anschlussaufgabe (nicht nur eine
Fußnote): „Equipment-basierte Übungsauswahl/Substitution für generierte/Builder-Pläne real
verbinden", siehe Task-Tracking. Sie gehört zu P3/P4, nicht zu P2.1.

**Geänderte Komponenten:** `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` (`build`,
`makeTemplate`), `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` (neue `@Query`, neue
`equipmentPlanningContext`, Aufrufstelle), `Sources/FitnessAppUI/Cardio/
CardioFeasibilityCardModel.swift` (beide Aufrufstellen), `Sources/FitnessAppUI/OnboardingView.swift`
(Custom-Plan-Aufrufstelle).

**Neue/geänderte Datenfelder:** keine — reine Parameter-/Verdrahtungs-Korrektur, keine
SwiftData-Schema-Änderung.

**Tests hinzugefügt:** `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift`: neuer
`buildPlan(...)`-Test-Wrapper (neutraler Testwert nur für die 8 bestehenden, von Environment/
Equipment unabhängigen Tests — diese direkt mit-aktualisiert, da die Produktionssignatur jetzt
Pflichtparameter verlangt) plus 6 neue Tests: die Kern-Regression (expliziter Wert ≠ `.gym`) und
die 5 angeforderten Szenarien (Gym+Kurzhanteln, Home-Gym+Langhantel, Bodyweight ohne Geräte,
explizit fehlendes Equipment, unbekannte Ausstattung) — alle prüfen, dass `targetEnvironment` exakt
dem übergebenen Wert entspricht, UNABHÄNGIG vom Equipment-Inhalt (Punkt 2: Equipment ersetzt den
Trainingsort nie).

**Tests tatsächlich ausgeführt:** Linux Build (`swift build`) grün — beweist nur, dass die Datei
syntaktisch gültiges Swift enthält (Klammerbilanz etc.); der Dateiinhalt selbst steht hinter
`#if canImport(SwiftData)`/`#if canImport(SwiftUI) && canImport(SwiftData)` und kompiliert auf
diesem Linux-Toolchain zu einer effektiv leeren Übersetzungseinheit (`swift /tmp/swcheck.swift`
mit `import SwiftData` bestätigt: „no such module 'SwiftData'"; `swift test --filter
PlanGeneratorInstantiatorTests` führt nachweislich 0 Tests aus). Die neuen/geänderten Tests selbst
sind **nicht gelaufen** — weder die 8 angepassten noch die 6 neuen. Vollständiger Lauf `swift test`
— unverändert 1020/1020 (identisch zum P2.0-Nachbesserung-Stand, keine Linux-sichtbare Regression,
aber auch kein Nachweis für P2.1 selbst). Verifikation dieser Änderung
beruht ausschließlich auf manueller Zeile-für-Zeile-Prüfung gegen die tatsächlichen Deklarationen
(`UserBodyProfile.environment`/`.equipmentProfile`/`.equipmentProfileConfirmedComplete`,
`TrainingPlan.targetEnvironment`, `ProgramInstantiator.instantiate`-Parameter-Namen, `EnvironmentType`/
`UserEquipmentProfile`-Fälle) — kein Ersatz für einen echten Compiler-Lauf.

**Apple-Build/CI:** nicht durchgeführt — offen, bis ein echter Codemagic-/Xcode-Lauf vorliegt. Das
Risiko ist hier HÖHER als bei P2.0 (reiner Core-Code) und vergleichbar mit P1 (SwiftUI/SwiftData-
gegatete Dateien, auf Linux nicht prüfbar).

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Insbesondere ungeprüft: ob `PlanBuilderView`s
neue `@Query` sich mit den übrigen `@Query`/`@Environment`-Deklarationen der View verträgt (keine
doppelte Registrierung, keine Reihenfolge-Abhängigkeit), und ob ein frisch über den Builder mit
Home-Gym-Equipment erzeugter Plan auf einem echten Gerät tatsächlich mit `targetEnvironment ==
.homeGym` erscheint (Settings/Dashboard-Anzeige, Plan-Matching-Filter).

**Bekannte Grenzen/Risiken:**
1. `equipmentProfile` ändert den materialisierten Tagesinhalt eines Builder-Plans HEUTE noch nicht
   sichtbar — der synthetische Wegwerf-Template hat nie `equipmentVariants`, `bestEquipmentCheckedVariant`
   fällt deshalb mangels Alternativen immer auf die unveränderten Tage zurück (verifiziert durch
   Lesen von `PlanEquipmentCheck.swift:201-213`). Die Korrektur behebt den `targetEnvironment`-Bug
   und macht den Pfad bereit für künftige Variant-/Substitutions-Erweiterungen, ändert aber nicht
   schon heute sichtbar, WELCHE Übungen ein Builder-Plan bekommt.
2. Separater, unverändert gebliebener Fund: `PlanGeneratorInput.equipmentPreferences: Set<Equipment>`
   (Schritt-2-Checkboxen in `PlanBuilderView`) hat nachweislich (`PlanGenerator.swift` referenziert
   das Feld nirgends) schon VOR dieser Korrektur keinerlei Effekt auf die generierten Tage gehabt —
   weder auf die Auswahl noch auf irgendeine Variante. Nicht Teil dieses Tasks (nicht der
   `targetEnvironment`-Bug), aber eine eigene Aufgabe wert: entweder die Checkbox-UI entfernen
   oder sie tatsächlich mit dem Generator verbinden.
3. `profiles.first?.environment ?? .gym` in `PlanBuilderView` bleibt ein (wie bei
   `ProgramTemplatePickerView` bereits bestehender) Fallback für den strukturell unerwarteten Fall
   „kein Profil vorhanden" — sollte dieser Fall auf einem Gerät doch beobachtet werden, ist das ein
   Zeichen für ein tieferliegendes Onboarding-Problem, nicht für einen Fehler in dieser Korrektur.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** siehe P2.2-Abschlussbericht unten.

## P2.2-Abschlussbericht (TrainingGoal.endurance angehängt)

**Paket:** P2.2 — `TrainingGoal` bekommt den sechsten, additiv ans Ende angehängten Fall
`.endurance` ("Laufen & Ausdauer", Audit Konflikt 1, ENTSCHIEDEN).

**Implementiert:**
- `CoachingTypes.swift`: `case endurance` angehängt (RawValue `"endurance"`, stabil — reiht sich
  nach `.functional` ein, keine Umbenennung bestehender Fälle). `label`/`symbol`/`blurb` ergänzt
  (`"Laufen & Ausdauer"`, `"figure.run"` — dasselbe Symbol, das `TrainingTypeKind.running`/
  `CardioProfile.generalFitness` bereits durchgehend verwenden, kein neu erfundenes Icon).
- Zwei dadurch nicht mehr kompilierende, erschöpfende `switch`-Anweisungen in
  `DomainEnums+Localization.swift` (`TrainingGoal.localizedName`/`.localizedBlurb`) um
  `case .endurance` ergänzt; zwei neue Localizable.xcstrings-Keys
  `coaching.goal.endurance.label`/`.blurb` (DE/EN/TR, Katalog jetzt 2094/2094/2094/2094 Keys,
  0 hardcoded).
- **Stale-Proxy-Fund behoben:** `BaselineCheckFlowView.showsCardioStep` prüfte bisher nur
  `goal == .hybrid`, mit einem Kommentar, der wörtlich erklärte, `.hybrid` diene hier nur als
  Behelf, weil `TrainingGoal` "kein eigenes 'Lauf'-Case" kenne. Mit `.endurance` existiert dieser
  Fall jetzt wirklich — `showsCardioStep` prüft deshalb jetzt `goal == .hybrid || goal ==
  .endurance`, sonst hätte ein `.endurance`-Nutzer im Baseline-Check genau den Cardio-Schritt
  NICHT mehr gesehen, den die ursprüngliche Vorgabe für "Lauf-/Hybrid-Ziel" wörtlich verlangt.
- **Katalog-Anbindung für den Pflicht-Test:** `ProgramTemplates.swift`s `hybrid_balanced`
  ("Hybrid Athlete — Balanced") bekommt `.endurance` zusätzlich zu `.hybrid` in `targetGoals` —
  das einzige Template im Katalog mit echten Lauf-Tagen (distanz-/dauerbasiert: "Easy Run",
  "Long Run"). `PlanMatchmaker.rankPlansDetailed` behandelt `targetGoals` als Scoring-Bonus, kein
  harter Filter — andere Kandidaten bleiben für `.endurance`-Nutzer weiterhin sichtbar.
  **Nachtrag (P2.1/P2.2-Nachbesserung):** diese Tagging-Ergänzung erfüllt nur den Katalogtest
  (jedes `TrainingGoal` braucht ≥1 Template) und ist NICHT als vollständige Ausdauerlösung zu
  verstehen — `hybrid_balanced` bleibt ein Hybrid-Template mit Kraft- UND Lauf-Tagen, kein reines
  Ausdauerprogramm. Zusätzlich praktisch entschärft, solange `.endurance` ohnehin UI-seitig
  ausgeblendet ist (siehe unten).

**Automatisch mit erledigt, ohne Codeänderung (wichtig zu wissen, nicht übersehen):**
`ProfileEditorView` (Zeile ~1086) und `OnboardingView`s Coaching-Style-Schritt (Zeile ~732) iterieren
beide bereits `ForEach(TrainingGoal.allCases, ...)` dynamisch. `.endurance` erscheint dadurch **ab
sofort** als fünfte/sechste wählbare Zielkarte in BEIDEN bestehenden Oberflächen — mit echtem
Label/Icon/Blurb, nicht als Platzhalter. Das ist eine unmittelbare, sichtbare Verhaltensänderung
der bestehenden App durch diesen rein additiven Schritt, keine stille Vorbereitung für P3 — falls
`.endurance` vor dem geplanten zielorientierten P3-Einstieg noch nicht wählbar sein soll, ist das
jetzt zu entscheiden, nicht erst beim P3-Rollout.

**Nachtrag (P2.1/P2.2-Nachbesserung):** entschieden — NICHT vor P3 sichtbar. Beide `ForEach`
nutzen jetzt `TrainingGoal.currentlySelectableInUI` (eine gemeinsame Liste statt zwei
unabhaengiger Filter, siehe dortiger Bericht) statt `.allCases`; `.endurance` ist dadurch aus
beiden Oberflaechen wieder ausgeblendet, bis ein echter Ziel→Plan-Pfad existiert. Im Core bleibt
der Fall unveraendert gueltig/getestet/katalog-angebunden.

**Drei bewusst NICHT entschiedene Fragen (explizit offengelassen, keine versteckten Defaults):**
1. `PlanMatchmaker.goalIsSupportedButNotPrimaryFocus` gibt `.weightLoss` einen Sekundär-Scoring-
   Bonus auf hypertrophy-/strength-getaggte Templates ("Krafttraining hilft auch beim Abnehmen").
   Analog denkbar: ein Sekundär-Bonus für `.endurance` auf `.hybrid`-getaggte Templates, die NICHT
   explizit `.endurance` tragen (`hybrid_beginner`, `hybrid_performance` — siehe Punkt 3). Nicht
   umgesetzt — eigene Scoring-Policy-Entscheidung, nicht Teil von "anhängen".
2. `ExerciseSubstitutionRules.swift` blockt zwei lastreduzierende Ersetzungen (Kniebeuge→Goblet
   Squat, Rudern vorgebeugt→Chest Supported Row) explizit nur für `goal == .strength`. Ob
   `.endurance`-Nutzer ebenfalls ausgenommen werden sollen (Kraft-Erhalt an Nebentagen wichtig)
   oder wie jedes andere Nicht-Strength-Ziel behandelt werden (aktuelles, unverändertes Verhalten),
   ist offen — nicht verändert.
3. `CoachingMessageProvider`s Goal-Fallback-Kette fällt für fehlende `coaching.{context}.{tone}.
   {goal}`-Einträge fest auf `.hybrid` zurück. `.endurance` hat deshalb aktuell KEINEN einzigen
   dedizierten Coaching-Matrix-Eintrag und nutzt durchgehend `.hybrid`s Text. Das ist kein neuer
   Mangel: `.functional` läuft nachweislich seit seiner Einführung identisch (0 dedizierte
   `coaching.*.functional`-Einträge im gesamten Katalog, geprüft) — etabliertes, bereits
   akzeptiertes Verhalten für ein Ziel ohne eigene Matrix-Zeilen, kein Rückschritt.

   **Nachtrag (P2.1/P2.2-Nachbesserung) — Korrektur:** Die Analogie zu `.functional` war zu
   schnell gezogen. Tatsaechliche Inhaltspruefung der `.hybrid`-Fallback-Texte (z.B.
   `coaching.morningCardioDone.motivating.hybrid`: „Dein Hybrid-Ziel braucht auch Kraft — heb
   heute Abend noch etwas Eisen") zeigt: diese Texte sind nicht neutral-generisch, sondern
   schreiben aktiv Krafttraining vor — fuer ein reines Ausdauerziel inhaltlich falsch, nicht nur
   unspezifisch. Korrigiert: `CoachingMessageProvider.message(for:tone:goal:)` schliesst
   `.endurance` jetzt explizit vom `.hybrid`-Fallback aus; es faellt stattdessen auf den leeren
   String (→ UI blendet die Insight-Card aus) statt auf eine inhaltlich unpassende Empfehlung.

**Geänderte Komponenten:** `Sources/FitnessAppCore/Coaching/CoachingTypes.swift`,
`Sources/FitnessAppCore/Programs/ProgramTemplates.swift` (nur `hybrid_balanced.targetGoals`),
`Sources/FitnessAppUI/Localization/DomainEnums+Localization.swift`,
`Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift`,
`Sources/FitnessAppUI/Resources/Localizable.xcstrings`.

**Neue/geänderte Datenfelder:** keine Migration — `TrainingGoal` bleibt `String`-RawRepresentable,
`.endurance` ist rein additiv; bestehende `trainingGoalRaw`-Werte unverändert lesbar.

**Tests hinzugefügt/angepasst:** `CoachingTypesTests.testTrainingGoalCoversAllExpectedCases`
erweitert um `"endurance"`. `ProgramTemplatesTests.testEveryTrainingGoalHasAtLeastOneTemplate`
unverändert im Code, lief vor der `targetGoals`-Ergänzung nachweislich mit genau der erwarteten
Fehlermeldung durch (siehe unten) und danach grün — kein neuer Test nötig, der bestehende deckt
die Abnahme bereits ab.

**Tests tatsächlich ausgeführt — zwei unterschiedliche Vertrauensstufen, nicht vermischen:**
- **Core (`CoachingTypes.swift`, `ProgramTemplates.swift`, beide Testdateien): echte Linux-
  Kompilierung UND -Ausführung.** Vor der `targetGoals`-Ergänzung gezielt reproduziert:
  `swift test --filter testEveryTrainingGoalHasAtLeastOneTemplate` schlug exakt wie erwartet fehl
  ("TrainingGoal.endurance hat kein einziges Template — tote Quiz-Auswahl"); nach der Ergänzung
  grün. Vollständiger Lauf `swift test` — **1020/1020 Tests grün**, keine Regression.
- **UI (`DomainEnums+Localization.swift`, `BaselineCheckFlowView.swift`): NUR Syntax-Ebene
  geprüft, keine echte Kompilierung.** Beide Dateien stehen hinter `#if canImport(SwiftUI)`; direkt
  verifiziert (`swift /tmp/swuicheck.swift` mit `import SwiftUI`): „no such module 'SwiftUI'" auf
  diesem Linux-Toolchain. `swift build` meldet zwar "Compiling FitnessAppUI
  DomainEnums+Localization.swift" und build-complete, das beweist aber nur, dass die Datei
  lexikalisch gültiges Swift ist (Klammerbalance etc.) — der Dateikörper selbst wird NICHT
  semantisch geprüft (keine Typ-/Exhaustiveness-Prüfung der beiden erweiterten `switch`-
  Anweisungen). Verifikation dieser zwei Dateien beruht ausschließlich auf manueller
  Zeile-für-Zeile-Prüfung. Exakt dieselbe Einschränkung wie bei jeder P1-/P2.1-UI-Änderung dieser
  Session — hier nur erstmals für dieses konkrete Paket explizit nachgewiesen statt nur behauptet.

**Apple-Build/CI:** nicht durchgeführt — offen für die beiden UI-Dateien (höheres Risiko, siehe
oben); für `CoachingTypes.swift`/`ProgramTemplates.swift` durch echten Linux-Test bereits
abgedeckt, ein Apple-Lauf bleibt trotzdem zusätzlich sinnvoll (Integration ins Gesamt-Target).

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Insbesondere ungeprüft: erscheint die neue
Zielkarte "Laufen & Ausdauer" im Onboarding/ProfileEditor korrekt mit `figure.run`-Icon und
korrektem Text in allen drei Sprachen; führt die Auswahl zu einem sinnvollen Cardio-Schritt im
Baseline-Check; zeigt `hybrid_balanced` im Template-Picker für ein `.endurance`-Ziel plausibel an.

**Bekannte Grenzen/Risiken:** die drei offengelassenen Fragen oben; zusätzlich: `hybrid_beginner`
und `hybrid_performance` haben ebenfalls echte, teils sogar umfangreichere Lauf-Tage (3 Läufe inkl.
Intervallen bei `hybrid_performance`) und wurden bewusst NICHT mit `.endurance` getaggt — nur
`hybrid_balanced`, um die Abnahme minimal und nachvollziehbar zu erfüllen. Ob die gesamte
"Hybrid Athlete"-Familie `.endurance` tragen soll oder ob stattdessen ein eigenes, reines
Ausdauer-Template entstehen sollte (ohne Kraft-Tage), ist eine redaktionelle Katalog-Entscheidung
für später, keine Nebenwirkung dieser Korrektur.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** siehe P2.1/P2.2-Nachbesserung unten — fünf Nachschärfungspunkte, vor der
weiteren UI-Anbindung erledigt. Danach P2.3 (gemeinsamer Adopt-Pfad, darf parallel laufen).

## P2.1/P2.2-Nachbesserung (Profilkontext-Fehlerzustand, Equipment-Tracking, Ziel-UI-Gating,
sportneutrale Texte, Coaching-Fallback)

Review-Rückmeldung zu P2.1/P2.2 fand fünf Punkte, alle vor der weiteren UI-Anbindung behoben.
P2.1 bleibt als Trainingsort-Korrektur akzeptiert; die Equipment-Anpassung war und ist
ausdrücklich offen (jetzt als Task #194 verbindlich nachverfolgt, siehe Punkt 2).

**Paket:** Fünf unabhängige Korrekturen auf Code- und Berichtsebene, keine neue Funktionalität.

**Implementiert:**
1. **Expliziter Fehlerzustand statt stillem `?? .gym`-Fallback im eigenständigen Builder:**
   `PlanBuilderView.equipmentPlanningContext` liefert jetzt `EquipmentPlanningContext?` (`nil`
   ohne Profil) statt einer erfundenen `.gym`/`UserEquipmentProfile()`-Annahme. Neuer State
   `missingProfileErrorMessage: String?` plus `.alert(...)` (identisches Muster wie
   `SettingsView.resetErrorMessage`) zeigen einen echten Fehlertext
   (`planBuilder.error.noProfile.title`/`.message`, DE/EN/TR), wenn `adoptPlan()` im
   eigenständigen Modus (kein `onGenerated`-Callback) kein Profil findet, statt kommentarlos
   einen Plan mit geratenen Werten zu bauen. Der Onboarding-Callback-Pfad (`onGenerated != nil`)
   ist unverändert — er kehrt bereits vorher zurück und berührt `profiles`/
   `equipmentPlanningContext` gar nicht, braucht also kein Profil. Der bestehende, UNVERÄNDERT
   gebliebene `?? .gym`-Fallback in `ProgramTemplatePickerView` ist davon nicht betroffen — die
   Korrektur gilt für diesen NEU eingeführten Fall, nicht rückwirkend für das bereits bestehende
   Muster.
2. **Equipment-Status korrekt benannt:** siehe Nachtrag im P2.1-Bericht oben. Report-Sprache
   korrigiert, damit sie nicht als Beleg für echte equipment-basierte Übungsauswahl gelesen werden
   kann — nur Kontext-Weitergabe ist belegt. Neue, verbindlich nachverfolgte Aufgabe **Task #194**
   „Equipment-basierte Übungsauswahl/Substitution für generierte/Builder-Pläne real verbinden"
   angelegt (P3/P4-Umfeld, kein P2.1-Scope).
3. **`TrainingGoal.endurance` bleibt im Core, UI-Auswahl gegated:** neue
   `TrainingGoal.currentlySelectableInUI` (in `DomainEnums+Localization.swift`, EINE gemeinsame
   Liste statt zweier unabhängiger Filterbedingungen) schließt `.endurance` aus. Sowohl
   `OnboardingView`s Coaching-Style-Schritt als auch `ProfileEditorView`s Ziel-Picker iterieren
   jetzt über diese Liste statt `TrainingGoal.allCases` — `.endurance` ist dadurch in beiden
   Oberflächen wieder unsichtbar, bis ein echter Ziel→Plan-Pfad (P3) implementiert UND getestet
   ist. Im Core bleibt der Fall unverändert gültig, RawValue-stabil, katalog-angebunden und
   getestet. `hybrid_balanced`s `.endurance`-Tagging bleibt bestehen (erfüllt weiterhin den
   Katalogtest), wird aber jetzt explizit NICHT als vollständige Ausdauerlösung bezeichnet (siehe
   Nachtrag im P2.2-Bericht oben).
4. **Zielbeschreibung sportartneutral:** `TrainingGoal.endurance`s `label` ("Laufen & Ausdauer" →
   "Ausdauer"/"Endurance"/"Dayanıklılık") und `blurb` (lief-spezifische Formulierungen wie
   "Laufleistung"/"running performance"/"koşu" entfernt, jetzt z.B. DE: "Aerobe
   Leistungsfähigkeit und Grundlagenausdauer steigern, lange ruhige Einheiten plus gezielte
   Tempoarbeit.") in `CoachingTypes.swift` UND den entsprechenden
   `coaching.goal.endurance.label`/`.blurb`-Einträgen in `Localizable.xcstrings` (DE/EN/TR)
   umbenannt. Lauf/Radfahren/beides (`EnduranceModality`) bleiben dadurch erkennbar getrennte
   Folgeentscheidungen, keine Vorwegnahme durch den Zielnamen selbst. Keine automatische Kopplung
   an `cardioCoachingEnabled`/den Laufcoach eingeführt oder entfernt — bestand vorher nicht und
   wurde nicht neu geschaffen. Das `figure.run`-Symbol wurde **bewusst nicht geändert** — Punkt 4
   der Vorgabe betraf die Zielbeschreibung (Text), nicht das Icon, und `figure.run` hat bereits
   Präzedenz als generisches Cardio-Symbol (`CardioProfile.generalFitness` nutzt es ebenfalls,
   nicht laufexklusiv). Falls das Icon ebenfalls sportneutraler wirken soll, ist das ein separater,
   expliziter Folgeauftrag.
5. **Coaching-Fallback inhaltlich geprüft statt per Präzedenz angenommen:** `.hybrid`s tatsächliche
   Fallback-Texte direkt aus `Localizable.xcstrings` gelesen (nicht nur aus der `.functional`-
   Analogie geschlossen) — sie schreiben aktiv Krafttraining vor (Beispiel siehe Nachtrag im
   P2.2-Bericht oben), was für `.endurance` inhaltlich falsch wäre. `CoachingMessageProvider.
   message(for:tone:goal:)`s letzte Fallback-Stufe schließt `.endurance` jetzt explizit aus
   (`goal != .hybrid && goal != .endurance`); `.endurance` fällt stattdessen auf den bereits
   bestehenden leeren String zurück, der die Insight-Card UI-seitig ausblendet. Keine pauschale
   Hybrid-Zuordnung mehr für dieses Ziel.

**Bewusst NICHT umgesetzt (wie vorgegeben):** kein neuer `PlanMatchmaker`-Scoring-Bonus für
`.endurance`→Hybrid-Templates, keine neue `ExerciseSubstitutionRules`-Ausnahme für `.endurance`.
Beide bleiben die bereits in der P2.2-Nachtrag-Liste offengelassenen Fragen — fachlicher Bedarf
und betroffene Fälle sind nicht nachgewiesen, also nicht vorab implementiert.

**Geänderte Komponenten:** `Sources/FitnessAppUI/Workout/PlanBuilderView.swift`,
`Sources/FitnessAppCore/Coaching/CoachingTypes.swift`,
`Sources/FitnessAppUI/Localization/DomainEnums+Localization.swift`,
`Sources/FitnessAppUI/OnboardingView.swift`, `Sources/FitnessAppUI/Settings/ProfileEditorView.swift`,
`Sources/FitnessAppUI/Coaching/CoachingMessageProvider.swift`,
`Sources/FitnessAppUI/Resources/Localizable.xcstrings`, `docs/PLANUNG_BEGLEITUNG_AUDIT.md`.

**Neue/geänderte Datenfelder:** keine SwiftData-Schema-Änderung. Zwei neue Lokalisierungs-Keys
(`planBuilder.error.noProfile.title`/`.message`), zwei umbenannte (`coaching.goal.endurance.label`/
`.blurb` — Key-Namen unverändert, nur Werte).

**Bekannter, bewusst ungelöster Randfall:** sollte ein bestehendes `UserBodyProfile.trainingGoal`
jemals `.endurance` sein (aktuell nicht erreichbar, da `.endurance` nirgends auswählbar ist und
nicht automatisch vergeben wird), zeigt `ProfileEditorView`s Picker keine zu `.endurance`
passende Option mehr an (`.tag(.endurance)` fehlt in der gefilterten Liste) — SwiftUI würde die
Auswahl dann leer/nicht übereinstimmend darstellen. Bewusst nicht zusätzlich abgesichert: der Fall
ist mit aktuellem Code nicht erreichbar, eine Behandlung dafür wäre Komplexität ohne reales
Szenario. Festzuhalten, nicht zu verschweigen.

**Tests hinzugefügt:** keine neuen Tests in diesem Nachbesserungs-Schritt — alle fünf Punkte sind
entweder reine UI-Gating-/Text-/Fehlerzustand-Änderungen (nicht sinnvoll Linux-testbar, da
SwiftUI-gated) oder Report-Sprache-Korrekturen ohne Codeverhalten-Änderung. Die bestehenden
Core-Tests (`CoachingTypesTests`, `ProgramTemplatesTests`) decken `.endurance`s Katalog-/RawValue-
Vertrag unverändert ab.

**Tests tatsächlich ausgeführt — zwei Vertrauensstufen, nicht vermischen:**
- **Core:** `swift build`/`swift test` erneut ausgeführt (siehe unten für Zahl) — bestätigt, dass
  die `label`/`blurb`-String-Änderungen in `CoachingTypes.swift` syntaktisch UND semantisch korrekt
  sind (Core wird auf Linux echt kompiliert), keine Regression in den 1020 bestehenden Tests.
- **UI** (`PlanBuilderView.swift`, `DomainEnums+Localization.swift`, `OnboardingView.swift`,
  `ProfileEditorView.swift`, `CoachingMessageProvider.swift`): NUR Syntax-Ebene via `swift build`
  geprüft (Datei lexikalisch gültiges Swift — Klammerbalance etc.), KEINE semantische Prüfung
  (kein Typecheck, keine Exhaustiveness-Prüfung), da alle fünf Dateien hinter
  `#if canImport(SwiftUI)` stehen und auf diesem Linux-Toolchain zu einer leeren
  Übersetzungseinheit kompilieren (wiederholt verifiziert: `swift /tmp/swcheck.swift` mit
  `import SwiftUI` → „no such module 'SwiftUI'"). Verifikation dieser fünf Dateien beruht
  ausschließlich auf manueller Zeile-für-Zeile-Prüfung (korrekte Klammerschachtelung in
  `DomainEnums+Localization.swift` gezielt nachgelesen).
- `Localizable.xcstrings`: JSON-Validität und Key-Anzahl nach den Edits geprüft (siehe unten).

**Apple-Build/CI:** nicht durchgeführt — offen, unverändert höheres Risiko für alle fünf
UI-Dateien dieser Nachbesserung.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Insbesondere ungeprüft: zeigt der neue Alert in
`PlanBuilderView` den Fehlertext korrekt an und blockiert zuverlässig die Plan-Erstellung;
verschwindet "Ausdauer" tatsächlich aus beiden Zielkarten-Oberflächen; zeigt die Insight-Card für
ein (aktuell nicht erreichbares) `.endurance`-Profil tatsächlich den Empty-State statt eines
Absturzes.

**Bekannte Grenzen/Risiken:** siehe die vier Nachträge oben (P2.1- und P2.2-Bericht) plus der
Picker-Randfall oben. Zusätzlich: Task #194 ist angelegt, aber nicht terminiert — die
Equipment-Substitutions-Lücke bleibt bis zur tatsächlichen Umsetzung bestehen.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** P2.3 (gemeinsamer Adopt-Pfad) — darf wie vorgegeben parallel zu allem oben
laufen. Apple-Build und die betroffenen SwiftData-/UI-Tests bleiben für P1, P2.1 und diese
Nachbesserung gemeinsam offen, bis ein echter Lauf vorliegt.

## P2.3-Abschlussbericht (gemeinsamer Adopt-Pfad)

**Paket:** P2.3 — vier bisher unabhängig geschriebene Resolve+Build-Kopien
(`OnboardingView.finishOnboarding`, `CardioFeasibilityCardModel.accept`/`.acceptCustom`,
`PlanBuilderView.adoptPlan()`) auf EINEN gemeinsamen Einstiegspunkt konsolidiert. Zusätzlich
parallel erledigt: Picker-Fix für ein bestehendes `.endurance`-Profil (eigener Abschnitt unten).

**Vorab geklärt — vier bewusst unterschiedene Pfade, keine Vereinheitlichung zu einem einzigen
generischen "Adopt":**
1. **Onboarding-Entwurf** (`PlanBuilderView(onGenerated:)`): unverändert — liefert
   `PlanGeneratorInput`/`PlanGenerator.Result` nur per Closure zurück, ruft nichts aus
   `PlanGeneratorInstantiator` auf. Persistenz passiert ausschließlich in `finishOnboarding()`.
   Verifiziert durch Code-Lesen: der `onGenerated`-Zweig in `adoptPlan()` kehrt vor jedem
   Datenbankzugriff zurück.
2. **Neuen Plan erstellen**: neues `PlanGeneratorInstantiator.createPlan(from:result:for:
   generationSource:in:)` — bündelt die vorher vierfach kopierte
   `EquipmentPlanningResolver.resolve(...)`+`build(...)`-Sequenz an einer Stelle. Nimmt bewusst ein
   `UserBodyProfile` entgegen statt vorab aufgelöster Werte — das Finden/Fehlen eines Profils bleibt
   Verantwortung des Aufrufers (z.B. `PlanBuilderView`s `missingProfileErrorMessage`-Alert aus der
   letzten Nachbesserung), die Funktion selbst sucht/errät kein Profil.
3. **Bestehenden Plan kontrolliert aktualisieren**: `PlanGeneratorInstantiator.recalculate(_:in:)` —
   unverändert in seiner Kernlogik (nur unangetastete Tage), zusätzlich um einen Schutz gegen
   laufende Sessions ergänzt (siehe unten).
4. **Bewusst eine neue Kopie erstellen**: `PlansListView.duplicatePlan(_:)` — unverändert, nur mit
   Querverweis-Kommentar versehen. Bewusst NICHT in den Service verschoben: es gibt dort nur eine
   einzige Implementierung, ein Umzug wäre Umbau ohne behobene Duplikation.

**Implementiert:**
- `PlanGeneratorInstantiator.createPlan(from:result:for:generationSource:in:)` (neu) — löst
  Equipment einmal über `EquipmentPlanningResolver.resolve(...)` auf und delegiert an das
  bestehende `build(...)`. Ersetzt die separaten Resolve+Build-Sequenzen in allen vier Aufrufern.
- `CardioFeasibilityCardModel.accept`/`.acceptCustom`: rufen jetzt `createPlan(for:)` statt der
  bisherigen Inline-Sequenz. Rückgabetyp/Verhalten für deren eigene Aufrufer unverändert.
- `PlanBuilderView.adoptPlan()`: eigenständiger Zweig ruft `createPlan(for:)`; die jetzt überflüssige
  eigene `equipmentPlanningContext`-Berechnung wurde entfernt (totes Duplikat nach der Umstellung).
- `OnboardingView.finishOnboarding()`: Custom-Plan-Zweig ruft `createPlan(for:)` mit dem gerade
  erst angelegten, zu diesem Zeitpunkt bereits vollständig befüllten `profile` — identische Werte
  wie das vorherige `equipmentPlanningContext.effectiveProfile`, nur einmalig statt separat
  aufgelöst. Der Template-Zweig (`ProgramInstantiator.instantiate` mit `ResolvedPlanSelection`)
  ist NICHT Teil dieser Konsolidierung — andere Mechanik, nicht einer der vier ursprünglich
  genannten Call-Sites.
- **Verantwortungs-Vertrag festgelegt** (Typ-Dokumentation in `PlanGeneratorInstantiator.swift`):
  keiner der vier Pfade speichert/aktiviert/schließt/navigiert über das hinaus, was
  `ProgramInstantiator.instantiate` schon immer als Seiteneffekt hatte (alte Pläne deaktivieren,
  neuen Plan aktiv anlegen — unverändertes Bestandsverhalten, keine neue Policy). Schließen,
  Navigieren und Fehleranzeige bleiben explizit beim jeweiligen Aufrufer.
  **Nachtrag (P2.3-Nachbesserung, Punkt 5 — Korrektur):** diese Formulierung war zu glatt — sie
  konnte so gelesen werden, als sei der Aktivierungs-Vertrag damit abschließend geklärt. Ist er
  NICHT: die automatische Deaktivieren-alles/Aktivieren-neu-Policy ist fuer das HEUTIGE
  Ein-aktiver-Plan-Modell akzeptabel, aber ausdruecklich NICHT fuer alle Zukunft entschieden — ein
  spaeterer Wocheneditor wird vermutlich eine AUSDRUECKLICHE Aktivierungsentscheidung brauchen.
  Offen gehalten, nicht geloest — siehe Typ-Doku in `PlanGeneratorInstantiator.swift` fuer die
  vollstaendige Begruendung.
- **Doppel-Bestätigung-Schutz** (Abnahme-Punkt "keine Duplikate bei mehrfacher Bestätigung"): fünf
  neue `@State`-Flags mit Guard-am-Funktionsanfang + `.disabled(...)`, da alle beteiligten Aktionen
  synchron ohne `await` laufen und ein zweiter Tap vor der sichtbaren UI-Reaktion sonst doppelt
  ausgelöst hätte:
  - `PlanBuilderView.isAdopting` — deckt sowohl den eigenständigen Adopt- als auch (da derselbe
    Button) den `onGenerated`/`acceptCustom`-Weg über "Plan anpassen"-Sheets ab.
  - `OnboardingView.isFinishingOnboarding` — sitzt IN `finishOnboarding()` selbst, weil die
    Funktion zwei unabhängige Auslöser hat (Haupt-Button UND `DayPickerSheet.onConfirm`).
  - `PlansListView.isAcceptingCardioFeasibility` / `ProfileEditorView.isAcceptingCardioFeasibility`
    — je eine Instanz für den jeweils eigenen direkten "Übernehmen"-Button (der NICHT über
    `PlanBuilderView` läuft, daher ein eigener Schutz nötig).
- **Schutz laufender Sessions in `recalculate`** (Abnahme-Punkt "keine Veränderung laufender
  Sessions", beim Umsetzen gefunden, nicht vorab bekannt): Starten/Ausführen eines Workouts ändert
  weder `generationFingerprint` noch `currentContentFingerprint` (beide beschreiben nur die
  Plan-STRUKTUR) — ein Tag mit einer laufenden Session hätte die bisherige Prüfung also
  unverändert durchlaufen, woraufhin `apply(...)` seine Exercise-Zeilen gelöscht und neu angelegt
  hätte. ~~Neuer Guard `hasActiveSession(for:in:)` (... `#Predicate<WorkoutSession> { $0.isCompleted
  == false }` ...)~~ **durch die P2.3-Nachbesserung ersetzt — siehe dortiger Bericht:** sowohl der
  Fetch-Fehlerpfad als auch der Schutzumfang (nur laufend vs. jede Session) waren unzureichend.

**Bewusst NICHT umgesetzt (wie vorgegeben):** `duplicatePlan` nicht in den Service verschoben
(siehe oben); keine neue, fünfte Persistenz-Variante; kein neuer `PlanMatchmaker`-Scoring-Bonus,
keine neue `ExerciseSubstitutionRules`-Ausnahme. Task #194 (Equipment-Substitution für generierte
Pläne) bleibt unverändert offen — P2.3 hat daran nichts repariert oder verschoben, die Lücke ist
weiterhin sichtbar und nachverfolgt.

**Geänderte Komponenten:** `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` (`createPlan`,
`recalculate`-Guard, `hasActiveSession`), `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift`,
`Sources/FitnessAppUI/Workout/PlanBuilderView.swift`, `Sources/FitnessAppUI/OnboardingView.swift`,
`Sources/FitnessAppUI/Workout/PlansListView.swift` (Doppel-Tap-Schutz + Querverweis-Kommentare),
`Sources/FitnessAppUI/Settings/ProfileEditorView.swift` (Doppel-Tap-Schutz).

**Neue/geänderte Datenfelder:** keine — reine Verdrahtungs-/Schutz-Korrektur, keine
SwiftData-Schema-Änderung.

**Tests hinzugefügt:** `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift`:
`testCreatePlanResolvesEnvironmentFromProfile`, `testCreatePlanReturnsNilWhenGeneratorProducesNoDays`
(neuer Einstiegspunkt, gleiche Garantien wie die bestehenden `build`-Tests).
**Nachtrag (P2.3-Nachbesserung):** `testRecalculateSkipsDayWithActiveSession` und
`testRecalculateReplacesExercisesButPreservesHistoricalLog` waren unzureichend/falsch (Letzterer
bewies nur "Zeile nicht gelöscht", nicht "Historie unverändert") und wurden durch
`testRecalculateSkipsDayWithActiveSessionAndReportsIt`,
`testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact`,
`testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned`,
`testRecalculateThrowsAndChangesNothingWhenSessionCheckFails` und
`testRecalculateSucceedsNormallyWithoutOverride` ersetzt/ergänzt — siehe P2.3-Nachbesserung-Bericht
unten für die vollständige Begründung.

**Tests tatsächlich ausgeführt — WICHTIG, anders als bei P2.1/P2.2: P2.3 berührt KEINE einzige
Core-Datei.** Jede Änderung dieses Pakets liegt in `FitnessAppData`/`FitnessAppUI` — beide
Dateien UND beide neuen Testdateien stehen hinter `#if canImport(SwiftData)`
(teils zusätzlich `canImport(SwiftUI)`) und werden auf diesem Linux-Toolchain NICHT geparst/
typgeprüft (nachweislich: `swift build`/`swift build --build-tests` melden "Build complete", aber
`import SwiftData` schlägt separat nachweislich mit "no such module 'SwiftData'" fehl — ein
inaktiver `#if`-Zweig wird vom Compiler nur auf gültige Tokens, NIE auf Typkorrektheit geprüft).
Insbesondere UNGEPRÜFT: die exakten Parameternamen/-typen von `WorkoutSession.init`/
`ExerciseLog.init`/`UserBodyProfile.init` (gegen den tatsächlichen Dateiinhalt abgeschrieben, aber
nicht kompiliert), die Korrektheit des neuen `#Predicate`-Ausdrucks in `hasActiveSession`, und ob
`createPlan(for:)`s Signatur an allen vier Aufrufstellen wirklich passt. Einzige echte
Linux-Verifikation in dieser Runde bleibt das bereits separat berichtete `CoachingTypesTests`
(Picker-Fix, Core). Vollständiger Lauf `swift test` — **1023/1023 grün** (1020 + die 3 neuen
`CoachingTypesTests` aus dem Picker-Fix), keine Regression unter den tatsächlich ausgeführten
Tests — das ist kein Nachweis für P2.3 selbst.

**Apple-Build/CI:** nicht durchgeführt — offen, und für dieses Paket mit HÖHEREM Gewicht als
üblich: anders als P2.1/P2.2 gibt es hier keinen Core-Anteil, der die Grundmechanik bereits absichert.
Der `#Predicate`/`persistentModelID`-Ausdruck in `hasActiveSession` ist die riskanteste einzelne
neue Zeile dieser Runde.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Insbesondere zu prüfen:
1. Doppel-Tap auf "Plan übernehmen"/"Fertig"/"Übernehmen" erzeugt tatsächlich nur einen Plan.
2. "Neu rechnen" an einem Tag mit laufendem (gestartetem, nicht beendetem) Workout überspringt
   diesen Tag tatsächlich und zeigt dem Nutzer das nachvollziehbar an (aktuell: stiller Skip, keine
   eigene UI-Meldung dafür — offene Frage, ob das reicht oder ein Hinweis noetig ist, siehe Grenzen).
3. Alle vier Aufrufer von `createPlan(for:)` erzeugen weiterhin denselben `targetEnvironment`/
   `isActive`-Zustand wie vor der Umstellung (Verhaltensgleichheit, kein Soll-Ist-Vergleich bisher
   auf echtem Gerät gemacht).

**Bekannte Grenzen/Risiken:**
1. ~~`recalculate` zeigt dem Nutzer aktuell KEINE explizite Meldung ...~~ **behoben in der
   P2.3-Nachbesserung:** `RecalculateSummary.skippedDueToHistoryCount` wird jetzt im
   `PlanEditorView`-Toast explizit genannt ("sichtbar erklärt", siehe dortiger Bericht).
2. Code-Lesen zeigt `PlanGeneratorInstantiator.recalculate` als vollständig implementiert, aber
   KEINEN verifizierten UI-Button, der es aufruft, außer dem bereits bestehenden Verweis in
   `PlanEditorView.swift:386` (nicht Teil dieser Änderung, nur mitgelesen) — ob "neu rechnen" heute
   tatsächlich erreichbar ist und wie, wurde in dieser Runde nicht erneut end-to-end geprüft.
3. Atomizität ("keine unvollständigen Änderungen bei Fehlern"): `ProgramInstantiator.instantiate`
   läuft synchron ohne Rücksprung nach `context.insert(plan)`, bis alle Tage/Übungen angelegt sind
   (verifiziert durch Lesen) — strukturell atomar auf Code-Ebene. Echte Persistenz-Atomizität
   (Absturz zwischen zwei `context.insert`-Aufrufen vor dem naechsten Autosave) ist
   SwiftData-Framework-Verhalten, außerhalb der Kontrolle dieses Codes, und auf Linux nicht
   prüfbar.
   **Nachtrag (P2.3-Nachbesserung, Punkt 4 — Korrektur):** "synchroner Code" war als Beleg zu
   stark formuliert — es beweist nur, dass DIESE Funktion keine halbe Graph-Konstruktion
   zurueckgibt, NICHT echte Festschreibungs-Atomizitaet. Commit-Verantwortung jetzt explizit in
   der Typ-Doku von `PlanGeneratorInstantiator.swift` benannt: niemand hier ruft `context.save()`,
   Autosave entscheidet Zeitpunkt/Fehlerbehandlung, und ausdrücklich KEIN `context.rollback()` als
   Fix — das würde unabhängige, bereits bestätigte Änderungen auf demselben geteilten Context mit
   zerstören. Siehe P2.3-Nachbesserung-Bericht unten.
4. Die fünf Doppel-Tap-Guards sind einfache `@State`-Flags, kein Test kann einen echten
   Doppel-Tap auf Linux simulieren (kein SwiftUI) — die Abnahme-Garantie dafür ist Code-Review-
   Qualität, keine automatisierte.
5. Task #194 (Equipment-Substitution) bleibt unverändert offen — explizit sichtbar gehalten, wie
   gefordert.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** siehe P2.3-Nachbesserung unten — fünf Schutzlücken, vor Abnahme von P2.3
behoben.

## P2.3-Nachbesserung (Fetch-Fail-Safe, konservativer Historien-Schutz, Übernahme-Ergebnis,
Commit-/Aktivierungsvertrag)

Review-Rückmeldung zu P2.3 fand fünf Schutzlücken, alle vor Abnahme behoben. P2.4 durfte laut
Vorgabe parallel als reine Draft-/Core-Arbeit weiterlaufen, wurde in dieser Runde aber nicht
begonnen (Fokus auf die fünf Punkte).

**Paket:** fünf unabhängige Korrekturen an Code, Tests und Berichtssprache, keine neue
Funktionalität.

**Implementiert:**

1. **Fetch-Fehler darf nicht als "keine Session" gelten:** `recalculate`s Schutzpfad nutzte
   `(try? context.fetch(...)) ?? []` — ein echter Fetch-Fehler wäre damit still als "keine Session
   vorhanden" gewertet worden und `apply(...)` hätte ungebremst weiterlaufen können. Korrigiert:
   ein einziger `try fetchAllSessions(in: context)`-Aufruf GANZ AM ANFANG von `recalculate`, VOR
   jeder Mutation (nicht mehr pro Tag in der Schleife); schlägt er fehl, wirft die Funktion
   `PlanGeneratorInstantiator.RecalculateError.sessionCheckFailed`, OHNE auch nur einen Tag
   anzufassen (strukturell garantiert: die erste moegliche Mutation steht erst nach dieser
   Zeile). `PlanEditorView.recalculateFromGenerator()` faengt das jetzt ab und zeigt einen
   verständlichen Fehler-Toast ("Neu rechnen fehlgeschlagen — keine Änderung vorgenommen")
   statt eines stillen No-Ops oder einer falschen Erfolgsmeldung. Testbarkeit: neuer DI-Seam
   `PlanGeneratorInstantiator.fetchAllSessionsOverrideForTesting` (statischer Override, `nil` =
   unverändertes Verhalten), exaktes Vorbild `BackupService.backupsDirectoryOverride` — dieselbe,
   bereits im Projekt etablierte Konvention statt einer neu erfundenen Closure-Parameter-DI.
2. **Historientest war kein Beweis für unveränderte Historie — korrigiert, nicht nur das
   Testergebnis angepasst:** die vorherige Behauptung "`ExerciseLog`-Zeile wird nicht gelöscht,
   nur `.exercise` wird `nil`" ist technisch richtig, aber kein Beleg für "Historie unverändert".
   Tatsächlich geprüft (neuer Test `testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned`):
   `ExerciseLog.resolvedExerciseName`/`.resolvedIsCardio`/`.resolvedIsTimeBased` überleben einen
   Exercise-Delete korrekt über eigene Snapshot-Felder (bereits bestehender, dokumentierter
   Mechanismus) — ABER `cnsFatigueScore`/`localMuscleDamageScore` (reine Auswertung, kein
   Snapshot) fallen MESSBAR auf `0.0` zurück, sobald `exercise == nil` ist. Ein Tag, der auch nur
   einmal trainiert wurde, hätte durch "neu rechnen" also echte Recovery-/Fatigue-Auswertung
   verloren, nicht nur eine Code-Zeile. Korrektur: `recalculate` überspringt jetzt JEDEN Tag mit
   IRGENDEINER Session (abgeschlossen ODER laufend), nicht mehr nur laufende — konservativ, bis es
   eine Inhalts-/Versionsabsicherung dafür gibt (P5). Sichtbar erklärt statt stillschweigend:
   `RecalculateSummary.skippedDueToHistoryCount` wird im `PlanEditorView`-Toast explizit genannt
   ("N Tage neu berechnet, M wegen bestehender Trainingshistorie übersprungen").
3. **Übernahme-Ergebnis jetzt ausdrücklich behandelt:** `CardioFeasibilityCardModel.accept`/
   `.acceptCustom` setzten `cardioGoal`/`cardioFeasibilityDismissedFingerprint` bisher
   UNCONDITIONAL nach dem `createPlan`-Aufruf, auch wenn dieser `nil` zurückgab — ein Fehlschlag
   hätte dann wie eine erfolgreiche Annahme ausgesehen (Fingerprint gesetzt → Karte verschwindet →
   kein Plan existiert, keine Wiederholung möglich, ohne dass der Nutzer das bemerkt). Beide
   Funktionen schreiben diese Felder jetzt NUR noch bei tatsächlichem Erfolg (`guard let plan =
   ... else { return nil }` VOR den Profil-Mutationen). Die beiden direkten "Übernehmen"-Buttons
   (`PlansListView`, `ProfileEditorView`) setzen ihr `isAcceptingCardioFeasibility`-Flag im
   Fehlerfall jetzt zurück, damit der Button nach einem Fehlschlag wieder bedienbar ist
   (Wiederholung möglich) statt dauerhaft gesperrt zu bleiben. Hinweis zur Testbarkeit: der
   Fehlerpfad ist mit den heutigen Aufrufern strukturell UNERREICHBAR (`hasPlan`/
   `!result.days.isEmpty` garantieren an der Call-Site bereits ein nicht-leeres Ergebnis, und das
   ist `build`s EINZIGER nil-Rückgabepfad, verifiziert durch Lesen) — die Korrektur ist eine
   defensive Vertragskorrektur (dieselbe Disziplin wie überall sonst in
   `PlanGeneratorInstantiator`), kein Fix für einen heute beobachtbaren Bug. Kein künstlicher
   Test-Seam dafür eingebaut, um keinen unreachable Pfad vorzutäuschen.
4. **Commit-Verantwortung ehrlich dokumentiert statt Atomizität behauptet:** neuer Abschnitt in
   `PlanGeneratorInstantiator.swift`s Typ-Dokumentation legt explizit fest: keine Funktion in
   dieser Datei ruft `context.save()`; Zeitpunkt und Fehlerbehandlung der tatsächlichen
   Festschreibung liegen vollständig bei SwiftDatas Autosave (unverändert zu jedem anderen
   Adopt-Pfad der App). "Synchroner Code ohne Rücksprung nach dem ersten Insert" bewiest NUR, dass
   `build`/`instantiate` keine halbe Graph-Konstruktion zurückgeben — KEIN Nachweis echter
   Festschreibungs-Atomizität. Ausdrücklich NICHT eingebaut: ein eigener `context.save()` hier,
   und erst recht kein `context.rollback()` bei einem Fehler — Letzteres wirkt auf den GESAMTEN
   geteilten `ModelContext` und würde unabhängige, andernorts bereits bestätigte Änderungen (z.B.
   ein offenes Edit auf einem anderen Screen mit demselben `modelContext`) mit zerstören. Echte
   Speicherfehler-Behandlung für genau diese Operation wäre eine eigene, sorgfältig geschnittene
   Aufgabe — **Task #197 angelegt**, nicht Teil von P2.3/dieser Nachbesserung.
5. **Aktivierungsvertrag ehrlich benannt statt als gelöst berichtet:** Typ-Dokumentation korrigiert
   — die automatische Deaktivieren-alles/Aktivieren-neu-Policy (über `ProgramInstantiator.
   instantiate`, unverändertes Bestandsverhalten) ist für das HEUTIGE Ein-aktiver-Plan-Modell
   akzeptabel, aber AUSDRÜCKLICH NICHT für alle Zukunft entschieden. Ein späterer Wocheneditor wird
   vermutlich eine AUSDRÜCKLICHE Aktivierungsentscheidung brauchen (z.B. "nur speichern, Plan nicht
   wechseln" vs. "jetzt aktiv schalten") statt der heutigen impliziten Alles-oder-nichts-Automatik.
   Keine Code-Änderung — reine Berichts-/Dokumentations-Korrektur, damit diese Frage nicht
   fälschlich als bereits entschieden gilt.

**Bewusst NICHT umgesetzt:** P2.4 wurde in dieser Runde nicht begonnen (Vorgabe erlaubte es
parallel, forderte es nicht). Keine neue UI-Übernahme-Funktionalität auf P2.3 aufgebaut, wie
vorgegeben.

**Geänderte Komponenten:** `Sources/FitnessAppData/PlanGeneratorInstantiator.swift`
(`RecalculateError`, `RecalculateSummary`, `fetchAllSessions`, `recalculate` neu gefasst,
Typ-Doku-Korrekturen), `Sources/FitnessAppUI/Workout/PlanEditorView.swift`
(`recalculateFromGenerator` auf `throws`/`RecalculateSummary` umgestellt, Fehler-/Skip-Toast),
`Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift` (`accept`/`acceptCustom` guard-on-
success), `Sources/FitnessAppUI/Workout/PlansListView.swift` + `Sources/FitnessAppUI/Settings/
ProfileEditorView.swift` (Flag-Reset im Fehlerfall).

**Neue/geänderte Datenfelder:** keine SwiftData-Schema-Änderung. Öffentliche API-Änderung:
`recalculate(_:in:)` ist jetzt `throws` und liefert `RecalculateSummary` statt `Int` — der einzige
bekannte Aufrufer (`PlanEditorView.swift`) wurde mitgezogen.

**Tests hinzugefügt/korrigiert:** `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift`:
`testRecalculateThrowsAndChangesNothingWhenSessionCheckFails` (Punkt 1: Fetch-Fehler → Wurf, keine
Mutation, via DI-Seam erzwungen), `testRecalculateSucceedsNormallyWithoutOverride` (Gegenprobe:
Erfolgspfad unverändert), `testRecalculateSkipsDayWithActiveSessionAndReportsIt` (laufende Session
→ übersprungen UND sichtbar gemeldet), `testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact`
(ERSETZT den vorherigen, unzureichenden Test — eine abgeschlossene Session blockiert jetzt
EBENFALLS, Log bleibt vollständig intakt statt nur "überlebend-aber-verwaist"),
`testExerciseLogDegradesScoringButKeepsIdentityOnceOrphaned` (direkter Beleg für die Punkt-2-
Begründung: Identität übersteht Exercise-Delete, Auswertung nicht). Außerdem die vier bestehenden
`recalculate`-Tests auf die neue `throws`/`RecalculateSummary`-Signatur umgestellt (keine
Verhaltensänderung an sich, nur Signatur-Anpassung).

**Tests tatsächlich ausgeführt — unverändert zur P2.3-Einschränkung:** alle Änderungen dieser
Runde liegen erneut in `FitnessAppData`/`FitnessAppUI`, NICHTS in Core. Jede neue/geänderte Zeile
ist deshalb NUR syntaktisch via `swift build`/`swift build --build-tests` geprüft, NICHT
typgeprüft — identische Einschränkung wie im P2.3-Bericht oben, hier nicht erneut ausführlich
wiederholt. Insbesondere ungeprüft: ob `XCTAssertEqual(error as? PlanGeneratorInstantiator.
RecalculateError, .sessionCheckFailed)` wirklich so kompiliert (Optional-Promotion eines
Enum-Falls in einem generischen `XCTAssertEqual`-Aufruf — gaengiges, aber nicht auf diesem
Toolchain verifizierbares Swift-Muster), ob der neue DI-Seam-Override tatsächlich greift, und ob
`RecalculateSummary`s automatisch generierter (nicht explizit `public` deklarierter)
Memberwise-Initializer über `@testable import` wirklich wie erwartet nutzbar ist. Vollständiger
Lauf `swift test` — **1023/1023 grün** (unverändert zur letzten Runde, da alle neuen Tests dieser
Nachbesserung in der nicht-ausgeführten `FitnessAppDataTests`-Gruppe liegen) — kein Nachweis für
diese Nachbesserung selbst.

**Apple-Build/CI:** nicht durchgeführt — offen, unverändert höheres Gewicht als sonst (siehe
P2.3-Bericht oben), hier zusätzlich: der neue `throws`/`RecalculateSummary`-Vertrag und der
DI-Seam sind komplett ungeprüfter Neuzugang.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Zusätzlich zu den P2.3-Punkten oben: zeigt der
neue Fehler-Toast bei einem simulierten Fetch-Fehler tatsächlich den vorgesehenen Text; zeigt der
"N Tage neu berechnet, M übersprungen"-Toast bei einem Tag mit Trainingshistorie tatsächlich
beide Zahlen korrekt; wird der direkte "Übernehmen"-Button nach einem (heute unerreichbaren, aber
fuer eine zukünftige Code-Änderung relevanten) Fehlschlag tatsächlich wieder bedienbar.

**Bekannte Grenzen/Risiken:**
1. Task #197 (Commit-/Speicherfehler-Behandlung für Plan-Erstellung/-Aktualisierung) ist angelegt,
   aber nicht terminiert — die Lücke bleibt bis zur tatsächlichen Umsetzung bestehen, wie bei
   Task #194.
2. Der Aktivierungsvertrag für einen späteren Wocheneditor ist weiterhin offen — diese
   Nachbesserung macht das nur sichtbar, löst es nicht.
3. `recalculate`s konservativer Historien-Schutz (Punkt 2) bedeutet: SOBALD ein Tag einmal
   trainiert wurde, "neu rechnen" betrifft ihn nie wieder, auch nicht nach Monaten — das ist eine
   bewusste, aber spürbare Einschränkung der Funktion, bis P5 (Versionierung) eine echte Lösung
   liefert. Nutzer-Erwartung ("ich habe nur mal trainiert, warum wird der Tag nie wieder
   aktualisiert") ist nicht durch UI-Text abgefedert außer dem Toast-Hinweis.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** siehe P2.3-Nacharbeiten unten — ein fehlerhafter Test und fehlende
Lokalisierung, vor dem Start von P2.4 noch zu erledigen.

## P2.3-Nacharbeiten (Testfix, Lokalisierung, Abhängigkeiten verbindlich)

**Paket:** zwei konkrete Korrekturen plus verbindliche Dokumentation von Abhängigkeiten/
Aktivierungs-Prinzip für künftige Arbeit. Keine Verhaltensänderung an `recalculate` selbst.

**Implementiert:**

1. **Testfix `testRecalculateSucceedsNormallyWithoutOverride` (Review-Fund):** der Test erwartete
   `rewrittenCount: 0` für einen frisch gebauten, unveränderten Plan — falsch. Ein frisch gebauter
   Tag hat exakt den Fingerprint, den `build` ihm gerade gegeben hat; das ist per Vertrag
   ("ersetzt NUR unangetastete Tage") genau der Fall, der NEU GESCHRIEBEN wird, nicht übersprungen.
   Ein passender Fingerprint ERLAUBT das Überschreiben, er verhindert es nicht — nur ein
   ABWEICHENDER Fingerprint (echter User-Edit) blockiert. Korrigiert: der Test erwartet jetzt
   `rewrittenCount: workoutDayCount` (alle Tage), konsistent mit
   `testRecalculateSkipsDayWithEditedExerciseSets`, die das Gegenteil bereits richtig testete.
   Keine Code-Änderung an `recalculate` — wie vorgegeben, der Test war falsch, nicht das Verhalten.
2. **Vollständige Lokalisierung der neuen Toasts:** die vier Toast-Varianten in
   `PlanEditorView.recalculateFromGenerator()` waren hartcodiert Deutsch (Regression gegen die
   sonst durchgehend eingehaltene "0 hardcoded strings"-Disziplin dieses Projekts). Sechs neue
   Catalog-Keys (`planEditor.recalculate.toast.none/.failed/.rewritten.one/.rewritten.other/
   .skipped.one/.skipped.other`, DE/EN/TR, Katalog jetzt 2102 Keys, weiterhin 0 hardcoded).
   Pluralisierung folgt dem bestehenden, bewusst manuellen `.one`/`.other`-Namespace-Muster
   (`PlansListView.pluralizedCount`/`WorkoutSummaryView.formatBreakdownFooter`) — AUSDRÜCKLICH
   NICHT xcstrings' native `variations.plural`, an denen Xcode 26.4.1s `GenerateStringSymbols`
   nachweislich scheitert (DEL-121 Build-Saga, bereits vor dieser Session dokumentiert). Neuer
   lokaler Helper `pluralizedRecalculateToast(_:count:)`, bewusst dupliziert statt geteilt (gleiche
   Begründung wie die beiden Vorbilder: ein gemeinsamer Helper für so wenige Aufrufstellen lohnt
   keinen dritten Ort). Der kombinierte Fall (Tage neu berechnet UND Tage übersprungen) setzt sich
   jetzt aus zwei unabhängig korrekt pluralisierten Teilsätzen zusammen statt der vorherigen
   Inkonsistenz (ein Zweig pluralisierte "Tag/Tage" für die übersprungene Zahl, der andere nicht).
3. **Abhängigkeiten verbindlich dokumentiert** (Typ-Doku `PlanGeneratorInstantiator.swift`,
   Task #197 aktualisiert):
   - Task #197 (Commit-/Speicherfehler-Behandlung) muss VOR einer finalen
     Wocheneditor-Übernahmefunktion gelöst sein — das wäre die erste Stelle, an der ein
     Speicherfehler für den Nutzer sichtbare Konsequenzen hätte.
   - Apple-Kompilierung und die betroffenen SwiftData-Tests bleiben Voraussetzung für die Abnahme
     jeder P2.3/-Nachbesserung-Änderung — unverändert zur Standing-Regel dieser gesamten Arbeit,
     hier noch einmal ausdrücklich für diese Runde festgehalten.
   - Der konservative Historien-Schutz in `recalculate` (jede Session blockiert) darf erst
     gelockert werden, wenn NACHGEWIESEN ist, dass eine künftige Versionierung/Snapshot-Mechanik
     (P5) TATSÄCHLICH sämtliche für die Auswertung benötigten Daten erhält (mindestens: CNS-/
     Muskel-Belastungsfaktoren-Äquivalente, nicht nur Name/Cardio/TimeBased wie die heutigen
     `ExerciseLog`-Snapshot-Felder) — als verbindliches Exit-Kriterium direkt im Code dokumentiert,
     nicht nur im Bericht.
4. **Aktivierungs-Prinzip verschärft:** die Typ-Doku formuliert jetzt eine VERBINDLICHE Anforderung
   statt nur einer offenen Frage: eine finale Wocheneditor-Übernahmefunktion MUSS ausdrücklich
   zwischen „nur speichern" (Entwurf/Änderungen persistieren, ohne den aktiven Plan zu wechseln)
   und „aktivieren" (zusätzlich den bisherigen aktiven Plan ablösen) unterscheiden — zwei erkennbar
   getrennte Operationen, keine stille Übernahme der heutigen impliziten
   Alles-oder-nichts-Automatik.

**P2.4-Vorprüfung (wie vorgegeben, vor neuen Feldern):** `PlanDraft`/`DraftDay` (Core, P2.0,
`Sources/FitnessAppCore/Planning/PlanDraft.swift`) wurde gezielt gelesen, bevor P2.4 beginnt.
Ergebnis: `DraftDay` hat BEREITS `isContentFixed`/`isPositionFixed` (zwei unabhängige, pro Tag
gesetzte Bool-Flags mit eigenen Settern `setContentFixed`/`setPositionFixed`), stabile
`DraftDayID`/`DraftExerciseID`, und `reorder(to:)`/`moveDay(_:toIndex:)` mit vollständigem Schutz
gegen direkte UND indirekte Positionsverdrängung (`respectsPositionFixations`, aus der
P2.0-Nachbesserung). **Das deckt die in P2.4 benötigte Fixierungslogik bereits vollständig ab.**
Was heute fehlt, ist NICHT eine zweite Fixierungs-Datenstruktur, sondern dass `PlanBuilderView`
`PlanDraft` überhaupt verwendet — der Builder hat aktuell eine eigene, von `PlanDraft` unabhängige
Repräsentation seines Schritt-3-Ergebnisses (`PlanGenerator.Result`) ohne jedes Fixierungskonzept.
P2.4 ist damit vermutlich eher eine Verdrahtungsaufgabe (Builder auf `PlanDraft` umstellen, die
bereits vorhandenen Setter/`reorder`-Pfade an die UI anbinden) als eine neue Core-Datenmodellierung
— wird aber erst bei tatsächlichem Start von P2.4 im Detail entschieden, nicht hier vorweggenommen.
Keine Code-Änderung in dieser Runde, reine Prüfung.

**Bewusst NICHT umgesetzt:** P2.4 selbst wurde in dieser Runde NICHT begonnen — die Vorgabe
erlaubte den Start parallel, verlangte ihn nicht; diese Runde deckte nur die zwei explizit
genannten Nacharbeiten plus Dokumentation ab.

**Geänderte Komponenten:** `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift`
(Testfix), `Sources/FitnessAppUI/Workout/PlanEditorView.swift` (Lokalisierung + Helper),
`Sources/FitnessAppUI/Resources/Localizable.xcstrings` (6 neue Keys),
`Sources/FitnessAppData/PlanGeneratorInstantiator.swift` (Typ-Doku-Verschärfung, keine
Verhaltensänderung).

**Neue/geänderte Datenfelder:** keine. Sechs neue Lokalisierungs-Keys (siehe oben).

**Tests hinzugefügt/korrigiert:** `testRecalculateSucceedsNormallyWithoutOverride` korrigiert (siehe
Punkt 1 oben). Keine neuen Testfälle — reine Erwartungs-Korrektur.

**Tests tatsächlich ausgeführt:** `python3 -I` JSON-Validierung der 6 neuen xcstrings-Keys (Parse +
Werte DE/EN/TR geprüft, Katalog 2102/2102/2102/2102). `TRANSLATIONS.md` regeneriert — **0 hardcoded
Strings in 0 Dateien**, bestätigt die Lokalisierung ist vollständig. `swift build`/
`swift build --build-tests`: grün (Syntax-Ebene, unverändert dieselbe Einschränkung wie bei jeder
FitnessAppData-/FitnessAppUI-Änderung dieser Session — `PlanEditorView.swift` ist SwiftUI-gated,
auf Linux nicht typgeprüft). Vollständiger Lauf `swift test` — **1023/1023 grün**, keine Regression
(der korrigierte Test selbst läuft NICHT auf Linux, da `FitnessAppDataTests` SwiftData-gated ist —
die Korrektur ist durch Nachlesen von `recalculate`s eigener Implementierung verifiziert, nicht
durch einen tatsächlichen Testlauf).

**Apple-Build/CI:** nicht durchgeführt — offen, unverändert.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Zusätzlich zu prüfen: alle vier Toast-Varianten
(none/rewritten/skipped/kombiniert/failed) zeigen in DE/EN/TR den erwarteten, grammatisch
korrekten Text inklusive Singular/Plural.

**Bekannte Grenzen/Risiken:** keine neuen gegenüber dem P2.3-Nachbesserung-Bericht oben. Die
P2.4-Vorprüfung ist Code-Lesen, kein Test — sollte bei tatsächlichem P2.4-Start noch einmal
gegengeprüft werden, falls sich `PlanDraft` zwischenzeitlich geändert hat.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** P2.4 (Fixierungs-Flag im Builder-Draft) — darf jetzt beginnen, voraussichtlich
als Verdrahtungsaufgabe (`PlanBuilderView` auf `PlanDraft` umstellen), siehe P2.4-Vorprüfung oben.
Keine neue UI-Übernahme-Funktionalität, bis Apple-Build diese und die vorherige Nachbesserung
bestätigt hat. Task #197 bleibt Voraussetzung für jede finale Wocheneditor-Übernahmefunktion.
Apple-Build und Geräteprüfung bleiben für P1, P2.1, beide Nachbesserungen, P2.3 und diese
Nacharbeiten gemeinsam offen, bis ein echter Lauf vorliegt.

## P2.4-Abschlussbericht (PlanBuilderView an PlanDraft angebunden)

**Paket:** `PlanBuilderView` (Schritt 3, die bearbeitete Wochenvorschau des Plan-bauen-Assistenten)
verwendet jetzt `PlanDraft` (Core, P2.0) als maßgebliche Quelle statt eines eigenen,
`PlanDraft`-unabhängigen `PlanGenerator.Result`-State. Reine Verdrahtungsaufgabe wie in der
P2.3-Nacharbeiten-Vorprüfung erwartet — keine neue Fixierungs-/Identitäts-/Reorder-Logik, keine
neuen persistenten Felder, keine neue Übernahmefunktion.

**Welche Zustände wurden ersetzt?**
`@State private var result: PlanGenerator.Result?` ist komplett entfernt. An seiner Stelle:
- `draft: PlanDraft?` — der eigentliche Entwurf (Tage, Übungen, beide Fixierungs-Flags, stabile
  `DraftDayID`/`DraftExerciseID`).
- `loadLevelByDayID: [DraftDayID: PlanLoadLevel]` — bewusst NICHT in `PlanDraft`/Core verschoben,
  siehe Typ-Doku: `loadLevel` ist ein generatorspezifisches, gesamt-wochen-relatives
  Anzeigekonzept (`loadLevels(for:)` vergleicht alle Tage EINES Generierungslaufs gegeneinander),
  keine Fixierungs-/Identitätsfrage und keine Eigenschaft eines einzelnen Tages für sich — würde
  `PlanDraft`s generatorunabhängige Wiederverwendbarkeit (auch für Template-Auswahl/P3.2-Edit
  bestehender Pläne) unnötig einschränken.
- `explanationKey: String?` — vorher `result.explanationKey`, jetzt direkt gehalten.
- `lastGeneratedInput: PlanGeneratorInput?` — neu, trägt die "nur neu generieren, wenn nötig"-Prüfung
  (Punkt 5 der Vorgabe).

**Welche Quelle ist jetzt für Vorschau und Übergabe maßgeblich?**
`draft` ist die alleinige Quelle für die Anzeige (`resultStepView`/`resultDayRow` lesen
ausschließlich `draft.days`, keine zweite Repräsentation parallel). Für die Übergabe an
`onGenerated`/`PlanGeneratorInstantiator.createPlan` — deren Signatur unverändert
`PlanGenerator.Result` erwartet (Punkt 7: kein Ripple-Effekt in `OnboardingView`,
`CardioFeasibilityCardModel`, `PlansListView`, `ProfileEditorView`) — rekonstruiert die neue
berechnete Property `currentResult` bei jedem Zugriff frisch aus `draft` + `loadLevelByDayID` +
`explanationKey`. Das ist genau die Punkt-8-Absicherung: ein bearbeiteter Draft kann beim
Übernehmen nicht mehr durch ein altes, unverändertes Generatorergebnis ersetzt werden, weil es
dieses alte Ergebnis als separaten State gar nicht mehr gibt. `adoptPlan()` liest jetzt
`currentResult` statt des alten `result`-State, der Rest der Funktion (Onboarding-Callback-Zweig
kehrt vor jedem SwiftData-Zugriff zurück; eigenständiger Zweig mit Profil-Fehlerzustand,
`createPlan`, verzögerter Navigation) ist strukturell unverändert.

Diese Umstellung ermöglichte einen Korrektheitsgewinn gegenüber dem alten Code: vorher rechnete
`goToNextStep()` bei JEDEM Eintritt in Schritt 3 unbedingt neu (`recalculatePreview()` ohne
Bedingung), `resultStepView.onAppear` prüfte nur `result == nil` als Fallback. Jetzt prüft
`generatePreviewIfNeeded(shuffle:)` selbst, ob sich `currentInput` seit der letzten Generierung
geändert hat (`lastGeneratedInput != currentInput`) — ein Zurück zu Schritt 1/2 und wieder vor,
OHNE dort etwas zu ändern, erzeugt keinen neuen Draft und damit keine neuen `DraftDayID`s mehr
(Punkt 5). Ein echter Input-Wechsel oder ein expliziter „Neu rechnen"-Tap (`shuffle: true`) bauen
den Draft weiterhin bewusst komplett neu auf (Punkt 6, "neue Generierung" vs. "gezielte Änderung" —
Letztere hat mangels UI-Affordanz noch keinen Aufrufer, bleibt P3).

**Was wurde aus P2.0 wiederverwendet statt neu gebaut?**
Wie in der P2.3-Nacharbeiten-Vorprüfung vorhergesagt: die komplette Fixierungs-/Identitäts-/
Reorder-Logik (`DraftDayID`/`DraftExerciseID`, `isContentFixed`/`isPositionFixed` samt Settern,
`reorder(to:)`/`moveDay(_:toIndex:)` mit Schutz gegen direkte UND indirekte
Positionsverdrängung, `replaceContent(of:with:)`) existierte bereits vollständig in
`PlanDraft`/`DraftDay` und wurde unverändert übernommen — P2.4 hat dort NICHTS Neues
implementiert, nur `PlanBuilderView` an die bestehende Schicht angeschlossen. Einzige echte
Neuerung war eine Blockade auf dem Weg dorthin: `PlanGenerator.Result`/`GeneratedDay` (Core)
hatten nur einen `internal` Memberwise-Init (ein `public struct` mit ausschließlich
`public let`-Feldern bekommt in Swift trotzdem keinen `public` Init synthetisiert) — `FitnessAppUI`
konnte diese Typen deshalb nicht konstruieren, um `currentResult` aus einem `PlanDraft`
zurückzubauen. Behoben durch zwei zusätzliche, rein additive `public init`s in
`PlanGenerator.swift`, mit exakt denselben Parametern/Labels wie die beiden einzigen bisherigen
internen Konstruktionsstellen (verifiziert per Grep — keine weitere Konstruktionsstelle im Repo
betroffen).

**Noch keine UI-Neuerung:** `resultStepView` zeigt weiterhin eine reine Liste ohne Drag&Drop oder
Fixierungs-Schalter — die Vorgabe „kein vollständiges P3-Redesign" wurde als Grenze gelesen, keine
Bedienelemente für die jetzt technisch verfügbaren Fixierungen/Reorder in dieser Runde einzuführen.
„Reorder und Fixierungen ausschließlich über die bereits vorhandenen Draft-Funktionen abwickeln"
(Punkt 3) ist damit als VORWÄRTS GERICHTETE Einschränkung für die künftige P3.2-UI erfüllt, nicht
als Auftrag, diese UI jetzt zu bauen.

**Geänderte Komponenten:**
- `Sources/FitnessAppCore/Programs/PlanGenerator.swift` — zwei neue `public init`s
  (`GeneratedDay.init(spec:loadLevel:)`, `Result.init(days:explanationKey:)`), keine
  Verhaltensänderung an `generate(from:shuffle:)`.
- `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` — State-Umstellung, neue
  `generatePreviewIfNeeded(shuffle:)`/`loadLevel(for:)`/`currentResult`, `resultStepView`/
  `resultDayRow` auf `DraftDay` umgestellt (`ForEach(draft.days)` statt
  `ForEach(Array(result.days.enumerated()), id: \.offset)` — `DraftDay` ist selbst `Identifiable`),
  `goToNextStep()`/`navigationBar`/`adoptPlan()` entsprechend angepasst.

**Neue/geänderte Datenfelder:** keine SwiftData-/Persistenz-Felder. Zwei neue `public init`s in
Core (additiv, keine Signaturänderung bestehender Konstruktionsstellen).

**Tests hinzugefügt:** `Tests/FitnessAppCoreTests/PlanGeneratorTests.swift` —
`testGeneratedDayAndResultPublicInitsReconstructEquivalentResult` (ein echtes Generator-Ergebnis
über die neuen Inits verlustfrei nachgebaut, Namen/Sequenzindizes/Ladestufen/ExplanationKey per
Round-Trip verglichen — genau der Mechanismus, den `currentResult` in `PlanBuilderView`
verwendet) und `testResultInitExplanationKeyDefaultsToNil` (Default-Parameter-Verhalten).

**Tests tatsächlich ausgeführt:** `swift build`/`swift build --build-tests` grün. `swift test`:
**1025/1025 grün** (1023 + 2 neue) — die beiden neuen Tests sind ECHTE, auf Linux ausgeführte
Core-Tests, kein Syntax-Only-Nachweis. Das ist der einzige Teil von P2.4, der tatsächlich auf
Linux lauffähig ist: `PlanBuilderView.swift` selbst liegt hinter
`#if canImport(SwiftUI) && canImport(SwiftData)` und wird auf dieser Plattform NIE geparst/
typgeprüft (beide Bedingungen sind hier `false`) — der grüne `swift build` für `FitnessAppUI`
belegt ausschließlich lexikalische Gültigkeit (Klammern balanciert, Token gültig), KEINE
semantische Korrektheit (Typen, Bindings, SwiftUI-Datenfluss). Kein `FitnessAppUITests`-Lauf deckt
diese Datei ab. Apple-Kompilierung/Gerätetest bleiben offen, siehe unten.

**Apple-Build/CI:** nicht durchgeführt — offen, unverändert zur Standing-Regel dieser gesamten
Arbeit.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Zusätzlich zu prüfen, sobald ein echter Build
vorliegt: Wechsel zwischen Schritt 1/2/3 mehrfach hin und her OHNE Änderung behält exakt dieselbe
Vorschau (keine sichtbare Neuberechnung); „Neu rechnen" liefert weiterhin eine sichtbar andere
Variante; „Plan übernehmen" übergibt in BEIDEN Modi (Onboarding-Callback und eigenständig) exakt
die zuletzt angezeigte Vorschau, auch nach einem vorherigen „Neu rechnen".

**Bekannte Grenzen/Risiken:**
- Die Korrektheit der neuen `zip(draft.days, resolvedGenerated)`-Zuordnung in
  `generatePreviewIfNeeded` beruht auf identischer Sortierung nach `sequenceIndex` auf beiden
  Seiten (explizit hergestellt, nicht nur angenommen) — bei einer künftigen Änderung an
  `PlanDraft.init(generated:)`s Sortierlogik müsste diese Stelle mitgeprüft werden.
- Kein Drag&Drop, keine Fixierungs-Schalter in der UI — die vorhandene Core-Funktionalität ist
  damit noch nicht für den Nutzer sichtbar/bedienbar (bleibt P3).
- Wie jede `FitnessAppUI`-Änderung dieser Session: ausschließlich Linux-Syntax-geprüft, nicht
  Apple-kompiliert, nicht auf einem Gerät gesehen.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Was bleibt offen für P3 und Task #197?**
- P3 (visueller Wochen-Editor): Drag&Drop-UI für `reorder(to:)`/`moveDay(_:toIndex:)`, sichtbare
  Schalter für `isContentFixed`/`isPositionFixed`, die „gezielte Änderung" eines einzelnen Tages
  über `replaceContent(of:with:)` (aktuell ohne jede UI-Affordanz) — alles bereits
  Core-seitig vorhanden, nur noch nicht angebunden.
- Task #197 (Commit-/Speicherfehler-Behandlung) bleibt zwingende Voraussetzung, BEVOR eine finale
  Wocheneditor-Übernahmefunktion gebaut wird — P2.4 selbst baut keine neue Übernahmefunktion
  (nur dieselbe, bereits bestehende `createPlan`/`onGenerated`-Übergabe mit neuem Quellinhalt),
  ändert an dieser Abhängigkeit nichts.
- Der Aktivierungsvertrag (ausdrückliche Trennung „nur speichern" vs. „aktivieren" für den
  künftigen Wocheneditor, siehe P2.3-Nachbesserung) und der konservative Historien-Schutz in
  `recalculate` (erst lockerbar nach nachgewiesenem P5-Exit-Kriterium) sind von P2.4 nicht
  berührt und bleiben unverändert in Kraft.

**Nächste Aufgabe:** P3 (A+B-Builder und Onboarding an den visuellen Wochen-Editor anbinden) kann
beginnen, sobald Apple-Build/Gerätetest für P2.4 (und die noch offenen vorherigen Phasen) vorliegen
und Task #197 geklärt ist. Apple-Build und Geräteprüfung bleiben für P1, P2.1, beide
P2.1/P2.2-Nachbesserungen, P2.3, die P2.3-Nacharbeiten und P2.4 gemeinsam offen, bis ein echter
Lauf vorliegt.
