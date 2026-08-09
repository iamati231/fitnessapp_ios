# Plan bauen

"Plan bauen" ist der 3-Schritte-Assistent, der aus mehreren gewählten
Trainingsarten (z. B. "3 Tage Kettlebell + 2 Tage Laufen") automatisch eine
berechnete Wochenstruktur erzeugt — im Unterschied zum klassischen Weg über
eine feste `ProgramTemplate`.

## Einstiegspunkt

`Sources/FitnessAppUI/Workout/PlansListView.swift`
Plus-Menü der Plan-Liste → `showingPlanBuilder = true` → `.sheet` präsentiert
`PlanBuilderView()`.

## Beteiligte Schichten

Der Assistent ist bewusst in drei Schichten aufgeteilt, damit die eigentliche
Rechenlogik ohne SwiftData/UI testbar bleibt:

```
PlansListView (Plus-Menü)
        │  Sheet
        ▼
PlanBuilderView.swift                 FitnessAppUI
  3-Schritte-Wizard: Trainingsarten → Ausrüstung → Ergebnis
        │  baut PlanGeneratorInput
        ▼
PlanGeneratorInput.swift              FitnessAppCore
  TrainingTypeKind, PlanGeneratorTypeSelection, PlanGeneratorInput
        │
        ▼
PlanGenerator.swift                   FitnessAppCore
  PlanGenerator.generate(from:) -> Result   (reine Funktion, kein SwiftData)
        │  Result.days: [GeneratedDay] (DaySpec + PlanLoadLevel)
        ▼
PlanGeneratorInstantiator.swift       FitnessAppData
  .build(from:in:)       -> neuer aktiver TrainingPlan
  .recalculate(_:in:)    -> "neu rechnen" für bestehenden Plan
```

### 1. `Sources/FitnessAppUI/Workout/PlanBuilderView.swift`
Die UI selbst. Struktur folgt `OnboardingQuizView` (`NavigationStack`,
Fortschrittsbalken, `switch step`, Zurück/Weiter-Leiste). Schritte
(`BuilderStep`):

1. **`.types`** — Trainingsarten wählen + je Art Tage/Woche, Sessiondauer,
   Erfahrungslevel (`PlanGeneratorTypeSelection`).
2. **`.equipment`** — verfügbare Ausrüstung, optional feste Wochentage.
3. **`.result`** — Vorschau des berechneten `PlanGenerator.Result`, Übernahme
   erzeugt den Plan via `PlanGeneratorInstantiator.build`.

### 2. `Sources/FitnessAppCore/Programs/PlanGeneratorInput.swift`
Reine Eingabe-Typen (kein SwiftData, `Codable` für die spätere
Persistierung als JSON):
- `TrainingTypeKind` — die 6 Wizard-Trainingsarten (`barbell`, `dumbbell`,
  `kettlebell`, `bodyweight`, `running`, `cycling`); die vier Kraft-Kinds
  mappen 1:1 auf `Equipment`, die zwei Cardio-Kinds haben keine
  Equipment-Entsprechung.
- `PlanGeneratorTypeSelection` — eine Zeile aus Schritt 1.
- `PlanGeneratorInput` — gesammelte Antworten aus Schritt 1+2.

### 3. `Sources/FitnessAppCore/Programs/PlanGenerator.swift`
Die eigentliche Rechenlogik, `PlanGenerator.generate(from:) -> Result`:
sammelt pro gewählter Trainingsart Kandidaten-Tage (`strengthCandidates`/
`cardioCandidates`), dedupliziert Namensdopplungen, verteilt sie nach
geschätzter Belastung über die Woche (`spreadByHardness`) und ordnet jedem
Tag ein relatives `PlanLoadLevel` (locker/mittel/schwer/hart) zu. Läuft
bewusst ohne SwiftData — dieselbe reine-Funktion-Philosophie wie
`PlanMatchmaker`.

### 4. `Sources/FitnessAppData/PlanGeneratorInstantiator.swift`
Brücke zwischen dem reinen Generator-Ergebnis und der bestehenden
`ProgramInstantiator`-Materialisierung:
- `build(from:in:)` — rechnet einmal, baut eine wegwerfbare synthetische
  `ProgramTemplate`-Hülle und delegiert die eigentliche Insert-Arbeit an
  `ProgramInstantiator.instantiate` (kein Duplikat der Instanziierungslogik).
  Speichert zusätzlich `plan.generatorInput` (JSON-codiert) sowie pro Tag
  `generatorSequenceIndex`/`generationFingerprint`.
- `recalculate(_:in:)` — "neu rechnen" für einen bestehenden, über den
  Assistenten erzeugten Plan: rechnet `generatorInput` erneut aus und
  überschreibt nur Tage, die seit der Erzeugung unverändert geblieben sind
  (`generationFingerprint == currentContentFingerprint`), damit manuelle
  Anpassungen nicht verloren gehen.

## Persistenz für "neu rechnen"

- `TrainingPlan.generatorInputRaw: String?` — JSON-Snapshot von
  `PlanGeneratorInput`, ermöglicht spätere Neuberechnung.
- `TrainingDay.generatorSequenceIndex` / `.generationFingerprint` — verknüpfen
  einen erzeugten Tag mit seiner Position im letzten Rechenlauf und markieren,
  ob er seither manuell bearbeitet wurde.
- Additive CSV-Spalte `generator_input_raw` in Export/Import
  (`Sources/FitnessAppData/Export/Data{Export,Import}Service.swift`) sichert
  das für Backup/Restore.

## Lokalisierung

Alle sichtbaren Wizard-Texte über `planBuilder.*`-Keys in
`Sources/FitnessAppUI/Resources/Localizable.xcstrings` (DE/EN/TR).
`PlanGenerator` selbst liegt in `FitnessAppCore` (kein `Bundle.module` dort)
und erzeugt Tages-/Plan-Namen daher als hartcodierte deutsche Strings —
einzige echte Lokalisierung ist `Result.explanationKey`, ein Schlüssel-String,
den die Wizard-UI auflöst.

## Tests

- `Tests/FitnessAppCoreTests/PlanGeneratorTests.swift` — reine
  Generator-Logik (Kandidaten, Verteilung, Namensdisambiguierung, Kettlebell-
  EMOM-Finisher-Cap, ...), kein SwiftData nötig.
- `Tests/FitnessAppDataTests/PlanGeneratorInstantiatorTests.swift` —
  `build`/`recalculate` inkl. Fingerprint-Schutz und Wochentag-Zuordnung.
