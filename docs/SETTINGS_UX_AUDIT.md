# Settings UX Audit

Phase 1 des Settings-Epics (`SETTINGS_FULL_REVIEW_AND_IMPLEMENTATION.md`, ersetzt/erweitert die frühere `SETTINGS_BODY_AND_EQUIPMENT_TASK.md`). Reine Bestandsaufnahme — **keine Code-Änderung in dieser Phase.**

**Methode:** 6 parallele Audit-Agents, jeweils mit Volltext-Lektüre der Zieldateien und Pflicht zur Datei:Zeile-Belegung pro Fund.

**Geprüfter Umfang:** `SettingsView` + `DashboardSettingsView` · `ProfileEditorView` + Körperdaten-Modelle (`UserBodyProfile`, `BodyMeasurement`, `MeasurementView`) · Reminder-Einstellungen + `ReminderPreferencesApplier` · `DataExportView`/`BackupListView`/`DataImportView` + Export/Backup/Import-Services + `SettingsPortability` · `HealthWorkoutWriteView`/`HealthAppLink` + Health-Services · `GearListView`/`ExerciseLibraryView`(+`EditorSheet`)/`ExerciseMediaCreditsView`.

**Legende**
- **Priorität:** P0 = Datenverlust/-korruption oder irreversible Aktion ohne Schutz · P1 = funktionale Inkonsistenz / bedeutsame UX-Falle · P2 = Politur (Accessibility, Wording, Edge Case).
- **Status:** `open` (noch nicht behoben) · `entschieden` (Rückfrage beantwortet, Umsetzung steht an) · `OK` (geprüft, kein Änderungsbedarf).

---

## Teil 1 — Priorisierte Befundliste (maschinenlesbar)

| ID | Bereich | Datei:Zeile | Prio | Befund | Vorschlag | Phase | Status |
|---|---|---|---|---|---|---|---|
| PE-G2 | Profil/Körperdaten | `ProfileEditorView.swift:146-166` (`.onChange`), Query `:50-51` | **P0** | Trainingsort-Wechsel überschreibt `targetEnvironment` **aller** Pläne (auch archivierter — `allPlans`-Query hat kein `isActive`-Filter) synchron und ohne Dialog, bevor überhaupt eine Bestätigung erscheint. Zweite Stufe (Bestätigungsdialog) erscheint nur, wenn mind. ein Plan aktive Übungen hat — sonst läuft die Mutation **ganz ohne** Dialog durch. "Nein, so lassen" stellt den Ursprungszustand **nicht** wieder her (kein Undo-Pfad). Laut Code-Kommentar deliberate ("Profil ist Source of Truth"), aber ohne Schutz für Altpläne. | Stufe 1 (promptloser Bulk-Sync) entfernen; Stufe 2 bleibt die einzige Stelle, die `targetEnvironment` ändert, nur noch nach expliziter Bestätigung | P2 | **behoben** (Phase 2) |
| PE-FFM | Profil/Körperdaten | `BodyMeasurement.swift:105-160` (`makeDerived`), Call-Site `OnboardingView.swift:1845-1850` | **P0** | `makeDerived` berechnet KFA/FFM/FFMI unbedingt per Deurenberg-BMI-Fallback, auch ganz ohne Umfänge. Onboarding ruft das bereits produktiv auf (0 Umfänge dort je erfasst) — **jede** Tag-1-Messung aller Bestandsnutzer trägt einen erfundenen Wert, der auf dem Dashboard als echt angezeigt wird. | Neuer `makeWeightOnly`-Service ohne Fallback-Kette; Onboarding umstellen; Altdaten per Migration bereinigen | P2 | **behoben** (Phase 2) |
| PE-B1/G1 | Profil/Körperdaten | `ProfileEditorView.swift:477-507` | P1 | Größe und Zielgewicht in getrennten Cards, aktuelles Gewicht nirgends in diesem Screen sichtbar (0 Treffer für ein Gewichts-Ist-Feld) | Kombinierte Höhe/Gewicht/Zielgewicht-Karte, Gewicht aus `BodyMeasurement` gelesen (wie Dashboard/MeasurementView) | P3 | open |
| PE-H1 | Profil/Körperdaten | `ProfileEditorView.swift:306-441` | P1 | HealthKit-"Übernehmen"-Button überschreibt Geburtsdatum/Geschlecht/Größe unbedingt, ohne Bestätigung, ohne Undo | Bestätigungsschritt vor dem Übernehmen ergänzen | P4 | open |
| PE-P1 | Profil/Körperdaten | `ProfileEditorView.swift:447-453`, `BodyMeasurement.swift` | P2 | Geschlechts-Änderung berechnet vorhandene `BodyMeasurement`-Ableitungen (Navy/Deurenberg/FFMI) nicht neu — bleiben unter altem Geschlecht eingefroren | Hinweistext ergänzen, kein Code-Zwang nötig | P3 | open |
| DX-02c | Daten/Export | `DataExportView.swift:239-275`, `DataExportService.swift` | **P0** | Export läuft komplett synchron auf MainActor (Kommentar behauptet `Task.detached`, Code tut es nicht) — UI friert für die volle CSV/ZIP-Dauer ein | Fetch bleibt Main, dann Sendable-DTOs bauen, CSV/ZIP-Arbeit off-Main | P5 | open |
| BL-07 | Daten/Backup | `BackupListView.swift:278-289` | **P0** | `createNow()` ist komplett synchron, kein `Task{}` — UI friert schlimmer ein als beim Export | Gleiches DTO-Snapshot-Muster wie DX-02c | P5 | open |
| DI-03 | Daten/Import | `DataImportView.swift:600-648` | **P0** | `loadPreview` läuft synchron bei jeder Dateiauswahl — entpackt+parsed das ganze ZIP auf Main, UI friert bei **jeder** Dateiwahl ein | In `Task{}` verschieben (reine Daten, kein `ModelContext` nötig) | P5 | open |
| BL-03 | Daten/Backup | `BackupListView.swift:274-276`, `BackupService.swift:209-212` | **P0** | `(try? listGenerations()) ?? []` — echter Lesefehler ununterscheidbar von "keine Backups", genau das Panic-Szenario, für das der Screen existiert | Echte I/O-Fehler durchreichen, eigener Error-State statt wiederverwendetem Empty-State | P5 | open |
| BL-05 | Daten/Backup | `BackupListView.swift:182-197` | **P0** | Backup löschen: ein Tap, keine Bestätigung, irreversibel; Fehler verschluckt (`try?`); Tap-Ziel 32×32pt (< 44pt-Minimum) | Eigener `confirmationDialog`, Fehler anzeigen, Tap-Ziel vergrößern, `.accessibilityLabel` mit Datum | P5 | open |
| RS-02 | Daten/Reset | `SettingsView.swift:816-919` | **P0** | "App zurücksetzen" ist die einzige destruktive Aktion ohne automatisches Vorab-Backup | Automatisches Backup vor dem Löschen | P5 | **entschieden** — ja, automatisch sichern |
| GEAR-05 | Gear | `GearListView.swift:113-124,162-164` | **P0** | Gear löschen ohne Bestätigung, ein Tap, Kilometerstand-Historie unwiderruflich weg (Workout-Sessions selbst bleiben, `.nullify`) | Bestätigungsdialog wie bei Custom-Exercise-Löschung | P6 | open |
| EXLIB-07/09 | Bibliothek | `ExerciseLibraryEditorSheet.swift:180-200`; `Exercise.swift:15`, `ExerciseLog.swift:40`, `PersonalRecordEntry.swift:27` | **P0** | Umbenennen einer eigenen Übung bricht Verlaufs-/PR-Lookup und Plan-Anzeige für alle vorher geloggten Einträge — `name` wird beim Adoptieren kopiert, kein Rückbezug zu `ExerciseTemplate`. Kein Warnhinweis beim Umbenennen. Daten nicht verloren, nur unauffindbar (falsch-leer). | Stabile Referenz (ID) von `Exercise`/`ExerciseLog`/`PersonalRecordEntry` zurück zu `ExerciseTemplate` | P6 | **entschieden** — jetzt sauber beheben (Schema-Änderung) |
| SV-F01 | Settings | `SettingsView.swift:245-261` vs. `:857` / `SettingsPortability.swift:33` | P1 | `weight_unit` ist laut Portability-Whitelist "echte Präferenz", wird aber von Reset gelöscht — widerspricht Resets eigenem Kommentar | Default: als Präferenz behandeln, nicht löschen | P5 | open |
| SV-F07/08/09 | Settings/Dashboard | `Theme.swift` (`DeltiqControlRow`/`DeltiqRow`/`DeltiqHeaderAction`), alle Toggle/Picker/Icon-Buttons in `SettingsView.swift` + `DashboardSettingsView.swift` | P1 | Durchgängig fehlende `.accessibilityLabel` (Gegenprobe: `HealthWorkoutWriteView.swift` macht es im selben Ordner korrekt) | Labels pro Instanz ergänzen, **nicht** die shared Theme-Components anfassen | P6 | open |
| DX-03/04 | Daten/Export | `DataExportView.swift:183-195, 266, 294-306` | P1 | `lastDataExportAt` wird gesetzt bevor Share/Backup bestätigt ist; `ShareSheet` ohne Completion-Handler | Erst nach erfolgreichem `BackupService.store()` setzen | P5 | **entschieden** — Bedeutung = lokales Backup gespeichert |
| BL-08 | Daten/Backup | `BackupListView.swift:232-239` | P1 | Status-Text "Wird wiederhergestellt…" erscheint identisch auch beim reinen Backup-Erstellen | Eigener String je Operation (Enum statt `isWorking: Bool`) | P5 | open |
| DI-09 | Daten/Import | `DataImportView.swift:705-773`, `DataImportService.swift:352-360` | P1 | `performImport` durchgehend synchron ohne `await` — "live" Fortschrittsbalken kann nicht wirklich animieren | async + `Task.yield()` zwischen Phasen, oder ehrlicher Indeterminate-Spinner | P5 | open |
| R-08 | Health | `HealthWorkoutWriteView.swift:242-250` | P1 | Diagnose-String unlokalisiert und ungated im **häufigen** `.blocked`-Normalfall gezeigt; Kommentar sagt "nur TestFlight", kein Guard | Hinter "Diagnose anzeigen"-Disclosure verstecken + lokalisieren | P4 | open |
| REM-01 | Reminder | `SettingsView.swift:459-529` | P1 | Reminder-Toggles lesen nie den echten OS-Benachrichtigungsstatus — anders als strukturell identische `healthKitSection` (`SV-21`) | OS-Status aktiv abfragen, analog `healthKitSection` anzeigen | P4 | open |
| REM-02 | Reminder | `ReminderPreferencesApplier.swift` + Onboarding-Re-Init-Pfad | P1 | Resets Zusage "Reminder-Prefs bleiben erhalten" wird durch hartkodierte Re-Init bei erzwungenem Re-Onboarding gebrochen | Re-Onboarding darf vorhandene, nicht-default Reminder-Prefs nicht überschreiben | P4 | open |
| GEAR-01 | Gear/Profil | `GearListView.swift:29`; `ProfileEditorView.swift:847,862` | P1 | Gear-Screen-Titel und Equipment-Sheet-Titel/`navigationTitle` beide identisch "Ausrüstung" | Gear-Screen-Titel um "& Schuhe" ergänzen (Settings-Zeile hat es schon) | P3 | open |
| GEAR-04 | Gear | `GearListView.swift:92-142` | P1 | Gear-Zeile nutzt `.onTapGesture` auf `VStack` statt `Button` — keine VoiceOver-Button-Semantik (Exercise Library macht es korrekt) | In `Button` einpacken | P6 | open |
| CREDITS-02 | Bibliothek | `ExerciseMediaCreditsView.swift:21-33` | P1 | Credits-Text behauptet "mit Erlaubnis gezeigt" als gesicherte Tatsache, stärker als die eigene `NOTICE-exercise-gifs.md` das stützt | Formulierung auf Quelle zurückführen ("laut Datensatz-Projekt"), nicht als eigene Zusicherung | P6 | open |
| RS-03a | Daten/Reset | `SettingsView.swift:913-919` vs. `DataImportService.swift:505-508` | P1 | Zwei unabhängig gepflegte "Alles löschen"-Sequenzen; Repo-README warnt bereits vor dem Drift-Risiko | Gemeinsamen `wipeAllPersistentModels`-Helper extrahieren | P5 | open |
| DX-05 | Daten/Export | `DataExportView.swift:199-210, 258` | P2 | `BackupService.store`-Fehler per `try?` verschluckt, Banner zeigt trotzdem "fertig" | Fehler nicht-blockierend zusätzlich anzeigen | P5 | open |
| SV-F02 | Settings | `SettingsView.swift:857` | P2 | `height_unit`/`unit_system` sind tote Keys | Aus Reset-Loop entfernen | P5 | open |
| SV-F13 | Settings | `HealthKitController.swift:24` | P2 | "Letzter Sync" nur In-Memory, verschwindet nach jedem Kaltstart | Persistieren oder als "diese Sitzung" kennzeichnen | P4 | open |
| EXLIB-02/03 | Bibliothek | `ExerciseLibraryView.swift:253-279,282-294` | P2 | Suche/Filter ohne Treffer rendert stumme leere Liste, kein "keine Treffer"-Hinweis | Expliziten No-Results-State ergänzen | P6 | open |
| R-24 | Health | `HealthKitController.swift:130-231` | P2 | Gewicht-Schreibstatus als Lese-Gate für andere Health-Typen zweckentfremdet — niedriges Realrisiko (ein gemeinsamer Consent-Dialog) | Nur relevant, falls Consent-Dialoge je getrennt werden | — | OK |

### Bereits korrekt — nicht anfassen

- `BodyMeasurement` ist bereits das alleinige Gewichts-Verlaufsmodell; `UserBodyProfile` hat kein eigenes Gewichtsfeld (nur `goalWeightKg`). Der neue `makeWeightOnly`-Service kann direkt darauf aufsetzen.
- Health: keine Fabrikation von Kalorien/Puls (App-Review-5.1.3(ii)-Kommentar im Code); ehrliche Teilergebnis-Anzeige bei Abbruch; Blind-Spot-Warnung bereits im UI; typ-spezifische Berechtigungen sauber getrennt.
- Import: Vorschau vor jedem Replace, zweistufige Append/Replace-Bestätigung, automatisches Vorab-Backup vor jedem Replace — unbedingt erhalten.
- Deload-Toggle (`SV-14`) und "Gesenkte Gewichte zurücksetzen" (`SV-15`) bereits sauber entkoppelt.
- Timer-Vorlauf zeigt bei 0 bereits "Aus"/"Off".
- Reset lässt Apple-Health-Daten nachweislich unangetastet, löscht bereits alle 11 SwiftData-Modelltypen vollständig.
- Custom-Exercise-**Löschen** ist bereits sicher: `Exercise`/`ExerciseLog`/`PersonalRecordEntry` halten keine Relation zu `ExerciseTemplate`, Löschen einer Vorlage kann keine Logs verwaisen lassen (im Unterschied zum Umbenennen-Bug `EXLIB-07/09`).
- System-Übungen sind im Editor-Sheet bereits echt read-only (keine Felder, kein Silent-Fail).
- Gear-Kilometerstand-Automatik, Re-Zuordnung, Verschleiß-Warnung, Export/Import/Reset bereits korrekt implementiert und (Re-Zuordnung) getestet.
- `DashboardSettingsView`: Autosave über `@Bindable` ist das etablierte App-Muster, kein Fehler.

---

## Teil 2 — Detailbefunde je Bereich

### 2.1 SettingsView + DashboardSettingsView

32 Zeilen in `SettingsView.swift`, 7 in `DashboardSettingsView.swift`. Reminder-Zeilen (`SV-16`…`SV-20`) liegen innerhalb von `SettingsView.swift` — die tieferen Service-Befunde dazu stehen in 2.5. Health-Status-Zeilen (`SV-21`…`SV-25`) sind reine Navigation; die editierbaren Toggles mit korrekten Accessibility-Labels liegen in `HealthWorkoutWriteView.swift` (2.4). Reset (`SV-32`) ist bereits die letzte Section im Scroll, aber nur farblich/ikonografisch abgehoben. `DashboardSettingsView`s Reorder/Edit-Header-Button (`DSV-01`) ist die schwerste Einzel-Accessibility-Lücke im gesamten Audit: komplett icon-only, kein Label in keinem der beiden Zustände.

### 2.2 Profil & Körperdaten (ProfileEditorView, UserBodyProfile, BodyMeasurement, MeasurementView)

Architektur-Fakt (Grundlage für Phase 2): `UserBodyProfile` hat **kein** eigenes Gewichtsfeld; `BodyMeasurement` ist bereits die alleinige Quelle für Gewichtsverlauf (kein Modell-Umbau nötig). `DataImportService.measurementKey` dedupliziert nur beim CSV-Import, nie beim Live-Save — erneutes Loggen desselben Gewichts ist bereits uneingeschränkt möglich.

**Weight-only-Lücken (für den neuen `makeWeightOnly`-Service), alle bestätigt:**
- `MeasurementView.canSave` verlangt Nacken+Taille(+Hüfte) **identisch** für Neu- und Bearbeiten-Modus (`MeasurementView.swift:948-957,975`) — "nur heutiges Gewicht loggen" ist aktuell unmöglich ohne Umfänge.
- Kein `source`-Feld auf `BodyMeasurement` — ein "Aus Apple Health"-Badge existiert nur als transienter `@State` während der laufenden Eingabe (`MeasurementView.swift:79,376-398`), wird nie persistiert.
- `HealthKitController.saveMeasurement` erwartet bereits optionale `bodyFatPct`/`fatFreeMassKg` zum gezielten Überspringen (`HealthKitController.swift:260-291`) — die aktuelle `?? ??`-Fallback-Kette an der einzigen Call-Site würde dort heute zufällig (aber fragil) nie greifen; der neue Weight-only-Pfad muss `nil` **explizit** übergeben, nicht die bestehende Kette wiederverwenden.
- Dashboard-Hero-Karten (`DashboardView.swift:607-695`) lesen FFMI/Lean-Mass nur von der **einen** neuesten Zeile — fällt nicht automatisch auf die letzte Zeile mit echtem Wert zurück. Wird relevant, sobald Weight-only-Zeilen existieren (sonst zeigt die neueste Zeile sofort "–", obwohl eine valide ältere Messung existiert).
- Bearbeiten-Modus einer Weight-only-Zeile braucht einen expliziten "als weight-only gespeichert"-Flag statt Ableitung aus "Felder sind gerade leer" (sonst könnte eine versehentlich geleerte Vollmessung fälschlich als weight-only durchgehen).
- Vollmessungs-Pfad (`canSave`, `makeDerived`-Call-Sites, DEL-219-Links/Rechts-Erhaltung) bleibt bei rein additiver Umsetzung unberührt — **muss** additiv bleiben, nicht in bestehende Funktionen hineinredigiert werden.
- Vorhandene Rundungs-/Formatierungs-Helfer (`roundsToWeightPrecision`, `Double.rounded(toDecimals:)`, `.formattedWeightInput()`) bereits korrekt für Gewicht im Einsatz — wiederverwenden, nicht neu bauen.

**`PE-H1`:** HealthKit-"Übernehmen" überschreibt Geburtsdatum/Geschlecht/Größe unbedingt und ohne Bestätigung (`ProfileEditorView.swift:410-441`) — schließt Gewicht bereits korrekt aus (Gewicht lebt ausschließlich in `BodyMeasurement`). Fehlt nur die Bestätigung vor dem Überschreiben der drei anderen Felder.

### 2.3 Daten-Export / Backup / Import / Reset

27 Zeilen vollständig ausgewertet. **Drei-Zustände-Verwechslung bei `lastDataExportAt`:** Datei erstellt (①, ephemer) → lokales Backup gespeichert (②, Fehler per `try?` verschluckt) → Nutzer hat extern geteilt (③, nie geprüft — `ShareSheet` ohne Completion-Handler) → `lastDataExportAt` wird aktuell **bei ①** gesetzt, lange vor ② und ③. Entschieden: Zukünftig erst nach ② setzen (siehe Teil 4).

**Concurrency:** `DataExportView.startExport`, `BackupListView.createNow`/`restore`, `DataImportView.loadPreview` laufen faktisch synchron auf MainActor, obwohl ein Kommentar `Task.detached` behauptet — nicht per Rename behebbar, da `ModelContext` nicht `Sendable` ist. Braucht echten DTO-Snapshot-Grenzzug (Fetch bleibt Main, CSV/ZIP-Bau off-Main) — von der Vorgabe selbst bereits gefordert.

### 2.4 Apple Health (HealthWorkoutWriteView, HealthAppLink)

25 Zeilen, nur **ein** P1-Fund (`R-08`, Diagnose-String), Rest P2 oder bereits korrekt. Bestätigt vorbildlich: ehrliche Teilergebnis-Anzeige bei Abbruch, Blind-Spot-Warnung im Vorschau-Screen, keine Kalorien-/Puls-Fabrikation, typ-spezifische Berechtigungen sauber getrennt. Terminologie-Fund (drei uneinheitlich benannte Lese-Berührungspunkte) ist von der Vorgabe selbst bereits entschieden ("Daten übernehmen" vs. "Trainings an Health senden") — reine Umsetzungsarbeit in Phase 4, kein Blocker.

### 2.5 Reminder (Wasser-/Messungs-Erinnerungen)

UI-Zeilen vollständig in 2.1 als `SV-16`…`SV-20` erfasst. Zwei tieferliegende Funde: `remindersSection` fragt nie den tatsächlichen OS-Benachrichtigungsstatus ab (anders als `healthKitSection`); Resets Zusage "Reminder-Prefs bleiben erhalten" wird durch hartkodierte Re-Init beim erzwungenen Re-Onboarding gebrochen.

### 2.6 Gear-Tracker, Exercise-Library, Media-Credits

**Gear (`GearListView`):** Kilometerstand-Automatik beim Workout-Abschluss, Re-Zuordnung zwischen Geräten, Verschleiß-Warnung, Export/Import/Reset — alles bereits korrekt implementiert (Re-Zuordnung sogar unit-getestet, `GearDistanceTests.swift`). Zwei echte Lücken: Löschen ohne Bestätigung (`GEAR-05`, P0) und Zeilen-Tap ohne Button-Semantik (`GEAR-04`, P1). Naming-Kollision mit dem Equipment-Profil-Sheet (`GEAR-01`): Settings-Zeile selbst sagt bereits korrekt "Ausrüstung & Schuhe", aber der Screen-eigene Header verkürzt auf bloßes "Ausrüstung" — identisch zum `ProfileEditorView`-Equipment-Sheet-Titel.

**Exercise Library:** System-Übungen sind im Editor-Sheet echt read-only (keine editierbaren Felder, kein Silent-Fail/Revert) — korrekt. Custom-Löschen ist sicher (keine Relation zu löschen, Logs bleiben unberührt) und hat bereits einen korrekten, akkuraten Bestätigungsdialog. Der echte Bug liegt beim **Umbenennen**: `Exercise.name`, `ExerciseLog.exerciseNameSnapshot`, `PersonalRecordEntry.exerciseName` werden beim Adoptieren einer Vorlage als reiner Wert kopiert, ohne Rückbezug zu `ExerciseTemplate` (`DayEditorView.swift:866-910`). Umbenennen einer eigenen Übung lässt Plan-Anzeige, Verlaufs-Swipe (`ExerciseDetailView`) und Trophy-Room/PRs auf dem **alten** Namen stehen — Daten bleiben erhalten, sind aber über die Library nicht mehr auffindbar (falsch-leer). Kein Warnhinweis beim Umbenennen. Suche/Filter ohne Treffer rendert eine stumme leere Liste (P2, kein harter Fehler).

**Media-Credits (`ExerciseMediaCreditsView`):** Pflicht-Attribution ist vollständig und wortgetreu vorhanden (`NOTICE-exercise-gifs.md`-Anforderungen erfüllt), aber der Fließtext behauptet "mit Erlaubnis gezeigt" bestimmter als die eigene NOTICE-Datei das stützt (die selbst vorsichtiger formuliert: "laut der NOTICE.md des Datensatz-Projekts").

---

## Teil 3 — Alte → neue Navigation (5 Gruppen)

**Profil & Training**
`SV-01` Profil-Editor (+ Unterseiten: Körperdaten-Karte neu, Trainingsort+Ausstattung-Screen aus Phase 3)

**App & Trainingserlebnis**
`SV-02`+`DSV-*` Dashboard anpassen · `SV-03` Einheiten (kg/lbs) · `SV-06` Erscheinungsbild · `SV-07`…`SV-11` Timer/Sound/Haptik/Vorlauf · `SV-12`/`SV-13` Workout-Verhalten · `SV-14`/`SV-15` Deload (**zusammen lassen**) · `SV-16`…`SV-20` Erinnerungen

**Daten & Verbindungen**
`SV-21`…`SV-25` Apple Health · `SV-26` Export · `SV-27` Backups · `SV-28` Import · `SV-32` Zurücksetzen

**Bibliothek & Ausrüstung**
`SV-04` Übungen (Library) · `SV-05` Ausrüstung/Schuhe (Gear-Tracker — Titel-Fix `GEAR-01` einplanen)

**Hilfe & Informationen**
`SV-29`/`SV-30` Version/Bundle · `SV-31` Übungs-GIF-Credits

`SV-03` (Einheiten) bleibt bei "App & Trainingserlebnis" (reines Anzeigeformat, keine Dateneingabe).

---

## Teil 4 — Entscheidungen (Rückfragen beantwortet)

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Zielbranch dieser Session vs. tatsächlicher Epic-Branch | **`claude/smart-onboarding-epic`** (enthält Phase 6 / `EquipmentPlanningContext`) |
| 2 | Automatisches Vorab-Backup bei "App zurücksetzen"? | **Ja** — wie Restore/Replace-Import, `BackupService.createBackup` vor dem Löschen |
| 3 | Bedeutung von `lastDataExportAt`? | **Lokales Backup gespeichert** — erst nach erfolgreichem `BackupService.store()` setzen |
| 4 | Übungs-Umbenennung bricht Verlaufs-Lookup — Vorgehen? | **Jetzt sauber beheben** — stabile Referenz `Exercise`/`ExerciseLog`/`PersonalRecordEntry` → `ExerciseTemplate` |
| 5 | Bereits erfundene FFM/FFMI-Altdaten (Tag-1-Messungen ohne Umfänge)? | **Einmalig bereinigen** — betroffene Altzeilen per Migration auf `nil` setzen |
| 6 | Onboarding künftig auf `makeWeightOnly` umstellen? | **Ja** — Tag-1-Dashboard zeigt FFMI/Lean-Mass als "–" bis echte Umfänge erfasst sind |

Alle übrigen Funde aus Teil 1 sind entweder bereits durch die Vorgabe selbst entschieden (z. B. Export-Actor-Fix, separate Health-Lese-/Schreib-Einträge) oder niedrigrisikobehaftete Einzelfixes (Accessibility-Labels, Bestätigungsdialoge, Wording) — werden ohne weitere Rückfrage in den jeweiligen Phasen (P2–P6, Tasks #122–127) umgesetzt.
