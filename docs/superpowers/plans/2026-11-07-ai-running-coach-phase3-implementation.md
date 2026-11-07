# AI Running Coach – Phase 3: Implementierungsplan

Datum: 2026-11-07  
Spec: `docs/superpowers/specs/2026-11-07-ai-running-coach-phase3-design.md`  
Branch: `claude/great-dewdney-af8974`  
Status: **WARTEND AUF FREIGABE — Schritt 1 + 2 abgeschlossen**

---

## Global Constraints

- Kein neues SwiftData-Feld außer `profile.activeDashboardWidgets` (wird bereits geschrieben).
- Keine automatische Trainingsplanänderung.
- Keine medizinischen Formulierungen.
- PR #4 bleibt ungemergt.
- `swift test` auf Windows durch ZIPFoundation blockiert — Verifikation auf macOS CI.
- Nach jedem Task `swift build --target DeltiqCore` lokal ausführen (Typ-Prüfung).

---

## Offene Entscheidungen (vor Task 1 zu klären)

1. Chart-Overlay: Projektion allein oder mit Ist-Daten-Overlay?  
2. `cardioJunkMiles` aktivieren in Phase 3?  
3. Widget-Repositionierung: bei jedem Einschalten oder nur einmalig?

---

## Task 1 — Volumen-Projektionschart in `CardioCoachDetailView`

**Ziel:** `CardioFeasibilityCalculator.weeklyVolumeProjection` als Swift-Charts-LineMark anzeigen.

**Dateien:**
- `Sources/DeltiqUI/Cardio/CardioCoachDetailView.swift` (ändern)
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` (neue Keys)

**Interfaces Produces:** `volumeProjectionChart` ViewBuilder in `CardioCoachDetailView`

**Schritte:**

1. Test (falls noch fehlend): `CardioFeasibilityCalculatorTests.testChartPhasesAllCasesPresent` — verifiziert dass `chartPhases` für eine valide Projektion buildUp/peak/taper zurückgibt. Falls Test existiert: überspringen.

2. In `CardioCoachDetailView` eine neue `private var volumeProjectionSection: some View`:
   ```swift
   // Guard: braucht goal mit Zielvolumen und Renndatum
   guard let goal = profile.cardioGoal,
         CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: goal) != nil,
         let raceDate = profile.cardioRaceDate,
         let startKm = profile.weeklyBaseVolumeKm,
         startKm > 0
   else { return AnyView(EmptyView()) }
   let weeksAvail = max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear ?? 0)
   guard weeksAvail > 0 else { return AnyView(EmptyView()) }
   let projection = CardioFeasibilityCalculator.chartPoints(
       from: CardioFeasibilityCalculator.weeklyVolumeProjection(startKm: startKm, goal: goal, weeksAvailable: weeksAvail)
   )
   let phases = CardioFeasibilityCalculator.chartPhases(for: projection)
   ```
   Chart: `Chart(Array(zip(projection, phases)), id: \.0.week) { pair in let (point, phase) = pair; AreaMark(x: .value("Woche", point.week), y: .value("km", point.km)).foregroundStyle(by: .value("Phase", phase.rawValue)) }` mit `.chartForegroundStyleScale` für buildUp/peak/taper in orange/rot/grün (System-Colors, keine Custom-Colors).

3. Section in `body` nach dem historischen Chart einfügen:
   ```swift
   Section(header: Text("cardioCoach.section.volumeProjection", bundle: .module)) {
       volumeProjectionSection
   }
   ```

4. Lokalisierungs-Keys in `Localizable.xcstrings` eintragen (DE/EN/TR).

5. `swift build --target DeltiqCore` — muss grün sein (kein neuer Core-Code).  
   `swift build --target DeltiqUI` — erwartet ZIPFoundation-Fehler auf Windows (bekannt).

**Completion Contract:** Section erscheint in `CardioCoachDetailView` wenn Renndatum + Ziel vorhanden; bei fehlendem Renndatum bleibt sie versteckt. Lokalisierungs-Keys vorhanden.

**Commit:** `feat(cardio): Phase 3A – volume projection chart in CardioCoachDetailView`

---

## Task 2 — Handlungsempfehlungen in `RaceProgressDetailView`

**Ziel:** Pro Concern eine zweite Textzeile mit konkreter Empfehlung.

**Dateien:**
- `Sources/DeltiqUI/Cardio/RaceProgressDetailView.swift` (ändern)
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` (neue Keys)

**Schritte:**

1. Test: `RaceProgressRecommendationTests.testRecommendationNonNilForAllConcerns` — 5 Concern-Cases, je ein konkreter String zurück. Test zuerst in DeltiqCoreTests (falls Recommendation in Core), oder als Doc-only wenn nur View.

   **Ruling (Ponytail ultra):** Recommendation-Mapping ist reine String-Lokalisierung → bleibt in der View. Kein Core-Typ.

2. In `RaceProgressDetailView` neue `private func recommendation(for concern: RaceProgressAssessment.Concern) -> String`:
   ```swift
   switch concern {
   case .loadIncreasedTooFast:    return String(localized: "raceProgress.recommendation.loadIncreasedTooFast", bundle: .module)
   case .insufficientRecovery:    return String(localized: "raceProgress.recommendation.insufficientRecovery", bundle: .module)
   case .volumePlateau:           return String(localized: "raceProgress.recommendation.volumePlateau", bundle: .module)
   case .goalLikelyUnrealistic:   return String(localized: "raceProgress.recommendation.goalLikelyUnrealistic", bundle: .module)
   case .recentTrainingGap:       return String(localized: "raceProgress.recommendation.recentTrainingGap", bundle: .module)
   }
   ```

3. In `concernsSection` pro Concern eine zweite `.caption.foregroundStyle(.secondary)` Zeile mit dem Recommendation-String.

4. Lokalisierungs-Keys eintragen.

**Completion Contract:** Für jeden Concern-Fall erscheint eine zweite Zeile. `swift build --target DeltiqCore` grün.

**Commit:** `feat(cardio): Phase 3B – actionable recommendations in RaceProgressDetailView`

---

## Task 3 — Erstaktivierungs-UX runCoachCard

**Ziel:** Beim Einschalten von `cardioCoachingEnabled` → `runCoachCard` an Position 1 im Widget-Array.

**Dateien:**
- `Sources/DeltiqUI/Settings/ProfileEditorView.swift` (ändern)

**Schritte:**

1. Test: `DashboardWidgetAutoPositionTests.testRunCoachCardMovedToTopOnEnable` — gegeben `activeDashboardWidgets = [.nextWorkout, .coachingInsight, .weeklyVolume]` und Toggle false → true → `runCoachCard` an Index 1.

   **Ruling:** Test in DeltiqDataTests oder als reine Funktions-Extraktion. Da die Logik in `ProfileEditorView` (SwiftUI) sitzt, wird sie in eine `static func insertRunCoachCard(into widgets: [DashboardWidgetType]) -> [DashboardWidgetType]` in `RunCoachPlanAdjustment` oder als Standalone-Funktion extrahiert, die testbar ist.

2. Neue pure Hilfsfunktion `DashboardWidgetType.insertedAtTop(_ type: DashboardWidgetType, into widgets: [DashboardWidgetType], afterFirst: DashboardWidgetType?) -> [DashboardWidgetType]` in `DashboardWidgetType.swift` (oder inline in `ProfileEditorView` wenn zu spezifisch).

   Ponytail: inline in `ProfileEditorView` ist kleiner (kein neuer Export):
   ```swift
   .onChange(of: profile.cardioCoachingEnabled) { _, newValue in
       guard newValue else { return }
       var ws = profile.activeDashboardWidgets
       guard !ws.prefix(3).contains(.runCoachCard) else { return }
       ws.removeAll { $0 == .runCoachCard }
       ws.insert(.runCoachCard, at: min(1, ws.count))
       profile.activeDashboardWidgets = ws
   }
   ```

3. `swift build --target DeltiqCore` grün.

**Completion Contract:** Test (Standalone-Funktion oder XCTest) grün; `.onChange` Handler ist vorhanden.

**Commit:** `feat(cardio): Phase 3C – auto-position runCoachCard on first coaching enable`

---

## Task 4 — Lokalisierung + Abnahme

**Ziel:** Vollständige DE/EN/TR Strings für alle neuen Keys.

**Dateien:**
- `Sources/DeltiqUI/Resources/Localizable.xcstrings`

Alle in Tasks 1–3 eingetragenen Keys werden auf Vollständigkeit geprüft (DE, EN, TR). `.scripts/training_density_phase2c_keys.py` als Referenz für das Patch-Skript-Pattern falls Batch-Eintrag gewünscht.

**Commit:** `i18n(cardio): Phase 3 – add recommendation and projection strings (DE/EN/TR)`

---

## Final Review

Nach Task 4: `review-package` über Branch `claude/great-dewdney-af8974` von `main` aus. Schwerpunkte:
- Kein medizinischer Formulierungsfehler in Recommendation-Strings
- Chart leer bei fehlendem Renndatum (kein Crash)
- Widget-Mutation nur bei Einschalten, nicht bei Ausschalten

---

## Test-Matrix

| Test | Datei | Erwartet |
|------|-------|----------|
| `testChartPhasesAllCasesPresent` | DeltiqCoreTests | buildUp, peak, taper je mindestens 1x |
| `testRecommendationNonNilForAllConcerns` | inline/DeltiqCoreTests | 5/5 non-empty Strings |
| `testRunCoachCardMovedToTopOnEnable` | inline/DeltiqDataTests | runCoachCard @ index 1 |
| `testRunCoachCardNotMovedIfAlreadyTop3` | inline | kein Duplikat, keine Verschiebung |

---

## Commit-Folge

```
feat(cardio): Phase 3A – volume projection chart in CardioCoachDetailView
feat(cardio): Phase 3B – actionable recommendations in RaceProgressDetailView
feat(cardio): Phase 3C – auto-position runCoachCard on first coaching enable
i18n(cardio): Phase 3 – add recommendation and projection strings (DE/EN/TR)
docs: Phase 3 Implementierungsplan + Design-Review commit
```

---

*STOP — Schritt 1 (Audit) und Schritt 2 (Design Review) sind abgeschlossen.  
Schritt 3 (Implementierung) erfordert explizite Freigabe durch Atakan.*
