# Deltiq

iOS-App für Krafttraining, Ausdauer und Körperwerte. Alles lokal auf dem Gerät – kein Konto, kein Cloud-Sync.

**Status:** Beta · TestFlight · `com.atamya.Deltiq`

---

## Features

- **Pläne** – 20 Programm-Vorlagen, eigene Pläne, Assistent „Plan bauen"
- **Training** – Satz-Logging, Pausen-Timer, Live Activity, AMRAP / EMOM / Auf Zeit / Zirkel
- **Auswertung** – Rekorde, Trends (1RM, Volumen, Cardio-Pace, Gewicht), Kalender, Heatmap
- **Coaching** – Smart Progression, Deload-Vorschlag, Lauf-Coaching, Wiedereinstiegs-Hilfe
- **Messung** – Körperfett (Navy + Deurenberg), FFMI, BMI, Grundumsatz
- **Werkzeuge** – Hantel-Rechner, 1RM-Rechner, TDEE-Rechner, Wasser-Tracker
- **Apple Health** – lesen und schreiben; Workout-Import (Laufen/Radfahren)

---

## Technische Basis

| | |
|---|---|
| Plattform | iOS 17+ · iPhone + iPad |
| Sprachen | Deutsch, Englisch, Türkisch |
| Frameworks | SwiftUI, SwiftData, HealthKit, ActivityKit, WidgetKit |
| Daten | lokal · Export/Import als ZIP (CSV) |
| CI/CD | Codemagic → TestFlight |

---

## Projekt-Struktur

```
Sources/
  FitnessAppCore/     Berechnungslogik, Domäne, SwiftData-Modelle
  FitnessAppAI/       Ernährungs-KI (NutritionAI)
  DeltiqUI/           SwiftUI-Views, Dashboard, Charts
  DeltiqCore/         Analyse, Coaching, Trends
App/FitnessApp/       Entry Point, AppDelegate
Tests/                Unit- und UI-Tests
```

---

## Build & Run

Xcode 16+, iOS 17 SDK, Apple-Developer-Account mit HealthKit- und ActivityKit-Berechtigung.

```bash
open fitnessapp_ios.xcodeproj
```

Pausen-Timer und Wasser-Widget benötigen App-Group `group.com.atamya.Deltiq` – in signierten Builds automatisch aktiv, im Simulator nicht verfügbar.

---

## CI

Branch `main` → Codemagic baut automatisch → TestFlight. Feature-Branches laufen nur Unit-Tests.
