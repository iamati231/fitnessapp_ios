# Smart-Coach-Audit: Bestandsaufnahme vor dem Onboarding-Epic

Reine Bestandsaufnahme (Aufgabe 1 aus `SMART_ONBOARDING_EPIC.md`) — keine Codeänderung in diesem Dokument-Commit. Ziel: was existiert bereits, wo weicht es vom Epic-Konzept ab, was muss vor Phase 2 entschieden werden.

Branch: `claude/smart-onboarding-epic` (von `claude/neue-views-entwicklung-ahsg90`).

## 1. Aktuelle Onboarding-Schritte

Es gibt **zwei unabhängige Assistenten**, nicht einen:

### 1.1 `OnboardingView.swift` (1360 Zeilen) — Haupt-Onboarding, 5 Schritte

| # | Schritt | Fragt | UI | Pflicht/Default |
|---|---|---|---|---|
| 1 | `healthConnect` | Apple Health verbinden (zieht Alter, Geschlecht, Größe, Gewicht) | Connect-Buttons + ZIP-Backup-Import | Optional, immer überspringbar |
| 2 | `personalInfo` | Vorname, Geschlecht, Geburtsdatum, Größe, Gewicht, Zielgewicht, Trainingsort | TextField/Picker/DatePicker | Name+Zielgewicht optional; Größe+Gewicht **pflicht** (100–250 cm / 20–400 kg); Ort default `.gym` |
| 3 | `coachingStyle` (DEL-101) | Primäres Ziel (`TrainingGoal`), Coach-Ton (`CoachingTone`), Wochenziel | 2 Karten-Listen + Stepper 1–7 | Defaults `.hybrid`/`.analytical`/3, immer weiter |
| 4 | `equipmentPreferences` (DEL-170b) | Verfügbares Equipment | Mehrfachauswahl | Leer erlaubt = "Standard-Variante"; vorbelegt nach Ort |
| 5 | `preferencesAndPlan` | Reminder-Toggles, dann Plan-Wahl: Quiz / Template-Liste / „Plan bauen" | 2 Toggles + 3 Karten | Optional, auch ohne Plan-Wahl abschließbar |

Schritt „Equipment" wird übersprungen, wenn `environment == .noEquipment` — **in beiden Assistenten unabhängig voneinander implementiert** (Duplikat-Logik).

### 1.2 `OnboardingQuizView.swift` (479 Zeilen) — optionaler Plan-Finder, aus Schritt 5 heraus startbar

| # | Schritt | Fragt | Default |
|---|---|---|---|
| 1 | `goal` | Primäres Ziel (`GoalType`) | `.hypertrophy`, oder aus Schritt 3 übernommen |
| 2 | `experience` | Erfahrung (`ExperienceLevel`) | `.intermediate` |
| 3 | `days` | Tage/Woche | 3 |
| 4 | `environment` | Trainingsort | aus Schritt 2 übernommen |
| 5 | `equipment` | Equipment | leer |
| 6 | `result` | — | `PlanMatchmaker.rankPlans`-Ergebnis |

Keine echte „Weiß ich nicht"-Option irgendwo — jede Frage hat einen Chip/Karten-Default, das ist der De-facto-Skip. Nur Größe/Gewicht in Schritt 2 blockieren ohne Eingabe.

**Stale Selbstdokumentation gefunden:** Code-Kommentare in beiden Dateien behaupten „Fünf"/„Vier kompakte Fragen" und „19"/„14 Templates" — live sind es 5 Quiz-Fragen und **20** Templates. Sollte unabhängig vom Epic korrigiert werden.

## 2. Plan-Datenmodell

Drei parallele Wege, einen Plan zu bekommen:

1. **Kuratierte Templates**: `ProgramTemplates.swift` (1225 Zeilen) — **20** `ProgramTemplate`-Werte (nicht 19, siehe oben), Felder u. a. `targetEnvironment`, `targetExperience: [ExperienceLevel]`, `targetGoals: [GoalType]`, `daysPerWeek`, `days: [DaySpec]`, optional `equipmentVariants`. Nur 3 Templates (die Hybrid-Familie) haben `equipmentVariants`; das vorbereitete `EquipmentProfile.machineGym` hängt an keinem Template (totes Scaffold).
2. **`PlanMatchmaker.rankPlans(for:templates:)`**: reine Funktion. Harte Filter (Umgebungs-Hierarchie, `daysPerWeek <= preferredDays`, Equipment-Teilmenge falls Varianten existieren) + weiches Scoring (+3 Ziel-Treffer, +2 Erfahrungs-Treffer, +1 exakte Tage) + Fallback auf alle `noEquipment`-Templates, falls alles rausfällt.
3. **„Plan bauen" (PlanBauen.md)**: dritter, unabhängiger Generator-Pfad (`PlanBuilderView` → `PlanGeneratorInput` → `PlanGenerator.generate` → `PlanGeneratorInstantiator`), der einen synthetischen `ProgramTemplate` erzeugt und denselben `ProgramInstantiator` wie die Templates nutzt. Einzige Anpassung: „Neu rechnen" (Re-Run derselben gespeicherten Eingabe, überschreibt nur unveränderte Tage per Fingerprint).

**SwiftData-Persistenz** (`Sources/FitnessAppData/`, 11 `@Model`-Klassen, Single-Source-of-Truth `AppSchema.types`): `TrainingPlan` → `TrainingDay` → `Exercise` → `ExerciseLog`; daneben `WorkoutSession`, `ExerciseTemplate` (Katalog), `UserBodyProfile` (Singleton-Profil), `PersonalRecordEntry`, `BodyMeasurement`, `WaterEntry`, `Gear`.

**Wichtig für Phase 1/3:** `LibrarySeeder.backfillNewLibraryEntriesIfNeeded` diff't nur Namen und **fügt ausschließlich fehlende Zeilen ein** — es patcht keine Feldwerte auf bereits existierenden `ExerciseTemplate`-Zeilen. Neue `ExerciseMeta`-Felder (complexity, movementPattern, fatigueCost, …) landen also NICHT automatisch auf bereits geseedeten Übungen; es braucht einen eigenen, einmaligen Backfill nach dem Muster von `backfillCustomExerciseMetadataIfNeeded` (DEL-163).

**PlanBauen.md ist selbst veraltet** (eingebettete Swift-Kopie, diverged vom Live-Code um mehrere hundert Zeilen; zitierte README-Abschnitte „2.20"/„2.9" existieren nicht mehr). Für Phase 2/4 ist der **lebende** Code (`ProgramTemplates.swift`, `PlanMatchmaker.swift`, `ProgramInstantiator`) die relevante Grundlage, nicht dieses Dokument.

## 3. Vorhandene Progressionslogik

`ProgressionEvaluator.evaluate` (reine Funktion): Double Progression, RIR-gated. Alle Sätze am oberen Rep-Ende + RIR ≥ Schwelle (2 Compound / 1 Isolation, pro Plan überschreibbar) → Gewicht hoch um `Exercise.progressionStep` (manueller Double pro Übung, Default 2,5 kg — **nicht** equipmentabhängig, wie das Epic in §6.1 annimmt). Unterhalb des Rep-Bereichs bei RIR ≤ 0 → Deload.

- **e1RM**: nur als manueller Rechner + linearer Trend (`OneRMForecaster`), nicht Teil der Auto-Progression.
- **Plateau-Erkennung**: existiert **nicht**. `CoachingContext.plateauDetected` + 8 lokalisierte Strings liegen fertig, aber unverdrahtet da.
- **Deload nach Überlastung**: `DeloadManager`/`DeloadAdvisor` (3-Wochen-Lastanstieg ≥20 % + ≥2 harte Einheiten/14 Tage → Vorschlag, halbiert Gewichte, Auto-Restore nach 7 Tagen).
- **Reduktion nach Pause** (deckt Epic §6.1 „Nach Pause > 14 Tage" bereits ab, feiner als dort beschrieben): `ComebackAdvisor`/`AbsenceDeload`, Bucket-Tabelle 14–20 Tage → −5 %, 21–29 → −10 %, 30–59 → −15 %, 60–89 → −20 %, 90–179 → −25 %, ≥180 → Retest nötig; Isolation wird weniger reduziert als Compound. **Diese Tabelle ist die einzige im Code belegte Kalibrierung für Pausen-Rampen** und sollte als Referenz für die Rampen-Längen in §5.3 des Epics dienen statt neuer frei erfundener Werte.

## 4. Zielmodell

Es gibt **kein** dediziertes `Goal`/`Milestone`-Modell. Vorhanden, jeweils nur Teilausschnitt:

| Konzept | Ort | Umfang |
|---|---|---|
| `goalWeightKg` | `UserBodyProfile` | Ein Zielgewicht, nur Anzeige + Referenzlinie im Gewichtschart, kein Fortschritt-%/Zeitplan |
| `weeklyWorkoutGoal` | `UserBodyProfile` | Steuert nur den Streak-Zähler, keine Zielkarte |
| `CardioGoal`/`cardioRaceDate` | `UserBodyProfile`/`CardioProfile` | Ausdrücklich „rein deskriptiv, kein Coaching-Trigger" dokumentiert |
| `GoalType`/`ExperienceLevel` | `OnboardingTags.swift` | Nur Quiz-Tags fürs Template-Ranking, kein getracktes Nutzerziel |
| `WorkoutAchievementDetector` | Workout-Modul | Ephemere Feier-Badges, nicht persistiert, keine Nutzer-gesetzten Ziele |
| `Gear.progress` | `Gear.swift` | Einziges existierendes %-zum-Ziel-Muster im Code (Schuh-Kilometerstand) — brauchbares Vorbild für `GoalProgressEvaluator` |

Zielreps/-zeit für eine bestimmte Übung als Nutzerziel: nirgends vorhanden.

## 5. Coaching-Texte

- `CoachingTone` (`analytical`/`motivating`/`strict`) persistiert auf `UserBodyProfile`.
- `TrainingGoal` (`hypertrophy`/`strength`/`hybrid`/`weightLoss`, 4 Werte) — **zweite, persistierte** Zielachse, separat von `GoalType` (s. u., Abweichung 1).
- `CoachingContext`: ~20 fest kodierte Trigger-Fälle (restDay, cnsOverloaded, deloadRecommended, reEntry, …), priorisiert per `if/guard`-Ketten direkt im `DashboardView` ausgewertet — **kein datengetriebener Regel-Tisch**, wie das Epic ihn in §8 („CoachMessageEngine: Regeltabelle") will.
- `CoachingMessageProvider` löst `coaching.{context}.{tone}.{goal}` gegen `Localizable.xcstrings` auf, mit Tone→analytical/Goal→hybrid-Fallback.
- `RIRTooltip`: Erklärtext pro RIR-Wert, Popover beim Schieberegler-Drag, in Workout + Plan-Editor.
- Vorname-Personalisierung existiert (`UserBodyProfile.firstName`, Begrüßung im Dashboard).
- „Schwere Beine nach langem Lauf" (vom Epic als „bereits vorhanden" genannt) ist **kein** lauf-spezifischer Trigger — es ist der generische `highFatigueYesterday`-Trigger (≥20 Sätze ODER >90 Min, egal ob Kraft oder Cardio), dessen Text unter (motivating, hybrid) zufällig von „Beinen"/Laufen spricht.

## 6. Lokalisierung

Etabliertes Muster (aus den GIF-Integrationsrunden dieser Session direkt bekannt): `Localizable.xcstrings`, Schlüssel-Namespace `exercise.name.*` für Übungen (DE eigen, EN eigen, **TR = EN** verbindlich für Übungsnamen), `coaching.*` für Coach-Texte (dreifach pro Tonlage × Ziel). `TRANSLATIONS.md` wird generiert (`generate_translations_md.py`) und zeigt 0 hartcodierte Strings als Ziel-/Ist-Zustand. Für neue Epic-Texte (Onboarding-Fragen, Zielassistent, neue Coach-Trigger) gilt dieselbe Konvention — aber **nicht** automatisch TR=EN: die TR=EN-Regel wurde bisher nur für Übungsnamen explizit festgelegt, für UI-Fließtext/Coaching-Sätze müsste geklärt werden, ob sie genauso gilt oder ob dort echte türkische Übersetzungen erwartet werden.

## 7. Abweichungen vom Epic-Konzept (vor Phase 2 relevant)

1. **Zwei überlappende Ziel-Enums.** `GoalType` (Quiz, 5 Werte: hypertrophy/strength/fatloss/hybrid/functional, nie persistiert) und `TrainingGoal` (Coaching, 4 Werte: hypertrophy/strength/hybrid/weightLoss, persistiert) sind zwei verschiedene Typen, verbunden durch einen verlustbehafteten Einweg-Mapper (`mappedQuizGoal`) — `GoalType.functional` ist über die Brücke nie erreichbar. Das Epic will 6 Optionen (inkl. „Laufen", „Fitness/Gesundheit"), die zu keinem der beiden sauber passen. **Muss vor dem `OnboardingProfile`-Schema entschieden werden**, sonst entsteht ein drittes überlappendes Enum.
2. **Zwei Onboarding-Assistenten statt einem.** `OnboardingView` und `OnboardingQuizView` fragen teils dasselbe (Ziel, Umgebung) doppelt, mit eigener Skip-Logik je Datei. Das Epic beschreibt einen linearen 7-Fragen-Flow — ob die beiden verschmolzen werden oder der Quiz als optionaler Nachgang bestehen bleibt, ist eine Architekturentscheidung vor Phase 2.
3. **`QuizAnswers` ist komplett flüchtig.** `goal`/`experience`/`preferredDays` werden nirgends gespeichert (nur `environment`/`equipmentPreferences` landen indirekt über die Onboarding-`@State`-Werte auf `UserBodyProfile`). Ein `OnboardingProfile`-Modell ist für das Epic also nicht optional, sondern Voraussetzung — passenderweise wurde das in `OnboardingTags.swift` bereits per Kommentar vorbereitet (`RawRepresentable`/`Codable` „damit später ohne Schema-Migration persistiert werden kann").
4. **`ExperienceLevel` ≠ `ExperienceTrack`.** Es gibt bereits ein Erfahrungslevel (beginner/intermediate/advanced), aber selbst gewählt, nicht verhaltensbasiert hergeleitet. Das Epic will zusätzlich einen komplett neuen, verhaltens-/pausenbasierten `ExperienceTrack` (starter/returner/experienced). Das sind zwei verschiedene Achsen — sollten nicht verschmolzen werden, aber die Benennung muss klar getrennt bleiben, um nicht ein viertes "Level"-Konzept neben `DifficultyLevel` (Übungsschwierigkeit) zu schaffen.
5. **Templates: 20, nicht 19** — plus intern widersprüchliche Kommentare (19/14/20). Vor der Frage „welche Templates für Starter/Returner sperren" (Epic §14) sollte diese Zahl stimmen.
6. **Equipment-Inkremente existieren nicht.** `Exercise.progressionStep` ist aktuell ein manueller, übungsbezogener Wert, nicht aus `Equipment` abgeleitet — Epic §6.1 braucht hier echte neue Logik, keine Erweiterung.
7. **Rückfall-/Pausen-Reduktion ist schon eingebaut** (`ComebackAdvisor`, feiner gestuft als das Epic beschreibt) — sollte wiederverwendet/referenziert statt neu erfunden werden, auch als Beleg-Quelle für die Rampen-Konstanten.
8. **Dashboard-Untertraining-Heatmap hat eine bestehende Lücke:** löst Übung→Muskel nur über den statischen `ExerciseLibraryData`-Namens-Lookup auf, nicht über das persistierte (ggf. custom-überschriebene) `primaryMuscle`-Feld der geloggten `Exercise`. Nicht Epic-verursacht, aber angrenzend, falls Phase 3 an Muskel-Metadaten rührt.
9. **PlanBauen.md ist nicht die richtige Einstiegslektüre** für Phase 2/4 — es dokumentiert den dritten, separaten „Plan bauen"-Pfad und ist selbst veraltet. Die eigentlich relevante, lebende Architektur ist `ProgramTemplates.swift` + `PlanMatchmaker.swift` + `ProgramInstantiator`.
10. **Kein `VersionedSchema`/`SchemaMigrationPlan`** im Projekt — Migrationen laufen über Default-Werte (lightweight) + idempotente Backfill-Funktionen, unbedingt aus `RootView.task` aufgerufen. Neue Modelle müssen zusätzlich in `AppSchema.types`, `SettingsView.resetApp()`, Export/Import-CSV und ggf. `SettingsPortability.whitelist` eingetragen werden (sonst brechen Reset/Backup/Restore still).

## 8. Offene Rückfragen

Siehe separate Rückfrage an den Nutzer (Abschnitt 14 des Epics, plus zwei zusätzliche aus Punkt 1 und 2 oben) — wird nicht geraten, sondern vor Phase 2 gestellt.
