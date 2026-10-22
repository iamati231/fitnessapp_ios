# Hauptnavigation (5 Tabs) Design

**Status:** Freigegeben — Zielstruktur ist `C:\Users\a.isik\Downloads\Deltiq_Navigationsplan.md`
(bereits vom Nutzer bereitgestellt), dieses Dokument bildet sie auf den
tatsächlichen Repo-Stand ab und trifft die darin offen gelassenen
technischen Entscheidungen.

## Ziel

Die Hauptnavigation wird von 5 funktions-/werkzeug-orientierten Tabs auf
5 tagesablauf-orientierte Tabs umgestellt:

| Aktuell (`AppTab`) | Neu | Inhalt |
|---|---|---|
| `.dashboard` ("Dashboard") | **Heute** | Unverändert `DashboardView` — nur Tab-Label/Icon. |
| `.plan` ("Plan") | **Training** | Unverändert `WorkoutRootView` — nur Tab-Label. |
| *(neu)* | **Ernährung** | `NutritionDayView` direkt als Tab-Wurzel — **keine neue Zwischenseite** (explizite Nutzerentscheidung: kein zweites Ernährungsdashboard, keine Wochenübersicht vorgeschaltet). |
| `.measurement` ("Messung") | **Fortschritt** | Unverändert `MeasurementView`, nur Tab-Label — siehe Abschnitt "Scope-Einschränkung Fortschritt". |
| `.tools` + `.settings` ("Werkzeuge" + "Mehr") | **Mehr** | `SettingsView`, erweitert um einen neuen Navigationslink zu `CalculatorsView` (bisheriger `.tools`-Tab-Inhalt wandert hier als Unterpunkt rein). |

Der **wichtigste Effekt** dieser Umstellung: Ernährung ist aktuell NUR
über eine optionale, bei Bestandsnutzern inaktive Dashboard-Kachel
erreichbar (`DashboardWidgetType.nutrition`, `DashboardView.swift` ist der
einzige Code-Pfad zu `AddMealView`/`NutritionDayView` im ganzen Repo). Mit
einem eigenen Tab ist die gesamte Ernährungsfunktion (Katalogsuche,
manuelle Erfassung, KI-Freitext-Erfassung, Online-Suche, eigenes
Lebensmittel anlegen) immer erreichbar — unabhängig vom
Kachel-Ein-/Ausblende-Status. Die Dashboard-Kachel bleibt als optionaler
Schnellzugriff bestehen (bestehende Nutzerpräferenzen unverändert), wird
aber kein Gatekeeper mehr.

## Scope-Einschränkung Fortschritt

Der Referenzplan beschreibt für "Fortschritt" eine reichere Struktur
(Körper/Kraft/Ausdauer/Plan-Checks). Recherche im Repo: **es existieren
aktuell keine eigenständigen, navigierbaren Vollbild-Ansichten für
Kraft-/Ausdauer-Trends oder Plan-Check-Rückblicke** — `compoundLifts`,
`cardioPace`, `trophyRoom`, `trainingCalendar` etc. sind ausschließlich
inline gerenderte Dashboard-Karten (`DashboardView.swift`), keine eigenen
Screens. Der Referenzplan selbst verlangt explizit: "Falls noch kein
gemeinsamer Fortschritts-Einstieg existiert, eine schlanke Übersicht mit
Links zu **vorhandenen** Ansichten ergänzen" und verbietet neue
Statistik-/Analyse-Entwicklung.

**Entscheidung:** Fortschritt-Tab zeigt für diesen Umsetzungsschritt
ausschließlich die bestehende `MeasurementView` (= "Körper"). Kraft/
Ausdauer/Plan-Checks werden NICHT als leere oder platzhalterhafte
Menüpunkte vorgetäuscht (ausdrückliches Verbot im Referenzplan) — sie
bleiben vorerst nur über ihre bestehenden Dashboard-Karten erreichbar.
Das ist eine bewusste Lücke, kein Versehen, und wird im Abschlussbericht
als offener Punkt genannt.

## Ernährungstab — Details

- Tab-Wurzel: `NavigationStack { NutritionDayView() }`, analog zu den
  anderen vier Tabs.
- Standarddatum: heute. Frühere Tage über die in `NutritionDayView`
  bereits vorhandene Datumsauswahl — keine neue Datums-UI.
- Der Tab bleibt sichtbar und bedienbar, wenn die lokale KI nicht
  verfügbar ist (bereits durch Tasks D-F sichergestellt — hier nur
  sicherstellen, dass der Tab selbst nicht an eine KI-Verfügbarkeits-
  Prüfung gekoppelt wird).
- Tageswerte/Mahlzeiten gehören weiterhin zum ausgewählten Datum
  (unverändertes `NutritionDayView`-Verhalten).

## Dashboard-Kachel — Verhalten nach der Umstellung

Aktuell pusht die Dashboard-Kachel `NutritionDayView` vermutlich in den
eigenen `NavigationStack` von `DashboardView` (zu verifizieren beim
Implementieren, exakter Call-Site). Nach dieser Umstellung: Tap auf die
Kachel wechselt stattdessen den Tab (`navigation.selectedTab = .nutrition`)
statt eine zweite, parallele Ernährungs-Navigation im Dashboard-Stack
aufzubauen (explizites Verbot im Referenzplan: "Keine zweite vollständige
Ernährungs-... Verwaltung im Dashboard aufbauen"). Bestehende
Kachel-Sichtbarkeits-Präferenzen (aktiv/inaktiv, Reihenfolge) bleiben
unverändert erhalten — die Kachel wird nur zu einem Schnellzugriff,
nicht entfernt.

## "Mehr" — Werkzeuge-Integration

`SettingsView` ist bereits in 5 gruppierte Navigationsbereiche
strukturiert (`groupNavigationSection`, 4 bestehende `NavigationLink`s:
AppExperience, DataConnections, LibraryEquipment, HelpInfo). Neuer 5.
`NavigationLink` zu `CalculatorsView` in genau dieser Sektion, selbes
`DeltiqRow`-Muster, passendes Icon (z.B. `"square.grid.2x2"`, bisheriges
Tab-Icon). Der `.tools`-Tab/`toolsPath` entfällt; `CalculatorsView`
bekommt stattdessen ihren eigenen Navigations-Pfad innerhalb des
Settings-`NavigationStack` (gleiches Prinzip wie bisher, nur eine Ebene
tiefer gehängt).

**Wassertracker-Deep-Link:** `RootView.applyPendingRouteIfAny()` setzt
aktuell `selectedTab = .tools` + `toolsPath = NavigationPath([.waterTracker])`.
Wird auf `selectedTab = .settings` + einen äquivalenten Pfad in die neue
Werkzeuge-Unteransicht umgestellt — einziger betroffener Code-Pfad
(`RootView.swift`, laut Recherche keine weiteren Referenzen auf
`.tools`/`toolsPath`).

**Mein Profil vs. App-Einstellungen:** `SettingsView` hat bereits eine
separate `profileSection` (Profil/Ziele) von der Gruppen-Navigation
getrennt — die vom Referenzplan geforderte Trennung "fachliche
Profilangaben" vs. "App-Einstellungen" existiert damit schon strukturell;
keine Änderung hier nötig außer ggf. Umbenennung der Sections-Überschrift,
falls das Label noch "Werkzeuge" fehlt zu erwähnen.

## `AppTab`-Enum-Änderung

```swift
public enum AppTab: Hashable, Sendable {
    case dashboard   // "Heute" — unveraendert
    case plan        // "Training" — unveraendert
    case nutrition   // NEU
    case measurement // "Fortschritt" — unveraendert als Case-Name
    case settings    // "Mehr" — unveraendert
    // .tools entfernt
}
```

`AppTab` ist ein reiner Swift-Enum ohne `RawValue`, `selectedTab` wird
NICHT in `AppStorage`/SwiftData persistiert (nur In-Memory im
`AppNavigation`-Observable, pro App-Start auf `.dashboard` zurückgesetzt)
— das vom Referenzplan befürchtete Risiko stiller Fehlzuordnung durch
geänderte numerische Indizes betrifft dieses Projekt laut Recherche NICHT
(keine persistierte Tab-Auswahl gefunden). `DashboardWidgetType` (separates,
tatsächlich per String persistiertes Enum für Dashboard-Karten) ist davon
unberührt und wird durch diese Spec nicht angefasst.

## Zustand/Entwurfsschutz

Unverändert — `AppNavigation.workoutPath` bleibt pro Tab erhalten,
`WorkoutRootView` verwaltet seinen eigenen Stack weiter selbst. Diese
Spec ändert an der bestehenden Entwurfsschutz-/Session-Fortsetzungs-Logik
NICHTS; sie fügt nur einen zusätzlichen Tab hinzu und verschiebt
`CalculatorsView` von einer eigenen Tab-Wurzel in einen Navigationslink
unter "Mehr". Ein Tab-Wechsel darf weiterhin keine offene Eingabe/aktive
Trainingseinheit verwerfen — das ist bereits durch die bestehende
`NavigationStack`-pro-Tab-Architektur sichergestellt, nicht neu zu bauen.

## Global Constraints

- Keine neuen Statistiken, Rechner oder Coaching-Algorithmen — reine
  Navigations-/Zuordnungs-Änderung.
- Bestehende Views, Modelle und Berechnungen werden wiederverwendet, nicht
  dupliziert oder neu gebaut.
- Keine bestehenden Daten werden gelöscht oder migriert — rein UI-seitige
  Umstrukturierung.
- Jedes neue/geänderte sichtbare Label geht über `Localizable.xcstrings`
  (DE/EN/TR).
- Alle 5 Tabs müssen auf kleiner Gerätebreite und bei großer
  Bedienungshilfen-Schrift sichtbar und bedienbar bleiben (nicht
  abgeschnitten, nicht durch Overflow versteckt).
- Vor Beginn der Implementierung tatsächliche Dateiüberschneidungen mit
  den anderen gerade laufenden Teilprojekten (Online-Food-Lookup) prüfen
  — `AddMealView.swift`/`NutritionDayView.swift` werden von beiden
  Teilprojekten potenziell berührt.
- Kein Merge nach main, kein Release.

## Review Focus

- **Dashboard-Karte als einziger bisheriger Einstieg:** nach der
  Umstellung muss der Tab-Einstieg GENAUSO funktionieren wie der
  Kachel-Einstieg vorher — keine Regression für Nutzer, die die Kachel
  bereits aktiviert hatten.
- **Wassertracker-Deep-Link:** die Erinnerungs-Notification muss nach der
  `.tools`-Entfernung weiterhin direkt zum Wassertracker durchpushen, nicht
  nur auf "Mehr" landen.
- **Laufende Trainingseinheit + Tab-Wechsel:** explizit mit einem aktiven
  Workout testen, während zwischen allen 5 Tabs gewechselt wird — Timer/
  Satzdaten dürfen nicht zurückgesetzt werden.
- **Große Schrift (Accessibility Dynamic Type) bei 5 Tab-Labels:** das
  längste neue Label ("Fortschritt") darf die anderen nicht zum Abschneiden
  zwingen — auf kleinster unterstützter iPhone-Breite UND größter
  Schriftgröße prüfen.
- **DE/EN/TR-Label-Längen:** "Ernährung"/"Fortschritt" können in anderen
  Sprachen deutlich länger werden — alle 3 Sprachen auf Überlauf prüfen.
