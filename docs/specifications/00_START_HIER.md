# 00 – START HIER: Deltiq-Weiterentwicklung für Claude Code

## Ziel

Deltiq soll einen verständlichen Einstieg, eine konsistente Trainingsplanung und eine begründete langfristige Begleitung bieten:

> Passend starten → echte Trainingsdaten sammeln → Entwicklung erklären → gezielte Anpassungen vorschlagen → bewusst übernehmen.

Dieses Paket ist eine zusammenhängende Spezifikation, nicht fünf unabhängig zu implementierende Features. Ein großer Auftrag soll in überprüfbare Aufgaben zerlegt werden. Nicht alle Funktionen gleichzeitig umbauen.

## Lesereihenfolge und Zuständigkeit

1. `00_START_HIER.md`: Prioritäten, Arbeitsweise, Integration.
2. `01_PLANUNG_BUILDER_UND_FIXES.md`: Profil-Plan-Verbindung, neuer A+B-Builder, Equipment, Warm-up/Cooldown, RIR und bestehende Regressionen.
3. `02_ONBOARDING_HYBRID_LAUFCOACH.md`: gemeinsame Onboarding-Planung, Ausdauerwahl, getrennte Laufcoach-Entscheidung, Abschlusslogik.
4. `03_TRAININGSBEGLEITUNG_PLAN_CHECKS.md`: Einstiegsphase, regelmäßige Rückblicke, Progression versus Planänderung, Erklärungen und Planversionen.
5. `04_TESTS_UND_ABNAHME.md`: übergreifende Tests und wahrheitsgemäßer Verifikationsstand.

Dokument 02 ist für Onboarding-Interaktion maßgeblich, Dokument 03 für Review-/Coaching-Regeln, Dokument 04 für Abnahme. Bei echten fachlichen Widersprüchen nicht eigenmächtig eine Vorgabe verwerfen: Konflikt und Lösungsvorschlag benennen. Dieses Paket ersetzt die frühere einzelne A+B-MD als maßgeblichen Gesamtauftrag.

## Verbindlich versus vorgeschlagen

Verbindlich sind insbesondere: ein gemeinsames Planungskonzept, keine doppelten Profilfragen, getrennte Entscheidung über Laufeinheiten und Laufcoach, kontrollierte Planänderungen, vollständige Werteanzeige, Schutz der Trainingshistorie und ehrliche Tests.

Vorgeschlagene Produktdefaults: erster Review ungefähr nach vier Wochen; spätere Reviews ungefähr nach sechs bis acht Wochen. Das sind keine wissenschaftlich zwingenden Trainingszyklen. Datenanforderungen und konkrete Progressions-/Belastungsregeln sind gegen bestehende Domänenlogik und geeignete fachliche Quellen zu prüfen. Nicht erfundene Grenzwerte als Trainingswissenschaft ausgeben.

## Phase 0: verpflichtende Bestandsaufnahme

- Tatsächlichen Branch, Arbeitsbaum, aktuelle Commits und geltende Repository-Instruktionen prüfen.
- Bestehende Planer-, Onboarding-, Cardio-Coaching-, Progressions-, Deload-, Absenz-/Wiedereinstiegs- und Equipment-Logik suchen.
- Bereits gelöste Fehler nicht erneut umbauen. Aktuelle Lücken mit Dateipfad/Funktion belegen.
- Eingangs-/Ausgangsverträge, Live-Autosave versus Draft, Schema und Export/Import erfassen.
- Einen Umsetzungsplan mit kleinen Aufgaben, Abhängigkeiten und Abnahmekriterien vorlegen.
- Bestehende frühere Commits nur als historischen Kontext behandeln.

## Empfohlene Umsetzung als Arbeitspakete

| Paket | Inhalt | Voraussetzung |
|---|---|---|
| P0 | Audit und Integrationsentwurf | keine |
| P1 | Aktuelle Fehler/Regressionen: RIR, Messung, Unknown, Discard, Navigation | P0 |
| P2 | Gemeinsamer Planungskontext und isolierter Wochenentwurf | P0 |
| P3 | Zielorientierter Builder + visueller Wocheneditor | P2 |
| P4 | Onboarding-Integration und Hybrid/Laufcoach-Verzweigung | P2, P3 |
| P5 | Profiländerung → Auswirkungsanalyse → Vorschau → Übernahme | P2, P3 |
| P6 | Planversionen, Datenqualität und Review-Grundlage | P0, P2 |
| P7 | Erster Vier-Wochen-Rückblick mit transparenten Regeln | P6 |
| P8 | Spätere Block-Reviews und gezielte Anpassungsvorschläge | P3, P5, P7 |
| P9 | Apple-/UI-Verifikation, Regression, Dokumentation | fortlaufend + Abschluss |

Unabhängige Audits/Tests dürfen parallelisiert werden. Überlappende Schreibzugriffe auf dieselben Dateien koordinieren. Nach jeder Phase sinnvoll kompilieren/testen; nicht erst am Ende eines riesigen Diffs.

## Nicht verhandelbare Architekturgrenzen

- Eine gemeinsame fachliche Planung für Onboarding, neue Pläne und Anpassung bestehender Pläne.
- Kontextabhängige Oberfläche statt kopierter zweiter Builder.
- Vorschau/Entwurf erzeugt keine persistierten Pläne.
- Historische Logs nicht umschreiben, um einen neuen Plan passend aussehen zu lassen.
- Kein ungefragtes Bulk-Update, kein neuer aktiver Plan ohne ausdrückliche Entscheidung.
- Laufende Sessions nicht durch nachträgliche Planänderung destabilisieren.
- Keine pauschale neue Baseline, die fremde offene Änderungen bestätigt.
- Keine neue Start-Check-Einstiegsstelle außerhalb des Onboardings.
- Keine Diagnose-/Verletzungsprognosen aus einfachen Trainingsdaten.

## Arbeits- und Abschlussregeln

Nicht nur Texte und Audit-Dokumente liefern: den beauftragten Funktionsumfang phasenweise implementieren, sofern die Arbeitsumgebung es erlaubt. Fehlende Zugriffe und offene Tests ausdrücklich melden. Keine angeblich laufenden Hintergrundprozesse oder automatische Rückmeldungen versprechen, wenn die Umgebung das nicht tatsächlich unterstützt.

Remote-Schreibaktionen, Pushes und PRs nur nach den tatsächlich geltenden Freigaben. Nicht ungefragt mehrere Branches synchronisieren. Kein paralleles neues Modell für eine bereits existierende Funktion bauen, bevor Wiederverwendung geprüft wurde.

Zum Abschluss je Paket: umgesetzt / teilweise / offen, Dateien, tatsächlich ausgeführte Tests, Apple-Ergebnis, UI-Ergebnis, Risiken und nächste konkrete Aufgabe. „Tests geschrieben“ ist nicht „Tests bestanden“; Push ist kein grüner CI-Lauf.
