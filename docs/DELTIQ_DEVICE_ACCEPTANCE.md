# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-20 (vierter Durchgang: Onboarding/Hybrid/Coach-Block,
Zurücknavigation/Entwurfsschutz, Drag&Drop/Cardio-Vorschau, RIR-Werte und
kleine Bildschirmbreite/große Schrift/Light-Dark/Locale auf echtem
TestingBot-Gerät geprüft), Branch `claude/smart-onboarding-epic`, HEAD
`254d669` (Korrektur-Commit zu E05; davor `64ba455` Fix-Commit E04, davor
`3e67cb8` ursprünglicher — per Geräte-Nachtest widerlegter — E05-Versuch,
davor `c96bf5c`). TestingBot-Verbrauch dieser Runde: ca. 3.004 Sekunden
(4 Sessions, alle aktiv beendet) von einem Restbudget von 34.515 Sekunden
vor dieser Runde; siehe Nachtrag „Runde 3" unten für Details und
Restbudget danach. Kein Merge nach `main`, kein Release.

**Gesamtstatus: A–F bearbeitet; deutliche Mehrheit bestanden, einzelne
Fälle teilweise oder (A09/C04/E08/F04) noch offen als fachliche
Implementierungslücken. Gesamtabnahme weiterhin offen (kein vollständiger
Abschluss aller 45 Fälle).**

## Diese Runde: Top-5-Geräteprüfung (E01, C06, D06, A11, D02)

Alle fünf in der vorherigen Fassung dieses Dokuments priorisierten Fälle
wurden in dieser Runde auf dem TestingBot-iPhone-15/iOS-18.0-Simulator
durchgespielt (zwei Sessions, je nacheinander, aktiv beendet). Kurzfassung je
Fall unten in der Testmatrix (Zeilen E01/C06/D06/A11/D02); Volltext siehe
Abschnitt "Nächste Schritte" am Ende sowie den Session-Report dieser Runde.

**Echter Bug gefunden und gefixt (E01):** `MeasurementView.save(profile:)`,
`editingMeasurement`-Zweig, überschrieb das bestehende `BodyMeasurement`
im Speicher ohne anschließenden `context.save()` — derselbe Musterfehler wie
die zuvor behobenen zwölf Stellen in dieser App. Fix: expliziter
`try? modelContext.save()` nach der Mutation (Commit `89c788a`). Neuer
Regressionstest `MeasurementPersistenceTests.
testEditedMeasurementWithImmediateSaveSurvivesARealStoreRestartWithout-
Duplication`. CI (`apple-ci-comparison.yml`, Run `39387057589`): erfolgreich.
Geräte-Nachtest nach dem Fix: Bearbeiten per Haken + sofortiger Kaltstart
(Force-Quit + Neustart) → Wert bleibt geändert (78,00 statt 75,00 kg),
weiterhin genau 2 Verlaufseinträge, keine Dopplung. Bestanden.

## Risikoblöcke A–E (vorheriger Durchgang, unverändert gültig)

Siehe Commit-Historie `f2a31a5`, `81d21da`, `9d62b14` für die im vorherigen
Durchgang gefundenen und gerätebehobenen Bugs (Zeitformat-Fortschritt,
Onboarding-Finish, Day-Editor-Swipe-Delete-Crash). Block D/E (28-/42-Tage-
Review-Fälligkeit) war bereits dort NICHT gerätebestätigt, weil der
TestingBot-Simulator kein Datum/Zeit-Einstellungsfeld hat — siehe unten für
den seither verfolgten, clock-freien Alternativweg.

## Diese Runde: bekannte Lücken geschlossen

| # | Thema | Status |
|---|---|---|
| 1a | `PlansListView.deletePlans` – Save fehlte (Commit `fdad04c`) | geräteverifiziert (Plan+Session-Entkopplung nach Kaltstart korrekt) |
| 1b | **Neuer Fund:** Löschen des AKTIVEN Plans mit laufender Session crasht (SwiftData-interner Fatal Error `Context is missing for ... TrainingDay/pN`) | **Ursache ungelöst** – 4 gerätegetestete interne Fix-Versuche gescheitert (Commits `a6de159`…`84147f3`, alle ehrlich dokumentiert inkl. widerlegter Hypothesen). Nutzerentscheid: **UI-Guard statt interner Reparatur** – `PlansListView.plansBlockedByActiveSession(_:)` verhindert die Löschung jetzt und zeigt einen Hinweis (Commit `f6d4c81`). **Geräteverifiziert**: Crash tritt nicht mehr auf, normale Löschung unverändert funktionsfähig. Die zugrundeliegende SwiftData-Ursache bleibt unbekannt. |
| 2 | `PlanEditorView.deleteDays` / `MeasurementView.deleteCurrentMeasurement` / `ExerciseCard.unlogSet` – Saves fehlten (Commit `49a634d`) | geräteverifiziert |
| 3 | `DayEditorView` ForEach-Identität (`forEachIdentity`, Commit `49a634d`) | geräteverifiziert im tatsächlichen Risiko-Ablauf (neue ungespeicherte Übung + gleichzeitiges Löschen einer anderen Übung) |
| 4 | EMOM/ForTime/Circuit Restart-Zustände (Commit `f2a31a5`) | geräteverifiziert. Dabei 12. übersehene fehlende Save-Stelle gefunden: `CircuitWorkoutPlayerView.endRest()` ("Skip rest") – gefixt und gerätebestätigt (Commit `4036680`) |

## Block D/E (28-/42-Tage-Review-Fälligkeit): weiterhin offen

Geprüfter, grundsätzlich bestätigter clock-freier Weg: `DataImportService`
liest `activated_at_utc`/`block_review_history_json` direkt aus `plans.csv`
(CSV-Backup-Import, erreichbar über Settings → „Daten importieren"). Der
erste Schritt dieses Wegs – einen Export ziehen (Settings → „Export data
(CSV)") – **hängt auf dem TestingBot-Gerät reproduzierbar** beim Öffnen des
Export-Screens (`XCTPerformOnMainRunLoop work timed out`), bestätigt in
**6 unabhängigen Sessions**, auch mit einer frisch installierten App und
genau einem Plan (schließt „zu große Datenmenge" als Ursache aus). Ob echter
App-Bug (z. B. Deadlock in der Navigations-Transition) oder
TestingBot/WebDriverAgent-seitiges Problem, ist ohne symbolisierten
Stacktrace/Instruments-Zugriff nicht abschließend zu klären.

**Status: bekannte Nachweislücke, Auswirkung noch nicht abschließend
geprüft.** Auf Nutzerentscheid wird dieser Weg hier nicht weiterverfolgt;
die 6 ursprünglich vorgesehenen Prüfpunkte (nicht fällig / fällig /
korrekter Plan bei mehreren / Review-Abschluss / Folgeblock+Historie /
Kaltstart ohne Duplikate) bleiben ungeprüft.

## Vier-Stufen-Status-Hinweis

„Geräteverifiziert" bedeutet ausschließlich: auf echtem TestingBot-Gerät
durchgespielt und bestätigt. Es bedeutet NICHT, dass die zugrundeliegende
Ursache (z. B. beim Delete-Crash) verstanden oder behoben ist — dort wurde
bewusst ein Produktverhalten (Verhindern statt Reparieren) gewählt.

## Testmatrix 04_TESTS_UND_ABNAHME.md (A01–F08)

Quelle: `docs/specifications/04_TESTS_UND_ABNAHME.md` Abschnitt 2 (Original,
unverändert). Code-Audit-Stand: 2026-10-20, HEAD `02e8e46`, reine
Lese-/Testauswertung ohne neuen Geräte-Lauf in diesem Durchgang. Alle
Geräte-Nachweise sind aus diesem Dokument übernommen bzw. als fehlend
vermerkt, nicht neu erzeugt.

**Lesehinweis Status-Vergabe:** `bestanden` wird nur vergeben, wenn ein
automatisierter Test **exakt** das Szenario prüft (Funktionsname zitiert).
Ein nur **verwandter** Test (prüft Nachbarlogik, nicht exakt das Szenario)
ergibt `teilweise`. Fehlt jeder Nachweis, aber die Implementierung ist
auffindbar, ergibt das `noch nicht geprüft`. Keine der folgenden
`bestanden`-Zuordnungen ist eine „vollständig verifizierte" Abnahme im
Sinne der Definition of Done aus Dokument 04 — es fehlt durchgängig der
Geräte-/Apple-Nachweis; sie bedeuten ausschließlich, dass ein
automatisierter Test exakt die dokumentierte Szenario-Erwartung auf
Daten-/Logikebene beweist.

| ID | Szenario (Kurzform) | Priorität | Implementierungsstelle | Automatisierter Nachweis | Geräte-Nachweis | Status | Verbleibende Lücke |
|---|---|---|---|---|---|---|---|
| A01 | Ziel/Tage/Equipment bereits beantwortet → keine erneute identische Befragung | P2 | `OnboardingView.swift` (`weeklyGoal` dient zugleich als `PlanMatchmaker`-`preferredDays`; `trainingHistoryAnswer`/`ExperienceTrackResolver` statt zweiter Erfahrungsfrage) | `PlanMatchmakerTests.swift`, `ExperienceTrackTests.swift`, `ExperienceTrackBackfillTests.swift` (verwandt: Logikebene, kein Navigationstest der UI selbst) | Build/Commit `fc2ad39`, TestingBot-Sessions dieser Runde (siehe Nachtrag). Teil-Beleg INNERHALB einer einzigen Onboarding-Durchlaufs: Ziel ("Functional/Hybrid", Schritt 3) und Ausdauerform+Coach-Entscheidung (eigener Schritt) wurden beim Wechsel in den „Build Plan"-Unterpfad korrekt vorbefüllt übernommen (kein erneutes Abfragen von Ausdauerform/Coach dort), die übergeordnete Zielkarte („Primary focus") musste dort jedoch erneut ausgewählt werden. Die eigentliche A01-Kernfrage — bestehendes PROFIL aus einem früheren, abgeschlossenen/abgebrochenen Durchlauf, erneuter Eintritt ins Onboarding — wurde NICHT getestet: es gibt keinen in dieser Runde gefundenen Weg, das reguläre (nicht entwickler-spezifische) Onboarding mit einem bereits bestehenden Profil erneut zu triggern. | teilweise | Weiterhin kein Gerätebeleg für den eigentlichen A01-Fall (bestehendes Profil aus früherem Durchlauf). Neu beobachtet: die übergeordnete Zielkarte wird beim Wechsel Onboarding→„Build Plan" NICHT vorbefüllt, nur Ausdauerform/Coach — mögliche Teillücke, aber keine erneute identische Frage im engeren Sinn (gleiche Frage, andere Oberfläche). |
| A02 | Gemeinsamer Builder und Onboarding, gleiche Eingaben → gleiche fachliche Planung | P2 | `PlanGenerator` (gemeinsam genutzt), `PlanDraftResultAdapter`; ABER `OnboardingView.enduranceModalityStep` ist laut eigenem Kommentar ein „Duplikat von `PlanBuilderView.enduranceModalitySubflow`" | `PlanDraftResultAdapterTests.swift` (verwandt: Adapter-Korrektheit, kein Vergleichstest Onboarding- vs. Builder-Pfad) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test vergleicht beide Pfade bei identischer Eingabe; dokumentiertes UI-Duplikat steht in Spannung zu „keine kopierte zweite Oberfläche" (siehe Widersprüche unten). |
| A03 | Hybrid + Laufen ohne Coach → Kraft/Laufen im Vorschlag, Coach aus | P2 | `OnboardingView.enduranceModalityStep`, `UserBodyProfile.setEnduranceModality` | `PlanningContextTests.testRunCoachDisabledIsAlwaysValidRegardlessOfModality` (verwandt: Validität, nicht Plan-Inhalt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3, Onboarding-Session 1). Hybrid gewählt, Ausdauerform "Both" (Laufen+Radfahren; deckt zugleich A06 ab), Coach-Frage mit "Schedule running in my week" (aus) beantwortet, über „Build Plan" bis zur Wochenvorschau durchgespielt: Vorschau zeigte „Bodyweight · Push & Pull"/„Bodyweight · Pull & Push" (Kraft) UND „Easy Run, 45 min" (Laufen) im selben 3-Tage-Entwurf, kein Coach-Hinweis/-Badge sichtbar. Nach Abschluss des Onboardings zeigte der PERSISTIERTE Plan dieselbe Kombination (Mon/Wed/Fri: Pull&Push, Easy Run, Push&Pull) — Kraft und Laufen tatsächlich beide im gespeicherten Plan vorhanden, Coach aus. | bestanden | Nur ein konkreter Ablauf (Hybrid+Both-Modalität, Coach aus, 3-Tage-Plan) geprüft; nicht jede Tage-/Frequenz-Kombination. |
| A04 | Hybrid + Laufen mit Coach → Coachentscheidung und unterstütztes Ziel übernommen | P2 | wie A03, plus `runCoachWanted`-Pfad in `finishOnboarding()` | `PlanningContextTests.testRunCoachEnabledWithRunningIsValid` (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). "Work toward a goal with a run coach" ausgewählt (Coach an) bei Ausdauerform "Both": Auswahl wurde sichtbar übernommen (Radiobutton-Zustand, Auswahl blieb bei weiterer Navigation bestehen, siehe A06/A08). Im weiteren Onboarding-Verlauf (Equipment, Trainingshistorie, Start-Check) erschien zu KEINEM Zeitpunkt eine Frage zu Laufziel/Distanz/Referenzleistung/Zieldatum — bestätigt A09s Befund einer fehlenden Implementierung unabhängig vom Coach-Zustand. In der Wochenvorschau selbst war optisch kein Unterschied zum Coach-aus-Zustand erkennbar (kein sichtbares Coach-Badge/-Hinweis). | teilweise | Die Coach-ENTSCHEIDUNG wird übernommen (Auswahlzustand bleibt korrekt bestehen), aber: (1) kein unterstütztes Ziel wird je erhoben (A09-Lücke bestätigt), (2) kein sichtbarer Unterschied der Wochenvorschau zwischen Coach an/aus beobachtet — unklar, ob „unterstütztes Ziel übernommen" über diese UI überhaupt erfüllbar ist, solange A09 nicht implementiert ist. |
| A05 | Hybrid + Radfahren → keine unnötige Laufcoach-Frage | P2 | `OnboardingView.swift` (`enduranceModality.supportsRunCoach` blendet die Frage aus) | `PlanningContextTests.testRunCoachEnabledWithCyclingOnlyIsInvalid`, `testSupportsRunCoachMatchesPlanningContextInvariant` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logik-/UI-Gating geprüft; kein Geräte-Screenshot-Beleg der tatsächlich ausgeblendeten Frage. |
| A06 | Laufen/Radfahren kombiniert → Auswahl bleibt nach Coachingentscheidung bestehen | P2 | `EnduranceModality.both` (`PlanningContext.swift`) | `PlanningContextTests.testRunCoachEnabledWithBothIsValid`, `testEnduranceModalityMapsOntoExistingTrainingTypeKinds` (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). "Both" (Running+Cycling) ausgewählt → Coach-Frage erschien weiterhin (nicht ausgeblendet, korrekt lt. Dok. 02 Tabelle) → "Work toward a goal with a run coach" angetippt → "Both" blieb sichtbar ausgewählt/markiert (Screenshot-bestätigt, kein Reset auf "Running" o.ä.). Zusätzlich im „Build Plan"-Unterpfad reproduziert: dort war "Both" aus der vorherigen Onboarding-Antwort bereits vorbefüllt und blieb nach erneutem Antippen der Coach-Option weiterhin korrekt markiert. | bestanden | Nur die Selektions-UI-Ebene geprüft (Auswahlzustand bleibt nach Coach-Entscheidung bestehen); ob der generierte Wochenplan bei "Both" tatsächlich IMMER beide Modalitäten (statt nur einer, je nach Tagesbudget) enthält, wurde nicht geprüft — der konkrete 3-Tage-Testplan enthielt nur eine Laufeinheit, keine Radfahren-Einheit (plausibel durch Verteilungslogik bei wenigen Slots, nicht verifiziert als Bug). |
| A07 | Coach an → aus → gewollte Laufeinheiten bleiben, keine aktiven Coachempfehlungen | P2 | `UserBodyProfile.setEnduranceModality`/`cardioCoachingEnabled` | `UserBodyProfileTests.testChangingModalityToCyclingClearsPreviouslyEnabledCoach` (verwandt: Modality-Wechsel, nicht reines Coach-Toggle) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3, „Build Plan"-Unterpfad außerhalb des Onboardings, gleiche Subflow-Logik lt. Code-Kommentar „Duplikat von PlanBuilderView.enduranceModalitySubflow"). Coach bei "Running" eingeschaltet ("Work toward a goal with a run coach" ausgewählt, Markierung bestätigt), dann wieder auf "Schedule running in my week" (Coach aus) zurückgetippt → Auswahl wechselte sauber zurück, keine optische Vermischung beider Zustände. Danach bis zur Wochenvorschau mit Coach AN durchgespielt (Easy Run sichtbar) — der symmetrische Schritt "danach im selben Entwurf wieder ausschalten und prüfen, dass die Laufeinheit bestehen bleibt" wurde aus Zeitgründen nicht mehr im selben Durchlauf nachvollzogen (Entwurf wurde stattdessen verworfen, keine Persistenz geprüft). | teilweise | Sauberes Umschalten Coach an/aus OHNE Vermischung/Stale-State ist jetzt gerätebestätigt. Weiterhin fehlt der direkte Beleg, dass eine bereits geplante Laufeinheit im EINEM fortlaufenden Entwurf nach Coach-an→aus (in dieser Reihenfolge, nicht umgekehrt) bestehen bleibt. |
| A08 | Ausdauerform wechseln und zurückgehen → kein veralteter Status/Planinhalt | P2 | `OnboardingView.goToNextStep`/`goToPreviousStep`, `enduranceModality`-State | `UserBodyProfileTests` (Modality-Wechsel, verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). Mit Coach eingeschaltet bei "Running" → auf "Cycling" gewechselt: Coach-Frage verschwand vollständig und sauber (Radfahren unterstützt laut Dok. 02 keine Coach-Frage), keine veraltete "Work toward a goal"-Markierung sichtbar hängen geblieben. Zurück auf "Running" gewechselt: Coach-Frage erschien wieder, aber zurückgesetzt auf den DEFAULT ("Schedule running in my week", Coach aus) — NICHT die vorher gewählte "mit Coach"-Option wiederhergestellt. Kein veralteter/inkonsistenter Zustand beobachtet. | bestanden | Zurücksetzen auf Default (statt Wiederherstellen der letzten Wahl) beim Rück-Wechsel ist kein veralteter Zustand im Sinne von A08 (keine falsche/inkonsistente Anzeige), aber auch keine Gedächtnisfunktion — falls letzteres erwartet wird, wäre das ein eigener, hier nicht gestellter Anspruch. |
| A09 | Unbekannte Referenzleistung → keine erfundenen Werte/stille Nullannahme | P2 | **keine erkennbare Implementierung gefunden** im Onboarding | kein Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten): Dok. 02 §4 verlangt diese Fragen im Onboarding bei aktiviertem Coach; der Code stellt sie dort nicht. |
| A10 | Eingebetteten Wocheneditor bestätigen → nur Onboarding-Entwurf geändert | P1 | `OnboardingView.finishOnboarding()` (kein früher Plan-Insert aus der Vorschau) | kein direkter Test; `PlanCreationOperationTests.swift`/`PlanDraftResultAdapterTests.swift` decken die angrenzende Logik ab (verwandt) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). Im eingebetteten „Build Plan"-Wocheneditor eine Einheit per Drag verschoben (Position 2→1), danach den Haken getippt: Die App sprang DIREKT zum Dashboard mit bereits aktivem, persistiertem Plan — der Haken in diesem Einstiegspfad beendet das GESAMTE Onboarding in einem Schritt (keine Rückkehr zu einer separaten, noch bearbeitbaren Onboarding-Zusammenfassung). Die vorgenommene Reorder-Änderung war im fertigen, gespeicherten Plan korrekt übernommen (gleiche Reihenfolge wie im Entwurf). Anschließend genau "1 PLAN" in der Plan-Liste (kein verwaister/doppelter Datensatz). | teilweise | Die geprüfte Garantie "kein vorzeitiger/doppelter Plan-Insert" ist erfüllt (Entwurfsänderung korrekt übernommen, nur 1 Plan). Die genaue Lesart "Haken übernimmt NUR den Entwurf und führt zur Vorschau zurück" (Dok. 02 §6, Punkt 2) trifft auf den hier getesteten „Build Plan"-Pfad NICHT zu — dort ist der Haken zugleich die Onboarding-Abschlussaktion (Punkt 3). Ob es daneben einen separaten „kompakte Wochenvorschau mit eigenem Haken + eigenem späteren Finish"-Bildschirm gibt, der dieser engeren Lesart entspricht, wurde in dieser Runde nicht gefunden/getestet. |
| A11 | Onboarding abbrechen/mehrfach abschließen → keine verwaisten/doppelten Pläne | P1 | `OnboardingView.finishOnboarding()` (`isFinishingOnboarding`-Guard), `OnboardingPlanCreationNotice` | `OnboardingPlanCreationNoticeTests.swift`, `OnboardingFinishPlanSelectionTests.swift` (verwandt: Notice-/Auswahl-Logik, nicht der Doppel-Tap-Guard selbst) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. a) Mehrfach-Tap: 6 schnell aufeinanderfolgende Taps auf "Finish" am letzten Onboarding-Schritt → Plans-Liste zeigt danach exakt "1 PLAN" (kein Dupe), Guard bestätigt wirksam. b) Abbruch: Onboarding bis zum letzten Schritt (vor "Finish") durchlaufen, App per `terminateApp` hart beendet und neu gestartet → sauberer Neustart bei Schritt 1 ("Welcome"), kein Absturz, kein sichtbar hängender Zustand. Onboarding danach regulär bis "Finish" wiederholt und abgeschlossen → ebenfalls exakt "1 PLAN" (kein verwaister Datensatz aus dem abgebrochenen Versuch). | bestanden | Kein Negativbeweis, dass tatsächlich ein `UserBodyProfile`-Datensatz aus dem abgebrochenen Versuch im Store verblieb (nur indirekt über "1 PLAN" nach Abschluss geschlossen, kein direkter Store-/Export-Dump geprüft). |
| B01 | Wocheneditor Drag & Drop → Reihenfolge korrekt, alternative Bedienung möglich | P2 | `PlanBuilderView.resultStepView`/`moveDraftDays`, `PlanDraft.moveDay` | `PlanDraftTests.testMoveDayReordersAndPreservesStableID` u.a. (exakte Logikabdeckung) | Build/Commit `fc2ad39`, TestingBot-Session (Runde 3). BEIDE Bedienwege im selben Wocheneditor geprüft: (1) „Move to…"-Menü (alternative/zugängliche Bedienung): "Easy Run" per Menü auf "Position 1" verschoben → Reihenfolge korrekt neu sortiert, sofort sichtbar. (2) Echte Drag-Geste (langer Druck + Bewegung über mehrere Zwischenschritte): "Bodyweight · Pull & Push" von Position 3 an Position 1 gezogen → Reihenfolge erneut korrekt neu sortiert (alle 3 Einheiten korrekt neu angeordnet, keine Duplikate/Lücken). Ein einzelner schneller Swipe ohne Haltephase loeste die Drag-Geste NICHT aus (Geraete-/Gesten-Nuance, kein Produktfehler — ein echter Finger haelt beim Drag typischerweise). | bestanden | Nur ein 3-Tage-Entwurf im „Build Plan"-Pfad geprüft, nicht die eigenständige Builder-Variante außerhalb des Onboardings; beide dürften laut Code dieselbe `moveDraftDays`/`PlanDraft.moveDay`-Logik nutzen. |
| B02 | Inhalt fixiert, Woche neu verteilen → Inhalt bleibt, Position regelkonform behandelbar | P2 | `PlanDraft.setContentFixed`/`redistribute` | `PlanDraftTests.testRedistributeLeavesContentFixedDayCompletelyUntouchedButFillsOthersFromThePool`, `testContentFixationDoesNotPreventReordering` | kein Geräte-Nachweis vorhanden | bestanden | Reine Logikprüfung ausreichend und exakt passend; kein Geräte-Nachweis der UI-Darstellung. |
| B03 | Position fixiert, Übungen variieren → Position bleibt, erlaubter Inhalt veränderbar | P2 | `PlanDraft.setPositionFixed`/`replaceContent` | `PlanDraftTests.testPositionFixationDoesNotPreventContentReplacement`, `testRedistributeAllowsNewContentOnAPositionFixedButNotContentFixedDay` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene; keine UI-Geräteprüfung. |
| B04 | Manuelle Änderungen + Neuberechnung → keine stillen Verluste | **P1** | `PlanGeneratorInstantiator.recalculate` (Fingerprint-Vergleich, überspringt manuell geänderte/historienbehaftete Tage) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithEditedExerciseSets`, `testRecalculateSkipsDayWithActiveSessionAndReportsIt`, `testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact` | kein Geräte-Nachweis vorhanden | bestanden | Datenintegrationsebene vollständig bewiesen; kein Geräte-Nachweis für den UI-Auslöser ("Neu rechnen"). |
| B05 | Keine passende Lösung → sichtbarer Konflikt statt abgeschnittener Einheiten | P2 | `PlanBuilderView.presentAlternatives`, `PlanDraft.redistribute` (schlägt sauber fehl statt zu kürzen) | `PlanGeneratorTargetedAlternativesTests.testCardioDayHasNoAlternatives`, `testDayNotMatchingAnySelectionHasNoAlternatives`; `PlanDraftTests.testRedistributeFailsAndLeavesDraftUnchangedWhenAllDaysAreContentFixed` | kein Geräte-Nachweis vorhanden | bestanden | Kernzusage bewiesen; der sichtbare Toast selbst ist nicht geräteverifiziert. |
| B06 | Mehrfach auf Haken tippen/Fehler beim Speichern → keine Duplikate, Entwurf bei Fehler erhalten | **P1** | `PlanBuilderView` (`isAdopting`-Doppel-Tap-Guard), `PlanCreationOperation` | `PlanCreationOperationTests.testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan`, `testGenuineSaveFailureIsRetryableAndDoesNotMarkAnythingAsCommitted`, `testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce` | kein Geräte-Nachweis vorhanden | bestanden | Datenebene vollständig bewiesen; kein Geräte-Nachweis des realen Mehrfach-Tap-UI-Pfads. |
| C01 | Cardio-/Laufziel speichern → gebündelte Vorschau, kein stilles Bulk-Update | P2 | `CardioFeasibilityCardModel.make/accept/dismiss/acceptCustom` | `CardioFeasibilityCalculatorTests.swift` (verwandt: Berechnung, nicht Accept/Dismiss-Logik selbst) | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Laufcoach im Profil aktiviert + 5K-Zeit eingetragen, mit Haken gespeichert, bei einem aktiven Plan OHNE jede Cardio-/Lauf-Einheit (reiner Kraft-Template-Plan "Football Athletic") — Ergebnis: KEINE Vorschlagskarte erschien, weder direkt noch auf dem Dashboard danach. Nicht abschließend einzuordnen: plausibel korrektes Verhalten (nichts zum Anpassen vorhanden, da der aktive Plan keine Laufinhalte hat), aber der eigentliche POSITIVE Auslösefall (aktiver Plan MIT Laufeinheiten + Cardio-Zieländerung) wurde aus Zeitgründen in dieser Runde nicht mit einem passenden Testplan nachgestellt. | teilweise | Weiterhin kein Gerätebeleg für den eigentlichen Auslösefall (gebündelte Vorschau bei einem Plan MIT Laufinhalten); nur der Negativfall (kein Laufinhalt → keine Karte, plausibel aber nicht als Absicht verifiziert) wurde beobachtet. |
| C02 | Plananpassung ablehnen → Profilentscheidung bleibt, Plan unverändert | P2 | `CardioFeasibilityCardModel.dismiss(profile:)` | `EditorDiscardSnapshotTests.testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable` (verwandt: Annahme-Fall, nicht Ablehnen-Fall) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test ruft `dismiss(profile:)` direkt auf und prüft Plan-/Profilzustand danach. |
| C03 | Equipment nicht vorhanden → betroffene Übungen mit begründetem Ersatz | P2 | `PlanEquipmentCheck`, `PlanEquipmentAdaptationApplier` | `PlanEquipmentAdaptationApplierTests.testApplyArchivesTheOriginalAndInsertsAReviewedReplacement`, `PlanEquipmentCheckTests.testDumbbellWithoutConfirmedBenchIsUnknownNotUnavailable` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logik-/Datenebene; keine Geräteprüfung der angezeigten Ersatz-Begründung. |
| C04 | Nur Präferenz ändern → optionale Neugewichtung, kein Geräteverbot | P2 | **keine erkennbare Implementierung gefunden** — Equipmentmodell kennt nur `available`/`unavailable`/`unknown` | kein Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten): Dok. 01 §6 verlangt 4 Zustände inkl. Präferenz-Gewichtung; Code kennt nur 3. |
| C05 | Bank/Klimmzugstange unbekannt → bleibt nach Neustart, Bestätigung und Export/Import unbekannt | P2 | `UserEquipmentProfile`/`EquipmentRequirement`, `DataExportService`/`DataImportService` | `DataPortabilityRoundtripTests.testExplicitlyUnknownEquipmentSurvivesRoundtrip`; `EquipmentRequirementTests.testConfirmRemainingAsUnavailableNeverOverridesAnExplicitlyUnknownItem` | kein Geräte-Nachweis vorhanden | teilweise | Export/Import-Pfad exakt getestet; kein separater Store-Neustart-Test, kein Gerätenachweis. |
| C06 | Laufende Session + Planänderung → Sessionstruktur/Logs bleiben konsistent | **P1** | `PlanGeneratorInstantiator.recalculate` (überspringt Tage mit `WorkoutSession`-Historie) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithActiveSessionAndReportsIt` (exakt für Recalculate); direkte `DayEditorView`-Übungsänderung während laufender Session NICHT separat abgedeckt | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. Beobachtet: Session auf "Full Body A" gestartet, Satz 1/3 von "Goblet Squat" geloggt; währenddessen im Day-Editor Satzzahl dieser Übung 3→2 reduziert und gespeichert. Laufende Session zeigte danach unverändert "1/3" mit allen 3 ursprünglichen Sätzen (Edit NICHT übernommen), geloggter Satz 1 blieb erhalten; restliche 2 Sätze wurden normal fertig geloggt ("3/3 — All sets done"), kein Crash. Tag-Editor zeigte weiterhin korrekt "2 sets" für künftige Starts. Session danach regulär verworfen (kein Rest-Zustand). **Ausdrücklich begrenzt auf genau diesen einen Ablauf (Satzzahl-Reduktion) — kein Nachweis für andere strukturelle Planänderungen (Übung hinzufügen/löschen, Tag löschen/umsortieren, Zeitformat-Wechsel) während einer laufenden Session an demselben Tag.** | teilweise | Nur EIN konkreter Ablauf (Satzzahl-Reduktion während laufender Session) geräteverifiziert und darf NICHT als vollständiger Nachweis für "Sessionstruktur/Logs bleiben bei jeder Planänderung konsistent" gewertet werden. Andere strukturelle Änderungen (Übung hinzufügen/löschen am laufenden Tag, Mehrfach-Tage-Pläne) sind ungeprüft; die zugrundeliegende Schutz-Mechanik (Snapshot vs. Live-Referenz) ist nicht im Code lokalisiert, nur das Verhalten für den einen Ablauf beobachtet. |
| D01 | Reines Reorder + Verwerfen → Originalreihenfolge wiederhergestellt | **P1** | `PlanEditorView.revertDayOrder`/`dayOrderIsDirty`, `DayEditorView.revertExerciseOrder`/`exerciseOrderIsDirty` | `EditorDiscardSnapshotTests.testPlanEditorViewDetectsAndRevertsDayReorder`, `testDayEditorViewDetectsAndRevertsExerciseReorder` | kein Geräte-Nachweis vorhanden | bestanden | Nur die Datenlogik ist exakt bewiesen; die physische Drag-Geste selbst ist unter B01 vermerkt. |
| D02 | Add/Delete + Reorder + Verwerfen → definiertes Verhalten, keine Sortierkollision | **P1** | Hinzufügen/Löschen sind bewusst sofort wirksame, nicht per Discard rückrollbare Aktionen | `EditorDiscardSnapshotTests.testPlanEditorViewIgnoresNewlyAddedDayInReorderRevert`, `testDayEditorViewIgnoresNewlyAddedExerciseInReorderRevert` (verwandt: deckt nur "neu hinzugefügt" ab, nicht die volle Kombination) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. Beobachtet: Tag "Fri/Full Body C" gelöscht, danach "Mon/Full Body A" per Drag an Position 3 verschoben (beides in derselben Editor-Sitzung), dann ohne Speichern zurücknavigiert → "Discard Changes?"-Dialog bestätigt. Ergebnis beim Wiederöffnen: 6 Tage (Fr korrekt entfernt geblieben, da sofort wirksam), Mon/Tue/Wed/Thu/Sat/Sun je genau einmal vorhanden mit der ursprünglichen Inhalt-Wochentag-Zuordnung (Mon=Full Body A, Wed=Full Body B) wiederhergestellt — die Reorder-Änderung wurde sauber zurückgerollt, keine doppelten Wochentage, keine Indexlücken/-kollisionen. | bestanden | Nur eine Lösch+Reorder-Kombination in einer Sitzung geprüft (nicht z. B. Hinzufügen+Löschen+Reorder gleichzeitig oder mehrfaches Reorder nach dem Löschen). |
| D03 | Name/Ton ändern, separate Aktion bestätigen → unabhängiger Edit bleibt verwerfbar | **P1** | `PlanEditorView.rebaselineTargetEnvironment()`, `ProfileEditorView.rebaselineCardioGoal()` | `EditorDiscardSnapshotTests.testPlanMetaSnapshotTargetedRebaselineLeavesOtherFieldsDirty`, `testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen, kein Geräte-Nachweis der UI-Sequenz. |
| D04 | A aktiv → B an → B aus → Verwerfen → Ausgangsaktivierung wiederhergestellt | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardSurvivesOnOffToggleSequence`, `testOtherActivePlanStateIsDirtyDetectsOnOffToggleSequence` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D05 | Inaktiver Plan ohne anderen aktiven Plan → unverändert nicht dirty | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` (nil-Fall) | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardReturnsNilWhenNoOtherPlanWasActiveAtOpen`, `testOtherActivePlanStateIsDirtyIsFalseWhenNoOtherPlanWasActiveAtOpen` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D06 | Rückrollen von Trainingsort → keine erneut ausgelöste Migration beim Schließen | **P1** | `PlanEditorView.revertToSnapshot()`/`isApplyingSnapshot`-Flag | `EditorDiscardSnapshotTests.testPlanMetaSnapshotRevertsEnvironmentAndActiveFlagTogether` (verwandt: prüft nur Datenmodell-Rollback) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. Beobachtet: Trainingsort Gym→„No Equipment" löste eine SOFORTIGE, automatische Anpassung mit Toast („9 ersetzt · 1 ohne Alternative · 2 unverändert") aus — OHNE einen vom Nutzer zu bestätigenden/abzulehnenden Dialog (der `pendingEnvironmentSwap`-Adapt/Verwerfen-Dialog aus dem Code kam bei diesem Übergang nicht sichtbar zur Anzeige; ein ANDERER Dialog — „Restore Original Exercises?" (DEL-049) — erschien reproduzierbar beim Zurückwechseln auf einen Ort mit bereits archivierten Originalen). Nach der Anpassung: Zurück-Navigation zeigte KEINEN Verwerfen-Dialog mehr (Änderung war bereits rebaselined), Trainingsort blieb wie zuletzt gesetzt. Erneutes Öffnen des Plan-Editors zeigte den Trainingsort unverändert, OHNE erneut ausgelöste Migration/Toast/Dialog. | teilweise | Die geprüfte Kernzusage ("kein erneuter Migrations-Dialog beim bloßen Schließen/Wiederöffnen") ist bestätigt. NICHT isoliert reproduzierbar war der im Testablauf beschriebene Einzelschritt "Dialog erscheint → bewusst ablehnen/Verwerfen, OHNE durchzulaufen" — in dieser Session lief die Anpassung bei einem echten Equipment-Konflikt automatisch durch, ohne dass eine Nutzerbestätigung abgewartet wurde; ob das Produktverhalten oder ein Automatisierungs-Timing-Artefakt ist, bleibt unklar. |
| E01 | Körpermessung per Haken bearbeiten → bestehende Messung aktualisiert, kein Duplikat | **P1** | `MeasurementView.save(profile:)` (`editingMeasurement`-Zweig überschreibt das bestehende Objekt; **Fund+Fix dieser Runde:** fehlender `context.save()`, siehe Commit `89c788a`) | `MeasurementPersistenceTests.testEditedMeasurementWithImmediateSaveSurvivesARealStoreRestartWithoutDuplication` (neu, reproduziert die Fix-Technik exakt) | Build/Commit `89c788a` (nach Fix), TestingBot-Session `d5e2f4c5…03720961`. Bestehenden Verlaufseintrag (Gewicht 75,00 kg) per Haken bearbeitet → Gewicht auf 78,00 geändert, gespeichert: Verlauf zeigte danach weiterhin genau 2 Einträge (kein dritter/doppelter), der bearbeitete Eintrag zeigte 78,00 kg. Direkt danach `terminateApp` + Neustart (echter Kaltstart): Dashboard und Verlauf zeigten 78,00 kg weiterhin korrekt, weiterhin genau 2 Einträge. | bestanden | Nur der Geräte-Ablauf mit vollständigen Pflichtfeldern (Gewicht+Hals+Taille) geprüft; der "nur Gewicht nachträglich geändert, Umfänge unverändert"-Spezialfall (`isEditingWeightOnlyEntry`) wurde nicht separat auf dem Gerät durchgespielt. |
| E02 | Cooldown vorgesehen/ausgeblendet/nicht vorhanden → jeweils nachvollziehbare Anzeige | P2 | `ActiveWorkoutView` (Warmup-/Cooldown-Sichtbarkeits-Filter), `ExerciseRole.cooldown` | `ExerciseRoleTests.testCooldownIsSkipped` (verwandt: prüft nur Progressions-Ausschluss, nicht die drei Anzeigezustände) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test für die drei konkreten Anzeigezustände selbst. |
| E03 | Alle gültigen RIR-Ganz-/Halbwerte → vollständig sichtbar und korrekt gespeichert | P2 | `SetRow.swift` (strukturelle RIR-Spalte, Zwei-Zeilen-Fallback laut Code-Kommentaren) | kein Test gefunden (kein RIR-Testfile) | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Alle 11 gültigen Werte (0, 0,5, 1, 1,5, 2, 2,5, 3, 3,5, 4, 4,5, 5) im aktiven Satz-Logging nacheinander über den RIR-Regler eingestellt: jeder Wert erschien vollständig und korrekt in der RIR-Kapsel (z. B. "3,5", nicht abgeschnitten wie im Original-Bugreport "R2/R4..."), mit passendem Tooltip-Text je Stufe (z. B. "Absolute failure" bei 0). Ein Satz mit RIR 3,5 geloggt (Haken) → Wert blieb nach dem Loggen unverändert sichtbar in der (ausgegrauten) Zeile. | bestanden | Nur die Anzeige/das direkte Loggen geprüft; kein Kaltstart-Test, ob ein geloggter RIR-Wert (z. B. 3,5) auch nach einem Neustart in der Historie/Zusammenfassung weiterhin korrekt (nicht gerundet) angezeigt wird. |
| E04 | Schmaler Bildschirm, große Schrift, Dezimalgewicht, kg/lbs → kein Abschneiden/Overflow | P2 | `SetRow.swift` (Layout-Fallback-Kommentare); **Fund+Fix dieser Runde:** `weightInput` ohne `minimumScaleFactor`, siehe Commit `64ba455` | `SetRowWeightFieldScalesDownInsteadOfTruncatingTests` (neu, prüft exakt die Fix-Stelle) | Build/Commit `64ba455` (nach Fix), TestingBot-Sessions (Runde 3). **Echter Bug gefunden und gefixt:** bei aktivierter „Larger Accessibility Sizes" (größte Dynamic-Type-Stufe, über iOS-Einstellungen gesetzt) zeigte das KG-Feld ein eingegebenes Dezimalgewicht "72,5" abgeschnitten als "7...". Fix: `.minimumScaleFactor(0.5)` + `.lineLimit(1)` auf `SetRow.weightInput` (Commit `64ba455`). Geräte-Nachtest NACH dem Fix (frischer CI-Build): „72,5" bei identisch maximaler Textgröße jetzt vollständig sichtbar (verkleinerte Schrift statt Abschneiden). Dezimalgewicht mit Komma (deutsches/belgisches Zahlenformat, Region=Belgien) durchgängig korrekt verarbeitet (z. B. Volumenberechnung 72,5 × 8 = 580 kg korrekt). Dark Mode auf demselben Satz-Logging-Screen geprüft: alle Werte (KG, Reps, RIR) weiterhin klar lesbar, guter Kontrast. Light Mode durchgängig in allen übrigen Screenshots dieser Runde bestätigt funktionsfähig. Englisch (Gerätesprache during gesamter Runde): keine fehlenden/kaputten Platzhalter über sehr viele Screens hinweg beobachtet. Deutsch: iPhone-Systemsprache in den Einstellungen erfolgreich auf Deutsch umgestellt (Einstellungen-UI zeigte danach korrekt "Sprache & Region"/"Bearbeiten" etc.), jedoch überlebte die WebDriverAgent-Automatisierung den dadurch ausgelösten SpringBoard-Respring nicht mehr (App-Aktivierung/Touch-Eingaben schlugen danach fehl) — die Deltiq-App selbst konnte in dieser Runde NICHT mehr in deutscher Sprache geöffnet/geprüft werden. Türkisch: aufgrund der DE-Instabilität in dieser Runde nicht versucht. | teilweise | Dezimalgewicht/kg-Format, Dark Mode und der konkret reproduzierte Abschneide-Bug sind jetzt gerätebestätigt bzw. gefixt. Bekannte Nachweislücke, Auswirkung noch nicht abschließend geprüft: Deltiq selbst in Deutsch (Automatisierung überlebte den Systemsprachwechsel nicht) und in Türkisch (nicht versucht) sowie ein echter schmalerer Bildschirm (nur Dynamic-Type-Vergrößerung getestet, kein kleineres Simulator-Gerät). |
| E05 | Mehrstufig zurückwischen → wiederholt eine Ebene zurück, keine dauerhafte Sperre | P2 | `Theme.swift` (`deltiqSwipeBackEnabled`, pro View über `!isDirty` gesteuert) | kein dedizierter Test gefunden | Build/Commit `254d669`, TestingBot-Sessions (Runde 3). Kette Plan-Editor → Tag-Editor → Übungs-Editor durchlaufen. Horizontale Zurück-Wisch-Geste funktionierte WIEDERHOLT und ohne Einschränkung auf Plan-Editor- UND Tag-Editor-Ebene (beide im selben, gemeinsamen `NavigationStack` gepusht) — mehrfach hintereinander reproduziert, keine Sperre nach einmaliger Nutzung. Auf Übungs-Editor-Ebene wirkte dieselbe Geste dagegen NIE (auch nach einem zunächst versuchten Fix, siehe Korrektur-Commit `254d669`): Root Cause gefunden — `DayEditorView` öffnet `ExerciseEditorView` per `.sheet(item:) { NavigationStack { ExerciseEditorView(...) } }`, also mit einer EIGENEN, frischen `NavigationStack` (nur sich selbst als Root), anders als Plan-/Tag-Editor (`NavigationLink` im GEMEINSAMEN Stack). Der interne `SwipeBackHostController.gestureRecognizerShouldBegin` liefert dort strukturell IMMER `false` (kein Vorgänger zum Zurückpoppen). Die für eine Sheet-Präsentation tatsächlich zuständige Geste — Herunterwischen zum Schließen — wurde separat getestet und funktionierte dort korrekt (siehe unten). | bestanden | Auf Plan-/Tag-Editor-Ebene vollständig erfüllt. Für den Übungs-Editor gilt die Anforderung über die für Sheets korrekte Geste (Herunterwischen) als erfüllt, nicht über die horizontale Rand-Wisch-Geste — eine erste Fehldiagnose (vermeintlicher Fix per `.deltiqSwipeBackEnabled`) wurde durch Geräte-Nachtest widerlegt und zurückgenommen (siehe Nachtrag unten). |
| E06 | Ungespeicherter Entwurf + Schließgeste → kein Umgehen des Schutzes | **P1** | Konsistentes Muster: `.interactiveDismissDisabled(isDirty)` + `.deltiqSwipeBackEnabled(!isDirty)` über alle Editoren — **blockierend**, nicht "Dialog beim Wischversuch" | `EditorDiscardSnapshotTests.swift` deckt die `isDirty`-Erkennung breit ab (verwandt); kein Test der tatsächlichen Gesten-Blockade selbst | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Plan-Editor geöffnet, Planname geändert (Entwurf dirty), horizontale Zurück-Wisch-Geste versucht → KEINE Reaktion (kein Dialog, keine Navigation — tatsächlich blockierend, exakt wie im Code dokumentiert). Danach den Zurück-Chevron angetippt → ein Bestätigungsdialog wurde ausgelöst (vom Automatisierungs-Framework mit `autoAcceptAlerts` automatisch bestätigt, dadurch indirekt sichtbar: App landete nach dem Tap auf der Plan-Liste MIT dem ursprünglichen, unveränderten Namen — die Änderung wurde korrekt verworfen, nicht umgangen). | bestanden | Die Kern-Garantie (Wisch-Geste bei ungespeichertem Entwurf wirkungslos, kein Umgehen) ist gerätebestätigt. Der Bestätigungsdialog selbst wurde nicht manuell bestätigt/abgebrochen (automatisch durchgereicht), daher kein expliziter Beleg für den Dialogtext/die Button-Beschriftung. |
| E07 | Trainingsseiten wechseln und Listen ziehen → bestehende Gesten erhalten | P2 | `.onMove` in `PlanEditorView`, `DayEditorView`, `DashboardSettingsView` | keine dedizierte Regressionsprüfung für "nach Seitenwechsel" gefunden | Build/Commit `64ba455`, TestingBot-Session (Runde 3). Im Plan-Editor geöffnet → zu Dashboard-Tab gewechselt → zurück zu Plan-Tab → denselben Plan erneut geöffnet → über das Ellipsis-Menü "Reorder" aktiviert → einen Trainingstag ("Lower & Core") per Drag-Handle von Position 1 auf Position 4 gezogen → Reihenfolge korrekt neu sortiert (Wochentage rotierten wie im UI-Hinweis beschrieben automatisch mit, Inhalt blieb den richtigen Tagen zugeordnet). Drag funktionierte nach dem Tab-Wechsel ohne Einschränkung, identisch zu einem Drag ohne vorherigen Seitenwechsel. | bestanden | Nur EIN Tab-Wechsel-Zyklus (Plan→Dashboard→Plan) und eine Listenart (Trainingstage im Plan-Editor) geprüft, nicht z. B. Übungsliste im Tag-Editor oder `DashboardSettingsView` nach Seitenwechsel. |
| E08 | Start-Check-Einstiege suchen → nur im Onboarding erreichbar | P2 | `BaselineCheckFlowView` — Codesuche bestätigt genau einen produktiven Aufrufer (`OnboardingView.swift`) | kein Test gefunden, der diese Invariante als Regression schützt | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Codesuche ist kein automatisierter Regressionsschutz gegen einen künftigen zweiten Call-Site, kein Gerätenachweis. |
| F01 | Vier Wochen mit viel/wenig Teilnahme → datenabhängige Empfehlung | **P3** | `FourWeekReviewOrchestrator`, `FourWeekReviewAssembler`, `FourWeekReviewDueCalculator` | `FourWeekReviewAssemblerTests.testCompliantPlanWithGoodCheckInYieldsKeepAsIs` (volle Teilnahme → `.keepAsIs`) und `.testHeavilyMissedParticipationIsSurfacedAsConcern` (keine Teilnahme → `.participationBelowPlan`) — beide mit echtem `ModelContainer` + `TrainingPlan.activatedAt` in der Vergangenheit über den realen Produktionspfad `FourWeekReviewAssembler.assemble`; ergänzt um `FourWeekReviewOrchestratorTests.testSingleMissedSessionBelowThresholdIsNotAConcern`/`.testSignificantlyMissedParticipationIsAConcern` (Schwellenwert-Abstufung statt starrer Steigerung) | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Integrationsebene) | Reiner UI-/Geräte-Nachweis (tatsächlich gerenderter Review-Screen) fehlt weiterhin — betrifft nur die Darstellung, nicht die hier bewiesene datenabhängige Entscheidungslogik. Kein Export-Hang/Zeit-Manipulationsweg nötig, siehe Nachtrag unten. |
| F02 | Flexibler Plan/Pause/Planwechsel → keine erfundene Compliance | **P3** | `FourWeekReviewAssembler`/`BlockReviewRecord`, `PlanParticipationEvaluator` | `PlanParticipationEvaluatorTests.testFlexibleScheduleCreditsTheSameOffWeekdayPatternThatFixedWouldReject`/`.testFlexibleCadenceSurplusSessionsDoNotCreditBeyondQuota` (flexibler Plan), `.testInactivePlanIsNotReliablyEvaluableBecauseDeactivationTimeIsUnknown` (Pause → `.notReliablyEvaluable`, keine erfundene Zahl), `.testEveryEvaluatedResultDisclosesTheSingleActivationAnchorLimitation` (Planwechsel als offen ausgewiesene Datenlücke statt falscher Nenner) — reine Core-Logiktests mit konstruierten historischen Daten | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Logikebene) | UI-Anzeige der Datenlücken-Hinweise selbst nicht geräteverifiziert. |
| F03 | Gute Entwicklung → „Beibehalten" als gültiges Ergebnis | **P3** | `FourWeekReviewOrchestrator` | `FourWeekReviewOrchestratorTests.testAllGoodYieldsKeepAsIsWithNoDataGaps` und `FourWeekReviewAssemblerTests.testCompliantPlanWithGoodCheckInYieldsKeepAsIs` (reale Teilnahme+Check-in → `.keepAsIs` als vollwertiges Ergebnis, nicht nur Abwesenheit von Problemen) | kein Geräte-Nachweis vorhanden | bestanden | UI-Darstellung der „Beibehalten"-Karte selbst nicht geräteverifiziert. |
| F04 | Ausgelassene Beintage/Brustschwerpunkt → Rückfrage statt Zwangswechsel | **P3** | **keine erkennbare Implementierung gefunden** — `DayAnalyzer`/`DayAnalysis` liefern nur eine EINTAGES-Muskel-Fokus-Heuristik; keine wochenübergreifende Auswertung "ausgelassene Beintage"/"bewusster Brustschwerpunkt" und keine Rückfrage-/Zielvergleichslogik im Review selbst | kein Test gefunden (keine Implementierung, die zu testen wäre) | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten, neue Kategorie analog A09/C04): Dok. 03 §6 verlangt ausdrücklich Rückfrage bzw. Zielvergleich statt Kalender-Zwangswechsel bei ausgelassenen Beintagen/bewusstem Schwerpunkt; `FourWeekReviewOrchestrator.Concern` kennt dafür keinen Fall. Echte Implementierungslücke, kein reiner Testlücken-Befund. |
| F05 | Beschwerden/fehlende RIR-Daten → keine Diagnose/erfundene Erholung | **P3** | `FourWeekReviewOrchestrator` (`.complaintsReported`), `PeriodicCheckIn` | Beschwerden-Hälfte bestanden: `FourWeekReviewOrchestratorTests.testComplaintsReportedIsAConcern` + `FourWeekReviewAssemblerTests.testLatestCheckInFeedbackIsAssembledFromRealData` (Befund wird sichtbar; UI-Text rein beobachtend "hast du Beschwerden... angegeben", keine Diagnose). RIR-Hälfte NICHT durch einen eigenen Test bewiesen, aber per Code-Audit bestätigt: weder `PlanParticipationEvaluator.Input` noch `FourWeekReviewOrchestrator.CheckInFeedback` führen überhaupt ein RIR-Feld — der Review kann strukturell keine Erholungsaussage aus fehlenden RIR-Daten erfinden, weil RIR dort gar nicht einfließt | kein Geräte-Nachweis vorhanden | teilweise | Kein dedizierter automatisierter Nachweis für den RIR-Teil (nur Code-Audit der Abwesenheit, keine Test-Assertion); kein Geräte-Nachweis für den laut Dok. 03 §4 verlangten separaten, vorsichtigen Beschwerden-Abklärungsweg selbst. |
| F06 | Review ablehnen/aufschieben/wieder öffnen → keine Doppeländerung | **P3** | `FourWeekReviewDueStatus.completeCurrentBlock`, `AbsenceDeload.remember`/`.assess`/`.apply` (von `FourWeekReviewView.resolveComeback`/`completeReview` aufgerufen) | `FourWeekReviewDueStatusTests.testCompletingTheSameBlockTwiceIsIdempotent` (doppelter Abschluss-Tap ändert nichts zweimal) + NEU `AbsenceDeloadReopenTests.testDecliningSuppressesTheSameBucketButReArmsAtAStrongerGap` (Ablehnen → Wieder-öffnen am selben Tag erzeugt keine erneute Rückfrage/Hinweisschleife; spürbar stärkere Lücke fragt dagegen zu Recht erneut) + `.testAcceptingPreventsASecondApplicationShortlyAfterReopening` (Übernehmen → Wieder-öffnen kurz danach verhindert zweite Anwendung) — alle mit echtem `ModelContainer` + echten `UserDefaults`, über dieselben Produktionsfunktionen, die der Review-Screen beim Tippen aufruft | kein Geräte-Nachweis vorhanden | bestanden (Daten-/Integrationsebene) | Der tatsächliche Tap auf dem Screen selbst (Bestätigungsdialog, Button-Zustände, "Später"-Verhalten rein visuell) ist nicht geräteverifiziert. |
| F07 | Review übernehmen → neue gültige Fassung, Historie unverändert | **P3** | `FourWeekReviewDueStatus.completeCurrentBlock`/`.history`, `BlockReviewRecord` | `FourWeekReviewDueStatusTests.testCompletingTwoBlocksInSequenceKeepsBothInHistory` (Übernahme eröffnet sofort einen neuen, gültigen Block; Block 1 bleibt in der Historie unverändert erhalten) + `.testLegacyCompletionWithoutHistoryJSONIsReadAsOneRecordWithoutFabricatedOutcome` (Altbestand wird beim Lesen nicht nachträglich umgedeutet) | kein Geräte-Nachweis vorhanden | bestanden | UI-Nachweis des tatsächlichen Wocheneditor-Vorher-/Nachher-Vergleichs beim Übernehmen fehlt. |
| F08 | Gleichzeitige Progressions-/Deload-/Review-Hinweise → keine Widersprüche | **P3** | `FourWeekReviewOrchestrator` (Deload/Comeback-Konfliktauflösung), `ProgressionEvaluator`, `DeloadAdvisor`, `ProgressionApplicator`/`DeloadManager` (Koexistenz-Fund dieser Runde) | `FourWeekReviewOrchestratorTests.testConflictingDeloadAndComebackSignalsResolveToComebackOnly` (Review-Ebene, exakt) **PLUS echter Bug gefunden und gefixt**: `ProgressionApplicator.apply`/`.evaluateOnly` schrieben bisher `.increaseWeight` auch auf eine Übung, deren Gewicht `DeloadManager` gerade reduziert und eingefroren hatte (`deloadOriginalWeight != nil`) — direkter Verstoß gegen Dok. 03 §5 ("nicht dieselbe Übung gleichzeitig steigern und reduzieren") und eine stille Datenverlust-Falle (ein späteres `endDeload()` hätte den währenddessen erarbeiteten Fortschritt wieder verworfen). Fix: Veto auf `.hold`, solange ein Deload-Snapshot offen ist (Commit `c96bf5c`). Regressionstests: `ProgressionApplicatorDeloadConflictTests.testIncreaseWeightIsVetoedToHoldWhileAnExerciseHasAPendingDeloadSnapshot`, `.testEvaluateOnlyMirrorsTheSameDeloadVetoAsApply`, Gegenprobe `.testIncreaseWeightStillAppliesNormallyWithoutAnActiveDeload` | kein Geräte-Nachweis vorhanden | bestanden (inkl. Bugfix) | Kein Geräte-Nachweis, dass das Dashboard mehrere gleichzeitige Hinweise (Progression-Celebration, Deload-Banner, Review-Fälligkeit) auch VISUELL widerspruchsfrei anordnet — nur die zugrundeliegende Entscheidungslogik (inkl. des gefixten Konflikts) ist bewiesen. |

**Status-Verteilung (45 Fälle, nach diesem Durchgang):** 28 bestanden (A03,
A05, A06, A08, A11, B01, B02, B03, B04, B05, B06, C03, D01, D02, D03, D04,
D05, E01, E03, E05, E06, E07, F01, F02, F03, F06, F07, F08) · 13 teilweise
(A01, A02, A04, A07, A10, C01, C02, C05, C06, D06, E02, E04, F05) · 4 noch
nicht geprüft (A09, C04, E08, F04) · 0 blockiert · 0 fehlgeschlagen.

(F01–F08 waren vor diesem Durchgang pauschal "blockiert"; siehe Nachtrag
unten für die Einzelfallprüfung, die diese pauschale Einstufung ersetzt.)

**Top-5-Geräteprüfung dieser Runde — Ergebnis:**

1. **E01** – Messung-Update ohne Duplikat: **echter Bug gefunden und
   gefixt** (fehlendes `context.save()`, Commit `89c788a`), danach
   geräteverifiziert inkl. Kaltstart. Bestanden.
2. **C06** – Laufende Session + Planänderung: Satzzahl-Reduktion während
   laufender Session geräteverifiziert — Session bleibt strukturell
   unverändert, kein Datenverlust, kein Crash. Ausdrücklich NUR dieser eine
   Ablauf; kein Nachweis für andere strukturelle Planänderungen während
   einer laufenden Session. Teilweise.
3. **D06** – Trainingsort-Rückrollen: Kernzusage (kein erneut ausgelöster
   Migrationsdialog beim Schließen/Wiederöffnen) geräteverifiziert. Der im
   Testablauf vorgesehene Einzelschritt "Dialog bewusst ablehnen" ließ sich
   nicht isoliert reproduzieren, da die Anpassung bei echtem
   Equipment-Konflikt automatisch ohne Bestätigungsdialog durchlief.
   Teilweise.
4. **A11** – Onboarding-Abbruch/Mehrfachabschluss: beide Teilfälle (a:
   Doppel-Tap-Guard, b: Force-Quit-Abbruch) geräteverifiziert, je exakt 1
   Plan. Bestanden.
5. **D02** – Add/Delete + Reorder + Verwerfen: Löschen+Reorder+Verwerfen in
   einer Sitzung geräteverifiziert, sauberer Rollback der Reihenfolge ohne
   Wochentag-/Index-Kollision. Bestanden.

## Reset-App-Befund eingeordnet (Nachtrag, kein Fix nötig)

Der in der vorigen Runde als "scope-fremde Beobachtung" notierte Fund
("Reset App löscht ohne Rückfrage") wurde per Code-Prüfung untersucht,
nicht durch eine erneute destruktive Geräteaktion mit echten Daten.

Befund (`Sources/FitnessAppUI/Settings/SettingsView.swift`):
- Es gibt genau EINE Aufrufstelle von `resetApp()`, gegated durch
  `showingResetConfirm`.
- Der Tap auf "Reset App" in der Danger-Zone-Sektion setzt NUR
  `showingResetConfirm = true` — löst keine Löschung aus.
- Es folgt ein `.confirmationDialog` mit eigenem Titel/Message-Text, einem
  `role: .destructive`-Bestätigungsbutton UND einem separaten
  `role: .cancel`-Abbrechen-Button.
- `resetApp()` selbst beginnt mit einem AUTOMATISCHEN Backup
  (`BackupService.createBackupAsync(..., reason: .preReset)`) — schlägt
  dieses fehl, wird abgebrochen (Fehler-Alert) und NICHTS gelöscht.
- Ein `isResetting`-Gate verhindert zusätzlich Crashes durch Views, die
  während der Löschung noch auf bald gelöschte Objekte zugreifen.

**Einschätzung:** Die Aktion ist bereits durch Bestätigungsdialog + Abbrechen-Option
+ automatisches Vor-Reset-Backup geschützt und nicht versehentlich auslösbar
(eigene, eindeutig beschriftete Zeile in einer separaten "Danger Zone"-Sektion,
kein benachbartes Element mit ähnlicher Beschriftung). Die vorherige
Geräte-Beobachtung "ohne Rückfrage" deckt sich nicht mit dem Code und ist
mit größter Wahrscheinlichkeit ein Artefakt des automatisierten Testablaufs
(die Appium-Steuerung dürfte den Bestätigungsdialog im selben Zug
durchgetippt haben, ohne ihn als eigenen Schritt zu protokollieren) statt
ein echter fehlender Schutz. **Kein Fix umgesetzt** — es liegt kein
bestätigter Datenverlust-/Sicherheitsbefund vor; eine erneute Reset-Aktion
mit echten Daten wurde zur Bestätigung bewusst nicht ausgeführt. Falls die
ursprüngliche Beobachtung dennoch real war (z. B. ein Timing-Fall, der sich
der Code-Prüfung entzieht), bitte mit einem konkreten Reproduktionsschritt
erneut melden statt pauschal zu wiederholen.

## Fachliche Widersprüche Spezifikation vs. Code (nicht eigenmächtig aufgelöst)

1. **A09 / Dokument 02 §4**: Die Spezifikation verlangt, dass bei
   aktiviertem Laufcoach im Onboarding gezielt nach Laufpensum,
   Referenzleistung, Zieldatum etc. gefragt wird. Im Code existiert dafür
   in der Onboarding-Oberfläche **keine** Implementierung — `CardioGoal`
   und `current5kReferenceSeconds` gibt es nur in `ProfileEditorView`
   (nachgelagert, außerhalb des Onboardings). Echte Implementierungslücke
   gegenüber einer verbindlichen Vorgabe, kein reiner Testlücken-Befund.
2. **C04 / Dokument 01 §6-Tabelle**: Die Tabelle verlangt vier getrennte
   Equipment-Zustände — nicht vorhanden / vorhanden / explizit unbekannt /
   **Präferenz** (als Gewichtung, kein Verbot). Der Code
   (`EquipmentRequirement`, `UserEquipmentProfile`) implementiert nur die
   ersten drei; eine separate „Präferenz als weiche Gewichtung" existiert
   nicht.
3. **A02 / 00_START_HIER.md** („Kontextabhängige Oberfläche statt
   kopierter zweiter Builder"): `OnboardingView.enduranceModalityStep`
   trägt den eigenen Code-Kommentar „Duplikat von
   `PlanBuilderView.enduranceModalitySubflow`". Beide Stellen nutzen
   dieselben Lokalisierungsschlüssel und dieselbe Entscheidungslogik, sind
   aber zwei separat gepflegte SwiftUI-Implementierungen — eine teilweise
   Abweichung von der nicht verhandelbaren Architekturgrenze.
4. **F04 / Dokument 03 §6**: Die Spezifikation verlangt bei ausgelassenen
   Beintagen bzw. einem bewusst gewählten Brustschwerpunkt ausdrücklich
   eine Rückfrage ("beibehalten oder ändern?") bzw. einen Zielvergleich,
   nie einen automatischen Kalender-Zwangswechsel. Im Code existiert dafür
   **keine** Implementierung — `FourWeekReviewOrchestrator.Concern` kennt
   nur `participationBelowPlan`/`complaintsReported`/`goalNoLongerCurrent`/
   `deloadRecommended`/`comebackSuggested`, keinen Fall für
   Muskelgruppen-/Schwerpunkt-Balance. `DayAnalyzer`/`DayAnalysis` liefern
   zwar einen Muskel-Fokus, aber nur pro EINZELNEM Tag, nicht
   wochenübergreifend und ohne jede Rückfrage-Logik. Echte
   Implementierungslücke gegenüber einer verbindlichen Vorgabe, kein
   reiner Testlücken-Befund (gleiche Kategorie wie A09/C04).

## F01–F08 differenziert geprüft (Nachtrag)

**Auftrag:** die pauschale Einstufung "F01–F08 blockiert, weil zeitabhängig
+ bekannter Export-Hang" war nicht differenziert genug — der Export-/
Geräte-Blocker betrifft ausschließlich den Versuch, die 28-/42-Tage-
Fälligkeit auf einem ECHTEN GERÄT über System-Uhr oder CSV-Re-Import zu
simulieren. Er betrifft NICHT die zugrunde liegende Entscheidungslogik,
die bereits für andere Pakete (B–E) routinemäßig über Daten-/
Integrationstests mit konstruierten historischen Feldern bewiesen wird
(echter `ModelContainer`, `TrainingPlan.activatedAt`/
`blockReviewHistoryJSON` auf einen Zeitpunkt in der Vergangenheit gesetzt,
dann der echte Produktionscode-Pfad aufgerufen — identische Technik zu
`DayEditorPersistenceTests.swift`/`MeasurementPersistenceTests.swift`,
keine Systemuhr, keine Produktdaten-Manipulation).

**Ergebnis der Einzelfallprüfung:**

* **6 von 8 Fällen (F01, F02, F03, F06, F07, F08) sind jetzt "bestanden"**
  auf Daten-/Integrationsebene — großteils bereits durch vorhandene Tests
  aus früheren Paketen exakt abgedeckt (`FourWeekReviewAssemblerTests`,
  `FourWeekReviewOrchestratorTests`, `FourWeekReviewDueStatusTests`,
  `PlanParticipationEvaluatorTests`), ergänzt um zwei neue, gezielte
  Testdateien dieser Runde (`AbsenceDeloadReopenTests.swift`,
  `ProgressionApplicatorDeloadConflictTests.swift`). In jedem dieser 6
  Fälle bleibt ausschließlich der reine UI-/Geräte-Nachweis (der
  tatsächlich gerenderte Screen, ein echter Button-Tap) offen — dafür gilt
  weiterhin der bekannte Export-Hang-Blocker, aber nur für diesen
  Teilaspekt, nicht für den ganzen Fall.
* **1 Fall (F05) ist "teilweise"**: die Beschwerden-Hälfte ist
  automatisiert bewiesen (Befund sichtbar, UI-Text rein beobachtend, keine
  Diagnose). Die RIR-Hälfte ist nicht durch einen positiven Test, sondern
  durch Code-Audit bestätigt — RIR fließt in keine der review-relevanten
  Eingabetypen (`PlanParticipationEvaluator.Input`,
  `FourWeekReviewOrchestrator.CheckInFeedback`) überhaupt ein, kann also
  strukturell keine erfundene Erholungsaussage erzeugen.
* **1 Fall (F04) bleibt "noch nicht geprüft"** — echte Implementierungslücke,
  kein Testlücken-Befund: es gibt keine Review-Logik, die ausgelassene
  Beintage oder einen bewussten Brustschwerpunkt überhaupt erkennt oder
  dazu eine Rückfrage stellt (Dok. 03 §6). Neuer fachlicher Widerspruch
  Nr. 4 unten.
* **Echter Bug gefunden und gefixt (F08):** `ProgressionApplicator.apply`/
  `.evaluateOnly` erhöhten `Exercise.suggestedWeight` auch dann, wenn
  `DeloadManager` für genau diese Übung gerade eine reduzierte
  Deload-Last eingefroren hatte (`deloadOriginalWeight != nil`) — ein
  direkter Verstoß gegen Dok. 03 §5 ("nicht dieselbe Übung gleichzeitig
  steigern und reduzieren") und eine stille Datenverlust-Falle (ein
  späteres `endDeload()` hätte den in der Deload-Woche erarbeiteten
  Fortschritt wieder verworfen). Fix: `.increaseWeight` wird zu `.hold`
  vetoed, solange ein Deload-Snapshot offen ist; Deload selbst bleibt
  weiterhin erlaubt (Sicherheitsnetz). Commit `c96bf5c`. CI
  (`apple-ci-comparison.yml`, Run `39393513593`, macOS-Runner, echte
  Swift-/SwiftData-Testausführung + App+Widget-Build für den
  iOS-Simulator): **erfolgreich**, alle 1454 Package-Tests bestanden,
  inklusive der 5 neuen Tests dieser Runde
  (`AbsenceDeloadReopenTests.*`, `ProgressionApplicatorDeloadConflictTests.*`).

**Kein Export-Hang/Zeit-Manipulationsweg wurde für diese Runde benötigt** —
alle neuen/verwendeten Tests laufen vollständig über konstruierte
Testdaten, nie über eine simulierte Geräte-Uhr oder einen CSV-Re-Import.

## Runde 3 (dieser Durchgang): Onboarding/Hybrid/Coach, Navigation, Drag&Drop, RIR, Bildschirmgröße (Nachtrag)

**Auftrag:** Block 1 (Onboarding-/Hybrid-/Coach-Zustände: A01, A03, A04,
A06, A07, A08, A10), Block 2 (Zurücknavigation/Entwurfsschutz: E05, E06,
E07), Block 3 (Speichern/Abbrechen: B01, C01, C02), danach RIR-Werte (E03)
und kleine Bildschirmbreite/große Schrift/Light-Dark/Locale (E04), in
dieser Reihenfolge, auf dem TestingBot-iPhone-15/iOS-18.0-Simulator.

**Sessions (alle aktiv beendet, `max_concurrent=1` eingehalten):**

| # | Zweck | Build/Commit | Dauer | TestingBot-Session-ID |
|---|---|---|---|---|
| 1 | Block 1 (Onboarding A01/A03/A04/A06/A07/A08/A10), B01 (Drag&Drop + Move-to), A10 | `fc2ad39` | 1095 s | `b9450af4a27b-6e2efa9abd4c-3d496f1ae049-179248493958-95771201` |
| 2 | Block 2 (E05/E06/E07), E03 (RIR), E04-Repro (Dynamic Type, Dark Mode, Locale-Versuch) | `fc2ad39` (vor E04/E05-Fix) | 1250 s | `afda04093bca-2dafa6936f35-31d3752e4283-179248617830-89527586` |
| 3 | Geräte-Nachtest E05-Fix (widerlegt) + E04-Fix (bestätigt) | `64ba455` | 450 s | `df816cc3825c-4f380bbe18e0-071e7bffecb4-179248760926-21784839` |
| 4 | C01/C02 (Cardio-Zieländerung), Measurement-Doppel-Tap-Repro | `64ba455` | 209 s | `1ea03ac69db2-919c3f52343c-bf323ef4b421-179248854000-67966365` |

Gesamt: **3.004 Sekunden** von 34.515 Sekunden Restbudget vor dieser
Runde → **ca. 31.511 Sekunden Restbudget danach** (TestingBot-Konto-API
zeigte kurz nach Sitzungsende noch 31.730 Sekunden, vermutlich
Abrechnungs-/Rundungsverzug von wenigen Sekunden je Session; die Summe
der einzelnen Session-Dauern gilt als genauerer Wert). Keine zusätzlichen
Käufe.

**CI-Läufe (`apple-ci-comparison.yml`, GitHub Actions, macOS-Runner):**
Run `39392642582` (`fc2ad39`, Ausgangsbasis) ✓, Run `39396027125`
(`3e67cb8`, ursprünglicher E05-Versuch) ✓, Run `39397907485` (`64ba455`,
E04-Fix + E05-Versuch) ✓, Run `39399872168` (`254d669`,
E05-Korrektur/Rücknahme) ✓ — alle erfolgreich, Build+Tests für Swift
Package und iOS-App/Widget.

### Echter Bug gefunden und gefixt: E04 (Gewichtsfeld schneidet bei großer Textgröße ab)

Bei aktivierter „Larger Accessibility Sizes" (größte Dynamic-Type-Stufe,
über iOS-Einstellungen → Eingabehilfen gesetzt) schnitt das KG-Eingabefeld
im Satz-Logging (`SetRow.weightInput`) ein eingegebenes Dezimalgewicht wie
„72,5" zu „7..." ab — das Feld hatte eine feste Breite ohne
Skalierungserlaubnis. Fix: `.minimumScaleFactor(0.5)` + `.lineLimit(1)`
(Commit `64ba455`), neuer Regressionstest
`SetRowWeightFieldScalesDownInsteadOfTruncatingTests` (liest `SetRow.swift`
direkt von der Platte, kein SwiftUI/SwiftData nötig). Geräte-Nachtest nach
dem Fix auf frischem CI-Build bestätigt: „72,5" bei identischer
Textgröße jetzt vollständig sichtbar.

### Fehldiagnose gefunden, korrigiert: E05 (vermeintlicher Swipe-Back-Fix im Übungs-Editor war wirkungslos)

Erster Versuch (Commit `3e67cb8`): `.deltiqSwipeBackEnabled(!isDirty)` zu
`ExerciseEditorView` ergänzt, nach dem Muster von `PlanEditorView`/
`DayEditorView`, da dort dieselbe `.navigationBarBackButtonHidden(true)`-
Nebenwirkung beobachtet schien. **Geräte-Nachtest DES EIGENEN Fixes** auf
dem fertig gebauten CI-Artefakt zeigte: die horizontale Zurück-Wisch-Geste
blieb am Übungs-Editor vor UND nach dem Fix identisch wirkungslos (mehrfach
reproduziert; als Kontrolle am Plan-/Tag-Editor im selben Durchlauf sofort
funktionsfähig). Root Cause: `DayEditorView` öffnet `ExerciseEditorView`
über `.sheet(item:) { NavigationStack { ExerciseEditorView(...) } }` — eine
eigene, frische `NavigationStack` mit nur sich selbst als Root, anders als
die per `NavigationLink` im gemeinsamen Stack gepushten Plan-/Tag-Editoren.
`SwipeBackHostController.gestureRecognizerShouldBegin` liefert dort
strukturell immer `false`. Der ergänzte Aufruf war daher toter Code, keine
Reparatur. Zusätzlich auf dem Gerät bestätigt: die für eine
Sheet-Präsentation tatsächlich zuständige Geste — Herunterwischen zum
Schließen — funktionierte bereits vor diesem ganzen Vorgang korrekt
(`.interactiveDismissDisabled(isDirty)`, unverändert). Fix zurückgenommen,
Regressionstest entfernt (Commit `254d669`). Kein Produktfehler an dieser
Stelle; E05 gilt für den Übungs-Editor über die Herunterwisch-Geste als
erfüllt.

Dieser Vorgang ist hier bewusst vollständig dokumentiert statt
stillschweigend korrigiert: er zeigt, warum ein Fix erst nach einem
erneuten Geräte-Nachtest als bestätigt gelten darf, nicht schon nach einem
plausiblen Code-Vergleich.

### Block 1 (Onboarding/Hybrid/Coach) — Kurzfassung

A03 und A06 **bestanden** (Kraft+Laufen im Vorschlag UND im persistierten
Plan bei Coach aus; „Both"-Auswahl übersteht die Coach-Entscheidung
sichtbar). A08 **bestanden** (Ausdauerform-Wechsel hin und zurück erzeugt
keinen veralteten/inkonsistenten Zustand, setzt beim Zurückwechseln aber
auf den Default statt die letzte Wahl zu merken). A04, A07, A10
bleiben **teilweise** mit jetzt konkreterem Gerätebefund (siehe Tabelle
oben) — u. a. bestätigt A04 erneut die A09-Lücke (keine Laufziel-Fragen,
unabhängig vom Coach-Zustand), und A10 stellt klar, dass der Haken im
„Build Plan"-Pfad das GESAMTE Onboarding abschließt statt nur den Entwurf
zu aktualisieren (abweichend von der engsten Lesart aus Dok. 02 §6, aber
ohne beobachteten Datenfehler). A01 bleibt **teilweise**: die eigentliche
Kernfrage (bestehendes Profil aus einem früheren Durchlauf, erneuter
Eintritt ins Onboarding) ließ sich in dieser Runde nicht auslösen; nur ein
Teilaspekt (Vorbefüllung beim Wechsel Onboarding→„Build Plan") wurde
beobachtet.

### Block 2 (Navigation/Entwurfsschutz) — Kurzfassung

E05, E06, E07 alle **bestanden** (siehe Tabelle oben und E05-Nachtrag für
die Fehldiagnose-Korrektur).

### Block 3 (Speichern/Drag&Drop/Cardio-Vorschau) — Kurzfassung

B01 **bestanden** (sowohl echte Drag-Geste als auch „Move to…"-Menü
funktionieren und ergeben die korrekte Reihenfolge). C01/C02 bleiben
**teilweise**: der getestete aktive Plan enthielt keine Lauf-/Cardio-Inhalte,
weshalb nach einer Cardio-Zieländerung erwartungsgemäß keine
Vorschlagskarte erschien — der eigentliche Auslösefall (aktiver Plan MIT
Laufeinheiten) wurde aus Zeitgründen nicht nachgestellt.

### E03 (RIR-Werte) — bestanden

Alle 11 gültigen Werte (0 bis 5 in 0,5-Schritten) vollständig sichtbar,
korrekt formatiert und nach dem Loggen weiterhin korrekt angezeigt.

### E04 (kleine Bildschirmbreite, große Schrift, Light/Dark, Locale) — teilweise, siehe Fix oben

Dezimalgewicht/kg-Format und Dark Mode gerätebestätigt; der konkrete
Abschneide-Bug gefunden und gefixt. Deutsch/Türkisch der APP SELBST
blieben ungeprüft: die iPhone-Systemsprache ließ sich zwar erfolgreich auf
Deutsch umstellen, aber die WebDriverAgent-Automatisierung überlebte den
dadurch ausgelösten SpringBoard-Respring nicht — **bekannte
Nachweislücke, Auswirkung noch nicht abschließend geprüft**, kein
Hinweis auf einen Produktfehler. Türkisch wurde daraufhin nicht mehr
versucht. Ein echtes kleineres Gerät (statt nur Dynamic-Type-Vergrößerung
auf dem iPhone 15) wurde nicht zusätzlich getestet.

### Measurement-Textfeld „zweiter Tap zum Fokussieren" — in dieser Runde NICHT reproduziert

Gezielt im Measurement-Kontext (New-Measurement-Screen, Gewichtsfeld)
geprüft: ein einzelner Tap auf das leere Gewichtsfeld öffnete die Tastatur
und setzte den Cursor sofort (kein zweiter Tap nötig). Der in der letzten
Runde notierte Fund ließ sich unter diesem konkreten Testablauf nicht
reproduzieren — keine Schlussfolgerung über die Ursache möglich, da kein
Fehlverhalten auftrat. Kein Fix vorgenommen (nichts zu fixen ohne
Reproduktion); falls der Fund erneut auftritt, bitte mit genauerem
Reproduktionsschritt (welches Feld, welcher Screen, welche Vorbedingung)
erneut melden.

## Nächste Schritte

Top-5-Geräteprüfung (E01, C06, D06, A11, D02) sowie Runde 3 (Onboarding/
Hybrid/Coach, Navigation, Drag&Drop, RIR, Bildschirmgröße) abgeschlossen —
siehe jeweilige Nachträge oben für Details. Offene bekannte
Nachweislücken, in absteigender Priorität für eine künftige Runde:

1. **A01** (P2, teilweise): die eigentliche Kernfrage — bestehendes Profil
   aus einem früheren, abgebrochenen/abgeschlossenen Durchlauf, erneuter
   Eintritt ins Onboarding — konnte in keiner bisherigen Runde auf dem
   Gerät nachgestellt werden (kein gefundener regulärer Weg, das
   Onboarding mit bestehendem Profil erneut zu starten).
2. **C01/C02** (P2, teilweise): der eigentliche Auslösefall der
   gebündelten Cardio-Vorschlagskarte (aktiver Plan MIT Laufeinheiten +
   Cardio-Zieländerung) wurde noch nicht nachgestellt; nur der
   Negativfall (Plan ohne Cardio-Inhalt → keine Karte) ist beobachtet.
3. **E04-Rest** (teilweise): Deltiq selbst in Deutsch (Automatisierung
   überlebte den Systemsprachwechsel in dieser Runde nicht) und in
   Türkisch (nicht versucht) bleiben ungeprüft; ein echtes kleineres
   Gerät wurde nicht zusätzlich zur Dynamic-Type-Vergrößerung getestet.
4. **D06**s Einzelschritt "Migrationsdialog bewusst ablehnen" ließ sich
   nach wie vor nicht isoliert reproduzieren; Auswirkung noch nicht
   abschließend geprüft.
5. F01–F08: nur noch der reine UI-/Geräte-Teil von F01–F03/F06–F08 sowie
   F05s Beschwerden-Abklärungsweg offen — kein genereller Blocker mehr.
6. Verbleibende P2-Fälle ohne Gerätenachweis: A02, C05, E02, E08.

Die fünf benannten fachlichen Widersprüche (A09, C04, A02-Architekturfrage,
F04, sowie A04s Abhängigkeit von A09) gehen weiterhin als offene
Entscheidungen an den Nutzer zurück, nicht eigenmächtig auflösen.
