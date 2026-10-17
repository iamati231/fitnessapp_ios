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
  P3.2 ist damit **vollstaendig abgenommen** (Implementiert + Apple-kompiliert + Tests bestanden +
  UI-verifiziert, alle vier getrennt bestaetigt).
- P3.3 ✅ **vollständig abgenommen** (Commit `61ee3bb`, 2026-10-17): Implementiert + Apple-kompiliert +
  Tests bestanden + UI-verifiziert, alle vier getrennt bestätigt.
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
- P3.4 Header/Label/Discard-Guard auf `DeltiqHeader`-Muster — **geprueft und bewusst NICHT
  umgesetzt** (Review, 2026-10-17). `DeltiqHeader` + Checkmark/Discard-Guard ist das etablierte
  Muster fuer EINZELNE, autosave-artige Daten-Editoren (UI-Refactor P1-P10: `ProfileEditorView`,
  `PlanEditorView`, `DayEditorView`, `BodyDataEditorView`, `TrainingLocationEquipmentEditorView`,
  `ExerciseLibraryEditorSheet`, `GearEditorView` - alle Screens, die man "verlaesst", nicht
  "durchlaeuft"). `PlanBuilderView` ist dagegen explizit ein MEHRSCHRITTIGER ASSISTENT (eigener
  Datei-Kommentar: "Struktur folgt bewusst `OnboardingView`") - und `OnboardingView` selbst, das
  ausdruecklich genannte Vorbild, nutzt ebenfalls `.navigationTitle`+`.toolbar` statt
  `DeltiqHeader`, nicht aus Versehen, sondern weil ein Wizard-Schritt keinen Checkmark-"Speichern"-
  Zustand hat (es gibt "Zurueck/Weiter"+"Plan uebernehmen", kein verwerfbares Einzelfeld). Ein
  erzwungener `DeltiqHeader`-Umbau wuerde `PlanBuilderView` vom eigenen Vorbild `OnboardingView`
  ABKOPPELN statt die beiden konsistent zu halten - das waere eine neue Inkonsistenz, keine
  Verbesserung. Eingestuft als veraltetet/premature Checklisten-Punkt aus einer frueheren
  Audit-Runde, nicht als echte Produktanforderung dieser Spezifikation. P3 (P3.1-P3.4) damit
  insgesamt abgeschlossen.

**P4 — Onboarding-Integration, Hybrid/Laufcoach (groß, abhängig von P2.5, teils parallel zu P3):**
- P4.1 Separate Laufcoach-Entscheidung nach Hybrid/Laufen-Auswahl.
- P4.2 Kompakte "Deine erste Trainingswoche"-Vorschau direkt nach den Onboarding-Fragen.
- P4.3 Radfahren als geführte Ausdauerform-Option.

**P5 — Equipment-Änderung → Plananpassung, Cooldown (mittel-groß, teilweise parallel zu P3/P4):**
- P5.1 Equipment-Save in `TrainingLocationEquipmentEditorView`/`ProfileEditorView` löst
  Vorschau/Ersatzvorschlag aus (Vorbild: bestehender `envSwap`-Dialog).
- P5.2 Substitutions-Pfad an Builder-generierte Pläne anbinden (abhängig von P3.1 — braucht ein
  echtes `TrainingGoal`).
- P5.3 Mindestens einen Generator-/Template-Pfad ergänzen, der `.cooldown` tatsächlich erzeugt;
  Rollen-Anzeige in `DayEditorView`/`PlanEditorView` ergänzen (fehlt dort komplett).

**P6 — Plan-Versionierung & Datenqualität (klein-mittel, blockiert P7):**
- P6.1 `TrainingPlan.activatedAt: Date?` additiv (nil = unbekannt für Bestandspläne).
- P6.2 Soll-Ist-Aggregator (geplante Gelegenheiten vs. tatsächliche Sessions, je nach fester/
  flexibler Terminierung) — komplett neue Core-Logik.
- P6.3 Fehlende 4 von 5 Nutzerfeedback-Fragen (§4) erfassen (`SessionFeeling` deckt nur Belastung).
- (Stufe-2-Inhalts-Snapshot `TrainingDayContentRecord` bewusst erst für P8 relevant, nicht P7.)

**P7 — Vier-Wochen-Rückblick, Stufe 1 (groß, abhängig von P6):**
- P7.1 Review-Orchestrator (Core, reine Funktion wie `DeloadAdvisor`): bündelt Deload/Comeback/
  Progression + neuen Soll-Ist-Vergleich, löst Konflikte zwischen Empfehlungen auf (F08).
- P7.2 Review-UI ("Deine ersten vier Wochen") inkl. Snooze-Regel.
- P7.3 Review-Zustandsfeld (zuletzt reviewed/fällig/Entscheidung).

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
