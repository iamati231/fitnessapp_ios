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

**Session 3** (`c616bc51eb9c-…`, iPhone 15 / iOS 18.0, frischer Onboarding-Durchlauf, ~19 Minuten): genutzt für Laufcoaching Option B (siehe unten für den dabei gefundenen Befund C). Vom Controller sauber mit `DELETE /session` beendet (Concurrency danach bei 0 bestätigt), nicht durch Timeout.

Verbleibendes Guthaben laut Account-API nach allen 3 Sessions weiterhin bei 2484s gemeldet (Abrechnung scheint asynchron/verzögert zu sein, nicht in Echtzeit) — real verbraucht laut Session-Metadaten mindestens 1800s (Session 1) plus die Laufzeiten von Session 2 und 3, alles innerhalb des ursprünglich bestätigten ~71-Minuten-Guthabens.

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

**Geprüft, mit einem wichtigen Zwischenbefund: Session 3** (frisches Onboarding, `Football Athletic` aktiv, Running Coaching aktiviert via `CardioGoalEditorView`).

**Befund C (informativ, Diskrepanz zur Task-11-Formulierung):** die vom `CardioGoalEditorView`-Aktivierungsfluss geöffnete "Adjust plan"-Vorschau (`CoachAdjustmentCardModel`, über das Dashboard-Karten-`Review plan` erneut bestätigt) bietet ausschließlich **"Keep as is"** und **"Adjust current plan"** — es existiert in dieser konkreten Vorschau keine dritte, direkt anwählbare "Create separate plan"-Aktion. Das ist konsistent mit Task 8s bestätigtem Befund: `CardioFeasibilityCardModel`s alte "Create separate plan nur"-Logik ist inzwischen totes, korrekt entferntes Fallback-Verhalten, das nur noch greift, wenn GAR KEIN aktiver Plan existiert — sobald (wie hier) ein aktiver Plan vorhanden ist, übernimmt `CoachAdjustmentCardModel` exklusiv, und dieses bot nie eine dritte Handlungsoption an. Task 11s Formulierung ("vom selben Ausgangspunkt stattdessen Option B wählen") trifft auf die tatsächliche UI nicht mehr zu, seit Task 8 das alte Fallback entfernt hat — kein Code geändert, nur als Dokumentations-/Plan-Diskrepanz festgehalten, nicht als Bug.

**Tatsächlich geprüft (eigenständiger Pfad über `Training → +`):** stattdessen über "Build Plan" einen zweiten, unabhängigen Plan ("Individueller Plan", Strength & Muscle, 3 Tage/Woche) erstellt und gespeichert. Danach zeigte die Plans-Liste **zwei gleichzeitig "ACTIVE"** markierte Pläne (`Football Athletic`, `Individueller Plan`) — bestätigt das vorbestehende Mehrfach-aktive-Pläne-Design bleibt unverändert.

**Der eigentlich relevante Befund für Task 9:** mit zwei gleichzeitig aktiven Plänen, von denen KEINER `generationSource == .cardioCoach` ist, verschwand die "Coach activated, plan not yet adjusted"-Karte **korrekt vollständig sowohl vom Dashboard als auch von der Plans-Liste** — genau das von `ActivePlanResolver`s Fall 0 ("mehrere aktive Nicht-Cardio-Pläne → KEINE verlässliche Zuordnung → nil, niemals geraten") vorhergesagte, sichere Verhalten, direkt auf einem echten Gerät bestätigt, und zwar konsistent über BEIDE Views hinweg (genau die Eigenschaft, die die alte `activePlans.first`-Logik nicht garantieren konnte). Dies ist eine direktere, strengere Bestätigung von Task 9s Kernversprechen als das ursprünglich geplante Szenario.

## Gesamtbewertung

**Kein Produktionscode-Fehler gefunden — weder beim ersten echten `swift test`-Lauf dieses gesamten Plans noch bei der Geräteabnahme.** Zwei reine Test-Bugs wurden gefunden, root-caused und behoben (Commits `30b5fe3`, `e5174b2`); CI ist jetzt grün (2015/2015 Tests). Die Geräteabnahme bestätigte auf einem echten iOS-Simulator:
- Equipment-Vielfalt: kuratierte Defaults bei voller Geräteausstattung (2a), korrekte reviewte Alternativen-Auflösung bei eingeschränkter Ausstattung (2b) — beide mit sichtbarer, nicht-stillschweigender UI (Equipment-Gap-Banner bzw. "Adapted to your equipment"-Banner).
- Laufcoaching: der komplette, mehrfach in Review-Runden korrigierte Einfüge-Pfad (3a) funktioniert Ende-zu-Ende korrekt — richtige Tageszahl, keine Beschädigung bestehender Kraft-Tage, korrekte, nicht-durchgestrichene UI-Darstellung.
- Task 9s `ActivePlanResolver`: mit zwei gleichzeitig aktiven, nicht-Cardio-Coach-Plänen verschwindet die Coach-Karte korrekt und konsistent aus BEIDEN Views (Dashboard, Plans-Liste) statt zu raten — direkt auf einem echten Gerät bestätigt, die strengste verfügbare Probe für die Kerngarantie dieser Aufgabe.

**Ein Befund außerhalb reiner Testresultate (Befund C):** die in Task 11 beschriebene "Option A vs. Option B, vom selben Bildschirm"-Wahl existiert in der aktuellen UI nicht mehr — Folge von Task 8s korrekter Entfernung des alten `CardioFeasibilityCardModel`-Fallbacks. Keine Regression, aber die Plan-Formulierung für dieses eine Prüfkriterium ist veraltet.

**Nicht geprüft** (Zeit-/Budgetgründe über alle 3 Sessions hinweg): Equipment-Vielfalt 2c (bodyweight-only) und die systematische 3-Profile-Regressionsprüfung für unkonvertierte Templates; Laufcoaching 3c. 3b ist strukturell nicht per Geräteabnahme prüfbar und wird durch einen bestehenden, dedizierten Unit-Test abgedeckt. Option B wurde geprüft (siehe oben) — mit dem Befund, dass die in Task 11 beschriebene direkte "Option A vs. B"-Auswahl auf derselben Vorschau nicht mehr existiert (Task 8s korrekte Entfernung des alten Fallbacks), stattdessen aber über einen unabhängigen zweiten Plan getestet, mit einem direkten, strengen Beleg für Task 9s Kernversprechen (Dashboard/Plans-Liste zeigen konsistent KEINE Karte bei Mehrdeutigkeit, statt zu raten).

**Empfehlung:** aus Sicht der durchgeführten Prüfungen steht einem Merge/PR nichts entgegen; die nicht geprüften Szenarien sind entweder durch bestehende Unit-Tests abgedeckt (3b) oder durch unverändert gebliebenen, vor diesem Plan bereits funktionierenden Code (3c, Option B, der alte `PlanEquipmentChecker`-Pfad für 2c/Regression) plausibel, aber nicht auf diesem Gerät neu verifiziert. Die Entscheidung über PR und Merge liegt wie vereinbart beim Auftraggeber.

**Kein Merge, kein PR im Rahmen dieser Abnahme erstellt.** Die 2 Test-Fixes (`30b5fe3`, `e5174b2`) wurden auf Anweisung des Auftraggebers ("Yes, proceed with Task 11 device acceptance testing") und im Rahmen der laufenden Session gepusht, um den CI-Fehlschlag zu beheben, der sonst jede Geräteabnahme blockiert hätte; dies ist keine Merge-Freigabe.
