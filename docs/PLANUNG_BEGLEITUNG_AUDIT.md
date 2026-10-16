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

## P2.4-Nachbesserung (Draft→Result-Adapter, abgeleitete Angaben, Apple-Build-Status)

**Paket:** drei der vier geforderten Punkte vor dem breiten P3-UI-Umbau. Punkt 4 (Task #197 als
nächstes Integrationspaket) ist bewusst NICHT Teil dieses Berichts — eigener, größerer Schnitt,
siehe eigener Abschnitt danach.

**1. Draft→Result-Adapter geschaffen und produktiv angebunden.** Vorher war die Rekonstruktion
eines `PlanGenerator.Result` aus einem `PlanDraft` inline in `PlanBuilderView.currentResult`
implementiert — korrekt, aber nicht für sich testbar (SwiftUI-gated, auf Linux nie typgeprüft).
Neu: `Sources/FitnessAppCore/Planning/PlanDraftResultAdapter.swift`,
`PlanDraftResultAdapter.makeResult(from:loadLevels:explanationKey:) throws -> PlanGenerator.Result?`
— reine Core-Funktion (keine SwiftUI-/SwiftData-Abhängigkeit, obwohl der vorherige Code zufällig in
einer View lag). `PlanBuilderView.currentResult` ruft jetzt ausschließlich diesen Adapter auf.
Regressionstest `testMakeResultReflectsReorderAndContentChangeCompletely`
(`Tests/FitnessAppCoreTests/PlanDraftResultAdapterTests.swift`): generiert einen echten
3-Tage-Plan, vertauscht Tag 1 und Tag 3 (`reorder(to:)`), ersetzt den Inhalt des jetzt an Position 0
stehenden Tages komplett durch einen andersartigen generierten Tag (`replaceContent(of:with:)`),
rekonstruiert dann über den Adapter — und vergleicht an allen drei Positionen die VOLLSTÄNDIGE
Übungsliste (`XCTAssertEqual(days[i].spec.exercises, ...)`, nicht nur `.name`) UND den neu
vergebenen `sequenceIndex`. Zusätzlich `testReorderAloneKeepsAllLoadLevelsResolvable` (reine
Umsortierung verliert keine `loadLevel`-Zuordnung, da die Map über `DraftDayID` statt Position
indiziert ist) und `testMakeResultReturnsNilForEmptyDraft`.

**2. "Kein stilles .medium für fehlende Zuordnung" umgesetzt, Rest als verbindliche P3-Regel
dokumentiert.** `loadLevel` und `explanationKey` sind abgeleitete, generatorspezifische Angaben
(`loadLevel` ist relativ zu ALLEN Tagen EINES Generierungslaufs berechnet, keine Eigenschaft eines
einzelnen Tages). Konkret umgesetzt: `PlanDraftResultAdapter.makeResult` wirft jetzt
`AdapterError.missingLoadLevel(dayID:)`, wenn ein Tag im Draft keine `loadLevel`-Zuordnung hat —
VORHER (im alten Inline-Code) wäre das still zu `.medium` verfallen. Regressionstest
`testMakeResultThrowsOnMissingLoadLevelInsteadOfDefaultingSilently` deckt das ab. Dieselbe
Disziplin auch für die reine Anzeige: `PlanBuilderView.loadLevel(for:)` liefert jetzt
`PlanLoadLevel?` (vorher mit `?? .medium`-Fallback), `resultDayRow` zeigt bei `nil` einen eigenen,
neutralen "Nicht bewertet"-Badge (neuer Key `planBuilder.result.loadLevel.unrated`, DE/EN/TR,
Katalog jetzt 2103 Keys, weiterhin 0 hardcoded) statt eine Einordnung vorzutäuschen. Heute in
BEIDEN Fällen unerreichbar (jeder Tag im Draft hat nach `generatePreviewIfNeeded` exakt eine
Zuordnung) — die Absicherung greift erst, sobald P3 Tage ohne volle Neugenerierung ändert/einfügt.
Als VERBINDLICHE Anforderung in der Adapter-Doku UND im `PlanBuilderView`-Typ-Kommentar
festgehalten (nicht in dieser Runde umgesetzt, da es keinen Aufrufer dafür gibt): sobald P3
`replaceContent(of:with:)` tatsächlich aufruft, wird die bisherige `loadLevels`-Zuordnung für die
GESAMTE Woche stale (nicht nur für den geänderten Tag, weil die relative Einstufung sich
mit-ändern kann) — P3 MUSS dann entweder alle Ladestufen neu berechnen oder die betroffenen
Einträge ausdrücklich entfernen (der Adapter wirft dann `missingLoadLevel`), niemals die alte,
jetzt falsche Einstufung unverändert weiterzeigen. Dieselbe Regel gilt für `explanationKey`: er
beschreibt, warum der Generator eine bestimmte Auswahl getroffen hat — nach einer manuellen
Änderung trifft das nicht mehr zu und muss entfernt/ersetzt werden, nicht stehen bleiben.

**3. Apple-Build real geprüft — nicht verfügbar, genaue Lücke benannt.** Diese Session läuft in
einem reinen Linux-Container: kein `xcodebuild`, `xcrun`, `xcode-select` (verifiziert, alle drei
`command not found`), kein `swift` ohne den manuell nachinstallierten Linux-Toolchain im
Scratchpad-Pfad. Es gibt in diesem Container keinen Weg, einen echten Apple-Build oder
SwiftUI-/SwiftData-Typcheck durchzuführen — das ist eine strukturelle Eigenschaft dieser
Umgebung, keine fehlende Konfiguration, die sich hier beheben ließe. Das Repo hat allerdings
eine echte, bereits eingerichtete Apple-CI: `codemagic.yaml`, Workflow `swift-package`, Trigger
"push, alle Branches", läuft auf `mac_mini_m2` mit Xcode und führt neben `swift build`/
`swift test --parallel` explizit
`xcodebuild -scheme FitnessAppUI -destination 'generic/platform=iOS Simulator' build` aus (ebenso
für FitnessAppCore/-Data/-Health/-Activities) — genau der reale Typcheck, den
`PlanBuilderView.swift` und `PlanDraftResultAdapter.swift` auf Linux nicht bekommen. Geprüft, ob
dieser Lauf für den P2.4-Push (`fca8c01`) sichtbar ist: `mcp__github__actions_list` für den Branch
`claude/smart-onboarding-epic` liefert **0 GitHub-Actions-Runs** (erwartet — Codemagic ist keine
GitHub Action, das Repo hat kein `.github/workflows`); es gibt in diesem Toolset keinen Zugriff auf
Codemagics eigenes Dashboard/API oder auf GitHub-Check-Runs ohne bekannte Check-Run-ID, also keinen
Weg von hier aus zu sehen, ob/wie der Codemagic-Lauf für diesen Push ausgefallen ist. **Es wird
nicht behauptet, dass ein Lauf gestartet oder erfolgreich war** — nur, dass die Infrastruktur dafür
existiert. Benötigt, um das wirklich zu schließen: Login im Codemagic-Account, der an dieses
GitHub-Repo gebunden ist, App "FitnessApp" öffnen, Workflow "Swift Package CI" (`swift-package`),
Build-Historie für Branch `claude/smart-onboarding-epic` ansehen (ein Build sollte automatisch
durch den Push getriggert worden sein, sofern die Codemagic-Anbindung aktiv ist) — Build-Log
insbesondere auf den "Build library products for iOS Simulator"-Schritt für `FitnessAppUI` prüfen.
Falls kein automatischer Build gelistet ist, ist entweder die Codemagic-GitHub-Anbindung nicht
aktiv, oder der Trigger greift aus einem anderen Grund nicht — in dem Fall den Workflow manuell in
der Codemagic-UI für diesen Branch/Commit starten.

**Geänderte Komponenten:** `Sources/FitnessAppCore/Planning/PlanDraftResultAdapter.swift` (neu),
`Sources/FitnessAppUI/Workout/PlanBuilderView.swift` (`currentResult` nutzt den Adapter,
`loadLevel(for:)` optional, `resultDayRow`s "Nicht bewertet"-Zweig, Typ-Doku ergänzt),
`Sources/FitnessAppUI/Resources/Localizable.xcstrings` (1 neuer Key).

**Neue/geänderte Datenfelder:** keine. Ein neuer Lokalisierungs-Key.

**Tests hinzugefügt:** `Tests/FitnessAppCoreTests/PlanDraftResultAdapterTests.swift` — 4 Tests
(siehe Punkt 1/2 oben), alle ECHTE Linux-Core-Tests.

**Tests tatsächlich ausgeführt:** `swift build`/`swift build --build-tests`: grün.
`python3 -I .scripts/generate_translations_md.py`: Katalog 2103/2103/2103, **0 hardcoded Strings**.
`swift test`: **1029/1029 grün** (1025 + 4 neue). `PlanBuilderView.swift` bleibt wie jede
`FitnessAppUI`-Datei SwiftUI-/SwiftData-gated und damit auf Linux nur syntaktisch, nicht
semantisch geprüft — unverändert zur Standing-Einschränkung dieser gesamten Arbeit.

**Apple-Build/CI:** nicht durchgeführt und von hier aus nicht einsehbar — siehe Punkt 3 oben für
die genaue Lücke und die benötigten Schritte.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Zusätzlich zu prüfen, sobald ein echter Build
vorliegt: der "Nicht bewertet"-Badge-Zweig ist mit dem heutigen Code-Pfad nicht erreichbar
(bewusst, siehe Punkt 2) und kann daher nur durch Code-Review, nicht durch manuelles Antippen
verifiziert werden.

**Bekannte Grenzen/Risiken:** keine neuen gegenüber dem P2.4-Bericht oben.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** Punkt 4 — Task #197 (Commit-/Speicherfehler-Behandlung) als eigenes
Integrationspaket, siehe eigenen Abschnitt.

## Task #197: Commit-/Speicherfehler-Behandlung (begrenzter Scope, Rückbau, Fehlerpropagation)

**Paket:** `build`/`createPlan` (neuer Plan) und `recalculate` (bestehender Plan) rufen jetzt selbst
`context.save()` auf und werfen einen typisierten Fehler statt sich ausschließlich auf SwiftDatas
Autosave zu verlassen. Begrenzt auf GENAU diese beiden Operationen — keine finale
Wocheneditor-Übernahmefunktion, die bleibt von diesem Task weiterhin unabhängig.

**Implementiert (vier geforderte Punkte):**

1. **Begrenzter Commit-Scope:** EIN `context.save()`-Aufruf pro Funktion, direkt nach den eigenen
   Mutationen — kein Save, der nebenbei irgendetwas anderes mitnimmt. `recalculate` ruft `save()`
   nur auf, wenn tatsächlich ein Tag neu geschrieben wurde (`rewritten > 0`, gleiches Muster wie
   `DeloadManager.startDeload`/`.endDeload`) — reines Überspringen allein löst keinen Save aus
   (durch Test `testRecalculateSkipsSaveEntirelyWhenNothingWasRewritten` belegt: ein auf "wirft
   immer" gesetzter Save-Override feuert in diesem Fall NICHT).
2. **Fehlerbehandlung:** neuer `PlanGeneratorInstantiator.PlanCreationError.saveFailed` (für
   `build`/`createPlan`) und `RecalculateError.saveFailed` (neuer Case, ergänzt
   `.sessionCheckFailed`). Beide werden geworfen statt verschluckt. Neuer DI-Seam
   `saveOverrideForTesting` (gleiches Muster wie `fetchAllSessionsOverrideForTesting`) macht einen
   echten Speicherfehler deterministisch simulierbar.
3. **Wiederholbarkeit — mit einer ehrlich benannten Asymmetrie zwischen beiden Funktionen:**
   - `build` macht auf einem Save-Fehler einen GEZIELTEN, auf die eigenen Änderungen begrenzten
     Rückbau: der gerade erst eingefügte Plan wird gelöscht (cascadet automatisch auf seine
     Tage/Übungen, `TrainingPlan.days`/`TrainingDay.exercises` sind beide `deleteRule: .cascade`)
     und die `isActive`-Flags der zuvor aktiven Pläne — die `ProgramInstantiator.instantiate`
     unconditional auf `false` gesetzt hatte — werden wiederhergestellt. Der Context landet exakt
     im Zustand von VOR dem Aufruf; ein erneuter Versuch legt weder einen doppelten Plan an, noch
     bleibt zwischenzeitlich kein Plan aktiv. Durch
     `testBuildRollsBackNewPlanAndRestoresPreviousActivePlanWhenSaveFails` bewiesen (prüft BEIDE
     Hälften: Plananzahl bleibt bei 1, UND der vorherige Plan ist wieder `isActive`).
   - `recalculate` kann NICHT auf dieselbe Weise zurückbauen: `apply` löscht bereits bestehende,
     persistierte `Exercise`-Objekte — SwiftData bietet keine sichere Operation, ein bereits
     angestoßenes Delete ohne einen Context-weiten `rollback()` wieder rückgängig zu machen (siehe
     Punkt 4 unten, warum dieser Rollback ausgeschlossen bleibt). Das ist eine echte technische
     Grenze, kein Zeitdruck-Kompromiss — hier bewusst NICHT mit einer fragilen
     "rekonstruiere die alten Objekte neu"-Behelfslösung umgangen (das wäre keine echte Wiederher­
     stellung, sondern neue Objekte mit geratener Identität). Bleibt trotzdem sicher: `save()` ist
     atomar — schlägt es fehl, landet NICHTS auf der Platte; die hängengebliebenen Änderungen
     werden vom nächsten erfolgreichen Save (von hier oder anderswo) einfach nachgeholt, und ein
     erneuter `recalculate`-Aufruf dupliziert nichts, weil der neu geschriebene Fingerprint bereits
     zum neuen Inhalt passt (ein zweiter Durchlauf ersetzt also wieder nur konsistent denselben
     Zielzustand). Durch `testRecalculatePropagatesSaveFailureAsThrownError` wird zumindest die
     SICHTBARKEIT des Fehlers bewiesen, nicht ein vollständiger Rückbau — diese Asymmetrie steht
     jetzt explizit in der Typ-Doku, nicht nur in diesem Bericht.
4. **Ausdrückliche Aktivierungsentscheidung:** gelesen als Teil von Punkt 3, nicht als die separate
   "nur speichern vs. aktivieren"-Frage für den künftigen Wocheneditor (die bleibt unverändert
   offen, siehe unten) — die `isActive`-Seite-Effekte von `instantiate` werden im Fehlerfall nicht
   mehr unbeachtet gelassen, sondern sind Teil des EXPLIZIT nachvollzogenen, wiederhergestellten
   Zustands (`previouslyActivePlans` wird VOR `instantiate` bewusst erfasst, nicht erraten).

**Nicht verwechseln mit der offenen Aktivierungsvertrag-Frage:** "nur speichern" (Entwurf/Änderungen
persistieren, ohne den aktiven Plan zu wechseln) vs. "aktivieren" (zusätzlich den bisherigen aktiven
Plan ablösen) für eine künftige Wocheneditor-Übernahmefunktion bleibt UNVERÄNDERT offen — diese
Runde hat ausschließlich die Save-/Fehlerbehandlung der BEREITS BESTEHENDEN Operationen (neuer Plan,
bestehenden Plan aktualisieren) real geklärt, keine neue "nur speichern ohne Aktivierung"-Funktion
eingeführt.

**Ausdrücklich NICHT eingebaut, in BEIDEN Funktionen:** ein `context.rollback()` bei einem Fehler —
das wirkt auf den GESAMTEN geteilten `ModelContext` und würde unabhängige, an anderer Stelle bereits
bestätigte Änderungen (z.B. ein offenes Edit auf einem anderen Screen, der denselben `modelContext`
teilt) mit zerstören. Konkret relevant bei `OnboardingView.finishOnboarding`: `createPlan` läuft dort
NACH bereits erfolgten `modelContext.insert(profile)`/`insert(measurement)`-Aufrufen im selben
Context — ein `rollback()` im Fehlerfall hätte Profil UND Messung mit verworfen, nicht nur den
fehlgeschlagenen Plan. Der gezielte Rückbau in `build` berührt `profile`/`measurement` nicht.

**Geänderte Komponenten:**
- `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` — `build`/`createPlan` werfen jetzt,
  gezielter Rückbau, `RecalculateError.saveFailed`, `saveOverrideForTesting`-DI-Seam, Typ-Doku
  komplett überarbeitet (Commit-/Speicherverantwortung, Aktivierungsvertrag-Abschnitt).
- `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` — `adoptPlan()` fängt den neuen Fehler,
  zeigt eigenen Alert (`adoptSaveErrorMessage`), setzt `isAdopting` zurück (Wiederholbarkeit aus
  UI-Sicht).
- `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift` — `accept`/`acceptCustom` nutzen
  `try?`, behandeln einen Speicherfehler identisch zum bereits bestehenden `nil`-Pfad (bestehende
  P2.3-Nachbesserung-UI deckt Retry/Doppeltap-Reset bereits ab, keine neue UI nötig).
- `Sources/FitnessAppUI/OnboardingView.swift` — `finishOnboarding()` fängt den Fehler bewusst OHNE
  Alert ab (siehe Begründung dort: Profil/Messung müssen den Onboarding-Abschluss unabhängig vom
  optionalen Plan erreichen, ein neuer Alert-State könnte nach dem Profil-Insert nie mehr sichtbar
  werden).
- `Sources/FitnessAppUI/Resources/Localizable.xcstrings` — 2 neue Keys
  (`planBuilder.error.saveFailed.title`/`.message`, DE/EN/TR, Katalog jetzt 2105 Keys, weiterhin 0
  hardcoded).

**Neue/geänderte Datenfelder:** keine.

**Tests hinzugefügt:** `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift` — 4 neue
Tests (`testBuildRollsBackNewPlanAndRestoresPreviousActivePlanWhenSaveFails`,
`testCreatePlanPropagatesSaveFailure`, `testRecalculatePropagatesSaveFailureAsThrownError`,
`testRecalculateSkipsSaveEntirelyWhenNothingWasRewritten`) plus Anpassung zweier bestehender Tests
(`testBuildReturnsNilWhenGeneratorProducesNoDays`/`testCreatePlanReturnsNilWhenGeneratorProducesNoDays`
brauchen jetzt `throws`/`try`, da `build`/`createPlan` selbst werfen).

**Tests tatsächlich ausgeführt:** `swift build`/`swift build --build-tests`: grün.
`python3 -I .scripts/generate_translations_md.py`: Katalog 2105/2105/2105, **0 hardcoded Strings**.
`swift test`: **1029/1029 grün — UNVERÄNDERT**. Das ist hier besonders wichtig festzuhalten: KEINER
der neuen/geänderten Tests in `PlanGeneratorInstantiatorTests.swift` läuft auf Linux, weil die
GESAMTE Datei (wie jede `FitnessAppDataTests`-Datei) hinter `#if canImport(SwiftData)` liegt — die
vier neuen Tests sind sorgfältig konstruiert (inklusive des `saveOverrideForTesting`-DI-Seams genau
für diesen Zweck), aber bis zu einem echten Apple-Testlauf ausschließlich durch Code-Lesen verifiziert,
nicht durch Ausführung. Dasselbe gilt für `PlanBuilderView.swift`/`CardioFeasibilityCardModel.swift`/
`OnboardingView.swift` — alle drei SwiftUI-gated, auf Linux nur lexikalisch, nicht semantisch geprüft.

**Apple-Build/CI:** nicht durchgeführt — siehe Punkt 3 im P2.4-Nachbesserung-Bericht oben für die
genaue Lücke (kein Xcode/xcodebuild in diesem Container) und die benötigten Schritte über
Codemagic. Für DIESE Änderung besonders wichtig: die vier neuen Tests sind der einzige Weg, den
gezielten Rückbau in `build` tatsächlich zu verifizieren — bis ein echter Lauf vorliegt, ist das
unbewiesener, nur gelesener Code.

**UI-/Geräteprüfung:** nicht durchgeführt — offen. Zusätzlich zu prüfen, sobald ein echter Build
vorliegt: der neue "Plan konnte nicht gespeichert werden"-Alert in `PlanBuilderView` (DE/EN/TR,
inklusive erfolgreicher Wiederholung nach OK-Tap) — dieser Fall ist mit normalen Mitteln im
Simulator nicht provozierbar (ein echter Speicherfehler erfordert z.B. vollen Speicher oder einen
beschädigten Store), eine Device-Verifikation kann deshalb praktisch nur den Alert selbst
(z.B. über einen temporären Test-Hook) und das Button-/Reset-Verhalten prüfen, nicht den echten
Fehlerfall end-to-end.

**Bekannte Grenzen/Risiken:**
- `recalculate`s fehlender Rückbau (Punkt 3 oben) ist eine bewusste, dokumentierte Grenze, keine
  Lücke, die "noch gelöst werden muss" — eine echte Lösung würde ein Undo-Log oder eine
  Zwei-Phasen-Commit-Struktur brauchen, die für dieses konservative, bereits session-geschützte
  Update (siehe P2.3-Nachbesserung) nicht gerechtfertigt ist.
- `OnboardingView.finishOnboarding`s bewusst alertloser Fehlerpfad bedeutet: ein Nutzer, dessen
  initialer Plan beim Onboarding-Abschluss nicht gespeichert werden konnte, erfährt das NICHT
  explizit — er landet einfach ohne Plan in der App (identisch zum bereits unterstützten "Fertig
  ohne Plan"-Fall). Bewusste Abwägung (siehe Begründung oben), aber wert, im Hinterkopf zu behalten,
  falls spätere Analytics/Support-Daten zeigen, dass das in der Praxis verwirrt.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** P3 (A+B-Builder und Onboarding an den visuellen Wochen-Editor anbinden) kann
jetzt beginnen — Task #197 ist für die BESTEHENDEN Operationen (neuer Plan, Aktualisierung) geklärt,
bleibt aber weiterhin Voraussetzung dafür, dass eine FINALE Wocheneditor-Übernahmefunktion (mit der
noch offenen "nur speichern vs. aktivieren"-Entscheidung) überhaupt gebaut werden darf. Apple-Build
und Geräteprüfung bleiben für ALLE Phasen dieser Arbeit (P1 bis hier) gemeinsam offen, bis ein
echter Lauf vorliegt.

## Task #197-Nachbesserung (Operations-/Fehlervertrag, Scratch-Context-Isolation, sichtbare Fehlerweitergabe)

**Task #197 wurde vom User explizit WIEDER GEÖFFNET** — der obige Abschlussbericht war verfrüht.
Korrigierte Kernaussage zuerst, weil sie die Grundannahme des gesamten vorherigen Abschnitts betrifft:

**Punkt 1 der Korrektur — die Behauptung "begrenzter Commit-Scope" oben (Punkt 1 im alten Bericht)
war FALSCH.** `context.save()` committet IMMER den gesamten übergebenen `ModelContext`, nicht nur
die eigenen Änderungen der aufrufenden Funktion — ein einzelner `save()`-Aufruf "direkt nach den
eigenen Mutationen" ist deshalb KEIN begrenzter Operations-Scope, sondern speichert genauso jede
andere, unabhängige, zu diesem Zeitpunkt im selben Context ausstehende Änderung mit (z.B. ein
offenes Edit auf einem anderen Screen, der denselben `modelContext` teilt). Der alte Bericht hat das
Risiko benannt (siehe dortiger Abschnitt zu `context.rollback()`), aber beim Save selbst fälschlich
das Gegenteil behauptet.

**Neuer, echter Operations-/Fehlervertrag (zuerst festgelegt, dann implementiert, wie vom User
verlangt):**

1. **`build`/`createPlan` (neuer Plan) — ECHTE Isolation über einen Scratch-`ModelContext`:**
   `build` erzeugt jetzt `let scratchContext = ModelContext(context.container)` — SwiftData-Contexts
   sind "Peers", die denselben Store teilen, aber keine Parent-Child-Beziehung haben (verifiziert per
   WebSearch gegen hackingwithswift.com/Apple-Dokumentation, nicht durch Kompilieren, s.u.). Fetch,
   Instanziierung UND `save()` laufen ausschließlich auf `scratchContext`. Schlägt der Save fehl,
   bleibt der AUFRUFER-`context` (der geteilte) komplett unberührt — kein Rückbau nötig, weil nie
   etwas dort verändert wurde. Bei Erfolg wird das Ergebnis über `context.model(for:
   plan.persistentModelID) as? TrainingPlan` in den Context des Aufrufers zurückgeholt (die einzige
   portable Brücke zwischen zwei SwiftData-Contexts ist die `persistentModelID`, der Zielcontext muss
   sie explizit auflösen). Das ersetzt den gezielten Lösch-Rückbau aus dem alten Bericht komplett —
   der ist jetzt unnötig, nicht nur verbessert.
2. **`recalculate` (bestehenden Plan aktualisieren) — BEWUSST KEINE Context-Isolation, dafür ein
   anderer Sicherheitsmechanismus:** anders als `build` hält der Aufrufer (typischerweise
   `PlanEditorView` über `@Query`/`@Bindable`) bereits eine lebende Bindung an den EXISTIERENDEN Plan.
   Eine Isolation wie bei `build` würde diese Bindung vom tatsächlich geänderten Objekt entkoppeln —
   nach einem "erfolgreichen" Recalculate stünde eine veraltete Ansicht auf dem Bildschirm, eine neue,
   schwerer zu findende Fehlerklasse. Stattdessen bleibt `recalculate` auf dem geteilten Context, aber
   `apply(...)` wurde umgebaut: alte Übungen werden jetzt per `exercise.isArchived = true`
   ARCHIVIERT statt per `context.delete()` gelöscht (Wiederverwendung des bestehenden
   `Exercise.isArchived`-Mechanismus aus `PlanEnvironmentMigrator`s Urlaubsmodus — verifiziert durch
   Lesen von `TrainingDay.currentContentFingerprint`, das bereits über `activeExercises`
   [`!isArchived`] filtert, UND von `PlanEnvironmentMigrator.restoreOriginals`, das NUR über
   `swappedFromOriginal != nil` wiederherstellt, nie über `isArchived` allein — ein von `recalculate`
   archiviertes Objekt kann also nie versehentlich vom Migrator "zurückgeholt" werden). `apply`
   sammelt pro Tag einen `DayMutationSnapshot` (archivierte + neu eingefügte Übungen, alte
   Feldwerte). Schlägt `save()` fehl, ruft `recalculate` `revert(snapshots:in:)` auf: neu eingefügte
   Übungen werden gelöscht (sie wurden nie gespeichert, ein Delete auf einem nie committeten Insert
   ist unproblematisch), archivierte Übungen bekommen `isArchived = false` zurück, alle Feldwerte +
   der Fingerprint werden auf den Vorzustand zurückgeschrieben — der geteilte Context landet exakt im
   Zustand von vor dem Aufruf, OHNE dass `context.rollback()` (das unabhängige fremde Änderungen mit
   verwerfen würde) jemals aufgerufen wird. Akzeptierter Kompromiss, bewusst nicht behoben (siehe
   unten "keine weitere Architektur nebenher"): archivierte Übungen werden nie hart gelöscht und
   sammeln sich bei wiederholtem "Neu rechnen" an — ein reines Speicherplatz-, kein
   Korrektheitsproblem.
3. **`previouslyActivePlans`-Fetch vor jeder Mutation — kein `(try? fetch) ?? []` mehr:** neue
   `PlanGeneratorInstantiator.fetchActivePlans(in:)` (mit eigenem `fetchActivePlansOverrideForTesting`-
   DI-Seam) wirft jetzt `PlanCreationError.activePlanCheckFailed`, wenn die Zustandsprüfung selbst
   scheitert — VOR jeder Instanziierung/Mutation, nicht erst danach bemerkt. Dieselbe Disziplin, die
   für `recalculate`s Session-Check schon vorher galt, jetzt auch hier.
4. **Speicherfehler an alle Aufrufer weitergeben** — drei Call-Sites korrigiert:
   - **Cardio** (`PlansListView.swift`, `ProfileEditorView.swift`):
     `CardioFeasibilityCardModel.accept`/`.acceptCustom` sind wieder `throws` (die `try?`-Variante aus
     dem allerersten Durchlauf dieser Korrektur wurde verworfen). Beide UI-Stellen fangen den Fehler
     jetzt explizit mit `do/catch`, zeigen einen sichtbaren Alert (`cardioAcceptErrorMessage`, neue
     Keys `cardioFeasibility.error.saveFailed.title`/`.message`) und setzen
     `isAcceptingCardioFeasibility` in JEDEM Fall (Erfolg wie Fehler) zurück — der Button bleibt
     bedienbar, ein erneuter Versuch ist möglich. `ProfileEditorView`s `acceptCustom`-Pfad hat bisher
     das Ergebnis komplett verworfen (`_ = model.acceptCustom(...)`, auch den Erfolgsfall) — das
     verschluckte vorher sowohl Erfolg als auch Fehler gleichermaßen, jetzt zumindest den Fehler
     sichtbar. Bewusst NICHT nachgerüstet: Navigation zum neuen Plan nach Erfolg — dieser Screen hält
     (anders als `PlansListView`) gar keine `AppNavigation`-Referenz, der direkte "Übernehmen"-Button
     auf derselben Seite navigiert aus demselben strukturellen Grund ebenfalls nicht; das Threading
     einer Navigationsreferenz in `ProfileEditorView` wäre genau die Art zusätzlicher Architektur, die
     der User für diese Runde ausgeschlossen hat.
   - **Onboarding** (`OnboardingView.swift`): kein leerer `catch {}` mehr. Neue, reine
     `UserDefaults`-Core-Utility `OnboardingPlanCreationNotice` (`Sources/FitnessAppCore/Domain/`,
     Muster identisch zu `HealthWritePreferences`/`ReminderPreferences`) markiert den Fehlschlag via
     `markFailed()`. Nach wie vor KEIN Alert direkt in `OnboardingView` (unverändert korrekte
     Begründung aus dem alten Bericht: `RootView` kann zu diesem Zeitpunkt bereits auf `MainTabView`
     umgeschaltet haben, ein neuer Alert-State dort könnte nie mehr sichtbar werden) — aber jetzt
     auch kein stilles Verschwinden mehr: `DashboardView` (der erste Screen nach Onboarding-Abschluss)
     konsumiert den Hinweis über `OnboardingPlanCreationNotice.consumeIfPending()` in einem
     zusätzlichen `.task` (gleiches "läuft bei jedem Erscheinen, aber harmlos" Muster wie das
     bestehende `autoEndDeloadIfExpired()`-`.task` in derselben Datei) und zeigt EINMALIG einen Alert
     mit Erklärung + direktem Sprung zum Plan-Tab (`navigation.selectedTab = .plan`, Wiederverwendung
     des bestehenden Patterns aus der Cardio-Dashboard-Karte). "Einmalig" ist durch
     `consumeIfPending()`s Lese-und-Lösch-in-einem-Schritt-Semantik erzwungen, nicht nur durch
     UI-Zustand.

**Warum keine der drei technischen Lösungen (1–3) als "zusätzliche große Architektur" zählt, die der
User für diese Runde ausgeschlossen hat:** alle drei sind direkte, minimale Umsetzungen der vom User
selbst geforderten Verhaltensweisen (echte Isolation ODER bewusst gemeinsam verantworteter Abschluss;
kein Rollback auf dem geteilten Context; Abbruch vor Mutation bei Fetch-Fehler) — keine neue
Abstraktion, kein neues Subsystem, keine über das Geforderte hinausgehende Verallgemeinerung.
`OnboardingPlanCreationNotice` ist eine einzelne, ca. 15 Zeilen lange `enum`-Utility nach bereits
etabliertem Muster, kein neues Notification-/Messaging-System.

**Geänderte/neue Komponenten (zusätzlich zu den im alten Bericht genannten):**
- `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` — Typ-Doku komplett um den obigen
  Operations-/Fehlervertrag ergänzt; `build` nutzt `scratchContext`; `fetchActivePlans(in:)` +
  `fetchActivePlansOverrideForTesting`; `DayMutationSnapshot` + `revert(_:in:)`; `apply(...)` gibt
  jetzt `DayMutationSnapshot` zurück und archiviert statt zu löschen.
- `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift` — `accept`/`acceptCustom` wieder
  `throws` statt `try?`.
- `Sources/FitnessAppUI/Workout/PlansListView.swift` — neue `cardioAcceptErrorMessage` + `.alert`,
  beide Aufrufstellen (`accept`, `acceptCustom` im Plan-anpassen-Sheet) auf `do/catch` umgestellt.
- `Sources/FitnessAppUI/Settings/ProfileEditorView.swift` — identisches Muster
  (`cardioAcceptErrorMessage` + `.alert`), siehe Navigation-Einschränkung oben.
- `Sources/FitnessAppCore/Domain/OnboardingPlanCreationNotice.swift` — NEU.
- `Sources/FitnessAppUI/OnboardingView.swift` — `finishOnboarding()`s leerer `catch` ruft jetzt
  `OnboardingPlanCreationNotice.markFailed()`.
- `Sources/FitnessAppUI/DashboardView.swift` — neues `.task` konsumiert den Hinweis, neuer Alert mit
  Sprung zum Plan-Tab.
- `Sources/FitnessAppUI/Resources/Localizable.xcstrings` — 5 neue Keys
  (`cardioFeasibility.error.saveFailed.title`/`.message`,
  `dashboard.onboardingPlanCreationFailed.title`/`.message`/`.goToPlan`, DE/EN/TR, Katalog jetzt 2110
  Keys, weiterhin 0 hardcoded).

**Tests hinzugefügt:**
- `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift` — 4 neue Tests:
  `testFailedCreationIsRepeatableWithoutOrphanedObjects`,
  `testBuildAbortsBeforeAnyMutationWhenActivePlanCheckFails`,
  `testBuildDoesNotSaveIndependentPendingChangeInCallerContext`,
  `testRecalculateSaveFailureLeavesNoStructuralChangeEvenAfterLaterSave`. Deckt alle 5 vom User
  geforderten Testfälle ab bis auf den Onboarding-Fall (der liegt, s.u., in einer eigenen Core-Datei).
- `Tests/FitnessAppCoreTests/OnboardingPlanCreationNoticeTests.swift` — NEU, 4 Tests
  (`testNothingPendingByDefault`, `testMarkFailedThenConsumeReturnsTrueOnce`,
  `testMarkFailedIsIndependentPerDefaultsInstance`, `testRepeatedMarkFailedStillConsumesOnlyOnce`) —
  deckt den 5. geforderten Testfall ("Onboarding-Fehler bleibt sichtbar und nachvollziehbar") für die
  Core-Logik ab.

**Tests tatsächlich ausgeführt vs. nur gelesen — diesmal mit einem präziseren Befund zur
Linux-Build-Verifikation (siehe unten):** `swift build` und `swift build --build-tests`: grün, nach
JEDER Änderungsstufe einzeln geprüft. `swift test`: **1033/1033 grün** (vorher 1029 — die Differenz
sind GENAU die 4 neuen `OnboardingPlanCreationNoticeTests`, verifiziert durch gezielten
`--filter`-Lauf). Die 4 neuen `PlanGeneratorInstantiatorTests` tragen NICHTS zur Zählung bei — exakt
wie erwartet, weil die gesamte Datei hinter `#if canImport(SwiftData)` liegt, das auf Linux falsch
ist. **Das heißt: von den 5 vom User geforderten Tests sind 4 bis zu einem echten Apple-Testlauf nur
codegelesen, nicht ausgeführt; genau 1 (der Onboarding-Fall, weil er in reinem Foundation/Core liegt)
läuft tatsächlich und grün auf Linux.**

**Präzisierung der Linux-Build-Aussage (betrifft die Vertrauenswürdigkeit ALLER bisherigen
"`swift build`: grün"-Aussagen in diesem gesamten Dokument, nicht nur diese Runde):** bisher wurde an
mehreren Stellen "nur syntaktisch, nicht semantisch geprüft" geschrieben, ohne das genauer zu
belegen. Diese Runde wurde das empirisch getestet: ein absichtlich eingefügter, grober Syntaxfehler
(fehlerhafte Klammerung) INNERHALB eines inaktiven `#if canImport(SwiftData)`-Blocks wurde von
`swift build` auf Linux tatsächlich mit exakter Zeilen-/Spaltenangabe gemeldet — die Datei danach per
Diff gegen das Original als byte-identisch wiederhergestellt bestätigt. Ergebnis: ein inaktiver
`#if`-Zweig wird auf Linux SEHR WOHL lexikalisch/syntaktisch geparst (grobe Fehler wie falsche
Klammerung, kaputte Deklarationen würden auffallen), aber NIE semantisch gegen die echten
SwiftData-/SwiftUI-APIs typgeprüft (falsche Methodennamen, falsche Signaturen, falsche
API-Verwendung würden NICHT auffallen). Für diese Runde besonders relevant, weil `build` jetzt
`ModelContext(container)` und `context.model(for:) as? TrainingPlan` verwendet — beides laut
WebSearch (hackingwithswift.com, Apple-Forenbeiträge) korrekt verwendete, dokumentierte APIs, aber
NICHT durch Kompilieren gegen die echte SwiftData-Implementierung verifiziert. Diese Einschränkung
gilt unverändert für `CardioFeasibilityCardModel.swift`, `PlansListView.swift`,
`ProfileEditorView.swift`, `OnboardingView.swift`, `DashboardView.swift` (alle vier SwiftUI-gated).

**Apple-Build/CI:** weiterhin nicht durchgeführt — unverändert keine Xcode-/`xcodebuild`-Umgebung in
diesem Container. Für DIESE Runde besonders wichtig: `ModelContext(container)` +
`context.model(for:)` sind neue, in dieser gesamten Codebasis bisher nicht verwendete SwiftData-APIs
— bis zu einem echten Build-/Testlauf ist nicht auszuschließen, dass sich hier ein Compile- oder
Laufzeitproblem verbirgt, das von Linux aus prinzipiell nicht sichtbar gemacht werden kann.

**Bekannte Grenzen/Risiken (zusätzlich zu den im alten Bericht genannten, die weiterhin gelten):**
- Archivierte, von `recalculate` nie wieder hart gelöschte Übungen sammeln sich bei wiederholtem
  "Neu rechnen" an (siehe Punkt 2 oben) — bewusst akzeptierter, reiner Speicherplatz-Kompromiss.
- `ProfileEditorView`s `acceptCustom`-Pfad navigiert nach Erfolg weiterhin nicht zum neuen Plan
  (strukturell bedingt, siehe oben) — unverändert gegenüber dem Verhalten vor dieser Korrektur, jetzt
  aber explizit dokumentiert statt stillschweigend.
- Task #197 gilt NICHT als sicher abgeschlossen, bis ein echter Apple-Build/Testlauf die neuen
  SwiftData-API-Aufrufe (`ModelContext(container)`, `context.model(for:)`) und alle SwiftUI-gated
  UI-Änderungen bestätigt hat — identisch zur Haltung des Users im Korrektur-Auftrag.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** unverändert P3, mit derselben Einschränkung wie oben — Task #197 ist für die
BESTEHENDEN Operationen jetzt nach bestem Wissen auf Code-Ebene vollständig umgesetzt, bleibt aber
erst durch einen echten Apple-Lauf tatsächlich bewiesen. Finale Wocheneditor-Übernahme bleibt bis
dahin UND bis zur separaten "nur speichern vs. aktivieren"-Entscheidung blockiert.

## Task #197-Nachbesserung, zweite Korrekturrunde (drei eng begrenzte Vertragslücken)

**Task #197 bleibt `in_progress`** — der User hat die obige Nachbesserung als "sinnvolle
Fortschritte" akzeptiert, aber NICHT als abgeschlossen geführt. Drei konkrete, eng begrenzte
Lücken wurden benannt und in dieser Runde geschlossen.

**Punkt 1 — `recalculate` kann weiterhin fremde offene Änderungen mitspeichern:** die vorherige
Runde hatte das als bewusst akzeptierte Eigenschaft von SwiftDatas Save-Modell dokumentiert — das
wurde vom User explizit NICHT als Produktverhalten akzeptiert. Lösung: `recalculate` prüft jetzt
VOR jeder eigenen Mutation per neuer privater `hasIndependentPendingChanges(relativeTo:in:)`, ob
der Context ein Objekt AUSSERHALB des Plan-Objektgraphen (Plan selbst + seine Tage + deren
Übungen, aktiv UND archiviert) als ausstehende Änderung hält, und bricht in diesem Fall mit dem
neuen `RecalculateError.independentChangesPending` ab — keine Mutation, kein Save-Versuch.

**Bewusst NICHT per simplem `context.hasChanges`** — ein erster Entwurf dieser Korrektur hätte
genau das getan und wäre ein eigener, neuer Bug gewesen: `TrainingPlan` ist in `PlanEditorView` ein
`@Bindable`-Autosave-Screen (`PlanMetaSnapshot`), ein noch nicht automatisch gespeichertes Feld AM
SELBEN Plan (z. B. ein gerade editierter `customName`) ist kein "fremder" Zustand, sondern derselbe
Bearbeitungsvorgang — ein blankes `hasChanges` hätte das fälschlich blockiert, und hätte sogar den
BESTEHENDEN Test `testRecalculateSkipsDayWithEditedExerciseSets` (der genau so eine
Vor-Ort-Bearbeitung simuliert) zum Fehlschlagen gebracht. Per WebSearch-Recherche verifiziert:
`ModelContext.insertedModelsArray`/`.changedModelsArray`/`.deletedModelsArray` sind echte,
öffentliche, dokumentierte SwiftData-API seit iOS 17.0/macOS 14.0 (genau das Deployment-Target
dieses Projekts, keine `@available`-Anhebung nötig) — Quelle: developer.apple.com/documentation/
swiftdata/modelcontext/{insertedmodelsarray,changedmodelsarray,deletedmodelsarray}. Bekannter
Caveat (Community-Quellen, nicht auf den Referenzseiten selbst): die drei Arrays leeren sich sofort
nach einem erfolgreichen Save — irrelevant hier, da ausschließlich VOR jedem Save gelesen.

**Punkt 2 — erfolgreichen Commit von fehlgeschlagener Rückbindung unterscheiden:** nach einem
ERFOLGREICHEN `save(scratchContext)` erschien ein nachfolgender Rückbindungsfehler
(`context.model(for:)` liefert `nil`) bisher als `PlanCreationError.saveFailed` mit der Nachricht
"Es wurde nichts geändert" — faktisch falsch, der Plan EXISTIERT bereits persistiert. Neuer Fall
`PlanCreationError.createdButRebindFailed(planID:)` trägt die bereits persistierte
`PersistentIdentifier` weiter. `createPlan` (der tatsächlich von allen vier Aufrufern genutzte
Einstiegspunkt, nicht `build` direkt) fängt diesen Fall sofort ab und versucht GENAU EINMAL erneut
aufzulösen (neue `resolveCreatedPlan(id:in:)`, über denselben privaten `rebind`-Helfer wie `build`s
eigener erster Versuch, mit neuem `rebindOverrideForTesting`-DI-Seam) — gelingt das, kehrt
`createPlan` normal mit dem Plan zurück, der Aufrufer bemerkt nichts. Schlägt auch dieser interne
Retry fehl, reicht `createPlan` denselben `createdButRebindFailed(planID:)` weiter — ein Aufrufer
darf darauf NIE erneut `build`/`createPlan` aufrufen (zweiter Plan!), nur `resolveCreatedPlan` mit
derselben ID ist sicher wiederholbar. Vier UI-Stellen (`PlanBuilderView`s eigener Pfad,
`PlansListView`/`ProfileEditorView`s direkter "Übernehmen"-Button) fangen diesen Fall jetzt mit
eigenem Titel/eigener Nachricht ("Plan wurde erstellt" statt "konnte nicht gespeichert werden") ab,
statt die generische Save-Fehler-Meldung zu zeigen.

**Punkt 3 — `onGenerated`/Builder-Callback muss Erfolg/Fehler zurückmelden:** `PlanBuilderView`s
`adoptPlan()` rief die `onGenerated`-Closure bisher auf und dismissed danach UNBEDINGT — ein
Fehler aus `CardioFeasibilityCardModel.acceptCustom(...)` innerhalb dieser Closure (Cardio-"Plan
anpassen"-Pfad) hätte den bearbeiteten Entwurf kommentarlos verworfen. `onGenerated`s Signatur ist
jetzt `(PlanGeneratorInput, PlanGenerator.Result) -> String?` statt `-> Void`: `nil` = Erfolg,
Sheet schließt; ein Nicht-nil-Wert ist eine bereits lokalisierte Fehlermeldung, die
`PlanBuilderView` in ihrem EIGENEN, bereits bestehenden `adoptSaveErrorMessage`-Alert zeigt UND
dabei das Sheet (mit intaktem Entwurf) offen lässt, `isAdopting` zurückgesetzt. Die
Onboarding-Entwurfsübergabe (`OnboardingView`, reines `@State`-Zwischenspeichern ohne Persistenz)
liefert dafür immer `nil` — sie kann strukturell nicht fehlschlagen, unverändert ohne Persistenz.

**Geänderte/neue Komponenten:**
- `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` — Typ-Doku um drei neue Punkte A/B/C
  ergänzt; `hasIndependentPendingChanges`, `RecalculateError.independentChangesPending`;
  `PlanCreationError.createdButRebindFailed(planID:)`, `rebind`/`rebindOverrideForTesting`,
  `resolveCreatedPlan`, `createPlan`s interner Retry.
- `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` — `onGenerated`-Signatur auf `String?`
  umgestellt (Typ-Doku + `init` + `adoptPlan()`); neuer `adoptSaveErrorIsCreatedButUnresolved`-Flag
  für den eigenen direkten `createPlan`-Pfad.
- `Sources/FitnessAppUI/Workout/PlansListView.swift` / `Sources/FitnessAppUI/Settings/
  ProfileEditorView.swift` — beide Cardio-Aufrufstellen (direkter Button + `onGenerated`-Closure)
  behandeln `createdButRebindFailed` jetzt eigens; neuer `cardioAcceptErrorIsCreatedButUnresolved`-
  Flag in beiden Views.
- `Sources/FitnessAppUI/OnboardingView.swift` — `onGenerated`-Closure liefert jetzt `return nil`.
- `Sources/FitnessAppUI/DashboardView.swift` — keine Code-Änderung, aber die Lokalisierungs-Texte
  unten wurden geschärft (s. u.).
- `Sources/FitnessAppUI/Resources/Localizable.xcstrings` — 4 neue Keys
  (`planBuilder.error.createdButUnresolved.title`/`.message`,
  `cardioFeasibility.error.createdButUnresolved.title`/`.message`) plus eine Textkorrektur an
  `dashboard.onboardingPlanCreationFailed.title`/`.message` (DE/EN/TR) — die ursprüngliche
  Formulierung ("Plan konnte nicht gespeichert werden") wäre nach dieser Korrektur für den seltenen
  `createdButRebindFailed`-Fall falsch gewesen, da `OnboardingView` diesen Fall (mangels sichtbarem
  Alert an dieser Stelle, siehe Typ-Doku Punkt 4 oben) nicht vom echten Save-Fehler unterscheidet —
  neuer Text ("Hinweis zu deinem Trainingsplan" / "bitte im Plan-Tab nachsehen") ist in BEIDEN
  Fällen akkurat. Katalog jetzt 2114 Keys, weiterhin 0 hardcoded.

**Tests hinzugefügt** (`Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift`, alle
syntax-only auf Linux verifiziert, SwiftData-gated):
- `testRecalculateBlocksWhenAnUnrelatedIndependentChangeIsPending` — geforderter Test "Fremde
  offene Änderung überlebt recalculate ungespeichert".
- `testRecalculateIsNotBlockedByAPendingEditOnTheSamePlan` — Regressionsschutz: beweist direkt,
  dass die PRÄZISE (nicht die grobe `hasChanges`-)Prüfung eine Änderung AM SELBEN Plan nicht
  fälschlich blockiert.
- `testBuildReturnsAPlanThatIsVisibleAndActiveInTheCallerContext` — geforderter Test "Erfolgreiche
  Aktivierung ist auch im aufrufenden Context korrekt sichtbar".
- `testCreatePlanTransparentlyRecoversFromATransientRebindFailure` — beweist den internen
  Ein-Wiederholungsversuch in `createPlan`.
- `testCreatePlanThrowsCreatedButRebindFailedAndLaterResolvesWithoutDuplicate` — geforderter Test
  "Commit erfolgreich + Rückbindung fehlgeschlagen → Retry ohne Duplikat".

**Punkt 3 (acceptCustom/Builder-Callback) ist NICHT durch einen automatisierten Test abgedeckt —
ehrlich als Lücke benannt, nicht stillschweigend übergangen:** der geforderte Test "acceptCustom
fehlgeschlagen → derselbe bearbeitete Draft bleibt offen" prüft sichtbares SwiftUI-View-Verhalten
(Sheet bleibt offen, `@State`-Entwurf unverändert) — dieses Repository hat kein
`FitnessAppUITests`-Target und keinerlei UI-Test-Infrastruktur (bestätigt beim Audit für das
Übungs-GIF-Feature). Weder auf Linux noch auf einem echten Apple-Build ohne zusätzliche, hier nicht
beauftragte Test-Infrastruktur automatisiert prüfbar. Was STATTDESSEN belegt ist: der
`onGenerated`-Rückgabewert-Vertrag selbst (`nil`/`String?`) ist durch Code-Lesen nachvollziehbar
korrekt verdrahtet (siehe `adoptPlan()`), und `acceptCustom`s Fehler-Durchreichung (dass sie
tatsächlich wirft, statt den Fehler zu verschlucken) ist indirekt durch die
`createPlan`/`PlanGeneratorInstantiator`-Tests oben abgedeckt — das tatsächliche
UI-Offenbleiben ist bis zu einem echten Geräte-/Simulator-Test unbewiesen.

**Tests tatsächlich ausgeführt:** `swift build`/`swift build --build-tests`: grün nach jeder
Änderungsstufe. `swift test`: **1033/1033 grün — UNVERÄNDERT** gegenüber der vorherigen Runde (alle
5 neuen `PlanGeneratorInstantiatorTests` sind SwiftData-gated, tragen auf Linux nichts zur Zählung
bei — erwartungsgemäß, keine neuen Core-Tests in dieser Runde). `python3 -I
.scripts/generate_translations_md.py`: Katalog 2114/2114/2114, 0 hardcoded Strings.

**Apple-Build/CI:** weiterhin nicht durchgeführt. Für DIESE Runde zusätzlich relevant:
`ModelContext.insertedModelsArray`/`.changedModelsArray`/`.deletedModelsArray` sind laut
WebSearch-Recherche echte, dokumentierte APIs mit passendem Deployment-Target — aber wie jede
SwiftData-API in diesem gesamten Dokument NICHT durch tatsächliches Kompilieren gegen das echte
Framework verifiziert (Linux parst nur die Syntax des `#if canImport(SwiftData)`-Blocks, prüft
niemals die Typen/Signaturen dagegen, siehe die entsprechende Präzisierung im vorherigen
Berichtsabschnitt).

**Bekannte Grenzen/Risiken (zusätzlich zu den bereits genannten):**
- Punkt 3 bleibt ohne automatisierten Test (s. o.) — eine manuelle Geräteprüfung ("Plan anpassen"
  → absichtlich einen Speicherfehler erzwingen → Sheet bleibt mit Entwurf offen, Alert zeigt
  Fehler) ist Teil der weiterhin ausstehenden Apple-Prüfung.
- `createPlan`s automatischer Ein-Retry (Punkt 2) könnte im sehr seltenen Fall eines dauerhaft
  kaputten Stores wirkungslos verpuffen (beide Versuche scheitern) — in diesem Fall bleibt der Plan
  zwar persistiert, aber in KEINER UI sichtbar, bis die App neu gestartet wird (frischer Context).
  Bewusst nicht weiter abgesichert — ein zweiter automatischer Retry oder ein periodischer
  Hintergrund-Check wären genau die "weitere große Architektur", die diese Runde ausschließt.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** unverändert P3 — Task #197 bleibt `in_progress`, bis ein echter Apple-Build/
Testlauf (inklusive der in dieser UND der vorherigen Runde neu eingeführten SwiftData-APIs) sowie
eine manuelle Geräteprüfung von Punkt 3 vorliegen.

## Task #197-Nachbesserung, dritte Korrekturrunde (UI-Retry war noch nicht duplikatsicher)

**Befund des Users, der diese Runde auslöste:** die zweite Korrekturrunde hatte
`PlanCreationError.createdButRebindFailed(planID:)` eingeführt und `createPlan` einen internen
Ein-Retry gegeben — aber an den UI-Aufrufstellen wurde die `planID` aus diesem Fehler NIRGENDS
festgehalten. Nach einem dauerhaften Rebind-Fehler (Commit erfolgreich, aber auch der interne
Retry scheitert) zeigten `PlansListView`/`ProfileEditorView`/`PlanBuilderView` nur eine
Fehlermeldung und setzten den normalen "Übernehmen"-Button wieder scharf — ein erneuter Tap hätte
`build`/`createPlan` ein ZWEITES Mal aufgerufen und einen echten Duplikat-Plan angelegt. Der
Service-Test aus der zweiten Runde (`PlanGeneratorInstantiatorTests`) bewies nur, dass `createPlan`
selbst EINEN internen Retry unternimmt — er bewies NICHT, dass ein wiederholter Button-Tap sicher
ist, weil dieser Vertrag gar nicht am Service, sondern erst an der UI-Verdrahtung existierte (oder
eben nicht existierte).

**Neue, UI-unabhängige Zustandsmaschine `PlanCreationOperation`** (`Sources/FitnessAppData/
PlanCreationOperation.swift`, `@MainActor final class`, SwiftData-abhängig aber KEIN SwiftUI-Import
— exakt dasselbe Testmuster wie `PlanGeneratorInstantiatorTests`): hält `committedPlanID:
PersistentIdentifier?` PERMANENT fest, sobald einmal bekannt. `attempt(in:create:)` ruft das
übergebene `create()` NUR auf, solange `committedPlanID == nil` — ist es gesetzt, wird `create()`
STRUKTURELL NICHT MEHR AUFGERUFEN, nur noch `PlanGeneratorInstantiator.resolveCreatedPlan`
versucht. Vier Ausgänge (`Outcome`): `.success(TrainingPlan)`, `.nothingToCreate` (bestehende
Konvention: `create()` liefert `nil`, kein Fehler), `.failedBeforeCommit` (nichts persistiert,
voller Retry sicher) und `.committedButUnresolved` (NIE wieder `create()`, nur auflösen). Bewusst
OHNE eigene Lokalisierung — `FitnessAppData` kennt `FitnessAppUI`s Bundle nicht, der Aufrufer leitet
seine Nachricht aus dem typisierten `Outcome` ab, nicht umgekehrt.

**`onGenerated`-Vertrag (`PlanBuilderView`) ein drittes Mal verschärft:** liefert jetzt
`PlanBuilderHandoffOutcome` (`.success`/`.failedBeforeCommit`/`.committedButUnresolved`, OHNE
Payload — anders als `PlanCreationOperation.Outcome`, weil die Onboarding-Entwurfsübergabe gar
keinen `TrainingPlan` hat, nur einen Draft) statt des vorherigen `String?`. `PlanBuilderView` leitet
ihre eigene, bereits vorhandene lokalisierte Nachricht selbst aus diesem Zustand ab — der Cardio-
Aufrufer liefert keinen fertigen Text mehr.

**Drei "Operation"-Instanzen, nicht eine globale:** jede Übernahme-Aktion bekommt ihre EIGENE
`PlanCreationOperation` als `@State` — `PlanBuilderView`s eigener Pfad, `PlansListView`/
`ProfileEditorView`s direkter Button (`acceptOperation`) UND deren jeweiliges "Plan anpassen"-Sheet
(`acceptCustomOperation`, bewusst NEU erzeugt bei jedem Sheet-Öffnen, damit eine neue
Bearbeitungssitzung nie den committed-Zustand einer früheren erbt).

**Punkt 5 (kein irreführendes "Übernehmen" mehr):** alle drei Haupt-Buttons prüfen
`operation.committedPlanID != nil` und zeigen dann "Erneut versuchen" (neuer Key
`{planBuilder.result,plans.cardioFeasibility,profile.cardio.feasibility}.retryResolve`) statt
"Plan übernehmen" — derselbe Button-Handler ruft strukturell ohnehin nur noch `resolveCreatedPlan`
auf, das Label macht das jetzt auch sichtbar. Keine automatische Neuanlage nach weiterem
Rebind-Fehler — es gibt bewusst KEINE Reset-Funktion auf `PlanCreationOperation`; ein wirklich neuer
Versuch braucht eine neue Instanz (z.B. ein frisch geöffnetes Sheet oder ein neu geladener Screen).

**Geänderte/neue Komponenten:**
- `Sources/FitnessAppData/PlanCreationOperation.swift` — NEU.
- `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` — `PlanBuilderHandoffOutcome` (neuer
  Top-Level-Typ), `onGenerated`-Signatur erneut geändert, `creationOperation`-State,
  `adoptPlan()` komplett auf `creationOperation.attempt(...)` umgestellt, Haupt-Button-Label
  bedingt auf `planBuilder.result.retryResolve`.
- `Sources/FitnessAppUI/Workout/PlansListView.swift` / `Sources/FitnessAppUI/Settings/
  ProfileEditorView.swift` — `acceptOperation`/`acceptCustomOperation`-State, beide
  Aufrufstellen (direkter Button + Sheet-Closure) auf `attempt(...)` umgestellt, Button-Label
  bedingt, `acceptCustomOperation` wird beim Öffnen des Sheets neu erzeugt.
- `Sources/FitnessAppUI/Resources/Localizable.xcstrings` — 3 neue `.retryResolve`-Keys
  (DE/EN/TR). Katalog jetzt 2117 Keys, weiterhin 0 hardcoded.

**Tests hinzugefügt** (`Tests/FitnessAppDataTests/PlanCreationOperationTests.swift`, NEU — bewusst
in einer eigenen Datei, nicht in `PlanGeneratorInstantiatorTests.swift`, weil ein anderer Typ
geprüft wird):
- `testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan` — der geforderte
  Regressionstest: erster Aufruf speichert genau einen Plan, Rebind scheitert DAUERHAFT
  (`rebindOverrideForTesting` bleibt gesetzt), 3x wiederholtes `attempt(...)` ruft `create()` kein
  einziges Mal erneut auf (per Zähler bewiesen), Anzahl persistierter Pläne bleibt bei eins über
  alle Wiederholungen; nach Entfernen des Overrides löst ein weiterer Versuch dieselbe ID auf,
  immer noch ohne `create()` erneut aufzurufen.
- `testFirstAttemptSucceedsNormallyWithoutAnyRebindIssue` — Gegenprobe: Normalfall bleibt
  `committedPlanID == nil`.
- `testNothingToCreateDoesNotMarkAnythingAsCommitted` — ein leeres Generator-Ergebnis markiert
  nichts als committed.
- `testGenuineSaveFailureIsRetryableAndDoesNotMarkAnythingAsCommitted` — ein ECHTER Speicherfehler
  (nichts persistiert) bleibt voll wiederholbar, bewusst anderer Vertrag als
  `committedButUnresolved`.

**Ausdrücklich "möglichst unabhängig von SwiftUI testbar" (User-Vorgabe) — präzise eingeordnet, NICHT
mit "läuft auf Linux" verwechselt:** `PlanCreationOperation` und seine Tests haben keinerlei
SwiftUI-/`@State`-/View-Abhängigkeit — reines `ModelContainer`/`ModelContext`-Setup, identisch zum
bestehenden `PlanGeneratorInstantiatorTests`-Muster. Das ist etwas ANDERES als "läuft auf Linux":
die Datei bleibt `#if canImport(SwiftData)`-gated, und `canImport(SwiftData)` ist auf Linux
ebenfalls `false` — die 4 neuen Tests sind deshalb weiterhin NUR syntax-geprüft hier (bestätigt:
`swift test` blieb bei 1033/1033, unverändert), nicht ausgeführt. Der Unterschied zu einem
UI-Test ist aber real und für einen künftigen Apple-Lauf wichtig: auf einem echten Gerät/Simulator
liefe dieser Test als reiner Swift-/SwiftData-Integrationstest OHNE jede UI-Interaktion nötig zu
haben — eine ganz andere (und deutlich leichter zu automatisierende) Kategorie als "prüfe, ob ein
Sheet sichtbar offen bleibt".

**Was weiterhin NICHT automatisiert geprüft ist, ehrlich benannt:** dass die UI tatsächlich
"Erneut versuchen" statt "Plan übernehmen" ANZEIGT, dass ein zweiter Tap wirklich NICHTS Neues auf
dem Bildschirm auslöst, und das Sheet-Offen-Bleiben bei `.committedButUnresolved` selbst — all das
bleibt UI-Verhalten, für das (unverändert) kein `FitnessAppUITests`-Target in diesem Repository
existiert. Was die neue Zustandsmaschine beweist, ist der KORREKTE VERTRAG, den die UI-Views jetzt
verwenden (sie rufen `attempt(...)` korrekt auf, codegelesen verifiziert) — nicht, dass SwiftUI das
auch tatsächlich pixelgenau so rendert.

**Tests tatsächlich ausgeführt:** `swift build`/`swift build --build-tests`: grün nach jeder
Änderungsstufe. `swift test`: **1033/1033 grün — unverändert** (wie erwartet: alle neuen Tests
SwiftData-gated). `python3 -I .scripts/generate_translations_md.py`: Katalog 2117/2117/2117, 0
hardcoded Strings.

**Apple-Build/CI:** weiterhin nicht durchgeführt — unverändert keine Xcode-Umgebung in diesem
Container.

**Bekannte Grenzen/Risiken (zusätzlich zu den bereits genannten):**
- `CardioFeasibilityCardModel.accept`/`.acceptCustom`s eigener Postlude (`profile.cardioGoal =`/
  Fingerprint-Fortschreibung) läuft NUR, wenn die jeweilige Funktion selbst bis zu ihrem `return`
  kommt. Im seltenen Fall "committed-aber-unresolved, User tippt SPÄTER erneut, Resolve gelingt
  jetzt" löst `PlanCreationOperation` direkt über `resolveCreatedPlan` auf, OHNE `accept`/
  `.acceptCustom` ein zweites Mal aufzurufen (das würde ja wieder `create()` bedeuten) — der
  Postlude bleibt in diesem spezifischen Fall aus. Bewusst akzeptierter, kosmetischer Kompromiss
  (keine Datenkorruption, kein Duplikat): die Machbarkeits-Karte könnte dem Nutzer theoretisch
  erneut denselben Vorschlag zeigen, obwohl faktisch schon ein Plan dafür existiert. Keine weitere
  Architektur dafür eingeführt, wie vom User für diese Runde verlangt.
- `PlanCreationOperation` hat bewusst keine Reset-Funktion — ein Screen, der dieselbe `@State`-
  Instanz über sehr lange Zeit am Leben hält (z.B. nie neu geladen), bliebe nach einem einmaligen
  `committedButUnresolved` für den Rest seiner Lebensdauer im "nur noch auflösen"-Modus. Für die
  drei betroffenen Screens unproblematisch: jedes Sheet bekommt ohnehin eine frische Instanz pro
  Öffnung, die beiden Direkt-Buttons leben nur so lange wie `PlansListView`/`ProfileEditorView`
  selbst (Navigation weg und zurück erzeugt eine neue Instanz).

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** unverändert P3 — Task #197 bleibt `in_progress`, bis ein echter Apple-Build/
Testlauf UND eine manuelle Geräteprüfung (insbesondere: Sheet bleibt bei `.committedButUnresolved`
offen, Button-Label wechselt korrekt, ein tatsächlich wiederholter Tap legt wirklich keinen
zweiten Plan an) vorliegen.

## Task #197-Nachbesserung, vierte Korrekturrunde (übersehene Aufrufstelle, Commit-Lücke bei
Normalfall-Erfolg, Cardio-Postlude nicht länger "kosmetischer Kompromiss")

**Drei eng begrenzte Korrekturen, vom User nach Prüfung der dritten Runde verlangt** — die
Zustandsmaschine selbst wurde als richtige Richtung bestätigt, aber mit einer real übersehenen
Aufrufstelle und zwei verbliebenen Lücken, die die dritte Runde noch nicht geschlossen hatte.

**Punkt 1 — übersehene Onboarding-Aufrufstelle, UND der konkrete Beweis für die
Linux-`#if`-Blindstelle:** als `onGenerated`s Rückgabetyp in der dritten Runde von `String?` auf
`PlanBuilderHandoffOutcome` geändert wurde, blieb `OnboardingView.swift`s eigener
`PlanBuilderView { ... }`-Aufruf unverändert bei `return nil` stehen — ein echter Typfehler
(`nil` ist kein `PlanBuilderHandoffOutcome`). Das hätte ein sofortiger Kompilierfehler sein
müssen. Es war keiner, weil `OnboardingView.swift` komplett hinter
`#if canImport(SwiftUI) && canImport(SwiftData)` liegt — auf Linux `false` — und ein inaktiver
`#if`-Zweig dort nachweislich nur noch LEXIKALISCH/SYNTAKTISCH geparst, nie mehr
semantisch/typgeprüft wird. Diese Engagement-weite Einschränkung war bereits zuvor durch einen
gezielten Syntax-Injektionstest belegt worden — hier hat sie sich zum ERSTEN MAL als Ursache
eines ECHTEN, vom User gefundenen Bugs bestätigt, nicht nur als theoretisches Risiko. Fix:
`return nil` → `return .success` (reine Entwurfsübergabe kann strukturell nicht fehlschlagen,
siehe bestehende Typ-Doku). Danach alle vier `PlanBuilderView(`-Aufrufstellen im gesamten
`Sources/`-Baum per `Grep` erneut geprüft (User-Vorgabe: "alle Callback-Aufrufstellen prüfen"):
`ProfileEditorView.swift:1121` und `PlansListView.swift:378` (beide `acceptCustom`-Sheets) waren
bereits korrekt auf `PlanBuilderHandoffOutcome` umgestellt, `PlansListView.swift:165` hat gar
keinen `onGenerated`-Parameter (eigenständiger Erstellen-Pfad, unbetroffen) — `OnboardingView.swift`
war die einzige verbliebene, jetzt behobene Stelle. **Konsequenz für die gesamte bisherige
Verifikationsdisziplin dieses Dokuments:** jede Aussage "kompiliert auf Linux" für
SwiftUI-/SwiftData-gated Code bedeutet ab sofort noch strikter nur "syntaktisch plausibel", NIE
"typkorrekt" — dieser Fund ist der empirische Beleg dafür, nicht nur die Begründung.

**Punkt 2 — `committedPlanID` fehlte beim ganz normalen Erfolg:** `PlanCreationOperation.attempt`
setzte `committedPlanID` bisher NUR im `catch
PlanGeneratorInstantiator.PlanCreationError.createdButRebindFailed`-Zweig. Ein völlig
problemloser Erfolg (kein Rebind-Fehler) ließ `committedPlanID == nil` — ein wiederholter
`attempt(...)`-Aufruf DANACH (z. B. durch einen nicht korrekt gesperrten Doppel-Tap-Pfad) hätte
`create()` ein zweites Mal aufgerufen und einen echten zweiten Plan angelegt. Die
"nie wieder `create()`"-Garantie der dritten Runde galt also faktisch nur für den
Rebind-Fehlerfall, nicht uneingeschränkt. Fix: `committedPlanID = plan.persistentModelID` läuft
jetzt unconditioniert im Erfolgspfad VOR dem `return .success(plan)`, nicht mehr nur im
`catch`-Zweig — die Garantie gilt jetzt ab JEDEM Commit, exakt wie der Typname es verspricht.

**Punkt 3 — Cardio-Postlude: von "akzeptierter kosmetischer Kompromiss" zu tatsächlich
idempotent nachholbar:** die dritte Runde hatte den Umstand, dass `profile.cardioGoal =`/die
Fingerprint-Fortschreibung bei einer SPÄTER (nach permanentem Rebind-Fehler) aufgelösten
Übernahme NICHT nachlaufen, als akzeptables Risiko eingeordnet. Der User hat das ausdrücklich
zurückgewiesen: der fachliche Abschluss muss von der eigentlichen Planerstellung GETRENNT, aber
genauso idempotent wiederaufnehmbar gemacht werden, unter Verwendung der BESTÄTIGTEN Angaben des
URSPRÜNGLICHEN Vorgangs. Umsetzung: `PlanCreationOperation.attempt(in:create:completion:)` bekam
einen neuen optionalen `completion: (() -> Void)?`-Parameter plus private `pendingCompletion`-
Ablage. Die beim ALLERERSTEN Aufruf, der einen Commit erreicht (egal ob sofortiger Erfolg oder
`createdButRebindFailed`), übergebene Closure wird gespeichert und exakt einmal ausgeführt,
sobald `resolveCreatedPlan` (ob sofort in `attempt` oder später über `resumeIfCommitted`)
tatsächlich erfolgreich auflöst — spätere Aufrufe können eine NEUE Closure übergeben, die dann
bewusst IGNORIERT wird (nur `pendingCompletion == nil ? completion : nichts` wird je
übernommen), damit garantiert nur die ursprünglich bestätigten Werte verwendet werden, nie eine
zwischenzeitlich neu berechnete. `CardioFeasibilityCardModel.accept`/`.acceptCustom` wurden
entsprechend umgebaut: beide rufen zuerst `operation.resumeIfCommitted(in:)` auf (damit ein
späterer Resume nicht an `accept`s eigenen Vorbedingungen wie `hasPlan` scheitert, falls sich das
Profil zwischenzeitlich geändert hat) und reichen ihren bisherigen Postlude als `completion`-
Closure an `operation.attempt(...)` durch — `accept` schnappt sich `proposedGoal`/`raceDate`/
`weeklyVolume`, `acceptCustom` den `fingerprint` jeweils zum Zeitpunkt DIESES Aufrufs als lokale
Konstanten, bevor sie in die Closure eingefangen werden. Beide Funktionen verloren dabei `throws`
— sie geben jetzt `PlanCreationOperation.Outcome?` direkt zurück (`nil` nur, wenn ihre eigenen
Vorbedingungen gar nicht erfüllt sind), der Aufrufer leitet alles daraus ab.

**Zusätzlicher kleiner UI-Fix (vom User explizit mitverlangt):** im `onGenerated`-Pfad (externer
Handoff, z. B. Cardios "Plan anpassen"-Sheet) liegt die tatsächliche `PlanCreationOperation` beim
AUFRUFER (`acceptCustomOperation` in `PlansListView`/`ProfileEditorView`), nicht bei
`PlanBuilderView`s eigener `creationOperation` — letztere blieb bei einem von außen gemeldeten
`.committedButUnresolved` unverändert `nil`, wodurch der Haupt-Button fälschlich weiter
"Plan übernehmen" statt "Erneut versuchen" gezeigt hätte. Neuer State
`externalHandoffIsCommittedButUnresolved` (gesetzt im `.committedButUnresolved`-Zweig des
`onGenerated`-Switches in `adoptPlan()`), per `||` in die Label-Bedingung in `navigationBar`
aufgenommen. Reine Label-Korrektur — die eigentliche Duplikat-Sicherheit für diesen Pfad lag
bereits vorher vollständig beim Aufrufer (dessen `resumeIfCommitted`-zuerst-Logik verhindert ein
zweites `create()` unabhängig von dieser View).

**Geänderte Komponenten:**
- `Sources/FitnessAppUI/OnboardingView.swift` — `return nil` → `return .success` (Punkt 1).
- `Sources/FitnessAppData/PlanCreationOperation.swift` — `committedPlanID` jetzt auch im
  Erfolgspfad gesetzt (Punkt 2); neuer `completion`-Parameter + `pendingCompletion`-Ablage +
  `runPendingCompletionIfNeeded()` (Punkt 3).
- `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift` — `accept`/`acceptCustom` auf
  `using operation: PlanCreationOperation` + `completion:`-Closure umgebaut, kein `throws` mehr,
  geben `PlanCreationOperation.Outcome?` direkt zurück, rufen `resumeIfCommitted` zuerst auf.
- `Sources/FitnessAppUI/Workout/PlansListView.swift` / `Sources/FitnessAppUI/Settings/
  ProfileEditorView.swift` — beide Aufrufstellen (Direkt-Button + Sheet-Closure) rufen jetzt
  `model.accept(...using:)`/`model.acceptCustom(...using:)` direkt auf, statt sie selbst in
  einen eigenen `operation.attempt(...)`-Aufruf zu wrappen (das übernimmt `accept`/`acceptCustom`
  jetzt intern); `switch` behandelt `nil` als eigenen Fall (Vorbedingung nicht erfüllt).
- `Sources/FitnessAppUI/Workout/PlanBuilderView.swift` — neuer State
  `externalHandoffIsCommittedButUnresolved`, Label-Bedingung erweitert (UI-Fix).
- Keine neuen Lokalisierungs-Keys — alle Änderungen sind rein intern (Logik/Typen), alle
  wiederverwendeten Strings existierten bereits aus früheren Runden. Katalog unverändert bei
  2117/2117/2117.

**Tests geändert/ergänzt** (`Tests/FitnessAppDataTests/PlanCreationOperationTests.swift`):
- `testFirstAttemptSucceedsNormallyWithoutAnyRebindIssue` korrigiert: prüfte vorher
  `XCTAssertNil(operation.committedPlanID, ...)` — das war nach Punkt 2 falsch geworden und
  prüft jetzt `XCTAssertEqual(operation.committedPlanID, plan.persistentModelID, ...)`.
- `testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce` — NEU, exakt der vom User
  geforderte Test "Erfolg → erneuter Versuch → weiterhin genau ein create-Aufruf": erster
  `attempt(...)` liefert `.success`, 3 weitere Wiederholungen liefern weiterhin `.success` mit
  DERSELBEN `persistentModelID`, `createCallCount` bleibt bei 1, genau ein Plan persistiert.
- `testCompletionRunsExactlyOnceOnImmediateSuccess` — NEU: `completion` läuft bei sofortigem
  Erfolg genau einmal, ein wiederholter (bereits committeter) Aufruf mit neuer Closure löst sie
  nicht nochmal aus.
- `testCompletionFromFirstCallReplaysExactlyOnceOnLaterResolutionIgnoringNewerClosures` — NEU:
  simuliert permanenten Rebind-Fehler (`rebindOverrideForTesting`), belegt dass die BEIM ERSTEN
  AUFRUF übergebene `completion` weder beim ursprünglichen `.committedButUnresolved` noch bei
  einem Zwischenversuch läuft, sondern erst bei der späteren erfolgreichen Auflösung (hier über
  `resumeIfCommitted`, dem tatsächlichen Resume-Pfad) — und dass eine bei diesem Zwischenversuch
  NEU übergebene Closure dabei nie ausgeführt wird, nur die ursprüngliche.
- Bestehende vier Tests der dritten Runde unverändert grün.

**Tests tatsächlich ausgeführt:** `swift build` nach jeder einzelnen Dateiänderung grün (gezielt
mit `touch` erzwungen, um inkrementelles Caching bei reinen Signaturänderungen auszuschließen).
`swift build --build-tests` grün. `swift test`: **1033/1033 grün — unverändert**, exakt wie
erwartet, da `PlanCreationOperationTests.swift` weiterhin komplett `#if canImport(SwiftData)`-
gated ist (auf Linux `false`) — alle vier neuen/geänderten Tests dort sind damit weiterhin NUR
syntax-geprüft, nicht ausgeführt. Einzige in diesem gesamten Engagement tatsächlich auf Linux
ausgeführte Tests bleiben `OnboardingPlanCreationNoticeTests` (reines Foundation/UserDefaults,
aus einer früheren Runde).

**Was dieser Fund für die Selbsteinschätzung bedeutet (ehrlich benannt):** Punkt 1 ist der
Beleg, dass "kompiliert auf Linux" für jede SwiftUI-gated Datei in diesem gesamten Dokument
IMMER nur syntaktische Plausibilität belegt hat, nie Typkorrektheit — auch wenn das an jeder
einzelnen Stelle so benannt wurde, hat genau diese Lücke hier real einen Bug durchgelassen, den
erst der User beim Lesen des Diffs gefunden hat. Für JEDEN bisherigen und künftigen
SwiftUI-/SwiftData-Codeabschnitt in diesem Projekt gilt deshalb: ein manueller Review des Diffs
durch eine Person mit Zugriff auf einen echten Swift-Compiler (Xcode/Apple-CI) ist nicht optional
"zusätzliche Sicherheit", sondern die EINZIGE Stelle, an der Typfehler in diesem Code überhaupt
auffallen können, solange diese Session nur auf Linux läuft.

**Apple-Build/CI:** weiterhin nicht durchgeführt — unverändert keine Xcode-Umgebung in diesem
Container. Das ist jetzt ausdrücklich die vom User gesetzte NÄCHSTE Priorität, nicht mehr nur
eine Randbemerkung.

**Bekannte Grenzen/Risiken (Rest aus der dritten Runde, soweit nicht durch diese Runde behoben):**
- Der in der dritten Runde genannte "kosmetische Kompromiss" beim Cardio-Postlude ist durch
  Punkt 3 dieser Runde behoben (completion läuft jetzt auch bei später aufgelöstem Resume nach) —
  aus der Liste bekannter Grenzen entfernt.
- `PlanCreationOperation` hat weiterhin bewusst keine Reset-Funktion — unverändert, siehe dritte
  Runde.
- Unverändert ungeprüft: dass die UI tatsächlich "Erneut versuchen" ANZEIGT, dass ein zweiter Tap
  wirklich nichts Neues auslöst, und das Sheet-Offen-Bleiben bei `.committedButUnresolved` selbst
  — weiterhin reines UI-Verhalten ohne `FitnessAppUITests`-Target in diesem Repository.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe (User-Vorgabe, ausdrücklich keine weitere Erweiterung von Task #197):** echter
Apple-Build und Ausführung der Data-Tests priorisieren. P3-Finalübernahme bleibt bis dahin
weiterhin nicht abgenommen. Task #197 bleibt `in_progress`.

## Verifikationsstatus zu Commit 185b6cd: reale externe CI gefunden, von dieser Session aus nicht
einsehbar

**Auslöser:** User verlangte getrennten Nachweis (1) echte Apple-Kompilierung, (2) tatsächlich
ausgeführte Data-Tests, (3) gezielte Simulator-/Geräteprüfung für Commit `185b6cd` — ausdrücklich
NICHT nochmal nur Linux als Ersatz. Reine Verifikationsrunde, keine Code-Änderung an
`PlanCreationOperation`/den UI-Aufrufstellen.

**Fund: `codemagic.yaml` existiert bereits und deckt genau das ab.** Zwei der drei konfigurierten
Workflows lösen laut `branch_patterns: {pattern: '*', include: true}` bei JEDEM Push auf JEDEN
Branch automatisch aus, auf echten `mac_mini_m2`-Instanzen mit echtem Xcode:
- `swift-package` — `swift build`, `swift test --parallel` (komplette Suite, echtes Xcode/macOS,
  SwiftData/SwiftUI existieren dort wirklich — keine `#if canImport`-Leerlauf-Kompilierung mehr),
  danach `xcodebuild build` für jedes der 5 Library-Produkte einzeln fürs iOS-Simulator-SDK
  (`FitnessAppCore/Data/Health/Activities/UI`).
- `ios-app` — generiert per XcodeGen das `.xcodeproj`, baut App + Widget-Extension komplett für
  iOS Simulator.
Beide sollten durch den Push von `185b6cd` auf `claude/smart-onboarding-epic` bereits ausgelöst
worden sein — das ist aus dieser Session heraus NICHT bestätigbar: kein Codemagic-API-Token in
dieser Umgebung konfiguriert (geprüft), keine GitHub-Actions-Workflows in diesem Repo (0, geprüft
per `actions_list`), keine offene PR, keine Tool-Bridge zwischen Codemagic-Ergebnissen und
GitHub Checks/Status in dieser Session verfügbar. Das erklärt rückwirkend auch frühere
"Apple-CI-Fund"-Referenzen in diesem Dokument (z.B. Task #175) — diese kamen vermutlich aus genau
dieser Codemagic-Pipeline, nicht aus einer in dieser Session je selbst ausgeführten Prüfung.

**Konkret benannter externer Schritt (User-Vorgabe):**
1. Codemagic-Dashboard, Commit `185b6cd`, Branch `claude/smart-onboarding-epic`, Workflows
   `swift-package` + `ios-app` — Status + Build-Log.
2. Alternativ: E-Mail an a.isik@atamya.com — `ios-app` benachrichtigt laut `codemagic.yaml` IMMER
   (Erfolg wie Fehler), `swift-package` NUR bei Fehler.
3. Alternativ: ein Read-only-Codemagic-API-Token als Network-Secret in dieser Umgebung hinzufügen
   — dann kann diese Session Status/Log selbst abrufen.

**Tatsächlicher Testzahlen-Abgleich (per `grep -c "func test"`, Gegenprobe exakt stimmig):**
1240 Testfunktionen im gesamten Repository, davon 207 hinter `#if canImport(SwiftData)` bzw.
`#if canImport(SwiftUI)` gated (1240 − 207 = 1033 = exakt der etablierte Linux-Wert — bestätigt
die Zählmethode). Die 207 Apple-only-Funktionen verteilen sich auf 16 Dateien, darunter namentlich
die vom User verlangten:
- `PlanCreationOperationTests` — 7 Tests (komplett aus dritter/vierter Runde).
- `PlanGeneratorInstantiatorTests` — 35 Tests, darunter `testCreatePlanPropagatesSaveFailure`,
  `testFailedCreationIsRepeatableWithoutOrphanedObjects`,
  `testCreatePlanTransparentlyRecoversFromATransientRebindFailure`,
  `testCreatePlanThrowsCreatedButRebindFailedAndLaterResolvesWithoutDuplicate`.
- Übrige 165 Funktionen in 14 weiteren `FitnessAppDataTests`-Dateien + 2 `FitnessAppUITests`-
  Dateien (`EditorDiscardSnapshotTests`, `ExerciseTemplateIDBackfillTests` — Resource-/Discard-
  Checks, nicht Task-#197-relevant).

**Simulator-/Geräteprüfung — 6 geforderte Punkte gegen tatsächliche Abdeckung abgeglichen:**
4 der 6 Punkte (Normalfall kein Duplikat, Fehler-vor-Commit wiederholbar, Commit-aber-unresolved
löst nur dieselbe ID auf, spätere Auflösung holt den Postlude genau einmal nach) sind inhaltlich
bereits durch die oben genannten Data-Tests automatisiert bewiesen, sobald deren Ausführung auf
Apple bestätigt ist — über die echten Seams `rebindOverrideForTesting`/`saveOverrideForTesting`,
nicht durch Abwarten eines zufälligen Fehlers. Die übrigen 2 Punkte (korrekter Button-/Alert-
Zustand bei Builder/externem Cardio-Handoff; Onboarding-Entwurf erzeugt keinen vorzeitigen Plan)
sind rein sichtbares UI-Verhalten, für das kein automatisiertes UI-Test-Target in diesem
Repository existiert (`FitnessAppUITests` enthält nur Resource-/Discard-Unit-Tests, keine
XCUITest-Automatisierung).

**Wichtiger Befund dabei:** `rebindOverrideForTesting`/`saveOverrideForTesting` sind `internal`
und ausdrücklich nur für `@testable import` aus In-Prozess-XCTests gedacht (siehe deren eigene
Doku-Kommentare in `PlanGeneratorInstantiator.swift`). In der echten, kompilierten App gibt es
AKTUELL KEINE Möglichkeit, die beiden Fehlerzustände ("Fehler vor Commit", "Rebind-Fehler")
manuell im Simulator auszulösen — auch ein Mensch mit Xcode kann das ohne zusätzliche
Instrumentierung nicht nachstellen. Nur der Normalfall-Teil beider UI-only-Punkte ist ohne
Weiteres manuell im Simulator prüfbar.

**User-Entscheidung (gefragt, nicht selbst entschieden):** ob für die zwei nicht auslösbaren
Fehlerzustände eine schmale `#if DEBUG`-Instrumentierung ergänzt werden soll, bevor Task #197
geschlossen wird. Antwort: **zurückstellen** — erst Punkt 1 (Apple-Kompilierung) und Punkt 2
(Data-Tests) über einen der drei oben genannten externen Wege bestätigen, die
Instrumentierungs-Entscheidung folgt danach. Kein Code in dieser Runde geändert.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`, dieser Eintrag wird mit dem nächsten
Commit mitgeführt (reine Dokumentation, kein Produktivcode betroffen).

**Nächste Aufgabe:** auf externe Bestätigung von Codemagic (Commit `185b6cd`, Workflows
`swift-package` + `ios-app`) warten — per Dashboard, E-Mail oder einem der Session bereitgestellten
API-Token. Erst danach: Instrumentierungs-Entscheidung für die 2 offenen Simulator-Punkte, dann
Task #197 abschliessen. Keine weitere Erweiterung bis dahin.

## Echter Apple-Testlauf liefert zwei konkrete Regressionsbefunde (testflight-Build #19,
"Run unit tests (Release-Gate)")

**Auslöser:** User lädt das reale Codemagic-Build-Log des `testflight`-Workflows (Build #19,
Schritt "Run unit tests (Release-Gate)") hoch — echtes Xcode 26.6 / macOS-SDK 26.5 /
`arm64e-apple-macos14.0`, `swift test --parallel`, 1240 Tests selektiert. Das ist der erste Fall in
diesem gesamten Dokument, in dem tatsächlich ausgeführter Apple-Testoutput (nicht nur
Linux-Syntaxpruefung) vorliegt — und er enthält vier echte, deterministische Fehlschläge, kein
Flake. Alle vier reproduzieren denselben Code-Pfad (`recalculate`), alle vier liegen in Code aus
früheren Task-#197-Runden, alle vier waren auf Linux UNSICHTBAR, weil
`PlanGeneratorInstantiator.swift`/-`Tests.swift` komplett hinter `#if canImport(SwiftData)` liegen
(dort `false`) — bestätigt den immer wieder benannten Verifikationsvorbehalt dieses Dokuments ein
weiteres Mal, diesmal mit zwei konkreten, nicht-trivialen Bugs statt nur einem Typfehler.

**Fund 1 — `hasIndependentPendingChanges` blockierte `recalculate` faelschlich bei eigener
Session-/Log-Historie (3 Fehlschläge):** `testRecalculateSkipsDayWithActiveSessionAndReportsIt`,
`testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact`,
`testRecalculateSkipsSaveEntirelyWhenNothingWasRewritten` warfen alle
`RecalculateError.independentChangesPending` statt wie erwartet zu arbeiten. Root Cause: diese
Tests inserten eine `WorkoutSession`/einen `ExerciseLog` (fuer einen Tag/eine Uebung DES Plans) in
denselben Context, OHNE vorher zu speichern, und rufen dann `recalculate` auf — genau das
Szenario, das die zweite Korrekturrunde dieses Dokuments absichtlich ermoeglichen wollte (ein Tag
mit laufender/abgeschlossener Session soll uebersprungen, nicht blockiert werden). Die Funktion
`hasIndependentPendingChanges` (Nachbesserung, zweite Korrekturrunde, Punkt A) kannte als "eigen"
aber nur `plan`/`days`/`exercises` — eine pendente `WorkoutSession`/ein pendenter `ExerciseLog`,
der sich auf einen Tag/eine Uebung DIESES Plans bezieht, zaehlte faelschlich als "unabhaengig" und
loeste denselben Block aus, den `testRecalculateBlocksWhenAnUnrelatedIndependentChangeIsPending`
(ein WIRKLICH unabhaengiges `UserBodyProfile`) korrekt ausloest. Fix:
`hasIndependentPendingChanges` prueft jetzt zusaetzlich, ob ein pendentes Objekt eine
`WorkoutSession` (ueber `session.day`) oder ein `ExerciseLog` (ueber `log.exercise` ODER
`log.session?.day`) ist, das sich auf einen Tag/eine Uebung DIESES Plans bezieht — in dem Fall
zaehlt es nicht als unabhaengig. `PersonalRecordEntry` (hat ebenfalls `session: WorkoutSession?`)
bewusst NICHT mit aufgenommen: `recalculate` liest/beruecksichtigt `PersonalRecordEntry` an keiner
Stelle, ein pendenter Eintrag ist fuer diese Operation also tatsaechlich unabhaengig — anders als
bei `WorkoutSession`/`ExerciseLog`, die `recalculate` selbst aktiv abfragt
(`fetchAllSessions`/`daysWithAnySession`).

**Fund 2 — `revert(...)` liess geloeschte, nie gespeicherte Uebungen im Tag haengen (1
Fehlschlag):** `testRecalculateSaveFailureLeavesNoStructuralChangeEvenAfterLaterSave` verglich
`Set(day.activeExercises.map(\.persistentModelID))` nach einem simulierten Speicherfehler gegen die
urspruengliche Menge — die Fehlermeldung zeigte keine reine Reihenfolgen-Differenz (wie der erste
Blick auf die `[...]`-Druckausgabe nahelegt, da `Set`s mit derselben Bracket-Syntax wie Arrays
drucken), sondern einen echten INHALTS-Unterschied: 12 statt 6 Elemente — die 6 urspruenglichen
PLUS 6 neu eingefuegte, nie gespeicherte Uebungen mit TEMPORAEREN `PersistentIdentifier`s, die
`revert(...)` eigentlich per `context.delete(...)` wieder entfernt haben sollte. Root Cause: ein
`context.delete(...)` auf einem frisch inserteten, NIE gespeicherten Objekt aktualisiert die
Swift-seitige `day.exercises`-Relationship-Array-Darstellung auf echter Hardware (SwiftData/Core
Data) nachweislich NICHT synchron — das geloeschte Objekt blieb bis zu einem Save/Re-Fetch in
`day.exercises` sichtbar, obwohl es im Context bereits als geloescht markiert war. Diese
Zeitfenster-Eigenheit existiert auf Linux nicht, weil SwiftData dort ueberhaupt nicht existiert, ist
also NIE zuvor real getestet worden. Fix: `revert(...)` entfernt jede geloeschte Uebung jetzt
zusaetzlich EXPLIZIT aus `day.exercises` (`day.exercises.removeAll { $0.persistentModelID ==
exercise.persistentModelID }`), bevor `context.delete(...)` aufgerufen wird — macht den
In-Memory-Zustand unabhaengig von dieser Relationship-Timing-Eigenheit korrekt, statt sich auf eine
implizite Synchronisierung zu verlassen.

**Warum beide Funde nicht als "nur Testartefakt" abgetan werden:** beide Szenarien (ein pendentes
Session-/Log-Objekt im selben Context beim Aufruf von `recalculate`; ein fehlgeschlagener Save
direkt nach einer Tagesersetzung) sind plausible reale Zeitfenster, keine rein künstlichen
Test-Konstruktionen — SwiftDatas Autosave ist nicht synchron nach jeder Mutation, ein
`context.save()` kann aus denselben Gruenden scheitern, die `saveOverrideForTesting` nur
deterministisch simuliert (Disk voll, Store-Korruption, etc.). Beide Fixes schliessen echte
Luecken in genau dem Vertrag, den Task #197 von Anfang an herstellen sollte.

**Geänderte Komponenten:**
- `Sources/FitnessAppData/PlanGeneratorInstantiator.swift` — `hasIndependentPendingChanges`
  (Fund 1) und `revert(...)` (Fund 2) korrigiert, Doku an beiden Stellen ergaenzt. Keine neuen
  Tests noetig — die bereits bestehenden, auf Apple real fehlgeschlagenen Tests sind die
  Regressionstests; dieselben vier Tests muessen nach dem Fix dort gruen sein.

**Ausdrücklich NICHT auf dieser Session verifizierbar:** ob die beiden Fixes die vier realen
Apple-Fehlschläge tatsächlich beheben, kann hier NICHT geprüft werden — `PlanGeneratorInstantiator.
swift` liegt komplett hinter `#if canImport(SwiftData)` (auf Linux `false`), `swift build`/
`swift test` bestätigen hier deshalb erneut NUR Syntax, nicht Semantik oder tatsächliches
Laufzeitverhalten (derselbe Vorbehalt wie beim OnboardingView-Fund der vierten Korrekturrunde).
Beide Fixes sind durch genaues Lesen von `TrainingDay`/`WorkoutSession`/`ExerciseLog`s
Relationship-Deklarationen und der vier fehlschlagenden Tests hergeleitet, nicht durch einen
eigenen Apple-Testlauf bestätigt. Nächster nötiger Schritt: denselben `testflight`- oder
`swift-package`-Workflow erneut gegen den Commit laufen lassen, der diese beiden Fixes enthält, und
bestätigen, dass exakt diese vier Tests jetzt gruen sind (und keine neuen Fehlschläge entstanden
sind).

**Tests tatsächlich ausgeführt (diese Session):** `swift build`, `swift build --build-tests`,
`swift test` — alle gruen, 1033/1033 unveraendert (erwartet, da beide geaenderten Funktionen
komplett im fuer Linux inaktiven `#if canImport(SwiftData)`-Zweig liegen).

**Codemagic-Connect-Frage des Users beantwortet:** kein nativer Codemagic-Connector/-Plugin in
dieser Session verfuegbar (`SearchPlugins` liefert nichts Codemagic-Spezifisches). Der
funktionierende Weg bleibt: User laedt ein Codemagic-Log manuell hoch (wie in dieser Runde
geschehen, hat direkt zu zwei echten Funden gefuehrt) ODER stellt ein Read-only-API-Token als
Network-Secret bereit.

**Branch/Commit:** Branch `claude/smart-onboarding-epic`. Commit folgt unmittelbar nach diesem
Berichtseintrag.

**Nächste Aufgabe:** Fix-Commit pushen, User bittet erneut um einen Apple-Testlauf (Codemagic) fuer
genau diesen Commit, Ergebnis der betroffenen vier Tests abwarten. Task #197 bleibt `in_progress`
bis diese Bestaetigung vorliegt. Keine weitere Erweiterung ueber diese beiden Fixes hinaus.

## Commit 6300fbf real auf Apple-Hardware bestaetigt, zwei weitere echte Geraete-Befunde (935e0f6, 73fa31a), TestingBot/WebDriverAgent-Grenzen dokumentiert

**Auslöser:** User stellt `TESTINGBOT_KEY`/`TESTINGBOT_SECRET` und spaeter `CODEMAGIC_API_TOKEN` als
Environment-Secrets bereit. Drei nacheinander gestartete Hilfs-Sessions (neue Umgebungsvariablen
werden erst in einem neuen Container sichtbar) plus diese Hauptsession selbst arbeiten die vom User
in der vierten Korrekturrunde verlangte "getrennte, konkrete" Verifikation ab.

**1. Zwei falsche TestingBot-App-IDs entlarvt.** Zwei vom User genannte Storage-IDs
(`tb://ba636a4d7c3e43478373100b`, `tb://a76ddd7b6031ff7302cbc360`) wurden heruntergeladen und per
SHA256 verglichen: beide byte-identisch mit TestingBots eigenem Demo-Projekt `xcuitest-sample-app`
(Quell-Zip, kein kompilierter Build), obwohl ein Storage-Eintrag "FitnessApp.app.zip" hieß. Lehre:
Namen/Labels in TestingBots Storage nie ungeprüft übernehmen - vor Gebrauch immer den Inhalt
verifizieren (entpacken, `Info.plist` + Mach-O-Executable `FitnessApp` in einem `*.app`-Verzeichnis
pruefen).

**2. Echter Apple-Testlauf fuer Commit 6300fbf bestaetigt, zwei weitere echte Lebenszyklus-Bugs
gefunden und behoben.** Mit `CODEMAGIC_API_TOKEN` wurde zuerst ein `swift-package`-Build fuer den
aktuellen HEAD ausgewertet: **1240/1240 Tests gruen**, inklusive aller vier zuvor fehlschlagenden
(`testRecalculateSkipsDayWithActiveSessionAndReportsIt`,
`testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact`,
`testRecalculateSkipsSaveEntirelyWhenNothingWasRewritten`,
`testRecalculateSaveFailureLeavesNoStructuralChangeEvenAfterLaterSave`) - Commit 6300fbf's beiden
Fixes (`hasIndependentPendingChanges`, `revert(...)`) sind damit **real auf Apple-Hardware
bestaetigt**, nicht mehr nur code-gelesen. Danach wurde ein echter, verifizierter `ios-app`-Build zu
TestingBot hochgeladen und per Appium gegen einen iOS-Simulator gefahren. Dabei auf ECHTEM Geraet
reproduziert: `PlansListView.acceptOperation` wird einmalig als `@State` erzeugt und nie
ausgetauscht, obwohl ihre eigene Typ-Doku eine neue Instanz pro wirklich neuem Versuch verlangt -
nach einem angenommenen Cardio-Vorschlag zeigte jede spaetere, voellig unabhaengige Cardio-Karte
(neues Ziel/Renndatum/Volumen) faelschlich "Erneut versuchen" statt "Vorschlag annehmen", und ein
Tap darauf haette nur den laengst aufgeloesten alten Plan erneut aufzuloesen versucht statt den
neuen anzulegen. Fix: `CardioFeasibilityCardModel.fingerprint` oeffentlich gemacht, `PlansListView`
haelt jetzt einen `acceptOperationFingerprint` und tauscht `acceptOperation` gegen eine frische
Instanz aus, sobald die angezeigte Karte zu einer anderen Kombination gehoert (Commit `935e0f6`).
Dasselbe strukturell identische Muster wurde praeventiv auch in `ProfileEditorView` behoben (Commit
`73fa31a`, code-gelesen uebertragen, nicht am Geraet separat reproduziert, da die Codebasis exakt
identisch war). Ein erneuter `swift-package`-Lauf fuer `73fa31a` wurde von mir selbst (nicht nur
berichtet) direkt per Codemagic-API nachvollzogen: Build `6ad2481c586b3da52c8d456f`, alle
Build-Schritte `success`, Testschritt-Log zeigt die Fortschrittszeilen `[1/1240]` bis `[1240/1240]`
lueckenlos, keine Fail-/Error-Zeile, die vier zuvor fehlschlagenden Tests namentlich enthalten und
durchgelaufen. `swift test --parallel` laeuft unter `set -e` - ein echter Fehlschlag haette den
Schritt sichtbar als `failed` markiert.

**3. WebDriverAgent-Infrastrukturfehler bei TestingBot bestaetigt transient.** Die Appium-Session,
die Fund 2 oben gemacht hat, scheiterte danach dreimal in Folge mit `Unable to launch
WebDriverAgent - xcodebuild failed with code 70` (zwei verschiedene Geraete-/iOS-Kombinationen),
unabhaengig von Code oder Build - TestingBot-seitiges Infrastrukturproblem, Retries wie angewiesen
gestoppt. Ich habe in dieser Hauptsession (neuer Container, dieselben Secrets) selbst eine frische
WebDriverAgent-Session gegen denselben verifizierten Build (`tb://534a0efa885a30bc28e86bb1`)
erzeugt - **erfolgreich** (`iPhone 15`/`iOS 17.5`, echter Screenshot + Accessibility-Tree
abgerufen). Der Infrastrukturfehler war also tatsaechlich transient, nicht dauerhaft.

**4. Eigene Simulator-Durchsteuerung (diese Session): teilweise erfolgreich, ein Szenario
ergebnisoffen wegen eines WebDriverAgent-Hit-Testing-Problems.** Selbst durchgefuehrt, real auf dem
Simulator: komplettes Onboarding (Profil, Ziel "Functional/Hybrid", Trainingshistorie, Equipment,
Benachrichtigungen, Abschluss) - Dashboard zeigte danach "No active plan", Plan-Tab "No plans yet"
(**stuetzt Szenario 6**: Onboarding-Abschluss allein legt keinen Plan an, auch wenn eine Empfehlung
vorausgewaehlt war). Danach Plan aus Vorlage ("Full Body 3x") uebernommen, in `ProfileEditorView`
echtes Cardio-Ziel eingerichtet (Running Coaching an, 10K, Renndatum, Startvolumen) - die reale
`CardioFeasibilityCardModel.make`-Karte ("Your running goal is achievable") erschien korrekt. Der
Versuch, "Adopt plan" zu tappen, um Szenario 1/2 selbst erneut zu reproduzieren, blieb
**ergebnisoffen**: Element-Klick ohne Wirkung, ein Koordinaten-Tap traf nachweislich ein anderes,
darunterliegendes Element (Accessibility-Tree und Screenshot liefen zu diesem Zeitpunkt auseinander),
und Appiums native `mobile: scroll {toVisible: true}`-Befehl schlug mit WebDriverAgents eigener
Fehlermeldung `Failed to perform scroll with visible cell due to max scroll count reached` fehl -
ein autoritatives Signal von Apples eigener Scroll-/Accessibility-Logik, keine eigene
Koordinaten-Fehlrechnung. Ich habe daraufhin NICHT weiter geraten, um keine Schein-Bestaetigung zu
erzeugen. Ob das ein echtes Accessibility-/Layout-Problem dieser spezifischen Taste ist oder eine
XCUITest/SwiftUI-Interop-Eigenheit, ist ungeklaert und nicht Teil des Task-#197-Scopes - nicht
untersucht, nicht "behoben". Szenario 1/2 bleiben damit fuer DIESEN eigenen Durchlauf unbestaetigt;
die zugrundeliegende Code-Korrektur selbst ist unabhaengig davon durch Fund 2 oben bereits einmal
real am Geraet bestaetigt. Szenario 3 (ProfileEditorView), 4 (Adjust plan) und 5
(Onboarding-Custom-Builder) wurden in diesem Durchlauf nicht erreicht.

**Nebenbefund, nicht behoben (ausserhalb Scope):** Der Button "Diesen Plan übernehmen" in der
Vorlagen-Vorschau (Plan-Tab, "From Template") ist hartcodiert Deutsch, obwohl der Rest der UI in
dieser Session durchgehend Englisch war (Geraet-/Simulator-Locale). Nur vermerkt, nicht korrigiert -
kein Bezug zu Task #197.

**Ausdrücklich NICHT in dieser Runde verifiziert:** Szenario 3/4/5 real am Geraet; die beiden
Fehlerpfad-Szenarien (Fehler vor Commit/Rebind-Fehler) bleiben wie zuvor dokumentiert ohne
UI-Ausloeser (DI-Seams nur In-Process-XCTest, siehe fruehere Eintraege) - unveraendert zurueckgestellt
per User-Entscheidung.

**Branch/Commits:** `claude/smart-onboarding-epic`, Commits `935e0f6` und `73fa31a` (beide bereits
gepusht, aus Hilfs-Session `session_01UFjTwK41YkxLRZbveiFXAt`). Dieser Eintrag selbst folgt als
eigener Dokumentations-Commit.

**Naechste Aufgabe:** Szenario 1/2/3/4/5 bei Gelegenheit erneut versuchen (frische TestingBot-Session,
ggf. anderes Geraet/andere iOS-Version, um das Hit-Testing-Problem zu umgehen oder als reproduzierbar
zu bestaetigen). Task #197 bleibt `in_progress` - der Kern (Commit-/Speicherfehler-Vertrag inkl.
beider Lebenszyklus-Bugs) ist jetzt real auf Apple-Hardware bestaetigt, die vollstaendige
Simulator-Szenarioliste des Users ist es noch nicht.

## Vereinbarter UI-Pruefumfang vollstaendig durchgefuehrt (neue TestingBot-Session, verifizierter Build), ein weiterer echter Geraete-Bug gefunden und behoben

**Auslöser:** User verlangt explizit, das vorige Hit-Testing-Problem (siehe oben) NICHT durch einen
App-Umbau zu umgehen, sondern den offenen UI-Pruefumfang gezielt abzuschliessen: Cardio-Vorschlag
uebernehmen, entstandenen Plan oeffnen+pruefen, Plan-Anzahl vor/nach, uebernommenes Laufziel im Profil
kontrollieren, Ziel erneut aendern + neuen Vorschlag sowohl im Plan-Tab als auch im Profileditor
uebernehmen, danach "Adjust plan" und den Onboarding-Custom-Builder durchfuehren - mit Pflicht, nur
nachweislich den eigenen Build zu verwenden (Commit/Artefakt/TestingBot-Zuordnung dokumentiert) und bei
erneutem Automatisierungsfehler den Fall als blockiert zu melden statt die App vorsorglich umzubauen.

**0. Build-Nachweis (von dieser Session selbst, nicht nur uebernommen).** Commit
`73fa31a0fa7ebcdaac572017cc859fad4b27f066` → Codemagic `ios-app`-Build `6ad248222278e4b9b05b7c1f`
(alle Schritte `success`) → Artefakt `FitnessApp.app.zip`, 37.570.625 Bytes, Bundle-ID
`com.atamya.FitnessApp`, Version `0.1.0`, `MinimumOSVersion 17.0`. Frisch von Codemagic
heruntergeladen, entpackt, Mach-O-Executable `FitnessApp.app/FitnessApp` gegen die bei TestingBot
unter `tb://534a0efa885a30bc28e86bb1` (Storage-Dateiname `FitnessApp_73fa31a.zip`) hinterlegte
Kopie per SHA256 verglichen: **identisch**
(`bb38efefb67aff885686aef5c270af10a1bd56ddb0274fee33c2224215dd4b0b`). Damit nachweislich derselbe,
echte Build - nicht wieder TestingBots Demo-Projekt wie in der vorigen Runde.

**1.-5. Vereinbarter Pruefumfang, alle Punkte real am Simulator belegt (iPhone 15/iOS 17.5):**
- **Cardio-Vorschlag uebernehmen (Plan-Tab):** Running Coaching im Profil aktiviert (10K, Renndatum
  8. Jan 2027, Startvolumen 20 km/Woche) → echte Karte "Your running goal is achievable" im Plan-Tab
  → "Adopt plan" getappt → navigiert zu einem neuen Plan "Individueller Plan" mit genau dem
  angekuendigten Inhalt (Mo Intervals, Di Easy Run, Mi Bodyweight Push&Pull, Do Tempo Run, Fr
  Bodyweight Pull&Push, Sa/So Rest).
- **Plan-Anzahl vor/nach:** "1 PLAN" (nur "Full Body 3x") → nach der Uebernahme "2 PLANS" - per
  Badge-Text verifiziert, nicht geschaetzt.
- **Uebernommenes Laufziel im Profil:** `Edit Profile` zeigt weiterhin Running-Ziel "10K", Renndatum
  "Jan 8, 2027", Startvolumen "20" - exakt die zuvor bestaetigten Werte, korrekt zurueckgespiegelt.
  Karte erscheint fuer diese IDENTISCHE Kombination danach nicht erneut (kein Nach-Nerven,
  konsistent mit Commit 935e0f6).
- **Ziel erneut aendern + neuen Vorschlag uebernehmen, im Profileditor:** Ziel auf "Marathon"
  geaendert → App erkennt real die Unmachbarkeit ("You need about 15 weeks, but only 11 are
  available. A more realistic goal right now: Half Marathon.", Button "Accept suggestion" statt
  "Apply") → direkt im Profileditor angenommen, OHNE zum Plan-Tab zu wechseln → Profil zeigt danach
  korrekt "Half Marathon" (nicht das urspruenglich gewaehlte, unmachbare "Marathon") -
  `rebaselineCardioGoal()` uebernimmt also den tatsaechlich akzeptierten Fallback-Vorschlag korrekt.
  Plan-Anzahl danach "3 PLANS".
- **Ziel ein drittes Mal aendern + "Adjust plan" (Plan-Tab):** Ziel auf "5K" geaendert, neue machbare
  Karte erschien ("You need about 2 weeks, 11 are available"). "Adjust plan" oeffnet real das
  vorausgefuellte Build-Plan-Sheet (Running 2x/Woche + Bodyweight 2x/Woche als "4 UNITS"), nach Equipment
  (Bodyweight)/Rhythm(Order Only)/Next bis zur Vorschau durchgesteuert, "Adopt Plan" getappt →
  navigiert zu einem vierten, eigens zusammengestellten Plan. Plan-Anzahl danach "4 PLANS".
- **Onboarding-Custom-Builder:** App ueber "Reset App" (In-App-Funktion, keine neue TestingBot-Session
  noetig) real auf Werkszustand zurueckgesetzt ("The app will start in onboarding", bestaetigt),
  Onboarding bis zur Plan-Auswahl erneut durchlaufen, dort "BUILD YOUR OWN" → "Build Plan" geoeffnet,
  Trainingstyp "Bodyweight" gewaehlt (siehe Automatisierungs-Notiz unten), Equipment/Rhythm gesetzt, bis
  zur Vorschau durchgesteuert, "Adopt Plan" getappt → zurueck auf dem Onboarding-Auswahlbildschirm
  zeigt "Build Plan" jetzt den Auswahl-Haken, "Football Athletic" nicht mehr ausgewaehlt. Erst nach
  "Finish" entstand ein echter Plan: Dashboard zeigt danach "INDIVIDUELLER PLAN" mit dem exakt
  selbstgebauten Inhalt (Bodyweight Push&Pull: Push-Up, Wide-Grip Pull-Up, Pike Push-Up, ...),
  Plan-Tab zeigt "1 PLAN" (frischer Reset-Zustand). **Bestaetigt real am Geraet:** das Oeffnen/
  Konfigurieren des Custom-Builders waehrend des Onboardings legt keinen Plan vorzeitig an - genau
  einer entsteht erst beim finalen "Finish".

**Automatisierungs-Notiz (kein App-Befund):** Auf dem "Training Types"-Mehrfachauswahl-Bildschirm des
Custom-Builders registrierte ein Tap auf den umschliessenden `XCUIElementTypeButton` (z.B.
"Bodyweight") wiederholt KEINE Aenderung - weder im Accessibility-Baum noch im Screenshot sichtbar,
mit zwei unabhaengigen Tap-Strategien (Element-Klick, Koordinaten-Tap) reproduziert. Ein Tap auf das
INNERE `XCUIElementTypeStaticText`-Element mit demselben Namen hat dagegen sofort funktioniert (Zeile
wandelte sich sichtbar in eine konfigurierte "Unit"-Karte um, "Next" wurde aktiv). Auf dem strukturell
aehnlichen "Equipment"-Mehrfachauswahl-Bildschirm (an anderer Stelle im selben Builder) hat der
normale Button-Tap dagegen anstandslos funktioniert. Da zwei unterschiedliche Beobachtungsmethoden
(Baum + Pixel) uebereinstimmend keine Wirkung zeigten UND ein alternativer, gleichwertiger Tap am
selben Bildschirm sofort griff, ist das als Eigenheit dieser Automatisierungs-Interaktion (nicht als
App-Fehlfunktion) eingeordnet - die App selbst wurde dafuer nicht veraendert, wie vom User verlangt.

**6. Neuer echter Geraete-Fund (Nebenbefund waehrend Punkt 5, nicht gesucht):** Nach der ERSTEN
erfolgreichen Cardio-Uebernahme blieb der "Adopt plan"-Button im Plan-Tab fuer die gesamte restliche
Session dauerhaft deaktiviert (`enabled="false"`, mehrfach reproduziert, per Re-Dump nach Wartezeit
bestaetigt kein Timing-Artefakt) - jede spaetere, voellig unabhaengige Cardio-Karte (5K, siehe oben)
zeigte dasselbe. Root Cause (Code-Lesen): `isAcceptingCardioFeasibility` wird in BEIDEN betroffenen
Views (`PlansListView`, `ProfileEditorView`) im `.success`-Fall des `switch` nie zurueckgesetzt - nur
`nil`/`.nothingToCreate`/`.committedButUnresolved`/`.failedBeforeCommit` taten das. Da SwiftUIs
`TabView` seine Kind-Views (und damit deren `@State`) ueber Tab-Wechsel hinweg am Leben haelt, blieb
die Sperre nach einem einzigen Erfolg fuer den Rest der App-Laufzeit aktiv - einzig "Plan anpassen"
blieb als Umweg bedienbar, da nur der primaere Button `.disabled(isAcceptingCardioFeasibility)` hat.
Fix (Commit `3d462dd`): `isAcceptingCardioFeasibility = false` zusaetzlich im `.success`-Fall, an
beiden Stellen.

**Codemagic-Nachlauf fuer den Fix (von dieser Session selbst ausgeloest, da Push auf diesem Repo
keinen automatischen Codemagic-Trigger ausloest - abweichend von der bisherigen Annahme, siehe
Notiz unten):** `swift-package`-Build `6ad27962e8810c37ac26d788` fuer Commit `a12a4255c8126c97...`
(= `3d462dd` + Doku-Commit `a12a425`) manuell per API getriggert. Alle Schritte `success`, inklusive
"Run unit tests" - Fortschrittszeilen `[1/1240]` bis `[1240/1240]` lueckenlos, keine echte
Fail-/Error-Zeile. Bestaetigt: der Fix bricht nichts in der bestehenden Suite.

**Ausdrücklich WEITERHIN NICHT verifiziert:** dass der Fix das urspruengliche UI-Symptom (Button
bleibt nach Erfolg dauerhaft deaktiviert) tatsaechlich behebt, ist NICHT per echtem erneuten
UI-Durchlauf bestaetigt - die bestehende Testsuite enthaelt keinen Test fuer genau dieses
`isAcceptingCardioFeasibility`-Zuruecksetzen, "1240/1240 gruen" beweist nur Abwesenheit von
Regressionen, nicht Behebung des urspruenglichen Symptoms. Fuer die volle Bestaetigung noetig: ein
weiterer TestingBot-Lauf mit genau zwei aufeinanderfolgenden, unabhaengigen Cardio-Uebernahmen, der
pruefen, dass "Adopt plan" nach der ersten weiterhin bedienbar bleibt.

**Korrektur einer bisherigen Annahme:** `codemagic.yaml` deklariert zwar Trigger fuer jeden Push,
die beiden Pushes dieser Runde (`3d462dd`, `a12a425`) loesten aber ueber zehn Minuten lang KEINEN
automatischen Build aus - erst ein manueller `POST /builds` per API hat den Lauf gestartet. Alle
bisher in diesem Dokument als "Apple-Testlauf"/"Codemagic-Build" zitierten Laeufe fuer 6300fbf/
935e0f6/73fa31a wurden, soweit rekonstruierbar, ebenfalls explizit angestossen (von der
TestingBot-Hilfssession), nicht durch einen automatischen Webhook. Fuer kuenftige Runden: nach
jedem Push aktiv `POST https://api.codemagic.io/builds` aufrufen, nicht auf Auto-Trigger warten.

**Geaenderte Komponenten:** `Sources/FitnessAppUI/Workout/PlansListView.swift`,
`Sources/FitnessAppUI/Settings/ProfileEditorView.swift` (je eine Zeile `isAcceptingCardioFeasibility =
false` im `.success`-Fall plus Doku-Kommentar). `swift build` lokal gruen (Syntax, beide Dateien
`#if canImport(SwiftUI)`-gated).

**Branch/Commits:** `claude/smart-onboarding-epic`, `ce9600f` (Doku-Nachtrag zu 73fa31a/935e0f6,
vorige Runde) und `3d462dd` (dieser Fix), beide gepusht.

**Naechste Aufgabe:** Codemagic-Ergebnis fuer `3d462dd` abwarten/pruefen. Danach, falls gewuenscht, der
oben genannte gezielte Re-Test des Fixes. Szenario "Fehler vor Commit"/"Rebind-Fehler" bleiben wie
zuvor dokumentiert per User-Entscheidung zurueckgestellt. Task #197 bleibt `in_progress`.
