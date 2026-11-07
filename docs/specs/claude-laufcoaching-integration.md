# Deltiq – Laufcoaching als integrierter Trainingsbegleiter

**Zweck:** Architektur- und Umsetzungsspezifikation für Claude Code  
**Repository:** `iamati231/fitnessapp_ios`  
**Arbeitsbasis:** Branch `claude/ponytail-audit-16a17f` (vor Änderungen aktuellen HEAD und Repo-Zustand prüfen)  
**Status:** Produktanforderungen; zunächst Code-Audit und Lösungsvorschlag, keine Implementierung bis zur Freigabe  
**Wichtig:** Dieses Dokument beschreibt gewünschtes Verhalten, nicht den bereits verifizierten Ist-Zustand des Codes.

---

## 1. Zielbild

Laufcoaching soll kein isolierter Schalter sein und nicht bloß gelegentlich einen Laufplan vorschlagen. Wenn es aktiviert ist, wird es zu einem integrierten Begleiter für Nutzer, deren Trainingsziel Laufen/Ausdauer einschließt.

Die Funktion muss sich konsistent durch drei Kernbereiche ziehen:

1. **Plan bauen:** Die Plan-Generierung berücksichtigt das aktive Laufcoaching und integriert Lauftraining, wenn das übergeordnete Trainingsziel Laufen/Ausdauer einschließt. Sie darf nicht einfach einen separaten Laufplan als unverbundene Empfehlung danebenstellen.
2. **Aktiven Plan:** Wenn bereits ein Plan existiert und Laufcoaching aktiviert wird oder die Ziele angepasst werden, fragt Deltiq ausdrücklich, ob der aktive Plan um passende Laufeinheiten ergänzt bzw. angepasst werden soll. Nie stillschweigend einen aktiven Plan verändern.
3. **Heute/Dashboard:** Bei aktivem Laufcoaching erscheint eine eigene Laufcoaching-Karte **direkt unter der Hero-Karte bzw. den Hero-Kennzahlen**, oberhalb der übrigen Dashboard-Karten. Sie zeigt die relevanten Laufeinheiten und den nächsten sinnvollen Schritt.
4. **Planansicht und Trainingstag:** Laufeinheiten werden im Plan als echte, verständliche Trainingstage dargestellt – mit Laufziel, Distanz und zielgerechtem Tempo bzw. Pace-Vorgabe. Die Vorgaben richten sich nach dem gewählten Cardio-Ziel und den verfügbaren Baseline-Daten, nicht nach einem beliebigen statischen Standard.

Die Lösung muss sich in die bestehende Deltiq-Architektur und Designsysteme einfügen. Vorhandene Planungs-, Cardio-, Dashboard-Widget-, Lokalisierungs- und Persistenzmechanismen sind zu untersuchen und möglichst wiederzuverwenden.

## 2. Produktregeln und Abgrenzung

- Laufcoaching ist nur aktiv, wenn der Nutzer es in seinem Profil aktiviert hat.
- Das übergeordnete **Trainingsziel** (z. B. Kraft, Ausdauer, Hybrid) und das **Cardio-Ziel** (z. B. allgemeine Fitness, 5 km, 10 km) sind unterschiedliche Konzepte. UI-Texte und Logik dürfen sie nicht verwechseln.
- Wenn das Trainingsziel Laufen/Ausdauer nicht einschließt, darf die Aktivierung des Laufcoaches nicht ungefragt den gesamten Krafttrainingsplan in einen Laufplan verwandeln. Claude soll die bestehende Zielmodellierung untersuchen und eine klare Regel für Kraft-/Hybrid-/Ausdauer-Ziele vorschlagen.
- Wenn das Trainingsziel Laufen/Ausdauer einschließt und Laufcoaching aktiv ist, muss die Plan-Generierung Läufe als Teil des Wochenplans berücksichtigen. Kein loses „Laufplan vorgeschlagen“-Ergebnis, das außerhalb des eigentlichen Plans steht.
- Der Nutzer muss verstehen, welche Laufeinheiten geplant sind, warum sie zum Ziel passen und wie sie mit Krafttrainingstagen zusammenwirken.
- Bestehende Trainingsdaten, vergangene Workouts und aktive Planänderungen sind zu respektieren. Bestehende Daten nicht destruktiv migrieren oder löschen.
- Bestehende Nutzer dürfen nicht unerwartet einen neuen Plan, neue Trainingsziele oder eine aktivierte Funktion erhalten.
- Die bisherige Laufcoach-Aktivierung hat laut Einstellungs-Audit asymmetrisches Speicherverhalten (Ausschalten sofort, Einschalten erst nach Speichern). Im Code prüfen und in einem Lösungsvorschlag konsistent machen. Während dieses Spezifikationsschritts noch nicht ändern.

## 3. Anforderung A – Plan bauen und Trainingsziel integrieren

Bei der Generierung eines neuen Plans:

- Prüfen, ob Laufcoaching aktiviert ist.
- Prüfen, ob das übergeordnete Trainingsziel Laufen/Ausdauer einschließt.
- Bei passender Kombination echte Laufeinheiten in die Wochenstruktur integrieren.
- Kraft- und Laufeinheiten sinnvoll über die Woche verteilen; verfügbare Trainingstage, Trainingsort, Ausstattung, bisheriges Volumen und bekannte Cardio-Baseline berücksichtigen, soweit die bestehende Architektur diese Daten unterstützt.
- Die Läufe sollen einen konkreten Trainingszweck haben (z. B. locker/Grundlage, Qualität/Tempo, längerer Lauf – nur soweit passend zum Ziel und zur verfügbaren Datenbasis).
- Anzahl und Belastung der Laufeinheiten müssen realistisch zum hinterlegten wöchentlichen Basisvolumen und zum Erfahrungs-/Leistungsstand passen. Keine unbegründeten abrupten Steigerungen.
- Bei fehlenden Angaben nicht so tun, als seien präzise Trainingszonen bekannt. Eine sichere, nachvollziehbare Fallback-Vorgabe verwenden und fehlende Baseline ggf. schrittweise erfragen.
- Wenn Laufcoaching aus ist, darf die bisherige Plan-Generierung nicht unbeabsichtigt verändert werden.
- Keine doppelte Planung: Ein Lauf darf nicht zusätzlich als separate Empfehlung auftauchen, wenn er bereits als reguläre Einheit im Wochenplan enthalten ist.

**Zu klären im Code-Audit:** Wo wird der Wochenplan zusammengesetzt? Welche bestehende Plan-/Exercise-/Cardio-Abstraktion kann Laufeinheiten aufnehmen? Gibt es bereits Cardio-Session-Typen, Coach-Advisor, Baseline-Calculator oder eine andere Quelle für Distanz-/Pace-Ziele? Keine parallele zweite Planungsarchitektur bauen, bevor bestehende Mechanismen verstanden sind.

## 4. Anforderung B – Aktiven Plan anpassen, mit Zustimmung

Wenn ein aktiver Plan vorhanden ist und der Nutzer Laufcoaching aktiviert oder die relevanten Ziele so ändert, dass Laufen einbezogen werden soll:

- Eine klare Bestätigungsoberfläche anzeigen, sinngemäß: **„Soll dein aktueller Plan auch um passende Laufeinheiten ergänzt werden?“**
- Kurz erklären, dass Deltiq die Wochenstruktur und die Laufeinheiten passend zum Cardio-Ziel überprüfen wird.
- Mindestens die Optionen **„Plan anpassen“** und **„Nicht jetzt“** anbieten. Keine Anpassung ohne explizite Zustimmung.
- Bei „Nicht jetzt“ bleibt der bestehende Plan unverändert; Laufcoaching kann trotzdem aktiv bleiben. Das Dashboard kann den Laufcoach-Status zeigen, aber darf nicht fälschlich behaupten, dass bereits Laufeinheiten im aktiven Plan enthalten sind.
- Bei Zustimmung eine Vorschau der Änderungen bereitstellen, wenn die bestehende Plan-Architektur das ermöglicht: hinzugefügte/geänderte Lauftage, Ziel, Distanz und Pace; Konflikte mit Krafttrainingstagen deutlich machen.
- Änderungen nach Möglichkeit als nachvollziehbare Planrevision anwenden und nicht den gesamten aktiven Plan unnötig neu erzeugen. Bestehende abgeschlossene Trainings und historische Daten bleiben unberührt.
- Bei bereits vorhandenen Laufeinheiten Duplikate vermeiden und bestehende Einheiten nur dann verändern, wenn dies Teil der bestätigten Vorschau ist.
- Der Dialog darf nicht bei jedem Dashboard-Aufruf erneut erscheinen. Den Auslöser/Zustand so modellieren, dass eine Entscheidung nicht wiederholt aufgedrängt wird, solange sich die relevanten Bedingungen nicht geändert haben.

**Zu klären:** Welche bestehenden Dialoge/Flows werden bereits bei Änderungen an Trainingsort, Equipment oder Cardio-Coaching ausgelöst? Den vorhandenen Mechanismus bevorzugen und dessen Verhalten konsistent erweitern.

## 5. Anforderung C – Laufcoaching-Karte im Heute/Dashboard-Tab

Wenn Laufcoaching aktiv ist, soll eine eigene Laufkarte **ganz oben direkt unter der Hero-Karte bzw. den Hero-Kennzahlen** erscheinen.

Die Karte soll – abhängig vom Status und den verfügbaren Daten – relevante Inhalte zeigen:

- Laufcoaching-Status und das gewählte Cardio-Ziel.
- Nächste geplante Laufeinheit bzw. Lauf-Einheiten der aktuellen Trainingswoche.
- Pro Einheit: verständlicher Lauf-Typ/Zweck, Distanz oder Dauer, Zieltempo/Pace bzw. Intensitätsvorgabe und geplanter Tag.
- Bei einer Einheit am aktuellen Tag eine klare Aktion, um Details zu öffnen bzw. das Training zu starten, sofern ein passender bestehender Flow existiert.
- Bei fehlender Laufeinheit im aktiven Plan einen ehrlichen Zustand mit passender Aktion, z. B. den Nutzer fragen, ob der aktive Plan angepasst werden soll – nicht eine erfundene Einheit anzeigen.
- Bei unvollständiger Baseline keine scheinpräzisen Pace-Werte anzeigen. Stattdessen eine passende, verständliche Intensitätsvorgabe und ggf. Hinweis, welche Referenzdaten noch fehlen.

Layout und Verhalten müssen zum Deltiq-Designsystem passen. Die Karte soll vor den übrigen konfigurierbaren Dashboard-Widgets liegen, ohne deren gespeicherte Reihenfolge oder Einstellungen unerwartet zu überschreiben. Bestehende Nutzer-Widget-Konfigurationen müssen erhalten bleiben. Neue Installationen und Bestandsnutzer sind entsprechend der vorhandenen Dashboard-Widget-Konventionen zu behandeln.

Wenn Laufcoaching deaktiviert ist, wird die Karte nicht angezeigt. Prüfen, ob die Karte ein fester Coach-Bereich oder ein Eintrag im bestehenden Widget-System sein sollte; im Audit begründet entscheiden und keine zweite, widersprüchliche Dashboard-Konfiguration schaffen.

## 6. Anforderung D – Laufeinheiten in Plan und Trainingstag

Läufe müssen in der Planansicht klar als Laufeinheiten erkennbar sein und dürfen nicht wie normale Krafttrainingstage mit leeren oder unpassenden Satz-/Wiederholungsfeldern aussehen.

Jede Laufeinheit soll, sofern vorhanden, enthalten:

- Laufart bzw. Trainingszweck.
- Ziel und Kontext der Einheit.
- Zieldistanz und/oder Dauer.
- Zieltempo/Pace oder eine sinnvollere Intensitätsvorgabe, falls Pace-Daten fehlen.
- Bei strukturierten Laufeinheiten Abschnitte/Intervalle und deren Vorgaben, sofern das bestehende Datenmodell dies unterstützt.
- Hinweise zu Aufwärmen/Abkühlen nur, wenn sie zur Einheit gehören und verständlich dargestellt werden.
- Einheitliche Anzeige von Einheiten und Zahlen gemäß den bestehenden Formatierungs- und Lokalisierungsregeln.

Die konkreten Werte richten sich nach dem Cardio-Ziel, der 5-km-Referenzzeit, dem wöchentlichen Basisvolumen und weiteren tatsächlich unterstützten Baseline-Daten. Die maximale Herzfrequenz darf laut bestehendem Einstellungs-Audit derzeit nicht als wirksam vorausgesetzt werden: Sie wird zwar gespeichert, aber in der Core-Zonenberechnung offenbar nicht gelesen. Vor Verwendung muss Claude das erneut verifizieren und darf keine nicht implementierte Pulszonen-Funktion unterstellen.

Die Laufdetails sollen in der Planansicht lesbar sein und am Trainingstag dieselben Zielvorgaben zeigen. Es darf keine Diskrepanz geben zwischen der Dashboard-Karte, dem Plan und der geöffneten Laufeinheit. Abgeschlossene Einheiten und ihre ursprünglichen Sollwerte müssen historisch stabil bleiben, wenn der Plan später angepasst wird.

**Architekturfrage für das Audit:** Kann das vorhandene Planmodell Cardio-Einheiten bereits ausdrücken? Falls nicht, soll Claude die kleinste tragfähige, rückwärtskompatible Erweiterung vorschlagen, statt Laufdaten in unpassende Krafttrainingsfelder zu quetschen.

## 7. KI-Einsatz und Grenzen

KI ist optional und nur dann einzusetzen, wenn sie gegenüber vorhandener deterministischer Logik einen konkreten Mehrwert bietet. Trainingssicherheit, Zahlenkonsistenz und Plan-Integrität dürfen nicht von frei generierten Texten abhängen.

- Zuerst bestehende lokale KI-Architektur und vorhandene Cardio-Coaching-/Planungslogik untersuchen.
- Distanz-, Pace-, Wochenvolumen- und Terminberechnungen müssen deterministisch und testbar bleiben. KI darf sie nicht frei erfinden oder als alleinige Quelle berechnen.
- Falls KI für verständliche Erläuterungen, adaptive Vorschläge oder eine natürlichsprachliche Zusammenfassung nützlich ist, nur eine bestehende geeignete Abstraktion verwenden und ihre Grenzen benennen.
- Bereits festgelegte Plattformregel beibehalten: App bleibt ab iOS 17 nutzbar. Lokale Foundation-Models-/On-Device-KI nur auf iOS 26+ und kompatiblen Geräten; **kein Cloud-Fallback**. Auf nicht unterstützten Geräten muss das Laufcoaching weiterhin deterministisch funktionieren.
- Bei nicht verfügbarer KI muss ein klarer regelbasierter/manualer Weg bestehen. KI-Ausfall darf die Planerstellung, Anzeige oder Speicherung nicht blockieren.
- Keine KI für eine Aufgabe einbauen, die mit vorhandener deterministischer Core-Logik einfacher, sicherer und besser testbar ist.

## 8. Lokalisierung, Barrierefreiheit und Design

- Alle neuen Texte über das bestehende Lokalisierungssystem abdecken: mindestens Deutsch, Englisch und Türkisch.
- Keine hartkodierten deutschen UI-Texte und keine lokalisierten Werte direkt in Persistenzschlüsseln speichern.
- Dynamische Werte (km/mi, min/km oder vorhandene alternative Pace-Einheiten) gemäß bestehender Einheiten- und Formatierungsregeln darstellen. Nicht ungeprüft annehmen, dass Gewichtseinheiten auch Distanz-/Pace-Einheiten steuern.
- Bestehende Deltiq-Komponenten, Farben, Abstände, Button-Stile und Navigationsmuster verwenden.
- VoiceOver-/Accessibility-Labels und dynamische Schriftgrößen berücksichtigen.
- Status, Ladezustand, leere Zustände und Fehlerzustände sinnvoll behandeln.

## 9. Persistenz, Migration und Kompatibilität

- Vorhandene Nutzerdaten und aktive Pläne nicht destruktiv verändern.
- Neue persistierte Felder benötigen eine kompatible SwiftData-Migration bzw. einen nachweislich sicheren Schema-Ansatz.
- Vorhandene Nutzer, bei denen Laufcoaching deaktiviert ist, behalten das bisherige Verhalten.
- Die Entscheidung „aktiven Plan anpassen / nicht jetzt“ darf nicht bei jedem Start erneut abgefragt werden.
- Historische absolvierte Workouts müssen ihre ursprünglichen Soll-/Ist-Werte behalten.
- App-Kompatibilität ab iOS 17 erhalten; APIs ab iOS 26 müssen korrekt verfügbarkeitsgeprüft werden.

## 10. Erwarteter Ablauf von Claude Code

### Phase 1 – Nur Audit und Lösungsvorschlag

Zuerst den aktuellen Branch und Arbeitsbaum prüfen und dann den relevanten Code vollständig nachvollziehen, insbesondere:

- Profilfelder und Cardio-Coaching-Einstellungen.
- Plan-Generierung und aktive-Plan-Anpassungsflows.
- Cardio-Baseline, Pace-/Zielberechnung und bestehende Coach-Logik.
- Datenmodell für geplante Einheiten, Workout-Details und historische Sessions.
- Dashboard-Hero, Widget-Reihenfolge, Widget-Persistenz und Deep Links.
- Lokalisierung DE/EN/TR, iOS-Verfügbarkeit und ggf. bestehende lokale KI.
- Tests, die Planerstellung, Planänderungen, Dashboard-Widgets, Cardio-Vorgaben und Persistenz absichern.

Erstelle danach einen kurzen, konkreten Implementierungsvorschlag mit:
1. Ist-Architektur und relevanten Dateien/Symbolen.
2. Vorgeschlagener Datenfluss von Profil → Plan-Generierung → aktiver Plan → Dashboard → Laufdetail.
3. Datenmodell-/Migrationsbedarf.
4. Umgang mit bereits aktiven Plänen und Duplikaten.
5. Regeln für Distanz/Pace bei vollständiger bzw. fehlender Baseline.
6. Entscheidung, ob und wo KI einen tatsächlichen Mehrwert bietet.
7. Tests und Akzeptanzkriterien.
8. Risiken, offene Produktentscheidungen und eine empfohlene Reihenfolge der Arbeit.

**In dieser Phase keine Quellcodeänderungen, keine Tests ausführen, keine Commits und keinen Implementierungsplan anlegen.** Ergebnisse zur Review vorlegen und auf Freigabe warten.

### Phase 2 – Nach Freigabe

Erst nach ausdrücklicher Freigabe die Spezifikation konkretisieren und anschließend einen überprüfbaren Implementierungsplan erstellen. Nach Freigabe darf Claude die freigegebenen Änderungen gemäß Projektkonventionen implementieren, Tests ausführen, Fehler beheben und Ergebnisse dokumentieren. Keine zusätzlichen kostenpflichtigen Dienste oder externen KI-APIs einführen.

## 11. Akzeptanzkriterien für die spätere Implementierung

- [ ] Laufcoaching aktiv + Trainingsziel umfasst Laufen/Ausdauer: neu generierter Plan enthält passende, echte Laufeinheiten in der Wochenstruktur.
- [ ] Laufcoaching deaktiviert: bestehende Plan-Generierung bleibt im bisherigen Verhalten.
- [ ] Bei bestehendem aktivem Plan fragt die App vor einer Anpassung explizit nach Zustimmung.
- [ ] Ablehnung lässt den aktiven Plan unverändert; keine wiederholten unerwünschten Dialoge.
- [ ] Zustimmung zeigt nachvollziehbare Änderungen und vermeidet doppelte Laufeinheiten.
- [ ] Bei aktivem Laufcoaching steht die Laufkarte direkt unter den Hero-Kennzahlen im Heute-Tab.
- [ ] Die Karte zeigt tatsächliche geplante Einheiten und erfindet keine, wenn keine im aktiven Plan enthalten sind.
- [ ] Planansicht und Laufdetail zeigen konsistente Laufziele, Distanz und Tempo/Intensität.
- [ ] Pace-Vorgaben verwenden nur nachweislich unterstützte Baseline-Berechnungen; fehlende Daten führen zu einem sinnvollen Fallback.
- [ ] Bestehende abgeschlossene Trainings und bisherige Dashboard-Konfigurationen bleiben erhalten.
- [ ] DE/EN/TR sind vollständig lokalisiert.
- [ ] App funktioniert ab iOS 17; lokale KI bleibt optional, iOS-26+-gebunden und ohne Cloud-Fallback.
- [ ] Relevante Unit-/Integrationstests decken Zielkombinationen, Zustimmung/Ablehnung, Duplikatvermeidung, Fallbacks und Dashboard-Sichtbarkeit ab.
