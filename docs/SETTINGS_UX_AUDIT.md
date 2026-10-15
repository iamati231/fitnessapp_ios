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
| PE-B1/G1 | Profil/Körperdaten | `ProfileEditorView.swift:477-507` | P1 | Größe und Zielgewicht in getrennten Cards, aktuelles Gewicht nirgends in diesem Screen sichtbar (0 Treffer für ein Gewichts-Ist-Feld) | Kombinierte Höhe/Gewicht/Zielgewicht-Karte, Gewicht aus `BodyMeasurement` gelesen (wie Dashboard/MeasurementView) | P3 | **behoben** (Phase 3) |
| PE-H1 | Profil/Körperdaten | `ProfileEditorView.swift:306-441` | P1 | HealthKit-"Übernehmen"-Button überschreibt Geburtsdatum/Geschlecht/Größe unbedingt, ohne Bestätigung, ohne Undo | Bestätigungsschritt vor dem Übernehmen ergänzen | P4 | **behoben** (Phase 4) |
| PE-P1 | Profil/Körperdaten | `ProfileEditorView.swift:447-453`, `BodyMeasurement.swift` | P2 | Geschlechts-Änderung berechnet vorhandene `BodyMeasurement`-Ableitungen (Navy/Deurenberg/FFMI) nicht neu — bleiben unter altem Geschlecht eingefroren | Hinweistext ergänzen, kein Code-Zwang nötig | P3 | **behoben** (Phase 7) |
| DX-02c | Daten/Export | `DataExportView.swift:239-275`, `DataExportService.swift` | **P0** | Export läuft komplett synchron auf MainActor (Kommentar behauptet `Task.detached`, Code tut es nicht) — UI friert für die volle CSV/ZIP-Dauer ein | Fetch bleibt Main, dann Sendable-DTOs bauen, CSV/ZIP-Arbeit off-Main | P5 | **behoben** (Phase 5) |
| BL-07 | Daten/Backup | `BackupListView.swift:278-289` | **P0** | `createNow()` ist komplett synchron, kein `Task{}` — UI friert schlimmer ein als beim Export | Gleiches DTO-Snapshot-Muster wie DX-02c | P5 | **behoben** (Phase 5) |
| DI-03 | Daten/Import | `DataImportView.swift:600-648` | **P0** | `loadPreview` läuft synchron bei jeder Dateiauswahl — entpackt+parsed das ganze ZIP auf Main, UI friert bei **jeder** Dateiwahl ein | In `Task{}` verschieben (reine Daten, kein `ModelContext` nötig) | P5 | **behoben** (Phase 5) |
| BL-03 | Daten/Backup | `BackupListView.swift:274-276`, `BackupService.swift:209-212` | **P0** | `(try? listGenerations()) ?? []` — echter Lesefehler ununterscheidbar von "keine Backups", genau das Panic-Szenario, für das der Screen existiert | Echte I/O-Fehler durchreichen, eigener Error-State statt wiederverwendetem Empty-State | P5 | **behoben** (Phase 5) |
| BL-05 | Daten/Backup | `BackupListView.swift:182-197` | **P0** | Backup löschen: ein Tap, keine Bestätigung, irreversibel; Fehler verschluckt (`try?`); Tap-Ziel 32×32pt (< 44pt-Minimum) | Eigener `confirmationDialog`, Fehler anzeigen, Tap-Ziel vergrößern, `.accessibilityLabel` mit Datum | P5/P6 | **behoben** (Phase 5 + 6) — Bestätigung + Fehleranzeige (Phase 5); Tap-Ziel auf 44×44pt vergrößert + `.accessibilityLabel` mit Datum ergänzt (Phase 6) |
| RS-02 | Daten/Reset | `SettingsView.swift:816-919` | **P0** | "App zurücksetzen" ist die einzige destruktive Aktion ohne automatisches Vorab-Backup | Automatisches Backup vor dem Löschen | P5 | **behoben** (Phase 5) |
| GEAR-05 | Gear | `GearListView.swift:113-124,162-164` | **P0** | Gear löschen ohne Bestätigung, ein Tap, Kilometerstand-Historie unwiderruflich weg (Workout-Sessions selbst bleiben, `.nullify`) | Bestätigungsdialog wie bei Custom-Exercise-Löschung | P6 | **behoben** (Phase 6) |
| EXLIB-07/09 | Bibliothek | `ExerciseLibraryEditorSheet.swift:180-200`; `Exercise.swift:15`, `ExerciseLog.swift:40`, `PersonalRecordEntry.swift:27` | **P0** | Umbenennen einer eigenen Übung bricht Verlaufs-/PR-Lookup und Plan-Anzeige für alle vorher geloggten Einträge — `name` wird beim Adoptieren kopiert, kein Rückbezug zu `ExerciseTemplate`. Kein Warnhinweis beim Umbenennen. Daten nicht verloren, nur unauffindbar (falsch-leer). | Stabile Referenz (ID) von `Exercise`/`ExerciseLog`/`PersonalRecordEntry` zurück zu `ExerciseTemplate` | P6 | **behoben** (Phase 6) |
| SV-F01 | Settings | `SettingsView.swift:245-261` vs. `:857` / `SettingsPortability.swift:33` | P1 | `weight_unit` ist laut Portability-Whitelist "echte Präferenz", wird aber von Reset gelöscht — widerspricht Resets eigenem Kommentar | Default: als Präferenz behandeln, nicht löschen | P5 | **behoben** (Phase 5) |
| SV-F07/08/09 | Settings/Dashboard | `Theme.swift` (`DeltiqControlRow`/`DeltiqRow`/`DeltiqHeaderAction`), alle Toggle/Picker/Icon-Buttons in `SettingsView.swift` + `DashboardSettingsView.swift` | P1 | Durchgängig fehlende `.accessibilityLabel` (Gegenprobe: `HealthWorkoutWriteView.swift` macht es im selben Ordner korrekt) | Labels pro Instanz ergänzen, **nicht** die shared Theme-Components anfassen | P6 | **behoben** (Phase 6) — 19 Toggle/Picker-Instanzen in `SettingsAppExperienceView`/`SettingsDataConnectionsView`/`ProfileEditorView`/`DashboardSettingsView` gelabelt; `DeltiqHeaderAction` um optionales `accessibilityLabel` ergänzt (additiv, Theme-Component selbst nur um das neue Feld erweitert) fuer DSV-01 + Gear-/Dashboard-"+"-Buttons |
| DX-03/04 | Daten/Export | `DataExportView.swift:183-195, 266, 294-306` | P1 | `lastDataExportAt` wird gesetzt bevor Share/Backup bestätigt ist; `ShareSheet` ohne Completion-Handler | Erst nach erfolgreichem `BackupService.store()` setzen | P5 | **behoben** (Phase 5) |
| BL-08 | Daten/Backup | `BackupListView.swift:232-239` | P1 | Status-Text "Wird wiederhergestellt…" erscheint identisch auch beim reinen Backup-Erstellen | Eigener String je Operation (Enum statt `isWorking: Bool`) | P5 | **behoben** (Phase 5) |
| DI-09 | Daten/Import | `DataImportView.swift:705-773`, `DataImportService.swift:352-360` | P1 | `performImport` durchgehend synchron ohne `await` — "live" Fortschrittsbalken kann nicht wirklich animieren | async + `Task.yield()` zwischen Phasen, oder ehrlicher Indeterminate-Spinner | P5 | **behoben** (Phase 5) |
| R-08 | Health | `HealthWorkoutWriteView.swift:242-250` | P1 | Diagnose-String unlokalisiert und ungated im **häufigen** `.blocked`-Normalfall gezeigt; Kommentar sagt "nur TestFlight", kein Guard | Hinter "Diagnose anzeigen"-Disclosure verstecken + lokalisieren | P4 | **behoben** (Phase 4) |
| REM-01 | Reminder | `SettingsView.swift:459-529` | P1 | Reminder-Toggles lesen nie den echten OS-Benachrichtigungsstatus — anders als strukturell identische `healthKitSection` (`SV-21`) | OS-Status aktiv abfragen, analog `healthKitSection` anzeigen | P4 | **behoben** (Phase 4) |
| REM-02 | Reminder | `ReminderPreferencesApplier.swift` + Onboarding-Re-Init-Pfad | P1 | Resets Zusage "Reminder-Prefs bleiben erhalten" wird durch hartkodierte Re-Init bei erzwungenem Re-Onboarding gebrochen | Re-Onboarding darf vorhandene, nicht-default Reminder-Prefs nicht überschreiben | P4 | **behoben** (Phase 4) |
| GEAR-01 | Gear/Profil | `GearListView.swift:29`; `ProfileEditorView.swift:847,862` | P1 | Gear-Screen-Titel und Equipment-Sheet-Titel/`navigationTitle` beide identisch "Ausrüstung" | Gear-Screen-Titel um "& Schuhe" ergänzen (Settings-Zeile hat es schon) | P3 | **behoben** (Phase 3) |
| GEAR-04 | Gear | `GearListView.swift:92-142` | P1 | Gear-Zeile nutzt `.onTapGesture` auf `VStack` statt `Button` — keine VoiceOver-Button-Semantik (Exercise Library macht es korrekt) | In `Button` einpacken | P6 | **behoben** (Phase 6) |
| CREDITS-02 | Bibliothek | `ExerciseMediaCreditsView.swift:21-33` | P1 | Credits-Text behauptet "mit Erlaubnis gezeigt" als gesicherte Tatsache, stärker als die eigene `NOTICE-exercise-gifs.md` das stützt | Formulierung auf Quelle zurückführen ("laut Datensatz-Projekt"), nicht als eigene Zusicherung | P6 | **behoben** (Phase 6) |
| RS-03a | Daten/Reset | `SettingsView.swift:913-919` vs. `DataImportService.swift:505-508` | P1 | Zwei unabhängig gepflegte "Alles löschen"-Sequenzen; Repo-README warnt bereits vor dem Drift-Risiko | Gemeinsamen `wipeAllPersistentModels`-Helper extrahieren | P5 | **behoben** (Phase 5) |
| DX-05 | Daten/Export | `DataExportView.swift:199-210, 258` | P2 | `BackupService.store`-Fehler per `try?` verschluckt, Banner zeigt trotzdem "fertig" | Fehler nicht-blockierend zusätzlich anzeigen | P5 | **behoben** (Phase 5) — derselbe Fix wie DX-03/04 |
| SV-F02 | Settings | `SettingsView.swift:857` | P2 | `height_unit`/`unit_system` sind tote Keys | Aus Reset-Loop entfernen | P6 | **behoben** (Phase 6) |
| SV-F13 | Settings | `HealthKitController.swift:24` | P2 | "Letzter Sync" nur In-Memory, verschwindet nach jedem Kaltstart | Persistieren oder als "diese Sitzung" kennzeichnen | P4 | **behoben** (Phase 4) |
| EXLIB-02/03 | Bibliothek | `ExerciseLibraryView.swift:253-279,282-294` | P2 | Suche/Filter ohne Treffer rendert stumme leere Liste, kein "keine Treffer"-Hinweis | Expliziten No-Results-State ergänzen | P6 | **behoben** (Phase 6) |
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

**`PE-H1`** (**behoben, Phase 4**): HealthKit-"Übernehmen" überschrieb Geburtsdatum/Geschlecht/Größe unbedingt und ohne Bestätigung (`ProfileEditorView.swift:410-441`) — schloss Gewicht bereits korrekt aus (Gewicht lebt ausschließlich in `BodyMeasurement`). Jetzt: reiner Lese-Fetch (`requestHealthPull`) zeigt einen `confirmationDialog` mit genau den verfügbaren Feldern und ihrem Wert; erst der explizite "Übernehmen"-Tap mutiert das Profil (`applyHealthPull`). Siehe Teil 6.

### 2.3 Daten-Export / Backup / Import / Reset

27 Zeilen vollständig ausgewertet. **Drei-Zustände-Verwechslung bei `lastDataExportAt`** (**behoben, Phase 5**): Datei erstellt (①, ephemer) → lokales Backup gespeichert (②, vorher Fehler per `try?` verschluckt) → Nutzer hat extern geteilt (③, weiterhin nicht geprüft — `ShareSheet` bekommt bewusst keinen Completion-Handler, siehe Teil 7) → `lastDataExportAt` wird jetzt erst nach ② gesetzt, und nur im Erfolgsfall.

**Concurrency** (**behoben, Phase 5**): `DataExportView.startExport`, `BackupListView.createNow`/`restore`, `DataImportView.loadPreview` liefen faktisch synchron auf MainActor, obwohl ein Kommentar `Task.detached` behauptet hatte. Echter DTO-Snapshot-Grenzzug umgesetzt (Fetch bleibt auf dem Context-Actor, ZIP-Kompression/Entpacken off-Main) — siehe Teil 7 fuer die genaue Aufteilung.

### 2.4 Apple Health (HealthWorkoutWriteView, HealthAppLink)

25 Zeilen, nur **ein** P1-Fund (`R-08`, Diagnose-String — **behoben, Phase 4**), Rest P2 oder bereits korrekt. Bestätigt vorbildlich: ehrliche Teilergebnis-Anzeige bei Abbruch, Blind-Spot-Warnung im Vorschau-Screen, keine Kalorien-/Puls-Fabrikation, typ-spezifische Berechtigungen sauber getrennt. Terminologie-Fund (drei uneinheitlich benannte Lese-Berührungspunkte) — **umgesetzt, Phase 4**: "Daten übernehmen" (Lese-/Import-Richtung, neue Section-Caption `settings.health.readGroup.header`) vs. "Trainings an Health senden" (`settings.healthWrite.row`/`.title`, vorher "Trainings in Health").

### 2.5 Reminder (Wasser-/Messungs-Erinnerungen)

UI-Zeilen vollständig in 2.1 als `SV-16`…`SV-20` erfasst. Zwei tieferliegende Funde, **beide behoben in Phase 4**: `remindersSection` fragte nie den tatsächlichen OS-Benachrichtigungsstatus ab (anders als `healthKitSection`) — jetzt zeigt `reminderPermissionStatusRow` den echten `PRNotificationCenter`-Status (erlaubt/verweigert+Einstellungen-Link/noch nicht festgelegt), ruft dabei nie selbst einen Berechtigungs-Dialog auf. Resets Zusage "Reminder-Prefs bleiben erhalten" wurde durch hartkodierte Re-Init beim erzwungenen Re-Onboarding gebrochen (`OnboardingView.init()` seedete `enableWaterReminder`/`enableMeasurementReminder` immer mit `true`) — jetzt aus `ReminderPreferences.load()` geseedet, siehe Teil 6.

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

---

## Teil 5 — Phase 3 Abschlussbericht

**Umgesetzt:**
- `BodyDataEditorView` (neu): kombinierte Größe/Gewicht(+Datum)/Zielgewicht-Karte als Draft-Sheet. Nutzt `BodyMeasurement.makeWeightOnly` (Phase 2). Gewichtsfeld startet leer (letzter Wert nur als Platzhalter-Kontext) — `weightTouched`-Flag unterscheidet "nicht angefasst" (kein neuer Eintrag, auch bei Größen-/Zielgewichtsänderung) von "bewusst erneut eingetragen" (legt immer einen neuen Eintrag an, auch bei identischem Wert). Link zur vollständigen Messung (`MeasurementView`).
- `MeasurementView`: Bearbeiten einer ursprünglich umfangslosen Zeile verlangt jetzt nur noch das Gewicht (`isEditingWeightOnlyEntry`); füllt der User nachträglich alle Pflicht-Umfänge aus, wird trotzdem korrekt zu einer vollen Messung hochgestuft.
- `TrainingLocationEquipmentEditorView` (neu): kombinierter Trainingsort+Ausstattung-Editor, Draft-basiert. Speichern ändert ausschließlich `profile.environment`/`equipmentProfile`/`equipmentProfileConfirmedComplete`. Die bestehende Plan-Anpassungs-Bestätigung (`ProfileEditorView.onChange(of: profile.environment)`, Schritt 2 aus Phase 2) bleibt unverändert die einzige Stelle, die Pläne tatsächlich ändert — feuert weiterhin genau einmal beim Speichern. `equipmentTouched`-Flag verhindert, dass ein reiner Trainingsort-Wechsel ungefragt eine bestehende Gym-Annahme in eine volle Bestätigung umwandelt.
- Dashboard-Hero-Karten (KFA/FFMI/Lean-Mass): fallen jetzt auf die jüngste ÄLTERE Zeile mit echtem Wert zurück (statt "–" sobald die neueste Zeile ein Weight-only-Eintrag ist) und zeigen deren tatsächliches Datum ("Stand: …") — nie das der neuesten Messung. Keine neue Schätzung wird dabei erzeugt.
- `GearListView`-Titel um "& Schuhe"/"& Shoes" ergänzt (`GEAR-01`), deckt sich jetzt mit der Settings-Zeile; zusätzlich entschärft durch den neuen, klar benannten `profile.trainingLocation.title`-Screen (kein "Ausrüstung" mehr an zwei Stellen).
- `SettingsView`: gruppierte Navigation (Profil & Training direkt, 4 Gruppen-Unterseiten: App & Trainingserlebnis, Daten & Verbindungen, Bibliothek & Ausrüstung, Hilfe & Informationen). Reine Verschiebung bestehender Sections/`@AppStorage`-Keys/Logik in `SettingsAppExperienceView`/`SettingsDataConnectionsView`/`SettingsLibraryEquipmentView`/`SettingsHelpInfoView` — keine Funktion entfernt oder verändert. "App zurücksetzen" bleibt unverändert auf der obersten Seite, ganz unten, außerhalb jeder Gruppe.
- Neue xcstrings-Keys (17) vollständig DE/EN/TR übersetzt, `TRANSLATIONS.md` regeneriert, 0 hartkodierte Strings (`.scripts/generate_translations_md.py`).

**Bewusst unverändert gelassen (nicht Teil dieser Phase):**
- `derivedSection`/`computeDerivedFields`-Live-Vorschau in `MeasurementView` (zeigt "Deurenberg" als eigene, klar benannte Zeile neben "Navy" — bereits transparent, keine versteckte Fabrikation, anders als der in Phase 2 behobene `makeDerived`/Onboarding-Fall).
- `PlanEnvironmentMigrator` selbst: unverändert, keine neue Bulk-Substitutionslogik (Vorgabe wörtlich).

**Tests/Build — getrennt berichtet (Punkt 7):**
- **Core (reines Swift, kein SwiftData/SwiftUI):** `fallbackMeasurement`/`fallbackDate`-Logik in `DashboardView` nur code-gelesen, nicht isoliert unit-getestet (sitzt in einer SwiftUI-View-Methode, nicht in `FitnessAppCore`) — kein Core-Test ergänzt.
- **SwiftData/SwiftUI (Linux):** `swift build`/`swift test` grün, 961 Bestandstests unverändert grün. **Das ist KEIN Beleg für die neue UI selbst** — `BodyDataEditorView.swift`/`TrainingLocationEquipmentEditorView.swift`/`ProfileEditorView.swift`/`MeasurementView.swift`/`SettingsView.swift`+Gruppen-Seiten sind alle `#if canImport(SwiftUI) && canImport(SwiftData)`-gated; auf diesem Linux-Toolchain ist SwiftData nicht importierbar, der Compiler parst diese Dateien nur oberflächlich (bestätigt: `echo 'import SwiftData' | swift -` → "no such module"), ohne echte Typ-Prüfung. Keine neuen automatisierten Tests für die beiden neuen Draft-Editoren ergänzt (dieselbe Einschränkung, die auch bestehende SwiftUI-Screens in diesem Projekt nicht unit-testet).
- **Apple-Build/iOS-Abnahme:** **nicht durchgeführt in dieser Session** (kein Zugriff auf Xcode/echtes iOS-Target). Insbesondere ungeprüft: Keyboard-Dismiss-Verhalten, VoiceOver-Ansagen, Dynamic-Type-Verhalten der neuen Sheets, tatsächliches Layout auf kleinen Displays. Das reale, verbindliche Signal bleibt der naechste Codemagic-Lauf — wie bei jeder vorherigen Phase dieses Epics wird ein dort auftretender Fehler anhand des Logs diagnostiziert und gezielt behoben.

---

## Teil 6 — Phase 4 Abschlussbericht

Alle sechs Befunde aus der Vorgabe (`REM-01`, `REM-02`, Health-Terminologie, `PE-H1`, `R-08`, `SV-F13`) umgesetzt. Kein fachlicher Blocker — alles direkt aus Vorgabe + Code ableitbar.

**Umgesetzt:**
- **`REM-01`** — `SettingsAppExperienceView` liest jetzt den echten OS-Status über die bereits vorhandene `PRNotificationCenter` (dieselbe Berechtigung wie PR-Celebrations, keine zweite Abfrage/Infrastruktur). Neue `reminderPermissionStatusRow` zeigt 3 Zustände: erlaubt (inkl. `.provisional`/`.ephemeral`), verweigert (mit Hinweistext + "Einstellungen öffnen"-Button, neuer generischer `AppSettingsLink`-Helfer statt des Health-spezifischen `HealthAppLink`), noch nicht festgelegt. Status wird per `.task` beim Öffnen und per `.onChange(of: scenePhase)` bei Rückkehr aus den System-Einstellungen aktualisiert — ausschließlich über `refreshAuthorizationStatus()` (reiner Lesezugriff), nie über `requestAuthorization()`. Gespeicherte Reminder-Präferenzen bleiben bei verweigerter Berechtigung unangetastet (Präferenz und Zustellung sind getrennte Dinge, wie vorgegeben). Bestehendes `rescheduleReminders()`-Verhalten (Berechtigungsanfrage nur bei aktivem Toggle-Wechsel) unverändert.
- **`REM-02`** — Root Cause war `OnboardingView`: `enableWaterReminder`/`enableMeasurementReminder` waren mit hartkodiertem `= true` initialisiert und wurden in `finishOnboarding()` unbedingt in dieselben `UserDefaults`-Keys geschrieben, die Reset bewusst erhält — ein erzwungenes Re-Onboarding überschrieb damit einen zuvor bewusst deaktivierten Reminder wieder mit dem Default. Fix: neuer `init()` seedet beide `@State`-Werte aus `ReminderPreferences.load()`, das "Key fehlt" (→ Default) bereits korrekt von "Key explizit `false`/non-default gespeichert" unterscheidet (`defaults.object(forKey:) as? Bool/Int`, nie `.bool(forKey:)`). Erstmaliges Onboarding (keine Keys vorhanden) und bewusste Nutzeränderungen funktionieren unverändert; `ReminderPreferencesApplier` selbst war bereits korrekt und musste nicht geändert werden.
- **Health-Terminologie** — `SettingsDataConnectionsView.healthKitSection` bekommt zwei Unter-Captions statt einer undifferenzierten Liste: "Daten übernehmen" (Status/Letzter Sync/Workout-Import) und, per Trennlinie abgesetzt, "Trainings an Health senden" (Link zu `HealthWorkoutWriteView`, dessen Titel/Zeile jetzt denselben Text tragen statt des vorherigen "Trainings in Health"). Keine neue Navigationsebene, keine Funktion/Berechtigungsgrenze verändert. Bestehende Hinweise (nicht erkennbare Lese-Berechtigungen, ehrliche Teilergebnis-/Fehlerzustände in `HealthWorkoutWriteView`) unverändert erhalten; keine neue "verbunden = alle Lese-Rechte erteilt"-Aussage eingeführt.
- **`PE-H1`** — `ProfileEditorView.pullProfileFromHealthKit()` in einen reinen Lese-Schritt (`requestHealthPull()`: holt den `OnboardingHealthSnapshot`, zeigt bei leerem Snapshot einen "nichts gefunden"-Hinweis) und einen reinen Mutations-Schritt (`applyHealthPull(_:)`, byte-identische Feld-für-Feld-Logik wie vorher) aufgeteilt. Dazwischen ein neuer `confirmationDialog`, der exakt die verfügbaren Felder mit ihrem konkreten Wert auflistet (Vorbild: die bereits vorhandenen `pendingProfileEnvSwap`/`pendingCardioBaseline`-Dialoge). Abbrechen (Button oder Wegtippen) ruft `applyHealthPull` nicht auf — keine Mutation, alle bisherigen Werte bleiben unverändert. Fehlende Health-Werte haben weiterhin keinen Effekt (nie `nil`/0 in ein vorhandenes Profilfeld geschrieben). Gewicht bleibt ausschließlich im `BodyMeasurement`-Pfad — `OnboardingHealthSnapshot.weightKg` wird in der Pull-Logik nicht referenziert (neu getestet, siehe unten). Phase-3-Draft-Editoren (`BodyDataEditorView`, `TrainingLocationEquipmentEditorView`) nicht angefasst.
- **`R-08`** — `HealthWorkoutWriteView.diagnosticRow` steckt den rohen Diagnose-String jetzt in ein lokalisiertes `DisclosureGroup("Diagnose anzeigen")` statt ihn im häufigen `.blocked`-Normalfall unverlangt anzuzeigen. Deckt alle 3 bisherigen Aufrufstellen ab (`.canRequest` ohne Dialog, `.canRequest` bei `.sharingDenied`, `.blocked`). Der Normalfall zeigt weiterhin eine verständliche Erklärung + passende nächste Aktion (unverändert); die rohe Diagnose-Payload selbst bleibt bewusst unlokalisiert (technische Support-/Debug-Kennung, keine UI-Prosa) — alle UI-Sätze drumherum sind jetzt lokalisiert. Bestehende Accessibility (Labels/Hints an den Status-Zeilen) unverändert.
- **`SV-F13`** — `HealthKitController.lastSyncDate` wird jetzt zusätzlich in `UserDefaults` persistiert (`markSyncSucceeded()`, einzige Schreibstelle) und beim `init()` wieder geladen — überlebt damit einen Kaltstart. Semantik geprüft: beide bisherigen Schreibstellen (`saveMeasurement`, `saveWorkout`) setzen den Zeitstempel bereits ausschließlich nach einem nachweislich erfolgreichen Schreibvorgang, nie bei einem bloßen Zugriffsdialog, Versuch oder Fehler — die stärkere, dauerhafte Persistierung war damit fachlich eindeutig und wurde der Session-Markierung vorgezogen (wie in der Vorgabe priorisiert). Ohne je erfolgreich synchronisiert zu haben bleibt der Wert ehrlich `nil` (kein erfundenes Datum).

**Kleine, fachlich begründete Extraktionen (für Testbarkeit, keine Architekturänderung):**
- `HealthKitController.init(userDefaults:)` injizierbar gemacht (Default `.standard`, wie `ReminderPreferences.load(from:)`); `lastSyncDateDefaultsKey` von `private` auf Modul-intern geändert, damit der Test denselben Key referenziert statt ihn zu duplizieren.
- `OnboardingHealthSnapshot.hasApplicableProfileFields` (neu, `FitnessAppHealth`): die "lohnt sich ein Bestätigungsdialog?"-Prüfung aus `requestHealthPull()` 1:1 herausgezogen (reine Werte-Prüfung, Gewicht zählt bewusst nicht mit).
- `NotificationPermissionDisplayState` (neu, `FitnessAppCore`): die dreistufige `Bool?`→Zustand-Ableitung hinter `reminderPermissionStatusRow`, als plattformneutraler Typ statt Inline-`switch` in der SwiftUI-View.

**Bewusst unverändert gelassen (nicht Teil dieser Phase):**
- Allgemeines Reset-/Backup-Verhalten (`RS-02`/`RS-03a` etc.) — explizit Phase 5.
- `applyHealthPull`s SwiftData-Mutation selbst und das Dialog-Binding (`pendingHealthPull`) — reine Wiring-/Model-Logik ohne weitere Verzweigung, nicht sinnvoll isolierbar ohne SwiftData.

**Tests/Build — getrennt berichtet:**
- **Core (reines Swift, kein SwiftData/SwiftUI/HealthKit):** 3 neue Testdateien, 14 neue Tests, alle grün:
  - `NotificationPermissionDisplayStateTests` (`FitnessAppCoreTests`, 3 Tests): `Bool?` → `granted`/`denied`/`notDetermined`, inkl. `nil` ≠ "verweigert".
  - `OnboardingHealthSnapshotTests` (`FitnessAppHealthTests`, 9 Tests): `hasApplicableProfileFields` für leer/Geburtsdatum/männlich/weiblich/`.other`/`.notSet`/Größe>0/Größe≤0 (inkl. negativ)/nur-Gewicht (muss `false` bleiben)/alle Felder.
  - `HealthKitControllerLastSyncTests` (`FitnessAppHealthTests`, 2 Tests): `init(userDefaults:)` lädt einen zuvor gespeicherten Zeitstempel korrekt; bleibt `nil`, wenn nie gespeichert. `HealthKitController` selbst ist (anders als die meisten UI-Dateien) **nicht** SwiftUI/SwiftData-gated, nur `#if canImport(HealthKit)`-Gates um den Service — lief deshalb echt, nicht nur oberflächlich geparst.
  - `ReminderPreferencesTests` (bereits vorhanden, unverändert): deckt die "Key fehlt vs. explizit gespeichert"-Unterscheidung bereits vollständig ab, auf der `REM-02`s Fix (`OnboardingView.init()`) beruht — kein neuer Test nötig, da `OnboardingView.init()` selbst keine weitere Verzweigung enthält.
  - Gesamt: `swift test` — **975 Tests, 0 Fehler** (961 Bestand aus Phase 3 + 14 neu).
- **SwiftUI/SwiftData/HealthKit (Linux-Toolchain, oberflächlich geparst):** `swift build` grün für alle geänderten Dateien (`HealthKitController.swift`, `HealthKitTypes.swift`, `OnboardingView.swift`, `AppSettingsLink.swift` (neu), `SettingsAppExperienceView.swift`, `HealthWorkoutWriteView.swift`, `ProfileEditorView.swift`, `SettingsDataConnectionsView.swift`). **Das ist kein Beleg für echtes Typchecking dieser SwiftUI-Oberflächen** — `#if canImport(SwiftUI) && canImport(SwiftData)`-gated Dateien werden auf diesem Linux-Toolchain nur oberflächlich geparst (SwiftData nicht importierbar: `echo 'import SwiftData' | swift -` → "no such module"). Insbesondere ungeprüft auf diesem Weg: `reminderPermissionStatusRow`s tatsächliches Rendering, der neue `confirmationDialog` in `ProfileEditorView`, das `DisclosureGroup`-Verhalten in `HealthWorkoutWriteView`, die neuen Caption-Zeilen in `SettingsDataConnectionsView`.
- **Apple-Build/iOS-Abnahme:** **nicht durchgeführt in dieser Session** (kein Zugriff auf Xcode/echtes iOS-Target). Offene manuelle Prüfpunkte für den nächsten Codemagic-/TestFlight-Lauf:
  - `AppSettingsLink.open()` öffnet tatsächlich die Deltiq-Seite der iOS-Einstellungen (nicht nur die allgemeinen Einstellungen).
  - Rückkehr aus den System-Einstellungen aktualisiert `reminderPermissionStatusRow` tatsächlich ohne manuelles Neuladen (`.onChange(of: scenePhase)`).
  - VoiceOver liest den neuen Disclosure-Status ("Diagnose anzeigen", eingeklappt/ausgeklappt) und die neuen Caption-Zeilen sinnvoll an.
  - `confirmationDialog` in `ProfileEditorView` zeigt bei echtem HealthKit-Zugriff die erwarteten Werte/Formatierung (Datum, Geschlecht, Größe in cm) und Abbrechen hinterlässt das Profil tatsächlich unverändert.
  - `lastSyncDate` übersteht einen echten App-Kill+Neustart auf einem Gerät mit zuvor erfolgreichem Health-Schreibzugriff.
  - Das reale, verbindliche Signal bleibt der nächste Codemagic-Lauf — ein dort auftretender Fehler wird wie bei jeder vorherigen Phase anhand des Logs diagnostiziert und gezielt behoben.

---

## Teil 7 — Phase 5 Abschlussbericht

Alle sieben Punkte der Vorgabe (Export/Backup-Erstellung, Import, Backup-Liste, Sicherungsstatus, App-Reset, Präferenzen/Sessions/Live-Activities/Health, Tests) umgesetzt. Kein fachlicher Blocker.

**Umgesetzt:**

1. **Export/Backup-Erstellung ohne Main-Thread-Blockade (`DX-02c`/`BL-07`)** — `DataExportService.makeExport` in `makeFilesSnapshot` (Fetch + CSV-Bau, bleibt zwingend auf dem Actor von `context` — `ModelContext` ist nicht `Sendable`, `id(_:)` braucht die lebenden Objekt-Referenzen fuer die FK-Map) und `buildBundle` (meta.json + ZIP-Kompression, reine Byte-Arbeit auf einem `Sendable` `FilesSnapshot`) aufgeteilt. Neue `makeExportAsync`/`BackupService.createBackupAsync` fuer User-initiierte Aufrufe fuehren `buildBundle`/`store` ueber `Task.detached` aus — dort steckt kein `ModelContext` und kein lebendes SwiftData-Objekt mehr drin. Die bestehenden synchronen `makeExport`/`createBackup` bleiben unveraendert fuer den automatischen Hintergrund-Backup-Lauf (`BackupService.runAutomaticBackupIfDue`, ausgeloest in `FitnessAppApp.swift` beim App→Background-Wechsel) — dort ist ein kurzer synchroner Schreibvorgang weiterhin bewusst gewollt (siehe dortiger Kommentar). `BackupListView.createNow`/`restore` nutzen jetzt echte `Task{}`+`createBackupAsync`/`performImport`.
2. **Import ohne UI-Blockade (`DI-03`/`DI-09`)** — `DataImportView.loadPreview` laeuft jetzt per `Task.detached` (die gesamte Vorschau — Entpacken, CSV-Zeilenzaehlung — beruehrt gar keinen `ModelContext`: `DataImportService.preview(zipData:)` nimmt keinen Context entgegen). `DataImportService.performImport` ist jetzt `async`: der reine Entpack-/Validierungsschritt (`extractAndValidate`, kein SwiftData-Zugriff) laeuft per `Task.detached`, die SwiftData-Schreibphase (`runImport`) ist explizit `@MainActor` und `yield`et nach jedem Fortschritts-Tick (`Task.yield()`), damit der Fortschrittsbalken tatsaechlich sichtbar mitlaeuft statt erst am Ende zu springen. Vorschau, Append-/Replace-Bestaetigung und Vorab-Sicherung (`preImport`) unveraendert erhalten. **Zusaetzlich gefunden und behoben:** `runImport` rief bei `.replace` bisher `context.save()` direkt nach dem Wipe auf — das widersprach dem eigenen Doc-Kommentar auf `wipeAllUserData` ("ein einziges save(), das Wipe und Merge atomisch committet") und schuf genau die Luecke, vor der dieser Kommentar warnte: ein Abbruch zwischen Wipe-Save und Merge-Ende haette einen leeren UND unvollstaendig importierten Bestand hinterlassen. Jetzt committet ausschliesslich das finale `context.save()` (Schritt 7) Wipe und Merge atomisch zusammen.
3. **Backup-Liste Fehler-/Zustaende (`BL-03`/`BL-05`/`BL-08`)** — `BackupService.listGenerations()` wirft jetzt bei einem echten `contentsOfDirectory`-Fehler (vorher `try?` → `[]`, ununterscheidbar von "noch nie gesichert"); `BackupListView` zeigt dafuer eine eigene `loadErrorCard` mit "Erneut versuchen"-Button, getrennt von der Empty-State-Karte. Loeschen verlangt jetzt denselben `confirmationDialog` wie Wiederherstellen (vorher ein ungesicherter Tap) und zeigt Fehler statt sie mit `try?` zu verschlucken. Neues `Operation`-Enum (`idle`/`creating`/`restoring`/`deleting`) ersetzt das gemeinsame `isWorking: Bool` — der Status-Text zeigte vorher bei JEDER laufenden Operation "Wird wiederhergestellt…". Tap-Ziel-Vergroesserung (32×32pt) bewusst NICHT mitgemacht — das ist Accessibility-Politur, Phase-6-Scope.
4. **`lastDataExportAt`-Semantik (`DX-03`/`DX-04`/`DX-05`)** — bedeutet jetzt verbindlich "lokale Sicherung erfolgreich gespeichert" und wird nur gesetzt, wenn `BackupService.store` nach dem Teilen-faehigen Export auch wirklich erfolgreich war. Scheitert NUR die lokale Zusatzsicherung, bleibt Teilen weiterhin moeglich — der Teilfehler erscheint als eigener, nicht-blockierender Hinweis (`backupWarning`) statt stillschweigend verschluckt zu werden. Eine externe Sicherung (User hat tatsaechlich per Share-Sheet geteilt) wird nach wie vor nicht behauptet — das bleibt bewusst unbelegt, da `UIActivityViewController` keinen zuverlaessigen Completion-Status fuer alle Ziele liefert (AirDrop/Mail/Drittanbieter-Apps).
5. **App-Reset Vorab-Backup + geteilte Loeschlogik (`RS-02`/`RS-03a`/`SV-F01`)** — `resetApp()` erzeugt jetzt zuerst eine `BackupService.createBackupAsync(reason: .preReset)`-Sicherung (neuer `BackupFilename.Reason`-Fall, eigener Label in der Backup-Liste). Schlaegt sie fehl, kehrt `resetApp` VOR `isResetting = true` und vor jeder Mutation zurueck und zeigt den Fehler — es wird nicht trotzdem geloescht. Die neue Sicherung liegt in `Documents/Backups`, einem von der SwiftData-Loeschung voellig unabhaengigen Verzeichnis (verifiziert, nicht nur angenommen) und kann vom Reset nicht mitgeloescht werden. Neue `UserDataWipe` (Core/`FitnessAppData`) buendelt die 10 Typen, deren Loeschumfang zwischen Reset und destruktivem Replace-Import tatsaechlich identisch ist (PersonalRecordEntry, ExerciseLog, WorkoutSession, Exercise, TrainingDay, TrainingPlan, WaterEntry, BodyMeasurement, Gear, UserBodyProfile) — `ExerciseTemplate` bleibt an BEIDEN Call-Sites bewusst separat (Reset loescht+reseedet alle Templates, Replace-Import nur Custom-Templates: zwei tatsaechlich unterschiedliche Umfaenge, nicht in eine Funktion gezwungen). `SettingsView.deleteAll<T>` (Duplikat von `DataImportService.deleteEach<T>`) entfernt. `weight_unit` nicht mehr Teil der Reset-Loeschliste (`SV-F01`) — es ist laut `SettingsPortability`-Whitelist eine echte Praeferenz, widersprach sich mit Resets eigenem Kommentar ("Nutzer loescht Daten, nicht Einstellungen").
6. **Praeferenzen/Sessions/Live-Activities/Health bei Reset** — `pref_water_reminder*`/`pref_measurement_reminder*` waren bereits NICHT Teil der Reset-Loeschliste (verifiziert, keine Code-Aenderung noetig — Phase-4-Vertrag haelt). `TimedWorkoutBackground.shared.endAll()` (Zeitformat-Lauf) wurde bereits VOR der Loeschung aufgerufen (verifiziert, korrekt). **Neu gefunden und behoben:** der per-Satz-Pausentimer (`RestTimerActivityController`, eigene Live Activity, unabhaengig vom Zeitformat-Lauf) wurde von `resetApp()` bisher gar nicht referenziert — eine laufende Pause-Activity ueberlebte den Reset unbeendet. `SettingsView` liest jetzt `@Environment(RestTimerActivityController.self)` (dieselbe von `RootView` injizierte Instanz) und ruft `endRestTimer(reason: .skipped)` im selben Zug wie `TimedWorkoutBackground.endAll()`. Ein aktives/laufendes Workout selbst ist bereits durch den bestehenden Crash-Safe-Mechanismus (`navigation.workoutPath`-Reset + `isResetting`-Gate + verzoegertes `DispatchQueue.main.async`-Delete) kontrolliert behandelt — keine Aenderung noetig, nur verifiziert. Apple-Health-Daten bleiben unangetastet (verifiziert: `resetApp()` referenziert keinerlei `FitnessAppHealth`-Symbol).

**Kleine, fachlich begruendete Extraktionen (fuer Testbarkeit/Wiederverwendung, keine Architekturaenderung):**
- `UserDataWipe` (neu, `FitnessAppData`): buendelt die zwischen Reset und Replace-Import identischen 10 Loesch-Typen — direkte Antwort auf `RS-03a`, kein Selbstzweck.
- `DataExportService.FilesSnapshot`/`makeFilesSnapshot`/`buildBundle`: der Sendable-Grenzzug selbst, zentral fuer `DX-02c`.

**Bewusst unveraendert gelassen (nicht Teil dieser Phase):**
- `SV-F02` (`height_unit`/`unit_system` als tote Keys aus dem Reset-Loop entfernen) — P2-Politur, nicht in der Vorgabe genannt, Phase-6-Scope.
- BL-05s Tap-Ziel-Vergroesserung (32×32pt) — Accessibility-Politur, Phase-6-Scope.
- `DispatchQueue.main.async`-Deferral in `resetApp()` fuer die eigentliche Loeschung — bewusst NICHT auf `Task`/`Task.yield()` umgestellt. Das ist kein generisches Threading-Problem, sondern loest ein spezifisches, dokumentiertes Render-Timing-Problem (SwiftUI darf nicht mid-render auf halb-geloeschte Models treffen); `DispatchQueue.main.async`s "naechster Main-Run-Loop-Turn nach dem aktuellen Render" ist dafuer die etablierte, gezielt richtige Garantie.

**Tests/Build — getrennt berichtet:**
- **Core (reines Swift, kein SwiftData/SwiftUI/HealthKit):** `swift test` — **975 Tests, 0 Fehler**, unveraendert gegenueber Phase 4. `BackupFilenameTests.testRoundTripPreservesReasonAndTimestamp` iteriert bereits `Reason.allCases` und deckt den neuen `.preReset`-Fall automatisch mit ab (verifiziert: Test bleibt gruen nach Hinzufuegen des Falls, ohne Testcode-Aenderung).
- **SwiftData (Linux-Toolchain, oberflaechlich geparst):** 3 neue Regressionstests in `DataPortabilityRoundtripTests.swift` (alle `#if canImport(SwiftData)`-gated, auf diesem Linux-Toolchain NICHT ausfuehrbar — SwiftData nicht importierbar, `echo 'import SwiftData' | swift -` → "no such module"):
  - `testAsyncExportAtVolumeRoundtripsCompletely` ("grosse Historie"): 250 Sessions × 3 Saetze, `makeExportAsync` → `performImport`, prueft exakte Zeilenzahlen — beweist, dass der neue Off-Main-Pfad bei echtem Volumen keine Zeilen verliert/verdoppelt.
  - `testUserDataWipeDeletesOnlyTheSharedScope` (`RS-03a`): `UserDataWipe.deleteSharedUserData` loescht exakt die 10 gemeinsamen Typen, System- UND Custom-`ExerciseTemplate` ueberleben beide.
  - `testRestoreAfterResetLikeWipeRecoversFullState` ("Restore nach Reset"): Seed → Export (simuliert `.preReset`-Sicherung) → `UserDataWipe`+Templates loeschen (simuliert Reset-Loeschumfang) → `performImport(strategy: .replace)` → voller Datenbestand zurueck. Die Service-Garantie ("Backup vor Wipe ist vollstaendig restaurierbar") ist damit vollstaendig geprueft; die SwiftUI-Orchestrierung selbst (`SettingsView.resetApp` → Confirm-Dialog → `BackupListView.restore`) nicht — kein UI-Test-Target in diesem Repo.
  - Bereits vorhandene `testGarbageZipThrowsWithoutWiping`/`testPreviewRejectsGarbage` decken "ungueltiges ZIP" ab, nach Migration auf `async throws` unveraendert in ihrer Aussage (Replace-Import darf bei strukturell ungueltigem ZIP nicht erst wipen und dann scheitern).
  - Alle 31 bestehenden Tests in dieser Datei auf `async throws` migriert (`performImport`-Signaturaenderung), ein `XCTAssertThrowsError`-Aufruf auf manuelles do/catch umgestellt (Autoclosure-Parameter ist nicht `async`-faehig) — mechanische Migration, keine Assertion inhaltlich veraendert.
- **Nicht durch Unit-Tests abgedeckt, nur durch Code-Lektuere verifiziert (SwiftData-/Filesystem-Kopplung ohne etablierten Test-Seam in diesem Repo):**
  - "Fehlgeschlagene Sicherung": `BackupService.store`/`createBackup` werfen `BackupError.storeUnhealthy`, wenn `SharedStore.health == .fellBackAfterGroupStoreFailure` — dieser Zustand wird ueber `private(set) static var health` gesetzt und ist von aussen nicht test-induzierbar, ohne eine echte App-Group-Container-Fehlfunktion zu simulieren. Kein Test-Seam dafuer vorhanden; einen neu einzufuehren waere eine groessere Architekturaenderung, die die Vorgabe ausdruecklich ausschliesst ("keine grosse Architekturaenderung nur fuer Tests").
  - "Backup-Lade-/Loeschfehler" ueber echte Dateisystem-Berechtigungen: `BackupService` haengt an einem hartkodierten `Documents/Backups`-Pfad (keine injizierbare Basis) — ein Test muesste den echten Pfad manipulieren (z. B. `chmod`), was in diesem Repo bisher fuer `BackupService` nicht etabliert ist und in einer CI-Sandbox fragil waere.
  - "Abgebrochene Bestaetigung": reine SwiftUI-Interaktion (Tap auf "Abbrechen" in einem `confirmationDialog`) — durch Code-Lektuere gesichert (der Cancel-Button ruft ausschliesslich `pending… = nil` auf, nie die mutierende Funktion), aber nicht automatisiert pruefbar ohne UI-Test-Framework (keines in diesem Repo vorhanden).
  - "Doppeltippen": durch Konstruktion verhindert (`.disabled(operation != .idle)` auf allen ausloesenden Buttons) und per Code-Lektuere verifiziert; echtes Doppeltipp-Timing ist wieder ein UI-Test-Fall.
- **Apple-Build/iOS-Abnahme:** **nicht durchgefuehrt in dieser Session** (kein Zugriff auf Xcode/echtes iOS-Target). Alle in dieser Phase geaenderten Dateien sind `#if canImport(SwiftData)`- bzw. `#if canImport(SwiftUI) && canImport(SwiftData)`-gated; `swift build`/`swift test` auf diesem Linux-Toolchain bestaetigen nur, dass die `#if`/`#endif`-Klammerung intakt ist und der Rest der Codebasis unveraendert kompiliert/testet — **kein echtes Typechecking der hier geaenderten Actor-Isolation/Sendable-Semantik.** Insbesondere ungeprueft:
  - Tatsaechliches Laufzeitverhalten von `Task.detached`/`@MainActor`/`Task.yield()` in `DataExportService`/`DataImportService`/`BackupService` — die Kernaenderung dieser Phase.
  - Ob die UI waehrend Export/Import/Backup-Erstellung bei echter grosser Historie tatsaechlich responsiv bleibt (visuelle/Interaktions-Pruefung).
  - Ob der Fortschrittsbalken beim Import jetzt sichtbar animiert statt am Ende zu springen.
  - `RestTimerActivityController.endRestTimer` raeumt eine echte Live Activity beim Reset tatsaechlich vom Lock-Screen/der Dynamic Island.
  - Vollstaendiger End-to-End-Lauf: Reset ausloesen → Vorab-Sicherung wird angelegt → Reset laeuft durch → ueber die Backup-Liste wiederherstellen → App ist wieder im Vor-Reset-Zustand.
  - `XCTFail`/do-catch-Umstellung in `testGarbageZipThrowsWithoutWiping` kompiliert und verhaelt sich wie erwartet (kann auf diesem Toolchain nicht ausgefuehrt werden).
  - Das reale, verbindliche Signal bleibt der naechste Codemagic-Lauf — ein dort auftretender Fehler wird wie bei jeder vorherigen Phase anhand des Logs diagnostiziert und gezielt behoben.

---

## Teil 8 — Phase 6 Abschlussbericht

**1. Stabile Exercise-Referenz (EXLIB-07/09):** `ExerciseTemplate` bekommt ein
neues `id: UUID` (Default-Literal, KEIN `@Relationship`, damit Loeschen einer
Vorlage strukturell nie Logs/PRs mitloeschen kann). `Exercise.exerciseTemplateID`,
`ExerciseLog.exerciseTemplateIDSnapshot` und `PersonalRecordEntry.exerciseTemplateID`
referenzieren diese ID zusaetzlich zum bestehenden Namens-Snapshot (der bewusst
erhalten bleibt — "historische Namens-Snapshots erhalten"). `PRDetector.GroupKey`
und der Trophy-Room (`PRHistoryView.TrophyGroupKey`) gruppieren jetzt ID-first:
ein Attempt mit aufloesbarer ID gruppiert darueber (ueberlebt ein Umbenennen),
nur Alt-Eintraege ohne ID fallen weiterhin auf den Namen zurueck — nie beides
gemischt, damit ein zufaelliger Namens-Treffer nie zwei Uebungen zusammenlegt.
`ExerciseDetailView` (die "Verlaufs-Swipe"-Ansicht) loest ebenso ID-first auf.
Neue One-Shot-Migration `ExerciseTemplateIDBackfill` (gleicher Ort/Aufruf-Pattern
wie `ExerciseNameBackfill`, MUSS danach laufen) verknuepft Bestandsdaten
rueckwirkend — aber NUR bei exaktem, eindeutigem Namens-Treffer; zwei Vorlagen
mit demselben Namen oder gar kein Treffer bleiben bewusst `nil`, es wird nicht
geraten ("Mehrdeutige Altzuordnungen nicht anhand aehnlicher Namen raten").
CSV-Export/-Import (`custom_exercises.csv` + neue `exercise_template_id`-
Spalten auf den 3 anderen Tabellen) sichert die ID ueber Backup-Roundtrips ab,
inklusive Dedup-Fall (Zielcontainer hat bereits eine gleichnamige Vorlage mit
eigener ID → Referenz zeigt auf die wiederverwendete, nicht die verwaiste
Export-ID). Rueckwaertskompatibel: ein Backup von vor dieser Phase hat die
neuen Spalten nicht, `CSVReader` liefert dafuer `nil` (keine Sonderbehandlung
noetig, Pattern bereits etabliert z. B. bei `superset_id`).
*Bewusst nicht mit angefasst:* `DashboardView.cardioSeries` (DEL-065-Pace-
Trend-Chart) gruppiert Cardio-Logs ebenfalls per Namens-Snapshot — dieselbe
Bug-Kategorie, aber deutlich geringere Schwere (eine umbenannte Cardio-Uebung
splittet nur in zwei Legenden-Linien statt eine Linie zu verlieren oder
Daten falsch zu verstecken/zusammenzulegen). Nicht Teil dieser Phase, da es
eine neue `@Query<ExerciseTemplate>` in einer bereits 3000+-Zeilen-Datei
erfordert haette, die ich nicht vollstaendig gelesen habe — Kandidat fuer
einen kleinen Folge-Fix.

**2. Gear-Loeschen (GEAR-05/04):** `GearListView` bekommt `pendingDelete` +
`confirmationDialog` (Vorbild: `BackupListView`/`ExerciseLibraryView`), Fehler
werden per `do/catch` + sichtbarer Inline-Fehlerzeile angezeigt (nicht mehr
stillschweigend `try?`). Die Zeile ist jetzt ein echter `Button` (VoiceOver-
Semantik) statt `.onTapGesture` auf einem `VStack`; der Loesch-Button bleibt
ein eigenstaendiger SIBLING-Button (kein Nesting) mit eigenem 44×44pt-Tap-Ziel
und `.accessibilityLabel`. Titel-Pruefung: `GearListView` ("Ausruestung &
Schuhe") und der Trainingsort-Equipment-Screen ("Trainingsort & Ausstattung",
`TrainingLocationEquipmentEditorView`) sind bereits eindeutig unterschiedlich
benannt (verifiziert, keine Aenderung noetig).

**3. Exercise-Library "Keine Treffer" (EXLIB-02/03):** expliziter No-Results-
State (`DashboardEmptyState`, Icon "magnifyingglass") wenn Suche/Filter alles
ausschliessen; Plan-Env-Filter-Zeile bleibt sichtbar, damit der User den
Filter direkt anpassen kann. System-Uebungen-Schutz (`ExerciseLibraryEditorSheet`
read-only-Pfad) unberuehrt, verifiziert.

**4. Dashboard/Settings Accessibility + Sortierung:** 19 bislang unbeschriftete
Toggle-/Picker-Instanzen in `SettingsAppExperienceView`, `SettingsDataConnectionsView`,
`ProfileEditorView` und `DashboardSettingsView` bekommen `.accessibilityLabel`
(derselbe String, der ohnehin schon als sichtbares `DeltiqControlRow`-Label
existiert — keine neuen Uebersetzungen noetig, bis auf die unten genannten).
`DeltiqHeaderAction` bekommt ein neues optionales `accessibilityLabel`-Feld
(additiv, Default `nil` aendert nichts an bestehenden Call-Sites) — behebt
damit DSV-01 (schwerste Einzel-Luecke im Audit: Dashboard-Sortieren-Button
war komplett icon-only in beiden Zustaenden) sowie den Gear-"+"-Button und
die beiden Dashboard-"+"-Buttons. Sortieren ohne zwingendes Dragging: neue
Auf-/Ab-Buttons pro Zeile in beiden Dashboard-Listen (aktive Widgets, Hero-
Slots), sichtbar nur im Edit-Modus (dort ist Dragging ohnehin die einzige
bisherige Option) — Drag bleibt zusaetzlich moeglich, ist aber nicht mehr
die einzige Art zu sortieren. BL-05s verbliebener Teil (Tap-Ziel 32×32pt →
44×44pt) nachgeholt. Kleine Displays/grosse Schrift: Stichprobe ergab, dass
die bestehenden Shared-Components (`DeltiqHeader`, `DeltiqControlRow`) bereits
`.lineLimit(1)` + `.minimumScaleFactor` einsetzen und in `SettingsView`/
`DashboardSettingsView`/`GearListView` keine riskanten festen Text-Frames
existieren — keine weitere Haertung noetig ueber das hinaus, was neue eigene
Elemente (Gear-Zeile, Sortier-Buttons) selbst schon beachten. SV-F02 (toter
Reset-Loop-Eintrag `height_unit`/`unit_system`, Phase-5-Nachtrag) ebenfalls
entfernt, verifiziert dass die Keys nirgends sonst im Repo referenziert sind.

**5. GIF-Credits (CREDITS-02):** `settings.credits.exerciseMedia.body` (DE/
EN/TR) umformuliert — die "mit Erlaubnis gezeigt"-Aussage wird jetzt explizit
der Quelle zugeschrieben ("laut dessen eigener Hinweis-Datei"/"according to
that dataset's own notice") statt als eigene Zusicherung der App zu stehen.
Keine Code-Aenderung noetig, nur der lokalisierte Textinhalt.

**6. DI-Seams fuer Phase-5-Fehlerpfade:** zwei gezielte, additive Oeffnungen,
keine Architekturaenderung. `SharedStore.health`: `private(set)` →
`internal(set)` — `@testable import FitnessAppData` kann den Zustand jetzt
direkt auf `.fellBackAfterGroupStoreFailure` setzen, ohne einen echten
App-Group-Fehler zu provozieren. `BackupService.backupsDirectoryOverride:
URL?` (neu, `internal`, Default `nil` = unveraendertes Verhalten): Tests
koennen ein temporaeres Verzeichnis unterschieben. Neue
`BackupServiceFailurePathTests.swift` nutzt beide Seams: "fehlgeschlagene
Sicherung" (`storeUnhealthy` wird geworfen/nicht geworfen, je nach Health-
Zustand), sowie BL-03/BL-05 — echter Ladefehler via einem Pfad, der auf eine
REGULAERE DATEI statt ein Verzeichnis zeigt (`contentsOfDirectory` wirft dann
umgebungsunabhaengig, ohne auf Unix-Permissions angewiesen zu sein, die in
einer Root-/Sandbox-Umgebung oft gar nicht greifen), und ein echter Loeschfehler
via nicht-existentem Pfad.

**Tests/Build — getrennt berichtet:**
- **Core (reines Swift):** `swift test` — **979 Tests, 0 Fehler** (975 aus
  Phase 5 + 4 neue `PRDetectorTests` fuer die ID-first-Gruppierung: Umbenennen-
  ueberlebt-via-ID, unterschiedliche-IDs-trotz-gleichem-Namen-bleiben-getrennt,
  Nil-ID-faellt-auf-Namen-zurueck, ID-und-Nil-werden-nie-gemischt). `LiftAttempt`/
  `PersonalRecord`/`PRDetector` liegen in `FitnessAppCore` OHNE SwiftData-Gate —
  diese 4 Tests sind also ECHT auf diesem Linux-Toolchain ausgefuehrt, nicht
  nur geparst.
- **SwiftData (Linux-Toolchain, nur oberflaechlich geparst, `#if canImport(SwiftData)`
  bzw. `#if canImport(SwiftUI) && canImport(SwiftData)` evaluieren hier `false`):**
  7 neue Tests geschrieben, auf diesem Toolchain NICHT ausfuehrbar:
  - `DataPortabilityRoundtripTests.swift`: `testExerciseTemplateIDResolvesHistoryAfterTemplateRename`,
    `testDeletingTemplateNeverCascadesToExerciseLogsOrPRs`,
    `testCustomExerciseTemplateIDSurvivesExportImportRoundtrip`,
    `testCustomExerciseTemplateIDResolvesThroughDedupOnReimport`.
  - Neue `Tests/FitnessAppUITests/ExerciseTemplateIDBackfillTests.swift` (dort,
    nicht in `FitnessAppDataTests`, weil `ExerciseTemplateIDBackfill` wie sein
    Vorbild `ExerciseNameBackfill` in `FitnessAppUI` liegt — `FitnessAppUITests`
    bekam dafuer `FitnessAppData` als neue Test-only-Dependency in `Package.swift`):
    `testBackfillConnectsOnlyUniqueNameMatches`, `testBackfillConnectsSystemExerciseByName`.
  - Neue `Tests/FitnessAppDataTests/BackupServiceFailurePathTests.swift` (4 Tests,
    siehe Punkt 6 oben).
- **Nicht durch Unit-Tests abgedeckt, nur durch Code-Lektuere verifiziert:**
  - "Abgebrochene Bestaetigung"/"Doppeltippen" fuer den neuen Gear-Lösch-Dialog:
    gleiches Argument wie in jeder vorherigen Phase — kein UI-Test-Target in
    diesem Repo. Cancel-Button ruft ausschliesslich `pendingDelete = nil` auf
    (verifiziert durch Lesen), Trigger-Buttons sind durch den Dialog selbst vor
    Doppel-Aktivierung geschuetzt (SwiftUI `confirmationDialog` blockt weitere
    Taps waehrend er offen ist).
  - Reale VoiceOver-Ausgabe der 19+ neuen `.accessibilityLabel`-Aufrufe sowie der
    neuen Dashboard-Sortier-Buttons: nur Code-Review (korrekter Key, korrekte
    Bindung), keine tatsaechliche VoiceOver-Sitzung moeglich ohne Geraet/Simulator.
  - Visuelle Pruefung des neuen No-Results-States, der restrukturierten Gear-
    Zeile (zwei Sibling-Buttons statt einem `.onTapGesture`-VStack) und der
    neuen Dashboard-Auf-/Ab-Buttons bei grosser Dynamic-Type-Schriftgroesse
    und auf kleinen Displays (SE-Groesse): nicht moeglich ohne Simulator.
- **Apple-Build/iOS-Abnahme:** **nicht durchgefuehrt in dieser Session**, exakt
  aus denselben Gruenden wie in jeder vorherigen Phase (kein Xcode/iOS-Target
  verfuegbar). `swift build`/`swift test` auf dem Linux-Toolchain bestaetigen
  nur: (a) die `#if`/`#endif`-Klammerung aller SwiftData-/SwiftUI-gegateten
  Dateien ist syntaktisch intakt, (b) der komplett ungegatete Core-Code
  (inkl. der neuen `exerciseTemplateID`-Felder auf `LiftAttempt`/`PersonalRecord`
  und der neuen `PRDetector`-Gruppierungslogik) ist korrekt typisiert und
  getestet. **Kein echtes Typechecking** der neuen SwiftData-`@Model`-Felder
  (`ExerciseTemplate.id`, `Exercise.exerciseTemplateID`, etc.), der neuen
  Migration, der CSV-Spalten-Aenderungen, der restrukturierten SwiftUI-Views
  (Gear-Zeile, Dashboard-Sortier-Buttons) oder des `DeltiqHeaderAction`-
  Accessibility-Feldes im SwiftUI-Kontext. Das naechste verbindliche Signal
  ist der naechste Codemagic-Lauf.

---

## Teil 9 — Phase 7 Abnahmebericht

### 1. Audit vollständig abgeglichen

Alle 29 Befund-IDs aus Teil 1 haben einen eindeutigen Endstatus — **0 offen**:

- 27 IDs **behoben** in den Phasen 2–6 (PE-G2/PE-FFM: Phase 2; PE-B1/G1/GEAR-01:
  Phase 3; PE-H1/R-08/REM-01/REM-02/SV-F13: Phase 4; DX-02c/BL-07/DI-03/BL-03/
  RS-02/SV-F01/DX-03/04/BL-08/DI-09/RS-03a/DX-05 + BL-05-Teil1: Phase 5;
  GEAR-05/EXLIB-07/09/SV-F07/08/09/GEAR-04/CREDITS-02/SV-F02/EXLIB-02/03 +
  BL-05-Teil2: Phase 6).
- 1 ID **begründet unverändert**: R-24 ("OK" — niedriges Realrisiko, Fix nur
  relevant falls Consent-Dialoge je strukturell getrennt werden; keine
  Codeänderung vorgenommen).
- 1 ID **in dieser Phase behoben**: **PE-P1** — `profile.person.footer`
  (DE/EN/TR) um einen Satz erweitert: eine Geschlechts-Änderung wirkt nur auf
  künftige Messungen, bereits gespeicherte Körperfett-/FFMI-Werte werden nicht
  rückwirkend neu berechnet. Reiner Text-Fix wie im Audit-Vorschlag selbst
  vorgesehen ("Hinweistext ergänzen, kein Code-Zwang nötig") — keine
  Logikänderung an `BodyMeasurement`/`ProfileEditorView`.

**Gegenprobe statt Blindvertrauen:** die 10 Phase-2–4-"behoben"-Markierungen
(PE-G2, PE-FFM, PE-B1/G1, PE-H1, R-08, REM-01, REM-02, GEAR-01, SV-F13, R-24)
wurden von einem unabhängigen Such-Lauf nochmal gegen den aktuellen Code
gelesen (nicht nur die alte Markierung übernommen) — alle 10 bestätigt, keine
Regression, nur unwesentliche Zeilenverschiebungen durch spätere Phasen. Alle
Phase-5/6-"behoben"-Markierungen wurden in dieser Phase ebenfalls direkt am
aktuellen Code nachgelesen (nicht nur am Commit-Diff) — ebenfalls alle
bestätigt.

**"Implementiert" vs. "auf Apple getestet" — gilt einheitlich für alle 29
IDs:** der Code ist für jede ID vollständig implementiert. Ob er auf Apple
tatsächlich kompiliert und funktioniert, ist je nach Gate unterschiedlich
sicher (siehe Abschnitt 2) — für keine einzige ID liegt eine echte
Apple-Kompilierung oder ein Gerätetest aus dieser Session vor.

### 2. Apple-Build, SwiftData-Tests, Codemagic-Signal

**Apple-Zugriff geprüft und verneint:** `list_environments` liefert für diese
Session genau ein Environment (`anthropic_cloud`, Kind "Standard") — kein
macOS-/Xcode-Environment verfügbar. Damit gilt wie in jeder vorherigen Phase:
**kein Apple-Build, kein SwiftData-Test-Lauf, keine Abnahme auf Apple-Seite
wird hier behauptet.**

**Linux-Lauf (nach dem PE-P1-Fix erneut ausgeführt, cached Swift 6.0.3):**
`swift build` grün, `swift test`: **979/979 Tests, 0 Fehler.** Aufschlüsselung
nach tatsächlicher Prüftiefe:

- **Echt typegecheckt + echt ausgeführt** (kein `#if canImport(SwiftData/
  SwiftUI)`-Gate, da reines `FitnessAppCore`): die komplette ID-first-
  Gruppierungslogik in `PRDetector`/`LiftAttempt`/`PersonalRecord` inkl. der 4
  neuen Phase-6-Tests (Umbenennen überlebt via ID, unterschiedliche IDs bei
  gleichem Namen bleiben getrennt, nil-ID fällt auf Namen zurück, ID/nil
  werden nie gemischt).
- **Nur Linux-geparst, NICHT typegecheckt** (Gate evaluiert auf Linux zu
  `false`, `swift build`/`swift test` sehen diesen Code nur syntaktisch):
  alle `@Model`-Änderungen (`ExerciseTemplate.id`, `Exercise.exerciseTemplateID`,
  `ExerciseLog.exerciseTemplateIDSnapshot`, `PersonalRecordEntry.exerciseTemplateID`),
  `ExerciseTemplateIDBackfill` + seine 2 Tests, die CSV-Export/-Import-
  Erweiterungen (`exercise_template_id`-Spalten) + die 4 neuen
  `DataPortabilityRoundtripTests`, die 4 neuen `BackupServiceFailurePathTests`,
  sowie jede SwiftUI-Änderung (Gear-Bestätigungsdialog, Dashboard-Auf/Ab-
  Buttons, alle 19 neuen `.accessibilityLabel`, No-Results-State).
  Konkret zu den vom User benannten Schwerpunkten: **Migration**
  (`ExerciseTemplateIDBackfill`) — nur geparst. **Stabile Übungsreferenzen**
  — Core-Teil (Gruppierung) echt getestet, SwiftData-Teil (Backfill,
  CSV-Spalten) nur geparst. **CSV-/Backup-Roundtrip** — nur geparst
  (`DataPortabilityRoundtripTests`). **Replace-Import** (Phase 5) — nur
  geparst. **Reset/Restore** (Phase 5) — nur geparst. **Injizierte
  Backup-Fehlerpfade** (`BackupServiceFailurePathTests`, Phase 6) — nur
  geparst, obwohl die Tests selbst so geschrieben sind, dass sie
  umgebungsunabhängig (kein Root/Sandbox-Problem) auf echtem Apple-Toolchain
  laufen würden.

**Neuer Befund — Codemagic existiert und läuft automatisch:** `codemagic.yaml`
konfiguriert zwei Workflows (`swift-package`, `ios-app`), die bei **jedem
Push auf jeden Branch** (`branch_patterns: '*'`) auf echter Mac-mini-M2-
Hardware mit echtem Xcode laufen: `swift build` + `swift test --parallel` +
`xcodebuild` für iOS-Simulator (5 Library-Produkte einzeln, dann die ganze
App inkl. Widget-Extension über ein generiertes Xcode-Projekt). Das heißt:
für die in dieser Epic gepushten Commits sollte bereits echtes Apple-Signal
vorliegen oder gerade entstehen. **Ich kann dieses Ergebnis aus dieser
Session heraus aber nicht einsehen** — für `claude/smart-onboarding-epic`
existiert kein Pull Request (geprüft via `list_pull_requests`), über das
Checks sichtbar wären, und mir steht kein API-Zugriff auf Commit-Status/
Check-Runs für einen bloßen Branch-Ref zur Verfügung (nur PR- und
Workflow-Run-bezogene Tools, Codemagic läuft aber außerhalb von GitHub
Actions). **Empfehlung:** Codemagic-Dashboard oder die GitHub-Commit-Seite
der gepushten Commits direkt prüfen — dort kann das tatsächliche,
verbindliche Ergebnis bereits vorliegen, ohne dass ich es faelschlich als
"ungeprüft" hätte stehen lassen müssen.

### 3. Gerätetest — alle 8 Punkte offen/blockiert

Keiner der 8 Punkte ist in dieser Session durchführbar (kein iOS-Gerät, kein
Simulator, kein Xcode). Status je Punkt — was der Code verspricht (bereits
code-verifiziert) vs. was auf Gerät fehlt:

1. **Gewicht ohne Umfänge speichern/bearbeiten** — `BodyMeasurement.makeWeightOnly`
   (Phase 2) code-verifiziert. Offen: echtes Speichern/Bearbeiten auf Gerät.
2. **Trainingsort/Equipment ändern ohne Planänderung** — PE-G2-Fix (Phase 2)
   code-verifiziert (promptloser Bulk-Sync entfernt). Offen: Gerätetest.
3. **Eigene Übung umbenennen → Plan/Verlauf/PRs/Trends** — EXLIB-07/09
   (Phase 6), Core-Gruppierung echt getestet, SwiftUI/SwiftData-Seite nur
   geparst. Offen: echtes Umbenennen + Sichtprüfung auf Gerät.
4. **Vorlage löschen → historische Daten bleiben** — strukturell erzwungen
   durch fehlende `@Relationship` (kein Cascade möglich). Offen: Gerätetest.
5. **Gear-Löschen abbrechen/bestätigen** — `confirmationDialog` + Cancel-Pfad
   code-verifiziert (Cancel setzt nur `pendingDelete = nil`). Offen: echtes
   Antippen, Doppeltipp-Schutz auf Gerät.
6. **Dashboard per Auf/Ab + VoiceOver sortieren** — Buttons + Labels vorhanden
   (Phase 6). Offen: reale VoiceOver-Ausgabe nie gehört.
7. **Benachrichtigungen + Health-Bestätigung** — REM-01/PE-H1 code-verifiziert.
   Offen: echte OS-Berechtigungsdialoge nie durchlaufen.
8. **Export/Import/Backup/Reset-Restore mit Testdaten** — soweit auf Linux
   ausführbar, grün (siehe Abschnitt 2). Offen: echter Durchlauf mit
   Share-Sheet/Dateisystem/App-Group auf Gerät.

**Alle 8 Punkte: offen, blockiert durch fehlenden Geräte-/Simulator-Zugriff.**
Keine Abnahme wird hierfür behauptet.

### 4. Kleine Displays, große Schrift, DE/EN/TR

- **DE/EN/TR-Stichprobe** (8 Phase-6/7-Keys inkl. der neuen PE-P1-Erweiterung:
  `profile.person.footer`, `gear.delete.confirm.title/.message`,
  `library.noResults.title/.description`, `dashboardSettings.reorder.action`,
  `dashboardSettings.add.actionFormat`, `backups.actions.menu`) direkt aus dem
  Catalog gelesen (nicht nur automatisiert validiert): alle 3 Sprachen
  vorhanden, inhaltlich korrekt und sinngemäß übereinstimmend, keine
  Platzhalter-Lücken, kein EN-Leak in DE/TR. `generate_translations_md.py`
  bestätigt zusätzlich: 2086/2086/2086 Keys, **0 hardcodierte Strings**.
- **Große Schrift/kleine Displays:** gezielte Nachprüfung der in Phase 6 NEU
  hinzugekommenen Elemente (Gear-Zeile, Dashboard-Sortier-Buttons,
  No-Results-State) auf feste Text-Frames, die bei großer Dynamic-Type-Schrift
  abschneiden könnten — gefunden wurden nur zwei feste `.frame(width:height:)`
  (44×44 Gear-Lösch-Button, 40×40 Library-Zeilen-Icon), beides reine
  Icon-Container ohne Text darin, kein Clipping-Risiko. Keine neue Regression
  gegenüber dem bereits in Phase 6 (Teil 8, Punkt 4) dokumentierten Befund.
  Weiterhin nicht möglich: echtes Rendering bei z. B. "Accessibility XXL" oder
  auf SE-Displaygröße — das bleibt Code-Review ohne Simulator.
- **Settings-Erreichbarkeit** (Teil 3, SV-01…SV-32 über 5 Gruppen) Punkt für
  Punkt gegen den aktuellen Code verifiziert: `SettingsView` (Profil-
  Direktlink, 4 Gruppen-Links, Reset ganz unten) → `SettingsAppExperienceView`
  (Dashboard-Link + alle Inline-Controls SV-03/06/07–20) →
  `SettingsDataConnectionsView` (Health/Export/Backup/Import, 4 Links) →
  `SettingsLibraryEquipmentView` (Library/Gear, 2 Links) →
  `SettingsHelpInfoView` (Version/Bundle als reiner Text, GIF-Credits als
  Link). **Alle ursprünglichen SV-Einträge bleiben erreichbar — keine Lücke
  gefunden.**

### 5. Zusammenfassung — tatsächliche Ergebnisse und offene Blocker

**Erreicht:**
- Alle 29 Audit-Befund-IDs behoben oder begründet — 0 offen.
- Linux-Build/-Tests vollständig grün (979/979), frisch nach dem letzten Fix
  erneut bestätigt.
- DE/EN/TR vollständig (2086 Keys, 0 hardcodiert), Stichprobe inhaltlich
  geprüft.
- Settings-Navigation vollständig auf Erreichbarkeit alle 32 Alteinträge
  verifiziert.
- Keine neue Dynamic-Type-/Kleindisplay-Regression in den Phase-6-Neuerungen
  gefunden.

**Offene Blocker (keine Abnahme wird dafür behauptet):**
- Kein Apple-Build, kein SwiftData-Typecheck, keine SwiftData-Tests in dieser
  Session ausgeführt — mangels Apple-/Xcode-Environment.
- Alle 8 Gerätetest-Punkte aus Abschnitt 3 offen.
- Reale VoiceOver-Ausgabe und reales Dynamic-Type-/Kleindisplay-Rendering nie
  beobachtet, nur code-verifiziert.
- Codemagic ist konfiguriert und läuft automatisch bei jedem Push — das
  tatsächliche Ergebnis für die gepushten Commits ist aus dieser Session
  heraus nicht einsehbar (siehe Abschnitt 2). Nächster Schritt liegt beim
  User: Codemagic-Dashboard bzw. GitHub-Commit-Checks ansehen.

Diese Blocker sind identisch zu denen jeder vorherigen Phase — neu ist
lediglich, dass sie hier vollständig gegen jede einzelne der 29 Befund-IDs
sowie gegen alle 5 Vorgabe-Punkte der finalen Abnahme durchdekliniert und
damit explizit bestätigt statt nur pauschal wiederholt wurden.

---

## Teil 10 — Codemagic-Nachtrag (echtes Apple-Signal eingetroffen)

Kurz nach Teil 9 hat der User ein echtes Codemagic-Build-Log (`testflight`-
Workflow, Schritt "Run unit tests (Release-Gate)") bereitgestellt — genau das
in Teil 9 Abschnitt 2 als nicht einsehbar beschriebene Signal lag damit real
vor und bestätigt die dort geäußerte Sorge unmittelbar:

**Fund:** `DataPortabilityRoundtripTests.swift:1397,1406` (Phase-6-Test
`testCustomExerciseTemplateIDResolvesThroughDedupOnReimport`) nutzte
`primaryMuscle: .legs` — `.legs` existiert aber nicht auf `MuscleGroup`
(nur auf `DayType`; `MuscleGroup` hat stattdessen `.quads`/`.hamstrings`/
`.glutes`). Ein echter Tippfehler meinerseits, auf dem Linux-Toolchain
unsichtbar, weil die Datei SwiftData-gated und dort nur geparst, nie
typegecheckt wird — exakt die in Teil 7/8/9 wiederholt benannte Lücke.
Der erste echte Apple-Typecheck hat sie real aufgedeckt, kein anderer
Befund im Log.

**Fix:** beide Stellen auf `.quads` korrigiert (Commit `7c2e626`), nur
Testfixture-Daten betroffen, keine Produktionslogik. Linux-Build/-Test
danach erneut grün (979/979, unverändert — der Fix selbst ist auf Linux
nicht prüfbar, nur die Abwesenheit einer Regression anderswo).

**Zwei vorbestehende, nicht-blockierende Warnungen im selben Log** (nicht
Teil dieser Phase, nicht von mir eingeführt — `DeloadManager.swift` zuletzt
vor dem Smart-Onboarding-Epic geändert, `HealthKitControllerLastSyncTests.swift`
zuletzt in Phase 4): `DeloadManager.defaultFactor` (main-actor-isoliertes
statisches Property als Parameter-Default in nonisolated Kontext) und
`HealthKitControllerLastSyncTests` (Sendable-Capture von `UserDefaults` in
einer `@Sendable`-Closure) sind beide laut Compiler "ein Fehler im
Swift-6-Sprachmodus" — das Paket baut aktuell offenbar noch nicht mit
voller Swift-6-Strict-Concurrency-Prüfung, sonst wären das bereits Fehler
statt Warnungen. Nicht behoben (außerhalb des Auftrags, keine
Verhaltensänderung nötig, keine Regression dieser Epic) — hier nur
dokumentiert, falls eine künftige Swift-6-Migration ansteht.

**Status:** mit diesem Fix ist der einzige im bereitgestellten Log sichtbare
Fehler behoben. Ob der `testflight`-Workflow jetzt komplett durchläuft
(inkl. Signing/Archive/Upload-Schritte danach), ist weiterhin nicht
einsehbar — dafür wäre ein erneuter Codemagic-Lauf nötig, den nur der
User anstoßen bzw. einsehen kann.

---

## Teil 11 — Codemagic-Nachtrag 2 (zwei weitere reale Compile-Fehler)

Der User hat ein zweites, neueres Codemagic-Log bereitgestellt (`testflight`,
"Run unit tests (Release-Gate)"), diesmal mit zwei neuen, voneinander
unabhängigen Fehlern in `FitnessAppUI` — wieder ein Modul, das auf Linux nur
geparst, nie typegecheckt wird. `.legs`-Fix aus Teil 10 taucht in diesem Log
nicht mehr auf (behoben), stattdessen zwei neue, bisher unentdeckte Fehler:

**Fund 1 — fehlender Import:** `SettingsAppExperienceView.swift` nutzt
`PRNotificationCenter` (Zeile 18) und `ReminderScheduler` (4 Stellen,
Zeilen 393–404), beide in `FitnessAppActivities` deklariert, importierte
dieses Modul aber nicht (nur `SwiftUI`/`SwiftData`/`FitnessAppCore`/
`FitnessAppData`). Die gemeldete `.onChange(of: scenePhase) { _, newPhase in`
-Arity-Fehlermeldung (Zeile 81, "expects 1 argument, but 2 were used") ist
eine Folgediagnose desselben Fehlers — sobald `prNotifications` nicht
aufgeloest werden kann, destabilisiert das die Typpruefung des ganzen
`body`, inkl. Overload-Resolution fuer das direkt danach stehende
`.onChange`. Andere Dateien im selben Ordner (`SettingsView.swift`,
`DataImportView.swift`, `ReminderPreferencesApplier.swift`) importieren
`FitnessAppActivities` bereits korrekt. **Eingefuehrt in Phase 3** (Commit
`50d7e65`, beim Herausloesen dieser Datei aus `SettingsView.swift`) — der
Import ist beim Verschieben verlorengegangen. **Fix:** `import
FitnessAppActivities` ergaenzt.

**Fund 2 — fehlendes `@ViewBuilder`:** `ExerciseLibraryView.swift:274`,
`customSection: some View { let customs = ...; if !customs.isEmpty {
Section { ... } } }` — ein bloßes `if` ohne `else` als einzige Anweisung
kann ohne `@ViewBuilder` keinen opaken Rückgabetyp herleiten (fehlt der
Filter, gibt es keinen Rückgabewert). Beide direkten Nachbarn
(`noResultsRow`, `muscleSection`) tragen `@ViewBuilder` bereits korrekt —
`customSection` war die einzige Ausnahme. **Nicht Teil dieser Epic:** laut
`git blame` stammt diese Property aus der ursprünglichen Dateierstellung,
lange vor dem Smart-Onboarding-/Settings-Epic — ein latenter, vorbestehender
Fehler, den erst dieser zweite echte Apple-Typecheck aufgedeckt hat. **Fix:**
`@ViewBuilder` ergänzt.

**Keine Breitenwirkung bestätigt:** vor dem Fix wurde geprüft, ob dasselbe
Muster (computed `some View`-Property/-Funktion ohne `@ViewBuilder` mit
riskantem `if`/`switch`-Körper) anderswo in `FitnessAppUI` vorkommt — ein
Scan fand 26 oberflächlich ähnliche Kandidaten (u. a. in `DashboardView.swift`,
`WorkoutSummaryView.swift`, `TimedWorkoutPlayerView.swift`,
`PlanBuilderView.swift`). Das Log selbst widerlegt diese Kandidaten aber:
es zeigt genau diese Dateien im selben Lauf fehlerfrei durchkompiliert (nur
Warnungen, keine Fehler) — der echte Compiler ist hier die verlässlichere
Quelle als ein text-basierter Scan ohne echtes Parsing. Keine ungeprüften
Änderungen an diesen 26 Stellen vorgenommen, um kein funktionierendes
Verhalten unnötig zu riskieren.

**Linux-Kontrolle:** `swift build`/`swift test` danach erneut grün (979/979,
unverändert — beide Fixes betreffen ausschliesslich SwiftUI/SwiftData-
gegateten Code, auf Linux nur Syntax-geparst, nicht typegecheckt).

**Status:** beide im zweiten Log sichtbaren Fehler behoben. Weiterhin keine
Einsicht in nachfolgende Workflow-Schritte (Signing/Archive/Upload) oder ob
ein dritter Fehler im Log weiter hinten steht, den der zweiseitige
Log-Ausschnitt nicht zeigt — dafür bräuchte es entweder das vollständige
Log oder einen erneuten Codemagic-Lauf.

---

## Teil 12 — Codemagic-Nachtrag 3 (erster Lauf mit echten SwiftData-Tests)

Drittes Log vom User: `FitnessAppUI` kompiliert jetzt fehlerfrei — zum
ersten Mal in dieser Epic laufen die SwiftData-Tests dieses Pakets
tatsaechlich auf echter Apple-Hardware (`swift test --parallel`, Xcode
26.6, macOS arm64). Ergebnis: **4 Tests stuerzten den Testprozess ab**
(Signal 5 / SIGTRAP) und **2 Tests schlugen mit falschem Zahlenwert fehl**
— alle 6 betreffen ausschliesslich Code, der auf Linux nie echt lief.

**Root Cause der 4 Abstuerze — gefunden, nicht geraten:** alle vier
betroffenen Tests (`testExerciseTemplateIDResolvesHistoryAfterTemplateRename`,
`testDeletingTemplateNeverCascadesToExerciseLogsOrPRs`,
`testBackfillConnectsOnlyUniqueNameMatches`, `testBackfillConnectsSystemExerciseByName`)
schrieben `let ctx = try makeContainer().mainContext` — der `ModelContainer`
wird dabei NIRGENDS gehalten, nur sein `.mainContext` wird einer Variable
zugewiesen. Ohne eine eigene Referenz auf den Container kann dieser laut
ARC-Semantik jederzeit freigegeben werden, waehrend `ctx` noch in Benutzung
ist — der Context arbeitet dann auf einem eingerissenen Store, was beim
naechsten SwiftData-Zugriff (Fetch/Save/Property-Zugriff) nicht-deterministisch
crasht. Beweis statt Vermutung: eine Volltext-Suche ueber ALLE ca. 50+
Container-Erzeugungen in `DataPortabilityRoundtripTests.swift` zeigt, dass
JEDE ANDERE Stelle den Container korrekt in einer eigenen Variable haelt
(`let source/target/container = try makeContainer()`, danach `.mainContext`
separat) — **einzig diese zwei Stellen** weichen vom Muster ab, und beide
sind exakt zwei der vier Absturz-Tests. Dieselbe Abweichung fand sich in
`ExerciseTemplateIDBackfillTests.swift`, dort in BEIDEN Tests — exakt die
anderen zwei Abstuerze. Verifiziert ueber den isolierten Retry-Lauf im Log
(SwiftPM fuehrt jeden abgestuerzten Test danach einzeln erneut aus): jeder
der vier crasht auch ALLEIN erneut, sofort nach "started", ohne jedes
Testergebnis — das schliesst "Kollateralschaden durch einen Nachbartest im
selben Worker-Prozess" aus und bestaetigt vier eigenstaendige, deterministische
Bugs mit identischer Ursache. **Fix:** `let container = try makeContainer();
let ctx = container.mainContext` in allen vier Tests — Container bleibt fuer
die Testdauer durch die lokale Variable am Leben. Repo-weite Nachsuche nach
demselben Muster (`makeContainer().mainContext`, `.mainContext` direkt an
einem Funktionsaufruf) ergab keine weiteren Treffer.

**Zweiter, unabhaengiger Bug in `testDeletingTemplateNeverCascadesToExerciseLogsOrPRs`:**
zusaetzlich zum Container-Bug griff der Test NACH `ctx.delete(template)` +
`try ctx.save()` noch zweimal auf `template.id` zu — ein per Web-Recherche
unabhaengig bestaetigtes SwiftData-Verhalten: ein geloeschtes UND gespeichertes
Model-Objekt ist invalidiert, jeder Property-Zugriff danach ist undefiniert
(Apple-DTS-Statement dazu: "the crash comes from accessing the deleted
object afterward"). **Fix:** `templateID` vor dem Loeschen in eine lokale
Konstante sichern, beide Assertions darauf umstellen.

**Zwei Zahlenwert-Fehler — beide vorbestehende Test-Bugs, nicht Phase-6/7:**
- `testAsyncExportAtVolumeRoundtripsCompletely`: erwartete `1 /* profile */ +
  1 /* plan */ + sessionCount + sessionCount * 3` = 1002, tatsaechlich
  1004 — die Kommentar-Summe vergisst `day` und `exercise`, die der Test
  selbst anlegt und die ebenfalls exportiert werden. **Fix:** Formel um
  `+ 1 /* day */ + 1 /* exercise */` ergaenzt.
- `testRestoreAfterResetLikeWipeRecoversFullState`: erwartete 2
  `ExerciseLog`-Zeilen nach Restore, tatsaechlich 3 — die gemeinsame
  `seed()`-Fixture legt 2 Session-Logs PLUS 1 Orphan-Log an (siehe
  Kommentar "DEL-189-Pfad" in `seed()`). Der direkt benachbarte
  Schwester-Test `testExportImportRoundtripRestoresAllRows`, der dieselbe
  Fixture nutzt, erwartet an derselben Stelle bereits korrekt 3 (mit
  Kommentar "2 Session-Logs + 1 Orphan-Log") — die "2" war ein
  Kopier-/Zaehlfehler beim Schreiben dieses einen Tests. **Fix:** auf 3
  korrigiert.

**Linux-Kontrolle:** `swift build`/`swift test` danach erneut grün
(979/979 — unveraendert, da alle sechs Fixes ausschliesslich SwiftData-
gegateten Testcode betreffen, auf Linux nur geparst). Die eigentliche
Wirksamkeit (stuerzen die vier Tests jetzt nicht mehr ab, stimmen die
beiden Zahlen jetzt) ist aus dieser Session weiterhin nicht verifizierbar
— das ist exakt das, was ein vierter Codemagic-Lauf zeigen wird.

**Einordnung:** dies ist der bisher ergiebigste Codemagic-Lauf dieser Epic
— zum ersten Mal lief SwiftData-Testcode statt nur geparst zu werden, und
foerderte sofort einen echten, mehrfach wiederholten Speicherverwaltungs-
Bug zutage, den weder Linux-Parsing noch Code-Review allein je haette finden
koennen. Bestaetigt die in jeder vorherigen Phase wiederholte Einschaetzung:
"Kein echtes Typechecking" auf Linux bedeutet nicht nur "ungetestete
Geschaeftslogik", sondern auch "ungetestete Objektlebensdauer" — eine
eigene Fehlerklasse, die Code-Review strukturell nicht abdecken kann.

---

## Teil 13 — Geraetetest-Fund: Uebungsbibliothek zeigte jede Uebung mehrfach

Erster echter Geraetetest-Befund dieser Epic (3 Screenshots vom User:
"Bankdruecken" 8-fach, "Australian Pull-ups" 8-fach, "Arnold Press (KH)"
mehrfach in der Uebungsbibliothek).

**Root Cause (vom User korrekt diagnostiziert, verifiziert):**
`LibrarySeeder.seedIfNeeded`/`backfillNewLibraryEntriesIfNeeded` behandelten
einen fehlgeschlagenen Fetch (`try? ... ?? 0` bzw. `?? []`) identisch zu
"Bibliothek ist leer"/"Eintrag fehlt noch". Schlaegt der Fetch aus
irgendeinem Grund fehl, fuegt `seedIfNeeded` bei JEDEM App-Start die
komplette ~229-Eintraege-Library erneut ein — kompoundiert mit jedem
weiteren Start. Plausibler Ausloeser (nicht aus dieser Session heraus
beweisbar, siehe naechster Absatz): die Lightweight-Migration, die beim
Hinzufuegen von `ExerciseTemplate.id` in Phase 6 noetig wurde.

**Fix 1 — Ursache:** `seedIfNeeded`/`backfillNewLibraryEntriesIfNeeded` in
`LibrarySeeder.swift` werfen den Fetch-Fehler jetzt explizit per `do/catch`
durch und geben bei einem echten Fehler `false`/`0` zurueck, OHNE etwas
einzufuegen — ein fehlgeschlagener Fetch darf nie mehr als "leer"
interpretiert werden. Im schlimmsten Fall bleibt ein Start ohne Seeding,
der naechste versucht es erneut — himmelweit sicherer als kompoundierende
Duplikate.

**Fix 2 — bereits entstandener Schaden:** neue
`LibrarySeeder.deduplicateTemplatesIfNeeded(in:)` gruppiert alle System-
Templates (`isCustom == false`) case-insensitiv nach Namen und behaelt
genau einen Eintrag pro Name (bevorzugt den mit gesetztem
`localizationKey`). Custom-Templates sind nie betroffen. In `RootView.task`
VOR allen anderen Seeder-Aufrufen eingehaengt. Sicher bzgl. bestehender
Referenzen: `exerciseTemplateID` ist ein reiner UUID-Scalar (kein
`@Relationship`, siehe Phase-6-Begruendung) — Loeschen ueberzaehliger
Duplikate kann keine PR-/Verlaufs-Zuordnung brechen.

**Zusaetzliche, eigenstaendige Absicherung (ueber die User-Vorgabe hinaus):**
Recherche zu SwiftDatas Lightweight-Migration ergab ein von mehreren
Entwicklern berichtetes, aber nicht offiziell dokumentiertes Risiko: ein
neues Property mit Expression-Default wie `ExerciseTemplate.id: UUID =
UUID()` bekommt bei einer Migration moeglicherweise NICHT pro Bestandszeile
einen eigenen frischen Wert, sondern denselben einen Default fuer mehrere/
alle migrierten Zeilen — das haette unterschiedliche Uebungen mit
kollidierender ID und damit faelschlich zusammengelegte PR-/Verlaufs-
Historien zur Folge (die ID-basierte Gruppierung in `PRDetector.GroupKey`/
`PRHistoryView.TrophyGroupKey` vergleicht nur den WERT, nicht ob die
Vorlage noch existiert). **Aus dieser Session heraus nicht an echtem
Apple-SwiftData verifizierbar** (kein Xcode-/Geraete-Zugriff) — deshalb
defensiv behandelt, nicht unterstellt oder ignoriert:
- `ExerciseTemplateIDBackfill.repairDuplicateTemplateIDsIfNeeded(in:)`
  (neu): findet jede von 2+ verschiedenen Vorlagen geteilte `id`, vergibt
  allen bis auf eine je eine frische UUID. Laeuft als allererster Schritt
  in `runIfNeeded`, bevor irgendeine Namens-Verknuepfung stattfindet.
- `runIfNeeded` selbst bekam einen Konsistenz-Check: eine bereits gesetzte
  `exerciseTemplateID`/`-Snapshot`, die zu KEINER Vorlage mit demselben
  Namen mehr passt (z.B. weil `deduplicateTemplatesIfNeeded` genau die
  Vorlage geloescht hat, auf die sie zeigte), wird zurueckgesetzt und ueber
  den normalen eindeutigen Namens-Treffer neu aufgeloest — vorher wurde
  eine einmal gesetzte ID fuer immer als "erledigt" uebersprungen, auch
  wenn sie inzwischen ins Leere zeigte.
- **Ehrliche Grenze:** bereits VOR diesem Fix fehlerhaft verknuepfte
  `Exercise`/`ExerciseLog`/`PersonalRecordEntry`-Zeilen (falls das
  Kollisions-Risiko real eingetreten ist) werden durch
  `repairDuplicateTemplateIDsIfNeeded` allein NICHT rueckwirkend geheilt —
  nur der neue Konsistenz-Check in `runIfNeeded` kann das, und nur fuer
  Faelle, in denen die ID inzwischen zu gar keiner Vorlage mit demselben
  Namen mehr passt (nicht fuer den selteneren Fall, dass die kollidierende
  ID zufaellig weiterhin zu EINER anderen, falschen Vorlage mit einem
  ANDEREN Namen passt). Ob dieses Risiko auf irgendeinem Geraet tatsaechlich
  eingetreten ist, ist unbekannt — es gibt keinen gemeldeten Befund dafuer,
  nur den gemeldeten Duplikate-Bug.

**Tests:** 4 neue in `LibrarySeederTests.swift`
(`testDeduplicateRemovesExcessSystemTemplateCopies` — 5 identische
Bankdruecken-Templates → 4 entfernt, 1 bleibt, wie vom User verlangt;
`testDeduplicateNeverTouchesCustomTemplateWithSameName` — Custom-Template
mit gleichem Namen bleibt unangetastet, wie vom User verlangt;
`testDeduplicateIsIdempotent`; `testDeduplicateHandlesMultipleNameGroupsIndependently`)
+ 3 neue in `ExerciseTemplateIDBackfillTests.swift`
(`testRepairDuplicateTemplateIDsAssignsFreshIDToCollidingTemplate`,
`testRepairDuplicateTemplateIDsIsIdempotent`,
`testRunIfNeededHealsExerciseWithStaleTemplateIDPointingToDeletedDuplicate`).
Alle sieben SwiftData-gated, auf Linux nur geparst, nicht real ausgefuehrt
— identische Einschraenkung wie der gesamte Rest dieser Epic.

**Linux-Kontrolle:** `swift build`/`swift test` grün, 979/979 (unveraendert,
da alle Aenderungen SwiftData-gegateten Code betreffen).

**Status:** Root Cause behoben, bestehender Schaden wird beim naechsten
Start automatisch bereinigt, zusaetzliche Absicherung gegen ein verwandtes,
aber unbestaetigtes Risiko ergaenzt. Ob der Fix auf dem betroffenen Geraet
tatsaechlich greift (Duplikate verschwinden nach dem Update, bleiben
verschwunden), kann nur der naechste Start auf echtem Geraet zeigen — hier
nicht verifizierbar.

---

## Teil 14 — Geraetetest-Fund: RIR-Kapsel abgeschnitten bei Langhantel-Saetzen

Zweiter Geraetetest-Befund (2 Screenshots: "Kreuzheben (konventionell)" und
"Schrägbankdrücken aufwärts (KH)" in einem laufenden Workout). Betraf
`SetRow.swift` — die Datei dokumentiert bereits FUENF vorherige, erfolglose
Anlaeufe fuer dieselbe Befund-Familie (README 2.24/2.25/2.36, zwei
"Layout-Fix 2026-05-21"-Iterationen) — alle beschraenkten sich auf
Padding-/Scale-Factor-Anpassungen an der Kapsel selbst, ohne die zweite
Ursache (der Aufladungs-Knopf als eigenes HStack-Kind) strukturell zu
entfernen.

**Root Cause (vom User korrekt diagnostiziert):** die Eingabezeile hat bei
Langhantel-Uebungen ein zusaetzliches Kind (`plateCalculatorButton`,
~34pt inkl. Spacing) gegenueber Nicht-Langhantel-Uebungen. Ueberschlagsrechnung
fuer iPhone SE (375pt): Satznummer (24) + Gewichts-Feld (72) + "KG" (~20) +
Wdh-Feld (72) + "WDH" (~28) + RIR-Kapsel (~45) + Haekchen (~32) + Zeilen-
Padding (16) + HStack-Spacing (~36) ≈ 345pt — passt knapp. Mit dem
zusaetzlichen Aufladungs-Knopf (+34pt) ≈ 379pt — ueberschreitet die 375pt
SE-Breite. Die `rirCapsule` war die einzige nicht-`.fixedSize()`-Komponente
und bekam bei echtem Overflow praktisch keine Breite mehr zugewiesen —
sichtbar als auf "R" zusammengequetschter Text ohne Ellipse.

**Fix 1 (strukturell, behebt die Ursache):** `plateCalculatorButton` ist
kein eigenes HStack-Kind mehr, sondern ein `.overlay(alignment: .topTrailing)`
auf `weightInput` selbst (28×28 → 22×22, rundes Badge mit dezentem Rand
statt eigenstaendigem Button). Macht die Eingabezeile fuer JEDES Equipment
gleich breit — behebt damit auch den vom User genannten Layout-Sprung
zwischen Langhantel- und Kurzhantel-Uebungen. Keine Verhaltensaenderung:
derselbe Popover, dieselbe Sichtbarkeits-/Tap-Logik (`weight > 0 &&
!isTimeBased`).

**Fix 2 (Kapsel selbst, zusaetzlicher Puffer):** sichtbarer Text kompakter
("RIR 3"/"RIR 2,5" → "R3"/"R2,5", wie vom User als Option vorgeschlagen),
`.frame(minWidth: 32)` fuer eine stabile Pillenform auch bei einstelligen
Werten. `.lineLimit(1)` + `.minimumScaleFactor(0.85)` bleiben als Sicherheitsnetz
bestehen, `.fixedSize()` bewusst NICHT reaktiviert (war in einer fruehen
Iteration genau wegen eines Overflows in die andere Richtung entfernt
worden — mit Fix 1 sollte jetzt Puffer in beide Richtungen bestehen).

**Accessibility (zusaetzlich, waehrend derselben Aenderung behoben):**
der kuerzere sichtbare Text darf VoiceOver nicht verschlechtern — neues
explizites `.accessibilityLabel("RIR <Wert>")` (volle Form, unabhaengig vom
kompakten Sichttext) + `.accessibilityHint` ("zum Anpassen antippen") auf
der Kapsel. Beim Beheben zusaetzlich gefunden: `plateCalculatorButton`s
Accessibility-Label war hartcodiert deutsch (`"Hantel-Aufladung anzeigen"`,
nie uebersetzt) — jetzt lokalisiert. 3 neue xcstrings-Keys
(`activeSet.plateCalculator.accessibilityLabel`,
`activeSet.rirCapsule.accessibilityLabel` [%@-Format],
`activeSet.rirCapsule.accessibilityHint`), DE/EN/TR. Katalog 2086 → 2089
Keys, weiterhin 0 hardcodierte Strings (automatisiert bestaetigt).

**Linux-Kontrolle:** `swift build`/`swift test` gruen, 979/979 (unveraendert
— SwiftUI-gegateter Code, auf Linux nur geparst, kein echtes Rendering
moeglich).

**Ehrliche Grenze — Punkt 3 der Vorgabe nicht erfuellbar:** "auf iPhone SE
und normalen Displaybreiten testen" kann aus dieser Session heraus NICHT
durchgefuehrt werden (kein Simulator-/Geraete-Zugriff, kein UI-Test-Target
in diesem Repo, keine Preview fuer `SetRow` vorhanden). Die Breiten-
Rechnung oben ist eine Ueberschlagsrechnung auf Basis der im Code
dokumentierten Fixed-Width-Werte, keine tatsaechliche Messung. Ob die
Kapsel jetzt wirklich nie mehr abschneidet (insbesondere bei "WDH"/"KG" in
anderen Sprachen oder bei sehr grosser Dynamic-Type-Schrift, die dieses
gesamte Fixed-Width-HStack-Muster strukturell anfaellig macht, wie die
fuenf vorherigen Anlaeufe in der Datei-Historie bereits zeigen), kann nur
ein echter Geraetetest zeigen.

---

## Teil 15 — UI-Refactor: DeltiqHeader-Muster + Discard-Bestaetigung fuer alle Editoren

User-Vorgabe (sinngemaess): einheitliche Kopfzeile fuer alle Formulare/
Editoren — Speichern-Checkmark oben rechts (Orange, disabled bei
`!canSave`), Zurueck-Chevron oben links mit Discard-Bestaetigung bei
vorhandenen Aenderungen, Loesch-Aktionen bleiben ganz unten in roter
Warnfarbe. Betroffen: `BodyDataEditorView`, `TrainingLocationEquipmentEditorView`,
`ExerciseLibraryEditorSheet`, `GearEditorView` (in `GearListView.swift`),
`ExerciseEditorView`, `DayEditorView`, `PlanEditorView`, `ProfileEditorView`
— 8 Editoren insgesamt.

### Architektur-Grundlage (`Theme.swift`)

`DeltiqHeaderAction` bekommt ein additives `isDisabled: Bool = false`
(dimmt das Icon, deaktiviert den Tap). Neue geteilte Extension
`discardChangesConfirmation(isPresented:onDiscard:)` kapselt den
`confirmationDialog` ("Änderungen verwerfen?" / "Änderungen verwerfen"
destruktiv / "Weiter bearbeiten" abbrechend) — einmal geschrieben, von
allen 8 Editoren per `.discardChangesConfirmation(isPresented:) { ... }`
wiederverwendet statt 8× dasselbe Dialog-Boilerplate.

### Fork 1 — DeltiqHeader auch fuer Sheets

`GearListView.swift` dokumentierte bisher explizit die Regel "Sheets sind
kein Fall fuer DeltiqHeader" (native `.toolbar` mit Cancel/Done fuer
sheet-praesentierte Editoren). Diese Vorgabe hebt die Regel fuer die
betroffenen Sheets (`ExerciseLibraryEditorSheet`, `GearEditorView`)
bewusst auf: DeltiqHeader wird INNERHALB des Sheets im eigenen
`NavigationStack` gerendert (`.toolbar(.hidden, for: .navigationBar)` +
`.navigationBarBackButtonHidden(true)`, keine Aenderung am
Praesentations-Modus selbst). Kein Modell-/Daten-Risiko, rein visuell —
das bestehende "kein DeltiqHeader in Sheets"-Dokumentationszitat in
`GearListView.swift` wurde entsprechend korrigiert.

### Fork 2 — Snapshot+Revert fuer Autosave-Screens

Vier der acht Screens (`ExerciseEditorView`, `DayEditorView`,
`PlanEditorView`, `ProfileEditorView`) binden `@Bindable` direkt an ihr
SwiftData-Modell — jede Eingabe persistiert sofort, es gibt keinen Draft
und (vor dieser Aenderung) keinen Cancel-Pfad. "Aenderungen verwerfen"
waere auf einem solchen Screen eine leere UI-Behauptung ohne Wirkung, wenn
es nur `dismiss()` aufruft — die laengst geschriebenen Werte blieben
stehen. Statt die verworfene Alternative umzusetzen (Saves komplett hinter
einen expliziten Commit sperren — groesserer Verhaltenswechsel, Risiko von
Datenverlust bei App-Kill vor dem Speichern), bekommt jeder Autosave-Screen
einen Snapshot-Mechanismus:

- Ein `XxxSnapshot`-Struct (`Equatable`) erfasst die editierbaren Felder
  beim Oeffnen (`State(initialValue: Snapshot.capture(from: model))` im
  `init`).
- `isDirty` vergleicht den aktuellen Modell-Zustand live gegen den
  Snapshot.
- Der Zurueck-Chevron zeigt bei `isDirty` den Discard-Dialog; "Aenderungen
  verwerfen" ruft `snapshot.apply(to: model)` auf (schreibt alle Felder
  zurueck) und dismissed erst danach.
- Der Save-Checkmark bleibt ein reines "Fertig" (`dismiss()`), da ohnehin
  schon alles autosaved ist — kein `canSave`-Gate auf diesen vier Screens.

**Scope-Einschraenkungen (bewusst, pro Screen begruendet):**

- **`ExerciseEditorView`:** Snapshot deckt alle 17 editierbaren Felder ab.
  Eine verworfene Muskel-/Equipment-/Compound-Aenderung wird zusaetzlich
  auf das verknuepfte Custom-`ExerciseTemplate` zurueckgespiegelt (dieselbe
  `syncCustomTemplate`-Funktion, die auch beim Editieren schreibt, DEL-163)
  — sonst bliebe ein verworfener Wert dauerhaft in der Library-Vorlage
  stehen.
- **`DayEditorView`:** Snapshot deckt nur `metaSection` ab (Name/Wochentag/
  Typ/Intensitaet/Zeitformat + Unterfelder). Die Uebungsliste (Hinzufuegen/
  Loeschen/Reorder/Training starten) bleibt aussen vor — das sind eigene,
  sofort wirksame Aktionen ohne Save/Cancel-Konzept, kein Teil eines
  "Formulars". Der bestehende Reorder-Toggle im Header (teilt sich sein
  Icon mit "Fertig"-Checkmark waehrend des Edit-Modes) und der neue
  Save-Checkmark vertragen sich wegen `DeltiqHeader`s Cap von 2 Actions:
  waehrend des Reorder-Modes zeigt NUR dessen eigener Checkmark (sonst
  Icon-Kollision, siehe `DeltiqHeaderAction.id`-Dokumentation), ausserhalb
  stehen beide nebeneinander.
- **`PlanEditorView`:** Snapshot deckt nur `customName`/`weeks`/
  `progressionTargetRIROverride` ab — NICHT `targetEnvironment` (eigener
  Migrations-Flow mit `onChange`+mehreren Dialogen, Seiteneffekte auf
  Uebungen) und NICHT `isActive` (deaktiviert andere Plaene global,
  `setActive`). Ein einfaches Feld-Rueckschreiben wuerde diese
  Seiteneffekte nicht mitverwerfen und koennte den Store inkonsistenter
  zuruecklassen als vorher (z.B. kein Plan mehr aktiv). Zusaetzliche
  Kollisions-Vermeidung: der bestehende "Neu rechnen"-Action (nur fuer
  Generator-Plaene) + Reorder-Toggle + neuer Save-Checkmark sind bis zu
  DREI Kandidaten fuer den 2-Action-Cap — Save faellt im seltenen Fall
  "Generator-Plan + Tage + nicht editierend" bewusst weg, statt "Neu
  rechnen" oder Reorder zu verdraengen (beide bleiben erreichbar; der
  Checkmark ist hier ohnehin nur ein zweiter Weg zum selben `dismiss()`,
  den der Chevron bei `!isDirty` schon bietet).
- **`ProfileEditorView`:** Snapshot deckt nur die einfachen lokalen Felder
  ab (Geschlecht, Geburtsdatum, Cardio-Coaching inkl. Ziel/Referenzzeit/
  Renndatum/Wochenvolumen/Maxpuls, Wochenziel, Trainingsziel, Coaching-Ton).
  Explizit NICHT erfasst: `heightCm`/`goalWeightKg`/Gewichtsmessungen
  (eigener Save/Cancel-Flow in `BodyDataEditorView`), `environment`/
  `equipmentProfile` (eigener Flow in `TrainingLocationEquipmentEditorView`),
  `baselineAssessment` (eigener mehrstufiger Flow in
  `BaselineCheckFlowView`), sowie alles, was der Machbarkeits-Karte
  (`feasibilitySection`s accept/dismiss/acceptCustom) anfasst — eigene,
  bereits explizit bestaetigte Aktionen mit Seiteneffekten auf andere
  Plaene/Tage. Dieser Screen hatte zuvor KEINE Header-Actions — der neue
  Save-Checkmark kollidiert mit nichts.

Diese Scope-Entscheidungen (Fork 2 insgesamt sowie die vier Screen-
spezifischen Ausschluesse) wurden autonom getroffen, nicht einzeln
rueckgefragt — konsistent mit dem bisherigen Arbeitsmuster dieser Epic.
Sie werden hier transparent dokumentiert, nicht erst am Ende verschwiegen.

### Lokalisierung

3 neue Keys (`editor.discardChanges.title`, `.confirmAction`,
`.keepEditing`), DE/EN/TR, per chirurgischem Text-Splice eingefuegt (siehe
Teil 13 fuer die Methodik — NIE `json.dump` auf die xcstrings-Datei, das
sortiert/reformatiert die gesamte ~1.2MB-Datei neu). `git diff --stat`
bestaetigt exakt 69 Insertions, 0 Deletions. Katalog 2089 → 2092 Keys,
weiterhin 0 hardcodierte Strings (automatisiert bestaetigt via
`generate_translations_md.py`), `TRANSLATIONS.md` regeneriert.

### Linux-Kontrolle

`swift build`/`swift test` gruen, 979/979 Tests (unveraendert — reiner
UI-Layer-Refactor, alle 8 betroffenen Dateien sind
`#if canImport(SwiftUI) && canImport(SwiftData)`-gegated und werden auf
Linux nur geparst, nie type-gecheckt oder gerendert. "Build complete!"
beweist hier ausschliesslich syntaktische Korrektheit, keine SwiftUI-
Semantik — identische Einschraenkung wie der gesamte Rest dieser Epic.

### Ehrliche Grenzen — kein Apple-/Geraetezugriff

Folgendes kann aus dieser Session heraus NICHT verifiziert werden (kein
Simulator-/Geraetezugriff):

- Visuelles Layout aller 8 Kopfzeilen (Checkmark-Platzierung, Chevron,
  Eyebrow) auf echten Displaygroessen/Dynamic Type.
- Das tatsaechliche Erscheinen/Verschwinden des Discard-Dialogs bei
  `isDirty`-Uebergaengen zur Laufzeit.
- Dass der Snapshot-Rueckschreibe-Pfad (`apply(to:)`) auf einem echten
  SwiftData-`ModelContext` wirklich alle Felder korrekt zuruecksetzt
  (insbesondere `fiveKReferenceText`s Resync in `ProfileEditorView` und
  die Custom-Template-Ruecksynchronisierung in `ExerciseEditorView`).
- Die Icon-Kollisions-Vermeidung in `DayEditorView`/`PlanEditorView`
  (Reorder-Checkmark vs. Save-Checkmark) im tatsaechlichen Edit-Mode-
  Uebergang.
- Dass `GearEditorView`/`ExerciseLibraryEditorSheet` innerhalb ihres
  Sheets mit ausgeblendeter Navigationsleiste optisch korrekt aussehen
  (Fork 1 — erstmaliger Einsatz von DeltiqHeader in einem Sheet-Kontext
  in diesem Repo).

Code-seitig (Typen, Bindings, Optionalitaet, Equatable-Konformanz der
Snapshot-Structs) wurde durchgehend gegen die tatsaechlichen SwiftData-
Modell-Definitionen gegengelesen; funktional korrekt kompilierender Code
ist aber nicht dasselbe wie ein verifiziertes UI-Verhalten.

---

## Teil 16 — Korrektur zu Teil 15: fuenf fachliche Nachbesserungen

User-Feedback nach Teil 15: "Grundrichtung passt, aber noch nicht als
abgeschlossen behandeln." Fuenf konkrete Punkte, alle umgesetzt. Dieser
Teil ergaenzt/korrigiert Teil 15, statt ihn zu ersetzen — Teil 15s
Architektur-Grundlage (DeltiqHeaderAction/discardChangesConfirmation,
Fork 1) bleibt unveraendert gueltig; nur die hier aufgefuehrten Stellen
waren falsch oder unvollstaendig.

### Punkt 1+2 — Save-Checkmark stabil, nie als Reorder-Done ueberladen

Teil 15 liess den Save-Checkmark in `PlanEditorView` beim seltenen
Zusammentreffen "Generator-Plan + Tage + nicht editierend" durch den
2-Action-Cap verschwinden — genau das verbietet die Korrektur-Vorgabe
ausdruecklich. Fix in `DayEditorView` UND `PlanEditorView`: der bisherige
Top-Level-Reorder-Toggle (eigenes Icon, eigene Position) wandert in ein
Ellipsis-Menu (`"ellipsis"`, bestehende Repo-Konvention, siehe
`WorkoutSummaryView`/`PRHistoryView`/`PlansListView`). `PlanEditorView`s
"Neu rechnen" wandert ins selbe Menu. Der Save-Checkmark ist dadurch IMMER
genau 1 von hoechstens 2 Actions und IMMER die letzte (= am weitesten
rechts, `ForEach(actions)` rendert in Array-Reihenfolge) — nie durch den
Cap verdraengt, nie Icon/Position mit einem "Reorder fertig"-Haekchen
geteilt (das lebt jetzt als eigener Menu-Eintrag, dessen Label/Icon
zwischen "Sortieren" und "Fertig" wechselt, voellig unabhaengig vom
Save-Slot). Die anderen 6 Editoren hatten nie konkurrierende Header-
Actions und waren bereits konform — hier war nichts zu aendern.

Neue xcstrings-Keys: `editor.reorder.start`/`editor.reorder.done`
(wiederverwendet in beiden Screens), `planEditor.recalculate.action`
(uebernimmt die Formulierung von `planBuilder.result.recalculate` fuer
Konsistenz). DE/EN/TR, per chirurgischem Splice ergaenzt (69 Insertions,
0 Deletions, wie gehabt per `git diff --stat` bestaetigt).

### Punkt 3 — Discard-Scope fachlich korrigiert

Teil 15 schloss `targetEnvironment`/`isActive` (PlanEditorView) komplett
vom Snapshot aus, mit der Begruendung, ein einfaches Feld-Rueckschreiben
koenne ihre Seiteneffekte nicht mitverwerfen. Das loest das Problem nicht,
es versteckt es nur: ein reiner, folgenloser Picker-Wechsel (z.B. bei
einem leeren Plan, wo gar keine Migration laeuft) waere dann STILL NICHT
ueber "Verwerfen" rueckgaengig zu machen — die Korrektur-Vorgabe verlangt
aber "Änderungen des aktuellen Formulars vollständig verwerfen", nicht
"manche Formular-Felder nie". Fix:

- `PlanMetaSnapshot` erfasst jetzt `targetEnvironment` UND `isActive` als
  vollwertige Snapshot-Felder — ein einfacher Picker-/Toggle-Wechsel ohne
  nachgelagerte Aktion ist ab sofort normal ueber `isDirty`/"Verwerfen"
  rueckgaengig zu machen, wie jedes andere Feld.
- Sobald der User eine der ihr eigenen, bereits sichtbar bestaetigten
  Aktionen auslöst — Umgebungs-Migration (Adapt/Restore ueber die
  `envSwap`/`envRestore`-Dialoge, inkl. Seiteneffekt "Uebungen archiviert/
  getauscht") oder (in `ProfileEditorView`) `CardioFeasibilityCardModel.
  accept`/`acceptCustom` (legt einen neuen Plan samt Tagen an) —, wird der
  Snapshot SOFORT per neuer `rebaselineSnapshot()`-Funktion auf den
  Nach-Zustand neu gesetzt. Ab dann ist diese Aenderung keine "ausstehende,
  per Verwerfen rueckrollbare Formular-Aenderung" mehr, sondern eine
  eigene, abgeschlossene Aktion — der Discard-Dialog verspricht ab da
  nichts mehr, was er nicht einloesen kann (das war die praezise Lesart
  von "Bereits separat bestaetigte Untereditor-Aktionen klar davon
  abgrenzen" / "Keine pauschale Verwerfen-Zusage bei nur teilweisem
  Rueckrollen").
- Fuer `isActive` zusaetzlich: `setActive(true)` deaktiviert global jeden
  anderen Plan. Ein reines `isActive = false` beim Verwerfen wuerde diesen
  anderen Plan NICHT reaktivieren. Neuer State `otherActivePlanIDAtOpen`
  (erfasst in `.onAppear`, nicht `init` — `@Query allPlans` ist zum
  Init-Zeitpunkt noch leer) haelt fest, welcher andere Plan beim Oeffnen
  aktiv war; `revertToSnapshot()` reaktiviert ihn, wenn genau dieser Screen
  ihn waehrend der Sitzung verdraengt hat.
- Fuer `targetEnvironment` zusaetzlich: `.onChange(of: plan.
  targetEnvironment)` triggert normalerweise den Migrations-Dialog. Ein
  Revert darf das NICHT nochmal ausloesen (der User hat seinen Discard ja
  gerade bestaetigt) — neuer Guard `isApplyingSnapshot`, nur waehrend
  `revertToSnapshot()` gesetzt.
- `BodyDataEditorView`/`TrainingLocationEquipmentEditorView`/
  `ExerciseLibraryEditorSheet`/`GearEditorView`: reine Draft-Screens, bei
  denen vor dem expliziten Speichern ohnehin nichts committed wird —
  "Verwerfen" war dort immer schon vollstaendig, keine Aenderung noetig.
  `DayEditorView`s `metaSection`-Scope hat ebenfalls kein Feld mit eigenem
  Bestaetigungs-Dialog — ebenfalls unveraendert korrekt.
- `ProfileEditorView`s delegierte Sub-Editoren (`BodyDataEditorView` fuer
  `heightCm`/`goalWeightKg`, `TrainingLocationEquipmentEditorView` fuer
  `environment`/`equipmentProfile`, `BaselineCheckFlowView` fuer
  `baselineAssessment`) bleiben bewusst ausserhalb des Snapshots — das
  sind echte, eigenstaendige Sub-Editoren mit eigenem sichtbarem Save/
  Cancel, keine stillschweigende Mehrdeutigkeit wie bei den Dialog-
  gesteuerten Aktionen oben.

**Zwei gefundene Fehler bei der Umsetzung — keiner davon auf Linux
kompilierbar pruefbar, beide nur durch Nachlesen/Review gefunden:**

1. **Selbst gefunden, vor dem ersten Commit:** die erste Fassung von
   `revertToSnapshot()`s Bedingung fuer die Plan-Reaktivierung war
   invertiert (`!wasActive` statt `wasActive`) — haette beim
   Zurueckrollen eines frisch eingeschalteten `isActive` den
   verdraengten anderen Plan NICHT reaktiviert. Beim eigenen Nachlesen
   des Diffs gefunden und korrigiert.
2. **Von der unabhaengigen Code-Review gefunden, NACH dem ersten
   Commit dieser Korrekturrunde:** `isApplyingSnapshot` unterdrueckte in
   Wahrheit GAR NICHTS. Die urspruengliche Fassung setzte das Flag in
   `revertToSnapshot()` synchron `true` → `snapshot.apply(to: plan)` →
   synchron wieder `false`, alles in einem Zug. SwiftUIs
   `.onChange(of:)` feuert aber erst NACH diesem synchronen Durchlauf,
   zum Zeitpunkt des naechsten Update-Zyklus — die Pruefung im Handler
   sah das Flag deshalb immer schon wieder auf `false` und unterdrueckte
   nichts, weder bei echten Edits (korrekt) noch beim Revert
   (inkorrekt — genau der Fall, den das Flag eigentlich abdecken sollte).
   Konkretes Fehlerbild: ein Plan ohne aktive Uebungen (oder nach einem
   "justEnv"-Dialogklick) aendert `targetEnvironment`, der User verwirft
   ueber den Chevron — `revertToSnapshot()` schreibt das Feld zurueck,
   der (wirkungslose) Guard laesst den kompletten DEL-050-Flow ein
   zweites Mal durchlaufen: `profile.environment` wird beim Verlassen
   des Screens nochmal (still) ueberschrieben, bei einem Plan MIT
   Uebungen poppt sogar der Adapt/Restore-Dialog erneut auf, waehrend
   der Screen eigentlich schon schliessen sollte. **Fix:** das Flag wird
   jetzt NUR in `revertToSnapshot()` scharf geschaltet (und nur, wenn
   sich `targetEnvironment` dort nachweislich aendert — sonst faende
   `.onChange` nie statt und das Flag bliebe `true` haengen), und
   ausschliesslich im `.onChange`-Handler selbst wieder konsumiert/
   zurueckgesetzt — unabhaengig davon, wann genau SwiftUI diesen Handler
   tatsaechlich aufruft.

Eine unabhaengige Code-Review ueber den gesamten Diff wurde bewusst
angestossen, genau wegen dieser Fehlerklasse (Timing-/Logik-Fehler, die
auf Linux nicht kompilierbar pruefbar sind, siehe Punkt 5) — sie hat den
zweiten, subtileren Fehler gefunden, den das eigene Nachlesen uebersehen
hatte. Alles andere im Diff (Reaktivierungs-Bedingung nach Fix 1,
`rebaselineSnapshot()`-Aufrufstellen, Header-Action-Reihenfolge in beiden
Screens, alle Boolean-Richtungen bei `interactiveDismissDisabled`/
`deltiqSwipeBackEnabled`, Test-Datei-Enum-Werte) wurde von der Review
gegengelesen und nicht beanstandet.

### Punkt 4 — alle Verlassen-Wege abgesichert

Vorher sicherte nur der DeltiqHeader-Chevron gegen Datenverlust ab — Swipe-
Back (Push-Screens) und interaktives Sheet-Wegziehen (Dismiss-Sheets)
gingen am Discard-Dialog komplett vorbei.

- **Push-Screens** (`DayEditorView`, `PlanEditorView`, `ProfileEditorView`):
  `.deltiqSwipeBackEnabled()` → `.deltiqSwipeBackEnabled(!isDirty)`. Die
  Geste existiert in diesem Repo nur als einfacher An/Aus-Schalter (siehe
  `SwipeBackEnabler` in Theme.swift, `enabled: Bool = true`) — kein Hook,
  um beim Versuch einen Dialog einzublenden. Bei Aenderungen bleibt die
  Geste deshalb komplett deaktiviert (kein Swipe-Pop moeglich), ohne
  Aenderungen funktioniert sie normal. Matcht "ohne Aenderungen weiterhin
  direkt schliessen".
- **Sheet-Screens** (`BodyDataEditorView`, `TrainingLocationEquipmentEditorView`,
  `ExerciseLibraryEditorSheet`, `GearEditorView`, `ExerciseEditorView`):
  neu `.interactiveDismissDisabled(isDirty)` (Apple-API seit iOS 15, ein
  einzelner `Bool`-Parameter — per Websuche gegen die offizielle Doku
  verifiziert, da auf Linux nicht kompilierbar pruefbar). Bei Aenderungen
  tut Wegziehen nichts (Sheet bleibt offen), ohne Aenderungen normal.
  `ExerciseLibraryEditorSheet` bekommt den bestehenden `isReadOnly`-Guard
  dazu (`isReadOnly ? false : isDirty`) — im Read-Only-Modus (System-
  Template) gibt es nichts zu verlieren.

### Punkt 5 — Linux-Tests sind keine Verifikation dieser Aenderung

Alle 8 betroffenen Dateien sind `#if canImport(SwiftUI) && canImport
(SwiftData)`-gegated. `swift build`/`swift test` auf Linux (979/979, siehe
unten) pruefen NUR, dass der Rest des Pakets weiterhin kompiliert — sie
pruefen nicht, ob dieser PR-Inhalt selbst richtig ist (die Datei wird auf
Linux mangels SwiftUI/SwiftData schlicht uebersprungen). Das war bereits
in Teil 15 so benannt, wird hier aber konkretisiert statt nur wiederholt:

- **Neue gezielte Tests:** `Tests/FitnessAppUITests/EditorDiscardSnapshotTests.swift`
  (`@testable import FitnessAppUI`, gleiches `#if canImport`-Gate wie die
  Produktionsdateien). Dafuer wurden `ExerciseSnapshot`/`TrainingDaySnapshot`/
  `PlanMetaSnapshot`/`ProfileMetaSnapshot` von `private` auf `internal`
  gestellt (keine funktionale Aenderung, nur Sichtbarkeit innerhalb des
  Moduls fuer `@testable import`). Die Tests pruefen Capture/Apply-
  Rundreisen und Mehrfeld-Reverts (inklusive des neu erfassten
  `targetEnvironment`/`isActive`-Paars) — bewusst NUR die reine Struct-
  Logik. Was NICHT getestet wird, weil es einen echten View-/UI-Test-
  Harness braucht, den dieses Repo nicht hat: die View-seitige
  Verdrahtung selbst (genau die Stelle, an der der oben beschriebene
  invertierte-Bedingung-Fehler sass) sowie die Cross-Entity-Seiteneffekte
  (Custom-Template-Ruecksync, Plan-Reaktivierung).
- **Diese Tests laufen NICHT auf Linux** — exakt dieselbe `#if canImport`-
  Einschraenkung gilt fuer die Testdatei selbst. Sie kompilieren und laufen
  nur auf einem Apple-Runner.
- **Automatischer Apple-Build ist nach dem Push bereits angestossen:**
  `codemagic.yaml` definiert zwei Workflows, `swift-package` und `ios-app`,
  BEIDE mit `triggering: events: [push, pull_request]` auf
  `branch_patterns: '*'` — jeder Push auf irgendeinen Branch startet
  automatisch einen `mac_mini_m2`-Lauf mit echtem Xcode: `swift build`/
  `swift test --parallel` auf macOS (wo `canImport(SwiftUI)` wahr ist —
  die neuen Tests liefen dort also tatsaechlich) PLUS
  `xcodebuild -scheme FitnessAppUI -destination 'generic/platform=iOS
  Simulator'` fuer alle Library-Targets PLUS den vollen App+Widget-Build
  via `ios-app`. Diese Session kann den Lauf weder selbst anstossen noch
  einsehen, aber er passiert automatisch durch das Pushen dieses Commits —
  bei einem Fehlschlag geht automatisch eine E-Mail an die hinterlegte
  Adresse (`publishing.email.recipients`, `notify.failure: true`). Das ist
  exakt der Mechanismus, der in dieser Epic bereits dreimal echte Apple-
  seitige Bugs gefangen hat (Log 16/17/18, Teile 10-12) — kein Linux-
  Workaround, sondern dieselbe reale Pruefung wie immer.
- **Was auch nach einem gruenen Codemagic-Lauf offen bleibt:** visuelles
  Layout, tatsaechliches Verhalten der Dialoge/Gesten auf einem Geraet,
  und alles, was Teil 15s "Ehrliche Grenzen"-Abschnitt bereits auflistet —
  `xcodebuild ... build` fuer den Simulator beweist Kompilierbarkeit und
  Typkorrektheit, kein manuelles UI-Verhalten.

### Linux-Kontrolle (diese Session)

`swift build`/`swift test` gruen, 979/979 Tests (unveraendert — reiner
UI-Layer-Refactor plus eine neue, ebenfalls SwiftUI-gegatete Testdatei,
die auf Linux uebersprungen wird). 3 weitere xcstrings-Keys (2092 → 2095),
weiterhin 0 hardcodierte Strings, `TRANSLATIONS.md` regeneriert.

## Teil 17 — Korrektur-Runde 3: sieben weitere fachliche Befunde

User-Feedback nach Teil 16: drei gezielte Verifikations-Anfragen zum
onChange-Fix (Reorder-Discard, Rebaseline-Granularitaet, isActive-
Wiederherstellung) PLUS vier neue, unabhaengige Geraetetest-Funde
(MeasurementView-Speichern, Equipment-"Weiß ich nicht"-Persistenz,
Start-Check-Entry-Point, Mehrebenen-Swipe-Back). Alle sieben umgesetzt,
hier einzeln dokumentiert mit dem jeweiligen konkreten Fehlerbild, Fix und
Verifikationsstand.

### V1 — Reorder (Tage/Uebungen) fehlte in Dirty-Erkennung und Discard

**Befund:** `PlanEditorView.isDirty`/`DayEditorView.isDirty` verglichen nur
`PlanMetaSnapshot`/`TrainingDaySnapshot` — beide Structs klammern die
Tage-/Uebungs-LISTE bewusst aus (eigene, sofort wirksame Add/Delete-
Aktionen ohne Save/Cancel-Konzept, siehe Teil 15/16). Reines Umsortieren
per Drag&Drop ist aber WEDER ein Add noch ein Delete — es aendert nur die
Reihenfolge bestehender Items (`TrainingDay.weekday` bzw.
`Exercise.orderIndex`). Das fiel faelschlich durchs selbe Raster: weder
als "dirty" erkannt noch beim Verwerfen zurueckgerollt.

**Fix:** neuer, intersection-basierter Open-Snapshot pro Screen —
`PlanEditorView.dayWeekdayAtOpen`/`DayEditorView.exerciseOrderIndexAtOpen`
(`[PersistentIdentifier: Int]`, in `init` erfasst, da `plan`/`day` direkte
Init-Parameter sind, kein `@Query`). "Intersection-basiert" heisst: nur
Items, die beim Oeffnen UND aktuell noch existieren, werden verglichen/
zurueckgesetzt — neu angelegte oder zwischenzeitlich geloeschte Items
bleiben unangetastet (bleiben eigene, sofort wirksame Aktionen). Reine
Pruef-/Rueckschreib-Logik als `dayOrderIsDirty(comparedTo:)`/
`revertDayOrder(usingSnapshot:)` (PlanEditorView) bzw.
`exerciseOrderIsDirty(comparedTo:)`/`revertExerciseOrder(usingSnapshot:)`
(DayEditorView) ausgelagert — `internal`, expliziter Parameter statt
direktem `@State`-Zugriff, dadurch OHNE lebende SwiftUI-/Query-Umgebung
direkt testbar.

**Getestet (echte, laufende Tests statt nur Nachlesen):**
`PlanEditorView`/`DayEditorView` lassen sich als reine Struct-Werte ueber
ihren oeffentlichen `init(plan:)`/`init(day:)` konstruieren und die oben
genannten Funktionen direkt aufrufen, OHNE eine lebende SwiftUI-
Renderumgebung zu brauchen — sie beruehren ausschliesslich den
uebergebenen `plan`/`day` (normaler Objekt-Verweis) und ihre eigenen
expliziten Parameter, nie `@Query`/`@Environment`-rueckgebundene
Properties. Vier neue Tests in `EditorDiscardSnapshotTests.swift`:
reines Umsortieren zweier Tage wird als dirty erkannt und exakt
zurueckgerollt; ein NEU waehrenddessen angelegter Tag bleibt beim
Reorder-Revert unangetastet (Gegenprobe fuer die Intersection-Logik);
dieselben zwei Faelle nochmal fuer Uebungen in `DayEditorView`.

### V2 — rebaselineSnapshot() bestaetigte unbeabsichtigt andere Felder mit

**Befund:** `PlanEditorView.rebaselineSnapshot()` (nach einer bestaetigten
Umgebungs-Migration, Adapt/Restore) machte ein VOLLES Re-Capture des
gesamten `PlanMetaSnapshot`. Haette der User zu diesem Zeitpunkt noch eine
ANDERE, unabhaengige Aenderung offen gehabt (z.B. `customName` getippt,
aber noch nicht verlassen), waere die beim naechsten Verwerfen-Versuch
faelschlich mit "bestaetigt" worden — die Migrations-Bestaetigung haette
lautlos auch den Namen festgeschrieben, obwohl der User dafuer nie
"Verwerfen"/"Speichern" gedrueckt hat.

**Fix:** `rebaselineSnapshot()` → `rebaselineTargetEnvironment()`,
schreibt NUR `snapshot.targetEnvironment = plan.targetEnvironment` fort.
Alle anderen Snapshot-Felder bleiben unberuehrt und damit weiterhin ganz
normal ueber `isDirty`/Verwerfen rueckrollbar.

**Getestet:** `testPlanMetaSnapshotTargetedRebaselineLeavesOtherFieldsDirty`
(`EditorDiscardSnapshotTests.swift`) — simuliert exakt das Szenario
(gleichzeitig `customName` UND `targetEnvironment` geaendert, dann die
gezielte Rebaseline nachgebildet) und prueft, dass `customName` danach
weiterhin als abweichend/revertierbar gilt, waehrend `targetEnvironment`
als bestaetigt gilt. Reiner Struct-Test auf `PlanMetaSnapshot` (bereits
seit Teil 16 `internal`), keine View-Instanziierung noetig.

### V3 — isActive-Reaktivierung sah nur den unmittelbaren Vorher-Zustand

**Befund:** Szenario "Plan A ist aktiv → User oeffnet Editor fuer Plan B →
schaltet B an (verdraengt A ueber `setActive(true)`) → schaltet B wieder
aus (`setActive(false)` reaktiviert NIEMANDEN automatisch) → zurueck":
`plan.isActive` ist am Ende wieder `false`, identisch zur Baseline — der
reine Feld-Vergleich meldete faelschlich "nicht dirty", und
`revertToSnapshot()`s Reaktivierungs-Bedingung (`wasActiveBeforeRevert`,
der unmittelbare Zustand VOR dem Revert-Aufruf) griff ebenfalls nicht.
Ergebnis: A blieb dauerhaft inaktiv, ohne dass der User das je sehen oder
rueckgaengig machen konnte.

**Fix:** zwei Ebenen.
1. Neue `isOtherActivePlanStateDirty`-Pruefung: wenn dieser Plan selbst
   (wieder) inaktiv ist UND der beim Oeffnen aktive andere Plan
   (`otherActivePlanIDAtOpen`) aktuell NICHT mehr aktiv ist, gilt der
   Screen als dirty — unabhaengig vom einfachen Feld-Vergleich.
2. `revertToSnapshot()`s Reaktivierungs-Bedingung vereinfacht: reaktiviert
   `otherActivePlanIDAtOpen` jetzt UNBEDINGT (statt nur bei
   `wasActiveBeforeRevert`). Beweisfuehrung: `snapshot.apply(to: plan)`
   schreibt `isActive` immer auf die Baseline zurueck; die Invariante
   "otherActivePlanIDAtOpen ist nur gesetzt, wenn diese Baseline `false`
   war" (von `setActive`s "hoechstens ein aktiver Plan"-Garantie erzwungen)
   bedeutet: nach dem Zurueckschreiben ist `plan.isActive` in diesem Fall
   immer `false` — die unbedingte Reaktivierung ist deshalb entweder
   korrekt (genau der gemeldete Bug-Fall) oder ein folgenloses No-Op (A war
   die ganze Zeit ueber aktiv geblieben). Beide Pfade teilen sich jetzt
   dieselbe `planToReactivateOnDiscard(otherActivePlanIDAtOpen:
   amongCandidates:)`-Lookup — `internal`, explizite Parameter statt
   `@State`/`@Query`-Zugriff, direkt testbar.

**Getestet:** drei neue Tests. Das gemeldete Szenario exakt nachgebildet
(A aktiv, B an, B aus, dann `planToReactivateOnDiscard` aufgerufen — muss
A liefern, `.isActive = true` darauf stellt den korrekten Zustand wieder
her); Gegenprobe "anderer Plan war die ganze Zeit aktiv geblieben" (muss
ebenfalls A liefern, Reaktivierung ist dann ein belegtes No-Op); Gegenprobe
"kein anderer Plan war beim Oeffnen betroffen" (liefert `nil`).

### V4 — MeasurementView: Haken oben rechts speicherte nie

**Befund:** `MeasurementView` hatte als einziger der urspruenglich
genannten Editoren (Teil 15/16 deckten `BodyDataEditorView`,
`TrainingLocationEquipmentEditorView`, `ExerciseLibraryEditorSheet`,
`ExerciseEditorView`, `DayEditorView`, `PlanEditorView`, `ProfileEditorView`
ab — `MeasurementView` war nie Teil davon) nie das DeltiqHeader-Muster
bekommen. Der Stift/Haken oben rechts togglete nur einen reinen Lese-/
Editier-Modus (`isEditingEnabled`) OHNE jemals `save()` aufzurufen — ein
User, der ihn in Erwartung eines Speicherns antippte (die seit Teil 15/16
etablierte App-weite Konvention: Haken oben rechts = Speichern), verlor
seine Eingabe kommentarlos, wenn er danach ueber den Chevron verliess
(der ohne Aenderungs-Schutz sofort schloss). Die tatsaechliche Speicherung
lief ausschliesslich ueber einen SEPARATEN Button ganz unten im Screen —
genau das Muster, das Teil 15 fuer alle anderen Editoren bereits abgeloest
hatte.

**Fix:**
- Separate Lese-/Editier-Modus-Unterscheidung (`isEditingEnabled`/
  `fieldsEnabled`) komplett entfernt — eine bestehende Messung ist beim
  Oeffnen sofort editierbar, wie jeder andere Editor dieser Epic.
- Haken oben rechts (`headerActions`) ist jetzt die EINZIGE Speichern-
  Aktion, in New- UND Edit-Mode, `isDisabled: !canSave(profile:)`, ruft
  `save(profile:)` direkt auf.
- Separater Speichern-Button unten (`actionsSection`) entfernt — Loeschen
  bleibt unten, rot, wie vorgegeben.
- Neuer Verwerfen-Schutz: `showingDiscardConfirm` + `discardChangesConfirmation`
  auf dem Zurueck-Chevron (nur Edit-Mode, New-Mode bleibt Tab-Root ohne
  Chevron), `.deltiqSwipeBackEnabled(isEditMode ? !isDirty : true)`.
  `isDirty` vergleicht gegen einen neuen `MeasurementFieldSnapshot`
  (9 Formularfelder, direkt nach dem Edit-Mode-Prefill erfasst). Kein
  `apply(to:)` noetig: dieser Screen schreibt Feldaenderungen NIE direkt
  ins SwiftData-Model (reiner Draft in `@State`, wie `BodyDataEditorView`)
  — "Verwerfen" ist deshalb ein einfaches `dismiss()`.
- `save()` selbst (die Logik, die die EXISTIERENDE `BodyMeasurement`
  ueberschreibt statt eine zusaetzliche anzulegen) war inhaltlich bereits
  korrekt und unveraendert — der Bug sass ausschliesslich in der
  Verdrahtung, WELCHER Button sie aufruft.
- 5 verwaiste xcstrings-Keys entfernt (`measurement.title.detail`,
  `measurement.action.save`/`saveEdit`, `measurement.validation.missing.one`/
  `many` — alle ohne verbleibende Swift-Referenz nach dem Umbau).

**Getestet:** `MeasurementFieldSnapshot`s Equatable-Vertrag (gleicher
Feldstand gleich, ein geaendertes Feld ungleich) und Default-Init (alle
`nil`) — zwei neue Tests. Die eigentliche Verdrahtungs-Korrektur (Haken
ruft jetzt `save(profile:)` statt `isEditingEnabled.toggle()` auf) ist
reine View-Verdrahtung ohne `@Query`/`@Environment`-freie Pure-Logic-
Stelle und bleibt — wie in Teil 16 Punkt 5 bereits fuer vergleichbare
Faelle dokumentiert — nur per echtem Geraete-/Simulator-Test
verifizierbar: **auf einem Geraet/Simulator muss geprueft werden, dass der
Haken beim Bearbeiten einer bestehenden Messung tatsaechlich die
EXISTIERENDE Zeile aktualisiert (keine zusaetzliche Zeile entsteht) und
die Aenderung nach erneutem Oeffnen sichtbar bleibt.**

### V5 — Equipment "Weiß ich nicht" (Bank/Klimmzugstange) nicht persistent

**Befund (Root Cause genau lokalisiert):** `UserBodyProfile.equipmentProfile`
persistierte `UserEquipmentProfile.availability` ueber genau ZWEI
Rohlisten (`equipmentAvailableItemsRaw`/`equipmentUnavailableItemsRaw`) —
ein Item landet in der einen, der anderen, oder KEINER (= `.unknown` via
Abwesenheit). `EquipmentProfileEditor`s `BenchChoice`/`TriStateChoice`
schreiben fuer "Weiß ich nicht" aber bewusst ein EXPLIZITES
`availability[item] = .unknown` ins In-Memory-Struct (nicht einfach den
Eintrag entfernen — siehe deren eigene Dokumentation, "Pflicht-Test 6").
Der Persistenz-Setter kannte diesen dritten Fall nicht: `.unknown` passte
in KEINEN der beiden `compactMap`-Filter und landete dadurch in KEINER
Rohliste — exakt dieselbe Rohdarstellung wie "nie angefasst". Nach dem
naechsten Lesen war die bewusste Aussage von einem echten Nie-Angefasst-
Item nicht mehr unterscheidbar. Der sichtbare Schaden trat beim naechsten
`confirmRemainingAsUnavailable()`-Aufruf auf (z.B. beim Abschluss der
Erfassung): der pruefte `availability[item] == nil` (Dictionary-Abwesenheit)
und kippte die bewusste "weiß ich nicht"-Aussage dadurch lautlos zu
`.unavailable` — **nur bei Bank/Klimmzugstange ueberhaupt beobachtbar**,
weil nur diese beiden Items im UI ueberhaupt eine dritte, explizite
"Weiß ich nicht"-Option haben (jedes andere Item kennt nur toggle an/aus,
"aus" bedeutet dort schon immer "entfernt" = unknown, es gibt dort gar
keine explizite Unknown-Aussage zu verlieren).

**Architektur-Trennung bereits korrekt (verifiziert, nicht neu gebaut):**
die Gym-Planungs-Annahme (`EquipmentPlanningContext.gymDefault`, nimmt
Bank/Klimmzugstange als "wahrscheinlich vorhanden" fuer Matching/Vorschau
an) wird NIRGENDS in den Code-Pfaden in `UserBodyProfile.equipmentProfile`
zurueckgeschrieben — `effectiveProfile` fliesst ausschliesslich in
`PlanSelectionResolver.resolve`/`ProgramInstantiator.instantiate`/
Staleness-Vergleiche, nie in einen Setter. Explizit per Grep bestaetigt:
keine Fundstelle `profile.equipmentProfile = ...effectiveProfile`
irgendwo im Repo. Der Bug lag ausschliesslich in der Zwei-statt-Drei-
Listen-Persistenz, nicht in einer Vermischung von Annahme und
gespeicherter Antwort.

**Fix:** dritte Rohliste `equipmentUnknownItemsRaw: [String] = []` auf
`UserBodyProfile` (gleiches "ein Feld pro Wert"-Array-Muster, Default
leer → Lightweight-Migration fuer Bestand). Getter liest sie als dritten
Durchlauf (`availability[item] = .unknown`), Setter schreibt explizites
`.unknown` dort hinein statt es verschwinden zu lassen. CSV-Export/Import
(`DataExportService`/`DataImportService`) um die fuenfte additive Spalte
`equipment_unknown_items` ergaenzt — aeltere Importer/ZIPs liefern "" (=
kein explizites Unknown aus der Zeile, identisch zum Vorher-Verhalten).

**Getestet:** vier neue Tests. `UserBodyProfileTests`:
(1) explizites Unknown landet in der neuen dritten Liste UND bleibt beim
Lesen `.unknown` fuer genau das eine Item, waehrend ein zweites Item
`.available` bleibt; (2) der eigentliche Kernvertrag — explizites Unknown
fuer `.adjustableBench` ueberlebt `confirmEquipmentProfileComplete()`
(ruft intern genau den Getter→`confirmRemainingAsUnavailable()`→Setter-
Pfad auf, der vor dem Fix gebrochen war), waehrend ein wirklich nie
angefasstes Item weiterhin zu `.unavailable` kippt — exakt das Gegenteil
des gemeldeten Bugs. `DataPortabilityRoundtripTests`: derselbe Kernvertrag
zusaetzlich durch einen ECHTEN CSV-Export/Import-Rundlauf hindurch (nicht
nur den In-Memory-Setter/Getter) — bestaetigt, dass die neue Spalte auch
bei Backup/Restore nicht verloren geht. Alle vier bauen auf der bereits
bestehenden `EquipmentRequirementTests.
testConfirmRemainingAsUnavailableNeverOverridesAnExplicitlyUnknownItem`
(Core-Struct-Ebene, Teil des Pflicht-Test-6-Katalogs) auf, die den
Vertrag fuer das reine `UserEquipmentProfile`-Struct schon laenger belegt
— die neuen Tests schliessen die Luecke genau an der Stelle, wo das reine
Struct endet und die SwiftData-Persistenz beginnt (dort sass der Bug).

### V6 — Start-Check-Einstieg aus "Profil bearbeiten" entfernt

**Befund:** `ProfileEditorView.coachingCard` hatte seit Teil zuvor (UX-Fix
P3 §6) einen Wiedereinstiegs-Punkt fuer den optionalen Start-Check
("wiederholbar jederzeit nach dem Onboarding aus Profil/Einstellungen").
Sollte ausserhalb des Onboardings entfernt werden.

**Fix:** `DeltiqRow` ("Start-Check", Status-Text, Chevron) +
`.sheet(isPresented: $showingBaselineCheck) { BaselineCheckFlowView(...) }`
+ das zugehoerige `@State private var showingBaselineCheck` +
`baselineCheckStatusText` vollstaendig entfernt. `profile.
baselineAssessment` (das gespeicherte Ergebnis) und der Flow im
Onboarding (`OnboardingView.baselineCheckStep`/`BaselineCheckFlowView`)
sind davon komplett unberuehrt — per Grep bestaetigt, dass
`baselineAssessment` nirgends sonst in `ProfileEditorView.swift`
angefasst wird und `OnboardingView.swift` keine einzige Zeile geaendert
wurde. Die danach letzte Zeile der Section (`coachingTone`-Picker)
bekommt `showsDivider: false`, damit keine verwaiste Trennlinie vor dem
Footer-Hinweis uebrig bleibt. 2 verwaiste xcstrings-Keys entfernt
(`profile.coaching.baselineCheck`/`.notDone`) — `profile.coaching.footer`
bleibt, der Text beschreibt die Goal-/Tone-Picker darueber, nicht den
entfernten Start-Check-Einstieg.

**Getestet:** keine neue Logik, reine UI-Entfernung ohne neuen Pure-Code
— Verifikation ueber Code-Lesen + Grep (s.o.), kein neuer Unit-Test
sinnvoll moeglich/noetig.

### V7 — Swipe-Back funktionierte nur einmal ueber mehrere Navigationsebenen

**Befund (Repro-Pfad im Repo konkret nachvollzogen):** `SettingsLibrary
EquipmentView` → `ExerciseLibraryView` (Push) → `ExerciseDetailView`
(Push ueber `.navigationDestination(item:)`) — alle drei nutzen das
Standard-Signature-Geruest (`.navigationBarBackButtonHidden(true)` +
`.deltiqSwipeBackEnabled()`). Swipe-Back von Ebene 3→2 funktionierte,
aber danach 2→1 nicht mehr.

**Root Cause:** `SwipeBackEnabler` (Theme.swift) hostete bisher einen
BLOSSEN `UIViewController()` und aktivierte
`interactivePopGestureRecognizer` einmalig in `makeUIViewController` —
das feuert genau EINMAL pro Push. `.navigationBarBackButtonHidden(true)`s
dokumentierte Nebenwirkung (deaktiviert denselben Gesture-Recognizer)
feuert dagegen bei JEDEM erneuten Sichtbarwerden eines Screens neu — auch
wenn kein neuer Push stattfindet, sondern nur ein darueber gepushter
Screen wieder weggepoppt wird und dieser Screen dadurch wieder oben im
Stack steht. Konkret: Ebene 2 bekam ihr Re-Enable beim eigenen Push (vor
Ebene 3) genau einmal, dieses wurde durch Ebene 3s Push + Pop-Zyklus
wieder kassiert, und nichts re-aktivierte es erneut, als Ebene 2 dadurch
wieder sichtbar wurde (`makeUIViewController` feuert fuer Ebene 2 nicht
noch einmal).

**Verifikation der Hypothese (vor dem Fix, da auf Linux nicht
kompilierbar/laufbar pruefbar):** gezielte Websuche gegen Apple-
Developer-Forum-Threads und UIKit-Referenzdokumentation bestaetigt (a)
`UIViewController.viewWillAppear(_:)` feuert nachweislich bei JEDEM
Sichtbarwerden eines Screens, explizit auch nach dem Pop eines
darueberliegenden Screens (hohe Konfidenz, mehrere unabhaengige Quellen
inkl. UIKit-Referenztext), (b) das Symptom "Custom-Back-Button killt
Swipe-Back nach mehreren Ebenen, Re-Enable in `.onAppear`-aequivalenten
Hooks behebt es" ist in unabhaengigen Quellen mehrfach dokumentiert. Als
robustere Alternative identifiziert, aber bewusst NICHT umgesetzt: den
Gesture-Delegate einmalig zentral auf dem `UINavigationController` selbst
zu setzen (staerkster Community-Standard-Fix) — in diesem Repo nicht
ohne Weiteres erreichbar, da die Navigation komplett ueber SwiftUIs
`NavigationStack` laeuft und SwiftUI den dahinterliegenden
`UINavigationController` intern verwaltet (nicht direkt austauschbar ohne
eine Introspection-Bibliothek wie `swiftui-introspect`, die dieses Repo
nicht nutzt) — eine bewusste Scope-Entscheidung fuer den kleineren, bereits
im etablierten Pro-Screen-Muster verifizierten Fix statt einer groesseren
Architektur-Aenderung ohne Simulator-Verifikationsmoeglichkeit in dieser
Session.

**Fix:** `SwipeBackEnabler` hostet jetzt eine echte `UIViewController`-
Subklasse (`SwipeBackHostController`) statt eines bloss gehosteten
Controllers — nur eine Subklasse bekommt echte Lifecycle-Callbacks. Das
Re-Enable laeuft jetzt in `viewWillAppear(_:)` (feuert bei JEDEM
Sichtbarwerden) statt ausschliesslich in `makeUIViewController`
(ergaenzt dort um einen zusaetzlichen, async-verzoegerten Aufruf als
Sicherheitsnetz fuer den allerersten Push, falls `viewWillAppear` in
einem noch unbekannten Einbettungsfall doch einmal ausbleiben sollte).
Die Subklasse ist direkt ihr eigener `UIGestureRecognizerDelegate` — die
separate `Coordinator`-Klasse mit ihrer `weak var navigationController`
(potenziell veraltende, gecachte Referenz) entfaellt komplett:
`self.navigationController` loest UIKits eigene Eltern-Traversierung bei
JEDEM Aufruf frisch auf. Zentrale Komponente, genutzt von **26 Screens**
im gesamten Repo (per Grep auf `.deltiqSwipeBackEnabled(` bestaetigt) —
der Fix wirkt dadurch auf jeden
Mehrebenen-Navigationspfad der App gleichzeitig, keine Pro-Screen-
Aenderung noetig.

**Getestet:** keine automatisierte Pruefung moeglich — reine UIKit-
Lifecycle-/Gesture-Recognizer-Interaktion, die einen lebenden
Navigation-Stack in einem echten Fenster braucht (XCUITest/Simulator),
kein extrahierbarer Pure-Code-Kern wie bei V1/V3. Verifikation bislang
ausschliesslich ueber (a) Code-Nachvollzug des exakt gemeldeten Repro-
Pfads im Repo, (b) externe Recherche zur UIKit-Lifecycle-Garantie (s.o.).
**Auf einem Geraet/Simulator muss geprueft werden:** Settings → Library
&Equipment → Uebungsbibliothek → eine Uebung oeffnen → zweimal
hintereinander per Edge-Swipe zurueckwischen (muss beide Male
funktionieren, nicht nur einmal); dieselbe Probe auf mindestens einem
weiteren Mehrebenen-Pfad (z.B. ueber den Plan-Tab: Plan → Trainingstag
→ zurueck → zurueck); Gegenprobe, dass normale Menü-Seiten OHNE offene
Aenderungen weiterhin ganz normal per Swipe verlassen werden koennen
(`enabled: false`-Faelle wie `WorkoutSummaryView` im frischen Post-
Finish-Modus unveraendert gesperrt); Gegenprobe, dass In-Editor-Swipes
(TabView.page in `ActiveWorkoutView`) und Drag&Drop-Reorder (Tage/
Uebungen) von dieser Aenderung vollstaendig unberuehrt bleiben — die
Aenderung betrifft ausschliesslich die Navigations-Stack-Pop-Geste, nie
ein In-Content-Gesture.

### Ehrliche Grenzen dieser Korrektur-Runde (verschaerfte Fassung ggue. Teil 16)

Teil 16 stellte bereits fest, dass Linux `swift build`/`swift test` die
betroffenen Dateien nur ueberspringt. Diese Session hat das jetzt EXPLIZIT
verifiziert statt nur angenommen: ein kleines Probe-Skript
(`#if canImport(SwiftUI/SwiftData/UIKit)`) bestaetigt, dass alle drei in
dieser Linux-Umgebung `false` sind. Das bedeutet konkret:

- **Jede** Datei, die mit `#if canImport(SwiftUI)` beginnt — das betrifft
  ausnahmslos ALLE `.swift`-Dateien in `FitnessAppUI` (inkl. `Theme.swift`
  selbst, also auch V7) UND die dazugehoerigen Testdateien — kompiliert
  auf Linux zu einer LEEREN Uebersetzungseinheit. `swift build`/`swift
  test` gruen beweist fuer diese Dateien NICHTS ausser "der Rest des
  Pakets kompiliert weiterhin".
- Fuer `FitnessAppData`-Dateien (`#if canImport(SwiftData)`, kein
  `SwiftUI`-Erfordernis) gilt dasselbe — auch `UserBodyProfile.swift`,
  `DataExportService.swift`, `DataImportService.swift` und ihre
  Testdateien (V5) liefen auf Linux NICHT tatsaechlich durch den
  Compiler/Testrunner, exakt verifiziert durch denselben Probe-Befund
  (`canImport(SwiftData) == false`) PLUS die direkte Beobachtung, dass
  die Gesamt-Testanzahl (979) sich durch alle neuen Tests dieser Session
  (V1, V3, V5, zusammen 13 neue Testfunktionen ueber drei Dateien) NICHT
  veraendert hat — der beweiskraeftigste verfuegbare Beleg dafuer, dass
  Linux sie nie ausgefuehrt hat.
- **Was das NICHT bedeutet:** die Aenderungen sind deshalb nicht
  ungeprueft — jede einzelne Datei wurde nach der Bearbeitung vollstaendig
  per Hand erneut gelesen (inkl. Klammer-/Typ-Abgleich, bei
  `DataExportService.swift` sogar manuellem Abzaehlen von Header- gegen
  Row-Spalten, 44 gegen 44), und V5/V1/V3 haben zusaetzlich echte,
  gezielte Tests bekommen (auch wenn sie hier nicht laufen).
- **Reale Kompilierung/Testlauf passiert automatisch ueber Codemagic**
  nach diesem Push — `swift-package`-Workflow auf einem `mac_mini_m2` mit
  echtem Xcode, wo `canImport(SwiftUI/SwiftData/UIKit)` tatsaechlich
  `true` ist: `swift test --parallel` fuehrt dort ALLE heute
  hinzugefuegten Tests wirklich aus, PLUS `xcodebuild` fuer alle Library-
  Targets im iOS-Simulator, PLUS der volle App+Widget-Build. Das ist
  derselbe Mechanismus, der in dieser Epic bereits mehrfach echte Apple-
  seitige Bugs gefangen hat. Diese Session kann den Lauf weder ausloesen
  noch einsehen — bei einem Fehlschlag geht automatisch eine E-Mail an
  die hinterlegte Adresse.
- **Was auch nach einem gruenen Codemagic-Lauf offen bleibt:** JEDES der
  vier "Auf einem Geraet/Simulator muss geprueft werden"-Elemente oben
  (V4, V7) ist tatsaechliches UI-/Gesten-Verhalten, das `xcodebuild build`
  (beweist Kompilierbarkeit/Typkorrektheit) nicht abdeckt — dafuer braucht
  es einen echten Geraete-/Simulator-Durchlauf durch einen Menschen oder
  einen UI-Test, den dieses Repo nicht hat.

### Linux-Kontrolle (diese Session)

`swift build`/`swift test`: gruen, 979/979 Tests — unveraendert, da V1-V7
ausschliesslich SwiftUI-/SwiftData-/UIKit-gegatete Dateien beruehren (s.o.,
explizit per Probe-Skript verifiziert statt nur angenommen). 7 verwaiste
xcstrings-Keys entfernt (2095 → 2088, 5 nach V4 + 2 nach V6), weiterhin 0
hardcodierte Strings, `TRANSLATIONS.md` regeneriert.
