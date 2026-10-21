# 02 – Onboarding, Hybrid und Laufcoach: eine Planung, zwei Einstiegstiefen

## Produktentscheidung

Der neue zielorientierte A+B-Planer gilt auch für das Onboarding. Aber nicht als zweiter kompletter Assistent nach den bereits beantworteten Fragen.

> Dieselbe Planung, dieselben Wochenkarten und dieselben Bearbeitungsregeln – im Onboarding geführt und kompakt, später direkt und ausführlich.

Das Onboarding soll zu einer verständlichen ersten Woche führen, ohne sämtliche Expertenfunktionen zu erzwingen. Bestehende sinnvolle Profil-/Gesundheits-/Einwilligungsschritte nicht blind durch dieses Konzept ersetzen.

## 1. Gemeinsame Grundlage statt doppelter Formulare

- Onboarding-Antworten bilden einen gemeinsamen Planungskontext.
- Der eigenständige Builder liest denselben Kontext aus dem gespeicherten Profil und erlaubt planbezogene Abweichungen.
- Dieselben Eingaben sollen bei gleichem Generatorstand und gleicher expliziter Variantenwahl zum gleichen fachlichen Vorschlag führen.
- Keine erneute Frage nach Ziel, Erfahrung, Ort, Ausstattung, Tagen oder Zeit, wenn diese Angaben bereits vorliegen.
- Änderungen in der Wochenvorschau aktualisieren den Entwurf und die relevante Zusammenfassung konsistent.
- Wenn eine Änderung zusätzliche Angaben erfordert, nur diese gezielt nachfragen.

Die konkrete API an vorhandene Architektur anpassen. Konzeptuell: Planungskontext + Modus + Entwurf + Validierung; kein eigener Onboarding-Generator.

## 2. Zielauswahl und Hybrid

„Hybrid“ bedeutet zunächst Kraft und Ausdauer kombinieren. Es bedeutet NICHT automatisch Laufen, Laufcoach oder ein bestimmtes Wettkampfziel.

Nach Auswahl von Hybrid:

1. Ausdauerform klären.
2. Trainingsrahmen berücksichtigen.
3. Nur bei Laufen die Coaching-Entscheidung anzeigen.
4. Bei gewünschtem Coach relevante Zielangaben erheben.
5. Einen konkreten gemeinsamen Wochenvorschlag zeigen.

Unterstützte Ausdauerformen sichtbar anbieten, etwa Laufen, Radfahren oder beides. „Noch unsicher – Vorschlag erhalten“ nur anbieten, wenn eine transparente Empfehlung mit anschließender Bestätigung umgesetzt wird. Keine unbekannte Auswahl still in Laufen umwandeln.

Nicht unterstützte Sportarten nicht scheinbar auswählbar machen. Bestehende unterstützte Trainingsformen nicht entfernen.

## 3. Laufeinheiten und Laufcoach getrennt modellieren

Nach Auswahl von Laufen:

### Frage: „Wie möchtest du dein Lauftraining gestalten?“

- „Laufen in meine Woche einplanen“
  - Laufeinheiten im Plan.
  - Zusätzlicher Laufcoach bleibt aus.
- „Mit Laufcoach auf ein Ziel hinarbeiten“
  - Laufeinheiten im Plan.
  - Unterstützte Coaching-Funktionen werden aktiviert.

Kurze Erklärung unter jeder Option. Keine bloße interne Bezeichnung „Cardio-Coaching enabled“.

Verbindliche Zustandsunterschiede:

| Zustand | Geplante Laufeinheiten | Laufcoach |
|---|---|---|
| Hybrid mit Laufen, ohne Coach | ja | aus |
| Hybrid mit Laufen und Coach | ja | an |
| Hybrid nur mit Radfahren | nein | keine Laufcoach-Frage nötig |
| Reines Laufen, ohne Coach | ja | aus |
| Reines Laufen mit Coach | ja | an |

Bei „Laufen und Radfahren“ darf die Coaching-Auswahl nicht das Radfahren löschen. Ausdauerverteilung vorgeschlagen und im Wocheneditor veränderbar.

Ein generischer Cardio-Schalter darf diese Zustände nicht ununterscheidbar machen. Vorhandene Modellfelder und Semantik prüfen; nur bei Bedarf kontrolliert erweitern. Laufcoach nicht allein aufgrund von Hybrid still aktivieren. Die Entscheidung sichtbar machen.

## 4. Laufziel und Ausgangsdaten

Nur bei aktiviertem Coach die dafür relevanten Fragen einblenden. Mögliche Zielgruppen anhand tatsächlich vorhandener Engine prüfen:

- Allgemeine Laufausdauer verbessern.
- Eine unterstützte Distanz schaffen.
- Eine Zeit verbessern.
- Einen Wettkampf vorbereiten.

Nur unterstützte Ziele anbieten. Eine auswählbare Distanz ohne passende Planungs-/Coaching-Wirkung ist kein fertiges Feature.

Je Ziel nur notwendige Angaben:

- Aktuelles Laufpensum, sofern bekannt.
- Verfügbare Referenzleistung, sofern bekannt.
- Zieldatum nur bei einem datierten Ziel.
- Unsicherheit explizit zulassen.

Keine Pace, Herzfrequenz oder Leistungsfähigkeit erfinden. Leeres Feld ist nicht null Leistung. Kein optionaler Start-Check als verdeckte Pflicht. Bei unzureichender Grundlage transparenten, vorsichtigen Einstieg anbieten oder fehlende Unterstützung offen benennen.

Beim Abschalten des Coaches weder vorhandene Laufhistorie noch automatisch alle Laufeinheiten löschen. Wechsel von Laufen zu Radfahren konsistent behandeln: keine aktiven Laufcoach-Empfehlungen für einen ausdrücklich lauflosen neuen Entwurf. Ob Zielangaben inaktiv aufbewahrt werden, dokumentieren; keine ungefragte Datenlöschung.

## 5. Kompakte erste Wochenvorschau

Nach den vorhandenen Onboarding-Fragen direkt „Deine erste Trainingswoche“ zeigen.

Sichtbar ohne Expertenansicht:

- Ziel und Trainingsmix.
- Anzahl und Zeitbedarf der Einheiten.
- Tage oder flexible Reihenfolge.
- Tatsächlich verwendete Ausdauerform.
- Laufcoach an/aus, soweit relevant.
- Laufziel, soweit gewählt.
- Relevante Konflikte/Unsicherheiten.
- Kurze Begründung anhand realer Eingaben.

„Woche anpassen“ öffnet den gemeinsamen Editor aus Dokument 01. Fortgeschrittene können dort Inhalte und Verteilung anpassen; Anfänger müssen das nicht tun. Keine andere Kartensprache oder abweichende Generierungslogik im Onboarding.

## 6. Abschluss, Haken und Navigation

Drei Vorgänge unterscheiden:

1. Nächster Onboarding-Schritt: Navigation, keine finale Speicherung.
2. Eingebetteten Wocheneditor bestätigen: Haken übernimmt Anpassungen NUR in den Onboarding-Entwurf und führt zur Vorschau zurück.
3. Gesamtes Onboarding abschließen: eindeutige beschriftete Hauptaktion, beispielsweise „Mit diesem Plan starten“.

Kein Haken mit gleichzeitig drei Bedeutungen. Auf dem finalen Onboarding-Schritt keine zweite konkurrierende Abschlussaktion. Andere normale Formular-Editoren behalten den Speichern-Haken oben rechts und keinen zweiten Speichern-Button unten.

Zurückgehen zwischen Schritten erhält Antworten. Tatsächliches Verlassen berücksichtigt den bestehenden Entwurfsschutz. Das bestehende Verhalten für Wiederaufnahme nach App-Unterbrechung prüfen; keine langfristige Entwurfspersistenz versprechen, die nicht implementiert ist.

Profil und Plan über den bestehenden Onboarding-Abschluss konsistent übernehmen. Kein vorzeitiger Plan-Insert aus der Vorschau. Fehler müssen korrigierbar sein, ohne verwaiste Daten oder doppelten Abschluss. Bestehende `onGenerated`-/Callback-Verträge erhalten oder kontrolliert an allen Aufrufern ändern.

## 7. Optionaler Weg ohne sofortigen Plan – Entscheidungstor

„Plan später erstellen“ ist ein Produktvorschlag, keine unbedingte Pflichtfunktion. Zuerst prüfen, ob Dashboard, Navigation und Onboarding-Abschluss ohne Plan sinnvoll funktionieren.

Falls unterstützt: bewusst abschließen, klaren Empty-State und späteren Einstieg anbieten. Falls nicht: nicht nur einen Button ergänzen und den Nutzer in eine kaputte App schicken; Grenze und nötige Arbeit dokumentieren.

## 8. Start-Check

- Einstieg ausschließlich im Onboarding.
- Optional, keine Voraussetzung für einen nutzbaren Vorschlag.
- Gespeicherte Ergebnisse dürfen verwendet werden.
- Profil, Wocheneditor und Plan-Review dürfen keinen neuen Wiederholungs-Einstieg einführen.
- Ein kurzer späterer Rückblick auf Alltag/Belastung ist KEIN erneuter Start-Check und erhebt keine Pflicht-Leistungstests.

## 9. Abnahme

Alle Tabellenzustände aus Abschnitt 3 plus diese Fälle prüfen:

- Vor-/Zurücknavigation ändert keine Antworten unbemerkt.
- Coach deaktivieren lässt gewollte Laufeinheiten bestehen.
- Ausdauerform ändern erzeugt keine veraltete Zusammenfassung.
- Fehlende Referenzdaten verhindern nicht kommentarlos den Abschluss.
- Onboarding-Vorschau und eigenständiger Builder verwenden denselben Generatoradapter.
- Wocheneditor abbrechen/übernehmen verändert nur den vorgesehenen Entwurf.
- Onboarding-Abschluss erzeugt genau die beabsichtigten Daten.
- Kein doppeltes Abfragen und kein automatisch eingeführter zusätzlicher Trainingsblock.
