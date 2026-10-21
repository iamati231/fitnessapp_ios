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

## 10. Phase 2 — Equipment-Datenmodell, Persistenz, Voraussetzungen-Prüfung

Umgesetzt (Tasks #84/#85, Commit siehe Git-Log):

- **Core** (`Sources/FitnessAppCore/Programs/EquipmentRequirement.swift`):
  `EquipmentItem` (10 Faelle: 4 Gewichte + 6 Zubehoer/Stationen, bewusst
  getrennt von `Equipment`), `EquipmentAvailability` (available/unavailable/
  unknown), `UserEquipmentProfile` (reine Sicht, kein SwiftData-Bezug),
  `ExerciseRequirement` (UND/ODER-Baum mit optionaler Mindest-Stueckzahl),
  `RequirementStatus`/`UnmetReason` fuer die dreistufige Pruefung mit
  konkreten Gruenden (Kleene/Łukasiewicz-Logik: ein definitiv unerfuelltes
  Kind schlaegt ein unbekanntes im UND; ein unbekanntes Kind haelt das ODER
  offen statt es als unerfuellt zu werten). 19 Core-Tests, auf Linux
  tatsaechlich ausgefuehrt und gruen.
- **Katalog-Anbindung**: `ExerciseTemplateSpec.equipmentRequirement: Exer
  ciseRequirement?` (neues optionales Feld, Default `nil`, bestehende 229
  Eintraege unveraendert). 8 Uebungen aus den Worked Examples der Vorgabe
  real annotiert und verifiziert (Kniebeuge: Langhantel UND Rack; Goblet
  Squat: Kettlebell ODER Kurzhantel; Schraegbankdruecken aufwaerts (KH) +
  Chest Supported Row (KH): 2 Kurzhanteln UND verstellbare Bank; alle 3
  Klimmzug-Varianten: Klimmzugstange — zeigt zugleich den Mehrwert ggueber
  `Equipment` alleine, da diese als `.bodyweight` klassifiziert sind, aber
  real eine Stange brauchen; Kettlebell Floor Press: nur Kettlebell, explizit
  keine Bank; Kettlebell Doppel-Push-Press: 2 Kettlebells). Die vollstaendige
  Erfassung aller 229 Eintraege ist NICHT Teil dieser Phase (Task #87, siehe
  Abschnitt 9).
- **Persistenz** (`UserBodyProfile.swift`): drei neue additive Felder
  (`equipmentAvailableItemsRaw`/`equipmentUnavailableItemsRaw`/
  `equipmentItemCountsRaw`, alle `[String]`, Default `[]`) + typisierter
  `equipmentProfile`-Accessor. Bewusst KEIN Backfill aus der alten
  `equipmentPreferencesRaw` (Begruendung: Abschnitt 5.1/5.2 — deren
  Eintraege koennen aus einer ungeprueften Environment-Vorbelegung stammen,
  eine Uebernahme waere falsche Sicherheit aus fraglichen Altdaten). Jedes
  Bestandsprofil liest nach dieser Aenderung fuer jedes `EquipmentItem`
  `.unknown` — keine aktive Migration noetig, weil nichts hergeleitet wird
  (die "idempotente Migration" ist hier per Konstruktion erfuellt, nicht
  durch eine eigene Backfill-Klasse wie bei `experienceTrackRaw`).
- **CSV Export/Import**: drei additive Spalten (`equipment_available_items`/
  `equipment_unavailable_items`/`equipment_item_counts`), gleiches
  `;`-Join-Verfahren wie `equipment_preferences`. Kein `headerSet`-Guard
  noetig (anders als `dashboard_widgets`/`hero_metric_slots`): fehlende
  Spalte und vorhandene-aber-leere Spalte fuehren hier auf denselben Wert
  ("alles unbekannt"), es gibt keinen abweichenden Konstruktor-Default zu
  schuetzen.
- **Reset**: keine Code-Aenderung noetig — `SettingsView.resetApp()` loescht
  bereits die gesamte `UserBodyProfile`-Zeile (`deleteAll(of:
  UserBodyProfile.self)`), die neuen Felder haengen am selben Modell und
  werden automatisch mitgeloescht. Durch Lesen verifiziert, kein eigener
  Test moeglich (`resetApp` ist SwiftUI-View-interne Logik, nicht pure-
  testbar).
- **Bestehende Trainingsplaene unveraendert**: durch Konstruktion erfuellt
  — nichts in dieser Phase beruehrt `TrainingPlan`/`TrainingDay`/`Exercise`
  oder deren Instanziierung/Matching. Kein eigener Regressionstest dafuer
  (waere ohne echten Beruehrungspunkt ein Test ohne Aussagekraft); die
  bestehende `DataPortabilityRoundtripTests`-Suite deckt eine versehentliche
  Beeinflussung des gemeinsamen Export/Import-Pfads indirekt mit ab.
- **Bewusst NICHT umgesetzt** (wie von der Anfrage selbst ausgeschlossen):
  Ersatzuebungs-Engine, grosser Onboarding-UI-Umbau, vollstaendige
  Katalog-Erfassung aller 229 Uebungen, exakte Plan-Verifikation (Abschnitt
  5 der Original-Vorgabe).

### Testabdeckung — tatsaechlich ausgefuehrt vs. nur geschrieben+geprueft

Dieses Projekt dokumentiert in seiner `README.md` bereits selbst, dass
`swift test` auf Linux NUR den Core- und Health-Teil ausfuehrt — der
komplette `FitnessAppDataTests`-Teil (laut README ca. 80 Tests, inklusive
aller bereits bestehenden SwiftData-Roundtrip-/Backfill-Tests) braucht
echtes SwiftData und laeuft nur auf macOS/Codemagic. Das ist keine neue
Einschraenkung dieser Phase, sondern durch `swift test list` empirisch
bestaetigt: **kein einziger** Test aus `FitnessAppDataTests` erscheint in
der Linux-Testliste, obwohl der komplette Code (inklusive der neuen
SwiftData-Tests dieser Phase) sauber kompiliert.

Konkret fuer diese Phase:
- **Tatsaechlich auf Linux ausgefuehrt und gruen**: alle 19 neuen
  `EquipmentRequirementTests` (Core, dreistufige UND/ODER-Pruefung) + die
  volle bestehende Core/Health-Suite (885 Tests insgesamt, 0 Fehler).
- **Geschrieben, kompiliert, manuell gegengelesen, aber NICHT lokal
  ausgefuehrt** (identische Einschraenkung wie bei JEDEM bestehenden
  `FitnessAppDataTests`-Test in diesem Projekt, nicht spezifisch fuer diese
  Aenderung): 5 neue `UserBodyProfileTests` (equipmentProfile Get/Set,
  Stale-Value-Robustheit, Disjunktheit der beiden Rohlisten) + 2 neue
  `DataPortabilityRoundtripTests` (Export/Import-Rundlauf, Bestandsprofil
  bleibt unbekannt). Diese laufen beim naechsten Codemagic-Build auf
  macOS automatisch mit.

## 11. Phase 3 — Equipment-Auswahl in Onboarding + Profil-Editor

Umgesetzt (Task #86):

- **Core-Erweiterung** (`EquipmentRequirement.swift`):
  `UserEquipmentProfile.confirmRemainingAsUnavailable()` (die "vollstaendige
  Bestaetigung" — alles noch `.unknown` wird explizit `.unavailable`,
  idempotent) und `.legacyEquipmentPreferences` (reine Projektion auf das
  alte `Equipment`-Set, zaehlt NUR `.available`-Eintraege, nie `.unknown`).
  9 neue Core-Tests, auf Linux ausgefuehrt und gruen.
- **Persistenz** (`UserBodyProfile.swift`): neues Feld
  `equipmentProfileConfirmedComplete: Bool` (Default `false`) + drei neue
  Methoden: `confirmEquipmentProfileComplete()` (Bestaetigung + einmaliger
  Legacy-Sync), `confirmBodyweightOnly()` (verwirft eine Teil-Auswahl,
  bestaetigt alles als nicht verfuegbar), `setEquipmentAvailability(_:for:
  count:)` (Einzel-Item-Aenderung, synct die alte `equipmentPreferences`
  nur wenn bereits bestaetigt). **Zentrale Korrektheits-Eigenschaft,
  getestet**: vor der ersten Bestaetigung bleibt `equipmentPreferences`
  (DEL-170, von `PlanMatchmaker`s Equipment-Hartfilter konsumiert) komplett
  unberuehrt — sonst haette eine unvollstaendige Zwischenauswahl den
  bestehenden Matcher-Filter verfrueht scharf geschaltet (Abschnitt 9's
  Leitlinie "kein pauschales Equipment-passend aus unvollstaendigen
  Angaben" wörtlich am Code durchgesetzt). CSV um eine vierte additive
  Spalte erweitert. 7 neue Tests (Data-Layer): geschrieben, kompiliert,
  nicht lokal ausgefuehrt (siehe Abschnitt 10 — gilt fuer jeden
  `FitnessAppDataTests`-Test in diesem Projekt).
- **Geteilte UI-Komponente** (`Components/EquipmentProfileEditor.swift`,
  neu): EINZIGE Implementierung der Mehrfachauswahl — Gewichte-Sektion (4
  Items) + Zubehoer-Sektion (6 Items), je Item ein Toggle, Stueckzahl-Chips
  (1 / 2+, kein Default) fuer Kurzhantel/Kettlebell, "Nur Koerpergewicht"
  als eigene Aktion (verwirft Teil-Auswahl, markiert alles nicht
  verfuegbar). Die "vollstaendige Bestaetigung" selbst ist bewusst NICHT
  Teil der Komponente — das entscheidet der Einbettungs-Kontext (Wizard-
  "Weiter" vs. Sheet-"Fertig"), damit Navigation und Dateneingabe getrennt
  bleiben.
- **Onboarding** (`OnboardingView.swift`): Equipment-Schritt nutzt die
  geteilte Komponente, KEIN Environment-Prefill mehr (die alten
  `defaultEquipment(for:)`/`prefillEquipmentIfNeeded`-Funktionen sind
  vollstaendig entfernt, nicht nur deaktiviert). Neuer "Später
  einrichten"-Link umgeht die Bestaetigung bewusst (alles bleibt
  `.unknown`); der normale "Weiter"-Pfad bestaetigt. Eine neue
  `derivedLegacyEquipment`-Berechnung liefert `[]`, bis bestaetigt wurde —
  speist `QuizAnswers`, `BaselineCheckFlowView`, `TemplatePreviewView` und
  `ProgramInstantiator.instantiate` konsistent. Der `.noEquipment`-
  Umgebungs-Skip (DEL-207) wurde in dieser Phase noch bewusst unangetastet
  gelassen — mittlerweile entfernt, siehe Abschnitt 12.
- **Profil-Editor** (`ProfileEditorView.swift`): die alte Checkbox-Liste
  ist durch eine `DeltiqRow` mit Status-Text (Nicht eingerichtet / Teilweise
  erfasst / Nur Koerpergewicht / Bestaetigt) ersetzt, die ein Sheet mit der
  gleichen geteilten Komponente oeffnet (Vorbild: der bestehende
  Baseline-Check-Re-Entry-Punkt). Toolbar "Fertig" bestaetigt, "Schliessen"
  verlaesst ohne zu bestaetigen (= "spaeter", Angaben bleiben wie sie
  sind). Ein eigener Binding-Wrapper haelt die alte `equipmentPreferences`
  live im Sync, sobald einmal bestaetigt wurde.
- **Bestehende Trainingsplaene unveraendert**: durch Konstruktion erfuellt
  — nichts in dieser Phase beruehrt `TrainingPlan`/`TrainingDay`/
  `ProgramInstantiator`s Instanziierungslogik selbst, nur WELCHE
  Equipment-Menge als Eingabe an die bestehende, unveraenderte Logik
  uebergeben wird.
- **Lokalisierung**: 24 neue Keys (DE/EN/TR, echte Uebersetzungen, kein
  TR=EN-Platzhalter) + 3 inhaltlich ueberarbeitete Bestandskeys
  (`onboarding.equipment.subtitle`/`.footer`, `profile.equipment.footer`).
  `TRANSLATIONS.md` regeneriert (1973 → 1997 Keys, 0 hartkodierte Strings).

### Bewusst nicht umgesetzt / unveraendert gelassen

- Keine Aenderung an `PlanMatchmaker`/`ProgramInstantiator`/
  `EquipmentVariant`/`BaselineCheckFlowView`s eigener `hasPullUpBar`-Frage
  — alle konsumieren weiterhin ausschliesslich die alte, jetzt automatisch
  synchronisierte `equipmentPreferences`. Die Umstellung dieser Konsumenten
  auf das reichere `UserEquipmentProfile`/die dreistufige Pruefung ist
  Gegenstand der noch ausstehenden Taskliste (u.a. #87-89).
- Kein UI-Test (kein Test-Target im Repo), kein echter Xcode/Geraete-Lauf
  — nur Linux-Build (Klammer-Balance, keine echte Typpruefung fuer
  SwiftUI-Dateien) + sorgfaeltige manuelle Zeile-fuer-Zeile-Pruefung,
  zusaetzlich gegen mehrere bereits bestehende, nachweislich funktionierende
  Code-Stellen in genau dieser Codebase abgeglichen (u.a. identisches
  Ternary-in-Text/-foregroundStyle-Muster, identisches
  DeltiqSection+.sheet-Muster).

## 12. Vor Phase 4 — vier Praezisierungen (Tasks #92-95)

Vor dem eigentlichen Phase-4-Auftrag explizit angefordert, weil Phase 3 nur
die Eingabe gebaut hat — die tatsaechliche Planpruefung liest bis Phase 4
weiterhin die alte, grobe `equipmentPreferences`-Spalte.

### 12.1 `.noEquipment`-Skip entfernt (Task #92)

**Befund**: `OnboardingView.visibleSteps`/`goToNextStep()`/`goToPreviousStep()`
haben den kompletten Equipment-Schritt uebersprungen, sobald
`environment == .noEquipment` (DEL-207, urspruenglich fuer die ALTE,
binaere Equipment-Auswahl gedacht). Dadurch konnte diese Nutzergruppe den
in Phase 3 gebauten "Nur Koerpergewicht bestaetigen"-Button nie erreichen
— `equipmentProfileConfirmedComplete` blieb permanent `false`,
`derivedLegacyEquipment` damit permanent `[]` ("unbekannt"), obwohl die
Umgebungswahl inhaltlich genau das nahelegt.

**Fix**: Skip-Logik komplett entfernt (`visibleSteps` faellt weg, der
Equipment-Schritt ist jetzt fuer jede Umgebung Teil des Wizards).
Bewusst KEIN Ersatz durch eine automatische "No-Equipment -> bestaetigt
Koerpergewicht"-Herleitung — das waere wieder "Ort ist nicht Ausstattung"
(Abschnitt 5.1) nur mit anderem Vorzeichen. Der Nutzer sieht stattdessen
denselben Schritt wie jede andere Umgebung und bestaetigt explizit (Ein
Tap auf den bereits vorhandenen "Nur Koerpergewicht"-Button, falls
zutreffend) oder waehlt abweichend echtes Equipment (z.B. eine
Klimmzugstange zuhause trotz "Kein Equipment"-Wahl).

### 12.2 "Bestaetigt leer" vs. "unbekannt" im Matcher (Task #93)

**Frage**: Behandelt `PlanMatchmaker.equipmentMatches` ein bestaetigtes
"Nur Koerpergewicht" (`{.bodyweight}`) und ein nie gepflegtes Profil (`[]`)
beide als "kein Filter"?

**Empirisch verifiziert (nicht nur aus dem Gedaechtnis): Nein.**
`equipmentMatches` steigt nur bei `user.isEmpty` fruehzeitig mit `true`
aus. `UserEquipmentProfile.legacyEquipmentPreferences` liefert nach einer
Bestaetigung IMMER mindestens `{.bodyweight}` (nie `[]`) — und
`.bodyweight` ist nachweislich nie Teil eines `requiredEquipment`-
Ergebnisses, weder in `PlanMatchmaker.requiredEquipment(for:)` noch in
`EquipmentProfile.requiredEquipment` (alle vier Faelle: Langhantel+
Kurzhantel / Kurzhantel / Kettlebell / Maschine+Kabel). Ein bestaetigter
Nur-Koerpergewicht-Nutzer besteht deshalb korrekt keinen Equipment-Check,
der echtes Geraet braucht — in beiden Pruefpfaden (hergeleitet UND
`equipmentVariants`).

Jetzt robust dokumentiert (Doc-Kommentar direkt an `equipmentMatches`,
nicht nur in diesem Audit) UND durch einen dedizierten Test abgesichert,
der genau diese beiden Zustaende nebeneinander prueft:
`PlanMatchmakerTests.testEmptyEquipmentIsNoFilterButConfirmedBodyweightOnlyActuallyFilters`.

### 12.3 Stueckzahl-unbekannt-Invariante (Task #94)

**Frage**: Kann ein ausgewaehltes Geraet ohne erfasste Stueckzahl beim
Bestaetigen faelschlich zu "nicht vorhanden" kippen, oder faelschlich als
"ausreichend" fuer eine Zwei-Geraete-Uebung gelten?

**Verifiziert durch neuen End-to-End-Test** (vorher nur getrennt, nie in
Kombination getestet):
`EquipmentRequirementTests.testSelectedItemWithUnrecordedCountSurvivesConfirmationAndStaysUnknownAgainstDoubleRequirement`.
`confirmRemainingAsUnavailable()` aendert ausschliesslich Items, die noch
`.unknown` sind — ein bereits `.available` markiertes Item (mit oder ohne
Stueckzahl) bleibt unangetastet. `ExerciseRequirement.evaluate` liefert
fuer "verfuegbar, Stueckzahl nie erfasst, `minimumCount > 1`" weiterhin
`.unknown`, nie `.satisfied`. Kein Fix noetig, nur die fehlende
Kombinations-Absicherung ergaenzt.

### 12.4 CI-Status der gepushten Commits (Task #95)

**Ehrlicher Befund, keine Vermutung**: dieses Repository hat **keine**
GitHub-Actions-Workflows (`list_workflows`/`list_workflow_runs` liefern
beide `total_count: 0`), und `get_commit` liefert fuer keinen der
gepushten Commits (`f55f02f`, `d0ec07a`, `6c6b671`, `bb6133d`, `84637e7`)
ein `status`/`check_runs`-Feld. Aus dieser Session heraus ist der
tatsaechliche Lauf-Status des `swift-package`-Workflows aus
`codemagic.yaml` (triggert laut Konfiguration auf `push`/`pull_request`
fuer jeden Branch, `instance_type: mac_mini_m2`, fuehrt `swift build` +
`swift test --parallel` + iOS-Simulator-Library-Build fuer alle 5 Targets
aus — inklusive `FitnessAppUI`, wo diese Phase ausschliesslich gearbeitet
hat) **nicht pruefbar**. Ob Codemagic tatsaechlich automatisch angelaufen
ist und mit welchem Ergebnis, kann nur im Codemagic-Dashboard selbst
eingesehen werden — das liegt ausserhalb dessen, was ueber die in dieser
Session verfuegbaren GitHub-Tools sichtbar ist.

## 13. Phase 4 — Vollstaendige Equipment-Pruefung fuer Katalog + Planvarianten

Setzt den 9-Punkte-Auftrag um, der ausdruecklich erst nach den vier
Abschnitt-12-Praezisierungen beginnen sollte. Kein Backfill, keine Aenderung
an bestehenden `TrainingPlan`/`TrainingDay`/`Exercise`-Zeilen — nur WELCHE
Variante als Eingabe fuer Vorschau/Instanziierung dient, aendert sich.

### 13.1 Katalog-Annotation (Punkte 1-2)

**Reihenfolge wie gefordert**: zuerst alle 102 Uebungen annotiert, die
tatsaechlich in einem ausgelieferten Template ODER einer seiner
`equipmentVariants` vorkommen (empirisch ermittelt per Scratch-Test, nicht
geschaetzt), danach die restlichen 127 Katalog-Eintraege.

| | Annotiert | Gesamt | Deckung |
|---|---|---|---|
| Ausgelieferte Templates + Varianten | 102 | 102 | 100 % |
| Restliche Bibliothek | 110 | 127 | 87 % |
| **Gesamt** | **212** | **229** | **92,6 %** |

**Fehlende Annotation ist niemals automatisch "keine Anforderung"**: durchgesetzt
in `PlanEquipmentChecker.check` — eine Uebung ohne `equipmentRequirement`
(oder ganz ohne Katalog-Treffer) zaehlt als `PlanEquipmentGapReason.notAnnotated`
und macht die GESAMTE Planvariante `.unknown`, nie `.available` (siehe
`PlanEquipmentCheckTests.testNotYetAnnotatedExerciseMakesDayUnknownNeverAvailable`/
`testUnknownExerciseNameIsTreatedLikeNotAnnotatedNeverAvailable`).

**17 offene Eintraege** (Abdeckungsreport mit konkreten Namen, wie gefordert),
in zwei Kategorien:

*Unklar — Uebung/Geraet-Zuordnung bleibt auch mit dem bestehenden
`EquipmentItem`-Vokabular zweifelhaft, bewusst nicht geraten:*
- Nordic Curls (Knoechel-Fixierung — Partner/Geraet unklar)
- Australian Pull-ups, Inverted Row (niedrige Stange/Schlinge — nicht dieselbe
  Sache wie `.pullUpBar`)
- Back Widows (Bewegung nicht sicher identifiziert)
- Beincurl stehend (BW) (vermutlich Slider/Band, nicht eindeutig)

*Noch nicht erfasst — das benoetigte Geraet existiert als `EquipmentItem`-Fall
schlicht noch nicht (Plyo-Box, Dip-Station, Sandsack, Schlingen, Landmine,
Trap-Bar, Sled):*
- Box Jump, Box Squat (zusaetzlich zur bereits erfassten Langhantel+Rack-Anforderung)
- Dips (Brust), Dips (Trizeps)
- Battle Ropes, Medizinball-Slam, Sandbag Carry
- Sled Push, Sled Pull
- Meadows Row, T-Bar Rudern (Landmine)
- Trap-Bar-Kreuzheben

Beide Kategorien liefern ueber `PlanEquipmentChecker` korrekt `.unknown`
(nie `.available`, nie `.unavailable`) — das System behauptet an keiner
Stelle, diese 17 Uebungen seien geprueft.

**Modellierungs-Entscheidung waehrend der Annotation**: eine Flachbank-
Anforderung akzeptiert `.any([.item(.flatBench), .item(.adjustableBench)])`
statt nur `.item(.flatBench)` — eine verstellbare Bank kann flach genutzt
werden, deckt also eine Flachbank-Anforderung mit ab. Umgekehrt gilt das
NICHT: eine reine Flachbank kann nicht inclinen/declinen, eine Schraegbank-
Uebung verlangt deshalb weiterhin ausschliesslich `.adjustableBench` (siehe
Doc-Kommentar an `EquipmentItem.flatBench`, `PlanEquipmentCheckTests.
testFlatBenchSatisfiesFlatExerciseButNotInclineExercise`/
`testAdjustableBenchSatisfiesBothFlatAndInclineExercises`).

**Beim Testen entdeckte, bestehende (Phase-2-) Einschraenkung, nicht Teil
dieser Phase**: `ExerciseRequirement.evaluate`s `.all(...)`-Fall liefert beim
ERSTEN definitiv unerfuellten Kind sofort dessen Grund zurueck (kurzschliesst),
sammelt also nicht ALLE fehlenden Teile einer Mehrfach-Anforderung ein (siehe
bereits bestehender `EquipmentRequirementTests.
testAllIsDefinitelyUnmetWhenOneChildDefinitelyUnmetEvenIfAnotherIsUnknown`).
Praktisch: "Kniebeuge" (Langhantel UND Rack) zeigt bei beidem fehlend nur
"Langhantel fehlt", nicht zusaetzlich "Rack fehlt". Nie falsch (die Uebung
gilt korrekt als nicht erfuellt), nur nicht maximal erschoepfend — kein
Phase-4-Blocker, aber dokumentiert fuer eine spaetere UI-Verfeinerung.

### 13.2 Planvarianten-Pruefung (Punkt 3) — neue Core-Typen

`Sources/FitnessAppCore/Programs/PlanEquipmentCheck.swift` (neu):

- `PlanEquipmentStatus` (available / unavailable(gaps:) / unknown(gaps:)) +
  `PlanEquipmentGap`/`PlanEquipmentGapReason` (notAnnotated / missing / uncertain)
  — die "vorhanden, fehlt oder unbekannt, jeweils mit konkreten Gruenden"-Vorgabe.
- `PlanEquipmentChecker.check(days:against:)` — prueft JEDE Uebung einer
  Tage-Liste einzeln ueber das bestehende `ExerciseRequirement.evaluate`
  (Phase 2) und aggregiert: ein definitiv fehlendes Item irgendwo gewinnt,
  sonst macht ein unbekanntes/nicht-annotiertes Item die ganze Variante
  `.unknown`, nur wenn ALLES erfuellt ist wird `.available` geliefert.
- `CheckedPlanVariant` + `ProgramTemplate.equipmentCheckedVariants(against:)`
  (alle Varianten inkl. Basis, je mit Status) und
  `.bestEquipmentCheckedVariant(against:)` (EINE Auswahl: zuerst eine
  `.available`-Variante nach `EquipmentProfile.priority`, sonst die
  bestplatzierte `.unknown`, sonst transparent die Basis MIT ihrem
  `.unavailable`-Status — keine stillschweigende Ersatz-Variante).

### 13.3 Matcher + Begruendungen (Punkt 4-5)

`QuizAnswers` traegt jetzt `equipmentProfile: UserEquipmentProfile?` (Default
`nil` = reiner Legacy-Pfad, unveraendertes alt-Verhalten fuer jeden
bestehenden Aufrufer/Test). Ist es gesetzt:

- `PlanMatchmaker`s Equipment-Hartfilter (`equipmentMatches`) entscheidet
  AUSSCHLIESSLICH ueber `bestEquipmentCheckedVariant` — die grobe
  `equipmentPreferences`-Projektion wird fuer diese Entscheidung ignoriert.
  Nur `.unavailable` schliesst aus, `.unknown` laesst durch (Punkt 1 erneut
  durchgesetzt, diesmal auf Plan-Ebene).
- `matchReasons(for:answers:)` liefert `equipmentStatus: PlanEquipmentStatus?`
  zusaetzlich zum (jetzt praeziseren) `equipmentMatch: Bool`. `equipmentMatch`
  ist `true` ausschliesslich bei `.available` — ein unbestaetigtes/unklares
  Template zeigt nie das "Equipment passend"-Badge.
- `OnboardingView.planMatchAnswers` gibt das LEBENDE `equipmentProfile`
  immer mit, auch vor vollstaendiger Bestaetigung — eine unvollstaendige
  Erfassung liefert dadurch korrekt `.unknown` statt eines verfruehten
  Ausschlusses ODER eines stillschweigenden "passt schon" (die alte
  `derivedLegacyEquipment`-Gate-Logik bleibt nur fuer die Legacy-Spalte und
  `BaselineCheckFlowView` bestehen).

Auftrags-Vorgabe erfuellt: "legacyEquipmentPreferences bleibt nur
Kompatibilitaetsprojektion, darf eine bestaetigte Unvereinbarkeit nicht
uebersteuern" — belegt durch
`PlanEquipmentCheckTests.testDumbbellWithoutBenchDoesNotSelectDumbbellVariantForHybridBalanced`
(Kurzhanteln vorhanden wuerde die alte Set-Pruefung durchlassen, die neue
Pro-Uebung-Pruefung blockt wegen der fehlenden Bank korrekt).

### 13.4 Vorschau + Instanziierung + Fallback (Punkt 6-7)

- `TemplatePreviewView` nutzt `userEquipmentProfile: UserEquipmentProfile`
  statt der alten groben Menge; `checkedVariant`/`orderedDays` laufen beide
  ueber `bestEquipmentCheckedVariant`. Neue `equipmentStatusBanner` zeigt den
  Status TRANSPARENT: gruen "Equipment passend bestaetigt", orange "noch
  nicht vollstaendig bestaetigt" (mit den konkreten unklaren Geraeten UND,
  getrennt davon, einem Hinweis auf noch nicht annotierte Uebungen), rot
  "passt nicht" mit den konkret fehlenden Geraeten.
- `ProgramInstantiator.instantiate` bekommt einen neuen
  `userEquipmentProfile: UserEquipmentProfile?`-Parameter; gesetzt, resolved
  er ueber DIESELBE `bestEquipmentCheckedVariant`-Funktion wie die Vorschau
  (Punkt 6 woertlich: "dieselbe geprueften Variante"). `nil` (der
  synthetische Template-Pfad aus `PlanGeneratorInstantiator`, der nie
  `equipmentVariants` hat) faellt unveraendert auf die alte
  `resolvedDays(forUserEquipment:)` zurueck.
- `PlanMatchmaker.fallback(...)` respektiert jetzt Equipment als vorletzte
  Lockerungsstufe (nach Tagen/Track, vor dem absoluten Notfall ohne jeden
  Filter) — vorher pruefte der Fallback-Pfad GAR KEIN Equipment. Konkret und
  getestet: `crossfit_bodyweight_rx` ist `.noEquipment`-getaggt, braucht aber
  tatsaechlich eine Klimmzugstange ("Klimmzüge") — ein Nutzer mit bestaetigt
  fehlender Stange bekommt ihn auch im Fallback nicht mehr vorgeschlagen,
  waehrend das klimmzugstangen-freie Geschwister-Template
  `crossfit_bodyweight_scaled` ein gueltiger Kandidat bleibt
  (`testFallbackRespectsConfirmedMissingPullUpBarEvenForNoEquipmentTemplates`/
  `testFallbackAllowsPullUpBarTemplateWhenConfirmedAvailable`).

### 13.5 Punkt 8 (keine Ersatzuebungs-Engine) + Punkt 9 (bestehende Plaene unveraendert)

Keine Ersatzuebungs-Logik existiert — wo keine Variante passt, liefert
`bestEquipmentCheckedVariant` transparent die Basis-Variante MIT ihrem
`.unavailable`-Status zurueck (siehe
`testBodyweightOnlySelectsNoVariantAsAvailableForHybridBalanced`,
`testInstantiateWithBodyweightOnlyProfileStillMaterializesTheTransparentBaseVariant`)
statt irgendeine andere Uebung/Template unterzuschieben. Bestehende
Nutzerplaene: durch Konstruktion unveraendert — kein Code in dieser Phase
beruehrt `TrainingPlan`/`TrainingDay`/`Exercise` selbst oder irgendeine
Migrations-/Backfill-Logik, nur WELCHE `[DaySpec]` als Eingabe fuer einen
NEU zu instanziierenden Plan gewaehlt wird.

### 13.6 Regressionstests (Punkt 9 der Testvorgabe)

Alle sechs explizit geforderten Szenarien, je mit Auswahl + Begruendung
(und, wo ueber SwiftData moeglich, der tatsaechlich instanziierten Variante):

| Szenario | Core-Test (Linux-ausgefuehrt) | Data-Layer-Test (kompiliert, Apple-Lauf ausstehend) |
|---|---|---|
| Nur Koerpergewicht | `testBodyweightOnlyProfileRejectsBarbellExercise`, `testBodyweightOnlySelectsNoVariantAsAvailableForHybridBalanced`, `testBodyweightOnlyExcludesHybridBalancedFromMatcherResults` | `testInstantiateWithBodyweightOnlyProfileStillMaterializesTheTransparentBaseVariant` |
| Nur Kettlebells | `testKettlebellOnlyProfileSatisfiesSingleKettlebellExercises`, `testKettlebellOnlySelectsKettlebellVariantAsAvailableForHybridBalanced` | `testInstantiateWithKettlebellOnlyProfileUsesTheSameVariantAsBestEquipmentCheckedVariant` |
| KH ohne Bank | `testDumbbellWithoutAnyBenchRejectsBenchDependentExercise`, `testDumbbellWithoutConfirmedBenchIsUnknownNotUnavailable`, `testDumbbellWithoutBenchDoesNotSelectDumbbellVariantForHybridBalanced` | — (ueber denselben Core-Pfad abgedeckt, kein separater Data-Test noetig) |
| KH Flachbank vs. Schraegbank | `testFlatBenchSatisfiesFlatExerciseButNotInclineExercise`, `testAdjustableBenchSatisfiesBothFlatAndInclineExercises` | — |
| Klimmzugstange vorhanden/fehlend | `testPullUpBarAvailableSatisfiesPullupExercise`, `testPullUpBarConfirmedMissingRejectsPullupExercise`, `testPullUpBarUnknownIsUnknownNotAvailable`, `testFallbackRespectsConfirmedMissingPullUpBarEvenForNoEquipmentTemplates`, `testFallbackAllowsPullUpBarTemplateWhenConfirmedAvailable` | — |
| Unbekannte Stueckzahl | `testKettlebellAvailableWithoutCountIsUnknownForDoubleKettlebellExercise`, `testKettlebellAvailableWithConfirmedCountOfTwoSatisfiesDoubleKettlebellExercise`, `testKettlebellAvailableWithConfirmedCountOfOneRejectsDoubleKettlebellExercise` | — |

Zusaetzlich: `testInstantiateWithoutProfileFallsBackToLegacyResolvedDays`
(Legacy-Pfad unveraendert) und
`testBestEquipmentCheckedVariantIsDeterministicAcrossRepeatedCalls` (Schutz
gegen die Phase-1-Vorschau/Instanziierung-Divergenz in neuer Form).

### 13.7 Tatsaechlich ausgefuehrte Tests vs. offen

**Ausgefuehrt und gruen, auf Linux, diese Session**: 919 Core-/Health-/UI-Tests
(vorher 896 — 21 neue `PlanEquipmentCheckTests` + 2 neue
`PlanMatchmakerTests`-Faelle), inklusive `swift build` fuer alle 5 Targets.

**Geschrieben, kompiliert, NICHT lokal ausgefuehrt** (gilt wie bei jeder
bisherigen Phase fuer `FitnessAppDataTests` — SwiftData, laut README nur auf
macOS lauffaehig, `swift test list` zeigt auf diesem Linux-Sandbox
weiterhin `0` Data-Tests): die 3 neuen Tests in
`ProgramInstantiatorEquipmentTests.swift`.

**Weiterhin offen, ausdruecklich nicht aus dieser Session heraus pruefbar**
(siehe Abschnitt 12.4 — unveraendert): ob Codemagic die gepushten Commits
dieser Phase tatsaechlich gebaut/getestet hat, inklusive eines echten
Xcode/iOS-Builds von `TemplatePreviewView`s neuer `equipmentStatusBanner`.
Nur im Codemagic-Dashboard selbst einsehbar.

**Bewusst nicht Teil dieser Phase**: ein UI-Fluss, der gezielt nach genau den
unklaren Geraeten EINES konkreten Plans zurueckfragt (die Vorschau zeigt sie
nur an, verlinkt noch nicht direkt in den Profil-Editor) — das waere ein
eigener kleiner UX-Schritt, kein Korrektheitsproblem. Die 17 offenen
Katalog-Eintraege aus 13.1 bleiben ebenfalls offen, bis entweder die
Modellierungsfrage geklaert (z.B. ein dediziertes "Low Bar"-Item) oder das
noetige `EquipmentItem` ergaenzt wird (Plyo-Box, Dip-Station, Sandsack,
Schlingen, Landmine, Trap-Bar, Sled).
