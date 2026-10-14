# Settings UX Audit

Phase 1 des Settings-Epics (`SETTINGS_FULL_REVIEW_AND_IMPLEMENTATION.md`, ersetzt/erweitert die frühere `SETTINGS_BODY_AND_EQUIPMENT_TASK.md`). Reine Bestandsaufnahme — **keine Code-Änderung in dieser Phase.**

**Methode:** 6 parallele Audit-Agents, jeweils mit Volltext-Lektüre der Zieldateien und Pflicht zur Datei:Zeile-Belegung pro Fund.

**Geprüfter Umfang:** `SettingsView` + `DashboardSettingsView` · `ProfileEditorView` + Körperdaten-Modelle (`UserBodyProfile`, `BodyMeasurement`, `MeasurementView`) · Reminder-Einstellungen + `ReminderPreferencesApplier` · `DataExportView`/`BackupListView`/`DataImportView` + Export/Backup/Import-Services + `SettingsPortability` · `HealthWorkoutWriteView`/`HealthAppLink` + Health-Services · `GearListView`/`ExerciseLibraryView`(+`EditorSheet`)/`ExerciseMediaCreditsView`.

**Legende**
- **Priorität:** P0 = Datenverlust/-korruption oder irreversible Aktion ohne Schutz · P1 = funktionale Inkonsistenz / bedeutsame UX-Falle · P2 = Politur (Accessibility, Wording, Edge Case).
- **Status:** `open` (noch nicht behoben) · `blocked` (siehe Rückfragen) · `OK` (geprüft, kein Änderungsbedarf).
- **Tests:** Zum Audit-Zeitpunkt existiert für keinen Fund bereits ein Regressionstest. Das Testmatrix wird pro Umsetzungs-Phase (Tasks #122–127) ergänzt; hier nur vermerkt, welcher Fund welche Phase braucht.

---

## Teil 1 — Priorisierte Befundliste (maschinenlesbar)

| ID | Bereich | Datei:Zeile | Prio | Befund | Vorschlag | Phase | Status |
|---|---|---|---|---|---|---|---|
| PE-01 | Profil/Körperdaten | ProfileEditorView.swift (Equipment-/Umgebungs-Save-Pfad) | **P0** | `onChange`-Bulk-Sync überschreibt `targetEnvironment` bestehender Pläne bei reinem Profil-Save | Entfernen (Spec bereits entschieden); optional spätere separate "Pläne überprüfen"-Flow | P2 | open |
| PE-02 | Profil/Körperdaten | `BodyMeasurement.makeDerived` | **P0** | Berechnet KFA/FFM/FFMI automatisch (Deurenberg-BMI-Fallback) auch ganz ohne Umfänge — läuft bereits produktiv über `OnboardingView.swift` (0 Umfänge dort je erfasst) | Automatikberechnung entfernen; BMI/BMR nur bei bewusster Eingabe | P2 | open |
| DX-02c | Daten/Export | `DataExportView.swift:239-275`, `DataExportService.swift` | **P0** | Export läuft komplett synchron auf MainActor (Kommentar behauptet `Task.detached`, Code tut es nicht) — UI friert für die volle CSV/ZIP-Dauer ein | Fetch bleibt Main, dann Sendable-DTOs bauen, CSV/ZIP-Arbeit off-Main | P5 | open |
| BL-07 | Daten/Backup | `BackupListView.swift:278-289` | **P0** | `createNow()` ist komplett synchron, kein `Task{}` — UI friert schlimmer ein als beim Export | Gleiches DTO-Snapshot-Muster wie DX-02c | P5 | open |
| DI-03 | Daten/Import | `DataImportView.swift:600-648` | **P0** | `loadPreview` läuft synchron bei jeder Dateiauswahl — entpackt+parsed das ganze ZIP auf Main, UI friert bei **jeder** Dateiwahl ein | In `Task{}` verschieben (reine Daten, kein `ModelContext` nötig) | P5 | open |
| BL-03 | Daten/Backup | `BackupListView.swift:274-276`, `BackupService.swift:209-212` | **P0** | `(try? listGenerations()) ?? []` — echter Lesefehler ist ununterscheidbar von "keine Backups vorhanden", genau das Panic-Szenario, für das der Screen existiert | Echte I/O-Fehler durchreichen, eigener Error-State statt wiederverwendetem Empty-State | P5 | open |
| BL-05 | Daten/Backup | `BackupListView.swift:182-197` | **P0** | Backup löschen: ein Tap, keine Bestätigung, irreversibel; Fehler verschluckt (`try?`); Tap-Ziel 32×32pt (< 44pt-Minimum) | Eigener `confirmationDialog`, Fehler anzeigen, Tap-Ziel vergrößern, `.accessibilityLabel` mit Datum | P5 | open |
| RS-02 | Daten/Reset | `SettingsView.swift:816-919` | **P0** | "App zurücksetzen" ist die einzige destruktive Aktion im Audit **ohne** automatisches Vorab-Backup (anders als Restore/Replace-Import) | Siehe Rückfrage 2 | P5 | **blocked** |
| SV-F01 | Settings | `SettingsView.swift:245-261` vs. `:857` / `SettingsPortability.swift:33` | P1 | `weight_unit` ist laut Portability-Whitelist eine "echte Präferenz", wird aber von Reset gelöscht — widerspricht Resets eigenem Kommentar ("Präferenzen bleiben stehen") | Default: als Präferenz behandeln, nicht löschen | P5 | open |
| SV-F07/08/09 | Settings/Dashboard | `Theme.swift` (`DeltiqControlRow`/`DeltiqRow`/`DeltiqHeaderAction`), alle Toggle/Picker/Icon-Buttons in `SettingsView.swift` + `DashboardSettingsView.swift` | P1 | Durchgängig fehlende `.accessibilityLabel` auf Toggles, Picker und Icon-only-Buttons (Gegenprobe: `HealthWorkoutWriteView.swift` macht es im selben Ordner korrekt) | Labels pro Instanz ergänzen, **nicht** die shared Theme-Components anfassen (App-weiter Radius) | P6 | open |
| DX-03/04 | Daten/Export | `DataExportView.swift:183-195, 266, 294-306` | P1 | `lastDataExportAt` wird gesetzt bevor Share/Backup bestätigt ist; `ShareSheet` hat keinen Completion-Handler | Siehe Rückfrage 3 | P5 | **blocked** |
| BL-08 | Daten/Backup | `BackupListView.swift:232-239` | P1 | Status-Text "Wird wiederhergestellt…" erscheint identisch auch beim reinen Backup-Erstellen — sachlich falsch | Eigener String je Operation (braucht Enum statt `isWorking: Bool`) | P5 | open |
| DI-09 | Daten/Import | `DataImportView.swift:705-773`, `DataImportService.swift:352-360` | P1 | `performImport` ist durchgehend synchron ohne `await` — der "live" Fortschrittsbalken kann nicht wirklich inkrementell animieren, läuft in einem Schub nach Abschluss | async + `Task.yield()` zwischen Phasen, oder ehrlicher Indeterminate-Spinner statt vorgetäuschtem Fortschritt | P5 | open |
| R-08 | Health | `HealthWorkoutWriteView.swift:242-250`, Kommentar `:242` | P1 | Diagnose-String wird unlokalisiert und ungated im **häufigen** `.blocked`-Normalfall gezeigt; Kommentar sagt "nur für TestFlight", kein Guard vorhanden | Hinter "Diagnose anzeigen"-Disclosure verstecken + lokalisieren | P4 | open |
| REM-01 | Reminder | `SettingsView.swift:459-529` (`remindersSection`) | P1 | Reminder-Toggles lesen nie den echten OS-Benachrichtigungsstatus — anders als die strukturell identische `healthKitSection` (`SV-21`), die das korrekt tut | OS-Berechtigungsstatus aktiv abfragen, Status analog `healthKitSection` anzeigen | P4 | open |
| REM-02 | Reminder | `ReminderPreferencesApplier.swift` + Onboarding-Re-Init-Pfad | P1 | Resets dokumentierte Zusage "Reminder-Prefs bleiben erhalten" wird durch hartkodierte Re-Initialisierung beim erzwungenen Re-Onboarding gebrochen | Re-Onboarding darf vorhandene, nicht-default Reminder-Prefs nicht überschreiben | P4 | open |
| GL-REN | Bibliothek | `Exercise`/`ExerciseLog`/`PersonalRecordEntry` (Core-Modelle) | P1 | Umbenennen einer eigenen Übung bricht den History-Lookup der Library (kopieren `name` beim Adoptieren, kein Rückbezug zu `ExerciseTemplate`) — falsch-leer, kein Datenverlust | Siehe Rückfrage 4 | P6 | **blocked** |
| GL-DEL | Gear | `GearListView.swift` (Lösch-Aktion) | P1 | Gear-Eintrag löschen ohne Bestätigung | Bestätigungsdialog ergänzen, analog Backup/Import-Pattern | P6 | open |
| RS-03a | Daten/Reset | `SettingsView.swift:913-919` vs. `DataImportService.swift:505-508` | P1 | Zwei unabhängig von Hand gepflegte "Alles löschen"-Sequenzen; Repo-eigenes README warnt bereits vor diesem Drift-Risiko | Gemeinsamen `wipeAllPersistentModels`-Helper extrahieren | P5 | open |
| DX-05 | Daten/Export | `DataExportView.swift:199-210, 258` | P2 | `BackupService.store`-Fehler wird per `try?` verschluckt, Export-Banner zeigt trotzdem "fertig" | Fehler nicht-blockierend zusätzlich anzeigen | P5 | open |
| SV-F02 | Settings | `SettingsView.swift:857` | P2 | `height_unit`/`unit_system` sind tote Keys, nirgends sonst referenziert | Aus Reset-Loop entfernen (Aufräumen) | P5 | open |
| SV-F13 | Settings | `HealthKitController.swift:24` | P2 | "Letzter Sync" ist nur In-Memory, verschwindet nach jedem Kaltstart | Persistieren oder als "diese Sitzung" kennzeichnen | P4 | open |
| GL-NAME | Gear/Profil | `GearListView.swift` Titel vs. `ProfileEditorView.swift` Equipment-Sheet-Titel | P2 | Beide heißen identisch "Ausrüstung", keine Unterscheidung auf dem Screen | Siehe Rückfrage (optional, niedriges Risiko — Default: disambiguieren, s.u.) | P3 | open |
| R-24 | Health | `HealthKitController.swift:130-231` | P2 | Gewicht-Schreibstatus wird als Lese-Gate für andere Health-Typen (Puls/Schritte/Größe) zweckentfremdet — niedriges Realrisiko, da alle Typen in einem Consent-Dialog hängen | Nur relevant, falls Consent-Dialoge je getrennt werden | — | OK (kein Handlungsbedarf jetzt) |

*(P2-Funde ohne Produktrelevanz — z. B. bereits korrekt verifizierte Picker-Beschriftungen — sind unten in den Detailtabellen, aber nicht in dieser Kurzliste, um sie als Kurzliste nutzbar zu halten.)*

### Bereits korrekt — nicht anfassen

- `BodyMeasurement` ist bereits das alleinige Gewichts-Verlaufsmodell; `UserBodyProfile` hat kein eigenes Gewichtsfeld (nur `goalWeightKg`).
- Health: keine Fabrikation von Kalorien/Puls (App-Review-5.1.3(ii)-Kommentar im Code); ehrliche Teilergebnis-Anzeige bei Abbruch ("12 von 40"); Blind-Spot-Warnung bereits im UI; typ-spezifische Berechtigungen bereits sauber getrennt (Workout write ≠ Workout read ≠ Distanz).
- Import: Vorschau vor jedem Replace, zweistufige Append/Replace-Bestätigung (unterschiedliche Dialoge/Farben/Icons), automatisches Vorab-Backup vor jedem Replace — alles bereits vorbildlich umgesetzt, **unbedingt erhalten**.
- Deload-Toggle (`SV-14`) und "Gesenkte Gewichte zurücksetzen" (`SV-15`) sind bereits sauber entkoppelt — Toggle steuert nur künftige Vorschläge, nie aktive Gewichte.
- Timer-Vorlauf zeigt bei 0 bereits "Aus"/"Off", nicht "0".
- Reset lässt Apple-Health-Daten nachweislich unangetastet (keine HealthKit-Symbole im Reset-Pfad) und löscht bereits alle 11 SwiftData-Modelltypen vollständig.
- `DashboardSettingsView`: Autosave über `@Bindable` ist das etablierte App-Muster, kein Fehler.

---

## Teil 2 — Detailbefunde je Bereich

### 2.1 SettingsView + DashboardSettingsView

32 Zeilen in `SettingsView.swift`, 7 in `DashboardSettingsView.swift`. Vollständige Zeilen-für-Zeilen-Tabelle (alle `SV-01`…`SV-32`, `DSV-01`…`DSV-07`, inkl. aller als "OK" geprüften Zeilen) liegt im Agenten-Rohbericht; die Funde daraus sind oben in Teil 1 (`SV-F01/02/07/08/09/13`) eingeflossen. Kernaussagen:

- Reminder-Zeilen (`SV-16`…`SV-20`, Wasser/Messung + Unterfragen) sind **innerhalb** von `SettingsView.swift`, nicht in einer eigenen Datei — darum teilen sie sich die generische `permission dependency`-Spalte ("lokale Benachrichtigungen") mit dem tieferen REM-01/02-Befund aus 2.6.
- Health-Zeilen (`SV-21`…`SV-25`) sind reine Status-/Navigations-Zeilen; die eigentlichen Toggles mit korrekten Accessibility-Labels liegen in `HealthWorkoutWriteView.swift` (siehe 2.5) — nicht doppelt zählen.
- Reset (`SV-32`) ist bereits die letzte Section im Scroll (korrekt platziert), aber strukturell nicht von den anderen Cards abgehoben — nur Farbe/Icon unterscheiden sie.
- `DashboardSettingsView`: Hero-Slots sind hart auf 3 begrenzt (`HeroMetricType.maxSlots`), normale Widgets uncapped — beide Listen nutzen "Toggle mit `get` immer `true`, `set(false)` entfernt das Element" als Muster, kein Bug, aber `DSV-01` (Reorder/Edit-Header-Button) ist die **schwerste** Einzel-Accessibility-Lücke im ganzen Audit: komplett icon-only, kein Label in keinem der beiden Zustände.

### 2.2 Profil & Körperdaten (ProfileEditorView, UserBodyProfile, BodyMeasurement, MeasurementView)

*Diese Teiltabelle wurde aus der Erstauswertung übernommen; eine zeilengenaue Nachlieferung (Datei:Zeile für jede Einzel-Zeile des Editors) folgt als kleiner Ergänzungs-Commit, sobald die Nachbearbeitung der Rohdaten abgeschlossen ist. Die beiden P0-Befunde (`PE-01`, `PE-02`) sind bereits mit hoher Konfidenz bestätigt und fließen unverändert in Phase 2 ein.*

- **`PE-01` — Plan-Bulk-Sync:** Eine `onChange`-Beobachtung auf die Trainingsort-Auswahl löst beim reinen Speichern des Profils eine Massenänderung an `targetEnvironment` auf **bestehenden** Trainingsplänen aus — ein Seiteneffekt, den ein Nutzer beim "ich ändere nur mein Profil"-Vorgang nicht erwartet und nicht sieht. Exakte Zeile wird beim Umsetzen in Phase 2 am aktuellen Code erneut verifiziert (Datei ändert sich ohnehin durch den neuen kombinierten Trainingsort+Ausstattung-Screen aus Phase 3).
- **`PE-02` — Fabrizierte Körperfett-Werte:** `BodyMeasurement.makeDerived` berechnet bei fehlenden Umfängen unbedingt einen Deurenberg-BMI-Fallback für Körperfett (und darauf aufbauend FFM/FFMI). Das Onboarding ruft diesen Pfad bereits produktiv auf, ohne je Umfänge zu erfassen — jeder Onboarding-Nutzer bekommt aktuell einen unausgewiesenen Schätzwert als vermeintlich echten Wert gespeichert.
- Architektur-Fakt (bestätigt, Grundlage für Phase 2): `UserBodyProfile` hat **kein** eigenes Gewichtsfeld; `BodyMeasurement` ist bereits die alleinige Quelle für Gewichtsverlauf. Der neue `makeWeightOnly`-Service kann direkt darauf aufsetzen, ohne Modelländerung an `UserBodyProfile`.

### 2.3 Daten-Export / Backup / Import / Reset

Vollständig ausgewertet (`DataExportView.swift`, `BackupListView.swift`, `DataImportView.swift`, `DataExportService.swift`, `BackupService.swift`, `DataImportService.swift`, `SettingsPortability.swift`, Reset-Abschnitt in `SettingsView.swift`). 27 Zeilen (`DX-01`…`05`, `BL-01`…`09`, `DI-01`…`10`, `RS-01`…`03`), Funde oben in Teil 1 eingeflossen (`DX-02c/03/04/05`, `BL-03/05/07/08`, `DI-03/09`, `RS-02/03a`).

**Drei-Zustände-Verwechslung bei `lastDataExportAt`** (zentraler Fund, siehe Rückfrage 3): Der Code kennt faktisch vier Zustände — ① Export-Datei erstellt (ephemer, `Caches/`) → ② lokale Backup-Generation gespeichert (`Documents/Backups/`, Fehler dabei per `try?` verschluckt) → ③ Nutzer hat tatsächlich extern geteilt (**nie geprüft**, `ShareSheet` ohne Completion-Handler) → ④ `lastDataExportAt` wird **bei ①**, also vor ② und weit vor ③, gesetzt. Das Dashboard liest `lastDataExportAt` aber so, als bedeute es "Nutzer hat eine sichere Kopie" — das ist nur für Zustand ① belegt.

**Concurrency-Befund (Export/Backup/Import):** Alle drei Flows (`DataExportView.startExport`, `BackupListView.createNow`/`restore`, `DataImportView.loadPreview`) laufen faktisch synchron auf dem MainActor, obwohl der Export-Code-Kommentar `Task.detached` behauptet. Das lässt sich nicht einfach per Rename beheben, da `ModelContext` nicht `Sendable` ist — es braucht einen echten DTO-Snapshot-Grenzzug (Fetch bleibt Main, CSV/ZIP-Bau wandert off-Main). Reale Architekturänderung (~700 Zeilen in `DataExportService.swift`), aber von der Vorgabe selbst bereits gefordert ("Export-Actor/Blocking-Problem behoben").

### 2.4 Apple Health (HealthWorkoutWriteView, HealthAppLink)

Vollständig ausgewertet (850+36 Zeilen UI, plus `HealthKitController`/`HealthKitTypes`/`HealthKitService`/`HealthKitError`/`HealthWorkoutWriter`/`WorkoutHealthExportService`/`HealthWritePreferences`/`HealthExportMarker`). 25 Zeilen (`R-01`…`25`), nur **ein** P1-Fund (`R-08`, Diagnose-String), Rest P2 oder bereits korrekt.

Bestätigt vorbildlich: ehrliche Teilergebnis-Anzeige bei Abbruch (verarbeitete/gesamt, keine Rollbacks bereits geschriebener Einträge), Blind-Spot-Warnung im Vorschau-Screen ("HealthKit verrät nicht, was schon drin ist"), keine Kalorien-/Puls-Fabrikation (App-Review-Begründung im Code), typ-spezifische Berechtigungen sauber getrennt von Lese-/Schreib-Status.

Einziger offener Terminologie-Fund: "Daten übernehmen" (Profil-Pull) / "Workout-Import" (Settings-Toggle) / `HealthWorkoutWriteView` (reine Schreib-Optik, fragt aber bei "Trainings prüfen" intern auch eine Lese-Berechtigung ab) sind drei uneinheitlich benannte Berührungspunkte — von der Vorgabe selbst bereits klar entschieden ("separate Einträge 'Daten übernehmen' vs. 'Trainings an Health senden'"), daher kein Blocker, nur Umsetzungsarbeit in Phase 4.

### 2.5 Reminder (Wasser-/Messungs-Erinnerungen)

*Ebenfalls aus der Erstauswertung übernommen, zeilengenaue Nachlieferung für `ReminderPreferencesApplier.swift` folgt als Ergänzungs-Commit.* Die Erinnerungs-**UI-Zeilen** selbst sind bereits vollständig in 2.1 als `SV-16`…`SV-20` erfasst (Toggle + Picker, korrekt Portable, korrekt nicht von Reset gelöscht). Die zwei zusätzlichen, tieferliegenden Funde:

- **`REM-01`:** `remindersSection` fragt nie den tatsächlichen OS-Benachrichtigungsstatus ab — im Unterschied zur strukturell gleichen `healthKitSection` (`SV-21`), die das korrekt tut. Ein Nutzer, der die System-Berechtigung verweigert hat, sieht in den App-Settings trotzdem einen eingeschalteten Toggle ohne Hinweis, dass nichts ankommt.
- **`REM-02`:** Reset dokumentiert explizit, dass echte Präferenzen (wozu Reminder-Einstellungen zählen) erhalten bleiben. Dieses Versprechen wird aber unterlaufen, sobald ein erzwungenes Re-Onboarding nach Reset durchlaufen wird — das Onboarding initialisiert die Reminder-Preferences hart neu, unabhängig vom vorherigen Zustand.

### 2.6 Gear-Tracker, Exercise-Library, Media-Credits

*Ebenfalls aus der Erstauswertung übernommen, zeilengenaue Nachlieferung folgt als Ergänzungs-Commit.* Drei bestätigte Funde:

- **`GL-NAME`:** `GearListView`-Bildschirmtitel und der `navigationTitle` des Equipment-Sheets in `ProfileEditorView` sind beide wortgleich "Ausrüstung" — keine Unterscheidung auf dem Screen selbst, obwohl es sich um zwei völlig unterschiedliche Konzepte handelt (Verschleißteile-Tracker vs. Trainingsequipment-Inventar für die Plan-Filterung).
- **`GL-REN`:** `Exercise`, `ExerciseLog` und `PersonalRecordEntry` kopieren beim Adoptieren einer `ExerciseTemplate` deren `name` als reinen Wert, ohne Rückbezug. Benennt man die zugrunde liegende eigene Übung später um, bricht der "Verlauf"-Swipe-Lookup der Library für alle **vorher** geloggten Einträge (falsch-leer, kein Datenverlust — die Logs existieren weiter, sind aber nicht mehr auffindbar).
- **`GL-DEL`:** Gear-Eintrag löschen hat keine Bestätigung.

---

## Teil 3 — Alte → neue Navigation (5 Gruppen)

Quelle: vollständige Zuordnung aller 32 `SettingsView`-Zeilen (jede Unterseite hängt an genau einer davon — `DataExportView`/`BackupListView`/`DataImportView` an `SV-26/27/28`, `HealthWorkoutWriteView` an `SV-25`, `GearListView`/`ExerciseLibraryView` an `SV-04/05`, `ExerciseMediaCreditsView` an `SV-31`).

**Profil & Training**
`SV-01` Profil-Editor (+ alle Unterseiten: Körperdaten, Trainingsort+Ausstattung-Screen aus Phase 3)

**App & Trainingserlebnis**
`SV-02`+`DSV-*` Dashboard anpassen · `SV-03` Einheiten (kg/lbs) · `SV-06` Erscheinungsbild · `SV-07`…`SV-11` Timer/Sound/Haptik/Vorlauf · `SV-12`/`SV-13` Workout-Verhalten (Warmup/RIR) · `SV-14`/`SV-15` Deload (**zusammen lassen**) · `SV-16`…`SV-20` Erinnerungen

**Daten & Verbindungen**
`SV-21`…`SV-25` Apple Health (Status/Verbinden/Sync/Import/Schreiben) · `SV-26` Export · `SV-27` Backups · `SV-28` Import · `SV-32` Zurücksetzen

**Bibliothek & Ausrüstung**
`SV-04` Übungen (Library) · `SV-05` Ausrüstung/Schuhe (Gear-Tracker — **Namenskonflikt mit Equipment-Profil, siehe `GL-NAME`**)

**Hilfe & Informationen**
`SV-29`/`SV-30` Version/Bundle · `SV-31` Übungs-GIF-Credits

Offene, bewusst nicht vorentschiedene Zuordnung: `SV-03` (Einheiten) passt sowohl zu "App & Trainingserlebnis" als auch zu "Profil & Training" (da an Körperdaten-Eingabe gekoppelt) — Empfehlung: bei "App & Trainingserlebnis" belassen, da es ein reines Anzeige-Format ist, keine Dateneingabe.

---

## Teil 4 — Rückfragen (echte Blocker)

Die meisten Funde aus Teil 1 sind durch die Vorgabe selbst bereits entschieden (z. B. "keine automatische KFA/FFM/FFMI-Berechnung", "Export-Actor-Problem beheben", "separate Health-Lese-/Schreib-Einträge") und werden ohne Rückfrage in den jeweiligen Phasen umgesetzt. Vier Punkte sind fachlich nicht aus der Vorgabe ableitbar oder ändern eine bestehende Zusage — dazu siehe die anstehende Rückfrage an den User. Alles andere läuft unabhängig davon weiter.
