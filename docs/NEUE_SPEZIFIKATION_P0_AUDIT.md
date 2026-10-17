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

Konsolidierter Codemagic-Build über alle 4 Commits zusammen: `6ad3c031` (angestoßen, Ergebnis siehe
unten im Abschlussvermerk).

**P2.5 — PlanningContext/EnduranceModality verdrahten (klein-mittel, Vorbedingung für P3/P4):**
Core-Typ ist fertig und getestet, es fehlt die Persistenz (additives Feld auf `UserBodyProfile`)
und die erste echte Instanziierung außerhalb von Tests.

**P3 — A+B-Builder & Wocheneditor (groß, abhängig von P2.5):**
- P3.1 Zielorientierter Einstieg (4 Zielkarten → `TrainingGoal`, inkl. Entsperrung `.endurance`).
- P3.2 Visueller Wocheneditor (Drag&Drop + "Verschieben nach…", gebunden an `PlanDraft`).
- P3.3 Fixierungs-UI (Inhalt/Position getrennt).
- P3.4 Gezielte Alternativen (zuerst Alternative 1 über `replaceContent`, dann 2 und 3).
- P3.5 Header/Label/Discard-Guard auf `DeltiqHeader`-Muster umstellen.

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
