# Deltiq – Umfassender App-Audit

**Datum:** 2026-10-23 (Europe/Berlin)
**Auftrag:** Audit-only. Keine Codeänderung, kein Commit, kein Push.
**Prüfgegenstand:** aktueller Branch-Zustand dieses Arbeitsbaums.

---

## 2. Ausgangszustand

| Punkt | Wert |
|---|---|
| Branch | `abacus/worktree-ed931e7c` (Arbeitsbaum, Basis `main`) |
| Commit | `5e6ba39` – „fix: store FoodCatalogEntry.source as raw String to avoid SwiftData migration crash" |
| Arbeitsbaum | sauber (`git status --short` = 0 Einträge, vor **und** nach der Prüfung) |
| Struktur | Swift Package (`Package.swift`) + XcodeGen (`project.yml`, kein committed `.xcodeproj`) |
| Module | `FitnessAppCore` (reine Logik), `FitnessAppData` (SwiftData), `FitnessAppHealth`, `FitnessAppActivities`, `FitnessAppUI`, `FitnessAppAI` (Foundation Models, iOS 26+), `FitnessAppFoodLookup` (einzige netzwerkfähige Schicht) |
| Deployment-Target | iOS 17.0 (`project.yml`), macOS 14 nur als Build-Target für CI |
| Sprachen | de, en, tr – `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (kanonisch, 2518 Keys), `App/FitnessApp/InfoPlist.xcstrings`, `App/FitnessAppWidgets/Localizable.xcstrings` |
| Testtargets | `FitnessAppCoreTests`, `FitnessAppDataTests`, `FitnessAppHealthTests`, `FitnessAppUITests`, `FitnessAppAITests`, `FitnessAppFoodLookupTests` |
| CI | Codemagic (primär) + `.github/workflows/apple-ci-comparison.yml` (`workflow_dispatch`, `swift build` + `swift test --parallel` + `xcodegen`/`xcodebuild`), `.github/workflows/testflight-release.yml` |
| Externe Dienste | Open Food Facts Search-a-licious (`https://search.openfoodfacts.org/search`) – nur bei Nutzer-Opt-in; Apple Foundation Models (on-device, iOS 26+); HealthKit; ActivityKit/WidgetKit; ZIPFoundation (MIT) |
| Berechtigungen | HealthKit (Share/Update), Notifications, Live Activities, `UIBackgroundModes: audio`, `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` |

**Geprüfte Bereiche:** Navigation/Tabs/Deep-Links, Einstellungsstruktur, Ernährung (Erfassung, Tagesübersicht, Ziele), Online-Suche/Open Food Facts, KI-Ernährung, Lokalisierung/Katalognamen, Persistenz- und Snapshot-Modell, Datenschutz/Netzwerk, Architektur/Codequalität, Training/Plan-Editor (Save/Discard), vollständige Toggle-Matrix.

**Einschränkungen der Prüfung (siehe Abschnitt D):** kein macOS/Xcode, kein Simulator, kein Gerät, keine Netzzugriffe auf Open Food Facts, kein Zugriff auf Apple-Foundation-Models-Hardware. `swift build`/`swift test` konnten in dieser Umgebung **nicht** laufen (siehe E.2).

---

## 3. Schweregrade
P0 (kritisch) · P1 (hoch) · P2 (mittel) · P3 (niedrig) – Definition wie im Auftrag.

---

## A. Executive Summary

**Gesamtbild:** Der geprüfte Bereich ist erkennbar weit entwickelt und in vielen Punkten über dem Durchschnitt eines Beta-Builds: Nährwerte werden als Snapshot eingefroren (`MealItem`), fehlende Open-Food-Facts-Werte bleiben `nil` und werden **nicht** durch `0` ersetzt, die Online-Suche ist standardmäßig aus und an einen expliziten Opt-in gebunden, KI-Ergebnisse sind reine Vorschläge (Kandidaten) und erzeugen nie Nährwerte, die Zielberechnung ist deterministisch zentralisiert (`NutritionCalculations.goalProgress`), Save-Fehler werden inline gezeigt, Discard-Dialoge existieren, und Netzwerkaufrufe sind auf genau ein Modul begrenzt.

**Anzahl der Befunde je Priorität**

| Priorität | Anzahl |
|---|---|
| P0 | 0 |
| P1 | 2 |
| P2 | 9 |
| P3 | 6 |

**Größte Risiken**

1. **Halb-persistierte bearbeitete Mahlzeit nach fehlgeschlagenem Save** (`MealDraft.save`, Edit-Pfad) – das sichtbare Verhalten widerspricht dem eigenen Fehlertext „Es wurde nichts geändert" (NUT-01, P1).
2. **Online-Import blockiert bei unvollständigen OFF-Nährwerten** – der Nutzer kann einen Treffer in der Vorschau weder übernehmen noch als „unbekannt" kennzeichnen, obwohl genau dieses Verhalten (unbekannt statt 0) erklärtes Ziel ist (OFF-01, P1).
3. **RIR-Hilfetext-Toggle wirkt nur auf einen von zwei Screens** – im laufenden Training wird der Hilfetext gar nicht mehr gelesen; die Beschriftung „Zeigt kurze Erklärungen …" ist dort unwahr (SET-01, P2). Das ist der im Auftrag explizit genannte Konkretsfall, und er ist **nicht** korrekt implementiert.
4. **Kein Privacy-Manifest** – SDK-/Required-Reason-API-Anforderung nicht erfüllt (PRIV-01, P2).
5. **README widerspricht der Implementierung an mehreren zentralen Stellen** (keine Mahlzeitenerfassung, 5 Tabs inkl. Werkzeuge, 12 Widgets) – für Tester und Reviewer irreführend (DOC-01, P2).

**Release-Einschätzung:** Kein P0. Für eine externe Beta sind NUT-01 und OFF-01 vor dem nächsten Build zu beheben (beide klein und risikoarm), PRIV-01 vor einer App-Store-Einreichung. SET-01 und DOC-01 sind Glaubwürdigkeits-/Konsistenzthemen mit kleinem Fix.

**Wichtig zur Einordnung:** „Grün" sind hier nur die Befunde, die ich am Code belegen kann. Ausgeführte Tests gibt es in dieser Umgebung **keine** (Abschnitt E.2) – keine Aussage dieses Berichts bedeutet „getestet und bestanden".

---

## B. Befundübersicht

| ID | Prio | Bereich | Status | Kurzbeschreibung | Beleg |
|---|---|---|---|---|---|
| NUT-01 | P1 | Mahlzeit speichern | bestätigt | Edit-Save-Fehler lässt neue `MealItem`s neben restaurierten alten im Context stehen; UI suggeriert „nichts geändert" | `MealDraft.swift` `save(into:persist:)` catch-Zweig |
| OFF-01 | P1 | Online-Suche | bestätigt | Vorschau-Zeile „Hinzufügen" ist bei fehlendem Nährwert dauerhaft deaktiviert, ohne Erklärung oder Alternativweg | `OnlineFoodCandidatePreviewSheet.swift` `pendingValues`/`OnlineFoodImportValues.init?` |
| SET-01 | P2 | Einstellungen/RIR | bestätigt | `showRirTooltips` wirkt nur in `ExerciseEditorView`; `SetRow.rirSliderRow` zeigt den Hilfetext immer | `SettingsAppExperienceView.swift:266`, `ExerciseEditorView.swift:557`, `SetRow.swift:828` |
| AI-01 | P2 | KI-Ernährung | bestätigt | Bei `.languageNotSupported` ist der KI-Entwurf komplett weg und der Hinweis sagt „auf diesem Gerät nicht verfügbar" – kein manueller/transparenter Weg für genau diesen Fall | `AddMealView.aiSection` `default:`-Zweig; `NutritionAIAvailability` |
| AI-02 | P2 | KI-Ernährung | bestätigt | Die im Text erkannte Mahlzeit (`MealTextCandidate.mealType`) wird von der UI nie verwendet | `AddMealView.applyAICandidate` |
| AI-03 | P3 | KI-Ernährung | bestätigt | Die Zahlen-Verifikation (`onlyContainsVerifiedNumbers`) akzeptiert jede einstellige Ziffer im Text, inkl. „2 Mahlzeiten" / „3 Portionen" | `NutritionInsightGenerator.allowedNumbers/numbers` |
| NAV-01 | P2 | Navigation | bestätigt | Werkzeuge liegen als 3. Zeile in der Einstellungs-Gruppenliste zwischen „Bibliothek" und „Daten", nicht als eigener Bereich „Werkzeuge" | `SettingsView.groupNavigationSection` |
| I18N-01 | P2 | Lokalisierung | bestätigt | TR-Übersetzungen von Übungsnamen sind teils reines Englisch (z. B. „Lying Leg Raise Flat Bench", „Box Squat") | `Localizable.xcstrings`, 268 Keys mit `en == tr` |
| DATA-01 | P2 | Persistenz/Import | bestätigt | Import akzeptiert Mahlzeiten ohne Positionen → dauerhaft leere Mahlzeit-Einträge | `DataImportService.importMeals` |
| DOC-01 | P2 | Doku | bestätigt | README behauptet „keine Mahlzeitenerfassung", listet 5 falsche Tabs und 12 statt 13 Widgets | `README.md:41–46,58–60` |
| PRIV-01 | P2 | Datenschutz | bestätigt | Kein `PrivacyInfo.xcprivacy` im Repo (App + Widget) | `find`-Ergebnis leer |
| NUT-02 | P3 | Mahlzeit-Details | bestätigt | Zeile einer Mahlzeit listet nur Namen, ohne Mengen/Einheiten – mehrere Portionen sind nicht unterscheidbar | `NutritionDayView.mealEntryRow` |
| NUT-03 | P3 | Ernährung | bestätigt | `@"kcal"`/`@"g"`-Einheiten sind hartcodiert (Lokalisierung inkonsistent zum Rest) | `NutritionDayView:227–230/514–523`, `AddMealView.previewRow` |
| NUT-04 | P3 | Ernährung | bestätigt | Leere Mahlzeit ist nur UI-seitig gesperrt (Manifestation über Import statt lokal reproduzierbar) | siehe DATA-01 |
| PLAN-01 | P3 | Plan-Editor | bestätigt | „Aktiver Plan"-Toggle ruft `setActive` sofort und global auf; Verwerfen reaktiviert den alten Plan, aber bis dahin kann zwischenzeitlich kein Plan aktiv gewesen sein | `PlanEditorView` (`setActive`-Pfad, `revertToSnapshot`) |
| I18N-02 | P3 | Lokalisierung | bestätigt | 140 Keys mit identischem DE-/TR-Text; Mehrzahl davon bewusst (Fachbegriffe/Kachelnamen), aber ohne Kennzeichnung als „bewusst" | `Localizable.xcstrings` |
| DOC-02 | P3 | Doku | bestätigt | „1806 Texte" im README vs. 2518 Keys im Katalog | `README.md:46` vs. Katalog |

**Befunde, die geprüft und als in Ordnung befunden wurden** (Wichtig, weil sie die häufigsten Verdachtsfälle sind):
fehlende OFF-Nährwerte → `nil`, nicht `0`; kJ-only-Kalorien → `/4.184`-Fallback; Suchfeld sendet nur den Suchbegriff + Sprachcode; Suchfeld ist ohne Opt-in nicht erreichbar; `MealItem` hält Nährwerte als Snapshot (`catalogID` ohne Relationship), Katalogupdates ändern keine Historie; KI schreibt nie in `draft` und nie in `modelContext`; Save-Button hat Doppeltap-Schutz doppelt (`didSaveSuccessfully` + `.disabled`); `deleteMeal` hat Bestätigungsdialog; `AddMealView` hat Dirty-Snapshot inkl. Datum/Mahlzeitentyp; `PlanEditorView.saveAndDismiss()` persistiert vor `dismiss`; alle `.dismiss()`-Pfade mit Dirty-State sind abgesichert; `dead_catalog_v3.py` meldet UNUSED 0.

---

## C. Detaillierte Befunde

### NUT-01 – Bearbeitete Mahlzeit bleibt nach fehlgeschlagenem Speichern halb-persistiert
- **Priorität:** P1 · **Status:** bestätigt (Code-Evidenz) · **Bereich:** Ernährung, Persistenz
- **Beobachtetes Verhalten:** Im Edit-Pfad von `MealDraft.save` werden vor dem `persist`-Aufruf alle neuen `MealItem`s eingefügt und alle alten gelöscht. Schlägt `persist(context)` fehl, werden die neuen Objekte wieder gelöscht und **Kopien** der alten als neue `MealItem`s eingefügt – **ohne** einen erneuten Save der Rückbau-Schritte. Der Fehlertext in der UI lautet „Beim Speichern ist ein Fehler aufgetreten. **Es wurde nichts geändert** — bitte versuche es erneut."
- **Erwartetes Verhalten:** Nach einem fehlgeschlagenen Speichern zeigt jede nachfolgende Ansicht exakt den alten Stand der Mahlzeit.
- **Reproduktion (vorgesehen, nicht ausgeführt – kein Simulator):** Mahlzeit mit 2 Positionen anlegen → bearbeiten (eine Position ändern) → `modelContext.save()` zum Fehlschlagen bringen (Test-Seam `persist:`) → Fehlerpfad abwarten → App beenden und neu starten → Tagesübersicht prüfen. Erwartbar: der Store enthält den Stand vor dem Edit (die Rückbau-Schritte sind ungespeichert), d. h. gespeichert werden sie nie – **oder**, falls ein späterer, fremder Save den Context mitnimmt, landen die Positionen in doppelter/abweichender Form. Beides ist falsch; welcher der beiden Fälle eintritt, hängt davon ab, welcher Save als nächstes läuft (offen, siehe D.2).
- **Technischer Beleg:** `Sources/FitnessAppUI/Nutrition/MealDraft.swift`, `save(into:persist:)`, Edit-Zweig – `catch`-Block; Kommentar dort rechtfertigt das Fehlen von `context.rollback()` (richtig), zieht aber nicht die Konsequenz, dass auch der manuelle Rückbau nicht persistiert wird. Vergleich: der Neuanlage-Zweig ist hier sauber (löscht die eingefügten Objekte ersatzlos).
- **Nutzer-/Datenwirkung:** Widersprüchliche Rückmeldung („nichts geändert"), potenzielle Dateninkonsistenz bei der nächsten Speicherung, Verwirrung beim erneuten Versuch (der Entwurf bleibt erhalten – das ist korrekt).
- **Belegte Ursache:** Kein `persist`-Aufruf (bzw. kein explizites `context.rollback()` nur für diese Objektmenge) im Rollback-Zweig; zusätzlich Fehlertext, der eine Garantie behauptet, die der Code nicht gibt.
- **Empfohlene Lösung (kleinster sinnvoller Schritt):** Nach dem manuellen Rückbau ein `try? persist(context)` ausführen (bzw. `context.rollback()` nur dann, wenn der Context keine fremden ungespeicherten Änderungen enthalten kann – aktuell nicht garantiert) **oder** – risikoärmer – den Rollback so umbauen, dass gar keine Deletes/Inserts vor dem persist stattfinden (z. B. Änderungen an `meal.items` erst nach erfolgreichem Validierungsschritt anwenden bzw. die alten Objekte erst nach erfolgreichem `persist` löschen, was mit SwiftData nicht direkt geht → daher Variante 1). Unabhängig davon: Fehlertext auf „Der letzte Speicherversuch ist fehlgeschlagen; prüfe die Mahlzeit nach dem Neustart" entschärfen, wenn die Garantie nicht herstellbar ist.
- **Risiken:** Ein zweiter `persist`-Aufruf kann andere, fremde ungespeicherte Änderungen mit-schreiben (genau der Grund für den Verzicht auf `rollback()`). Deshalb nur nach vorheriger Prüfung des tatsächlichen Aufrufpfads umsetzen.
- **Regressionstests:** `MealDraft.save` mit fehlschlagendem `persist` + anschließendem „Neu laden" (Zustand muss dem Stand vor dem Edit entsprechen); Fehlertext-Assertion.

### OFF-01 – Online-Import ist bei unvollständigen Nährwerten eine Sackgasse
- **Priorität:** P1 · **Status:** bestätigt (Code-Evidenz) · **Bereich:** Online-Suche / Open Food Facts
- **Beobachtetes Verhalten:** `OnlineFoodImportValues.init?` verlangt **alle vier** Makros nicht-`nil` und `>= 0`. Fehlt in den OFF-Daten ein Wert (laut Code-Doku der häufigste Fall: „a hit with `nutriments` had no `fat_100g`"), ist der „Hinzufügen"-Button der Vorschau dauerhaft deaktiviert – bei leerem Pflichtfeld ohne sichtbaren Grund. Es gibt in der Vorschau keinen Weg, den fehlenden Wert als „unbekannt" zu behandeln und den Rest zu übernehmen.
- **Erwartetes Verhalten:** Entweder fehlende Werte als unbekannt kennzeichenbar speichern, oder klar erklären „Nährwerte unvollständig – bitte ergänzen" und den manuellen Weg anbieten; alternativ direkt auf „Eigenes Lebensmittel anlegen" verweisen (das existiert bereits).
- **Reproduktion:** Opt-in „Online-Suche" einschalten → Mahlzeit hinzufügen → Suche mit 0 Treffern → Online suchen → Treffer wählen, der bei OFF ohne `fat_100g` geführt ist (z. B. Test-Fixture aus `OnlineFoodSearchClientTests.test_search_withMissingProtein_mapsToNilNotZero`) → Vorschau zeigt leeres Fettfeld → „Hinzufügen" bleibt ausgegraut.
- **Technischer Beleg:** `Sources/FitnessAppUI/Nutrition/OnlineFoodCandidatePreviewSheet.swift` (`OnlineFoodImportValues.init?`, `pendingValues`, `.disabled(pendingValues == nil)`), `Sources/FitnessAppFoodLookup/OnlineFoodCandidate.swift` (Optionals), `OnlineFoodSearchClient.swift` (Optionals je Feld). Auch `CustomFoodDraft.isValid` verlangt alle 4 Makros – dort ist es konsistent mit dem dortigen manuellen Flow (nur UI-Gate, kein Netz).
- **Nutzer-/Datenwirkung:** Ein realer Treffer kann nicht übernommen werden; die Funktion wirkt kaputt; der Nutzer muss alle Werte manuell bei OFF nachsehen und selbst eintragen.
- **Belegte Ursache:** Alles-oder-nichts-Validierung gegen ein Datenmodell, das Unbekannt-Werte ausdrücklich als zulässig führt.
- **Empfohlene Lösung:** Fehlende Makros als `nil`/unbekannt übernehmen dürfen (Snapshot-Modell trägt bereits `Double`, dafür wäre ein „unbekannt"-Zustand nötig – **Produktentscheidung P1**, siehe G.1) **oder** minimal: fehlende Felder mit sichtbarem Hinweis + Fokus auf das erste leere Feld + Button „Eigenes Lebensmittel anlegen" in der Vorschau.
- **Risiken:** Unbekannt-Werte in Summen würden je nach Entscheidung als 0 gewertet (wähle: fehlende Position zeigt „–", Summe weist „unvollständig" aus).
- **Regressionstests:** Vorschau mit genau einem fehlenden Makro: Button-Zustand, Hinweistext, Übernahme-Ergebnis.

### SET-01 – RIR-Hilfetext-Toggle steuert nur einen von zwei Screens
- **Priorität:** P2 · **Status:** bestätigt · **Bereich:** Einstellungen → App & Trainingserlebnis → Trainingsverhalten
- **Beobachtetes Verhalten:** `showRirTooltips` (AppStorage, Default `true`, in `SettingsPortability` exportiert) wird in `ExerciseEditorView.targetRIRSliderRow` ausgewertet (steuert `rirTooltip.setVisible`). In `SetRow.rirSliderRow` (aktives Training) wird der Hilfetext `RIRTooltipBloop.tooltipKey(for: rir)` **immer** gerendert; der dortige Kommentar dokumentiert ausdrücklich, dass Toggle/Controller hier „nicht mehr gebraucht" werden. Die Einstellungsbeschreibung sagt aber „Zeigt kurze Erklärungen beim Einstellen der Intensität (Reps in Reserve)." – im Training stimmt das nicht.
- **Erwartetes Verhalten:** Ausschalten blendet den Hilfetext überall aus (oder die Beschriftung wird ehrlich eingeschränkt – Produktentscheidung).
- **Reproduktion:** Einstellungen → App & Trainingserlebnis → Trainingsverhalten → RIR-Hilfetext aus → Training starten → Satz-RIR-Regler: Hilfetext weiterhin sichtbar. Persistenz des Schalters selbst ist in Ordnung (`@AppStorage`).
- **Technischer Beleg:** `SettingsAppExperienceView.swift:266`, `ExerciseEditorView.swift:50/557`, `SetRow.swift:777–828`.
- **Wirkung:** Einstellung ohne die zugesagte Wirkung; Vertrauensverlust in „jede Einstellung hat echte Wirkung".
- **Ursache:** Umbau des SetRow-Layouts (README 2.24) hat die Toggle-Auswertung dort bewusst entfernt, Beschriftung/Toggle blieben unverändert.
- **Empfohlene Lösung (kleinster Schritt):** In `SetRow` den Hilfetext an `@AppStorage("showRirTooltips")` binden (eine Zeile + Property). Alternativ Beschriftung ändern – aber die Matrix in Abschnitt 10.1 zeigt, dass ein korrektes Verhalten hier billiger ist.
- **Risiken:** SetRow ist ein heißer Pfad (Performance/Accessibility bereits mehrfach angepasst) – Änderung nur additiv, keine Layout-Änderung.
- **Regressionstests:** Quelltext-/Verhaltens-Test analog `SetDisplayModeSettingTests`: alle lesenden Komponenten verwenden denselben Key.

### AI-01 – „Sprache nicht unterstützt" wird als „Gerät nicht unterstützt" verpackt
- **Priorität:** P2 · **Status:** bestätigt · **Bereich:** KI-Ernährung
- **Beobachtetes Verhalten:** `MealTextExtractor.availability()` → `AddMealView.aiSection` `default:`-Zweig zeigt immer `nutrition.addMeal.aiDraft.unavailable` („KI-Entwurf ist auf diesem Gerät nicht verfügbar. Nutze stattdessen die Suche unten …"). Das ist für `.deviceNotSupported`/`.appleIntelligenceNotEnabled` korrekt, für `.languageNotSupported` (Gerät kann es, Modell unterstützt die App-Sprache nicht – TR erst ab iOS 26.1) und `.temporarilyUnavailable` (Modell lädt noch) aber falsch.
- **Erwartetes Verhalten:** Grund benennen; bei `.languageNotSupported` transparent sagen „in dieser Sprache nicht verfügbar, manuell erfassen" und die manuelle Suche in den Vordergrund stellen; bei `.temporarilyUnavailable` „wird vorbereitet, später erneut versuchen".
- **Reproduktion:** iOS-26-Gerät mit Apple Intelligence, Systemsprache Türkisch, iOS 26.0 (vor 26.1) → Mahlzeit hinzufügen.
- **Technik:** `Sources/FitnessAppAI/NutritionAIAvailability.swift` (5 Fälle), `Sources/FitnessAppUI/Nutrition/AddMealView.swift` (`aiSection`), keine `switch`-Verzweigung pro Fall.
- **Wirkung:** Falsche Auskunft, unnötiger Supportaufwand; der Nutzer denkt, sein Gerät sei zu alt.
- **Ursache:** UI behandelt 5 Zustände als 2.
- **Lösung:** `switch` auf alle Fälle mit je einem Key (3 neue Keys × 3 Sprachen); der Hinweis auf die Suche bleibt in allen Fällen gleich. Kein neuer Code-Pfad, keine Logikänderung.
- **Risiken:** minimal (nur Texte/Verzweigung).
- **Regressionstests:** Snapshot/Unit-Test über die Mapping-Funktion Zustand → Key.

### AI-02 – Erkannte Mahlzeit wird nie übernommen
- **Priorität:** P2 · **Status:** bestätigt · **Bereich:** KI-Ernährung/Erfassung
- **Beobachtet:** `MealTextCandidate.mealType`/`MealDraftCandidate.mealType` werden extrahiert („200 g Hähnchen … zum Mittagessen"), aber in `applyAICandidate`/`addSelectedEntry` nicht verwendet; `draft.mealType` bleibt unverändert.
- **Erwartet:** Entweder übernehmen und als Änderung im `isDirty`-Sinn behandeln, oder das Feld nicht extrahieren (Kosten/Tokens sparen) – die Nichtnutzung ist mindestens irreführend, weil das Prompt-Feld „mealType" im Schema gepflegt wird.
- **Beleg:** `MealTextExtractor.swift` (`MealTextCandidateMealType`, `@Guide mealType`), `AddMealView.applyAICandidate` (nutzt nur `quantity`/`unit`).
- **Wirkung:** Nutzer wählt „Mittagessen" umständlich selbst, obwohl das Modell es korrekt erkannt hat.
- **Lösung:** Beim Übernehmen des letzten Kandidaten `draft.mealType` setzen, wenn die erkannte Mahlzeit gesetzt ist und noch keine Position vorhanden ist (sonst stiller Wechsel mehrerer Mahlzeiten in einem Draft). Oder Feld aus dem Schema entfernen.
- **Risiken:** Ein Draft mit Positionen aus „Frühstück" und „Mittagessen" – deshalb die Bedingung „nur beim ersten Kandidaten".
- **Regressionstests:** Kandidat mit `mealType` → `draft.mealType` gesetzt; zweiter Kandidat ändert ihn nicht.

### AI-03 – Zahlen-Verifikation lässt jede Ziffer im Satz durch
- **Priorität:** P3 · **Status:** bestätigt · **Bereich:** KI-Ernährung
- **Beobachtet:** `numbers(in:)` zieht alle Ziffernfolgen aus dem Text; `allowedNumbers` ist die Menge der erlaubten ganzen Zahlen. Enthält der Text also zusätzlich eine erfundene Ziffer, die zufällig einer erlaubten Zahl entspricht (oder der Einzelziffer „2"/„3"), wird sie akzeptiert. Beispiel: „Du hast heute 2 Mahlzeiten gegessen" – die 2 ist erlaubt, wenn irgendwo ein 2-Wert (z. B. 1200 kcal) erlaubt ist. Ebenso sind Ziffern aus Datum/Uhrzeit unproblematisch, aber Portionszahlen nicht.
- **Erwartet:** Die „nicht erfundene Zahl"-Garantie soll Nährwerte abdecken; sie ist derzeit als schwache Heuristik zu verstehen, nicht als Garantie – der Code-Kommentar nennt sie „the only hard guarantee". Das ist überzeichnet.
- **Beleg:** `Sources/FitnessAppAI/NutritionInsightGenerator.swift`, `onlyContainsVerifiedNumbers`, `allowedNumbers`, `numbers`.
- **Wirkung:** Kein Datenrisiko (der Text ist reine Anzeige), aber eine zu starke Zusicherung im Code; ein erfundenes „1.500 kcal" (Punkt → „1", „500") würde zu „1" und „500" zerfallen und ebenfalls geprüft.
- **Lösung:** Entweder Zusicherung im Kommentar/Tests realistisch formulieren (P3, empfohlen) oder Verifikation auf „Zahl + unmittelbare Einheit aus {kcal, g}" beschränken.
- **Risiken:** strengere Verifikation kann korrekte Antworten verwerfen (dann zeigt die Sektion bewusst nichts – akzeptiertes Fallback-Verhalten).
- **Regressionstests:** Text mit „2 Mahlzeiten"/„3 Portionen" und nicht erlaubten Zahlen.

### NAV-01 – Werkzeuge sind kein eigener Bereich unter „Mehr"
- **Priorität:** P2 · **Status:** bestätigt (Abweichung zur Soll-IA des Auftrags) · **Bereich:** Navigation/Einstellungen
- **Beobachtet:** Die Werkzeuge-Zeile steht als dritter von fünf Einträgen in `SettingsView.groupNavigationSection` zwischen „Bibliothek & Ausrüstung" und „Daten & Verbindungen"; bei aktuellem Stand ist „Hilfe & Informationen" die letzte Zeile (also nicht „am Ende versteckt" – das ist bereits behoben). Ein eigener Bereich „Werkzeuge" existiert nicht.
- **Erwartet (Auftrag §4):** Werkzeuge klar unter **Mehr → Werkzeuge** erreichbar. Ist er es? Ja, ein Tap führt direkt zu `CalculatorsView` – aber nur, weil es die einzige gruppierte Zeile ist, die keine eigene Unterseite hat (inkonsistente Gruppierung: vier Einträge sind Navigationsgruppen, einer ist ein Werkzeug-Bereich).
- **Beleg:** `SettingsView.swift` (`groupNavigationSection`), Doku dazu im Kopfkommentar.
- **Wirkung:** Nutzer erwartet bei „Werkzeuge" eine Gruppe wie die anderen drei; dort landen direkt die Rechner. Akzeptabel, aber nicht das Soll.
- **Lösung:** Werkzeuge als eigene Gruppen-Seite (Header + 4 Rechner-Zeilen) mit `navigationDestination`-Routing für `.waterTracker` erhalten (Deep-Link bleibt unverändert, weil weiterhin wertbasiert gepusht wird). Oder – kleiner – Zeile an das Gruppenende über „Hilfe" (dann nicht mehr letzte Zeile).
- **Risiken:** Der Deep-Link hängt an `CalculatorsRoute`; die Registrierung auf der Settings-Stack muss erhalten bleiben (bestehende Tests `WaterTrackerDeepLinkTests` decken das ab).
- **Regressionstests:** Deep-Link → Wassertracker; Navigation zurück bleibt; Gruppierungsreihenfolge.

### I18N-01 – Türkische Übungsnamen teils unübersetzt (Englisch)
- **Priorität:** P2 · **Status:** bestätigt (Datenanalyse Katalog) · **Bereich:** Lokalisierung
- **Beobachtet:** 268 Keys haben identischen EN-/TR-Text; ein erheblicher Teil der `exercise.name.*`-Keys bleibt in TR englisch, wo eine türkische Bezeichnung existiert/üblich ist, z. B. `exercise.name.lyingLegRaiseFlatBench` („Lying Leg Raise Flat Bench", DE dagegen „Beinheben auf Flachbank"), `exercise.name.boxSquat`, `exercise.name.floorPress`, `exercise.name.pistolSquat`. Ein kleiner Teil ist bewusst („Plank", „Tofu", „Skyr", „Parmesan", Kachelnamen).
- **Erwartet:** Bei TR-UI die türkische Bezeichnung; kein stiller Sprachwechsel innerhalb eines Screens.
- **Reproduktion (Datenprüfung genügt):** Katalog auf TR gesetzt → Übungsbibliothek öffnen → deutsche/englische Mischung mit türkischen Systembegriffen.
- **Beleg:** `Sources/FitnessAppUI/Resources/Localizable.xcstrings`; Vergleichsskript in E.1.
- **Wirkung:** Inkonsistente Oberflächensprache, für eine App, die TR als vollständig unterstützt bewirbt.
- **Ursache:** Migrationswellen (DEL-113/114/116) haben DE/EN kuratiert; TR wurde für Fachbegriffe mit dem EN-Fallback gefüllt.
- **Lösung:** Liste der `exercise.name.*`-Keys mit `en == tr` exportieren, fachlich prüfen (Eigenname vs. Übersetzbarkeit), bewusst getroffene Fälle dokumentieren.
- **Risiken:** Übungsnamen sind in Snapshots (`ExerciseLog.exerciseNameSnapshot`) eingefroren → Korrektur ändert nur die Anzeige/neue Einträge, nicht die Historie (korrekt, im Test bestätigen).
- **Regressionstests:** `FoodCatalogLocalizationTests`-Muster auf `exercise.name.*` erweitern (DE≠EN, TR≠EN für eine kuratierte Liste).

### DATA-01 – Import legt leere Mahlzeiten an
- **Priorität:** P2 · **Status:** bestätigt · **Bereich:** Persistenz/Import
- **Beobachtet:** `importMeals` fügt jede `meals.csv`-Zeile ein (Duplikatprüfung nur über Datum+Mahlzeitentyp). `importMealItems` kann fehlschlagen oder Zeilen überspringen (Duplikate/Ungültiges). Damit können `MealEntry`s ohne Items entstehen – ein Zustand, den die UI bewusst nie erzeugt (`MealDraft.save` verweigert 0 Items).
- **Erwartet:** Tagesübersicht und Summen verhalten sich konsistent; leere Mahlzeiten erscheinen nicht als sichtbare Einträge mit 0 kcal.
- **Reproduktion:** ZIP mit `meals.csv`-Zeile ohne passende `meal_items.csv`-Zeile importieren → Tagesübersicht zeigt die Mahlzeit mit 0 kcal.
- **Beleg:** `Sources/FitnessAppData/Export/DataImportService.swift` (`importMeals`, `importMealItems`), `MealDraftError.noItems` als Gegenstück in der UI.
- **Wirkung:** Kosmetisch/historisch inkonsistent; keine Summenverfälschung (0), aber Datenrauschen, das man nicht mehr zuordnen kann.
- **Lösung:** Am Ende des Item-Passes Mahlzeiten ohne Items entfernen (oder beim Import-Recovery nur Mahlzeiten einfügen, für die Items existieren).
- **Risiken:** Löschlogik im Import – muss die Cascade-Regel beachten (nur die Eltern löschen, keine Item-Waisen).
- **Regressionstests:** ZIP mit meals-only → Import-Ergebnis enthält keine leere Mahlzeit.

### DOC-01 – README beschreibt einen anderen App-Stand
- **Priorität:** P2 · **Status:** bestätigt · **Bereich:** Doku/Release-Risiko
- **Beobachtet:** `README.md:41` nennt 5 Tabs „Dashboard, Plan, Messung, Werkzeuge, Mehr" (real: Heute/Training/Ernährung/Fortschritt/Mehr), `:45` 12 Dashboard-Widgets (real 13, `DashboardWidgetType` inkl. `.nutrition`), `:46` „1806 Texte" (Katalog: 2518 Keys), `:58–60` „Keine Mahlzeiten- oder Kalorienerfassung – es gibt nur den Kalorien-Rechner" (real: vollständige Erfassung inkl. KI-Entwurf und Online-Suche).
- **Erwartet:** Dokumentation entspricht dem Branch.
- **Beleg:** Zeilenangaben wie oben; Werte gegengeprüft in `RootView.MainTabView`, `DashboardWidgetType`, `Localizable.xcstrings`.
- **Wirkung:** Interne wie externe Leser (Tester, Reviewer, App-Store-Texte) arbeiten mit falschen Aussagen; auch für den Audit selbst war der README als Kontext irreführend.
- **Lösung:** README-Abschnitte 2/3/5: Tabs, Widget-Anzahl, Text-Anzahl, „Was die App (noch) nicht kann" korrigieren.
- **Risiken:** keine.

### PRIV-01 – Kein Privacy-Manifest
- **Priorität:** P2 · **Status:** bestätigt (Existenzprüfung) · **Bereich:** Datenschutz/App Store
- **Beobachtet:** Im Repo existiert keine `PrivacyInfo.xcprivacy` – weder für das App-Target noch für die Widget-Extension. Es gibt keine Deklaration von Required-Reason-APIs (u. a. `UserDefaults`/`FileManager` werden intensiv genutzt) und von `NSPrivacyCollectedDataTypes`/Tracking.
- **Erwartet:** Ein Privacy-Manifest je Target, das die genutzten Required-Reason-APIs und die Datenerhebung (lokal, keine Weitergabe außer Suchbegriff an Open Food Facts bei Opt-in) deklariert.
- **Beleg:** `find . -iname "PrivacyInfo*"` → leer; `project.yml` listet für beide Targets nur `sources`.
- **Wirkung:** App-Store-Upload kann abgelehnt werden; fehlende Transparenz zur OFF-Datenübermittlung.
- **Lösung:** Zwei `PrivacyInfo.xcprivacy` (App, Widget), beide in `project.yml` als Resource geführt; Inhalte: `NSPrivacyAccessedAPITypes` (UserDefaults CA92.1, File timestamp C617.1/Disk space E174.1 je nach Nutzung), `NSPrivacyTracking=false`, `NSPrivacyCollectedDataTypes` leer (alles lokal).
- **Risiken:** Muss zu tatsächlichem Verhalten passen (kein Tracking, keine Analytics) – dann unkritisch.
- **Regressionstests:** CI-Schritt, der die Dateien prüft (analog `.scripts`-Prüfungen).

### NUT-02 – Mahlzeit-Zeile ohne Mengen
- **Priorität:** P3 · **Bereich:** Ernährungs-Tagesansicht
- **Beobachtet:** `NutritionDayView.mealEntryRow` listet je Item nur `nameSnapshot`, rechts `kcal` und Uhrzeit. Mengen/Einheiten fehlen, obwohl sie im Edit-Sheet sichtbar sind.
- **Erwartet:** Menge sichtbar (wie im AddMealView-Item-Section: „`150 g`").
- **Beleg:** `NutritionDayView.swift` (`mealEntryRow`).
- **Wirkung:** Zwei Portionen „Hähnchenbrust" sind in der Zusammenfassung nicht unterscheidbar; Kontrollmöglichkeit fehlt.
- **Lösung:** Menge+Einheit unter dem Namen ergänzen, gleiche Formatierung wie `itemsSection` in `AddMealView`.
- **Risiken:** Zeilenhöhe steigt; `minHeight: 44` bleibt.
- **Regressionstests:** Snapshot-Sichtprüfung im Preview.

### NUT-03 – Hartcodierte Einheiten „kcal"/"g"
- **Priorität:** P3 · **Beleg:** `NutritionDayView.swift:227–230,514–523`, `AddMealView.previewRow`, `DashboardView` kcal
- **Wirkung:** In allen drei Sprachen identische Einheiten – bewusst akzeptabel (SI-Konvention), aber inkonsistent zu einem Katalog, der sonst jeden String führt; auch `formattedTwoDecimals` erzwingt überall zwei Nachkommastellen (z. B. „2.200,00 kcal"), während der Rest der App `formattedNoDecimals` nutzt.
- **Lösung:** Einheiten in Katalog aufnehmen oder im `CONTRIBUTING.md` als bewusst hartcodiert dokumentieren; kcal-Anzeige auf `formattedNoDecimals` prüfen.
- **Risiken:** keine.

### NUT-04 – Leere Mahlzeit nur per Import möglich
- **Priorität:** P3 · **Beleg:** Kombination aus DATA-01 und `MealDraft.save`-Guard
- **Wirkung:** Invariante „keine leere Mahlzeit" wird durch die UI gehalten, aber nicht durch das Datenmodell/den Import – deshalb P3 (Manifestation über DATA-01 abgedeckt).

### PLAN-01 – „Aktiver Plan"-Toggle hat globale Wirkung vor dem Speichern
- **Priorität:** P3 · **Bereich:** Plan-Editor
- **Beobachtet:** `PlanEditorView` mutiert `plan.isActive` live; `setActive(true)` deaktiviert global alle anderen Pläne. Bei „Verwerfen" wird der zuvor aktive Plan reaktiviert (`otherActivePlanIDAtOpen`) und der Wochentag zurückgesetzt. `saveAndDismiss()` persistiert vor `dismiss()`. Restrisiko: Schlägt der Save fehl, bleiben die Mutationen im Objektgraphen (bewusst, Toast), und ein späterer fremder Save kann sie mitschreiben.
- **Erwartet/Bewertung:** Das ist ein bewusst dokumentiertes, risikoarmes Muster mit Fehlerfeedback – kein Defekt, aber ein Randfall, der bei NUT-01-Fix mitbetrachtet werden sollte.
- **Regressionstests:** vorhanden (`PlanEditorPersistenceTests`).

### I18N-02 / DOC-02 – Kennzahlen
- **Priorität:** P3 · `de == tr` bei 140 Keys, `en == tr` bei 268 Keys; README nennt 1806 Texte, Katalog hat 2518. Beides ohne Funktionsrisiko, aber Doku-/Pflegeaufwand; Vorschlag: Kennzahlen automatisch generieren (`TRANSLATIONS.md` wird bereits per Skript erzeugt).

---

## 4.–14. Bewertung der geprüften Prüfpunkte (verdichtet)

**4. Navigation und Einstellungen**
- Tabs in Soll-Reihenfolge vorhanden (`RootView.MainTabView`), `.tools` entfernt, Deep-Links (`fitnessapp://workout/active`, `fitnessapp://dashboard`, Wassertracker-Reminder) über `AppNavigation`/`CalculatorsRoute` wertbasiert.
- Einstellungsgruppen: `ProfileEditor` als direkter Link + 5 Gruppen in der Reihenfolge App-Erlebnis, Bibliothek, Werkzeuge, Daten, Hilfe (Befund NAV-01 zur Einordnung der Werkzeuge-Zeile; „Hilfe" ist die letzte Zeile, also nicht versteckt).
- Modale Ansichten mit Dirty-Schutz: `AddMealView`, `PlanEditorView`, `MeasurementView`, `BaselineCheckFlowView`, `DayEditorView`, `ExerciseEditorView`, `NewCustomExerciseSheet`, `ExerciseLibraryEditorSheet`, `ProfileEditorView`, `GearListView`, `BodyDataEditorView`, `CardioGoalEditorView`, `PeriodicCheckInView`, `DayPickerSheet`, `PlanBuilderView` – alle mit `isDirty` + Discard-Dialog, `interactiveDismissDisabled`/`deltiqSwipeBackEnabled(!isDirty)`.
- Laufende Workouts: Tab-Wechsel behält `ActiveWorkoutView`-Zustand (TabView hält die View; Fit-Session bleibt im Path `workoutPath`), verifizierbar über den Active-Session-Banner in `PlansListView` und den Live-Activity-Deep-Link. Rest-Timer lebt in der Safe-Area-Inset, Live Activity ist prozessunabhängig.
- Dashboard-Widget-Einstellungen (`activeDashboardWidgetsRaw`) werden von Änderungen an Tabs/Einstellungen nicht berührt; Setter schreibt nur bei Reorder/Toggle.
- Leere Zustände: Ernährung, Verlauf, Fortschritt, Werkzeuge haben eigene `DashboardEmptyState`-Varianten.

**5. Ernährung/Mahlzeiten (ohne KI/OFF)**
Das Grundgerüst ist solide: Draft-Puffer ohne SwiftData-Kontakt (`MealDraft`), Doppeltap-Schutz doppelt (Draft + UI), Löschen nur mit Bestätigung, Cascade-Regel korrekt auf der Elternseite, Positions-Löschen per Swipe (`onDelete`), Datum/Mahlzeitentyp im Dirty-Snapshot. Schwachstellen: NUT-01 (Save-Rollback), NUT-02/NUT-03 (Anzeige), Datenmodell erlaubt leere Mahlzeiten (DATA-01/NUT-04).

**6. Open Food Facts**
Kette vollständig geprüft: Request (`q`, `langs`, `page_size=20`, `User-Agent` im geforderten Format) → Rohtreffer → Decoding (alle Felder optional, kein force-unwrap) → Mapping (kJ→kcal bei fehlendem kcal) → Vorschau (Werte editierbar, fehlende Werte leer) → Übernahme (`FoodCatalogEntry(source: .onlineImported)` via `context.insert`) → Persistenz. Positiv: keine 0-Ersatzwerte, Fehlerzustände (`noNetwork`, `rateLimited` 503, `noResults`, `invalidResponse`) gemappt und lokalisiert, Doppeltap-Guard, Offline-Verhalten deterministisch. Negative Befunde: OFF-01 (Sackgasse), Attribution in der Trefferliste vorhanden, Lizenzseite unter Einstellungen → Hilfe (Soll erfüllt). **Rechtlich offen (D.4):** ODbL verlangt u. U. „Share-Alike" für abgeleitete Datenbanken; importierte Einzelwerte in einem lokalen Nutzerkatalog sind regelmäßig unproblematisch, das ist aber eine Rechtsfrage und wird hier **nicht** als konform bewertet. Die Quelle ist als `source: onlineImported` gekennzeichnet und exportierbar – ausreichend für Nachvollziehbarkeit, nicht für eine Rechtsaussage.

**7. KI-Ernährung**
On-device (`FoundationModels`, `#if canImport` + `if #available(iOS 26)`, sonst `.deviceNotSupported`), keine Cloud-Fallbacks, keine Netzwerk-APIs im AI-Modul (`FitnessAppAI` hat keine Dependencies). iOS 17 bleibt nutzbar, weil UI-Pfade auf `availability()` verzweigen. KI liefert nur Kandidaten/Beschriftungen, keine Nährwerte (belegt in `MealTextExtractor` + `AddMealView.applyAICandidate`). Zielberechnung deterministisch (`GoalProgress`, 40/150 → 27 %, 110 g; Test existiert in `NutritionCalculationsTests`). Prompt enthält Prozent und Restmenge, plus Tonregel. Sprache: `locale` wird explizit übergeben und als Satz „Respond only in X." in die Instructions geschrieben; kein stiller Sprachwechsel (Modellantwort wird durch `supportsLocale`-Gate verhindert, bevor sie zustande kommt). Befunde: AI-01, AI-02, AI-03.

**8. Lokalisierung und Lebensmittelnamen**
- Katalog: 2518 Keys, DE/EN/TR je vollständig vorhanden (keine fehlenden, keine leeren Werte), alle 130 `FoodCatalogItem`-IDs haben einen `nutrition.food.*.name`-Key, keine Orphan-Keys. Tr-Snapshot „Bier → Bira", „Hähnchenbrust → Tavuk Göğsü" vorhanden.
- Seed-Namen werden über `resolvedName(for:)` aus der aktiven Locale aufgelöst; importierte/eigene Einträge haben `displayName` mit Vorrang (`nameKey` = ""), daher **kein** unbeabsichtigtes Überschreiben.
- Historische Snapshots (`MealItem.nameSnapshot`, `ExerciseLog`-Snapshots) sind eingefroren → Sprachwechsel ändert die Historie nicht (per Code belegt; Gerätetest steht aus). Das entspricht der Anforderung „Snapshot bleibt intakt"; ein **bewusstes** Übersetzen der Historie gibt es nicht (Produktentscheidung, G.3).
- Befunde: I18N-01 (Übungen), I18N-02 (Kennzahlen).

**9. Training/Pläne**
`PlanEditorView.saveAndDismiss()` persistiert vor dem Dismiss (Commit `cf27ed4`) und zeigt bei Fehler einen Toast statt zu schließen; `isDirty` deckt Meta-Felder, Tages-Reihenfolge und den zwischenzeitlich geänderten aktiven Plan ab; `revertToSnapshot` stellt diese zurück. Restrisiko PLAN-01. Übrige Editor-Flows haben Save-Error-Handling und Doppeltap-Schutz (`c5c978a`).

**10. Einstellungen/Toggle-Matrix**

| Einstellung (Key) | Speicherort | Lesende Komponente(n) | Erwartete Wirkung | Beobachtet | Test |
|---|---|---|---|---|---|
| `showRirTooltips` | UserDefaults (@AppStorage) | ExerciseEditorView **ja**, SetRow **nein** | Hilfetext überall aus | Training: Text bleibt → **SET-01** | Quelltext-Test fehlt |
| `pref_show_warmups` | AppStorage | ActiveWorkoutView, ExerciseCard | Warmups ausgeblendet | konsistent | – |
| `pref_set_display_mode` | AppStorage | SetRow, ExerciseCard, Settings | Spalten/Klassisch | konsistent | `SetDisplayModeSettingTests` |
| `pref_deload_enabled` | AppStorage | Settings, DayEditor, Dashboard | keine Vorschläge | konsistent | – |
| `pref_timer_sound`/`_haptics` | AppStorage | ActiveWorkoutView, TimedWorkoutPlayerView | Ton/Vibration | konsistent | – |
| `pref_timer_background_audio` | AppStorage | TimedWorkoutBackground (`audioPreferenceEnabled`) | stilles Audio an/aus | konsistent | – |
| `pref_preroll_seconds` | AppStorage | TimedWorkoutPlayerView (`storedPrerollSeconds`) | Vorlauf | konsistent | – |
| `pref_pr_celebrations` | AppStorage | ActiveWorkoutView, Settings | PR-Feiern aus | konsistent | – |
| `pref_appearance` | AppStorage | RootView | Farbschema | konsistent | – |
| `weight_unit` | AppStorage | 8 Stellen (Settings, Profile, BodyData, Calculator, Dashboard) | kg/lbs überall | konsistent | – |
| `pref_water_reminder*`, `pref_measurement_reminder*` | AppStorage + `ReminderPreferences` | ReminderScheduler, Settings (`rescheduleReminders`) | Erinnerungen | konsistent | – |
| `onlineFoodLookupEnabled` | AppStorage (Default false) | SettingsDataConnectionsView, AddMealView (beide Einstiegspunkte) | Online-Suche nur bei Opt-in | konsistent, Footer reagiert | `OnlineFoodLookupFlowTests`, `OnlineFoodLookupSettingPersistenceTests` |
| `pref_healthkit_workout_import`, `HealthWritePreferences.*` | AppStorage | RootView, SettingsDataConnectionsView, HealthWorkoutWriteView | Import/Write | konsistent | – |

**11. Persistenz/Datenintegrität**
Snapshot-Design verhindert Katalogdrift in der Historie; `source` als Rohstring vermeidet den dokumentierten Migration-Crash (Build 173). Kein `VersionedSchema`/`SchemaMigrationPlan` (additive Lightweight-Migrationen + Backfills im `RootView.task`); das ist ein bewusstes, dokumentiertes Muster, aber jede nicht-additive Modelländerung ist ein Risiko (D.1). Stabile `catalogID` bleibt beim Import erhalten (nur so löst `meal_items.catalog_id` nach Restore). Befunde: NUT-01, DATA-01.

**12. Datenschutz/Sicherheit**
Einziger Netzwerkaufruf: `OpenFoodFactsSearchClient` (URLSession `.ephemeral`, nur Suchbegriff + Sprachcode + UA, kein Cache, keine Cookies). Keine Secrets im Code (der echte Kontakt im `User-Agent` stammt aus dem Repo-Kommentar des Bestandscodes und ist bereits öffentlich; hier nicht erneut wiedergegeben). Keine sensiblen Daten in Logs – nur zwei `#if DEBUG`-`print`s (Deep-Link-URL, fehlende GIF-Ressource). HealthKit-Beschreibungen in `Info.plist`/`InfoPlist.xcstrings` vorhanden und DE/EN/TR. Einwilligung für OFF = Opt-in-Toggle mit klarem Footer. Löschungs-/Exportpfad: Export (ZIP/CSV) + `UserDataWipe` (Reset, Replace-Import) vorhanden. Offen: PRIV-01.

**13. Architektur/Codequalität**
Klare Schichtung (Core/Data/AI/FoodLookup/UI/Health/Activities), UI importiert Data+AI+FoodLookup einseitig, FoodLookup und AI hängen nur von Core bzw. nichts ab – die Netzwerkgrenze ist aus dem Modulgraphen ablesbar. SwiftUI-Zustand: moderne Muster (`@Observable`, `@AppStorage`, `@Query`), async/await mit `@MainActor`, `Task`-Lebenszyklus über `.task(id:)` inkl. `Task.isCancelled`-Check in `NutritionDayView.loadInsight`. `try!` nur in `#Preview`-Blöcken (3 Stellen). Viele ausführliche Kommentare begründen Designentscheidungen – hilfreich, teilweise exzessiv (P3, Stil). Keine toten Katalog-Keys (`UNUSED: 0`).

**14. Designsystem/Barrierefreiheit**
`DeltiqHeader`/`DeltiqRow`/`DeltiqSection`/`DeltiqSegmentedPicker`/`deltiqCardStyle` einheitlich; Accessibility-Labels bei icon-only Buttons ergänzt (Dashboard, AddMeal, DashboardSettings); `.lineLimit(1)+.minimumScaleFactor` gegen Umbruch bei AX-Größen; `contentShape(Rectangle())` für volle Trefferflächen; Discard-Dialoge mit destruktiver Rolle. Restrisiken: Dynamic-Type-Verhalten in `quantityBottomBar` (TextField + Segment + Button in einer Karte über der Tastatur) und im sog. „kompakten Mengenbereich" am unteren Rand nur durch Gerätetest belegbar (D.2). Kontrast/Farben adaptiv (Light/Dark-Verzweigung in `Theme`/`configureTabBarAppearance`).

---

## D. Nicht verifizierte Risiken

**D.1 Datenmigration.** Ohne `VersionedSchema` ist jede künftige nicht-additive Schemaänderung potenziell ein Crash beim Start (`SharedStore` fällt dann in den „gespiegelten" Notzustand zurück bzw. `fatalError` im letzten Fallback). Heute additiv – **nicht reproduziert**, nur architektonisch abgeleitet.

**D.2 NUT-01-Endzustand.** Ob nach fehlgeschlagenem Edit-Save beim nächsten Start der alte Zustand (Rückbau nie persistiert) oder ein gemischter Zustand (fremder Save nimmt Rückbau mit) sichtbar wird, hängt vom realen Save-Verhalten von SwiftData ab und wurde **nicht** ausgeführt. Beide Varianten sind falsch; welche eintritt, muss auf Gerät/Simulator mit injiziertem Fehler geprüft werden.

**D.3 Geräte-/Simulatorpunkte.** Alle UI-, Dynamic-Type-, VoiceOver-, Tastatur-, Live-Activity-, Widget- und HealthKit-Punkte **nicht** verifiziert (kein macOS, kein Simulator, kein Gerät). Insbesondere: `quantityBottomBar` mit Tastatur auf iPhone SE, AX5-Schrift, iPad-Layout, VoiceOver-Reihenfolge in `AddMealView`.

**D.4 Open-Food-Facts-Lizenz.** ODbL-Konformität der Übernahme einzelner Nährwerte in einen lokalen Nutzerkatalog ist **rechtlich offen** (Share-Alike, Attribution auf Treffer und Credits-Seite vorhanden, Quellenlink vorhanden, Übersetzungen vorhanden). Keine Aussage über Konformität – juristische Prüfung nötig.

**D.5 Live-Verhalten der OFF-API.** Die Doku im Client belegt eine reale Antwort von 2026-10-22. In diesem Audit wurden **keine** Anfragen gesendet (kein Rate-Limit-Verbrauch, keine Reproduktion anderer Antwortformen, z. B. HTTP 429 statt 503, Captcha-/Blockseiten, `product_name_<lang>`-Präferenzen).

**D.6 Foundation Models.** Nicht prüfbar ohne iOS-26-Gerät: tatsächliche Antwortqualität, `supportsLocale`-Verhalten für TR, Guardrail-Ablehnungen, Latenz, verweigerte `respond`-Aufrufe.

**D.7 Tests.** Ob die vorhandenen Quelltext-Regressionstests den beabsichtigten Zustand prüfen, wurde gelesen (Assertions prüfen tatsächlich die genannten Quelltextstellen), aber **nicht ausgeführt**.

---

## E. Testprotokoll

**E.1 Ausgeführt (auf diesem Rechner, ohne macOS/Xcode)**

| Schritt | Kommando | Ergebnis |
|---|---|---|
| Repo-Zustand | `git status --short`, `git log --oneline -30`, `git rev-parse HEAD` | sauber; HEAD `5e6ba39` |
| Katalog-Dead-Code | `python .scripts/dead_catalog_v3.py` | `Total catalog keys: 2518 · Referenced: 2518 · UNUSED: 0` (grün) |
| Katalog-Vollständigkeit | Python-Skript über `Localizable.xcstrings` | DE/EN/TR je 0 fehlende, 0 leere Werte; `state` durchgehend `translated` |
| Food-Katalog-IDs ↔ Keys | Python-Abgleich `FoodCatalogData.all` (130 Items) vs. `nutrition.food.*.name` | 0 fehlende, 0 verwaiste Keys |
| TR-Abdeckung | Skript: `de == tr` / `en == tr` | 140 bzw. 268 Keys (Befund I18N-01/02) |
| Nährwert-Plausibilität | Skript: 4/4/9-Atwater gegen `kcalPer100g` | 1 Auffälligkeit: `beer` (43 kcal vs. 16 kcal aus Makros – konsistent mit Alkohol, kein Defekt) |
| Privacy-Manifest | `find . -iname "PrivacyInfo*"` | leer (Befund PRIV-01) |
| Netzwerk-/Log-Scan | `grep` nach `URLSession`, `http(s)://`, `print(`, `NSLog` | nur `FitnessAppFoodLookup` + 2 `#if DEBUG`-Prints (Befund: unkritisch) |
| Lokalisierungs-Scan | `grep -rn "\"kcal\"\|\"g\""` in Nutrition | 8 hartcodierte Einheiten (NUT-03) |

**E.2 Nicht ausgeführt – mit Grund**

| Prüfung | Grund |
|---|---|
| `swift build` / `swift test` | In dieser Sandbox nicht ausführbar: `swift build` scheitert an fehlenden Dateisystemrechten des Arbeitsverzeichnisses (`NSCocoaErrorDomain 257`), und in einem Temp-Klon lassen sich kompilierte Binaries nicht starten (`Permission denied`/exit 126). Swift 6.2.4 für Windows ist vorhanden, der Build wurde versucht und **scheiterte an der Umgebung**, nicht am Code. **Keine Aussage über Build-/Testergebnis.** |
| `xcodebuild`, `xcodegen`, Xcode-Schemes | kein macOS |
| Simulator/Gerätetests | kein Simulator/Gerät verfügbar |
| Open-Food-Facts-Live-Anfrage | bewusst unterlassen (Rate-Limit, Auftrag „keine externen Dienste nötig") |
| Foundation-Models-Lauf | keine iOS-26-Hardware |
| CI-Status | keine GitHub-/Codemagic-Anbindung in dieser Umgebung geprüft; Workflow-Definitionen nur gelesen |

**E.3 Manuelle Regressionstest-Matrix (Auftrag §15) – Status**

| Bereich | Szenario | Status |
|---|---|---|
| Navigation | Alle Hauptbereiche wechseln | Code-belegt, Gerät offen |
| Einstellungen | Werkzeuge finden | Code-belegt: vorhanden (NAV-01 zur Platzierung) |
| Mahlzeit | Lebensmittel, Menge, Speichern | Code-belegt, Gerät offen |
| Mahlzeit | Abbrechen nach Änderungen | Code-belegt (Discard-Dialog + Dirty-Snapshot inkl. Datum/Typ) |
| Mahlzeit | Ungültige Eingabe/Speicherfehler | Inline-Fehler vorhanden; **NUT-01** beim Edit-Save |
| Online-Suche | Produkt mit Nährwerten | Code-belegt (`OnlineFoodSearchClientTests`) |
| Online-Suche | Fehlende Nährwerte | korrekt `nil` gemappt; **Sackgasse OFF-01** |
| Online-Suche | Offline/Timeout/keine Treffer | Code-belegt (`noNetwork`/`noResults`/`invalidResponse`) |
| Protein | 150 g Ziel, 40 g Aufnahme | deterministisch 27 % / 110 g (Test vorhanden, nicht ausgeführt) |
| KI-Sprache | DE/EN/TR | Code-belegt (Locale → Directives); TR-Modell ab 26.1, sonst AI-01 |
| Katalog | DE → TR → EN | Code-belegt (Seed über Keys), **I18N-01** für Übungen |
| Historie | Mahlzeit nach Sprachwechsel | Snapshot eingefroren – Code-belegt |
| RIR | Schalter ein/aus | **SET-01** (nur Editor), Neustart-Persistenz in Ordnung |
| Persistenz | Eintrag bearbeiten/löschen | NUT-01-Randfall |
| Kompatibilität | KI nicht verfügbar | Kern-App nutzbar, manueller Weg vorhanden; Text falsch (AI-01) |

---

## F. Priorisierter Maßnahmenplan (noch nichts umgesetzt)

**F.1 Vor Release (P1)**

1. **NUT-01** – Rollback nach fehlgeschlagenem Edit-Save persistieren **oder** Fehlergarantie im Text zurücknehmen.
   - Dateien: `Sources/FitnessAppUI/Nutrition/MealDraft.swift` (+ ggf. `Localizable.xcstrings` für den Fehlertext).
   - Kleinste Änderung: `try? persist(context)` am Ende des `catch`-Zweigs, sofern der Aufrufpfad keine fremden ungespeicherten Änderungen enthält (vorher verifizieren); sonst Text entschärfen.
   - Abhängigkeiten: Klärung des Save-Verhaltens (D.2).
   - Tests: Fehler-Injektion über den `persist`-Seam, anschließender Reload.
   - Risiko: mittel (Context-weite Wirkung eines zweiten Saves).

2. **OFF-01** – Vorschau-Sackgasse auflösen.
   - Dateien: `OnlineFoodCandidatePreviewSheet.swift`, ggf. `FoodCatalogEntry`/`MealItem` (Unbekannt-Zustand), `Localizable.xcstrings`.
   - Kleinste Änderung ohne Modellumbau: Hinweistext „Nährwerte unvollständig" + Sprung zu „Eigenes Lebensmittel anlegen" (bereits vorhanden) direkt aus der Vorschau.
   - Abhängigkeiten: Produktentscheidung G.1 (unbekannt vs. Pflichtwerte).
   - Tests: Vorschau mit genau einem fehlenden Makro.
   - Risiko: niedrig (UI) / mittel (Modell, falls Unbekannt-Zustand gewählt wird).

**F.2 Zeitnah (P2)**

3. **SET-01** – `SetRow.rirSliderRow` an `@AppStorage("showRirTooltips")` binden; Test analog `SetDisplayModeSettingTests`.
4. **AI-01** – `switch` über alle 5 `NutritionAIAvailability`-Fälle, 3 neue Keys × 3 Sprachen; Suche-Hinweis überall.
5. **PRIV-01** – zwei `PrivacyInfo.xcprivacy`, in `project.yml` als Resource; CI-Prüfschritt.
6. **DOC-01** – README-Korrekturen (Tabs, Widgets, Text-Anzahl, „Was fehlt"-Liste).
7. **NAV-01** – Werkzeuge als eigene Gruppen-Seite (oder Reihenfolge anpassen); Deep-Link unverändert.
8. **I18N-01** – TR-Übungsnamen kuratieren; Liste aus dem Skript ableiten.
9. **DATA-01** – Import: Mahlzeiten ohne Items am Ende entfernen.
10. **AI-02** – erkannte `mealType` beim ersten Kandidaten übernehmen (oder Feld aus dem Schema entfernen).

**F.3 Verbesserungen (P3)**

11. NUT-02 (Mengen in der Mahlzeit-Zeile), NUT-03 (Einheiten/Dezimalformat), AI-03 (Verifikationsclaim präzisieren), I18N-02/DOC-02 (Kennzahlen automatisch erzeugen), PLAN-01-Notiz im Code, NUT-04 implizit über DATA-01.

**F.4 Zusätzliche Tests / technische Schulden**

12. Test-Lücke: kein Test prüft, dass `showRirTooltips` **alle** lesenden Stellen erreicht (Ursache von SET-01).
13. Test-Lücke: `MealDraft.save`-Fehlerpfad im Edit-Modus nur über Injektion testbar – Test fehlt.
14. Test-Lücke: Import-Roundtrip mit absichtlich unvollständigem ZIP (DATA-01) fehlt.
15. Quelltext-Grep-Tests (`MainTabStructureTests`, `SettingsGroupOrderAndAttributionTests`, `AddMealViewSaveErrorStyleTests` …) sind als Regressionsschutz akzeptabel, prüfen aber Formulierungen statt Verhalten; sie brechen bei reinen Umbenennungen. Empfehlung: beibehalten, aber bewusst als „Strukturverträge" dokumentieren.
16. `SharedStore.makeAppContainer()` endet im letzten Fallback in `fatalError` – dokumentiert und bewusst, aber beim nächsten Schema-Umbau (D.1) prüfen, ob ein sichtbarer Fehlerzustand statt Crash möglich ist.

---

## G. Produktentscheidungen (echte offene Fragen)

1. **Unbekannte Nährwerte in der Erfassung:** Dürfen Positionen ohne einzelne Makros gespeichert werden (Anzeige „–", Tagessumme markiert „unvollständig")? Antwort entscheidet, ob OFF-01 überhaupt eine Modelländerung braucht.
2. **Historie und Sprache:** Soll die Historie (`nameSnapshot`) bei Sprachwechsel unverändert bleiben (heute: ja) oder optional aufgelöst/übersetzt werden? Heute klar „eingefroren" – bitte bestätigen, weil der Auftrag das für Snapshots ausdrücklich verlangt.
3. **Werkzeuge:** Eigene Gruppen-Seite unter „Mehr → Werkzeuge" (Soll-IA) oder bewusst direkte Zeile wie heute?
4. **RIR-Hilfetext:** Soll der Schalter im Training wirken (empfohlen) oder soll die Beschriftung auf „Plan-Editor" eingeschränkt werden?
5. **Open Food Facts / ODbL:** Reicht die vorhandene Attribution (Trefferzeile + Credits-Seite + Quellenlink) nach interner/rechtlicher Bewertung, oder sind weitere Hinweise (z. B. im Export/CSV) nötig?

---

*Ende des Berichts. Es wurden keine Dateien im Quellbaum verändert; dieser Bericht ist die einzige neu angelegte Datei. Ich warte auf ausdrückliche Freigabe, bevor irgendetwas davon umgesetzt wird.*
