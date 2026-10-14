# Plan-Matching & Equipment — Audit

Quelle: `PLAN_MATCHING_AND_EQUIPMENT_COMBINED.md` (Upload), Abschnitte 1+2.
Alle Befunde unten sind durch direktes Lesen des aktuellen Codes auf
`claude/smart-onboarding-epic` verifiziert (Dateipfad + Zeile angegeben) —
teils selbst gelesen, teils über einen Recherche-Agenten gefunden und
danach an den genannten Stellen stichprobenartig selbst nachgelesen.
Keine Annahme aus der Spezifikation wurde ungeprüft übernommen.

## 1. Szenario 8 — Ursache und Fix (bereits umgesetzt)

**Reproduktion** (Eingaben: Erfahren, Abnehmen, Gym, 4 Tage) via
Swift-Scratch-Test, siehe Commit `f55f02f`. Zwei unabhängige Ursachen
gefunden und behoben:

1. `ExperienceTrack.templateScoreBonus` gab Erfahrenen einen pauschalen +1
   für **jedes** `.advanced`-getaggte Template — auch wenn es zusätzlich
   das eigene gemappte Level bereits trug (`crossfit_weighted`:
   `[.beginner, .intermediate, .advanced]`) und darüber schon die vollen
   Basis-+2 für "Level" kassiert hatte. Fix: Bonus nur noch für Templates,
   die das Nutzer-Level **nicht** bereits selbst tragen (reiner Ausgleich
   für Templates wie Arnold Split, die sonst beim Level-Term leer ausgehen).
2. Ein Kraft-Split ohne eigenen `weightLoss`-Tag (z. B. Upper-Lower) konnte
   gegen ein explizit `weightLoss`-getaggtes Zirkel-/CrossFit-Programm
   rechnerisch nie gewinnen, selbst bei exakt passenden Tagen/Level/
   Equipment — ein fehlender Zieltag hat ihn komplett aus dem Rennen
   genommen. Fix: neuer Scoring-Term `goalIsSupportedButNotPrimaryFocus`
   (`PlanMatchmaker.swift:149-152`) — nur für `.weightLoss`, nur für
   Templates mit echtem Hypertrophie-/Kraft-Fokus, bewusst **keine**
   pauschale weightLoss-Freigabe für alle Templates und bewusst **kein**
   Zusatzpunkt für Zirkel-/CrossFit-Programme (das ist eine
   Trainingspräferenz, keine automatische Konsequenz aus "Abnehmen").

Ergebnis: Upper-Lower (einziger 4-Tage-Kandidat) rankt jetzt vor CrossFit
mit Gewichten und Kettlebell Grundlagen. Details, Zahlen und die beiden
Regressionstests siehe Commit `f55f02f` und
`Tests/FitnessAppCoreTests/PlanMatchmakerTests.swift` (Abschnitt
"Szenario 8").

## 2. Wochenziel wird 1:1 als Tage-Obergrenze verwendet (bestätigt)

Die Vorgabe verlangt in Abschnitt 6 ausdrücklich, das Wochenziel von der
tatsächlich verfügbaren Tagesanzahl zu trennen ("Mindestens 3 schaffen ist
nicht automatisch maximal 3 verfügbar"). Das ist **real so im Code**, und
zwar als bewusste, dokumentierte Design-Entscheidung aus einem früheren Fix
— kein Versehen:

```swift
// Sources/FitnessAppUI/OnboardingView.swift:1255-1267
/// Fix "doppeltes Onboarding": die Antworten, mit denen der
/// Plan-Schritt direkt `PlanMatchmaker.rankPlans` aufruft — `weeklyGoal`
/// dient zugleich als `preferredDays`, eine zweite "wie oft"-Frage nur
/// fuers Matching gaebe es sonst doppelt.
private var planMatchAnswers: QuizAnswers {
    QuizAnswers(
        goal: trainingGoal,
        experience: (resolvedExperienceTrack ?? .experienced).asExperienceLevel,
        preferredDays: weeklyGoal,
        environment: environment,
        equipmentPreferences: equipmentPreferences
    )
}
```

Die tatsächlich gestellte Frage (`onboarding.weeklyGoal.title`/`.subtitle`)
fragt explizit nach einem **Commitment-Ziel**, nicht nach Verfügbarkeit:

> DE: "Dein Wochenziel" — "Wie oft willst du pro Woche trainieren? Dein
> Kalender-Streak zählt gegen dieses Ziel — wähle, was du wirklich
> durchhalten kannst."

Ein Nutzer, der hier bewusst konservativ "3" wählt (um den Streak sicher zu
halten), obwohl er an 5-6 Tagen Zeit hätte, bekommt `preferredDays: 3` —
der harte K.O.-Filter `daysPerWeek <= answers.preferredDays`
(`PlanMatchmaker.swift:84`) schließt dann jedes 4+-Tage-Template aus, nicht
weil der Nutzer an diesen Tagen nicht könnte, sondern weil er sich ein
niedrigeres *Ziel* gesetzt hat. Das ist exakt der in Abschnitt 6 der
Vorgabe benannte Fehler, hier am Code nachgewiesen statt nur vermutet.

**Wichtig für die Einordnung**: die bestehende Konflation ist kein Bug,
sondern die bewusste Auflösung eines früheren Problems ("doppeltes
Onboarding" — zwei separate "wie oft"-Fragen wirkten redundant). Eine
Entflechtung braucht entweder eine neue, UX-seitig sauber von "Wochenziel"
abgegrenzte Verfügbarkeitsfrage, oder eine andere, bewusste Zuordnung —
das ist eine Produktentscheidung, keine reine Code-Korrektur, und wird
deshalb hier nur dokumentiert, nicht in diesem Durchlauf umgesetzt (siehe
Abschnitt 8).

## 3. Szenario 12 — Ursache: keine Bank-Equipment-Option

Es gibt **keine** Bank-Option irgendwo im Onboarding, weil es dafür auf
Modell-Ebene gar keinen Equipment-Fall gibt:

```swift
// Sources/FitnessAppCore/Domain/DomainEnums.swift:4-13
public enum Equipment: String, Codable, Sendable, CaseIterable {
    case barbell, dumbbell, bodyweight, machine, cable, kettlebell, band
}
```

Sieben grobe Kategorien, keine Bank (flach/verstellbar), kein Rack, keine
Klimmzugstange, keine Dip-Barren. Das ist kein UI-Versehen — das
Onboarding hat bereits eine vollwertige, dedizierte Multi-Select-Equipment-
Frage (`OnboardingView.swift`, Step `.equipmentPreferences`, Titel
"Was trainierst du damit?" / `onboarding.equipment.title`, Toggle-Zeilen
über `Equipment.allCases`) — die Lücke liegt rein im zu groben Enum, nicht
im UI-Pattern. Eine "Bank-Checkbox" ließe sich ohne Erweiterung von
`Equipment` nicht einmal persistieren oder gegen Templates matchen.

**Präzedenzfall**, der zeigt, dass dieses Problem schon einmal real
aufgetreten ist:

```swift
// Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift:90-95
// C. Pull — Equipment entscheidet den Pfad (siehe `pullHasGymEquipment`);
// ... nach einer Klimmzugstange gefragt, da `Equipment` dafür keinen
// eigenen Fall kennt.
@State private var hasPullUpBar: Bool?
```

Der Baseline-Check musste für "hat der Nutzer eine Klimmzugstange" exakt
dasselbe Problem umschiffen — mit einer lokalen, **nicht persistierten**
`Bool?`-Variable (`BaselineCheckFlowView.swift:95`), die nach Abschluss des
Flows verloren geht und vom `PlanMatchmaker`/der Instanziierung nie wieder
gelesen wird. Eine dritte, parallele Ad-hoc-Lösung für die Bank wäre damit
bereits die **dritte** unabhängige Umgehung derselben Modell-Lücke. Die
Spezifikation verlangt zu Recht die strukturelle Lösung (Abschnitt 3/4)
statt einer weiteren Checkbox.

## 4. Equipment-Datenmodell — Bestandsaufnahme

| Ebene | Typ | Fundort | Granularität |
|---|---|---|---|
| Einzel-Übung | `Equipment` (7 Fälle) | `DomainEnums.swift:4` | 1 Kategorie pro Übung, kein AND/OR, keine Stückzahl, keine Last |
| Programm-Variante | `EquipmentProfile` (4 feste Shapes: barbellGym/dumbbellOnly/kettlebellOnly/machineGym) + Priorität | `EquipmentVariant.swift:11-43` | Ganzer Tage-Satz wird 1:1 getauscht, keine Einzel-Übungs-Anpassung |
| User-Profil | `equipmentPreferencesRaw: [String]` → `Set<Equipment>` | `UserBodyProfile.swift:59,307-310` | Flaches Set, **kein Tri-State** |

`EquipmentVariant.bestMatch` (`EquipmentVariant.swift:64-71`) wählt unter
mehreren passenden `EquipmentProfile`s das mit der höchsten Priorität
(`barbellGym` > `dumbbellOnly` > `kettlebellOnly` > `machineGym`). Das ist
ein grobes Subset-Matching auf 4 fest codierte Kombinationen — keine der
vom Auftrag geforderten AND/OR/Anzahl/Last-Strukturen (Abschnitt 4 der
Vorgabe) ist damit abbildbar (z. B. "zwei passende Kurzhanteln UND eine
verstellbare Bank" lässt sich in diesem Modell nicht ausdrücken).

**Nur 3 von 20 Katalog-Templates** haben überhaupt `equipmentVariants`:
`hybrid_beginner` (`ProgramTemplates.swift:574`, Variante bei `:610`),
`hybrid_balanced` (`:660`, Variante bei `:704`), `hybrid_performance`
(`:772`, Variante bei `:821`) — jeweils genau eine `.dumbbellOnly`-
Variante. Für die übrigen 17 Templates (u. a. alle in
`docs/PLAN_CATALOG_AUDIT.md` genannten reinen Langhantel-Programme) gibt es
**keinerlei** Equipment-Anpassungsmechanismus — nur den harten Filter
`PlanMatchmaker.equipmentMatches` (lässt das Template durch oder nicht),
nie eine Anpassung des Inhalts.

**Equipment ist bereits an zwei Stellen nutzerseitig editierbar**, beide
mit identischer, auf die 7 `Equipment`-Fälle begrenzter UI:
- Onboarding: `OnboardingView.swift`, Step `.equipmentPreferences`
  (Multi-Select-Toggle-Zeilen über `Equipment.allCases`).
- Settings: `ProfileEditorView.swift:836-847` (`equipmentCard`, dieselbe
  `ForEach(Equipment.allCases, ...)`-Toggle-Liste).

Ein künftiger Umbau muss beide Stellen konsistent halten (gleiche
Komponente/gleicher Zustand), sonst entsteht Drift zwischen Onboarding und
nachträglicher Bearbeitung.

## 5. Konkrete Lücken

### 5.1 "Ort ist nicht Ausstattung" — Environment schlägt Equipment vor (Vorschlag, kein Bypass)

```swift
// Sources/FitnessAppUI/OnboardingView.swift:913-921
/// Sinnvolle Equipment-Defaults pro Trainings-Umgebung. Gym = "hat alles";
private func defaultEquipment(for env: EnvironmentType) -> Set<Equipment> {
    switch env {
    case .gym:         return [.barbell, .dumbbell, .machine, .cable, .kettlebell, .bodyweight]
    case .homeGym:     return [.dumbbell, .kettlebell, .band, .bodyweight]
    case .noEquipment: return [.bodyweight, .band]
    }
}
```

Der Kommentar sagt wörtlich "Gym = hat alles" — inhaltlich genau das von
der Vorgabe verbotene Muster. **Einschränkend korrekt einzuordnen**: das
ist kein stiller Bypass. Die Equipment-Frage bleibt ein eigener,
sichtbarer, editierbarer Onboarding-Schritt (Abschnitt 3); `defaultEquipment`
liefert nur eine **vorangekreuzte Vorauswahl** auf dieser Seite
(`prefillEquipmentIfNeeded`, `formUnion` statt Überschreiben — siehe 5.2),
der Nutzer kann jede Checkbox wieder abwählen, bevor er weiterklickt. Der
reale Effekt ist trotzdem problematisch: eine vorangekreuzte "hat alles"-
Vorauswahl auf einer Seite, die viele Nutzer nur kurz überfliegen, führt in
der Praxis dazu, dass z. B. eine fehlende Bank nie aktiv auffällt, weil das
Modell dafür ohnehin keinen Fall kennt (Abschnitt 3) — das eigentliche
Problem ist die Kombination aus "optimistischer Default" und "zu grobes
Modell", nicht eine einzelne stille Überschreibung.

### 5.2 Prefill verschmilzt nur (fügt hinzu), bereinigt aber nie

```swift
// Sources/FitnessAppUI/OnboardingView.swift:906-911
private func prefillEquipmentIfNeeded(force: Bool = false) {
    if !force, equipmentPrefilledForEnv == environment { return }
    let suggestion = defaultEquipment(for: environment)
    equipmentPreferences.formUnion(suggestion)
    equipmentPrefilledForEnv = environment
}
```

Das ist absichtlich so gebaut, um eine bewusste Nutzer-Auswahl nie zu
überschreiben (`formUnion`, nie `=`) — das ist für sich genommen richtig.
Aber das Verhalten ist nur einseitig sicher: wechselt ein Nutzer von
`.gym` zu `.homeGym` oder `.noEquipment`, bleiben die beim Gym-Prefill
hinzugefügten `.machine`/`.cable`/`.barbell`-Einträge **für immer** in
`equipmentPreferences` stehen, weil nichts sie je wieder entfernt — ein
eigener, von der Vorgabe nicht explizit genannter, aber genauso realer
Bug: falsch-positive Equipment-Reste nach einem Standortwechsel nach unten
(Gym → Home-Gym/Körpergewicht). Das ist zusätzlich zu dem in Abschnitt 3
der Vorgabe explizit verlangten Schutz ("Standortwechsel darf bestätigte
Auswahl nicht überschreiben") zu lösen — hier geht es um die Kehrseite,
dass er sie auch nie bereinigt.

### 5.3 Kein Tri-State — `[]` ist doppeldeutig

```swift
// Sources/FitnessAppData/UserBodyProfile.swift:55-58
// Default leer — Lightweight-Migration: pre-DEL-170-Profile kommen mit
// `[]` an. Plan-Matcher behandelt leeres Set wie "User hat das nicht
// gepflegt" und nutzt die Standard-Variante (template.days).
public var equipmentPreferencesRaw: [String] = []
```

Ein leeres Set bedeutet heute gleichzeitig "nie gefragt" UND müsste
eigentlich auch "bewusst bestätigt: nur Körpergewicht" bedeuten können —
beide Zustände sind nicht unterscheidbar. Das ist genau die von der
Vorgabe verlangte Tri-State-Lücke (verfügbar/nicht verfügbar/unbekannt),
hier konkret am Datenmodell nachgewiesen statt nur behauptet.

### 5.4 Vorschau und instanziierter Plan laufen für 3 Templates auseinander — direkt im Onboarding-Pfad

`TemplatePreviewView` (definiert in `ProgramTemplatePickerView.swift`,
Zeilen 190-349) wird an zwei Stellen verwendet: im eigenständigen
`ProgramTemplatePickerView` (Settings/Workout) **und direkt im
Onboarding selbst**, als Sheet mit dem Adopt-Button "Diesen Plan wählen"
(`OnboardingView.swift:197-224`) — das ist der Haupt-Bestätigungs-Dialog,
den jeder Onboarding-Nutzer vor der finalen Plan-Übernahme sieht, nicht
nur ein Nebenpfad.

Diese eine View liest für Vorschau und Übernahme zwei unterschiedliche
Datenquellen:

```swift
// ProgramTemplatePickerView.swift:356-358 — Vorschau (Liste der Tage/Übungen)
private var orderedDays: [DaySpec] {
    template.days.sorted { $0.sequenceIndex < $1.sequenceIndex }
}
```

```swift
// ProgramTemplatePickerView.swift:116-124 — tatsächliche Instanziierung
private func instantiate(_ template: ProgramTemplate) {
    let userEquipment = profiles.first?.equipmentPreferences ?? []
    let plan = ProgramInstantiator.instantiate(template, in: modelContext, userEquipment: userEquipment)
    ...
}
```

`orderedDays` liest immer `template.days` (die Basis-/Barbell-Variante) —
ganz ohne `EquipmentVariant.bestMatch`. `ProgramInstantiator.instantiate`
(`ProgramInstantiator.swift:101-114`) wählt dagegen, wenn das Template
`equipmentVariants` hat und der Nutzer die Basis-Anforderung
(`barbellGym`: Langhantel+Kurzhantel) nicht erfüllt, eine **andere**
Tage-Liste. Für die 3 betroffenen Templates (`hybrid_beginner`,
`hybrid_balanced`, `hybrid_performance`) sieht ein Nutzer ohne Langhantel
in der Vorschau also die Langhantel-Variante, bekommt aber beim Bestätigen
eine andere (z. B. Kettlebell-/Dumbbell-)Variante gespeichert — genau das
in Abschnitt 5, Punkt 5 der Vorgabe ausdrücklich geforderte Verbot
("Vorschau und instanziierter Plan müssen dieselbe geprüfte Variante
verwenden") ist hier nachweislich bereits verletzt, und zwar im zentralen
Onboarding-Bestätigungsdialog, nicht nur in einem Nebenpfad.

**Gegenbeispiel aus derselben Codebase, wie man es richtig macht**: der
custom "Plan bauen"-Assistent reicht sein zuletzt angezeigtes
`PlanGenerator.Result`-Objekt unverändert an die Instanziierung durch
(`PlanGeneratorInstantiator.swift:31-42`, Parameter `precomputed:`) —
"sonst wiche der instanziierte Plan von der im Wizard zuletzt gezeigten
Vorschau ab". Genau dieses Prinzip (ein einziges, wiederverwendetes
Ergebnis statt zwei getrennter Berechnungen) fehlt beim Template-Pfad.

**Status**: in diesem Durchlauf behoben (siehe Abschnitt 9) — isoliert vom
großen Equipment-Umbau, da klein und risikoarm.

### 5.5 Kein Ersatzübungs-Mechanismus (PlanAdapter) existiert

Repo-weite Suche nach "PlanAdapter"/"substitute"/"adapt" bestätigt: es
gibt keine Einzel-Übungs-Ersatzlogik, keine Bewegungsmuster-/Zielmuskel-
Zuordnung für Ersatz, keine Re-Verifikation nach einem Tausch — über die
in Abschnitt 4 beschriebene ganze-Tage-Liste-Variantenwahl hinaus
existiert nichts. Zwei Stellen im Code bestätigen das explizit selbst:

```swift
// Sources/FitnessAppCore/Baseline/BaselineAssessmentEvaluator.swift:4-8 (sinngemäß)
// ... die Anwendung auf einen echten Plan folgt erst, wenn ein PlanAdapter
// existiert (Epic-Vorgehen Schritt 5, Stand heute: existiert nicht).
```
```swift
// Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift:1014 (sinngemäß)
// Bis Phase 4 (PlanAdapter existiert noch nicht) ...
```

Der einzige tatsächlich implementierte Übungs-Austausch-Mechanismus im
gesamten Repo ist `PlanEnvironmentMigrator`
(`Sources/FitnessAppData/PlanEnvironmentMigrator.swift`, UI-Label "Adapt
Exercises" in `PlanEditorView.swift:174`) — er tauscht Übungen aber anhand
von `EnvironmentType` (gym/homeGym/noEquipment), nicht anhand von
`Equipment`/`equipmentPreferences`, läuft ausschließlich **nach** dem
Onboarding (bei Umgebungswechsel in Profil/Plan, z. B. "Urlaubs-Modus"),
und wird von `ProgramInstantiator`/`PlanGeneratorInstantiator` bei der
Erst-Erzeugung nie aufgerufen. Er ist ein brauchbares strukturelles
Vorbild (Alternative-Auflösung über `ExerciseLibraryData.
resolveAlternative(forExerciseName:targetEnvironment:)`), aber kein
Ersatz für den geforderten equipment-genauen, AND/OR/Anzahl-bewussten
Mechanismus aus Abschnitt 5 der Vorgabe.

Die Warnung der Vorgabe ("PlanAdapter nicht vortäuschen, wenn er noch
nicht existiert") trifft zu — er existiert nicht, auf keiner Ebene
unterhalb des ganzen Tage-Listen-Tauschs.

## 6. Betroffene Call-Sites (vollständig, Equipment-bezogen)

- `Sources/FitnessAppCore/Programs/PlanMatchmaker.swift` — `equipmentMatches`, `requiredEquipment(for:)`, `matchReasons` (K.O.-Filter + Badge, bereits in der vorigen Audit-Runde gehärtet).
- `Sources/FitnessAppData/ProgramInstantiator.swift:101-114` — Varianten-Wahl bei Instanziierung (Onboarding-Adopt + Picker-Adopt).
- `Sources/FitnessAppData/PlanGeneratorInstantiator.swift:58` — reicht `input.equipmentPreferences` nur durch, gleiche Instantiator-Logik.
- `Sources/FitnessAppUI/OnboardingView.swift:197-224` (Vorschau-Sheet), `:906-921` (Prefill), `:1255-1267` (Wochenziel-als-Tage, Abschnitt 2), `:1711-1719` (Adopt) — vier unabhängige Fundstellen in derselben Datei.
- `Sources/FitnessAppUI/Workout/ProgramTemplatePickerView.swift:116-124,356-358` — Vorschau/Instanziierung-Divergenz (Abschnitt 5.4).
- `Sources/FitnessAppUI/Settings/ProfileEditorView.swift:836-847` — zweite Editier-Stelle, gleiche 7-Fälle-Begrenzung.
- `Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift:90-203` — eigener, nicht persistierter Equipment-Sonderfall (Klimmzugstange).
- `Sources/FitnessAppData/PlanEnvironmentMigrator.swift` — strukturelles Vorbild für Ersatz-Logik, aber Environment- statt Equipment-basiert (Abschnitt 5.5).
- `Sources/FitnessAppUI/Settings/ExerciseLibraryView.swift:390`, `Sources/FitnessAppUI/Workout/DayEditorView.swift:770` — nutzen `ExerciseLibraryData.isEquipment(_:compatibleWith:)`, also Environment-basiert, nicht Equipment-Profil-basiert; von einem künftigen Equipment-Umbau separat zu betrachten.

## 7. Persistenz/Export/Import-Implikationen

- **SwiftData**: `UserBodyProfile.equipmentPreferencesRaw: [String]`
  (`UserBodyProfile.swift:59`), Default `[]`, unbekannte Rohwerte werden
  beim Lesen stillschweigend gefiltert (`:308`) — das bestehende
  Lightweight-Migrations-Muster verträgt neue `Equipment`-Fälle bereits
  verlustfrei. Ein **Tri-State-Umbau** (Abschnitt 5.3) ist aber kein
  Lightweight-Fall mehr: er braucht ein echtes "unset"-Sentinel, nicht nur
  neue Enum-Fälle.
  **Exakter Präzedenzfall dafür ist bereits im Code**: `experienceTrackRaw`
  (`UserBodyProfile.swift:127`) ist bewusst `String?` (optional) statt
  eines defaulteten Rohstrings wie `coachingToneRaw`/`trainingGoalRaw` —
  der Kommentar dort begründet das genau mit dem Tri-State-Bedarf eines
  Backfills ("nicht gesetzt" muss von jedem echten Wert unterscheidbar
  sein). Die dazugehörige Backfill-Klasse `ExperienceTrackBackfill.swift`
  (`runIfNeeded(in:)`) verarbeitet ausschließlich Profile mit
  `experienceTrackRaw == nil`, leitet einmalig aus echter Trainingshistorie
  her und schreibt nie ein bereits gesetztes Feld um — Idempotenz und
  Nie-überschreiben sind in
  `Tests/FitnessAppDataTests/ExperienceTrackBackfillTests.swift` gegen
  einen echten In-Memory-`ModelContainer` abgesichert. Ein künftiger
  Equipment-Tri-State-Umbau sollte exakt dieses Muster wiederverwenden
  (optionales Sentinel-Feld + eigene, getestete Backfill-Klasse), statt ein
  neues zu erfinden.
- **CSV-Export/Import**: `DataExportService.swift:223,255` schreibt eine
  `equipment_preferences`-Spalte (Semikolon-getrennte Rohwerte,
  `DataImportService.swift` liest sie über denselben `splitMulti`-Helper
  zurück) — ein vollständiger, funktionierender Rundlauf für das heutige
  flache Set. Ein Tri-State- oder Mengen-/Count-Modell braucht
  zusätzliche Spalten (nicht nur neue Werte in der bestehenden) — der
  Import muss alte Export-Dateien ohne diese Spalten weiterhin als
  "unbekannt" (nicht "leer = nichts vorhanden") einlesen. Die generischen
  Backup-UIs (`DataExportView.swift`, `DataImportView.swift`) haben keinen
  eigenen Equipment-Code — Equipment reist dort nur als Teil von
  `profile.csv` mit, ein Spalten-Zusatz betrifft sie nicht direkt.
- **Settings-Portabilität**: `ProfileEditorView.swift:836-847` ist die
  einzige Nach-Onboarding-Bearbeitungsstelle — ein künftiges
  Mehrfachauswahl-UI (Abschnitt 3 der Vorgabe) muss dort UND im Onboarding
  denselben Zustand/dieselbe Komponente verwenden, um Drift zwischen
  beiden Eingabewegen zu vermeiden (siehe Abschnitt 4, letzter Absatz).

## 8. Baseline-Check's Bezug zu Equipment

Nicht vollständig unabhängig — ein schmaler, UI-lokaler Berührungspunkt:
`BaselineCheckFlowView` nutzt `equipmentPreferences` ausschließlich, um zu
entscheiden, welche Pull-Test-Variante angeboten wird
(`pullHasGymEquipment`, Zeilen 198-200, kombiniert mit dem nicht
persistierten `hasPullUpBar`, Abschnitt 3). Die eigentliche Score-Logik
`BaselineAssessmentEvaluator` (Core) nimmt nirgends Bezug auf `Equipment`
und hat laut eigenem Kommentar (Zeilen 4-8) noch keine Verbindung zur
Planerzeugung — genau der in Abschnitt 5.5 zitierte PlanAdapter-Hinweis.

## 9. Eingrenzung dieses Durchlaufs

Der Upload fordert in Abschnitt 3-5 einen vollständigen Umbau: neues
Tri-State-Equipment-Datenmodell samt SwiftData-Migration, ein überarbeitetes
Mehrfachauswahl-Onboarding-UI (Granularität statt neuem UI-Pattern — das
Pattern existiert, siehe Abschnitt 3), eine AND/OR/Anzahl/Last-
Anforderungsstruktur pro Übungsvariante in `ExerciseLibraryData`, und einen
neuen, getesteten Ersatzübungs-Mechanismus (PlanAdapter) inklusive
Re-Verifikation. Das sind mehrere voneinander abhängige, aber einzeln
schon substanzielle Architektur-Änderungen mit Persistenz-Migration —
realistisch mehrere eigenständige PRs, nicht in einem Durchgang seriös
umsetzbar, ohne die von der Vorgabe selbst verbotene Abkürzung zu nehmen
("PlanAdapter nicht vortäuschen", "kein beliebiger 1:1-Tausch").

**In diesem Durchlauf umgesetzt**:
- Abschnitt 1 (Szenario-8-Reproduktion + Fix, Commit `f55f02f`).
- Dieser Audit (Abschnitt 2 der Vorgabe: Bestandsaufnahme + Lückenliste,
  alles oben durch Code-Lesen verifiziert, nichts geraten).
- Der in 5.4 beschriebene Vorschau/Instanziierung-Divergenz-Bug: isoliert
  behoben, da klein, risikoarm und unabhängig vom großen Equipment-Umbau.
  Neue, einzige Quelle `ProgramTemplate.resolvedDays(forUserEquipment:)`
  (`ProgramTemplate.swift`), von `ProgramInstantiator.instantiate` UND
  `TemplatePreviewView.orderedDays` aufgerufen (letztere bekommt dafür
  einen neuen `userEquipment`-Parameter, an beiden Aufrufstellen —
  `ProgramTemplatePickerView` und `OnboardingView`s eigenem Vorschau-Sheet —
  mit exakt derselben Equipment-Quelle befüllt, die auch beim Adopt
  verwendet wird). 4 neue Core-Tests (`PlanMatchmakerTests.swift`,
  Abschnitt "resolvedDays"). **Nicht Xcode/Gerät-verifiziert** — die
  geänderten Dateien liegen unter `#if canImport(SwiftUI)` und werden vom
  Linux-Build nur auf Klammer-Balance, nicht auf echte Typkorrektheit
  geprüft; stattdessen manuelle Zeile-für-Zeile-Prüfung aller 4
  Änderungsstellen durchgeführt (siehe Commit).

**Bewusst NICHT in diesem Durchlauf umgesetzt** (Abschnitte 3-5 der
Vorgabe, Tasks #84-#88 im Projekt-Tracking):
- Equipment-Datenmodell-Umbau (Tri-State, AND/OR/Anzahl/Last-Struktur).
- Überarbeitetes Onboarding-Mehrfachauswahl-UI (feinere Equipment-Fälle).
- Persistenz-Migration + Backfill + CSV-Spalten-Erweiterung.
- Ersatzübungs-Mechanismus (PlanAdapter) inkl. Re-Verifikation.
- Die Trennung Wochenziel/verfügbare Tage (Abschnitt 2) — das ist eine
  Produktentscheidung (neue Frage vs. Neuinterpretation), kein reiner
  Code-Fix, und sollte vor der Umsetzung bewusst entschieden werden.
- Der in 5.2 gefundene Bug (Prefill-Reste nach Standortwechsel nach unten)
  bleibt bestehen, bis der Equipment-Umbau ihn strukturell mitlöst.

Dieser Scope-Schnitt wird im Abschlussbericht an den Nutzer offen
kommuniziert, nicht stillschweigend vorausgesetzt.
