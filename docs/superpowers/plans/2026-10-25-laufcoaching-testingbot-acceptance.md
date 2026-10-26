# Laufcoaching – TestingBot-Geräteabnahme

Datum: 2026-10-25  
Zielbranch: `claude/ponytail-audit-16a17f`  
Bekannter Stand vor diesem Auftrag: `cf9e03d`

## Auftrag an Claude

Bitte führe nach Abschluss der Laufcoaching-Remediation-Runde 2 eine **reale UI-/Geräteabnahme über TestingBot** durch. Die CI und der Modellebene-Integrationstest sind bereits grün; jetzt soll geprüft werden, ob der tatsächliche Nutzerfluss auf einem verfügbaren iOS-Gerät bzw. Simulator korrekt funktioniert.

### Regeln

- Arbeite auf `claude/ponytail-audit-16a17f` und verifiziere zuerst den aktuellen Branch-Stand. Erwarte mindestens den bekannten Commit `cf9e03d`; überschreibe oder verwirf keine vorhandenen Änderungen.
- Nutze ausschließlich vorhandene TestingBot-Konfiguration und bereits verfügbare Credits. **Keine kostenpflichtigen Zusatzkäufe, kein Upgrade und keine zusätzlichen Kosten ohne ausdrückliche Freigabe.**
- Keine Feature-Änderungen, kein Merge und kein Pull Request im Rahmen dieses Testauftrags.
- Falls TestingBot-Konfiguration, Zugangsdaten, ein lauffähiger Build oder die erforderliche Geräteumgebung fehlen, nicht improvisieren und keine erfolgreiche Ausführung behaupten. Dokumentiere die Blockade und was benötigt wird.
- Bevorzuge reproduzierbare Tests und sichere Testdaten. Vermeide destruktive Änderungen an echten Nutzerdaten.

## Zu prüfender Ablauf

1. App auf dem verfügbaren iOS-Gerät starten und Laufcoaching aktivieren.
2. Im Onboarding bzw. Profil ein Cardio-Ziel auswählen.
3. Einen Trainingsplan generieren und prüfen, dass das Ziel den Lauftyp-Mix tatsächlich beeinflusst.
4. Mit vorhandener Wochenbasis und Referenzzeit prüfen, ob Umfang und Pace plausibel dargestellt werden.
5. Einen aktiven Plan öffnen und die Laufcoaching-Anpassungsvorschau anzeigen.
6. Der Anpassung zustimmen und den tatsächlich übernommenen Trainingstag öffnen.
7. Prüfen, dass die Ziel-Pace dort weiterhin sichtbar ist und zur übernommenen Anpassung passt.
8. Prüfen, dass nach erfolgreicher Übernahme keine erneut unapplizierte Anpassungskarte für dieselbe Änderung erscheint.
9. Laufcoaching deaktivieren und prüfen, dass keine unpassende Coach-Pace angezeigt wird.
10. Ohne Referenzzeit prüfen, dass keine erfundene oder irreführend präzise Ziel-Pace erscheint; die vorgesehene Fallback-Anzeige muss funktionieren.

## Ergebnisbericht

Bitte dokumentiere:
- TestingBot-Gerät/iOS-Version, Build und getesteten Commit;
- jeden Prüfschritt mit **Bestanden / Fehlgeschlagen / Blockiert**;
- relevante Screenshots, Logs oder Session-Links, sofern TestingBot sie bereitstellt;
- reproduzierbare Fehler inklusive Schritte und erwartetes/tatsächliches Verhalten;
- ob Fehlerbehebungen nötig sind. Ändere bei Fehlern nicht stillschweigend den Umfang: beschreibe den Befund und schlage einen gezielten Fix vor;
- abschließenden Status der bestehenden CI-Tests, falls sie im Zuge des Auftrags erneut ausgeführt werden.

Erst nach Vorlage des Testberichts wird über PR und Merge entschieden.
