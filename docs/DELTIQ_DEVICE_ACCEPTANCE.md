# Deltiq – TestingBot-Geräteabnahme (konsolidierter Stand)

Stand: 2026-10-20, Branch `claude/smart-onboarding-epic`, HEAD `f6d4c81`.
TestingBot-Restbudget zu diesem Zeitpunkt: ca. 36.048 Sekunden (~10 h) von
ursprünglich zugesagten ~15–16,7 h. Kein Merge nach `main`, kein Release.

**Gesamtstatus: A–E bearbeitet; teilweise bestanden, teilweise blockiert.
Gesamtabnahme weiterhin offen.**

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
| A11 | Onboarding abbrechen/mehrfach abschließen → keine verwaisten/doppelten Pläne | P1 | `OnboardingView.finishOnboarding()` (`isFinishingOnboarding`-Guard), `OnboardingPlanCreationNotice` | `OnboardingPlanCreationNoticeTests.swift`, `OnboardingFinishPlanSelectionTests.swift` (verwandt: Notice-/Auswahl-Logik, nicht der Doppel-Tap-Guard selbst) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test ruft `finishOnboarding()` zweimal auf und prüft "kein zweiter Plan"; kein Abbruch-Test. |
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
| C06 | Laufende Session + Planänderung → Sessionstruktur/Logs bleiben konsistent | **P1** | `PlanGeneratorInstantiator.recalculate` (überspringt Tage mit `WorkoutSession`-Historie) | `PlanGeneratorInstantiatorTests.testRecalculateSkipsDayWithActiveSessionAndReportsIt` (exakt für Recalculate); direkte `DayEditorView`-Übungsänderung während laufender Session NICHT separat abgedeckt | kein Geräte-Nachweis vorhanden (der dokumentierte Fund betrifft das **Löschen** des aktiven Plans, siehe Punkt 1b oben, nicht normale Planänderungen) | teilweise | Der Recalculate-Pfad ist bewiesen; direkte Übungsänderungen an einem Tag mit laufender Session haben keinen nachgewiesenen Schutz-/Verschiebungsmechanismus. |
| D01 | Reines Reorder + Verwerfen → Originalreihenfolge wiederhergestellt | **P1** | `PlanEditorView.revertDayOrder`/`dayOrderIsDirty`, `DayEditorView.revertExerciseOrder`/`exerciseOrderIsDirty` | `EditorDiscardSnapshotTests.testPlanEditorViewDetectsAndRevertsDayReorder`, `testDayEditorViewDetectsAndRevertsExerciseReorder` | kein Geräte-Nachweis vorhanden | bestanden | Nur die Datenlogik ist exakt bewiesen; die physische Drag-Geste selbst ist unter B01 vermerkt. |
| D02 | Add/Delete + Reorder + Verwerfen → definiertes Verhalten, keine Sortierkollision | **P1** | Hinzufügen/Löschen sind bewusst sofort wirksame, nicht per Discard rückrollbare Aktionen | `EditorDiscardSnapshotTests.testPlanEditorViewIgnoresNewlyAddedDayInReorderRevert`, `testDayEditorViewIgnoresNewlyAddedExerciseInReorderRevert` (verwandt: deckt nur "neu hinzugefügt" ab, nicht die volle Kombination) | kein Geräte-Nachweis vorhanden | teilweise | Kein Test kombiniert Löschen **und** Reorder **und** Verwerfen gleichzeitig bzw. prüft explizit Index-/Wochentag-Kollisionen. |
| D03 | Name/Ton ändern, separate Aktion bestätigen → unabhängiger Edit bleibt verwerfbar | **P1** | `PlanEditorView.rebaselineTargetEnvironment()`, `ProfileEditorView.rebaselineCardioGoal()` | `EditorDiscardSnapshotTests.testPlanMetaSnapshotTargetedRebaselineLeavesOtherFieldsDirty`, `testProfileEditorViewRebaselineCardioGoalLeavesCoachingToneDiscardable` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen, kein Geräte-Nachweis der UI-Sequenz. |
| D04 | A aktiv → B an → B aus → Verwerfen → Ausgangsaktivierung wiederhergestellt | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardSurvivesOnOffToggleSequence`, `testOtherActivePlanStateIsDirtyDetectsOnOffToggleSequence` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D05 | Inaktiver Plan ohne anderen aktiven Plan → unverändert nicht dirty | **P1** | `PlanEditorView.planToReactivateOnDiscard`/`otherActivePlanStateIsDirty` (nil-Fall) | `EditorDiscardSnapshotTests.testPlanToReactivateOnDiscardReturnsNilWhenNoOtherPlanWasActiveAtOpen`, `testOtherActivePlanStateIsDirtyIsFalseWhenNoOtherPlanWasActiveAtOpen` | kein Geräte-Nachweis vorhanden | bestanden | Nur Logikebene bewiesen. |
| D06 | Rückrollen von Trainingsort → keine erneut ausgelöste Migration beim Schließen | **P1** | `PlanEditorView.revertToSnapshot()`/`isApplyingSnapshot`-Flag | `EditorDiscardSnapshotTests.testPlanMetaSnapshotRevertsEnvironmentAndActiveFlagTogether` (verwandt: prüft nur Datenmodell-Rollback, NICHT dass der Migrations-Dialog beim Schließen nicht erneut aufgeht — laut Code-Kommentar selbst nur live testbar) | kein Geräte-Nachweis vorhanden | teilweise | Die Kernzusage ("kein erneuter Migrations-Dialog") ist weder automatisiert noch auf dem Gerät bewiesen — nur der Datenmodell-Rollback. |
| E01 | Körpermessung per Haken bearbeiten → bestehende Messung aktualisiert, kein Duplikat | **P1** | `MeasurementView.save(profile:)` (`editingMeasurement`-Zweig überschreibt das bestehende Objekt) | kein Test gefunden — der zuständige Testfile-Kommentar dokumentiert selbst, dass dieser Pfad "nur per echtem Geräte-/Simulator-Test verifizierbar" ist | kein Geräte-Nachweis vorhanden (im Gegensatz zu `deleteCurrentMeasurement`, das laut Commit `49a634d` geräteverifiziert ist — das betrifft Löschen, nicht dieses Update-Szenario) | noch nicht geprüft | Exakt das geforderte Szenario ("Bestehende Messung aktualisiert, keine Dopplung") hat laut eigenem Code-Kommentar weder automatisierten noch Geräte-Nachweis. |
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

**Status-Verteilung (45 Fälle):** 11 bestanden (A05, B02, B03, B04, B05, B06,
C03, D01, D03, D04, D05) · 19 teilweise (A01, A02, A03, A04, A06, A07, A08,
A10, A11, B01, C01, C02, C05, C06, D02, D06, E02, E06, E07) · 7 noch nicht
geprüft (A09, C04, E01, E03, E04, E05, E08) · 8 blockiert (F01–F08) · 0
fehlgeschlagen.

**Top 5 als nächstes gerätezuprüfende Fälle** (nach Priorität):

1. **E01** – Messung-Update ohne Duplikat: einziger P1-Fall mit komplett
   fehlendem Nachweis (weder automatisiert noch Gerät); Risiko: stille
   Datenverdopplung in der Trend-Historie.
2. **C06** – Laufende Session + Planänderung: Recalculate-Pfad bewiesen,
   aber direkte `DayEditorView`-Bearbeitung während laufender Session ohne
   nachgewiesenen Schutz — höchstes Datenverlust-/Inkonsistenzrisiko.
3. **D06** – Trainingsort-Rückrollen: Kernzusage (kein erneuter
   Migrationsdialog) laut Code-Kommentar nur live testbar, bislang nicht
   geprüft.
4. **A11** – Onboarding-Abbruch/Mehrfachabschluss: Doppel-Tap-Guard
   vorhanden, aber nicht direkt getestet.
5. **D02** – Add/Delete + Reorder + Verwerfen: Teilabdeckung vorhanden,
   riskante Kombination (löschen **und** umsortieren **und** verwerfen)
   nicht als zusammenhängender Test/Gerätefall geprüft.

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

Gerätezuprüfung der oben priorisierten Top-5-Fälle (E01, C06, D06, A11,
D02), danach die übrigen P2-Fälle. F01–F08 bleiben am bekannten
Export-Hang/Zeit-Manipulations-Blocker, bis dieser gelöst oder ein
anderer sanktionierter Weg gefunden ist. Die drei benannten fachlichen
Widersprüche (A09, C04, A02) gehen als offene Entscheidungen an den
Nutzer zurück, nicht eigenmächtig auflösen.
