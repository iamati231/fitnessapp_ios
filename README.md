# Deltiq

iOS-App für **Krafttraining, Ausdauer und Körperwerte**: Trainingspläne planen, Workouts Satz für Satz protokollieren, Fortschritt auswerten, Körperzusammensetzung messen und berechnen – alles lokal auf dem Gerät.

*Stand dieser Beschreibung: Oktober 2026 · Version 0.1.x (Beta, Verteilung über TestFlight)*

## Inhalt

1. [Was ist Deltiq?](#1-was-ist-deltiq)
2. [Auf einen Blick](#2-auf-einen-blick)
3. [Die fünf Bereiche der App](#3-die-fünf-bereiche-der-app)
4. [Bedienung Schritt für Schritt](#4-bedienung-schritt-für-schritt)
5. [Alle Funktionen im Detail](#5-alle-funktionen-im-detail)
   - [5.1 Dashboard](#51-dashboard) · [5.2 Plan](#52-plan) · [5.3 Training durchführen](#53-training-durchführen) · [5.4 Auswertung](#54-auswertung) · [5.5 Progression, Deload und Lauf-Coaching](#55-progression-deload-und-lauf-coaching) · [5.6 Messung](#56-messung) · [5.7 Werkzeuge](#57-werkzeuge) · [5.8 Mehr](#58-mehr) · [5.9 Apple Health](#59-apple-health) · [5.10 Daten sichern](#510-daten-sichern) · [5.11 Widgets, Live Activity und Benachrichtigungen](#511-widgets-live-activity-und-benachrichtigungen) · [5.12 Sprache, Design und Datenschutz](#512-sprache-design-und-datenschutz)
6. [Für Tester](#6-für-tester)
7. [Glossar](#7-glossar)
8. [Für Entwickler](#8-für-entwickler)
9. [Offene Punkte](#9-offene-punkte)

---

## 1. Was ist Deltiq?

Deltiq begleitet dich von der Planung bis zur Auswertung: Du wählst oder baust einen Trainingsplan, führst das Training mit Satz-Logging, Pausen-Timer und Zeitformaten (AMRAP, EMOM, Auf Zeit, Zirkel) durch, siehst Rekorde, Trends und Coaching-Hinweise und behältst Gewicht, Körperfett und Wasserzufuhr im Blick. Die App braucht kein Konto und keinen Cloud-Dienst; der Quellcode enthält keine Netzwerkzugriffe.

| | |
|---|---|
| App-Name | **Deltiq** (Bundle-ID `com.atamya.FitnessApp`) |
| Plattform | iOS 17.0 oder neuer · iPhone (nur Hochformat) und iPad |
| Sprachen | Deutsch, Englisch, Türkisch (folgt der iOS-Systemsprache) |
| Technik | SwiftUI, SwiftData, HealthKit, ActivityKit, WidgetKit |
| Daten | lokal auf dem Gerät; Export und Backups als ZIP mit CSV-Dateien |
| Status | Beta, Verteilung über TestFlight |

Entstanden ist das Projekt als iOS-Port einer Android-Fitness-App. Die Berechnungslogik (Körperzusammensetzung, 1RM, Hantelscheiben) ist durch Parity-Tests gegen die Android-Referenzwerte abgesichert.

## 2. Auf einen Blick

| Zahl | Was |
|---|---|
| 5 | Tabs: Dashboard, Plan, Messung, Werkzeuge, Mehr |
| 20 | kuratierte Programm-Vorlagen (Ganzkörper, Push-Pull-Legs, Upper/Lower, Powerlifting, Hybrid Athlete, CrossFit, Kettlebell …) |
| 186 | Übungen in der System-Bibliothek, dazu eigene Übungen |
| 4 | Zeitformate: AMRAP, EMOM, Auf Zeit, Zirkel |
| 12 | Dashboard-Widgets (frei ein-/ausblendbar und sortierbar) |
| 3 | Sprachen mit 1796 Texten (DE, EN, TR jeweils vollständig) |

**Was die App kann**

- **Pläne:** 20 Programm-Vorlagen, der Assistent „Plan bauen“ (rechnet aus Trainingsarten wie „3 Tage Kettlebell + 2 Tage Laufen“ eine Woche), eigene Pläne, Tages- und Übungs-Editor mit Supersätzen und Zeitformaten, Tagesanalyse (Belastung, Muskelfokus, Dauer).
- **Training:** Satz-Logging mit Vorgänger-Hinweis, RIR-Regler, Pausen-Timer (Sperrbildschirm und Dynamic Island), Aufwärm-Rampe, Haltesätze, Cardio mit Distanz und Pace, spontane Workouts, Laufen/Radfahren aus Apple Health importieren, abgeschlossene Trainings (auch frühere) nach Apple Health schreiben.
- **Auswertung:** Zusammenfassung mit Erfolgen und Rekorden, Trainingsverlauf (nachträglich bearbeitbar), Trophy Room, Trends (Gewicht mit Prognose, geschätztes 1RM, Wochenvolumen, Cardio-Pace), Trainingskalender mit Wochenserie, Muskel-Heatmap.
- **Coaching:** Hinweise je Coach-Ton und Trainingsziel, Smart Progression (automatische Gewichtsvorschläge), Deload-Vorschlag, Wiedereinstiegs-Hilfe nach Trainingspausen, Lauf-Machbarkeits-Check.
- **Körperwerte:** Körperfett (Navy und Deurenberg), FFMI, BMI, Grundumsatz, WHR/SWR live berechnet, Verlauf, Abgleich mit Apple Health.
- **Werkzeuge:** Hantel-Rechner, 1RM-Rechner, Kalorien-Rechner (TDEE), Wasser-Tracker mit Home-Screen-Widget.
- **Daten:** Export und Import als ZIP, automatische Backups (sichtbar in der Dateien-App), Wiederherstellung.

**Was die App (noch) nicht kann**

- Keine Mahlzeiten- oder Kalorienerfassung – es gibt nur den Kalorien-**Rechner** (Grundumsatz/Tagesbedarf).
- Kein Cloud-Sync, kein iCloud-Drive-Backup, kein Konto, keine soziale Funktion.
- Keine GPS-Aufzeichnung (kein Standortzugriff): Läufe werden manuell erfasst oder aus Apple Health importiert.
- Keine Apple-Watch-App; nur ein Home-Screen-Widget (Wasser).
- Kein Sprachwechsel in der App (es gilt die iOS-Systemsprache).

## 3. Die fünf Bereiche der App

| Tab | Wofür |
|---|---|
| **Dashboard** | Tagesübersicht: nächstes Training, Kennzahlen (Hero-Karten), Coaching-Hinweise, Trends, Kalender, Rekorde, Verlauf. Alles anpassbar. |
| **Plan** | Pläne, Trainingstage und Übungen verwalten, Programm-Vorlagen, „Plan bauen“, Training starten. |
| **Messung** | Körpermaße erfassen, Körperfett/FFMI/BMI/Grundumsatz live berechnen, Verlauf, Apple-Health-Abgleich. |
| **Werkzeuge** | Hantel-Rechner, 1RM-Rechner, Kalorien-Rechner, Wasser-Tracker. |
| **Mehr** | Einstellungen, Profil & Ziele, Übungsbibliothek, Ausrüstung, Dashboard anpassen, Export/Import/Backups, App zurücksetzen. |

---

## 4. Bedienung Schritt für Schritt

### 4.1 Erster Start

Beim ersten Start führt „Willkommen“ in fünf Schritten durch die Einrichtung (Fortschrittskapseln oben, „Zurück“ / „Weiter“ / „Fertig“):

1. **Apple Health verbinden (optional).** „Apple Health verbinden“ öffnet den iOS-Dialog; danach werden Geburtsdatum, Geschlecht, Größe und Gewicht vorbefüllt. Am Seitenende steht „Backup importieren (ZIP)“, falls du von einer früheren Installation kommst.
2. **Persönliche Daten.** Vorname (optional), Geschlecht, Geburtsdatum, Größe (100–250 cm), aktuelles Gewicht (20–400 kg, Pflicht – wird deine erste Messung), Zielgewicht (optional) und Trainingsort: *Gym*, *Home-Gym* oder *Ohne Equipment*.
3. **Coaching-Stil.** Fokus (*Muskelaufbau*, *Maximalkraft*, *Funktionell / Hybrid*, *Abnehmen*), Coach-Ton (*Analytisch*, *Motivierend*, *Streng*) und Wochenziel (1–7 Einheiten, Vorgabe 3).
4. **Equipment.** Mehrfachauswahl aus Langhantel, Kurzhantel, Maschine, Kabel, Kettlebell, Körpergewicht, Widerstandsband (entfällt bei „Ohne Equipment“).
5. **Erinnerungen und Plan.** Wasser- und Mess-Erinnerung (Vorgabe: an); optional einen Plan wählen: „Plan finden lassen“ (5 Fragen), eine passende Vorlage aus der Liste oder „Plan bauen“. Danach legst du die Trainings-Wochentage fest.

Cardio- und Lauf-Ziele werden hier nicht abgefragt, sondern später unter **Mehr → Profil bearbeiten**.

### 4.2 Plan wählen oder bauen

**Plan-Tab → „+“** bietet drei Wege: *Aus Template anlegen* (20 Programme), *Plan bauen* (Assistent) oder *Leerer Plan*. Der neue Plan wird aktiv. Das Dashboard zeigt als „Nächstes Training“ den nächsten Tag der **Rotation**: Nach jedem abgeschlossenen Training rückt der Plan einen Tag weiter, unabhängig vom Kalenderdatum. Ruhetage rücken über „Ruhetag abschließen“ weiter.

### 4.3 Ein Training durchführen

1. **Starten:** Dashboard → „Direkt starten“, oder Plan-Tab → Plan → Tag → „Training starten“. Ohne Plan geht es über „Vom Plan abweichen – Spontanes Training“.
2. **Sätze loggen:** Pro Übung eine Seite (wischen zum Wechseln). Gewicht, Wiederholungen und RIR sind vom letzten Mal vorbelegt („letztes: 80 kg × 8 · RIR 2“). Haken setzen = Satz gespeichert.
3. **Pause:** Nach jedem Satz läuft unten der Pausen-Timer (Vorgabe 90 s) mit Ton und Vibration; tippen überspringt ihn. Auf dem Sperrbildschirm und in der Dynamic Island läuft eine Live Activity.
4. **Beenden:** „Training speichern“ → Dauer und Sätze prüfen, Gefühl wählen (1 *Großartig* bis 5 *Zerstört*), bei Cardio die verwendete Ausrüstung → Zusammenfassung.
5. **Unterbrechen:** Der Zurück-Pfeil lässt die Session offen. Fortsetzen über Dashboard, das Banner im Plan-Tab oder die orange Kachel „Aktuelles Training fortsetzen“.

### 4.4 Zeitformate

Im Tag-Editor (Plan → Tag → **Struktur**) lässt sich ein Tag als **AMRAP**, **EMOM**, **Auf Zeit** oder **Zirkel** festlegen; auch als spontanes Training über das Dashboard. Der Start beginnt mit einem Vorlauf-Countdown (Vorgabe 10 s). Details in [5.3](#53-training-durchführen).

### 4.5 Nach dem Training

Die **Zusammenfassung** zeigt Hero-Zahl, Erfolge, neue Rekorde und Progressions-Vorschläge; du kannst eine Notiz anfügen und Sätze löschen. Danach findest du die Einheit im **Trainingsverlauf** (Dashboard-Karte „Trainingsverlauf“ oder „Letzte Trainings → Alle anzeigen“), wo sich Datum, Dauer, Sätze, Ausrüstung und Notiz nachträglich bearbeiten lassen. Rekorde stehen im **Trophy Room** (Dashboard-Karte „Rekorde“).

### 4.6 Körperwerte messen

**Messung-Tab:** Gewicht, Halsumfang und Taille (bei Frauen zusätzlich Hüfte) eintragen – die Live-Auswertung zeigt BMI, Körperfett, fettfreie Masse, FFMI und Grundumsatz sofort. „Messung speichern“ legt den Eintrag an (und schreibt ihn bei Verbindung nach Apple Health). Ab drei Messungen zeigt das Dashboard einen Gewichts-Trend mit Prognose.

### 4.7 Werkzeuge nutzen

**Werkzeuge-Tab:** *Hantel-Rechner* (welche Scheiben pro Seite?), *1RM-Rechner*, *Kalorien-Rechner* (Grundumsatz und Tagesbedarf), *Wasser-Tracker* (Tagesziel, Schnell-Einträge). Das Wasser-Widget lässt sich auf dem Home-Screen platzieren.

### 4.8 Apple Health verbinden

Möglich im Onboarding, in der Messung, über die gesperrten Dashboard-Karten (Ruhepuls, Schritte), im Profil oder unter **Mehr → Einstellungen → Apple Health → Verbinden**. Ohne Freigabe bleibt die App voll nutzbar; Werte werden dann manuell eingegeben. Läufe und Radfahrten anderer Apps (z. B. Adidas Running, Strava) importierst du mit dem separaten Schalter *Workout-Import*; Trainings aus Deltiq nach Health schreibst du über *Trainings in Health* – beides in [5.9](#59-apple-health).

### 4.9 Daten sichern und wiederherstellen

**Mehr → Einstellungen → Datenschutz:** *Automatische Backups* (Liste, „Jetzt sichern“, Wiederherstellen), *Daten exportieren (CSV)* (ZIP teilen) und *Daten importieren (CSV)*. Die automatischen Backups liegen in der Dateien-App unter **Auf meinem iPhone → Deltiq → Backups**. Details in [5.10](#510-daten-sichern).

---

## 5. Alle Funktionen im Detail

### 5.1 Dashboard

**Kopf:** Begrüßung nach Tageszeit („Guten Morgen/Tag/Abend“, plus Vorname); „+“ öffnet *Neue Messung*. Die Kontextzeile zeigt den aktiven Plan und eine **Wochenserie** („N-Wochen-Streak“ = aufeinanderfolgende Kalenderwochen, in denen dein Wochenziel erreicht wurde; die laufende Woche hat eine Gnadenfrist).

**Hero-Karten (oben, bis zu 3):** wählbar aus 9 Kennzahlen – *Gewicht* (mit Wochen-Delta), *KFA (Navy)*, *FFMI*, *Magermasse*, *BMI*, *Wasser heute*, *Trainings diese Woche*, *Ruhepuls*, *Schritte heute*. Vorgabe: Gewicht, KFA (Navy), FFMI. Ruhepuls und Schritte kommen aus Apple Health (bis zur Freigabe „—“ mit Schloss; Tippen öffnet den Dialog). KFA (Navy) braucht Hals- und Taillenmaß (bei Frauen zusätzlich Hüfte).

**Nicht abschaltbar:** die Kachel *Aktuelles Training fortsetzen* (erscheint bei einer offenen Session, die die Plan-Karte nicht abdeckt, z. B. einem spontanen Training) und die *Lauf-Machbarkeitskarte* (nur wenn Lauf-Coaching aktiv ist, siehe [5.5](#55-progression-deload-und-lauf-coaching)).

**Die 12 Widgets** (Vorgabe: alle an, in dieser Reihenfolge):

| Widget | Inhalt |
|---|---|
| **Nächstes Training** | Plan-Tag der Rotation mit bis zu 3 Übungen; Buttons „Direkt starten“ / „Laufendes Training fortsetzen“. An Ruhetagen: „Heute ist Ruhetag“, „Spontanes Training starten“, „Tag im Plan abhaken“. Link „Vom Plan abweichen – Spontanes Training“ (Sätze & Wdh., AMRAP 15 Min., EMOM 12 Min., Auf Zeit, Zirkel 5 Runden/90 s). |
| **Coaching-Insight** | ein Hinweis aus der Coaching-Kette (siehe unten); bei aktiver Deload-Woche ersetzt ein Banner die Karte. |
| **Diese Woche** | Volumen (kg) und Distanz (km) der Kalenderwoche. |
| **Muskel-Heatmap** | Sätze pro Woche für 10 Muskelgruppen: Untrainiert (0), Erhalt (1–8), Optimal (9–18), Übervolumen (>18). |
| **Trainings-Kalender** | Monatsraster, Trainingstage orange; Tippen öffnet die Einheiten des Tages. |
| **Rekorde (Trophy Room)** | Anzahl und letzter Rekord → Rekord-Historie. |
| **Trainingsverlauf** | Anzahl und letztes Training → Verlauf. |
| **Gewichts-Trend** | Chart aller Messungen, gestrichelte Prognose „4 / 8 W.“ (ab 3 Messungen), grüne Ziellinie bei gesetztem Zielgewicht. Schwanken die Werte stark (Standardabweichung > 2 kg), entfällt die Prognose. |
| **Compound-Lift-Trend** | geschätztes 1RM für Kniebeuge, Bankdrücken, Kreuzheben, Schulterdrücken (stehend), Rudern vorgebeugt; ab 2 Einheiten je Lift; Filter 1M/3M/Max; gestrichelte 4-Wochen-Prognose. |
| **Volumen-Trend** | Wochenvolumen (nur Kraft) als Balken; Filter 1M/3M/Max. |
| **Cardio-Pace-Trend** | Pace je Übung und Gerät („min/km, niedriger = besser“); nur mit mindestens zwei Cardio-Einheiten. |
| **Letzte Trainings** | die 5 jüngsten Einheiten, „Alle anzeigen“. |

**Dashboard anpassen:** *Mehr → Einstellungen → Präferenzen → Dashboard anpassen* – bis zu 3 Hero-Karten wählen, Widgets ein-/ausblenden und umsortieren. (Sind „Rekorde“ und „Trainingsverlauf“ ausgeblendet, fehlt der direkte Zugang zu diesen Screens.)

**Coaching-Hinweise:** Die Karte zeigt immer höchstens einen Hinweis; der erste zutreffende der Kette gewinnt. Wortlaut und Tonalität hängen von deinem **Coach-Ton** (Analytisch, Motivierend, Streng) und teils vom **Trainingsziel** ab.

| Stufe | Hinweis | Auslöser |
|---|---|---|
| Warnung | Nervensystem überlastet | jüngste Einheit < 48 h her mit sehr hoher Gesamtbelastung (Cardio zählt mit) |
| Warnung | Ruhetag | der heutige Rotationstag ist ein Ruhetag |
| Tagesempfehlung | Morgen-Training erledigt (Kraft/Cardio) | heute vor 13:00 Uhr trainiert |
| Tagesempfehlung | Harte Einheit gestern | gestern ≥ 20 Sätze oder > 90 Minuten |
| Hinweis | Cardio-Volumen-Spike | Cardio-km der laufenden Woche > 120 % der Vorwoche |
| Hinweis | Deload empfohlen | siehe [5.5](#55-progression-deload-und-lauf-coaching) (mit Button „Deload-Woche starten“) |
| Hinweis | Wiedereinstieg | ≥ 5 Tage ohne Training |
| Hinweis | Volumen-Rekord | letzte volle Woche übertrifft alle früheren (mindestens 4 volle Wochen Historie) |
| Hinweis | Langer Lauf fehlt | Plan enthält Cardio mit ≥ 2 Zieldauern, in 7 Tagen aber kein Lauf ≥ 80 % der längsten |
| Hinweis | Nach dem Training | gestern ≥ 5.000 kg Volumen bzw. ≥ 5 km |
| Hinweis | Serie | ≥ 5 Einheiten in 7 Tagen |
| Hinweis | Gestern trainiert · Plan-Vorschau | gestern trainiert · heute Trainingstag, noch nicht trainiert |
| Hinweis | Messung überfällig | mindestens 2 Messungen, die letzte > 14 Tage her |
| Hinweis | Wenig getrunken | Wasser in den letzten 7 Tagen getrackt, gestern < 1,5 l |
| Hinweis | Backup überfällig | nie exportiert und ≥ 10 Einheiten – oder letzter Export ≥ 30 Tage her und neue Einheit seitdem |
| Tipp | Lern-Tipps | 21 Tipps je Coach-Ton, täglich wechselnd |

### 5.2 Plan

**Plan-Liste** (Tab *Plan*)

- „+“-Menü: *Aus Template anlegen*, *Plan bauen*, *Leerer Plan* (Vorgabename „Neuer Plan“ / „New Plan“ / „Yeni Plan“ je nach Sprache, 12 Wochen, Gym).
- Der aktive Plan steht oben; jede Zeile zeigt Name, Pille „AKTIV“ und „N Tage • N Wochen • Trainingsort“ (Ruhetage zählen als Tage – Vorlagen-Pläne zeigen deshalb „7 Tage“).
- Wischen nach rechts: **Duplizieren** („… (Kopie)“, inaktiv, tiefe Kopie inkl. Zeitformat-/Zirkel-Parametern, Supersätzen und RIR-Vorgaben). Wischen nach links: **Löschen** (ohne Rückfrage; die Trainingshistorie bleibt erhalten).
- Ein Banner weist auf eine offene Session hin; bei aktivem Lauf-Coaching erscheint die Machbarkeitskarte.

**Programm-Vorlagen** (20): *Plan → „+“ → Aus Template anlegen → Programm wählen* (nach Fokus gruppiert und nach deinem Trainingsort gefiltert: Gym zeigt alle 20, Home-Gym 8, Ohne Equipment 3) → Vorschau („TAG N · Name“, Übungen mit Sätzen/Wdh./Pause) → **Diesen Plan übernehmen**. Der Plan wird aktiv (alle anderen werden inaktiv), läuft 12 Wochen, nutzt Standard-Wochentage (2 Tage: Mo/Do, 3: Mo/Mi/Fr, 4: Mo/Di/Do/Fr, 5: Mo–Fr, 6: Mo–Sa), übrige Tage sind „Ruhetag“. Die drei Hybrid-Vorlagen wählen anhand deiner Equipment-Präferenzen eine Kurzhantel- oder Kettlebell-Variante.

| # | Programm | Tage | Ort | Level | Inhalt |
|---|---|---|---|---|---|
| 1 | Ganzkörper 3x | 3 | Gym | Anf., Fortg. | Ganzkörper A/B/C |
| 2 | Cut-Phase Ganzkörper | 3 | Gym | Anf., Fortg. | Cut A/B/C, je mit Cardio-Finisher |
| 3 | Home Gym Hero | 3 | Home-Gym | Anf., Fortg. | Ganzkörper A/B/C (Kurzhanteln) |
| 4 | Bodyweight Mastery | 3 | Ohne Equipment | Anf., Fortg. | Push & Core · Pull & Beine · Ganzkörper HIIT |
| 5 | Push-Pull-Legs | 6 | Gym | Fortg., Exp. | Push A, Pull A, Beine A, Push B, Pull B, Beine B |
| 6 | Upper-Lower-Split | 4 | Gym | Fortg., Exp. | Oberkörper/Unterkörper A (Kraft), B (Volumen) |
| 7 | Arnold Split | 6 | Gym | Exp. | Brust & Rücken, Schultern & Arme, Beine – je A/B |
| 8 | Bro-Split | 5 | Gym | Fortg., Exp. | Brust, Rücken, Schultern, Arme, Beine |
| 9 | Powerlifting 5x5 | 3 | Gym | Anf., Fortg. | Training A, B, A |
| 10 | Powerlifting 3x5 | 3 | Gym | Fortg., Exp. | Kniebeuge-, Bankdrück-, Kreuzhebe-Tag |
| 11 | Fussball Athletik | 2 | Gym | Fortg. | Unterkörper & Core · Oberkörper & Explosivität |
| 12 | Hybrid Athlete – Beginner | 4 | Gym | Anf., Fortg. | Kraft A, Easy Run, Kraft B, Long Run |
| 13 | Hybrid Athlete – Balanced | 5 | Gym | Fortg., Exp. | Push, Easy Run, Pull, Long Run, Legs (leicht) |
| 14 | Hybrid Athlete – Performance | 6 | Gym | Exp. | Push, Easy Run, Pull, Intervalle, Legs, Long Run |
| 15 | CrossFit Bodyweight (Rx) | 3 | Ohne Equipment | Exp. | Cindy (AMRAP 20), EMOM Intensität, Auf Zeit |
| 16 | CrossFit Bodyweight (Scaled) | 3 | Ohne Equipment | Anf. | dieselben WODs, Einsteiger-Bewegungen |
| 17 | CrossFit mit Gewichten | 3 | Home-Gym | Anf.–Exp. | AMRAP, EMOM Ganzkörper, Auf Zeit (Thruster & Burpees) |
| 18 | Kettlebell Grundlagen | 3 | Home-Gym | Anf., Fortg. | Grundlagen-Zirkel, Push, Pull & Core, Schwung & Ausdauer (AMRAP 15) |
| 19 | Kettlebell Fortgeschritten | 3 | Home-Gym | Exp. | Heavy Pull (EMOM Snatch), Heavy Push & Squat, Metabolic Conditioning (AMRAP 20) |
| 20 | Kettlebell Komplexe | 5 | Home-Gym | Fortg., Exp. | 5 Komplexe: Ganzkörper (Zirkel 5×, 90 s), Schulter & Core (10×, bis zur Ausbelastung), Explosivität, Seated Control (AMRAP 15), Kraftausdauer |

**Plan-Editor:** Name; Liste der Trainingstage (Mo→So, mit „N Übungen • Normal/Leicht/Schwer“); „+“ → *Trainingstag* oder *Ruhetag*; Umsortieren per ↑↓-Symbol (die vorhandenen Wochentage rotieren mit), Löschen per Wischen. Einstellungen: Wochen (1–52, nur Anzeige), Trainingsort, *Als aktiven Plan setzen*, *Progressions-Ziel-RIR* (Auto oder RIR ≥ 0/1/2/3 im letzten Satz, siehe [5.5](#55-progression-deload-und-lauf-coaching)). Bei Plänen aus „Plan bauen“ gibt es zusätzlich **Neu rechnen**. Ein **Wechsel des Trainingsorts** führt durch Rückfragen (auch für andere aktive Pläne?) und tauscht passende Übungen automatisch aus; ersetzte Übungen werden archiviert und lassen sich wiederherstellen.

**Tag-Editor**

- *Tag-Info:* Name, Wochentag, Typ (Brust, Rücken, Beine, Schultern, Arme, Push, Pull, Oberkörper, Unterkörper, Ganzkörper, Ruhetag, Custom, Cardio/Run), „Nächste Intensität“, **Struktur**.
- *Struktur:* *Sätze & Wdh.* (klassisch) · *AMRAP* · *EMOM* · *Auf Zeit* · *Zirkel* (Parameter in [5.3](#53-training-durchführen)).
- *Übungen:* „+“ öffnet die Bibliothek; Zeile mit „3 Sätze • 8–12 Wdh • 90s Pause“ und Symbolen (Herz = Cardio, Stoppuhr = zeitbasiert, Kette = Superset). Wischen nach rechts: **Verbinden/Trennen** (Superset mit der Übung darüber); nach links: Löschen; ↑↓ sortiert um. Passt eine Übung nicht zum Plan-Ort, fragt „Equipment-Konflikt“.
- *Tagesanalyse* (live): Belastung (Leicht/Moderat/Hoch/Sehr hoch), Muskel-Fokus, geschätzte Dauer, Regeneration, systemische Last, Coach-Satz.
- *Aktionen:* „Training starten“ (gesperrt ohne Übung), „Training fortsetzen“; bei Ruhetagen „Ruhetag abschließen“. Nach ≥ 14 Tagen Pause erscheint vor dem Start ggf. „Willkommen zurück“ ([5.5](#55-progression-deload-und-lauf-coaching)).

**Übungs-Editor** (Sheet): Name; Schalter *Cardio* und *Zeit-basiert* (schließen sich aus). Kraft: Sätze 1–20, Wdh. min/max, Pause 0–600 s, **Ziel-RIR** (Regler 0–5, Vorgabe 2), vorgeschlagenes Gewicht, Notizen. Zeit-basiert: Sätze, Sekunden min/max. Cardio: Zielstrecke, Zieldauer, Gerät (Kein Gerät, Laufband, Fahrrad draußen, Ergometer, Rudergerät). **Smart-Progression** (nur Kraft): „Smart Overload aktivieren“ (Vorgabe an), „Compound-Lift“, Inkrement 1,25/2,5/5 kg. Eigene Übungen lassen sich zusätzlich mit Zielmuskel und Equipment versehen oder löschen.

**Plan bauen** (Assistent, Sheet aus dem „+“-Menü):

1. *Trainingsarten:* Langhantel, Kurzhantel, Kettlebell, Körpergewicht, Laufen, Radfahren; je Art Tage pro Woche (Summe ≤ 7), Dauer (15–120 Min.) und Erfahrung (Anfänger/Fortgeschritten/Profi). Bei Laufen/Radfahren optional ein Zeitformat (Sätze & Wdh., AMRAP, EMOM, Auf Zeit).
2. *Ausrüstung & Rhythmus:* Ausrüstung wählen, dann „Nur Reihenfolge“ oder feste Wochentage.
3. *Ergebnis:* Vorschau je Tag (Umfang, Härte-Kapsel Locker/Mittel/Schwer/Hart), Wochendauer, **Neu rechnen** (mischt die Kraft-Übungsauswahl), **Plan übernehmen**.

Härte und Reihenfolge werden so verteilt, dass harte und leichte Einheiten abwechseln. Kettlebell-Pläne mit ≥ 3 Tagen enden mit einem EMOM-Finisher; Laufpläne wechseln zwischen ruhigem Lauf, Intervallen und Tempolauf. Das Ergebnis heißt „Individueller Plan“ und wird sofort aktiv. „Neu rechnen“ im Plan-Editor überschreibt nur Tage, die du seit der Erzeugung nicht verändert hast.

**Übungsbibliothek** (*Mehr → Einstellungen → Präferenzen → Übungen*; zugleich der Übungs-Picker im Tag-Editor): 186 System-Übungen (Körpergewicht 57, Kurzhantel 34, Langhantel 32, Maschine 24, Kettlebell 22, Kabel 13, Band 4) in 10 Muskelgruppen, darunter 14 Cardio- und 16 zeitbasierte Übungen. Suche, Filter (Gerät, Muskelgruppe), eigene Übungen anlegen/bearbeiten/löschen. Wischen nach rechts öffnet den **Verlauf** einer Übung (Sätze gesamt, Volumen, schwerster Satz, bestes e1RM, e1RM-Verlauf, persönliche Rekorde, letzte Sätze). System-Übungen sind schreibgeschützt.

### 5.3 Training durchführen

**Start und Fortsetzen**

- Die Session wird beim Start angelegt und überlebt Zurück-Pfeil und App-Beenden. Fortsetzen: Dashboard-Button, orange Kachel „Aktuelles Training fortsetzen“ oder Banner im Plan-Tab.
- Startest du etwas Neues, während eine Session offen ist, fragt ein Dialog: „Altes verwerfen & Neu starten“ / „Altes fortsetzen“ / „Abbrechen“ (im Tag-Editor: Fortsetzen / Speichern & neu starten / Verwerfen & neu starten).
- **Spontanes Training** (Dashboard): *Sätze & Wdh.* (Übungen während des Trainings aus der Bibliothek hinzufügen; ohne Sätze verlassen löscht die Session), *AMRAP*, *EMOM*, *Auf Zeit*, *Zirkel* (öffnen den Tag-Editor mit Vorgaben).
- **Hinweis vor dem Start:** Das Banner „Du hattest gestern eine harte Einheit“ erscheint nach einer harten Cardio-Einheit (Gefühl ≥ 4, ≥ 60 Min. oder ≥ 10 km) vor Beinübungen wie Kniebeuge oder Kreuzheben.

**Satz-Eingabe (Sätze-Training)**

- Kopf: „LÄUFT · m:ss“, Kapseln „ÜBUNG 2/5“ und „VOLUMEN … KG“. Eine Seite pro Übung plus Abschlussseite („Training speichern“ / „Verwerfen“); nach dem letzten Satz einer Übung blättert die App nach 1,2 s weiter.
- **Kraft:** Gewicht, Wdh., RIR-Kapsel, Haken. Der Haken wird aktiv, sobald Wdh. > 0. Leeres Gewicht = Körpergewicht („BW“). Der **RIR-Regler** (0–5 in Halbschritten) erklärt jeden Wert („Optimaler Reiz – noch 2 Wiederholungen möglich.“). Tipp auf einen fertigen Satz nimmt ihn zurück.
- **Vorbelegung:** letzter Satz gleichen Index aus einer abgeschlossenen Session; ein niedrigeres Plangewicht (Deload) hat Vorrang. Am aktiven Satz steht „letztes: 80 kg × 8 · RIR 2“.
- **Langhantel-Übungen:** Waage-Symbol → Popover „Hantel-Aufladung“ (Stange 20 kg, SZ-Stange 10 kg, Trap-Bar 25 kg; Scheiben pro Seite). Zusätzlich eine einklappbare Zeile **Aufwärm-Sätze** (Leere Stange ×10, ~55 % ×5, ~75 % ×3, ~90 % ×1 ab 100 kg; auf 2,5 kg gerundet; nur Anzeige).
- **Cardio:** „KM“ und „MM:SS“ (auch H:MM:SS oder Minuten); die **Pace** erscheint live. Vorgaben sind die Planziele.
- **Haltesatz** (z. B. Plank): „Start“ → 3-2-1-„GO!“ → Zähler „x / N SEK“ (Vorgabe 30 s); bei Erreichen der Zielzeit Ton und Haptik, der Zähler läuft bis „Stoppen & speichern“ weiter.
- **Supersätze:** Die Pause startet erst, wenn alle Partner den Satz geloggt haben.
- „Satz hinzufügen“ bzw. Langdruck → „Satz entfernen“ ändern die Satzzahl der Plan-Übung dauerhaft.
- Warm-up-/Cool-down-Übungen tragen die Kapsel „WARM-UP“/„COOL-DOWN“ und lassen sich über *Einstellungen → Trainings-Verhalten → Warmup & Cooldown anzeigen* ausblenden.

**Pausen-Timer:** startet nach jedem Satz mit Pause > 0 (Vorgabe 90 s, max. 600 s) als Leiste unten („PAUSE“, m:ss, Fortschritt; Tippen = überspringen). Bei 0: „PAUSE VORBEI“, Haptik und Ton (gemäß Einstellungen). Die Zeit basiert auf der Endzeit und stimmt daher auch nach einem Hintergrundwechsel. Im Hintergrund erscheint die Benachrichtigung „Pause vorbei!“ (nur wenn Ton oder Vibrieren an ist und Benachrichtigungen erlaubt sind).

**Zeitformate**

| Format | Parameter | Ablauf | Signale | Ergebnis |
|---|---|---|---|---|
| **AMRAP** | Dauer 5–60 Min. (Vorgabe 15) | Countdown; „+1 Runde“ zählt Runden | ab 60 s Rest langer Ton und Haptik | Runden + Wiederholungen der angebrochenen Runde (Stepper nach Ablauf) |
| **EMOM** | Dauer 5–60 Min. (Vorgabe 12) | Ring 60 → 0 je Minute, Übungen rotieren; „Minute geschafft“ | kurzer Piep 0:10–0:01, langer Ton beim Minutenwechsel; Benachrichtigungen im Hintergrund | geschaffte Minuten |
| **Auf Zeit** | Zeitlimit: kein Limit oder 5–60 Min. | Stoppuhr; je Übung ein Kreis pro Runde; das letzte Häkchen stoppt die Uhr | – | Zeit (bei Limit: Limit) |
| **Zirkel** | Runden 1–20 (Vorgabe 5), Pause 10–300 s (Vorgabe 90), Modus | ungezeitete Arbeitsphase; Runde endet automatisch (*Feste Wiederholungen*, Übungen abhaken) oder per „Runde beenden“ (*Bis zur Ausbelastung*); dann Pausen-Countdown | Pause: Startton + Haptik, Piep bei 60 s/30 s, 10…1 jede Sekunde, Endton | geschaffte Runden |

Gemeinsam: Vorlauf-Countdown (*Einstellungen → Pausen-Timer-Feedback → Vorlauf vor dem Start*: Aus/5/10/15 s, Vorgabe 10) mit „Jetzt starten“; Menü „…“ → *Speichern* (sofort, gilt als vorzeitig) oder *Verwerfen*; der Zurück-Pfeil lässt die Session offen, „Training fortsetzen“ stellt den Stand wieder her. Die Töne spielen auch bei aktivem Stumm-Schalter, mischen sich aber mit Musik. Zeitformate haben keine Pausen-Leiste und keine Live Activity.

**Beenden:** „Training speichern“ → Sheet *Training beenden* mit Dauer, Sätzen/Volumen (Cardio: Distanz, Ø-Pace), „Wie hat sich das Training angefühlt?“ (1 Großartig, 2 Gut, 3 Okay, 4 Sehr schwer, 5 Zerstört / Am Limit; ab 4 gibt es im nächsten Training kein Gewichts-Plus) und – bei Cardio – „Verwendete Ausrüstung“. „Verwerfen“ löscht die Session samt Sätzen nach Rückfrage.

### 5.4 Auswertung

**Zusammenfassung** (direkt nach dem Training): Hero-Zahl (Volumen, Distanz oder Minuten bzw. das Zeitformat-Ergebnis), *Erfolge* („Dein N. Training diese Woche“ ab 3, „Stärkstes/Längstes Training der Woche“, „Längste Distanz der Woche“), *Persönliche Rekorde*, *Smart-Progression*, Kennzahlen, Ausrüstung, Notiz, Sätze je Übung. Vorzeitig gespeicherte Zeitformate sind markiert und zählen nicht als Bestleistung. Danach: „Speichern & zum Dashboard“.

**Trainingsverlauf:** nach Monaten gruppiert, neueste zuerst. Jede Zeile zeigt Tagesname, Badges („VORZEITIG“, bei Importen der Name der Quell-App) und Kennzahlen (Kraft: Min • Sätze • kg; Cardio: Min • km • Ø-Pace). Tippen öffnet das **Trainings-Detail** (nur lesen); Stift → **Training bearbeiten** (Datum, Dauer, Satzwerte, Sätze/Übungen hinzufügen oder entfernen, Notiz, Ausrüstung, Zeitformat-Ergebnis); „…“ → *Training löschen*. Nach dem Bearbeiten werden Summen und Rekorde neu berechnet.

**Rekorde (Trophy Room):** Arten – *Geschätztes 1RM* (Mittel aus Epley und Brzycki), *Max. Gewicht*, *Bestsatz* (Gewicht × Wdh.), *Max. Wiederholungen* (Körpergewicht), *Bestzeit* (Haltesatz), *Distanz* und *Pace* (ab 1 km, getrennt nach Cardio-Gerät), *Neue Bestrunde* (AMRAP) und *WOD-Bestzeit* (Auf Zeit, nur reguläre Läufe). EMOM und Zirkel erzeugen keine Rekorde. Regeln: nur strikt besser, je Übung und Art höchstens ein Rekord pro Einheit, die erste Einheit einer Übung setzt nur die Basis. Ansicht: Filter-Chips je Art, aufklappbare Gruppen je Übung mit Chart (ab 2 Punkten), „…“ → *Aus History neu berechnen*. Neue Rekorde lösen (bei aktivem *PR-Feiern*) eine Live-Activity-Anzeige und eine Benachrichtigung aus.

### 5.5 Progression, Deload und Lauf-Coaching

**Smart Progression** (pro Übung, Vorgabe an): Nach dem Training erhöht Deltiq das Zielgewicht um das Inkrement (1,25/2,5/5 kg, Vorgabe 2,5), wenn **alle** geplanten Sätze geloggt wurden, jeder Satz die obere Wiederholungsgrenze erreicht hat und der **letzte Satz** noch RIR ≥ 2 (Grundübung) bzw. ≥ 1 (Isolation) hatte; der Plan-Wert *Progressions-Ziel-RIR* ersetzt diese Schwelle. Liegt ein Satz unter der unteren Grenze bei RIR ≤ 0, sinkt das Ziel um ein Inkrement; sonst bleibt es. Ein Session-Gefühl von 4 oder 5 verhindert jede Erhöhung. Angezeigt wird nur eine Änderung („Ziel erreicht – nächstes Mal mehr“, „Neues Ziel: x kg“). Cardio, zeitbasierte und Warm-up-Übungen sind ausgenommen.

**Deload-Woche:** Empfohlen, wenn die Kraft-Belastung über die letzten drei vollen Wochen strikt steigt (Woche 3 ≥ 120 % von Woche 1) **und** in 14 Tagen mindestens zwei Kraft-Einheiten mit Gefühl 4/5 vorkamen. „Deload-Woche starten“ halbiert die Arbeitsgewichte des aktiven Plans (auf 2,5 kg gerundet); vorgesehen sind 7 Tage, ein Banner „Deload-Woche aktiv bis …“ ersetzt die Coaching-Karte (fehlt der Timer, steht die Meldung ohne Datum). Nach Ablauf der 7 Tage werden die Originalgewichte beim nächsten Öffnen der App bzw. des Dashboards automatisch zurückgesetzt; vorher geht das jederzeit über „Deload beenden & Gewichte zurücksetzen“ (Banner) oder *Einstellungen → Trainings-Verhalten → „Gesenkte Gewichte zurücksetzen (N Übungen)“*. Der Schalter *Deload-Vorschläge* (Vorgabe an) steuert nur die Vorschläge.

**Wiedereinstieg („Willkommen zurück“):** Vor dem Start eines Sätze-Trainings (nicht bei Zeitformaten, und nur bei aktivem Schalter *Deload-Vorschläge*) erscheint ein Sheet, wenn die letzte Krafteinheit ≥ 14 Tage her ist (individuell max(14, 2,5 × typischer Abstand)), mindestens 3 Kraft-Einheiten vorliegen und kein Deload läuft. Empfohlene Reduktion: 14–20 Tage −5 %, 21–29 −10 %, 30–59 −15 %, 60–89 −20 %, 90–179 −25 %, ab 180 Tagen nur ein Hinweis. Wählbar sind 5–30 % in 5er-Schritten mit Vorschau (alt → neu); „Gewichte senken“ oder „Nein, volle Last“.

**Lauf-Coaching** (*Mehr → Profil bearbeiten → Cardio- & Lauf-Ziele*, Vorgabe aus): Lauf-Ziel (Allgemeine Fitness, 5 km, 10 km, Halbmarathon, Marathon), aktuelle 5-km-Zeit (zeigt „Locker ~… · Tempo ~…“), Renn-Datum, Start-Laufvolumen (km/Woche), Maximalpuls (nur gespeichert). **Retro-Sync** („Aus Trainingsverlauf berechnen“) leitet Wochenvolumen (km der letzten 28 Tage ÷ 4) und 5-km-Referenz (schnellster Lauf ≥ 3 km und ≥ 5 Min. der letzten 60 Tage) aus deinem Verlauf ab. Der **Machbarkeits-Check** (Dashboard, Plan-Tab, Profil) rechnet mit maximal +10 % Wochenvolumen, Zielvolumen 20/30/45/65 km (5 km/10 km/Halbmarathon/Marathon) und 2 Wochen Taper und zeigt „machbar“ oder „wird eng“ mit einer Wochenvorschau. Reaktionen (im Plan-Tab und im Profil): **Plan übernehmen** bzw. **Vorschlag annehmen**, **Plan anpassen** (öffnet „Plan bauen“ vorbefüllt) oder **Ziel behalten**; das Dashboard zeigt zusätzlich „Plan ansehen“.

### 5.6 Messung

**Eingabe:** Pflicht sind *Gewicht (kg)*, *Halsumfang (cm)* und *Taille (cm)*, bei Frauen zusätzlich *Hüfte (cm)*. Optional: Schulterumfang (Männer, für das Schulter-Taille-Verhältnis) sowie weitere Umfänge (Brust, Bizeps, Oberschenkel, Wade, …), die in keine Formel einfließen. „Messung speichern“ wird aktiv, sobald die Pflichtfelder gefüllt sind. Das Messdatum ist der Speicherzeitpunkt; ein manuelles Körperfett-Feld gibt es nicht.

**Live-Auswertung** (ab Gewicht > 0):

| Wert | Berechnung |
|---|---|
| BMI | kg / m² |
| Körperfett (Navy) | Hodgdon/Beckett aus Hals, Taille (Frauen: + Hüfte) und Größe |
| Körperfett (Deurenberg) | 1,20 · BMI + 0,23 · Alter − 10,8 · (Mann = 1) − 5,4 |
| Fettfreie Masse | Gewicht × (1 − KFA/100); verwendet wird Navy, sonst Deurenberg |
| FFMI / normalisierter FFMI | FFM / m²; normalisiert: + 6,1 · (1,8 − Größe in m) |
| Grundumsatz (BMR) | Katch-McArdle (370 + 21,6 · FFM), wenn Navy verfügbar, sonst Mifflin-St Jeor |
| Taille-Hüfte-Verhältnis (Frauen) | < 0,80 Gesund, < 0,85 Grenzwert, sonst Erhöht |
| Schulter-Taille-Verhältnis (Männer) | < 1,30 Schmal, < 1,50 Mittel, < 1,62 Ausgeprägt, sonst V-Shape |

*Rundung:* Berechnete Werte werden **abgeschnitten, nie aufgerundet** (15,869 → „15,86“), mit festen Nachkommastellen und Komma gemäß Locale. Gespeichert wird immer metrisch (kg, cm).

**Verlauf:** die 12 jüngsten Messungen (Datum, KFA, Gewicht …); Tippen zeigt Details, der Stift öffnet *Messung bearbeiten*, dort auch *Messung löschen* (ohne Rückfrage). Charts liegen im Dashboard (Gewichts-Trend). **Apple Health:** Beim ersten Öffnen einer neuen Messung wird das neueste Health-Gewicht vorbefüllt („Aus Apple Health übernommen“); beim Speichern schreibt Deltiq Gewicht, Körperfett und Magermasse zurück.

### 5.7 Werkzeuge

- **Hantel-Rechner:** Zielgewicht und Stange eingeben → Scheiben pro Seite plus Stangen-Grafik. Greedy von schwer nach leicht, jede Scheibenart durch dein Inventar begrenzt (Vorgabe 10× für 25/20 kg bzw. 45/35 lbs, sonst 1×; „Inventar zurücksetzen“); Rest wandert zu kleineren Scheiben, nie aufgerundet. Ist das Ziel nicht erreichbar, steht z. B. „Mit deinem Inventar nur 142,50 kg erreichbar (Δ −0,50 kg)“. Scheiben kg: 25/20/15/10/5/2,5/1,25; lbs: 45/35/25/10/5/2,5/1,25. Das kg/lbs-Segment schaltet die app-weite Einheit.
- **1RM-Rechner:** Gewicht und Wiederholungen (1–36) → *Epley*, *Brzycki* und *Mittelwert* (Hauptwert) sowie eine Tabelle „Trainings-Last“ (100 %…65 % mit ca. 1…15 Wdh.). Derselbe Mittelwert speist Dashboard-Trends, Übungsdetail und Rekord-Erkennung.
- **Kalorien-Rechner (TDEE):** Geschlecht, Alter und Größe aus dem Profil, Gewicht vorbelegt; Aktivität (Bürojob 1,2 · Leicht aktiv 1,375 · **Moderat 1,55** (Vorgabe) · Aktiv 1,725 · Sehr aktiv 1,9). Ausgabe: TDEE (Mifflin × Faktor), BMR (Mifflin, ggf. Katch-McArdle), *Cut (−500)*, *Erhaltung*, *Bulk (+300)*. Feste Offsets; keine Makros, kein Ernährungstagebuch.
- **Wasser-Tracker:** Tagesziel = Gewicht × 35 ml (Quelle: letzte Messung → Zielgewicht → 70 kg). Progress-Ring (ab 100 % grün, „Tagesziel erreicht“), Schnell-Einträge **+125 ml / +250 ml / +500 ml / +1 L**, Liste „Heute“ mit Uhrzeit und Löschen je Eintrag, Menü „Heute zurücksetzen“. Es gibt keinen Verlauf früherer Tage. Dazu: Hero-Karte „Wasser heute“, Coach-Hinweis, Home-Screen-Widget und Erinnerungen ([5.11](#511-widgets-live-activity-und-benachrichtigungen)).

### 5.8 Mehr

*Mehr → Einstellungen* gliedert sich in folgende Bereiche (Vorgaben in Klammern):

| Bereich | Inhalt |
|---|---|
| **Profil & Ziele** | Zeile mit Geschlecht/Alter/Größe/Ziel → **Profil bearbeiten** (siehe unten) |
| **Präferenzen** | *Einheiten* (Metrisch/Imperial); *Übungen* (Bibliothek); *Ausrüstung & Schuhe* (Gear); *Dashboard anpassen* |
| **Erscheinungsbild** | System · Hell · Dunkel (System) |
| **Pausen-Timer-Feedback** | Ton abspielen (an), Vibrieren (an), PR-Feiern (an), Vorlauf vor dem Start: Aus/5/10/15 s (10) |
| **Trainings-Verhalten** | Warmup & Cooldown anzeigen (an), RIR-Hilfstexte anzeigen (an), Deload-Vorschläge (an), „Gesenkte Gewichte zurücksetzen (N Übungen)“ |
| **Erinnerungen** | Wasser erinnern (an) + Häufigkeit: jede Stunde / alle 2 / 3 (Vorgabe) / 4 Stunden; Messung erinnern (an) + Wochentag (Sonntag) + Uhrzeit 6–22 Uhr (8 Uhr) |
| **Apple Health** | Status/Verbinden, „Letzter Sync“, **Trainings in Health** (eigener Bildschirm, siehe [5.9](#59-apple-health)), **Workout-Import** (aus) |
| **Datenschutz** | Daten exportieren (CSV) · Automatische Backups · Daten importieren (CSV) |
| **Über** | Version `x.y.z (Build)` und Bundle-ID |
| **Daten-Management** | **App zurücksetzen** |

**Profil bearbeiten** (speichert automatisch): *Person* (Geschlecht, Geburtsdatum), *Körpermasse* (Größe), *Ziel & Training* (Zielgewicht, Trainingsort – ein Wechsel bietet an, die Pläne anzupassen), *Cardio- & Lauf-Ziele* (siehe [5.5](#55-progression-deload-und-lauf-coaching)), *Wochenziel* (1–7, Vorgabe 1), *Equipment-Präferenzen* (7 Schalter), *Coach* (Trainingsziel, Coaching-Stil), *Apple Health* („Aus Apple Health übernehmen“: Geburtsdatum, Geschlecht, Größe – ersetzt die aktuellen Werte, soweit Health sie liefert).

**Ausrüstung & Schuhe (Gear-Tracker):** Laufschuhe und Fahrräder mit Name, Typ, *Max. km* (Vorgabe 800) und „Bisherigen km“. Beim Beenden eines Trainings mit Cardio wählst du die verwendete Ausrüstung; ihre Kilometer werden gutgeschrieben (nachträglich im Verlauf umbuchbar, beim Löschen von Einheiten rückgebucht). Ab Erreichen von „Max. km“ färbt sich der Eintrag rot („Schuh erneuern – Dämpfung erschöpft“).

**App zurücksetzen:** löscht nach Rückfrage alle App-Daten (Profil, Messungen, Pläne, Einheiten, Rekorde, Wasser, Ausrüstung, Übungsvorlagen) und startet das Onboarding neu; die System-Übungsbibliothek wird dabei sofort neu angelegt. Apple-Health-Daten, Einstellungen (Erscheinungsbild, Timer, Erinnerungen, Workout-Import, Schalter für Trainings in Health) und Backup-Dateien bleiben bestehen; vorher wird **kein** Backup angelegt.

### 5.9 Apple Health

| Richtung | Daten | Wann |
|---|---|---|
| Lesen | Körpergewicht, Körperfett, Magermasse, Größe, Geburtsdatum, biologisches Geschlecht, Ruhepuls, Schritte | Onboarding, Messung (Gewicht-Vorbefüllung), Profil, Dashboard-Hero-Karten |
| Schreiben | Körpergewicht, Körperfett, Magermasse | beim Speichern einer *neuen* Messung |
| Schreiben (Freigabe „Trainings“, auch im Verbinden-Dialog) | Trainings | beim Beenden eines Trainings und rückwirkend über den Export, je nach Schaltern (*Krafttraining* an, *Cardio* aus), siehe unten |
| Schreiben (Zusatzfreigabe) | Geh- und Laufdistanz | nur bei Läufen/Spaziergängen und nur, wenn zusätzlich freigegeben; wird beim Einschalten von *Cardio schreiben* und vor einem Export mit Läufen angefragt |
| Lesen (separater Schalter) | Läufe und Radfahrten **anderer Apps** | *Einstellungen → Apple Health → Workout-Import* |
| Lesen (für den Export-Abgleich) | Trainings anderer Apps und der Uhr | nur um Doppelte zu vermeiden; wird beim Prüfen des Exports angefragt |

**Trainings in Health** (*Mehr → Einstellungen → Apple Health → Trainings in Health*): Der Bildschirm fasst alles zum Schreiben zusammen.

- **Zugriff:** Apple kennt nur eine Freigabe „Trainings“ für alles; sie gehört auch zum normalen Verbinden-Dialog (Onboarding, Messung, Dashboard, Profil). Wer Apple Health schon früher verbunden hat, wurde dafür nie gefragt – dort gibt es jetzt die Schaltfläche „Zugriff erlauben“. Fragt iOS nicht mehr (die Frage gilt als beantwortet), erklärt der Bildschirm den Weg über die Health-App (*Profil → Apps → Deltiq → „darf Daten schreiben“*) und öffnet sie mit „Health-App öffnen“. Sobald „Trainings“ erlaubt ist, schreibt Deltiq Krafttraining nach jedem beendeten Training (Schalter an), solange du es nicht abschaltest.
- **Krafttraining schreiben** (Vorgabe: an): Kraft-Einheiten und die Zeitformate AMRAP, EMOM, Auf Zeit und Zirkel werden als *Krafttraining* gespeichert (indoor, mit Sätzen und Volumen als Metadaten). Ein Zeitformat-Tag, der nur aus Cardio-Übungen besteht (z. B. Lauf-/Rad-Intervalle, Rudern), zählt zu *Cardio* (als gemischtes Cardio ohne Distanz).
- **Cardio schreiben** (Vorgabe: aus): Laufen, Radfahren, Gehen und gemischtes Cardio, die du in Deltiq selbst erfasst. Aus bleibt es für alle, deren Läufe schon eine andere App (z. B. Adidas Running) nach Health schreibt. Die Art wird aus den Einträgen abgeleitet (Ausrüstung vor Namen; Laufband = indoor), eine Distanz bekommen nur Laufen und Gehen.
- Geschrieben werden nur Start, Dauer und Art – **keine Kalorien und kein Puls** (Deltiq erfindet keine Gesundheitsdaten). Aus anderen Apps importierte Einheiten werden **nie** zurückgeschrieben. Trainings unter einer Minute, über sechs Stunden, in der Zukunft oder ohne Einträge werden nicht geschrieben.
- **Frühere Trainings:** „Trainings prüfen“ zeigt zuerst eine Vorschau (wie viele würden geschrieben, wie viele stehen schon in Health, wie viele sind nicht exportierbar); erst nach der Bestätigung wird geschrieben, neueste zuerst, mit Fortschritt und Abbruch. Die Vorschau verfällt, wenn du die App verlässt oder den Bildschirm schließt. Enthält der Export Läufe mit Distanz, fragt Deltiq vor dem Schreiben die Distanz-Freigabe an (nur, wenn sie noch offen ist) – später lässt sich kein Distanz-Sample mehr nachtragen, weil die Trainings dann als behandelt gelten. Der Export ist wiederholbar: Was in Health schon steht, wird erkannt und übersprungen. Der Abgleich sieht fremde Trainings nur mit Leseerlaubnis – ohne sie warnt der Bildschirm vor möglichen Doppelten.
- Der Export-Merker („behandelt“) liegt nur auf dem Gerät und gehört nicht zum CSV-Export. Er ist maßgeblich: Ein markiertes Training wird nie wieder exportiert, auch wenn du den Eintrag später in Health löschst. Ein verlorener Merker (Zurücksetzen, Backup-Wiederherstellung) führt über den Abgleich mit Health nicht zu Doppelten. Direkt nach dem Beenden geschriebene Trainings bekommen den Merker sofort; ändert man Beginn oder Dauer danach im Verlauf, bleibt der alte Health-Eintrag bestehen und es entsteht kein zweiter.

**Workout-Import (Adidas Running, Strava, …):** Der Schalter fragt nur den Lesezugriff auf Workouts an (zweiter iOS-Dialog) und startet sofort einen Sync – danach bei jedem App-Start. Importiert werden ausschließlich **Laufen und Radfahren** anderer Apps (nicht die von Deltiq selbst nach Health geschriebenen); jedes Workout wird zu einer abgeschlossenen spontanen Einheit mit einem Cardio-Eintrag („Freier Lauf“ / „Radfahren (outdoor)“, Dauer, ggf. Distanz) und im Verlauf mit dem Namen der Quell-App gekennzeichnet. Duplikate werden übersprungen (gleiche Health-ID oder mehr als die Hälfte der Dauer überlappt mit einer vorhandenen Einheit). Der erste Sync holt alle historischen Läufe/Radfahrten.

**Hinweise:** Die App sieht nur den Schreibstatus – den Lesestatus gibt Apple nicht preis. Wird der Zugriff verweigert, funktioniert alles manuell weiter (*Mehr → Apple Health → „In iOS-Einstellungen öffnen“*). Die Distanz-Freigabe wird beim „Zugriff erlauben“ (bei eingeschaltetem Cardio), beim Einschalten von *Cardio schreiben*, über die Schaltfläche „Geh- und Laufdistanz erlauben“ und vor einem Export mit Läufen angefragt (die beiden letzten nur, solange sie noch offen ist); fehlt oder verweigert sie, entsteht der Lauf ohne Distanz (und gilt danach als behandelt).

**Gesperrte Trainings-Freigabe:** iOS führt „Trainings“ als *einen* Typ und merkt sich nur, *dass* gefragt wurde, nicht für welchen Zugriff. Wurde der Typ zuerst nur zum Lesen angefragt (frühere Builds beim Einschalten des Workout-Imports), meldet iOS das Schreiben als „verweigert“, zeigt keinen Dialog mehr und listet in der Health-App keinen Schalter „Trainings“ unter „darf Daten schreiben“. Deltiq erkennt das über den Anfrage-Status (`statusForAuthorizationRequest`): Meldet iOS „Anfrage nötig“, erscheint „Zugriff erlauben“; sonst zeigt der Bildschirm eine Anleitung (Health-App prüfen, fehlt der Schalter: Deltiq löschen und neu installieren – vorher *Daten exportieren (CSV)* und die ZIP-Datei außerhalb von Deltiq sichern) und eine technische Zeile (`workout=… request=…`) für Rückmeldungen. Damit das nicht mehr passiert, fragt Deltiq „Trainings“ jetzt immer für Schreiben **und** Lesen zusammen an (Verbinden-Dialog, Workout-Import, „Zugriff erlauben“) und nur, wenn iOS überhaupt noch fragen würde.

### 5.10 Daten sichern

**Export** (*Datenschutz → Daten exportieren (CSV)*): ZIP `deltiq-export-yyyy-MM-dd-HHmm.zip` mit 12 CSV-Dateien (`profile`, `settings`, `measurements`, `water_log`, `plans`, `plan_days`, `plan_exercises`, `workouts`, `workout_sets`, `personal_records`, `gear`, `custom_exercises`) und `meta.json`; Weitergabe über das Share-Sheet. Format: CSV nach RFC 4180 (UTF-8, Komma), Zeitstempel ISO-8601 UTC, Dezimalpunkt. *Nicht* enthalten: System-Bibliothek, abgeleitete Werte, Apple-Health-Daten, der Workout-Import-Schalter, die Schalter für Trainings in Health und der Export-Merker. Unverschlüsselt – die Datei enthält persönliche Gesundheitsdaten.

**Automatische Backups** (*Datenschutz → Automatische Backups*): entstehen, wenn die App in den Hintergrund wechselt, höchstens alle 24 Stunden und nur, wenn mindestens eine Einheit existiert; es werden die **5 jüngsten** Generationen aufbewahrt (Typ *Automatisch*, *Manuell* oder *Vor einem Import*). Ort: **Dateien → Auf meinem iPhone → Deltiq → Backups**. In der Liste: „Jetzt sichern“, pro Eintrag „…“ → *Wiederherstellen* oder *Löschen*. Eine Wiederherstellung sichert vorher den jetzigen Stand.

**Import** (*Datenschutz → Daten importieren (CSV)*): ZIP wählen → Vorschau („Inhalt der Datei“, Datensätze in der Datei vs. in der App) → Modus → Bestätigung → Ergebnis (Importiert / Übersprungen / Fehlerhafte Zeilen, optional Fehlerprotokoll `errors.csv`). Modi: **Anhängen (sicher)** (Vorgabe; erkennt Duplikate bei Workouts, Sätzen, Rekorden, Messungen, Wasser, Ausrüstung und eigenen Übungen) und **Ersetzen** (löscht erst alle Daten, spielt dann das Archiv ein). Vor jedem Import entsteht ein Backup „Vor einem Import“. Pläne werden **nicht** dedupliziert, und das Profil sowie die portablen Einstellungen werden auch beim Anhängen mit den Werten aus der Datei überschrieben.

### 5.11 Widgets, Live Activity und Benachrichtigungen

**Wasser-Widget** (Home-Screen, klein und mittel, interaktiv): Ring mit Tagesziel; klein „+250 ml“, mittel „+250 ml“, „+500 ml“, „+1 L“. Taps schreiben direkt in die gemeinsame Datenbank (App Group). Funktioniert nur in signierten Builds (z. B. TestFlight); ohne App-Group-Store steht „App einmal öffnen, um das Widget zu aktivieren.“

**Rest-Timer-Live-Activity:** Sperrbildschirm und Dynamic Island (kompakt, erweitert, minimal) zeigen Übung, „Satz n / m“ und den Pausen-Countdown; nach Ablauf 8 Sekunden „Pause vorbei“. Nach einem Training mit Rekord (und aktivem *PR-Feiern*) erscheint 8 Sekunden lang eine Trophäen-Meldung. Voraussetzung: Live Activities sind in iOS erlaubt. Nur das Sätze-Training nutzt die Live Activity.

**Lokale Benachrichtigungen:**

| Benachrichtigung | Zeitpunkt |
|---|---|
| Wasser-Erinnerung | täglich 08:00–20:00 Uhr alle 1/2/3/4 Stunden |
| Mess-Erinnerung | wöchentlich zu Wochentag und Uhrzeit deiner Wahl |
| „Pause vorbei!“ | nach dem Pausen-Timer im Hintergrund (nur mit Ton oder Vibrieren an) |
| EMOM-Minutensignale | während eines EMOM im Hintergrund (nur mit Ton an) |
| PR-Feier | ca. 1 s nach einem Training mit Rekord (bei aktivem *PR-Feiern*) |

Die Erinnerungen werden nach dem Onboarding, nach Imports und Backup-Wiederherstellungen sowie bei jedem App-Start gegen deine Schalter abgeglichen (z. B. nach einer Geräte-Wiederherstellung); ohne Benachrichtigungs-Erlaubnis bleiben sie ungeplant. Antippen der Wasser-Erinnerung öffnet *Werkzeuge → Wasser*, der Mess-Erinnerung den Messung-Tab.

**Deep-Links** (Schema `fitnessapp`): `fitnessapp://workout/active` öffnet den Plan-Tab mit der laufenden Session (Tap auf die Live Activity), `fitnessapp://dashboard` das Dashboard.

### 5.12 Sprache, Design und Datenschutz

- **Sprachen:** Deutsch, Englisch, Türkisch – die App folgt der iOS-Systemsprache (kein In-App-Wechsel). Der Katalog enthält 1796 Texte, alle in drei Sprachen vollständig; die Texte der Apple-Health-Berechtigungsdialoge stehen getrennt in `App/FitnessApp/InfoPlist.xcstrings` (ebenfalls DE/EN/TR). Nur auf Deutsch (nicht lokalisiert): Wasser-/Mess-Erinnerungstexte, Widget und Live Activity, einige Hinweis- und Fehlermeldungen.
- **Design:** Akzentfarbe Orange; Erscheinungsbild System, Hell oder Dunkel.
- **Datenschutz:** alle Daten bleiben lokal. Die App fragt **keinen** Zugriff auf Kamera, Fotos, Standort oder Mikrofon an und nutzt kein Netzwerk. Berechtigungen im Überblick: [6.2](#62-voraussetzungen-und-berechtigungen).

---

## 6. Für Tester

### 6.1 Zugang und Installation

Deltiq wird als Beta über **TestFlight** verteilt:

1. Einladung per E-Mail annehmen (Einladungslink öffnet TestFlight).
2. In der **TestFlight-App** „Deltiq“ → *Installieren*. Updates kommen automatisch über TestFlight.
3. Installierte Version prüfen: **Mehr → Einstellungen → Über → Version** (Format `x.y.z (Build)`).

Hinweise: Für *interne* Tester verlangt Apple einen Eintrag im App-Store-Connect-Team; externe Tester brauchen eine separate Freigabe durch Apple. Das Wasser-Widget funktioniert nur in signierten Builds, Live Activities müssen in iOS aktiviert sein.

### 6.2 Voraussetzungen und Berechtigungen

- iOS 17.0 oder neuer; iPhone (Hochformat) oder iPad.
- Berechtigungen und Systemeinstellungen, die die App braucht:

| Berechtigung | Wann | Wofür |
|---|---|---|
| Mitteilungen | Ende des Onboardings und nach einem Backup-Import im Onboarding (jeweils wenn eine Erinnerung an ist), beim Ändern eines Erinnerungs-Schalters, bei der ersten PR-Feier | Wasser-/Mess-Erinnerungen, „Pause vorbei!“, EMOM-Signale, PR-Meldung. Ohne Erlaubnis werden Erinnerungen still nicht geplant. |
| Apple Health – Standard | Onboarding, Messung, Dashboard-Karten, Profil, Einstellungen | Lesen: Gewicht, Körperfett, Magermasse, Größe, Geburtsdatum, Geschlecht, Ruhepuls, Schritte · Schreiben: Gewicht, Körperfett, Magermasse, Trainings |
| Apple Health – Trainings schreiben (nachholen) | Einstellungen → Trainings in Health („Zugriff erlauben“) für alle, die Health vor dieser Freigabe verbunden hatten; Geh- und Laufdistanz zusätzlich beim Einschalten von *Cardio schreiben* oder vor einem Export mit Läufen | Trainings (und optional Laufdistanz) nach Health schreiben, auch rückwirkend |
| Apple Health – Workouts lesen | beim Einschalten von *Workout-Import* und beim Prüfen des Exports | Läufe/Radfahrten anderer Apps importieren; Doppelte beim Export vermeiden |
| Live Activities | in den iOS-Einstellungen | Pausen-Timer auf Sperrbildschirm/Dynamic Island |

Keine Berechtigung benötigt die App für Kamera, Fotos, Standort, Mikrofon oder Netzwerk.

### 6.3 Was es zu testen gibt – Checkliste

**Einrichtung**
- [ ] Onboarding komplett durchlaufen, einmal mit und einmal ohne Apple Health; Trainingsort „Ohne Equipment“ (Equipment-Schritt entfällt)
- [ ] „Plan finden lassen“ (5 Fragen) → Plan übernehmen → Wochentage wählen
- [ ] „Backup importieren (ZIP)“ im Onboarding

**Dashboard**
- [ ] Leeres Dashboard → erstes Training → Karten füllen sich
- [ ] Hero-Karten wechseln; Widgets aus-/einblenden und umsortieren
- [ ] Drei Messungen anlegen → Gewichts-Prognose; Trainingskalender und Wochenserie
- [ ] Hero-Karte „Gewicht“: Wochen-Delta bei 100-g-Schritten (z. B. 70,2 → 70,3 kg nach einer Woche) zeigt „+0,1 kg / Wo.“, nicht „+0,0“
- [ ] Coach-Ton ändern und Hinweistexte vergleichen
- [ ] Einheiten im Verlauf **rückdatieren** (Datum ist bearbeitbar), um Deload-, Wiedereinstiegs- und Serien-Logik zu testen
- [ ] Neuer Nutzer ohne Training: Der Hinweis „Wiedereinstieg“ erscheint nicht

**Plan**
- [ ] Programm-Liste je Trainingsort: Gym 20 / Home-Gym 8 / Ohne Equipment 3
- [ ] Vorlage übernehmen: Plan aktiv, andere inaktiv, „7 Tage“ in der Liste
- [ ] „Plan bauen“: verschiedene Arten und Erfahrungsstufen, Summe 7 Tage, *Neu rechnen*, feste Wochentage, Laufen mit Zeitformat; Plan übernehmen, eine Übung ändern, erneut *Neu rechnen*
- [ ] Tag-Editor: alle fünf Strukturen, Parameter ändern, Tagesanalyse, Supersätze verbinden/trennen/umsortieren
- [ ] Übungs-Editor: Kraft, Cardio, zeitbasiert, Smart-Progression; die Hilfetexte und das *Progressions-Ziel-RIR* im Plan-Editor nennen „RIR ≥ …“
- [ ] Leeren Plan anlegen (Systemsprache EN/TR): Name „New Plan“ / „Yeni Plan“, auch nach einem App-Neustart, solange er nicht umbenannt wird
- [ ] Trainingsort mit mehreren Plänen wechseln (Dialogkette, Toast, Übungen wiederherstellen)
- [ ] Übungsbibliothek: Suche, Filter, eigene Übung anlegen/umbenennen/löschen, Verlauf einer Übung

**Training**
- [ ] Standardtraining: Sätze loggen, Pause laufen lassen, App in den Hintergrund/Sperren → Benachrichtigung und Live Activity; zurück → „PAUSE VORBEI“
- [ ] Pause überspringen, neuer Satz während der Pause, Pause 0 s
- [ ] Superset, Haltesatz, Cardio-Übung mit Pace, Warm-up-Anzeige, Aufwärm-Sätze
- [ ] Unterbrechen und Fortsetzen: Zurück-Pfeil, App aus dem App-Switcher beenden, Banner/Kachel, Dialog bei zweitem Start, Verwerfen
- [ ] Spontanes Training in allen fünf Varianten
- [ ] Zeitformate AMRAP, EMOM, Auf Zeit, Zirkel (beide Modi) mit Vorlauf 0/5/10/15 s; Gerät sperren; vorzeitig speichern
- [ ] Zusammenfassung: Erfolge, Rekorde, Progression, Notiz, Gerät zuordnen
- [ ] Verlauf: Training bearbeiten und löschen; Trophy Room „Aus History neu berechnen“
- [ ] Progression: obere Grenze + RIR ≥ 2 → „Neues Ziel“; Gefühl 4/5 → keine Erhöhung; unter der Untergrenze bei RIR 0 → Senkung
- [ ] Deload starten und manuell beenden; nach Ablauf der 7 Tage (z. B. Gerätedatum um 8 Tage vorstellen) die App erneut in den Vordergrund holen → Gewichte sind automatisch zurückgesetzt, Banner weg
- [ ] „Willkommen zurück“ (≥ 14 Tage Pause, ≥ 3 Kraft-Einheiten)
- [ ] Lauf-Coaching: Profil → Ziel, Datum, Volumen → Machbarkeitskarte (alle drei Reaktionen); Retro-Sync

**Messung und Werkzeuge**
- [ ] Messung für Mann und Frau speichern, bearbeiten, löschen; kg/lbs umschalten und prüfen, was sich ändert
- [ ] Zehntelwerte (64,1 / 64,6 / 65,1 kg) speichern → Anzeige „64,10“ usw., nicht „64,09“
- [ ] Apple Health: alles erlauben · alles verweigern · nur Schreiben/nur Lesen verweigern; der iOS-Dialog erscheint in der Systemsprache (DE/EN/TR)
- [ ] Trainings in Health bei Nutzern, die den Workout-Import schon vor der Trainings-Freigabe eingeschaltet haben („Trainings“ nur lesend freigegeben): Bildschirm zeigt die Anleitung samt „Health-App öffnen“ und der technischen Zeile (`workout=denied · request=…`); „Health-App öffnen“ öffnet die Health-App; nach Löschen und Neuinstallation zeigt „Zugriff erlauben“ einen Dialog mit Schreiben **und** Lesen für „Trainings“
- [ ] Trainings in Health: Bestandsnutzer (Health schon früher verbunden) → Einstellungen → Trainings in Health → „Zugriff erlauben“ zeigt den iOS-Dialog; danach „Zugriff erlaubt“
- [ ] Krafttraining beenden (Schalter an) → Eintrag *Krafttraining* in Health/Fitness, ohne Kalorien; mit Schalter aus → kein Eintrag
- [ ] Zugriff in Health entziehen → Bildschirm zeigt den Hinweis; Training beenden bricht nichts ab
- [ ] *Cardio schreiben* an, ohne Distanz-Freigabe: Lauf beenden → Eintrag ohne Distanz; mit Freigabe → *Laufen* mit Distanz; Laufband = indoor, Radfahren = *Radfahren*
- [ ] Training mit gesperrtem Gerät beenden (sofort sperren) → später prüfen, ob es in Health steht
- [ ] Export früherer Trainings mit Läufen ohne Distanz-Freigabe (*Cardio schreiben* aus): in der Vorschau Cardio zuschalten, bestätigen → die Distanz-Abfrage erscheint vor dem Schreiben; bei Ablehnung steht „ohne Distanz gespeichert“ im Ergebnis
- [ ] Training beenden, danach im Verlauf die Dauer deutlich verlängern (oder den Beginn um einen Tag zurücksetzen) → Export prüfen: kein zweiter Health-Eintrag
- [ ] Export früherer Trainings: „Trainings prüfen“ → Vorschau stimmt (direkt beim Beenden bestätigt geschriebene Einheiten tragen schon den Merker und erscheinen gar nicht; „Schon in Health erkannt“ zählt Trainings ohne Merker, die in Health stehen, z. B. von anderer App/Uhr), schreiben, Ergebnis; Export direkt wiederholen → nichts Neues, keine Doppelten; Abbrechen mitten drin → beim nächsten Mal geht es weiter
- [ ] Export mit Trainings einer anderen App/Uhr im selben Zeitraum: mit Leseerlaubnis keine Doppelten; ohne Leseerlaubnis erscheint die Warnung
- [ ] Hantel-, 1RM-, Kalorien-Rechner mit den Referenzwerten unten
- [ ] Wasser: Schnell-Einträge, Tagesziel, Widget (+250 ml, danach Eintrag in der App prüfen), Erinnerung antippen → richtiger Tab

**Daten und Einstellungen**
- [ ] Frisch installieren, Onboarding mit eingeschalteten Erinnerungen abschließen, nichts weiter anfassen → Erinnerungen kommen (Vorgabe: Wasser alle 3 Stunden um 08, 11, 14, 17 und 20 Uhr; dazu sonntags 08:00 die Mess-Erinnerung)
- [ ] Training loggen → App in den Hintergrund → Backup in der Dateien-App prüfen
- [ ] Export-ZIP öffnen (12 CSV + `meta.json`); dieselbe ZIP erneut *Anhängen* (Workouts/Rekorde „übersprungen“, Pläne doppelt); *Ersetzen*; Wiederherstellen
- [ ] Zurücksetzen → Onboarding; Backups bleiben; die Übungsbibliothek ist sofort gefüllt (z. B. im Übungs-Picker, ohne Neustart)
- [ ] Workout-Import: Lauf in Apple Health (von anderer App) → Schalter an → Einheit mit Quell-Badge; zweiter Sync erzeugt keine Duplikate
- [ ] Sprachen DE/EN/TR umschalten (iOS-Einstellungen) und nicht übersetzte Texte melden

**Referenzwerte zum Nachrechnen**

| Eingabe | Erwartetes Ergebnis |
|---|---|
| Mann, 180 cm, 30 J., 80 kg, Hals 38, Taille 88 | BMI 24,69 · KFA Navy 18,46 · Deurenberg 20,32 · FFM 65,23 · FFMI 20,13 · BMR 1778,97 |
| Frau, 170 cm, Hals 33, Taille 75, Hüfte 95 | KFA Navy 25,93 |
| 1RM: 100 kg × 5 | Epley 116,66 · Brzycki 112,50 · Mittelwert 114,58 |
| Kalorien-Rechner: Mann, 80 kg, „Moderat“ | TDEE 2759 · Cut 2259 · Bulk 3059 |
| Wasserziel bei 80 kg | 2800 ml |
| Hantel-Rechner: 100 kg, Stange 20 kg | 1×25 + 1×15 pro Seite |

### 6.4 Bekannte Einschränkungen

- **Timer im Hintergrund:** Es gibt kein Hintergrund-Audio. AMRAP, Auf Zeit und Zirkel geben im Hintergrund keine Signale; Pausen- und EMOM-Signale laufen über Benachrichtigungen (Erlaubnis nötig). Zeitformate haben weder Pausen-Leiste noch Live Activity.
- **Einheiten:** „Imperial“ wirkt nur teilweise (u. a. Hantel- und 1RM-Rechner, Hantel-Aufladung, Aufwärm-Rampe, Profil-Untertitel). Messung, Dashboard, Kalorien-Rechner, Profil-Editor, Wasser, Satz-Eingabe, Volumen und Rekorde bleiben kg/cm.
- **Widgets:** nur ein Widget (Wasser). Widget, Live Activity und Erinnerungen sind nur deutsch.
- **Löschen ohne Rückfrage:** Plan (Wischen), Trainingstag, Übung im Tag-Editor, Messung, Ausrüstung, Wasser-Eintrag, „Heute zurücksetzen“.
- **Messungen:** In der Liste erscheinen nur die 12 jüngsten (ältere bleiben gespeichert, sind aber nicht bearbeitbar). Es gibt keine Plausibilitätsgrenzen bei der Eingabe.
- **Workout-Import:** nur Laufen/Radfahren, nur beim App-Start (kein Hintergrund-Sync); eine gelöschte importierte Einheit kommt beim nächsten Start zurück.
- **Import:** Auch im Modus *Anhängen* werden Profil und portable Einstellungen mit den Werten aus der Datei überschrieben, und Pläne werden nie dedupliziert (ein erneuter Import derselben ZIP verdoppelt sie); der Bestätigungsdialog weist darauf hin.
- **Deload ohne Timer:** Fehlt der Deload-Timer, obwohl noch gesicherte Originalgewichte existieren (Randfall), erkennt die App den Deload an den Gewichten, zeigt das Banner ohne Enddatum und beendet ihn nicht automatisch – hier hilft „Deload beenden“.
- **Plan-Sessions:** Übungen lassen sich im laufenden Plan-Training weder hinzufügen noch tauschen (nur im spontanen Training); nachtragen geht über Verlauf → Bearbeiten. Der Pausen-Timer wird nach einem Wiedereintritt nicht wiederhergestellt.
- **Backups:** unverschlüsselt und nur lokal (sie liegen im Geräte-Backup, ein iCloud-Drive-Container existiert nicht).
- **Coaching:** Die Nachrichtentypen *Neuer Rekord*, *Plateau* und *Junk Miles* sind angelegt, aber nicht aktiv; der Maximalpuls im Profil wird nur gespeichert.
- **Kein Feedback-Kanal in der App:** Rückmeldungen laufen außerhalb der App (siehe 6.6).

### 6.5 Auffälligkeiten zum Prüfen

Die folgenden Punkte stammen aus einer Code-Analyse und wurden **nicht** durchgängig auf dem Gerät bestätigt. Wer sie nachstellen kann, hilft uns besonders:

1. **Plan bauen:** Der Schritt „Ausrüstung“ beeinflusst die Übungsauswahl nicht (nur die Trainingsart); *Langhantel + Anfänger* liefert nur eine Übung; zeitbasierte Übungen (z. B. Plank, Burpees) bekommen in generierten Plänen die Standard-Wiederholungsspanne als Sekunden (8–12 s); der Plan ist immer „Gym“ und heißt „Individueller Plan“.
2. **Training:** „Direkt starten“ bei einem Tag ohne Übungen reagiert nicht und gibt keinen Hinweis; die Benachrichtigung nach dem letzten Satz kann „Satz n+1 von n“ nennen.
3. **Nicht lokalisierte Texte:** u. a. „Individueller Plan“, „Smart-Progression“, „Inkrement“, „WARM-UP“, „Diesen Plan übernehmen“, einige Toasts und Zeilen im Rekord-Screen erscheinen auch in EN/TR auf Deutsch.
4. **Apple Health und Benachrichtigungen:** Ob Trainings samt Distanz-Sample (Zusatzfreigabe „Geh- und Laufdistanz“) in Apple Health ankommen, ob der Abgleich beim Export fremde Trainings sicher erkennt, ob `finishWorkout()` bei gesperrtem Gerät ein Training zuverlässig ablegt und ob eine Neuinstallation die gesperrte Trainings-Freigabe (siehe „Gesperrte Trainings-Freigabe“ in [5.9](#59-apple-health)) wirklich zurücksetzt, ist auf dem Gerät noch nicht bestätigt (bestätigt ist nur der gesperrte Zustand selbst: „verweigert“, kein Dialog, kein Schalter in der Health-App); für „zeitkritische“ Benachrichtigungen fehlt laut Code das passende Entitlement.
5. **Dashboard-Zugang:** Sind die Karten „Rekorde“ und „Trainingsverlauf“ ausgeblendet, fehlt der direkte Zugang zu Trophy Room und Verlauf.

### 6.6 Feedback geben

Bitte mit jeder Rückmeldung angeben: **Gerät und iOS-Version**, **App-Version** (*Mehr → Einstellungen → Über*), die **Schritte zum Nachstellen**, **erwartetes** und **tatsächliches** Verhalten und möglichst einen **Screenshot**. Über TestFlight geht das direkt: Screenshot machen und den Feedback-Dialog von TestFlight nutzen, der danach erscheint. Bei Datenproblemen hilft ein Export-ZIP – er enthält persönliche Gesundheitsdaten, deshalb bitte nur direkt an die Projektverantwortlichen und nicht öffentlich teilen.

---

## 7. Glossar

| Begriff | Bedeutung |
|---|---|
| **RIR** | Reps in Reserve – wie viele Wiederholungen du am Satzende noch geschafft hättest (0 = nichts mehr, 2 = „optimaler Reiz“) |
| **1RM / e1RM** | One-Rep-Max, das theoretische Maximalgewicht für eine Wiederholung; „e1RM“ = geschätzt aus Gewicht und Wiederholungen |
| **AMRAP** | As Many Rounds As Possible – in vorgegebener Zeit so viele Runden wie möglich |
| **EMOM** | Every Minute On the Minute – zu jeder vollen Minute eine festgelegte Aufgabe |
| **Auf Zeit** (For Time) | feste Aufgabe, möglichst schnell erledigt; Ergebnis ist die Zeit |
| **Zirkel** | feste Rundenzahl mit definierter Pause zwischen den Runden |
| **Superset** | zwei Übungen im Wechsel ohne Pause dazwischen |
| **Deload** | bewusst leichtere Woche zur Erholung |
| **PR** | Personal Record (persönlicher Rekord) |
| **KFA** | Körperfettanteil; **Navy** und **Deurenberg** sind zwei Schätzverfahren |
| **FFM / FFMI** | Fettfreie Masse / fettfreie-Masse-Index (FFM geteilt durch Größe zum Quadrat) |
| **BMR / TDEE** | Grundumsatz / Gesamtenergieverbrauch pro Tag |
| **WHR / SWR** | Taille-Hüfte- bzw. Schulter-Taille-Verhältnis |
| **Rotation** | Der Plan rückt pro abgeschlossenem Training einen Tag weiter, unabhängig vom Kalenderdatum |
| **Hero-Karten** | die bis zu drei Kennzahlen-Kacheln am Dashboard-Anfang |

---

## 8. Für Entwickler

### 8.1 Projektstruktur

Domänenlogik und Datenmodell liegen als **Swift Package** vor; das App-Target (Einstieg, Widget-Extension, Assets) setzt darauf auf. Es wird per XcodeGen aus `project.yml` erzeugt – ein `.xcodeproj` wird nie committet.

```
fitnessapp_ios/
|-- project.yml                  # XcodeGen-Spec (Source of Truth für App- und Widget-Target)
|-- Package.swift                # Swift Package (iOS 17+, macOS 14+), Abhängigkeit: ZIPFoundation
|-- codemagic.yaml               # CI: swift-package, ios-app, testflight
|-- App/
|   |-- FitnessApp/              # App-Einstieg, AppDelegate, Info.plist (+ InfoPlist.xcstrings), Entitlements, Assets
|   `-- FitnessAppWidgets/       # Wasser-Widget + Rest-Timer-Live-Activity
|-- Sources/
|   |-- FitnessAppCore/          # reine Logik (nur Foundation): Analytics, Programs (Vorlagen,
|   |                            #   Bibliothek, Plan-Generator), Records, BodyComposition,
|   |                            #   Exercises, Progression, Nutrition, Coaching, DataPortability
|   |-- FitnessAppData/          # SwiftData-Modelle, Export/Import/Backup, SharedStore (App Group)
|   |-- FitnessAppHealth/        # HealthKit-Service + plattformneutraler Controller
|   |-- FitnessAppActivities/    # ActivityKit, Erinnerungen, Deep-Links, Notification-Routing
|   `-- FitnessAppUI/            # alle SwiftUI-Views, Theme, Lokalisierung (Localizable.xcstrings)
|-- Tests/
|   |-- FitnessAppCoreTests/     # Rechner, Analytik, Plan-Generator, CSV, Backup (ca. 600 Tests)
|   |-- FitnessAppDataTests/     # SwiftData in-memory, Export/Import-Roundtrip (ca. 60 Tests)
|   `-- FitnessAppHealthTests/   # Zustandslogik der Health-Berechtigungen (ca. 10 Tests)
`-- .scripts/                    # Python-Werkzeuge für den String-Katalog
```

Modul-Abhängigkeiten: `FitnessAppData → FitnessAppCore`; `FitnessAppUI` hängt von allen vier anderen ab; `FitnessAppHealth` und `FitnessAppActivities` sind eigenständig. Alle SwiftUI-/SwiftData-Dateien sind mit `#if canImport(...)` gekapselt, damit `FitnessAppCore` überall kompiliert.

### 8.2 Architektur-Invarianten

1. **Single Source of Truth metrisch.** Gespeichert wird immer kg und cm; die Einheiten-Einstellung wirkt nur in der Anzeige (keine Datenmigration).
2. **Truncate statt Round.** Berechnete Körperwerte werden abgeschnitten, nie aufgerundet (`value.truncated(to: 2).formattedTwoDecimals`).
3. **Zahlenformat locale-aware** mit fest erzwungenen Nachkommastellen; ganzzahlige Größen (Schritte, Sätze, BPM) ohne Dezimalen.
4. **Plate-Greedy mit Per-Plate-Cap.** Jede Scheibenart wird auf das Inventar begrenzt, der Rest wandert zu kleineren Scheiben.
5. **Neue `@Model`-Felder** immer mit Default-Wert (Lightweight-Migration); Felder nie leichtfertig löschen; Löschen per Einzelinstanz statt Batch (`SettingsView.deleteAll(of:)`).
6. **Neue Modelle** in `AppSchema.types`, in die Reset-Sequenz (`SettingsView.resetApp`), den Replace-Wipe des Imports und die Export-/Import-Spalten (additiv, `formatVersion` 1.x) eintragen; neue portable Einstellungen in `SettingsPortability.whitelist`.

### 8.3 Bauen und Testen

```bash
swift test                       # Core- und Health-Tests überall; Data-Tests nur mit SwiftData (macOS)
swift test --parallel            # wie in der CI

# App-Target (macOS mit Xcode):
brew install xcodegen
xcodegen generate
xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

- `DEVELOPMENT_TEAM` ist leer – das ergibt Simulator-Builds ohne Signing; Signing und Versionsnummern setzt die CI.
- `STRING_CATALOG_GENERATE_SYMBOLS: NO` ist in `project.yml` gesetzt, weil der Symbol-Generator von Xcode 26.4.1 am Katalog scheitert.
- Es gibt keine UI- oder Activities-Tests; Logik, die testbar sein soll, gehört nach `FitnessAppCore`. Für Health gibt es nur Tests der plattformneutralen Zustandslogik (`FitnessAppHealthTests`); das Verhalten von HealthKit selbst lässt sich nur auf dem Gerät prüfen.
- Entwickelt wird ohne lokalen Mac (Windows + Codemagic); `swift test` läuft auf macOS und Linux (auf Linux nur der Core-Teil).

### 8.4 CI und Release

`codemagic.yaml` definiert drei Workflows (Mac mini M2):

| Workflow | Trigger | Aufgabe |
|---|---|---|
| `swift-package` | Push/PR | `swift build`, `swift test --parallel`, Simulator-Build der Library-Schemes |
| `ios-app` | Push/PR | XcodeGen, App + Widget für den Simulator ohne Signing |
| `testflight` | Git-Tag `v*` | Tests als Gate, Version aus dem Tag (`v0.1.73` → 0.1.73), Build-Nummer hochzählen, Signing per App-Store-Connect-API-Key, Archiv, Upload in die TestFlight-Gruppe |

Einrichtung des TestFlight-Flows: [`TestFlightSetup.md`](./TestFlightSetup.md). Einen Public-Release-Workflow gibt es noch nicht.

### 8.5 Konventionen

Ausführlich in [`CONTRIBUTING.md`](./CONTRIBUTING.md). Kurzfassung:

- **String-Katalog** (`Sources/FitnessAppUI/Resources/Localizable.xcstrings`) ist die einzige Quelle für App-Texte; DE, EN und TR immer vollständig (Ausnahme: die Berechtigungstexte in `App/FitnessApp/InfoPlist.xcstrings`, Fallback = englischer Info.plist-Wert). Keys: `domain.subdomain.purpose` mit camelCase-Suffix (keine Parent-Leaf-Kollisionen); Plural über `.one`/`.other`-Keys statt `variations`; mehrere Format-Argumente positional (`%1$@`).
- Nach Refactors `python .scripts/dead_catalog_v3.py` (Ziel `UNUSED: 0`) und `python .scripts/generate_translations_md.py` – im selben Commit wie die Änderung.
- Neue Binärformate zuerst in `.gitattributes` eintragen.
- Commit-Prefix `DEL-…` oder `UX-…` mit kurzer Beschreibung.

### 8.6 Weitere Dokumente

| Datei | Inhalt | Hinweis |
|---|---|---|
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Konventionen, Katalog-Werkzeuge, Migration, Reset-Sequenz | teils veraltet: der Reset läuft heute in `SettingsView.resetApp` |
| [`PlanBauen.md`](./PlanBauen.md) | Aufbau des „Plan bauen“-Assistenten | Beschreibung gültig, der eingebettete Quellcode ist veraltet |
| [`TestFlightSetup.md`](./TestFlightSetup.md) | TestFlight-Einrichtung Schritt für Schritt | App-Name/IDs und einzelne Schritte nicht mehr aktuell |
| [`XcodeSetup.md`](./XcodeSetup.md) | manuelle Xcode-Einbindung | veraltet (heute XcodeGen) |
| [`WidgetSetup.md`](./WidgetSetup.md) | Widget/Live-Activity-Einrichtung | teilweise veraltet |
| [`TRANSLATIONS.md`](./TRANSLATIONS.md) | Übersetzungstabelle je Key | Kopfzeile und Tabelle sind aktuell (per `.scripts/generate_translations_md.py` erzeugt) |

---

## 9. Offene Punkte

- **Widgets:** weitere Home-Screen-Widgets („Nächstes Training“, „Letzte Messung“) sind nur als Idee im Widget-Bundle vermerkt.
- **Release:** Public-Release-Workflow und Datenschutz-Manifest (`PrivacyInfo.xcprivacy`) fehlen noch.
- **Einheiten:** durchgängige lbs-/in-Unterstützung (Eingaben, Volumen, Rekorde, Messung).
- **Lokalisierung:** Widget, Live Activity, Erinnerungen und einzelne Meldungen in DE/EN/TR.
- **Health:** Retro-Sync des Cardio-Baselines aus der HealthKit-Historie (bewusst zurückgestellt, damit Bestandsnutzer keinen neuen Berechtigungsdialog sehen); Workout-Import ohne Hintergrund-Sync; Trainings in Health ohne Kalorien/Puls und ohne automatischen Hintergrund-Export.
- **Coaching:** Auslöser für *Neuer Rekord*, *Plateau* und *Junk Miles*; Wiedereinstieg passt bisher nur Gewichte an (nicht Volumen/RIR); Maximalpuls hat noch keinen Verbraucher.
- **Ausrüstung:** eigenes Feld für Basis-Kilometer (Schemaänderung zurückgestellt).
- **Backups:** optionaler iCloud-Drive-Container und Verschlüsselung.
