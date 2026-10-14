# Phase 5 — Konservative Ersatzübungs-Engine

Branch `claude/smart-onboarding-epic`, baut auf Phase 4
(`docs/PLAN_EQUIPMENT_MATCHING_AUDIT.md` Abschnitt 13) auf. Quelle: vom User
hochgeladene `PHASE_5_SUBSTITUTION_IMPLEMENTATION.md` (Implementierungs-
vorschlag, kein Referenz-Swift-Code mitgeliefert — die Core-Engine ist nach
der dort beschriebenen Architektur eigenständig implementiert).

## 1. Reviewed-Regel-Matrix (Schritt 1 der Vorgabe)

Die Vorgabe nennt 7 Kandidaten ausdrücklich als "candidates, NOT automatic
approvals". Geprüft gegen den echten, in Phase 4 annotierten Katalog —
**5 freigegeben, 2 abgelehnt**:

| # | Quelle → Ziel | Status | Gating | Begründung |
|---|---|---|---|---|
| R1 | Flachbank-Kurzhantel-Bankdrücken → "Kurzhantel-Floor-Press" | **Abgelehnt** | — | Ziel existiert nicht im Katalog (nur "Floor Press" [Langhantel] und "Kettlebell Floor Press" [Kettlebell], keine Kurzhantel-Variante). Vorgabe: "If target exercise or GIF does not exist, do not invent a mapping." |
| R2 | Kniebeuge → Goblet Squat (`.any([kettlebell, dumbbell])`) | **Freigegeben** | nur `repsMax >= 10` UND `goal != .strength` | Kniebeuge ist `isSystemCompound`. Ein Goblet Squat kann die Lastkapazität eines schweren Low-Rep-Backsquats nicht ersetzen — Gate schliesst Kraft-Anker-Kontexte explizit aus (Vorgabe: "Heavy low-rep barbell work must not become an alleged equivalent light kettlebell exercise"). |
| R3 | Bulgarische Kniebeuge (KH) → Ausfallschritte (KH) | **Freigegeben** | keines (ausser global) | Beide bereits Kurzhantel-Equipment-Klasse, kein Kraft-Anker. Entfernte erhöhte Fussposition reduziert Balance-/Dehn-Anforderung moderat — Vorschrift bleibt unveraendert, explizit als Grund kommuniziert. |
| R4 | Rudern vorgebeugt (Langhantel) → Chest Supported Row (KH) | **Freigegeben** | `goal != .strength` (isSystemCompound) | NUR die beidarmige, unterstuetzte Variante — NICHT "Rudern einarmig (KH)" (andere Satz-Semantik pro Seite, siehe Vorgabe "review unilateral set semantics"). Rumpfstabilisations-/unterer-Ruecken-Anforderung entfaellt, Vorschrift bleibt unveraendert. |
| R5 | Klimmzüge / Klimmzüge (weit) → Latzug (neutraler Griff) | **Freigegeben** | keines (siehe Limitation unten) | Ziel bestaetigt `.cableStation`-annotiert. Vorgabe verlangt zusaetzlich "goal is not specifically pull-up performance" — es existiert aktuell KEIN solcher `TrainingGoal`-Fall im Katalog; die Einschraenkung hat deshalb derzeit keine erzwingbare Wirkung (dokumentierte Limitation, keine erfundene Sperre). |
| R6 | Chest Supported Row (KH) → Kabelrudern sitzend | **Freigegeben** | `experienceTrack != .starter` | Sitzendes Kabelrudern verlangt MEHR Rumpfstabilisation als die unterstuetzte Variante — fuer Starter laut Vorgabe ("no harder replacement merely to satisfy equipment") ausgeschlossen. |
| R7 | Kettlebell Doppel-Push-Press → einarmige Variante | **Abgelehnt** | — | Vorgabe woertlich: "reject in MVP if bilateral-to-unilateral timing/set semantics are not implemented" — sind sie nicht. Keine Regel, keine Huelle, keine spaetere Attrappe. |

Globale Sperren (gelten VOR jeder Einzel-Regel, nie uebersteuerbar):
- Cardio-Uebungen (`isCardio == true`) werden nie substituiert.
- Nicht-`.workingSet`-Rollen (Warmup/Cooldown) werden nie substituiert.
- Jeder Tag mit `timeFormat != nil` (AMRAP/EMOM/Auf-Zeit/Circuit) wird komplett
  von der Substitution ausgenommen (Vorgabe Abschnitt 4: "reject all
  timed/circuit/AMRAP/EMOM substitutions to reduce risk").
- Nur Uebungen mit `PlanEquipmentGapReason.missing` (definitiv nicht erfuellt)
  sind Substitutions-Kandidaten. `uncertain`/`notAnnotated` werden NIE
  automatisch ersetzt — sie bleiben Klaerungs-Hinweise (Abschnitt 1 der
  Vorgabe, woertlich).
- Eine vorgeschlagene Ersatzuebung muss nach der Pruefung selbst `.satisfied`
  gegen das Profil sein — nicht nur "existiert im Katalog".

**Nicht Teil dieser Phase**: weitere, von der Vorgabe nicht genannte
Substitutions-Paare. Die Vorgabe nennt 7 Kandidaten als Start-Set; dabei
bleibt es bewusst, statt den Scope eigenstaendig zu erweitern.

## 2. Architektur (Core, `FitnessAppCore/Programs/Substitution/`)

- `PlanEquipmentChecker.fullReport(days:against:)` (NEU, additiv): liefert
  JEDE nicht-erfuellte Uebung mit Slot-Position, getrennt nach `missing`
  (Substitutions-Kandidaten) und `uncertain` (Klaerung, nie Substitution) —
  im Unterschied zu `check(days:against:)` (Phase 4, unveraendert), das bei
  der ersten definitiv fehlenden Uebung alle unklaren Geschwister-Funde
  verwirft (Kurzschluss-Aggregation). `check` ist jetzt ueber `fullReport`
  implementiert, exakt gleiches Verhalten, siehe Regressionstest.
- `ExerciseSlot` (dayIndex + exerciseIndex — Namen wiederholen sich ueber Tage).
- `ReviewedSubstitutionRule`: id, Quelle/Ziel-Name, Prioritaet, Reason-Key,
  Context-Pruedikat + Praescriptions-Builder (`(ExerciseSpec, SubstitutionContext) -> ExerciseSpec?`,
  `nil` = Regel gilt in diesem Kontext nicht).
- `ExerciseReplacement`, `PlanAdaptationDraft` (angepasste Tage + alle
  Aenderungen + finaler Equipment-Status NACH Ersatz + Blocker).
- `ExerciseSubstitutionEngine.adapt(...)`: deterministisch, wendet pro
  fehlender Uebung die erste passende, equipment-tatsaechlich-erfuellte
  Regel an; keine Regelketten (ein Ersatz wird nie seinerseits ersetzt).
- `PlanAdaptationValidator`: Programm-Ebene — doppelte Ersatz-Namen am
  selben Tag, verlorene Push/Pull/Legs-Abdeckung.

## 3. Variantenwahl (Phase 5.3, `PlanSelectionResolver`)

`PlanSelectionResolver.resolve(template:profile:context:rules:) -> ResolvedPlanSelection`
ersetzt NICHT `ProgramTemplate.bestEquipmentCheckedVariant` (Phase 4), sondern
erweitert den Datenfluss davor:

1. Zuerst exakt die Phase-4-Logik: gibt es eine Variante, die bereits
   VOLLSTAENDIG passt (`equipmentStatus.isAvailable`), gewinnt sie
   unveraendert — kein Adaptionsversuch, `isAdapted == false`. Eine bereits
   passende Variante wird nie durch eine mit Substitutionen ersetzt.
2. Erst wenn das fehlschlaegt: JEDE konkrete Quell-Variante (nicht nur die
   von Phase 4 bevorzugte Basis) einzeln ueber
   `ExerciseSubstitutionEngine.adapt` bewerten (`equipmentCheckedVariants(against:)`).
3. Unter den VOLLSTAENDIG geloesten Entwuerfen (`PlanAdaptationDraft.isFullyResolved`)
   gewinnt: zuerst die wenigsten Substitutionen, dann die niedrigste
   summierte `deviationCost`, erst dann die hoehere Basis-Prioritaet als
   stabiler Tie-Breaker — nie umgekehrt, sonst wuerden technisch schwerere
   Ersetzungen scheinbar bevorzugt (durch einen synthetischen Mehr-Varianten-
   Test in `PlanSelectionResolverTests` abgesichert).
4. Loest NICHTS vollstaendig, faellt die Funktion auf die unveraenderte,
   transparente Phase-4-Basisvariante zurueck (nie eine nur TEILWEISE
   geloeste Anpassung als Ergebnis ausgeben) — alle versuchten Entwuerfe
   bleiben in `consideredButUnresolvedAdaptations` fuer die UI erhalten
   ("das haben wir versucht, das fehlt noch").

`ResolvedPlanSelection` traegt zusaetzlich `ruleSetVersion`
(`ReviewedSubstitutionCatalog.version`) und `equipmentSnapshot` (das Profil,
gegen das aufgeloest wurde) fuer die Veraltungs-Pruefung in Abschnitt 4.

## 4. Instanziierung (Phase 5.4)

Punkt 6 der Vorgabe woertlich: *"Do NOT preview adaptedDays and then call an
instantiator that reselects bestEquipmentCheckedVariant and loses
substitutions."* Dafuer:

- `ResolvedPlanSelection.isStale(comparedTo:)` — einfacher `Equatable`-
  Vergleich des gespeicherten `equipmentSnapshot` gegen das aktuelle Profil.
- `ProgramInstantiator.instantiate(...)` bekommt einen neuen Parameter
  `resolvedSelection: ResolvedPlanSelection? = nil`, der — sobald gesetzt —
  als EINZIGE Quelle fuer `resolvedDays` gilt (Prioritaet:
  `resolvedSelection` > `bestEquipmentCheckedVariant` [Phase 4] >
  `resolvedDays(forUserEquipment:)` [Legacy]). Eine `precondition` sichert
  `resolvedSelection.templateID == template.id` ab (Caller-Fehler, kein
  Laufzeit-Normalfall).
- Beide Aufrufstellen (`OnboardingView.finishOnboarding()`,
  `ProgramTemplatePickerView.instantiate(_:selection:)`) pruefen VOR dem
  Instanziieren `isStale(comparedTo:)` gegen das aktuell geladene Profil;
  bei Veraltung wird still ueber `PlanSelectionResolver.resolve` frisch
  aufgeloest statt eine moeglicherweise falsche Auswahl zu uebernehmen, bei
  frischer Auswahl wird sie EXAKT (keine erneute Herleitung) uebernommen.
  Dokumentiert als defensiv: kein UI-Pfad in diesem Flow erlaubt aktuell
  eine Equipment-Aenderung zwischen Vorschau und Adopt.
- `TemplatePreviewView.onAdopt` liefert jetzt die in der Vorschau tatsaechlich
  verwendete `ResolvedPlanSelection` an den Parent zurueck (statt eines
  parameterlosen Callbacks) — Vorschau (`resolvedSelection`-computed-property)
  und `adoptButton` lesen dieselbe Funktion, die die Instanziierung erhaelt.
- Neue Ersatz-Uebungen uebernehmen nie Last/Progression der Quell-Uebung —
  by construction, da `ProgramInstantiator.makeExercise` `suggestedWeight`/
  `progressionStep` nie aus einem `ExerciseSpec` liest (kein neuer Code
  dafuer noetig, siehe Apple-Test 22).
- Bewusst NICHT umgesetzt: persistierte Herkunfts-/Regelversion-Felder auf
  `Exercise`. Nicht noetig fuer MVP-Korrektheit (nichts liest aktuell "war
  das substituiert" zurueck), und haette CSV-Export/-Import/Backup/Reset
  beruehrt — Scope-Risiko, das diese Epic durchgehend vermeidet ("only as
  needed" laut Vorgabe Abschnitt 7).

## 5. Vorschau-/Freigabe-UI + Lokalisierung (Phase 5.5)

`TemplatePreviewView.equipmentStatusBanner` (Vorgabe Abschnitt 6):

- Zeigt `adaptedEquipmentBanner(_:)` NUR, wenn `resolvedSelection.appliedAdaptation`
  gesetzt ist — per Konstruktion (Abschnitt 3) also nur bei vollstaendig
  geloester Substitution, nie bei einem Teilerfolg. Titel "An deine
  Ausruestung angepasst" (`picker.plan.equipment.adapted.title`), blaues
  `wand.and.stars`-Icon statt dem gruenen Haken der unveraenderten
  Passend-Anzeige — bewusst unterscheidbar.
- Eine aufklappbare `DisclosureGroup` ("Aenderungen anzeigen",
  `picker.plan.equipment.adapted.showChanges`) listet jede
  `ExerciseReplacement` als durchgestrichener Original-Name → fett
  hervorgehobener Ersatz-Name, darunter der lokalisierte Begruendungstext
  (`replacement.reasonKey`, einer der 5 `substitution.reason.*`-Keys aus
  Abschnitt 1).
- Bleibt nach der Substitution eine Luecke (Fall "nichts vollstaendig
  geloest"), haengt `missingGapDetail` den zusaetzlichen Hinweistext
  `picker.plan.equipment.adaptationAttemptedHint` an, sobald
  `consideredButUnresolvedAdaptations` nicht leer ist — "wir haben es
  versucht, aber es hat nicht vollstaendig geklappt" statt einer stillen
  Luecke ohne Kontext.
- `adoptButton` ruft `onAdopt(resolvedSelection)` — der CTA ist IMMER
  aktiv (kein separater "nur bei vollstaendiger Loesung"-Gate auf
  Button-Ebene noetig), weil `resolvedSelection` bei einer ungeloesten
  Luecke ohnehin die transparente, unveraenderte Basis-Variante liefert
  (Abschnitt 3, Punkt 4) — der User uebernimmt in dem Fall exakt das, was
  die Vorschau zeigt, nie eine verdeckte Teil-Anpassung.
- Abbrechen (Sheet schliessen ohne Adopt) persistiert nichts — `resolvedSelection`
  ist eine reine `computed property`, es existiert kein Zwischenspeicher,
  der beim Verwerfen aufgeraeumt werden muesste (Vorgabe Abschnitt 6:
  "Cancelling must preserve answers/inventory and create no persisted
  draft"). Eine Inventar-Aenderung waehrend die Vorschau offen ist, gibt es
  in diesem Flow nicht (kein editierbarer Equipment-Schritt zwischen
  Preview und Adopt) — die Veraltungs-Pruefung in Abschnitt 4 deckt den
  Fall trotzdem defensiv ab, falls sich das je aendert.
- 8 neue Lokalisierungs-Keys (DE/EN/TR, TR=EN fuer die 5 Uebungs-/Regel-
  Begruendungstexte analog zur bestehenden Konvention fuer Uebungsnamen):
  `picker.plan.equipment.adapted.title`, `.adapted.showChanges`,
  `.adaptationAttemptedHint`, sowie `substitution.reason.squatToGobletSquat`,
  `.bulgarianSplitSquatToLunge`, `.barbellRowToChestSupportedRow`,
  `.pullupToCableLatPulldown`, `.chestSupportedRowToSeatedCableRow`.
  `TRANSLATIONS.md`: 2011 Keys gesamt, 0 hartkodierte Strings.

## 6. Abschlussbericht (Phase 5.6)

**Regeln.** 5 freigegeben (R2 Kniebeuge→Goblet Squat, R3 Bulgarische
Kniebeuge→Ausfallschritte, R4 Rudern vorgebeugt→Chest Supported Row, R5
Klimmzüge/Klimmzüge (weit)→Latzug neutral, R6 Chest Supported Row→Kabelrudern
sitzend), 2 abgelehnt (R1 Ziel existiert nicht im Katalog, R7 Bilateral→
unilateral-Semantik nicht implementiert). Details + Gating: Abschnitt 1.

**Ungeloeste/bewusst nicht abgedeckte Faelle** (werden transparent als Luecke
gezeigt, NIE still uebergangen oder falsch ersetzt):
- Kurzhantel-Bankdruecken (flach/schraeg) ohne Bank — keine Regel vorhanden
  (R1 abgelehnt), bleibt eine `missing`-Luecke ohne Substitutionsangebot.
- Die meisten Langhantel-Grunduebungen ohne Regel (z. B. Kreuzheben,
  Langhantel-Bankdruecken, Langhantel-Schulterdruecken) — nur Kniebeuge (R2)
  und Rudern vorgebeugt (R4) haben eine reviewte Regel; alles andere bleibt
  unsubstituiert.
- Kettlebell-Doppel-Push-Press ohne zwei Kettlebells — keine Regel (R7
  abgelehnt).
- Jede Kraft-Ziel-Kombination (`goal == .strength`) fuer R2/R4 — Gate
  schliesst sie bewusst aus, bleibt unsubstituiert (Vorgabe: kein Ersatz
  fuer Kraft-Anker-Uebungen).
- R5s Einschraenkung "goal is not specifically pull-up performance" hat
  aktuell keinen entsprechenden `TrainingGoal`-Fall im Katalog — dokumentierte
  Limitation ohne erzwingbare Wirkung, keine erfundene Sperre (Abschnitt 1).
- `uncertain`/`notAnnotated`-Luecken (Geraet unbestaetigt, Stueckzahl unklar,
  oder eine der 17 absichtlich nicht annotierten Katalog-Uebungen aus Phase 4)
  werden NIE substituiert — bleiben immer Klaerungs-Hinweis, per Design.
- Cardio-, Warmup/Cooldown- und jeder Tag mit `timeFormat != nil`
  (AMRAP/EMOM/Circuit/Auf-Zeit) — global von Substitution ausgenommen,
  unabhaengig vom Equipment-Status.
- Verkettungen (eine Ersatzuebung wird ihrerseits ersetzt) — die Engine
  verkettet nie; fehlt auch dem Regel-Ziel das Equipment, bleibt der
  Versuch unvollstaendig und landet in `consideredButUnresolvedAdaptations`.

**Tests, tatsaechlich ausgefuehrt (Linux).** Phase 5 fuegt 25 neue
Core-Tests hinzu (`ExerciseSubstitutionEngineTests` 21, `PlanSelectionResolverTests`
4) — Teil der 903 in `FitnessAppCoreTests` insgesamt ausgefuehrten Tests.
Projekt gesamt: **944/944 gruen** (903 Core + 38 Health + 3 UI), per
`swift test --parallel` auf Linux tatsaechlich gelaufen und verifiziert
(zuletzt direkt vor diesem Commit erneut bestaetigt).

**Tests, nur kompiliert (Apple/SwiftData, NICHT lokal ausgefuehrt).** 4 neue
`ResolvedPlanSelectionInstantiationTests` (Items 18, 21, 22 der Vorgabe —
19/20/24 sind reine UI-/Verhaltensfragen ohne sinnvollen SwiftData-Test;
23 entfaellt, siehe Abschnitt 4: keine neuen Herkunfts-Felder). Zusammen mit
den 3 Phase-4-Tests (`ProgramInstantiatorEquipmentTests`) liegen damit 7
`FitnessAppDataTests` vor, die auf Linux kompilieren (`swift build
--build-tests` erfolgreich) aber laut `swift test list` mit 0 Treffern NICHT
discovered/ausgefuehrt werden (bekannte, seit Phase 4 dokumentierte
SwiftData-Einschraenkung dieser Linux-Toolchain).

**Korrektur dieser Aussage, belegt durch einen echten Codemagic-Lauf.** Der
User hat ein `run_unit_tests__release_gate__1.log` eines tatsaechlichen
Release-Gate-Builds hochgeladen — Build fehlgeschlagen, mit 4 konkreten
Compiler-Fehlern in `ResolvedPlanSelectionInstantiationTests.swift`. Root
Cause: in 2 der 4 Tests ueberschattet (shadowing) eine lokale `let context =
SubstitutionContext(...)` die Klassen-Property `context: ModelContext`
desselben Namens — `ProgramInstantiator.instantiate(..., in: context, ...)`
erhielt dadurch den falschen Typ. Gefixt (lokale Variable auf
`substitutionContext` umbenannt). `grep -r "let context = " Tests/
FitnessAppDataTests` bestaetigt: kein weiteres Vorkommen dieses Musters im
Target.

Grund, warum Linux das nie haette fangen koennen: `SwiftData` ist auf dieser
Linux-Toolchain NICHT importierbar (`echo 'import SwiftData' | swift -`
schlaegt mit "no such module" fehl) — jede `FitnessAppDataTests`-Datei steht
komplett hinter `#if canImport(SwiftData)`, das hier `false` ist. "Kompiliert
auf Linux" bedeutete fuer diese Dateien bisher NUR "parst als syntaktisch
gueltiges Swift", NICHT "der Datei-Inhalt wurde typgeprueft" — der
Compiler sieht den Codeblock hinter dem `#if` auf Linux ueberhaupt nie. Das
ist eine schwaechere Garantie als in jedem bisherigen Phasenbericht
suggeriert. Als Ersatz wurde die gesamte Datei nach dem Fix manuell gegen
die echten Signaturen verifiziert (`ProgramInstantiator.instantiate`,
`DaySpec`/`ProgramTemplate`/`ExerciseSpec`-Init, `TrainingPlan`/`TrainingDay`/
`Exercise`-Properties — alle per `grep`/`Read` im jeweiligen Quell-File
gegengeprueft, mehrere Konstruktions-Muster zusaetzlich 1:1 gegen bereits auf
Linux ausgefuehrten Core-Code abgeglichen). Danach erneut `swift build
--build-tests` + `swift test --parallel`: weiterhin 944/944 gruen.
**Fuer kuenftige Phasen:** "FitnessAppDataTests kompiliert auf Linux" wird ab
jetzt NICHT mehr als Typpruefungs-Nachweis dargestellt — nur noch als
Syntax-Check. Echte Typsicherheit fuer diese Dateien gibt es ausschliesslich
durch einen echten Codemagic/Apple-Lauf.

**Keine UI-Tests.** Es wurden fuer Phase 5 keine `FitnessAppUITests`
ergaenzt — die neue Vorschau-/Freigabe-UI (`adaptedEquipmentBanner`,
`DisclosureGroup`) wurde ausschliesslich durch Code-Review + die
Core/Data-Tests der darunterliegenden Logik abgesichert, nicht durch einen
automatisierten UI-Test.

**Apple/Codemagic-Status: weiterhin ungeprueft, explizit offen.**
`mcp__github__actions_list` liefert fuer `claude/smart-onboarding-epic`
`total_count: 0` (keine sichtbaren Workflow-Runs), es existiert keine
Pull Request fuer diesen Branch. Diese Session hat KEINE Sicht auf
Codemagic-Build-/Test-Ergebnisse. Wie in jedem vorherigen Phasenbericht:
Linux-kompilierter SwiftData-/SwiftUI-Code wird hier nicht als
"Apple-getestet" dargestellt — die Phase-4- UND jetzt Phase-5-
Apple-Validierung (echter `mac_mini_m2`-Build inkl. der 7 `FitnessAppDataTests`
und einer manuellen Pruefung der neuen UI) bleibt eine offene
Release-Voraussetzung.

**Nicht Teil dieser Phase (bewusste Scope-Entscheidungen, siehe Abschnitt 4).**
Keine persistierten Herkunfts-/Regelversion-Felder. Keine Aenderung an
bestehenden, bereits gespeicherten Plaenen (durch `testExistingPlanContentIsUnchangedWhenANewAdaptedPlanIsInstantiated`
abgesichert). Kein Substitutions-Ketten-Mechanismus. Keine ueber die 7
Kandidaten der Vorgabe hinausgehenden Regeln.
