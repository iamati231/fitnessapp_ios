# AI Running Coach – Phase 3: Design Review

Datum: 2026-11-07  
Phase: 3 – Integrierte Coaching-Entscheidungen und konkrete Handlungsempfehlungen  
Status: **DESIGN REVIEW — Implementierung ausstehend (Freigabe erforderlich)**

---

## 1. Ziel

Phase 3 vervollständigt den Lauf-Coaching-Loop: Analyse existiert (Phase 1 + 2), aber es fehlen (a) ein Volumen-Fortschrittschart bis zum Renntag, (b) konkrete Handlungsempfehlungen aus den erkannten Concerns, und (c) eine saubere Erstaktivierungs-UX für die Lauf-Coaching-Karte.

---

## 2. Schritt 1 – Audit-Ergebnis

### 2.1 Was existiert und wird wiederverwendet

| Komponente | Datei | Verwendung in Phase 3 |
|-----------|-------|----------------------|
| `CardioFeasibilityCalculator.weeklyVolumeProjection` | DeltiqCore | Volumen-Chart – existiert, aber **nirgendwo aufgerufen** |
| `CardioFeasibilityCalculator.chartPoints` / `chartPhases` | DeltiqCore | Daten-Reduktion + Phasen-Färbung für Chart |
| `RaceProgressAssessment.Concern` | DeltiqCore | Mapping → Handlungsempfehlung (view-seitig) |
| `RaceProgressCardModel` | DeltiqUI/Cardio | Hat `profile.weeklyBaseVolumeKm`, `goal`, `raceDate` → fertige Inputs für den Chart |
| `CardioCoachDetailView` | DeltiqUI/Cardio | Importiert bereits `Charts`; zeigt letzten 8 Wochen historisches Volumen |
| `RaceProgressDetailView` | DeltiqUI/Cardio | Zeigt Concerns als Text – erhält Empfehlungs-Section |
| `DashboardWidgetType` | DeltiqCore | `runCoachCard` ist bereits drin, Drag&Drop + Toggle sind Standard-Mechanismus |

### 2.2 Kritischer Befund: `weeklyVolumeProjection` ist totes Code

`CardioFeasibilityCalculator.weeklyVolumeProjection`, `.chartPoints`, `.chartPhases` und das `ChartPhase`-Enum sind vollständig in DeltiqCore implementiert (seit Phase 1), werden aber an keiner Stelle der UI aufgerufen. Der Chart-Daten-Layer ist fertig; nur die View fehlt.

### 2.3 Gap: Keine konkrete Handlungsempfehlung

`RaceProgressAssessment.Concern` klassifiziert das Problem (z. B. `loadIncreasedTooFast(percent:weeks:)`), gibt aber keinen konkreten Folge-Text aus. `RaceProgressDetailView` zeigt nur die Beschreibung, nicht die Handlung.

### 2.4 Gap: Erstaktivierungs-UX der runCoachCard

Für Neu-User erscheint `runCoachCard` per `defaultOrder` an Position 2. Für Bestandsuser, die `cardioCoachingEnabled` nachträglich einschalten, bleibt die Karte an ihrer historischen Position (oder fehlt ganz). Es gibt keinen Mechanismus, der die Karte beim ersten Einschalten in die sichtbare Region schiebt.

---

## 3. Schritt 2 – Design

### 3.1 Komponente A: Volumen-Fortschrittschart

**Wo:** `CardioCoachDetailView` — neue Section „Volumen bis Renntag" zwischen dem historischen Chart und der Feasibility-Aussage.

**Datenfluss:**
```
CardioCoachDetailView
  └── hat: profile.weeklyBaseVolumeKm, profile.cardioGoal, profile.cardioRaceDate
  └── ruft: CardioFeasibilityCalculator.weeklyVolumeProjection(startKm:goal:weeksAvailable:)
  └── reduziert: .chartPoints(from:maxCount:20)
  └── färbt: .chartPhases(for:) → buildUp/peak/taper
  └── rendert: Swift Charts LineMark + AreaMark (iOS 17 Charts, bereits importiert)
```

**Chart-Design:**
- X-Achse: Wochennummer relativ zu heute (Woche 0 = jetzt)
- Y-Achse: km/Woche
- Drei farbkodierte Phasen: buildUp (orange), peak (rot), taper (grün)
- Kein Anmerkungstext, keine medizinischen Aussagen
- Linie endet am Renntag

**Implementierung:**
- Keine neuen DeltiqCore-Typen — nur neue View-Funktion `volumeProjectionChart` in `CardioCoachDetailView`
- Kein neues Modell — Inputs kommen aus dem bereits vorhandenen `CardioFeasibilityCardModel` / `profile`
- Kein neuer `@Query` — existierende `allSessions` liefert historische Punkte (Optional: Overlay der letzten 8 Ist-Wochen)

### 3.2 Komponente B: Handlungsempfehlungen aus Concerns

**Wo:** `RaceProgressDetailView`, innerhalb der bestehenden `concernsSection`, als zweite Zeile pro Concern.

**Datenfluss:**
```
RaceProgressDetailView
  └── hat: concerns: [RaceProgressAssessment.Concern]
  └── neu: private func recommendation(for concern: RaceProgressAssessment.Concern) -> String?
        switch concern {
        case .loadIncreasedTooFast: → "trainingDensity bekannt – nächste Woche unter Vorwochenniveau bleiben"
        case .insufficientRecovery: → "Ruhetag nach je 2 harten Einheiten einplanen"
        case .volumePlateau:        → "Wochenvolumen gezielt um 10 % anheben"
        case .goalLikelyUnrealistic:→ "Erreichbareres Ziel prüfen (auf Machbarkeits-Karte tippen)"
        case .recentTrainingGap:    → "Wiedereinsteiger-Rampe – erste Woche unter gewohntem Niveau"
        }
```

**Leitplanke:** Keine medizinischen Formulierungen, keine Verletzungsprognosen, keine automatischen Plan-Änderungen. Text ist Empfehlung (Konjunktiv), kein Gebot.

**Implementierung:** Pure `switch` in der View, neue Lokalisierungs-Keys `raceProgress.recommendation.*`. Keine neuen Core-Typen.

### 3.3 Komponente C: Erstaktivierungs-UX runCoachCard

**Wo:** `ProfileEditorView`, im `.onChange(of: profile.cardioCoachingEnabled)` Handler.

**Logik:**
```swift
// Nur beim ersten Einschalten (false → true)
guard newValue == true else { return }
let widgets = profile.activeDashboardWidgets  // [DashboardWidgetType]
let targetIndex = 1  // nach .nextWorkout
guard !widgets.prefix(3).contains(.runCoachCard) else { return }
// runCoachCard vorne einsetzen, Duplikat entfernen falls weiter hinten
var updated = widgets.filter { $0 != .runCoachCard }
let insertAt = min(targetIndex, updated.count)
updated.insert(.runCoachCard, at: insertAt)
profile.activeDashboardWidgets = updated
```

**Warum kein Rücksetzen beim Ausschalten:** Wenn der User die Karte über DashboardSettings ausblendet, schreibt er selbst `runCoachCard` aus der Liste. Das nächste Einschalten des Coachings triggert die obige Logik erneut (sie prüft nur „oben in top 3"), sodass die Karte wieder erscheint — aber nur wenn der User den Coaching-Schalter aktiv umdreht. Damit ist die Anforderung „bis eine neue Änderung nicht wieder aktiviert" erfüllt: eine „neue Änderung" ist das erneute Einschalten von `cardioCoachingEnabled`.

---

## 4. Leitplanken (unverändert aus Phase 3 Ticket)

- Keine automatische Trainingsplanänderung
- Keine neue Plan-Engine
- Keine medizinischen Aussagen oder Verletzungsprognosen
- PR #4 bleibt ungemergt
- Phase 4 beginnt nicht

---

## 5. Datenmodell-Änderungen

**Keine neuen SwiftData-Felder.**  
Alle Daten kommen aus bestehenden Feldern:
- `UserBodyProfile.weeklyBaseVolumeKm` → Chart-Startpunkt
- `UserBodyProfile.cardioGoal` + `cardioRaceDate` → Projektion
- `UserBodyProfile.activeDashboardWidgets` → Widget-Reihenfolge (wird in C mutiert)

---

## 6. Lokalisierungs-Keys (neu)

| Key | DE (Entwurf) |
|-----|--------------|
| `raceProgress.recommendation.loadIncreasedTooFast` | „Nächste Woche das Volumen nicht weiter steigern." |
| `raceProgress.recommendation.insufficientRecovery` | „Zwischen zwei harten Einheiten je einen Ruhetag einplanen." |
| `raceProgress.recommendation.volumePlateau` | „Wochenumfang schrittweise um ~10 % anheben." |
| `raceProgress.recommendation.goalLikelyUnrealistic` | „Erreichbareres Ziel in der Profil-Konfiguration prüfen." |
| `raceProgress.recommendation.recentTrainingGap` | „Erste Woche nach Pause deutlich unter gewohntem Niveau starten." |
| `cardioCoach.section.volumeProjection` | „Volumen bis Renntag" |
| `cardioCoach.volumeProjection.phase.buildUp` | „Aufbau" |
| `cardioCoach.volumeProjection.phase.peak` | „Spitze" |
| `cardioCoach.volumeProjection.phase.taper` | „Tapering" |
| `cardioCoach.volumeProjection.noRaceDate` | „Kein Renndatum konfiguriert" |

---

## 7. Test-Strategie

Alle neuen View-Helpers sind pure functions; keine SwiftData-Mutation außer Widget-Reihenfolge.

| Komponente | Testbar? | Strategie |
|-----------|----------|-----------|
| Volumen-Chart-Daten | ✅ DeltiqCore-Tests vorhanden | `CardioFeasibilityCalculator`-Tests existieren; neue Tests für `chartPhases` + `chartPoints` falls noch fehlend |
| `recommendation(for:)` | ✅ | Unit-Test: je 5 Concern-Cases → non-nil String |
| Erstaktivierungs-UX | ✅ | Unit-Test: given [.nextWorkout, .coachingInsight], toggle → runCoachCard an Position 1 |
| Chart-Render | ❌ XCUITest | Kein Präzedenzfall im Repo; visuell auf Device/Simulator |

---

## 8. Abgrenzung zu Phase 4

Phase 3 schließt explizit aus:
- Keine KI-generierten Trainingsempfehlungen
- Kein neues Backend
- Kein Push-Notification-Trigger aus den Concerns
- Kein personalised pace adjustment

---

## 9. Offene Fragen vor Implementierung

1. **Chart-Overlay Ist-Daten**: Soll der Volumen-Chart nur die Projektion zeigen, oder zusätzlich die letzten 8 Ist-Wochen aus `last8WeeksBuckets` als Overlay? Overlay macht die Karte nützlicher, aber erfordert eine zweite Series im Chart.

2. **`cardioJunkMiles` Context**: Im Audit-Comment steht „bewusst NICHT Teil der Priority-Liste" für `cardioJunkMiles`. Ist Phase 3 der richtige Zeitpunkt, diesen Concern zu aktivieren? (Requires Junk-Miles-Detection ist fertig in `CardioCoachingAdvisor.isJunkMiles`, aber ein passender Auslöser im SoftCoachingContext fehlt noch.)

3. **Widget-Repositionierung**: Soll die Erstaktivierungs-UX (`runCoachCard` nach oben) auch beim nachträglichen Einschalten passieren, oder nur beim allerersten Aktivieren (d.h. einen `wasEverEnabled`-Flag in `UserBodyProfile` setzen)?

---

*Phase 3 Schritt 1 (Audit) und Schritt 2 (Design Review) abgeschlossen. Implementierung (Schritt 3) erfordert explizite Freigabe.*
