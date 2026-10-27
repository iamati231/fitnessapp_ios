# Equipment-Vielfalt & Laufcoaching-Dual-Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two confirmed, pre-existing architecture gaps found during manual device testing after PR #2: (1) equipment selection has no effect on most curated training templates because a fixed priority always picks barbell when available, and (2) Laufcoaching cannot add running to an active plan that has no cardio day yet, so the user is silently funneled into creating a second, uncoordinated plan.

**Architecture:** Equipment side (revised after architecture review, see "Änderungen nach Review" below): the `ExerciseSubstitutionEngine`/`ReviewedSubstitutionRule` catalog stays completely untouched — it is not replaced, duplicated, or bypassed. The new mechanism is a *separate, additive* layer: each slot in a template may declare 0-3 **already-authored, reviewed alternative exercise names** (not an open catalog search by muscle/role/difficulty) — for the 3 hybrid templates this is a 1:1 migration of their existing, hand-curated `equipmentVariants` content, so parity is structural, not heuristic. Resolution per slot is a strict three-state decision: curated default available → keep it; a reviewed alternative available → use it; neither available → surface the gap visibly via the existing `PlanEquipmentChecker` gap reporting, never a silent fallback to an unusable exercise. Templates whose name/identity *is* a specific equipment (Kettlebell*, Powerlifting*, Home Gym Hero, Bodyweight Mastery, CrossFit*) are explicitly out of scope and keep their fixed content, and their existing equipment gaps continue to be handled exclusively by the unmodified `ExerciseSubstitutionEngine`. The 7 purely-generic templates that have never had any equipment-authored alternative are **not** given invented, unreviewed alternatives by this plan (see Open Question A4) — that would need separate, explicit content review. Laufcoaching side: every `TrainingPlan` already has a `TrainingDay` row for all 7 weekdays (non-workout days are auto-generated `.rest` days) — "adding" a cardio day is therefore "convert an eligible rest day", reusing the exact same persistence primitive (`PlanGeneratorInstantiator.apply`) the existing replace-path already uses, re-validated immediately before every write, never trusting a stale preview. The silent Option A/B fallback in `CardioFeasibilityCardModel.accept()` becomes an explicit user choice, reusing the existing `CoachAdjustmentPreviewView` screen.

## Änderungen nach Architektur-Review (2026-10-25)

Der Auftraggeber hat die erste Planfassung geprüft und sieben konkrete Korrekturen verlangt, bevor eine Freigabe zur Umsetzung infrage kommt. Alle sieben sind in dieser Fassung eingearbeitet:

1. **Slot-Auflösung ohne Qualitätsgrenze (Task 1):** ein offener Katalog-Suchmechanismus nach Muskelgruppe/Rolle/Schwierigkeit allein garantiert nicht denselben Trainingsreiz/dasselbe Bewegungsmuster. Behoben: Slots tragen nur noch eine begrenzte, bereits kuratierte Alternativen-Liste (siehe A2 unten), kein freier Katalog-Suchlauf mehr. `ExerciseSubstitutionEngine` bleibt die einzige Instanz, die offene (nicht vor-autorisierte) Ersatz-Entscheidungen trifft, und bleibt dafür unverändert.
2. **„Nie leer" ≠ „ausführbar" (Task 2):** der bisherige Fallback auf den ursprünglichen Übungsnamen bei fehlendem Kandidaten wurde gestrichen. Die Drei-Zustände-Regel (kuratiert verfügbar / geprüfte Alternative verfügbar / keine geeignete Alternative — Lücke sichtbar) ersetzt ihn, siehe Task 1 Step 4 unten.
3. **Paritäts-Nachweis für die Hybrid-Templates (Task 3):** eine explizite Paritätsmatrix (jede bisherige `equipmentVariants`-Übung gegen jedes Profil) ist jetzt Step 1 von Task 3 und Voraussetzung für das Löschen der alten Daten, nicht nachträgliche Stichprobe.
4. **Doppelte Modellierung der Cardio-Verfügbarkeit (Task 5):** der vorgeschlagene `.insertable(...)`-Enum-Fall entfällt. `cardioAvailability` beschreibt ausschließlich ersetzbare Cardio-Tage, `insertableRestDays` ist ein eigenes, unabhängiges Feld.
5. **Erneute Prüfung vor dem Einfügen (Task 6/7):** die Auswahl geeigneter Ruhetage wird unmittelbar vor dem Schreiben neu berechnet (gleiches Prinzip wie der bestehende Ersetzungspfad), nicht aus einer möglicherweise veralteten Vorschau übernommen. Reicht die Zahl nicht mehr aus, bricht die Übernahme sicher und mit verständlicher Rückmeldung ab, statt teilweise oder mit veralteten IDs zu schreiben.
6. **Eindeutige fachliche Zuordnung des Laufplans (Task 9):** ein einzelner, dokumentierter `ActivePlanResolver` ersetzt die vage Formulierung "generationSource == .cardioCoach oder zuletzt aktiviert" — mit einer expliziten, stabilen Tie-Break-Regel und einem definierten "kein eindeutiger Plan" Ergebnis statt eines geratenen.
7. **Umfang der Schutztests (Task 10):** der Double-Tap-Test prüft jetzt ausdrücklich dieselbe Modellinstanz zweimal (das historische Runde-2-Bugmuster), und ein neuer Testfall prüft den Fehlerfall beim Einfügen (kein Teil-Ergebnis, kein gesetzter Fingerprint bei Misserfolg).

## Änderungen nach der zweiten Review-Runde (2026-10-25)

Fünf weitere, konkrete Punkte wurden geprüft und eingearbeitet — zwei davon (Punkt 1, Punkt 2) durch Lesen des tatsächlichen Codes gelöst statt nur im Text präzisiert:

1. **„Unresolved" bis zur Instanziierung eindeutig (Task 1/3/4):** gelöst durch Wiederverwendung des bereits bestehenden, bewährten Mechanismus statt eines neuen. `ResolvedPlanSelection`/`PlanSelectionResolver.resolve` (`Sources/FitnessAppCore/Programs/ResolvedPlanSelection.swift`) transportiert diesen Zustand bereits heute für alle 17 unveränderten Templates — `equipmentStatus: PlanEquipmentStatus` (`.available`/`.unknown`/`.unavailable(gaps:)`), `days` zeigt bei einer Lücke transparent die unveränderte Variante, niemals eine stillschweigend "gelöste" Fälschung. `ProgramTemplatePickerView.equipmentStatusBanner` (Zeilen 359-389) zeigt diesen Zustand bereits heute sichtbar an — ohne den Adopt-Button zu sperren (etablierte, bereits reviewte UX: Transparenz statt Blockade). Die 3 Hybrid-Templates produzieren künftig ebenfalls ein `ResolvedPlanSelection` über denselben Resolver, mit demselben Status-Vokabular — keine neue Datenstruktur, kein neuer UI-Pfad. Siehe überarbeitete Tasks 3/4.
2. **Schutz manuell bearbeiteter Ruhetage (Task 5):** `generationFingerprint` hilft hier nicht — automatisch erzeugte Ruhetage bekommen laut `ProgramInstantiator.swift:191-198` NIE einen Fingerprint, genau wie ein manuell bearbeiteter Tag. Tatsächlich gefundenes, bereits im Code verwendetes Unterscheidungsmerkmal: `TrainingDay.name == "Ruhetag"` — automatisch erzeugte Ruhetage tragen exakt diesen Namen (`ProgramInstantiator.swift:192`), und `DayEditorView`s Typ-Wechsel (`TrainingDaySnapshot.apply`, Zeile 1703) ändert `day.type`, NIE `day.name`. Ein Nutzer, der einen Trainingstag ("Push A") zu einem Ruhetag umwidmet, behält also den alten `name`. Dieselbe `type == .rest && name == "Ruhetag"`-Kombination verwendet der bestehende Code bereits an zwei Stellen zum selben Zweck (`LibrarySeeder.swift:300`, `:386`) — kein neuer Mechanismus, sondern ein bestehendes, bereits genutztes Muster. Die Eignungsprüfung wird um `customName == nil` ergänzt (zusätzliche, günstige Absicherung gegen einen vom Nutzer umbenannten Ruhetag).
3. **ActivePlanResolver-Gleichstand (Task 9):** `TrainingPlan` hat kein eigenes, stabiles `id`-Feld (nur `activatedAt: Date?`, sonst ausschließlich SwiftDatas interne, nicht dafür vorgesehene `PersistentIdentifier`) — ein erfundener zweiter Sortierschlüssel wäre eine stille, bedeutungslose Pseudo-Ordnung. Bei echtem Gleichstand (identischer `activatedAt`-Wert ODER beide `nil`) unter mehreren `.cardioCoach`-Plänen liefert der Resolver jetzt `nil` statt zu raten (Review-Vorschlag, direkt übernommen). Ein zusätzliches, stabiles `id: UUID`-Feld auf `TrainingPlan` wäre eine Datenmodell-Änderung und bleibt eine offene, separate Entscheidung, falls dieser seltene Fall (zwei Laufcoaching-Vorgänge in sehr kurzer Folge) später doch aufgelöst werden soll.
4. **Task 2, `UserEquipmentProfile.gymDefault` (Korrektur, keine Architekturfrage):** existiert tatsächlich — nur nicht in `EquipmentRequirement.swift`, sondern in `Sources/FitnessAppCore/Programs/EquipmentPlanningContext.swift:98-108`. Dort auch dokumentiert: Kettlebell/Widerstandsband bleiben in diesem Profil bewusst `.unknown`, nicht `.unavailable`. Task 2 definiert jetzt alle vier Testprofile explizit und wertet `PlanEquipmentChecker.fullReport`s `missing`/`uncertain`-Listen GETRENNT aus, statt sie zu einer undifferenzierten "Lücke" zusammenzufassen.
5. **Eigenständige Re-Validierung in `insertCoachCardioDays` (Task 6):** die Funktion verlässt sich jetzt nicht mehr auf korrekte Verwendung durch den Aufrufer, sondern prüft jeden Zieltag unmittelbar vor der Mutation selbst erneut (neue, wiederverwendbare Einzeltag-Prüfung, siehe Task 5). Zur Transaktions-/Wiederherstellungsstrategie: `PlanGeneratorInstantiator.apply`/`revert`/`save` (Zeilen 508-514, 811-896, 943ff.) belegen bereits den heute produktiv laufenden, bereits reviewten Vertrag — `save` ist zwar ein echtes `context.save()` (sichert den gesamten Context, eine bestehende, nicht von diesem Plan eingeführte SwiftData-Eigenschaft), aber `revert` ist KEIN Context-Rollback, sondern eine manuelle, feldgenaue Rücknahme ausschließlich der selbst vorgenommenen Änderungen (`DayMutationSnapshot`). `insertCoachCardioDays` nutzt exakt dieselben `apply`/`revert`/`DayMutationSnapshot`-Bausteine unverändert — keine neue, ungetestete Transaktionsstrategie.

## Vierte Review-Runde: zwei letzte Entscheidungen vor der Freigabe (2026-10-25)

### Entscheidung 1: Übernahme bei ungelösten Equipment-Slots — Warnung, nicht Blockade

**Entschieden: Warnung, keine Blockade — das ist keine neue Entscheidung, sondern die bereits heute für alle 17 unveränderten Templates geltende, bereits reviewte und ausgelieferte Regel, unveraendert auf die 3 Hybrid-Templates ausgedehnt.** `ProgramTemplatePickerView.equipmentStatusBanner`/`adoptButton` (Zeilen 302-389, vollstaendig gelesen) zeigen den `.unavailable`-Status heute bereits sichtbar an, OHNE den Adopt-Button zu sperren — das gilt fuer jedes Template mit Equipment-Luecke, nicht nur fuer die 3 Hybrid-Templates. Task 4 fuehrt KEINE neue Produktentscheidung ein, es wendet exakt diese bestehende, app-weit konsistente UX unveraendert auf das neue `equipmentStatus`-Mapping an. Eine Blockade waere die tatsaechlich neue, breiter wirkende Verhaltensaenderung gewesen — die habe ich bewusst NICHT eingefuehrt.
Das loest den scheinbaren Widerspruch zu Task 11 auf: fuer die 3 Hybrid-Templates mit den Profilen, die ihre migrierten `reviewedAlternatives` tatsaechlich abdecken (`dumbbellOnly`/`kettlebellOnly` — exakt die Profile, fuer die die alten `equipmentVariants` vollstaendig geloest waren), gibt es per Konstruktion KEINEN ungeloesten Slot — "keine nicht ausfuehrbare Uebung" gilt dort also tatsaechlich uneingeschraenkt. Fuer ein Profil AUSSERHALB dieser Abdeckung (z.B. wirklich nur Koerpergewicht) kann ein Slot `.unresolved` bleiben; dort gilt dieselbe Warnung-statt-Blockade-Regel wie ueberall sonst in der App. Task 11 ist entsprechend praezisiert (siehe unten) — die Formulierung "keine nicht ausfuehrbare Uebung" galt nur fuer die abgedeckten Profile und war missverstaendlich allgemein formuliert.

## Siebte Review-Runde: Implementierungsfreigabe-Prüfung — zwei Korrekturen, drei Präzisierungen (2026-10-25)

**Entscheidung zu Bestandsplänen bestätigt:** Option (a) ist verbindlich — kein automatischer Backfill, eine nutzerbestätigte Vorbereitung (Option c) bleibt ein separates, noch nicht freigegebenes Folge-Feature. Task 5/6 sind für neu erstellte Pläne vollständig, für Bestandspläne bewusst eingeschränkt — nicht mehr "pending", sondern entschieden.

### Korrektur 1: `ActivePlanResolver` verletzte die Modulgrenze

Zu Recht gefunden: `FitnessAppCore/Programs/ActivePlanResolver.swift` als "pure logic, no SwiftData" war falsch angegeben — die Signatur nimmt `[TrainingPlan]` entgegen, ein SwiftData-Modell aus `FitnessAppData`; `FitnessAppCore` kann davon nicht abhängen. Korrigiert: Datei und Test verschoben nach `FitnessAppData`, neben `RunCoachPlanAdjustment`/`ProgramInstantiator`, die bereits genauso mit `TrainingPlan` arbeiten. Der Resolver bleibt in dem engeren, weiterhin relevanten Sinn "rein" — er holt nichts selbst, schreibt nichts, ist eine deterministische Funktion über seine Eingabe.

### Korrektur 2: Task 11 verwechselte "Option A insgesamt" mit "die neue Einfüge-Fähigkeit"

Die Option-(a)-Einschränkung betrifft ausschließlich das EINFÜGEN in einen Plan ohne jeden Cardio-Tag. Ein Bestandsplan, der (aus Runde 2) bereits einen ersetzbaren Cardio-Tag hat, ist davon komplett unberührt — seine Eignung läuft über `generationFingerprint`/`isEligibleForAdjustment`, ein Feld, das es schon vor `isAutoFilledPlaceholder` gab und das dieser Plan nicht anfasst. Der Abnahmetest prüft jetzt drei statt einem alten-Plan-Fall: frisch erzeugt (Einfügen funktioniert), alt ohne Cardio-Tag (bewusst eingeschränkt), alt MIT bestehendem Cardio-Tag (Ersetzungspfad unverändert funktionsfähig).

### Präzisierung P2a: `.unresolved` und `equipmentStatus` sind EIN zusammenhängendes Invariant, nicht zwei separate Aussagen

Jetzt explizit verknüpft (Task 1 und Task 3/4): die ursprüngliche Übung bleibt bei `.unresolved` NUR als transparenter Vorschauinhalt in `days` erhalten — sie gilt nicht als erfolgreich aufgelöst, und `equipmentStatus` (und damit jede UI, die ihn liest) darf in diesem Fall NIEMALS `.available` melden. "Kein stiller Fallback" (Task 1) und "Tage bleiben sichtbar" (Task 3) beschreiben denselben Zustand aus zwei Blickwinkeln, nicht zwei unabhängige, potenziell widersprüchliche Verhalten.

### Präzisierung P2b: Reaktivität des Equipment-Banners ist bereits strukturell gegeben — jetzt explizit benannt

Nachgeprüft: `PlanEditorView` hat bereits `@Query private var userProfiles: [UserBodyProfile]` (`PlanEditorView.swift:37`) — die View ist also schon heute eine SwiftData-`@Query`-Observanz auf `UserBodyProfile`, die bei einer Profiländerung anderswo im Context automatisch neu rendert. `SavedPlanEquipmentCheck`s Aufruf muss `userProfiles` (bzw. den daraus abgeleiteten `UserEquipmentProfile`) auf genau demselben Weg lesen, den diese View für das Profil bereits nutzt — dann kommt die Aktualisierung ohne jeden neuen Mechanismus, einfach weil die View ohnehin schon beobachtet. Keine Vermutung mehr, sondern am Code bestätigt.

### Präzisierung P2c: `.unknown` gewinnt nie einen Slot

Explizit festgelegt (Task 1): `TemplateSlotResolver.resolve` behandelt `EquipmentRequirement.evaluate(against:) == .unknown` NIEMALS wie `.satisfied` — ein Kandidat (Standard oder Alternative) gewinnt ausschließlich bei `.satisfied`. Bleiben Standard UND alle Alternativen bei `.unknown`/`.unmet` stehen, wird der Slot `.unresolved` mit `.uncertain(...)` (aus einem `.unknown`-Ergebnis) bzw. `.missing(...)` (aus `.unmet`) — genau dieselbe Drei-Werte-Logik, die `PlanEquipmentChecker` bereits an jeder anderen Stelle dieses Projekts verwendet. Das ist besonders relevant, weil `UserEquipmentProfile.gymDefault` Kettlebell/Widerstandsband bewusst `.unknown` lässt (siehe erste Review-Runde) — ohne diese Festlegung hätte `.unknown` versehentlich wie "passt schon" behandelt werden können.

## Sechste Review-Runde: eine offene Produktentscheidung, vier Präzisierungen (2026-10-25)

### Offene Produktentscheidung: was passiert mit VOR diesem Update erstellten Plänen?

Der Auftraggeber hat zu Recht benannt, was die "nicht raten"-Regel aus Option (a) tatsächlich kostet: JEDER vor diesem Update instanziierte Plan hat `isAutoFilledPlaceholder == false` auf all seinen Ruhetagen (Lightweight-Migration-Default), unabhängig davon, ob sie strukturell echte, unberührte Auto-Platzhalter sind. Das bedeutet: **Option A (Cardio in einen bestehenden Plan einfügen) funktioniert für JEDEN heute schon aktiven, bereits installierten Nutzer-Plan nicht** — nur neu erzeugte Pläne profitieren. Ein Backup aus einer älteren Version verhält sich identisch (fehlende CSV-Spalte → `false`).

Ein nachträglicher Backfill für bestehende Zeilen wuerde zwangsläufig wieder genau die Feldkombination (`type == .rest && activeExercises.isEmpty && ...`) heranziehen, die dieses gesamte Review bereits als unzuverlässig erwiesen hat (`PlanEditorView.createNewDay` erzeugt identische Werte) — ein Backfill WÄRE also wieder ein Raten, nur zeitlich verschoben. Deshalb schlage ich KEINEN automatischen Backfill vor. Zwei echte Optionen:

- **(a) Akzeptierte Einschränkung:** Option A steht nur für ab jetzt neu erstellte/neu generierte Pläne zur Verfügung. Bestehende Nutzer mit einem älteren Plan sehen in der Vorschau weiterhin nur "Create new plan" (Option B) — kein Rückschritt gegenüber heute, nur noch keine Verbesserung für sie.
- **(c) Expliziter, nutzerbestätigter Reparatur-Weg:** ein eigener, vom Nutzer ausdrücklich ausgelöster Schritt (z.B. ein Button "Ruhetage für dieses Feature vorbereiten" im Plan-Editor), der die HEUTE bereits leeren, typmäßig als `.rest` erkannten Tage eines bestehenden Plans auf `isAutoFilledPlaceholder = true` setzt — NICHT automatisch/still, sondern nur nach einer bewussten Nutzer-Bestätigung. Das ist kein Raten mehr, weil der Nutzer selbst die Aussage trifft ("ja, das sind für mich freie Tage"), genau wie `UserEquipmentProfile.confirmRemainingAsUnavailable` an anderer Stelle in diesem Projekt bereits eine unklare Datenlage durch eine explizite Nutzer-Bestätigung auflöst, statt sie zu erraten.

**Entschieden (siebte Review-Runde): Option (a).** Kein automatischer Backfill für Bestandspläne; Option (c) bleibt ein separates, noch nicht freigegebenes Folge-Feature, nicht Teil dieses Plans. Task 5/6 gelten damit als abschließend spezifiziert: vollständig für neu erstellte Pläne, bewusst eingeschränkt für Bestandspläne — das ist keine offene Frage mehr, sondern der dokumentierte, akzeptierte Umfang dieses Plans.

### Präzisierung 2 (ergänzt): Testname korrigiert

`TrainingDayIsAutoFilledPlaceholderMigrationTests` → `TrainingDayIsAutoFilledPlaceholderDefaultTests`. Der Test beweist, dass das NEUE Modell ohne expliziten Parameter korrekt `false` liefert und sich speichern/laden lässt — er beweist NICHT, dass ein vor der Änderung erstellter, echter SwiftData-Store korrekt migriert wird (das gibt es in diesem Projekt für kein vergleichbares Feld als eigenen Test, siehe fünfte Runde). Die automatische Lightweight-Migration bleibt eine begründete, aber ausdrücklich separat dokumentierte Annahme, keine durch einen Test bewiesene Tatsache.

### Präzisierung 3 (ergänzt): widersprüchlicher Rollback-Test entfernt

`test_insertCoachCardioDays_throwsAndRollsBackPartialWrites_onMidwayFailure` beschrieb einen "Fehler zwischen Tag 1 und Tag 2"-Fall, der der tatsächlichen Mechanik (alle `apply()` zuerst, EIN `save()` am Ende) widerspricht und denselben Fall wie der bereits korrigierte `test_insertCoachCardioDays_revertOnFailure_restoresDayTypeToRest` beschreibt. Gestrichen — siehe Task 6 unten, nur noch EIN Test für diesen Fehlerfall, mit allen vier vom Auftraggeber verlangten Teilen explizit benannt.

### Präzisierung 4 (ergänzt): `SavedPlanEquipmentCheck`s Anforderungen explizit benannt

Vier Anforderungen, jetzt als Interfaces-Text und Tests in Task 4 verankert: (1) identische `.missing`/`.uncertain`-Regeln wie `PlanEquipmentChecker` (durch Wiederverwendung ohnehin strukturell garantiert, jetzt zusätzlich mit einem Test gepinnt, der dieselben Tage ueber beide Wege prueft); (2) eine Profiländerung muss das Ergebnis ohne erneutes Öffnen/Speichern aktualisieren — die Funktion ist eine reine Berechnung, der Aufrufer (SwiftUI-View) muss sie als berechneten Wert lesen, nie zwischenspeichern; (3) niemals Übungen eines ANDEREN Plans einbeziehen (Test mit zwei Plänen); (4) ein leerer Plan (keine Übungen) ist dokumentiert `isFullyAvailable == true` ("nichts vorhanden, das fehlen könnte"), nicht stillschweigend — mit explizitem Test, der dieses Verhalten pinnt statt es unausgesprochen zu lassen.

### Präzisierung 5 (NEU): Kostenrahmen für Task 11

Dieselbe, bereits im TestingBot-Auftrag etablierte Regel gilt explizit auch hier: nur vorhandenes TestingBot-Guthaben im genehmigten Rahmen, keine Zusatzkäufe oder ein Guthaben-Upgrade ohne vorherige Zustimmung.

## Fünfte Review-Runde: vier Präzisierungen, keine neuen Produktentscheidungen (2026-10-25)

### Präzisierung 1: Equipment-Lücke muss auch NACH der Übernahme nachweisbar sein — fehlender Mechanismus gefunden und ergänzt

Nachgeprüft: es gibt HEUTE keinerlei Stelle, die den Equipment-Status eines bereits gespeicherten Plans gegen das aktuelle `UserEquipmentProfile` neu berechnet und anzeigt (`PlanEditorView`/`DashboardView`/`ExerciseDetailView` — keine Treffer für `PlanEquipmentChecker`/`PlanEquipmentStatus`). `ResolvedPlanSelection.equipmentStatus` ist ein reiner Vorschau-Wert, der nach `ProgramInstantiator.instantiate` nirgends weiterlebt — die Lücke "verschwindet" nach der Übernahme tatsächlich aus der Sicht des Nutzers. Das war eine echte Lücke im Plan, keine bereits vorhandene Eigenschaft.
**Ergänzung (keine neue Persistenz, wie vom Auftraggeber verlangt):** Task 4 bekommt einen zusätzlichen Baustein — eine kleine, zustandslose Funktion in `FitnessAppData` (wo `TrainingDay`/`Exercise` als SwiftData-Typen existieren), die aus den AKTUELLEN `activeExercises` eines gespeicherten Plans eine minimale `[DaySpec]`-Repräsentation baut und damit das bestehende, unveränderte `PlanEquipmentChecker.fullReport(days:against:)` aufruft — reine Neuberechnung bei jedem Rendern, kein gespeicherter Status. `PlanEditorView` zeigt das Ergebnis über eine neue, einfache Banner-Zeile (gleiche visuelle Sprache wie `ProgramTemplatePickerView.equipmentStatusRow`, aber kein neuer Typ) an, wenn mindestens eine Lücke besteht. Details siehe Task 4 unten.

### Präzisierung 2: der Migrationstest braucht kein neues, bisher unbenutztes Test-Muster

Nachgeprüft, wie dieses Repository SwiftData-Schema-Versionen handhabt (`Sources/FitnessAppData/AppSchema.swift`, `Tests/FitnessAppDataTests/ExperienceTrackBackfillTests.swift` als Referenz-Beispiel fuer ein vergleichbares additives, defaultwertiges Feld): **es gibt kein `VersionedSchema`/`SchemaMigrationPlan` in diesem Projekt — `AppSchema.types` ist eine flache Typenliste, jede Migration eines additiven, defaultwertigen Feldes (`localizationKey`, `generatorSequenceIndex`, `activatedAt` u.a.) läuft ausschließlich über SwiftDatas automatische Lightweight-Migration, OHNE eigenen Test dafür irgendwo in diesem Projekt.** Jeder bestehende Persistenz-Test (z.B. `ExperienceTrackBackfillTests`) baut einen FRISCHEN, In-Memory-`ModelContainer` aus dem AKTUELLEN Modell — es existiert kein Fixture mit einem echten, vor der Änderung gespeicherten `.sqlite`-Store irgendwo im Projekt, und keine Infrastruktur, einen solchen zu erzeugen.
**Entscheidung: kein neues Test-Muster einführen.** Der zuvor vorgeschlagene "Apple-CI-only"-Test mit einem echten alten Schema wird gestrichen — er hätte eine für dieses Feld unverhältnismäßige, im gesamten Projekt präzedenzlose Test-Infrastruktur gebraucht, für ein Risiko, das identisch zu einem Dutzend bereits ausgelieferter additiver Felder ist, die alle ohne einen solchen Test auskamen. Stattdessen: derselbe In-Memory-`ModelContainer`-Test wie bei `ExperienceTrackBackfillTests` (Task 5, unten) — das ist die tatsächlich etablierte, von diesem Projekt als ausreichend behandelte Sorgfaltsstufe für genau diese Art Änderung, nicht eine Abkürzung.

### Präzisierung 3: Eignungsfunktion vs. Einfügefunktion — getrennt gezählt

`RunCoachPlanAdjustment.isEligibleRestDayForInsertion` prüft **fünf** Bedingungen: Herkunft (`isAutoFilledPlaceholder == true`), `type == .rest`, `activeExercises.isEmpty`, `sessions.isEmpty`, `customName == nil`. `PlanGeneratorInstantiator.insertCoachCardioDays` prüft ZUSÄTZLICH, als eigene, nachgelagerte Garantie VOR jeder Mutation: Plan-Zugehörigkeit (`day.plan?.persistentModelID == plan.persistentModelID`) und ausreichende Anzahl (`restDays.count >= newCardioDays.count`). Zwei Funktionen, zwei getrennte Invarianten — unten in Task 5/6 entsprechend präzise benannt, nicht mehr als "sechs Bedingungen" zusammengefasst.

### Präzisierung 4: Rollback-Test — tatsächliche Mechanik dieses Codes

Nachgeprüft (`PlanGeneratorInstantiator.applyCoachCardioAdjustment`, vollständig gelesen): `apply()` wird für ALLE betroffenen Tage nacheinander rein im Speicher aufgerufen (sammelt dabei einen `DayMutationSnapshot` pro Tag), und ERST DANACH EIN EINZIGER `save(context)`-Aufruf am Ende versucht, alles gemeinsam zu persistieren. Es gibt in dieser Architektur keinen "Tag 1 erfolgreich gespeichert, Tag 2 schlägt fehl"-Fall — entweder der eine `save()` gelingt für alle, oder er schlägt fehl und `revert(snapshots, in:)` nimmt ALLE gesammelten Snapshots zurück, nicht nur den zuletzt bearbeiteten. Der Testansatz wird entsprechend präzisiert (Task 6, unten): der erzwungene Fehler muss NACH ALLEN `apply()`-Aufrufen, aber BEIM `save()`-Aufruf selbst erfolgen (über `saveOverrideForTesting`, denselben bereits bestehenden Test-Hook, den `applyCoachCardioAdjustment`s eigene Tests schon nutzen) — und der Test prüft die Wiederherstellung für MEHRERE betroffene Tage gleichzeitig (mindestens zwei), nicht nur für einen.

### Entscheidung 2: welche manuelle Bearbeitung hebt die Einfuege-Eignung eines Ruhetags auf

`TrainingDaySnapshot.apply(to:)` (vollstaendig gelesen, `DayEditorView.swift:1700-1710`) ist die EINZIGE Stelle, an der ein Nutzer einen bestehenden Tag editiert; sie schreibt genau neun Felder: `customName, weekday, type, nextIntensity, timeFormat, timeCapMinutes, circuitRounds, circuitRestSeconds, circuitMode`. Durchgegangen, welche davon eine bewusste Nutzer-Absicht fuer GENAU DIESEN Tag ausdruecken (nicht nur eine mechanische Struktur-Aenderung):
- `type`/`activeExercises`/`sessions` sind bereits Teil der bestehenden Live-Pruefung — ausreichend abgedeckt, keine Aenderung noetig.
- `weekday`, `nextIntensity`, `timeFormat`, `timeCapMinutes`, `circuitRounds`, `circuitRestSeconds`, `circuitMode` sind bei einem Ruhetag faktisch immer in ihrem Default-Zustand (`nil`/Standard) und tragen keine erkennbare Nutzer-Absicht speziell fuer DIESEN Tag — keine Disqualifikation noetig.
- `customName`: EINZIGES Feld, das eine explizite, bewusste Nutzer-Handlung an GENAU diesem Tag ausdrueckt (der Nutzer hat etwas eingetippt). Ein Nutzer, der seinem Ruhetag einen Namen gibt (z.B. "Family Day"), hat sich damit erkennbar mit diesem spezifischen Tag befasst — ein anderes Signal als `isAutoFilledPlaceholder` (das beweist nur die HERKUNFT, nicht ob der Nutzer den Tag seither bewusst behalten hat).

**Empfehlung, in Task 5 umgesetzt:** `customName == nil` wird als sechste, unabhaengige Live-Bedingung ergaenzt — nicht als Herkunftsnachweis (das bleibt `isAutoFilledPlaceholder`s alleinige Aufgabe), sondern als eigenstaendiges "hat sich der Nutzer mit GENAU diesem Tag befasst"-Signal. Keine andere Bearbeitung disqualifiziert, weil keine andere ueber `TrainingDaySnapshot.apply` erreichbare Aenderung eine vergleichbare, tagspezifische Absicht ausdrueckt.

## Dritte Review-Runde: ein echter Befund, jetzt entschieden — und zwei weitere behobene Lücken (2026-10-25)

Auf ausdrücklichen Wunsch des Auftraggebers wurde die `name == "Ruhetag"`-Erkennung gegen ANDERE Bearbeitungswege als den Type-Toggle geprüft, nicht nur gegen `DayEditorView`. Ergebnis: **die Annahme aus der zweiten Runde ist widerlegt, nicht nur unvollständig.**

### Offener Befund: `name == "Ruhetag"` ist kein Herkunftsnachweis — echter Gleichstand gefunden

`PlanEditorView.createNewDay(type: .rest)` (`Sources/FitnessAppUI/Workout/PlanEditorView.swift:973-1003`) — die reguläre "Tag hinzufügen"-Funktion im Plan-Editor — erzeugt bei Wahl von "Ruhetag" exakt:
```swift
TrainingDay(name: "Ruhetag", weekday: nextWeekday, type: .rest, plan: plan)
```
Kein `customName`, kein `generationFingerprint`, keine Übungen, keine Sessions — **identisch** zu einem automatisch erzeugten, nie angefassten Ruhetag aus `ProgramInstantiator`. Der Code-Kommentar dort bestätigt sogar ausdrücklich die Absicht: *"Bei Ruhetagen lassen wir den User auf der Liste — er kann den Tag bei Bedarf umbenennen, aber muss nicht zwingend"* — ein Nutzer kann also bewusst einen Ruhetag anlegen und ihn dauerhaft unverändert als "Ruhetag" stehen lassen. Mit der aktuellen Datenlage lässt sich dieser Fall NICHT vom automatisch gefüllten Platzhalter unterscheiden — beide haben identische Feldwerte.

**Das ist keine Lücke, die sich im Plan-Text präzisieren lässt — es ist eine echte Grenze des heutigen Datenmodells.** Drei Optionen, zur Entscheidung vorgelegt (Hard Constraint: Datenmodell-Frage, nicht einseitig zu entscheiden):

- **(a) Neues, persistiertes Merkmal** (Datenmodell-Änderung): z.B. `TrainingDay.isAutoFilledPlaceholder: Bool`, ausschließlich von `ProgramInstantiator`s Auto-Fill auf `true` gesetzt, überall sonst (inkl. `PlanEditorView.createNewDay`) implizit `false`. Zuverlässig, unabhängig von Namens-/Umbenennungs-Zufällen, aber eine Schema-Änderung mit Migration (additiv, lightweight, wie andere optionale Felder in diesem Modell).
- **(b) Kein Schema-Wechsel — Transparenz statt Herkunftsnachweis:** jede Einfügung zeigt in der ohnehin vorhandenen Vorschau (`CoachAdjustmentPreviewView`) explizit JEDEN betroffenen Wochentag, auch wenn er zuvor schon "Ruhetag" hieß — derselbe "sichtbar statt blockierend"-Grundsatz wie beim Equipment-Status. Schützt nicht vor einem Nutzer, der die Vorschau nicht genau liest, verlangt aber keine Datenmodell-Änderung.
- **(c) Hybrid ohne Schema-Wechsel:** wie (b), zusätzlich eine EINZELNE, explizite Bestätigung pro betroffenem Tag statt eines Sammel-"Übernehmen"-Buttons — mehr Reibung als Schutz, aber ohne neues Feld.

**Entscheidung des Auftraggebers (2026-10-25): Option (a).** `TrainingDay.isAutoFilledPlaceholder: Bool`, additiv, Default `false`. Vier Bedingungen wurden dazu ausdrücklich verlangt und sind unten in Task 5/6 eingearbeitet:
1. Migration/Initialisierung: bestehende Datensätze erhalten `false` ohne jeden Versuch, Herkunft aus `name == "Ruhetag"` zu erraten.
2. Alle Erzeugungspfade geprüft, nicht nur der offensichtliche.
3. Re-Validierung unmittelbar vor der Mutation: `isAutoFilledPlaceholder == true` UND weiterhin `.rest`, keine aktiven Übungen, keine Sessions, richtiger Plan.
4. Rollback vollständig getestet: `day.type`, Übungsdaten, Fingerprint und jedes weitere von `apply` geänderte Feld müssen bei einem Fehlschlag wiederhergestellt werden — für den bestehenden Ersetzungspfad UND den neuen Einfügepfad gleichermaßen.

### Zwei zusätzliche, beim Nachprüfen gefundene und bereits behobene Lücken

1. **Plan-Zugehörigkeit nicht geprüft:** `insertCoachCardioDays(restDays:newCardioDays:in:)` hatte keinen `plan`-Parameter und konnte deshalb nie prüfen, ob jeder Zieltag tatsächlich noch zu DEM Plan gehört, für den die Einfügung gedacht ist. Behoben in Task 6 (Signatur um `plan: TrainingPlan` ergänzt, Prüfung `day.plan?.persistentModelID == plan.persistentModelID` vor jeder Mutation).
2. **`day.type` bleibt nach dem Einfügen fälschlich `.rest`:** `PlanGeneratorInstantiator.apply(_:to:...)` setzt `day.type` nirgends (verifiziert durch Lesen der vollständigen Funktion) — beim bestehenden Ersetzungspfad unproblematisch, weil ein Cardio-Tag dort immer schon vorher den richtigen Typ hatte. Bei einer Einfügung in einen vormaligen `.rest`-Tag bliebe `type == .rest`, obwohl der Tag jetzt Cardio-Inhalt hat — `RunCoachPlanAdjustment.isCardioDay` selbst kommt damit zurecht (prüft Übungen, nicht nur `type`), aber jeder andere Code, der direkt auf `day.type == .rest` prüft (z.B. `DashboardView.swift:2135`), würde den Tag weiterhin als Ruhetag anzeigen. Behoben in Task 6: `apply` bekommt einen neuen, optionalen `targetType: DayType? = nil`-Parameter (bei `nil` exakt das heutige Verhalten, kein bestehender Aufrufer ändert sich), `insertCoachCardioDays` übergibt `targetType: .cardio` (der dafür vorgesehene, dedizierte Typ laut `DomainEnums.swift:106-109`); `DayMutationSnapshot`/`revert` werden um `oldType` ergänzt, damit ein fehlgeschlagener Einfüge-Versuch auch den Typ zuverlässig zurücksetzt.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, multi-module Swift Package (`FitnessAppCore`, `FitnessAppData`, `FitnessAppUI`), XCTest.

**Spec:** `docs/PLANUNG_BEGLEITUNG_AUDIT.md`, section "Manueller Gerätetest nach PR #2: zwei neue, vorbestehende Architekturbefunde (2026-10-25)" — contains both root-cause findings and the user's binding product decisions this plan implements.

## Global Constraints

- Hard constraint carried over from the Laufcoaching-Remediation rounds: if a task reveals that a further product decision or data-model change is needed beyond what this plan already specifies, stop and ask instead of deciding unilaterally.
- No merge, no PR update beyond this plan's own branch commits, until the user has reviewed and approved. CI must stay green after every commit (per established project convention).
- Existing behavior for all 10 equipment-*identity* templates (Kettlebell*, Powerlifting*, Home Gym Hero, Bodyweight Mastery, CrossFit*) AND for the 7 purely-generic templates left untouched per A4 (`fullBody`, `fatLossFullBody`, `pushPullLegs`, `upperLower`, `arnoldSplit`, `broSplit`, `footballAthletic`) must stay byte-identical for every profile — these are regression-tested, not just "should still work". Only the 3 hybrid templates' resolution behavior is allowed to change, and only within the bounds of their migrated `reviewedAlternatives` data.
- `PaceCalculator.parseDurationToSeconds`, `PaceCalculator.parseFiveKReferenceSeconds`, `CardioExerciseZone`, `CoachAdjustmentCardModel.proposedGoal`/fingerprint logic, and every other Round-2/Finding-B deliverable are out of scope and must not be modified.
- `ExerciseSubstitutionEngine`, `ReviewedSubstitutionRule`, `ReviewedSubstitutionCatalog`, and `PlanEquipmentChecker`/`PlanEquipmentGap`/`PlanEquipmentReport` are out of scope and must not be modified, duplicated, or bypassed. No new `ReviewedSubstitutionRule` entries are an automatic part of this plan — if a task's own research finds a slot with no viable alternative, the gap is surfaced (ledger ruling + Review Focus note), never silently filled with an unreviewed substitute.
- `python .scripts/dead_catalog_v3.py` must report `UNUSED: 0` after every task that touches `Localizable.xcstrings`.
- New/changed pure logic that does NOT need a SwiftData model type (e.g. `UserEquipmentProfile`/`DaySpec`-based logic) lives in `FitnessAppCore`, matching `PlanEquipmentChecker`/`ExerciseSubstitutionEngine`, for Windows-CI testability. Logic that necessarily takes a SwiftData model type as a parameter (`TrainingPlan`/`TrainingDay`) lives in `FitnessAppData` even when otherwise side-effect-free, matching `RunCoachPlanAdjustment` (its ENTIRE file is `FitnessAppData`, not split — corrected per the seventh review round's P1 finding, which first surfaced this exact class of mistake for `ActivePlanResolver`) and `ProgramInstantiator`.
- Any SwiftUI-layer test that cannot be compiled on Windows follows the established pattern in this codebase: source-introspection tests (grep-style assertions on the file contents), verified by both the implementer and the task reviewer via direct reading.

## Offene Architekturfragen & Empfehlungen

**A1 (Equipment-Scope): Welche Templates bekommen dynamische Equipment-Auflösung?** *(nach Review in zwei Stufen verfeinert, siehe A4)*
Zwei Gruppen von 10 Templates lassen sich klar unterscheiden: die "equipment-generischen" (`fullBody`, `fatLossFullBody`, `pushPullLegs`, `upperLower`, `arnoldSplit`, `broSplit`, `footballAthletic`, `hybridBeginner`, `hybridBalanced`, `hybridPerformance`) gegenüber den "equipment-identitätsstiftenden" (`homeGymHero`, `bodyweightMastery`, `crossfitBodyweightRx`, `crossfitBodyweightScaled`, `crossfitWeighted`, `kettlebellBeginner`, `kettlebellAdvanced`, `kettlebellComplexes`, `powerlifting5x5`, `powerlifting3x5`). Die zehn identitätsstiftenden bleiben in JEDEM Fall unverändert fest verdrahtet (A1 unverändert).
Begründung für diese erste Abgrenzung: deren Name/Identität IST eine Geräte-Entscheidung — wer "Kettlebell Beginner" wählt, hat damit bereits Kettlebell gewählt; Vielfalt dort würde die Auswahl selbst unterlaufen.
Innerhalb der zehn generischen Templates gilt nach der Review eine ZWEITE, engere Grenze (siehe A2/A4): **nur die 3 Hybrid-Templates bekommen in diesem Plan tatsächlich eine Code-Änderung**, weil nur sie bereits kuratierte, geprüfte Equipment-Alternativen besitzen (ihre heutigen `equipmentVariants`), die verlustfrei migriert werden können. Die anderen 7 generischen Templates (`fullBody`, `fatLossFullBody`, `pushPullLegs`, `upperLower`, `arnoldSplit`, `broSplit`, `footballAthletic`) bleiben in DIESEM Plan ebenfalls unverändert — ihnen fehlt die kuratierte Grundlage, die Punkt A2/A4 für eine verantwortbare Auflösung voraussetzt. Nur eine reine Analyse (Task 2) liefert die Entscheidungsgrundlage für eine mögliche separate Content-Review.

**A2 (Equipment-Mechanismus): Template-Variants erweitern, dynamisch generieren, oder Hybrid?** *(nach Review revidiert — kein offener Katalog-Suchlauf mehr)*
Empfehlung: Hybrid, aber mit einer bewusst ENGEN Definition von "dynamisch". Templates bleiben die Autorität für Struktur (Tage/Woche, Split-Art, Schwierigkeit, Ziel-Tags). Jede Übung wird als Slot definiert: `defaultExerciseName` (die kuratierte Standard-Übung) plus `reviewedAlternatives: [String]` — eine EXPLIZIT AUTORISIERTE, kurze Liste bereits bekannter, gleichwertiger Alternativen für denselben Bewegungsreiz, keine Muskelgruppe/Rolle/Schwierigkeits-Suche im gesamten Katalog. Für die 3 Hybrid-Templates ist diese Liste nichts Neues: sie ist exakt die Übung, die heute schon in der jeweiligen `dumbbellOnly`/`kettlebellOnly`-`equipmentVariants`-Fassung für diesen Slot steht — eine 1:1-Migration bereits kuratierter Daten, keine Heuristik, die eine kuratierte Entscheidung erraten müsste. Resolution pro Slot ist eine strikte Drei-Zustände-Regel: kuratierte Übung mit vorhandenem Equipment ausführbar → unverändert übernehmen; eine `reviewedAlternative` mit vorhandenem Equipment ausführbar → diese verwenden; keine der beiden ausführbar → **kein Fallback auf die ursprüngliche, nicht ausführbare Übung** — die Lücke wird über das bestehende `PlanEquipmentChecker`/`PlanEquipmentGap`-Reporting sichtbar gemacht (gleiche Mechanik wie heute bei `ExerciseSubstitutionEngine`), nie stillschweigend als gelöst behandelt.
Begründung: ein offener Katalog-Suchlauf nach Muskelgruppe/Rolle/Schwierigkeit (die ursprünglich vorgeschlagene Fassung) kann nicht garantieren, dass der Trainingsreiz/das Bewegungsmuster erhalten bleibt — genau der vom Auftraggeber benannte Widerspruch zur bestehenden, bewusst eng gehaltenen `ExerciseSubstitutionEngine`. Eine begrenzte, autorisierte Alternativen-Liste pro Slot vermeidet das vollständig: jede Alternative, die je vorgeschlagen wird, war entweder schon vorher kuratiert (Hybrid-Templates) oder muss es noch werden (siehe A4). Das vermeidet außerdem die bei systematischen `equipmentVariants` entstehende 3-4-fache Datenduplizierung.

**A3 (Equipment-Priorität): Ersatz für `EquipmentProfile.priority`?**
Empfehlung: Für die 3 konvertierten Hybrid-Templates entfällt die ganze-Template-Variantenwahl komplett (jeder Slot löst unabhängig auf, keine 3 konkurrierenden Varianten mehr) — die Prioritätsfrage verschwindet dort, statt eine neue Rangfolge zu brauchen. `EquipmentProfile`/`.priority` bleiben unverändert für alle 17 übrigen Templates (10 Identity-Templates + 7 generische Templates ohne jede Alternativen-Daten, siehe A4), wo sie weiterhin ihren ursprünglichen Zweck erfüllen (Template-Auswahl im `PlanMatchmaker`, nicht Inhalts-Variation).

**A4 (Umfang, NEU nach Review): Was passiert mit den 7 rein-generischen Templates ohne jede Equipment-Alternative?**
`fullBody`, `fatLossFullBody`, `pushPullLegs`, `upperLower`, `arnoldSplit`, `broSplit`, `footballAthletic` haben HEUTE keine einzige kuratierte Equipment-Alternative pro Übung — anders als die 3 Hybrid-Templates gibt es hier keine vorhandenen Daten, die 1:1 migriert werden könnten. Ihnen jetzt neue `reviewedAlternatives` zu geben hieße, UNAUTORISIERTE Ersatzübungen zu erfinden — genau das, was Punkt 1/2 der Review ausdrücklich ausschließen und was der Auftraggeber bereits als "keine automatische Ausweitung" markiert hat.
Empfehlung: Dieser Plan ändert an diesen 7 Templates NICHTS (sie verhalten sich exakt wie die 10 Identity-Templates: fester Inhalt, `ExerciseSubstitutionEngine` als einzige Lücken-Behebung bei fehlendem Equipment). Task 2 (unten) liefert dafür ausschließlich eine Ist-Stand-Analyse — welche Slots bei welchen eingeschränkten Profilen tatsächlich eine Lücke hätten — als Entscheidungsgrundlage für eine SEPARATE, vom Auftraggeber zu beauftragende Content-Review, nicht als Teil der Umsetzung dieses Plans. Diese Entscheidung liegt beim Auftraggeber (Hard Constraint: Produktentscheidung, nicht einseitig zu treffen).

**B1 (Laufcoaching-Einfügen): Wie werden neue Cardio-Tage technisch eingefügt?** *(Eignungsprüfung nach Review verschärft — siehe Dritte/Fünfte Review-Runde, hier nur noch der technische Grundmechanismus)*
Empfehlung: kein Array-Insert nötig — jeder Plan hat bereits für jeden Wochentag ohne Workout einen `.rest`-`TrainingDay` (`ProgramInstantiator.instantiate`). "Neuen Cardio-Tag hinzufügen" heißt: einen geeigneten `.rest`-Tag mit `PlanGeneratorInstantiator.apply(_:to:...)` (`targetType: .cardio`, siehe Task 6) in einen Cardio-Tag umwandeln. Die tatsächliche, endgültige Eignungsprüfung ist `RunCoachPlanAdjustment.isEligibleRestDayForInsertion` (fünf Bedingungen inkl. `isAutoFilledPlaceholder == true`, siehe Task 5) — NICHT die hier ursprünglich skizzierte einfache `type == .rest && activeExercises.isEmpty && sessions.isEmpty`-Prüfung, die sich im Review als unzureichend erwies (ein manuell angelegter Ruhetag erfüllt diese drei Bedingungen identisch, siehe Dritte Review-Runde).
Begründung: wiederverwendet die bereits bewährte, getestete Persistenz-Mechanik vollständig; einziger neuer Code ist die Eignungsprüfung und die Auswahl, welche/wie viele Rest-Tage konvertiert werden.

**B2 (Laufcoaching-UI): Neuer Screen oder bestehende Vorschau erweitern?**
Empfehlung: `CoachAdjustmentPreviewView` erweitern (nicht neu bauen) — sie zeigt im `.ready`-Fall bereits beide Optionen nebeneinander ("Apply to current plan" / "Create new plan"). Der `.noEligibleCardioDay`-Fall zeigt heute nur "Create new plan"; dort muss künftig auch "Apply to current plan" erscheinen, mit eingefügten Tagen als "— (neu)" statt eines durchgestrichenen alten Namens in der Vorher/Nachher-Liste.

**B3 (Mehrere aktive Pläne): Reicht das bestehende Datenmodell für Option B?**
Empfehlung: Datenmodell reicht (mehrere aktive Pläne sind bereits bewusst unterstützt), aber `DashboardView`s nicht-deterministisches `activePlans.first` (13 Aufrufstellen) muss für die Cardio-relevanten Karten behoben werden, sonst reproduziert Option B exakt die bei der TestingBot-Abnahme gefundene Verwirrung (zwei "ACTIVE"-Pläne, falsche Karten-Zuordnung). Das gehört zwingend in diesen Plan, nicht als Folgearbeit.

## Review Focus

- Ein `.unresolved` Slot (Task 1/3) wird IMMER sichtbar gemacht, nie durch die ursprüngliche, nicht ausführbare Übung kaschiert — das ist der konkrete Fehlerfall, den die Review unter Punkt 2 explizit verlangt hat.
- Equipment-Auflösung ist deterministisch — gleiches Profil + gleiches Template ergibt immer dieselbe Übungsauswahl (kein Zufall außerhalb des expliziten "Neu rechnen").
- Rest-Tag-Einfügung darf NIE einen Tag mit bereits geloggten Sessions oder manuell erstellten/editierten Übungen anfassen, auch nicht indirekt über eine falsch sortierte Tagesliste.
- Die explizite A/B-Wahl darf bestehendes `isAlreadyApplied`/Fingerprint-Verhalten aus Runde 2 nicht brechen (ein zweiter Tap auf bereits Angewendetes bleibt ein No-Op).
- Dashboard-Determinismus-Fix darf bei GENAU EINEM aktiven Plan (der heute weit überwiegende Fall) keine sichtbare Verhaltensänderung erzeugen.
- Ein nicht vollständig geloester Equipment-Status (`.unavailable`/`.unknown`) blockiert die Plan-Uebernahme NICHT (Vierte Review-Runde, Entscheidung 1) — er muss aber sichtbar bleiben, auch NACH der Uebernahme, nicht nur in der Vorschau.
- Eine vollstaendig verfuegbare Ausstattung darf NIEMALS eine kuratierte Standard-Uebung verdraengen, die selbst ausfuehrbar ist — Vielfalt ist ein moegliches Ergebnis, nie ein eigenes Ziel (Task 11, Schritt 2a).

---

## Phase A — Equipment-Vielfalt

### Task 1: `TemplateSlot` + bounded three-state resolver (no open catalog search)

**Files:**
- Create: `Sources/FitnessAppCore/Programs/TemplateSlotResolver.swift`
- Test: `Tests/FitnessAppCoreTests/TemplateSlotResolverTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct TemplateSlot: Sendable, Equatable {
      public let defaultExerciseName: String       // today's curated/original exercise for this slot
      public let reviewedAlternatives: [String]     // explicitly authorized alternative exercise names, priority order
      public let sets: Int
      public let repsMin: Int
      public let repsMax: Int
      public let restSeconds: Int
  }

  public enum SlotResolution: Sendable, Equatable {
      case `default`(ExerciseSpec)                  // defaultExerciseName's equipment is satisfied
      case alternative(ExerciseSpec, usedName: String) // a reviewedAlternatives entry's equipment is satisfied
      case unresolved(PlanEquipmentGapReason)        // neither is satisfied - caller MUST surface this, never substitute silently
  }

  public enum TemplateSlotResolver {
      /// Strict three-state, no catalog-wide search: tries ONLY
      /// `slot.defaultExerciseName`, then each of `slot.reviewedAlternatives`
      /// in order, each checked via the existing, unmodified
      /// `EquipmentRequirement.evaluate(against:)` (same contract
      /// `PlanEquipmentChecker` already uses). The first candidate whose
      /// evaluation is EXACTLY `.satisfied` wins (quality-first: default
      /// always tried first). Seventh review round, P2c: `.unknown` is
      /// NEVER treated as a win, for the default OR any alternative -
      /// `UserEquipmentProfile.gymDefault` deliberately leaves some items
      /// `.unknown` (kettlebell/band), and silently accepting `.unknown` as
      /// "good enough" would defeat the whole point of this three-state
      /// design. If every candidate ends on `.unmet`/`.unknown`, the slot is
      /// `.unresolved` - with reason `.missing(...)` if the LAST-evaluated
      /// candidate (conventionally the default, for a single-candidate case)
      /// was `.unmet`, or `.uncertain(...)` if it was `.unknown` - same
      /// `.missing`-wins-over-`.uncertain` aggregation `PlanEquipmentChecker`
      /// already uses elsewhere, just scoped to one slot. No candidate
      /// outside this fixed, pre-authorized list is ever considered -
      /// `ExerciseSubstitutionEngine`/`ReviewedSubstitutionRule` remain the
      /// only mechanism that picks from the wider catalog, and this
      /// function does not call or duplicate it. An `.unresolved` slot's
      /// exercise in the caller's `days` (Task 3) is a TRANSPARENT PREVIEW
      /// of the unmet default, never a claim that it was resolved — the
      /// caller's `equipmentStatus` (Task 4) must never report `.available`
      /// while any slot is `.unresolved`.
      public static func resolve(slot: TemplateSlot, against profile: UserEquipmentProfile) -> SlotResolution
  }
  ```
- Consumes: `EquipmentRequirement.evaluate(against:)` and `ExerciseLibraryData.byName` (existing, unchanged — only used to look up the already-named candidates' own `ExerciseSpec`/requirement, never to search), `PlanEquipmentGapReason` (existing, reused for the `.unresolved` case so gap reporting stays consistent with `PlanEquipmentChecker`'s established vocabulary).

- [ ] **Step 1: Read `Sources/FitnessAppCore/Programs/EquipmentRequirement.swift` and `Sources/FitnessAppCore/Programs/ExerciseLibraryData.swift` in full** to confirm `equipmentRequirement`'s exact type/field name and `ExerciseLibraryData.byName`'s exact signature. Record any naming mismatch before writing Step 2's tests.

- [ ] **Step 2: Write failing tests**
  ```swift
  func test_resolve_keepsDefaultExercise_whenEquipmentAvailable() {
      // slot.defaultExerciseName = "Barbell Bench Press", reviewedAlternatives = ["Dumbbell Bench Press"],
      // profile has barbell+dumbbell+machine+cable -> expect .default("Barbell Bench Press") - quality-first, no forced substitution even though an alternative would also work
  }
  func test_resolve_usesFirstSatisfiedAlternative_whenDefaultEquipmentMissing() {
      // slot.defaultExerciseName = "Barbell Bench Press" (unsatisfied), reviewedAlternatives = ["Dumbbell Bench Press", "Machine Chest Press"],
      // profile has only dumbbell -> expect .alternative("Dumbbell Bench Press", usedName: "Dumbbell Bench Press")
  }
  func test_resolve_isDeterministic_acrossRepeatedCalls() {
      // same slot + same profile, called 5x -> identical result every time
  }
  func test_resolve_returnsUnresolved_neverSilentFallback_whenNothingSatisfiable() {
      // default AND every reviewedAlternatives entry unsatisfied -> expect .unresolved(...), NEVER .default/.alternative with an unexecutable exercise
  }
  func test_resolve_treatsUnknownAsNotSatisfied_neverAsAWin() {
      // Seventh review round, P2c: profile is UserEquipmentProfile.gymDefault
      // (kettlebell left .unknown), slot's default AND only alternative both
      // require kettlebell -> EquipmentRequirement.evaluate returns .unknown
      // for both, NOT .satisfied -> expect .unresolved(.uncertain(...)),
      // never .default/.alternative just because nothing was definitively
      // "missing"
  }
  func test_resolve_neverConsidersExerciseOutsideDefaultAndReviewedAlternatives() {
      // a profile that would satisfy some OTHER catalog exercise of the same muscle (not in reviewedAlternatives) -> still .unresolved, confirms no open catalog search happens
  }
  ```

- [ ] **Step 3: Run tests, verify they fail** (`swift test --filter TemplateSlotResolverTests`).

- [ ] **Step 4: Implement `TemplateSlot`/`SlotResolution`/`TemplateSlotResolver`** per the Interfaces block above. No fallback to an unexecutable exercise anywhere in this function — `.unresolved` is a first-class, always-possible outcome every caller must handle.

- [ ] **Step 5: Run tests, verify they pass.**

- [ ] **Step 6: Commit** (`feat: add bounded, three-state equipment slot resolver`).

### Task 2: Equipment-gap analysis for the 7 purely-generic templates (no code change to their content)

**Files:**
- Create: `.superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path/generic-template-equipment-gap-analysis.md`
- Test: none (pure analysis task, no production code changes — see Open Question A4)

Per A4, `fullBody`/`fatLossFullBody`/`pushPullLegs`/`upperLower`/`arnoldSplit`/`broSplit`/`footballAthletic` get **no new `reviewedAlternatives` in this plan** — inventing them would be exactly the unauthorized substitution the review flagged. This task only produces the evidence the user needs to decide whether a follow-up content-review is worth commissioning.

- [ ] **Step 1: Define exactly four test profiles explicitly** (do not assume unnamed ones):
  1. `UserEquipmentProfile.gymDefault` (`Sources/FitnessAppCore/Programs/EquipmentPlanningContext.swift:98-108` — NOT `EquipmentRequirement.swift`, correcting the first plan draft's wrong file reference). Note its documented quirk: kettlebell and resistance band are deliberately `.unknown` here, not `.unavailable` — carry this distinction through to Step 2, do not treat `.unknown` as `.unavailable`.
  2. A `dumbbellOnly` profile: `.dumbbell` explicitly `.available`, every other item explicitly `.unavailable` (not left `.unknown` — this profile must represent "confirmed, nothing else owned", matching `confirmedComplete == true` semantics).
  3. A `bodyweightOnly` profile: every item explicitly `.unavailable`.
  4. A `machineOnly` profile: `.machine`/`.cableStation`/`.machineStation` (confirm exact `EquipmentItem` case names against `Sources/FitnessAppCore/Domain/DomainEnums.swift` or wherever `EquipmentItem` is defined before writing this) explicitly `.available`, every other item explicitly `.unavailable`.

- [ ] **Step 2: For each of the 7 templates × each of the 4 profiles, run the EXISTING, unmodified `PlanEquipmentChecker.fullReport(days:against:)`** against the template's current `days`. Record `missing` and `uncertain` as TWO SEPARATE lists per (template, profile) in the analysis file — never merge them into one undifferentiated "gap" count. A `.unknown`-availability item (like kettlebell in `gymDefault`) producing an `uncertain` finding means "not confirmed either way", which is a materially different, less urgent signal than a `missing` finding ("confirmed absent") — conflating them would misrepresent which gaps are real blockers versus simply unconfirmed inventory.

- [ ] **Step 3: Append a one-paragraph summary to `docs/PLANUNG_BEGLEITUNG_AUDIT.md`** stating whether real gaps were found, and if so, how many exercises across how many templates would need a reviewed alternative to close them — framed explicitly as a scope question for the user, not a recommendation to act on unilaterally.

- [ ] **Step 4: Commit** (`docs: equipment-gap analysis for equipment-generic templates without authored alternatives`).

### Task 3: Convert the 3 hybrid templates, delete redundant `equipmentVariants`

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/ProgramTemplates.swift` — convert `hybridBeginner`/`hybridBalanced`/`hybridPerformance` strength days to `slots:` (cardio days inside these templates stay untouched — they are not equipment-dependent), delete their `equipmentVariants:` arrays entirely (~250 lines per prior research) ONLY after Step 1's parity matrix passes
- Modify: `Sources/FitnessAppCore/Programs/ProgramTemplate.swift` — add `slots: [[TemplateSlot]]?` per day, additive and optional, parallel to `days: [DaySpec]` (every other template's `days` field is untouched)
- Modify: `Sources/FitnessAppCore/Programs/EquipmentVariant.swift` — remove `EquipmentVariant.bestMatch` only if Task 4 confirms no remaining caller needs it; keep `EquipmentProfile`/`.priority` (still used by the 17 untouched templates per A3)
- Test: `Tests/FitnessAppCoreTests/HybridTemplateSlotParityTests.swift`

**Interfaces:**
- Consumes: `TemplateSlotResolver.resolve`/`SlotResolution` (Task 1).
- Produces:
  ```swift
  public struct SlotAlternativeUsage: Sendable, Equatable {
      public let dayIndex: Int
      public let exerciseIndex: Int
      public let originalName: String   // slot.defaultExerciseName
      public let usedName: String       // the reviewedAlternatives entry actually used
  }

  public struct SlotResolutionResult: Sendable, Equatable {
      public let days: [DaySpec]                      // every slot filled: default, alternative, or (if unresolved) the UNCHANGED default exercise - never omitted, never faked
      public let gaps: [PlanEquipmentGap]              // one entry per .unresolved slot, using the DEFAULT exercise's own evaluate() reason (.missing or .uncertain) - empty when every slot resolved
      public let usedAlternatives: [SlotAlternativeUsage] // one entry per slot that used a reviewedAlternatives pick instead of the default
  }
  ```
  `ProgramTemplate.resolvedSlots(against profile: UserEquipmentProfile) -> SlotResolutionResult?` — `nil` for a template without `slots` (all 17 others, unaffected). This is a pure, Task-4-internal helper: Task 4 is responsible for turning it into the existing `ResolvedPlanSelection`/`PlanEquipmentStatus` vocabulary that `PlanSelectionResolver`/`ProgramTemplatePickerView` already understand — see Task 4's Interfaces for the exact mapping. This task does NOT invent a new UI-facing status type.

- [ ] **Step 1: Write a failing, EXHAUSTIVE parity matrix test** — for each of the 3 hybrid templates × each of their today-existing `equipmentVariants` profiles (`dumbbellOnly`, `kettlebellOnly` per prior research) × every strength slot in every day: assert `resolvedSlots(against:)?.days` produces the EXACT SAME exercise name as today's hand-authored `equipmentVariants` entry for that (template, profile, slot) triple, and that `gaps` is empty for all three profiles (base, dumbbellOnly, kettlebellOnly) since every one of these was previously a fully-authored, fully-available variant. This matrix is the parity proof the review asked for — not a handful of spot checks.

- [ ] **Step 2: Run the matrix test, verify it fails (code doesn't exist yet).**

- [ ] **Step 3: Add `slots` to `ProgramTemplate`, convert the 3 templates' strength days to slots** — for each slot, `defaultExerciseName` = today's base-variant exercise name, `reviewedAlternatives` = exactly the exercise name(s) found in Step 1's matrix for that slot across `dumbbellOnly`/`kettlebellOnly` (a direct, lossless transcription of the existing hand-authored data, not a derived guess). Implement `resolvedSlots(against:)`.

- [ ] **Step 4: Run the matrix test, verify it passes for every cell.** If any cell cannot be made to match (the old variant's choice genuinely isn't reconstructable as a simple default/alternative, e.g. it depends on something beyond equipment), STOP and report it as a ledger ruling rather than approximating — this is exactly the case the review warned about.

- [ ] **Step 5: Only once Step 4 is fully green, delete the 3 templates' old `equipmentVariants` arrays** and re-run the full `FitnessAppCoreTests` suite.

- [ ] **Step 6: Commit** (`refactor: replace hybrid templates' duplicated equipmentVariants with slot resolution`).

### Task 4: Wire slot resolution into `PlanSelectionResolver` (reusing the existing `ResolvedPlanSelection`/`PlanEquipmentStatus` vocabulary) + make equipment gaps visible on an ALREADY-SAVED plan

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/ResolvedPlanSelection.swift` — `PlanSelectionResolver.resolve` gains an early branch: `if let slotResult = template.resolvedSlots(against: profile) { ... }`, returning a `ResolvedPlanSelection` built from it (see Interfaces), BEFORE the existing `bestEquipmentCheckedVariant`/`ExerciseSubstitutionEngine` logic runs. All 17 `slots == nil` templates fall through to today's exact, untouched code path.
- Create: `Sources/FitnessAppData/SavedPlanEquipmentCheck.swift` — fünfte Review-Runde, Präzisierung 1: a saved `TrainingPlan`'s equipment status is NOT re-derivable anywhere today (confirmed: no reference to `PlanEquipmentChecker`/`PlanEquipmentStatus` in `PlanEditorView.swift`/`DashboardView.swift`/`ExerciseDetailView.swift`). Pure, stateless re-check — no new persisted field:
  ```swift
  /// Baut aus den AKTUELLEN `activeExercises` eines gespeicherten Plans die
  /// minimale `[DaySpec]`-Repraesentation, die das bestehende, unveraenderte
  /// `PlanEquipmentChecker.fullReport(days:against:)` braucht (nur `name`
  /// wird für den Katalog-Abgleich benoetigt), und ruft es unveraendert auf.
  /// Reine Neuberechnung bei jedem Aufruf - kein gespeicherter Status, kein
  /// neues Feld auf `TrainingPlan`/`TrainingDay`.
  public enum SavedPlanEquipmentCheck {
      public static func report(for plan: TrainingPlan, against profile: UserEquipmentProfile) -> PlanEquipmentReport
  }
  ```
- Modify: `Sources/FitnessAppUI/Workout/PlanEditorView.swift` — add a simple banner row (reuse the visual pattern of `ProgramTemplatePickerView.equipmentStatusRow`, not a new component type) shown whenever `SavedPlanEquipmentCheck.report(for:against:).isFullyAvailable == false`, naming the affected exercises (same `missingItems`-style formatting `ProgramTemplatePickerView` already has). MUST be a `private var`/computed property read fresh in `body` (same pattern `ProgramTemplatePickerView.resolvedSelection`/`equipmentStatusBanner` already use), never cached into `@State`. Seventh review round, P2b — this view ALREADY has `@Query private var userProfiles: [UserBodyProfile]` (`PlanEditorView.swift:37`), so it already re-renders on any profile change elsewhere in the app; the new banner MUST derive its `UserEquipmentProfile` from THIS SAME existing `userProfiles` query (whatever accessor this view already uses to read the current profile from it), not from a separately-fetched or newly-added observation — reactivity then falls out of the view's existing structure, nothing new to wire up.
- Test: `Tests/FitnessAppCoreTests/PlanSelectionResolverSlotWiringTests.swift`, `Tests/FitnessAppDataTests/SavedPlanEquipmentCheckTests.swift`, `Tests/FitnessAppUITests/PlanEditorEquipmentGapBannerTests.swift` (source-introspection)

**Interfaces:**
- Consumes: `ProgramTemplate.resolvedSlots(against:)` / `SlotResolutionResult` (Task 3).
- Produces (mapping, inside `PlanSelectionResolver.resolve`'s new branch — no new public type):
  - `equipmentStatus`: mirror `PlanEquipmentChecker.check`'s existing aggregation rule EXACTLY (a definite `.missing` gap always wins over any `.uncertain` one): `slotResult.gaps.isEmpty` → `.available`; else if any gap's reason is `.missing` → `.unavailable(gaps: slotResult.gaps)`; else (all gaps are `.uncertain`/`.notAnnotated`) → `.unknown(gaps: slotResult.gaps)`.
  - `days`: `slotResult.days` unchanged (already contains the transparent, unresolved-but-unfaked content per Task 3).
  - `appliedAdaptation`: `nil` when `slotResult.usedAlternatives.isEmpty`; otherwise a `PlanAdaptationDraft` synthesized from `slotResult.usedAlternatives` so `ProgramTemplatePickerView.adaptedEquipmentBanner` renders unchanged — one `ExerciseReplacement` per usage (`ruleID: "slot:\(originalName)->\(usedName)"`, `reasonKey: "picker.plan.equipment.slotAlternative"` — new, single localization key, not a new banner), `unresolved: []` (unresolved slots are reported via `equipmentStatus`'s gaps instead, not duplicated here), `finalEquipmentStatus`/`validatorBlockers` matching this same `equipmentStatus`/`[]`.
  - `consideredButUnresolvedAdaptations`: `[]` (the slots path has exactly one outcome per profile, not multiple competing variant attempts — nothing else was "considered").
  - `variantProfile`: `nil` (slots resolution isn't tied to a single named `EquipmentProfile`).

- [ ] **Step 1a: Confirm every instantiation call site for the 3 converted templates actually goes through `PlanSelectionResolver.resolve`** (per `ProgramTemplatePickerView`'s own doc comment, "Vorschau UND Instanziierung duerfen nie auseinanderlaufen" — `ProgramInstantiator.instantiate(resolvedSelection:)` takes an already-resolved `ResolvedPlanSelection`). Grep every caller of `ProgramInstantiator.instantiate` and `template.bestEquipmentCheckedVariant`/`template.resolvedDays(forUserEquipment:)` directly — if any caller bypasses `PlanSelectionResolver.resolve` entirely for a template (e.g. a non-picker code path, onboarding default, or a test fixture), that caller would still use the OLD bar­bell-priority path for the 3 converted templates even after this task ships. Record every such bypass as a ledger note; fix the ones that are reachable by a real user flow in this same task (out of scope: internal test-only helpers that don't represent a real user path).

- [ ] **Step 1b: Write failing tests** — one confirming a `slots`-bearing template now resolves via Task 3's path end-to-end through `PlanSelectionResolver.resolve`, covering all three `equipmentStatus` outcomes (`.available` with no alternatives used, `.available`-via-`appliedAdaptation` with alternatives used — confirm `ProgramTemplatePickerView.adaptedEquipmentBanner`'s existing source renders it, via the established source-introspection pattern, and `.unavailable(gaps:)` with a genuinely unresolvable profile); one confirming every one of the 17 untouched templates' resolution is UNCHANGED (locate and re-run existing tests for `bestEquipmentCheckedVariant`/`PlanSelectionResolver` on those templates, do not just add new ones).

- [ ] **Step 2: Run tests, verify the new ones fail and the untouched-template ones still pass against current code.**

- [ ] **Step 3: Implement the branch in `PlanSelectionResolver.resolve` per the Interfaces mapping above. Add the one new `picker.plan.equipment.slotAlternative` localization key (en/de/tr) and run `python .scripts/dead_catalog_v3.py`, confirm `UNUSED: 0`.**

- [ ] **Step 4a: Confirm whether `EquipmentVariant.bestMatch` still has a real caller.** It was only ever used for templates with a populated `equipmentVariants` array; after Task 3 deleted the only 3 templates that had one, grep the whole codebase for callers. If none remain (expected outcome), delete `EquipmentVariant.bestMatch` and re-run `python .scripts/dead_catalog_v3.py` — this is the conditional cleanup Task 3's Files section deferred to this task, not an open item to silently drop.

- [ ] **Step 4b: Run the full `FitnessAppCoreTests`/`FitnessAppDataTests` suites, verify everything passes, no existing test for the 17 untouched templates changed its expected output.**

- [ ] **Step 5: Commit** (`feat: wire slot-based equipment resolution into PlanSelectionResolver`).

- [ ] **Step 6: Write failing tests for `SavedPlanEquipmentCheck`**, covering all four requirements from the sixth review round's Präzisierung 4:
  ```swift
  func test_report_matchesPlanEquipmentCheckerExactly_forEquivalentDaySpec() {
      // (1) same .missing/.uncertain classification: build a saved plan's
      // exercises AND the equivalent [DaySpec] by hand from the same data,
      // run both through their respective checker, assert identical results
  }
  func test_report_recomputesPurely_noCachingAcrossCalls() {
      // (2) calling report(for:against:) twice with two DIFFERENT profiles
      // on the SAME unchanged plan returns two DIFFERENT results - proves
      // the function itself has no memoization/caching that could make a
      // SwiftUI view show a stale result after the user changes their profile
  }
  func test_report_ignoresOtherPlansExercises() {
      // (3) two plans in the same context, one with a gap, one without -
      // report(for: planA, ...) never reflects planB's exercises
  }
  func test_report_emptyPlan_isFullyAvailable() {
      // (4) a plan whose days are all .rest with zero active exercises ->
      // isFullyAvailable == true, documented and pinned, not an accidental
      // "nothing to check" result nobody verified
  }
  ```

- [ ] **Step 7: Run tests, verify they fail.**

- [ ] **Step 8: Implement `SavedPlanEquipmentCheck` and the `PlanEditorView` banner** as a computed property, not `@State`, deriving its profile from the view's existing `userProfiles` query. Add a source-introspection test (`PlanEditorEquipmentGapBannerTests.swift`) confirming the banner's source references `SavedPlanEquipmentCheck.report(` directly inside a `body`/computed-property context (no intervening `@State`/cached variable), AND that it reads `userProfiles` rather than introducing a second, separate profile fetch.

- [ ] **Step 9: Run tests, verify they pass. Confirm via the acceptance test (Task 11) that a plan adopted with a visible gap (per Decision 1 — warn, not block) still shows that gap when the plan is reopened later, not only during the adoption preview.**

- [ ] **Step 10: Commit** (`feat: show equipment gaps on an already-saved plan, not only during adoption`).

---

## Phase B — Laufcoaching Dual-Path

### Task 5: Rest-day insertion eligibility

**Files:**
- Modify: `Sources/FitnessAppData/RunCoachPlanAdjustment.swift` — add:
  ```swift
  /// Rest-Tage, in die ein neuer Cardio-Tag eingefuegt werden darf.
  /// Herkunft wird durch `TrainingDay.isAutoFilledPlaceholder` bewiesen
  /// (Auftraggeber-Entscheidung, Option (a) — siehe "Dritte Review-Runde"),
  /// NICHT durch Name/Fingerprint/eine zufaellige Feldkombination geraten.
  /// FUENF Bedingungen, ALLE erforderlich (fünfte Review-Runde, Präzisierung 3
  /// — diese Funktion garantiert NUR die Tag-eigene Eignung; Plan-Zugehörigkeit
  /// und ausreichende Anzahl sind eine SEPARATE Garantie von
  /// `insertCoachCardioDays`, siehe dort): `isAutoFilledPlaceholder == true`
  /// (historischer Herkunfts-Beweis — bleibt nach einer erfolgreichen
  /// Einfuegung bewusst `true` stehen, exakt dasselbe Prinzip wie
  /// `generationFingerprint`: ein permanenter Erzeugungs-Stempel, kein
  /// "ist aktuell noch leer"-Live-Bit), `type == .rest`, `activeExercises.isEmpty`,
  /// `sessions.isEmpty` (drei Live-Zustands-Pruefungen), UND `customName == nil`
  /// (Vierte Review-Runde, Entscheidung 2: einziges ueber `DayEditorView`
  /// erreichbares Feld, das eine bewusste Nutzer-Absicht fuer GENAU diesen
  /// Tag ausdrueckt — unabhaengig von `isAutoFilledPlaceholder`, das nur die
  /// Herkunft, nicht die seitherige Nutzer-Absicht beweist).
  public static func isEligibleRestDayForInsertion(_ day: TrainingDay) -> Bool

  public static func eligibleRestDaysForInsertion(in plan: TrainingPlan) -> [TrainingDay] {
      plan.days.filter(isEligibleRestDayForInsertion)
  }
  ```
  `CardioAvailability` itself is **unchanged** (no new case) — it keeps describing only the replace-path (`.ready`/`.noEligibleCardioDay`/`.noActivePlan`) exactly as today, per the review's point 4. `Analysis` gains one new, independent field: `public let insertableRestDays: [PersistentIdentifier]` (empty array, never optional, when none exist). A plan can have a non-empty `cardioAvailability == .ready` AND a non-empty `insertableRestDays` at the same time (replaceable cardio days and convertible rest days are not mutually exclusive) — exactly why this is a second field, not a richer enum case.
- Modify: `Sources/FitnessAppData/TrainingDay.swift` — add `public var isAutoFilledPlaceholder: Bool = false` (new, additive, lightweight-migration field, same pattern as `localizationKey`/`generatorSequenceIndex`) and the matching `init` parameter, defaulted to `false` so every EXISTING call site compiles and behaves unchanged without being touched.
- Modify: `Sources/FitnessAppData/ProgramInstantiator.swift:191-198` — the auto-rest-day-fill call site, and ONLY this one, passes `isAutoFilledPlaceholder: true`.
- Audit every OTHER `TrainingDay(...)` call site (Condition 2 from the user's decision — confirmed exhaustive list as of this research pass, re-grep before implementing since line numbers may have shifted):
  - `Sources/FitnessAppUI/Workout/PlanEditorView.swift:990` (`createNewDay`, manual "add day" incl. "add rest day") — MUST NOT set it (stays `false` by omission). This is the exact call site that falsified the old `name == "Ruhetag"` heuristic; confirming it stays `false` is the whole point of this fix.
  - `Sources/FitnessAppUI/Workout/PlansListView.swift:844` (`dayCopy`, "duplicate plan") — MUST explicitly PRESERVE the source day's value: `isAutoFilledPlaceholder: day.isAutoFilledPlaceholder`. This is a real exception to "every other call site stays false": duplicating a plan that already had a genuine, untouched auto-rest-day should duplicate that TRUTH, not silently clear it to `false` (which would make a freshly-duplicated plan's legitimately-eligible rest days disappear) or silently set `true` unconditionally (which would wrongly mark a duplicated, already-customized day as eligible).
  - `Sources/FitnessAppData/ProgramInstantiator.swift:147` (actual workout-day creation, from a `DaySpec` with real exercises) — confirmed safe, no change: a day with content is never a placeholder by definition.
  - `Sources/FitnessAppUI/DashboardView.swift:2717`/`:2769` (ad-hoc workout days, `plan: nil`) — confirmed safe, no change: never attached to any `TrainingPlan.days`, irrelevant to this predicate.
  - `Sources/FitnessAppUI/PreviewSupport.swift` — SwiftUI preview fixtures only, no change needed.
  - `Sources/FitnessAppUI/DeviceAcceptanceFixturePaket3a.swift:106` — test/device-acceptance fixture; update if it specifically exercises the "auto rest day" scenario, otherwise leave as `false`.
  - `Sources/FitnessAppData/Export/DataImportService.swift:1436` (backup import) — extend per the file's own established, repeatedly-used pattern (identical to `generation_fingerprint`/`generator_sequence_index` immediately above it in the same function): read a new `is_auto_filled_placeholder` CSV column, `row.bool(...) ?? false` — an older backup without the column defaults to `false` (Condition 1: "don't guess", applied consistently to the backup round-trip, not only to the live SwiftData migration).
  - `Sources/FitnessAppData/Export/DataExportService.swift` (`buildDays`, the writer side of the same round-trip) — add the matching `is_auto_filled_placeholder` column so a plan exported AFTER this change and re-imported preserves the flag faithfully (without this, export→import would silently reset every genuinely-eligible day back to `false`).
- Test: `Tests/FitnessAppDataTests/RunCoachPlanAdjustmentInsertionTests.swift`, `Tests/FitnessAppDataTests/TrainingDayIsAutoFilledPlaceholderDefaultTests.swift` (fünfte→sechste Review-Runde: NICHT "...MigrationTests" benannt — siehe Präzisierung 2 unten, dieser Name würde einen Nachweis behaupten, den die Datei nicht erbringt)

- [ ] **Step 1: Write failing tests**
  ```swift
  func test_eligibleRestDaysForInsertion_includesAutoGeneratedRestDay() {
      // TrainingDay(type: .rest, isAutoFilledPlaceholder: true, no exercises, no sessions) -> included
  }
  func test_eligibleRestDaysForInsertion_excludesManuallyCreatedRestDay() {
      // REGRESSION FOR THE REVIEW'S FOUND GAP: a TrainingDay built exactly the
      // way PlanEditorView.createNewDay(type: .rest) builds one TODAY - name:
      // "Ruhetag", no customName, type: .rest, no exercises, no sessions, AND
      // isAutoFilledPlaceholder defaulting to false (that call site is never
      // changed) -> excluded. The old field-value coincidence that broke the
      // second review's heuristic no longer matters, because this predicate
      // no longer looks at name/customName at all.
  }
  func test_eligibleRestDaysForInsertion_excludesPreMigrationRestDay() {
      // Unit-level check: a TrainingDay constructed WITHOUT passing
      // isAutoFilledPlaceholder explicitly -> defaults to `false`, excluded
      // even though it is, structurally, a genuine old auto-rest-day. This is
      // the Condition-1 trade-off made explicit as a test, not a surprise:
      // insertion is unavailable for any plan instantiated before this change
      // ships, until the plan is recreated.
      //
      // Fünfte Review-Runde, Präzisierung 2: this project has no
      // VersionedSchema/SchemaMigrationPlan anywhere (confirmed by reading
      // AppSchema.swift) - every comparable additive field
      // (localizationKey, generatorSequenceIndex, activatedAt) relies
      // exclusively on SwiftData's automatic lightweight migration, with NO
      // dedicated migration test anywhere in this project. A bespoke
      // "build a real pre-change .sqlite fixture" test would introduce
      // test infrastructure with no precedent in this codebase, for a risk
      // identical to a dozen already-shipped fields that never needed it.
      // The test below - a real in-memory ModelContainer built from
      // AppSchema.types, matching Tests/FitnessAppDataTests/
      // ExperienceTrackBackfillTests.swift's established pattern exactly -
      // IS this project's established, accepted rigor level for this kind
      // of change. It still exercises real SwiftData model creation, just
      // not a historical on-disk file.
  }
  func test_modelContainer_trainingDayWithoutExplicitFlag_defaultsToFalse() {
      // Sixth review round: this is a MODEL-DEFAULT-AND-PERSISTENCE test,
      // explicitly NOT a migration test - it proves the new model's default
      // works and round-trips through a real ModelContainer, nothing more.
      // It does NOT prove an on-disk store created before this field existed
      // opens/migrates correctly (no test in this project proves that for
      // any comparable field - the automatic lightweight migration is a
      // documented assumption, not a tested one). Same
      // ModelContainer/Schema(AppSchema.types)/ModelConfiguration(isStoredInMemoryOnly: true)
      // setup as ExperienceTrackBackfillTests.setUpWithError() - insert a
      // TrainingDay via the init WITHOUT passing isAutoFilledPlaceholder,
      // save, re-fetch via a fresh FetchDescriptor, confirm
      // isAutoFilledPlaceholder == false and the container opened/saved
      // without error.
  }
  func test_eligibleRestDaysForInsertion_excludesRestDayWithLoggedSession() {
      // isAutoFilledPlaceholder: true, but day.sessions is non-empty -> excluded
  }
  func test_eligibleRestDaysForInsertion_excludesNonRestDay() {
      // isAutoFilledPlaceholder: true but type is a strength day -> excluded (should never actually occur together, defensive test)
  }
  func test_eligibleRestDaysForInsertion_excludesRestDayWithActiveExercises() {
      // isAutoFilledPlaceholder: true, type: .rest, but has an active exercise -> excluded
  }
  func test_eligibleRestDaysForInsertion_excludesManuallyRenamedAutoRestDay() {
      // Vierte Review-Runde, Entscheidung 2: isAutoFilledPlaceholder: true,
      // type: .rest, no exercises, no sessions, BUT customName: "Family Day"
      // (set via DayEditorView) -> excluded, despite a true origin proof -
      // customName signals the user engaged with this specific day since
  }
  func test_analyze_reportsInsertableRestDays_forZeroCardioPlan() {
      // "Ganzkörper 3x"-shaped plan (all strength + isAutoFilledPlaceholder rest days, no cardio day)
      // expect: cardioAvailability == .noEligibleCardioDay, insertableRestDays non-empty
  }
  func test_dataImportService_roundTrip_preservesIsAutoFilledPlaceholder() {
      // export a plan with a mix of true/false rest days, re-import, confirm each day's value survived
  }
  func test_dataImportService_olderBackupWithoutColumn_defaultsToFalse() {
      // a fixture CSV row missing the new column entirely -> imported day has isAutoFilledPlaceholder == false
  }
  func test_plansListView_duplicatePlan_preservesIsAutoFilledPlaceholder() {
      // source plan has one true and one false rest day -> dayCopy of each matches its source exactly
  }
  ```

- [ ] **Step 2: Run tests, verify they fail.**

- [ ] **Step 3: Implement the field, the one true-setting call site, the one preserving call site (duplicate), the export/import column, and `eligibleRestDaysForInsertion`/`Analysis`/`CardioAvailability` per Files above.**

- [ ] **Step 4: Run tests, verify they pass.** Check every existing caller of `Analysis`/`CardioAvailability` (grep) still compiles — this is an additive field, not a breaking rename. Re-grep ALL `TrainingDay(...)` call sites once more as a final check — the list above is this research pass's best-effort inventory, not guaranteed exhaustive after other code has moved.

- [ ] **Step 5: Commit** (`feat: detect insertable rest days for Laufcoaching plan adjustment`).

### Task 6: Weekday selection + insertion apply

**Files:**
- Modify: `Sources/FitnessAppData/PlanGeneratorInstantiator.swift`:
  - Extend `apply(_:to:...)` (unchanged for every existing caller) with a new, defaulted parameter: `targetType: DayType? = nil` — when non-`nil`, snapshots the day's current `type` into a new `DayMutationSnapshot.oldType` field and sets `day.type = targetType`; when `nil` (the default, used by every existing call site), behaves EXACTLY as today (confirmed: `apply` currently never touches `type` at all).
  - Extend `revert(_:in:)` (unchanged for every existing caller) to also restore `day.type = snapshot.oldType` when `oldType` is non-`nil` (it is `nil`, a no-op, for every existing replace-path call, since those never pass `targetType`).
  - Add a sibling to `applyCoachCardioAdjustment`:
  ```swift
  /// Wandelt ausgewaehlte Rest-Tage in neue Cardio-Tage um - reuses `apply(_:to:...)`
  /// mit `targetType: .cardio` (der dedizierte Typ fuer Lauf-/Rad-Tage,
  /// `DomainEnums.swift:106-109` - `apply` selbst setzt `type` sonst nie,
  /// verifiziert durch vollstaendiges Lesen der Funktion; ein eingefuegter
  /// Tag braucht den expliziten Typ-Wechsel weg von `.rest`, den der
  /// bestehende Ersetzungspfad nie brauchte, weil dort der Typ schon vorher
  /// stimmte).
  ///
  /// Re-Validierungs-Vertrag (Review-Punkt 5): die Sicherheit haengt NICHT
  /// von korrekter Verwendung durch den Aufrufer ab. Vor der ERSTEN Mutation
  /// prueft diese Funktion JEDEN Tag in `restDays` selbst erneut:
  /// (1) `day.plan?.persistentModelID == plan.persistentModelID` - gehoert
  /// der Tag ueberhaupt noch zu DIESEM Plan (Review-Punkt, zweiter Teil:
  /// "Zugehoerigkeit zum richtigen Plan"); (2)
  /// `RunCoachPlanAdjustment.isEligibleRestDayForInsertion(day)` - ist er
  /// JETZT noch eignungsfaehig (nicht nur zum Vorschau-Zeitpunkt). Verletzt
  /// auch nur EIN Tag eine der beiden Bedingungen, wirft die Funktion VOR
  /// jeder Schreiboperation (kein Teil-Ergebnis, kein gesetzter Fingerprint)
  /// - ebenso wenn `restDays.count < newCardioDays.count`.
  public static func insertCoachCardioDays(
      plan: TrainingPlan, restDays: [TrainingDay], newCardioDays: [DaySpec], in context: ModelContext
  ) throws -> Int
  ```
- Modify: `Sources/FitnessAppData/RunCoachPlanAdjustment.swift` — add a pure selection helper:
  ```swift
  /// Waehlt aus den eignungsfaehigen Rest-Tagen genau `count` aus (bevorzugt
  /// Tage NICHT direkt neben einem bereits existierenden harten Krafttag,
  /// best-effort - Platzkonflikt mit einem Nicht-Rest-Tag ist nie erlaubt).
  /// Deterministisch: gleiche Eingabe -> gleiche Auswahl (sortiert nach
  /// `weekday` vor jeder Auswahl-Entscheidung).
  public static func selectRestDaysForInsertion(
      eligible: [TrainingDay], count: Int, otherDays: [TrainingDay]
  ) -> [TrainingDay]
  ```
- Test: `Tests/FitnessAppDataTests/CoachCardioInsertionTests.swift`

**Interfaces:**
- Consumes: `RunCoachPlanAdjustment.eligibleRestDaysForInsertion` (Task 5), `CardioFeasibilityCalculator.runTypeMix(for:)`/`planGeneratorInput(for:cardioRunProfile:)` (existing, unchanged), `PlanGeneratorInstantiator.apply` (existing, unchanged).

- [ ] **Step 1: Write failing tests**
  ```swift
  func test_selectRestDaysForInsertion_isDeterministic() {
      // same eligible/otherDays input, called twice -> identical selection
  }
  func test_selectRestDaysForInsertion_avoidsAdjacentHardStrengthDay_whenAlternativeExists() {
      // 3 eligible rest days, one adjacent to a strength day, two not ->
      // picks the two non-adjacent ones first when count == 2
  }
  func test_insertCoachCardioDays_convertsRestDayToCardioContent() {
      // after: day.type == .cardio (not left as .rest), exercises match newCardioDays, generationFingerprint set
  }
  func test_insertCoachCardioDays_neverTouchesNonSelectedDays() {
  }
  func test_insertCoachCardioDays_throwsAndWritesNothing_whenADayBelongsToADifferentPlan() {
      // one of the passed-in restDays' `.plan` is some OTHER TrainingPlan
      // (e.g. stale reference from a different plan's earlier preview) ->
      // throws BEFORE any apply() call; zero days changed anywhere
  }
  func test_insertCoachCardioDays_revertOnFailure_restoresDayTypeToRest() {
      // Fünfte Review-Runde, Präzisierung 4 - the ACTUAL mechanics of this
      // code (confirmed by reading applyCoachCardioAdjustment fully): every
      // apply() call for every target day happens in-memory FIRST (each
      // producing its own DayMutationSnapshot), and only ONE single
      // save(context) call at the very end can fail - there is no
      // "day 1 persisted, day 2 failed" case, because nothing is persisted
      // until that one save(). So: use >= 2 restDays, force
      // saveOverrideForTesting to throw (the SAME existing test seam
      // applyCoachCardioAdjustment's own tests already use - reset it in
      // tearDown so it never leaks into another test's production-path
      // assertions), confirm apply() genuinely ran for BOTH days first (spy/
      // counter == 2 before the thrown error), then re-fetch and confirm,
      // for BOTH days: day.type == .rest again, archived exercises
      // un-archived, inserted exercises deleted, name/localizationKey/
      // timeFormat/etc. restored, generationFingerprint back to its prior
      // value - every field DayMutationSnapshot carries, for EVERY affected
      // day, not just one.
  }
  func test_applyCoachCardioAdjustment_replacePath_revertOnFailure_leavesTypeUnchanged() {
      // Condition 4 (user decision, "tested for both the existing replace
      // path and the new insert path"): the EXISTING applyCoachCardioAdjustment
      // never passes targetType (stays nil) - confirm its revert behavior is
      // byte-identical to before this task: day.type is whatever it was
      // (e.g. .cardio from a curated template, or .fullBody from a wizard
      // plan) both before AND after a simulated failure, i.e. oldType being
      // nil is a true no-op, not an accidental reset to some default
  }
  func test_insertCoachCardioDays_throwsAndWritesNothing_whenRestDaysCountIsInsufficient() {
      // restDays.count < newCardioDays.count -> throws BEFORE any apply() call;
      // re-fetch the plan afterwards, confirm zero days changed, no fingerprint set anywhere
  }
  func test_insertCoachCardioDays_throwsAndWritesNothing_whenAPassedRestDayIsNoLongerEligible() {
      // one of the passed-in restDays now has a logged session (added after
      // the caller computed `restDays` but before this call) -> throws BEFORE
      // any apply() call, regardless of what the caller passed in; re-fetch
      // the plan afterwards, confirm zero days changed
  }
  ```

- [ ] **Step 2: Run tests, verify they fail.**

- [ ] **Step 3: Implement both functions.** `insertCoachCardioDays` re-validates every `restDays` entry — plan identity (`day.plan?.persistentModelID == plan.persistentModelID`) AND eligibility (`RunCoachPlanAdjustment.isEligibleRestDayForInsertion`) — BEFORE calling `apply()` on any of them (plus the pre-write count check), passing `targetType: .cardio` to `apply`. Extend `DayMutationSnapshot` with `oldType: DayType?` and `revert` to restore it, per the Files section above — additive, confirmed no-op for every existing replace-path caller.

- [ ] **Step 4: Run tests, verify they pass.**

- [ ] **Step 5: Commit** (`feat: add rest-day-to-cardio insertion mechanics`).

### Task 7: `CoachAdjustmentCardModel` insertion support + preview UI

**Files:**
- Modify: `Sources/FitnessAppUI/Cardio/CoachAdjustmentCardModel.swift` — `make` must no longer return `nil`-equivalent-behavior when `cardioAvailability == .noEligibleCardioDay` but `insertableRestDays` is non-empty; `accept` gains an insertion branch using Task 6's functions. Per the re-validation contract: `accept` calls `RunCoachPlanAdjustment.eligibleRestDaysForInsertion(in: plan)` FRESH at call time (never reuses `self`'s `analysis.insertableRestDays` snapshot from `make`, same principle `eligibleDays`/`isAlreadyApplied` already follow in this type), selects `count` from `CardioFeasibilityCalculator.runTypeMix(for: effectiveProposedGoal)`'s run-day count, and surfaces `insertCoachCardioDays`'s thrown "insufficient rest days" error as a distinct, user-readable failure (not swallowed into a generic 0-count return) so the caller can show "plan changed since preview, please re-check" rather than silently doing nothing
- Modify: `Sources/FitnessAppUI/Cardio/CoachAdjustmentPreviewView.swift` — the `.noEligibleCardioDay` case (lines ~135-140 per prior research) must show the "Apply to current plan" button whenever `insertableRestDays` is non-empty; before/after list renders an inserted slot as `"— → <new day name>"` (no struck-through old name) instead of today's replace-only rendering
- Test: `Tests/FitnessAppUITests/CoachAdjustmentInsertionUITests.swift` (source-introspection style, matching Round-2's established pattern for FitnessAppUI tests that can't compile on Windows)

- [ ] **Step 1: Write failing tests** — source-introspection assertions confirming: `CoachAdjustmentCardModel.accept` calls `insertCoachCardioDays` when `cardioAvailability == .noEligibleCardioDay && !insertableRestDays.isEmpty`; `CoachAdjustmentPreviewView`'s `.noEligibleCardioDay` branch references the "Apply to current plan" action; the before/after rendering branches on inserted vs. replaced.

- [ ] **Step 2: Run tests, verify they fail.**

- [ ] **Step 3: Implement the model and UI changes.**

- [ ] **Step 4: Run tests, verify they pass. Implementer AND task reviewer independently hand-trace the control flow (per Round-2's established verification pattern for this untestable-on-Windows UI layer).**

- [ ] **Step 5: Commit** (`feat: support inserting new cardio days via the coach adjustment preview`).

### Task 8: Explicit Option A/B choice, replacing the silent fallback

**Files:**
- Modify: `Sources/FitnessAppUI/Cardio/CardioFeasibilityCardModel.swift` — `accept(profile:in:using:activePlan:)` (lines ~146-268 per prior research) currently silently branches between in-place adjustment and `createPlan`; this must instead present a choice (reusing `CoachAdjustmentPreviewView`'s now-dual-option UI from Task 7, OR routing through `CoachAdjustmentCardModel`'s model directly) whenever an active plan exists at all (regardless of whether it already has a cardio day) — i.e. the "Option B always available, Option A silently preferred when possible" behavior becomes "both visible, user picks."
- Create (if `CoachAdjustmentPreviewView` cannot represent the zero-active-plan-at-all case): no new file expected — confirm during Step 1 whether `CardioFeasibilityCardModel`'s only remaining job after this change is the "no active plan exists yet" case (straight to `createPlan`, no choice needed — nothing to choose between).
- Test: `Tests/FitnessAppUITests/CardioFeasibilityChoiceTests.swift`

- [ ] **Step 1: Re-read `CardioFeasibilityCardModel.swift` in full** to confirm exactly which call sites currently invoke its silent-fallback `accept`, and whether `CoachAdjustmentCardModel`'s card already supersedes it whenever an active plan exists (per `CoachAdjustmentCardModel`'s own doc comment: "neue Karte hat Vorrang, sobald ein aktiver Plan existiert"). If `CoachAdjustmentCardModel` already fully supersedes `CardioFeasibilityCardModel` whenever a plan is active, this task may reduce to: confirm `CardioFeasibilityCardModel`'s silent branch is genuinely unreachable once Task 7 ships (dead code to delete) rather than a second code path to fix. Record the finding as a ledger ruling either way before writing Step 2.

- [ ] **Step 2: Write failing tests for whichever outcome Step 1 confirms** — either "`CardioFeasibilityCardModel.accept`'s in-place branch is unreachable when an active plan exists, delete it and route exclusively through `CoachAdjustmentCardModel`" (source-introspection test confirming the dead branch is gone) or "the choice is surfaced explicitly in both models' UI" (test per Task 7's pattern).

- [ ] **Step 3: Run tests, verify they fail.**

- [ ] **Step 4: Implement per Step 1's finding.**

- [ ] **Step 5: Run tests, verify they pass.**

- [ ] **Step 6: Commit** (`fix: replace silent plan-adjustment fallback with explicit user choice`).

### Task 9: `ActivePlanResolver` — one documented, deterministic resolver for cardio cards

**Files:**
- Create: `Sources/FitnessAppData/ActivePlanResolver.swift` — **seventh review round, P1 correction:** the original draft placed this in `FitnessAppCore` as "pure logic, no SwiftData," but its interface takes `[TrainingPlan]` directly, and `TrainingPlan` is a `FitnessAppData` SwiftData model — `FitnessAppCore` cannot depend on it (layering violation, would not compile). Correct placement is `FitnessAppData`, alongside `RunCoachPlanAdjustment`/`ProgramInstantiator`, which already operate on `TrainingPlan` the same way. It is still "pure" in the narrower, still-meaningful sense that matters here: it takes an already-fetched `[TrainingPlan]` array, performs no new fetch and no mutation/save — a deterministic function over its input, just one that necessarily imports SwiftData for the parameter type.
- Modify: `Sources/FitnessAppUI/DashboardView.swift` — the coach-adjustment/missed-run-days card call sites (2 of the 13, per prior research — confirm exact line numbers before editing) call the new resolver instead of `activePlans.first`
- Test: `Tests/FitnessAppDataTests/ActivePlanResolverTests.swift` (uses the same in-memory `ModelContainer`/`AppSchema.types` pattern as `ExperienceTrackBackfillTests`, per the sixth review round's established-pattern finding — not a `FitnessAppCoreTests` file, since the type under test now lives in `FitnessAppData`), `Tests/FitnessAppUITests/DashboardActivePlanDeterminismTests.swift` (source-introspection)

**Interfaces:**
- Produces:
  ```swift
  public enum ActivePlanResolver {
      /// Eindeutige, dokumentierte Regel fuer "welcher aktive Plan ist der
      /// Laufcoaching-relevante" (Review-Punkt 6 - ersetzt die vage
      /// "generationSource == .cardioCoach ODER zuletzt aktiviert"-Formulierung):
      /// 1. Genau EIN Plan mit `generationSource == .cardioCoach` unter den
      ///    aktiven Plaenen -> dieser gewinnt immer.
      /// 2. KEIN Plan mit `generationSource == .cardioCoach` -> der einzige
      ///    aktive Plan gewinnt, wenn es nur einen gibt; bei mehreren
      ///    aktiven Nicht-Cardio-Plaenen (kein heute vorgesehener Fall,
      ///    aber moeglich) gibt es KEINE verlaessliche Zuordnung -> `nil`,
      ///    niemals ein geratener Plan.
      /// 3. MEHR ALS EIN Plan mit `generationSource == .cardioCoach`
      ///    (Grenzfall, z.B. zwei Laufcoaching-Vorgaenge nacheinander) ->
      ///    der mit dem SPAETESTEN `activatedAt` gewinnt, aber NUR wenn
      ///    dieser Wert unter den Kandidaten eindeutig ist. `TrainingPlan`
      ///    hat kein eigenes stabiles `id`-Feld (nur `activatedAt: Date?`,
      ///    sonst ausschliesslich SwiftDatas interne, dafuer nicht
      ///    vorgesehene `PersistentIdentifier`) - ein erfundener zweiter
      ///    Sortierschluessel waere eine stille, bedeutungslose Pseudo-
      ///    Ordnung. Bei echtem Gleichstand (identischer `activatedAt`-Wert
      ///    ODER mehrere `nil`) unter den Cardio-Coach-Kandidaten -> `nil`,
      ///    niemals eine von der Array-Reihenfolge abhaengige Wahl.
      public static func cardioRelevantPlan(among activePlans: [TrainingPlan]) -> TrainingPlan?
  }
  ```

- [ ] **Step 1: Re-grep all 13 `activePlans.first` call sites in the current code** (line numbers may have shifted since the research pass) and classify each: cardio-card-relevant (must be fixed now) vs. unrelated (plan name display, workout-session ownership, etc. — explicitly out of scope per this plan's Global Constraints, flag for a follow-up ledger note if any looks cardio-adjacent but wasn't in the original 2).

- [ ] **Step 2: Write failing tests**
  ```swift
  func test_cardioRelevantPlan_withOnePlan_returnsIt() {
      // exactly one active plan, any generationSource -> that plan (Review Focus: single-plan case unchanged)
  }
  func test_cardioRelevantPlan_withOneCardioCoachPlanAmongOthers_returnsIt() {
      // one .manual + one .cardioCoach active -> the .cardioCoach one
  }
  func test_cardioRelevantPlan_withMultipleNonCardioPlansAndNoCardioCoachPlan_returnsNil() {
      // no reliable signal -> nil, never a guess
  }
  func test_cardioRelevantPlan_withTwoCardioCoachPlans_returnsMostRecentlyActivated() {
      // distinct activatedAt values -> the later one, verified with the SAME
      // two plans passed in multiple different array orderings (not just once)
      // to prove the result does not depend on input order
  }
  func test_cardioRelevantPlan_withTwoCardioCoachPlans_identicalActivatedAt_returnsNil() {
      // exact same activatedAt value on both -> nil, checked in multiple array orderings
  }
  func test_cardioRelevantPlan_withTwoCardioCoachPlans_bothNilActivatedAt_returnsNil() {
      // both nil -> nil, checked in multiple array orderings
  }
  ```

- [ ] **Step 3: Run tests, verify they fail.**

- [ ] **Step 4: Implement `ActivePlanResolver`, fix the classified Dashboard call sites to call it** (passing the already-fetched `activePlans` array — no new `@Query` sort needed, since the resolver itself handles ordering/selection).

- [ ] **Step 5: Run tests, verify they pass. Run the single-active-plan existing test suite, confirm zero behavior change.**

- [ ] **Step 6: Commit** (`feat: add a documented, deterministic active-plan resolver for cardio cards`).

### Task 10: Protection regression suite

**Files:**
- Create: `Tests/FitnessAppDataTests/LaufcoachingDualPathProtectionTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 5-9.

- [ ] **Step 1: Write failing tests covering the Review Focus items not already covered by earlier tasks' own tests:**
  ```swift
  func test_insertion_neverTouchesManuallyAddedDay() {
      // a TrainingDay the user manually edited (fingerprint mismatch, non-rest type) -> never selected
  }
  func test_doubleTapAccept_sameModelInstance_afterInsertion_isNoOp() {
      // Review-Punkt 7 / das historische Round-2-Bugmuster: calls `accept()`
      // TWICE on the exact same `CoachAdjustmentCardModel` VALUE (not a
      // freshly re-made one) - the second call must still be a no-op
      // because `accept` reads `profile.cardioPlanAdjustmentFingerprint`
      // LIVE at call time, never `self`'s frozen snapshot (same principle
      // CoachAdjustmentCardModel.accept's own doc comment already states
      // for the replace-path - this test proves the insertion-path
      // implementation in Task 7 follows it too, not just claims to)
  }
  func test_insertionAccept_saveFailure_leavesNoPartialDaysAndNoFingerprint() {
      // integration-level version of Task 6's unit test, through
      // CoachAdjustmentCardModel.accept, with >= 2 insertable rest days: a
      // forced save() failure (all apply() calls already ran in-memory
      // first, per Präzisierung 4) -> re-fetch plan, confirm EVERY day is
      // back to .rest with its original content, AND
      // profile.cardioPlanAdjustmentFingerprint still nil/unchanged
  }
  func test_optionB_withSecondActivePlan_doesNotDeactivateFirstPlan() {
      // confirms multi-active-plan design (ProgramInstantiator's existing, deliberate behavior) is preserved
  }
  ```

- [ ] **Step 2: Run tests, verify they fail (or already pass if prior tasks already cover them — in that case, delete the duplicate and note which task's test already proves it; don't keep a vacuous test).**

- [ ] **Step 3: Fix any gap the tests reveal in Tasks 5-9's implementation.**

- [ ] **Step 4: Run full `FitnessAppDataTests`/`FitnessAppCoreTests` suites, verify all green.**

- [ ] **Step 5: Commit** (`test: add Laufcoaching dual-path protection regression suite`).

### Task 11: End-to-end device acceptance

**Files:**
- Create: `docs/superpowers/plans/2026-10-25-equipment-vielfalt-laufcoaching-dual-path-acceptance-report.md`

**Kostenrahmen (Präzisierung 5, sechste Review-Runde):** wie beim ursprünglichen TestingBot-Auftrag — nur vorhandenes Guthaben im genehmigten Rahmen nutzen, keine Zusatzkäufe oder ein Guthaben-Upgrade ohne vorherige ausdrückliche Zustimmung.

- [ ] **Step 1: Build the branch via Apple CI (or local Xcode if available), obtain a simulator-runnable artifact**, same mechanism as the prior TestingBot pass.

- [ ] **Step 2: Device-test Equipment-Vielfalt, two DISTINCT scenarios (per the fourth review's Decision 1 — do not blur them into one generic "variety" check):**
  - **(2a) Alle Geräte verfügbar:** onboarding/template picker with ALL equipment selected, pick one of the 3 converted hybrid templates (e.g. "Hybrid Beginner"). Confirm the curated DEFAULT exercises are used wherever they're executable — mixing equipment is NOT itself the goal, and the test must fail if a perfectly-executable default was swapped for an alternative just to "show variety." A mix of equipment across different slots is an acceptable, expected OUTCOME of different exercises naturally using different gear, not something to assert as a target in itself.
  - **(2b) Eingeschränktes Equipment (dumbbell-only):** repeat with only dumbbell-equivalent equipment — a profile fully covered by the migrated `reviewedAlternatives` (per Task 3's parity matrix). Confirm every slot resolves via EXACTLY its default or one of its `reviewedAlternatives` (never an unreviewed catalog exercise), and confirm there is no unexecutable exercise and no silently-skipped `.unresolved` case for THIS covered profile specifically.
  - **(2c) Equipment außerhalb der Abdeckung (z.B. nur Körpergewicht):** confirm the established "warn, don't block" behavior from Decision 1 — the equipment-status banner visibly shows the gap (same UI as today's `.unavailable` case for any other template), the adopt button remains usable, and adopting produces a plan whose gap is still visibly flagged afterward (not silently dropped). This is a regression check against EXISTING, already-shipped behavior, not a new feature to verify as "newly working."
  - Separately, confirm "Ganzkörper 3x" / "Football Athletic" (unconverted, per A4) behave EXACTLY as before this plan under all three equipment scenarios — this is an explicit regression check, not a feature test.

- [ ] **Step 3: Device-test Laufcoaching Option A, two DISTINCT old-plan scenarios (seventh review round, P1 correction — Option (a)'s limitation is narrowly about INSERTION into a plan with zero cardio days, it does NOT mean "Option A is broken for any old plan"):**
  - **(3a) Freshly instantiated "Ganzkörper 3x"** (zero cardio days, created on this build): confirm the adjustment preview offers "Apply to current plan" (insertion path), confirm accepting it inserts visible new run days without removing/damaging the existing strength days.
  - **(3b) A plan from a build BEFORE this change, with ZERO cardio days:** confirm it correctly shows only "Create new plan" — no silent failure, no crash. This is the deliberate, accepted limitation from the decided Option (a), not a bug to chase.
  - **(3c) A plan from a build BEFORE this change that ALREADY HAS an eligible, replaceable cardio day** (i.e. was created via the Round-2 Laufcoaching flow, eligible via `generationFingerprint`/`isEligibleForAdjustment` — a field that predates and is entirely independent of `isAutoFilledPlaceholder`): confirm "Apply to current plan" (REPLACE path) still works exactly as it did before this plan, completely unaffected by the new `isAutoFilledPlaceholder` field or the Option (a) limitation. This is the case Option (a)'s restriction does NOT cover, and the acceptance test must prove that explicitly rather than assume it.

- [ ] **Step 4: Device-test Laufcoaching Option B**: from the same starting point, choose "Create separate plan" instead, confirm both plans are listed, both correctly reflect their content, and the dashboard's coach-adjustment/missed-run-days cards consistently reference the running plan (Task 9's fix) across app restarts/re-navigation.

- [ ] **Step 5: Write the acceptance report** (same structure as `docs/superpowers/plans/2026-10-25-laufcoaching-testingbot-acceptance-report.md`), confirm final CI status, append a short result summary to `docs/PLANUNG_BEGLEITUNG_AUDIT.md`.

- [ ] **Step 6: Commit the report** (`docs: equipment-vielfalt & laufcoaching-dual-path device acceptance`). No merge — present results to the user per this plan's Global Constraints.
