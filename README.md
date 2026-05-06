# FitnessApp iOS

iOS-Port der Android-Fitness-App (`../fitnessapp/`). Domaenen-Logik und Datenmodell werden hier als **Swift Package** entwickelt — die App-Schicht (SwiftUI Views, Live Activities, HealthKit) wird spaeter in einem separaten Xcode-Projekt aufgesetzt, das dieses Package als lokale Dependency einbindet.

## Layout

```
fitnessapp_ios/
|-- Package.swift              # Swift-Package (iOS 17+, macOS 14+)
|-- Sources/
|   |-- FitnessAppCore/        # Reine Berechnungs-Logik (kein UIKit, kein SwiftData)
|   |   |-- Numerics/          # truncated(to:), formattedTwoDecimals
|   |   |-- BodyComposition/   # BMI, Navy KFA, Deurenberg, FFMI, BMR, weight-trend
|   |   `-- Exercises/         # 1RM (Epley/Brzycki), Plate-Calculator (greedy + cap)
|   |-- FitnessAppData/        # SwiftData @Model-Definitionen (canImport-gated)
|   |-- FitnessAppHealth/      # HealthKit-Wrapper (canImport-gated) + cross-platform Controller-Facade
|   |-- FitnessAppActivities/  # ActivityKit Live-Activity-Attributes + Controller (canImport-gated)
|   `-- FitnessAppUI/          # SwiftUI-Views (canImport-gated) + #Preview-Container
|-- Tests/
|   `-- FitnessAppCoreTests/   # Parity-Tests gegen Android-Werte
`-- README.md
```

## Architektur-Invarianten (1:1 vom Android uebernommen)

1. **Single-Source-of-Truth metric.** Persistente Werte sind IMMER kg und cm. Die Settings-Toggle (kg/lbs, cm/in) wirkt nur in der UI — keine Daten-Migration.
2. **Truncate (Floor) statt Round.** Berechnete Body-Composition-Werte werden auf 2 Nachkommastellen abgeschnitten, niemals aufgerundet (KFA 15.86 bleibt "15.86").
3. **App-weit 2 Nachkommastellen** mit erzwungenen nachgestellten Nullen. Locale-aware (`String(format: "%.2f", locale: Locale.current, value)`).
4. **Plate-Greedy mit Per-Plate-Cap.** Jede Plate-Klasse wird auf das Inventar-Maximum gedeckelt — Rest wandert in kleinere Plates.

## Entwicklung

### Tests laufen lassen (CLI)

```bash
swift test
```

Funktioniert auf macOS (Xcode-Toolchain) und Linux (Swift-Open-Source-Toolchain). Auf Windows: derzeit nicht — die SwiftData-Targets brauchen Apple-Frameworks. Tests sind aber so geschnitten, dass `FitnessAppCore` (ohne SwiftData) ueberall kompiliert.

### Einbindung in das Xcode-App-Projekt

Komplette Setup-Docs:
- [`XcodeSetup.md`](./XcodeSetup.md) — App-Target + Package-Einbindung + HealthKit-Capabilities
- [`WidgetSetup.md`](./WidgetSetup.md) — Widget-Extension + Live-Activity-UI + Deep-Link-Scheme

Kurzversion fuer App-Target:

1. In Xcode: `File → Add Packages → Add Local`
2. Diesen Ordner (`fitnessapp_ios/`) auswaehlen
3. Im App-Target unter "Frameworks, Libraries, and Embedded Content" `FitnessAppCore`, `FitnessAppData` und `FitnessAppUI` hinzufuegen
4. App-Entry-Point auf `RootView()` setzen + `.modelContainer(for: AppSchema.types)`

### SwiftUI-Previews live im Package

`FitnessAppUI/MeasurementView.swift` enthaelt drei `#Preview`-Varianten (maennlich, weiblich, leerer State). Sie greifen auf `PreviewSeed` (`PreviewSupport.swift`) zu, der einen In-Memory-`ModelContainer` mit `isStoredInMemoryOnly: true` aufsetzt — Preview-Daten landen NICHT im persistenten Store. Voraussetzung: Xcode (Mac) — auf Windows kompilieren die UI-Files via `#if canImport(SwiftUI) && canImport(SwiftData)` zu leeren Modulen, damit `swift test` weiter laeuft.

## Fortschritt

- [x] Projekt-Setup (Package.swift, README)
- [x] Number-Helpers (`Double.truncated(to:)`, `Double.formattedTwoDecimals`)
- [x] BodyCalculations (BMI, Navy, Deurenberg, FFMI, BMR Mifflin/Katch, WHR, Weight-Trend)
- [x] ExerciseCalculations + PlateCalculator
- [x] SwiftData-Models (BodyMeasurement, UserBodyProfile, TrainingPlan/Day/Exercise/Log, WorkoutSession, ExerciseTemplate)
- [x] Parity-Tests (55 Tests, 0 Failures)
- [x] MeasurementView mit Live-KFA-Preview + ModelContext-Save (FitnessAppUI)
- [x] OnboardingView (UserBodyProfile-Setup) + RootView-Switcher
- [x] DashboardView (Hero-Metrics, Swift-Charts Trend mit 4/8-W. Forecast, Goal-Linie)
- [x] CalculatorsView (Hub) + PlateCalculatorView + OneRepMaxView + TDEEView
- [x] Workout-Flow Phase 1: PlanBuilder (Plans/Day/Exercise CRUD) + Session-Lifecycle (Start/Speichern/Verwerfen)
- [x] Workout-Flow Phase 2: Set-Logging mit Previous-Hint, Rest-Timer (sticky Bar + Haptic), Live-Volume
- [x] Workout-Flow Phase 3: Summary mit Hero/Stats/Notes/Breakdown + Swipe-to-Delete + Cross-Tab-Return zum Dashboard
- [x] AppNavigation als zentraler @Observable State (selectedTab + workoutPath)
- [x] Dashboard Plan-Tag-Karte (Sequential-Rotation) mit Deep-Link in ActiveWorkout
- [x] Dashboard Recent-Workouts + WorkoutHistoryView (Monats-Gruppierung) mit Read-Only Summary
- [x] HealthKit-Integration (FitnessAppHealth-Target, Auto-Fill + Auto-Save in MeasurementView) — bereit fuer Xcode-App-Target
- [x] Settings-Tab (ProfileEditor, Einheiten-Toggle, HealthKit-Status, Danger-Zone Reset)
- [x] Wasser-Tracker (Calculators-Tab, WaterEntry-Model, Progress-Ring, Quick-Add)
- [x] Live-Activities-Skeleton (FitnessAppActivities-Target, RestTimerAttributes, Controller mit Lifecycle-Hooks)
- [x] Lokalisierung (String Catalog `Localizable.xcstrings` mit ~70 Keys, en+de full, tr Sample) + DomainEnums.localizedName
- [ ] Live Activities + Dynamic Island fuer Rest-Timer (Xcode-App-Target)
- [ ] WidgetKit Home-Screen-Widgets (Xcode-App-Target)
- [ ] WaterIntakeView (Tag 4 des Android-Calculators-Tabs)
- [ ] HealthKit-Integration (Gewicht/BMI/Koerperfett aus/in Apple Health)
- [ ] Live Activities fuer Rest-Timer
