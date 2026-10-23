# Zwischenstand 23.10.2026 – Gerätetest grün, SET-01 + AI-01 umgesetzt

**Branch:** `fix/nut01-off01-audit` · **HEAD:** `f728443` · **Basis:** `main` (`5e6ba39`)
**Status:** NUT-01 + OFF-01 abgeschlossen (Gerätetest durch den Nutzer positiv, CI grün). SET-01 und AI-01 sind implementiert, CI-Lauf **40011766658** läuft noch — Ergebnis wird nachgetragen.

---

## 1. Abgeschlossen: NUT-01 + OFF-01

- Gerätetest: **positiv verlaufen** (Rückmeldung des Nutzers).
- CI-Lauf 39959799171: Build grün, **1746/1746 Tests grün**, App+Widget (Debug und Release) gebaut.
- Abschlussbericht: `docs/REVIEW_ABSCHLUSS_2026-10-23_NUT01_OFF01.md`.

---

## 2. SET-01 – RIR-Hilfetext-Schalter wirkt jetzt überall

**Problem (Audit P2):** Der Schalter „RIR-Hilfetext" (Einstellungen → App & Trainingserlebnis → Trainingsverhalten, Beschreibung „Zeigt kurze Erklärungen beim Einstellen der Intensität") wurde nur in `ExerciseEditorView` gelesen. Im laufenden Training zeigte `SetRow.rirSliderRow` den Erklärungstext **immer**.

**Änderung**
| Datei | Änderung |
|---|---|
| `Sources/FitnessAppUI/Workout/SetRow.swift` | neuer `@AppStorage("showRirTooltips")`-Key (gleicher Key/Default wie die beiden anderen Stellen), Erklärungstext unter dem RIR-Regler jetzt in `if showRirTooltips { … }`; Doku an der Stelle korrigiert (sie behauptete, die Einstellung werde hier „nicht mehr gebraucht") |
| `Tests/FitnessAppUITests/RirTooltipToggleScopeTests.swift` | neu: prüft, dass alle drei lesenden Stellen denselben Key deklarieren **und** dass im Training genau der `tooltipKey`-Text hinter dem Gate steht |

Was bleibt sichtbar, wenn der Schalter aus ist: Untertitel „Reps in Reserve", Regler, Skala (0 = nichts mehr / 5 = locker) — also die Bedienung, nicht die Erklärung. Wer die Erklärung über den Regler legt, kann also weiterhin einstellen.

---

## 3. AI-01 – „KI nicht verfügbar" sagt jetzt den echten Grund

**Problem (Audit P2):** Alle fünf Verfügbarkeitszustände der on-device-KI wurden als „auf diesem Gerät nicht verfügbar" angezeigt — auch der Sprach-Fall (Gerät kann es, Modell unterstützt die App-Sprache nicht, z. B. Türkisch vor iOS 26.1) und der Lade-Fall.

**Änderung**
| Datei | Änderung |
|---|---|
| `Sources/FitnessAppAI/NutritionAIAvailability.swift` | neues `NutritionAIUnavailableReasonKey` + `NutritionAIAvailability.unavailableReasonKey` (Core-frei, testbar) — `.available` hat keinen Grund |
| `Sources/FitnessAppUI/Nutrition/AddMealView.swift` | `aiSection` zeigt pro Zustand einen eigenen Text statt des Sammelsatzes |
| `Localizable.xcstrings` | 4 neue Keys × DE/EN/TR, alter Sammel-Key `nutrition.addMeal.aiDraft.unavailable` entfernt (kein toter Key: `UNUSED: 0`, 2526 Keys) |
| `Tests/FitnessAppAITests/NutritionAIAvailabilityTests.swift` | 2 neue Tests: jeder Zustand hat einen eigenen Grund; Keys entsprechen dem Katalogvertrag |

Neue Texte (DE, sinngemäß):
- **Gerät:** „… auf diesem Gerät nicht verfügbar (iOS 26 und ein kompatibles Gerät sind nötig)."
- **Apple Intelligence aus:** „… aus: Apple Intelligence ist in den iOS-Einstellungen nicht aktiviert."
- **Sprache:** „… unterstützt die aktuelle App-Sprache noch nicht (das Gerät selbst kann es)."
- **Modell lädt:** „… wird gerade vorbereitet (Modell lädt noch)."

In allen vier Fällen verweist der Text gleichbleibend auf die manuelle Suche darunter — der manuelle Weg bleibt damit unverändert erreichbar.

---

## 4. Prüfungen

| Prüfung | Ergebnis |
|---|---|
| `python .scripts/dead_catalog_v3.py` | 2526 Keys, **UNUSED 0** ✅ |
| Katalog DE/EN/TR vollständig (Skript) | keine fehlenden/leeren Werte ✅ |
| CI-Lauf 40011766658 (Build + 1746+ Tests + App/Widget) | **läuft** — Ergebnis folgt |
| Gerätetest SET-01/AI-01 | offen (kein Simulator/Gerät in dieser Umgebung) |

## 5. Nächste Schritte
1. CI-Ergebnis für `f728443` abwarten und bei Rot nachziehen.
2. **PRIV-01** (Privacy-Manifest, Audit P2, release-relevant) — als nächstes umsetzen.
3. Danach NAV-01, I18N-01, DATA-01, DOC-01 (P2) und die P3-Punkte.
