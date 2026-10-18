# P0-Audit: neue 5-Dokument-Spezifikation (00–04) gegen tatsächlichen Code-Stand

**Branch:** `claude/smart-onboarding-epic`, HEAD zum Zeitpunkt dieses Audits: `bbf9dd8`.
**Methode:** sieben parallele Teilaudits (reine Code-Lektüre + gezielte Testläufe, keine
Implementierung), synthetisiert zu diesem Dokument. Jede Aussage unten ist durch Datei:Zeile im
jeweiligen Teilaudit belegt; Details/Zitate liegen in den Agenten-Protokollen dieser Session, nicht
noch einmal dupliziert hier — dieses Dokument bündelt die Ergebnisse und leitet den Umsetzungsplan
ab.

Dieses Paket ersetzt laut `00_START_HIER.md` den früheren Einzelauftrag `PlanBauen.md` als
maßgeblichen Gesamtauftrag. Frühere Commits/Audits (`docs/PLANUNG_BEGLEITUNG_AUDIT.md`,
`docs/PLAN_CATALOG_AUDIT.md` u. a.) bleiben historischer Kontext, wurden aber wo nötig gegen den
aktuellen Code neu verifiziert statt blind übernommen — mehrfach stellte sich heraus, dass sie
mittlerweile veraltet sind (z. B. "cardioCoachingEnabled nirgends gesetzt" stimmt nicht mehr).

## Wichtigster Einzelbefund: Aktivierungsverhalten widersprüchlich zwischen zwei Insert-Pfaden

Das ist der einzige Punkt, den ich nicht einseitig auflöse, sondern als Entscheidung vorlege
(Doc00: "Bei echten fachlichen Widersprüchen nicht eigenmächtig eine Vorgabe verwerfen").

- `ProgramInstantiator.instantiate(...)` (`Sources/FitnessAppData/ProgramInstantiator.swift:84-86`)
  deaktiviert **ausnahmslos alle** bestehenden Pläne, bevor ein neuer aktiviert wird — ungefragt,
  bei jeder Planerstellung über Onboarding, Template-Picker und Builder. Der Code kommentiert das
  selbst als "unveraendertes Bestandsverhalten, keine neue Policy" und fordert für den künftigen
  Wocheneditor ausdrücklich eine Trennung "nur speichern" vs. "aktivieren" — "Diese Unterscheidung
  ist NICHT getroffen".
- Im soeben durchgeführten echten TestingBot-UI-Test (siehe `docs/PLANUNG_BEGLEITUNG_AUDIT.md`,
  Abschnitt zu Task #197) wurden nach mehreren Cardio-Übernahmen aber **zwei bis vier gleichzeitig
  als "ACTIVE" markierte Pläne** im Plan-Tab beobachtet. Der Cardio-Übernahme-Pfad läuft über
  `PlanGeneratorInstantiator.createPlan(...)`, nicht über `ProgramInstantiator.instantiate(...)` —
  die beiden Instanziierungspfade haben demnach unterschiedliche, nirgends dokumentierte
  Aktivierungsregeln.
- Doc01 §5 verlangt ausdrücklich: "Bestehenden aktiven Plan nicht ungefragt ersetzen" UND Doc01 §6
  verlangt für die Cardio-/Equipment-Anpassung ausdrücklich eine Entscheidung "aktiven Plan
  anpassen / als neuen Plan erstellen / bestehenden Plan beibehalten" — das deutet darauf hin,
  dass **mehrere gleichzeitig aktive Pläne grundsätzlich vorgesehen** sein könnten (z. B. ein
  Kraft-Plan + ein unabhängiger Cardio-Plan), während der Template-Picker-Pfad weiterhin "genau
  ein aktiver Plan" voraussetzt.

**Frage an den User, bevor P3/P5 das anfassen:** Ist "mehrere gleichzeitig aktive Pläne" ein
gewolltes Zielbild (z. B. Kraft- und Cardio-Plan parallel), oder soll es am Ende immer nur einen
aktiven Plan geben und der Cardio-Pfad hat hier einen eigenen, unbeabsichtigten Bug? Das
entscheidet, ob `ProgramInstantiator.instantiate` an den Cardio-Pfad angeglichen wird (ungefragtes
Deaktivieren entfernen) oder umgekehrt.

## Ist/Soll-Tabelle nach Themenbereich

### A) A+B-Builder & visueller Wocheneditor (Doc01 §2–5, §9)

| Punkt | Ist | Soll | Status | Umfang |
|---|---|---|---|---|
| Zielorientierter Einstieg (4 Zielkarten) | `PlanBuilderView` Schritt 1 fragt weiterhin Trainingsmittel (Barbell/Dumbbell/…​), kein Ziel-Schritt (`PlanBuilderView.swift:141-148,328-374`) | 4 Zielkarten als erster Schritt | fehlt | mittel — `PlanningContext`/`TrainingGoal.endurance` als Fundament bereits da, nur UI-Schritt + Entsperrung von `.endurance` nötig |
| Visueller Wocheneditor (Drag&Drop + "Verschieben nach…") | Nicht vorhanden; `resultStepView` zeigt nur statische Liste, kein Aufrufer von `PlanDraft.moveDay`/`reorder` außerhalb von Tests | Eigenständiger Editor mit beiden Bedienwegen | fehlt komplett | groß — Core-Logik (`PlanDraft`, stabile IDs, Fixierungs-Invarianten) ist fertig und getestet, nur UI fehlt |
| Inhalt/Position getrennt fixierbar | Datenmodell sauber getrennt (`PlanDraft.swift:58-69`, `setContentFixed`/`setPositionFixed`), aber keine UI setzt diese Flags | Getrennte Fixierung bedienbar | teilweise (Core ja, UI nein) | klein-mittel, sobald Wocheneditor existiert |
| 3 gezielte Alternativen statt "Neu rechnen" | Nur pauschales Shuffle (`PlanBuilderView.swift:836-855`); `replaceContent` (Alternative 1) existiert im Core, ist aber laut Code-Kommentar "NOCH NICHT umgesetzt, da heute keine UI einen Tagesinhalt tatsächlich ändert" | 3 unterscheidbare Alternativen | fehlt | groß gesamt, Alternative 1 am günstigsten (Baustein vorhanden) |
| Header-Konvention (Haken oben rechts, "Trainingsplan übernehmen") | `PlanBuilderView` nutzt kein `DeltiqHeader`; Übernehmen-Button sitzt unten, Label "Plan übernehmen", kein Dirty-Guard, `dismiss()` ohne Rückfrage bei "Abbrechen" | Haken oben rechts, korrektes Label, Verwerfen-Dialog | fehlt | klein-mittel — Zielmuster existiert bereits 1:1 in `PlanEditorView`/`DayEditorView`, nur übertragen |
| Kein früher Plan-Insert durch Vorschau | Bestätigt: `generatePreviewIfNeeded` erzeugt nur `PlanDraft`, kein `context.insert` vor explizitem "Plan übernehmen" | — | **erfüllt** | — |
| Mehrfach-Tap-Schutz beim Speichern | `isAdopting`-Flag UND strukturelle Garantie über `PlanCreationOperation.committedPlanID` (zweite Absicherung unabhängig vom UI-Zustand) | Keine Duplikate | **erfüllt** | — |

### B) Profil/Equipment-Anpassung, Warm-up/Cooldown, RIR (Doc01 §6–8)

| Punkt | Ist | Soll | Status | Umfang |
|---|---|---|---|---|
| Cardio-Ziel-Änderung → Plananpassung | Vollständig gebaut und **per echtem TestingBot-Simulator-Test verifiziert** (Task #197, bestanden) | — | **erfüllt** | — |
| Equipment-Änderung im Profil → Vorschau/Ersatz | `TrainingLocationEquipmentEditorView.save()`/`EquipmentProfileEditor` speichern nur still, keine Analyse/kein Ersatzvorschlag; `PlanEquipmentChecker`/`ExerciseSubstitutionEngine` werden von keiner der beiden Views referenziert | Vorschau mit "bisherige Übung, Alternative, Grund" | fehlt | mittel-groß — Engines existieren, nur die UI-Anbindungsschicht fehlt; Vorbild `envSwap`/`envRestore`-Dialog in `ProfileEditorView.swift:226-289` für Environment-Wechsel existiert bereits |
| Substitutions-Engines an Builder-generierte Pläne angebunden | Nein — im Code selbst als "offene Anschlussaufgabe, sobald P3 ein echtes Ziel liefert" dokumentiert (`PlanGeneratorInstantiator.swift:238-263`) | Equipment-Prüfung wirkt überall | fehlt (bewusst vertagt) | groß, abhängig von A) Zielorientiertem Einstieg |
| 3 Equipment-Zustände (vorhanden/nicht/unbekannt) | Sauber als Enum `EquipmentAvailability` modelliert, inkl. korrekter "nie angefasst" vs. "bewusst unbekannt"-Unterscheidung | — | **erfüllt** | — |
| Warm-up strukturell vorgesehen | `ExerciseRole.warmup` wird erzeugt und in `ActiveWorkoutView`/`ExerciseCard` angezeigt | — | **erfüllt** | — |
| Cooldown erreichbar | `ExerciseRole.cooldown` existiert im Enum + UI-Pill + Toggle-Filterung, wird aber **von keinem Generator/Template je erzeugt** — erklärt den Nutzerbefund "sieht Warm-up, nie Cooldown" vollständig | Optionaler Cooldown am Ende, in Vorschau+Training erreichbar | fehlt (kein Bug, nie befüllt) | mittel — Infrastruktur fertig, nur Erzeuger-Pfad fehlt |
| Rollen-Anzeige konsistent Vorschau/Training | Nur in `ActiveWorkoutView`/`ExerciseCard`, fehlt in `DayEditorView`/`PlanEditorView` | Konsistent in beiden | fehlt in Vorschau | klein-mittel |
| RIR-Spaltenlayout (Doc01 §8) | Vollständig umgesetzt: Header einmal oben, `minWidth`-Berechnung für längsten Wert, lokalisierte Halbwerte, Zwei-Zeilen-`ViewThatFits`-Fallback, stabile Reglerposition, eigene Plate-Calculator-Spalte, A11y-Labels | Genau das | **erfüllt (code-seitig)** | offen: reine Geräteverifikation bei extremer Dynamic-Type-Stufe, kein bekannter Fehler |
| Bank/Klimmzugstange "unbekannt" nach Neustart/Export/Import | Eigenes Feld `equipmentUnknownItemsRaw`, korrekt in CSV-Export/-Import geführt | — | **erfüllt** | — |

### C) Onboarding, Hybrid, Laufcoach-Trennung (Doc02)

| Punkt | Ist | Soll | Status | Umfang |
|---|---|---|---|---|
| Hybrid ohne stille Laufcoach-Kopplung | `cardioCoachingEnabled` kommt in `OnboardingView.swift` nirgends vor — keine stille Kopplung, aber auch keine der geforderten Folgefragen | Hybrid = reine Kombination, danach geführter Ablauf | teilweise (Nicht-Kopplung korrekt, aber nur weil Folgelogik komplett fehlt) | groß |
| Explizite Laufcoach-Frage (2 Optionen) | Nicht vorhanden; nur ein genereller Toggle in `ProfileEditorView`, bewusst nicht im Onboarding (Code-Kommentar: "Umfang bewusst auf Profil-Editor beschränkt") | Separate Frage im Onboarding | fehlt | groß |
| 5 Hybrid/Laufcoach-Zustände abbildbar | `PlanningContext`/`EnduranceModality`/`runCoachEnabled` bilden das im Core exakt ab, sind aber **totes Scaffold** — nirgends außerhalb der eigenen Tests instanziiert; `UserBodyProfile` hat kein persistiertes Ausdauerform-Feld | Alle 5 Zustände unterscheidbar | fehlt im lebenden Code | groß |
| Radfahren als Ausdauerform wählbar | `TrainingTypeKind.cycling` existiert und ist technisch auch im Onboarding erreichbar (über den eingebetteten `PlanBuilderView`), aber nur als 1 von 6 generischen, zielunabhängigen Kacheln, nicht als geführte Ausdauerform-Frage | Laufen/Radfahren/beides sichtbar | teilweise | mittel |
| Gemeinsamer Generatoradapter, kein Doppel-Code | Ja im Kern (`PlanGeneratorInstantiator.createPlan` für alle Pfade), **aber** eingebetteter Builder im Onboarding bekommt kein `initialInput` → fragt Equipment ein zweites Mal ab | Kein `eigener Onboarding-Generator`, keine doppelte Abfrage | teilweise | klein-mittel (nur `initialInput` durchreichen) |
| Start-Check nur im Onboarding | Bestätigt, `BaselineCheckFlowView` hat genau einen Aufrufer (`OnboardingView`), früherer Entfernungs-Fix (V6) hält | — | **erfüllt** | — |
| 3 klar getrennte Abschlussaktionen | Grundmuster korrekt (Mehrfach-Tap-Schutz via `isFinishingOnboarding`), **aber** zwei unterschiedlich beschriftete Finish-Trigger je nach Pfad (DayPicker "Plan starten" vs. Footer "Fertig") | Eine eindeutige Hauptaktion | teilweise | klein-mittel |

### D) Trainingsbegleitung / Reviews / Progression / Versionierung (Doc03)

**Bestätigt: dieser gesamte Funktionsbereich existiert nicht**, aber deutlich mehr fachliche
Bausteine sind bereits fertig, als die bisherige Taskliste vermuten ließ:

| Baustein | Ist | Soll | Status |
|---|---|---|---|
| Laufende Übungsprogression | `ProgressionEvaluator`/`ProgressionApplicator` — fertig, produktiv, pro Session, RIR-Schwelle-basiert | Genau das | **erfüllt, wiederverwendbar** |
| Deload-Logik | `DeloadAdvisor` — last-/gefühlsbasiert, trennt Kraft/Cardio sauber | — | **erfüllt, wiederverwendbar** |
| Absenz-/Comeback-Erkennung | `ComebackAdvisor` + `AbsenceDeload` + UI-Sheet — die reichhaltigste fertige Komponente, inkl. gestaffelter Lastreduktion und Anti-Spam | — | **erfüllt, wiederverwendbar** |
| Plan-Versionierung/Zeitanker | **Fehlt komplett** — `TrainingPlan` hat kein Datumsfeld, `WorkoutSession.day` ist eine lebende Referenz ohne Snapshot. Blockiert den Vier-Wochen-Trigger selbst ("seit wann läuft der Plan" ist unberechenbar) | `activatedAt`-Zeitanker mind. nötig | **fehlt, blockierend** |
| Review-UI/-Datenmodell | **Fehlt komplett**, auch nicht als Platzhalter | "Deine ersten vier Wochen" | **fehlt** |
| Soll-Ist-Teilnahmevergleich | **Fehlt komplett** — Rohdaten (`WorkoutSession.startTime/isCompleted/isRestDay`) vorhanden, aber keine Aggregationsschicht "geplante Gelegenheit vs. tatsächliche Session" | Teilnahme-Nenner je nach fester/flexibler Terminierung | **fehlt** |
| Nutzerfeedback-Erfassung (§4, 5 Fragen) | Nur `SessionFeeling` (Belastung) deckt 1 von 5 Fragen ab | Häufigkeit/Dauer/Belastung/Beschwerden/Ziel | **fehlt (4 von 5)** |

### E) Datenmodelle, Architektur, Persistenz, Export/Import (Doc01 §9, Doc03 §8)

| Punkt | Ist | Status |
|---|---|---|
| Entwurf/Berechnung/Persistenz getrennt | `PlanDraft`/`PlanningContext` komplett SwiftData-frei (0 `import SwiftData` in `FitnessAppCore`), genau ein Instantiator-Einstiegspunkt | **erfüllt** |
| Kein früher Insert vor Bestätigung | Alle `.insert`-Stellen für Plan/Day geprüft, keine vor explizitem Button-Tap | **erfüllt** |
| Stabile Exercise-Referenz | ID-first für Logs/PRs vollständig; **eine kleine Lücke**: `DashboardView.CardioGroupKey` gruppiert Cardio-Trends noch über `name` statt ID | **teilweise** (kleine, nicht historienkritische Lücke) |
| Export/Import-Vollständigkeit | Equipment-Tristate, Cardio-Ziele, stabile IDs — alles im CSV-Roundtrip geführt (Stichprobe ohne Lücke) | **erfüllt** (nur Stichprobe, kein Vollabgleich) |
| SwiftData-Migration-Konvention | Jüngste Felder (`ExerciseTemplate.id` u. a.) korrekt mit Default-Value-Expression, inkl. eigener Absicherung gegen Default-Literal-Kollision | **erfüllt** |
| Plan-Versionierung | Fehlt komplett (s. o.) — bereits mit einer additiven Minimal-Skizze vordokumentiert (`activatedAt` + schlanker `TrainingDayContentRecord`-Snapshot) | **fehlt** |

### F) Architekturgrenzen (Doc00) — Cross-Check

| Grenze | Status | Befund |
|---|---|---|
| Ein gemeinsamer Planungskontext | eingehalten (Persistenz-Ebene), **aber** `PlanningContext`-Fachtyp ist totes Gerüst (s. o.) | — |
| Kontextabhängige Oberfläche statt Builder-Kopie | **eingehalten** | Genau eine `PlanBuilderView`-Datei, vier Aufrufer mit Kontext-Parametern |
| Historische Logs nicht umgeschrieben | **eingehalten**, mit explizitem Schutzmechanismus (`recalculate` überspringt jeden Tag mit irgendeiner Session) + Tests | — |
| Kein ungefragtes Bulk-Update / kein neuer aktiver Plan ohne Entscheidung | **teilweise verletzt** — siehe "Wichtigster Einzelbefund" oben | PE-G2-Fix (Environment-Swap-Dialog) hält; `ProgramInstantiator`-Auto-Deaktivierung ist der offene Rest |
| Keine neue Start-Check-Einstiegsstelle | **eingehalten** | — |
| Dead-Code-Audit-Pflicht (CONTRIBUTING.md) | **verletzt** | `dead_catalog_v3.py` real ausgeführt: `UNUSED: 4` (vier tote xcstrings-Keys, cross-verifiziert) |
| Dynamic Type / kleine Displays | nicht systematisch, nur Stichprobe; `PlanBuilderView`/`PlanEditorView` haben **kein** Dynamic-Type-Handling | selbst von den Projekt-Audits ehrlich als offen benannt |

### G) Testabdeckung gegen Testmatrix (Doc04)

45 Matrixzeilen geprüft: **9 abgedeckt, 14 teilweise, 22 nicht abgedeckt.** Am stärksten: Serie B
(Wocheneditor-Kernlogik) und D (Verwerfen/Dirty-Tracking) — direkt in `PlanDraftTests.swift` und
`EditorDiscardSnapshotTests.swift` belegt. Am schwächsten: Serie F (Reviews, 0/8 — erwartungsgemäß,
da das Feature nicht existiert) und Serie E (UI-Edge-Cases, praktisch 0/8), strukturell bedingt
durch das **weiterhin fehlende echte UI-Test-Target** (`Tests/FitnessAppUITests` ist ein normales
SwiftPM-Testziel ohne `XCUIApplication`, kein `.xctestplan` im Repo). Letzter vollständiger grüner
Apple-CI-Lauf: Commit `a2ca5ff`, 1240/1240, manuell per Codemagic-API getriggert (kein
Auto-Trigger bei Push in diesem Repo).

## Priorisierter Umsetzungsplan

Kleine Aufgaben, mit Abhängigkeiten. Jede Aufgabe bekommt am Ende: umgesetzt/teilweise/offen,
Dateien, tatsächlich ausgeführte Tests, Apple-Ergebnis, UI-Ergebnis, Risiken, nächste Aufgabe
(Format aus Doc04 §5) — genau wie beim Task-#197-Zyklus.

**P1 — Sofort-Korrekturen (klein, keine Abhängigkeiten, vor allem anderen):** ✅ alle 5 umgesetzt
(Task #202, 2026-10-17).
- P1.1 ✅ **Entscheidung eingeholt**: mehrere gleichzeitig aktive Pläne sind gewollt (User-Entscheidung,
  Task #201). `ProgramInstantiator.instantiate` deaktiviert keine anderen Pläne mehr (Commit `3da2506`);
  `PlanGeneratorInstantiator.build`/`createPlan` ruft intern denselben Pfad auf, ist also automatisch
  konsistent. 2 Tests entsprechend umgedreht. Codemagic Build `6ad3be0b`: Build+Tests+Simulator-Build
  alle `success`.
- P1.2 ✅ Dead-Code-Audit: 4 tote xcstrings-Keys entfernt (`.scripts/del144_delete_dead_keys.py`,
  Commit `d6710eb`), `UNUSED: 0` wiederhergestellt, `TRANSLATIONS.md` regeneriert.
- P1.3 ✅ `DashboardView.CardioGroupKey` auf ID-first umgestellt (analog `PRDetector.GroupKey`,
  Commit `d0cb503`) — ein umbenanntes Custom-Exercise fragmentiert den Cardio-Trend nicht mehr.
- P1.4 ✅ Onboarding: Builder-Pfad ruft jetzt wie `DayPickerSheet.onConfirm` direkt
  `finishOnboarding()` in seinem `onGenerated`-Callback auf (Commit `53b23a1`) — kein zweiter,
  separater Footer-Tap mehr nötig.
- P1.5 ✅ Onboarding: eingebettetes `PlanBuilderView` bekommt `initialInput` mit
  `equipmentPreferences: derivedLegacyEquipment` (Commit `53b23a1`) — `selections` bleibt bewusst
  leer (Dok02 §1: kein eigener Onboarding-Generator, keine doppelte Trainingsarten-/Tage-Abfrage).

Konsolidierter Codemagic-Build über alle 4 Commits zusammen (`3da2506`, `d6710eb`, `d0cb503`,
`53b23a1`): `6ad3c031` — Build (debug), `swift test --parallel`, Simulator-Build für alle 5 Targets
(FitnessAppCore/Data/Health/Activities/UI) alle `success`. Task #202 damit vollstaendig abgeschlossen,
Apple-seitig bestaetigt.

**P2.5 — PlanningContext/EnduranceModality verdrahten (klein-mittel, Vorbedingung für P3/P4):** ✅
umgesetzt (Task #203, 2026-10-17).
- `EnduranceModality` bekommt eine String-RawValue-Konformance + `supportsRunCoach` (Commit
  `438c1fd`) — identische Invariante wie `PlanningContextIssue.runCoachRequiresRunningOrBothModality`,
  aber nutzbar ohne vollstaendigen `PlanningContext` (Tage/Dauer/Scheduling sind Plan-, nicht
  Profil-Eigenschaften).
- `UserBodyProfile` bekommt `enduranceModalityRaw: String?` + `runCoachEnabled: Bool = false`
  (Default-Value-Expression) und den einzigen vorgesehenen Schreibweg
  `setEnduranceModality(_:runCoachEnabled:)`, der die Invariante erzwingt (Commit `438c1fd`).
- `ProfileEditorView` bekommt die erste echte Instanziierung außerhalb von Tests: eine neue
  Sektion in `coachingCard`, sichtbar NUR für ein bereits bestehendes `TrainingGoal.endurance`-
  Profil (P2.2-Zwischenstand/Import) — die Zielkarte selbst bleibt weiterhin nicht neu waehlbar,
  siehe `TrainingGoal.currentlySelectableInUI`-Doku. Picker (Laufen/Radfahren/Beides) + Laufcoach-
  Toggle, 6 neue xcstrings-Keys DE/EN/TR (Commit `8fe654c`).
- Codemagic-Builds fuer beide Commits: `6ad3be0b`-Nachfolger `6ad3c2cb` — Build+Tests+Simulator-
  Build alle `success`. `swift test` lokal: 1035 Tests gruen.

**P3 — A+B-Builder & Wocheneditor (groß, abhängig von P2.5):**
- P3.1 ✅ Zielorientierter Einstieg (4 Zielkarten → `TrainingGoal`, inkl. Entsperrung `.endurance`).
  Umgesetzt 2026-10-17 (Deltiq-Weiterentwicklungsauftrag, selbststaendige Fortsetzung nach P1/P2.5):
  - Grundlagenfix zuerst: Laufcoach-Schalter vereinheitlicht (Commit `0d0e6e4`) — `runCoachEnabled`
    (P2.5) war ein zweiter, mit `cardioCoachingEnabled` (DEL-250) konkurrierender Schalter;
    "Verbindliche Produktregel" des neuen Auftrags verlangt GENAU einen. `setEnduranceModality`
    schreibt jetzt direkt in `cardioCoachingEnabled`, Invariante korrigiert (`nil`-Modalitaet blockiert
    den Bestandsschalter nicht mehr).
  - `GoalDrivenPlanSelectionBuilder` (Commit `1aed7e5`, Core, 17 Tests): uebersetzt Ziel +
    Ausdauerform + Alltagsrahmen in dieselben `PlanGeneratorTypeSelection`-Eingaben des
    unveraenderten `PlanGenerator` — `preferredStrengthKind` leitet das Kraft-Trainingsmittel aus
    dem Equipment-Profil ab statt es erneut abzufragen.
  - `PlanBuilderView` (Commits `f46c723`, `3f3b751`): neuer Ziel-Schritt (4 Karten, Doc02-konforme
    Ausdauerform-/Laufcoach-Unterfragen) + neuer Alltagsrahmen-Schritt (Tage/Zeit/Erfahrung als
    Gesamtwerte, Equipment als vorbefuellte Zusammenfassung mit "fuer diesen Plan anpassen").
    Cardio-Machbarkeits-Handoff (`isPreSeededFlow`) behaelt die bestehende, trainingsmittel-direkte
    UI unveraendert — kein Risiko fuer den Task-#197-getesteten Pfad. `onEnduranceModalityChosen`
    meldet die Entscheidung an `OnboardingView` zurueck (dort existiert zur Entscheidungszeit noch
    kein Profil); der eigenstaendige Modus (`PlansListView`s "+") schreibt direkt.
  - Codemagic (Commit `3f3b751`, konsolidiert): Build+Tests+Simulator-Build alle `success`.
    `swift test`: 1052 Tests lokal gruen.
  - **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `3f3b751`,
    `tb://129e4b5d66e72bf33800340a`), 2026-10-17:** vollstaendiger Flow "+"→"Build Plan"→
    "Strength & Endurance Combined"→"Running"→"Work toward a goal with a run coach"→Alltagsrahmen→
    "Adopt Plan" real auf dem Simulator durchlaufen. Bestaetigt: alter trainingsmittel-direkter
    Schritt NICHT sichtbar (Regression zum Cardio-Handoff-Pfad ausgeschlossen), 4 Zielkarten + Hybrid-
    Ausdauerform-Unterfrage + Laufcoach-Frage erscheinen korrekt, Alltagsrahmen-Schritt (Equipment-
    Zusammenfassung + 2 Stepper) korrekt, "Adopt Plan" erzeugt den Plan und schliesst den Builder.
    Anschliessend ueber Profil (More-Tab) verifiziert, dass die Wahl tatsaechlich auf
    `UserBodyProfile` landete: `cardioCoachingEnabled`-Switch-Wert `"1"` (= an) UND "Endurance type"
    zeigt "Running" — `PlanBuilderView.applyEnduranceModalityChoiceIfNeeded(to:)` schreibt korrekt.
    Nicht in dieser Runde TestingBot-geprueft (Linux-Tests bzw. Code-Review decken sie ab, aber
    keine reale Apple-UI-Bestaetigung): reine Endurance-Karte ("Running & Endurance"), Hypertrophie/
    Maximalkraft-Unterwahl der Kraft-Karte, "ohne Coach"-Option. Fehlgeschlagene Diagnose-Artefakte
    (zwei Skript-Anlaeufe mit Session-Timeout bzw. mehrdeutigem "More"-Label-Selektor) sind in
    `scratchpad/tb-diag/` dokumentiert, haben aber zu keinem App-Bug gefuehrt — reine Testskript-
    Fragilitaet (zwei UI-Elemente teilen sich zufaellig das gleiche Accessibility-Label "More").
  - Offen/vertagt: visueller Wocheneditor mit Drag&Drop (P3.2), Fixierungs-UI (P3.2), 3 gezielte
    Alternativen (P3.3), Header-Konvention (`DeltiqHeader`, Haken-Label) fuer `PlanBuilderView`
    (P3.4) — Umfang dieser Runde war explizit auf P3.1 begrenzt.
- P3.2 ✅ **implementiert** (Commit `6933335`, 2026-10-17), Apple-Build/Test-Status siehe unten.
  Visueller Wocheneditor: `resultStepView` nutzt jetzt `List`+`.onMove` (identisches Muster wie
  `PlanEditorView.daysSection`) statt der bisherigen reinen `ScrollView`-Liste — bindet weiterhin
  ausschliesslich an `PlanDraft`, keine Persistenz waehrend der Bearbeitung. Drag&Drop ruft
  `moveDraftDays`→`PlanDraft.moveDay`; eine wegen Positionsfixierung abgelehnte Verschiebung bleibt
  ohne Zustandsaenderung (Tag "springt" sichtbar zurueck, siehe Abnahme B01) UND zeigt einen Toast
  (`reorderRejectedToast`), WARUM — kein stilles No-Op. Zusaetzliches, explizites "Verschieben
  nach…"-Menu pro Tag als zugaengliche, PER-TAP erreichbare Alternative zum Drag-Gesture (ergaenzt
  die implizite VoiceOver-Reorder-Aktion, die `.onMove` automatisch liefert — wichtig u.a. fuer
  Switch Control/Voice Control). Fixierungs-UI (Inhalt/Position getrennt, `PlanDraft.setContentFixed`/
  `setPositionFixed` existierten bereits seit P2.4/P2.0-Nachbesserung): Menu-Toggles + sichtbare
  Pin-/Lock-Badges pro Zeile, zusammengefasst in einer VoiceOver-Ansage
  (`resultDayRowAccessibilityLabel`). 10 neue xcstrings-Keys (DE/EN/TR), `dead_catalog_v3.py`
  bestaetigt 0 unused. `swift build` + `swift test --parallel`: 1052 Tests gruen (lokal, Linux).
  **Apple-kompiliert ✅ (Commit `0976d84`, nach 2 echten Apple-CI-Funden):** der urspruengliche
  Commit `6933335` scheiterte am `ios-app`-Workflow mit einem echten Xcode-Typfehler
  (`loadLevel.localizedName` ist `LocalizedStringResource`, nicht `String` — auf Linux/SwiftPM
  klaglos durchkompiliert, Xcode lehnte zu Recht ab; Fix `b12e720`: `String(localized:)`, identisches
  Muster wie ueberall sonst im Code). Der `swift-package`-Workflow deckte DANACH einen ZWEITEN
  echten Divergenz-Fall auf: `.listStyle(.insetGrouped)` ist unter `.macOS(.v14)` (Package.swift
  zielt zusaetzlich auf macOS fuer Linux-/macOS-Testbarkeit) nicht verfuegbar — Fix `0976d84`: Zeile
  entfernt, plattformgerechter Default (identisch zu `PlanEditorView.daysSection`, das ebenfalls
  keinen expliziten `.listStyle` setzt). Beide Funde sind ein weiterer Beleg dafuer, warum dieses
  Epos nie allein auf gruene Linux-Tests vertraut — Codemagic `ios-app` (Build app+widget fuer iOS
  Simulator) UND `swift-package` (Build + `swift test` + Build library products fuer iOS Simulator)
  beide `success` fuer Commit `0976d84`.
  **UI-verifiziert ✅ (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `0976d84`,
  `tb://cebefb6dd65abbe0132c9b24`), 2026-10-17:** vollstaendiger Flow real auf dem Simulator
  durchlaufen (5-Tage-Hybridplan ueber den Alltagsrahmen-Stepper erzeugt). Bestaetigt: alle 5 Tage
  zeigen ein "Day options"-Menu mit "Move to…"/"Lock position"/"Lock content"; "Lock position" auf
  Tag 1 erzeugt sichtbar das `pin.fill`-Badge UND haengt "Position locked" an die VoiceOver-Ansage
  an; der Versuch, Tag 2 ("Easy Run") per "Move to… → Position 1" an die fixierte Position 1 zu
  verschieben, wird korrekt ABGELEHNT — Reihenfolge bleibt unveraendert (`[Intervals, Easy Run, …]`)
  UND der Toast "Can't move this day: a pinned day would lose its position." erscheint exakt wie im
  Code hinterlegt; nach "Unlock position" gelingt dieselbe Verschiebung und die Reihenfolge aendert
  sich nachweislich zu `[Easy Run, Intervals, …]`; "Lock content" erzeugt sichtbar das
  `lock.fill`-Badge. Alle Kern-Mechaniken des Wocheneditors (Fixierung, zugaengliche
  Verschieben-Alternative, Ablehnungs-Feedback) damit real auf Apple-Infrastruktur bestaetigt — die
  native Drag-Geste selbst wurde NICHT separat simuliert (WebDriver-Drag fuer SwiftUI-`List.onMove`
  ist nicht zuverlaessig scriptbar), ruft aber denselben, hier bereits verifizierten Code-Pfad
  (`moveDraftDay`/`PlanDraft.moveDay`) auf wie das "Move to…"-Menu. TestingBot-Budget nach diesem
  Testpaket (4 Sessions in dieser P3.1/P3.2-Runde): weiterhin 58210s laut `/v1/user` — unveraendert
  gegenueber dem Stand vor der Runde, vermutlich Abrechnungs-Verzoegerung (bereits in der P3.1-Notiz
  vermerkt), NICHT als "kostenlos/unbegrenzt" zu interpretieren.
  **Korrektur (2026-10-17, User-Rueckmeldung):** "UI-verifiziert" deckt bislang AUSSCHLIESSLICH den
  "Move to…"-Menuepfad ab, nicht beide Bedienwege gleichwertig — wird hier getrennt ausgewiesen statt
  unter einem gemeinsamen Status verborgen:
  - **Menue-Verschieben ("Move to…"): UI-verifiziert** (siehe oben, real auf TestingBot bestaetigt).
  - **Native Drag-Geste (`List.onMove`): NICHT verifiziert, ausdruecklich offen.** Kein TestingBot-Lauf
    hat das bisher tatsaechlich versucht (nur als plausibel beschrieben, da derselbe Code-Pfad
    `moveDraftDay`/`PlanDraft.moveDay` greift — das ist eine Annahme, kein Beweis). Siehe Task
    "P3.2: native Drag-Geste separat dokumentieren".
  P3.2 ist damit **Implementiert + Apple-kompiliert + Tests bestanden + UI-verifiziert (nur
  Menuepfad)** — NICHT "alle vier fuer beide Bedienwege vollstaendig bestaetigt", wie eine fruehere
  Fassung dieses Abschnitts implizierte.
- P3.3 **Korrektur (2026-10-17, User-Rueckmeldung): deckt nur EINE von DREI vereinbarten
  Alternativaktionen ab — "vollstaendig abgenommen" war fuer P3.3 selbst zutreffend, aber eine
  fruehere Lesart hat das faelschlich mit "die Alternativaktionen-Anforderung ist erledigt"
  gleichgesetzt.** Drei eigenstaendige Aktionen waren vereinbart:
  1. **Einzeltag-Alternative** — ✅ **vollstaendig abgenommen** (Commit `61ee3bb`, 2026-10-17):
     Implementiert + Apple-kompiliert + Tests bestanden + UI-verifiziert, alle vier getrennt bestätigt
     (Details unten unveraendert).
  2. **"Woche anders verteilen"** (eine andere GESAMT-Verteilung der Woche, nicht nur Reorder
     bestehender Tage) — ❌ **fehlt, nicht implementiert.** Das bestehende "Move to…"-Menu (P3.2)
     ordnet nur bereits generierte Tage um, erzeugt keine inhaltlich andere Wochenaufteilung.
     Eingeplant als eigenstaendige Restaufgabe (Task #205).
  3. **"Vorschlag neu erstellen"** (kompletter neuer Gesamtvorschlag) — ❌ **fehlt, nicht
     implementiert.** Das alte globale "Neu rechnen" (`shuffle: true`) wurde von P3.3 bewusst
     ENTFERNT (es spuelte Fixierungen/Aenderungen an anderen Tagen stillschweigend weg, Abnahme
     B04) — aber ERSATZLOS, ohne die als dritte Aktion vereinbarte, sichere Alternative dafuer neu
     zu bauen. Eingeplant als eigenstaendige Restaufgabe (Task #206).
  P3 (P3.1-P3.4) ist damit NICHT vollstaendig abgeschlossen, bis #205/#206 (und die P3.4-Korrektur
  unten) geschlossen sind — wird parallel bzw. vor der abschliessenden Gesamtabnahme nachgeholt.

  **Einzeltag-Alternative — Details (unveraendert gegenueber der urspruenglichen Abnahme):**
  - **Implementiert:** `PlanGenerator.targetedAlternatives(for:input:count:)` (Core) ersetzt den
    bisherigen globalen "Neu rechnen"-Button durch bis zu 3 verschiedene, noch nie gezeigte
    Alternativ-Inhalte fuer GENAU EINEN Tag — `matchingSelection` rekonstruiert ueber Equipment-Pool-
    Zugehoerigkeit, welche `PlanGeneratorTypeSelection` einen Tag erzeugt hat (`DaySpec` traegt keine
    Herkunfts-ID). Cardio-Tage und nicht zuordenbare Tage liefern `.noAlternativesAvailable` statt
    einer stillen leeren Liste (Abnahme B05). `PlanBuilderView`: "Alternativen anzeigen" im
    bestehenden "..."-Menu (deaktiviert bei `isContentFixed`), Auswahl ueber `.confirmationDialog`,
    `PlanDraft.replaceContent` ruehrt ausschliesslich den gewaehlten Tag an — alle anderen (inkl.
    Fixierungen) bleiben unangetastet (Abnahme B04). Der veraltete `loadLevel`-Badge des ersetzten
    Tages wird entfernt statt stehen gelassen.
  - **Apple-kompiliert:** Codemagic `ios-app` + `swift-package` (inkl. `swift test`) beide `success`
    fuer Commit `61ee3bb` — diesmal ohne neue Linux/Apple-Divergenz (anders als P3.2).
  - **Tests bestanden:** 8 neue Core-Tests (`PlanGeneratorTargetedAlternativesTests`) + alle
    bestehenden — 1060 Tests gruen (lokal UND auf Codemagic).
  - **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `61ee3bb`,
    `tb://3ac2d577d777a84a5a436b04`):** realer Durchlauf bestaetigt: "Show alternatives" im Menu
    vorhanden; Tap oeffnet einen Dialog mit einer ECHTEN, vom Original-Tag abweichenden Alternative
    ("Bodyweight · Push & Pull" → Dialog zeigt u.a. "Bodyweight · Pull & Push"); Auswahl aendert
    NACHWEISLICH NUR den Inhalt dieses einen Tages, der Belastungs-Badge wechselt korrekt auf "Not
    rated" (kein stiller falscher Wert); "Lock content" auf einem ANDEREN Tag deaktiviert dort
    korrekt "Show alternatives" (`enabled="false"` im Accessibility-Baum) — die Fixierung wird also
    tatsaechlich respektiert, nicht nur vom `PlanDraft`-Code (bereits Core-getestet), sondern auch
    vom UI-Gating selbst. Einzige offene Kleinigkeit: der exakte `.confirmationDialog`-Titeltext
    ("Choose an alternative for this day") liess sich im XML-Dump nicht wiederfinden (vermutlich
    Rendering-/Capture-Eigenheit des Action-Sheets, nicht funktional) — rein kosmetisch, aendert
    nichts an der oben bestaetigten Kernfunktion.
- P3.4 Header/Label/Discard-Guard auf `DeltiqHeader`-Muster.
  **Korrektur (2026-10-17, User-Rueckmeldung): die vorherige Einstufung "geprueft und bewusst NICHT
  umgesetzt" war falsch und wird hiermit zurueckgenommen.** Die Begruendung von damals (Verweis auf
  `OnboardingView` als abweichendes Vorbild fuer Mehrschritt-Assistenten) mag technisch zutreffend
  beschrieben haben, WARUM `PlanBuilderView` bisher kein `DeltiqHeader` nutzt — das bestehende
  Onboarding-Layout ist aber kein Grund, eine eigenstaendige, explizit vereinbarte Produktvorgabe
  fuer DIESEN Screen fallenzulassen. Die Vorgabe bleibt verbindlich.
  **Implementiert (Commit `63b097d`, 2026-10-17):** `PlanBuilderView` nutzt jetzt `DeltiqHeader`
  statt `.navigationTitle`/`.toolbar`. Checkmark oben rechts (nur auf dem Ergebnis-Schritt aktiv,
  sonst leer — es gibt vor Erreichen des Ergebnisses nichts zu "uebernehmen") ersetzt den bisherigen
  unteren "Plan uebernehmen"/"retryResolve"-Button, identisches Icon-only-Prinzip wie
  `PlanEditorView`/`BodyDataEditorView`. Zurueck-Chevron zeigt den etablierten
  `discardChangesConfirmation`-Dialog, sobald eine echte Auswahl getroffen wurde (`isDirty`: ab
  Schritt 2 immer wahr, auf Schritt 1 sobald eine Ziel-/Trainingsart-Auswahl existiert — im
  Cardio-Handoff-Fall von Anfang an, da dort bereits vorbefuellt), statt weiterhin kommentarlos zu
  `dismiss()`en. Sheet zusaetzlich per `interactiveDismissDisabled(isDirty)` gegen Pull-to-dismiss
  bei ungesicherten Aenderungen geschuetzt (identisches Prinzip wie
  `TrainingLocationEquipmentEditorView`).
  **Linux:** `swift build` + `swift test` (1062 Tests) gruen, `dead_catalog_v3.py` bestaetigt 0
  unused Keys (keine neuen Strings noetig — alle wiederverwendet).
  **Apple-kompiliert:** Codemagic `ios-app` + `swift-package` (inkl. `swift test`, 1062 Tests, keine
  Regression) beide `success` fuer Commit `63b097d`.
  **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `63b097d`,
  `tb://0d6cf046285893e13011183c`), 2026-10-17:** realer Durchlauf ueber den eigenstaendigen
  "+"→"Build Plan"-Einstieg (`PlansListView`). Bestaetigt: `DeltiqHeader`-Back-Chevron vorhanden,
  altes `.toolbar`-"Cancel" verschwunden, kein Checkmark auf Schritt 1/2 sichtbar; nach Auswahl einer
  Zielkarte ("Strength & Muscle") loest der Zurueck-Chevron TATSAECHLICH den Verwerfen-Dialog aus
  ("Discard changes?", Buttons "Discard Changes"/"Keep Editing") — "Keep Editing" bricht korrekt ab,
  der Assistent bleibt mit der getroffenen Auswahl offen; auf dem Ergebnis-Schritt erscheint GENAU EIN
  Checkmark mit dem erwarteten Accessibility-Label "Adopt Plan" (`planBuilder.result.adopt`), der alte
  untere "Plan uebernehmen"-Button ist nicht mehr vorhanden. Einzig NICHT separat auf dem Geraet erneut
  bestaetigt: der Tap auf den Checkmark selbst — er ruft laut Code exakt dieselbe, bereits seit P2.3
  etablierte `adoptPlan()`-Funktion auf wie zuvor der alte Button (nur der Aufrufort hat sich
  verschoben, die Funktion selbst ist unveraendert) — aus TestingBot-Budget-Disziplin nicht noch
  einmal eigens auf dem Geraet wiederholt, da dieser Funktionsaufruf bereits in frueheren P2.3/P3.1-
  Runden uiverifiziert wurde.
  P3.4 ist damit **Implementiert + Apple-kompiliert + Tests bestanden + UI-verifiziert**, alle vier
  getrennt bestaetigt.
  P3 (P3.1-P3.4) ist dennoch NICHT vollstaendig abgeschlossen, solange die beiden P3.3-Luecken
  (#205/#206, "Woche anders verteilen" / "Vorschlag neu erstellen") offen sind.

**P4 — Onboarding-Integration, Hybrid/Laufcoach (groß, abhängig von P2.5, teils parallel zu P3):**
- P4.1 ✅ **vollständig abgenommen** (Commit `c91583e`, 2026-10-17): Implementiert + Apple-kompiliert +
  Tests bestanden + UI-verifiziert, alle vier getrennt bestätigt.
  - **Implementiert:** `OnboardingView.Step` bekommt einen neuen, bedingt uebersprungenen Schritt
    `.enduranceModality` direkt nach `.coachingStyle` (`needsEnduranceModalityStep = trainingGoal ==
    .hybrid || trainingGoal == .endurance`), `goToNextStep`/`goToPreviousStep` ueberspringen ihn in
    BEIDE Richtungen, `progressIndicator` filtert ihn aus `visibleSteps` passend heraus. Eigener,
    von `customPlanEnduranceModality`/`customPlanRunCoachWanted` GETRENNTER State
    (`enduranceModality`/`runCoachWanted`) — die bestehenden Builder-Felder wuerden sonst von
    `clearCustomPlan()` beim Template-Wechsel stillschweigend geleert und die neue Frage ueberschreiben
    (die urspruenglich verbotenen "konkurrierenden Schalter"). `finishOnboarding()` wendet die Antwort
    jetzt UNABHAENGIG vom gewaehlten Plan-Pfad an (`if needsEnduranceModalityStep { ...
    profile.setEnduranceModality(...) }`, vorher nur im Builder-Zweig) — `customPlanEnduranceModality`
    gewinnt nur, falls der Builder fuer den tatsaechlich gebauten Plan selbst eine Wahl getroffen hat,
    sonst gilt die neue Schritt-Antwort. Das ist exakt die Luecke aus der Spezifikation: ein
    Hybrid-/Ausdauer-Ziel-User, der ein TEMPLATE waehlt statt den Builder, bekam die Frage vorher nie
    gestellt und `enduranceModality`/`cardioCoachingEnabled` blieben unberuehrt.
  - **Apple-kompiliert:** Codemagic `ios-app` + `swift-package` (inkl. `swift test`) beide `success`
    fuer Commit `c91583e`, keine neue Linux/Apple-Divergenz.
  - **Tests bestanden:** 1 neuer Core-Test (`testEveryEnduranceModalityHasANonEmptySymbol`,
    `PlanningContextTests`) + alle bestehenden — 1061 Tests gruen (lokal).
  - **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `c91583e`,
    `tb://9909206b792bac8c1717867f`):** realer Durchlauf genau des vorher ungetesteten Pfads —
    Onboarding mit explizit gewaehltem Ziel "Functional / Hybrid", danach erscheint der neue Schritt
    ("Which endurance style?"), "Running" ausgewaehlt, Folgefrage "How do you want to structure your
    running?" erscheint, "Work toward a goal with a run coach" ausgewaehlt, Navigation landet korrekt
    (ohne Wiederholung/Haengenbleiben) im naechsten Schritt (Trainingshistorie). Anschliessend bewusst
    NICHT der Builder, sondern ein TEMPLATE gewaehlt ("Football Athletic" — die vom Matcher empfohlene
    Karte, unabhaengig vom Namen fuer diesen Test), Uebernahme ueber den (separat als Altlast
    dokumentierten, siehe unten) hartkodierten deutschen Button "Diesen Plan wählen", DayPicker
    vorbefuellt uebernommen ("Start Plan"), Onboarding abgeschlossen. Im Profil-Editor (More-Tab →
    Profilzeile) zeigt die Sektion "Ausdauer" korrekt: "Endurance type"-Zeile vorhanden und zeigt
    "Running"; Laufcoach-Switch (`accessibilityLabel`/`name`="Enable running coaching")
    `value="1"` (AN) — exakt die zuvor fehlende Persistenz ueber den Template-Pfad ist damit real auf
    einem Simulator bestaetigt, nicht nur im Code gelesen.
  - **Separat notierter, NICHT in P4.1 behobener Befund (Altlast, zufaellig beim Scripten
    entdeckt):** `OnboardingView.swift` uebergibt an die `TemplatePreviewView`-Sheet-Instanz
    `adoptButtonTitle: "Diesen Plan wählen"` als hartkodiertes deutsches Literal (ebenso der
    Default-Wert selbst in `ProgramTemplatePickerView.swift` — `"Diesen Plan übernehmen"`) — dieser
    Button-Text reagiert NICHT auf die Geraete-Sprache. Vorbestehend, nicht durch P4.1 eingefuehrt und
    nicht Teil von dessen Spezifikationsumfang; bewusst nicht im Rahmen dieser Abnahme mitgefixt
    (Scope-Disziplin), hier nur dokumentiert, damit es nicht wieder verloren geht.
- P4.2 ✅ **vollständig abgenommen** (Commit `176c57b`, 2026-10-17): Implementiert + Apple-kompiliert +
  Tests bestanden + UI-verifiziert, alle vier getrennt bestätigt.
  - **Implementiert:** `preferencesAndPlanStep` IST bereits der Schritt direkt nach allen
    Onboarding-Fragen — die empfohlene Plan-Karte (`recommendedPlanCard`) zeigte dort bisher nur
    Name/Tagline/Begruendung, die tatsaechliche Wochenstruktur sah der User erst nach einem
    zusaetzlichen Tap in `TemplatePreviewView` (volle Tag-fuer-Tag-Uebungsliste). Neue
    `firstWeekPreview(_:)`-Zeile (`OnboardingView.swift`) zeigt direkt in der empfohlenen Karte ALLE
    Trainingstage auf einen Blick OHNE Uebungsdetails — nur Tag-Nummer + Tagtyp
    (`DaySpec.displayName`, bereits lokalisiert) als kompakte Chips in einem `LazyVGrid` (kein
    verschachteltes horizontales `ScrollView` innerhalb des tappbaren Karten-Buttons, um
    Gesten-Konflikte zu vermeiden). Nutzt `template.days` (Basis-Variante) statt der
    equipment-aufgeloesten `ResolvedPlanSelection`, da Substitution nur Uebungen INNERHALB eines
    Tages ersetzt, nie dessen Typ/Reihenfolge. Neuer Lokalisierungs-Key
    `onboarding.plan.firstWeek.title` (DE/EN/TR).
  - **Apple-kompiliert:** Codemagic `ios-app` + `swift-package` (inkl. `swift test`) beide `finished`
    (erfolgreich, Artefakte erzeugt) fuer Commit `176c57b`, keine neue Linux/Apple-Divergenz.
  - **Tests bestanden:** keine neue Core-Logik (reine UI-Komposition bestehender, bereits getesteter
    Daten aus `ProgramTemplate.days`) — alle 1061 bestehenden Tests weiterhin gruen (lokal).
  - **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `176c57b`,
    `tb://dbb637b42beca25712e658a2`):** realer Durchlauf bis zum Plan-Schritt bestaetigt: Titel "Your
    first training week" erscheint direkt in der empfohlenen Karte (kein Tap noetig); darunter zwei
    Chips mit korrektem Inhalt fuer das tatsaechlich empfohlene 2-Tage-Template ("1, Lower & Core" /
    "2, Upper & Power") — Tag-Nummer UND Tagtyp stimmen exakt mit dem angezeigten Template ("Football
    Athletic, 2 Days · Strength & Explosiveness") ueberein. `LazyVGrid` rendert auf echtem
    Simulator-Bildschirm sichtbar (Screenshot gesichert), keine leere/abgeschnittene Grid-Zelle.
    Einzige noch offene (nicht blockierende) Pruefung: Verhalten bei groesster Dynamic-Type-Stufe
    wurde in dieser Runde nicht gezielt gegengeprueft (bereits an anderer Stelle als generelle P9-
    Geraeteverifikations-Luecke dokumentiert, kein P4.2-spezifischer Verdacht).
- P4.3 Radfahren als geführte Ausdauerform-Option — **weitgehend bereits durch P4.1 abgedeckt**:
  `EnduranceModality.cycling` ist bereits eine vollwertige, lokalisierte Auswahlkarte im neuen
  `.enduranceModality`-Schritt (siehe oben, Dump bestaetigt die Karte "Cycling, Cycling is the focus
  of your endurance sessions."); `supportsRunCoach == false` fuer `.cycling` blendet die Laufcoach-
  Unterfrage korrekt aus (kein "Radcoach", siehe `PlanningContextTests.testRunCoachEnabledWithCyclingOnlyIsInvalid`).
  Noch nicht eigens verifiziert: ob der reine Cycling-Pfad (ohne Running/Both) im Profil-Editor und in
  der Plan-Generierung genauso sauber durchlaeuft wie der hier getestete Running-Pfad — offen fuer eine
  gezielte Nachpruefung, kein bekannter Fehlerverdacht.

**P5 — Equipment-Änderung → Plananpassung, Cooldown (mittel-groß, teilweise parallel zu P3/P4):**
- P5.1 ✅ **vollständig abgenommen** (Commits `2901492` + `893fbb4` (Apple-CI-Fund) +
  `744fc4d` (Logikfund vor UI-Verifikation), 2026-10-17): Implementiert + Apple-kompiliert +
  Tests bestanden + UI-verifiziert. Equipment-Save in `TrainingLocationEquipmentEditorView`
  löst — analog zum bestehenden `envSwap`-Dialog in `ProfileEditorView` — einen
  Vorschau/Ersatzvorschlag für bestehende, bereits instanziierte Pläne aus.
  Neuer Typ `PlanEquipmentAdaptationApplier` (FitnessAppData) bringt die bestehende
  `PlanEquipmentChecker`/`ExerciseSubstitutionEngine`-Logik (Smart-Onboarding-Epic
  Phase 5, bisher ausschliesslich VOR der Instanziierung in `TemplatePreviewView`/
  `PlanBuilderView` genutzt) erstmals auf einen bereits LIVE gespeicherten `TrainingPlan`
  an — die Luecke, die P5.1 schliesst. Archive-statt-Delete-Prinzip identisch zu
  `PlanEnvironmentMigrator` (DEL-049): das Original wird `isArchived = true` statt
  geloescht (Historie bleibt erhalten), die neue Uebung traegt `swappedFromOriginal`.
  `save()` prueft nach dem Equipment-Schreiben, ob mindestens ein nicht-leerer Plan
  gegen das NEUE Profil eine Luecke hat; nur dann erscheint der Dialog — ein reines
  Equipment-Upgrade (nur Items hinzugefuegt) loest ihn korrekt nicht aus.
  Neue xcstrings-Keys: `profile.equipmentSwap.title`/`.message` (Yes/No-Buttons
  wiederverwenden `profile.envSwap.confirm`/`.keep` — identische Semantik, kein neuer
  String). Neue Tests: `PlanEquipmentAdaptationApplierTests` (5 Faelle: `check()`
  verfuegbar/nicht-verfuegbar, `apply()` archiviert+ersetzt korrekt, laesst unbeteiligte
  Uebungen unberuehrt, tut nichts wenn bereits alles verfuegbar ist).
  **Apple-CI-Fund (Commit `893fbb4`):** `PlanEquipmentAdaptationApplier.apply(...)` rief
  `ProgramInstantiator.makeExercise`/`libraryLookupNames`/`libraryLookupSpecs` aus einem
  nicht-`@MainActor`-isolierten Kontext auf — `ProgramInstantiator` selbst ist komplett
  `@MainActor`. Linux' Swift-Toolchain hat den fehlenden Isolations-Abgleich nicht erkannt,
  Xcode (Codemagic `ios-app` + `swift-package`) zu Recht schon: "call to main actor-isolated
  static method ... in a synchronous nonisolated context". Gefixt durch `@MainActor` auf
  dem gesamten `PlanEquipmentAdaptationApplier`-Enum (einziger Aufrufer ist ohnehin eine
  SwiftUI-View, laeuft also bereits auf dem Main-Actor). Dies ist die DRITTE in dieser
  Session gefundene, nur auf Apple-CI reproduzierbare Divergenz (nach den P3.2- und
  P5.2-Funden) — bestaetigt erneut die Mandats-Vorgabe, Linux-Ergebnisse nie als alleinigen
  Beweis zu akzeptieren.
  **Logikfund vor der UI-Verifikation (Commit `744fc4d`, selbst gefunden, nicht von
  Codemagic/TestingBot):** `save()` uebergab ursprünglich den noch UNBESTAETIGTEN
  `draftEquipmentProfile` an `hasAnyPlanWithEquipmentGap`/`pendingEquipmentAdaptation`.
  Ein nie beruehrtes Item (z.B. "Rack") ist darin noch `.unknown`, nicht `.unavailable` —
  `PlanEquipmentChecker`/`ExerciseSubstitutionEngine` ersetzen aber ausschliesslich
  definitiv `.unavailable` Luecken (`report.missing`), niemals `.unknown`-Faelle
  (`report.uncertain`). Der Dialog waere zwar erschienen (`!isAvailable` ist fuer
  `.unknown` ebenfalls wahr), ein Bestaetigen haette aber STILLSCHWEIGEND NICHTS
  veraendert — ein fuer den Nutzer nicht erkennbarer, funktionaler Bruch. Gefixt, indem
  ab dem Luecken-Check durchgehend `profile.equipmentProfile` (NACH
  `confirmEquipmentProfileComplete()`, also vollstaendig aufgeloest) statt des Drafts
  verwendet wird. Dieser Fund entstand aus der eigenen Code-Analyse beim Entwurf des
  TestingBot-Testfalls, VOR dem ersten reinen UI-Lauf — exakt die Art von Fehler, die das
  Mandat mit "gefundene Bugs werden behoben, betroffene Tests erneut ausgefuehrt" meint.
  **Apple-kompiliert:** `ios-app` + `swift-package` beide `success` fuer den finalen
  Commit `744fc4d` (nach allen drei oben genannten Fixes).
  **Tests bestanden:** Codemagic-Testlog bestaetigt alle 5 neuen
  `PlanEquipmentAdaptationApplierTests`-Faelle liefen tatsaechlich (log-grep-verifiziert:
  `testCheckReturnsAvailableWhenProfileSupportsEveryExercise`,
  `testCheckReturnsUnavailableWhenAnExerciseIsMissingRequiredEquipment`,
  `testApplyArchivesTheOriginalAndInsertsAReviewedReplacement`,
  `testApplyLeavesUnrelatedExercisesUntouched`,
  `testApplyDoesNothingWhenEverythingIsAlreadyAvailable`), 1282 Tests gesamt auf macOS
  gruen (Differenz zu 1277 bei P5.2 = genau die 5 neuen Tests; Differenz zu den 1062
  Linux-Tests = alle SwiftData-Suiten, die nur dort laufen).
  **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `744fc4d`,
  `tb://e8ca6cb4aedf646c153de723`):** voller End-to-End-Durchlauf — Onboarding mit Ziel
  "Weight loss" → Template "Cut Phase Full Body" adoptiert (enthaelt "Back Squat"
  [EN-Anzeige von "Kniebeuge"], 3 Saetze, 6-12 Wdh., damit die reviewte Regel
  "Kniebeuge" → "Goblet Squat" greift) → Equipment-Editor: Dumbbell + Barbell auf
  "verfuegbar" gesetzt, Rest (inkl. Rack) bleibt unberuehrt → Speichern → Dialog
  "Equipment Changed" erscheint TATSAECHLICH mit dem erwarteten Text ("You updated your
  equipment. Should existing plans be auto-adjusted...") und beiden Buttons ("Yes, Adjust
  Plans" / "No, Keep As-Is") → "Yes, Adjust Plans" angetippt → zurueck zum Tagesplan:
  "Back Squat" ist WEG, "Goblet Squat" ist an EXAKT DERSELBEN Position (Slot 1, gleiche
  Saetze/Wdh./Pause: 3 × 6-12 × 150s) erschienen — beweist Archivierung + korrekte
  Positionstreue end-to-end auf echtem Geraet, nicht nur in der Core-Simulation.
  Einzige nicht sichtbar gerenderte Komponente (kein Fehlerverdacht, erklaert):
  der `confirmationDialog`-TITEL ("Equipment Changed") selbst erscheint auf iOS NICHT
  als sichtbarer Text, wenn gleichzeitig eine `message:` gesetzt ist UND
  `titleVisibility` nicht explizit auf `.visible` gesetzt wird (SwiftUI-Standardverhalten
  `.automatic`) — identisches, bereits bestehendes Verhalten bei allen anderen
  `confirmationDialog`-Aufrufen in `ProfileEditorView` (`envSwap`, `envRestore`,
  `cardio.retroSync`, `health.pullConfirm`), also keine P5.1-Regression, sondern
  bewusst beibehaltene Konsistenz mit dem Rest der App.
  **Zusaetzliche Test-Infrastruktur-Erkenntnis (keine Produktauswirkung):** TestingBot/
  Appium-Sessions brauchen fuer Flows mit eigenen `confirmationDialog`s
  `"appium:autoAcceptAlerts": false` — der Default `true` tippt den Dialog automatisch
  weg, bevor das Skript reagieren kann. Das erfordert im Gegenzug ein explizites,
  defensives `POST .../alert/accept` direkt nach Abschluss des Onboardings (fuer die
  System-Benachrichtigungs-Berechtigung, die sonst unsichtbar blockiert — SpringBoard-
  Alerts erscheinen nie im App-eigenen `/source`-Baum). Dokumentiert fuer kuenftige
  TestingBot-Skripte mit eigenen Dialogen/Action-Sheets.
- P5.2 ✅ **vollständig abgenommen** (Commits `dc92d36` + Apple-CI-Fund-Fix `e51cad9`, 2026-10-17):
  Implementiert + Apple-kompiliert + Tests bestanden; UI-Verifikation bewusst NICHT separat
  nachgeholt (reine Core/Data-Verdrahtung ohne eigene neue UI-Interaktion ausser dem bereits mit
  P5.3 UI-verifizierten Status-Hinweis, siehe dort — kein separater UI-Pfad noetig).
  `PlanGeneratorInstantiator.build(...)`/`createPlan(...)` hatten laut eigener, bereits bestehender
  Code-Doku (P2.1-Korrektur) eine EXPLIZIT benannte, offene Anschlussaufgabe: "Der volle
  Phase-5-Substitutions-Pfad ... ist bewusst NICHT angebunden: er braucht einen
  `SubstitutionContext(goal:experienceTrack:)`, und ein ueber den Builder ... erzeugter Plan hat
  kein eigenes `TrainingGoal` ... Bleibt offene Anschlussaufgabe, sobald der zielorientierte
  Builder (P3) ein echtes Ziel liefert." P3.1 (`GoalDrivenPlanSelectionBuilder`, Commit `1aed7e5`)
  erfuellt diese Bedingung bereits seit Laengerem — P5.2 ist die Umsetzung dieser vorgezeichneten
  Verbindung. Neuer optionaler Parameter `generatorGoal: TrainingGoal?` (Default `nil`, alle drei
  bestehenden Aufrufer — Onboarding, `CardioFeasibilityCardModel`, der preseeded Builder-Handoff —
  bleiben dadurch UNVERAENDERT, kein erfundenes Ziel). Gesetzt (ausschliesslich von
  `PlanBuilderView.adoptPlan()`, mit `selectedTrainingGoal` — `nil` im `isPreSeededFlow`-Handoff,
  wo es keine echte Zielfrage gab), laeuft `build(...)` jetzt denselben `PlanSelectionResolver.
  resolve`-Pfad wie `TemplatePreviewView` fuer Templates und reicht das Ergebnis als
  `resolvedSelection:` an `ProgramInstantiator.instantiate` durch (bereits zuvor die "EINZIGE
  Quelle der Wahrheit sobald gesetzt" laut dortiger Doku — nur bisher nie vom Builder-Pfad benutzt).
  `experienceTrack` kommt in `createPlan(...)` automatisch vom echten `UserBodyProfile` (beschreibt
  den User, kein "erfundener" Wert wie ein Ziel). Zusaetzlich: `PlanBuilderView.resultStepView`
  zeigt jetzt (nur im zielorientierten Einstieg) einen Equipment-Status-Hinweis
  (`PlanEquipmentChecker.check`, dieselben `picker.plan.equipment.*`-Lokalisierungs-Keys wie
  `TemplatePreviewView` — keine neuen Strings). Zwei neue Core/Data-Integrationstests
  (`PlanGeneratorInstantiatorTests`): ohne `generatorGoal` bleibt eine equipment-inkompatible
  Uebung unveraendert (Regressionsschutz fuer die drei unveraenderten Aufrufer); MIT `generatorGoal`
  wird sie ueber eine echte, bereits reviewte Regel ("Kniebeuge" → "Goblet Squat") tatsaechlich im
  materialisierten `TrainingPlan` ersetzt — bewiesen end-to-end gegen einen echten `ModelContext`,
  nicht nur gegen eine separate Vorschau. Wie alle `FitnessAppDataTests` (SwiftData) kompilieren
  diese auf Linux, laufen dort aber nicht (bestehende Projekt-Einschraenkung).
  **Apple-kompiliert:** erster Versuch (Commit `dc92d36`) schlug auf Codemagic `swift-package` real
  fehl — `PlanBuilderView.swift:1283: cannot convert value of type 'String' to expected argument
  type 'LocalizedStringKey'` in der neuen `builderEquipmentStatusRow`: `Text(_:bundle:)` erwartet
  ein `LocalizedStringKey`, das sich NICHT implizit aus einer zur Laufzeit gewaehlten
  `String`-Variable ergibt — der Linux-SwiftUI-Stub akzeptierte das faelschlich (gleiche Art
  Divergenz wie der P3.2-Fund), Xcode zu Recht nicht. Gefixt mit `String.LocalizationValue`
  (Commit `e51cad9`, derselbe etablierte Weg wie im Rest der Datei). Danach: `ios-app` +
  `swift-package` beide `success`.
  **Tests bestanden:** Codemagic-Testlog bestaetigt beide neuen Tests liefen tatsaechlich
  (`testBuildWithGeneratorGoalSubstitutesAnUnavailableExerciseUsingAReviewedRule`,
  `testBuildWithoutGeneratorGoalNeverSubstitutesExercises`), 1277 Tests gesamt auf macOS gruen
  (Differenz zu den 1062 Linux-Tests = die SwiftData-Suiten, die nur dort laufen).
- P5.3 ✅ **vollständig abgenommen** (Commits `79be8fd` + derselbe Apple-CI-Fund-Fix `e51cad9`,
  2026-10-17): Implementiert + Apple-kompiliert + Tests bestanden + UI-verifiziert.
  `ExerciseRole.cooldown` (DEL-087) existierte bisher nur im Datenmodell und in der aktiven
  Workout-UI (`ExerciseCard`) — KEIN Generator- oder Template-Pfad erzeugte je eine Übung mit
  dieser Rolle (per Grep über den gesamten Katalog bestätigt: 0 Treffer). Ergänzt in
  `ProgramTemplates.swift` (`hybridPerformance`, Tag "Easy Run"): ein Cooldown-Spaziergang nach dem
  Lauf, mit derselben Übung wie der bestehende Warmup davor ("Gehen / Einlaufen") — kein neuer
  Katalog-Eintrag nötig. Neuer Core-Regressionstest
  `testAtLeastOneTemplateExerciseHasCooldownRole` (`ProgramTemplatesTests`) schützt gegen erneutes
  Leerlaufen. Zusätzlich: Rollen-Anzeige (Warmup/Cooldown-Pill) in `DayEditorView`s Übungszeile
  ergänzt — vorher keine einzige `ExerciseRole`-Referenz in dieser Datei, User sah beim Planen/
  Bearbeiten nicht, welche Übung Warmup/Cooldown ist. `PlanEditorView` zeigt grundsätzlich keine
  einzelnen Übungsnamen (nur eine Tag-weite Übungs-ANZAHL) — eine Rollen-Anzeige ist dort
  architektonisch nicht anwendbar, daher bewusst nicht nachgebaut (analog zur P3.4-Entscheidung).
  **Nebenfund gleich mitbehoben:** `ExerciseCard.rolePillText` gab bisher hartkodierte, nicht
  lokalisierte Strings `"WARM-UP"`/`"COOL-DOWN"` zurück — durch eine geteilte, lokalisierte Quelle
  (`ExerciseRole.localizedPillText`, neue xcstrings-Keys `exercise.role.warmup.pill`/`.cooldown.pill`)
  ersetzt, die jetzt sowohl `ExerciseCard` als auch das neue `DayEditorView`-Pill nutzen — ein
  Lokalisierungsbug weniger, keine Verdopplung der (vorher kopierten) Pill-Logik.
  **Apple-kompiliert:** `ios-app` + `swift-package` beide `success` (nach dem oben bei P5.2
  beschriebenen, gemeinsamen Apple-CI-Fund-Fix `e51cad9` — derselbe Commit deckte beide Phasen ab).
  **Tests bestanden:** `testAtLeastOneTemplateExerciseHasCooldownRole` lief tatsächlich (Codemagic-
  Testlog bestätigt), 1277 Tests gesamt auf macOS grün.
  **UI-verifiziert (TestingBot, iPhone 15/iOS 18.0, App-Build aus Commit `79be8fd`):** Die Pill-
  Mechanik selbst ist real auf einem Gerät bestätigt — Onboarding mit Ziel "Maximum Strength" →
  Template "Powerlifting 5x5" → `DayEditorView` von "Workout A" zeigt "Face Pull" mit sichtbarer,
  korrekt lokalisierter "WARM-UP"-Pille direkt daneben (exakt der gemeinsame, jetzt geteilte
  `ExerciseRole.localizedPillText`-Code, den auch `ExerciseCard` nutzt). Das bestätigt sowohl die
  Lokalisierungs-Korrektur als auch die neue `DayEditorView`-Integration. **Eine Einschränkung,
  transparent offen gelassen:** die KONKRETE neue Cooldown-Übung (im Template "Hybrid Athlete —
  Performance", Tag "Easy Run") wurde in dieser Runde nicht per UI erreicht — der volle
  Template-Katalog-Picker (`PlansListView` → "+" → "From Template" → `ProgramTemplatePickerView`)
  ließ sich per TestingBot-Skript nicht zuverlässig öffnen/scrollen (vermutlich ein SwiftUI-Menu-
  Interaktionsproblem im Skript, kein beobachteter Produktfehler — das Menü funktioniert im
  Code-Review unauffällig). Die Cooldown-Erzeugung selbst ist Core-getestet
  (`testAtLeastOneTemplateExerciseHasCooldownRole`, Apple-bestätigt gruen) und nutzt exakt denselben
  Rendering-Code-Pfad wie die hier real bestätigte Warmup-Pille — das Restrisiko wird als gering
  eingeschätzt, bleibt aber ein offener, benannter Gerätetest-Punkt statt stillschweigend als erledigt
  gebucht zu werden.

**P6 — Plan-Versionierung & Datenqualität (klein-mittel, abgeschlossen):** Code/Data UND
UI-Abnahme für P6.1–P6.3 vollständig grün (finaler Stand Commit `ae003a6`, 1320/1320 Apple-Tests;
P6.3-TestingBot-Blocker gefunden, behoben und erneut verifiziert — siehe dort für den vollständigen
Diagnoseweg). P7 läuft bereits parallel/danach weiter.
- P6.1 ✅ **vollständig abgenommen** (Commit `ec9f1fd`, 2026-10-18): Implementiert + Apple-kompiliert
  + Tests bestanden + UI-verifiziert (nicht zutreffend, begründet unten).
  `TrainingPlan.activatedAt: Date?` neu, additiv. `nil` bedeutet ausdrücklich "unbekannt" — NIE
  "nie aktiviert" und NIE ein rückwirkend erfundenes Datum (bindende Vorgabe aus dem Gesamtmandat:
  "Keine erfundenen historischen Startdaten oder Planfassungen"). Feld ist pro Plan, nicht global,
  weil das Produkt bereits mehrere gleichzeitig aktive Pläne zulässt (`ProgramInstantiator.
  instantiate` deaktiviert bestehende Pläne bewusst nicht, Task #201/#202) — genau die zweite
  bindende Vorgabe ("Mehrere aktive Pläne ... im Teilnahme-Nenner beachten") ist damit bereits in
  der Datenmodellierung verankert, nicht erst in P6.2 nachzurüsten. Kein kalendergesteuerter
  Automatismus irgendeiner Art beteiligt (dritte bindende Vorgabe) — das Feld wird ausschließlich
  durch echte Nutzeraktionen gesetzt: `TrainingPlan.init` stempelt "jetzt" nur, wenn ein NEUER Plan
  bereits aktiv erzeugt wird und kein expliziter Wert übergeben wurde; `PlanEditorView.setActive(true)`
  (der manuelle "Aktiv"-Schalter) stempelt beim manuellen Umschalten explizit nach, da SwiftData
  `@Model` keine zuverlässigen Property-Observer für bestehende Objekte bietet. Export/Import additiv
  erweitert (etabliertes Muster wie `generator_input_raw`/`generation_source`): neue CSV-Spalte
  `activated_at_utc`, Import liest sie defensiv (`row.date(...)`, nil-sicher für alte Backups ohne
  diese Spalte) und schreibt sie IMMER explizit, unabhängig davon, ob der bestehende DEL-225-Guard
  (`mayActivate`) die importierte `isActive`-Übernahme unterdrückt — der reale historische Zeitpunkt
  aus dem Backup bleibt so auch dann erhalten, wenn der importierte Plan am Ziel nicht aktiv wird.
  Drei neue Regressionstests (`DataPortabilityRoundtripTests`): Roundtrip für einen aktiven Plan,
  `nil`-Default für einen nie aktivierten Plan, und — der gezielte Regressionsschutz gegen genau die
  Fehlerklasse, die hier vermieden werden sollte — ein Plan, dessen Aktivierung beim Import durch den
  DEL-225-Guard unterdrückt wird, behält trotzdem sein echtes historisches `activatedAt`.
  **Apple-kompiliert:** `ios-app` + `swift-package` (Codemagic-Build-IDs `6ad4093daa3c963632c9d92d`/
  `6ad4093dcb9bea65cab692f7`) beide `success`, alle Steps grün.
  **Tests bestanden:** Codemagic-Testlog bestätigt, dass alle drei neuen Tests tatsächlich liefen
  (`testActivatedAtSurvivesRoundtripForAnActivePlan`,
  `testActivatedAtDefaultsToNilOnRoundtripForANeverActivatedPlan`,
  `testActivatedAtSurvivesEvenWhenImportSuppressesActivationDueToExistingActivePlan`), 1285 Tests
  gesamt auf macOS grün, 0 Fehler.
  **UI-verifiziert:** nicht zutreffend — P6.1 fügt keine neue UI-Oberfläche hinzu (reines Datenmodell-
  /Export-Feld, der einzige UI-Berührungspunkt ist der bereits bestehende, unveränderte "Aktiv"-
  Schalter in `PlanEditorView`, dessen sichtbares Verhalten sich nicht ändert). Analog zur P5.2-
  Handhabung wird dies hier explizit als "nicht zutreffend" dokumentiert statt stillschweigend
  ausgelassen.
- P6.2 ✅ **vollständig abgenommen** (Commit `06075eb`, 2026-10-18): Implementiert + Apple-kompiliert
  + Tests bestanden + UI-verifiziert (nicht zutreffend, begründet unten).
  `PlanParticipationEvaluator` (`Sources/FitnessAppCore/Analytics/`): reine, deterministische
  Core-Funktion — kein SwiftData, kein `Date()`/`Calendar.current` im Code-Pfad, Auswertungsdatum
  und `Calendar` werden immer injiziert. Deckt exakt die acht vom Gesamtmandat verbindlich
  benannten Fälle ab:
  1. **Jeder Plan einzeln** — die Funktion nimmt immer genau einen Plan entgegen; der Aufrufer
     ruft sie pro aktivem Plan separat auf (mehrere gleichzeitig aktive Pläne bleiben ein
     bewusstes Produktverhalten, Task #201/#202 — kein globaler Soll-Ist-Topf).
  2. **Abgeschlossen/teilweise/nur gestartet** bleiben als `Outcome.completed/.partial/.startedOnly`
     getrennt gezählt, nie zu einem Bit verschmolzen.
  3. **Kein Doppel-Ausgleich** — alle Sessions eines Kalendertags werden VOR jeder Zählung auf den
     stärksten Ausgang verdichtet (`Comparable`-Rang `startedOnly < partial < completed`). Ein
     zweites Training am selben Tag kann dadurch nie einen anderen, fehlenden Tag kompensieren —
     mit Regressionstests sowohl für feste Wochentage als auch für flexible Kadenz bewiesen.
  4. **Feste Wochentage vs. flexible Reihenfolge** sind zwei getrennte Zweige: bei festen
     Wochentagen wird eine konkrete, datumsgenaue Soll-Liste gebildet (Training an einem
     Nicht-Plantag zählt als "extra", nie als erfüllter Termin); bei flexibler Kadenz zählt nur
     "wie oft pro Woche", anteilig zur verstrichenen Zeit, abgerundet — exakt dasselbe
     Trainingsmuster wird testbar unterschiedlich bewertet, je nach Terminierungsart.
  5. **Nicht fällige Einheiten** (Datum nach dem Auswertungsdatum) fließen nie in die Soll-Zahl
     ein — bewiesen durch einen Test, der mitten in der Woche auswertet und die noch ausstehenden
     Plantage explizit NICHT als versäumt zählt.
  6. **Kein erfundener historischer Soll-Zustand** — fehlt `activatedAt` (P6.1), liefert die
     Funktion `.notReliablyEvaluable(.activationStartUnknown)` statt irgendeinen Start zu raten
     (auch nicht aus dem frühesten geloggten Workout).
  7. **Aktivierungswechsel/Planänderungen** — `activatedAt` ist nur der aktuelle, ununterbrochene
     Aktivierungsanker, keine vollständige Historie (es gibt kein `deactivatedAt`). Ein aktuell
     inaktiver Plan wird deshalb grundsätzlich NICHT bewertet
     (`.notReliablyEvaluable(.planNotCurrentlyActive)`), weil das tatsächliche Ende seiner letzten
     aktiven Phase unbekannt ist. Jedes ausgewertete Ergebnis legt zusätzlich offen
     (`dataGaps`), dass es nur einen einzigen Aktivierungsanker kennt und dass Planänderungen
     innerhalb der Periode nicht erkannt werden (die aktuelle Tagesstruktur wird für den gesamten
     Zeitraum angenommen, mangels Versionierung).
  8. **Unzureichende Datengrundlage** → benannte `UnreliableReason` (`activationStartUnknown`,
     `planNotCurrentlyActive`, `evaluationBeforeActivation`, `planHasNoTrainingDays`,
     `noOpportunityDueYet`) statt einer 0-von-0- oder sonst scheinpräzisen Quote — z.B. zeigt die
     Funktion am Aktivierungstag selbst, bevor proportional auch nur eine Einheit fällig wurde,
     ausdrücklich "nicht zuverlässig bewertbar" statt "0 %".
  Ergebnis (`Summary`) enthält Zeitraum (`periodStart`/`periodEnd`), geplante/absolvierte Einheiten
  je Kategorie, die tatsächlich angewendeten Zählregeln (`countingRules`, maschinenlesbare Enum-
  Fälle statt freiem Text — eine spätere UI/Lokalisierung übersetzt sie 1:1) und die Datenlücken
  (`dataGaps`) — wie gefordert nachvollziehbar, nicht nur eine nackte Zahl. Löst ausdrücklich
  NICHTS aus: reine rückblickende Kennzahl, keine automatische Belastungssteigerung oder
  Planänderung.
  20 neue Tests (`PlanParticipationEvaluatorTests`), je mindestens einer pro der acht Regeln plus
  eine Invarianten-Prüfung (`plannedCount == completed+partial+startedOnly+missed`).
  **Apple-kompiliert:** `ios-app` + `swift-package` (Codemagic-Build-IDs `6ad40f11a15c10578929c33f`/
  `6ad40f11aa538e3682cfa35b`) beide `success`, alle Steps grün.
  **Tests bestanden:** Codemagic-Testlog bestätigt, dass alle 20 neuen Tests tatsächlich liefen
  (einzeln nach Namen gegrept, z.B. `testDoubleSessionOnOneDayDoesNotOffsetAMissingDay`,
  `testFixedWeekdaysPenalizesOffScheduleTrainingAsExtraNotAsCredit`,
  `testInactivePlanIsNotReliablyEvaluableBecauseDeactivationTimeIsUnknown`), keine Fehlschläge,
  1305 Tests gesamt auf macOS grün (1082 Linux-Tests zuvor + 223 reine SwiftData-Suiten, die nur
  auf Apple laufen).
  **UI-verifiziert:** nicht zutreffend — P6.2 ist bewusst "reine, deterministisch testbare
  Core-Logik" ohne jede neue UI-Oberfläche (so vom User explizit verlangt); eine Anzeige der
  Teilnahmequote ist ein separater, noch offener Folgeschritt (Datenanbindung `WorkoutSession` →
  `PlanParticipationEvaluator.Input` + UI-Darstellung), nicht Teil dieser Abnahme.
- P6.3 — **Code/Data-Abnahme ✅ UND UI-Abnahme ✅ — beide vollständig, getrennt ausgewiesen**
  (aktueller Stand Commit `ae003a6`, 2026-10-18, über `618e63e`/`92757bf` auf `063cb90`
  aufbauend). Auf ausdrücklichen User-Wunsch ("Code-/Data-Abnahme und UI-Abnahme getrennt
  ausweisen") werden beide Status hier bewusst als zwei SEPARATE Befunde dokumentiert, auch
  nachdem beide grün sind.

  **Nachbesserung (Commit `618e63e`): periodische, echt optionale Belastungsfrage.** Nebenfund
  #3 (unten) führte zu einer fachlichen Korrektur, kein blosses Dokumentieren der Lücke: statt
  `WorkoutSession.sessionFeeling` (pro Session, nicht optional) bekommt `PeriodicCheckInView`
  eine EIGENE, periodenbezogene Belastungsfrage (neues Core-Enum `ExertionFeedback`:
  `tooEasy`/`appropriate`/`tooHard`, additives Feld `PeriodicCheckIn.exertionFeedbackRaw`, CSV-Spalte
  `exertion_feedback`, rückwärtskompatibel wie `activated_at_utc`). Damit sind jetzt alle FÜNF
  Fragen dieses Rückblicks (Häufigkeit/Dauer/Belastung/Beschwerden/Ziel) einzeln echt überspringbar
  — der in Nebenfund #3 dokumentierte Unterschied ist damit behoben, nicht nur benannt. Der
  bestehende Trainingsabschluss (`FinishWorkoutSheet`/`SessionFeeling`) bleibt unverändert.
  **Apple-kompiliert:** `ios-app` + `swift-package` beide `success`. **Tests bestanden:** 1320/1320
  auf macOS grün (bestehende P6.3-Roundtrip-Tests um `exertionFeedback` erweitert, keine
  Fehlschläge). `FourWeekReviewOrchestrator.CheckInFeedback` nimmt das neue Feld als reinen
  Durchreich-Wert auf, bewusst ohne eigene `Concern`-Logik dafür (offene, separate Entscheidung).

  **Code/Data-Abnahme (Implementiert + Apple-kompiliert + Tests bestanden): ✅**
  Neues eigenständiges Modell `PeriodicCheckIn` (`Sources/FitnessAppData/`) ergänzt
  `WorkoutSession.sessionFeeling` (deckt nur "Belastung" ab) um die vier laut Audit fehlenden
  Fragen aus Dok03 §4: Häufigkeit/Dauer/Beschwerden/Ziel-noch-aktuell. Bewusst **user-global**,
  nicht an eine einzelne `TrainingPlan`-Instanz gebunden — "Ist dein Ziel noch aktuell?" betrifft
  den Nutzer, nicht einen bestimmten Plan, und mehrere gleichzeitig aktive Pläne (Task #201/#202)
  hätten sonst keine eindeutige Zuordnung. Jede der vier Fragen ist EINZELN überspringbar
  (`FrequencyFeedback?`/`DurationFeedback?`/`Bool?`, `nil` = ausdrücklich "übersprungen", nie
  "Nein" oder ein anderer erratener Wert) — exakt wie vom Audit gefordert ("eigene, schlanke UI
  ... jede überspringbar", **ausdrücklich NICHT** als zweiter Start-Check oder Erweiterung von
  `BaselineCheckFlowView`, keine Leistungstest-Fragen).
  **Nebenfund beim Bau entdeckt und umschifft:** `CSVRow.bool(_:)` liest eine leere CSV-Spalte als
  `false` (etabliertes, für Bestandsfelder korrektes Verhalten) — für die beiden echten
  Ja/Nein/Keine-Angabe-Fragen dieses Features (`hadComplaints`/`goalStillCurrent`) wäre das eine
  stille Umdeutung von "übersprungen" zu "Nein" gewesen, also exakt die Art Fehler, die das
  Gesamtmandat durchgängig ausschließt. Eigener, strikt dreiwertiger `optionalSkippableBool`-Parser
  in `DataImportService` behebt das gezielt, ohne den bestehenden `CSVRow.bool`-Vertrag für dessen
  andere, unveränderte Aufrufer anzutasten.
  CSV-Export/Import additiv um eine neue Datei `periodic_checkins.csv` erweitert (nicht nur eine
  Spalte, da eine komplett neue Entität) — Import ist nil-sicher für alle vier Antwortfelder.
  **Nebenfund #2, bei Vorbereitung des TestingBot-Laufs dieser Runde per Code-Review entdeckt und
  behoben:** `PeriodicCheckInView` hatte als einziger Editor-Screen im gesamten UI-Refactor-Epos
  KEINEN Discard-Schutz — `onBack` rief bedingungslos `dismiss()`, ohne Dirty-Tracking. Behoben nach
  dem überall sonst etablierten Muster (`isDirty`, `showingDiscardConfirm`,
  `.discardChangesConfirmation`, `.deltiqSwipeBackEnabled(!isDirty)`); `save()` setzt das Formular
  jetzt bewusst in-place zurück (kein `dismiss()`), mit einer kurzlebigen `didJustSave`-Bestätigung
  statt des bis dahin toten `lastSavedAt`/Hinweis-Codes. Committed zusammen mit dem kombinierten
  Checkpoint als `92757bf`.
  **Nebenfund #3 — Klarstellung zu "alle fünf Fragen":** Per Code-Lesung von
  `ActiveWorkoutView.FinishWorkoutSheet` bestätigt, dass die 5. Frage ("Belastung", `SessionFeeling`)
  NICHT überspringbar ist — `@State private var selected: SessionFeeling = .okay` ist ein fest
  vorbelegter, nicht-optionaler Default ohne Skip-Pfad. Das ist bestehendes, von P6.3 unverändertes
  Verhalten dieser vorgelagerten Frage, nicht Teil dieses Features. Nur die 4 NEUEN Fragen
  (Häufigkeit/Dauer/Beschwerden/Ziel) waren zu diesem Zeitpunkt im strikten Sinn einzeln
  überspringbar. **Inzwischen durch die Nachbesserung oben (Commit `618e63e`) behoben** — siehe dort.
  **Kombinierter P6-Checkpoint (P6.1+P6.2+P6.3 zusammen, ein Codemagic-Lauf):** ein Apple-CI-Fund
  aus dem kombinierten Regressionstest wurde unterwegs gefixt — `XCTAssertEqual(_:_:accuracy:)`
  erhielt ein `TimeInterval?` statt `TimeInterval` (Linux kompilierte das fälschlich durch, Apples
  Toolchain lehnte zurecht ab); behoben per `try XCTUnwrap(...)` (Commit `e7a58ff`), dem bestehenden
  Muster der Datei folgend.
  **Apple-kompiliert:** `ios-app` + `swift-package` beide `success`, alle Steps grün, für den
  finalen kombinierten Stand (Commit `92757bf`, der `063cb90` + `e7a58ff` + den Discard-Fix
  zusammenfasst).
  **Tests bestanden:** 1308 Tests gesamt auf macOS grün (reale Ausführung auf Apples Toolchain
  per Codemagic — NICHT unter Linux ausgeführt; Linux bestätigt in dieser Codebasis grundsätzlich
  nur Kompilierbarkeit, wie der oben beschriebene `e7a58ff`-Fund selbst erneut zeigt). Darunter
  `testPeriodicCheckInPartialAnswersSurviveRoundtrip` und
  `testPeriodicCheckInFullySkippedStaysNilNotFalseAfterRoundtrip`, keine Fehlschläge.

  **UI-Abnahme: ✅ vollständig — Root Cause gefunden, Fix implementiert (Commit `ae003a6`),
  Apple-kompiliert, UND erneuter TestingBot-Lauf gegen alle 7 ursprünglich angeforderten
  Prüfpunkte erfolgreich.** Auf expliziten Wunsch dieser Runde wurde der TestingBot-Blocker
  gezielt untersucht, statt weitere identische Versuche ohne neue Hypothese zu fahren. Ergebnis:
  ein **echter, reproduzierbarer App-Bug**, keine TestingBot-Eigenart — gefunden, behoben, und
  die Behebung real auf einem Gerät/Simulator über TestingBot bestätigt.

  **Diagnoseweg (in dieser Reihenfolge, wie vorgegeben):**
  1. *Ausgeschlossene Ursachen* (bereits in der Vorrunde widerlegt): falsches/nicht-sichtbares
     Tap-Ziel (widerlegt durch Scroll + frischen Dump + präzisen Koordinaten-Tap auf eine
     verifiziert sichtbare Position), ein blockierender System-Alert (`acceptAlertIfPresent()`
     meldete `false`), zu kurze Wartezeit (bis zu 12s mit erfolgreichen Zwischen-Screenshots).
  2. *Appium-Log-Zeitrekonstruktion* (dieser Runde): Scroll → `source()` gelingt noch (1,5s) →
     Screenshot gelingt → präziser Koordinaten-Tap auf "Quick check-in" → ein WEITERER
     Screenshot gelingt weiterhin schnell (56ms) → der NÄCHSTE `source()`-Aufruf hängt exakt
     62066ms und scheitert mit `"XCTPerformOnMainRunLoop work timed out after 60.0s"` — ein
     bekanntes Signal dafür, dass der App-Hauptthread selbst nicht mehr reagiert (nicht primär
     ein Harness-Timing-Problem).
  3. *Bisektion gegen den Vor-Discard-Stand `063cb90`* auf einem eigenen, rein diagnostischen
     Zweig (`diag-p63-bisect-063cb90` — lokal wieder gelöscht; der Remote-Branch auf GitHub
     konnte mit den Push-Rechten dieser Sitzung nicht gelöscht werden und bleibt als erkennbar
     benannter Diagnose-Rest stehen): **identischer Hang reproduziert sich 1:1** — der Bug
     besteht unabhängig vom Discard-Guard-Nebenfund und unabhängig von jeder Änderung dieser
     Runde, er war bereits im allerersten P6.3-Commit vorhanden.
  4. *Gezielte `NSLog`-Instrumentierung* (auf demselben Diagnose-Zweig) an drei Stellen — Aufruf
     der `NavigationLink`-Destination-Closure, `PeriodicCheckInView.init()`, Betreten von
     `body` — lieferte den entscheidenden Befund: **alle drei Marker feuerten ca. 10.500 Mal
     in 75 Sekunden (~140×/Sekunde)**, UND DIES BEGANN BEREITS BEIM BLOSSEN ÖFFNEN von
     `SettingsAppExperienceView` (Tap auf "App & Workout Experience"), lange bevor "Quick
     check-in" überhaupt angetippt wurde. `PeriodicCheckInView` wurde also in einer
     Render-Endlosschleife immer wieder neu konstruiert und gerendert, was den App-Hauptthread
     vollständig sättigte — das erklärt exakt das beobachtete Verhalten (Screenshots über die
     Simulator-Compositor-Ebene gelingen weiter, der App-eigene Hauptthread aber reagiert auf
     nichts mehr, inkl. keiner sichtbaren Navigation und keinem `source()`-Abruf).

  **Root Cause:** `PeriodicCheckInView` deklarierte ein eigenes
  `@Query(sort: \PeriodicCheckIn.date, order: .reverse)`. Als Destination-Closure eines
  `NavigationLink` innerhalb von `SettingsAppExperienceView` wird dieser Closure-Typ bei jeder
  (offenbar auch spekulativen/vorausschauenden) Neubewertung des Eltern-Views neu konstruiert —
  und jede Neukonstruktion eines `@Query`-tragenden Views baut eine frische SwiftData-Beobachtung
  auf. Das zum Vergleich herangezogene, bereits erfolgreich TestingBot-verifizierte
  `dashboardCustomizationRow` (`NavigationLink { DashboardSettingsView(profile: profile) }` in
  derselben Datei) hat dieses Problem nicht, weil `DashboardSettingsView` sein Profil als
  Parameter bekommt statt selbst zu queryen — das ist der entscheidende Unterschied.

  **Fix (Commit `ae003a6`):** `@Query` entfernt, ersetzt durch einen einmaligen
  `FetchDescriptor`-Fetch (`fetchLimit = 1`) in `.task`, der nur beim tatsächlichen Erscheinen
  des Screens läuft — nicht bei jeder (ggf. spekulativen) Konstruktion. `save()` aktualisiert den
  angezeigten Wert direkt, damit "zuletzt gespeichert" weiterhin sofort reagiert.
  **Apple-kompiliert:** `ios-app` + `swift-package` beide `success`. **Tests bestanden:**
  1320/1320 auf macOS grün, keine Fehlschläge (Linux davor bereits 1094/1094 grün).

  **Bewertung gegen die Vorgabe "Ursache nicht ohne Beleg TestingBot oder der App zuschreiben":**
  die Ursache liegt klar UND belegt in der App (Render-Endlosschleife, 140 Hz, beginnt vor jedem
  Tap auf "Quick check-in") — kein TestingBot-Artefakt. Dieser Bug hätte auch ein echter Nutzer
  getroffen (eingefrorener Screen bei blossem Besuch von Einstellungen → App & Workout
  Experience), es handelt sich also um einen echten Produktionsfehler, nicht nur ein
  Test-Problem.

  **Finaler TestingBot-Lauf mit dem gefixten Build (iPhone 15/iOS 18.0) — alle 7 ursprünglich
  angeforderten Prüfpunkte bestätigt:**
  - **Stabilitäts-Regressionscheck (der eigentliche Blocker):** `source()` direkt nach Erscheinen
    von `SettingsAppExperienceView` (genau die Stelle, an der die Render-Schleife vorher sofort
    einsetzte) dauerte **2002 ms** statt zuvor 60+ Sekunden zu hängen. Die gesamte Checkliste lief
    danach durchgehend ohne einen einzigen Hang oder Timeout durch.
  - ✅ Alle fünf Fragen erreichbar (Labels + 5× "Skip"-Button bestätigt im Dump).
  - ✅ Kein neuer Leistungs-Start-Check (keine Baseline-/Leistungstest-Begriffe im Dump).
  - ✅ Unbeantwortet bleibt unbekannt, nicht automatisch "false"/"keine Beschwerden" — bereits
    durch die Apple-Roundtrip-Tests (`testPeriodicCheckInFullySkippedStaysNilNotFalseAfterRoundtrip`)
    auf Datenebene bewiesen; UI-seitig zusätzlich bestätigt, dass der Screen frisch geöffnet ohne
    "Last saved on"-Kontext erscheint und erst nach einer echten Antwort als "geändert" gilt
    (siehe Discard-Test unten).
  - ✅ Speichern funktioniert; Bestätigungstext "Thanks for your feedback!" UND die Kontextzeile
    "LAST SAVED ON OCT 18, 2026" erscheinen nach dem Speichern.
  - ✅ Erneutes Öffnen zeigt den richtigen letzten Rückblick — ein drittes Öffnen nach dem
    Speichern zeigt weiterhin korrekt "LAST SAVED ON OCT 18, 2026".
  - ✅ Formular nach Speichern sinnvoll zurückgesetzt — indirekt, aber eindeutig bewiesen: das
    Verlassen des frisch zurückgesetzten Formulars löst KEINEN Discard-Dialog aus, was nur möglich
    ist, wenn `isDirty` nach dem Reset tatsächlich wieder `false` ist (dieselbe Zustandsvariable
    steuert auch die optische Hervorhebung der Picker).
  - ✅ Zurück/Verwerfen-Schutz funktioniert vollständig: Antwort setzen → Zurück → Discard-Dialog
    erscheint → "Keep Editing" bringt zum weiterhin offenen, unverändert ausgefüllten Formular
    zurück → erneut Zurück → "Discard" verwirft tatsächlich und verlässt den Screen.

  **Methodischer Nebenfund bei der Verifikation (kein App-Bug):** die erste Fassung des
  Test-Skripts prüfte den Picker-Auswahlzustand über ein vermutetes `selected="true"`-XML-Attribut
  und das Vorhandensein von `"Last saved on"` (Kleinschreibung) — beides schlug fehl, weil (a)
  `DeltiqSegmentedPicker` (Theme.swift) die Auswahl rein visuell über Hintergrundfarbe vermittelt,
  ohne eigenen Accessibility-Trait, und (b) `DeltiqContextRow` den Text tatsächlich als
  `"LAST SAVED ON ..."` (durchgehend großgeschrieben) rendert. Mit korrigierter, direkt am
  rohen XML-Dump verifizierter Prüflogik bestätigen sich alle obigen Punkte eindeutig.

  **Separater, nicht blockierender Accessibility-Nebenfund:** weil `DeltiqSegmentedPicker` seine
  Auswahl nur über Farbe (kein Accessibility-Trait) anzeigt, kann VoiceOver nicht erkennen, welches
  Segment aktuell gewählt ist — betrifft die komponente app-weit, nicht nur P6.3, vorbestehend,
  eigenständig zu beheben (siehe spawnte Aufgabe). Zusätzlich verwenden die Antworten
  "Duration = Just right" und "Exertion = appropriate" denselben sichtbaren Text "Just right" /
  "Passend" — für Sehende im Kontext der jeweiligen Frage eindeutig, für automatisiertes Testen
  und VoiceOver ohne zusätzlichen Kontext aber nicht eindeutig unterscheidbar; ebenfalls als
  eigenständige Nachbesserung vorgemerkt, kein Blocker für diese Abnahme.

  **Aufräumen:** der rein diagnostische Zweig `diag-p63-bisect-063cb90` wurde lokal gelöscht; der
  Remote-Branch auf GitHub konnte mit den Push-Rechten dieser Sitzung nicht gelöscht werden und
  bleibt als erkennbar benannter, inhaltsloser Diagnose-Rest bestehen (enthält nur die temporäre
  `NSLog`-Instrumentierung, keine produktiven Änderungen).
- (Stufe-2-Inhalts-Snapshot `TrainingDayContentRecord` bewusst erst für P8 relevant, nicht P7.)

**P7 — Vier-Wochen-Rückblick, Stufe 1 (groß, abhängig von P6):**
- P7.1 ✅ **Review-Orchestrator vollständig abgenommen** (Commit `0298041`, 2026-10-18): reine,
  deterministische Core-Funktion (`FourWeekReviewOrchestrator`, wie `DeloadAdvisor` ohne SwiftData/
  `Date()`/`Calendar.current` im Code-Pfad) bündelt Deload-/Comeback-/Soll-Ist-Signale und das
  periodische Check-in-Feedback zu EINEM Befund (`keepAsIs` vollwertig, nicht nur "kein Problem
  gefunden", oder `concernsFound([Concern])`), statt mehrere widersprüchliche Einzelempfehlungen
  nebeneinander zu zeigen (F08). Löst selbst nichts aus — reine Auswertung. Die neu eingeführte
  `>30%`-Teilnahmeschwelle (`significantMissedRatioThreshold`) ist ausdrücklich als **vorläufige
  PRODUKTREGEL dokumentiert, keine wissenschaftliche Grenze**, und löst von sich aus KEINE
  automatische Last-/Planänderung aus (bindende Vorgabe dieser Runde).
  **Implementiert + Apple-kompiliert + Tests bestanden:** `ios-app` + `swift-package` beide
  `success`, 1320/1320 Tests auf macOS grün. **UI-verifiziert:** nicht zutreffend — reine
  Core-Logik ohne eigene UI-Oberfläche (die Darstellung folgt in P7.2).
- P7.2 Review-UI "Deine ersten vier Wochen" (Commit `fbb4abe`, 2026-10-18) —
  **Code/Data-Abnahme ✅, UI-Abnahme ⏳ noch ausstehend, getrennt ausgewiesen:**

  **Code/Data-Abnahme (Implementiert + Apple-kompiliert + Tests bestanden): ✅**
  `FourWeekReviewAssembler` (`Sources/FitnessAppData/`) übersetzt reale SwiftData-Objekte in die
  Eingabe von `FourWeekReviewOrchestrator` (P7.1) — reiner Daten-Zubringer, trifft selbst KEINE
  Progressions-/Deload-Entscheidung. Verwendet ausschließlich bereits bestehende, produktiv
  genutzte Bausteine: `PlanParticipationEvaluator` (P6.2) für den Soll-Ist-Vergleich,
  `DeloadAdvisor.shouldRecommendDeload` mit **identischer Herleitung** wie
  `DashboardView.shouldRecommendDeload` (keine zweite, abweichende Berechnung), `AbsenceDeload.assess`
  (bereits produktiv für den Trainings-Start-Comeback-Dialog genutzt) für das Comeback-Signal, und
  den zuletzt gespeicherten `PeriodicCheckIn` (P6.3) — explizit **keine neue, konkurrierende
  Progressions-/Deload-Logik**.
  `FourWeekReviewView` (`Sources/FitnessAppUI/`) zeigt das Ergebnis. Bewusst **kein `@Query`** auf
  dieser View — Lehre direkt aus dem gerade behobenen P6.3-Blocker (`@Query` als
  `NavigationLink`-Destination verursachte dort die Render-Endlosschleife); stattdessen einmaliger
  Fetch über `.task { FourWeekReviewAssembler.assemble(in:) }`. "Plan passt – beibehalten"
  (`keepAsIsCard`) ist ein vollwertiger, positiver Kartentyp, keine blosse Leerdarstellung.
  **Vorschläge werden nie automatisch angewendet:** Deload läuft über einen eigenen
  Bestätigungsdialog (`showingDeloadConfirm` → `DeloadManager.startDeload`), Comeback über das
  bereits bestehende, produktiv genutzte `ComebackPromptSheet` (dieselbe Komponente wie beim
  Trainingsstart) → `AbsenceDeload.apply`/`.remember` — beide rufen ausschließlich bestehende
  Apply-Funktionen auf. Neuer, rein manueller Einstiegspunkt in `SettingsAppExperienceView`
  (automatisches Fällig-/Snooze-Verhalten bewusst P7.3 vorbehalten). 28+1 neue
  Lokalisierungsschlüssel (`fourWeekReview.*`, `settings.fourWeekReview.row`).
  4 neue Regressionstests (`FourWeekReviewAssemblerTests`): kein Plan vorhanden → `keepAsIs` +
  Datenlücken statt erfundenem Befund; vollständig eingehaltener Plan → `keepAsIs`, keine
  Datenlücken; Teilnahme deutlich unter Plan → `concernsFound` inkl. `participationBelowPlan` UND
  `noCheckInYet` als Datenlücke (kein Check-in wird nie stillschweigend als "keine Beschwerden"
  interpretiert); zwei `PeriodicCheckIn`-Einträge → beweist, dass der NEUERE Eintrag ausgewertet
  wird, nicht der erstgefundene.
  **Apple-kompiliert:** `ios-app` (Build `6ad430bcb33965d444a11384`) + `swift-package` (Build
  `6ad430bc740edec2d1e71c39`) beide `success`, alle Steps grün.
  **Tests bestanden:** Codemagic-Testlog bestätigt, dass alle 4 neuen Tests tatsächlich liefen
  (`testCompliantPlanWithGoodCheckInYieldsKeepAsIs`,
  `testHeavilyMissedParticipationIsSurfacedAsConcern`,
  `testNoActivePlanYieldsKeepAsIsWithDataGapsNeverFabricated`,
  `testLatestCheckInFeedbackIsAssembledFromRealData`), 1324 Tests gesamt auf macOS grün (1320 davor
  + diese 4), keine Fehlschläge. Linux zeigt weiterhin dieselbe seit P6.3 bekannte, jetzt erneut
  bestätigte Einschränkung: `@MainActor`-SwiftData-Testklassen kompilieren unter Linux, laufen dort
  aber nicht aus (gegen die bestehende `DataPortabilityRoundtripTests`-Klasse cross-verifiziert) —
  real ausgeführt wurden sie ausschließlich auf Apples Toolchain.

  **UI-Abnahme: ❌ blockiert — neuer, schwerwiegender Hang-Bug gefunden, Diagnose läuft, noch
  nicht gelöst.** Der erste TestingBot-Lauf gegen `FourWeekReviewView` zeigte exakt dasselbe
  Symptom wie der ursprüngliche P6.3-Blocker (`XCTPerformOnMainRunLoop work timed out after
  60.0s` bei `source()`, kein sichtbarer Navigationswechsel, Screenshot bleibt auf "App & Workout
  Experience" stehen) — diesmal beim Tippen auf die NEUE Zeile "Four-week review". Auf ausdrücklichen
  Wunsch dieser Runde wurde NICHT einfach wiederholt getestet, sondern gezielt mit neuer werkzeuggestützter
  Instrumentierung diagnostiziert (gleiche Methodik wie P6.3: Appium-Log-Zeitauswertung, gezielte
  `NSLog`-Marker, Bisektion einer konkreten Hypothese).

  **Befund 1 (Appium-Log, Beleg):** Der Klick auf "Four-week review" selbst dauerte 10,5 s
  (normal: 0,8–1,1 s), der unmittelbar folgende `source()`-Aufruf hing 62 s und scheiterte mit
  demselben `XCTPerformOnMainRunLoop`-Fehler wie bei P6.3.

  **Befund 2 (gezielte `NSLog`-Instrumentierung in `FourWeekReviewView` + der
  `NavigationLink`-Destination-Closure in `SettingsAppExperienceView`, Beleg):** Die
  Destination-Closure sowie `FourWeekReviewView.init()`/`body` feuerten ca. 6.860 Mal in rund
  14 Sekunden (~490 Hz) — **`reload()`/`.task` liefen dabei KEIN EINZIGES MAL** (0 Treffer für die
  eigenen `reload-start`/`reload-end`-Marker). Die View wird also in derselben Art
  Render-Endlosschleife wie bei P6.3 ständig neu konstruiert, OHNE jemals ihren `.task`-Lebenszyklus
  zu erreichen. **Das widerlegt teilweise die bisherige P6.3-Diagnose:** `FourWeekReviewView`
  deklariert bewusst KEIN `@Query` (siehe oben) — die Render-Endlosschleife tritt trotzdem auf.
  `@Query` als alleinige/notwendige Ursache der P6.3-Bugklasse ist damit widerlegt; die eigentliche,
  tiefere Ursache liegt an anderer Stelle im `NavigationLink`/Eltern-View-Mechanismus von
  `SettingsAppExperienceView` und war durch den P6.3-Fix nur für `PeriodicCheckInView` *zufällig*
  unschädlich geworden (weil dessen Rekonstruktion seither "billig" ist), nicht grundsätzlich behoben.

  **Befund 3 (Bisektion, widerlegte Hypothese, ebenfalls Beleg):** `SettingsAppExperienceView`
  hat SELBST ein bislang unbeachtetes `@Query private var profiles: [UserBodyProfile]` (verwendet
  für `dashboardCustomizationRow`/`DashboardSettingsView`). Hypothese: dieses `@Query` sei der
  Treiber. Test: `@Query` durch einmaligen `FetchDescriptor`-Fetch in `.task` ersetzt (identisches
  Fix-Muster wie P6.3), neu gebaut, erneut mit TestingBot verifiziert — **Ergebnis: kein
  Unterschied** (~8.090 Marker in vergleichbarem Zeitfenster, der Hang bleibt). Diese Hypothese ist
  damit widerlegt, nicht die Ursache.

  **Befund 4 (feingranulare Zähler statt NSLog-pro-Aufruf, Beleg — korrigiert Befund 2
  methodisch):** Auf ausdrücklichen Hinweis dieser Runde wurde das Logging selbst auf einen
  begrenzten Snapshot (ein `NSLog` alle 300 ms, nicht pro Ereignis) umgestellt, um auszuschließen,
  dass die Messung die Last selbst erzeugt. Ergebnis: **kein 490-Hz-Dauersturm.** Stattdessen
  zeigen sich wenige, aber lange (10–14 Sekunden) Stillstände, in denen selbst der eigene
  300-ms-Snapshot-Timer aussetzt, gefolgt von kurzen Schüben (z. B. +9 Rekonstruktionen auf
  einmal). Die ursprüngliche ~490/s-Zahl aus Befund 2 war wahrscheinlich ein Artefakt des dichten
  NSLog-pro-Aufruf-Loggings selbst — das bestätigt die methodische Sorge, mit der diese Runde
  eingeleitet wurde.

  **Befund 5 (Kontrollversuch, isolierter Einstieg, Beleg — zentraler Fund):** `FourWeekReviewView`
  wurde testweise zusätzlich DIREKT von `SettingsView` aus verlinkt, unter Umgehung von
  `SettingsAppExperienceView`. **Ergebnis: vollständig fehlerfrei** — der Screen rendert sofort
  korrekt (Titel, "Your plan fits – keep going!", Datenlücken-Karte), kein Stillstand. Eine
  MINIMALE statische Kontroll-Destination (ein einzelner `Text`) an der GLEICHEN Stelle wie die
  echte "Four-week review"-Zeile in `SettingsAppExperienceView` zeigt dagegen densel­ben
  Stillstand wie die echte Zeile. **Damit ist zweifelsfrei belegt: `FourWeekReviewView` selbst ist
  nicht die Ursache.** Das Problem hängt ausschließlich an `SettingsAppExperienceView` als
  Navigationsquelle (bzw. an der Navigationstiefe: zwei verschachtelte Pushes
  `SettingsView → SettingsAppExperienceView → Ziel` vs. nur einem `SettingsView → Ziel`).

  **Befund 6 (Hypothese geprüft und widerlegt, Beleg):** `SettingsAppExperienceView` ist der
  einzige Screen im Repo, der `.deltiqSwipeBackEnabled()` aufruft (`SwipeBackHostController`,
  einziger UIKit-Interop-Code im Projekt, installiert bei jedem `viewWillAppear` neu den
  `interactivePopGestureRecognizer`-Delegate). Test: genau diese eine Zeile entfernt, sonst nichts
  geändert, neu gebaut, mit identischem Testlauf erneut geprüft. **Ergebnis: kein Unterschied** —
  exakt dieselbe Zähler-Sequenz (0→2→11→14, Stillstände von ~14 s und ~11 s) wie im Lauf davor,
  bis auf die Sekunde reproduzierbar. Diese Hypothese ist damit widerlegt.

  **Befund 7 (Versuch ergebnislos, kein Beleg weder dafür noch dagegen):** Hypothese: `List`
  garantiert lazy ausgewertete `NavigationLink`-Destinations, `ScrollView`+`VStack` nicht — daher
  könnte die Umstellung auf `List` den Stillstand beseitigen. Test: `SettingsAppExperienceView`s
  Container probeweise auf `List` umgestellt (Optik bewusst nicht poliert, rein diagnostisch).
  **Ergebnis nicht auswertbar:** die so entstandene `List` (jede bestehende Sektion als EIN groß­er,
  direkt eingebetteter Custom-View pro Zeile statt einzelner nativer `List`-Zeilen) liess sich per
  Swipe-Geste nicht zuverlässig scrollen (10 Swipe-Versuche bewegten den sichtbaren Bereich nicht
  über die ersten drei Sektionen hinaus) — dadurch war weder die echte "Four-week review"-Zeile
  noch die statische Kontroll-Destination in dieser Testrunde erreichbar. Dies ist selbst ein
  nicht-blockierender Nebenfund (ein naiver `List`-Tausch ohne echte Pro-Zeile-Struktur macht den
  Screen potenziell unbedienbar), sagt aber NICHTS darüber aus, ob `List` den eigentlichen
  Stillstand beheben würde. Eine echte Prüfung bräuchte eine vollständige Restrukturierung in
  einzelne native `List`-Zeilen (kein Zeilen-Diagnose-Workaround), die über den Rahmen eines
  schnellen Diagnoseversuchs hinausgeht.

  **Offen, nicht spekulativ behauptet:** Die tatsächliche Ursache ist noch nicht gefunden. Beide
  `@Query`-Ebenen (Befund 3) und die UIKit-Swipe-Back-Interop (Befund 6) sind ausgeschlossen. Die
  fast identische Zähler-Sequenz über zwei unabhängige Code-Varianten hinweg (Befund 6) spricht
  eher für einen von unserem Anwendungscode UNABHÄNGIGEN, deterministischen Mechanismus als für
  einen klassischen Render-Loop im eigenen Code — zwei nicht belegte, aber plausible Kandidaten,
  die als Hypothesen offen bleiben: (a) ein SwiftUI/`NavigationStack`-Verhalten speziell bei
  zwei verschachtelten Pushes mit `NavigationLink`-in-`ScrollView` (statt `List`) auf der
  mittleren Ebene, oder (b) eine periodische Hintergrundaktivität von WebDriverAgent/XCTest
  selbst (z. B. App-Zustands-Polling), die SwiftUI zur Neuauswertung zwingt. Eine echte
  Stack-Sample-/Time-Profiler-Aufnahme zum Hang-Zeitpunkt war in dieser Umgebung nicht möglich
  (kein Instruments/Xcode-GUI-Zugriff, nur TestingBot-WebDriver) — diese Grenze wird hier
  ausdrücklich benannt statt stillschweigend übergangen. Eine statische Suche nach einem
  wiederholten Schreiber auf `UserBodyProfile` fand weiterhin keinen Treffer.

  **Tragweite:** Dieser Fund betrifft potenziell nicht nur die neue P7.2-Zeile, sondern den
  gesamten `SettingsAppExperienceView`-Screen — die bereits abgenommene "Quick check-in"-Zeile
  (`PeriodicCheckInView`, P6.3) wurde mit der NEUEN, feingranularen Instrumentierung noch nicht
  erneut geprüft; nach aktuellem Stand ist offen, ob sie von demselben Mechanismus betroffen, aber
  wegen geringerer Kosten pro Rekonstruktion nicht sichtbar ist, oder ob sie tatsächlich
  unbetroffen bleibt.

  **Diagnose-Zweige (temporär, enthalten nur Instrumentierung, keine Produktivänderungen):**
  `diag-p72-fourweekreview-hang` (vier Commits: NSLog-Instrumentierung, widerlegte
  `profiles`-Bisektion, feingranulare Zähler + Kontrollen, widerlegte
  `deltiqSwipeBackEnabled()`-Hypothese) — auf GitHub gepusht, noch nicht aufgeräumt, da die
  Diagnose nicht abgeschlossen ist.

  **P7.2 bleibt bis zur Behebung dieses Blockers UI-seitig offen.** Code/Data-Abnahme (oben) ist
  und bleibt davon unabhängig gültig.
- P7.3 Review-Zustandsfeld (zuletzt reviewed/fällig/Entscheidung) — noch nicht begonnen.

**P8 — Spätere Block-Reviews, Stufe 3** — zurückgestellt bis P7 + vollständige Stufe-2-Versionierung
stehen.

**P9 — Verifikation, Regression, Dokumentation (laufend):**
- RIR-Layout auf echtem Gerät/Simulator bei größter Dynamic-Type-Stufe verifizieren (Code ist
  fertig, reine Verifikation).
- Entscheidung zum UI-Test-Target: weiter manuelle TestingBot-Spotchecks (etabliertes, aber
  teures Verfahren) oder echtes `XCUITest`-Target aufsetzen — sollte vor P3/P4 geklärt werden, da
  diese Phasen die meisten neuen UI-Interaktionen einführen.
- Dead-Code-Audit als wiederkehrenden Schritt nach jedem i18n-Refactor re-etablieren.

## Nicht abschließend geklärt (an mehreren Stellen von den Teilaudits selbst benannt)

- Reale Geräteverifikation (Dynamic Type, Light/Dark, kleine Displays, VoiceOver) ist aus dieser
  Linux-Sandbox grundsätzlich nicht möglich — betrifft RIR-Layout, Wocheneditor-Bedienbarkeit,
  Dynamic-Type-Fallbacks in `PlanBuilderView`/`PlanEditorView`.
- Vollständiger Feld-für-Feld-Abgleich aller 12 Export/Import-CSV-Dateien wurde nur stichprobenartig
  geprüft, nicht vollständig.
- Ob `TrainingDay.generationFingerprint`/`currentContentFingerprint` für eine künftige
  Inhalts-Versionierung (Stufe 2) taugt, wurde bewusst nicht vertieft (für Stufe 1 nicht nötig).
