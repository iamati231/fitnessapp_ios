# 01 – Planungsgrundlage, A+B-Builder und bestehende Fehler

## Einordnung

Lies zuerst `00_START_HIER.md`. Dokument 02 präzisiert den gemeinsamen Onboarding-Einstieg; Dokument 03 ergänzt spätere Plan-Checks; Dokument 04 definiert Tests und Abnahme. Diese Fassung ist eigenständig und setzt keine frühere Datei voraus.

## 1. Ziel

Den bisherigen „Plan bauen“-Assistenten durch eine Kombination aus zielorientiertem Einstieg (A) und visuellem Wocheneditor (B) ersetzen. Gleichzeitig die gemeldeten Lücken bei Profilanpassung, Equipment, Warm-up/Cooldown und RIR beheben.

Ablauf:

> Ziel bestätigen → Alltag und Ausstattung berücksichtigen → Woche vorschlagen → visuell anpassen → bewusst übernehmen.

Nicht nur bestehende Formulare umfärben. Bestehende fachliche Engine und funktionierende Eingänge erhalten; keine parallele zweite Planungslogik.

## 2. Audit vor Umsetzung

Aktuellen Branch und Code prüfen, nicht frühere Aussagen als aktuellen Zustand annehmen. Mindestens diese Komponenten bzw. aktuelle Entsprechungen untersuchen:

- `PlanBuilderView`, `PlansListView`, Onboarding und vorhandene Builder-Callbacks.
- PlanGenerator/Instantiator, Cardio-Machbarkeitslogik, Umgebungs-Migration.
- Profil-, Equipment-, Plan-, Tages-, Übungs- und Sessionmodelle.
- `ProfileEditorView`, `TrainingLocationEquipmentEditorView`, `EquipmentProfileEditor`.
- `ActiveWorkoutView`, `ExerciseCard`, `SetRow`, Rollen und Filter.
- Header, Navigation, Entwurfsschutz, Sortierung, Tests und Export/Import.

Ist-/Soll-Tabelle mit Dateipfad, tatsächlicher Ursache, Wiederverwendung und Risiko erstellen. Bereits reparierte Funktionen nicht erneut beschädigen.

## 3. Zielorientierter Einstieg – Option A

### Benennung

- Planbibliothek: „Trainingsplan erstellen“.
- Bestehenden Plan bearbeiten: „Trainingsplan anpassen“.
- Visuelle Vorschau: „Meine Trainingswoche“.

### Zielkarten

- Kraft & Muskelaufbau.
- Laufen & Ausdauer.
- Kraft & Ausdauer kombinieren.
- Allgemeine Fitness.

Diese Kategorien auf vorhandene Zielmodelle abbilden, nicht ungeprüft bestehende Enums ersetzen. Langhantel, Kurzhantel und Kettlebell sind Trainingsmittel/-formen und keine gleichrangigen Alternativen zum übergeordneten Ziel Ausdauer.

Vorhandenes Profil vorbefüllen. Planbezogene Abweichungen nicht automatisch ins Profil schreiben. Bei Hybrid und Laufen gelten die getrennten Entscheidungen aus Dokument 02.

### Alltagsrahmen

- Trainingstage pro Woche.
- Zeitbudget je Einheit, später pro Tag anpassbar.
- Feste Wochentage oder flexible Reihenfolge.
- Trainingsort und Ausstattung als vorbefüllte Zusammenfassung.
- Weitere Optionen nur bei Bedarf öffnen.

Anzahl der Einheiten und verfügbare Kalendertage auseinanderhalten. Falls mehrere Einheiten pro Tag nicht unterstützt werden, Begrenzung offen anzeigen. Keine überschüssigen Einheiten still abschneiden.

Ausstattung nicht erneut vollständig abfragen. Eine Änderung im Entwurf gilt zunächst für diesen Plan; globales Profilupdate braucht eine getrennte bewusste Entscheidung.

„Woche vorschlagen“ berechnet nur einen Entwurf, keinen gespeicherten Plan.

## 4. Visueller Wocheneditor – Option B

### Übersicht

Einheiten mit Trainingsart, Schwerpunkt, geschätzter Dauer und aufklappbaren Inhalten darstellen. Feste Tage oder flexible Einheiten korrekt beschriften; freie Tage sichtbar lassen. Kein automatisch als absolviert geloggter Ruhetag.

Beispiel ausschließlich für die Oberfläche:

```text
DEINE WOCHE
4 Einheiten · Kraft & Ausdauer · Gym
Mo  Kraft A     ca. 45 Min.
Di  Frei
Mi  Laufen      ca. 30 Min.
Do  Frei
Fr  Kraft B     ca. 45 Min.
Sa  Ausdauer    ca. 35 Min.
So  Frei
```

Bei flexibler Reihenfolge „Einheit 1“ usw., keine falsche Kalenderbindung.

Kurze Begründung anhand tatsächlicher Eingaben. Keine unbelegten Behauptungen über optimale Regeneration oder physiologische Wirkungen.

### Bearbeiten

- Einheiten per Drag & Drop verschieben.
- Alternative „Verschieben nach …“ für zugängliche Bedienung.
- Einheit öffnen, Dauer ändern, Trainingsform und einzelne Übungen anpassen.
- Inhalt und Position getrennt fixieren: „Einheit beibehalten“ sperrt nicht automatisch den Wochentag.
- Unmögliche Kombinationen mit konkreten Konflikten anzeigen.
- Manuelle Anpassungen bei neuen Vorschlägen schützen.
- Mindestens letzte Änderung rückgängig machen können.

### Gezielte Alternativen statt „Neu rechnen“

1. Alternative Übungen vorschlagen: nur ausgewählte/nicht fixierte Inhalte.
2. Woche anders verteilen: Inhalte erhalten, erlaubte Positionen ändern.
3. Vorschlag neu erstellen: größere Änderung mit Vorschau und Schutz bestehender Fixierungen.

Keine Funktion durch zufälliges Komplett-Neugenerieren imitieren, wenn gezielte Änderung nicht implementiert ist. Grenzen ausdrücklich nennen.

## 5. Header, Speichern und Verwerfen

- Oben links Deltiq-Zurück-Chevron.
- Innerhalb des Assistenten zurück zum vorherigen Schritt; Entwurf erhalten.
- Beim tatsächlichen Verlassen ohne Änderungen sofort schließen, sonst Verwerfen-Dialog.
- Schließgesten dürfen offene Änderungen nicht umgehen. Blockieren und Dialog beim Wischversuch sind unterschiedliche Implementierungen; tatsächlich umgesetztes Verhalten berichten.
- Im finalen eigenständigen Wocheneditor oben rechts Haken als einzige Übernehmen-Aktion, zugängliches Label „Trainingsplan übernehmen“.
- Haken nur bei gültigem Entwurf aktiv; nicht zum Beenden von Sortieren missbrauchen.
- Weitere Aktionen ins Ellipsis-Menü, Haken nie verdrängen.
- Unten dürfen Weiter/Vorschauaktionen stehen, aber kein zweiter finaler Speichern-Button.
- Löschaktionen bestehender Datensätze bleiben unten rot; keine Löschung für ungespeicherten Entwurf erfinden.
- Planname und optionale Aktivierung im Inhalt anbieten. Bestehenden aktiven Plan nicht ungefragt ersetzen.

Onboarding-Ausnahme: Eingebetteter Haken übernimmt nur den Onboarding-Entwurf. Gesamtes Onboarding endet mit einer eindeutig beschrifteten Aktion gemäß Dokument 02.

## 6. Profiländerung → kontrollierte Plananpassung

### Gemeinsamer Ablauf

Änderung bestätigen → Auswirkungen berechnen → Vorschau zeigen → Zielplan wählen/bestätigen → kontrolliert übernehmen.

Standardmäßig aktiven Plan berücksichtigen, keine ungefragte Änderung aller gespeicherten Pläne. Zusätzliche Pläne nur nach ausdrücklicher Auswahl. Profilentscheidung und Plananpassung sind getrennt: Planablehnung verwirft das bestätigte Profilupdate nicht.

### Cardio und Laufziel

- Nach gespeichertem relevanten Update einmalig gebündelten Vorschlag anbieten, nicht bei jedem Tastenanschlag.
- Konkrete Ergänzungen/Ersetzungen/Zeitänderungen und unveränderte Inhalte zeigen.
- Optionen: aktiven Plan anpassen, als neuen Plan erstellen, bestehenden Plan beibehalten.
- Ohne aktiven Plan vorbefüllte Neuerstellung anbieten.
- Aktivieren, Deaktivieren und Zielwechsel berücksichtigen.
- Kein doppeltes Anlegen bei wiederholter Bestätigung.
- Lauftraining ohne Coach bleibt möglich; vollständige Zustände in Dokument 02.

### Equipment

Verfügbarkeit ist eine Ausführbarkeitsbedingung, Präferenz eine Gewichtung geeigneter Alternativen.

| Angabe | Wirkung |
|---|---|
| Nicht vorhanden | Betroffene Übungen erkennen, geeigneten Ersatz anbieten |
| Vorhanden | Darf in der Planung verwendet werden |
| Explizit unbekannt | Antwort erhalten, Unsicherheit nicht als Bestätigung ausgeben |
| Präferenz | Geeignete Übungen bevorzugen, andere Geräte nicht pauschal verbieten |

Gym-Annahmen getrennt halten. Bestätigte Nichtverfügbarkeit nicht überschreiben. Bank/Klimmzugstange „Weiß ich nicht“ nach Neustart, Bestätigung und Export/Import erhalten.

Änderungsvorschau nennt bisherige Übung, Alternative und Grund. Präferenzänderung bietet optionale Neugewichtung statt stiller vollständiger Ersetzung.

### Daten-/Discard-Grenzen

- Abgeschlossene Trainings/Logs nicht ändern.
- Laufende Sessionstruktur schützen; Übernahme gegebenenfalls auf spätere Sessions begrenzen/verschieben.
- Manuelle Änderungen erhalten oder Konflikte sichtbar machen.
- Reorder muss dirty und verwerfbar sein.
- Add/Delete plus Reorder ausdrücklich regeln: keine doppelten Indizes oder unklare Wochentage durch partiellen Rollback.
- Bereits bestätigte Einzelaktionen aktualisieren nur betroffene Baseline-Felder – auch im Profileditor.
- A aktiv → B an → B aus → Verwerfen stellt Ausgangsaktivierung wieder her.
- Kein anderer aktiver Plan: unveränderter Plan bleibt sauber; nil nicht als Inaktivitätsänderung werten.
- Keine globale Context-Rücknahme, die unabhängige Änderungen vernichtet.

## 7. Warm-up, Aufwärm-Sätze und Cooldown

Der Nutzer sieht Aufwärm-Sätze, aber keinen Cooldown. Prüfen, ob Cooldown fehlt, nicht übernommen wird, gefiltert ist oder lediglich nicht erreichbar ist. Screenshot beweist keine genaue Ursache.

Struktur:

1. Optionales allgemeines Warm-up am Beginn.
2. Übungsspezifische Aufwärm-Sätze bei passenden Kraftübungen.
3. Haupttraining.
4. Optionaler Cooldown am Ende der Einheit.

Vorhandene Rollen, Sichtbarkeitspräferenzen und Sessionlogik wiederverwenden. Kein Cooldown pro Kraftübung als künstliches Gegenstück zur Aufwärmrampe. Vorgesehener Cooldown ist in Vorschau und Training erreichbar; nicht vorgesehener erzeugt keine leere Pflichtsektion. Überspringen/Abschließen darf die Einheit nicht fälschlich unvollständig halten. Keine Arbeitssatz-Progression auf Warm-up/Cooldown übertragen. Keine unbelegten medizinischen Wirkversprechen.

## 8. RIR: strukturell statt weiter zusammendrücken

Nutzerbild `IMG_2011.jpeg`: R2/R4 sichtbar, längerer Wert als R… abgeschnitten. Der exakte abgeschnittene Wert ist nicht lesbar. Halbwerte wie 2,5 müssen vollständig lesbar sein.

Bevorzugte Spaltenstruktur:

```text
Satz      kg       Wdh      RIR
1        [70]      [8]      [2]      ✓
2        [55]     [10]     [2,5]     ✓
3        [65]     [12]      [4]      ✓
```

- Beschriftungen einmal oberhalb statt in jeder Zeile.
- Alle gültigen Werte korrekt lokalisiert und ohne Auslassungspunkte.
- Längsten gültigen Wert berücksichtigen, nicht nur eine Ziffer.
- RIR-Position beim Öffnen des Reglers stabil halten.
- Scheibenrechner erreichbar, aber keine Überdeckung von Zahlen/Einheiten/Touch-Flächen.
- Bei schmalen Displays/großer Schrift gezielter Layout-Fallback, etwa zwei Zeilen.
- Dezimalgewichte, hohe Gewichte, Bodyweight und kg/lbs testen.
- Cardio/Halteübungen nicht neu RIR-pflichtig machen.
- Keine Daten-/Timeränderung durch Darstellungsfix; vollständige Accessibility-Labels.

## 9. Architektur und Kompatibilität

Entwurf, Berechnung und Persistenz trennen. Stabile Identitäten für Einheiten und Fixierungen, nicht flüchtige Indizes. Generatoradapter mit expliziten Ein-/Ausgaben außerhalb der Views. Bestehende Callbacks aus Onboarding/Profil/Planbibliothek erhalten oder alle Aufrufer kontrolliert migrieren.

Kein früher Plan-Insert durch Vorschau. Speichern mit Fehlerbehandlung und Schutz vor Mehrfachtaps. Bei Fehler Entwurf behalten, keine Erfolgsmeldung. Aktivierung konsistent abschließen.

Modelländerungen nur bei Bedarf. Bestehende Store-Migration, Defaults und Versionierung tatsächlich prüfen. Export/Import neuer Felder und älterer Dateien mitführen. Fachlich passende Cardio-Strukturen statt unkritischer Übernahme beliebiger Kraft-/Zeitformat-Enums.

## 10. Abnahme und Nichtregression

Verbindliche Matrix in Dokument 04. Zusätzlich:

- Bestehende Messung per Haken aktualisiert, keine Dopplung; Löschen unten.
- Mehrstufiges Zurückwischen funktioniert wiederholt.
- Trainingsseiten-Swipes und Listen-Drag-&-Drop erhalten.
- Start-Check nur im Onboarding.
- Header und Zeilen auf kleiner/normaler Breite, Dynamic Type, Light/Dark, DE/EN/TR prüfen.
- Tatsächlichen Apple-Test-/Buildstatus von Linux unterscheiden.

Langfristige Plan-Checks gemäß Dokument 03 nicht als ungefragten automatischen Planwechsel in diesen Builder integrieren.
