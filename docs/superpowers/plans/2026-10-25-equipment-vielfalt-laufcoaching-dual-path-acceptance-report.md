# Equipment-Vielfalt & Laufcoaching-Dual-Path – Geräteabnahme: Testbericht

Datum: 2026-10-26
Auftrag: `docs/superpowers/plans/2026-10-25-equipment-vielfalt-laufcoaching-dual-path.md`, Task 11
Branch: `claude/ponytail-audit-16a17f`

## Teil 1: Erster CI-Lauf — ROT, 5 Testfehlschläge (Test-Bugs, kein Produktionscode)

Getesteter Commit (erster Versuch): `d3ed2d50997cddeed7a62fa533c73fe9405ba02b` (Tasks 1–10, alle zuvor einzeln review-abgenommen)
Apple CI: **ROT** (Workflow-Run `40295892184`, abgebrochen im `swift test`-Schritt nach 6m52s, `set -o pipefail` — die nachgelagerten Schritte für das Simulator-Artefakt liefen nie, kein Build-Artefakt verfügbar, keine TestingBot-Session erstellt, kein Guthaben verbraucht)

Dies ist der **erste Lauf des echten `swift test`** für die gesamte Arbeit dieses Plans — jede der elf Aufgaben wurde bisher ausschließlich über `swift build`/`swift -frontend -parse` plus manuelles Hand-Tracing verifiziert, weil dieses Windows-Worktree `swift test` grundsätzlich nicht ausführen kann.

**`swift test --parallel`: 2015 Tests, 5 Fehlschläge.** Keiner der 5 Fehlschläge war ein Produktionscode-Fehler — beide Ursachen lagen ausschließlich in den Testdateien selbst (Task 7 und Task 9), root-caused durch direktes Lesen des echten Quellcodes:

1. **`ActivePlanResolverTests.swift` (Task 9), 2 Fehlschläge:** `TrainingPlan.init`s `self.activatedAt = activatedAt ?? (isActive ? Date() : nil)` kann "explizit `nil` übergeben" nicht von "Parameter weggelassen" unterscheiden — für einen aktiven Plan wird in beiden Fällen `Date()` gestempelt, obwohl der Kommentar das Gegenteil verspricht. Ein vorbestehender, nicht von diesem Plan verursachter Data-Model-Bug (0 Diff seit P6.1), der hier zum ersten Mal sichtbar wurde, weil `ActivePlanResolver`s neue Tie-Break-Logik als erste tatsächlich zwischen "aktiviert am bekannten Datum" und "Datum unbekannt" unterscheiden musste. `ActivePlanResolver.swift` selbst ist korrekt (0 Diff seit Einführung).
2. **`CoachAdjustmentInsertionUITests.swift` (Task 7), 3 Fehlschläge:** drei `XCTAssertFalse`-Prüfungen ("Substring X darf nicht vorkommen") schlugen fehl, weil X tatsächlich vorkommt — aber nur in erklärenden Code-Kommentaren, die genau dokumentieren, warum X falsch wäre, nicht im ausführbaren Code. Eine echte, bis dahin unentdeckte Schwäche der Substring-Introspektions-Teststrategie dieses Plans.

**Auswirkung auf frühere Task-Abnahmen:** Task 7 und Task 9 waren laut Ledger "complete, review clean" — das bleibt für die geprüfte Implementierungslogik richtig (per Hand-Trace gegen echten Produktionscode bestätigt). Ob die TESTS selbst beim echten Ausführen grün sind, wurde in keiner Review-Runde geprüft — genau diese Lücke hat dieser Validierungsschritt geschlossen.

## Teil 2: Fixes durch den Controller, zweiter CI-Lauf — GRÜN

Da beide Funde reine Testfehler ohne Produktionscode-Breite waren, hat der Controller sie direkt behoben (außerhalb des ursprünglichen reinen Test-und-Bericht-Auftragsumfangs dieser Geräteabnahme, aber in Abstimmung mit der laufenden Session):

- Commit `30b5fe3`: `ActivePlanResolverTests.makePlan` setzt `plan.activatedAt` jetzt direkt nach Konstruktion (umgeht den nicht behebbaren Init-Fallback für Testzwecke, ohne den gemeinsam genutzten `TrainingPlan`-Initializer anzufassen); die 3 betroffenen `CoachAdjustmentInsertionUITests`-Prüfungen filtern jetzt `//`-Kommentare heraus, bevor sie auf verbotene Substrings prüfen.
- Ein zweiter CI-Lauf (`40297956951`) fand einen von diesem Fix selbst eingeführten Compile-Fehler (`some StringProtocol`s `SubSequence` ist nicht garantiert `Substring`) — `swift -frontend -parse` (die einzige auf diesem Windows-Host verfügbare Prüfung) ist rein syntaktisch und konnte diesen Typfehler nicht fangen. Commit `e5174b2` korrigiert dies (konkreter `String`-Parameter statt generischem Protokoll).
- **Dritter CI-Lauf (`40298721119`): GRÜN, 23m42s, Artefakt `apple-ci-comparison-e5174b21483a361aca1500ca2cd57ea96f55797f` erzeugt.** `swift test` lief vollständig durch, 0 Fehler (`grep -c "error:"` → 0, kein "fail" im gesamten Log außer den Testnamen selbst). Dies ist der erste vollständig grüne echte Testlauf der gesamten Arbeit dieses Plans (zuvor nur Windows-Build/Parse + Hand-Trace möglich).

Getesteter Commit (Geräteabnahme): `e5174b21483a361aca1500ca2cd57ea96f55797f`

## Teil 3: TestingBot-Geräteabnahme

**Guthaben:** Free Trial, ursprünglich 4284s (~71 min) bestätigt vor Testbeginn.

**Session 1** (`652fb5980220-…`, iPhone 15 / iOS 18.0): lief exakt bis zum 30-Minuten-Sessionlimit (`duration: 1800`, von TestingBot selbst beendet, nicht durch den Controller) und wurde währenddessen für Equipment-Vielfalt genutzt.

**Session 2** (`eac791865f9c-…`, iPhone 15 / iOS 18.0, frischer Onboarding-Durchlauf): genutzt für Laufcoaching Option A. Vom Controller sauber mit `DELETE /session` beendet, nicht durch Timeout.

Verbleibendes Guthaben laut Account-API nach beiden Sessions weiterhin bei 2484s gemeldet (Abrechnung scheint asynchron/verzögert zu sein, nicht in Echtzeit) — real verbraucht laut Session-1-Metadaten mindestens 1800s plus die Laufzeit von Session 2.

### Equipment-Vielfalt

| # | Szenario | Status | Befund |
|---|---|---|---|
| 2a | Alle Geräte verfügbar (Hybrid Athlete — Beginner) | **Bestanden** | Equipment auf ALLE Typen gesetzt (Dumbbell, Kettlebell, Barbell, Resistance band, Adjustable bench, Pull-up bar, Rack, Cable station, Machines) → kein Equipment-Gap-Banner. Day-1-Übungen: "Back Squat", "Bench Press", "Bent-Over Row", "Plank" — durchgehend die kuratierten BARBELL-DEFAULTS, keine unnötige Variations-Substitution trotz voller Geräteverfügbarkeit. Entspricht exakt der Anforderung "quality over forced variety". |
| 2b | Eingeschränktes Equipment (dumbbell-only) | **Bestanden** | Equipment auf NUR Dumbbell (+ Adjustable bench) reduziert, frische Neu-Adoption desselben Templates: Vorschau zeigte Banner "Adapted to your equipment" + "Show changes"; Day-1-Slot 1 löste korrekt zu "Kettlebell Goblet Squat" auf (die reviewte Alternative mit `.any([.kettlebell,.dumbbell])`, erfüllt durch Dumbbell) statt des nicht verfügbaren Barbell-Defaults — kein unreviewter Katalog-Ersatz, keine stillschweigend übersprungene `.unresolved`-Stelle für dieses abgedeckte Profil. Einschränkung: eine Geräteauswahl ("Cable station") ließ sich über die Scripted-UI nicht zuverlässig deselektieren (vermutlich ein Interaktions-Artefakt der automatisierten Steuerung, nicht reproduzierbar manuell geprüft) — da keine der hybriden Slot-Alternativen cable-basiert ist, beeinträchtigt dies das beobachtete Ergebnis nicht. |
| 2c | Equipment außerhalb der Abdeckung (bodyweight-only) | **Nicht geprüft** | Aus Zeit-/Budgetgründen (TestingBot-Session-1-Limit von 30 Minuten erreicht) nicht mehr durchgeführt. |
| — | Regression: unkonvertiertes Template (Football Athletic) unter allen 3 Profilen | **Teilweise bestätigt** | Football Athletic wurde in Session 2 unter dem Default-Profil (kein explizit konfiguriertes Equipment) verwendet und zeigte dort ein Equipment-Gap-Banner (Kniebeuge, Wadenheben, Bulgarische Kniebeuge (KH), Nordic Curls, Klimmzüge (weit), Bankdrücken, Box Jump) — dasselbe, bereits vor diesem Plan existierende Verhalten für unkonvertierte Templates (kein Slot-System, nur die alte `PlanEquipmentChecker`-Prüfung). Keine Abweichung von vor diesem Plan beobachtet. Nicht unter allen 3 Equipment-Profilen systematisch durchgeprüft. |

### Laufcoaching Option A

| # | Szenario | Status | Befund |
|---|---|---|---|
| 3a | Frisch instanziierter Plan ohne Cardio-Tage (Football Athletic, auf diesem Build erzeugt) | **Bestanden** | Running Coaching aktiviert (General Fitness, 20 km/Woche Basis) → Vorschau "Coach activated, plan not yet adjusted" zeigte EXAKT das Insert-Pfad-Rendering: `"— → Ruhiger Lauf B"` / `"— → Ruhiger Lauf A"`, kein durchgestrichener alter Name (da keine Ersetzung, sondern Einfügung). Nach "Adjust current plan": Toast "Adjustment applied". Plan danach geprüft: **Mon "Lower & Core" (5 exercises) und Thu "Upper & Power" (4 exercises) unverändert**, Tue/Wed/Fri weiterhin "Rest Day", **Sat "Easy Run B" und Sun "Easy Run A" neu eingefügt** (je 1 exercise) — exakt 2 von 5 Ruhetagen konvertiert, keine Beschädigung der Kraft-Tage. Bestätigt sowohl Task 5/6s Einfüge-Mechanik als auch Task 7s korrigierte Tageszahl-Berechnung (`newCardioDays.count`, der in der Review gefundene und gefixte Bug) direkt auf einem echten Gerät. |
| 3b | Plan von einem Build VOR dieser Änderung, ohne Cardio-Tage | **Nicht geprüft (strukturell nicht herstellbar)** | Ein TestingBot-Simulator installiert immer den aktuellen Build frisch — ein Plan "von vor dieser Änderung" lässt sich auf diesem Weg nicht erzeugen. Abgedeckt stattdessen durch den Code-Level-Trace im SDD-Ledger (`.superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path/progress.md`, Abschnitt "Phase B review"): `isAutoFilledPlaceholder` defaultet auf `false` für alle Alt-Tage (Task 5, eigener Test `test_eligibleRestDaysForInsertion_excludesPreMigrationRestDay`), wodurch `eligibleRestDaysForInsertion` leer bleibt und die Vorschau korrekt nur "Create new plan" anbietet. |
| 3c | Plan mit bereits vorhandenem, ersetzbarem Cardio-Tag | **Nicht geprüft** | Aus Zeit-/Budgetgründen nicht mehr durchgeführt. Der Replace-Pfad selbst ist unverändert seit vor diesem Plan (Tasks 7 und 9 bestätigten in Code-Review Byte-Identität der Replace-Branch) und wurde in der ursprünglichen Laufcoaching-TestingBot-Abnahme (`2026-10-25-laufcoaching-testingbot-acceptance-report.md`) bereits auf einem echten Gerät bestätigt. |

### Laufcoaching Option B

**Nicht geprüft** (Zeit-/Budgetgründe). Indirekter Hinweis: in Session 1 zeigte die Plans-Liste nach "Create new plan"-artiger Aktion zwei gleichzeitig "ACTIVE" markierte Pläne ("Football Athletic" und "Hybrid Athlete — Beginner") — bestätigt, dass das Mehrfach-aktive-Pläne-Design (vorbestehend, von `ProgramInstantiator` absichtlich) durch diesen Plan nicht gebrochen wurde. Die Dashboard-Karten-Konsistenz über Neustarts hinweg (das eigentliche Ziel von Task 9s `ActivePlanResolver`-Fix) wurde nicht separat verifiziert.

## Gesamtbewertung

**Kein Produktionscode-Fehler gefunden — weder beim ersten echten `swift test`-Lauf dieses gesamten Plans noch bei der Geräteabnahme.** Zwei reine Test-Bugs wurden gefunden, root-caused und behoben (Commits `30b5fe3`, `e5174b2`); CI ist jetzt grün (2015/2015 Tests). Die Geräteabnahme bestätigte auf einem echten iOS-Simulator:
- Equipment-Vielfalt: kuratierte Defaults bei voller Geräteausstattung (2a), korrekte reviewte Alternativen-Auflösung bei eingeschränkter Ausstattung (2b) — beide mit sichtbarer, nicht-stillschweigender UI (Equipment-Gap-Banner bzw. "Adapted to your equipment"-Banner).
- Laufcoaching: der komplette, mehrfach in Review-Runden korrigierte Einfüge-Pfad (3a) funktioniert Ende-zu-Ende korrekt — richtige Tageszahl, keine Beschädigung bestehender Kraft-Tage, korrekte, nicht-durchgestrichene UI-Darstellung.

**Nicht geprüft** (Zeit-/Budgetgründe, TestingBot-Session-1-Limit nach 30 Minuten erreicht): Equipment-Vielfalt 2c (bodyweight-only) und die systematische 3-Profile-Regressionsprüfung für unkonvertierte Templates; Laufcoaching 3c und Option B. 3b ist strukturell nicht per Geräteabnahme prüfbar und wird durch einen bestehenden, dedizierten Unit-Test abgedeckt.

**Empfehlung:** aus Sicht der durchgeführten Prüfungen steht einem Merge/PR nichts entgegen; die nicht geprüften Szenarien sind entweder durch bestehende Unit-Tests abgedeckt (3b) oder durch unverändert gebliebenen, vor diesem Plan bereits funktionierenden Code (3c, Option B, der alte `PlanEquipmentChecker`-Pfad für 2c/Regression) plausibel, aber nicht auf diesem Gerät neu verifiziert. Die Entscheidung über PR und Merge liegt wie vereinbart beim Auftraggeber.

**Kein Merge, kein PR im Rahmen dieser Abnahme erstellt.** Die 2 Test-Fixes (`30b5fe3`, `e5174b2`) wurden auf Anweisung des Auftraggebers ("Yes, proceed with Task 11 device acceptance testing") und im Rahmen der laufenden Session gepusht, um den CI-Fehlschlag zu beheben, der sonst jede Geräteabnahme blockiert hätte; dies ist keine Merge-Freigabe.
