# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-20 (zweiter Durchgang), Branch `claude/smart-onboarding-epic`,
HEAD `89c788a` (Fix-Commit E01; davor `b8b8f6e`). TestingBot-Restbudget vor
diesem Durchgang: 36.754 Sekunden (~10,2 h). Kein Merge nach `main`, kein
Release.

**Gesamtstatus: A–E bearbeitet; teilweise bestanden, teilweise blockiert.
Gesamtabnahme weiterhin offen.**

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
| A01 | Ziel/Tage/Equipment bereits beantwortet → keine erneute identische Befragung | P2 | `OnboardingView.swift` (`weeklyGoal` dient zugleich als `PlanMatchmaker`-`preferredDays`; `trainingHistoryAnswer`/`ExperienceTrackResolver` statt zweiter Erfahrungsfrage) | `PlanMatchmakerTests.swift`, `ExperienceTrackTests.swift`, `ExperienceTrackBackfillTests.swift` (verwandt: Logikebene, kein Navigationstest der UI selbst) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test/Gerätebeleg, dass die Onboarding-UI Equipment/Ziel/Tage tatsächlich nicht zweimal abfragt. |
| A02 | Gemeinsamer Builder und Onboarding, gleiche Eingaben → gleiche fachliche Planung | P2 | `PlanGenerator` (gemeinsam genutzt), `PlanDraftResultAdapter`; ABER `OnboardingView.enduranceModalityStep` ist laut eigenem Kommentar ein „Duplikat von `PlanBuilderView.enduranceModalitySubflow`" | `PlanDraftResultAdapterTests.swift` (verwandt: Adapter-Korrektheit, kein Vergleichstest Onboarding- vs. Builder-Pfad) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test vergleicht beide Pfade bei identischer Eingabe; dokumentiertes UI-Duplikat steht in Spannung zu „keine kopierte zweite Oberfläche" (siehe Widersprüche unten). |
| A03 | Hybrid + Laufen ohne Coach → Kraft/Laufen im Vorschlag, Coach aus | P2 | `OnboardingView.enduranceModalityStep`, `UserBodyProfile.setEnduranceModality` | `PlanningContextTests.testRunCoachDisabledIsAlwaysValidRegardlessOfModality` (verwandt: Validität, nicht Plan-Inhalt) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test/Gerät bestätigt, dass der generierte Plan tatsächlich Kraft **und** Laufen enthält, wenn Coach aus ist. |
| A04 | Hybrid + Laufen mit Coach → Coachentscheidung und unterstütztes Ziel übernommen | P2 | wie A03, plus `runCoachWanted`-Pfad in `finishOnboarding()` | `PlanningContextTests.testRunCoachEnabledWithRunningIsValid` (verwandt) | kein Geräte-Nachweis vorhanden | teilweise | Siehe A09: Zielangaben (Distanz/Zeit/Wettkampf) werden im Onboarding gar nicht erhoben. |
| A05 | Hybrid + Radfahren → keine unnötige Laufcoach-Frage | P2 | `OnboardingView.swift` (`enduranceModality.supportsRunCoach` blendet die Frage aus) | `PlanningContextTests.testRunCoachEnabledWithCyclingOnlyIsInvalid`, `testSupportsRunCoachMatchesPlanningContextInvariant` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logik-/UI-Gating geprüft; kein Geräte-Screenshot-Beleg der tatsächlich ausgeblendeten Frage. |
| A06 | Laufen/Radfahren kombiniert → Auswahl bleibt nach Coachingentscheidung bestehen | P2 | `EnduranceModality.both` (`PlanningContext.swift`) | `PlanningContextTests.testRunCoachEnabledWithBothIsValid`, `testEnduranceModalityMapsOntoExistingTrainingTypeKinds` (verwandt) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test prüft explizit, dass die Radfahren-Komponente im `.both`-Fall nach der Coach-Entscheidung erhalten bleibt. |
| A07 | Coach an → aus → gewollte Laufeinheiten bleiben, keine aktiven Coachempfehlungen | P2 | `UserBodyProfile.setEnduranceModality`/`cardioCoachingEnabled` | `UserBodyProfileTests.testChangingModalityToCyclingClearsPreviouslyEnabledCoach` (verwandt: Modality-Wechsel, nicht reines Coach-Toggle) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test/Gerät bestätigt, dass bereits geplante Laufeinheiten nach Abschalten bestehen bleiben. |
| A08 | Ausdauerform wechseln und zurückgehen → kein veralteter Status/Planinhalt | P2 | `OnboardingView.goToNextStep`/`goToPreviousStep`, `enduranceModality`-State | `UserBodyProfileTests` (Modality-Wechsel, verwandt) | kein Geräte-Nachweis vorhanden | teilweise | Kein Navigationstest für Vor-/Zurück mit Ausdauerform-Wechsel. |
| A09 | Unbekannte Referenzleistung → keine erfundenen Werte/stille Nullannahme | P2 | **keine erkennbare Implementierung gefunden** im Onboarding | kein Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | **Fachlicher Konflikt** (siehe unten): Dok. 02 §4 verlangt diese Fragen im Onboarding bei aktiviertem Coach; der Code stellt sie dort nicht. |
| A10 | Eingebetteten Wocheneditor bestätigen → nur Onboarding-Entwurf geändert | P1 | `OnboardingView.finishOnboarding()` (kein früher Plan-Insert aus der Vorschau) | kein direkter Test; `PlanCreationOperationTests.swift`/`PlanDraftResultAdapterTests.swift` decken die angrenzende Logik ab (verwandt) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test simuliert direkt "Haken im eingebetteten Editor während Onboarding". |
| A11 | Onboarding abbrechen/mehrfach abschließen → keine verwaisten/doppelten Pläne | P1 | `OnboardingView.finishOnboarding()` (`isFinishingOnboarding`-Guard), `OnboardingPlanCreationNotice` | `OnboardingPlanCreationNoticeTests.swift`, `OnboardingFinishPlanSelectionTests.swift` (verwandt: Notice-/Auswahl-Logik, nicht der Doppel-Tap-Guard selbst) | Build/Commit `b8b8f6e`, TestingBot-Session `f3e600cd…26223308`. a) Mehrfach-Tap: 6 schnell aufeinanderfolgende Taps auf "Finish" am letzten Onboarding-Schritt → Plans-Liste zeigt danach exakt "1 PLAN" (kein Dupe), Guard bestätigt wirksam. b) Abbruch: Onboarding bis zum letzten Schritt (vor "Finish") durchlaufen, App per `terminateApp` hart beendet und neu gestartet → sauberer Neustart bei Schritt 1 ("Welcome"), kein Absturz, kein sichtbar hängender Zustand. Onboarding danach regulär bis "Finish" wiederholt und abgeschlossen → ebenfalls exakt "1 PLAN" (kein verwaister Datensatz aus dem abgebrochenen Versuch). | bestanden | Kein Negativbeweis, dass tatsächlich ein `UserBodyProfile`-Datensatz aus dem abgebrochenen Versuch im Store verblieb (nur indirekt über "1 PLAN" nach Abschluss geschlossen, kein direkter Store-/Export-Dump geprüft). |
| B01 | Wocheneditor Drag & Drop → Reihenfolge korrekt, alternative Bedienung möglich | P2 | `PlanBuilderView.resultStepView`/`moveDraftDays`, `PlanDraft.moveDay` | `PlanDraftTests.testMoveDayReordersAndPreservesStableID` u.a. (exakte Logikabdeckung) | kein Geräte-Nachweis vorhanden | teilweise | Logik vollständig getestet; Dok. 04 verlangt für die echte Geste ausdrücklich Geräteprüfung — fehlt. |
| B02 | Inhalt fixiert, Woche neu verteilen → Inhalt bleibt, Position regelkonform behandelbar | P2 | `PlanDraft.setContentFixed`/`redistribute` | `PlanDraftTests.testRedistributeLeavesContentFixedDayCompletelyUntouchedButFillsOthersFromThePool`, `testContentFixationDoesNotPreventReordering` | kein Geräte-Nachweis vorhanden | bestanden | Reine Logikprüfung ausreichend und exakt passend; kein Geräte-Nachweis der UI-Darstellung. |
| B03 | Position fixiert, Übungen variieren → Position bleibt, erlaubter Inhalt veränderbar | P2 | `PlanDraft.setPositionFixed`/`replaceContent` | `PlanDraftTests.testPositionFixationDoesNotPreventContentReplacement`, `testRedistributeAllowsNewContentOnAPositionFixedButNotContentFixedDay` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene; keine UI-Geräteprüfung. |
| B04 | Manuelle Änderungen + Neuberechnung → keine stillen Verluste | **P1** | `PlanGeneratorInstantiator.recalculate` (Fingerprint-Vergleich, überspringt manuell geänderte/historienbehaftete Tage) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithEditedExerciseSets`, `testRecalculateSkipsDayWithActiveSessionAndReportsIt`, `testRecalculateSkipsDayWithCompletedSessionTooAndLogStaysFullyIntact` | kein Geräte-Nachweis vorhanden | bestanden | Datenintegrationsebene vollständig bewiesen; kein Geräte-Nachweis für den UI-Auslöser ("Neu rechnen"). |
| B05 | Keine passende Lösung → sichtbarer Konflikt statt abgeschnittener Einheiten | P2 | `PlanBuilderView.presentAlternatives`, `PlanDraft.redistribute` (schlägt sauber fehl statt zu kürzen) | `PlanGeneratorTargetedAlternativesTests.testCardioDayHasNoAlternatives`, `testDayNotMatchingAnySelectionHasNoAlternatives`; `PlanDraftTests.testRedistributeFailsAndLeavesDraftUnchangedWhenAllDaysAreContentFixed` | kein Geräte-Nachweis vorhanden | bestanden | Kernzusage bewiesen; der sichtbare Toast selbst ist nicht geräteverifiziert. |
| B06 | Mehrfach auf Haken tippen/Fehler beim Speichern → keine Duplikate, Entwurf bei Fehler erhalten | **P1** | `PlanBuilderView` (`isAdopting`-Doppel-Tap-Guard), `PlanCreationOperation` | `PlanCreationOperationTests.testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan`, `testGenuineSaveFailureIsRetryableAndDoesNotMarkAnythingAsCommitted`, `testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce` | kein Geräte-Nachweis vorhanden | bestanden | Datenebene vollständig bewiesen; kein Geräte-Nachweis des realen Mehrfach-Tap-UI-Pfads. |
| C01 | Cardio-/Laufziel speichern → gebündelte Vorschau, kein stilles Bulk-Update | P2 | `CardioFeasibilityCardModel.make/accept/dismiss/acceptCustom` | `CardioFeasibilityCalculatorTests.swift` (verwandt: Berechnung, nicht Accept/Dismiss-Logik selbst) | kein Geräte-Nachweis vorhanden | teilweise | Keine dedizierten Tests für `accept`/`dismiss`/`acceptCustom` der Karte selbst. |
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
| E03 | Alle gültigen RIR-Ganz-/Halbwerte → vollständig sichtbar und korrekt gespeichert | P2 | `SetRow.swift` (strukturelle RIR-Spalte, Zwei-Zeilen-Fallback laut Code-Kommentaren) | kein Test gefunden (kein RIR-Testfile) | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Weder automatisierter noch Geräte-Nachweis für die Trunkierungs-Korrektur trotz des referenzierten Screenshot-Problems. |
| E04 | Schmaler Bildschirm, große Schrift, Dezimalgewicht, kg/lbs → kein Abschneiden/Overflow | P2 | `SetRow.swift` (Layout-Fallback-Kommentare), keine Snapshot-/UI-Testinfrastruktur im Projekt | kein Test gefunden (keine visuellen Snapshot-/XCUITests vorhanden) | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Mit vorhandener Testinfrastruktur grundsätzlich nicht automatisierbar; reiner Geräte-/Simulator-Test nötig, liegt nicht vor. |
| E05 | Mehrstufig zurückwischen → wiederholt eine Ebene zurück, keine dauerhafte Sperre | P2 | `Theme.swift` (`deltiqSwipeBackEnabled`, pro View über `!isDirty` gesteuert) | kein dedizierter Test gefunden | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Kein Nachweis, dass die Geste über mehrere verschachtelte Editoren hinweg nicht dauerhaft blockiert bleibt. |
| E06 | Ungespeicherter Entwurf + Schließgeste → kein Umgehen des Schutzes | **P1** | Konsistentes Muster: `.interactiveDismissDisabled(isDirty)` + `.deltiqSwipeBackEnabled(!isDirty)` über alle Editoren — **blockierend**, nicht "Dialog beim Wischversuch" | `EditorDiscardSnapshotTests.swift` deckt die `isDirty`-Erkennung breit ab (verwandt); kein Test der tatsächlichen Gesten-Blockade selbst | kein Geräte-Nachweis vorhanden | teilweise | Die `isDirty`-Logik ist bewiesen; dass die Wisch-/Sheet-Dismiss-Geste dadurch auf dem Gerät wirkungslos bleibt, ist nicht verifiziert. |
| E07 | Trainingsseiten wechseln und Listen ziehen → bestehende Gesten erhalten | P2 | `.onMove` in `PlanEditorView`, `DayEditorView`, `DashboardSettingsView` | keine dedizierte Regressionsprüfung für "nach Seitenwechsel" gefunden | kein Geräte-Nachweis vorhanden | teilweise | Kein Test/Gerätebeleg speziell für Tab-/Seitenwechsel + danach weiterhin funktionierendes Drag. |
| E08 | Start-Check-Einstiege suchen → nur im Onboarding erreichbar | P2 | `BaselineCheckFlowView` — Codesuche bestätigt genau einen produktiven Aufrufer (`OnboardingView.swift`) | kein Test gefunden, der diese Invariante als Regression schützt | kein Geräte-Nachweis vorhanden | noch nicht geprüft | Codesuche ist kein automatisierter Regressionsschutz gegen einen künftigen zweiten Call-Site, kein Gerätenachweis. |
| F01 | Vier Wochen mit viel/wenig Teilnahme → datenabhängige Empfehlung | **P3** | `FourWeekReviewOrchestrator`, `FourWeekReviewAssembler`, `FourWeekReviewDueCalculator` | `FourWeekReviewOrchestratorTests.swift`, `FourWeekReviewAssemblerTests.swift` (Logikebene, nicht vertieft geprüft) | kein Geräte-Nachweis vorhanden | blockiert | Zeitabhängig, bekannter Export-Hang + fehlender Zeit-Manipulationsweg (siehe Block D/E oben). Nicht erneut untersucht. |
| F02 | Flexibler Plan/Pause/Planwechsel → keine erfundene Compliance | **P3** | `FourWeekReviewAssembler`/`BlockReviewRecord` | `BlockReviewRecordTests.swift`, `FourWeekReviewDueStatusTests.swift` (Logikebene) | kein Geräte-Nachweis vorhanden | blockiert | Siehe F01. |
| F03 | Gute Entwicklung → „Beibehalten" als gültiges Ergebnis | **P3** | `FourWeekReviewOrchestrator` | `FourWeekReviewOrchestratorTests.swift` (Logikebene) | kein Geräte-Nachweis vorhanden | blockiert | Siehe F01. |
| F04 | Ausgelassene Beintage/Brustschwerpunkt → Rückfrage statt Zwangswechsel | **P3** | nicht vertieft lokalisiert (Auftrag: F-Fälle nicht erneut untersuchen) | nicht geprüft | kein Geräte-Nachweis vorhanden | blockiert | Siehe F01. |
| F05 | Beschwerden/fehlende RIR-Daten → keine Diagnose/erfundene Erholung | **P3** | nicht vertieft lokalisiert | nicht geprüft | kein Geräte-Nachweis vorhanden | blockiert | Siehe F04. |
| F06 | Review ablehnen/aufschieben/wieder öffnen → keine Doppeländerung | **P3** | `FourWeekReviewView`/`FourWeekReviewEntryView` (vermutlich, nicht vertieft) | nicht geprüft | kein Geräte-Nachweis vorhanden | blockiert | Siehe F04. |
| F07 | Review übernehmen → neue gültige Fassung, Historie unverändert | **P3** | `FourWeekReviewAssembler`/`BlockReviewRecord` (vermutlich, nicht vertieft) | nicht geprüft | kein Geräte-Nachweis vorhanden | blockiert | Siehe F04. |
| F08 | Gleichzeitige Progressions-/Deload-/Review-Hinweise → keine Widersprüche | **P3** | `ProgressionEvaluator`, `DeloadAdvisor`, `FourWeekReviewOrchestrator` (vermutlich, nicht vertieft) | `ProgressionEvaluatorTests.swift`, `DeloadAdvisorTests.swift` (isoliert, kein Zusammenspiel-Test) | kein Geräte-Nachweis vorhanden | blockiert | Siehe F04; zusätzlich kein Test für gleichzeitiges Auftreten mehrerer Hinweis-Systeme. |

**Status-Verteilung (45 Fälle, nach diesem Durchgang):** 14 bestanden (A05,
A11, B02, B03, B04, B05, B06, C03, D01, D02, D03, D04, D05, E01) · 17
teilweise (A01, A02, A03, A04, A06, A07, A08, A10, B01, C01, C02, C05, C06,
D06, E02, E06, E07) · 6 noch nicht geprüft (A09, C04, E03, E04, E05, E08) · 8
blockiert (F01–F08) · 0 fehlgeschlagen.

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

## Nächste Schritte

Top-5-Geräteprüfung (E01, C06, D06, A11, D02) in dieser Runde abgeschlossen
(4× bestanden, 1× teilweise — siehe oben). Offene bekannte Nachweislücke:
D06s Einzelschritt "Migrationsdialog bewusst ablehnen" ließ sich in dieser
Runde nicht isoliert reproduzieren; Auswirkung noch nicht abschließend
geprüft. Als Nächstes: die übrigen P2-Fälle, danach F01–F08 (bleiben am
bekannten Export-Hang/Zeit-Manipulations-Blocker, bis dieser gelöst oder
ein anderer sanktionierter Weg gefunden ist). Die drei benannten fachlichen
Widersprüche (A09, C04, A02) gehen als offene Entscheidungen an den
Nutzer zurück, nicht eigenmächtig auflösen.
