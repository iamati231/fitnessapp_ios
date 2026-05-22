# Contributing

Working notes für den Deltiq iOS-Repo. Diese Doku dokumentiert die in
~140 Commit-Wellen entstandenen Patterns + Verbindlichkeiten — wenn du
einen neuen Beitrag machst, sind die hier festgehaltenen Conventions
"unausgesprochener Standard" und sollen nicht jedes Mal neu verhandelt
werden.

## Dev-Setup

- **Plattform**: Windows + Codemagic CI (kein Mac lokal).
- **Build-System**: `xcodegen generate` (via `project.yml`), dann
  `xcodebuild`. Keine committed `.xcodeproj` — wird auf CI generiert.
- **Localization**: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
  als kanonische Single-Source. DE + EN + TR jeweils komplett.
- **iOS-Deployment-Target**: 17.0 (SwiftData, `@Observable`, neuer
  `.task`-Modifier).

## Dead-Code-Audit (Pflicht nach Refactors)

Nach jedem nicht-trivialen Refactor (i18n-Migration, View-Konsolidierung,
gerenamte Catalog-Keys) IMMER das Audit-Tool laufen lassen:

```bash
python .scripts/dead_catalog_v3.py
```

Akzeptanzkriterium: `UNUSED: 0`. Wenn das Tool unreferenzierte Keys
meldet:

1. **Verifizieren** ob das Tool den Pattern nicht catched (z.B. komplexe
   Format-String-Konstruktion). Im Zweifel manuell
   `grep -rn '"keyname"' Sources/` als Cross-Check.
2. **Wenn wirklich tot** → in dediziertem Sweep-Commit löschen. Pattern:
   `.scripts/del139_delete_dead_keys.py` als Vorlage.
3. **Migrationskritisches NIE einfach löschen** (SwiftData `@Model`-
   Felder, persisted AppStorage-Defaults) — User-Decision einholen.

## TRANSLATIONS.md Re-Generation

Bei jedem i18n-Refactor ZUSÄTZLICH die Translations-Doc regenerieren:

```bash
python .scripts/generate_translations_md.py
```

Output:
* Aktuelle Key-Count + DE/EN/TR-Coverage-Statistik
* Alle Keys nach Namespace gruppiert mit ihren Werten (Translator-
  friendly Tabellen-Format)
* Hardcoded-String-Scan (Akzeptanzkriterium: 0)

Im selben Commit wie die Code-Änderung — sonst driftet die Doku weg.

## xcstrings-Patterns

### Camel-Case-Suffix gegen Parent-Leaf-Collisions

Xcode-26.4.1's `GenerateStringSymbols`-Step bricht bei Parent-Leaf-
Collisions wie:

```
foo.bar.empty         (Leaf-Value)
foo.bar.empty.title   (Treats `empty` als Parent-Namespace)
```

Lösung: **camelCase als Sub-Key statt dot-separator**.

```
✗ foo.bar.empty + foo.bar.empty.title    (Collision)
✓ foo.bar.empty + foo.bar.emptyTitle     (kein Konflikt)
```

Siehe DEL-121 für die historische Build-Saga.

### Plural-Branches via `.one` / `.other` Namespace-Keys

Apple's `variations.plural` in xcstrings bricht ebenfalls den Symbol-
Generator. Stattdessen explicit branchen:

```swift
// catalog
foo.metric.days.one    = "%lld Tag"
foo.metric.days.other  = "%lld Tage"

// usage
let key: String.LocalizationValue = count == 1
    ? "foo.metric.days.one"
    : "foo.metric.days.other"
let raw = String(localized: key, bundle: .module)
let display = raw.replacingOccurrences(of: "%lld", with: "\(count)")
```

### Format-Args via positional-`%1$@`/`%2$@`

Wenn ein Format-String mehrere Args hat, immer positional:

```
exercise.target.strengthFormat = "%1$lld × %2$@ %3$@ • %4$llds %5$@"
```

Caller macht die Substitution manuell via `String(format: …)`.

## Binary-Files

`.gitattributes` markiert Binary-Formate explicit (PNG/JPG/Audio/Font).
NIE neue Binärformate ohne entsprechenden `.gitattributes`-Entry
committen — `core.autocrlf=true` (Windows-Default) korrumpiert sie sonst
beim Commit. Siehe DEL-134 / Icon-Saga.

## SwiftData-Migration

- **Neue `@Model`-Felder**: IMMER mit Default-Value-Expression
  (Lightweight-Migration). Beispiel:
  ```swift
  public var heroMetricSlotsRaw: [String]
      = HeroMetricType.defaultOrder.map { $0.rawValue }
  ```
- **Felder löschen**: Niemals leichtfertig — bricht Bestands-User-DBs.
  User-Decision erforderlich.
- **Per-instance Delete** statt `modelContext.delete(model:)` — die
  Batch-Variante umgeht `@Relationship`-Rules und triggert "mandatory
  nullify inverse"-Violations. Siehe `SettingsView.deleteAll(of:)`.

## Reset-Sequenz (DEL-134)

`AppStorage("isResetting")`-Flag gates die ganze UI:
1. SetActions setzt `isResetting = true` SOFORT
2. `RootView` checkt den Flag und rendert `ProgressView` statt
   MainTabView/OnboardingView
3. SwiftData-Deletes laufen in `DispatchQueue.main.async` (deferred)
4. Nach `modelContext.save()` (Success oder Error) Flag auf `false`
5. RootView swappt automatisch zur passenden View

Recovery: `RootView.task` forciert `isResetting = false` beim Launch
falls ein vorheriger Reset mid-flight crashed (iOS-Background-Termination).

## Number-Formatting

Body-Composition-Werte (Weight, Body Fat, FFMI, BMI, Lean Mass) und
abgeleitete Metriken IMMER:

```swift
value.truncated(to: 2).formattedTwoDecimals
```

- **Truncate** (nicht round) damit "Fortschritt" nicht kosmetisch
  hochgerundet wird (User-Vertrauen).
- **Two decimals** als App-weiter Standard für Doubles.
- Integer-Counts (Schritte, Workouts, Sätze, BPM) als plain
  `"\(value)"` ohne Dezimalen — semantische Korrektheit schlägt
  typografische Uniformität.

## Naming-Conventions

- **Catalog-Keys**: `domain.subdomain.purpose` mit camelCase-Suffix:
  `summary.section.stats`, `dashboardSettings.section.hero.title`.
- **Commit-Messages**: `DEL-XYZ` oder `UX-XYZ` Prefix mit kurzer
  Beschreibung, Co-Authored-By: Claude im Footer.
- **Skripte** in `.scripts/`: `del<NNN>_<purpose>.py` für Catalog-
  Mutationen, idempotent (skip-if-exists Pattern).

## Tooling-Übersicht

| Script | Zweck |
|---|---|
| `dead_catalog_v3.py` | Audit unused xcstrings-Keys (Pflicht nach Refactors) |
| `rebuild_app_icon.py` | Re-generate alle 18 App-Icon-Sizes aus 1024er Master |
| `del<NNN>_*.py` | Historische Catalog-Inject-Skripte (Idempotent, dokumentarisch) |

## Co-Authoring-Convention

Commits enden mit:
```
Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

Reflektiert die Tool-augmented Entwicklung. Reviewability bleibt auf
Atakan, aber die AI-Co-Authorship ist transparent.
