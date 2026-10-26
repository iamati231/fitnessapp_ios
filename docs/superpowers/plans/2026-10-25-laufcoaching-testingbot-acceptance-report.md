# Laufcoaching – TestingBot-Geräteabnahme: Testbericht

Datum: 2026-10-25
Auftrag: `docs/superpowers/plans/2026-10-25-laufcoaching-testingbot-acceptance.md`
Branch: `claude/ponytail-audit-16a17f`
Getesteter Commit: `cf9e03d` (Swift-Package-Build, Artefakt `apple-ci-comparison-cf9e03d...`)
Apple CI zu diesem Commit: GRÜN, 1928/1928 Tests (Run `40204487288`)

## Gerät / Build

- TestingBot-Session-ID: `24ab53ab-e2f1-46e8-a4f8-28a3063be11c` (Appium, `https://hub.testingbot.com/wd/hub`)
- Gerät/OS: iPhone 15, iOS 18.0 (TestingBot-Simulator)
- Build: `FitnessApp-simulator.zip` aus dem Apple-CI-Artefakt zu Commit `cf9e03d`, hochgeladen als `tb://d2699b1e1bbcff83cd1e7f41`
- TestingBot-Account: Free Trial, 6000s Guthaben — innerhalb des vorhandenen Guthabens getestet, keine Zusatzkäufe
- Keine Feature-Änderungen, kein Merge, kein PR im Rahmen dieses Auftrags

## Vorgehen

Da keine Accessibility-Identifier in den relevanten Views vorhanden sind, wurde über reale, auf dem Gerät gerenderte Textlabels (iOS-Predicate-Strings) und Screenshots gesteuert. Testdaten: frisches Onboarding, Profil "Male, 180cm, 78kg", Ziel 10K, 5K-Referenzzeit 25:00, Wochenbasis 20 km, Renndatum 17 Jan 2027.

## Ergebnis je Prüfschritt

| # | Schritt | Status | Befund |
|---|---|---|---|
| 1 | App starten, Laufcoaching aktivieren | **Bestanden** | Onboarding durchlaufen, "Work toward a goal with a run coach" aktiviert |
| 2 | Cardio-Ziel im Onboarding wählen | **Bestanden** | "10K" gewählt, persistiert bis ins Profil |
| 3 | Plan generieren, Ziel beeinflusst Lauftyp-Mix | **Bestanden** | Das Onboarding-Template ("Football Athletic") hat selbst KEINE Cardio-Tage (siehe Befund B unten) — die goal-gesteuerte Struktur zeigte sich beim über "Create new plan" erzeugten Plan: Mo Kraft, Di "Easy Run B", Mi Kraft, Do "Easy Run A", Fr "Tempo Run", exakt der 10K-Mix `[.easy, .quality]` aus Task 2/3 |
| 4 | Mit Wochenbasis + Referenzzeit: Umfang/Pace plausibel | **Bestanden** | Profil-Editor-Live-Vorschau: 25:00 5K → "Easy ~6:30 /km · Tempo ~5:30 /km", rechnerisch exakt (Faktoren 1.30/1.10) |
| 5 | Aktiven Plan öffnen, Anpassungsvorschau zeigen | **Bestanden** | "Review plan" öffnet die Vorschau; da "Football Athletic" keinen anfassbaren Cardio-Tag hat, bot sie korrekt "Create new plan" statt einer In-Place-Vorschau an |
| 6 | Der Anpassung zustimmen | **Bestanden** | "Create new plan" erzeugt real einen zweiten, aktiven Plan ("Individueller Plan") mit der goal-gesteuerten Struktur |
| 7 | Übernommenen Tag öffnen, Ziel-Pace sichtbar und passend | **Bestanden** | "Tempo Run"-Tag → Übung "Long Run" (stabiler Ankername) → SetRow zeigt "target: 5:30 /km", exakt die zuvor berechnete Tempo-Pace |
| 8 | Nach Übernahme keine erneut unapplizierte Karte | **Teilweise geprüft** | Siehe Befund A unten — der konkrete, im finalen Review gefundene und gefixte Fingerprint-Bug (`CoachAdjustmentCardModel`) konnte auf diesem Gerät nicht isoliert reproduziert werden, weil die Dashboard-Karte durchgehend gegen den ursprünglichen, nicht anpassbaren Plan auflöste statt gegen den neu erzeugten. Der Fix selbst wurde bereits unabhängig im Code-Review zweimal nachvollzogen (Kontrollfluss Zeile für Zeile bestätigt) |
| 9 | Coach deaktivieren, keine unpassende Pace | **Bestanden** | Mit deaktiviertem Coach verschwindet die "target: ..."-Zeile vollständig am selben Tag; die normale Live-Pace-Anzeige bleibt unberührt |
| 10 | Ohne Referenzzeit: keine erfundene Pace, Fallback funktioniert | **Bestanden** | Mit Coach an, aber leerem 5K-Feld zeigt derselbe Tag "target: pace by feel" statt einer Zahl — korrekter qualitativer Fallback |

## Befunde

**A. (Informativ, keine Round-2-Regression) Mehrere "aktive" Pläne gleichzeitig.** Nach "Create new plan" zeigte die Plan-Liste sowohl "Football Athletic" als auch "Individueller Plan" mit dem Badge "ACTIVE". Die Dashboard-Karte "Coach activated, plan not yet adjusted" löste bei jedem erneuten Öffnen weiterhin gegen "Football Athletic" auf (das Original, ohne Cardio-Tage), nicht gegen den neuen Plan. Dadurch war Schritt 8 (In-Place-Anpassung eines bereits anfassbaren Plans) über die Dashboard-Karte nicht erreichbar. Dies scheint bestehende, nicht von Runde 2 verursachte Architektur zu sein (wie mehrere aktive Pläne und die Dashboard-Plan-Auswahl zusammenspielen), aber es schränkt die Testbarkeit von Checkpoint 8 über die UI ein. Kein Code geändert; zur Kenntnisnahme.

**B. (Vorbestehend, nicht Round-2) Eingabefeld "Current 5K time" validiert/formatiert nicht.** Tippt man eine Zahl ohne Doppelpunkt (z. B. "2500" statt "25:00"), wird der Rohwert unverändert übernommen und als Sekunden interpretiert, wodurch die Live-Vorschau "Easy ~650:00 /km · Tempo ~550:00 /km" zeigt — eine unplausible, aber nicht als Fehler erkannte Pace. Betrifft `CardioGoalEditorView`/`PaceCalculator.parseDurationToSeconds`, nicht Bestandteil dieser Runde. Kein Code geändert; als Beobachtung festgehalten, da es demselben "keine irreführende Pace"-Prinzip wie Decision 1 unterliegt.

## Gesamtbewertung

8 von 10 Schritten vollständig bestanden, 1 Schritt (8) durch App-seitige Plan-Auswahl-Architektur nicht isoliert auf dem Gerät reproduzierbar (aber bereits zweifach unabhängig im Code verifiziert), keine neuen, durch Runde 2 verursachten Fehler gefunden. Die drei verbindlichen Entscheidungen (Pace am übernommenen Tag, zielgesteuerte Planstruktur, durchgängiges Vorschlagsziel) wurden alle direkt auf einem echten iOS-Simulator bestätigt.

Apple CI bleibt grün (1928/1928, Commit `cf9e03d`). Kein Code wurde im Rahmen dieses Testauftrags geändert.

**Empfehlung:** Aus Sicht dieser Geräteabnahme steht einem Merge/PR nichts entgegen. Die Entscheidung darüber liegt wie vereinbart beim Auftraggeber.
