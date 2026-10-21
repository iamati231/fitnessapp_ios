# 04 – Gemeinsame Teststrategie und Abnahme

## Ziel

Dieses Dokument gilt für alle anderen Dateien. Funktionsumfang, Testabdeckung und tatsächlich ausgeführte Verifikation getrennt dokumentieren.

## 1. Testebenen

### Domänen-/Unit-Tests

Berechnung, Zustandsübergänge, Datenqualität, Auswahl, Fixierungen, Vorschläge, Dirty-Erkennung und Vergleich möglichst ohne lebende UI testen. Nicht nur Lookup-Helper, sondern auch die konsumierende Entscheidungslogik prüfen.

### Daten-/Integrationstests

Persistenz, erneutes Laden, Migration, Planversionen, Aktivierung, doppelte Bestätigung, Export/Import, Onboarding-Abschluss und fehlgeschlagene Übernahme prüfen. In-Memory-Getter/Setter allein beweisen keinen App-Neustart oder Store-Migration.

### Apple-Build und Apple-Tests

Echte Toolchain-Ergebnisse erfassen. Wenn `canImport(SwiftUI/SwiftData/UIKit)` auf Linux false ist, sind diese Teile dort nicht verifiziert. macOS-Test und iOS-Build unterscheiden; UIKit- und iOS-only-Pfade brauchen passende Prüfung.

### UI-/Gerätetests

Echte Navigation, RIR-Layout, Gesten, Drag & Drop, Fokus/Tastatur, VoiceOver und Entwurfsschutz mit geeignetem Simulator/Gerät prüfen. Wo möglich automatisieren. „Nicht automatisiert“ nicht pauschal als „nicht automatisierbar“ darstellen.

## 2. Testmatrix

| ID | Szenario | Erwartung |
|---|---|---|
| A01 | Onboarding-Ziel/Tage/Equipment bereits beantwortet | Keine erneute identische Befragung |
| A02 | Gemeinsamer Builder und Onboarding mit gleichen Eingaben | Gleiche fachliche Planung bei gleicher expliziter Variante |
| A03 | Hybrid + Laufen ohne Coach | Kraft/Laufen im Vorschlag, Coach aus |
| A04 | Hybrid + Laufen mit Coach | Coachentscheidung und unterstütztes Ziel übernommen |
| A05 | Hybrid + Radfahren | Keine unnötige Laufcoach-Frage |
| A06 | Laufen/Radfahren kombiniert | Auswahl bleibt nach Coachingentscheidung bestehen |
| A07 | Coach an → aus | Gewollte Laufeinheiten bleiben; keine aktiven Coachempfehlungen |
| A08 | Ausdauerform wechseln und zurückgehen | Kein veralteter Status/Planinhalt |
| A09 | Unbekannte Referenzleistung | Keine erfundenen Werte oder stille Nullannahme |
| A10 | Eingebetteten Editor bestätigen | Nur Onboarding-Entwurf geändert |
| A11 | Onboarding abbrechen/mehrfach abschließen | Keine verwaisten/doppelten Pläne |
| B01 | Wocheneditor Drag & Drop | Reihenfolge korrekt, alternative Bedienung möglich |
| B02 | Inhalt fixiert, Woche neu verteilen | Inhalt bleibt, Position nach Regel behandelbar |
| B03 | Position fixiert, Übungen variieren | Position bleibt, erlaubter Inhalt veränderbar |
| B04 | Manuelle Änderungen + Neuberechnung | Keine stillen Verluste |
| B05 | Keine passende Lösung | Sichtbarer Konflikt statt abgeschnittener Einheiten |
| B06 | Mehrfach auf Haken tippen/Fehler beim Speichern | Keine Duplikate, Entwurf bei Fehler erhalten |
| C01 | Cardio-/Laufziel speichern | Gebündelte Vorschau, kein stilles Bulk-Update |
| C02 | Plananpassung ablehnen | Profilentscheidung bleibt, Plan unverändert |
| C03 | Equipment nicht vorhanden | Betroffene Übungen mit begründetem Ersatz |
| C04 | Nur Präferenz ändern | Optionale Neugewichtung, kein Geräteverbot |
| C05 | Bank/Klimmzugstange unbekannt | Bleibt nach Neustart, Bestätigung und Export/Import unbekannt |
| C06 | Laufende Session + Planänderung | Sessionstruktur/Logs bleiben konsistent |
| D01 | Reines Reorder + Verwerfen | Originalreihenfolge wiederhergestellt |
| D02 | Add/Delete + Reorder + Verwerfen | Definiertes Verhalten, keine Sortierkollision |
| D03 | Name/Ton ändern, separate Aktion bestätigen | Unabhängiger Edit bleibt verwerfbar |
| D04 | A aktiv → B an → B aus → Verwerfen | Ausgangsaktivierung wiederhergestellt |
| D05 | Inaktiver Plan ohne anderen aktiven Plan | Unverändert nicht dirty |
| D06 | Rückrollen von Trainingsort | Keine erneut ausgelöste Migration beim Schließen |
| E01 | Körpermessung per Haken bearbeiten | Bestehende Messung aktualisiert, kein Duplikat |
| E02 | Cooldown vorgesehen/ausgeblendet/nicht vorhanden | Jeweils nachvollziehbare Anzeige, keine leere Pflichtsektion |
| E03 | Alle gültigen RIR-Ganz-/Halbwerte | Vollständig sichtbar und korrekt gespeichert |
| E04 | Schmaler Bildschirm, große Schrift, Dezimalgewicht, kg/lbs | Kein Abschneiden/Overflow/Überdecken von Eingaben |
| E05 | Mehrstufig zurückwischen | Wiederholt eine Ebene zurück, keine dauerhafte Sperre |
| E06 | Ungespeicherter Entwurf + Schließgeste | Kein Umgehen des Schutzes |
| E07 | Trainingsseiten wechseln und Listen ziehen | Bestehende Gesten erhalten |
| E08 | Start-Check-Einstiege suchen | Nur im Onboarding erreichbar |
| F01 | Vier Wochen mit viel/wenig Teilnahme | Datenabhängige Empfehlung, keine starre gleiche Steigerung |
| F02 | Flexibler Plan/Pause/Planwechsel | Keine erfundene Compliance oder falscher Nenner |
| F03 | Gute Entwicklung | „Beibehalten“ als gültiges Ergebnis |
| F04 | Ausgelassene Beintage/Brustschwerpunkt | Rückfrage bzw. Zielbezug statt Kalender-Zwangswechsel |
| F05 | Beschwerden/fehlende RIR-Daten | Keine Diagnose oder erfundene Erholung |
| F06 | Review ablehnen/aufschieben/wieder öffnen | Keine Doppeländerung oder Hinweisschleife |
| F07 | Review übernehmen | Neue gültige Fassung, Historie unverändert |
| F08 | Gleichzeitige Progressions-/Deload-/Review-Hinweise | Keine widersprüchlichen Vorschläge |

## 3. Oberflächenprüfung

Mindestens kleine und normale iPhone-Breite, Light/Dark, große Schrift und DE/EN/TR prüfen. Dialogtitel und Accessibility-Labels beschreiben den tatsächlichen Vorgang: Entwurf übernehmen ist nicht final speichern. Ein Haken ist nie gleichzeitig Sortiermodus-Ende und Editorabschluss.

RIR-Testwerte aus dem tatsächlichen gültigen Wertebereich nehmen. Der bereitgestellte Screenshot belegt R…-Trunkierung, nicht den exakten abgeschnittenen Zahlenwert.

## 4. Migrations-/Kompatibilitätsprüfung

Bei persistenten Änderungen einen Bestandsspeicher aus dem vorherigen Schema öffnen. Alte Exporte ohne neue Felder importieren. Explizites Unknown und niemals erfasste Werte nicht vermischen. Keine erfundenen historischen Planversionen erzeugen. Daten nach Speichern in einem neuen Kontext beziehungsweise nach Neustart prüfen.

## 5. Abnahmebericht pro Paket

```text
Paket:
Implementiert:
Noch nicht implementiert:
Geänderte Komponenten:
Neue/geänderte Datenfelder:
Tests hinzugefügt:
Tests tatsächlich ausgeführt (Plattform, Befehl, Ergebnis):
Apple-Build/CI (konkreter Lauf oder nicht verifiziert):
UI-/Geräteprüfung:
Bekannte Grenzen/Risiken:
Branch/Commit (nur tatsächlich vorhandene):
Nächste Aufgabe:
```

Unbekannter CI-Status bleibt unbekannt. Ein automatischer Trigger in einer YAML-Datei belegt keinen erfolgreichen Lauf. Keine pauschale Aussage „alles grün“, wenn relevante Testdateien ausgeschlossen waren.

## Definition of Done

Alle für das jeweilige Paket verbindlichen Fälle sind implementiert und angemessen geprüft. Offene Geräteprüfungen oder fehlende Apple-Kompilierung verhindern die Bezeichnung „vollständig verifiziert“. Teilabnahmen sind möglich, müssen ihren Umfang nennen. Kein erfolgreicher Linux-Lauf ersetzt Apple-/UI-Verifikation.
