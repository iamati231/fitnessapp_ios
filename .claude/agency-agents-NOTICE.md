# Claude-Code-Agents aus „agency-agents“

Die Dateien in `.claude/agents/` sind **unveränderte Kopien** einer Auswahl aus
[msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
(MIT-Lizenz, Volltext in [`agency-agents-LICENSE`](./agency-agents-LICENSE)).

- **Stand der Kopie:** Commit `59635e0` vom 2026-10-04
- **Umfang:** 14 von rund 300 Agents; Claude Code lädt sie als Projekt-Subagents
- **Kopiert mit:** [`.scripts/sync_agency_agents.sh`](../.scripts/sync_agency_agents.sh)

## Enthalten

| Agent | Datei in `agents/` | Wofür in Deltiq |
|---|---|---|
| Mobile App Builder | `engineering-mobile-app-builder` | SwiftUI-/SwiftData-Features, iOS-Konventionen (HIG), Akku und Performance |
| Mobile Release Engineer | `engineering-mobile-release-engineer` | Signing, TestFlight über Codemagic, Checkliste vor der Einreichung (Privacy Manifest, dSYMs) |
| Code Reviewer | `engineering-code-reviewer` | Review von Änderungen vor Commit und Release-Tag |
| Privacy Engineer | `engineering-privacy-engineer` | Datenminimierung, Löschen/Export, was in Apple Health landet |
| Software Architect | `engineering-software-architect` | Modulgrenzen (Core/Data/Health/Activities/UI), Architekturentscheidungen |
| Technical Writer | `engineering-technical-writer` | README, Tester-Anleitung, Entwicklerdoku |
| UI Designer | `design-ui-designer` | Theme, Komponenten, Konsistenz der Oberfläche |
| UX Researcher | `design-ux-researcher` | Usability der Abläufe, Tester-Rückmeldungen auswerten |
| Accessibility Auditor | `testing-accessibility-auditor` | VoiceOver, Dynamic Type, Kontraste (die axe-/Lighthouse-Schritte der Vorlage gelten nur für Web) |
| Test Results Analyzer | `testing-test-results-analyzer` | Auswertung von `swift test`- und Codemagic-Läufen |
| Feedback Synthesizer | `product-feedback-synthesizer` | TestFlight-Feedback und Screenshots zu Prioritäten bündeln |
| Sprint Prioritizer | `product-sprint-prioritizer` | „Offene Punkte“ (README 9) und Wünsche priorisieren |
| Legal Compliance Checker | `support-legal-compliance-checker` | DSGVO, Gesundheitsdaten, App-Review-Regeln (5.1.3), Datenschutzerklärung |
| App Store Optimizer | `marketing-app-store-optimizer` | App-Store-Eintrag, Keywords, Texte in DE/EN/TR |

## Bewusst nicht enthalten

- **Evidence Collector, Reality Checker:** verlangen als ersten Pflichtschritt ein Web-Skript
  (`qa-playwright-capture.sh`, Playwright, `localhost:8000`), das es hier nicht gibt.
- **Performance Benchmarker, Application Security Engineer:** auf Web und APIs ausgelegt (k6, Lighthouse, JWT).
- **UI Finish-Gate Reviewer:** verweist auf einen externen Dienst (`uizze.com`).
- **Git Workflow Master:** Die Commit-Konventionen des Projekts stehen in [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- Der Rest (Marketing-Kanäle, Vertrieb, Games, Blockchain, Netzwerk, …) hat mit der App nichts zu tun.

## Benutzen

Im Projektordner in Claude Code: `/agents` listet sie auf. Den Agent beim Namen nennen, z. B.
„Lass den Privacy Engineer prüfen, was die Health-Zusatzfelder offenlegen“ oder
„Der Mobile Release Engineer soll die Einreichung vorbereiten“. Subagents werden beim Start einer
Sitzung geladen; eine schon laufende Sitzung braucht dafür einen Neustart.

Die Agents sind allgemein gehalten. Für Deltiq lohnt sich der Hinweis auf
[`README.md`](../README.md) (Abschnitt 8: Architektur, Bauen und Testen, Konventionen).

## Vorsicht: Fremd-Prompts

- Die Dateien sind Anweisungen eines Dritten. Beim Übernehmen wurden sie gelesen und auf
  Auffälliges geprüft (keine versteckten Zeichen, keine Anweisungen, Daten zu versenden oder
  Rechte zu umgehen); **bei jedem Update den Diff erneut lesen**.
- Bis auf Feedback Synthesizer und Sprint Prioritizer (`tools: WebFetch, WebSearch, Read, Write, Edit`)
  setzen die Agents kein `tools:` und erben damit alle Rechte der Sitzung, auch Bash und Edit. Wer
  einen Agent auf Lesen beschränken will, trägt in dessen Kopfzeile `tools: Read, Grep, Glob` ein
  (dann weicht die Datei vom Upstream ab; das Skript überschreibt sie beim nächsten Update).

## Aktualisieren oder erweitern

```bash
git clone --depth 1 https://github.com/msitarzewski/agency-agents /tmp/agency-agents
.scripts/sync_agency_agents.sh /tmp/agency-agents   # kopiert die Auswahl und die Lizenz
git diff .claude                                    # lesen!
```

Danach den Commit-Hash oben nachtragen. Einen weiteren Agent aufnehmen: seinen Pfad (`<Division>/<Datei>`)
in die Liste `AGENTS` im Skript eintragen, das Skript erneut laufen lassen und die Tabelle oben ergänzen.
